# Глава 5. Lifecycle App → Scene → VC и @MainActor под капотом

В четырёх предыдущих главах мы строили цепочку запуска mini-app:
splash, манифест, окно, координатор, лаунчер. Но под всем этим лежит
цепочка **более фундаментальная** — та, что запускается ещё до того,
как выполнится хоть одна наша строчка.

Когда пользователь тапает иконку, iOS не сразу зовёт твой
`SceneDelegate`. Сначала запускается процесс, создаётся объект
`UIApplication`, вызывается делегат приложения, система читает
настройки сцен из `Info.plist`, создаёт сцену — и **только потом**
вызывает `scene(_:willConnectTo:options:)`, где мы создаём окно.

В этой главе разбираем эту цепочку — **жизненный цикл** (lifecycle)
приложения: порядок состояний, через которые оно проходит («запускается
→ активно → в фоне → …»), и методы, которые iOS вызывает на каждом
переходе. Заодно разберём, почему весь код книги работает на главном
потоке и что для этого делает настройка Xcode 26 Default Actor
Isolation. А в конце соберём фундамент в работающий проект.

## 5.1 App → Scene → VC: три уровня

С iOS 13 у приложения на UIKit **три** уровня сверху вниз:

```
UIApplication                  ← процесс, один на всё приложение
   │
   └─ UIWindowScene            ← сцена: один «экземпляр» интерфейса
        │                         (запись о ней — UISceneSession)
        └─ PlaygroundWindow    ← наше окно (глава 3)
             │
             └─ rootViewController (лаунчер, splash, main mini-app)
                  │
                  └─ вложенные экраны и view…
```

**Сцена** (`UIScene`, для экранов — `UIWindowScene`) — это один
«экземпляр» интерфейса приложения со своими окнами. До iOS 13 сцен не
было: окно принадлежало прямо `UIApplication`, и у приложения мог быть
ровно один интерфейс. Сцены Apple ввела ради iPad: там одно приложение
может быть открыто в нескольких окнах сразу — две заметки рядом в
Split View, несколько окон в Stage Manager. Каждое такое окно — своя
сцена.

**`UISceneSession`** — «карточка» сцены, которую хранит система: какой
тип сцены, с какой конфигурацией создана, какое состояние сохранено.
Сцену система может выгрузить из памяти (например, давно не
открывавшееся окно на iPad), а карточка останется — и по ней сцену
потом восстановят.

На iPhone сцена обычно одна, но устройство то же самое. Шаблон Xcode
так и настраивает: в `Info.plist` ключ **Enable Multiple Windows**
(`UIApplicationSupportsMultipleScenes`) = `NO` — у нашего приложения
будет одна сцена даже на iPad.

Сцены — уже не выбор, а требование. В технической заметке TN3187 Apple
пишет: в первом крупном выпуске iOS после iOS 26 приложение,
собранное с новым SDK и не перешедшее на сцены, **не запустится**.
Поэтому книга с самого начала использует `SceneDelegate`.

На каждом уровне — свой **делегат**. Делегат — объект, которому
система сообщает о событиях и у которого спрашивает решения («что
сделать при запуске?», «приложение ушло в фон»). Мы встречали делегата
у таблицы в главе 4: там таблица сообщала лаунчеру «тапнули строку».
Здесь так же:

- `AppDelegate` — события процесса: запуск, получение токена
  push-уведомлений, конфигурация новых сцен;
- `SceneDelegate` — события одной сцены: подключилась, стала
  активной, ушла в фон;
- `UIViewController` — события одного экрана: `viewDidLoad`,
  `viewWillAppear`, `viewDidDisappear` (глава 1, раздел 1.3).

## 5.2 Info.plist: как iOS находит наши делегаты

**`Info.plist`** — файл-анкета приложения: название, версия,
минимальная версия iOS, разрешения, настройки сцен. iOS читает его
**до** запуска твоего кода. Часть ключей Xcode 26 генерирует из
настроек сборки (они начинаются с `INFOPLIST_KEY_…`), часть лежит в
самом файле `Info.plist`.

За сцены отвечает ключ **Application Scene Manifest**
(`UIApplicationSceneManifest`). После того как мы во введении удалили
строку со storyboard (раздел 0.1), в нём осталось:

```
Application Scene Manifest
├── Enable Multiple Windows: NO
└── Scene Configuration
    └── Application Session Role
        └── Item 0
            ├── Configuration Name: Default Configuration
            └── Delegate Class Name: $(PRODUCT_MODULE_NAME).SceneDelegate
```

