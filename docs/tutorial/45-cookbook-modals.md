# Глава 28. Cookbook — модалки и листы

Всё, что показывается **поверх** текущего экрана: лист снизу, окно на
весь экран, поповер со стрелкой, системный алерт, собственное окно
подтверждения, баннер сверху, короткое «Сохранено» по центру. Эта
глава — каталог таких способов и ошибок, которые с ними случаются.

> **В каком режиме код.** Листинги проверены компилятором в режиме
> Swift 6 с Default Actor Isolation = MainActor и минимальной версией
> iOS 15 (подробнее — в начале главы 25). Поэтому всё, что появилось
> позже iOS 15, в коде обёрнуто в проверку `#available`.

**Модальный показ** (modal presentation) — открыть экран поверх
текущего так, что пока его не закроют, работать можно только с ним.
Показывает его метод `present(_:animated:)`, закрывает —
`dismiss(animated:)`. Тот, кто показал, называется **presenting**
(показывающий) экран, тот, кого показали, — **presented** (показанный).
Как именно модальный экран выглядит — лист, весь экран, поповер —
задаёт его `modalPresentationStyle`.

## 28.1 Bottom sheet с детентами

**Когда применять.** «Лёгкая» задача, после которой хочется вернуться
к тому, что было под ней: новая заметка, фильтр, выбор адреса.
**Лист** (sheet) выезжает снизу, под ним виден краешек предыдущего
экрана, а высоту листа можно менять, потянув за верхний край.

**Детент** (detent, дословно «фиксатор») — высота, на которой лист
может остановиться. Похоже на выдвижной ящик с защёлками: его можно
выдвинуть наполовину или до конца, и он «щёлкнет» в одном из этих
положений.

```swift
let editor = EditorViewController()
let nav = UINavigationController(rootViewController: editor)

if let sheet = nav.sheetPresentationController {
    sheet.detents = [.medium(), .large()]
    sheet.prefersGrabberVisible = true
    sheet.preferredCornerRadius = 24
}

present(nav, animated: true)
```

`sheetPresentationController` (iOS 15+) — объект, который управляет
листом. Он есть у экрана со стилем показа `.pageSheet` или `.formSheet`
— а это стиль по умолчанию на iPhone, поэтому ничего дополнительно
выставлять не нужно.

- `detents` — список допустимых высот. `[.medium(), .large()]` —
  примерно половина экрана и почти весь экран. `[.medium()]` — только
  половина. `.medium()` не работает в **компактной высоте** (iPhone
  повёрнут горизонтально): там лист сразу раскрывается полностью.
- `prefersGrabberVisible = true` — серая полоска-«ручка» сверху
  листа: подсказка, что его можно тянуть.
- `preferredCornerRadius` — радиус скругления верхних углов, 24
  точки. Без него — системное значение.
- Экран обёрнут в `UINavigationController`, чтобы у листа была
  навигационная панель с кнопками «Отмена» и «Готово».

Ещё одно свойство часто понимают неправильно:
`prefersScrollingExpandsWhenScrolledToEdge`. По умолчанию оно `true`.
Это значит: если в листе есть список, лист стоит на `.medium`, а
список прокручен к самому верху, то свайп вверх по списку сначала
**раскрывает лист** до `.large`, и только потом начинает прокручивать
список. Если лист должен оставаться на половине, а список —
прокручиваться (например, лист поверх карты), ставь `false`.

**Свои детенты (iOS 16+).** В iOS 15 есть только `.medium()` и
`.large()`. Произвольная высота появилась в iOS 16, и при минимальной
версии iOS 15 её нужно обернуть в проверку:

```swift
if #available(iOS 16.0, *) {
    let small = UISheetPresentationController.Detent.Identifier("small")
    sheet.detents = [
        .custom(identifier: small) { _ in 200 },
        .custom { context in context.maximumDetentValue * 0.7 },
        .large(),
    ]
    sheet.largestUndimmedDetentIdentifier = small
} else {
    sheet.detents = [.medium(), .large()]
}
```

`.custom { ... }` — детент, высоту которого считает замыкание.
Замыкание получает **контекст**, а в нём `maximumDetentValue` — самая
большая возможная высота листа на этом экране.

- `{ _ in 200 }` — лист высотой 200 точек. Эти 200 точек
  отсчитываются **внутри безопасной области**: по документации Apple,
  у листа, прижатого к низу экрана, к ним добавляется нижний отступ
  (на iPhone с полоской «домой» — 34 точки). Твоему содержимому при этом
  достанутся ровно 200. Итоговая высота на экране зависит от версии
  iOS: на симуляторе iPhone 16 с iOS 26, где лист «парит» с отступами
  от краёв экрана, он получился около 224 точек.
