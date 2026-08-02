# Глава 35. Cookbook — темы и цвета

Dark / Light mode, semantic colors, custom palettes.

## 35.1 System colors (adaptive)

```swift
view.backgroundColor = .systemBackground       // белый light / чёрный dark
label.textColor = .label                       // чёрный light / белый dark
label.textColor = .secondaryLabel              // серый, чуть приглушённый
label.textColor = .tertiaryLabel               // ещё бледнее

// Background
view.backgroundColor = .systemBackground
view.backgroundColor = .secondarySystemBackground  // чуть приглушённый
view.backgroundColor = .systemGroupedBackground     // для grouped-таблиц
view.backgroundColor = .tertiarySystemBackground

// Fill
view.backgroundColor = .systemFill
view.backgroundColor = .secondarySystemFill
view.backgroundColor = .tertiarySystemFill
view.backgroundColor = .quaternarySystemFill

// Separator
view.backgroundColor = .separator
view.backgroundColor = .opaqueSeparator
```

Semantic colors **автоматически** меняются при переключении dark/light
mode. **Никогда не используй `.white` или `.black` для UI** — закрепи
адаптивные.

`systemBackground` vs `secondarySystemBackground` — для layered
интерфейсов. Карточка на сером фоне: `secondarySystemBackground` под
ней, `tertiarySystemBackground` внутри карточки.

