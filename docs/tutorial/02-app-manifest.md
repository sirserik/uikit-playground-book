# Глава 2. AppManifest — конфиг одного mini-app

У нас в playground'е 13 мини-приложений. Каждое — со своим именем,
иконкой, цветом, набором гейтов запуска (одним нужен onboarding,
другому — age gate, третьему — биометрия при возврате из фона).

Можно было бы каждое описывать в коде явно:

```swift
// Так делать НЕ будем
class TodoApp { /* всё про Todo */ }
class NotesApp { /* всё про Notes */ }
class CalculatorApp { /* всё про Калькулятор */ }
```

Но это путь к 13 почти одинаковым классам с copy-paste-логикой и
гарантированными разногласиями: где-то splash 1.4 секунды, где-то 1.2,
где-то иконка 80pt, где-то 84pt. В реальном проекте через полгода в
этом не разберётся даже автор.

Поэтому мы делаем по-другому. Описываем mini-app **данными**, не кодом.
Один тип `AppManifest`, в нём поля — имя, иконка, цвет, флаги. И один
реестр `AppRegistry`, где лежит массив манифестов.

В этой главе разбираем оба.

## 2.1 Манифест как «паспорт» mini-app

> 💡 **Идея.** Манифест — это `struct`, который **описывает**
> mini-app: что показать в лаунчере, какие гейты запускать, какой VC
> делать main. Сам манифест ничего не **делает** — он только говорит,
> что нужно. Делают другие — `BootCoordinator`, `AppListViewController`.

Файл: `App/AppManifest.swift`. Начнём с identity-блока:

```swift
struct AppManifest {

    let id: String          // "todo", "notes", "calculator"
    let name: String        // "Список дел"
    let subtitle: String    // "UITableView, ячейка-чек, UserDefaults"
    let symbolName: String  // SF Symbol: "checklist"
    let brandColor: UIColor // .systemBlue
    let isReady: Bool       // false → ячейка в лаунчере помечена «СКОРО»
```

`id` — стабильный идентификатор. Им мы потом ключуем UserDefaults
(например, для флага «онбординг этого app пройден»). Менять `id` после
релиза — нельзя: потеряются все настройки пользователей.

`name`, `subtitle`, `symbolName`, `brandColor` — то, что видит
пользователь в лаунчере. Иконка приходит из SF Symbols
(`UIImage(systemName:)`), цвет используется и как фон splash'а, и как
tint nav-бара внутри mini-app.

`isReady` — флаг «реализовано или placeholder». Если `false`, в ячейке
лаунчера висит бейдж «СКОРО», и при тапе откроется не настоящий main,
а заглушка (мы её увидим в конце главы).

## 2.2 Флаги гейтов запуска

Дальше — флаги, которые включают/выключают каждый гейт цепочки запуска:

