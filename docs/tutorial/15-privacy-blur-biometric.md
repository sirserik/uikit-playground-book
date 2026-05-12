# Глава 11. Privacy blur + Biometric on resume

Последний гейт в нашей цепочке запуска. Он отличается от всех
предыдущих принципиально: **он работает не только в начале**.
Splash, onboarding, permission primer показались — и забыли. А этот
живёт **на протяжении всей сессии** и реагирует на события lifecycle:
ушло приложение в фон → показать блюр. Вернулось → запросить Face ID.

В этой главе разбираем два связанных, но независимых механизма:

1. **Privacy blur** — размытие в app-switcher'е, чтобы при «уходе в
   фон» соседи в очереди или коллеги через плечо не увидели
   содержимое.
2. **Biometric on resume** — при возврате из фона спросить Face ID
   (или Touch ID), прежде чем показать UI.

Оба нужны для приложений с чувствительными данными: банкинг,
мессенджеры, заметки с паролями.

## 11.1 Зачем блюрить в фоне

Когда пользователь нажимает home button (или свайпает home indicator),
iOS делает **снимок** текущего экрана и показывает его в app-switcher'е.
Этот же снимок появляется в card-preview, если кто-то долго свайпает
вверх и выбирает приложения.

Если в момент сворачивания на экране что-то приватное — баланс счёта,
переписка, медицинская информация — снимок iOS захватит это. Снимок
кеш-айдится на диске, пока приложение в памяти.

Решение: **до** того как iOS сделает снимок, накрыть экран блюр-вью.
iOS сфоткает блюр, в app-switcher'е будет красивая размытая картинка
без содержимого.

iOS даёт два события:

- `UIScene.willDeactivateNotification` — сцена **сейчас уйдёт** из
  активного состояния. Этот момент важен — снимок ещё не сделан.
- `UIScene.didActivateNotification` — сцена снова активна. Снимок
  больше не нужен.

Подписываемся на оба и в первом ставим блюр, во втором убираем (если
не требуется биометрия — её разберём дальше).

## 11.2 Контроллер lifecycle-гейта

В отличие от других гейтов, этот **не view controller**. Это
обычный класс, который владеет двумя `UIView`'ами и подписан на
нотификации:

```swift
@MainActor
final class LifecycleSecurityController {

    private weak var window: UIWindow?
    private let manifest: AppManifest

    private var blurView: UIVisualEffectView?
    private var biometricPromptView: UIView?

    private var observers: [NSObjectProtocol] = []
    private var isAuthenticating = false

    init(window: UIWindow, manifest: AppManifest) {
        self.window = window
        self.manifest = manifest
    }

    func start() {
        guard manifest.hasPrivacyBlurOnBackground || manifest.requiresBiometricOnResume else { return }
        // ... подписки на нотификации ...
    }

    func stop() {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
        removeBlur()
        removeBiometricPrompt()
    }
}
```

Почему не VC? Этот гейт **не показывается в root**, он накладывается
поверх любого экрана mini-app. Чтобы blur был **выше всех** view'ов,
мы добавляем его прямо в `UIWindow.subviews`. С view-controller'ом
такое не сделать — он должен быть в иерархии VC.

Принадлежит контроллер `BootCoordinator`'у. Когда координатор показывает
main, он создаёт `LifecycleSecurityController`:

```swift
private func startLifecycleSecurity() {
    guard let window else { return }
    let controller = LifecycleSecurityController(window: window, manifest: manifest)
    controller.start()
    lifecycleSecurity = controller
}
```

И сильно держит его до выхода в лаунчер. Тогда `stop()` снимает
подписки и убирает blur/prompt:

```swift
private func exitToLauncher() {
    window?.onShake = nil
    lifecycleSecurity?.stop()
    lifecycleSecurity = nil
    onExit()
}
```

## 11.3 NotificationCenter — подписка

```swift
func start() {
    guard manifest.hasPrivacyBlurOnBackground || manifest.requiresBiometricOnResume else { return }
    let nc = NotificationCenter.default
    let bgObs = nc.addObserver(
        forName: UIScene.willDeactivateNotification,
        object: nil,
        queue: .main
    ) { [weak self] _ in
        MainActor.assumeIsolated { self?.handleEnterBackground() }
    }
    let fgObs = nc.addObserver(
        forName: UIScene.didActivateNotification,
        object: nil,
        queue: .main
    ) { [weak self] _ in
        MainActor.assumeIsolated { self?.handleEnterForeground() }
    }
    observers = [bgObs, fgObs]
}
```

`addObserver(forName:object:queue:)` — block-based API. Возвращает
**токен** (`NSObjectProtocol`), который мы храним в массиве.
Чтобы отписаться, нужно передать токен в `removeObserver(_:)`.
В `stop()` мы это делаем.