`Delegate Class Name` — какой класс создать делегатом сцены.
`$(PRODUCT_MODULE_NAME)` Xcode при сборке заменит на имя модуля
(название цели, где пробелы и дефисы заменены на `_`): Swift-классы
живут внутри модуля, и полное имя класса — `Модуль.SceneDelegate`.

`Configuration Name` — название этой конфигурации. Его же возвращает
`AppDelegate` (сразу ниже). Имена должны совпадать буква в букву:
опечатка — и iOS не найдёт конфигурацию, `SceneDelegate` не создастся,
а экран останется чёрным.

## 5.3 AppDelegate — что туда класть, а что нет

В нашем проекте `App/AppDelegate.swift` минимальный:

```swift
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions:
                         [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        true
    }

    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        UISceneConfiguration(name: "Default Configuration",
                             sessionRole: connectingSceneSession.role)
    }
}
```

`@main` — атрибут, который говорит компилятору: «это точка входа в
программу». Для класса-делегата приложения компилятор сам создаст
функцию `main()`, которая запустит `UIApplication` и назначит этот
класс его делегатом.

`AppDelegate` наследует `UIResponder` — поэтому он и стоит последним в
responder chain (глава 3).

`didFinishLaunchingWithOptions` — «процесс запущен, приложение готово
к работе». Возвращаем `true` — «всё в порядке». Шаблон Xcode пишет тут
`return true`; у нас тело из одного выражения, и Swift разрешает не
писать `return`.

`configurationForConnecting` — iOS создаёт новую сцену и спрашивает:
«с какой конфигурацией?». Отвечаем: с той, что в `Info.plist`
называется «Default Configuration», для той же роли
(`sessionRole` — роль сцены: обычное окно приложения, внешний экран и
т. п.).

Что **обычно** живёт в `AppDelegate` (а не в `SceneDelegate`):

- регистрация push-уведомлений (`registerForRemoteNotifications`) и
  получение **device token** — адреса устройства, по которому сервер
  Apple доставит push (глава 41);
- регистрация фоновых задач `BGTaskScheduler` — её нужно сделать до
  конца запуска приложения;
- инициализация SDK аналитики и отчётов о сбоях (Firebase, Sentry и
  подобных).

Что **не должно**: создание окна и интерфейса — это работа
`SceneDelegate`. Туда же в приложении со сценами приходят и ссылки:
открытие приложения по URL и по **Universal Link** (обычной ссылке
`https://…`, которую iOS открывает в приложении, а не в браузере).
Их получает `SceneDelegate` — в `scene(_:openURLContexts:)`,
`scene(_:continue:)`, а при холодном старте — в
`connectionOptions` метода `willConnectTo` (подробно — в главе 41).
Методы `AppDelegate` для ссылок в приложении со сценами не
вызываются.

Наш `AppDelegate` почти пуст, потому что ничего из списка мы пока не
делаем. Метод `application(_:didDiscardSceneSessions:)`, который
создаёт шаблон, мы удалили: он нужен, чтобы подчистить данные
закрытых сцен, а у нас таких данных нет.

## 5.4 SceneDelegate — где собирается всё дерево

С точки зрения интерфейса жизнь приложения начинается здесь: создаётся
окно и ставится первый экран. `App/SceneDelegate.swift` целиком:

```swift
import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    private var launcherRoot: UIViewController?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = PlaygroundWindow(windowScene: windowScene)
        let launcher = AppListViewController()
        let nav = UINavigationController(rootViewController: launcher)
        nav.navigationBar.prefersLargeTitles = true

        launcher.windowProvider = { [weak window] in window }
        launcher.onReturnToLauncher = { [weak self, weak window] in
            guard let self, let window, let root = self.launcherRoot else { return }
            UIView.transition(with: window, duration: 0.35,
                              options: .transitionCrossDissolve,
                              animations: { window.rootViewController = root })
        }

        launcherRoot = nav
        window.rootViewController = nav
        window.makeKeyAndVisible()
        self.window = window
    }
}
```

Разберём по частям.

`willConnectTo` iOS вызывает, когда сцена подключается к приложению:
при запуске или когда пользователь открывает новое окно на iPad.

`guard let windowScene = scene as? UIWindowScene` — сцена приходит
как общий тип `UIScene`. Окна бывают только у `UIWindowScene`, поэтому
приводим тип; если это какая-то другая сцена — выходим.

