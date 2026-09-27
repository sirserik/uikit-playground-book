# Глава 27. Cookbook — типы ячеек

Экран настроек, профиль, форма заказа — всё это таблица из ячеек
разных видов: с переключателем, со степпером, со слайдером, с выбором
даты, с полем ввода. Эта глава — каталог таких ячеек: как сделать
каждую и где у каждой прячутся ошибки.

> **В каком режиме код.** Листинги проверены компилятором в режиме
> Swift 6 с Default Actor Isolation = MainActor (подробнее — в начале
> главы 25). Короткие фрагменты вида `var content = ...` живут внутри
> `tableView(_:cellForRowAt:)`: там уже есть `cell` и `indexPath`.

Два понятия, на которых держится вся глава.

**Ячейка** (cell) — одна строка таблицы, объект `UITableViewCell`. Всё
содержимое ячейки лежит в её `contentView`, а справа может стоять
**аксессуар** (accessory) — стрелка, галочка или любая твоя view
(переключатель, кнопка).

**Переиспользование** (reuse). Таблица не создаёт по ячейке на каждую
строку данных. Ячеек примерно столько, сколько помещается на экране,
плюс пара запасных. Строка уехала за верхний край — её ячейка
отправляется в очередь, и таблица тут же берёт её для строки,
появляющейся снизу. Это как гардероб с десятью номерками на сотню
посетителей: номерок сдали — его тут же выдали новому гостю. Отсюда
главное правило: в `cellForRowAt` **каждое** свойство ячейки, которое
зависит от данных, надо выставлять заново, иначе ячейка покажет
остатки прошлой строки. Подробно — глава 12.

## 27.1 Default content configuration

**Когда применять.** Стандартная ячейка: текст, подпись, иконка,
стрелка справа. Самая частая.

```swift
var content = cell.defaultContentConfiguration()
content.text = "Уведомления"
content.secondaryText = "Включены"
content.image = UIImage(systemName: "bell.fill")
content.imageProperties.tintColor = .systemRed
content.imageProperties.maximumSize = CGSize(width: 28, height: 28)
content.textProperties.font = .preferredFont(forTextStyle: .body)
content.secondaryTextProperties.color = .secondaryLabel
content.prefersSideBySideTextAndSecondaryText = true
cell.contentConfiguration = content
cell.accessoryType = .disclosureIndicator
```

**Content configuration** (конфигурация содержимого, iOS 14+) — это
**описание** того, что должно быть в ячейке, а не сами метки и
картинки. Ты заполняешь структуру — текст, подпись, картинку, их
цвета и шрифты, — отдаёшь её ячейке, и ячейка сама создаёт и
раскладывает нужные view.

Разберём по строкам.

- `defaultContentConfiguration()` — заготовка, уже подходящая под
  стиль таблицы (отступы, шрифты по умолчанию).
- `var content` — это **структура**, то есть значение, а не ссылка.
  Изменения в `content` ничего не меняют на экране, пока ты не
  присвоишь её обратно: `cell.contentConfiguration = content`. Забыть
  эту строку — частая ошибка «я поменял текст, а он не поменялся».
- `imageProperties.maximumSize` — картинка не больше 28 × 28 точек.
  Без ограничения большая картинка раздует ячейку.
- `textProperties.font` — шрифт основного текста. Стиль `.body` —
  стиль **Dynamic Type**: он растёт вместе с системным размером текста,
  который человек выбирает в настройках.
- `prefersSideBySideTextAndSecondaryText = true` — основной текст
  слева, подпись справа, в одну строку, как в «Настройках». По
  умолчанию (`false`) подпись стоит **под** текстом. Если при крупном
  шрифте в строку не помещается, ячейка сама переставит подпись вниз.
- `accessoryType = .disclosureIndicator` — серая стрелка «›» справа:
  «тап откроет новый экран». Другие стандартные варианты:
  `.checkmark` (галочка), `.detailButton` (кнопка «i»), `.none`.

Этот API заменил старые свойства `cell.textLabel`,
`cell.detailTextLabel` и `cell.imageView`. В документации они помечены
«будут объявлены устаревшими». Смешивать старое и новое нельзя:
конфигурация перерисует ячейку и затрёт то, что ты написал в
`textLabel`.

Есть и готовые варианты конфигурации для типовых ячеек:
`UIListContentConfiguration.valueCell()` — текст слева, значение
справа; `.subtitleCell()` — подпись под текстом. Их используют,
когда ячейку создают без `defaultContentConfiguration()`.

