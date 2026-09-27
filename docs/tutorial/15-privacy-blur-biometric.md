# Глава 11. Privacy blur + Biometric on resume

Последний гейт нашей цепочки запуска. От всех предыдущих он
отличается принципиально: он работает **не только в начале**.
Splash, онбординг, экран-пояснение для разрешения показались — и
всё. А этот гейт живёт **всю сессию** и реагирует на события
жизненного цикла: приложение уходит в фон — закрываем экран
размытием; возвращается — просим Face ID.

В этой главе два связанных, но независимых механизма:

1. **Privacy blur** (размытие для приватности) — пока приложение не на
   переднем плане, вместо содержимого видно размытие. Соседи в
   очереди или коллеги через плечо не увидят баланс в переключателе
   приложений.
2. **Biometric on resume** (биометрия при возврате) — когда человек
   возвращается в приложение из фона, спросить Face ID или Touch ID,
   прежде чем показать данные.

Оба нужны приложениям с чувствительными данными: банкам,
мессенджерам, заметкам с паролями, медицинским картам.

Главное, что стоит вынести из главы, — **что биометрия гарантирует, а
что нет**. Экран «приложите лицо» сам по себе — это замок на двери
комнаты, а не сейф. Настоящий сейф — запись в Keychain, которую
система отдаёт только после Face ID. Разберём оба в разделе 11.8.

Полный код — в разделе 11.12.

## 11.1 Жизненный цикл сцены и снимок экрана

Напомню, как iOS сообщает приложению о смене состояний (подробно — в
главе 5). Приложение на iOS 13+ состоит из **сцен** (scene): сцена —
это одно окно приложения со своим интерфейсом. На iPhone она обычно
одна, на iPad их может быть несколько. У сцены есть состояния:

- **активна** (foreground active) — на экране, принимает касания;
- **неактивна** (foreground inactive) — видна, но касания не получает:
  поверх открыт Пункт управления, Центр уведомлений, системный alert,
  окно Face ID или переключатель приложений;
- **в фоне** (background) — не видна, скоро будет «заморожена».

Переходы приходят уведомлениями `NotificationCenter`:

- `UIScene.willDeactivateNotification` — сцена **сейчас перестанет**
  быть активной. Apple в документации перечисляет причины: временные
  прерывания (системные alert'ы) и уход в фон.
- `UIScene.didEnterBackgroundNotification` — сцена ушла в фон.
- `UIScene.didActivateNotification` — сцена снова активна.

Теперь о **снимке экрана** (snapshot). Документ Apple «Preparing your
UI to run in the background» описывает так: после того как приложение
ушло в фон и обработчик ухода в фон вернул управление, UIKit делает
снимок текущего интерфейса. Этот снимок показывается в переключателе
приложений и на мгновение — при возвращении в приложение. Та же статья
прямо требует: в интерфейсе не должно остаться чувствительных данных —
паролей, номеров карт. Снимок хранится в контейнере приложения на
диске и может пережить даже перезапуск.

Отсюда план:

- на `willDeactivate` накрываем окно размытием. Так закрыты сразу три
  случая: переключатель приложений (там сцена неактивна), системные
  шторки поверх приложения и снимок при уходе в фон — к моменту снимка
  размытие уже лежит сверху;
- на `didActivate` убираем размытие — если не нужна биометрия.

## 11.2 Контроллер «жизненного» гейта

В отличие от остальных гейтов, этот **не view controller**. Это
обычный класс, который владеет двумя view и подписан на уведомления:

```swift
final class LifecycleSecurityController {

    private weak var window: UIWindow?
    private let manifest: AppManifest

    private var blurView: UIVisualEffectView?
    private var biometricPromptView: UIView?

    private var observers: [NSObjectProtocol] = []
    private var isAuthenticating = false
    private var needsUnlock = false
    private var didAutoPrompt = false

    init(window: UIWindow, manifest: AppManifest) {
        self.window = window
        self.manifest = manifest
    }
}
```

Свойства по порядку:

- `window` — окно, которое закрываем. `weak`, потому что окно
  принадлежит `SceneDelegate`; контроллер не должен продлевать ему
  жизнь.
- `blurView` и `biometricPromptView` — наши две накладки: размытие и
  экран блокировки поверх него. `nil` — накладки сейчас нет.
- `observers` — «токены» подписок на уведомления, чтобы потом
  отписаться.
- `isAuthenticating` — идёт ли проверка Face ID прямо сейчас.
- `needsUnlock` — «приложение побывало в фоне, на входе нужна
  проверка».
- `didAutoPrompt` — «в этот раз Face ID уже спрашивали автоматически».

Зачем последние два флага и почему их нельзя заменить одним, — главный
сюжет раздела 11.5.

Почему не view controller? Этот гейт не становится корневым экраном —
он накладывается **поверх любого** экрана mini-app, включая модальные
окна и alert'ы. Для этого накладки кладутся прямо в окно
(`UIWindow`), выше всей иерархии view controller'ов. View controller
для этого не нужен.

Контроллер принадлежит `BootCoordinator` (глава 4). Когда координатор
показывает главный экран, он создаёт и запускает его:

```swift
private func startLifecycleSecurity() {
    guard let window else { return }
    let controller = LifecycleSecurityController(window: window, manifest: manifest)
    controller.start()
    lifecycleSecurity = controller
}
```

и держит сильной ссылкой (`lifecycleSecurity`) до выхода в лаунчер.
При выходе `stop()` снимает подписки и убирает накладки:

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
    let scene = window?.windowScene

    let resign = nc.addObserver(forName: UIScene.willDeactivateNotification,
                                object: scene, queue: .main) { [weak self] _ in
        MainActor.assumeIsolated { self?.handleWillDeactivate() }
    }
    let background = nc.addObserver(forName: UIScene.didEnterBackgroundNotification,
                                    object: scene, queue: .main) { [weak self] _ in
        MainActor.assumeIsolated { self?.handleDidEnterBackground() }
    }
    let active = nc.addObserver(forName: UIScene.didActivateNotification,
                                object: scene, queue: .main) { [weak self] _ in
        MainActor.assumeIsolated { self?.handleDidActivate() }
    }
    observers = [resign, background, active]
}

