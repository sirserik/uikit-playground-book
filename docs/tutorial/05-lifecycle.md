# Глава 5. Lifecycle App → Scene → VC и @MainActor под капотом

В четырёх предыдущих главах мы строили цепочку запуска mini-app —
splash, манифест, окно, координатор. Но за всем этим стоит **более
фундаментальная цепочка**, которая запускается ещё до того, как мы
успеваем что-то сделать.

Когда пользователь тапает иконку, iOS не сразу зовёт твой
`SceneDelegate`. Перед этим происходит несколько вещей: запускается
процесс, ставится в строй `UIApplication`, проверяется конфигурация
сцен, создаётся `UISceneSession`, и **только потом** идёт callback
`scene(_:willConnectTo:options:)`.

В этой главе разбираем эту цепочку и заодно — почему весь UIKit-код в
этой книге написан с `@MainActor`, и что вообще даёт нам Xcode 26 с
`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.

## 5.1 App → Scene → VC: три уровня

С iOS 13 у iOS-приложения **три** уровня сверху вниз:

```
UIApplication              ← процесс, одно на всё
   │
   └─ UISceneSession        ← окно (на iPad бывает несколько; на iPhone одно)
        │
        └─ UIWindowScene
             │
             └─ PlaygroundWindow (наш UIWindow)
                  │
                  └─ rootViewController (splash, лаунчер, mini-app)
                       │
                       └─ child VC, view'ы, …
```

До iOS 13 уровня **Scene** не было — окно сразу принадлежало
`UIApplication`. Apple ввела сцены, чтобы на iPad можно было держать
несколько окон одного приложения (split view, slide over). На iPhone
сцена всегда одна, но архитектура та же.

На каждый уровень есть свой delegate:

- `AppDelegate` — события процесса (запуск, выгрузка, push-токен).
- `SceneDelegate` — события окна (стало активным, ушло в фон).
- `UIViewController` — события экрана (`viewWillAppear`, `viewDidDisappear`).

## 5.2 AppDelegate — что туда положить, что нет

В нашем проекте `AppDelegate.swift` минимальный:

```swift
@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        return true
    }

    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration",
                                    sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication,
                     didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // ничего
    }
}
```

`@main` — атрибут, который говорит компилятору: «это точка входа в
приложение, создай вокруг неё `main()`-функцию».

Что **должно** жить в `AppDelegate` (а не в SceneDelegate):

- Регистрация push-нотификаций (`registerForRemoteNotifications`).
- Регистрация для Background Modes (BGTaskScheduler).
- Установка глобальных аналитических SDK (Firebase, Crashlytics).
- Конфигурация `Crashlytics`, `Sentry`, и подобных.
- Универсальные хуки для URL-схем и Universal Links.

Что **не должно** — настройка окна и UI. Это работа SceneDelegate.

Наш AppDelegate почти пустой, потому что мы пока ничего из перечисленного
не делаем. Конфигурации сцен — стандартные, нашего ничего нет.

## 5.3 SceneDelegate — где собирается всё дерево

Это место, где жизнь приложения начинается **с UI-точки зрения**. Здесь
создаётся окно и ставится первый root.

```swift
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    private var launcherRoot: UIViewController?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        AppRegistry.registerDemoConfigScenarios()

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

Здесь много всего, разберём по частям.

Первая важная строчка:

```swift
let window = PlaygroundWindow(windowScene: windowScene)
```

`PlaygroundWindow` — наш подкласс из Главы 3. `windowScene` —
инициализатор, который связывает окно с конкретной сценой. Без этого
окно «висит в воздухе» и не отображается.

`AppListViewController()` — лаунчер. Оборачиваем его в
`UINavigationController` ради large titles и nav-бара. Этот же
`UINavigationController` мы **сохраняем** в `launcherRoot`:

```swift
launcherRoot = nav
```

`launcherRoot` — приватное свойство SceneDelegate. Когда пользователь
зайдёт в mini-app, координатор заменит `window.rootViewController` на
splash/main mini-app. Лаунчер «уйдёт» из root'а, но **не из памяти**:
SceneDelegate держит на него сильную ссылку.

> 💡 **Зачем сохранять.** Без `launcherRoot` после первой замены root'а
> на mini-app, лаунчер деаллоцируется, и при возврате через shake мы
> создадим новый. Это значит — сбросится скролл-позиция, выделение,
> любое состояние. С сохранением — возвращаемся к **тому же** лаунчеру,
> в каком ушли.

`launcher.windowProvider` и `launcher.onReturnToLauncher` —
**инъекция зависимостей в лаунчер**. Лаунчер сам не знает про окно
(окно — деталь сцены), но ему нужно его передать координатору. Поэтому
SceneDelegate даёт лаунчеру замыкания: «вот так возьми окно», «вот так
сделай возврат».

