# Глава 2. AppManifest — конфиг одного mini-app

В нашем playground'е десять мини-приложений и тур «Anatomy». У каждого
своё имя, иконка, цвет и свой набор **гейтов запуска** — экранов,
которые пользователь проходит до main-экрана: одному нужен onboarding,
другому — проверка возраста, третьему — Face ID при возврате из фона.

Можно было бы описать каждое mini-app отдельным классом:

```swift
// Так делать НЕ будем
class TodoApp { /* всё про Todo */ }
class NotesApp { /* всё про Notes */ }
class CalculatorApp { /* всё про Калькулятор */ }
```

Но это путь к десятку почти одинаковых классов со скопированной
логикой — и к неизбежным расхождениям: где-то splash длится 1.4
секунды, где-то 1.2, где-то иконка 80 точек, где-то 84. Через полгода
в этом не разберётся даже автор.

Поэтому мы описываем mini-app **данными, а не кодом**. Один тип
`AppManifest` с полями «имя, иконка, цвет, флаги» и один реестр
`AppRegistry` с массивом таких описаний. Код, который по этим данным
что-то делает, пишется один раз — в координаторе (глава 4) и лаунчере.

В этой главе разбираем оба файла и заглушку для ещё не готовых
mini-app.

## 2.1 Манифест как «паспорт» mini-app

> **Идея.** Манифест — это структура, которая **описывает** mini-app:
> что показать в лаунчере, какие гейты пройти, какой экран сделать
> главным. Сам манифест ничего не **делает**. Делают другие —
> `BootCoordinator` и `AppListViewController`.

Слово «манифест» взято из мира сборки программ: так называют файл с
описанием пакета — имя, версия, зависимости. Наш манифест —
такое же описание, только для mini-app.

Файл: `App/AppManifest.swift`. Начнём с блока «кто я» (identity):

```swift
import UIKit

struct AppManifest {

    // MARK: Identity — задаются один раз
    let id: String          // "todo", "notes", "calculator"
    let name: String        // "Список дел"
    let subtitle: String    // "UITableView, ячейка-чек, UserDefaults"
    let symbolName: String  // SF Symbol: "checklist"
    let brandColor: UIColor // .systemBlue
    let isReady: Bool       // false → в лаунчере пометка «СКОРО»
```

`id` — стабильный идентификатор, короткая строка латиницей. По нему
гейты хранят свои отметки в **UserDefaults** — маленьком встроенном
хранилище настроек вида «ключ → значение», которое переживает
перезапуск приложения. Например, онбординг из главы 6 запоминает
«этот mini-app онбординг уже показывал» под ключом
`onboarding.seen.todo`. Поэтому **менять `id` после релиза нельзя**:
ключи станут другими, и у всех пользователей «забудутся» пройденные
шаги.

`name`, `subtitle`, `symbolName`, `brandColor` — то, что пользователь
видит в лаунчере. Иконка — SF Symbol по имени (`UIImage(systemName:)`,
см. главу 1). Цвет работает трижды: иконка в строке лаунчера, фон
splash'а и цвет кнопок на панели навигации внутри mini-app.

`isReady` — готово ли mini-app. Если `false`, в строке лаунчера стоит
пометка «СКОРО», а по тапу откроется не настоящий экран, а заглушка
(раздел 2.4).

`// MARK:` — не код, а комментарий-закладка: Xcode показывает такие
заголовки в выпадающем меню над редактором, по ним удобно прыгать по
большому файлу.

## 2.2 Флаги гейтов запуска

Дальше — поля, которые включают и выключают каждый гейт:

```swift
    // MARK: Флаги гейтов запуска — у каждого значение по умолчанию
    var hasAnimatedSplash: Bool = true
    var splashDuration: TimeInterval = 1.4

    var hasOnboarding: Bool = false
    var onboardingPages: [OnboardingPage] = []

    var hasAuthGate: Bool = false
    var checksForceUpdate: Bool = false
    var hasMaintenanceCheck: Bool = false
    var requiresPermission: PermissionKind? = nil
    var hasPrivacyBlurOnBackground: Bool = false
    var requiresBiometricOnResume: Bool = false

    var requiresRegionPick: Bool = false
    var requiresAgeGate: Bool = false
    var minAgeYears: Int = 13
```

`TimeInterval` — это просто `Double`, число секунд: 1.4 — одна целая
и четыре десятых секунды.