func stop() {
    observers.forEach { NotificationCenter.default.removeObserver($0) }
    observers.removeAll()
    removeBlur()
    removeBiometricPrompt()
}
```

Разбор:

- `guard` в начале — если у mini-app нет ни размытия, ни биометрии,
  подписываться незачем.
- `addObserver(forName:object:queue:using:)` — подписка «блоком»:
  передаёшь замыкание, и NotificationCenter вызывает его при каждом
  уведомлении. Метод возвращает **токен** (`NSObjectProtocol`). Чтобы
  отписаться, токен передают в `removeObserver(_:)` — это делает
  `stop()`.
- `object: scene` — слушаем уведомления **только своей** сцены. Если
  передать `nil`, придут уведомления от всех сцен приложения: на iPad
  с двумя окнами сворачивание одного окна закрыло бы размытием и
  второе. `window?.windowScene` — сцена, к которой относится окно.
- `queue: .main` — замыкание гарантированно выполняется на главной
  очереди. Это важно: трогать UIKit можно только с главного потока.
- `MainActor.assumeIsolated { ... }` — мост между старым API и нашим
  кодом главного актора. Замыкание NotificationCenter для компилятора
  не привязано к главному актору, а методы `handle...` — привязаны
  (как весь класс в нашем режиме). Мы знаем, что блок выполнится на
  главном потоке (`queue: .main`), но компилятор этого не знает.
  `assumeIsolated` говорит ему: «я уже на главном акторе, выполняй», а
  если это окажется неправдой, приложение остановится с понятной
  ошибкой. Доступен с iOS 13 — в нашем iOS 15 пользоваться можно без
  `@available`. (Альтернатива —
  `Task { @MainActor in self?.handleWillDeactivate() }`, но она
  выполнит код **позже**, на одном из новых проходов цикла событий, а нам
  нужно успеть поставить размытие до снимка.)
- `[weak self]` — обязательно. NotificationCenter держит замыкание, пока
  мы не отписались. Сильный `self` внутри удерживал бы контроллер —
  и он жил бы, даже когда координатор его отпустил.

## 11.4 Размытие

`UIVisualEffectView` с `UIBlurEffect` — стандартный способ получить
размытие «как в системе»:

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

По строкам:

- `guard blurView == nil` — защита от двойной установки. Уведомление
  о деактивации приходит и при открытии Пункта управления, и перед
  уходом в фон; без проверки мы положили бы два размытия друг на друга.
- `UIBlurEffect.Style.systemMaterial` — «материал» из системной
  палитры, сам подстраивается под светлую и тёмную тему. Есть тоньше
  (`.systemUltraThinMaterial`, `.systemThinMaterial` — сквозь них
  угадывается содержимое) и плотнее (`.systemThickMaterial`,
  `.systemChromeMaterial`). Для приватности нужен такой, через который
  не прочитать цифры. `.systemMaterial` — разумная середина; для
  совсем секретных экранов можно положить сверху ещё и непрозрачный фон
  с логотипом.
- `view.frame = window.bounds` — размытие размером с окно. `bounds` —
  прямоугольник окна в его собственных координатах: на iPhone 16 это
  (0, 0, 393, 852) точки.
- `autoresizingMask = [.flexibleWidth, .flexibleHeight]` — если окно
  изменит размер (поворот на iPad, изменение окна в многозадачности),
  размытие растянется вместе с ним. Это старый механизм
  «автоматического растягивания»: без констрейнтов, одной строкой. Для
  view «на весь родитель» его хватает.
- `window.addSubview(view)` — кладём прямо в окно, последним, то есть
  **поверх** всего: корневого экрана, модальных окон, alert'ов.

## 11.5 Возвращение: с биометрией или без

Здесь прячется главный подвох главы. Вот наивная версия:

```swift
// Так НЕ делаем
private func handleEnterForeground() {
    guard let window else { return }
    if manifest.requiresBiometricOnResume {
        showBiometricPrompt(on: window)   // и сразу запрос Face ID
    } else {
        removeBlur()
    }
}
```

Кажется логичным: вернулись — спросили Face ID. Но вспомни 11.1 (и
это мы видели в журнале запуска: как только появилось окно проверки,
сцена получила `willResignActive`):
сцена становится неактивной не только при уходе в фон, но и при
**любом системном окне поверх приложения**. А системное окно Face ID —
как раз такое. Получается цепочка:

1. Приложение вернулось → `didActivate` → показываем Face ID.
2. Окно Face ID открылось → сцена неактивна → `willDeactivate`.
3. Человек посмотрел в камеру, окно закрылось → `didActivate`.
4. Мы снова показываем Face ID → и по кругу.

Ещё хуже с Пунктом управления: человек лишь опустил шторку, чтобы
сделать экран ярче, — и при возврате получил требование Face ID, хотя
приложение никуда не уходило.

Решение — различать «побывали в фоне» и «на секунду прикрылись
шторкой»:

```swift
private func handleWillDeactivate() {
    guard let window else { return }
    installBlur(on: window)
}