Полный список: [Apple Human Interface Guidelines — Color](https://developer.apple.com/design/human-interface-guidelines/color).

## 35.2 Tint colors

```swift
view.tintColor = .systemBlue
button.tintColor = .systemRed  // override
```

`tintColor` — наследуется по view-hierarchy. Установил на root view,
все subviews подхватывают. Если хочешь конкретно другую кнопку —
override локально.

`.systemBlue` / `.systemRed` / `.systemGreen` / etc — автоматически
адаптивные. Apple каждой версией iOS чуть подстраивает оттенки.

## 35.3 Custom adaptive color

```swift
let cardBackground = UIColor { traitCollection in
    if traitCollection.userInterfaceStyle == .dark {
        return UIColor(white: 0.15, alpha: 1.0)
    } else {
        return UIColor(white: 0.98, alpha: 1.0)
    }
}
```

`UIColor(dynamicProvider:)` (iOS 13+) — closure, который iOS вызывает
при изменении traitCollection (включая dark/light mode).

## 35.4 Asset Catalog colors

Recommended for custom palettes.

В Assets.xcassets:
1. New Color Set → "BrandPrimary".
2. Set Any Appearance, Dark Appearance отдельно.
3. Light: #1A73E8, Dark: #4285F4.

В коде:

```swift
let primary = UIColor(named: "BrandPrimary")!
view.backgroundColor = primary
```

Один color set автоматически работает для обоих режимов.

## 35.5 Override interfaceStyle

Если хочешь **конкретный** VC всегда в dark mode:

```swift
override func viewDidLoad() {
    super.viewDidLoad()
    overrideUserInterfaceStyle = .dark  // только этот VC и дети
}
```

Применили в Калькуляторе (Глава 14) — всегда тёмный, независимо от
системы.

Для всего приложения:

```swift
// В SceneDelegate
window?.overrideUserInterfaceStyle = .dark
```

## 35.6 Detect mode change

```swift
override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
        // Manual updates if needed
        updateGradient()
    }
}
```

Если у тебя есть **CALayer-based** цвета (gradients, shadows) —
адаптивные UIColor'ы в layer не работают. Надо обновлять руками в
`traitCollectionDidChange`.

```swift
private func updateGradient() {
    gradient.colors = [
        UIColor.systemBlue.cgColor,
        UIColor.systemPurple.cgColor,
    ]
}
```

Без этого gradient «застрянет» в режиме первоначальной установки.

## 35.7 Settings let user choose theme

```swift
enum AppTheme: Int, CaseIterable {
    case system, light, dark
    var displayName: String {
        switch self {
        case .system: return "Системная"
        case .light: return "Светлая"
        case .dark: return "Тёмная"
        }
    }
    var userInterfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: return .unspecified
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// Сохранение
UserDefaults.standard.set(theme.rawValue, forKey: "settings.theme")

// Применение
let theme = AppTheme(rawValue: UserDefaults.standard.integer(forKey: "settings.theme")) ?? .system
windowScene.windows.first?.overrideUserInterfaceStyle = theme.userInterfaceStyle
```

`unspecified` — следовать system. `.light` / `.dark` — заставить.

Picker для выбора — `UIMenu` или action sheet (см. Глава 27).

## 35.8 Brand palette

Для приложения с бренд-цветами обычно делают `Palette` enum:

```swift
enum Palette {
    static let primary = UIColor(named: "BrandPrimary")!
    static let secondary = UIColor(named: "BrandSecondary")!
    static let accent = UIColor(named: "BrandAccent")!
    static let success = UIColor(named: "BrandSuccess")!
    static let warning = UIColor(named: "BrandWarning")!
    static let danger = UIColor(named: "BrandDanger")!
}

view.backgroundColor = Palette.primary
button.tintColor = Palette.accent
```

Все цвета в одном месте, легко поддерживать. Если дизайнер сказал
«поменяй основной с синего на бирюзовый» — меняешь color set в
Assets, без перекомпиляции (build settings, не код).

## 35.9 Color contrast

WCAG 2.0:
- **AA**: 4.5:1 для нормального текста, 3:1 для большого (≥ 24pt).
- **AAA**: 7:1 для нормального, 4.5:1 для большого.

Apple Accessibility Inspector проверяет автоматически. Цвета iOS
системные — все проходят.

Custom — проверь вручную (online calculators или Xcode Inspector).

`UIAccessibility.isDarkerSystemColorsEnabled` — увеличить контраст:

```swift
override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    let increased = UIAccessibility.isDarkerSystemColorsEnabled
    label.textColor = increased ? .label : .secondaryLabel
}
```

## 35.10 Trait-based colors in Storyboard

Если используешь Asset Catalog colors, в Storyboard они доступны в
list'е цветов. Назначаешь "BrandPrimary" — работает с light/dark.

Hardcoded colors в Storyboard (`backgroundColor: rgb(123, 45, 67)`) —
не адаптивные. Best practice — color set'ы.

## 35.11 Custom theme switcher (без UI restart)

```swift
extension UIWindow {
    func setTheme(_ theme: AppTheme) {
        UIView.transition(with: self, duration: 0.3,
                          options: .transitionCrossDissolve,
                          animations: {
            self.overrideUserInterfaceStyle = theme.userInterfaceStyle
        })
    }
}

// Use
windowScene.windows.first?.setTheme(.dark)
```

Cross-dissolve между темами вместо instant flip.

## 35.12 Trait inheritance в child VC

Когда parent VC меняет `overrideUserInterfaceStyle`, **все** child
VC'ы автоматически получают новый trait. Modal'ы (presented VC'ы) —
независимы, нужно явно прокинуть.

## 📋 Что мы выучили

- **Semantic colors** (`.label`, `.systemBackground`) — всегда
  адаптивные. Не используй `.white`/`.black`.
- **`tintColor`** наследуется по hierarchy.
- **`UIColor(dynamicProvider:)`** для custom adaptive colors.
- **Asset Catalog color sets** — лучшее место для бренд-палитры,
  поддерживает Any/Dark appearance.
- **`overrideUserInterfaceStyle`** — заставить VC в конкретную тему.
- **`traitCollectionDidChange`** — обновить CALayer-based цвета
  (gradients).
- **User-chosen theme** — UserDefaults + apply on app start или
  на change.
- **Color contrast** — AA минимум 4.5:1.
- **`UIAccessibility.isDarkerSystemColorsEnabled`** — реагировать на
  Increase Contrast.
- **`UIView.transition`** для плавной смены темы.

## Apple Developer Documentation

- [UITraitCollection](https://developer.apple.com/documentation/uikit/uitraitcollection) — все среды view (interface style, content size, layout direction).
- [UITraitCollection/userInterfaceStyle](https://developer.apple.com/documentation/uikit/uitraitcollection/1651063-userinterfacestyle) — текущий dark / light режим.
- [UIUserInterfaceStyle](https://developer.apple.com/documentation/uikit/uiuserinterfacestyle) — `.unspecified` / `.light` / `.dark`.
- [UIView/overrideUserInterfaceStyle](https://developer.apple.com/documentation/uikit/uiview/3238086-overrideuserinterfacestyle) — заставить конкретный VC / window работать в нужной теме.
- [UIColor/init(dynamicProvider:)](https://developer.apple.com/documentation/uikit/uicolor) — adaptive color через closure, iOS 13+.
- [UITraitChangeRegistration](https://developer.apple.com/documentation/uikit/uitraitchangeregistration) — `registerForTraitChanges(_:handler:)`, современный способ реагировать на смену трейтов, iOS 17+.
- [UITraitEnvironment/traitCollectionDidChange(_:)](https://developer.apple.com/documentation/uikit/uitraitenvironment/1623516-traitcollectiondidchange) — legacy-метод (помечен deprecated в iOS 17), нужен для обновления CALayer-цветов в старых версиях.
- [UITraitCollection/hasDifferentColorAppearance(comparedTo:)](https://developer.apple.com/documentation/uikit/uitraitcollection) — отличить смену именно цветовой темы от других trait-изменений.
- [UIColor — UI element colors](https://developer.apple.com/documentation/uikit/uicolor/standard_colors#3174519) — semantic colors (`.label`, `.systemBackground`, fill / separator).
- [HIG — Dark Mode](https://developer.apple.com/design/human-interface-guidelines/dark-mode) — гайдлайн Apple по dark mode и Asset Catalog Any/Dark Appearance.
- [HIG — Color](https://developer.apple.com/design/human-interface-guidelines/color) — палитра системных и semantic цветов.

→ [Глава 36. Cookbook: индикаторы статуса](./53-cookbook-status-indicators.md)
