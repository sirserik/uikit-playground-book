# Глава 33. Cookbook — haptics

Тактильная отдача. Все три типа генераторов + когда что использовать.

## 33.1 Impact (тактильный удар)

**Когда применять.** Любой UI-event, где хочется «отзыва»: кнопка
нажата, ячейка выбрана, переключатель щёлкнул.

```swift
let haptic = UIImpactFeedbackGenerator(style: .medium)
haptic.impactOccurred()

// С интенсивностью (iOS 13+)
haptic.impactOccurred(intensity: 0.6)
```

Стили:
- **`.light`** — самый мягкий.
- **`.medium`** — средний. Default для тапа.
- **`.heavy`** — сильный.
- **`.soft`** (iOS 13+) — мягкий, но «глубже».
- **`.rigid`** (iOS 13+) — резкий короткий.

`intensity: 0.5` — половина силы. Полная (1.0) для частых тапов
слишком сильно.

## 33.2 Notification (success / warning / error)

**Когда применять.** Сообщение о результате действия.

```swift
let notification = UINotificationFeedbackGenerator()
notification.notificationOccurred(.success)  // или .warning / .error
```

Три типа — три **разных** паттерна вибрации:
- **`.success`** — два коротких импульса. «Готово!».
- **`.warning`** — два более резких. «Внимание».
- **`.error`** — три-четыре с паузами. «Ошибка».

## 33.3 Selection (короткий тик)

**Когда применять.** Выбор из списка, scroll'инг между значениями
(picker), переключение сегмента.

```swift
let selection = UISelectionFeedbackGenerator()
selection.selectionChanged()
```

Очень короткий, тонкий тик. Подходит для **частых** событий
(прокрутка picker'а — на каждое изменение).

## 33.4 Prepare для оптимизации

Haptic engine «спит» в фоне. Первый вызов после длительного простоя
имеет задержку 100-200ms.

```swift
let haptic = UIImpactFeedbackGenerator(style: .medium)
haptic.prepare()  // прогрев

// ... через секунду или две:
haptic.impactOccurred()  // мгновенно, без задержки
```

Когда вызывать `prepare()`:

- Перед **ожидаемым** event'ом. Например, юзер начал scrubbing slider'а
  — prepare. Через секунду он отпустит — impact срабатывает мгновенно.
- На load view, если в этом screen будут haptic'и.

Когда **не нужен** prepare:

- Если haptic'и идут постоянно (chat → typing → haptic при отправке
  сообщения). Engine остаётся прогретым.
- При тапах, когда задержка незаметна.

## 33.5 Reuse vs new generator

```swift
// Один на класс — лучше
class ChatVC {
    private let haptic = UIImpactFeedbackGenerator(style: .light)

    private func sendTapped() {
        haptic.impactOccurred()
    }
}

// Каждый раз новый — хуже
private func sendTapped() {
    let haptic = UIImpactFeedbackGenerator(style: .light)  // создаём и выкидываем
    haptic.impactOccurred()  // может быть задержка
}
```

Generator — лёгкий, но переиспользование уменьшает шансы на cold
start.

## 33.6 Custom haptics (Core Haptics, iOS 13+)

Для **сложных** паттернов (игра «бомбочка» с нарастающей вибрацией):

```swift
import CoreHaptics

class HapticEngine {
    private var engine: CHHapticEngine?

    init() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            engine = try CHHapticEngine()
            try engine?.start()
        } catch {
            print("Haptic engine failed: \(error)")
        }
    }

    func playCustom() {
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
        let event = CHHapticEvent(eventType: .hapticTransient,
                                  parameters: [intensity, sharpness],
                                  relativeTime: 0)
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine?.makePlayer(with: pattern)
            try player?.start(atTime: 0)
        } catch {
            print("Failed to play haptic: \(error)")
        }
    }
}
```

`CHHapticEngine` — низкоуровневый API. Можно создавать паттерны из
многих events с разной intensity / sharpness / время.

Сложно. Используй только если стандартных generator'ов не хватает.

## 33.7 Когда haptic'и **не нужны**

- **Scrolling в обычной таблице** — там их и так нет от системы.
- **На каждое нажатие клавиатуры** — система уже даёт keyboard click
  (если включён в Settings).