private func handleDidEnterBackground() {
    guard manifest.requiresBiometricOnResume else { return }
    needsUnlock = true
    didAutoPrompt = false
}

private func handleDidActivate() {
    guard let window else { return }
    if needsUnlock {
        showBiometricPrompt(on: window)
        if !didAutoPrompt {
            didAutoPrompt = true
            authenticate()
        }
    } else if biometricPromptView == nil {
        removeBlur()
    }
}
```

Как это работает:

- **Размытие** ставим на любую деактивацию — и для шторки, и для фона.
- **Потребность в проверке** (`needsUnlock = true`) появляется только
  при настоящем уходе в фон. Окно Face ID или Пункт управления фон не
  вызывают — значит, и новой проверки не будет.
- **При возвращении:** если проверка нужна — показываем экран
  блокировки и **один раз** автоматически запускаем Face ID
  (`didAutoPrompt`). Если человек отменил Face ID, окно закрылось,
  пришёл новый `didActivate` — но `didAutoPrompt` уже `true`, и
  повторного запроса нет. Остаётся экран блокировки с кнопкой
  «Разблокировать»: человек сам решит, когда попробовать снова.
- **Если проверка не нужна** — убираем размытие. Но только когда нет
  экрана блокировки (`biometricPromptView == nil`): пока человек не
  прошёл проверку, размытие должно оставаться под экраном блокировки.

Проверь сценарии в голове:

| Что случилось | willDeactivate | didEnterBackground | didActivate |
|---|---|---|---|
| Опустил Пункт управления и вернул | размытие | — | убрали размытие |
| Свернул и вернулся | размытие | `needsUnlock = true` | экран блокировки + Face ID |
| Окно Face ID открылось и закрылось | размытие уже есть | — | экран блокировки остаётся, повторного запроса нет |

**Упражнение 11.1.** Сейчас Face ID спрашивается после **любого**
ухода в фон, даже на две секунды. Сделай «льготный период»: если
человек вернулся быстрее чем через 30 секунд, проверку не спрашивать.
Ответ — в конце главы.

## 11.6 Экран блокировки

```swift
private func showBiometricPrompt(on window: UIWindow) {
    guard biometricPromptView == nil else { return }
    installBlur(on: window)

    let container = UIView(frame: window.bounds)
    container.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    container.accessibilityViewIsModal = true

    let icon = UIImageView(image: UIImage(systemName: "lock.fill"))
    icon.tintColor = manifest.brandColor
    icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 48)

    var cfg = UIButton.Configuration.filled()
    cfg.title = unlockButtonTitle()
    cfg.baseBackgroundColor = manifest.brandColor
    cfg.cornerStyle = .capsule
    let button = UIButton(configuration: cfg, primaryAction: UIAction { [weak self] _ in
        self?.authenticate()
    })

    let stack = UIStackView(arrangedSubviews: [icon, button])
    stack.axis = .vertical
    stack.spacing = 24
    stack.alignment = .center
    stack.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(stack)
    NSLayoutConstraint.activate([
        stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
        stack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
    ])
    window.addSubview(container)
    biometricPromptView = container
}
```

- Сначала `installBlur` — на случай, если размытия почему-то нет. Наш
  guard внутри не даст положить второе.
- `container` — прозрачная view на всё окно поверх размытия. Иконка
  замка и кнопка — по центру.
- `accessibilityViewIsModal = true` — для VoiceOver: «за этой view
  ничего нет». Без этого незрячий человек мог бы пролистать диктором
  элементы экрана **под** размытием и услышать баланс вслух.
- Кнопка вызывает `authenticate()` — ручная повторная попытка.

Подпись кнопки зависит от того, какая биометрия есть на устройстве:

```swift
private func unlockButtonTitle() -> String {
    let context = LAContext()
    _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    switch context.biometryType {
    case .faceID: return "Разблокировать с Face ID"
    case .touchID: return "Разблокировать с Touch ID"
    default: return "Разблокировать"
    }
}
```

HIG советует называть способ входа прямо («с Face ID», а не просто
«Войти») и не упоминать Face ID на устройстве, где его нет.
`biometryType` заполняется только после вызова `canEvaluatePolicy`,
поэтому вызываем его, даже если результат нам не нужен (`_ =`).

## 11.7 Биометрия — LocalAuthentication

**LocalAuthentication** — фреймворк Apple для проверки владельца
устройства: Face ID, Touch ID или код-пароль. Главный класс —
`LAContext`, «контекст проверки»: один объект на одну проверку.
Правило App Review **2.5.13** требует для входа по лицу использовать
именно LocalAuthentication, а не свою распознавалку лиц.

```swift
private func authenticate() {
    guard !isAuthenticating else { return }
    let context = LAContext()
    let policy: LAPolicy = .deviceOwnerAuthentication
    var error: NSError?
    guard context.canEvaluatePolicy(policy, error: &error) else {
        if error?.code == LAError.passcodeNotSet.rawValue {
            // На устройстве нет даже код-пароля: проверять нечем.
            unlock()
        }
        return
    }
    isAuthenticating = true
    Task { [weak self] in
        let success: Bool
        do {
            success = try await context.evaluatePolicy(
                policy,
                localizedReason: "Подтверди, что это ты, чтобы открыть профиль"
            )
        } catch {
            success = false
        }
        guard let self else { return }
        self.isAuthenticating = false
        if success {
            self.unlock()
        }
    }
}