**Частые ошибки.**

- **Изменили `content`, но не присвоили** его обратно в
  `cell.contentConfiguration`.
- **`cell.textLabel?.text = ...` вместе с конфигурацией** — одно
  перетирает другое.
- **Жёсткий размер шрифта** (`systemFont(ofSize: 16)`) — ячейка не
  реагирует на Dynamic Type.

## 27.2 Switch cell

**Когда применять.** Настройка «вкл/выкл»: уведомления, тёмная тема,
автозагрузка.

```swift
var content = cell.defaultContentConfiguration()
content.text = "Уведомления"
cell.contentConfiguration = content

let toggle = UISwitch()
toggle.isOn = notificationsEnabled
toggle.addAction(UIAction { [weak self] action in
    guard let toggle = action.sender as? UISwitch else { return }
    self?.setNotificationsEnabled(toggle.isOn)
}, for: .valueChanged)
cell.accessoryView = toggle
cell.selectionStyle = .none
```

`accessoryView` — своя view на месте аксессуара. `UISwitch` при
создании сразу получает свой стандартный размер, поэтому его можно
класть в аксессуар без настройки рамки.

`UIAction` — действие-замыкание, которое контрол вызовет при событии
`.valueChanged` (переключатель сменил положение).

Самая важная строка — `action.sender as? UISwitch`. Кажется, проще
написать `self?.setNotificationsEnabled(toggle.isOn)`, обратившись к
`toggle` напрямую. Но тогда получится **цикл удержания** (retain
cycle): переключатель держит своё действие, действие держит замыкание,
а замыкание держит переключатель. Три объекта держат друг друга по
кругу и никогда не освободятся. На каждую перерисовку строки в памяти
будет оставаться по «мёртвому» переключателю. `action.sender` — это
тот контрол, который вызвал действие, и через него мы получаем
переключатель без сильной ссылки.

`[weak self]` — по той же причине, но для экрана: экран держит
таблицу, таблица — ячейку, ячейка — переключатель, и дальше по цепочке
до замыкания.

`selectionStyle = .none` — тап по самой строке ничего не делает
(переключается только переключатель), поэтому строка не должна
подсвечиваться при нажатии. Подробный пример экрана настроек с
переключателями — глава 19 (Profile).

**Частые ошибки.**

- **Замыкание захватывает сам контрол** — цикл удержания. Бери контрол
  из `action.sender`.
- **Состояние переключателя не из данных.** `toggle.isOn` надо
  выставлять в `cellForRowAt` каждый раз из модели. Иначе при прокрутке
  переключатель «перепрыгнет» в чужое положение.

## 27.3 Stepper cell

**Когда применять.** Небольшое целое число: количество, уровень,
число повторов. **Степпер** (`UIStepper`) — пара кнопок «−» и «+».

```swift
var content = cell.defaultContentConfiguration()
content.text = "Уровень"
content.secondaryText = "\(level)"
content.prefersSideBySideTextAndSecondaryText = true
cell.contentConfiguration = content

let stepper = UIStepper()
stepper.minimumValue = 0
stepper.maximumValue = 10
stepper.value = Double(level)
stepper.addAction(UIAction { [weak self, weak cell] action in
    guard let stepper = action.sender as? UIStepper, let cell else { return }
    let newLevel = Int(stepper.value)
    self?.level = newLevel
    var updated = content
    updated.secondaryText = "\(newLevel)"
    cell.contentConfiguration = updated
}, for: .valueChanged)
cell.accessoryView = stepper
cell.selectionStyle = .none
```

`value` у степпера — `Double`, поэтому на входе `Double(level)`, а на
выходе `Int(stepper.value)`. Степпер шагает по 1 (`stepValue`), от 0
до 10 включительно.

Число справа («5») надо обновить при каждом нажатии. Первое, что
приходит в голову, — перезагрузить строку (`reloadRows`). Но
перезагрузка создаст **новый** степпер, а старый, под пальцем, уйдёт
с экрана. Если человек зажал «+», чтобы число бежало само, это
автоповторение оборвётся. Поэтому обновляем только текст: копируем
конфигурацию (`var updated = content`), меняем подпись и присваиваем
ячейке.

`[weak cell]` — замыкание не должно удерживать ячейку: ячейка держит
степпер, степпер держит замыкание — снова круг.

## 27.4 Slider cell (полный label + slider)

**Когда применять.** Значение из непрерывного диапазона: размер
шрифта, громкость, яркость. Слайдер занимает всю ширину, и в
аксессуар он не помещается — нужна своя раскладка внутри ячейки.