- `maximumDetentValue * 0.7` — 70% максимальной высоты. Если
  максимум 800 точек, лист остановится на 560.
- `identifier` — имя детента. Оно нужно, чтобы ссылаться на него из
  других свойств. Без имени UIKit придумает случайное.

`largestUndimmedDetentIdentifier = small` — «до высоты `small`
включительно фон не затемнять». Пока лист маленький, экран под ним
остаётся ярким и **нажимаемым** — как лист с маршрутом поверх карты.
Если лист поднять выше, фон затемнится.

`else` — на iOS 15 откатываемся к системным детентам. Без `#available`
проект с минимальной версией iOS 15 просто не соберётся: компилятор
знает, что `.custom` на iOS 15 нет.

Сменить высоту листа из кода — например, раскрыть его, когда человек
начал вводить текст, — можно с анимацией:

```swift
sheet.animateChanges {
    sheet.selectedDetentIdentifier = .large
}
```

`selectedDetentIdentifier` — текущая высота. `animateChanges`
проигрывает её смену плавно, а не рывком.

**Защита от случайного закрытия.** Лист закрывается свайпом вниз. Если
в нём несохранённый текст, это обидно. Запрети свайп и спроси:

```swift
final class NoteEditorViewController: UIViewController,
                                      UIAdaptivePresentationControllerDelegate {
    private var hasChanges = false {
        didSet { isModalInPresentation = hasChanges }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationController?.presentationController?.delegate = self
    }

    func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Удалить изменения", style: .destructive) { [weak self] _ in
            self?.dismiss(animated: true)
        })
        alert.addAction(UIAlertAction(title: "Продолжить редактирование", style: .cancel))
        alert.popoverPresentationController?.sourceView = view
        alert.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX, y: 0, width: 1, height: 1)
        present(alert, animated: true)
    }
}
```

`isModalInPresentation = true` — «этот экран нельзя закрыть свайпом».
Мы включаем его, только пока есть изменения (`didSet` у
`hasChanges`). Лист при попытке свайпа упруго вернётся на место, а
UIKit вызовет `presentationControllerDidAttemptToDismiss` — тут мы
спрашиваем, что делать.

Делегата назначаем у `navigationController?.presentationController`:
показан был не сам редактор, а контроллер навигации вокруг него.
Назначаем в `viewDidAppear` — к этому моменту экран уже внутри
показанного контроллера.

**Частые ошибки.**

- **`.custom` детенты без `#available`** — проект с iOS 15 не
  собирается.
- **Ждут `viewWillAppear` у экрана под листом.** Когда лист
  закрывается, экран под ним **не** получает `viewWillAppear` и
  `viewDidAppear`: он всё время оставался на экране, просто частично
  закрытый. Если после закрытия листа нужно обновить данные, сообщи
  об этом явно — делегатом или замыканием `onSave`.
- **Лист с несохранённым вводом закрывается свайпом** — нет
  `isModalInPresentation`.

## 28.2 Full-screen modal

**Когда применять.** Экран, который должен полностью отгородить
человека от остального приложения: вход в аккаунт, обязательное
обновление, просмотр фото.

```swift
let login = LoginViewController()
let nav = UINavigationController(rootViewController: login)
nav.modalPresentationStyle = .fullScreen
present(nav, animated: true)
```

`.fullScreen` — модальный экран занимает весь экран, а экран под ним
после окончания анимации **убирается** из иерархии view. Поэтому у
нижнего экрана вызываются `viewWillDisappear` и `viewDidDisappear`, а
при закрытии — `viewWillAppear` и `viewDidAppear`. Свайпом вниз такой
экран не закрывается: нужна кнопка.

`.overFullScreen` — тоже на весь экран, но нижний экран **остаётся** в
иерархии, под модальным. Если у модального экрана прозрачный или
полупрозрачный фон, нижний будет виден сквозь него. Методы
`viewWillDisappear` у нижнего экрана при этом не вызываются. Этот стиль
нужен для затемнений и своих окон подтверждения (28.9).

Сравнение трёх стилей:

| Стиль             | Нижний экран                  | `viewWillDisappear` нижнего | Свайп вниз |
|-------------------|-------------------------------|-----------------------------|------------|
| `.pageSheet`      | виден краешком сверху          | нет                         | закрывает  |
| `.fullScreen`     | убран из иерархии              | да                          | нет        |
| `.overFullScreen` | под модальным, виден сквозь фон | нет                         | нет        |