Каждое поле — **одно решение**, которое координатор принимает при
запуске mini-app. Вот что за ними стоит и где это разбирается:

| Поле | Что включает | Глава |
|---|---|---|
| `hasAnimatedSplash`, `splashDuration` | наш splash и его длительность | 1 |
| `hasOnboarding`, `onboardingPages` | вводные экраны при первом запуске | 6 |
| `requiresPermission` | экран «зачем нам разрешение» до системного вопроса | 7 |
| `hasAuthGate` | вход в аккаунт, если пользователь не вошёл | 8 |
| `checksForceUpdate`, `hasMaintenanceCheck` | «обновите приложение» и «ведутся работы» по ответу сервера | 9 |
| `requiresRegionPick`, `requiresAgeGate`, `minAgeYears` | выбор региона и проверка возраста | 10 |
| `hasPrivacyBlurOnBackground`, `requiresBiometricOnResume` | размытие в переключателе приложений и Face ID при возврате | 11 |

Все флаги — `var` со значениями по умолчанию. Их тринадцать, и
перечислять все при создании манифеста не нужно — только те, что
**отличают** этот mini-app от обычного.

Как это работает. Для структуры Swift сам создаёт **поэлементный
инициализатор** (memberwise initializer): по параметру на каждое
хранимое свойство, **в том порядке, в каком свойства объявлены**. У
свойств со значением по умолчанию параметр становится необязательным.
Поэтому можно написать так:

```swift
AppManifest(
    id: "profile",
    name: "Профиль / Настройки",
    subtitle: "insetGrouped, разные типы ячеек",
    symbolName: "person.crop.circle",
    brandColor: .systemPurple,
    isReady: true,
    hasAuthGate: true,
    hasPrivacyBlurOnBackground: true,
    requiresBiometricOnResume: true,
    makeMain: { ProfileViewController() }
)
```

Пропущенные флаги возьмут значения по умолчанию. Одно правило:
указанные параметры должны идти в том же порядке, что и свойства в
структуре. Напишешь `requiresBiometricOnResume` раньше `hasAuthGate` —
компилятор скажет, что аргумент стоит не на своём месте.

(`ProfileViewController` появится в главе 19 — пока это просто пример
того, как будет выглядеть манифест с несколькими гейтами.)

> **Почему `var`, а не `let`.** Флаги удобно менять после создания
> манифеста — «создал, потом поправил одно поле»:
>
> ```swift
> var m = AppManifest.placeholder(id: "music", name: "Музыка",
>                                 subtitle: "AVPlayer", symbolName: "music.note",
>                                 brandColor: .systemRed)
> m.checksForceUpdate = true
> m.requiresAgeGate = true
> m.minAgeYears = 16
> ```
>
> Будь флаги `let`, так бы не получилось. А вот поля «кто я» (`id`,
> `name`…) — `let`: после создания их менять нельзя.

`requiresPermission` — опциональный enum, а не `Bool`. Разрешения
бывают разные (геолокация, фото, камера, уведомления), и нам важно не «нужно ли», а
«какое именно»: `nil` — никакое, `.location` — геолокация. Mini-app
просит максимум **одно** основное разрешение. Если когда-нибудь
понадобится несколько сразу, поле превратится в `Set<PermissionKind>`.
Пока это лишнее: ни одному нашему mini-app больше одного не нужно.

### Типы для гейтов: `PermissionKind` и `OnboardingPage`

Флаги ссылаются на два типа, которых ещё нет. Объявим их в том же
файле, над `AppManifest`:

```swift
/// Какое системное разрешение mini-app просит до main-экрана (глава 7).
enum PermissionKind: Sendable {
    case location
    case photoLibrary
    case camera
    case notifications
}

/// Одна страница онбординга (глава 6).
struct OnboardingPage {
    let symbolName: String
    let title: String
    let body: String
}
```

Экраны, которые эти типы используют, появятся в главах 6 и 7, а сами
типы нужны уже сейчас: без них не соберётся манифест. Держим их рядом
с `AppManifest`, потому что это часть его «словаря».

`Sendable` — пометка «значение можно безопасно передавать между
потоками». Простой enum без связанных значений и так безопасен, а
пометка делает это явным: в главе 7 значение `PermissionKind` уйдёт в
асинхронный запрос разрешения.

## 2.3 Фабрика `makeMain` — как создавать main-экран