`queue: .main` — наш handler гарантированно вызывается на main
queue. Это важно: UIKit-операции (showing/hiding views) с main только.

`MainActor.assumeIsolated { ... }` — мост между ObjC API (не знает
про Swift Concurrency) и нашими main-actor методами. Мы знаем, что
блок выполнится на main (потому что `queue: .main`), но компилятор
этого не знает. `assumeIsolated` обещает «я уже на main, пускай»
(см. Главу 5).

`[weak self]` — обязательно. Иначе observer держит controller вечно.

## 11.4 Установка блюра

`UIVisualEffectView` с `UIBlurEffect` — стандартный механизм блюра:

```swift
private func installBlur(on window: UIWindow) {
    guard blurView == nil else { return }
    let effect = UIBlurEffect(style: .systemMaterial)
    let view = UIVisualEffectView(effect: effect)
    view.frame = window.bounds
    view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    window.addSubview(view)
    blurView = view
}

private func removeBlur() {
    blurView?.removeFromSuperview()
    blurView = nil
}
```

Несколько важных моментов:

`guard blurView == nil` — защита от двойной установки. Если уйти в
фон → вернуться → уйти в фон снова без полного цикла — блюр может
успеть «остаться». Без guard мы бы добавили второй blurView поверх.

`UIBlurEffect.Style.systemMaterial` — адаптивный (light/dark mode).
`.systemUltraThinMaterial` — тоньше, видно содержимое. `.systemThickMaterial`
— гуще. Для privacy blur'а — берём что-то плотное, чтобы было реально
не видно. `.systemMaterial` — оптимально.

`window.addSubview(view)` — кладём поверх **всего** окна. Не в
rootViewController, а напрямую в window. Это гарантирует, что блюр
**выше** любых модалок, alert'ов, чего угодно.

`autoresizingMask = [.flexibleWidth, .flexibleHeight]` — если окно
вдруг изменит размер (например, на iPad при rotation), blur тянется
вместе с ним. Auto Layout сюда лезть не надо — слишком просто для
constraint'ов.

## 11.5 Обработка foreground — с биометрией или без

```swift
private func handleEnterForeground() {
    guard let window else { return }
    if manifest.requiresBiometricOnResume {
        showBiometricPrompt(on: window)
    } else {
        removeBlur()
    }
}
```

Если биометрия не требуется — просто убираем блюр. Готово.

Если требуется — оставляем блюр (он скрывает содержимое), и поверх
него показываем экран с кнопкой «Разблокировать» + автоматический
запрос Face ID.

## 11.6 Биометрия — LocalAuthentication

`LocalAuthentication.framework` — Apple-овский API для Face ID / Touch ID.
Главный класс — `LAContext`. Использование async/await:

```swift
private func authenticate() {
    guard !isAuthenticating else { return }
    isAuthenticating = true
    let context = LAContext()
    var error: NSError?
    let policy: LAPolicy = .deviceOwnerAuthenticationWithBiometrics
    guard context.canEvaluatePolicy(policy, error: &error) else {
        // На симуляторе биометрия может быть недоступна — фейлим открыто.
        isAuthenticating = false
        return
    }
    context.evaluatePolicy(
        policy,
        localizedReason: "Подтверди вход в \(manifest.name)"
    ) { [weak self] success, _ in
        DispatchQueue.main.async {
            guard let self else { return }
            self.isAuthenticating = false
            if success {
                self.removeBlur()
                self.removeBiometricPrompt()
            }
        }
    }
}
```

Что здесь происходит:

`isAuthenticating = false/true` — флаг защиты от двойного запроса.
Apple ругается, если зовёшь `evaluatePolicy` пока предыдущая ещё в
процессе.

`canEvaluatePolicy(_:error:)` — проверка, **доступна** ли биометрия:

- Устройство поддерживает Face ID / Touch ID?
- Пользователь записал лицо/палец?
- Биометрия не отключена в Settings?

Если хоть что-то не так — возвращает `false` и заполняет `error`.
На симуляторе обычно `false`, потому что нет реальной биометрии.

`LAPolicy.deviceOwnerAuthenticationWithBiometrics` — **только**
биометрия, без fallback на пароль устройства. Если хочешь fallback —
`.deviceOwnerAuthentication`. Тогда при неудаче Face ID юзер увидит
поле для passcode.

`localizedReason` — строка, которую iOS покажет в **системном**
alert'е Face ID. «Touch ID хочет получить доступ к ...». Должна
объяснять «зачем».

`evaluatePolicy(_:localizedReason:reply:)` — completion-handler-based.
Зовётся не обязательно на main. Поэтому внутри — `DispatchQueue.main.async`.

При успехе — убираем блюр и prompt. Пользователь видит экран mini-app.
При неудаче — оставляем prompt. Пользователь может тапнуть кнопку
«Разблокировать» и попробовать снова.

