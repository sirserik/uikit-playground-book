# Глава 0. Карта UIKit — кто от кого наследуется и что это даёт

В UIKit несколько сотен классов, и на первый взгляд это хаос: `UIButton`,
`UIBarButtonItem`, `UILabel`, `UINavigationItem`, `UIViewController`,
`CALayer`, `UITapGestureRecognizer`… Какие из них можно положить на экран
через `addSubview`? У каких есть `frame`? Кому можно повесить обработчик
нажатия, а кому — только жест? Почему у `UISearchBar` нет `addAction`, а
у `UIRefreshControl` есть? Почему экран (`UIViewController`) не рисуется,
хотя у него есть `view`?

На все эти вопросы один ответ: **посмотри, от кого класс наследуется**.
Почти весь UIKit стоит на лестнице из четырёх ступеней:

```
NSObject                       ← любой объект Objective-C-мира
 └─ UIResponder                ← умеет получать события
     └─ UIView                 ← прямоугольник на экране
         └─ UIControl          ← прямоугольник, который умеет «нажаться»
             └─ UIButton, UISwitch, UISlider, UITextField, …
```

Каждая ступень добавляет классу пачку умений, и наследник получает **все**
умения предков плюс свои. Если знаешь, на какой ступени стоит класс, ты
знаешь о нём больше половины ещё до того, как открыл документацию.

Эта глава — карта. Она не про то, *как сделать* splash или таблицу (это
главы 1–37), а про то, *из чего* всё сделано. Прочитай её до главы 1:
дальше в книге мы будем регулярно писать «это `UIControl`, поэтому у него
есть `addAction`» или «это не view, поэтому у него нет `frame`» и ссылаться
сюда. Все цепочки наследования в главе не вспоминались по памяти, а
распечатаны в симуляторе iOS 26.5 (как — в разделе 0.11), значения по
умолчанию — оттуда же.

> **Режим проверки.** Листинги главы собраны `swiftc` под iOS 15.0,
> Swift 6, Default Actor Isolation = MainActor (введение, раздел 0.2).
> Тексты ошибок компилятора — из Swift 6.3 (Xcode 26.5), дословно.

## 0.1 Зачем нужна карта

### Три фреймворка под одним `import UIKit`

Когда ты пишешь `import UIKit`, в проект приходит не один фреймворк, а
стопка. **Фреймворк** (framework) — библиотека классов и функций от Apple,
упакованная вместе с заголовками и ресурсами. Снизу вверх:

- **Foundation** — «фундамент»: корневой класс `NSObject`, строки и
  коллекции Objective-C (`NSString`, `NSArray` — в Swift они мостятся в
  `String` и `Array`), даты, `NotificationCenter`, `UserDefaults`,
  `URLSession`, `JSONDecoder`. Ничего визуального.
- **Core Graphics** — геометрия и рисование: `CGRect`, `CGPoint`, `CGSize`,
  `CGFloat`, `CGAffineTransform`, `CGColor`. Это **структуры** (value types),
  а не классы: у них нет наследования и нет `===`.
- **Core Animation** (модуль `QuartzCore`) — слои и анимации: `CALayer`,
  `CAGradientLayer`, `CABasicAnimation`. Слой — то, что железо реально
  рисует на экране; каждый `UIView` стоит на своём слое (раздел 0.4).
- **UIKit** — всё, что начинается на `UI`: окна, экраны, view, контролы,
  жесты, навигация. UIKit импортирует три нижних фреймворка сам, поэтому
  одной строки `import UIKit` хватает, чтобы пользоваться `CGRect`,
  `CALayer` и `NotificationCenter`.

Отсюда первая подсказка про имена. Префикс `NS` — Foundation (от NeXTSTEP,
системы, из которой вырос macOS), `CG` — Core Graphics, `CA` — Core
Animation, `UI` — UIKit. Увидел `CALayer` — знай, что это не view и Auto
Layout на него не действует. Увидел `NSLayoutConstraint` — это
Foundation-стиль имени, но класс живёт в UIKit; исключения бывают.

### Как читать лестницу

Вот карта главных классов UIKit. Строка вида `A → B` читается «A
наследует B». Карта снята с симулятора iOS 26.5 — так она выглядит в
рантайме, а не в чьём-то конспекте:

```
NSObject
├── UIResponder
│   ├── UIApplication
│   ├── UIScene
│   │   └── UIWindowScene
│   ├── UIViewController
│   │   ├── UINavigationController
│   │   │   └── UIImagePickerController
│   │   ├── UITabBarController
│   │   ├── UISplitViewController
│   │   ├── UIPageViewController
│   │   ├── UIAlertController
│   │   ├── UIActivityViewController
│   │   ├── UISearchController
│   │   ├── UITableViewController
│   │   └── UICollectionViewController
│   └── UIView
│       ├── UIWindow
│       ├── UILabel
│       ├── UIImageView
│       ├── UIStackView
│       ├── UIActivityIndicatorView
│       ├── UIProgressView
│       ├── UIPickerView
│       ├── UIVisualEffectView
│       ├── UISearchBar
│       ├── UINavigationBar
│       ├── UITabBar
│       ├── UIToolbar
│       ├── UITableViewCell
│       ├── UITableViewHeaderFooterView
│       ├── UICollectionReusableView
│       │   └── UICollectionViewCell
│       │       └── UICollectionViewListCell
│       ├── UIScrollView
│       │   ├── UITableView
│       │   ├── UICollectionView
│       │   └── UITextView
│       └── UIControl
│           ├── UIButton
│           ├── UISwitch
│           ├── UISlider
│           ├── UIStepper
│           ├── UISegmentedControl
│           ├── UIPageControl
│           ├── UIRefreshControl
│           ├── UIDatePicker
│           ├── UIColorWell
│           └── UITextField
│               └── UISearchTextField
├── UIBarItem
│   ├── UIBarButtonItem
│   └── UITabBarItem
├── UINavigationItem
├── UIGestureRecognizer
│   ├── UITapGestureRecognizer
│   ├── UIPanGestureRecognizer
│   │   └── UIScreenEdgePanGestureRecognizer
│   ├── UIPinchGestureRecognizer
│   ├── UILongPressGestureRecognizer
│   ├── UISwipeGestureRecognizer
│   └── UIRotationGestureRecognizer
├── UIPresentationController
│   ├── UISheetPresentationController
│   └── UIPopoverPresentationController
├── UIMenuElement
│   ├── UIAction
│   ├── UICommand
│   └── UIMenu
├── UIFeedbackGenerator
│   ├── UIImpactFeedbackGenerator
│   ├── UINotificationFeedbackGenerator
│   └── UISelectionFeedbackGenerator
├── UICollectionViewLayout
│   ├── UICollectionViewFlowLayout
│   └── UICollectionViewCompositionalLayout
├── UISceneSession, UISceneConfiguration
├── UIColor, UIFont, UIImage, UIBezierPath
├── NSLayoutConstraint, NSLayoutAnchor, UILayoutGuide
├── UITraitCollection, UIScreen, UIDevice
├── UIEvent, UITouch, UIPress
├── UIViewPropertyAnimator
├── UITableViewDiffableDataSource, UICollectionViewDiffableDataSource
├── CALayer
│   ├── CAGradientLayer
│   ├── CAShapeLayer
│   └── CATextLayer
└── CAAnimation
    ├── CAPropertyAnimation
    │   ├── CABasicAnimation
    │   └── CAKeyframeAnimation
    ├── CATransition
    └── CAAnimationGroup
```

Карта делится на две половины. **Левая** — ветка `UIResponder`: всё, что
получает события и (ниже `UIView`) видно на экране. **Правая** — объекты,
которые наследуют `NSObject` напрямую: слои, жесты, элементы панелей,
анимации, цвета. Они нужны интерфейсу, но сами не view: у них нет `frame`,
их нельзя `addSubview`, они не получают касаний. Половина типичных ошибок
в UIKit — попытка обращаться с правой половиной как с левой.

Что даёт каждая ступень левой половины, одной строкой:

| Ступень | Что добавляет | Пример умения |
|---|---|---|
| `NSObject` | Личность объекта в Objective-C-рантайме | `===`, `description`, `#selector`, `isKind(of:)` |
| `UIResponder` | Получать события и передавать их дальше | `touchesBegan`, `next`, `becomeFirstResponder()` |
| `UIView` | Прямоугольник: геометрия, дерево, слой, раскладка | `frame`, `addSubview`, `layer`, constraints |
| `UIControl` | Target-action и состояния | `addAction(_:for:)`, `isEnabled`, `isSelected` |
| Конкретный класс | Содержимое | текст у `UILabel`, картинка у `UIImageView` |

Дальше идём по ступеням снизу вверх и на каждой разбираем, что именно
она даёт и какие ошибки объясняет.

### Бытовая аналогия

Представь должностные инструкции в компании. У **любого сотрудника**
(`NSObject`) есть пропуск с номером — по нему его можно отличить от
других. **Сотрудник приёмной** (`UIResponder`) дополнительно обязан
принимать обращения и, если вопрос не его, передавать выше по цепочке.
**Сотрудник за стойкой в зале** (`UIView`) — тот же приёмщик, но у него
есть рабочее место определённого размера на определённом этаже: его видно
посетителям. **Кассир** (`UIControl`) — работник за стойкой, который по
нажатию кнопки выдаёт результат и ведёт журнал состояний «открыт /
закрыт / занят».

Кассир умеет всё, что умеет работник за стойкой, приёмщик и сотрудник,
плюс своё. А вот **табличка с именем на двери кабинета**
(`UIBarButtonItem`) — не сотрудник вовсе: у неё нет рабочего места и она
ничего не принимает. Дверь (`UINavigationBar`) показывает табличку, и
если хочешь поменять надпись — меняешь табличку, а не дверь.

## 0.2 `NSObject` — корень всего

UIKit написан на Objective-C, и Swift общается с ним через Objective-C
**рантайм** — библиотеку, которая во время работы программы знает про
каждый класс: его имя, родителя, список методов. `NSObject` — корневой
класс этого мира. От него наследуется каждый класс UIKit, поэтому всё,
что умеет `NSObject`, умеет и `UIButton`, и `CALayer`, и `UIColor`.

Что это даёт на практике.

**Личность объекта.** Два view с одинаковым размером и цветом — это два
разных объекта. `NSObject` даёт им `isEqual(_:)` и `hash`, по умолчанию
основанные на адресе в памяти. В Swift это оператор `==` для классов
UIKit: `a == b` истинно только для одного и того же объекта (мы проверили:
у двух свежих `UIView` `a == b` даёт `false`, `a == a` — `true`). Поэтому
view можно класть в `Set` и использовать ключом словаря — так в главе 20
контейнер ищет экран в `children`.

**`description`.** Печать объекта через `print` даёт строку, которую собрал
`NSObject` и дополнил наследник. Для view это полезная отладочная сводка:

```
<UIView: 0x106204100; frame = (0 0; 300 300); layer = <CALayer: 0x10a305c00>>
<UIViewController: 0x10a308370>
```

Видно, что у view есть `frame` и слой, а у view controller'а — нет ни
того, ни другого. К этому вернёмся в 0.7.