Последнее поле манифеста — самое интересное:

```swift
    // MARK: Фабрика main-экрана
    let makeMain: @MainActor () -> UIViewController
}
```

Это **функция**, которая создаёт и возвращает main-экран. Манифест
хранит не готовый view controller, а замыкание, которое умеет его
сделать. Такой приём называется **фабрикой**: не сам товар, а цех,
который выпускает товар по заказу.

Зачем так? Две причины.

**Экран создаётся только когда нужен.** `AppRegistry.allApps`
создаётся при первом обращении к нему — когда создаётся
лаунчер. Если бы каждый манифест держал готовый экран, при запуске
playground'а сразу создались бы десять view controller'ов со своими
данными — хотя пользователь, может, не зайдёт ни в один. С замыканием
экран создаётся **в момент** запуска mini-app. Зашёл в Калькулятор —
создался `CalculatorViewController`. Вышел в лаунчер — на него больше
никто не ссылается, и он освобождается из памяти. В памяти живёт
только то mini-app, в котором пользователь сейчас.

**Каждый вход — с чистого листа.** Зашёл в «Список дел», вышел,
зашёл снова — хотим **свежий** экран. Если бы манифест держал один и
тот же экземпляр, при втором входе ты увидел бы его в том состоянии,
в каком оставил: прокрученный список, открытое меню. С фабрикой
каждый вход — новый экземпляр.

`@MainActor` в типе замыкания говорит: «вызывать это замыкание можно
только на главном потоке». Вызывать его в другом месте всё равно
нельзя: внутри создаётся view controller, а весь UIKit работает на
главном потоке (см. раздел 0.2 введения).

Строго говоря, в нашем проекте эту пометку можно не писать: с Default
Actor Isolation = MainActor замыкание, написанное в нашем коде, и так
выполняется на главном потоке. Но стоит перенести `AppManifest` в
модуль без этой настройки (например, в отдельный Swift-пакет), и без
`@MainActor` компилятор Swift 6 откажется собирать реестр: «static
property 'allApps' is not concurrency-safe» — глобальная константа не
может хранить значение, которое нельзя безопасно передавать между
потоками. С пометкой такое замыкание разрешено передавать между
потоками (всё равно выполнится оно только на главном), и ошибки нет.
Мы пишем `@MainActor` явно, чтобы код не зависел от настройки проекта.

Когда mini-app будет готово (например, «Список дел» после главы 12),
его манифест будет выглядеть так:

```swift
AppManifest(
    id: "todo",
    name: "Список дел",
    subtitle: "UITableView, ячейка-чек, UserDefaults, dummyjson",
    symbolName: "checklist",
    brandColor: .systemBlue,
    isReady: true,
    makeMain: { TodoListViewController() }
)
```

`makeMain: { TodoListViewController() }` — короткое замыкание, которое
просто создаёт экран. Внутри может быть что угодно: передача
зависимостей, настройка, выбор экрана по условию.

## 2.4 Заготовка для ещё не готовых mini-app

В лаунчере должны быть **все** mini-app — и готовые, и те, что пока
только в плане («СКОРО»). Чтобы не повторять одинаковые поля у каждой
заглушки, заведём **фабричный метод** — статическую функцию, которая
собирает манифест. Файл `App/AppManifest+Placeholder.swift` (плюс в
имени файла — принятое в Swift обозначение «расширение такого-то
типа»):

```swift
import UIKit

extension AppManifest {
    static func placeholder(id: String,
                            name: String,
                            subtitle: String,
                            symbolName: String,
                            brandColor: UIColor) -> AppManifest {
        AppManifest(
            id: id,
            name: name,
            subtitle: subtitle,
            symbolName: symbolName,
            brandColor: brandColor,
            isReady: false,
            hasAnimatedSplash: true,
            makeMain: { PlaceholderViewController(name: name) }
        )
    }
}
```

Заглушка — это манифест с `isReady: false` и экраном
`PlaceholderViewController`. Обрати внимание: замыкание `makeMain`
**захватывает** параметр `name` — запоминает его значение, чтобы
использовать позже, когда замыкание вызовут.

Используется так (тип `AppManifest` Swift выведет из контекста, поэтому
достаточно точки):

```swift
.placeholder(
    id: "calculator",
    name: "Калькулятор",
    subtitle: "UIStackView grid, состояние, haptics",
    symbolName: "function",
    brandColor: .systemIndigo
)
```