## 28.3 Page sheet (стиль по умолчанию)

```swift
vc.modalPresentationStyle = .pageSheet
```

С iOS 13 модальные экраны по умолчанию показываются не на весь экран,
а **листом**: новый экран выезжает снизу, нижний слегка уменьшается и
виден полоской сверху, закрыть можно свайпом вниз. Стиль по умолчанию
— `.automatic`: система сама выбирает лист. В новых версиях iOS
свойство у такого экрана может вернуть `.formSheet`, а не
`.pageSheet`, — на iPhone они выглядят одинаково (см. 28.4).

`.pageSheet` — это тот же лист, что в 28.1. Детенты — просто его
настройки: без них лист раскрыт на `.large`.

## 28.4 Form sheet (iPad)

```swift
vc.modalPresentationStyle = .formSheet
vc.preferredContentSize = CGSize(width: 540, height: 620)
```

На iPad `.formSheet` — окно по центру экрана поверх затемнённого фона,
как диалог настроек. На iPhone разницы с `.pageSheet` нет: окну некуда
«встать по центру», и оно показывается обычным листом.

`preferredContentSize` — желаемый размер окна, 540 × 620 точек. iPad
учитывает его для `.formSheet`, а iPhone игнорирует.

## 28.5 Popover

**Когда применять.** Небольшое окошко рядом с конкретной кнопкой:
выбор цвета, короткие настройки. **Поповер** (popover) — «облачко» со
стрелкой, указывающей на кнопку, из которой оно выросло. Это типичный
элемент iPad.

```swift
let picker = ColorPickerViewController()
picker.modalPresentationStyle = .popover
picker.preferredContentSize = CGSize(width: 280, height: 320)

if let popover = picker.popoverPresentationController {
    popover.sourceView = colorButton
    popover.sourceRect = colorButton.bounds
    popover.permittedArrowDirections = [.up, .down]
}

present(picker, animated: true)
```

- `sourceView` и `sourceRect` — откуда растёт стрелка: view и
  прямоугольник в её координатах. `colorButton.bounds` — вся кнопка.
- `permittedArrowDirections` — куда может смотреть стрелка. `[.up,
  .down]` — поповер встанет под кнопкой или над ней, но не сбоку.
- `preferredContentSize` — размер облачка, 280 × 320 точек.

На iPhone экран узкий, и поповер по умолчанию **адаптируется**:
показывается не облачком, а модальным листом. Это нормальное
поведение, и часто оно лучше облачка. С iOS 15 этот лист можно
настроить, например дать ему половинную высоту:

```swift
if let popover = picker.popoverPresentationController {
    let sheet = popover.adaptiveSheetPresentationController
    sheet.detents = [.medium()]
    sheet.prefersGrabberVisible = true
}
```

`adaptiveSheetPresentationController` — тот лист, в который поповер
превратится на iPhone. На iPad эти настройки ни на что не влияют.

Если нужно **настоящее** облачко и на iPhone, запрети адаптацию через
делегата:

```swift
extension PaletteViewController: UIPopoverPresentationControllerDelegate {
    func adaptivePresentationStyle(for controller: UIPresentationController,
                                   traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        .none   // не адаптировать: остаться поповером
    }
}

// при показе:
// picker.popoverPresentationController?.delegate = self
```

`adaptivePresentationStyle` — UIKit спрашивает: «экран стал узким, во
что превратить поповер?». `.none` означает «ни во что, оставь как
есть». Делегат хранится слабой ссылкой, поэтому им обычно делают сам
показывающий экран.

**Частые ошибки.**

- **Нет `sourceView`** — на iPad показ поповера падает с ошибкой:
  UIKit не знает, куда направить стрелку.
- **Облачко на iPhone с большим содержимым.** Поповер 280 × 320 на
  экране шириной 393 — нормально, 380 × 600 — уже почти лист, только
  неудобный. Не запрещай адаптацию без нужды.

## 28.6 UIAlertController — alert

**Когда применять.** Подтверждение опасного действия, сообщение об
ошибке, выбор из двух-трёх вариантов. **Алерт** — системное окошко по
центру экрана, которое нельзя не заметить.

```swift
let alert = UIAlertController(
    title: "Удалить заметку?",
    message: "Это действие нельзя отменить.",
    preferredStyle: .alert
)
alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
alert.addAction(UIAlertAction(title: "Удалить", style: .destructive) { [weak self] _ in
    self?.deleteNote()
})
present(alert, animated: true)
```