**Селекторы и `@objc`.** Рантайм зовёт методы по имени. **Селектор**
(`Selector`) — и есть такое имя; в Swift его пишут `#selector(tap)`. Так
устроен старый target-action у контролов и жестов:

```swift
button.addTarget(self, action: #selector(tap), for: .touchUpInside)

@objc private func tap() { print("нажали") }
```

Пометка `@objc` делает метод видимым для рантайма. Без неё компилятор
остановит сборку:

```
error: argument of '#selector' refers to instance method 'tap()'
       that is not exposed to Objective-C
```

Так работает и `UITapGestureRecognizer(target:action:)`, и `Timer.
scheduledTimer(timeInterval:target:selector:…)`, и `NotificationCenter.
addObserver(_:selector:name:object:)`. Везде, где в API есть слово
`selector` или `action:` с `#selector`, нужен `@objc`. В современном коде
книга чаще использует замыкания — `addAction(UIAction { … })`,
`addObserver(forName:…) { … }` — там `@objc` не нужен.

**Проверка класса в рантайме.** `isKind(of:)`, `isMember(of:)`,
`responds(to:)`, `NSStringFromClass`, `class_getSuperclass` — функции,
которыми в 0.11 мы распечатаем родословную любого класса. Swift-оператор
`is` и приведение `as?` для классов UIKit работают через тот же механизм.

**Протоколы с `NSObjectProtocol`.** Многие протоколы UIKit —
`UITableViewDataSource`, `UITextFieldDelegate`, `UIGestureRecognizerDelegate`
— наследуют `NSObjectProtocol`. Это значит: их может реализовать только
наследник `NSObject`. Обычный Swift-класс не подойдёт:

```swift
final class Source: UITableViewDataSource { … }
// error: cannot declare conformance to 'NSObjectProtocol' in Swift;
//        'Source' should inherit 'NSObject' instead
```

Лечится одним словом: `final class Source: NSObject, UITableViewDataSource`.
Для view controller'ов и view вопрос не стоит — они уже наследники
`NSObject` через `UIResponder`.

**Что не наследует `NSObject`.** `CGRect`, `CGPoint`, `CGSize`,
`UIEdgeInsets`, `IndexPath`, `CGAffineTransform`, `UIControl.Event`,
`UIButton.Configuration`, `UIListContentConfiguration`,
`NSDiffableDataSourceSnapshot` — это структуры. Их копируют при
присваивании, у них нет родителей, нет `===` и нет селекторов. Если у
значения есть точка после имени типа и оно создаётся без `init` в стиле
класса (`CGRect(x:y:width:height:)`, `.zero`), почти наверняка это
структура.

## 0.3 `UIResponder` — кто получает события

**Responder** (англ. «отвечающий») — объект, который умеет принимать
события от системы: касания, нажатия клавиш и кнопок, движения
устройства (встряхивание), команды редактирования (копировать, вставить).
`UIResponder` — абстрактная ступень: сам по себе он ничего не
показывает, но даёт наследникам методы для событий и устройство
**цепочки ответчиков**.

Кто стоит на этой ступени: `UIApplication`, сцена (`UIScene` и её
наследник `UIWindowScene`), окно `UIWindow` и все view, все view
controller'ы. А ещё — твои `AppDelegate` и `SceneDelegate`, потому что
шаблон Xcode объявляет их как `class AppDelegate: UIResponder,
UIApplicationDelegate`. Зачем — чуть ниже.

Кто **не** стоит: слои `CALayer`, распознаватели жестов
`UIGestureRecognizer`, элементы панелей `UIBarButtonItem`,
`UINavigationItem`. Они участвуют в обработке событий, но сами события не
получают — получает view, а они лишь подписаны на него.

### Что добавляет `UIResponder`

- **Методы событий**: `touchesBegan(_:with:)`, `touchesMoved`,
  `touchesEnded`, `touchesCancelled` — касания; `pressesBegan` и родня —
  клавиши и кнопки пульта; `motionBegan`/`motionEnded` — встряхивание
  (им пользуется `PlaygroundWindow` в главе 3). По умолчанию каждый из них
  просто передаёт событие дальше по цепочке.
- **`next`** — «следующий ответчик». Свойство, через которое событие идёт
  вверх, пока кто-нибудь его не обработает.
- **Первый ответчик**: `canBecomeFirstResponder` (по умолчанию `false`),
  `becomeFirstResponder()`, `resignFirstResponder()`, `isFirstResponder`.
- **Редактирование**: `canPerformAction(_:withSender:)` решает, какие
  пункты показать в меню «Копировать / Вставить»; протокол
  `UIResponderStandardEditActions` даёт сами методы `copy(_:)`,
  `paste(_:)`, `selectAll(_:)`.
- **Клавиатурные команды** `keyCommands` (iPad с клавиатурой), `undoManager`,
  `inputAccessoryView` (панель над клавиатурой) и `inputView` (своя
  клавиатура вместо системной).

### Цепочка ответчиков

**Responder chain** — порядок, в котором событие передаётся от одного
ответчика к другому, если предыдущий его не обработал. Документация Apple
описывает `next` так: `UIResponder` сам ничего не хранит и возвращает
`nil`; `UIView` возвращает свой view controller, если управляет им, иначе
superview; `UIViewController` возвращает superview своего view; `UIWindow`
— объект приложения; `UIApplication` обычно возвращает `nil`, но вернёт
делегата приложения, если тот наследует `UIResponder` и ещё не получал
это событие.

Мы распечатали цепочку от кнопки, лежащей во вложенном view на экране
(программа — в разделе 0.11):

```
UIButton → UIView → UIView → UIViewController
        → UIDropShadowView → UITransitionView → UIWindow → UIWindowScene
```