```swift
let window = PlaygroundWindow(windowScene: windowScene)
```

`PlaygroundWindow` — наше окно из главы 3. Параметр `windowScene`
привязывает окно к сцене: без привязки окно не появится на экране.

`AppListViewController()` — лаунчер из главы 4. Оборачиваем его в
`UINavigationController` ради панели навигации с **большим заголовком**
(`prefersLargeTitles = true`): «UIKit Playground» крупным шрифтом, как
в «Настройках», который при прокрутке списка сжимается в обычный.

Этот `UINavigationController` мы **сохраняем** в `launcherRoot`:

```swift
launcherRoot = nav
```

`launcherRoot` — приватное свойство `SceneDelegate`. Когда
пользователь зайдёт в mini-app, координатор заменит
`window.rootViewController` на splash, потом на main. Лаунчер уйдёт из
окна, но **не из памяти**: на него по-прежнему указывает сильная
ссылка `launcherRoot`.

> **Зачем сохранять.** Без `launcherRoot` после первой замены
> корневого экрана лаунчер освободился бы, и при возврате пришлось бы
> создавать новый: прокрутка списка сбросилась бы. С сохранённой
> ссылкой возвращаемся к **тому же** лаунчеру, в том же состоянии. Есть
> и вторая причина: лаунчер держит активный координатор (глава 4). Если
> освободить лаунчер, освободится и координатор — и mini-app «зависнет»
> посреди запуска.

`launcher.windowProvider` и `launcher.onReturnToLauncher` — те самые
замыкания, которые лаунчер ждёт снаружи (глава 4, раздел 4.6):
«вот так добраться до окна» и «вот так вернуть лаунчер на экран».
Возврат — та же анимация перекрёстного растворения, что у `setRoot` в
координаторе: 0.35 секунды.

Списки захвата здесь такие.

- `{ [weak window] in window }` — лаунчер хранит это замыкание всё
  время. Со слабой ссылкой замыкание не продлевает окну жизнь: если
  сцена закроется и окно освободится, замыкание вернёт `nil`, а не
  «воскресит» ненужное окно. К тому же окно косвенно держит лаунчер
  (через `rootViewController`), а сильная ссылка обратно замкнула бы
  круг.
- `[weak self, weak window]` в `onReturnToLauncher` — та же логика:
  `SceneDelegate` держит лаунчер (через `launcherRoot`), лаунчер держит
  замыкание, и сильный захват `self` дал бы цикл сильных ссылок.
  `guard let self, let window, let root` — если чего-то уже нет,
  просто выходим.

`window.makeKeyAndVisible()` — окно становится ключевым и видимым
(глава 3). `self.window = window` — сохраняем окно, иначе оно
освободится и экран будет чёрным.

**Упражнение 5.1.** Чему равен `window.rootViewController` в тот
момент, когда пользователь находится внутри main-экрана mini-app? А
`launcherRoot`? Что из этого показано на экране?

## 5.5 Порядок событий при запуске

Упрощённый таймлайн **холодного старта** (приложения нет в памяти):

```
[тап по иконке]
 → iOS показывает launch screen (глава 1)
 → процесс запускается, создаётся UIApplication и AppDelegate
 → AppDelegate.application(_:didFinishLaunchingWithOptions:)
 → AppDelegate.application(_:configurationForConnecting:options:)
 → SceneDelegate.scene(_:willConnectTo:options:)  ← создаём окно и лаунчер
 → SceneDelegate.sceneWillEnterForeground(_:)
 → SceneDelegate.sceneDidBecomeActive(_:)          ← приложение готово к касаниям
 → launch screen исчезает, виден лаунчер
```

Сколько миллисекунд уходит на каждый шаг, зависит от устройства,
размера приложения и того, что ты делаешь в этих методах. Порядок же
одинаков всегда: делегат приложения → делегат сцены → первый экран →
активная сцена. Поэтому в `didFinishLaunching` и `willConnectTo` не
делают ничего долгого (скачивание, тяжёлые вычисления): пока они не
вернут управление, пользователь смотрит на launch screen.

**Тёплый старт** — приложение уже в памяти, пользователь вернулся к
нему из фона. Процесс и сцена уже есть, поэтому `didFinishLaunching` и
`willConnectTo` не вызываются — сразу `sceneWillEnterForeground` и
`sceneDidBecomeActive`.

Состояния сцены стоит различать:

- **active** (активна) — на экране и получает касания;
- **inactive** (неактивна) — на экране, но касания не получает:
  пользователь открыл переключатель приложений, опустил Центр
  уведомлений или пришёл входящий звонок;
- **background** (в фоне) — не на экране; через несколько секунд iOS
  обычно приостанавливает такое приложение.

## 5.6 Lifecycle-уведомления, которые мы используем

В главе 11 появится `LifecycleSecurityController` — он размывает
экран mini-app, когда приложение уходит в фон. Подписывается он не на
методы `SceneDelegate`, а на **уведомления** `NotificationCenter`.

**`NotificationCenter`** — общая «доска объявлений» приложения. Одни
объекты вешают объявления («сцена сейчас станет неактивной»), другие
подписываются на нужные и получают их. Отправитель не знает, кто
подписан, подписчик не знает, кто отправил. Системные события сцены
UIKit публикует там сам.

```swift
let bgObs = NotificationCenter.default.addObserver(
    forName: UIScene.willDeactivateNotification,
    object: nil,
    queue: .main
) { [weak self] _ in
    MainActor.assumeIsolated { self?.handleEnterBackground() }
}
```

- `forName:` — на какое объявление подписываемся.
- `object: nil` — от любого отправителя, то есть от любой сцены.
- `queue: .main` — выполнить замыкание на главной очереди (главном
  потоке).
- Замыкание — что сделать. Про `MainActor.assumeIsolated` — в
  разделе 5.8.
- Возвращённое значение `bgObs` — **жетон подписки**. Его надо
  сохранить и, когда подписка больше не нужна, отдать в
  `NotificationCenter.default.removeObserver(bgObs)`. Иначе замыкание
  продолжит вызываться — даже если объект, для которого подписывались,
  давно не нужен.

Почему уведомления, а не методы `SceneDelegate`? Контроллер защиты
живёт **внутри координатора**, а не в `SceneDelegate`. Если бы
`SceneDelegate` знал про координатор и сам звал его методы, два
независимых объекта оказались бы связаны. Уведомления развязывают их:
контроллер слушает «когда что произойдёт», не зная, кто сообщает.

Полезные уведомления жизненного цикла:

- `UIScene.willDeactivateNotification` — сцена сейчас станет
  неактивной: пользователь открывает переключатель приложений, уходит
  на домашний экран, пришёл звонок;
- `UIScene.didActivateNotification` — сцена снова активна;
- `UIScene.didEnterBackgroundNotification` /
  `UIScene.willEnterForegroundNotification` — ушла в фон / вот-вот
  вернётся на экран;
- `UIApplication.didReceiveMemoryWarningNotification` — системе не
  хватает памяти. Самое время освободить кэши: приложение, которое
  занимает много памяти, iOS может завершить.

Любой объект может на них подписаться — `SceneDelegate` этого не
контролирует.

## 5.7 MainActor под капотом

Во введении (раздел 0.2) мы включили в проекте три настройки. Теперь
посмотрим, что они меняют в коде.

**Весь UIKit помечен `@MainActor` самой Apple.** `UIView`,
`UIViewController`, `UILabel` — все их свойства и методы можно трогать
только с главного потока. Твой `class TodoListViewController:
UIViewController` наследует эту пометку **независимо от настроек
проекта**: экраны всегда на главном потоке.

**Default Actor Isolation = MainActor меняет всё остальное** — твои
собственные типы, которые ни от чего из UIKit не наследуют: модели,
сервисы, хранилища, свободные функции.

```swift
final class Counter {
    var value = 0
}
```

- Без настройки `Counter` ни к какому актору не привязан (nonisolated).
  Его можно трогать откуда угодно — и из двух потоков одновременно,
  получив гонку данных.
- С настройкой `Counter` — `@MainActor`. Компилятор следит, чтобы с
  ним работали только с главного потока.

То есть с этой настройкой **по умолчанию** весь твой код живёт там же,
где интерфейс, и гонка «обновил лейбл из фона» становится ошибкой
компиляции, а не редким падением у пользователя. В режиме Swift 6
большинство таких нарушений — ошибки, в режиме Swift 5 —
предупреждения (введение, раздел 0.2).

### Когда нужен `nonisolated`

Иногда код **нужно** выполнять не на главном потоке: сортировать
большой массив, разбирать JSON, декодировать картинку — чтобы
интерфейс в это время не замирал. Такой код помечают `nonisolated` —
«не привязан ни к какому актору, можно вызывать откуда угодно»:

```swift
struct Todo {
    var title: String
    var priority: Int
}

enum TodoSorting {
    nonisolated static func byPriority(_ a: Todo, _ b: Todo) -> Bool {
        a.priority > b.priority
    }
}
```

Функция сравнивает два дела по приоритету: `true`, если первое важнее.
Она «чистая» — не трогает интерфейс и не читает общее изменяемое
состояние, работает только с тем, что ей передали. Такую функцию
безопасно вызывать с любого потока, и `nonisolated` сообщает об этом
компилятору.

Проверим. Отсортируем список в фоне:

```swift
func sortOffMain(_ todos: [Todo]) {
    Task.detached {
        let sorted = todos.sorted(by: TodoSorting.byPriority)
        print(sorted.count)
    }
}
```

С `nonisolated` это собирается. Без него Swift 6 выдаст ошибку:
«converting function value of type '@MainActor (Todo, Todo) throws ->
Bool' to '(Todo, Todo) throws -> Bool' loses global actor 'MainActor'».
По-человечески: функция привязана к главному потоку, а `sorted(by:)`
в фоне вызвал бы её не на главном — так нельзя.

> **Когда нужен `nonisolated`.** Чистые функции и типы, которые не
> трогают UIKit и не используют состояние главного потока:
> сортировка, форматирование, валидация, разбор данных. Помечаем их
> `nonisolated`, чтобы звать из фоновых задач и других акторов.
> Частый случай — модель с `Codable`, которую разбирают в фоне: её
> объявляют `nonisolated struct` (подробнее — в главах про сеть,
> например в главе 15).

### Task: наследует или нет

**`Task { … }`** — запуск асинхронной работы. Если `Task` создан в
коде, привязанном к главному потоку (а у нас это почти весь код), он
**наследует** эту привязку. Поэтому такой код работает:

```swift
struct Post: Decodable {
    let title: String
}

struct PostAPI {
    func fetch() async throws -> Post { Post(title: "Привет") }
}

final class DemoViewController: UIViewController {
    private let label = UILabel()
    private let api = PostAPI()

    func loadInherited() {
        Task {
            let post = try await api.fetch()
            self.label.text = post.title   // мы на главном потоке
        }
    }
}
```

`await` — точка ожидания: пока `fetch()` работает, главный поток не
заблокирован и рисует интерфейс. Когда результат готов, задача
продолжается — снова на главном потоке, и лейбл можно менять.

**`Task.detached { … }`** — «отсоединённая» задача: ничего не
наследует от места, где её создали, и выполняется не на главном потоке.
Трогать из неё интерфейс напрямую нельзя — на главный поток переходим
явно:

```swift
    func loadDetached() {
        let api = self.api
        Task.detached {
            let post = try await api.fetch()
            await MainActor.run {
                self.label.text = post.title
            }
        }
    }
```

`MainActor.run { … }` — «выполни это замыкание на главном потоке».
`await` перед ним — потому что главный поток может быть занят, и
придётся подождать своей очереди.

Если забыть `MainActor.run` и вызвать метод экрана прямо из
`Task.detached` — например, `self.show(post)`, где `show` обновляет
лейбл, — Swift 6 выдаст ошибку «main actor-isolated instance method
'show' cannot be called from outside of the actor». Любопытная деталь,
которую мы увидели при проверке: присваивание свойствам UIKit
(`self.label.text = …`) из отсоединённой задачи Swift 6.3 отмечает
только **предупреждением**. Поэтому предупреждения о конкурентности
не игнорируй — это те же ошибки, только компилятор пока не настаивает.

`Task.detached` в UIKit-коде нужен редко. Если хочется просто
выполнить тяжёлую функцию в фоне, с Approachable Concurrency для этого
есть пометка `@concurrent`:

```swift
final class ImageDecoder {
    @concurrent
    nonisolated func decode(_ data: Data) async -> UIImage? {
        UIImage(data: data)
    }
}
```

`nonisolated` снимает привязку к главному потоку, а `@concurrent`
велит выполнять функцию в фоновом пуле потоков. Без `@concurrent`
асинхронная `nonisolated`-функция с Approachable Concurrency
выполняется там же, откуда её вызвали, — на главном потоке, если
вызвали из экрана. Вызов из экрана — `let image = await
decoder.decode(data)`: главный поток ждёт, не блокируясь, а
декодирование идёт в фоне.

## 5.8 `MainActor.assumeIsolated` — мост к старым API

Вернёмся к подписке из раздела 5.6:

```swift
let bgObs = NotificationCenter.default.addObserver(
    forName: UIScene.willDeactivateNotification,
    object: nil,
    queue: .main
) { [weak self] _ in
    MainActor.assumeIsolated { self?.handleEnterBackground() }
}
```

`addObserver(forName:object:queue:using:)` — API из времён
Objective-C. Его замыкание помечено как `@Sendable` — «может
выполниться на любом потоке», и компилятор не знает про `queue: .main`.
Мы-то уверены, что замыкание придёт на главный поток — мы сами
передали `.main`. А компилятор считает, что это может быть любой
поток, и не даёт вызвать `handleEnterBackground()` — метод экрана или
контроллера, привязанного к главному потоку.

`MainActor.assumeIsolated { … }` — это **утверждение** для компилятора:
«мы уже на главном потоке, выполни замыкание сразу, синхронно». Оно
проверяется во время работы: если окажется, что мы **не** на главном
потоке, приложение аварийно завершится с понятной ошибкой. Так
лучше, чем тихо тронуть интерфейс из фона.

Это компромисс между Swift Concurrency и старыми API UIKit.
Используй его, только когда **точно знаешь**, что окружение
правильное. Здесь это гарантирует `queue: .main`.

`MainActor.assumeIsolated` доступен начиная с iOS 13 (документация
Apple указывает iOS 13.0+), так что с нашим минимумом iOS 15 никаких
проверок версии не нужно. Альтернатива без проверки потока —
`Task { @MainActor in self?.handleEnterBackground() }`: тоже работает,
но выполняет код **асинхронно**, чуть позже. Для размытия экрана перед
уходом в фон это плохо: система может успеть сделать снимок экрана для
переключателя приложений до того, как размытие появится.

## 5.9 Бытовая аналогия

`AppDelegate` — **управляющий бизнес-центром**. Он знает, когда здание
открылось, принимает почту на всё здание (push-уведомления) и решает,
какой офис выделить новому арендатору.

`SceneDelegate` — **администратор одного офиса** в этом здании. Он
расставляет мебель (окно, первый экран), знает, когда офис открылся и
когда в нём погасили свет.

`UIViewController` — **сотрудник за конкретным столом**. Он знает, что
лежит у него на столе и кто к нему заходил.

На iPhone в здании один офис. На iPad их может быть несколько, и у
каждого свой администратор.

`@MainActor` — правило **«с документами работаем только в офисе»**.
Сотрудник не может поменять бумаги из дома (с фонового потока) —
охрана не пустит к шкафу. А `nonisolated` — черновики, с которыми
можно работать где угодно, потому что они ничьи.

## 5.10 Что мы пропустили

Несколько тем жизненного цикла, которые playground'у не нужны и в этой
книге не разбираются:

- **Восстановление состояния** (state restoration) — сохранить, на
  каком экране был пользователь, и вернуть его туда после того, как
  система выгрузила приложение. В приложениях со сценами это делается
  через `NSUserActivity` сцены (метод
  `stateRestorationActivity(for:)` делегата сцены).
- **Фоновые задачи** — `BGTaskScheduler`: периодически обновлять
  данные, даже когда приложение свёрнуто.
- **Несколько сцен на iPad** — если включить Enable Multiple Windows,
  `willConnectTo` будет вызываться для каждого окна, и всё, что сейчас
  хранится в одном экземпляре (как наш реестр), придётся продумать под
  несколько окон сразу.

Ссылки для самостоятельного изучения — в конце главы.

**Упражнение 5.2.** Добавь в `SceneDelegate` четыре метода и запусти
приложение в симуляторе:

```swift
    func sceneWillEnterForeground(_ scene: UIScene) {
        print("→ scene will enter foreground")
    }
    func sceneDidBecomeActive(_ scene: UIScene) {
        print("→ scene did become active")
    }
    func sceneWillResignActive(_ scene: UIScene) {
        print("→ scene will resign active")
    }
    func sceneDidEnterBackground(_ scene: UIScene) {
        print("→ scene did enter background")
    }
```

Сверни приложение (в симуляторе — ⇧⌘H, Device → Home), потом открой
снова. Какие строки и в каком порядке появятся в консоли Xcode при
запуске, при сворачивании и при возвращении?

## 5.11 Собираем фундамент

Все файлы части I готовы. Осталась мелочь и проверка.

