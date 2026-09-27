# Глава 33. Cookbook — haptics

**Haptics** (тактильная отдача) — короткие вибрации, которые
пользователь чувствует пальцем: «щелчок» переключателя, «тик» барабана
выбора даты, двойной толчок при успешной оплате. Это не звонковый
вибромотор, а **Taptic Engine** — линейный моторчик внутри iPhone,
который умеет делать очень короткие и точные импульсы.

В этой главе — три стандартных вида отдачи, когда какой уместен и
как не переборщить.

Сначала о том, где отдача вообще работает, — иначе ты потратишь час,
тыкая в симулятор:

- **Симулятор** вибрацию не воспроизводит. Вызовы проходят без ошибок
  и без эффекта. Проверять haptics можно только на устройстве.
- **iPhone.** Отдачу через `UIFeedbackGenerator` дают модели с Taptic
  Engine нового поколения — iPhone 7 и новее. На более старых вызовы
  просто ничего не делают.
- **iPad и iPod touch** встроенной тактильной отдачи не имеют — это
  прямо сказано в документации Core Haptics («Some devices don't
  support haptic feedback, including iPad, iPod touch, and Apple
  Vision Pro»). Приложение на iPad не падает, отдача просто молчит.
- **Пользователь может выключить** системную отдачу: Настройки → Звуки,
  тактильные сигналы → «Системные тактильные». Тогда стандартные
  генераторы тоже молчат.
- **Во время записи звука** (приложение пишет с микрофона) система
  по умолчанию глушит отдачу, чтобы вибрация не попала в запись.
  Разрешить можно через `AVAudioSession.setAllowHapticsAndSystemSoundsDuringRecording(true)`.

Отсюда главное правило: **отдача — всегда дополнение**. Любое
событие, которое сопровождается вибрацией, должно быть понятно и без
неё — анимацией, цветом, текстом.

## 33.1 Impact (удар)

**Когда применять.** Физическое событие в интерфейсе: элемент
«встал на место», карточка «ударилась» о край, кнопку нажали.

```swift
let haptic = UIImpactFeedbackGenerator(style: .medium)
haptic.impactOccurred()

// С силой от 0 до 1 (iOS 13+)
haptic.impactOccurred(intensity: 0.6)
```

`UIImpactFeedbackGenerator` — **генератор** отдачи: объект, который
знает, какой именно «удар» воспроизвести. `impactOccurred()` —
«удар произошёл, сыграй».

Стили:

- **`.light`** — лёгкий, как касание мелкого предмета.
- **`.medium`** — средний, самый ходовой.
- **`.heavy`** — тяжёлый, «глухой».
- **`.soft`** (iOS 13+) — мягкий, упругий, как удар о подушку.
- **`.rigid`** (iOS 13+) — жёсткий, короткий, как щелчок.

`intensity: 0.6` — 60% силы выбранного стиля. Для частых событий
(перетаскивание, прокрутка) берут 0,4–0,6: полная сила на каждое
событие быстро утомляет.

> В SDK iOS 26.5 инициализатор `init(style:)` помечен как «будет
> устаревшим» в пользу `init(style:view:)` из iOS 17.5 — генератора,
> привязанного к конкретному view. У нас минимум iOS 15, поэтому
> пишем `init(style:)`; когда поднимешь минимум до 17.5, переходи на
> новый вариант.

## 33.2 Notification (успех / предупреждение / ошибка)

**Когда применять.** Сообщить **результат** действия: платёж прошёл,
форма не отправилась, лимит почти исчерпан.

```swift
let notification = UINotificationFeedbackGenerator()
notification.notificationOccurred(.success)  // или .warning / .error
```

Три типа — три разных узора вибрации. Система играет их одинаково во
всех приложениях, и пользователь со временем узнаёт их без экрана.
Поэтому HIG Apple просит использовать их **по смыслу** («Use
system-provided haptic patterns according to their documented
meanings»): не ставь `.error` на «добавлено
в избранное», даже если узор тебе больше нравится.

## 33.3 Selection (короткий тик)

**Когда применять.** Значение меняется по шагам: барабан выбора,
сегменты, перетаскивание по засечкам.

```swift
let selection = UISelectionFeedbackGenerator()
selection.selectionChanged()
```

Очень короткий и тонкий тик. Подходит для **частых** событий: при
прокрутке барабана — на каждое новое значение. По HIG
стандартные переключатели, ползунки и барабаны выбора (`UISwitch`,
`UISlider`, `UIPickerView`) играют системную отдачу сами — добавлять
её к ним не нужно.

