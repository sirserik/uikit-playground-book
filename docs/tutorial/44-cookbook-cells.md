# Глава 27. Cookbook — типы ячеек

Какие ячейки бывают в `UITableView` и как их делать.

## 27.1 Default content configuration

**Когда применять.** Стандартная ячейка с текстом, иконкой, accessory.
Самая частая.

```swift
var content = cell.defaultContentConfiguration()
content.text = "Заголовок"
content.secondaryText = "Подзаголовок"
content.image = UIImage(systemName: "star.fill")
content.imageProperties.tintColor = .systemYellow
content.imageProperties.maximumSize = CGSize(width: 28, height: 28)
content.textProperties.font = .systemFont(ofSize: 16, weight: .semibold)
content.secondaryTextProperties.color = .secondaryLabel
content.prefersSideBySideTextAndSecondaryText = true
cell.contentConfiguration = content
cell.accessoryType = .disclosureIndicator
```

Один API заменил кучу старых: `cell.textLabel`, `cell.imageView`,
`cell.detailTextLabel`. Все настраивается через configuration.

`prefersSideBySideTextAndSecondaryText = true` — text слева, secondary
справа (как в iOS Settings). Без него — текст под друг другом.

## 27.2 Switch cell

```swift
var content = cell.defaultContentConfiguration()
content.text = "Уведомления"
cell.contentConfiguration = content

let toggle = UISwitch()
toggle.isOn = enabled
toggle.addAction(UIAction { [weak self] _ in
    self?.setEnabled(toggle.isOn)
}, for: .valueChanged)
cell.accessoryView = toggle
cell.selectionStyle = .none
```

См. Главу 19 (Profile) для деталей. `selectionStyle = .none` —
ячейка не должна реагировать на тап (только switch).

## 27.3 Stepper cell

```swift
var content = cell.defaultContentConfiguration()
content.text = "Уровень"
content.secondaryText = "\(value)"
content.prefersSideBySideTextAndSecondaryText = true
cell.contentConfiguration = content

let stepper = UIStepper()
stepper.minimumValue = 0
stepper.maximumValue = 10
stepper.value = Double(value)
stepper.addAction(UIAction { [weak self] _ in
    self?.setValue(Int(stepper.value))
    // ... reload row для обновления text ...
}, for: .valueChanged)
cell.accessoryView = stepper
```

## 27.4 Slider cell (полный label + slider)

```swift
cell.contentConfiguration = nil
let label = UILabel()
label.text = "Размер: \(value)"
let slider = UISlider()
slider.value = value
slider.addAction(UIAction { [weak label] _ in
    label?.text = "Размер: \(slider.value)"
    // save value
}, for: .valueChanged)

let stack = UIStackView(arrangedSubviews: [label, slider])
stack.axis = .vertical
stack.spacing = 8
stack.translatesAutoresizingMaskIntoConstraints = false

// Удалить старые subviews при reuse
for sub in cell.contentView.subviews { sub.removeFromSuperview() }
cell.contentView.addSubview(stack)
// ... pin к layoutMarginsGuide ...
```

Отказываемся от content configuration, кладём кастомный stack.
**Удаляем старые subviews** перед добавлением — критично для reuse.

## 27.5 Inline picker (UIMenu)

```swift
var content = cell.defaultContentConfiguration()
content.text = "Тема"
content.secondaryText = currentTheme
content.prefersSideBySideTextAndSecondaryText = true
cell.contentConfiguration = content

let actions = themes.map { theme in
    UIAction(title: theme, state: theme == currentTheme ? .on : .off) { [weak self] _ in
        self?.setTheme(theme)
    }
}
let button = UIButton(type: .system)
button.menu = UIMenu(children: actions)
button.showsMenuAsPrimaryAction = true
button.setImage(UIImage(systemName: "chevron.up.chevron.down"), for: .normal)
button.tintColor = .tertiaryLabel
cell.accessoryView = button
cell.selectionStyle = .none
```

Тап по кнопке — открывает popup с вариантами. Активный — галочкой.

## 27.6 Disclosure value cell