Три стиля кнопки:

- `.cancel` — отмена. Выделяется системно и одна на алерт: вторую
  кнопку `.cancel` UIKit не примет и упадёт.
- `.destructive` — красная подпись: действие удаляет или необратимо
  меняет данные.
- `.default` — обычная кнопка.

Где окажется «Отмена», решает iOS. Когда кнопок две, они стоят рядом,
и отмена — **слева**. Когда кнопок три и больше, они выстраиваются
столбиком, и отмена — **внизу**. Порядок вызовов `addAction` на
положение отмены не влияет.

`[weak self]` в замыкании кнопки: алерт показан экраном, и сильная
ссылка удержала бы экран, пока жив алерт. Утечки здесь обычно нет
(алерт закроется), но привычка брать `weak` в замыканиях UIKit
избавляет от раздумий «а тут можно?».

Если одна из кнопок — ожидаемый ответ, выдели её:
`alert.preferredAction = someAction`. Её подпись станет жирной, и она
сработает по клавише Return на подключённой клавиатуре.

Формулировка по рекомендациям Apple (HIG): заголовок — короткий
вопрос о действии («Удалить заметку?»), кнопка — глагол этого
действия («Удалить»), а не «Да» и «ОК».

## 28.7 UIAlertController — action sheet

**Когда применять.** Выбор из нескольких действий над объектом:
«Поделиться», «Сохранить», «Удалить».

```swift
let sheet = UIAlertController(title: nil, message: "Что сделать с фото?",
                              preferredStyle: .actionSheet)
sheet.addAction(UIAlertAction(title: "Поделиться", style: .default))
sheet.addAction(UIAlertAction(title: "Сохранить", style: .default))
sheet.addAction(UIAlertAction(title: "Удалить", style: .destructive))
sheet.addAction(UIAlertAction(title: "Отмена", style: .cancel))

sheet.popoverPresentationController?.sourceView = moreButton
sheet.popoverPresentationController?.sourceRect = moreButton.bounds

present(sheet, animated: true)
```

На iPhone action sheet выезжает снизу, «Отмена» — отдельной кнопкой
в самом низу. На iPad он показывается **поповером** рядом с кнопкой,
а кнопки «Отмена» там нет вовсе: чтобы отменить, тапают мимо облачка.

Две строки с `popoverPresentationController` на iPad **обязательны**:
без источника показ action sheet падает. На iPhone это свойство
`nil`, и строки ничего не делают — так что пиши их всегда, даже если
пока тестируешь только на iPhone.

## 28.8 Alert с UITextField

**Когда применять.** Короткий ввод без отдельного экрана: название
папки, переименование.

```swift
let alert = UIAlertController(title: "Новая папка", message: nil, preferredStyle: .alert)
alert.addTextField { field in
    field.placeholder = "Название"
    field.autocapitalizationType = .sentences
    field.returnKeyType = .done
}

let create = UIAlertAction(title: "Создать", style: .default) { [weak self, weak alert] _ in
    let name = alert?.textFields?.first?.text ?? ""
    self?.createFolder(named: name)
}
create.isEnabled = false
alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
alert.addAction(create)
alert.preferredAction = create

alert.textFields?.first?.addAction(UIAction { [weak create] action in
    let text = (action.sender as? UITextField)?.text ?? ""
    create?.isEnabled = !text.trimmingCharacters(in: .whitespaces).isEmpty
}, for: .editingChanged)

present(alert, animated: true)
```

- `addTextField` добавляет поле в алерт. Замыкание настраивает его:
  плейсхолдер, заглавная первая буква (`.sentences`), кнопка «Готово»
  на клавиатуре.
- Доступ к полю — через `alert.textFields`. В замыкании кнопки
  `alert` захвачен **слабо** (`weak alert`): алерт держит кнопку,
  кнопка — замыкание, и сильный захват алерта замкнул бы круг.
- `create.isEnabled = false` — пока поле пустое, «Создать» неактивна.
  Действие на `.editingChanged` включает кнопку, как только в поле
  появился хотя бы один непробельный символ. Папку с именем из трёх
  пробелов создать не получится.

## 28.9 Custom alert (без UIAlertController)

**Когда применять.** Стандартный алерт не подходит: нужна картинка,
фирменные цвета, нестандартная раскладка.

Своё окно лучше делать **отдельным экраном**, показанным поверх
остальных, а не view, добавленной в текущий экран. Тогда оно закроет и
навигационную панель, и вкладки, и сработает из любого места:

```swift
final class ConfirmViewController: UIViewController {
    var onConfirm: (() -> Void)?
    private let card = UIView()

    init() {
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) не используется") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        view.accessibilityViewIsModal = true

        card.backgroundColor = .systemBackground
        card.layer.cornerRadius = 20
        card.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(card)

        let icon = UIImageView(image: UIImage(systemName: "gift.fill"))
        icon.tintColor = .systemPink
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 44)
        let label = UILabel()
        label.text = "Забрать бонус 500 ₸?"
        label.font = .preferredFont(forTextStyle: .headline)
        label.numberOfLines = 0
        label.textAlignment = .center
        let button = UIButton(configuration: .filled())
        button.setTitle("Забрать", for: .normal)
        button.addAction(UIAction { [weak self] _ in
            self?.dismiss(animated: true) { self?.onConfirm?() }
        }, for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [icon, label, button])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            card.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            card.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.8),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        card.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        UIView.animate(withDuration: 0.35, delay: 0,
                       usingSpringWithDamping: 0.7, initialSpringVelocity: 0) {
            self.card.transform = .identity
        }
    }
}
```

Показ: `present(ConfirmViewController(), animated: true)`.

Разбор:

- `.overFullScreen` — экран поверх всего, а нижний остаётся виден
  (28.2). Полупрозрачный чёрный фон (`alpha 0.4` — 40% черноты)
  затемняет его.
- `.crossDissolve` — появление «проявлением», без выезда снизу.
- Карточка по центру шириной 80% экрана: на iPhone шириной 393 точки
  это около 314 точек. Высоту карточке задаёт стек через отступы
  сверху и снизу.
- Анимация карточки: стартуем с 90% размера (`scaleX: 0.9`) и
  пружиной возвращаемся к 100%. `usingSpringWithDamping: 0.7` — «чуть
  перелетит 100% и вернётся»: карточка на мгновение станет немного
  больше и тут же сядет на место. Длительность 0,35 с.
- `onConfirm` вызывается **после** закрытия (в completion
  `dismiss`), чтобы новый экран, если действие его откроет, не
  столкнулся с ещё не закрытым окном.
- `accessibilityViewIsModal = true` — VoiceOver не «провалится» в
  элементы экрана под окном, а будет читать только его содержимое.

**Частые ошибки.**

- **Окно как view внутри текущего экрана.** Не закрывает
  навигационную панель и вкладки, а при повороте рамка затемнения,
  заданная через `view.bounds`, остаётся старого размера.
- **Нет способа закрыть**, кроме главной кнопки. Добавь «Не сейчас»
  или закрытие по тапу на затемнение.

## 28.10 In-app banner

**Когда применять.** Ненавязчивое сообщение сверху, которое не
блокирует работу: «Новое сообщение», «Загрузка завершена», «Нет
соединения».

```swift
extension UIViewController {
    func showBanner(_ text: String, duration: TimeInterval = 3) {
        guard let window = view.window else { return }

        let label = UILabel()
        label.text = text
        label.textColor = .white
        label.numberOfLines = 0
        label.font = .preferredFont(forTextStyle: .subheadline)

        let banner = UIView()
        banner.backgroundColor = .systemBlue
        banner.layer.cornerRadius = 14
        banner.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false
        banner.addSubview(label)
        window.addSubview(banner)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: banner.topAnchor, constant: 12),
            label.bottomAnchor.constraint(equalTo: banner.bottomAnchor, constant: -12),
            label.leadingAnchor.constraint(equalTo: banner.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: banner.trailingAnchor, constant: -16),
            banner.topAnchor.constraint(equalTo: window.safeAreaLayoutGuide.topAnchor, constant: 8),
            banner.leadingAnchor.constraint(equalTo: window.leadingAnchor, constant: 12),
            banner.trailingAnchor.constraint(equalTo: window.trailingAnchor, constant: -12),
        ])
        window.layoutIfNeeded()

        let hiddenOffset = -(banner.frame.maxY + 20)
        banner.transform = CGAffineTransform(translationX: 0, y: hiddenOffset)
        UIView.animate(withDuration: 0.4, delay: 0,
                       usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
            banner.transform = .identity
        }
        UIAccessibility.post(notification: .announcement, argument: text)

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            UIView.animate(withDuration: 0.3, animations: {
                banner.transform = CGAffineTransform(translationX: 0, y: hiddenOffset)
            }, completion: { _ in
                banner.removeFromSuperview()
            })
        }
    }
}
```

Баннер выезжает сверху, три секунды висит и уезжает обратно.

