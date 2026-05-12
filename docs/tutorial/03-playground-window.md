# Глава 3. PlaygroundWindow — UIWindow с shake-detect

Когда пользователь зашёл в mini-app — например, в Калькулятор — он
оказывается «внутри отдельного приложения». Кнопки «← Назад» сверху нет
(мы не используем `UINavigationController` вокруг лаунчера —
mini-app **заменяет** root полностью). На жест свайпа от левого края
полагаться нельзя: он работает только внутри nav-стека.

Нужен другой механизм возврата. И в iOS он уже есть — **встряхивание**
устройства, `shake`-жест. Apple использует его для отмены ввода
(«встряхни, чтобы отменить»). Симулятор имитирует его
шорткатом **Ctrl+Cmd+Z**.

В этой главе мы делаем кастомный `UIWindow`, который ловит shake и
зовёт callback. Никаких сторонних библиотек, около 25 строк кода, плюс
понимание responder chain.

## 3.1 Что такое UIWindow и почему его обычно никто не трогает

`UIWindow` — это контейнер верхнего уровня сцены. На айфоне обычно
одно окно на всё приложение (бывают исключения — для AirPlay или
внешних дисплеев, но это редкость).

В большинстве проектов окно создают и забывают. Внутри `SceneDelegate`
обычно одна строка:

```swift
window = UIWindow(windowScene: windowScene)
```

Дальше с окном не работают — все экраны живут как `rootViewController`
и его дети.

Нам этого мало. Мы хотим, чтобы окно само ловило shake и реагировало.
Поэтому делаем подкласс — `PlaygroundWindow`.

## 3.2 Минимальный подкласс

Файл: `App/PlaygroundWindow.swift`. Весь класс — 25 строк:

```swift
final class PlaygroundWindow: UIWindow {

    var onShake: (() -> Void)?

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        guard motion == .motionShake else { return }
        onShake?()
    }
}
```

Что здесь происходит:

- `onShake: (() -> Void)?` — callback. Кто хочет реагировать на shake,
  присваивает функцию. Кто не хочет — оставляет `nil`.
- Переопределённый `motionEnded(_:with:)` — метод из `UIResponder`,
  который iOS зовёт после shake-жеста.
- `guard motion == .motionShake` — на всякий случай. У `EventSubtype`
  есть и другие значения (`motionShake` единственный публичный, но
  страховка не повредит).
- `onShake?()` — вызываем callback, если он установлен.

`super.motionEnded(motion, with: event)` зовём обязательно. Если убрать
— могут сломаться системные функции (например, «встряхни для отмены»
ввода в `UITextField` перестанет работать).

> 💡 **Идея.** Окно — нижний уровень responder chain. Все события, на
> которые **никто** не отреагировал по пути от first responder вверх,
> попадают сюда. Поэтому окно — идеальное место для глобальных
> shortcut'ов: shake, hardware-кнопки, motion-события.

## 3.3 Responder chain — короткое введение

`motionEnded` — это часть UIResponder API. Когда iOS детектит shake,
он зовёт `motionEnded` на **first responder**'е (обычно — это поле
ввода, в которое сейчас пишет пользователь, или активный VC). Если
тот не обработал событие — он вызывает `super.motionEnded(...)`,
который идёт **вверх** по responder chain.

Цепочка примерно такая:

```
UITextField (first responder)
    ↓ super
UIView
    ↓ super
UIViewController
    ↓ super
UIView (другие)
    ↓ super
UIWindow            ← здесь мы и ловим
    ↓ super
UIApplication
    ↓ super
AppDelegate
```

Каждое звено может «съесть» событие или передать дальше. Мы ловим **в
окне** — самой надёжной точке, потому что:

- окно есть всегда (а конкретный VC мог быть деаллоцирован);
- окно одно, в отличие от десятка VC, каждому из которых пришлось бы
  подписываться.

Альтернатива — подписаться через `NotificationCenter` или сделать
протокол, который реализуют все VC. Оба варианта работают, но
требуют дисциплины. С окном — забыть нельзя, окно всегда в строю.

## 3.4 Кто устанавливает `onShake`

Сам `PlaygroundWindow` не знает, что делать при встряхивании. Решает
это **`BootCoordinator`** — когда запускает mini-app, он
устанавливает callback:

```swift
// фрагмент из BootCoordinator.start()
window?.onShake = { [weak self] in
    self?.exitToLauncher()
}
```

И когда пользователь возвращается в лаунчер, координатор **сбрасывает**:

```swift
private func exitToLauncher() {
    window?.onShake = nil
    onExit()
}
```

После этого shake уже ничего не делает. Это правильно — в лаунчере
встряхивать незачем, выходить некуда.

> ⚠ **`[weak self]` — обязательно.** Координатор держит ссылку на окно,
> окно держит замыкание. Если в замыкании захватить `self` сильно —
> получим retain-cycle, координатор не сможет деаллоцироваться. Это
> классическая ловушка с замыканиями в UIKit.

## 3.5 Где создаётся окно

В `SceneDelegate.swift`:

```swift
func scene(_ scene: UIScene,
           willConnectTo session: UISceneSession,
           options connectionOptions: UIScene.ConnectionOptions) {
    guard let windowScene = scene as? UIWindowScene else { return }

    let window = PlaygroundWindow(windowScene: windowScene)
    // ... настройка лаунчера ...
    window.makeKeyAndVisible()
    self.window = window
}
```

