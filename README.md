# UIKit Playground

Книга-практикум по UIKit: 10+ полноценных мини-приложений, разобранных
от LaunchScreen до App Store, плюс каталог UI-паттернов на 60+ позиций.
Параллельно с книгой развивается учебный проект
[`uikit-playground-app`](https://github.com/sirserik/uikit-playground-app)
(пока локально — `~/Desktop/beginner-testing-app/`), где каждый шаг
урока — отдельный коммит.

> ⚠ **Стек.** Swift с `MainActor` по умолчанию (Xcode 26+),
> **UIKit + Storyboard для LaunchScreen, остальное — кодом**, iOS 15+.
> Никакого SwiftUI: эта книга про UIKit. Современные API (`@Observable`,
> `Sheet detents .custom`, `UISheetPresentationController`) — с явными
> `@available`.

## Чем эта книга отличается

Есть [старшая книга «ShopApp Beginner»](https://github.com/sirserik/alma-shop-ios-book-prod/tree/shopapp-beginner)
— линейная история «строим один e-commerce от Hello World до App Store».
Эта — **каталог-практикум**: каждое мини-приложение самодостаточно,
читай в любом порядке, бери куски в свои проекты.

## Что внутри

### Часть I. Фундамент playground'а

- LaunchScreen vs AnimatedSplash — два экрана, оба «splash»
- `PlaygroundWindow` — `UIWindow` подкласс с shake-detect
- `AppManifest` — конфиг одного мини-приложения
- `BootCoordinator` — оркестратор гейтов запуска
- Lifecycle App → Scene → ViewController, `@MainActor` под капотом

### Часть II. Launch-гейты «полноценного» приложения

- Onboarding (UIPageViewController с dots indicator)
- Permission primer (показываем «зачем» **до** системного алерта)
- Auth gate (Login/Register/Forgot/SMS-code/Biometric)
- Force-update / Maintenance gates (серверный конфиг)
- Region / Language picker
- Age gate
- Privacy blur при сворачивании, биометрия при возврате

### Часть III. 10 mini-приложений

| # | Mini-app | Что разбираем |
|---|---|---|
| 1 | **Список дел** | UITableView, custom cell, UserDefaults+Codable, dummyjson seed |
| 2 | **Заметки** | UITextView, файловое хранилище, UISearchController |
| 3 | **Калькулятор** | UIStackView grid, state machine, haptics |
| 4 | **Погода** | URLSession, pull-to-refresh, skeleton, offline, RelativeDateTimeFormatter |
| 5 | **Галерея** | UICollectionView compositional layout, pagination, photo viewer |
| 6 | **Музыкальный плеер** | AVAudioPlayer, custom slider, mini-player → full-screen |
| 7 | **Чат** | TableView с двумя стилями, keyboard avoidance, reactions |
| 8 | **Профиль / Настройки** | insetGrouped с разными cell-стилями, biometric prompt |
| 9 | **Custom Tab Bar** | Свой контейнер вместо UITabBarController |
| 10 | **Сложные экраны** | Stretchy header, sticky sections, parallax, многоуровневый scroll |
| **\*** | **Anatomy of a real app** | Тур по всем launch-гейтам с тумблерами |

### Часть IV. UI Cookbook (60+ паттернов)

- Загрузка: pull-to-refresh, infinite scroll, skeleton, button spinners, progressive images
- Empty / Error / Offline states — 4 эмпти, 3 эррора, баннер offline
- Search: UISearchController, scope buttons, recent searches, chips, sort sheet
- Навигация: large titles, tab bar badges, step indicators, breadcrumbs, custom transitions
- Variety cells: switch, stepper, slider, disclosure, value, multi-line, segmented, picker, inline edit
- Модалки: half/full/page/form sheet, action sheet, alert+textfield, toast, banner, HUD
- Жесты: UIContextMenu, swipe actions, drag-and-drop, pinch-zoom, edge-swipe
- Формы: real-time валидация, auto-format, password strength, wizard, save-as-draft
- Дата/время/деньги: DatePicker styles, RelativeDateTimeFormatter, currency, число-анимация
- Анимации: spring, hero, cell-appearance, SF Symbol анимация
- Haptic feedback (Notification / Impact / Selection)
- Доступность: VoiceOver, Dynamic Type, Reduce Motion, hit targets, контраст
- Темы: dark/light, semantic colors, custom palettes, traitCollection observer
- Status indicators: online dot, typing, badges, page control, progress bars
- Photo viewer: full-screen с zoom/pan/swipe-to-dismiss

### Часть V. Production checklist

- Screenshots для App Store (1290×2796, 6.5"-страт)
- App Privacy анкета и Privacy Manifest (`PrivacyInfo.xcprivacy`)
- Account deletion flow (REQUIRED Apple)
- Push notifications + Deep links + Universal Links
- WidgetKit и App Intents в двух словах
- Accessibility audit перед релизом

## Сборка PDF

```bash
bash build/build-pdf.sh
```

Pandoc → xelatex × 3. Результат — `UIKit-Playground-Book.pdf` в корне.
Стиль/pipeline согласованы с `ShopApp-Book-Beginner`.

## Учебный iOS-проект

[`uikit-playground-app`](https://github.com/sirserik/uikit-playground-app)
(пока `~/Desktop/beginner-testing-app/`) — рабочий Xcode-проект, где
каждый mini-app живёт в `Apps/<Name>/`, общий boot-слой — в `App/`,
дизайн-токены — в `Common/`.

## Как пользоваться книгой

- **Часть I и II** — читай по порядку, они закладывают boot-слой.
- **Часть III** — выбирай mini-app, который интересен сейчас.
- **Часть IV (Cookbook)** — справочник, заглядывай когда нужен конкретный паттерн.
- **Часть V** — перед своим первым релизом.
- **Не списывай.** Печатай каждый кусок кода руками — пальцы запоминают.

## Условные обозначения

> 💡 **Идея.** Самое важное из раздела — в цитатах с лампочкой.

```swift
let example = "это код, который можно (и нужно) набрать"
```

🛠 **Упражнение.** Маленькое задание после раздела. Делай до того, как читать дальше.

📋 **Что мы выучили.** Краткий список фактов в конце главы.