```swift
var content = cell.defaultContentConfiguration()
content.text = "О приложении"
content.secondaryText = "v1.0.0"
content.prefersSideBySideTextAndSecondaryText = true
cell.contentConfiguration = content
cell.accessoryType = .disclosureIndicator
```

Стандарт для row, ведущей дальше («О приложении → v1.0.0 →»).

## 27.7 Multi-line cell

```swift
var content = cell.defaultContentConfiguration()
content.text = "Заголовок"
content.textProperties.numberOfLines = 0
content.secondaryText = "Длинный текст описания, который занимает несколько строк..."
content.secondaryTextProperties.numberOfLines = 0
cell.contentConfiguration = content
```

`numberOfLines = 0` — без ограничения. Высота ячейки автоматически
(установи `tableView.rowHeight = UITableView.automaticDimension`).

## 27.8 Segmented cell

Сегмент-control внутри ячейки:

```swift
cell.contentConfiguration = nil
let segmented = UISegmentedControl(items: ["День", "Неделя", "Месяц"])
segmented.selectedSegmentIndex = currentIndex
segmented.addAction(UIAction { [weak self] _ in
    self?.setPeriod(segmented.selectedSegmentIndex)
}, for: .valueChanged)
segmented.translatesAutoresizingMaskIntoConstraints = false

for sub in cell.contentView.subviews { sub.removeFromSuperview() }
cell.contentView.addSubview(segmented)
// ... pin к layoutMarginsGuide ...
```

## 27.9 Picker cell (full width)

`UIDatePicker` или `UIPickerView` внутри ячейки. С iOS 14
`UIDatePicker` стал компактным (`.compact` стиль):

```swift
let datePicker = UIDatePicker()
datePicker.datePickerMode = .dateAndTime
datePicker.preferredDatePickerStyle = .compact
datePicker.addAction(UIAction { [weak self] _ in
    self?.setDate(datePicker.date)
}, for: .valueChanged)

cell.contentView.addSubview(datePicker)
// ... pin ...
```

`.compact` — маленькая «таблетка», открывается inline когда тапаешь.
Старый `.wheels` — три крутящихся барабана, full-screen modal.

## 27.10 Inline editing cell

Поле UITextField прямо в ячейке (без отдельного экрана):

```swift
cell.contentConfiguration = nil
let label = UILabel()
label.text = "Имя"
let textField = UITextField()
textField.placeholder = "Введи имя"
textField.text = currentName
textField.addAction(UIAction { [weak self] _ in
    self?.setName(textField.text ?? "")
}, for: .editingChanged)

let stack = UIStackView(arrangedSubviews: [label, textField])
stack.axis = .horizontal
stack.spacing = 16
stack.distribution = .fill
label.setContentHuggingPriority(.required, for: .horizontal)
textField.setContentHuggingPriority(.defaultLow, for: .horizontal)
// ... добавить в cell.contentView ...
```

Label слева, textField справа (тянется до края).

`setContentHuggingPriority(.required)` на label — не сжимаемое.
`.defaultLow` на textField — расширяется.

## 27.11 Variable-height cells

```swift
override func viewDidLoad() {
    super.viewDidLoad()
    tableView.rowHeight = UITableView.automaticDimension
    tableView.estimatedRowHeight = 60
}
```

`automaticDimension` — высота берётся из Auto Layout ячейки.

`estimatedRowHeight` — для производительности (scroll bar calculation).
Установи примерно по средней.

## 27.12 Cell selection style

```swift
cell.selectionStyle = .none    // не подсвечивать
cell.selectionStyle = .default // системная подсветка (бледно-серый)
cell.selectionStyle = .blue    // (deprecated)
cell.selectionStyle = .gray    // (deprecated)
```

Для cells с `UISwitch`/`UISlider` — `.none`. Для disclosure /
button — `.default`.

Если хочешь **кастомный** highlight цвет:

```swift
let bg = UIView()
bg.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
cell.selectedBackgroundView = bg
```

## 27.13 Avatar в ячейке

```swift
var content = cell.defaultContentConfiguration()
content.text = user.name
content.secondaryText = user.email
content.image = UIImage(systemName: "person.crop.circle.fill")
content.imageProperties.maximumSize = CGSize(width: 36, height: 36)
content.imageProperties.cornerRadius = 18  // круглая
cell.contentConfiguration = content
```

