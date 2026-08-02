# Глава 4. BootCoordinator — оркестратор гейтов

В Главах 1 и 2 мы увидели две части. AnimatedSplash — VC, который
показывает анимацию и зовёт `onFinish`. AppManifest — структура, где
лежит набор флагов: какие гейты нужны этому mini-app.

Самих **гейтов** — несколько. Onboarding, permission primer, region
picker, age gate, force-update, maintenance, auth, lifecycle security.
Каждый — отдельный VC. Каждый зовёт callback, когда закончил.

Кто-то должен это собрать в правильную цепочку: посмотреть в манифест,
решить какой гейт сейчас актуален, поставить нужный VC, дождаться его
callback'а, перейти к тому, что идёт дальше. Этот «кто-то» и есть
**BootCoordinator**.

## 4.1 Зачем отдельный класс

Когда я в первый раз делал подобную систему, всё это сидело в
SceneDelegate'е. Получилось:

```swift
// Так выглядит код, который мы НЕ пишем
func scene(_ scene: UIScene, willConnectTo ...) {
    if needsOnboarding { showOnboarding(...) }
    else if needsPermission { showPermission(...) }
    else if needsAuth { showAuth(...) }
    else { showMain() }
}
```

И каждый из этих `show*` был длинным замыканием, которое заканчивалось
вызовом очередного `show*`. SceneDelegate раздулся, стал нечитаемым,
любое добавление гейта ломало два соседних.

Решение — выделить **отдельный объект**, который держит:

1. **Состояние** — где сейчас пользователь в цепочке.
2. **Правила** — какой гейт идёт после какого.
3. **Зависимости** — окно (куда ставить root), манифест (что показывать).

Этот объект — `BootCoordinator`. Паттерн называется **coordinator**,
популяризован Soroush Khanlou в 2015 году. Идея проста: VC ничего не
знают друг о друге, координатор знает всё про порядок.

## 4.2 Скелет — конструктор и зависимости

Файл: `App/BootCoordinator.swift`. Начало:

```swift
@MainActor
final class BootCoordinator {

    private let manifest: AppManifest
    private weak var window: PlaygroundWindow?
    private let onExit: () -> Void
    private var lifecycleSecurity: LifecycleSecurityController?

    init(manifest: AppManifest,
         window: PlaygroundWindow,
         onExit: @escaping () -> Void) {
        self.manifest = manifest
        self.window = window
        self.onExit = onExit
    }
```

Три зависимости:

- `manifest` — что показывать (Глава 2). `let`, не меняется по ходу.
- `window` — куда ставить root. **`weak`**, потому что окно держит
  SceneDelegate, и координатор не должен с ним конкурировать. Если
  окно умерло — координатору всё равно нечего делать.
- `onExit` — callback в SceneDelegate, чтобы вернуть лаунчер обратно.

`@MainActor` на классе — потому что внутри сплошной UIKit. Один раз
объявил на классе, и все методы автоматически main-actor-isolated.

`lifecycleSecurity` — отдельный сервис для блюра в фоне и Face ID
(разберём в Главе 15). Координатор держит его сильно, чтобы он не
деаллоцировался посередине mini-app.

## 4.3 Точка входа — `start()`

```swift
func start() {
    window?.onShake = { [weak self] in
        self?.exitToLauncher()
    }

    if manifest.hasAnimatedSplash {
        showSplash()
    } else {
        proceedAfterSplash()
    }
}
```

Две вещи. Первая — подписываемся на shake. Когда пользователь встряхнёт,
выходим в лаунчер (см. Главу 3 про `PlaygroundWindow.onShake`).

Вторая — стартуем цепочку. Если в манифесте `hasAnimatedSplash`, идём
через splash. Если нет — сразу к тому, что идёт дальше.

> 💡 **Идея.** Каждый гейт — это **опционален**. Есть два состояния:
> «гейт нужен, показываем» и «гейт не нужен, пропускаем». Координатор
> для каждого гейта зовёт один из двух соответствующих методов:
> `showX()` или `proceedAfterX()`. Так получается единый, понятный
> механизм перехода.

## 4.4 Один гейт = три метода

Возьмём, например, onboarding:

```swift
private func proceedAfterSplash() {
    if OnboardingViewController.shouldShow(for: manifest) {
        showOnboarding()
    } else {
        proceedAfterOnboarding()
    }
}

private func showOnboarding() {
    let onboarding = OnboardingViewController(manifest: manifest) { [weak self] in
        self?.proceedAfterOnboarding()
    }
    setRoot(onboarding, animated: true)
}

private func proceedAfterOnboarding() {
    // ... решение про очередной гейт ...
}
```

Три метода вокруг одного гейта:

1. **`proceedAfterSplash()`** — точка входа в onboarding-блок. Решает,
   нужен ли этот гейт. Если да — `showOnboarding()`. Если нет —
   проскакивает в `proceedAfterOnboarding()`.
2. **`showOnboarding()`** — создаёт VC, ставит его как root. В callback
   `onFinish` передаёт `proceedAfterOnboarding()`.