- Баннер добавляется в **окно** (`view.window`), а не в экран: так он
  окажется поверх навигационной панели и любых модальных экранов.
- Ограничения: баннер на 8 точек ниже **безопасной области** (safe
  area — часть экрана, не занятая «чёлкой», Dynamic Island и
  статус-баром), с полями по 12 точек слева и справа. Высота — по
  тексту: метка многострочная, и длинное сообщение сделает баннер
  выше.
- `window.layoutIfNeeded()` — просим Auto Layout посчитать рамки
  **сейчас**, чтобы узнать, где баннер окажется.
- `hiddenOffset` — насколько сдвинуть баннер вверх, чтобы он целиком
  ушёл за экран. На числах: безопасная область на iPhone 16 начинается
  примерно на 59 точках, плюс 8 — баннер начинается на 67; при высоте
  42 (однострочный текст, замерено на симуляторе) его нижний край —
  109. Сдвиг на −(109 + 20) = −129 точек уводит его с запасом за верх
  экрана. Число 100 «на глаз», как часто пишут,
  оставило бы нижний край баннера видимым.
- Пружина с гашением 0,8 — баннер выезжает с едва заметным
  «доводом», без раскачки.
- `UIAccessibility.post(notification: .announcement, ...)` — VoiceOver
  прочитает текст баннера вслух. Без этого незрячий человек о нём не
  узнает.
- `DispatchQueue.main.asyncAfter` — через `duration` секунд запустить
  исчезновение. Замыкание держит `banner` до конца анимации, а после
  `removeFromSuperview()` баннер освобождается.

**Частые ошибки.**

- **Сдвиг «на −100»** — баннер не прячется целиком на телефонах с
  высоким статус-баром.
- **Баннеры наслаиваются.** Если показать три подряд, они лягут друг на
  друга. Для частых сообщений заведи очередь: новый баннер — после
  ухода предыдущего.

## 28.11 HUD — Heads-Up Display

**Когда применять.** Короткое подтверждение: «Сохранено»,
«Скопировано». **HUD** — блок с иконкой и текстом по центру экрана,
который сам исчезает через секунду-две. Название пришло из авиации:
так называют данные, выведенные прямо на стекло перед пилотом.

```swift
extension UIViewController {
    func showHUD(_ text: String, symbol: String = "checkmark.circle.fill") {
        let hud = UIView()
        hud.backgroundColor = UIColor.black.withAlphaComponent(0.85)
        hud.layer.cornerRadius = 18
        hud.translatesAutoresizingMaskIntoConstraints = false

        let icon = UIImageView(image: UIImage(systemName: symbol))
        icon.tintColor = .systemGreen
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 40)
        let label = UILabel()
        label.text = text
        label.textColor = .white
        label.font = .preferredFont(forTextStyle: .headline)

        let stack = UIStackView(arrangedSubviews: [icon, label])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        hud.addSubview(stack)
        view.addSubview(hud)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: hud.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: hud.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: hud.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: hud.trailingAnchor, constant: -32),
            hud.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hud.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])

        hud.alpha = 0
        UIView.animate(withDuration: 0.2) { hud.alpha = 1 }
        UIAccessibility.post(notification: .announcement, argument: text)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            UIView.animate(withDuration: 0.3, animations: { hud.alpha = 0 }) { _ in
                hud.removeFromSuperview()
            }
        }
    }
}
```

Хронология на числах: 0,2 с проявление, около 1 с HUD виден
полностью, в 1,2 с начинается исчезновение, к 1,5 с его уже нет.
Этого хватает, чтобы прочитать одно слово, и не мешает продолжать
работу.

HUD не принимает ввод и не требует нажатия. Если на подтверждение
нужно ответить — это уже алерт (28.6).

**Упражнение 28.1.** Поменяй в `showBanner` расчёт `hiddenOffset` на
`-100` и запусти на iPhone 16 с двухстрочным текстом баннера (высота
около 64 точек). Виден ли баннер до и после анимации? Посчитай, какой
сдвиг нужен в действительности.

## 28.12 Modal flow с UIViewControllerTransitioningDelegate

**Когда применять.** Своя анимация модального показа: проявление,
выезд сбоку, «рост» из миниатюры.

Схема похожа на переходы в стопке навигации (26.7): нужен
**аниматор**, который умеет анимировать, и **делегат**, который
выдаёт аниматор по запросу UIKit.