**Общие цвета и отступы.** Заведём одно место для общих цветов и
отступов playground'а. Листинги mini-app из части III ради
самостоятельности пишут системные цвета прямо в коде (`.systemGreen`,
`.systemRed`), а когда захочешь единый стиль, их удобно заменить на
`Palette.success`, `Palette.danger` и т. д. Создай
`Common/DesignSystem.swift`:

```swift
import UIKit

/// Общие цвета playground'а. Системные цвета сами подстраиваются
/// под светлую и тёмную тему.
enum Palette {
    static let tint: UIColor = .systemBlue
    static let success: UIColor = .systemGreen
    static let danger: UIColor = .systemRed
}

/// Отступы: все кратны 4 точкам.
enum Spacing {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 16
    static let l: CGFloat = 24
}
```

Это тоже namespace enum'ы (глава 2): только статические константы.
Цвета — системные, поэтому тёмная тема работает сама. Отступы кратны 4
точкам — так интерфейс выглядит ровнее: соседние расстояния 8 и 16
заметно различаются, а 15 и 16 — нет. Глава 35 покажет, как завести
свои фирменные цвета в каталоге ассетов.

**Проверь, что в проекте есть всё:**

| Файл | Глава |
|---|---|
| `App/AnimatedSplashViewController.swift` | 1 |
| `Base.lproj/LaunchScreen.storyboard` (фон System Grouped Background) | 1 |
| `App/AppManifest.swift` (с `PermissionKind` и `OnboardingPage`) | 2 |
| `App/AppManifest+Placeholder.swift` | 2 |
| `App/PlaceholderViewController.swift` | 2 |
| `App/AppRegistry.swift` | 2 |
| `App/PlaygroundWindow.swift` | 3 |
| `App/BootCoordinator.swift` | 4 |
| `App/AppListViewController.swift` | 4 |
| `App/AppDelegate.swift`, `App/SceneDelegate.swift` | 5 |
| `Common/DesignSystem.swift` | 5 |

И настройки из введения (раздел 0.1): нет `Main.storyboard` и ссылок
на него, минимальная версия iOS 15.0, Swift 6.

Если перемещаешь файлы по папкам в Xcode — перетаскивай их внутри
Project Navigator, а не в Finder: так Xcode не потеряет их.

**Запусти** (⌘R) на симуляторе iPhone. Мы собрали этот фундамент в
Xcode 26.5 (Swift 6, iOS 15.0) и прогнали на симуляторе iPhone 16 с
iOS 26.5. Что ты должен увидеть:

1. На долю секунды — серый фон launch screen.
2. Лаунчер: большой заголовок «UIKit Playground», одиннадцать строк с
   цветными иконками, у каждой справа серая пометка «СКОРО», под
   списком — подсказка про встряхивание.
3. Тап по любой строке — экран окрашивается в цвет mini-app, иконка
   «выпрыгивает» с лёгким перелётом, следом проявляется название, за
   ним — индикатор загрузки.
4. Примерно через полторы секунды — плавный переход к заглушке: молоток
   и текст «ещё не реализовано», сверху — панель навигации с названием
   mini-app.
5. ⌃⌘Z — плавный возврат в лаунчер, в том же положении прокрутки.

Консоль Xcode при этом должна оставаться чистой: никаких сообщений о
конфликтах constraints («Unable to simultaneously satisfy
constraints»).

Если вместо лаунчера — чёрный экран, проверь по порядку: имя
конфигурации «Default Configuration» в `Info.plist` и в `AppDelegate`
совпадает; в `Delegate Class Name` стоит
`$(PRODUCT_MODULE_NAME).SceneDelegate`; в `willConnectTo` есть
`makeKeyAndVisible()` и `self.window = window`.

Фундамент готов. С части II мы начнём вписывать гейты в
`BootCoordinator`, а с части III — заменять заглушки настоящими
mini-app.

## Ответы к упражнениям

**5.1.** Внутри main-экрана `window.rootViewController` — это
`UINavigationController`, который создал `showMain()` координатора, с
main-экраном mini-app внутри. `launcherRoot` — другой
`UINavigationController`, с лаунчером; он в памяти, но не в окне. На
экране — только то, что в `window.rootViewController`, то есть
mini-app.

**5.2.** При запуске мы увидели в консоли:

```
→ scene will enter foreground
→ scene did become active
```

Первое уведомление приходит и при самом первом появлении сцены: для
iOS запуск — это тоже «выход на передний план». При сворачивании:

```
→ scene will resign active
→ scene did enter background
```