```swift
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

Каждое поле — это **одно решение**, которое `BootCoordinator` принимает
при запуске mini-app. Например:

- `hasAnimatedSplash = true` → перед main показать наш AnimatedSplash
  (см. Главу 1).
- `requiresPermission = .location` → перед main показать «зачем нам
  локация» (Глава 11).
- `hasAuthGate = true` → перед main показать экран логина, если
  пользователь не залогинен (Глава 12).
- `requiresBiometricOnResume = true` → при возврате из фона спросить
  Face ID (Глава 15).

Все флаги — `var` с дефолтными значениями. Это важно: когда мы создаём
манифест, не нужно перечислять все 13 полей, только те, что **отличают**
этот mini-app от дефолта.

> 💡 **Почему `var`, а не `let`.** Эти поля могут редактироваться
> «билдер-стилем» — создал манифест, потом меняешь один флаг. Если бы
> были `let`, пришлось бы передавать всё в инициализатор сразу. Сравни:
>
> ```swift
> // С var — лаконично, читается как чек-лист
> var m = AppManifest.placeholder(id: "music", ...)
> m.checksForceUpdate = true
> m.requiresAgeGate = true
> m.minAgeYears = 16
> ```
>
> Сами **identity-поля** (`id`, `name`, ...) остаются `let` — их
> менять после создания нельзя.

`requiresPermission` — опциональный enum, не Bool. Потому что
permission-ов несколько разных типов, и mini-app просит максимум **один**
основной. Если позже понадобится несколько одновременно — превратим в
`Set<PermissionKind>`. Пока YAGNI: ни одно из наших mini-app не просит
больше одного основного разрешения.

## 2.3 Фабрика `makeMain` — как создавать main-экран

Главное поле манифеста — `makeMain`:

```swift
    let makeMain: @MainActor () -> UIViewController
}
```

Это **функция**, которая возвращает готовый main VC. Манифест **не
держит сам VC** — он держит замыкание, которое умеет его создать.

Почему так? Тут две причины, и обе про память.

Первая — ленивая инициализация. `AppRegistry.allApps` создаётся при
старте процесса. Если бы каждый манифест держал готовый VC, мы бы
создали 13 контроллеров на старте. 13 view'ов, 13 наборов constraint'ов,
13 источников данных. Все висят в памяти, хотя пользователь, может, ни
в один и не зайдёт.

С замыканием — VC создаётся **в момент** запуска mini-app. Зашёл в
Калькулятор — создался `CalculatorViewController`. Вышел в лаунчер —
он деаллоцируется. В памяти живёт только тот mini-app, в котором
пользователь сейчас.

Вторая — повторный вход. Если пользователь зайдёт в Todo, выйдет,
зайдёт снова — мы хотим **свежий** VC. Если бы манифест держал готовый,
после первого выхода он остался бы с накопленным состоянием (прокрученный
список, открытые ячейки). С замыканием каждый вход — чистый старт.

`@MainActor` перед `()` — потому что UIKit-классы изолированы на main.
Без этого аннотации компилятор Swift 6 / Xcode 26 ругался бы:
«нельзя создать UIViewController из не-main контекста».

Вот как выглядит «реальное» поле в манифесте Todo:

```swift
AppManifest(
    id: "todo",
    name: "Список дел",
    subtitle: "UITableView, ячейка-чек, UserDefaults",
    symbolName: "checklist",
    brandColor: .systemBlue,
    isReady: true,
    hasAnimatedSplash: true,
    makeMain: { TodoListViewController() }
),
```

`makeMain: { TodoListViewController() }` — короткий closure, который
просто создаёт VC. Внутри can be что угодно: передача зависимостей,
DI-контейнер, конфигурация.

> 🛠 **Упражнение.** Открой `Apps/Todo/UI/TodoListViewController.swift`,
> добавь в `viewDidLoad` строку `print("TodoListVC created")`. Запусти
> приложение, зайди в Todo, нажми shake (Cmd+Ctrl+Z в симуляторе) для
> возврата в лаунчер, снова зайди в Todo. В консоли увидишь два
> сообщения «TodoListVC created» — потому что замыкание `makeMain`
> вызывается каждый раз заново.

## 2.4 Builder для placeholder-приложений

В лаунчере у нас должны быть **все** mini-apps — и реализованные, и те,
что только в плане («СКОРО»). Чтобы не дублировать одинаковые поля для
заглушек, делаем builder:

```swift
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

Используется так:

```swift
.placeholder(
    id: "calculator",
    name: "Калькулятор",
    subtitle: "UIStackView grid, состояние",
    symbolName: "function",
    brandColor: .systemPurple
)
```

Один из mini-apps в registry — placeholder. Когда мы реализуем главу
по Калькулятору, заменим placeholder на полный `AppManifest(...)` с
`makeMain: { CalculatorViewController() }`. Лаунчер автоматически
подхватит — пометка «СКОРО» снимется.

`PlaceholderViewController` — тривиальный VC: иконка молотка по центру
и текст «Это мини-приложение ещё не реализовано». Не пустой экран —
пользователь понимает, что попал куда хотел, просто здесь пока ничего нет.

## 2.5 AppRegistry — реестр всех mini-apps

Манифесты лежат в массиве в `App/AppRegistry.swift`:

```swift
enum AppRegistry {

    @MainActor
    static let allApps: [AppManifest] = [
        AppManifest(
            id: "todo",
            name: "Список дел",
            subtitle: "UITableView, ячейка-чек, UserDefaults, dummyjson",
            symbolName: "checklist",
            brandColor: .systemBlue,
            isReady: true,
            hasAnimatedSplash: true,
            makeMain: { TodoListViewController() }
        ),

        .placeholder(
            id: "notes",
            name: "Заметки",
            subtitle: "UITextView, файловое хранилище, поиск",
            symbolName: "note.text",
            brandColor: .systemYellow
        ),

        // ... ещё 11 mini-apps
    ]
}
```

Здесь три детали, которые легко проглядеть.

Это `enum`, а не `struct` или `class`. Я не хочу, чтобы кто-то случайно
создал инстанс `AppRegistry()` и подумал, что у него своё состояние.
Реестр **один на всё приложение**. `enum` без `case`'ов именно так
используется в Swift для группировки `static`-функций и свойств — идиома
называется «namespace enum».

Дальше — `@MainActor` на самой константе. Манифесты держат `makeMain` с
`@MainActor`, и `UIColor`-ы для `brandColor` тоже main-actor-isolated,
поэтому всю константу приходится объявить как main-actor. Без `@MainActor`
Xcode 26 выдаст ошибку при попытке к ней обратиться из VC.