Для такой ячейки правильнее завести свой класс:

```swift
final class SliderCell: UITableViewCell {
    static let reuseID = "SliderCell"
    var onChange: ((Float) -> Void)?

    private let titleLabel = UILabel()
    private let slider = UISlider()
    private var title = ""

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        titleLabel.font = .preferredFont(forTextStyle: .body)
        titleLabel.adjustsFontForContentSizeCategory = true

        slider.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.updateLabel()
            self.onChange?(self.slider.value)
        }, for: .valueChanged)

        let stack = UIStackView(arrangedSubviews: [titleLabel, slider])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        let margins = contentView.layoutMarginsGuide
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: margins.topAnchor),
            stack.bottomAnchor.constraint(equalTo: margins.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) не используется") }

    func configure(title: String, value: Float, range: ClosedRange<Float>) {
        self.title = title
        slider.minimumValue = range.lowerBound
        slider.maximumValue = range.upperBound
        slider.value = value
        updateLabel()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onChange = nil
    }

    private func updateLabel() {
        titleLabel.text = "\(title): \(Int(slider.value.rounded())) pt"
    }
}
```

Разбор:

- Слайдер и метка создаются **один раз**, в `init`. При
  переиспользовании ячейка приходит уже с ними, и `configure` только
  выставляет значения. Ничего не добавляется повторно.
- Стек прибит к `layoutMarginsGuide` — к **внутренним полям** ячейки.
  Это те же отступы, что у текста в стандартных ячейках (обычно 16–20
  точек по бокам), поэтому слайдер ровно выстраивается с соседними
  строками.
- `slider.value` — `Float`. Метка показывает округлённое значение:
  при `value = 17.46` будет «Размер шрифта: 17 pt», при `17.5` —
  «18 pt» (`rounded()` округляет половину вверх). Без округления на
  экране мелькало бы «17.462963».
- `onChange` — замыкание, через которое ячейка сообщает экрану новое
  значение. Экран задаёт его в `cellForRowAt`.
- `prepareForReuse()` — UIKit вызывает этот метод, когда ячейку
  забирают под новую строку. Мы обнуляем `onChange`, чтобы старое
  замыкание (от прошлой строки) не сработало на новой.
- В замыкании слайдера `[weak self]`: ячейка держит слайдер, слайдер —
  замыкание, и сильный `self` замкнул бы круг.

Использование в `cellForRowAt`:

```swift
let cell = tableView.dequeueReusableCell(withIdentifier: SliderCell.reuseID,
                                         for: indexPath) as! SliderCell
cell.configure(title: "Размер шрифта", value: fontSize, range: 12...28)
cell.onChange = { [weak self] value in
    self?.fontSize = value
}
return cell
```

`as! SliderCell` — принудительное приведение типа. Здесь оно
оправдано: если ячейка под этим идентификатором не `SliderCell`, это
ошибка программиста, и лучше упасть сразу при разработке. Класс
регистрируется один раз в `viewDidLoad`:
`tableView.register(SliderCell.self, forCellReuseIdentifier: SliderCell.reuseID)`.

Встречается и более короткий способ: в `cellForRowAt` обнулить
`contentConfiguration`, удалить из `contentView` все старые subviews и
добавить новые. Он работает, но на каждую прокрутку создаёт и удаляет
view, и легко забыть удаление — тогда при переиспользовании в ячейке
окажется два слайдера друг на друге. Свой класс надёжнее.

**Частые ошибки.**

- **Замыкание слайдера захватывает слайдер** — цикл удержания (см. 27.2).
- **Добавление subviews в `cellForRowAt` без удаления** — наложение
  view при переиспользовании.
- **Не обнулили колбэк в `prepareForReuse`** — изменение слайдера в
  строке 5 записывается в данные строки 1.

**Упражнение 27.1.** Найди проблему в этом коде и исправь её:

```swift
let slider = UISlider()
slider.addAction(UIAction { _ in
    print(slider.value)
}, for: .valueChanged)
cell.accessoryView = slider
```

## 27.5 Inline picker (UIMenu)

**Когда применять.** Выбор из нескольких вариантов прямо в строке:
тема оформления, язык, единицы измерения.