`UIWindow(windowScene:)` — стандартный инициализатор окна. Мы
используем подкласс — `PlaygroundWindow` — но интерфейс тот же.

`makeKeyAndVisible()` — делает окно главным и видимым. Без этого экран
останется чёрным.

`self.window = window` — сохраняем сильную ссылку в SceneDelegate. Без
этого окно деаллоцируется сразу после выхода из метода, и приложение
упадёт.

## 3.6 Как проверить shake в симуляторе

В Xcode-симуляторе физически устройство не потрясёшь, но есть шорткат:

- В меню симулятора: `Device → Shake`.
- Клавиатурный shortcut: **Ctrl+Cmd+Z**.

Важно: фокус должен быть на окне симулятора. Если ты тыкаешь в
`Cmd+Z` в Xcode — это **undo** в редакторе, не shake.

На устройстве shake работает буквально — потряс iPhone, сработало.
В реальных приложениях этот жест часто отключают (потому что у Apple
есть глобальная подписка «встряхни для отмены ввода», и пользователь
может случайно отменить набранный текст). В playground'е это допустимо.

> 🛠 **Упражнение.** Запусти приложение, зайди в Калькулятор, набери
> что-нибудь (например, «42+8»). Нажми Ctrl+Cmd+Z. Если окно симулятора
> в фокусе — вернёшься в лаунчер. Зайди в Калькулятор снова — увидишь,
> что состояние сбросилось. Это потому, что `CalculatorViewController`
> создаётся заново через `makeMain` (см. Главу 2).

## 3.7 Бытовая аналогия

Окно — **дверь в офис**. Каждый VC — это **комната** внутри. Когда
кто-то стучит снаружи, стук может услышать любой человек в любой
комнате (responder chain снизу вверх). Если он занят — стук передаётся
дальше. До тех пор, пока не дойдёт до двери.

Дверь (окно) — последняя инстанция. Она **всегда** есть и
**всегда** слушает. Поэтому глобальный обработчик «впустить кого-то с
улицы» ставим именно на неё.

## 3.8 Что мы могли бы сделать вместо shake

Вариантов «как вернуться в лаунчер» несколько:

- **Системная кнопка home** — но Apple Home Indicator не для этого
  (он закрывает приложение, не возвращает в кастомный экран).
- **Drag from edge** — работает только если внутри `UINavigationController`,
  у нас mini-app сам себе root.
- **Долгое нажатие на статус-бар** — нестандартный жест, не интуитивен.
- **Невидимая кнопка в углу** — портит дизайн.
- **Shake** — изолированный жест, не конфликтует с UI mini-app, в
  симуляторе есть шорткат.

Shake — компромисс. В production-приложении я бы не делал такое
(пользователи не знают про этот жест без подсказки), но для учебного
playground'а — лучший вариант: не требует UI-элементов и не ломает
дизайн mini-apps.

> 🛠 **Упражнение.** Добавь в `AppListViewController` (лаунчер) тап на
> заголовок «UIKit Playground», который тоже зовёт `onShake`-callback,
> если он есть. Зайди в любой mini-app, потом тапни этот заголовок —
> по идее вернёшься в лаунчер (но только если как-то достучишься до
> него: в реальности заголовок не виден из mini-app, потому что лаунчер
> уже не root). Это упражнение показывает **изоляцию root'ов**: VC,
> которые не root, недоступны из текущего иерархии view.

## 📋 Что мы выучили

- `UIWindow` — контейнер верхнего уровня. Обычно его не трогают, но
  для глобальных жестов — самое надёжное место подписаться.
- `motionEnded(_:with:)` — UIResponder-метод. iOS вызывает его на
  first responder, дальше идёт по responder chain. Окно ловит, что
  не съел кто-то выше.
- `onShake: (() -> Void)?` — callback. `BootCoordinator` ставит
  его при входе в mini-app, сбрасывает при выходе.
- Всегда зови `super.motionEnded(...)` — иначе ломаются системные
  функции (типа undo).
- `[weak self]` в замыкании — обязательно. Иначе retain-cycle.
- В симуляторе shake — Ctrl+Cmd+Z или Device → Shake. На устройстве —
  буквально встряхнуть.

## Apple Developer Documentation

- [`UIWindow`](https://developer.apple.com/documentation/uikit/uiwindow) — базовый класс окна, который мы наследуем в `PlaygroundWindow`.
- [`UIWindowScene`](https://developer.apple.com/documentation/uikit/uiwindowscene) — сцена, к которой привязывается окно; инициализатор `UIWindow(windowScene:)`.
- [`UIResponder.motionEnded(_:with:)`](https://developer.apple.com/documentation/uikit/uiresponder/1621090-motionended) — точка, куда iOS доставляет shake после прохода по responder chain.
- [`UIEvent.EventSubtype.motionShake`](https://developer.apple.com/documentation/uikit/uievent/eventsubtype/motionshake) — единственный публичный подтип motion-события, который и проверяем в `guard`.
- [`UIResponder`](https://developer.apple.com/documentation/uikit/uiresponder) — общий обзор responder chain, в которой окно — последняя инстанция.
- [Multitasking — Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/multitasking) — продуктовый контекст, когда у приложения может быть несколько окон одной сцены.

→ [Глава 4. BootCoordinator — оркестратор гейтов](./04-boot-coordinator.md)