Когда в главе 14 появится настоящий Калькулятор, эту запись заменим на
полный `AppManifest(...)` с `isReady: true` и `makeMain: {
CalculatorViewController() }`. Лаунчер подхватит это сам: пометка
«СКОРО» пропадёт.

### Экран-заглушка

`App/PlaceholderViewController.swift` — простой экран: иконка молотка
по центру и текст «ещё не реализовано». Это лучше пустого экрана:
пользователь понимает, что попал куда хотел, просто здесь пока ничего
нет.

```swift
import UIKit

/// Заглушка для mini-app, которое ещё не реализовано.
final class PlaceholderViewController: UIViewController {

    private let name: String

    init(name: String) {
        self.name = name
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) не используется: экран создаётся только кодом")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = name
        view.backgroundColor = .systemBackground

        let config = UIImage.SymbolConfiguration(pointSize: 56)
        let icon = UIImageView(image: UIImage(systemName: "hammer.fill",
                                              withConfiguration: config))
        icon.tintColor = .secondaryLabel

        let label = UILabel()
        label.text = "«\(name)» ещё не реализовано.\n"
            + "Встряхни устройство, чтобы вернуться в лаунчер."
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .secondaryLabel

        let stack = UIStackView(arrangedSubviews: [icon, label])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        let guide = view.readableContentGuide
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
        ])
    }
}
```

Что здесь нового по сравнению со splash'ем из главы 1.

`title = name` — заголовок экрана. Координатор покажет main-экран
внутри панели навигации (глава 4), и заголовок появится на ней.

`.systemBackground`, `.secondaryLabel` — **семантические цвета**: их
имя говорит не «какой цвет», а «для чего». `systemBackground` — фон
(белый в светлой теме, чёрный в тёмной), `secondaryLabel` —
второстепенный текст (серый, в обеих темах читаемый). Пишешь
семантический цвет — и тёмная тема работает сама.

`UIStackView` — контейнер, который сам выстраивает вложенные view в
столбик (`axis = .vertical`) или в строку, с промежутком `spacing` —
здесь 16 точек. `alignment = .center` — каждый элемент по центру
столбика. Иконке и лейблу constraints не нужны: их расставляет стек,
а constraints задаём только самому стеку.

`readableContentGuide` — полоса «удобной для чтения ширины». На
iPhone она почти совпадает с полями экрана, а на широком iPad
ограничивает ширину текста, чтобы строка не растянулась на весь экран
(длинные строки читать тяжело). Стек привязан к ней слева и справа и
стоит по центру safe area по вертикали.

Текст склеен из двух строк через `+`, а `\n` внутри — перевод строки.

## 2.5 AppRegistry — реестр всех mini-app

Все манифесты лежат в одном массиве, в `App/AppRegistry.swift`. Пока
ни одно mini-app не готово, реестр состоит из заглушек:

```swift
import UIKit

enum AppRegistry {

    static let allApps: [AppManifest] = [
        .placeholder(id: "todo", name: "Список дел",
                     subtitle: "UITableView, ячейка-чек, UserDefaults, dummyjson",
                     symbolName: "checklist", brandColor: .systemBlue),
        .placeholder(id: "notes", name: "Заметки",
                     subtitle: "UITextView, файловое хранилище, поиск",
                     symbolName: "note.text", brandColor: .systemYellow),
        .placeholder(id: "calculator", name: "Калькулятор",
                     subtitle: "UIStackView grid, состояние, haptics",
                     symbolName: "function", brandColor: .systemIndigo),
        .placeholder(id: "weather", name: "Погода",
                     subtitle: "URLSession, pull-to-refresh, skeleton",
                     symbolName: "cloud.sun.fill", brandColor: .systemTeal),
        .placeholder(id: "gallery", name: "Галерея",
                     subtitle: "Compositional layout, пагинация, photo viewer",
                     symbolName: "photo.on.rectangle", brandColor: .systemPink),
        .placeholder(id: "music", name: "Музыка",
                     subtitle: "AVPlayer, mini-player, full sheet",
                     symbolName: "music.note", brandColor: .systemRed),
        .placeholder(id: "chat", name: "Чат",
                     subtitle: "Двусторонние ячейки, клавиатура",
                     symbolName: "bubble.left.and.bubble.right.fill", brandColor: .systemGreen),
        .placeholder(id: "profile", name: "Профиль / Настройки",
                     subtitle: "insetGrouped, разные типы ячеек",
                     symbolName: "person.crop.circle", brandColor: .systemPurple),
        .placeholder(id: "tabbar", name: "Custom Tab Bar",
                     subtitle: "Свой контейнер вместо UITabBarController",
                     symbolName: "square.split.bottomrightquarter", brandColor: .systemBrown),
        .placeholder(id: "layouts", name: "Сложные экраны",
                     subtitle: "Stretchy header, sticky, parallax",
                     symbolName: "rectangle.3.group", brandColor: .systemCyan),
        .placeholder(id: "anatomy", name: "Anatomy",
                     subtitle: "Тур по всем гейтам запуска",
                     symbolName: "list.bullet.rectangle", brandColor: .systemGray),
    ]
}
```