- **Long-running operations** — postlimited, не во время.
- **В Accessibility mode "Reduce Motion"** — Apple рекомендует
  снижать тактильные эффекты тоже.

Проверка:

```swift
if !UIAccessibility.isReduceMotionEnabled {
    haptic.impactOccurred()
}
```

## 33.8 Haptic для slider'а

```swift
class HapticSlider: UISlider {
    private let haptic = UIImpactFeedbackGenerator(style: .light)
    private var lastTick: Float = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        addTarget(self, action: #selector(check), for: .valueChanged)
    }

    @objc private func check() {
        let bucket = (value * 20).rounded()
        if bucket != lastTick {
            haptic.impactOccurred(intensity: 0.5)
            lastTick = bucket
        }
    }
}
```

Делим [0..1] на 20 секций. Haptic на каждое изменение секции — «крутилка
с засечками». Detail в Главе 17 (Music Player).

## 33.9 Haptic при достижении цели

«Конкурс марафона: достигнут шаг 10000»:

```swift
func didReachGoal() {
    let notification = UINotificationFeedbackGenerator()
    notification.notificationOccurred(.success)

    // Дополнительно — bounce анимация
    UIView.animate(withDuration: 0.2, animations: {
        self.goalIcon.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
    }) { _ in
        UIView.animate(withDuration: 0.3, delay: 0,
                       usingSpringWithDamping: 0.5, initialSpringVelocity: 0) {
            self.goalIcon.transform = .identity
        }
    }
}
```

Haptic **синхронно** с анимацией. Когда видно «успех» — чувствуется
«успех».

## 33.10 Haptic для drag-and-drop

Когда юзер захватывает элемент (long-press):

```swift
private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
    if gesture.state == .began {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        // начать drag
    }
}
```

Когда отпускает на новой позиции:

```swift
case .ended:
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
    // finalize drop
```

Меняется ощущение «весомости» — медиум для захвата (важное событие),
light для отпускания.

## 📋 Что мы выучили

- **`UIImpactFeedbackGenerator`** — стили `.light`/`.medium`/`.heavy`
  /`.soft`/`.rigid`. `intensity` для контроля силы.
- **`UINotificationFeedbackGenerator`** — `.success`/`.warning`/`.error`
  для результатов.
- **`UISelectionFeedbackGenerator`** — короткий тик для частых
  событий.
- **`prepare()`** — прогрев engine'а перед ожидаемым event'ом.
- **Reuse** generator'а — храни в свойстве класса, не создавай каждый
  раз.
- **`CHHapticEngine`** — кастомные паттерны (iOS 13+).
- **Не нужны** при scroll'е, частом keyboard input, в Reduce Motion.
- **Slider с засечками** — bucket подход на каждые 5% значения.
- **Sync с анимацией** — haptic в начале анимации, не после.

## Apple Developer Documentation

- [UIFeedbackGenerator](https://developer.apple.com/documentation/uikit/uifeedbackgenerator) — базовый класс тактильной отдачи и метод `prepare()`.
- [UIImpactFeedbackGenerator](https://developer.apple.com/documentation/uikit/uiimpactfeedbackgenerator) — «удар» при действиях UI.
- [UIImpactFeedbackGenerator.FeedbackStyle](https://developer.apple.com/documentation/uikit/uiimpactfeedbackgenerator/feedbackstyle) — `.light` / `.medium` / `.heavy` / `.soft` / `.rigid`.
- [UINotificationFeedbackGenerator](https://developer.apple.com/documentation/uikit/uinotificationfeedbackgenerator) — `.success` / `.warning` / `.error`.
- [UISelectionFeedbackGenerator](https://developer.apple.com/documentation/uikit/uiselectionfeedbackgenerator) — короткий тик при смене значения.
- [CHHapticEngine](https://developer.apple.com/documentation/corehaptics/chhapticengine) — Core Haptics для кастомных паттернов, iOS 13+.
- [CHHapticPattern](https://developer.apple.com/documentation/corehaptics/chhapticpattern) — описание сложной haptic-последовательности.
- [HIG — Playing haptics](https://developer.apple.com/design/human-interface-guidelines/playing-haptics) — гайдлайн Apple о том, когда уместна тактильная отдача.

→ [Глава 34. Cookbook: accessibility](./51-cookbook-accessibility.md)