`[weak window]` в `windowProvider` — обязательно. Если бы держали
сильно, лаунчер вечно бы держал окно, окно держало бы сцену, и весь
цикл жизни поломался.

`window.makeKeyAndVisible()` — окно становится главным и видимым.
Только после этого пользователь что-то увидит.

## 5.4 Что показывают переходы App → Scene на лайфтайме

Чтобы было ощутимо, вот примерный таймлайн при холодном старте:

```
0 ms     [user тап по иконке]
0 ms     LaunchScreen.storyboard на экране (iOS сама)
~150 ms  процесс приложения запустился
~160 ms  UIApplication создан
~165 ms  AppDelegate.application(_:didFinishLaunching:)  → return true
~170 ms  UIScene создаётся, SceneDelegate.scene(_:willConnectTo:)
~175 ms  PlaygroundWindow создаётся, root = NavigationController(launcher)
~180 ms  window.makeKeyAndVisible() → LaunchScreen уезжает, видим лаунчер
~200 ms  SceneDelegate.sceneDidBecomeActive(_:) (если бы реализовали)
```

Конкретные числа зависят от устройства, от того тёплый старт или
холодный, от размера бинарника. Но **порядок** всегда такой: App
делегат → Scene делегат → root VC → активная сцена.

При тёплом старте (приложение было в памяти, пользователь возвращается)
пропускается всё до Scene-делегата — сразу `sceneWillEnterForeground` и
`sceneDidBecomeActive`.

## 5.5 Lifecycle-нотификации, которые мы реально используем

В `LifecycleSecurityController` (Глава 15) мы подписываемся не на
методы SceneDelegate, а на **глобальные нотификации**:

```swift
let bgObs = NotificationCenter.default.addObserver(
    forName: UIScene.willDeactivateNotification,
    object: nil,
    queue: .main
) { [weak self] _ in
    MainActor.assumeIsolated { self?.handleEnterBackground() }
}
```

Почему через нотификации? Потому что наш контроллер живёт **внутри
координатора**, а не в SceneDelegate. Делать так, чтобы SceneDelegate
знал про координатор и звал его методы, — лишнее связывание.
Нотификации развязывают: контроллер слушает «когда что произойдёт», не
зная, кто это произведёт.

Useful события:

- `UIScene.willDeactivateNotification` — сцена сейчас уйдёт в фон
  (например, пользователь нажал home, или показывается app-switcher).
- `UIScene.didActivateNotification` — сцена снова в фокусе.
- `UIApplication.didReceiveMemoryWarningNotification` — освободи
  кеш, иначе тебя убьют.

Это глобальные нотификации. Любой код может на них подписаться —
SceneDelegate этого не контролирует.

## 5.6 MainActor под капотом — почему это сильно меняет жизнь

В Xcode 26 есть настройка проекта
`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`. Если она включена (а в
нашем проекте она включена), то **всё** объявленное на верхнем уровне
без явного аннотирования получает `@MainActor` по умолчанию.

Это меняет много чего:

```swift
// Без MainActor-default:
class TodoListViewController: UIViewController { ... }
// тип НЕ изолирован. Можно вызвать его метод откуда угодно.
// Если внутри метода вызовешь UIKit-метод — компилятор не предупредит.

// С MainActor-default:
class TodoListViewController: UIViewController { ... }
// тип АВТОМАТИЧЕСКИ изолирован на main.
// Компилятор требует, чтобы вызовы шли с main; иначе ошибка.
```

То есть весь наш UIKit-код **по умолчанию безопасен**. Race conditions
типа «обновил label из background queue» становятся невозможны на
этапе компиляции.

Если хочется явно вынести что-то с main — нужно написать `nonisolated`:

```swift
// Часть Todo storage:
nonisolated private static func todoSorter(_ a: Todo, _ b: Todo) -> Bool {
    // эта функция чистая, не трогает UI — её можно звать откуда угодно
    a.priority < b.priority
}
```

Без `nonisolated` Xcode 26 бы сказал «нельзя звать main-actor function
из не-main контекста».

> 💡 **Когда `nonisolated` нужен.** Чистые функции, не трогающие UIKit
> и не использующие main-actor состояния — сортировка, форматирование,
> валидация. Помечаем `nonisolated` чтобы их можно было звать из
> `Task.detached` или из другого actor'а.

### Async вызовы из не-main контекста

Если ты в `Task { ... }` хочешь обновить UI:

```swift
Task {
    let result = try await api.fetch()
    // Здесь актор не определён — Swift может выполнить на любом потоке.
    self.label.text = result.title  // ERROR: main-actor required
}
```

С `MainActor`-default'ом, если `Task` создан внутри main-actor
метода, он автоматически наследует main-isolation. Так что код работает.
Но если ты создал `Task.detached` (отдельная иерархия) — нужно явно
переходить на main:

```swift
Task.detached {
    let result = try await api.fetch()
    await MainActor.run {
        self.label.text = result.title
    }
}
```