И последнее — порядок имеет значение. Это `Array`, не `Set`. В каком
порядке мы перечислили манифесты — в таком они отрисуются в лаунчере.
Хочешь Todo первым — он первый. Notes между ними — окажется между.

## 2.6 Где это всё юзается

`AppListViewController` (лаунчер) при создании читает массив:

```swift
private let apps: [AppManifest] = AppRegistry.allApps
```

И отрисовывает их в `UITableView` — одна ячейка на манифест. При тапе
вызывает `launch(manifest)`, который передаёт манифест в
`BootCoordinator`. Дальше координатор смотрит на флаги:

```swift
if manifest.hasAnimatedSplash {
    showSplash()
} else {
    proceedAfterSplash()
}
```

И так — каждый гейт по очереди. То есть **манифест полностью описывает
поведение mini-app на этапе запуска**. Координатор без манифеста не
знает что делать; манифест без координатора — мёртвые данные. Они
работают только в паре.

> 💡 **Идея.** Манифест и координатор — паттерн «**конфигурация vs
> исполнение**». Конфигурация (`AppManifest`) — пассивная, легко
> читается, ничего не делает. Исполнение (`BootCoordinator`) — активное,
> читает конфигурацию и решает что показывать.

## 2.7 Бытовая аналогия

Манифест — это **меню в кафе**. Там описано: «Капучино — 600 ₸,
средний, с молоком». Меню само ничего не готовит и не наливает.

Бариста (координатор) читает меню, смотрит на твой заказ, и **делает**.
Если бы меню готовило кофе само — было бы магия. Если бы бариста
работал без меню — каждый раз сам бы решал что варить, и кофе был бы
разный каждый день.

`isReady: false` — это «временно нет в наличии». Пункт в меню остался,
ты его видишь, но заказать не получится.

## 2.8 Что мы не делаем

Манифест не описывает **внутреннюю** работу mini-app. Если в Калькуляторе
есть состояние «текущее число», `accumulator`, `pendingOperation` — это
живёт **внутри** `CalculatorEngine`/`CalculatorViewController`, не в
манифесте. Манифест знает только «как запустить», а не «как работать».

Это разграничение полезно держать в голове. Когда захочешь добавить
поле в манифест — спроси: это про **запуск** или про **работу**? Если
про работу — это поле должно жить в самом mini-app.

> 🛠 **Упражнение.** Открой `App/AppRegistry.swift`. Поменяй местами
> манифесты Todo и Notes (двигай весь блок). Запусти — в лаунчере
> Заметки теперь сверху, Todo вторым. Это и есть **декларативность**:
> поведение лаунчера определяется массивом, а не кодом таблицы.

## 📋 Что мы выучили

- `AppManifest` — `struct`, который **описывает** mini-app. Сам ничего
  не делает.
- Identity-поля (`id`, `name`, `symbolName`, `brandColor`) — `let`.
  `id` менять после релиза нельзя.
- Флаги гейтов запуска — `var` с дефолтными значениями. Создаёшь
  манифест и потом меняешь только нужные флаги.
- `makeMain: @MainActor () -> UIViewController` — **фабрика** main-VC.
  Замыкание, чтобы VC создавался лениво и заново при каждом входе.
- Builder `AppManifest.placeholder(...)` — короткая запись для
  «СКОРО»-приложений.
- `AppRegistry` — `enum` (namespace) с одной `static let allApps:
  [AppManifest]`. Помечен `@MainActor`, потому что внутри UIColor и
  closure'ы с UIKit.
- Манифест + координатор работают в паре: один — конфигурация, другой
  — исполнение.
- Манифест описывает **запуск**, не **работу** mini-app.

## Apple Developer Documentation

- [Structures and Classes — Swift Book](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/classesandstructures) — почему `AppManifest` — `struct` (value semantics, копируется при передаче).
- [Properties — Swift Book](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/properties) — различие `let` vs `var`, stored vs computed; используем для identity-полей и флагов гейтов.
- [`UIColor`](https://developer.apple.com/documentation/uikit/uicolor) — тип для `brandColor`; обрати внимание на dynamic-провайдеры для light/dark.
- [`UIImage.SymbolConfiguration`](https://developer.apple.com/documentation/uikit/uiimage/symbolconfiguration) — как параметризовать SF Symbol, который мы рендерим из `symbolName`.
- [SF Symbols](https://developer.apple.com/sf-symbols/) — каталог имён, которые можно класть в `symbolName`.

→ [Глава 3. PlaygroundWindow и shake-detect](./03-playground-window.md)
