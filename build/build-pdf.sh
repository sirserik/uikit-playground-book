#!/usr/bin/env bash
# Собирает PDF книги «UIKit Playground» из docs/tutorial/*.md.
# Использование: ./build/build-pdf.sh [output.pdf] [файл1.md файл2.md ...]
#
# По умолчанию собирает все главы по порядку (см. FILES ниже). Если переданы
# отдельные файлы — собирает только их. Удобно для preview одной главы.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$ROOT/UIKit-Playground-Book.pdf}"
shift || true

if [ "$#" -gt 0 ]; then
  FILES=("$@")
else
  FILES=(
    # Часть I. Фундамент playground'а
    "$ROOT/docs/tutorial/00-intro.md"
    "$ROOT/docs/tutorial/01-launch-screen-vs-splash.md"
    "$ROOT/docs/tutorial/02-app-manifest.md"
    "$ROOT/docs/tutorial/03-playground-window.md"
    "$ROOT/docs/tutorial/04-boot-coordinator.md"
    "$ROOT/docs/tutorial/05-lifecycle.md"

    # Часть II. Launch-гейты
    "$ROOT/docs/tutorial/10-onboarding.md"
    "$ROOT/docs/tutorial/11-permission-primer.md"
    "$ROOT/docs/tutorial/12-auth-gate.md"
    "$ROOT/docs/tutorial/13-force-update.md"
    "$ROOT/docs/tutorial/14-region-language.md"
    "$ROOT/docs/tutorial/15-privacy-blur-biometric.md"

    # Часть III. Mini-приложения
    "$ROOT/docs/tutorial/20-todo.md"
    "$ROOT/docs/tutorial/21-notes.md"
    "$ROOT/docs/tutorial/22-calculator.md"
    "$ROOT/docs/tutorial/23-weather.md"
    "$ROOT/docs/tutorial/24-gallery.md"
    "$ROOT/docs/tutorial/25-music.md"
    "$ROOT/docs/tutorial/26-chat.md"
    "$ROOT/docs/tutorial/27-profile.md"
    "$ROOT/docs/tutorial/28-custom-tab-bar.md"
    "$ROOT/docs/tutorial/29-complex-layouts.md"
    "$ROOT/docs/tutorial/30-anatomy.md"

    # Часть IV. UI Cookbook
    "$ROOT/docs/tutorial/40-cookbook-loading.md"
    "$ROOT/docs/tutorial/41-cookbook-empty-error.md"
    "$ROOT/docs/tutorial/42-cookbook-search-filters.md"
    "$ROOT/docs/tutorial/43-cookbook-navigation.md"
    "$ROOT/docs/tutorial/44-cookbook-cells.md"
    "$ROOT/docs/tutorial/45-cookbook-modals.md"
    "$ROOT/docs/tutorial/46-cookbook-gestures.md"
    "$ROOT/docs/tutorial/47-cookbook-forms.md"
    "$ROOT/docs/tutorial/48-cookbook-date-money.md"
    "$ROOT/docs/tutorial/49-cookbook-animations.md"
    "$ROOT/docs/tutorial/50-cookbook-haptics.md"
    "$ROOT/docs/tutorial/51-cookbook-accessibility.md"
    "$ROOT/docs/tutorial/52-cookbook-theming.md"
    "$ROOT/docs/tutorial/53-cookbook-status-indicators.md"
    "$ROOT/docs/tutorial/54-cookbook-photo-viewer.md"

    # Часть V. Production checklist
    "$ROOT/docs/tutorial/60-production-screenshots.md"
    "$ROOT/docs/tutorial/61-production-privacy.md"
    "$ROOT/docs/tutorial/62-production-account-deletion.md"
    "$ROOT/docs/tutorial/63-production-push-deeplinks.md"
    "$ROOT/docs/tutorial/64-production-widgets-intents.md"
    "$ROOT/docs/tutorial/65-production-accessibility-audit.md"
  )
fi

# Фильтруем только существующие файлы (для постепенного наполнения).
EXISTING=()
for f in "${FILES[@]}"; do
  if [ -f "$f" ]; then
    EXISTING+=("$f")
  else
    echo "  skip (not yet): $(basename "$f")"
  fi
done

if [ "${#EXISTING[@]}" -eq 0 ]; then
  echo "Ни одной главы не найдено. Нечего собирать."
  exit 1
fi

echo "Сборка PDF: ${#EXISTING[@]} глав → $OUT"

# Локально pandoc может быть установлен через Homebrew (не в $PATH под bash).
PANDOC="${PANDOC:-pandoc}"
if ! command -v "$PANDOC" >/dev/null 2>&1; then
  for candidate in /opt/homebrew/bin/pandoc /usr/local/bin/pandoc; do
    if [ -x "$candidate" ]; then PANDOC="$candidate"; break; fi
  done
fi
if ! command -v "$PANDOC" >/dev/null 2>&1; then
  echo "pandoc не найден. Установи: brew install pandoc"
  exit 1
fi

XELATEX="${XELATEX:-xelatex}"
USE_TECTONIC=0
if ! command -v "$XELATEX" >/dev/null 2>&1; then
  for candidate in /Library/TeX/texbin/xelatex /usr/local/texlive/*/bin/*/xelatex; do
    if [ -x "$candidate" ]; then XELATEX="$candidate"; break; fi
  done
fi
if ! command -v "$XELATEX" >/dev/null 2>&1; then
  # Fallback на tectonic — компактный TeX-движок (~16MB) без mactex.
  for candidate in /opt/homebrew/bin/tectonic /usr/local/bin/tectonic tectonic; do
    if command -v "$candidate" >/dev/null 2>&1; then
      XELATEX="$candidate"
      USE_TECTONIC=1
      break
    fi
  done
fi
if ! command -v "$XELATEX" >/dev/null 2>&1; then
  echo "Нужен xelatex или tectonic. Установи: brew install tectonic"
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Картинки в .md идут как ../images/... (относительно docs/tutorial/X.md).
# xelatex запускается из $TMP, поэтому добавляем \graphicspath.
cat > "$TMP/graphicspath.tex" <<EOF
\graphicspath{{$ROOT/docs/tutorial/}{$ROOT/docs/images/}}
EOF

"$PANDOC" \
  -s \
  "$ROOT/build/metadata.yaml" \
  "${EXISTING[@]}" \
  --pdf-engine="$XELATEX" \
  --top-level-division=chapter \
  --highlight-style=tango \
  --listings=false \
  --include-in-header="$ROOT/build/preamble.tex" \
  --include-in-header="$TMP/graphicspath.tex" \
  -o "$TMP/book.tex"

cd "$TMP"
if [ "$USE_TECTONIC" = "1" ]; then
  # tectonic сам делает нужное число проходов для TOC, plus auto-download
  # отсутствующих пакетов в локальный кэш.
  echo "  tectonic..."
  "$XELATEX" --keep-logs --outdir "$TMP" book.tex 2>&1 | tail -30 || {
    echo "tectonic failed"; exit 1
  }
else
  for i in 1 2 3; do
    echo "  xelatex pass $i/3..."
    "$XELATEX" -interaction=batchmode -halt-on-error book.tex >/dev/null 2>&1 || {
      "$XELATEX" -interaction=nonstopmode book.tex 2>&1 | tail -30
      exit 1
    }
  done
fi

mv "$TMP/book.pdf" "$OUT"
cd "$ROOT"

echo "Готово: $OUT ($(du -h "$OUT" | cut -f1))"