## 33.4 prepare() — прогрев

Taptic Engine в покое «спит», чтобы беречь батарею. Первый импульс
после сна приходит с небольшой задержкой — на глаз это рассинхрон
«анимация уже случилась, а вибрация чуть позже».

```swift
let haptic = UIImpactFeedbackGenerator(style: .medium)
haptic.prepare()  // прогрев

// ... через долю секунды или пару секунд:
haptic.impactOccurred()  // с минимальной задержкой
```

Что говорит документация Apple про `prepare()`:

- Генератор остаётся «прогретым» **недолго — обычно секунды**. Потом
  Taptic Engine снова засыпает.
- Вызвать `prepare()` и **сразу** `impactOccurred()` бесполезно: движку
  нужно время на подготовку.
- После срабатывания движок возвращается в покой; если отдача может
  понадобиться снова в ближайшие секунды — вызови `prepare()` ещё раз.

Когда вызывать:

- Когда событие **ожидается**. Пользователь начал тянуть ползунок —
  `prepare()`. Через секунду он дотянет до засечки — отдача без
  задержки.
- В начале жеста (`.began` у распознавателя), если в его конце будет
  отдача.

Когда можно обойтись: одиночный тап по кнопке — задержка там
незаметна на фоне самого нажатия.

## 33.5 Один генератор или новый каждый раз

```swift
// Один на экран — лучше
final class ChatViewController: UIViewController {
    private let haptic = UIImpactFeedbackGenerator(style: .light)

    private func sendTapped() {
        haptic.impactOccurred()
        haptic.prepare()   // новое сообщение может уйти через секунду
    }
}

// Каждый раз новый — хуже
private func sendTapped() {
    let haptic = UIImpactFeedbackGenerator(style: .light)  // создали и выбросили
    haptic.impactOccurred()  // без прогрева
}
```

Генератор — лёгкий объект, создавать его не дорого. Смысл хранения в
свойстве — в **прогреве**: `prepare()` действует на конкретный
экземпляр, и у генератора, созданного «на один раз», прогреть нечего.

## 33.6 Свои узоры — Core Haptics (iOS 13+)

**Core Haptics** — низкоуровневый фреймворк для собственных узоров
отдачи: нарастающая вибрация «бомба сейчас взорвётся», ритм сердца,
отдача в такт музыке.

```swift
import CoreHaptics

final class HapticEngine {
    private var engine: CHHapticEngine?
    private let supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics

    init() {
        guard supportsHaptics else { return }
        do {
            let engine = try CHHapticEngine()
            engine.resetHandler = { [weak engine] in
                try? engine?.start()
            }
            engine.stoppedHandler = { reason in
                print("Haptic engine stopped: \(reason.rawValue)")
            }
            try engine.start()
            self.engine = engine
        } catch {
            print("Haptic engine failed: \(error)")
        }
    }

    func playCustom() {
        guard let engine else { return }
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
        let event = CHHapticEvent(eventType: .hapticTransient,
                                  parameters: [intensity, sharpness],
                                  relativeTime: 0)
        do {
            try engine.start()
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("Failed to play haptic: \(error)")
        }
    }
}
```

Разбор по шагам:

- `capabilitiesForHardware().supportsHaptics` — умеет ли устройство.
  На iPad и в симуляторе — `false`, и мы вообще не создаём движок.
  Проверяй возможность, а не модель телефона.
- `CHHapticEngine` — связь приложения с моторчиком. Без запущенного
  движка узор не сыграть.
- `resetHandler` — система перезапустила свой сервер отдачи (такое
  бывает); движок нужно запустить снова. `[weak engine]` — чтобы
  замыкание, которое хранит сам движок, не держало его сильной ссылкой.
- `stoppedHandler` — движок остановили: звонок, уход приложения в фон.
  Это нормальная часть жизни движка, поэтому в `playCustom()` перед
  проигрыванием мы на всякий случай вызываем `engine.start()` — для
  уже запущенного движка это безопасно.
- `CHHapticEvent` — одно событие узора. `.hapticTransient` —
  короткий удар; бывает ещё `.hapticContinuous` — длительная вибрация
  с `duration`.
- Параметры от 0 до 1: **intensity** — сила, **sharpness** — «острота»
  (0 — мягкий, округлый толчок, 1 — чёткий, «механический» щелчок).
- `relativeTime: 0` — когда внутри узора случится событие, в секундах
  от начала. Три события с временем 0, 0,1 и 0,2 — три удара с
  интервалом в десятую долю секунды.
- `makePlayer(with:)` + `start(atTime: CHHapticTimeImmediate)` —
  сыграть прямо сейчас.

