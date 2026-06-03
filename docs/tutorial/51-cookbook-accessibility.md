# Глава 34. Cookbook — accessibility

Доступность приложения для людей с ограниченными возможностями. Это
не «было бы хорошо», а **обязательно** в App Store guidelines, и
часто решает 5-10% юзеров.

## 34.1 VoiceOver — accessibilityLabel и hint

**Когда применять.** Любой UI-элемент должен сообщать VoiceOver'у,
что он такое.

```swift
button.accessibilityLabel = "Удалить заметку"
button.accessibilityHint = "Дважды коснись, чтобы удалить эту заметку"
```

`accessibilityLabel` — **что это** (короткое имя). По умолчанию для
кнопок с title — берётся title. Если иконка без текста — нужно явно.

`accessibilityHint` — **дополнительная подсказка**. Указывает действие.
Опционально.

**Иконки без текста:**

```swift
let deleteButton = UIButton(type: .system)
deleteButton.setImage(UIImage(systemName: "trash"), for: .normal)
deleteButton.accessibilityLabel = "Удалить"  // ← обязательно!
```

Без `accessibilityLabel` VoiceOver скажет «кнопка» или «иконка», что
бесполезно.

## 34.2 Скрыть от VoiceOver

```swift
decorativeView.isAccessibilityElement = false
decorativeView.accessibilityElementsHidden = true
```

Чисто декоративные элементы (background, разделители) — скрываем.
VoiceOver их пропускает.

## 34.3 Группировка элементов

```swift
let card = UIView()
let titleLabel = UILabel()
let priceLabel = UILabel()

// Без группировки — VoiceOver читает по одному
// "Заголовок: iPhone 15 Pro" → "1199$"

// С группировкой — одно объявление
card.isAccessibilityElement = true
card.accessibilityLabel = "iPhone 15 Pro, цена 1199 долларов"
```

Когда несколько UILabel в одной ячейке, лучше группировать в один
accessible element с объединённым label'ом.

## 34.4 Dynamic Type — автоматический

```swift
label.font = UIFont.preferredFont(forTextStyle: .body)
label.adjustsFontForContentSizeCategory = true
```

**`preferredFont(forTextStyle:)`** — system font, размер которого
подстраивается под Dynamic Type setting (Settings → Display & Brightness
→ Text Size).

**`adjustsFontForContentSizeCategory = true`** — обязательно, иначе
size не пересчитается при изменении.

Стили:
- `.largeTitle` — для main titles.
- `.title1` / `.title2` / `.title3` — заголовки.
- `.headline` / `.body` / `.callout` / `.subheadline`.
- `.footnote` / `.caption1` / `.caption2`.

Custom font:

```swift
let fontMetrics = UIFontMetrics(forTextStyle: .body)
let customFont = UIFont(name: "Avenir-Book", size: 16)!
label.font = fontMetrics.scaledFont(for: customFont)
label.adjustsFontForContentSizeCategory = true
```

`UIFontMetrics` — даёт scaled font под Dynamic Type для custom-шрифтов.

## 34.5 Reduce Motion

```swift
if UIAccessibility.isReduceMotionEnabled {
    // Простая анимация — fade без spring
    UIView.animate(withDuration: 0.2) { view.alpha = 1 }
} else {
    // Полная анимация
    UIView.animate(withDuration: 0.5,
                   usingSpringWithDamping: 0.6,
                   initialSpringVelocity: 0.3) {
        view.transform = .identity
    }
}
```

Юзеры с motion sickness отключают сложные анимации в Settings.
Уважай это — простые fades вместо spring'ов.

Также: `UIAccessibility.reduceMotionStatusDidChangeNotification` —
если хочешь реагировать на смену в реальном времени.

## 34.6 Hit targets — минимум 44pt

Apple Human Interface Guidelines: **44×44 points** — минимальный
tappable размер.

```swift
button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
button.widthAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
```

Если иконка маленькая (например, 16pt), увеличь content insets:

```swift
var cfg = UIButton.Configuration.plain()
cfg.image = UIImage(systemName: "xmark")
cfg.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
let button = UIButton(configuration: cfg)
// итого 16 + 12*2 = 40pt по каждой стороне, чуть мало
// можно увеличить insets до 14
```

## 34.7 Contrast — поддержка `UIAccessibility.isDarkerSystemColorsEnabled`

Юзеры с проблемами зрения часто включают «Increase Contrast» в
Settings. Проверка:

```swift
if UIAccessibility.isDarkerSystemColorsEnabled {
    label.textColor = .label  // высокий контраст
} else {
    label.textColor = .secondaryLabel  // обычный
}
```

Лучше — использовать `.systemBackground`/`.label`/`.secondaryLabel` —
они **автоматически** адаптируются. Свои кастомные цвета проверяй
на contrast (4.5:1 для текста, 3:1 для UI).

## 34.8 Accessibility traits

```swift
button.accessibilityTraits = [.button]
imageView.accessibilityTraits = [.image]
label.accessibilityTraits = [.staticText]
slider.accessibilityTraits = [.adjustable]  // VoiceOver предлагает swipe up/down

// Несколько
button.accessibilityTraits = [.button, .selected]  // выбранная кнопка
```

iOS обычно проставляет автоматически. Но кастомные UIView нуждаются
в явных traits — иначе VoiceOver не понимает, что это.

## 34.9 Accessibility value (для slider'а)

```swift
slider.accessibilityValue = "50 процентов"
// VoiceOver скажет: "Громкость, регулируемая, 50 процентов"
```

Для значений (slider, stepper, picker) — `accessibilityValue`
сообщает текущее значение.

## 34.10 Test через VoiceOver

В симуляторе:
- `Cmd+F5` (или Settings → Accessibility → VoiceOver).
- Жесты: swipe right / left — следующий / предыдущий элемент.
  Double-tap — активировать.

На устройстве:
- Settings → Accessibility → VoiceOver → On.
- Или Triple-click home/side button (если настроен Accessibility
  Shortcut).

**Прогон VoiceOver через main flow** — обязательно перед релизом.

## 34.11 Accessibility Inspector (Xcode)

`Xcode → Open Developer Tool → Accessibility Inspector`. Подключается
к симулятору, показывает все элементы, их labels, traits, hierarchy.
Audit-режим находит частые проблемы (низкий contrast, hit targets
< 44pt).

## 34.12 Dynamic Type — table cells

```swift
tableView.rowHeight = UITableView.automaticDimension
tableView.estimatedRowHeight = 44

// В ячейке
label.numberOfLines = 0
label.font = UIFont.preferredFont(forTextStyle: .body)
label.adjustsFontForContentSizeCategory = true
```

`automaticDimension` + `numberOfLines = 0` + `preferredFont` —
ячейка растёт при увеличении Dynamic Type без обрезания текста.

## 34.13 Image accessibility

```swift
imageView.accessibilityLabel = "Логотип Apple"

// Декоративное изображение (например, фон) — скрыть
backgroundImage.isAccessibilityElement = false
```

## 34.14 Custom actions

Для ячеек с несколькими действиями (swipe-actions, context menu):

```swift
cell.accessibilityCustomActions = [
    UIAccessibilityCustomAction(name: "Удалить") { [weak self] _ in
        self?.delete(at: indexPath)
        return true
    },
    UIAccessibilityCustomAction(name: "Архив") { [weak self] _ in
        self?.archive(at: indexPath)
        return true
    },
]
```

VoiceOver скажет: «доступны 2 действия — swipe up/down для выбора».
Юзер swipe'ит — слышит «Удалить», double-tap — удалится.

Без custom actions swipe-actions недоступны для VoiceOver'а.

## 34.15 Бытовая аналогия

Accessibility — это **сурдопереводчик в кинотеатре**. Кто-то не
слышит звук — сурдопереводчик пересказывает диалоги. Кто-то не
видит — audio description.