```swift
var content = cell.defaultContentConfiguration()
content.text = "Тема"
cell.contentConfiguration = content

let actions = themes.map { theme in
    UIAction(title: theme,
             state: theme == currentTheme ? .on : .off) { [weak self] _ in
        self?.setTheme(theme)
    }
}
var config = UIButton.Configuration.plain()
config.contentInsets = .zero
let button = UIButton(configuration: config)
button.menu = UIMenu(children: actions)
button.showsMenuAsPrimaryAction = true
button.changesSelectionAsPrimaryAction = true
button.sizeToFit()
cell.accessoryView = button
cell.selectionStyle = .none
```

Тап по кнопке открывает меню со всеми вариантами, текущий отмечен
галочкой.

- `UIAction(title:state:)` — пункт меню. `.on` у текущей темы рисует
  галочку.
- `showsMenuAsPrimaryAction = true` — меню по обычному тапу, а не по
  долгому нажатию.
- `changesSelectionAsPrimaryAction = true` (iOS 15+) превращает кнопку
  во **всплывающую кнопку выбора** (pop-up button): она сама
  показывает заголовок выбранного пункта со значком «⌃⌄» и сама
  переносит галочку при выборе. Поэтому подпись `secondaryText` в
  ячейке не нужна — значение видно на кнопке.
- `sizeToFit()` — обязательно. `accessoryView` использует тот размер,
  который у view уже есть, а кнопка, созданная в коде, имеет нулевой
  размер. Без этой строки кнопка будет невидимой.

**Частые ошибки.**

- **Кнопка в аксессуаре без размера** — ячейка выглядит пустой, хотя
  код «точно добавил кнопку».
- **Галочка не переезжает.** Если собрать меню без
  `changesSelectionAsPrimaryAction` (или без опции `.singleSelection`,
  см. 25.6), состояние `state` зафиксировано в момент создания меню.
  После выбора меню надо пересобрать или перезагрузить строку.

## 27.6 Disclosure value cell

**Когда применять.** Строка, которая ведёт на другой экран и
показывает текущее значение: «Язык › Русский», «О приложении ›
1.0.3».

```swift
let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
var content = cell.defaultContentConfiguration()
content.text = "О приложении"
content.secondaryText = version
content.prefersSideBySideTextAndSecondaryText = true
cell.contentConfiguration = content
cell.accessoryType = .disclosureIndicator
```

`CFBundleShortVersionString` — номер версии из настроек проекта
(Marketing Version), то самое «1.0.3», которое видно в App Store.
Берём его из `Info.plist` приложения, а не пишем руками, иначе после
обновления в ячейке останется старый номер. Если ключа нет, покажем
тире.

Стрелка `.disclosureIndicator` обещает «тап откроет экран». Не ставь
её на строки, которые ничего не открывают: человек будет тапать и
удивляться.

## 27.7 Multi-line cell

**Когда применять.** Текст, который не помещается в одну строку:
описание, адрес, отзыв.

```swift
var content = cell.defaultContentConfiguration()
content.text = "Доставка"
content.textProperties.numberOfLines = 0
content.secondaryText = "Курьер привезёт заказ завтра с 10:00 до 14:00. Перед приездом позвонит."
content.secondaryTextProperties.numberOfLines = 0
cell.contentConfiguration = content
```

`numberOfLines = 0` — «сколько угодно строк». По умолчанию у текста
конфигурации тоже `0`, но явная строка защищает от сюрприза, если
кто-то в другом месте ограничил число строк.

Высоту ячейки таблица вычислит сама: с iOS 11 у `UITableView` по
умолчанию `rowHeight = UITableView.automaticDimension` — «высота по
содержимому». Если высота всё равно не растёт, проверь, не задал ли
кто-то `tableView.rowHeight = 44` или метод `heightForRowAt` с
фиксированным числом.

## 27.8 Segmented cell

**Когда применять.** Выбор из 2–4 коротких вариантов, которые
хочется видеть сразу: «День / Неделя / Месяц».

**Сегментированный контрол** (`UISegmentedControl`) — ряд
кнопок-сегментов, из которых выбран ровно один.

```swift
final class SegmentedCell: UITableViewCell {
    static let reuseID = "SegmentedCell"
    var onChange: ((Int) -> Void)?
    private let segmented = UISegmentedControl()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        segmented.addAction(UIAction { [weak self] action in
            guard let control = action.sender as? UISegmentedControl else { return }
            self?.onChange?(control.selectedSegmentIndex)
        }, for: .valueChanged)
        segmented.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(segmented)
        let margins = contentView.layoutMarginsGuide
        NSLayoutConstraint.activate([
            segmented.topAnchor.constraint(equalTo: margins.topAnchor),
            segmented.bottomAnchor.constraint(equalTo: margins.bottomAnchor),
            segmented.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            segmented.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) не используется") }

    func configure(items: [String], selected: Int) {
        segmented.removeAllSegments()
        for (index, title) in items.enumerated() {
            segmented.insertSegment(withTitle: title, at: index, animated: false)
        }
        segmented.selectedSegmentIndex = selected
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onChange = nil
    }
}
```