Сначала сцена перестаёт получать касания (неактивна), потом уходит с
экрана. При возвращении — снова `will enter foreground` и `did become
active` (эти шесть строк мы получили, запустив playground на
симуляторе iPhone 16 с iOS 26.5). Если вместо сворачивания открыть
переключатель приложений (в симуляторе — Device → App Switcher) и
вернуться, не выбирая другое приложение, сцена остаётся на экране,
просто без касаний, — поэтому ожидай только пару `will resign active`
/ `did become active`. Проверь это сам.

## Что мы выучили

- С iOS 13 у приложения три уровня: `UIApplication` → сцена
  (`UIWindowScene`, её запись — `UISceneSession`) → окно и экраны. На
  каждом уровне свой делегат. После iOS 26 приложения без сцен
  перестанут запускаться (TN3187).
- `Info.plist` → Application Scene Manifest говорит iOS, какой
  `SceneDelegate` создать; имя конфигурации должно совпадать с тем, что
  возвращает `AppDelegate`.
- `AppDelegate` — для процесса: push, фоновые задачи, SDK.
  `SceneDelegate` — для интерфейса сцены: окно, первый экран, а также
  входящие URL и Universal Links.
- Окно держится в `SceneDelegate.window`. Лаунчер держим в
  `launcherRoot`, чтобы возвращаться к тому же экрану — и чтобы не
  освободился активный координатор.
- Порядок при запуске: `didFinishLaunching` → `configurationForConnecting`
  → `willConnectTo` → `willEnterForeground` → `didBecomeActive`. Долгой
  работы в этих методах быть не должно.
- Для событий жизненного цикла вне `SceneDelegate` удобны уведомления
  `NotificationCenter` (`UIScene.willDeactivateNotification` и
  другие). Жетон подписки храним и снимаем через `removeObserver`.
- UIKit помечен `@MainActor` всегда. Default Actor Isolation =
  MainActor делает `@MainActor` и твои собственные типы. Для работы в
  фоне — `nonisolated` (и `@concurrent` для асинхронных функций).
- `Task { }` наследует главный поток, `Task.detached { }` — нет; из
  него на главный поток переходим через `await MainActor.run { }`.
- `MainActor.assumeIsolated { }` (iOS 13+) — мост к старым API,
  которые точно вызываются на главном потоке; если это не так —
  аварийное завершение.

## Apple Developer Documentation

- [TN3187: Migrating to the UIKit scene-based life cycle](https://developer.apple.com/documentation/technotes/tn3187-migrating-to-the-uikit-scene-based-life-cycle) — переход на сцены и требование после iOS 26.
- [Managing your app's life cycle](https://developer.apple.com/documentation/uikit/managing-your-app-s-life-cycle) — состояния active / inactive / background и переходы между ними.
- [`UIApplicationDelegate`](https://developer.apple.com/documentation/uikit/uiapplicationdelegate) — что обрабатывает делегат приложения.
- [`UISceneDelegate`](https://developer.apple.com/documentation/uikit/uiscenedelegate) и [`UIWindowSceneDelegate`](https://developer.apple.com/documentation/uikit/uiwindowscenedelegate) — события сцены, `scene(_:willConnectTo:options:)`.
- [`UIApplicationSceneManifest`](https://developer.apple.com/documentation/bundleresources/information-property-list/uiapplicationscenemanifest) — ключ `Info.plist` с конфигурациями сцен.
- [`UISceneSession`](https://developer.apple.com/documentation/uikit/uiscenesession) — запись о сцене, по которой система её восстанавливает.
- [`UIScene.willDeactivateNotification`](https://developer.apple.com/documentation/uikit/uiscene/willdeactivatenotification) и [`didActivateNotification`](https://developer.apple.com/documentation/uikit/uiscene/didactivatenotification) — уведомления, на которые подписан `LifecycleSecurityController`.
- [`MainActor.assumeIsolated(_:file:line:)`](https://developer.apple.com/documentation/swift/mainactor/assumeisolated(_:file:line:)) — проверка «мы на главном потоке» с доступностью iOS 13+.
- [Concurrency — Swift Book](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency) — async/await, акторы, `Task` и изоляция.

Это конец части I. Дальше — часть II про гейты запуска: onboarding,
экран разрешения, вход в аккаунт, «обновите приложение», регион и
возраст, защита при сворачивании. Каждый гейт — отдельная глава с
разбором UX и кода.

→ [Глава 6. Onboarding — UIPageViewController с dots indicator](./10-onboarding.md)