Три детали, которые легко проглядеть.

**Это `enum` без `case`'ов**, а не `struct` или `class`. Экземпляр
такого enum создать нельзя вообще: `AppRegistry()` не скомпилируется.
Значит, никто не заведёт «свой» реестр с отдельным состоянием —
реестр один на всё приложение. Пустой enum как «папка» для
статических свойств и функций — обычный приём в Swift, его называют
**namespace enum** (enum-пространство имён).

**Про изоляцию.** В нашем режиме (Default Actor Isolation = MainActor)
`AppRegistry` и его `allApps` автоматически принадлежат главному
потоку, поэтому отдельная пометка `@MainActor` здесь не нужна. Лаунчер
тоже работает на главном потоке, и читает массив без всяких `await`.

**Порядок имеет значение.** Это массив (`Array`), а не множество
(`Set`): в каком порядке перечислены манифесты, в таком они и
появятся в лаунчере.

Один цвет выбран не случайно: `.systemCyan` появился только в iOS 15.
На iOS 14 такого свойства нет, но наш минимум — iOS 15, так что его
можно использовать без проверок версии.

## 2.6 Кто читает манифест

Лаунчер (`AppListViewController`, глава 4) при создании берёт массив:

```swift
private let apps: [AppManifest] = AppRegistry.allApps
```

и показывает его в таблице — по строке на манифест. По тапу отдаёт
манифест координатору, а тот смотрит на флаги:

```swift
if manifest.hasAnimatedSplash {
    showSplash()
} else {
    proceedAfterSplash()
}
```

И так — для каждого гейта по очереди. То есть **манифест полностью
описывает поведение mini-app при запуске**. Координатор без манифеста
не знает, что делать; манифест без координатора — мёртвые данные.
Работают они только в паре.

> **Идея.** Манифест и координатор — это разделение «**конфигурация
> и исполнение**». Конфигурация (`AppManifest`) пассивна, легко
> читается, ничего не делает. Исполнение (`BootCoordinator`) активно:
> читает конфигурацию и решает, что показать.

## 2.7 Бытовая аналогия

Манифест — **меню в кафе**. В нём написано: «Капучино — 900 ₸,
средний, на обычном молоке». Меню само ничего не готовит.

Бариста (координатор) читает меню, смотрит на твой заказ и **делает**.
Если бы бариста работал без меню, каждый раз решал бы сам, что
варить, и кофе был бы каждый день разный.

`isReady: false` — пометка «скоро в меню». Пункт ты видишь, но заказать
пока нельзя: принесут табличку «готовим».

**Упражнение 2.1.** Докажи, что при выходе в лаунчер экран mini-app
действительно освобождается из памяти, а при повторном входе
создаётся новый. Добавь в `PlaceholderViewController` что-нибудь, что
напечатает сообщение при создании экрана и при его освобождении.
Проверять удобнее после главы 5, когда фундамент соберётся целиком.

## 2.8 Что манифест не описывает

Манифест не описывает **внутреннюю** работу mini-app. Если у
Калькулятора есть «текущее число» и «отложенная операция», это живёт
**внутри** калькулятора, а не в манифесте. Манифест знает «как
запустить», а не «как работать».

Это различие полезно держать в голове. Хочешь добавить в манифест
поле — спроси себя: это про **запуск** или про **работу**? Если про
работу — полю место внутри самого mini-app.

**Упражнение 2.2.** В `AppRegistry.swift` поменяй местами «Список
дел» и «Заметки» (перенеси целиком строки `.placeholder(...)`). Что
изменится в лаунчере? Какой код таблицы для этого пришлось поменять?