## 11.7 Bypass у симулятора

На симуляторе Face ID **физически** нет. `canEvaluatePolicy`
возвращает `false`. В нашей реализации мы просто оставляем prompt
как есть — пользователь видит экран блокировки с кнопкой, которая ни
к чему не приводит.

Для тестирования есть **меню симулятора**:

- `Features → Face ID → Enrolled` — включить «зарегистрированное
  лицо».
- `Features → Face ID → Matching Face` — успешный сканер.
- `Features → Face ID → Non-matching Face` — фейл.

Когда `Enrolled = true`, `canEvaluatePolicy` возвращает `true`. После
`evaluatePolicy(...)` ты выбираешь из меню «Matching» или «Non-matching»,
и получаешь нужный результат.

> 💡 **Production-важно.** `LAContext` нужно держать **новый на каждый
> запрос**. Если ты переиспользуешь один и тот же `LAContext`,
> результат предыдущей проверки **кешируется** на 30 секунд (по
> умолчанию). Это сделано Apple для UX (не спрашивать FaceID при
> каждой purchase), но для security-критичных сценариев — баг.
> Поэтому в нашем `authenticate()` каждый раз создаётся новый
> `LAContext()`.

## 11.8 Privacy blur **без** биометрии

Можно иметь только blur, без биометрии. Это сценарий банкинга, где
пароль на вход не требуется при возврате через 1-2 секунды (если
человек просто свернул и сразу развернул), но защита в app-switcher'е
нужна.

В нашем `LifecycleSecurityController`:

```swift
private func handleEnterBackground() {
    guard let window else { return }
    if manifest.hasPrivacyBlurOnBackground {
        installBlur(on: window)
    }
    if manifest.requiresBiometricOnResume {
        installBlur(on: window) // двойная защита
    }
}

private func handleEnterForeground() {
    guard let window else { return }
    if manifest.requiresBiometricOnResume {
        showBiometricPrompt(on: window)
    } else {
        removeBlur()
    }
}
```

Если только `hasPrivacyBlurOnBackground` (без `requiresBiometricOnResume`)
— блюр ставим в `willDeactivate`, убираем в `didActivate`. Пользователь
не замечает «защиту», но в app-switcher'е её видит.

## 11.9 Profile mini-app — оба флага

В нашем playground'е `Profile` использует **оба** механизма:

```swift
AppManifest(
    id: "profile",
    name: "Профиль / Настройки",
    // ...
    hasAuthGate: true,
    hasPrivacyBlurOnBackground: true,
    requiresBiometricOnResume: true,
    makeMain: { ProfileViewController() }
),
```

Это полный набор «параноидального» приложения: auth gate при первом
заходе (Глава 8), блюр в app-switcher'е, Face ID при возврате из фона.
Аналогично работают банковские приложения и Apple Wallet.

> 🛠 **Упражнение.** Запусти Profile, войди (`test@uikit.kz`).
> Сверни приложение (Cmd+Shift+H в симуляторе). Открой app-switcher
> (двойной Cmd+Shift+H). Увидишь, что превью Profile — размытое, без
> содержимого. Верни приложение в foreground. iOS попросит Face ID —
> в симуляторе через меню `Features → Face ID → Matching Face`. После
> успешной проверки увидишь свой Profile.

## 11.10 Бытовая аналогия

Privacy blur — это **жалюзи на окнах банка**. Кто-то проходит мимо
здания (app-switcher), смотрит в окно — видит размытое движение, не
людей и не суммы на экранах.

Biometric on resume — это **охранник перед входом**. Каждый раз когда
ты возвращаешься (после обеда, например), нужно показать пропуск.
Жалюзи остаются опущены, пока охранник тебя не пропустил.

Если ты прошёл и ушёл совсем (logout / closed app) — банк закрылся,
жалюзи неважны.

## 11.11 Edge cases

**iOS-системный confirm.** Иногда нашу сцену деактивирует не пользователь,
а сама iOS — например, при вызове `UIDocumentPickerViewController`
или `SFSafariViewController`. Технически это **тоже** `willDeactivate`.
То есть наш блюр включится. При закрытии этих UI приложение
возвращается, блюр снимется. Видимо это нормально, но иногда мешает.

В production-приложении тогда часто различают:

- `willResignActive` — лёгкий случай, не блюрить.
- `didEnterBackground` — серьёзный (юзер свернул), блюрить.

У нас единая логика на `willDeactivate` — для playground'а хватит.

**Background tasks**. Если приложение делает что-то фоновое через
`BGTaskScheduler`, во время этой работы оно технически в "background"
state. Но визуально пользователь свернул и ушёл. `LifecycleSecurityController`
тут не помеха — ему важно только когда сцена **активна** или **нет**.