Без accessibility приложение «без звука» для VoiceOver-юзеров и
«слишком мелкое» для пожилых.

Всё, что мы делаем — это **дополнительные знаки** для альтернативного
восприятия. Полные титры (`accessibilityLabel`) к каждому
фрагменту, увеличенный шрифт (Dynamic Type) для тех, кто плохо видит,
крупные кнопки (44pt) для шатких рук.

## 📋 Что мы выучили

- **`accessibilityLabel`** для иконок без текста — обязательно.
- **`accessibilityHint`** — опциональное «что произойдёт».
- **`isAccessibilityElement = false`** для декоративных view'ов.
- **Группировка** через `isAccessibilityElement = true` на родителе.
- **`UIFont.preferredFont(forTextStyle:)`** + `adjustsFontForContentSizeCategory
  = true` — Dynamic Type.
- **`UIFontMetrics`** для custom-шрифтов с Dynamic Type.
- **`UIAccessibility.isReduceMotionEnabled`** — упрощать анимации.
- **Min hit target 44×44pt**.
- **`accessibilityTraits`** для custom view'ов.
- **`accessibilityValue`** для slider'ов / stepper'ов.
- **VoiceOver test** (`Cmd+F5` в симуляторе) — обязательно перед
  релизом.
- **Accessibility Inspector** в Xcode — audit-инструмент.
- **`accessibilityCustomActions`** — для swipe-actions и контекстных
  меню.

## Apple Developer Documentation

- [UIAccessibility](https://developer.apple.com/documentation/uikit/uiaccessibility) — глобальные accessibility-настройки и нотификации.
- [UIAccessibility.isVoiceOverRunning](https://developer.apple.com/documentation/uikit/uiaccessibility/1615187-isvoiceoverrunning) — VoiceOver включён.
- [UIAccessibility.isReduceMotionEnabled](https://developer.apple.com/documentation/uikit/uiaccessibility/1615133-isreducemotionenabled) — пользователь просит упрощать анимации.
- [UIAccessibility.isDarkerSystemColorsEnabled](https://developer.apple.com/documentation/uikit/uiaccessibility/1615178-isdarkersystemcolorsenabled) — Increase Contrast.
- [UIView/accessibilityLabel](https://developer.apple.com/documentation/objectivec/nsobject/1615181-accessibilitylabel) — короткое имя элемента для VoiceOver.
- [UIView/accessibilityHint](https://developer.apple.com/documentation/objectivec/nsobject/1615093-accessibilityhint) — подсказка о действии.
- [UIView/accessibilityValue](https://developer.apple.com/documentation/objectivec/nsobject/1615117-accessibilityvalue) — текущее значение для slider / stepper.
- [UIView/accessibilityTraits](https://developer.apple.com/documentation/objectivec/nsobject/1615197-accessibilitytraits) — `.button`, `.image`, `.adjustable` и т. д.
- [UIAccessibilityIdentification](https://developer.apple.com/documentation/uikit/uiaccessibilityidentification) — `accessibilityIdentifier` для UI-тестов.
- [UIAccessibilityCustomAction](https://developer.apple.com/documentation/uikit/uiaccessibilitycustomaction) — кастомные действия (swipe-actions для VoiceOver).
- [UIContentSizeCategory](https://developer.apple.com/documentation/uikit/uicontentsizecategory) — текущий размер Dynamic Type.
- [UIFontMetrics](https://developer.apple.com/documentation/uikit/uifontmetrics) — масштабирование custom-шрифтов под Dynamic Type.
- [UIFont/preferredFont(forTextStyle:)](https://developer.apple.com/documentation/uikit/uifont/1619030-preferredfont) — системный шрифт под Dynamic Type.
- [HIG — Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility) — общий гайдлайн Apple по доступности.

→ [Глава 35. Cookbook: темы и цвета](./52-cookbook-theming.md)