Core Haptics — мощный, но многословный инструмент. Бери его, только
если трёх стандартных генераторов действительно не хватает.

## 33.7 Когда haptics **не нужны**

- **Обычная прокрутка списка** — система там отдачу не даёт, и
  добавленная тобой будет раздражать.
- **Каждое нажатие клавиши** — у клавиатуры своя отдача, пользователь
  включает её в Настройках.
- **Долгие операции** — не вибрируй «в процессе». Одна отдача в конце:
  `.success` или `.error`.
- **Дублирование стандартных контролов** — `UISwitch`, барабаны
  пикера уже вибрируют сами.
- **Без выключателя.** HIG Apple советует делать отдачу отключаемой
  («Make haptics optional»). Системный переключатель выключает
  стандартные генераторы, а для игр и Core Haptics-эффектов заведи
  свой пункт в настройках приложения:

```swift
enum HapticsSettings {
    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "settings.haptics") as? Bool ?? true
    }
}

if HapticsSettings.isEnabled {
    haptic.impactOccurred()
}
```

`object(forKey:) as? Bool ?? true` — если пользователь ещё ничего не
выбирал, ключа нет, и мы считаем отдачу включённой. Обычный
`bool(forKey:)` вернул бы для отсутствующего ключа `false`.

## 33.8 Отдача для ползунка

```swift
final class HapticSlider: UISlider {
    private let haptic = UIImpactFeedbackGenerator(style: .light)
    private var lastTick: Float = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        addTarget(self, action: #selector(check), for: .valueChanged)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) не используется")
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

Математика словами: значение ползунка от 0 до 1. Умножаем на 20 и
округляем — получаем номер «засечки» от 0 до 20, то есть шкала
разбита на 20 шагов по 5%. Значение 0,33 даёт 6,6 → засечка 7;
0,36 даёт 7,2 → тоже 7, отдачи нет; 0,38 даёт 7,6 → 8, щелчок.
Отдача срабатывает только при **смене** засечки, а не на каждое
событие `valueChanged` (их при перетаскивании десятки в секунду).

`required init?(coder:)` обязателен: `UISlider` — наследник `UIView`,
а у него этот инициализатор помечен `required`. Как только ты
переопределил свой `init(frame:)`, компилятор требует явно написать и
его, иначе код не соберётся.

По смыслу здесь подходит и `UISelectionFeedbackGenerator` (33.3):
засечки — это смена значения по шагам. Разница на ощупь: selection —
тоньше, impact `.light` — чуть «плотнее». Полная версия с плеером — в
главе 17.10.

## 33.9 Отдача при достижении цели

«Шагомер: 10 000 шагов сегодня!»

```swift
func didReachGoal() {
    let notification = UINotificationFeedbackGenerator()
    notification.notificationOccurred(.success)

    // Вместе с отдачей — «подпрыгивание» иконки
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

Иконка за 0,2 с вырастает на 30% (`1.3` — 130% размера), потом
пружиной с damping 0.5 возвращается — с заметным отскоком (около 16%
перелёта, см. главу 32.2). Отдачу запускаем **в тот же момент**, что
и анимацию: вибрация и визуальный «подскок» воспринимаются как одно
событие. Отдача после анимации ощущалась бы запоздалой.

## 33.10 Отдача при перетаскивании

Пользователь долгим нажатием «берёт» элемент, тащит и отпускает:

```swift
@objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
    switch gesture.state {
    case .began:
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        // начать перетаскивание
    case .ended:
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        // положить элемент на новое место
    default:
        break
    }
}
```

`.began` — долгое нажатие распознано (по умолчанию после 0,5 с
удержания), `.ended` — палец отпущен. «Взять» — `.medium`: важное
событие, должно ощущаться. «Положить» — `.light`: подтверждение, без
нажима. Здесь мы создаём генераторы на месте, без прогрева, и это
осознанное упрощение: между «взять» и «положить» проходят секунды, а
для производственного кода храни генератор в свойстве и вызывай
`prepare()` в `.began` (раздел 33.4).

## Упражнения

**Упражнение 33.1.** Для экрана оплаты подбери отдачу: а) нажатие
кнопки «Оплатить»; б) платёж прошёл; в) банк отклонил карту;
г) пользователь листает барабан выбора срока рассрочки
(`UIPickerView`). Что выбрать в каждом случае и где отдачу добавлять
не нужно?

**Упражнение 33.2.** Поменяй `HapticSlider` так, чтобы засечек было 10
(каждые 10%) и чтобы генератор прогревался, когда пользователь
касается ползунка. Подсказка: событие `.touchDown`.