`MainActor.run { ... }` — точка перехода. Гарантирует, что замыкание
выполнится на main потоке.

## 5.7 `MainActor.assumeIsolated` — компромиссный мост

В `LifecycleSecurityController` ты увидишь такое:

```swift
let bgObs = NotificationCenter.default.addObserver(
    forName: UIScene.willDeactivateNotification,
    object: nil,
    queue: .main
) { [weak self] _ in
    MainActor.assumeIsolated { self?.handleEnterBackground() }
}
```

Что здесь происходит. `addObserver(forName:object:queue:)` — старый
Objective-C API. Его замыкание не знает про Swift acotr-isolation. Мы
**уверены**, что oн прилетит на main queue (потому что мы передали
`.main`), но компилятор этого не знает.

`MainActor.assumeIsolated { ... }` — это **обещание** компилятору: «я
знаю, что мы уже на main, не блокируй меня». Если на самом деле мы не
на main — будет фатальный краш в рантайме.

Это компромисс между новым Swift Concurrency и старым UIKit API.
Использовать только тогда, когда **точно знаешь**, что окружение
правильное. В нашем случае — `queue: .main` это гарантирует.

## 5.8 Бытовая аналогия

`AppDelegate` — это **служба охраны** в здании. Знает, кто включил
свет, кто пришёл первым, кто получил пуш-уведомление.

`SceneDelegate` — это **управляющий конкретного офиса** в этом здании.
Знает, кто сидит в этом офисе, какая мебель стоит, кто свернул шторы
на обед.

`UIViewController` — это **сотрудник на конкретном рабочем месте**.
Знает, что у него на столе, кто заходил.

На айфоне один офис в одном здании. На iPad — могут быть несколько
офисов одной компании, и у каждого свой управляющий.

`@MainActor` — это **правило «никаких удалёнок»**. Сотрудник может
работать только из офиса; если он попытается что-то поменять из дома
(background thread), его не пустят к терминалу.

## 5.9 Что мы пропустили

Несколько вещей, которые относятся к lifecycle, но не нужны нам в
playground'е и появятся в Части V (production):

- **State restoration** — сохранение и восстановление состояния VC
  через `restorationIdentifier`. С iOS 14 рекомендуется через
  `NSUserActivity`.
- **Background modes** — фоновые задачи через BGTaskScheduler. Нужны,
  если хочешь периодически тянуть данные, даже когда приложение
  свёрнуто.
- **Multi-scene на iPad** — если поддерживаешь split view, нужно
  думать про несколько окон одного приложения.

В Главе 60-65 пройдёмся по этим темам с точки зрения релиза.

> 🛠 **Упражнение.** Открой `SceneDelegate.swift` и добавь метод:
>
> ```swift
> func sceneWillEnterForeground(_ scene: UIScene) {
>     print("→ scene will enter foreground")
> }
> func sceneDidBecomeActive(_ scene: UIScene) {
>     print("→ scene did become active")
> }
> func sceneDidEnterBackground(_ scene: UIScene) {
>     print("→ scene did enter background")
> }
> ```
>
> Запусти приложение в симуляторе. Сверни (Cmd+Shift+H), потом снова
> открой. Посмотри в консоль — увидишь точную последовательность
> событий. Полезно для понимания, в каком порядке iOS даёт вам
> возможность реагировать.

## 📋 Что мы выучили

- iOS-приложение с iOS 13 имеет три уровня: `UIApplication`,
  `UIScene`, `UIViewController`. На каждый — свой delegate.
- `AppDelegate` — для процесса (push, аналитика, конфигурации).
  `SceneDelegate` — для UI окна (создание window, root VC).
- Окно держится в `SceneDelegate.window`. Без этого деаллоцируется.
- Между сменами root окна можно держать сохранённую сильную ссылку
  на предыдущий root (`launcherRoot`), чтобы вернуться к тому же
  объекту с сохранённым состоянием.
- Для lifecycle-событий внутри координатора удобнее не методы
  SceneDelegate, а `NotificationCenter` на
  `UIScene.willDeactivateNotification` / `didActivateNotification`.
- В Xcode 26 `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` делает
  UIKit-код main-actor-isolated по умолчанию. Race conditions с
  обновлением UI становятся ошибкой компиляции.
- `nonisolated` — для чистых функций без UI и без main-state.
- `MainActor.assumeIsolated { ... }` — мост к старым ObjC API,
  которые точно вызываются на main, но компилятор не знает.

---

🎉 **Это конец Части I.** Дальше — Часть II про launch-гейты:
onboarding, permission primer, auth, force-update, region/age,
privacy blur + biometric. Каждый гейт = отдельная глава с
обоснованием UX и разбором кода.

→ [Глава 6. Onboarding — UIPageViewController с dots indicator](./10-onboarding.md)