```swift
final class FadeTransition: NSObject, UIViewControllerAnimatedTransitioning {
    let isPresenting: Bool
    init(isPresenting: Bool) { self.isPresenting = isPresenting }

    func transitionDuration(using ctx: UIViewControllerContextTransitioning?) -> TimeInterval {
        0.3
    }

    func animateTransition(using ctx: UIViewControllerContextTransitioning) {
        let duration = transitionDuration(using: ctx)
        if isPresenting {
            guard let toVC = ctx.viewController(forKey: .to),
                  let toView = ctx.view(forKey: .to) else {
                ctx.completeTransition(false)
                return
            }
            toView.frame = ctx.finalFrame(for: toVC)
            toView.alpha = 0
            ctx.containerView.addSubview(toView)
            UIView.animate(withDuration: duration, animations: {
                toView.alpha = 1
            }, completion: { _ in
                ctx.completeTransition(!ctx.transitionWasCancelled)
            })
        } else {
            guard let fromView = ctx.view(forKey: .from) else {
                ctx.completeTransition(false)
                return
            }
            UIView.animate(withDuration: duration, animations: {
                fromView.alpha = 0
            }, completion: { _ in
                ctx.completeTransition(!ctx.transitionWasCancelled)
            })
        }
    }
}

final class FadeTransitioningDelegate: NSObject, UIViewControllerTransitioningDelegate {
    func animationController(forPresented presented: UIViewController,
                             presenting: UIViewController,
                             source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        FadeTransition(isPresenting: true)
    }

    func animationController(forDismissed dismissed: UIViewController)
        -> UIViewControllerAnimatedTransitioning? {
        FadeTransition(isPresenting: false)
    }
}
```

Один аниматор на обе стороны: флаг `isPresenting` говорит, показываем
мы экран или закрываем.

- При показе новый экран получает итоговую рамку (`finalFrame`),
  становится прозрачным, добавляется на сцену и за 0,3 с проявляется.
- При закрытии уходящий экран за 0,3 с растворяется. Удалять его из
  иерархии вручную не нужно — это сделает UIKit после
  `completeTransition`.
- В обеих ветках `guard` в случае неудачи **всё равно** вызывает
  `completeTransition(false)`. Если просто выйти через `return`,
  переход никогда не закончится, и приложение перестанет реагировать
  на касания.

Делегат отвечает на два вопроса UIKit: «чем анимировать показ?»
(`forPresented`) и «чем анимировать закрытие?» (`forDismissed`).

Подключение:

```swift
final class GalleryViewController: UIViewController {
    private let fadeDelegate = FadeTransitioningDelegate()

    func openPhoto() {
        let photo = UIViewController()
        photo.view.backgroundColor = .black
        photo.modalPresentationStyle = .custom
        photo.transitioningDelegate = fadeDelegate
        present(photo, animated: true)
    }
}
```

Главная ловушка — в первой строке класса. `transitioningDelegate`
хранится **слабой** ссылкой. Если написать
`photo.transitioningDelegate = FadeTransitioningDelegate()`, объект
делегата никто не удержит, он исчезнет сразу после присваивания, и
UIKit молча покажет стандартную анимацию. Поэтому делегат лежит в
свойстве показывающего экрана.

`.custom` — «стандартного оформления показа не надо, анимирую сам».
Нижний экран при этом остаётся в иерархии, как при `.overFullScreen`.

Через эту схему делают hero-анимацию, выезд с любой стороны, переворот
карточки — всё, что можно описать анимацией двух view на одной сцене.

**Частые ошибки.**

- **Делегат не удержан** — анимация «не работает», без ошибок.
- **`return` без `completeTransition`** — зависший интерфейс.
- **Забыли `.custom`** — для стилей вроде `.pageSheet` UIKit может
  использовать своё оформление показа вместо твоего.

**Упражнение 28.2.** В `GalleryViewController` замени свойство
`fadeDelegate` на прямое присваивание
`photo.transitioningDelegate = FadeTransitioningDelegate()`. Что
увидит пользователь? Почему компилятор не предупредил?

## Ответы к упражнениям

**28.1.** Баннер начинается на 59 + 8 = 67 точках и при высоте 64
заканчивается на 131. Сдвиг на −100 поднимет его нижний край до 31 —
это ещё внутри экрана, под статус-баром. До появления и после ухода
нижняя часть баннера будет торчать сверху. Нужно сдвинуть минимум на
131 точку, с запасом — на −(131 + 20) = −151; ровно это и считает
формула `-(banner.frame.maxY + 20)`.