private func unlock() {
    needsUnlock = false
    removeBiometricPrompt()
    removeBlur()
}
```

Разберём.

**`isAuthenticating`** — защита от двух проверок одновременно: пока
окно Face ID открыто, повторный тап по кнопке ничего не сделает.

**Новый `LAContext` на каждую проверку.** Документация предупреждает:
не рассчитывай, что прошлая успешная проверка означает успех
новой. Контекст хранит состояние своей проверки; для новой проверки
создаём новый контекст — так ничего не «прилипнет» от прошлого раза.

**Политика** (`LAPolicy`) — что считается успешной проверкой:

- `.deviceOwnerAuthenticationWithBiometrics` — **только** Face ID или
  Touch ID. Если лицо не распозналось несколько раз подряд, биометрия
  блокируется, и войти будет нечем.
- `.deviceOwnerAuthentication` — биометрия, а если она не удалась или
  её нет — **код-пароль устройства**. Мы берём её: человек с
  повреждённым пальцем или в маске не останется запертым вне своего
  приложения.

**`canEvaluatePolicy(_:error:)`** — «можно ли сейчас проверить?». Для
нашей политики ответ «нет» бывает в основном по одной причине:
на устройстве не задан код-пароль (`LAError.passcodeNotSet`). Тогда
проверять нечем: без код-пароля нельзя включить и Face ID. Мы
пропускаем человека — иначе владелец никогда не попадёт в своё
приложение. Серьёзные банковские приложения в такой ситуации просят
завести собственный PIN приложения; для учебного примера достаточно
пропустить.

**`evaluatePolicy(_:localizedReason:)`** — сама проверка. Исходный
метод устроен на completion handler, который, как сказано в
документации, вызывается **на внутренней очереди фреймворка** — не на
главном потоке. Мы берём его async-версию, которую Swift создаёт
автоматически: `await` возвращает нас в код главного актора, и после
него можно спокойно трогать интерфейс. Ошибка (человек нажал
«Отменить», система прервала проверку) приходит как `throw` — считаем
это неуспехом.

> **Почему не completion handler.** Старый вариант —
> `context.evaluatePolicy(policy, localizedReason: ...) { success, error in ... }`.
> Мы проверили запуском в симуляторе: это замыкание действительно
> вызывается **не** на главном потоке (`Thread.isMainThread` внутри
> него — `false`). Значит, любую работу с интерфейсом внутри нужно
> вручную переносить на главный поток (`DispatchQueue.main.async`), и
> забыть об этом легко. Async-версия делает переход сама.

**`localizedReason`** — пояснение в системном окне проверки: зачем
просим. Документация Apple уточняет: коротко и ясно, на языке
пользователя, и **без названия приложения** — оно и так видно в окне
(в iOS — в подзаголовке). В симуляторе окно ввода код-пароля так и
выглядит: заголовок «Введите код-пароль iPhone для приложения
„G2Gates“», а под ним наша строка. Поэтому «Подтверди, что это ты,
чтобы открыть профиль», а не «Подтверди вход в Профиль».

**`NSFaceIDUsageDescription`** — отдельная строка в Info.plist,
которую iOS показывает, когда приложение **впервые** пытается
использовать Face ID: «Разрешить приложению использовать Face ID?».
Документация Apple: без этого ключа система не позволит приложению
использовать Face ID. Для Touch ID такой строки не требуется.

```xml
<key>NSFaceIDUsageDescription</key>
<string>Face ID защищает профиль, когда приложение возвращается из фона.</string>
```

При успехе — `unlock()`: снимаем флаг, экран блокировки и размытие.
При неудаче — всё остаётся как есть, человек может нажать
«Разблокировать» ещё раз.

> **Про повторное использование разблокировки.** У `LAContext` есть
> свойство `touchIDAuthenticationAllowableReuseDuration`. Оно не про
> «запомнить прошлую проверку в приложении», как часто думают, а про
> **разблокировку устройства**: если человек только что разблокировал
> iPhone Touch ID и это было не раньше чем указанное число секунд
> назад, проверка пройдёт сразу, без второго прикладывания пальца. По
> умолчанию 0 — повторное использование выключено; максимум задан
> константой `LATouchIDAuthenticationMaximumAllowableReuseDuration` — в
> iOS 26 это 300 секунд, то есть 5 минут (значение напечатано запуском).

## 11.8 Что биометрия гарантирует, а что нет

`evaluatePolicy` возвращает приложению **одно логическое значение**:
«да, это владелец» или «нет». Проверку лица делает защищённый
сопроцессор (Secure Enclave), и подделать само распознавание нельзя.
Но решение «пускать или нет» принимает **наш код**, в памяти нашего
процесса. На взломанном устройстве этот `if success` можно подменить —
и экран блокировки откроется без лица.

Поэтому экран блокировки из этой главы — защита от **случайного**
человека: от ребёнка, взявшего телефон, от коллеги, заглянувшего через
плечо. Он **не** защищает данные, если телефон попал в руки
подготовленному злоумышленнику.

Настоящая защита — привязать к биометрии **сам секрет**. В главе 8
токен лежал в Keychain и был доступен при разблокированном
устройстве. Можно положить его так, чтобы система выдавала его
**только** после Face ID — проверку тогда делает не наш `if`, а сама
iOS вместе с Secure Enclave:

```swift
import Foundation
import LocalAuthentication
import Security