Дальше в работающем приложении идут `UIApplication` и `AppDelegate`
(глава 3 показывает полную цепочку из playground'а). `UIDropShadowView` и
`UITransitionView` — служебные view UIKit между корневым view и окном; на
них не стоит полагаться, но знать, что они есть, полезно: `view.superview`
корневого view экрана — не окно.

Теперь понятно, зачем `AppDelegate` наследует `UIResponder`: он —
**последнее звено** цепочки. Событие, которое никто не обработал, можно
поймать там. И зачем view controller — responder: он стоит в цепочке
**между** своим view и его superview, поэтому может переопределить
`touchesBegan` и получить касание по пустому месту экрана, которое не
забрал ни один subview.

### Первый ответчик

**First responder** — объект, с которого цепочка начинается для событий
без координат: ввод с клавиатуры, встряхивание, команды меню. Для касаний
начало цепочки находит **hit-testing** (раздел 0.4) — view под пальцем.

По умолчанию `canBecomeFirstResponder` возвращает `false`: в симуляторе у
`UIView`, `UIButton` и `UIViewController` это `false`, у `UITextField` и
`UITextView` — `true`. Поэтому `textField.becomeFirstResponder()`
поднимает клавиатуру (поле стало первым ответчиком, и система показывает
ему `inputView` — по умолчанию клавиатуру), а `resignFirstResponder()`
убирает. `view.endEditing(true)` — удобная обёртка: находит первого
ответчика среди потомков view и снимает его.

Если первого ответчика нет (ни одно поле не в фокусе), UIKit не
отбрасывает событие: встряхивание в нашем запуске на iOS 26.5 пришло в
view controller текущего экрана и дальше пошло вверх — к окну (глава 3
показывает оба пути, с полем в фокусе и без). Чтобы экран получал
встряхивание **первым** даже при открытой клавиатуре, ему пришлось бы
переопределить `canBecomeFirstResponder` на `true` и вызвать
`becomeFirstResponder()` в `viewDidAppear`. В книге мы поступаем иначе:
ловим `motionEnded` в окне, до которого событие доходит в любом случае,
и не воюем с текстовыми полями за звание первого ответчика.

### Касания и жесты

Касание сначала получает view под пальцем, а **распознаватели жестов**
(`UIGestureRecognizer`, раздел 0.9), прикреплённые к этому view и его
предкам, смотрят на то же касание параллельно. Когда распознаватель
узнаёт жест, он по умолчанию отменяет касание для view
(`cancelsTouchesInView = true`): view получит `touchesCancelled`. Поэтому
на одной и той же view редко переопределяют `touchesBegan` и вешают
жесты одновременно — проще выбрать одно. Подробно — в главе 29.

### Target-action без адресата

У контролов и `UIBarButtonItem` можно указать `target: nil`:

```swift
button.addTarget(nil, action: #selector(save(_:)), for: .touchUpInside)
```

Тогда UIKit идёт по цепочке ответчиков от первого ответчика вверх и зовёт
`save(_:)` у первого, кто этот метод реализует. Так работают системные
команды «Копировать / Вставить» и так же можно доставить действие с
кнопки в ячейке до view controller'а, не передавая ссылку на него.
Приём редкий, но объясняет, почему у `UIResponder` есть
`target(forAction:withSender:)`.

## 0.4 `UIView` — прямоугольник на экране

`UIView` — главная ступень. Всё, что ты видишь в приложении на UIKit, —
view или нарисовано view. Эта ступень добавляет к ответчику пять вещей:
**геометрию** (где и какого размера), **дерево** (кто внутри кого),
**слой** (как это рисуется), **раскладку** (как размер и положение
вычисляются) и **внешний вид** (цвет, прозрачность, скрытость). Разберём
по очереди — с числами из симулятора.

### Геометрия: `frame`, `bounds`, `center`, `transform`

Создадим view и напечатаем три свойства:

```swift
let box = UIView(frame: CGRect(x: 10, y: 20, width: 100, height: 50))
print(box.frame)    // (10.0, 20.0, 100.0, 50.0)
print(box.bounds)   // (0.0, 0.0, 100.0, 50.0)
print(box.center)   // (60.0, 45.0)
```

- **`frame`** — прямоугольник view **в координатах superview**: «где я
  лежу внутри родителя». Левый верхний угол в точке (10, 20), размер
  100 × 50.
- **`bounds`** — тот же прямоугольник **в собственных координатах** view:
  «какой я изнутри». Начало по умолчанию (0, 0), размер тот же.
- **`center`** — центр `frame` в координатах superview:
  10 + 100 / 2 = 60 по горизонтали, 20 + 50 / 2 = 45 по вертикали.

Единица — **точка** (point), а не пиксель. У iPhone 16 экран
393 × 852 точки при масштабе 3, то есть 1179 × 2556 пикселей: в одной
точке — три пикселя по каждой стороне. Все размеры, отступы и шрифты в
UIKit задаются в точках, и один и тот же код даёт одинаковый физический
размер на экранах разной плотности.

Зачем два прямоугольника? Потому что они отвечают на разные вопросы.
Когда ты раскладываешь **subviews** внутри view, тебе нужен `bounds`: вот
моё пространство от (0, 0) до (100, 50), в нём и расставляю детей. Когда
ты кладёшь само view в родителя — нужен `frame`. Если сдвинуть
`bounds.origin`, `frame` не изменится, а сдвинется **содержимое**:

```swift
box.bounds.origin = CGPoint(x: 50, y: 0)
print(box.frame)    // (10.0, 20.0, 100.0, 50.0) — на том же месте
```

Теперь subview с `frame.origin = (0, 0)` окажется на 50 точек левее
видимой области. Ровно так устроена прокрутка: `UIScrollView.contentOffset`
— это и есть `bounds.origin` его view (раздел 0.6; в симуляторе после
`contentOffset = (0, 50)` печать `bounds.origin` даёт `(0.0, 50.0)`).

**`transform`** — поворот, масштаб или сдвиг, применённые к view как
целому. После поворота на 45° `frame` становится описывающим
прямоугольником наклонённого квадрата, а `bounds` — нет:

```swift
box.transform = CGAffineTransform(rotationAngle: .pi / 4)   // π/4 — 45°
print(box.frame)    // (6.97, -8.03, 106.07, 106.07)
print(box.bounds)   // (0.0, 0.0, 100.0, 50.0)
```

Документация Apple формулирует жёстко: если `transform` не единичный,
значение `frame` **не определено** и его нельзя ни читать, ни менять;
двигай view через `center`, меняй размер через `bounds`. Отсюда правило,
которое пригодится в главах про анимации (32) и перевёрнутый чат (18):
анимируешь `transform` — не трогай `frame`.

**Упражнение 0.1.** У view `frame = (40, 100, 200, 80)`. Чему равны
`bounds` и `center`? Если присвоить `center = (100, 100)`, каким станет
`frame`? Ответ — в конце главы.

### Дерево: `subviews`, `superview`, `window`

View вкладываются друг в друга и образуют **дерево** (view hierarchy).
У каждого view одно `superview` (или `nil`, если view ни в кого не
вложено) и массив `subviews`. Корень дерева — окно (`UIWindow`, тоже
view — раздел 0.8), и свойство `window` у любого view возвращает его или
`nil`, если view ещё не на экране.

Порядок в массиве `subviews` — это порядок **по глубине**: последний
добавленный рисуется поверх предыдущих. Мы положили в один родитель два
одинаковых view `a` и `b` (сначала `a`, потом `b`) и спросили, кто под
пальцем в точке (10, 10): ответ — `b`. Поменять порядок можно
`bringSubviewToFront(_:)`, `sendSubviewToBack(_:)`,
`insertSubview(_:at:)`, `insertSubview(_:belowSubview:)`.

`addSubview(_:)` принимает только `UIView`. Попробуй положить в view
элемент панели — и компилятор откажет:

```swift
view.addSubview(UIBarButtonItem())
// error: cannot convert value of type 'UIBarButtonItem'
//        to expected argument type 'UIView'
```

Это не придирка: `UIBarButtonItem` стоит в правой половине карты (0.9),
у него нет ни `frame`, ни слоя — рисовать нечего.

Координаты у каждого view свои, поэтому для перевода точки или
прямоугольника между view есть `convert(_:to:)` и `convert(_:from:)`:
«где `thumbnail.bounds` окажется в координатах `container`» — так в
главе 37 рассчитывается полёт картинки в photo viewer. `nil` вместо view
означает координаты окна.

### Слой: `layer` и `layerClass`

У каждого view есть ровно один **слой** — объект `CALayer` из Core
Animation, свойство `layer`. Слой — то, что железо реально рисует:
прямоугольник с содержимым, фоном, рамкой, скруглением, тенью. View —
это обёртка над слоем, добавляющая события и раскладку. Документация
говорит коротко: свойство никогда не `nil`, класс слоя определяет
`layerClass`, view — делегат своего слоя, и менять этого делегата нельзя.

Свойства, за которыми ты ходишь в слой: `cornerRadius` (по умолчанию 0),
`borderWidth` и `borderColor`, `shadowColor` / `shadowOpacity` (0 —
тени нет) / `shadowRadius` (3) / `shadowOffset` ((0, −3) — тень чуть
выше, наследие macOS), `masksToBounds`. Последнее — то же самое, что
`clipsToBounds` у view: мы выставили `layer.masksToBounds = true` и
`view.clipsToBounds` тут же стал `true`. Отсюда классический конфликт
«скругление + тень»: тень рисуется **за** границей слоя, а
`masksToBounds` обрезает всё за границей — тень исчезает. Решение —
два слоя (view-подложка с тенью и внутренняя view со скруглением), глава 32.

`layerClass` — свойство класса, которое UIKit читает **один раз** при
создании view. По умолчанию возвращает `CALayer`. Переопределив его на
`CAGradientLayer`, ты получаешь view, слой которого — градиент, и он
растягивается вместе с view без всякого кода в `layoutSubviews`
(глава 21). У `UILabel` слой тоже свой — служебный `_UILabelLayer`,
который умеет рисовать текст.

Чем слой **не** является: он не ответчик (касания не получает), не
участвует в Auto Layout (размер задаёшь сам, обычно в `layoutSubviews`),
не имеет `subviews` (у него `sublayers`). `layer.addSublayer(view)` не
скомпилируется: «cannot convert value of type 'UIView' to expected
argument type 'CALayer'». И ещё одна особенность: у **отдельных** слоёв,
добавленных через `addSublayer`, любое изменение `frame`, цвета или
прозрачности анимируется само за 0,25 секунды (**неявная анимация**), а
у слоя самого view — нет: UIKit эту анимацию отключает. Поэтому в главе
23 shimmer-слой обновляется внутри `CATransaction.setDisableActions(true)`.

### Раскладка: Auto Layout и проход layout

**Раскладка** (layout) — вычисление `frame` каждого view. Способов два.

**Руками через `frame`** — старый и простой: `label.frame = CGRect(…)`.
Проблема в том, что размеры экранов разные, текст разной длины, а шрифт
пользователь может увеличить в настройках. Поэтому в книге почти всегда
второй способ.

**Auto Layout** — ты описываешь не координаты, а **правила**:
«лейбл на 16 точек правее иконки, по вертикали — по центру с ней, не
шире родителя». Каждое правило — объект `NSLayoutConstraint`
(**constraint**, «ограничение»). UIKit решает систему таких уравнений и
сам ставит `frame`. Правила удобно создавать через **якоря**
(`leadingAnchor`, `topAnchor`, `widthAnchor`, `centerYAnchor`…):

```swift
label.translatesAutoresizingMaskIntoConstraints = false
view.addSubview(label)
NSLayoutConstraint.activate([
    label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 16),
    label.centerYAnchor.constraint(equalTo: icon.centerYAnchor),
    label.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor,
                                    constant: -16),
])
```

Разберём, что здесь из какой ступени.

`translatesAutoresizingMaskIntoConstraints = false` — обязательная первая
строка для любого view, которое ты расставляешь constraints в коде. По
умолчанию свойство `true` (проверено: у свежего `UIView` — `true`), и
UIKit **сам** создаёт constraints из `frame` и `autoresizingMask`
(старого механизма «растягиваться вслед за родителем»). Твои правила
столкнутся с этими автоматическими, и в консоли появится «Unable to
simultaneously satisfy constraints». Ставить флаг нужно у subview
снаружи (из экрана или родителя), а не внутри собственного `init` view —
так требует документация, потому что иначе родитель не сможет
разложить этот view по `frame`, если захочет.

`constraint(equalTo:constant:)` возвращает `NSLayoutConstraint` —
обычный объект (`NSObject`, не view). Создан он **неактивным**
(`isActive == false`) и ни на что не влияет, пока его не активируют:
`NSLayoutConstraint.activate([...])` или `isActive = true`. Приоритет по
умолчанию — `required`, 1000.

**Приоритеты.** Когда правила противоречат друг другу, побеждает более
важное. Шкала — от 1 до 1000: `.required` = 1000 («обязательно»),
`.defaultHigh` = 750, `.defaultLow` = 250. Правило с приоритетом ниже
1000 UIKit может нарушить ради более важного — так делают «хочу 200
точек в ширину, но если не влезаю — ужмись».

**Собственный размер.** У многих view есть `intrinsicContentSize` —
размер, который view хочет занять исходя из содержимого. `UILabel` с
текстом «Привет» шрифтом 17 пунктов просит 58 × 20,33 точки; пустой —
0 × 0; `UISwitch` — 61 × 28; системная кнопка с заголовком «OK» — 30 × 30.
Если у view нет естественного размера, он возвращает
`UIView.noIntrinsicMetric` (это −1) по нужной оси — так у голого `UIView`
и у `UIStackView` (стек считает размер из детей, а не из себя). Благодаря
`intrinsicContentSize` лейблу не нужны constraints на ширину и высоту —
хватает позиции.

Два приоритета управляют тем, как view держится за свой размер:
**content hugging** («обнимание содержимого» — сопротивление растяжению,
по умолчанию 250) и **compression resistance** (сопротивление сжатию,
по умолчанию 750). Числа одинаковы у `UIView`, `UILabel`, `UIButton` —
мы проверили. Поэтому два лейбла в строке, когда места мало, сначала
растягиваются (сопротивление растяжению слабое), и только потом UIKit
решает, кого обрезать. Чтобы правый лейбл не сжимался, ему поднимают
`setContentCompressionResistancePriority(.required, for: .horizontal)`.

**Направляющие** (`UILayoutGuide`) — невидимые прямоугольники с якорями,
к которым можно привязываться как к view, хотя view они не являются:

- `safeAreaLayoutGuide` — **безопасная зона**: часть экрана, не закрытая
  вырезом, часами, индикатором Home и панелями. У корневого view экрана
  на iPhone 16 в портрете `safeAreaInsets` — 59 точек сверху и 34 снизу.
  Кнопка, прибитая к `view.bottomAnchor`, залезет под индикатор Home;
  прибитая к `view.safeAreaLayoutGuide.bottomAnchor` — нет.
- `layoutMarginsGuide` — **поля** view. У обычного view по умолчанию
  8 точек с каждой стороны; у корневого view экрана поля задаёт система
  с учётом безопасной зоны (документация: «reflects the system minimum
  margins and safe area insets»).
- `readableContentGuide` — ширина, удобная для чтения текста (на iPad
  строка не растягивается на весь экран).
- `keyboardLayoutGuide` (iOS 15) — прямоугольник клавиатуры; к его
  `topAnchor` прибивают низ формы, чтобы она поднималась вместе с
  клавиатурой (глава 30).

**Когда раскладка происходит.** Не в момент `activate`. UIKit копит
изменения и выполняет **проход layout** один раз перед отрисовкой кадра
— так дешевле. Три метода управляют этим:

- `setNeedsLayout()` — «пометь, что раскладка устарела»; возвращается
  сразу, пересчёт будет в следующем цикле обновления;
- `layoutIfNeeded()` — «пересчитай **сейчас**, если есть что
  пересчитывать»; нужен, когда `frame` требуется немедленно, например
  внутри блока анимации, чтобы изменение `constant` анимировалось
  (глава 32);
- `layoutSubviews()` — метод, который UIKit вызывает **сам** во время
  прохода; реализация по умолчанию применяет constraints. Его
  переопределяют, чтобы расставить то, что Auto Layout не умеет
  (например, `frame` слоя), и **никогда не вызывают напрямую**.

Из этого следует правило, о которое спотыкаются чаще всего: в
`viewDidLoad` и сразу после `addSubview` **размеры subviews ещё не
вычислены**. `label.bounds.width` там равна нулю, и анимация «от 0 до
ширины» едет от нуля до нуля (глава 23). Окончательные размеры известны в
`viewDidLayoutSubviews` экрана или в `layoutSubviews` самого view.

### Hit-testing: кто получает касание

Когда палец касается экрана, UIKit ищет view под ним методом
`hitTest(_:with:)`, начиная с окна. Документация описывает алгоритм:
метод спрашивает каждый subview через `point(inside:with:)`, лежит ли
точка в его `bounds`, и спускается вглубь, пока не найдёт **самого
дальнего потомка** (самого верхнего на экране), содержащего точку. Три
условия выключают view из поиска — вместе с его потомками:

- `isHidden == true`;
- `alpha < 0.01`;
- `isUserInteractionEnabled == false`.

Мы проверили это в симуляторе: касание в центр дочернего view
возвращало его, а после каждого из трёх изменений — родителя. Четвёртое
правило из документации: точка **вне `bounds`** родителя не считается
попаданием, даже если subview вылезает за край (`clipsToBounds = false`
рисует его, но касания туда не доходят). В опыте касание по части
«внука», торчащей за пределы `child`, вернуло корневой view.

Два класса по умолчанию выключены из касаний: у `UILabel` и `UIImageView`
`isUserInteractionEnabled == false`, у голого `UIView` — `true`.
Поэтому жест на лейбле или картинке не сработает, пока не написать
`isUserInteractionEnabled = true` (главы 14, 22, 29). Документация
предупреждает ещё об одном: **во время анимации** касания для всех
анимируемых view отключены, если не передать опцию `.allowUserInteraction`.

### Внешний вид

- `backgroundColor` — у `UIView` по умолчанию `nil` (прозрачный), у
  `UILabel` — прозрачный чёрный с альфой 0, то есть тоже ничего не
  видно. `isOpaque` по умолчанию `true` — обещание «я непрозрачный», которое
  позволяет не смешивать цвета; с прозрачным фоном его стоит ставить в
  `false`, иначе возможны артефакты при рисовании.
- `alpha` — прозрачность от 0 до 1, действует на view со всеми потомками.
- `isHidden` — скрыть. Скрытый view остаётся в `subviews`, занимает место
  в раскладке и не получает событий (документация). Исключение —
  `UIStackView`: скрытый элемент стека места не занимает (глава 17).
- `clipsToBounds` — обрезать ли потомков по своим границам. По умолчанию
  `false`; `UIScrollView` переопределяет на `true`.
- `tintColor` — «акцентный» цвет: документация называет его первым
  ненулевым tint color в иерархии, начиная с самого view и поднимаясь к
  предкам. Если никто не задал — системный синий. Поэтому
  `window.tintColor = .systemGreen` перекрашивает все кнопки и ссылки
  приложения разом (глава 35).
- `contentMode` — как масштабировать содержимое, когда размер view
  меняется: `.scaleAspectFit`, `.scaleAspectFill`, `.center`… Важно для
  `UIImageView` (глава 16).

### Два инициализатора

У `UIView` два инициализатора: назначенный `init(frame:)` и
`init?(coder:)` — тот, которым UIKit воссоздаёт view из storyboard или
xib. Второй помечен `required`, поэтому любой наследник, объявивший
**свой** инициализатор, обязан реализовать и его:

```swift
final class Card: UIView {
    init(title: String) { super.init(frame: .zero) }
}
// error: 'required' initializer 'init(coder:)' must be provided
//        by subclass of 'UIView'
```

В книге storyboard для экранов не используется, поэтому везде стоит
идиома:

```swift
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
```

Она честно говорит: «из storyboard меня создавать нельзя». Так же у
`UIViewController`: назначенный `init(nibName:bundle:)` и обязательный
`init?(coder:)`.

### Трейты

`UIView` и `UIViewController` реализуют протокол `UITraitEnvironment` и
имеют `traitCollection` — набор **трейтов** (traits), то есть сведений об
окружении: светлая или тёмная тема (`userInterfaceStyle`), класс размера
(`horizontalSizeClass` — компактный на iPhone), выбранный пользователем
размер шрифта (`preferredContentSizeCategory`, по умолчанию `L`),
масштаб экрана (`displayScale` 3.0). Динамические цвета (`.label`,
`.systemBackground`) и шрифты `preferredFont(forTextStyle:)` сами
подстраиваются под трейты — поэтому тёмная тема в книге «работает сама»
(глава 35). Реагировать на смену трейтов в коде нужно через
`registerForTraitChanges` (iOS 17); старый `traitCollectionDidChange`
Apple объявила устаревшим.

## 0.5 `UIControl` — view, которое умеет «нажаться»

`UIControl` — ступень между `UIView` и конкретными кнопками. Документация
называет её «базовый класс для контролов — визуальных элементов, которые
передают конкретное действие или намерение в ответ на взаимодействие
пользователя» и описывает главный механизм: **target-action**. Ты не
следишь за касаниями сам — говоришь контролу «при таком событии вызови
вот это», и он зовёт.

### Что добавляет `UIControl`

**События** — `UIControl.Event`, набор флагов:

| Событие | Когда приходит | У кого |
|---|---|---|
| `.touchUpInside` | палец поднят внутри контрола — обычный «тап» | `UIButton` |
| `.touchDown`, `.touchUpOutside`, `.touchCancel` | фазы касания | любой контрол |
| `.valueChanged` | значение изменилось | `UISwitch`, `UISlider`, `UIStepper`, `UISegmentedControl`, `UIDatePicker`, `UIPageControl`, `UIRefreshControl`, `UIColorWell` |
| `.editingChanged`, `.editingDidBegin`, `.editingDidEnd`, `.editingDidEndOnExit` | ввод текста | `UITextField` |
| `.primaryActionTriggered` | «основное действие» контрола: тап кнопки, переключение тумблера, Return в поле | любой контрол |

`.primaryActionTriggered` — семантическое событие (документация: «a
semantic action triggered by buttons»). Именно к нему привязано
замыкание, переданное в `UIButton(primaryAction:)` и
`UIBarButtonItem(primaryAction:)`.

**Два способа подписаться.** Старый, через селектор (нужен `@objc`,
раздел 0.2):

```swift
button.addTarget(self, action: #selector(didTap), for: .touchUpInside)
```

Новый, с iOS 14, через `UIAction` с замыканием:

```swift
button.addAction(UIAction { [weak self] _ in self?.save() }, for: .touchUpInside)
```

`UIAction` — объект (`UIMenuElement → NSObject`, раздел 0.9), который
можно переиспользовать и в меню. Документация уточняет, что действия
различаются по `identifier`: добавление второго действия с тем же
идентификатором заменяет первое. В книге мы пишем `addAction`, кроме
мест, где показываем старый API.

**Состояния** — `isEnabled` (выключенный контрол серый и не реагирует),
`isSelected` (выбран; у кнопки-переключателя), `isHighlighted` (палец
сейчас на контроле). Свойство `state` собирает их в набор флагов
`UIControl.State`, и у кнопки на каждое состояние свой заголовок и цвет:
`setTitle(_:for: .disabled)`. У свежей кнопки `isEnabled == true`,
остальные `false`.

**Служебное**: `isTracking` и `isTouchInside` во время касания,
`contentHorizontalAlignment` / `contentVerticalAlignment`,
`sendActions(for:)` — вызвать подписчиков программно, и с iOS 14 —
контекстное меню по долгому нажатию (`showsMenuAsPrimaryAction`, `menu`).

### Кто контрол, а кто нет

Это самая практичная таблица главы. Если класс — наследник `UIControl`,
у него есть `addAction` и события. Если нет — о событиях сообщает
**делегат**, уведомление или жест.

| Класс | Родитель | Как узнать о событии |
|---|---|---|
| `UIButton` | `UIControl` | `.touchUpInside`, `.primaryActionTriggered` |
| `UISwitch`, `UISlider`, `UIStepper`, `UISegmentedControl` | `UIControl` | `.valueChanged` |
| `UITextField` (и `UISearchTextField`) | `UIControl` | `.editingChanged` или `UITextFieldDelegate` |
| `UIDatePicker`, `UIColorWell`, `UIPageControl` | `UIControl` | `.valueChanged` |
| `UIRefreshControl` | `UIControl` | `.valueChanged` — пользователь потянул список |
| `UILabel` | `UIView` | не контрол: `UITapGestureRecognizer` + `isUserInteractionEnabled = true` |
| `UIImageView` | `UIView` | не контрол: жест + `isUserInteractionEnabled = true` |
| `UISearchBar` | `UIView` | не контрол: `UISearchBarDelegate` |
| `UITextView` | `UIScrollView` | не контрол: `UITextViewDelegate`, уведомления `textDidChangeNotification` |
| `UIPickerView` | `UIView` | не контрол: `UIPickerViewDelegate` + `UIPickerViewDataSource` |
| `UIProgressView`, `UIActivityIndicatorView` | `UIView` | ничего не сообщают — только показывают |
| `UIStackView` | `UIView` | не контрол и сам не рисуется |
| `UIBarButtonItem`, `UITabBarItem` | `UIBarItem → NSObject` | не view вообще: `target`/`action`, `primaryAction`, `menu` |

Попытка повесить действие на лейбл не пройдёт компиляцию:

```swift
label.addAction(UIAction { _ in }, for: .touchUpInside)
// error: value of type 'UILabel' has no member 'addAction'
```

Теперь ясно, почему: `UILabel` стоит на ступени `UIView`, а `addAction`
появляется только на ступени `UIControl`.

Обратная ситуация — `UIRefreshControl`. Внешне это не кнопка, а крутилка
над списком, но наследует он `UIControl`, поэтому подписываешься так же,
как на тумблер: `refresh.addAction(…, for: .valueChanged)` (глава 23).
`UITextField` — контрол, поэтому `addAction(…, for: .editingChanged)`
сообщает о каждом символе без делегата (глава 30). А `UITextView` —
**scroll view**, не контрол: у него делегат.

**Упражнение 0.2.** Не заглядывая в таблицу: у каких из этих классов есть
`addAction(_:for:)` — `UISlider`, `UISearchBar`, `UIPageControl`,
`UIImageView`, `UIDatePicker`, `UITextView`? Для тех, у кого нет, назови
способ узнать об изменении. Ответ — в конце главы.

### `UIButton` крупным планом

`UIButton` — самый используемый контрол, и у него два поколения API.
Старое: `setTitle(_:for:)`, `setImage(_:for:)`, `setTitleColor(_:for:)`,
`contentEdgeInsets` — настройка по состояниям. Новое, с iOS 15:
`UIButton.Configuration` — структура, описывающая кнопку целиком
(`.filled()`, `.tinted()`, `.plain()`, заголовок, подзаголовок, картинка,
отступы, `cornerStyle`), и `configurationUpdateHandler`, который
вызывается при смене состояния. Книга рассчитана на iOS 15, поэтому в
новом коде используем конфигурации; старые методы встречаются там, где
важна совместимость с привычками.

`UIButton(type:)` создаёт кнопку одного из системных типов: `.system`
(синий текст, по умолчанию `UIButton()` — это тип `.custom`, без
оформления), `.close`, `.infoLight` и другие.

## 0.6 `UIScrollView` и его наследники: таблица, коллекция, текст

`UIScrollView` — view, содержимое которого больше, чем он сам, и
сдвигается пальцем. Эта ступень важна, потому что на ней стоят **три**
главных класса для списков и текста: `UITableView`, `UICollectionView`
и — неожиданно для многих — `UITextView`.

### Что добавляет `UIScrollView`

- **`contentSize`** — размер всего содержимого (по умолчанию 0 × 0: пока
  не задан, скроллить нечего).
- **`contentOffset`** — на сколько содержимое сдвинуто; как мы видели в
  0.4, это и есть `bounds.origin`. Прокрутка вниз на 50 точек — это
  `bounds.origin.y == 50`.
- **`contentInset`** — дополнительные поля вокруг содержимого: ими
  поднимают низ списка над клавиатурой. `adjustedContentInset` —
  поля с учётом панелей и безопасной зоны, которые UIKit добавляет сам
  (`contentInsetAdjustmentBehavior = .automatic` по умолчанию).
- **Направляющие** (iOS 11): `frameLayoutGuide` — видимая рамка скролла
  на экране, `contentLayoutGuide` — весь прокручиваемый лист.
  Содержимое в коде привязывают к `contentLayoutGuide`, а его ширину —
  к `frameLayoutGuide`, чтобы прокрутка была только вертикальной
  (главы 8, 30).
- Поведение: `bounces` (пружинит у края, `true`), `isPagingEnabled`
  (листать страницами, `false`), `alwaysBounceVertical`,
  `showsVerticalScrollIndicator`, `keyboardDismissMode` (убирать
  клавиатуру при прокрутке), `delaysContentTouches` (`true`: UIKit
  ждёт мгновение, чтобы отличить тап по кнопке внутри от начала
  прокрутки).
- **Масштабирование**: `minimumZoomScale` и `maximumZoomScale` по
  умолчанию равны 1 — зум выключен. Задай их разными и верни view из
  `viewForZooming(in:)` делегата — получится photo viewer (глава 37).
- **`refreshControl`** (iOS 10) — крутилка «потяни, чтобы обновить».
  Свойство объявлено у `UIScrollView`, поэтому есть и у таблицы, и у
  коллекции, и у любого скролла.
- **`delegate`** — `UIScrollViewDelegate` (слабая ссылка — в заголовке
  SDK написано `weak`): `scrollViewDidScroll`, `scrollViewWillEndDragging`
  и так далее. `clipsToBounds` у scroll view переопределён на `true`.

### Наследники и что они получают даром

```
UIScrollView
├── UITableView       — список строк в один столбец
├── UICollectionView  — сетка/лента с любой раскладкой
└── UITextView        — многострочный текст с прокруткой
```

Из наследования следуют вещи, которые иначе выглядят магией:

- `tableView.contentInset`, `contentOffset`, `refreshControl`,
  `keyboardDismissMode` — всё это **не методы таблицы**, а наследство
  scroll view. Глава 21 двигает шапку по `contentOffset` таблицы именно
  поэтому.
- Протокол `UITableViewDelegate` **наследует** `UIScrollViewDelegate`
  (заголовок SDK: `@protocol UITableViewDelegate<NSObject,
  UIScrollViewDelegate>`). Поэтому делегат таблицы может реализовать
  `scrollViewDidScroll(_:)` и получать прокрутку — отдельный делегат не
  нужен. То же у `UICollectionViewDelegate`.
- `UITextView` прокручивается и реагирует на `isScrollEnabled`; в ячейке
  или форме, где высота должна расти с текстом, прокрутку выключают,
  и тогда у него появляется `intrinsicContentSize` (глава 13).

### Ячейки — тоже view, но не контролы

```
UIView
├── UITableViewCell
├── UITableViewHeaderFooterView
└── UICollectionReusableView
    └── UICollectionViewCell
        └── UICollectionViewListCell       (iOS 14)
```

`UITableViewCell` наследует `UIView` напрямую — **не** `UIControl`, хотя
по ней тапают. Выделение и тап обрабатывает таблица и сообщает делегату
через `tableView(_:didSelectRowAt:)`; у ячейки нет `addAction`. Зато она
реализует `UIGestureRecognizerDelegate` — для своих служебных жестов
(свайп, перетаскивание).

У ячейки коллекции родитель — `UICollectionReusableView`: общий класс
для **всего переиспользуемого** в коллекции, включая заголовки и подвалы
секций (supplementary views). Поэтому header в главе 16 — это
`UICollectionReusableView`, а не ячейка, и регистрируется он отдельным
методом.

**`contentView`.** У обеих ячеек есть `contentView` — view, в который
нужно складывать своё содержимое. Документация объясняет зачем: это
«superview по умолчанию для содержимого ячейки»: при переходе в режим
редактирования и при появлении аксессуара справа ячейка **меняет
размер** `contentView`, и всё, что лежит внутри, подстраивается само; то,
что добавлено мимо него, остаётся на месте и перекрывает кнопки
(глава 12). В симуляторе видно: у свежей `UITableViewCell` ровно один
subview — `UITableViewCellContentView`.

**Переиспользование.** Таблица не создаёт ячейку на каждую строку —
строк может быть десять тысяч, а на экране помещается пятнадцать. Ты
регистрируешь класс под строковым **идентификатором**
(`register(_:forCellReuseIdentifier:)`), просишь ячейку
`dequeueReusableCell(withIdentifier:for:)`, и таблица отдаёт либо
новую, либо ту, что уехала за край. Перед повторной выдачей она зовёт
`prepareForReuse()` — там сбрасывают то, что не перезаписывается в
`cellForRowAt` (глава 19). Вариант `dequeue…(withIdentifier:for:)` с
`indexPath` требует регистрации и не возвращает опционал; без `register`
он роняет приложение (глава 22).

**Высота.** `UITableView.automaticDimension` — это −1 (мы напечатали), и
`rowHeight` по умолчанию равен ей: таблица считает высоту из constraints
ячейки (self-sizing). Чтобы это работало, содержимое должно быть прибито
к `contentView` сверху **и** снизу непрерывной цепочкой правил
(глава 27). Если делегат реализует `tableView(_:heightForRowAt:)`,
`rowHeight` игнорируется, и документация советует предпочитать
свойство: метод делегата таблица вызывает для **каждой** строки, даже
невидимой.

**Данные.** `dataSource` и `delegate` у таблицы и коллекции — **слабые**
ссылки (`@property (nonatomic, weak)` в заголовке SDK). Мы проверили:
назначили источник данных, обнулили свою ссылку на него — `tableView.
dataSource` стал `nil`. Поэтому источник должен кем-то владеть; обычно
это сам экран, который и реализует протоколы. Современная альтернатива
— **diffable data source** (`UITableViewDiffableDataSource`,
`UICollectionViewDiffableDataSource`): объект-`NSObject`, которому
отдают **снимок** данных (`NSDiffableDataSourceSnapshot`, структура), а
он сам вычисляет, какие строки вставить и удалить, и анимирует
(глава 16).

**Раскладка коллекции** — отдельный объект `UICollectionViewLayout`
(`NSObject`, не view): `UICollectionViewFlowLayout` для сетки,
`UICollectionViewCompositionalLayout` (iOS 13) для составных лент.
Коллекция спрашивает у него `frame` каждой ячейки; сама она ничего не
знает о сетках.

## 0.7 `UIViewController` — экран, а не view

Самое частое недоразумение в UIKit: считать view controller «большой
view». Карта говорит обратное: `UIViewController → UIResponder →
NSObject`. Он стоит **рядом** с `UIView`, а не под ним. У него нет
`frame`, нет `addSubview`, нет слоя — компилятор напомнит:

```swift
let vc = UIViewController()
vc.addSubview(UIView())
// error: value of type 'UIViewController' has no member 'addSubview'
let f = vc.frame
// error: value of type 'UIViewController' has no member 'frame'
```

**View controller** — объект, который **управляет** одним деревом view:
создаёт его, наполняет данными, реагирует на события, знает, когда дерево
появилось на экране и когда ушло. Книга называет его **экраном**, потому
что в девяти случаях из десяти один view controller — один экран
приложения. Но контейнеры (`UINavigationController`) и дочерние
контроллеры (глава 20) показывают, что это упрощение.

### `view` и его ленивая загрузка

Корневой view экрана — свойство `view`. Документация описывает его так:
значение по умолчанию `nil`; при первом обращении контроллер сам вызывает
`loadView()` и возвращает результат. `loadView()` без storyboard и xib
создаёт пустой `UIView`; переопределив его, ты можешь подставить свой
корневой view (например, `UITableView`), но вызывать `loadView()`
самому нельзя. После загрузки один раз вызывается `viewDidLoad()`.

Отсюда два практических правила.

Первое: **не трогай `view` в инициализаторе** — обращение загрузит
дерево раньше времени, до того как контейнер или окно сообщили экрану
его размер и трейты. Настройка интерфейса живёт в `viewDidLoad`.

Второе: чтобы узнать, загружен ли view, не читая его, есть
`isViewLoaded` и `viewIfLoaded` (вернёт `nil`, если ещё нет). У свежего
`UIViewController()` в симуляторе `isViewLoaded == false`; после первого
`vc.view` — `true`, а класс view — обычный `UIView` размером с экран.

Корневой view экрана растягивается по `frame` родителем — окном или
контейнером — через `autoresizingMask` (`flexibleWidth` + `flexibleHeight`
по умолчанию), поэтому его `translatesAutoresizingMaskIntoConstraints`
остаётся `true`. Флаг в `false` ставят **subviews**, а не корневому view.

### Жизненный цикл появления

UIKit зовёт методы экрана в фиксированном порядке. Сколько раз — главный
вопрос, и он различается:

| Метод | Когда | Сколько раз |
|---|---|---|
| `viewDidLoad()` | дерево view создано | один раз за жизнь экрана |
| `viewWillAppear(_:)` | view вот-вот добавят в окно | каждый показ |
| `viewIsAppearing(_:)` (iOS 17) | view добавлен, размеры и трейты уже верные | каждый показ |
| `viewWillLayoutSubviews()` / `viewDidLayoutSubviews()` | до и после прохода layout корневого view | многократно, при каждом пересчёте |
| `viewDidAppear(_:)` | анимация показа закончилась | каждый показ |
| `viewWillDisappear(_:)` / `viewDidDisappear(_:)` | экран уходит | каждый уход |

«Каждый показ» значит: вернулся из следующего экрана по «назад» — снова
`viewWillAppear` и `viewDidAppear`. Поэтому анимацию в `viewDidAppear`
защищают флажком (глава 1), а подписки, сделанные в `viewWillAppear`,
снимают в `viewWillDisappear`, чтобы не накопить дубликаты.
`viewIsAppearing` документация выделяет отдельно: к этому моменту у view
уже верная геометрия, поэтому прокрутить таблицу к нужной строке
правильнее здесь, а не в `viewWillAppear`.

Модальный лист (`.pageSheet` / `.formSheet`) **не** убирает нижний экран
из окна, поэтому его `viewWillDisappear` не вызывается; `.fullScreen` —
убирает и вызывает (глава 28).

### Контейнеры и дочерние контроллеры

Один view controller может содержать другие: это **containment**. Экран-
**контейнер** (container view controller) держит детей в `children`, у
ребёнка есть `parent`. Документация требует порядка: сначала
`addChild(_:)` — создать отношение «родитель → ребёнок», потом добавить
`child.view` в своё дерево и расставить, потом `child.didMove(toParent:
self)`. `addChild` **не** добавляет view сам — мы проверили: после
`addChild` `child.parent === vc`, а `child.view.superview == nil`.
Удаление зеркально: `willMove(toParent: nil)` → `view.removeFromSuperview()`
→ `removeFromParent()` (последний сам вызывает `didMove(toParent: nil)`).

Зачем так сложно? Потому что контейнер должен **пересылать** ребёнку
события жизненного цикла, трейты, повороты и безопасную зону. Без
`addChild` ребёнок не узнает, что его показали, и `viewDidAppear` у него
не придёт. Системные контейнеры делают это за тебя:

```
UIViewController
├── UINavigationController   — стек экранов, панель навигации
│   └── UIImagePickerController
├── UITabBarController       — вкладки, панель вкладок
├── UISplitViewController    — две колонки на iPad
└── UIPageViewController     — листание страниц (онбординг, глава 6)
```

У `UINavigationController` массив `viewControllers` — это те же
`children` (в симуляторе `nav.viewControllers.count == nav.children.
count`), а его собственный `view` содержит служебный
`UINavigationTransitionView` и `UINavigationBar`. `UIImagePickerController`
— наследник `UINavigationController`: системный выбор фото — это готовый
навигационный стек, поэтому его показывают модально и не кладут в свой
`UINavigationController`.

### Свойства, которые находят родню

`navigationController`, `tabBarController`, `splitViewController`,
`parent`, `presentingViewController`, `presentedViewController` — UIKit
ищет их, поднимаясь по цепочке родителей. Поэтому `navigationController`
у экрана **внутри** стека возвращает стек, а у экрана, показанного
модально без обёртки, — `nil`: пушить из него некуда (глава 22
оборачивает picker в `UINavigationController` именно для этого).

**`navigationItem`** — объект класса `UINavigationItem` (наследник
`NSObject`, не view), который описывает, как экран представлен в панели
навигации: заголовок, кнопки слева и справа, `backBarButtonItem`,
`searchController`, `largeTitleDisplayMode`. Документация: это уникальный
экземпляр, создаваемый при первом обращении к свойству. Панель
(`UINavigationBar`, view) только **показывает** `navigationItem` текущего
экрана: в симуляторе `nav.navigationBar.topItem === vc.navigationItem`.
Поэтому кнопки задают **у экрана**, а не у панели, и поэтому кнопка
«Назад» настраивается через `backBarButtonItem` **предыдущего** экрана —
это его элемент, который панель показывает, когда поверх лежит
следующий (глава 26). Так же `tabBarItem` (`UITabBarItem`) описывает
экран во вкладках, `toolbarItems` — в тулбаре, `title` — общее имя.

### Модальный показ

`present(_:animated:completion:)` показывает экран поверх текущего,
`dismiss(animated:completion:)` закрывает. Документация про `dismiss`:
закрывать должен **показывающий** (presenting) экран; если вызвать метод
у показанного, UIKit попросит показывающего сделать это. Поэтому
`dismiss` «работает и так, и так», но читается лучше у того, кто
открыл (глава 22).

Как экран выглядит, решает `modalPresentationStyle`. Значение по
умолчанию — `.automatic`, и документация уточняет, во что оно
превращается: для большинства экранов в iOS 18 и новее — `.formSheet`,
до iOS 18 — `.pageSheet`. В компактной ширине (iPhone в портрете) form
sheet выглядит как page sheet: карточка, из-под которой виден предыдущий
экран, смахивается вниз. Другие стили: `.fullScreen` (на весь экран,
нижний убирается из окна), `.overFullScreen` (на весь экран, нижний
остаётся — для прозрачных оверлеев), `.popover` (на iPad — всплывающее
окошко со стрелкой), `.custom` (свой переход, глава 28).
`isModalInPresentation = true` запрещает смахивание.

Сам показ ведёт отдельный объект — **presentation controller**
(`UIPresentationController → NSObject`, не view и не view controller).
Для листов это `UISheetPresentationController` (iOS 15) со своими
`detents` — высотами «средняя / полная» (глава 28); для popover —
`UIPopoverPresentationController`. Доступ через `presentationController`,
`sheetPresentationController`, `popoverPresentationController`;
документация предупреждает: задай `modalPresentationStyle` **до** первого
обращения к ним, потому что при обращении контроллер создаётся под
текущий стиль.

### Системные экраны

Несколько готовых экранов — тоже наследники `UIViewController`:
`UIAlertController` (алерты и action sheet; его **действия**
`UIAlertAction` — объекты `NSObject`, не кнопки), `UIActivityViewController`
(лист «Поделиться»), `UISearchController` (поиск над таблицей, глава 25),
`UITableViewController` и `UICollectionViewController` (экран, у которого
корневой view — сразу таблица или коллекция). Все они показываются
`present`, а не `addSubview` — потому что это экраны, а не view.

### Что ещё умеет экран

- **Трейты** и их переопределение: `overrideUserInterfaceStyle = .dark`
  делает тёмным один экран (глава 35).
- **Статус-бар и ориентация**: `preferredStatusBarStyle`,
  `supportedInterfaceOrientations`.
- **Безопасная зона**: `additionalSafeAreaInsets` расширяет её, когда
  экран показывает свою панель внизу (глава 20).
- **Ответчик**: как наследник `UIResponder`, экран стоит в цепочке между
  своим view и superview, может ловить `touchesBegan` по пустому месту и
  `keyCommands` с клавиатуры iPad.

## 0.8 Окно, сцена, приложение — верх дерева

Над корневым экраном стоят ещё три объекта, и у каждого своя ступень.

```
UIApplication      → UIResponder → NSObject    один на процесс
UIWindowScene      → UIScene → UIResponder     один «экземпляр» интерфейса
UIWindow           → UIView → UIResponder      окно — это view
   └── rootViewController.view                 дерево view экрана
```

**`UIWindow` — это `UIView`.** Самый верхний view дерева, без superview.
Отсюда три вещи, которые книга использует: окну можно сделать
`addSubview` — так в главах 11 и 23 размытие и оверлей загрузки кладутся
поверх **всего** интерфейса, включая модальные экраны; у окна есть
`bounds` (на iPhone 16 — 393 × 852) и `safeAreaInsets`; окно — ответчик,
и оно ловит встряхивание, которое не обработали экраны (глава 3). Своё:
`rootViewController` (его view окно само добавляет в своё дерево через
служебные `UITransitionView` / `UIDropShadowView`), `windowLevel`
(`.normal` = 0, `.statusBar` = 1000, `.alert` = 2000: окно с большим
уровнем лежит выше), `isKeyWindow`, `windowScene`.
`makeKeyAndVisible()` — документация: показать окно (`isHidden = false`)
и сделать его **ключевым** — тем, которое получает события клавиатуры.
Если нужно только показать — хватает `isHidden = false`.

**`UIWindowScene` — ответчик, но не view.** `UIScene` наследует
`UIResponder` напрямую: сцена стоит в цепочке ответчиков над окном (мы
видели её в распечатке в 0.3), но нарисовать её нельзя. Сцена — один
экземпляр интерфейса приложения со своими окнами (`windows`), экраном
(`screen`), ориентацией (`interfaceOrientation`), геометрией
(`effectiveGeometry`, iOS 16) и состоянием (`activationState`). Окно
создаётся с привязкой к сцене: `UIWindow(windowScene:)`. Документация
прямо говорит не создавать сцены самим — их создаёт система по
`Info.plist` или по запросу `requestSceneSessionActivation`.

**`UISceneSession` — `NSObject`.** Карточка сцены, которую система хранит,
пока сцена существует: `persistentIdentifier`, `configuration`
(`UISceneConfiguration`, тоже `NSObject`), `role`, сохранённое состояние.
Сцену могут выгрузить из памяти, сессия останется (глава 5).

**`UIApplication` — ответчик, один на процесс.** Доступ через
`UIApplication.shared`. Знает свои сцены (`connectedScenes`), делегата
(`delegate`), состояние (`applicationState`), умеет открывать URL
(`open(_:options:completionHandler:)`) и регистрироваться на пуши
(`registerForRemoteNotifications()`, глава 41). Стоит в цепочке
ответчиков после сцены и, если никто не обработал событие, передаёт его
делегату — последнему звену.

**Экран устройства** — `UIScreen` (`NSObject`): `bounds`, `scale`. Старое
`UIScreen.main` Apple не рекомендует с iOS 16: в документации — «Apple
discourages the use of this symbol», правильный путь — через сцену:
`view.window?.windowScene?.screen`. На iPad с внешним дисплеем экранов
несколько, и «главный» теряет смысл.

**Делегаты** всех трёх уровней — протоколы (раздел 0.10):
`UIApplicationDelegate` реализует `AppDelegate`, `UIWindowSceneDelegate`
(наследник `UISceneDelegate`) — `SceneDelegate`. Оба класса шаблон делает
наследниками `UIResponder`, чтобы они могли стоять в цепочке. Подробно
о порядке их вызовов — глава 5.

## 0.9 Что не view: слои, жесты, элементы панелей и другие `NSObject`

Правая половина карты — объекты, которые наследуют `NSObject` напрямую.
Они не рисуются, не ловят касания, не участвуют в Auto Layout, их нельзя
`addSubview`. Зато у них нет и накладных расходов view, поэтому UIKit
делает «лёгкие» вещи именно так. Короткая таблица — что это и как с ним
обращаться:

| Класс | Цепочка | Что это | Как с ним работать |
|---|---|---|---|
| `CALayer`, `CAGradientLayer`, `CAShapeLayer`, `CATextLayer` | `→ NSObject` | то, что рисует железо | `view.layer.addSublayer`, `frame` задаёшь сам в `layoutSubviews` |
| `CABasicAnimation`, `CAKeyframeAnimation` | `→ CAPropertyAnimation → CAAnimation → NSObject` | описание анимации слоя | `layer.add(_:forKey:)`; само значение модели не меняет |
| `CATransition`, `CAAnimationGroup` | `→ CAAnimation → NSObject` | переход / группа | то же |
| `UIGestureRecognizer` и наследники | `→ NSObject` | распознаватель жеста | `view.addGestureRecognizer`; один жест — одна view (`gesture.view`) |
| `UIBarButtonItem`, `UITabBarItem` | `→ UIBarItem → NSObject` | описание кнопки для панели | `navigationItem.rightBarButtonItem = …`; панель рисует сама |
| `UINavigationItem` | `→ NSObject` | как экран выглядит в панели навигации | `vc.navigationItem.title = …` |
| `UIAction`, `UICommand`, `UIMenu` | `→ UIMenuElement → NSObject` | действие или меню | `addAction`, `UIButton(primaryAction:)`, `menu` |
| `UIPresentationController`, `UISheetPresentationController`, `UIPopoverPresentationController` | `→ NSObject` | ведёт модальный показ | `vc.sheetPresentationController?.detents = …` |
| `UIFeedbackGenerator` и три наследника | `→ NSObject` | хаптика | `prepare()`, `impactOccurred()` (глава 33) |
| `UICollectionViewLayout`, `…FlowLayout`, `…CompositionalLayout` | `→ NSObject` | раскладка коллекции | передаётся в `UICollectionView(frame:collectionViewLayout:)` |
| `UITableViewDiffableDataSource`, `UICollectionViewDiffableDataSource` | `→ NSObject` | источник данных со снимками | `apply(snapshot)` |
| `NSLayoutConstraint`, `NSLayoutAnchor`, `UILayoutGuide` | `→ NSObject` | правило раскладки, якорь, направляющая | `activate`, `isActive`, `constant` |
| `UIColor`, `UIFont`, `UIImage`, `UIBezierPath` | `→ NSObject` | цвет, шрифт, картинка, контур | неизменяемые значения; `UIColor` может быть динамическим |
| `UITraitCollection` | `→ NSObject` | набор трейтов | читать через `traitCollection`, не создавать руками |
| `UIEvent`, `UITouch`, `UIPress` | `→ NSObject` | одно событие / касание | приходят в `touchesBegan(_:with:)` |
| `UIViewPropertyAnimator` | `→ NSObject` | управляемая анимация | `startAnimation`, `pauseAnimation`, `fractionComplete` (глава 32) |
| `UIScreen`, `UIDevice` | `→ NSObject` | экран и устройство | `windowScene.screen`, `UIDevice.current.userInterfaceIdiom` |
| `UISceneSession`, `UISceneConfiguration` | `→ NSObject` | карточка сцены | глава 5 |
| `UIContextMenuInteraction`, `UIDragInteraction` | `→ NSObject` | «взаимодействие», которое вешают на view | `view.addInteraction(_:)` (глава 29) |
| `UIGraphicsImageRenderer` | `→ UIGraphicsRenderer → NSObject` | рисует в картинку | `image { ctx in … }` (глава 22) |

Разберём три пары, которые путают чаще всего.

**`UIBarButtonItem` и `UIButton`.** Кнопка — view: у неё есть `frame`,
слой, касания. Элемент панели — **модель** кнопки: заголовок, картинка,
`isEnabled`, `target`/`action` или `primaryAction`, `menu`. Как именно
её нарисовать, решает панель (`UINavigationBar`, `UIToolbar` — вот они
view). Поэтому у элемента нет `frame`, его нельзя подвинуть и ему нельзя
`addSubview`. Если очень нужно своё view в панели — есть
`UIBarButtonItem(customView:)`, и тогда view внутри всё-таки есть.
То же с `UITabBarItem` и `UITabBar`.

**`CALayer` и `UIView`.** Слой — прямоугольник с содержимым, view — слой
плюс события плюс раскладка. Когда нужен градиент, тень, фигура по
контуру или много мелких элементов без касаний (десятки точек на
графике), берут слой: он дешевле. Но слой не знает про Auto Layout:
его `frame` выставляют руками, обычно в `layoutSubviews` родительского
view, где `bounds` уже известны. И у слоя своя анимационная модель:
`CABasicAnimation` рисует движение, но **не меняет** значение свойства —
по окончании слой «отскакивает» к старому значению, если ты не присвоил
новое отдельно (глава 32).

**`UIGestureRecognizer` и касания.** Распознаватель — не view и не
ответчик. Его **прикрепляют** к одной view (`addGestureRecognizer`), и он
слушает касания этой view. Состояния — `.possible` → `.began` →
`.changed` → `.ended` (или `.cancelled`, `.failed`); для дискретных
жестов (тап) `.ended` называется `.recognized` — это одно и то же
значение. Распознаватель сообщает через target-action или `UIAction`,
как контрол, и по умолчанию отменяет касание для view
(`cancelsTouchesInView == true`). У одного view может быть несколько
распознавателей, и кто из них побеждает, решает делегат
`UIGestureRecognizerDelegate` (глава 29).

Правило большого пальца: **если у объекта нет `frame`, он не view**. Его
нельзя положить на экран, он не получит касание, и Auto Layout его не
видит. Нужно показать — найди view, которая его отобразит (панель для
`UIBarButtonItem`, view для `CALayer`, `UIImageView` для `UIImage`).

## 0.10 Протоколы — второй скелет UIKit

Наследование — первый скелет: один родитель, цепочка ступеней.
**Протоколы** — второй: класс может принять сколько угодно протоколов и
тем самым пообещать набор методов, не меняя родословную. UIKit держится
на обоих.

### Делегат и источник данных

**Делегат** (delegate) — объект, которому класс UIKit **сообщает** о
событиях и у которого **спрашивает решения**: «тапнули строку»,
«можно ли начать редактирование?», «какой высоты строка?».
**Источник данных** (data source) — объект, у которого класс
**запрашивает содержимое**: «сколько строк?», «дай ячейку для строки 5».
Таблица не хранит ни твоих данных, ни твоей логики — она только рисует
и спрашивает. Это и есть причина, по которой один `UITableView` годится
и для списка дел, и для чата, и для настроек.

Делегат — всегда **слабая** ссылка. В заголовках SDK:
`@property (nonatomic, weak) id<UITableViewDelegate> delegate;`. Причина
— цикл: экран владеет таблицей (сильная ссылка), таблица — делегатом; если
бы делегатом был тот же экран и ссылка была сильной, экран и таблица
держали бы друг друга вечно (утечка). Слабая ссылка цикл разрывает —
но означает, что делегатом должен **владеть кто-то ещё**. Обычно это
не проблема: делегат — сам экран, которым владеет контейнер или окно.
Проблема появляется, когда делегат — отдельный маленький объект,
созданный на лету и никому не принадлежащий: он тут же освобождается, и
таблица молчит. То же для своих делегатов: объявляй `weak var delegate:
MyDelegate?` и делай протокол классовым (`: AnyObject`), иначе `weak`
не скомпилируется.

Протоколы делегатов UIKit наследуют `NSObjectProtocol`, поэтому
реализовать их может только наследник `NSObject` (раздел 0.2). И в них
много **необязательных** методов (`optional` в Objective-C): можно
реализовать три из тридцати, остальные UIKit заменит поведением по
умолчанию. Свои протоколы в Swift так не умеют — там либо расширение с
реализацией по умолчанию, либо `@objc optional`.

### Протоколы наследуют друг друга

У протоколов тоже есть цепочки, и они объясняют «лишние» методы:

- `UITableViewDelegate: UIScrollViewDelegate` — делегат таблицы получает
  `scrollViewDidScroll` (0.6);
- `UICollectionViewDelegate: UIScrollViewDelegate` — то же для коллекции;
- `UIWindowSceneDelegate: UISceneDelegate` — делегат оконной сцены
  получает общие методы сцены (`sceneDidBecomeActive`) и свои
  (`windowScene(_:didUpdate…)`);
- `UITextFieldDelegate`, `UITextViewDelegate`, `UISearchBarDelegate`,
  `UIPageViewControllerDelegate` — все `: NSObjectProtocol`.

### Протоколы, которые реализует сам UIKit

Несколько протоколов полезно знать, потому что по ним видно, что класс
умеет:

- `UITraitEnvironment` — у объекта есть `traitCollection`: `UIView`,
  `UIViewController`, `UIWindow`, `UIScreen`, `UIPresentationController`
  (подтверждено `conforms(to:)` в симуляторе).
- `UIContentContainer` — объект умеет подстраиваться под размер
  контейнера и пересылать его детям: `UIViewController`,
  `UIPresentationController`.
- `UIAppearance` — у класса есть «прокси внешнего вида»
  `UINavigationBar.appearance()`, через который задают стиль всем
  экземплярам разом: `UIView`, `UIBarItem` (глава 35).
- `NSCoding` — объект можно сохранить и восстановить из архива; отсюда
  обязательный `init?(coder:)` у `UIView` и `UIViewController` (0.4).
- `CALayerDelegate` — `UIView` сам делегат своего слоя (0.4; в симуляторе
  `view.layer.delegate === view`), поэтому делегатом **другого** слоя
  view делать нельзя.
- `UIGestureRecognizerDelegate` — его реализуют `UITableViewCell` и
  `UIScrollView` для своих внутренних жестов.
- `UIContentConfiguration` / `UIContentView` — пара для ячеек нового
  образца: структура-конфигурация (`UIListContentConfiguration`) и view,
  которая её показывает (глава 19).
- `UIViewControllerTransitioningDelegate`,
  `UIViewControllerAnimatedTransitioning` — свои переходы между экранами
  (глава 28).
- `UIInteraction` — «взаимодействие», которое вешают на view через
  `addInteraction`: контекстное меню, drag and drop (глава 29).
- `UIResponderStandardEditActions` — `copy(_:)`, `paste(_:)`,
  `selectAll(_:)` у каждого ответчика.

## 0.11 Проверь сам: печатаем родословную

Карту из 0.1 не нужно принимать на веру — её печатает сам рантайм.
Функция ниже спрашивает у Objective-C-рантайма родителя класса, потом
родителя родителя, пока не дойдёт до корня:

```swift
import UIKit

/// «Родословная» класса: сам класс → родитель → … → NSObject.
func superclassChain(of cls: AnyClass) -> String {
    var names = [NSStringFromClass(cls)]
    var current: AnyClass? = class_getSuperclass(cls)
    while let next = current {
        names.append(NSStringFromClass(next))
        current = class_getSuperclass(next)
    }
    return names.joined(separator: " → ")
}
```

`class_getSuperclass` — функция рантайма (`import UIKit` подтягивает и
модуль `ObjectiveC`): «дай родителя этого класса», для `NSObject`
вернёт `nil`, и цикл закончится. `NSStringFromClass` — имя класса
строкой. `AnyClass` — тип «любой класс»; передаём `UITableView.self`.

Вызови из `viewDidLoad` любого экрана книги:

```swift
let classes: [AnyClass] = [UITableView.self, UIBarButtonItem.self, UIViewController.self]
for cls in classes {
    print(superclassChain(of: cls))
}
```

В симуляторе iOS 26.5 мы получили:

```
UITableView → UIScrollView → UIView → UIResponder → NSObject
UIBarButtonItem → UIBarItem → NSObject
UIViewController → UIResponder → NSObject
```

Тем же способом снята вся карта из 0.1 и значения по умолчанию в этой
главе: `print(UILabel().isUserInteractionEnabled)`, `print(UIView().
intrinsicContentSize)` и так далее. Сомневаешься в утверждении про UIKit
— напечатай и посмотри. Это надёжнее любой статьи, включая эту главу.

Цепочку ответчиков печатают так же, только через `next`:

```swift
func responderChain(from responder: UIResponder) -> String {
    var names: [String] = []
    var current: UIResponder? = responder
    while let r = current {
        names.append(NSStringFromClass(type(of: r)))
        current = r.next
    }
    return names.joined(separator: " → ")
}
```

Вызывать нужно, когда view уже в окне (например, из `viewDidAppear`):
до этого `next` у корневого view обрывается на самом экране, потому что
superview ещё нет. Глава 3 показывает результат для лаунчера playground'а.

**Упражнение 0.3.** Распечатай цепочки для `UISearchBar`, `UITextView`,
`UIImagePickerController` и `UIAlertAction`. Для каждого ответь: можно ли
его `addSubview`, есть ли у него `addAction(_:for:)`, как он попадает на
экран. Ответ — в конце главы.

## Ответы к упражнениям

**0.1.** `bounds` = (0, 0, 200, 80): начало в собственных координатах
всегда (0, 0), размер тот же. `center` = (40 + 100, 100 + 40) = (140, 140).
После `center = (100, 100)` размер не меняется, а `frame.origin`
сдвигается так, чтобы центр оказался в (100, 100): (100 − 100, 100 − 40)
= (0, 60), то есть `frame` = (0, 60, 200, 80). Проверить: создай view с
таким `frame`, присвой `center` и напечатай `frame`.

**0.2.** `addAction(_:for:)` есть у `UISlider`, `UIPageControl` и
`UIDatePicker` — все три наследуют `UIControl`, событие `.valueChanged`.
Нет у `UISearchBar` (`UIView`; изменения приходят в
`UISearchBarDelegate.searchBar(_:textDidChange:)`), `UIImageView`
(`UIView`; нужен `UITapGestureRecognizer` и `isUserInteractionEnabled =
true`) и `UITextView` (`UIScrollView`; `UITextViewDelegate.
textViewDidChange(_:)` или уведомление `UITextView.textDidChangeNotification`).

**0.3.** В симуляторе iOS 26.5:

```
UISearchBar → UIView → UIResponder → NSObject
UITextView → UIScrollView → UIView → UIResponder → NSObject
UIImagePickerController → UINavigationController → UIViewController
                        → UIResponder → NSObject
UIAlertAction → NSObject
```

`UISearchBar` — view: `addSubview` можно, `addAction` нет (не контрол),
на экран попадает как subview или через `navigationItem.searchController`.
`UITextView` — view и scroll view: `addSubview` можно, `addAction` нет,
события через делегат. `UIImagePickerController` — экран, причём
навигационный стек: ни `addSubview`, ни `addAction`; на экран — через
`present`. `UIAlertAction` — ни view, ни экран: это описание кнопки
алерта; на экран попадает, когда `UIAlertController` нарисует его сам
после `alert.addAction(_:)`.

## Что мы выучили

- Почти весь UIKit стоит на лестнице `NSObject → UIResponder → UIView →
  UIControl → конкретный класс`. Каждая ступень добавляет умения, и
  наследник получает все умения предков.
- `NSObject` даёт объекту личность (`==` по адресу, `description`) и связь
  с Objective-C-рантаймом: `#selector` требует `@objc`, протоколы
  делегатов — наследования от `NSObject`.
- `UIResponder` — получатель событий. Цепочка ответчиков: view →
  экран → superview → … → окно → сцена → приложение → делегат. Первый
  ответчик — тот, кто получает клавиатуру; `canBecomeFirstResponder` по
  умолчанию `false`, у текстовых полей `true`.
- `UIView` — прямоугольник: `frame` в координатах родителя, `bounds` в
  своих, при `transform` `frame` не определён. Один слой `CALayer` на
  view. Auto Layout: `translatesAutoresizingMaskIntoConstraints = false`,
  приоритеты 1000/750/250, hugging 250 и compression resistance 750,
  `intrinsicContentSize`; раскладка происходит в проходе layout, а не
  сразу — в `viewDidLoad` размеры subviews нулевые.
- Hit-testing пропускает view с `isHidden`, `alpha < 0.01`,
  `isUserInteractionEnabled == false`; у `UILabel` и `UIImageView`
  касания выключены по умолчанию.
- `UIControl` добавляет target-action: `addAction(_:for:)`, события
  `.touchUpInside` / `.valueChanged` / `.editingChanged` /
  `.primaryActionTriggered`, состояния. У `UILabel`, `UISearchBar`,
  `UITextView` этого нет — там жесты и делегаты.
- `UITableView`, `UICollectionView`, `UITextView` — наследники
  `UIScrollView`: `contentOffset` (= `bounds.origin`), `contentInset`,
  `refreshControl`, `UITableViewDelegate: UIScrollViewDelegate`. Ячейки —
  view, не контролы; содержимое — в `contentView`; `dataSource` и
  `delegate` слабые.
- `UIViewController` — ответчик, не view: управляет `view`, который
  создаётся лениво (`loadView` → `viewDidLoad` один раз); `viewWillAppear`
  и `viewDidAppear` — каждый показ. Контейнеры требуют `addChild` →
  view → `didMove`. `navigationItem` принадлежит экрану, панель его
  показывает. `.automatic` — это `.formSheet` с iOS 18 (`.pageSheet`
  раньше); показ ведёт `UIPresentationController` (`NSObject`).
- `UIWindow` — view (можно `addSubview`), `UIScene` — ответчик, но не
  view, `UIApplication` — ответчик, `UISceneSession` — `NSObject`.
- Слои, анимации, жесты, `UIBarButtonItem`, `UINavigationItem`, `UIAction`,
  цвета, шрифты, constraints, трейты — `NSObject` без `frame`: их нельзя
  `addSubview`, они не ловят касания и не участвуют в Auto Layout.
- Протоколы — второй скелет: делегат (события и решения) и источник
  данных (содержимое), оба слабые; протоколы наследуют друг друга.
- Любое утверждение про UIKit проверяется печатью: `class_getSuperclass`,
  `next`, значения свойств у свежего объекта.

## Apple Developer Documentation

- [UIKit](https://developer.apple.com/documentation/uikit) — каталог фреймворка; у каждого класса на странице есть раздел Inherits From.
- [NSObject](https://developer.apple.com/documentation/objectivec/nsobject) — корневой класс: `isEqual`, `hash`, `description`, селекторы.
- [UIResponder](https://developer.apple.com/documentation/uikit/uiresponder) и [next](https://developer.apple.com/documentation/uikit/uiresponder/next) — ответчик и правило «кто следующий».
- [Using responders and the responder chain to handle events](https://developer.apple.com/documentation/uikit/using-responders-and-the-responder-chain-to-handle-events) — цепочка ответчиков на схемах Apple.
- [UIView](https://developer.apple.com/documentation/uikit/uiview), [frame](https://developer.apple.com/documentation/uikit/uiview/frame), [bounds](https://developer.apple.com/documentation/uikit/uiview/bounds) — геометрия и предупреждение про `transform`.
- [hitTest(_:with:)](https://developer.apple.com/documentation/uikit/uiview/hittest(_:with:)) — алгоритм поиска view под пальцем и три условия пропуска.
- [layer](https://developer.apple.com/documentation/uikit/uiview/layer) и [layerClass](https://developer.apple.com/documentation/uikit/uiview/layerclass) — слой view.
- [translatesAutoresizingMaskIntoConstraints](https://developer.apple.com/documentation/uikit/uiview/translatesautoresizingmaskintoconstraints), [intrinsicContentSize](https://developer.apple.com/documentation/uikit/uiview/intrinsiccontentsize), [layoutMargins](https://developer.apple.com/documentation/uikit/uiview/layoutmargins) — Auto Layout.
- [setNeedsLayout()](https://developer.apple.com/documentation/uikit/uiview/setneedslayout()), [layoutIfNeeded()](https://developer.apple.com/documentation/uikit/uiview/layoutifneeded()), [layoutSubviews()](https://developer.apple.com/documentation/uikit/uiview/layoutsubviews()) — проход раскладки.
- [UIControl](https://developer.apple.com/documentation/uikit/uicontrol), [UIControl.Event](https://developer.apple.com/documentation/uikit/uicontrol/event), [addAction(_:for:)](https://developer.apple.com/documentation/uikit/uicontrol/addaction(_:for:)) — target-action.
- [UIScrollView](https://developer.apple.com/documentation/uikit/uiscrollview), [contentOffset](https://developer.apple.com/documentation/uikit/uiscrollview/contentoffset), [refreshControl](https://developer.apple.com/documentation/uikit/uiscrollview/refreshcontrol) — прокрутка.
- [UITableViewCell.contentView](https://developer.apple.com/documentation/uikit/uitableviewcell/contentview), [UICollectionReusableView](https://developer.apple.com/documentation/uikit/uicollectionreusableview), [UITableView.rowHeight](https://developer.apple.com/documentation/uikit/uitableview/rowheight) — ячейки и высота.
- [UIViewController](https://developer.apple.com/documentation/uikit/uiviewcontroller), [view](https://developer.apple.com/documentation/uikit/uiviewcontroller/view), [loadView()](https://developer.apple.com/documentation/uikit/uiviewcontroller/loadview()), [viewIsAppearing(_:)](https://developer.apple.com/documentation/uikit/uiviewcontroller/viewisappearing(_:)) — экран и его view.
- [addChild(_:)](https://developer.apple.com/documentation/uikit/uiviewcontroller/addchild(_:)) и [didMove(toParent:)](https://developer.apple.com/documentation/uikit/uiviewcontroller/didmove(toparent:)) — containment.
- [navigationItem](https://developer.apple.com/documentation/uikit/uiviewcontroller/navigationitem) — элемент навигации принадлежит экрану.
- [UIModalPresentationStyle.automatic](https://developer.apple.com/documentation/uikit/uimodalpresentationstyle/automatic) и [presentationController](https://developer.apple.com/documentation/uikit/uiviewcontroller/presentationcontroller) — во что превращается `.automatic` и кто ведёт показ.
- [dismiss(animated:completion:)](https://developer.apple.com/documentation/uikit/uiviewcontroller/dismiss(animated:completion:)) — кто закрывает модальный экран.
- [UIWindow](https://developer.apple.com/documentation/uikit/uiwindow), [makeKeyAndVisible()](https://developer.apple.com/documentation/uikit/uiwindow/makekeyandvisible()), [UIWindowScene](https://developer.apple.com/documentation/uikit/uiwindowscene), [UISceneSession](https://developer.apple.com/documentation/uikit/uiscenesession), [UIApplication](https://developer.apple.com/documentation/uikit/uiapplication) — верх дерева.
- [UIScreen.main](https://developer.apple.com/documentation/uikit/uiscreen/main) — почему Apple не рекомендует.
- [UIBarItem](https://developer.apple.com/documentation/uikit/uibaritem), [UINavigationItem](https://developer.apple.com/documentation/uikit/uinavigationitem), [UIGestureRecognizer](https://developer.apple.com/documentation/uikit/uigesturerecognizer), [CALayer](https://developer.apple.com/documentation/quartzcore/calayer) — объекты правой половины карты.
- [UITraitEnvironment](https://developer.apple.com/documentation/uikit/uitraitenvironment), [UITableViewDelegate](https://developer.apple.com/documentation/uikit/uitableviewdelegate), [UIScrollViewDelegate](https://developer.apple.com/documentation/uikit/uiscrollviewdelegate) — протоколы и их наследование.
- [class_getSuperclass(_:)](https://developer.apple.com/documentation/objectivec/class_getsuperclass(_:)) — функция рантайма из раздела 0.11.

→ [Глава 1. LaunchScreen vs AnimatedSplash — два экрана, оба «splash»](./01-launch-screen-vs-splash.md)