Та же схема, что у слайдера: контрол создаётся один раз, `configure`
заново выставляет сегменты и выбранный индекс, `prepareForReuse`
отвязывает колбэк. `removeAllSegments()` перед вставкой нужен, чтобы
переиспользованная ячейка не набрала сегменты от прошлой строки
плюс новые.

Сегменты делят ширину поровну: на iPhone шириной 393 точки с полями
по 20 точек на три сегмента приходится (393 − 40) / 3 ≈ 117 точек
каждому. «Неделя» помещается, «За последние 30 дней» — уже нет.
Больше четырёх сегментов или длинные подписи — повод взять меню
(27.5).

## 27.9 Picker cell (full width)

**Когда применять.** Выбор даты и времени в строке настроек или
формы.

```swift
var content = cell.defaultContentConfiguration()
content.text = "Напомнить"
cell.contentConfiguration = content

let datePicker = UIDatePicker()
datePicker.datePickerMode = .dateAndTime
datePicker.preferredDatePickerStyle = .compact
datePicker.date = reminderDate
datePicker.addAction(UIAction { [weak self] action in
    guard let picker = action.sender as? UIDatePicker else { return }
    self?.reminderDate = picker.date
}, for: .valueChanged)
datePicker.sizeToFit()
cell.accessoryView = datePicker
cell.selectionStyle = .none
```

`UIDatePicker` умеет выглядеть по-разному, стиль задаёт
`preferredDatePickerStyle` (iOS 13.4+):

- `.compact` (iOS 14+) — маленькие «таблетки» с датой и временем прямо
  в строке. Тап по таблетке открывает поверх экрана календарь или
  выбор времени. Лучший вариант для строки таблицы.
- `.inline` (iOS 14+) — полный календарь прямо на экране, занимает
  много места по высоте. Хорош, когда выбор даты — главное на экране.
- `.wheels` — классические «барабаны», которые крутят пальцем. Они
  тоже стоят прямо на экране (это не отдельное окно), около 200 точек
  в высоту.
- `.automatic` — стиль выбирает система.

`sizeToFit()` — подгоняем рамку под содержимое. Пикер, в отличие от
кнопки из 27.5, получает размер уже при создании (на iOS 26 компактный
пикер с датой и временем — около 196 × 36 точек), но после смены
режима и стиля рамку надёжнее пересчитать: аксессуар берёт тот размер,
который у view есть в момент присваивания.

## 27.10 Inline editing cell

**Когда применять.** Короткое поле ввода прямо в строке: имя,
никнейм, название — без отдельного экрана редактирования.

```swift
final class TextFieldCell: UITableViewCell {
    static let reuseID = "TextFieldCell"
    var onChange: ((String) -> Void)?

    private let titleLabel = UILabel()
    private let textField = UITextField()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        titleLabel.font = .preferredFont(forTextStyle: .body)
        textField.font = .preferredFont(forTextStyle: .body)
        textField.textAlignment = .right
        textField.clearButtonMode = .whileEditing
        textField.addAction(UIAction { [weak self] action in
            guard let field = action.sender as? UITextField else { return }
            self?.onChange?(field.text ?? "")
        }, for: .editingChanged)

        titleLabel.setContentHuggingPriority(.required, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        textField.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let stack = UIStackView(arrangedSubviews: [titleLabel, textField])
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        let margins = contentView.layoutMarginsGuide
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: margins.topAnchor),
            stack.bottomAnchor.constraint(equalTo: margins.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) не используется") }

    func configure(title: String, text: String, placeholder: String) {
        titleLabel.text = title
        textField.text = text
        textField.placeholder = placeholder
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onChange = nil
    }
}
```

Метка слева, поле справа тянется до края. Тут работают два правила
Auto Layout, которые часто путают.

**Intrinsic content size** («собственный размер») — размер, который
view хочет иметь сама: метка «Имя» — ширину своего текста, кнопка —
ширину заголовка с полями. Когда в стеке места больше или меньше, чем
сумма собственных размеров, Auto Layout решает, кого растянуть, а кого
сжать. Для этого у каждой view две настройки:

- **Content hugging** («обнимание») — насколько view **не хочет
  растягиваться** больше собственного размера. Высокий приоритет:
  «обниму свой текст и не вырасту». Низкий: «могу растянуться».
- **Compression resistance** («сопротивление сжатию») — насколько view
  **не хочет сжиматься** меньше собственного размера. Высокий
  приоритет: «не обрежьте мне текст».

Приоритеты — числа от 1 до 1000: `.defaultLow` = 250, `.defaultHigh`
= 750, `.required` = 1000.

В нашей ячейке ширина 353 точки (393 минус поля по 20). Метка «Имя»
хочет, скажем, 40 точек, между ней и полем 16. Остаётся 297 точек, и
Auto Layout решает, кому их отдать. У метки hugging 1000, у поля 250 —
растягивается поле. А если поле с длинным текстом начнёт «давить», у
метки compression resistance 1000 — она не сожмётся до «Им…».

Одно только hugging защищает от растягивания, но не от сжатия. Для «не сжимаемой» метки нужна именно
compression resistance.

`textAlignment = .right` — текст в поле прижат к правому краю, как
значения в «Настройках». `clearButtonMode = .whileEditing` — крестик
«очистить» появляется во время ввода.

**Частые ошибки.**

- **Перепутали hugging и compression resistance** — метка обрезается
  при длинном вводе.
- **Данные не сохраняются при прокрутке.** Если не записывать текст в
  модель на каждое изменение (`.editingChanged`), то после прокрутки
  переиспользованная ячейка покажет старое значение из модели.

**Упражнение 27.2.** В ячейке `TextFieldCell` поменяй приоритеты
местами: метке — hugging `.defaultLow`, полю — `.required`. Что
изменится на экране? Опиши словами, без запуска.

## 27.11 Variable-height cells

**Когда применять.** Ячейки разной высоты: отзывы, сообщения, заметки.

```swift
override func viewDidLoad() {
    super.viewDidLoad()
    tableView.rowHeight = UITableView.automaticDimension
    tableView.estimatedRowHeight = 80
}
```

`rowHeight = automaticDimension` — высоту каждой ячейки вычисляет
Auto Layout по её содержимому. С iOS 11 это значение по умолчанию,
строка здесь для ясности. Чтобы расчёт сработал, содержимое ячейки
должно быть прибито к `contentView` сверху и снизу непрерывной
цепочкой ограничений (как стеки выше).

`estimatedRowHeight` — **прикидка** высоты строки. Таблица не меряет
все ячейки заранее — это дорого. Она меряет только видимые, а для
остальных берёт прикидку, чтобы вычислить общую высоту списка и
размер полосы прокрутки. На числах: 1000 строк × 80 = 80 000 точек
предполагаемой высоты. Если реальные ячейки в среднем по 200 точек,
прикидка ошибается в 2,5 раза: полоса прокрутки будет «прыгать», а
список — дёргаться при быстрой прокрутке. Ставь прикидку близко к
средней реальной высоте.

## 27.12 Cell selection style

```swift
cell.selectionStyle = .none     // не подсвечивать при нажатии
cell.selectionStyle = .default  // системная подсветка (серая)
```

Для строк с переключателем, слайдером, полем ввода — `.none`: тап по
строке ничего не делает. Для строк, которые открывают экран или
выполняют действие, — `.default`.

В перечислении есть ещё `.blue` и `.gray`. Они не устарели формально,
но `.blue` давно не синий — даёт обычную системную подсветку. На
практике используют `.default` и `.none`.

Подсветка после тапа должна гаснуть. Если ты открываешь экран из
`didSelectRowAt`, сними выделение сам:

```swift
override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    openDetails(for: indexPath)
}
```

У `UITableViewController` это частично происходит само
(`clearsSelectionOnViewWillAppear`) при возврате назад, но у обычного
`UIViewController` с таблицей строка останется серой.

Свой цвет подсветки:

```swift
let background = UIView()
background.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
cell.selectedBackgroundView = background
```

`selectedBackgroundView` — view, которая подкладывается под
содержимое, пока ячейка выделена. `withAlphaComponent(0.1)` — синий на
10% непрозрачности: лёгкий голубой оттенок, через который виден текст.

## 27.13 Avatar в ячейке

**Когда применять.** Список людей: контакты, участники чата,
комментарии.