nonisolated enum ProtectedTokenStore {
    private static let service = "kz.waid.uikitplayground.auth.protected"
    private static let account = "token"

    static func save(_ token: String) -> Bool {
        guard let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
            .biometryCurrentSet,
            nil
        ) else { return false }

        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(base as CFDictionary)
        var add = base
        add[kSecValueData as String] = Data(token.utf8)
        add[kSecAttrAccessControl as String] = access
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }

    static func read(reason: String) -> String? {
        let context = LAContext()
        context.localizedReason = reason
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: context,
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

func loadProtectedToken() async -> String? {
    await Task.detached {
        ProtectedTokenStore.read(reason: "Подтверди вход в аккаунт")
    }.value
}
```

Что здесь нового по сравнению с `AuthStorage` из главы 8:

- **`SecAccessControlCreateWithFlags`** создаёт правило доступа к
  записи. Два условия:
  - `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly` — запись
    существует, только пока на устройстве задан код-пароль, и не
    переезжает на другое устройство. Если человек снимет код-пароль,
    система **удалит** такие записи — токен пропадёт, и придётся войти
    заново;
  - `.biometryCurrentSet` — прочитать запись можно только после Face ID
    или Touch ID, и только с **текущим** набором лиц и пальцев. Если
    кто-то добавит в телефон своё лицо или палец, запись станет
    недоступной. Это защита от сценария «узнал код-пароль, добавил
    свой палец, открыл банк». Мягче — `.biometryAny` (любые, в том
    числе добавленные позже) или `.userPresence` (биометрия или
    код-пароль — пусть решит система).
- Правило кладётся в запись атрибутом `kSecAttrAccessControl` —
  вместо `kSecAttrAccessible` из главы 8.
- **Чтение** — тот же `SecItemCopyMatching`, но iOS сама показывает
  окно Face ID и отдаёт данные только после успеха. `LAContext` с
  `localizedReason` задаёт текст этого окна и передаётся атрибутом
  `kSecUseAuthenticationContext`.
- `SecItemCopyMatching` для такой записи **ждёт**, пока человек
  пройдёт проверку, — секунды. Держать главный поток всё это время
  нельзя: интерфейс замрёт. Поэтому `ProtectedTokenStore` объявлен
  `nonisolated` (не привязан к главному актору), а читают его через
  `Task.detached` — задачу, которая выполняется в фоне, вне главного
  актора. `await ... .value` дожидается результата, не блокируя главный
  поток.
- `SecItemDelete` + `SecItemAdd` вместо «добавить или обновить» из
  главы 8. Здесь это осознанно: обновить запись с биометрической
  защитой без самой проверки нельзя, поэтому старую удаляем, новую
  кладём.

С таким хранилищем экран блокировки из 11.6 становится просто
удобной оболочкой, а стеной работает iOS: без лица владельца токена в
памяти приложения просто нет.

**Упражнение 11.2.** Что произойдёт с токеном, сохранённым через
`ProtectedTokenStore`, в каждом случае: (а) человек добавил второе лицо
в «Альтернативный внешний вид» Face ID; (б) человек выключил
код-пароль; (в) человек перенёс данные на новый iPhone через
резервную копию? Ответ — в конце главы.

## 11.9 Проверка в симуляторе

В симуляторе нет камеры TrueDepth, но Face ID можно изобразить через
меню **Features → Face ID** (меню в окне приложения Simulator):

- **Enrolled** — «лицо записано». Пока пункт не отмечен, у симулятора
  нет биометрии.
- **Matching Face** — нажимаешь, когда открыто окно Face ID, и
  проверка проходит.
- **Non-matching Face** — проверка не проходит.

Когда отмечено **Enrolled**, `canEvaluatePolicy` для нашей политики
возвращает `true`, и появляется системное окно Face ID. После этого
выбираешь в меню Matching или Non-matching — и получаешь нужный
результат.

А если **Enrolled** не отмечено? Мы проверили запуском: политика
«только биометрия» (`.deviceOwnerAuthenticationWithBiometrics`) даёт
`false` с ошибкой «биометрия не настроена» (`biometryNotEnrolled`), а
наша `.deviceOwnerAuthentication` даёт `true` — и iOS показывает окно
ввода код-пароля. Так что без Enrolled ты увидишь запасной путь, а не
Face ID. Для проверки главы сначала включи Enrolled.

**Упражнение 11.3.** Запусти Profile, войди (`test@uikit.kz`, глава 8).
Включи Features → Face ID → Enrolled. Сверни приложение (⇧⌘H). Открой
переключатель приложений (Device → App Switcher). Что видно на
карточке Profile? Вернись в приложение. Что появится? Выбери
Non-matching Face, потом нажми «Разблокировать» и выбери Matching
Face. Ответ — в конце главы.

## 11.10 Бытовая аналогия

Размытие — **жалюзи на окнах банка**. Прохожий (переключатель
приложений) заглядывает в окно и видит размытые силуэты, а не суммы на
экранах. Жалюзи опускают, даже когда сотрудник просто отвернулся к
шкафу (шторка Пункта управления), — так надёжнее.

Экран блокировки — **охранник у входа**. Он проверяет пропуск, только
если ты выходил из здания (ушёл в фон), а не когда ты отвернулся к
окну. И если ты не нашёл пропуск с первого раза, он не будет требовать
его каждые две секунды — подождёт, пока ты сам подойдёшь снова (кнопка
«Разблокировать»).

А Keychain с `.biometryCurrentSet` — **банковская ячейка**,
которая открывается только отпечатком владельца. Даже если охранника
обманули, ячейку без пальца не открыть.

## 11.11 Краевые случаи

**Системные окна поверх приложения.** Документ-пикер, окно «Поделиться»,
alert разрешения — некоторые из них показываются в отдельном
процессе и деактивируют сцену. Размытие на мгновение появится. Это
плата за то, что мы закрываем переключатель приложений. Банковские
приложения обычно мирятся с этим.

**Фоновые задачи.** Если приложение выполняет фоновую работу
(`BGTaskScheduler`), интерфейс ему в фоне не нужен. Нашему контроллеру
это не мешает: он реагирует только на смену состояний сцены.

**iPad и несколько окон.** Контроллер привязан к одному окну и слушает
только его сцену (`object: scene` в 11.3). Если у приложения несколько
окон с чувствительным содержимым — нужно по контроллеру на каждое.

**Скриншоты и запись экрана.** Размытие не защищает от снимка экрана,
который делает сам человек. iOS не даёт приложению запретить снимок
экрана: уведомление `UIApplication.userDidTakeScreenshotNotification`
приходит уже **после** снимка. Запись экрана и трансляцию (AirPlay)
можно заметить: в iOS 17+ — через `traitCollection.sceneCaptureState`,
в более старых — через `UIScreen.main.isCaptured` и уведомление
`UIScreen.capturedDidChangeNotification`. При записи можно закрыть
чувствительные элементы.

## 11.12 Код целиком

`ProtectedTokenStore` приведён полностью в 11.8. Ниже —
`LifecycleSecurityController` одним файлом. `AppManifest` — из главы 2.

```swift
import UIKit
import LocalAuthentication

final class LifecycleSecurityController {

    private weak var window: UIWindow?
    private let manifest: AppManifest

    private var blurView: UIVisualEffectView?
    private var biometricPromptView: UIView?

    private var observers: [NSObjectProtocol] = []
    private var isAuthenticating = false
    private var needsUnlock = false
    private var didAutoPrompt = false

    init(window: UIWindow, manifest: AppManifest) {
        self.window = window
        self.manifest = manifest
    }

    func start() {
        guard manifest.hasPrivacyBlurOnBackground || manifest.requiresBiometricOnResume else { return }
        let nc = NotificationCenter.default
        let scene = window?.windowScene

        let resign = nc.addObserver(forName: UIScene.willDeactivateNotification,
                                    object: scene, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.handleWillDeactivate() }
        }
        let background = nc.addObserver(forName: UIScene.didEnterBackgroundNotification,
                                        object: scene, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.handleDidEnterBackground() }
        }
        let active = nc.addObserver(forName: UIScene.didActivateNotification,
                                    object: scene, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.handleDidActivate() }
        }
        observers = [resign, background, active]
    }

    func stop() {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
        removeBlur()
        removeBiometricPrompt()
    }

    private func handleWillDeactivate() {
        guard let window else { return }
        installBlur(on: window)
    }

    private func handleDidEnterBackground() {
        guard manifest.requiresBiometricOnResume else { return }
        needsUnlock = true
        didAutoPrompt = false
    }

    private func handleDidActivate() {
        guard let window else { return }
        if needsUnlock {
            showBiometricPrompt(on: window)
            if !didAutoPrompt {
                didAutoPrompt = true
                authenticate()
            }
        } else if biometricPromptView == nil {
            removeBlur()
        }
    }

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

    private func showBiometricPrompt(on window: UIWindow) {
        guard biometricPromptView == nil else { return }
        installBlur(on: window)

        let container = UIView(frame: window.bounds)
        container.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.accessibilityViewIsModal = true

        let icon = UIImageView(image: UIImage(systemName: "lock.fill"))
        icon.tintColor = manifest.brandColor
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 48)

        var cfg = UIButton.Configuration.filled()
        cfg.title = unlockButtonTitle()
        cfg.baseBackgroundColor = manifest.brandColor
        cfg.cornerStyle = .capsule
        let button = UIButton(configuration: cfg, primaryAction: UIAction { [weak self] _ in
            self?.authenticate()
        })

        let stack = UIStackView(arrangedSubviews: [icon, button])
        stack.axis = .vertical
        stack.spacing = 24
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])
        window.addSubview(container)
        biometricPromptView = container
    }

    private func removeBiometricPrompt() {
        biometricPromptView?.removeFromSuperview()
        biometricPromptView = nil
    }

    private func unlockButtonTitle() -> String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return "Разблокировать с Face ID"
        case .touchID: return "Разблокировать с Touch ID"
        default: return "Разблокировать"
        }
    }

    private func authenticate() {
        guard !isAuthenticating else { return }
        let context = LAContext()
        let policy: LAPolicy = .deviceOwnerAuthentication
        var error: NSError?
        guard context.canEvaluatePolicy(policy, error: &error) else {
            if error?.code == LAError.passcodeNotSet.rawValue {
                // На устройстве нет даже код-пароля: проверять нечем.
                unlock()
            }
            return
        }
        isAuthenticating = true
        Task { [weak self] in
            let success: Bool
            do {
                success = try await context.evaluatePolicy(
                    policy,
                    localizedReason: "Подтверди, что это ты, чтобы открыть профиль"
                )
            } catch {
                success = false
            }
            guard let self else { return }
            self.isAuthenticating = false
            if success {
                self.unlock()
            }
        }
    }

    private func unlock() {
        needsUnlock = false
        removeBiometricPrompt()
        removeBlur()
    }
}
```

В нашем playground'е оба механизма включены у Profile — вместе с auth
gate из главы 8:

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

Это полный набор «осторожного» приложения: вход при первом открытии,
размытие в переключателе, Face ID при возвращении. Так же ведут себя
многие банковские приложения.

## 11.13 Что можно добавить

- **Льготный период** — не спрашивать Face ID, если человек вернулся
  быстро (упражнение 11.1).
- **Своё изображение вместо размытия** — логотип на фоне фирменного
  цвета. Выглядит аккуратнее размытого пятна и точно ничего не
  просвечивает.
- **Реакция на запись экрана** — закрывать суммы и номера карт, пока
  идёт запись или трансляция (11.11).

Всё это — поверх той же основы: подписка на уведомления сцены и view
поверх окна.

## Ответы к упражнениям

**11.1.** Запоминаем время ухода в фон и решаем о проверке при
возвращении:

```swift
private var backgroundedAt: Date?
private let gracePeriod: TimeInterval = 30