**Упражнение 2.3.** Сделай так, чтобы «Чат» открывался **без** splash
— сразу main-экран. Меняй только `AppRegistry.swift`.

## Ответы к упражнениям

**2.1.** Добавь в `PlaceholderViewController` строку в конец `init` и
метод `deinit` — его Swift вызывает прямо перед освобождением объекта:

```swift
    init(name: String) {
        self.name = name
        super.init(nibName: nil, bundle: nil)
        print("Создан экран «\(name)»")
    }

    deinit {
        print("Освобождён экран «\(name)»")
    }
```

Зайди в любое mini-app, встряхни (⌃⌘Z), зайди снова. В консоли Xcode
появится «Создан экран…», после встряхивания — «Освобождён экран…», и
при повторном входе — снова «Создан экран…». Два «Создан» подряд с
«Освобождён» между ними и доказывают, что `makeMain` каждый раз
создаёт новый экран, а старый не задерживается в памяти.

**2.2.** «Заметки» станут первой строкой, «Список дел» — второй. Код
таблицы менять не пришлось: лаунчер показывает массив в том порядке,
в каком он записан. В этом и смысл описания данными — поведение
меняется правкой данных.

**2.3.** Заглушку создаёт `.placeholder(...)`, а флаги — `var`,
поэтому можно создать манифест и поправить его прямо внутри массива
через замыкание, которое сразу же вызывается:

```swift
        {
            var chat = AppManifest.placeholder(
                id: "chat", name: "Чат",
                subtitle: "Двусторонние ячейки, клавиатура",
                symbolName: "bubble.left.and.bubble.right.fill",
                brandColor: .systemGreen)
            chat.hasAnimatedSplash = false
            return chat
        }(),
```

Запись `{ ... }()` — замыкание, которое объявили и тут же вызвали: его
результат (готовый манифест) и попадает в массив. При запуске Чата
координатор увидит `hasAnimatedSplash == false`, пропустит
`showSplash()` и сразу вызовет `proceedAfterSplash()`, а оттуда
цепочка дойдёт до main-экрана.

## Что мы выучили

- `AppManifest` — структура, которая **описывает** mini-app. Сама
  ничего не делает.
- Поля «кто я» (`id`, `name`, `symbolName`, `brandColor`…) — `let`.
  `id` после релиза менять нельзя: на нём держатся ключи в
  UserDefaults.
- Флаги гейтов — `var` со значениями по умолчанию: в поэлементном
  инициализаторе указываешь только отличия, в порядке объявления
  свойств.
- `PermissionKind` и `OnboardingPage` объявлены рядом с манифестом:
  они нужны ему уже сейчас, а экраны для них появятся в главах 6–7.
- `makeMain: @MainActor () -> UIViewController` — **фабрика**
  main-экрана: экран создаётся лениво и заново при каждом входе.
  `@MainActor` делает код независимым от настройки изоляции проекта.
- `AppManifest.placeholder(...)` — короткая запись для заглушек
  «СКОРО»; экран-заглушка — `PlaceholderViewController`.
- `AppRegistry` — пустой enum-«папка» с `static let allApps`. Порядок
  массива = порядок в лаунчере.
- Манифест + координатор = конфигурация + исполнение. Манифест
  описывает **запуск**, а не **работу** mini-app.

## Apple Developer Documentation

- [Structures and Classes — Swift Book](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/classesandstructures) — почему `AppManifest` — структура и откуда берётся поэлементный инициализатор.
- [Properties — Swift Book](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/properties) — `let` и `var`, значения по умолчанию у свойств.
- [Deinitialization — Swift Book](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/deinitialization) — `deinit` из упражнения 2.1.
- [`UIColor`](https://developer.apple.com/documentation/uikit/uicolor) — тип `brandColor`; системные цвета сами подстраиваются под светлую и тёмную тему.
- [`UIStackView`](https://developer.apple.com/documentation/uikit/uistackview) — контейнер, который выстраивает элементы заглушки в столбик.
- [`UserDefaults`](https://developer.apple.com/documentation/foundation/userdefaults) — хранилище «ключ → значение», в котором гейты запоминают свои отметки по `id`.
- [SF Symbols](https://developer.apple.com/sf-symbols/) — каталог имён, которые можно класть в `symbolName`.

→ [Глава 3. PlaygroundWindow — UIWindow с shake-detect](./03-playground-window.md)