## Ответы к упражнениям

**33.1.** а) `UIImpactFeedbackGenerator(style: .medium)` — или вообще
без отдачи: нажатие кнопки и так видно. Результата ещё нет, поэтому
не `.success`. б) `UINotificationFeedbackGenerator` с `.success`.
в) Тот же генератор с `.error` — и обязательно текст ошибки на экране.
г) Ничего не добавляй: `UIPickerView` даёт тиковую отдачу сам.

**33.2.**

```swift
final class HapticSlider: UISlider {
    private let haptic = UIImpactFeedbackGenerator(style: .light)
    private var lastTick: Float = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        addTarget(self, action: #selector(check), for: .valueChanged)
        addTarget(self, action: #selector(warmUp), for: .touchDown)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) не используется")
    }

    @objc private func warmUp() {
        lastTick = (value * 10).rounded()
        haptic.prepare()
    }

    @objc private func check() {
        let bucket = (value * 10).rounded()
        if bucket != lastTick {
            haptic.impactOccurred(intensity: 0.5)
            haptic.prepare()
            lastTick = bucket
        }
    }
}
```

`value * 10` — десять шагов по 10%. `.touchDown` приходит, когда
палец коснулся ползунка, ещё до перетаскивания, — лучшее время для
`prepare()`. В `warmUp` заодно запоминаем текущую засечку, чтобы
первое же микродвижение не дало ложный щелчок. `prepare()` после
каждого удара держит движок прогретым для очередной засечки.

## Что мы выучили

- **Где работает**: только на устройстве; iPhone 7 и новее; на iPad
  и в симуляторе — тишина; пользователь может выключить; при записи
  звука отдача глушится.
- **`UIImpactFeedbackGenerator`** — стили `.light` / `.medium` /
  `.heavy` / `.soft` / `.rigid`, `intensity` от 0 до 1.
- **`UINotificationFeedbackGenerator`** — `.success` / `.warning` /
  `.error`, строго по смыслу.
- **`UISelectionFeedbackGenerator`** — тик для пошаговой смены значения.
- **`prepare()`** — за доли секунды или секунды до события, не
  вплотную; действует недолго.
- **Генератор в свойстве** — чтобы было что прогревать.
- **Core Haptics** — свои узоры; проверка `supportsHaptics`,
  перезапуск движка в `resetHandler` и перед проигрыванием.
- **Не нужны** при прокрутке, наборе текста, поверх стандартных
  контролов; делай отдачу отключаемой.
- **Ползунок с засечками** — отдача только при смене засечки;
  `required init?(coder:)` обязателен.
- **Синхронно с анимацией** — отдача в момент начала анимации.

## Apple Developer Documentation

- [UIFeedbackGenerator](https://developer.apple.com/documentation/uikit/uifeedbackgenerator) — базовый класс тактильной отдачи.
- [UIFeedbackGenerator.prepare()](https://developer.apple.com/documentation/uikit/uifeedbackgenerator/prepare()) — прогрев Taptic Engine и сколько он длится.
- [UIImpactFeedbackGenerator](https://developer.apple.com/documentation/uikit/uiimpactfeedbackgenerator) — «удар» при действиях в интерфейсе.
- [UIImpactFeedbackGenerator.FeedbackStyle](https://developer.apple.com/documentation/uikit/uiimpactfeedbackgenerator/feedbackstyle) — `.light` / `.medium` / `.heavy` / `.soft` / `.rigid`.
- [UINotificationFeedbackGenerator](https://developer.apple.com/documentation/uikit/uinotificationfeedbackgenerator) — `.success` / `.warning` / `.error`.
- [UISelectionFeedbackGenerator](https://developer.apple.com/documentation/uikit/uiselectionfeedbackgenerator) — короткий тик при смене значения.
- [Preparing your app to play haptics](https://developer.apple.com/documentation/corehaptics/preparing-your-app-to-play-haptics) — проверка `supportsHaptics`, какие устройства не поддерживают отдачу, перезапуск движка.
- [CHHapticEngine](https://developer.apple.com/documentation/corehaptics/chhapticengine) — движок Core Haptics, iOS 13+.
- [CHHapticPattern](https://developer.apple.com/documentation/corehaptics/chhapticpattern) — описание собственного узора.
- [HIG — Playing haptics](https://developer.apple.com/design/human-interface-guidelines/playing-haptics) — когда отдача уместна и почему её делают отключаемой.

→ [Глава 34. Cookbook — accessibility](./51-cookbook-accessibility.md)