**28.2.** Пользователь увидит стандартный модальный показ, как будто
никакого делегата нет (при `.custom` — просто появление без твоей
анимации). `transitioningDelegate` — слабая ссылка, созданный объект
тут же освобождается, и к моменту показа свойство уже `nil`.
Компилятор не предупреждает: присвоить новый объект слабому свойству
синтаксически законно. Иногда Xcode показывает предупреждение для
`weak`-переменных, объявленных в твоём коде, но для свойства UIKit
такого предупреждения нет.

## Что мы выучили

- **Лист** (`UISheetPresentationController`, iOS 15+) — детенты
  `.medium()` / `.large()`, ручка, скругление; свои высоты `.custom` —
  только iOS 16+ и только под `#available`.
- **Высота `.custom`** считается внутри безопасной области; `200` —
  это высота содержимого, сам лист на экране выше.
- **`largestUndimmedDetentIdentifier`** — лист без затемнения, под
  которым можно работать.
- **`isModalInPresentation`** + `presentationControllerDidAttemptToDismiss`
  — защита несохранённого ввода от свайпа.
- **Экран под листом не получает `viewWillAppear`** после закрытия
  листа; у `.fullScreen` — получает.
- **Поповер** на iPhone превращается в лист
  (`adaptiveSheetPresentationController` для настройки); `.none` в
  делегате оставляет облачко.
- **Алерт**: одна `.cancel`, она слева при двух кнопках и внизу при
  трёх и больше; `preferredAction`; action sheet на iPad требует
  `sourceView`.
- **Своё окно** — отдельный экран `.overFullScreen` + `.crossDissolve`
  с `accessibilityViewIsModal`.
- **Баннер и HUD** — в окно или экран, прячем на реально посчитанное
  расстояние, объявляем VoiceOver через `.announcement`.
- **Своя анимация модала** — аниматор + `transitioningDelegate`,
  который надо удержать сильной ссылкой.

## Apple Developer Documentation

- [`UISheetPresentationController`](https://developer.apple.com/documentation/uikit/uisheetpresentationcontroller) — лист с детентами (iOS 15+).
- [`UISheetPresentationController.Detent`](https://developer.apple.com/documentation/uikit/uisheetpresentationcontroller/detent) — `.medium()`, `.large()`, `.custom(identifier:resolver:)` (iOS 16+).
- [`largestUndimmedDetentIdentifier`](https://developer.apple.com/documentation/uikit/uisheetpresentationcontroller/largestundimmeddetentidentifier) — до какой высоты не затемнять фон.
- [`UIViewController.isModalInPresentation`](https://developer.apple.com/documentation/uikit/uiviewcontroller/ismodalinpresentation) — запрет закрытия свайпом.
- [`UIAdaptivePresentationControllerDelegate`](https://developer.apple.com/documentation/uikit/uiadaptivepresentationcontrollerdelegate) — `presentationControllerDidAttemptToDismiss(_:)` и адаптация стилей.
- [`UIModalPresentationStyle`](https://developer.apple.com/documentation/uikit/uimodalpresentationstyle) — `.automatic`, `.pageSheet`, `.formSheet`, `.fullScreen`, `.overFullScreen`, `.popover`, `.custom`.
- [`UIPopoverPresentationController`](https://developer.apple.com/documentation/uikit/uipopoverpresentationcontroller) — `sourceView`/`sourceRect`, `adaptiveSheetPresentationController`.
- [`UIAlertController`](https://developer.apple.com/documentation/uikit/uialertcontroller) — `.alert` и `.actionSheet`, `preferredAction`, `addTextField(configurationHandler:)`.
- [`UIAlertAction.Style`](https://developer.apple.com/documentation/uikit/uialertaction/style-swift.enum) — `.default`, `.cancel`, `.destructive`.
- [`UIAccessibility.Notification.announcement`](https://developer.apple.com/documentation/uikit/uiaccessibility/notification/announcement) — объявить текст для VoiceOver.
- [`UIViewControllerTransitioningDelegate`](https://developer.apple.com/documentation/uikit/uiviewcontrollertransitioningdelegate) и [`UIViewControllerAnimatedTransitioning`](https://developer.apple.com/documentation/uikit/uiviewcontrolleranimatedtransitioning) — свои модальные переходы.
- [HIG — Sheets](https://developer.apple.com/design/human-interface-guidelines/sheets), [HIG — Alerts](https://developer.apple.com/design/human-interface-guidelines/alerts), [HIG — Popovers](https://developer.apple.com/design/human-interface-guidelines/popovers) — Apple о том, когда какой способ показа уместен.

→ [Глава 29. Cookbook — жесты](./46-cookbook-gestures.md)