3. **`proceedAfterOnboarding()`** — точка входа в очередной гейт-блок
   (permission). Логика та же: нужен ли, показывать или пропускать.

Эта тройка повторяется для **каждого** гейта. Не самое короткое
решение, но **читаемое** и **расширяемое**: чтобы добавить новый гейт,
нужно вставить три метода между существующими — и всё.

Вот реальный поток для одного mini-app (Profile, у которого включено
много гейтов):

```
start()
 └─ showSplash()
     └─ proceedAfterSplash()
         └─ showOnboarding()        [если hasOnboarding и не показан раньше]
             └─ proceedAfterOnboarding()
                 └─ showPermissionPrimer()    [если requiresPermission и status == nil]
                     └─ proceedAfterPermission()
                         └─ showRegionPicker() [если requiresRegionPick]
                             └─ proceedAfterRegion()
                                 └─ showAgeGate() [если requiresAgeGate и age < min]
                                     └─ proceedAfterAgeGate()
                                         └─ checkRemoteConfig() [если форс-апдейт]
                                             └─ proceedAfterRemoteConfig()
                                                 └─ showAuthGate() [если hasAuthGate]
                                                     └─ showMain()
```

Глубокая лесенка, но каждый узел простой: проверка флага и переход к
одному из двух соседей.

## 4.5 `setRoot` — как меняем root view controller

Заметь, координатор не пушит экраны через `UINavigationController.push`.
Он **меняет root окна целиком**. Из splash → в onboarding → в
permission primer → в main. Каждый раз root окна — другой VC.

Почему так? Потому что предыдущий гейт **закончил свою задачу**.
Возвращаться к нему нельзя. Если бы они были в nav-стеке, пользователь
мог бы свайпнуть назад из onboarding обратно в splash. Это бессмысленно.

Кроме того, между гейтами часто **нет** общего nav-бара. У splash
нет шапки, у onboarding есть кнопки skip/next в шапке, у permission
primer кнопок нет. Если объединять в один nav-стек, эта шапка пляшет
визуально.

Меняем root так:

```swift
private func setRoot(_ vc: UIViewController, animated: Bool) {
    guard let window else { return }
    if animated {
        UIView.transition(with: window,
                          duration: 0.35,
                          options: .transitionCrossDissolve,
                          animations: {
                              window.rootViewController = vc
                          })
    } else {
        window.rootViewController = vc
    }
}
```

`UIView.transition(with: window, ...)` — стандартный способ анимированно
заменить содержимое view. `.transitionCrossDissolve` — мягкое затухание.
Без анимации (`animated: false`) — мгновенная замена; так делаем для
первого экрана (splash появляется без перехода).

> ⚠ **Замена root — не бесплатно.** UIKit пересоздаёт всю иерархию view,
> заново выставляет constraint'ы, заново показывает status bar.
> Поэтому делать `setRoot` часто (например, в ответ на каждый тап) —
> плохая идея. У нас же это происходит только при смене гейта — это
> редкое событие, никаких проблем.

## 4.6 Strong-ref проблема

Координатор — обычный объект. Если на него никто не держит сильную
ссылку — он умрёт сразу после `start()`, и все callback'и `[weak
self]` не сработают.

Кто его держит? **`AppListViewController` (лаунчер)**:

```swift
// фрагмент из AppListViewController
private var activeCoordinator: BootCoordinator?