**iPad multi-scene.** На iPad могут быть несколько окон одного
приложения. Наш контроллер привязан к **одному** окну (по weak ссылке
в init). Если у тебя несколько окон с защищённым контентом — нужно
по контроллеру на каждое.

## 11.12 Что мы могли бы добавить

- **Time-based auth**. Если человек ушёл и вернулся через 30 секунд —
  не спрашивать биометрию. Через 5 минут — спрашивать.
- **Скрин-рекординг.** `UIScreen.capturedDidChangeNotification` —
  iOS-нотификация, когда экран записывается (Control Center → Record).
  Можно при срабатывании показать блюр на чувствительные элементы.
- **AirPlay / Mirroring.** Аналогично — при mirroring блюрить чтобы
  не транслировать на ТВ.

Эти улучшения — поверх той же базы (наблюдатель на нотификации +
управление UIView поверх window).

## 📋 Что мы выучили

- Lifecycle gate — **не VC**, обычный класс с подписками на
  `UIScene.willDeactivateNotification` и `didActivateNotification`.
- **Privacy blur** — `UIVisualEffectView` с `UIBlurEffect(style:
  .systemMaterial)`, добавляется прямо в `window.subviews`,
  гарантируя позицию **выше всех**.
- `MainActor.assumeIsolated { ... }` — мост между ObjC NotificationCenter
  и Swift main-actor методами.
- `[weak self]` в observer-closure — обязателен, иначе observer
  держит controller вечно.
- **Biometric** через `LAContext().evaluatePolicy(.deviceOwnerAuthentication
  WithBiometrics, localizedReason:)`.
- `canEvaluatePolicy(_:error:)` перед запросом — проверка, доступна
  ли биометрия (девайс / enrolled / settings).
- Новый `LAContext` на каждый запрос, иначе результат кешируется.
- `Info.plist` нужна строка `NSFaceIDUsageDescription` — иначе крах
  при первом вызове.
- Симулятор: `Features → Face ID → Enrolled / Matching / Non-matching`
  для тестирования.

## Apple Developer Documentation

- [Human Interface Guidelines — Privacy](https://developer.apple.com/design/human-interface-guidelines/privacy) — общий принцип: чувствительный UI нельзя оставлять на снимке, который iOS делает при сворачивании.
- [`UIBlurEffect`](https://developer.apple.com/documentation/uikit/uiblureffect) — стили блюра; `.systemMaterial` — оптимальный для privacy-overlay, адаптивный к light/dark.
- [`UIVisualEffectView`](https://developer.apple.com/documentation/uikit/uivisualeffectview) — view-обёртка над эффектом; добавляем напрямую в `window.subviews`, чтобы быть выше всех modal'ов.
- [`UIApplication.willResignActiveNotification`](https://developer.apple.com/documentation/uikit/uiapplication/willresignactivenotification) — лёгкий случай деактивации (входящий звонок, control center); часто блюрить тут не надо.
- [`UIApplication.didBecomeActiveNotification`](https://developer.apple.com/documentation/uikit/uiapplication/didbecomeactivenotification) — обратное событие; парный момент, когда снимаем блюр или запускаем биометрию.
- [`UIScene.willDeactivateNotification`](https://developer.apple.com/documentation/uikit/uiscene/willdeactivatenotification) — то же, но per-scene (актуально для iPad multi-window); используем именно её, чтобы корректно работать на iPad.
- [`UIScene.didActivateNotification`](https://developer.apple.com/documentation/uikit/uiscene/didactivatenotification) — парное активирование сцены.
- [`LAContext`](https://developer.apple.com/documentation/localauthentication/lacontext) — точка входа в биометрию; на каждый запрос новый экземпляр, иначе результат кешируется на 30 секунд.
- [`LAPolicy.deviceOwnerAuthenticationWithBiometrics`](https://developer.apple.com/documentation/localauthentication/lapolicy/deviceownerauthenticationwithbiometrics) — только Face ID / Touch ID, без fallback на passcode.
- [`LAPolicy.deviceOwnerAuthentication`](https://developer.apple.com/documentation/localauthentication/lapolicy/deviceownerauthentication) — биометрия с fallback на пароль устройства; для банкинга чаще берут именно её.
- [`NSFaceIDUsageDescription`](https://developer.apple.com/documentation/bundleresources/information_property_list/nsfaceidusagedescription) — обязательная строка в Info.plist, иначе крах при первом `evaluatePolicy`.

---

🎉 **Это конец Части II.** Дальше — Часть III, mini-приложения:
Todo, Notes, Calculator, Weather, Gallery, Music, Chat, Profile,
Tab Bar, Layouts, Anatomy. Каждое — отдельная глава с разбором
реального кода.

→ [Глава 12. Todo — UITableView, кастомная ячейка, UserDefaults+Codable](./20-todo.md)