```swift
var content = cell.defaultContentConfiguration()
content.text = user.name
content.secondaryText = user.email
content.image = avatarCache[user.id] ?? UIImage(systemName: "person.crop.circle.fill")
content.imageProperties.maximumSize = CGSize(width: 36, height: 36)
content.imageProperties.reservedLayoutSize = CGSize(width: 36, height: 36)
content.imageProperties.cornerRadius = 18
cell.contentConfiguration = content
```

- `cornerRadius = 18` при размере 36 — половина стороны, поэтому
  картинка обрезается в круг.
- `reservedLayoutSize` — место под картинку резервируется всегда,
  даже пока аватар грузится. Иначе текст в ячейке «прыгнет» вправо,
  когда картинка появится.
- Пока настоящего фото нет, показываем системный символ-заглушку.

Настоящие фото грузятся из сети, и здесь главная ловушка
переиспользования. Пока фото летит, человек прокрутил список, ячейку
отдали другому пользователю — и пришедшее фото Анны окажется в строке
Бориса. Надёжная схема: картинку кладём в кэш по идентификатору
пользователя, а ячейку не трогаем напрямую — просим таблицу заново
настроить строку, где этот пользователь сейчас:

```swift
func loadAvatarIfNeeded(for user: User) {
    guard avatarCache[user.id] == nil else { return }
    Task { [weak self] in
        guard let image = await AvatarLoader.image(for: user.avatarURL),
              let self else { return }
        avatarCache[user.id] = image
        if let row = users.firstIndex(where: { $0.id == user.id }) {
            tableView.reconfigureRows(at: [IndexPath(row: row, section: 0)])
        }
    }
}
```

`reconfigureRows(at:)` (iOS 15+) заново вызывает `cellForRowAt` для
видимой строки, не пересоздавая ячейку. `cellForRowAt` возьмёт фото из
`avatarCache`. Если строка уже не видна, ничего не произойдёт — фото
подхватится из кэша, когда строка снова появится.

Искать строку по `user.id` в момент прихода фото, а не запоминать
`indexPath` заранее, нужно потому, что за время загрузки список мог
измениться: строку удалили, добавили новую сверху.

**Частые ошибки.**

- **Фото кладут прямо в ячейку из замыкания загрузки** — фото
  оказывается у чужого пользователя.
- **`cell.imageView?.image = ...` при конфигурации** — конфигурация
  перетрёт картинку при ближайшем обновлении (см. 27.1).

## 27.14 Drag handles (editing mode)

**Когда применять.** Ручная сортировка: плейлист, порядок виджетов,
избранное.

```swift
override func viewDidLoad() {
    super.viewDidLoad()
    tableView.isEditing = true
}

override func tableView(_ tableView: UITableView,
                        canMoveRowAt indexPath: IndexPath) -> Bool { true }

override func tableView(_ tableView: UITableView,
                        moveRowAt source: IndexPath, to destination: IndexPath) {
    let item = items.remove(at: source.row)
    items.insert(item, at: destination.row)
}

override func tableView(_ tableView: UITableView,
                        editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
    .none
}

override func tableView(_ tableView: UITableView,
                        shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool { false }
```

`isEditing = true` включает **режим редактирования**: справа у строк
появляются «ручки» (≡), за которые строку можно перетащить.

- `canMoveRowAt` — какие строки можно двигать. Здесь все.
- `moveRowAt` — таблица уже переставила строку на экране, и ты
  обязан повторить перестановку в данных. Иначе при очередной
  перезагрузке строки вернутся на старые места.
- `editingStyleForRowAt` возвращает `.none` — без красного кружка
  «удалить» слева: только перестановка.
- `shouldIndentWhileEditingRowAt` — `false`, чтобы содержимое не
  сдвигалось вправо, освобождая место под кружок, которого нет.

Как `remove` + `insert` двигают элемент, на числах. Было `[A, B, C]`,
тянем A (строка 0) на место C (строка 2). `remove(at: 0)` даёт
`[B, C]`, `insert(A, at: 2)` — `[B, C, A]`. Именно это человек и видит
на экране.

## Ответы к упражнениям

**27.1.** Замыкание захватывает `slider` сильной ссылкой, а слайдер
держит своё действие — цикл удержания, слайдер никогда не освободится
(на симуляторе с iOS 26 это легко проверить слабой ссылкой: после
выхода из области видимости она так и остаётся не `nil`). Исправление
— взять слайдер из `action.sender` (а ещё лучше сделать ячейку своим
классом, как `SliderCell`):