`cornerRadius` на imageProperties — Apple сам округляет.

Для real-фото — загружаем асинхронно, подменяем `content.image` через
`cell.contentConfiguration = content` (не назначай прямо в imageView,
content configuration перетрёт).

## 27.14 Drag handles (editing mode)

```swift
tableView.isEditing = true

func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool { true }
func tableView(_ tableView: UITableView, moveRowAt source: IndexPath, to dest: IndexPath) {
    let item = items.remove(at: source.row)
    items.insert(item, at: dest.row)
}

// Скрыть minus-button
func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
    .none
}

// Скрыть отступ при editing
func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool { false }
```

`isEditing = true` — постоянный editing-mode. Справа появляются drag
handles (≡), можно перетаскивать.

Если **только** drag без delete — `editingStyleForRowAt: .none`.

См. Главу 16 (Gallery) для examples.

## 📋 Что мы выучили

- **Default content configuration** — современный API для базовой
  ячейки. `image`, `text`, `secondaryText`, `imageProperties`.
- **Switch / Stepper** в `accessoryView` + `selectionStyle = .none`.
- **Slider / Segmented / Inline edit** — отказ от content
  configuration, кастомный stack в `contentView`. **Удаляй старые
  subviews** при reuse.
- **Inline picker** — `UIMenu` на `UIButton`, активный — `state: .on`.
- **Disclosure** — `accessoryType = .disclosureIndicator` для
  «откроется детальный экран».
- **Multi-line** — `numberOfLines = 0` + `rowHeight = automaticDimension`.
- **Avatar** — `imageProperties.cornerRadius` для круглого.
- **Drag-to-reorder** — `isEditing = true` + `moveRowAt`. Скрыть
  minus через `editingStyleForRowAt: .none`.

## Apple Developer Documentation

- [`UITableViewCell`](https://developer.apple.com/documentation/uikit/uitableviewcell) — базовая ячейка таблицы.
- [`UICollectionViewListCell`](https://developer.apple.com/documentation/uikit/uicollectionviewlistcell) — list-cell для современных collection views (iOS 14+).
- [`UIListContentConfiguration`](https://developer.apple.com/documentation/uikit/uilistcontentconfiguration) — `defaultContentConfiguration()`, `cell()`, `subtitleCell()` и т.п. (iOS 14+).
- [`UIListContentConfiguration.ImageProperties`](https://developer.apple.com/documentation/uikit/uilistcontentconfiguration/imageproperties) — `cornerRadius`, `maximumSize`, `tintColor`.
- [`UICellAccessory`](https://developer.apple.com/documentation/uikit/uicellaccessory) — современный набор accessory'ев (`.disclosureIndicator()`, `.checkmark()`, кастомные) (iOS 14+).
- [`UIBackgroundConfiguration`](https://developer.apple.com/documentation/uikit/uibackgroundconfiguration) — фон ячейки; нормальное и selected состояния.
- [`UISwitch`](https://developer.apple.com/documentation/uikit/uiswitch) — toggle в `accessoryView`.
- [`UIStepper`](https://developer.apple.com/documentation/uikit/uistepper) — `+`/`−` контрол.
- [`UISlider`](https://developer.apple.com/documentation/uikit/uislider) — ползунок диапазона.
- [`UISegmentedControl`](https://developer.apple.com/documentation/uikit/uisegmentedcontrol) — сегмент-control.
- [`UIDatePicker`](https://developer.apple.com/documentation/uikit/uidatepicker) и [`UIDatePicker.Style`](https://developer.apple.com/documentation/uikit/uidatepicker/style) — `.compact`, `.inline`, `.wheels` (iOS 14+).
- [`UIMenu`](https://developer.apple.com/documentation/uikit/uimenu) и [`UIAction`](https://developer.apple.com/documentation/uikit/uiaction) — inline picker через меню.
- [`UITableView.automaticDimension`](https://developer.apple.com/documentation/uikit/uitableview/automaticdimension) — авто-высота ячейки по Auto Layout.

→ [Глава 28. Cookbook: модалки и листы](./45-cookbook-modals.md)