private func launch(_ manifest: AppManifest) {
    guard let window = windowProvider?() else { return }
    let coordinator = BootCoordinator(
        manifest: manifest,
        window: window,
        onExit: { [weak self] in
            self?.activeCoordinator = nil
            self?.onReturnToLauncher?()
        }
    )
    activeCoordinator = coordinator
    coordinator.start()
}
```

`activeCoordinator` — `var`, сильная ссылка. Лаунчер держит координатор
**пока пользователь в mini-app**. Когда `onExit` сработает (юзер сделал
shake или сам гейт попросил выйти, как у age gate), лаунчер
**обнуляет** ссылку — `self?.activeCoordinator = nil`. Координатор
умирает, ARC чистит.

> 💡 **Признак «забыл держать».** Если ты запустил mini-app, и
> callback'и из splash/onboarding не срабатывают — почти всегда это
> ситуация «координатор деаллоцировался посередине». Проверяй, что у
> кого-то есть `var coordinator: ...` со сильной ссылкой.

## 4.7 Гейт может **выйти** в лаунчер сам

Большинство гейтов проходят пользователя дальше. Но age gate
(«16+ только») — особый: если пользователь слишком юн, дальше его не
пускаем, и кнопка «Вернуться» возвращает в лаунчер. Это сделано через
**два callback'а** от гейта — `onPass` и `onTooYoung`:

```swift
private func showAgeGate() {
    let gate = AgeGateViewController(
        manifestId: manifest.id,
        brandColor: manifest.brandColor,
        minAge: manifest.minAgeYears,
        onPass: { [weak self] in self?.proceedAfterAgeGate() },
        onTooYoung: { [weak self] in self?.exitToLauncher() }
    )
    setRoot(gate, animated: true)
}
```

`onPass` → идём дальше по цепочке. `onTooYoung` → сразу в лаунчер.

Это полезный паттерн в координаторах: **гейт может иметь больше одного
«выхода»**. Coordinator решает, куда какой выход ведёт.

## 4.8 Бытовая аналогия

Координатор — это **администратор клиники**. Пациент приходит,
администратор смотрит в карту (`manifest`): «нужно ли страховое
подтверждение → к стойке Х. Нужны ли анализы → к стойке Y. Если всё
ок — к врачу».

Сами стойки (`splash`, `onboarding`, `permission`...) не знают друг
про друга. Каждая делает свою работу и зовёт «того, кто дальше». Решает,
кто именно — администратор.

Если бы стойки знали друг про друга, переставить очередь было бы
адом. С администратором — поменял две строчки в координаторе, и
порядок другой.

## 4.9 Что мы могли бы улучшить

Текущая реализация — pragmatic, не «идеальная». Возможные улучшения,
если бы цепочка стала ещё длиннее:

- **State machine**. Каждый гейт — состояние. Координатор — переход
  между состояниями. Получится явная диаграмма, легче читать.
- **Builder для chain'а**:
  ```swift
  Chain
      .start(SplashGate())
      .then(OnboardingGate.if(manifest.hasOnboarding))
      .then(PermissionGate.if(manifest.requiresPermission != nil))
      .terminate(MainGate())
  ```
  Чище, но требует абстракции «Gate» — а сейчас гейты слишком разные
  (у age gate два выхода, у remote-config — асинхронный fetch).
- **Async/await chain**:
  ```swift
  await splashGate.show(in: window)
  if shouldShowOnboarding { await onboardingGate.show(in: window) }
  ```
  Линейный код вместо callback-pyramid'ы. Требует чтобы каждый гейт
  умел показать себя как `async`.

Эти варианты можно прикрутить позже. На текущем масштабе (8 гейтов)
наш «глупый» подход с тройками методов — лучший по балансу
«читаемость / простота».

> 🛠 **Упражнение.** Открой `App/BootCoordinator.swift` и найди
> `proceedAfterOnboarding`. Поменяй порядок: пусть **сначала** идёт
> auth gate, потом permission primer (то есть auth раньше permission).
> Чтобы это сделать, нужно переписать всего 2 строчки — изменить, кого
> зовёт `proceedAfterOnboarding`, и обновить цепочку дальше. Запусти,
> зайди в Profile (у него и auth, и biometric) — увидишь auth раньше.
> Потом верни обратно.

## 📋 Что мы выучили

- `BootCoordinator` — отдельный класс, который держит цепочку гейтов
  запуска. Без него вся логика осела бы в SceneDelegate.
- Зависимости: `manifest` (что), `window` (куда ставить root, `weak`),
  `onExit` (callback в лаунчер).
- Один гейт = три метода: `proceedAfterX()` (решает нужен/нет),
  `showX()` (создаёт VC), и `onFinish`-callback зовёт то, что идёт дальше.
- `setRoot` меняет `window.rootViewController` целиком, с
  cross-dissolve анимацией. Не nav-push — потому что возвращаться к
  предыдущему гейту нельзя.
- Координатор держится через сильную ссылку в `AppListViewController`.
  Без этого деаллоцируется сразу после `start()`.
- Гейт может иметь несколько callback'ов (`onPass`/`onTooYoung`), и
  координатор решает, какой выход куда ведёт.

## Apple Developer Documentation

Coordinator-паттерна нет в Apple-доках (это сообщественная идиома), но
все API, на которых он стоит, — каноничные UIKit и Swift.

- [`UIViewController`](https://developer.apple.com/documentation/uikit/uiviewcontroller) — координатор работает поверх корневых VC; смотри раздел про root view controller и transitions.
- [Implementing a Container View Controller](https://developer.apple.com/documentation/uikit/view_controllers/creating_a_custom_container_view_controller) — официальный гид по containment API, родственный нашему подходу со сменой root.
- [`addChild(_:)`](https://developer.apple.com/documentation/uikit/uiviewcontroller/1621394-addchild) и [`willMove(toParent:)`](https://developer.apple.com/documentation/uikit/uiviewcontroller) — методы containment, которые пригодятся, если решишь делать гейты как child-VC, а не подменой root.
- [`UIView.transition(with:duration:options:animations:completion:)`](https://developer.apple.com/documentation/uikit/uiview/1622574-transition) — анимация cross-dissolve при смене `rootViewController`.
- [Closures — Swift Book](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/closures) — для callback'ов `onPass`/`onTooYoung`/`onExit` и capture-list `[weak self]`.
- [Automatic Reference Counting — Swift Book](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/automaticreferencecounting) — почему координатор обязательно должен висеть на сильной ссылке у лаунчера.

→ [Глава 5. Lifecycle App→Scene→VC и @MainActor](./05-lifecycle.md)