```swift
let slider = UISlider()
slider.addAction(UIAction { action in
    guard let slider = action.sender as? UISlider else { return }
    print(slider.value)
}, for: .valueChanged)
cell.accessoryView = slider
```

**27.2.** Теперь метка готова растягиваться (hugging 250), а поле —
нет (hugging 1000). Всё свободное место отдаётся метке: «Имя» займёт
почти всю ширину, а поле ввода сожмётся до собственного размера —
ширины плейсхолдера или введённого текста — и прижмётся к правому
краю. Тапать в узкое поле неудобно, и при пустом плейсхолдере его
почти не видно.

## Что мы выучили

- **Переиспользование**: в `cellForRowAt` выставляй каждое зависящее
  от данных свойство заново; в своих классах ячеек отвязывай колбэки в
  `prepareForReuse`.
- **Content configuration** — описание содержимого (`text`,
  `secondaryText`, `image`, свойства); изменённую структуру
  присваивай обратно в `contentConfiguration`.
- **Контролы в аксессуаре** (`UISwitch`, `UIStepper`, `UIDatePicker`,
  кнопка): контрол бери из `action.sender`, иначе цикл удержания; view
  без собственного размера — `sizeToFit()`.
- **Слайдер, сегменты, поле ввода** — свой класс ячейки: view
  создаются один раз в `init`, `configure` только выставляет значения.
- **Меню выбора** — `changesSelectionAsPrimaryAction` (iOS 15+)
  делает кнопку, которая сама показывает выбранное.
- **Hugging** — «не растягиваться», **compression resistance** — «не
  сжиматься»; у метки рядом с полем нужны оба.
- **Высота по содержимому** — `automaticDimension` по умолчанию,
  `estimatedRowHeight` близко к средней реальной высоте.
- **Асинхронные аватары** — кэш по идентификатору и
  `reconfigureRows`, а не запись в ячейку из замыкания загрузки.
- **Перестановка строк** — `isEditing`, `moveRowAt` с обновлением
  данных, `.none` вместо кнопки удаления.

## Apple Developer Documentation

- [`UITableViewCell`](https://developer.apple.com/documentation/uikit/uitableviewcell) — базовая ячейка таблицы, `accessoryView`, `selectionStyle`, `prepareForReuse()`.
- [`UIListContentConfiguration`](https://developer.apple.com/documentation/uikit/uilistcontentconfiguration-swift.struct) — `defaultContentConfiguration()`, `valueCell()`, `subtitleCell()` (iOS 14+).
- [`UIListContentConfiguration.ImageProperties`](https://developer.apple.com/documentation/uikit/uilistcontentconfiguration-swift.struct/imageproperties-swift.struct) — `cornerRadius`, `maximumSize`, `reservedLayoutSize`, `tintColor`.
- [`UICollectionViewListCell`](https://developer.apple.com/documentation/uikit/uicollectionviewlistcell) — ячейка-строка для списков на основе collection view (iOS 14+).
- [`UISwitch`](https://developer.apple.com/documentation/uikit/uiswitch), [`UIStepper`](https://developer.apple.com/documentation/uikit/uistepper), [`UISlider`](https://developer.apple.com/documentation/uikit/uislider), [`UISegmentedControl`](https://developer.apple.com/documentation/uikit/uisegmentedcontrol) — контролы для ячеек настроек.
- [`UIDatePicker.Style`](https://developer.apple.com/documentation/uikit/uidatepickerstyle) — `.compact`, `.inline`, `.wheels`, `.automatic`.
- [`UIButton.changesSelectionAsPrimaryAction`](https://developer.apple.com/documentation/uikit/uibutton/changesselectionasprimaryaction) — всплывающая кнопка выбора (iOS 15+).
- [`UIView.setContentHuggingPriority(_:for:)`](https://developer.apple.com/documentation/uikit/uiview/setcontenthuggingpriority(_:for:)) и [`setContentCompressionResistancePriority(_:for:)`](https://developer.apple.com/documentation/uikit/uiview/setcontentcompressionresistancepriority(_:for:)) — кто растягивается, а кто не сжимается.
- [`UITableView.automaticDimension`](https://developer.apple.com/documentation/uikit/uitableview/automaticdimension) — высота ячейки по Auto Layout.
- [`UITableView.reconfigureRows(at:)`](https://developer.apple.com/documentation/uikit/uitableview/reconfigurerows(at:)) — перенастроить видимые строки без пересоздания ячеек (iOS 15+).

→ [Глава 28. Cookbook — модалки и листы](./45-cookbook-modals.md)