private func handleDidEnterBackground() {
    guard manifest.requiresBiometricOnResume else { return }
    backgroundedAt = Date()
    didAutoPrompt = false
}

private func handleDidActivate() {
    guard let window else { return }
    if let backgroundedAt {
        self.backgroundedAt = nil
        if Date().timeIntervalSince(backgroundedAt) > gracePeriod {
            needsUnlock = true
        }
    }
    if needsUnlock {
        showBiometricPrompt(on: window)
        if !didAutoPrompt {
            didAutoPrompt = true
            authenticate()
        }
    } else if biometricPromptView == nil {
        removeBlur()
    }
}
```

`Date().timeIntervalSince(backgroundedAt)` — сколько секунд прошло с
ухода в фон. Вернулся через 12 секунд — 12 меньше 30, проверки нет.
Через 45 — больше 30, `needsUnlock = true`. `backgroundedAt`
обнуляем сразу, чтобы очередной `didActivate` (например, после
Пункта управления) не пересчитывал старое время. Проверка: сверни и
сразу разверни — экран без Face ID; сверни, подожди минуту — Face ID
появится.

Учти: часы устройства человек может перевести, и тогда разница
окажется неверной. Для льготного периода в 30 секунд это не страшно; для
серьёзных сроков используют монотонное время, которое не зависит от
настроек часов.

**11.2.** (а) Запись станет недоступной: `.biometryCurrentSet`
привязан к набору лиц и пальцев на момент сохранения, а новое лицо
этот набор меняет. Чтение вернёт ошибку, приложению нужно будет
попросить войти заново и сохранить токен снова. (б) Система удалит
запись: у неё `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly`, а
такие записи живут, только пока задан код-пароль. (в) Запись не
переедет: суффикс `ThisDeviceOnly` запрещает восстановление на другом
устройстве. На новом iPhone человек войдёт заново.

**11.3.** На карточке Profile в переключателе — размытие вместо
содержимого (его положил `willDeactivate`). При возвращении появится
экран блокировки с замком и кнопкой «Разблокировать с Face ID», и
сразу откроется окно Face ID. После Non-matching Face окно проверки
предложит повторить попытку или ввести код-пароль; если отменить,
останется экран блокировки, и Face ID сам больше не появится. Тап
«Разблокировать» и Matching Face — экран блокировки и размытие
исчезнут, виден Profile.

## Что мы выучили

- «Жизненный» гейт — не view controller, а обычный класс с подпиской
  на уведомления **своей** сцены: `willDeactivate`,
  `didEnterBackground`, `didActivate`.
- Снимок для переключателя приложений iOS делает после ухода в фон;
  размытие ставим уже на `willDeactivate` — оно закрывает и
  переключатель, и шторки, и снимок.
- Размытие — `UIVisualEffectView` с `UIBlurEffect(style:
  .systemMaterial)`, прямо в окне, поверх всего.
- `MainActor.assumeIsolated` (iOS 13+) — мост между замыканием
  NotificationCenter на `.main` и методами главного актора.
- `[weak self]` в замыканиях подписок и `removeObserver` в `stop()` —
  иначе контроллер не освободится.
- Проверку Face ID требуем только после настоящего ухода в фон, иначе
  окно Face ID и Пункт управления запускают бесконечный круг.
- `LAContext` — новый на каждую проверку; политика
  `.deviceOwnerAuthentication` даёт запасной путь через код-пароль;
  `localizedReason` — без названия приложения.
- `evaluatePolicy` берём в async-версии: completion handler
  вызывается не на главном потоке, а `await` возвращает нас на главный
  актор сам.
- `NSFaceIDUsageDescription` обязателен: без него Face ID приложению
  недоступен.
- Экран блокировки защищает от случайного человека, а не от взлома.
  Настоящая защита — Keychain с `SecAccessControl` и
  `.biometryCurrentSet`.
- Симулятор: Features → Face ID → Enrolled / Matching Face /
  Non-matching Face.

## Apple Developer Documentation

- [Human Interface Guidelines — Privacy](https://developer.apple.com/design/human-interface-guidelines/privacy) — хранить чувствительное в Keychain, не изобретать свои схемы проверки, предпочитать системные (Face ID, Touch ID, passkeys).
- [Preparing your UI to run in the background](https://developer.apple.com/documentation/uikit/preparing-your-ui-to-run-in-the-background) — когда UIKit делает снимок для переключателя приложений и почему из интерфейса нужно убрать чувствительные данные.
- [`UIBlurEffect`](https://developer.apple.com/documentation/uikit/uiblureffect) — стили размытия; `.systemMaterial` подстраивается под светлую и тёмную тему.
- [`UIVisualEffectView`](https://developer.apple.com/documentation/uikit/uivisualeffectview) — view с эффектом; кладём её прямо в окно, поверх всех экранов.
- [`UIScene.willDeactivateNotification`](https://developer.apple.com/documentation/uikit/uiscene/willdeactivatenotification) — сцена перестаёт быть активной: системные окна поверх и уход в фон.
- [`UIScene.didActivateNotification`](https://developer.apple.com/documentation/uikit/uiscene/didactivatenotification) — сцена снова активна.
- [`UIApplication.willResignActiveNotification`](https://developer.apple.com/documentation/uikit/uiapplication/willresignactivenotification) — то же на уровне всего приложения, без различия сцен.
- [`UIApplication.didBecomeActiveNotification`](https://developer.apple.com/documentation/uikit/uiapplication/didbecomeactivenotification) — парное событие для всего приложения.
- [`LAContext`](https://developer.apple.com/documentation/localauthentication/lacontext) — проверка владельца устройства; новый контекст на каждую проверку.
- [Logging a user into your app with Face ID or Touch ID](https://developer.apple.com/documentation/localauthentication/logging-a-user-into-your-app-with-face-id-or-touch-id) — официальный пример: `NSFaceIDUsageDescription`, контекст, политики.
- [`LAPolicy.deviceOwnerAuthenticationWithBiometrics`](https://developer.apple.com/documentation/localauthentication/lapolicy/deviceownerauthenticationwithbiometrics) — только Face ID / Touch ID, без запасного код-пароля.
- [`LAPolicy.deviceOwnerAuthentication`](https://developer.apple.com/documentation/localauthentication/lapolicy/deviceownerauthentication) — биометрия с запасным код-паролем; её берём для экрана блокировки.
- [`NSFaceIDUsageDescription`](https://developer.apple.com/documentation/bundleresources/information_property_list/nsfaceidusagedescription) — обязательная строка в Info.plist для Face ID.
- [Restricting keychain item accessibility](https://developer.apple.com/documentation/security/restricting-keychain-item-accessibility) — `SecAccessControl`, `.userPresence` и биометрические флаги для записей Keychain.

---

**Это конец Части II.** Дальше — Часть III, mini-приложения: Todo,
Notes, Calculator, Weather, Gallery, Music, Chat, Profile, Tab Bar,
Layouts, Anatomy. Каждое — отдельная глава с разбором кода.

→ [Глава 12. Todo — UITableView, ячейка-чек, UserDefaults+Codable, dummyjson](./20-todo.md)
