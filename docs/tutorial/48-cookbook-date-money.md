# Глава 31. Cookbook — дата, время, деньги

Всё, что показывает человеку `Date` или сумму денег, проходит через
**форматтер** — объект, который превращает значение в строку по правилам
конкретного языка и страны. В этой главе собраны рецепты для дат,
длительностей, чисел и денег, и главное — реальный вывод этих рецептов
для трёх локалей, с которыми ты скорее всего столкнёшься: `ru_RU`,
`ru_KZ` и `kk_KZ`.

Два слова, без которых дальше никуда.

**Локаль** (`Locale`) — набор региональных правил: язык, страна,
разделитель тысяч, запятая или точка в дробях, какая валюта «своя»,
с какого дня начинается неделя. Идентификатор складывается из языка и
страны: `ru_KZ` — русский язык по правилам Казахстана, `kk_KZ` —
казахский язык в Казахстане, `ru_RU` — русский в России. Язык один,
страны разные — и форматтер покажет разную валюту.

**Часовой пояс** (`TimeZone`) — сдвиг местного времени относительно
**UTC**, всемирного координированного времени (это «время по нулевому
меридиану», от которого считают все пояса). Алматы сейчас живёт в
UTC+5: когда в Лондоне по UTC 09:30, в Алматы 14:30.

> **Как проверены примеры.** Все строки вида `// "…"` в этой главе —
> настоящий вывод, снятый программой на симуляторе iOS 26.5. На Mac
> те же форматтеры иногда печатают другое (другие версии данных о
> локалях), поэтому проверяй на симуляторе или устройстве. Код главы
> проверен компилятором в режиме Swift 6 с изоляцией `MainActor` по
> умолчанию (о режимах компилятора — во Введении).

## 31.1 DateFormatter — база

**Когда применять.** Показать дату или время в интерфейсе: «12 мая
2026 г.», «14:30», «вторник».

```swift
let formatter = DateFormatter()
formatter.locale = Locale(identifier: "ru_RU")
formatter.dateStyle = .medium
formatter.timeStyle = .short
let text = formatter.string(from: date)
// "12 мая 2026 г., 14:30"
```

Разбор:

- `locale` — по чьим правилам писать. Если не задать, возьмётся
  `Locale.current` — локаль, выбранная пользователем в Настройках
  (обычно тебе именно это и нужно; жёсткий `ru_RU` здесь только чтобы
  пример был воспроизводимым).
- `dateStyle` и `timeStyle` — готовые уровни подробности. Отдельно
  для даты и для времени, `.none` выключает часть.
- `string(from:)` — сама конвертация.

Четыре уровня для даты 12 мая 2026 года выглядят так (вывод
симулятора):

| Стиль | `ru_RU` и `ru_KZ` | `kk_KZ` | `en_US` |
|---|---|---|---|
| `.short` | 12.05.2026 | 12.05.26 | 5/12/26 |
| `.medium` | 12 мая 2026 г. | 2026 ж. 12 мам. | May 12, 2026 |
| `.long` | 12 мая 2026 г. | 2026 ж. 12 мамыр | May 12, 2026 |
| `.full` | вторник, 12 мая 2026 г. | 2026 ж. 12 мамыр, сейсенбі | Tuesday, May 12, 2026 |

Обрати внимание: в русских локалях `.medium` и `.long` совпадают и
оба добавляют «г.», а казахская локаль ставит год **первым**. Именно
поэтому стили лучше ручных форматов: ты не знаешь заранее, в каком
порядке человек привык читать дату.

Кастомный формат — когда нужен конкретный вид:

```swift
formatter.dateFormat = "d MMMM yyyy"   // "12 мая 2026"
formatter.dateFormat = "HH:mm"         // "14:30"
formatter.dateFormat = "EEEE"          // "вторник"
formatter.dateFormat = "yyyy-MM-dd"    // "2026-05-12"
```

Буквы в шаблоне — это поля даты: `d` — день, `MMMM` — месяц словом,
`yyyy` — год, `HH` — часы от 00 до 23, `mm` — минуты, `EEEE` — день
недели словом. Две ловушки:

- **Жёсткий формат не переставляет поля под локаль.** `"d MMMM yyyy"` в
  `en_US` даст «12 May 2026», хотя американец ждёт «May 12». Если нужен
  «набор полей», а порядок пусть решает локаль, используй шаблон:
  `formatter.setLocalizedDateFormatFromTemplate("dMMMM")` — для
  `ru_RU` получится «12 мая», для `en_US` — «May 12».
- **Месяц без дня — буква `L`, а не `M`.** В русском месяц склоняется:
  «12 мая», но «май 2026». `"MMMM yyyy"` печатает «мая 2026» (родительный
  падеж), а `"LLLL yyyy"` — правильное «май 2026». `L` означает
  «самостоятельная форма месяца».

> **Кешируй форматтеры.** Создание `DateFormatter` — сравнительно
> дорогая операция: он загружает данные локали. Для ячейки таблицы,
> которая форматирует дату при каждом показе, заведи один экземпляр
> и используй его повторно.

```swift
enum Formatters {
    static let mediumDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

// В ячейке:
dateLabel.text = Formatters.mediumDateTime.string(from: note.createdAt)
```

`static let` в Swift ленивый: замыкание выполнится один раз, при
первом обращении, дальше все берут готовый объект. Пустой `enum`
здесь — просто «папка» для констант, у него нельзя создать экземпляр.

## 31.2 RelativeDateTimeFormatter — «5 минут назад»

**Когда применять.** Ленты, чаты, комментарии — там, где важнее «как
давно», чем точная дата.

```swift
let formatter = RelativeDateTimeFormatter()
formatter.locale = Locale(identifier: "ru_RU")
formatter.unitsStyle = .full
let text = formatter.localizedString(for: someDate, relativeTo: Date())
// someDate на 5 минут раньше → "5 минут назад"
```

`localizedString(for:relativeTo:)` берёт две даты и описывает разницу
между ними: первая — событие, вторая — «сейчас». Склонения форматтер
делает сам: «5 минут назад», но «21 минуту назад».

Стили `unitsStyle` для трёх случаев (−5 минут, +2 дня, −21 минута):

| Стиль | `ru_RU` | `kk_KZ` |
|---|---|---|
| `.full` | 5 минут назад · через 2 дня · 21 минуту назад | 5 минут бұрын · 2 күннен кейін · 21 минут бұрын |
| `.short` | 5 мин. назад · через 2 дн. · 21 мин. назад | 5 мин. бұрын · 2 күннен кейін · 21 мин. бұрын |
| `.abbreviated` | -5 мин · +2 дн · -21 мин | 5 мин. бұрын · 2 күннен кейін · 21 мин. бұрын |
| `.spellOut` | пять минут назад · через два дня · двадцать один минуту назад | бес минут бұрын · … |

Последняя строка — не опечатка в книге: `.spellOut` на iOS 26.5
печатает «двадцать один минуту» (род не согласован). Прописью по-русски
этот стиль лучше не показывать.

Полезная настройка — `dateTimeStyle = .named`. Тогда вместо «1 день
назад» будет «вчера», вместо «через 1 день» — «завтра», а для нулевой
разницы — «сейчас» (без неё форматтер пишет «через 0 секунд»).

`RelativeDateTimeFormatter` появился в iOS 13, так что для нашего
iOS 15 доступен без проверок.

## 31.3 DateComponentsFormatter — длительности

**Когда применять.** Длительность — это не момент, а отрезок: «трек
длится 3:25», «до конца 1 ч 23 мин».

```swift
let formatter = DateComponentsFormatter()
formatter.allowedUnits = [.hour, .minute, .second]
formatter.unitsStyle = .abbreviated
formatter.string(from: 4980)   // 4980 секунд → "1 ч 23 мин" (ru)
```

Число `4980` — секунды: 4980 = 3600 (час) + 1380, а 1380 секунд — это
23 минуты ровно, поэтому секунд в ответе нет. `allowedUnits` задаёт,
какими единицами можно пользоваться.

Вывод для 4980 секунд в `ru_RU`:

- `.positional` — «1:23:00» (как на часах плеера);
- `.abbreviated` и `.short` — «1 ч 23 мин»;
- `.full` — «1 час 23 минуты»;
- `.spellOut` — «один час двадцать три минуты».

У этого форматтера нет свойства `locale`: язык берётся из его
`calendar`. Чтобы задать язык явно, создай календарь с нужной локалью
и присвой `formatter.calendar = calendar`. В приложении обычно этого не
делают — пользователю показывают его собственный язык.

Для таймера плеера пригодится ещё одна настройка:

```swift
formatter.allowedUnits = [.minute, .second]
formatter.unitsStyle = .positional
formatter.zeroFormattingBehavior = .pad
formatter.string(from: 65)     // "01:05"
formatter.string(from: 3725)   // "62:05"
```

`.pad` добивает нули слева: 65 секунд — «01:05», а не «1:05». Во
втором примере часов в `allowedUnits` нет, поэтому 1 час 2 минуты 5
секунд превращаются в «62:05».

> В iOS 16 появился тип `Duration` со своим форматированием
> (`Duration.seconds(4980).formatted(...)`). На iOS 15 его нет —
> компилятор с deployment target 15 откажется собирать такой код без
> `if #available(iOS 16, *)`.

## 31.4 Календарные операции

**Календарь** (`Calendar`) — это правила счёта дней: сколько дней в
месяце, какой год високосный, когда переводят часы. `Calendar.current`
— календарь пользователя, с его часовым поясом.

```swift
let cal = Calendar.current
let now = Date()

// Начало текущего дня (00:00 в часовом поясе календаря)
let today = cal.startOfDay(for: now)

// Та же минута завтра
let tomorrow = cal.date(byAdding: .day, value: 1, to: now)

// День недели: 1 — воскресенье, 2 — понедельник, …, 7 — суббота
let weekday = cal.component(.weekday, from: now)

// Сегодня ли?
let isToday = cal.isDateInToday(someDate)

// Полных лет
let age = cal.dateComponents([.year], from: birthDate, to: now).year ?? 0
```

Несколько тонкостей, о которые спотыкаются:

- Нумерация `weekday` **не зависит от локали**: воскресенье всегда 1.
  От локали зависит другое — `cal.firstWeekday`, первый день недели в
  календарной сетке. У `ru_RU` и `kk_KZ` он равен 2 (понедельник), у
  `en_US` — 1 (воскресенье).
- `dateComponents([.year], from:to:)` считает **полные** годы. Для
  рождённого 13 мая 2000 года на 12 мая 2026-го получится 25, а не 26:
  день рождения ещё не наступил. Проверено на симуляторе.
- `date(byAdding:)` возвращает опционал: теоретически не каждую дату
  можно сдвинуть (например, на несуществующий час при переводе часов).

**Почему нельзя `date.addingTimeInterval(86400)`.** 86 400 — это
секунд в сутках: 24 × 60 × 60. Но не каждые сутки длятся 24 часа. В
странах с летним временем (DST, daylight saving time — «перевод часов
на час вперёд весной») в день перевода в сутках 23 часа. Живой пример
с симулятора: в Нью-Йорке 7 марта 2026 года в 12:00 прибавляем
86 400 секунд и получаем 8 марта **13:00**, а `cal.date(byAdding: .day,
value: 1, to:)` даёт 8 марта **12:00**.

В Казахстане летнего времени нет с 2005 года, но зато в 2024 году
сменился сам пояс: до 1 марта 2024 года Алматы жил в UTC+6, после —
в UTC+5. Календарь и `TimeZone` эти правила знают (база часовых поясов
приходит с обновлениями iOS), а твоя ручная арифметика — нет.

## 31.5 NumberFormatter — деньги

**Когда применять.** Любая сумма на экране: цена, итог корзины,
баланс.

```swift
let formatter = NumberFormatter()
formatter.numberStyle = .currency
formatter.locale = Locale(identifier: "ru_RU")
formatter.string(from: NSNumber(value: 1234.5))  // "1 234,50 ₽"

formatter.locale = Locale(identifier: "ru_KZ")
formatter.string(from: NSNumber(value: 1234.5))  // "1 234,50 ₸"
```

`numberStyle = .currency` включает сразу три вещи: разделитель тысяч,
два знака после запятой и символ валюты, **которую локаль считает
своей**. Для `ru_KZ` и `kk_KZ` это тенге (₸), для `ru_RU` — рубль.

Пробелы в этих строках не обычные. Между «1» и «234» и перед «₸» стоит
**неразрывный пробел** (символ U+00A0): он выглядит как пробел, но не
даёт строке переломиться посреди суммы. Отсюда классическая ошибка в
тестах: `XCTAssertEqual(text, "1 234,50 ₸")` с обычным пробелом не
проходит, хотя на глаз строки одинаковые.

Валюта отдельно от локали:

```swift
formatter.locale = Locale(identifier: "ru_RU")
formatter.currencyCode = "USD"
formatter.string(from: NSNumber(value: 1234.5))  // "1 234,50 $"

formatter.currencyCode = "KZT"
formatter.string(from: NSNumber(value: 1234.5))  // "1 234,50 KZT"
```

`currencyCode` меняет валюту, а оформление (где запятая, где символ)
остаётся по правилам локали. Поэтому доллар в `ru_RU` стоит **после**
числа: «1 234,50 $». Американский вид «$1,234.50» получится только с
`Locale(identifier: "en_US")`.

Вторая строка важна для приложений в Казахстане: с локалью `ru_RU`
тенге выводится кодом **«KZT»**, а не знаком ₸. Знак ₸ форматтер знает
только для локалей, где тенге — «своя» валюта (`ru_KZ`, `kk_KZ`). Если
пользователь с российскими региональными настройками открывает
казахстанский магазин, он увидит «KZT». Реши заранее, что тебе нужно:
либо форматируешь по `ru_KZ`, либо явно задаёшь
`formatter.currencySymbol = "₸"`.

Тенге обычно показывают без тиынов (сотых долей). Для этого:

```swift
enum Money {
    static let tenge: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "ru_KZ")
        formatter.currencyCode = "KZT"
        formatter.maximumFractionDigits = 0
        return formatter
    }()
}

Money.tenge.string(from: 1234.5)   // "1 234 ₸"
Money.tenge.string(from: 1235.5)   // "1 236 ₸"
```

Почему 1234,5 превратилось в 1234, а 1235,5 — в 1236? По умолчанию
`NumberFormatter` округляет **банковским способом** (`.halfEven`):
ровно половину он округляет к **чётному** соседу. У 1234,5 соседи
1234 и 1235, чётный — 1234. У 1235,5 соседи 1235 и 1236, чётный —
1236. Так делают, чтобы при сложении тысяч округлённых сумм ошибки
«вверх» и «вниз» гасили друг друга. Если бизнес требует «школьное»
округление (половина всегда вверх), поставь
`formatter.roundingMode = .halfUp` — тогда 2,5 станет 3.

Сами деньги при этом храни не в `Double`, а в `Decimal` — почему,
разобрано в разделе 31.13.

## 31.6 NumberFormatter — другие стили

```swift
formatter.numberStyle = .percent
formatter.string(from: NSNumber(value: 0.42))  // "42 %"

formatter.numberStyle = .decimal
formatter.maximumFractionDigits = 2
formatter.string(from: NSNumber(value: 1234567.89))  // "1 234 567,89"

formatter.numberStyle = .spellOut
formatter.string(from: NSNumber(value: 42))  // "сорок два"

formatter.numberStyle = .ordinal
formatter.string(from: NSNumber(value: 3))   // "3"
```

Разбор (локаль `ru_RU`):

- `.percent` умножает на 100: 0.42 — это 42 процента. В русских
  локалях между числом и знаком стоит неразрывный пробел («42 %»), в
  `kk_KZ` пробела нет («42%»).
- `.decimal` — просто число с разделителями. `maximumFractionDigits`
  ограничивает хвост после запятой.
- `.spellOut` — прописью. Для договоров и чеков: `1234` в `ru_RU` —
  «одна тысяча двести тридцать четыре», в `kk_KZ` — «мың екі жүз отыз
  төрт».
- `.ordinal` — порядковое число. В `en_US` получится «3rd», в `kk_KZ` —
  «3-ші», а в русских локалях просто «3»: окончание («3-й», «3-я»,
  «3-е») зависит от рода и падежа слова, которого форматтер не знает.

## 31.7 Анимация числа

«Растущий счётчик» — сумма на экране итогов плавно бежит от 0 до
12 500. Первая мысль — расставить 30 отложенных задач:

```swift
func animateCount(from start: Int, to end: Int, duration: TimeInterval = 1.0, label: UILabel) {
    let steps = 30
    let stepDuration = duration / Double(steps)
    for step in 0...steps {
        let delay = stepDuration * Double(step)
        let progress = Double(step) / Double(steps)
        let value = Int(Double(start) + Double(end - start) * progress)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            label.text = "\(value)"
        }
    }
}
```

Математика словами: секунду делим на 30 шагов, каждый шаг длится
1/30 ≈ 0,033 секунды. На шаге номер `step` мы прошли долю пути
`step / 30`: на 15-м шаге — половину, и при счёте от 0 до 100 на
экране будет 50. Значение считаем как «старт плюс пройденная доля
разницы»: 0 + 100 × 0,5 = 50.

Недостатки такого подхода: 31 задача ставится в очередь сразу и
отменить их нельзя. Вызовешь функцию второй раз, пока первая не
закончилась, — два набора задач будут перебивать друг друга, и число
на экране запрыгает.

Аккуратнее через **`CADisplayLink`** — таймер, который срабатывает
ровно перед каждой перерисовкой экрана (обычно 60 раз в секунду):

```swift
final class CountAnimator {
    private var displayLink: CADisplayLink?
    private var startValue: Double = 0
    private var endValue: Double = 0
    private var duration: Double = 1.0
    private var startTime: CFTimeInterval = 0
    var update: ((Double) -> Void)?

    func animate(from: Double, to: Double, duration: Double = 1.0) {
        startValue = from
        endValue = to
        self.duration = duration
        startTime = CACurrentMediaTime()
        displayLink?.invalidate()
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func tick() {
        let elapsed = CACurrentMediaTime() - startTime
        let progress = min(elapsed / duration, 1.0)
        let value = startValue + (endValue - startValue) * progress
        update?(value)
        if progress >= 1.0 { stop() }
    }
}
```

Что здесь происходит:

- `CACurrentMediaTime()` — монотонные часы в секундах. Их не собьёт
  смена времени в Настройках, поэтому для анимаций берут их, а не
  `Date()`.
- В `tick()` мы не считаем кадры, а смотрим, **сколько времени прошло**.
  Если прошло 0,25 секунды из 1, `progress` = 0,25, и счётчик
  показывает четверть пути. Если какой-то кадр пропустится, очередной
  всё равно покажет правильное значение — число не отстаёт.
- `min(..., 1.0)` не даёт перелететь за конец: последний кадр может
  прийти на 1,01 секунде.
- `link.add(to: .main, forMode: .common)` — подписка на главный run
  loop (цикл обработки событий главного потока). Режим `.common` нужен,
  чтобы счётчик не замирал, пока пользователь скроллит: во время
  скролла run loop переходит в режим отслеживания касаний, и таймеры
  в режиме `.default` стоят.
- `displayLink?.invalidate()` в начале `animate` — повторный запуск
  отменяет предыдущий, та проблема из первого варианта ушла.

**Про память.** `CADisplayLink` держит свой `target` сильной ссылкой,
а наш аниматор держит `displayLink`. Это цикл удержания: пока ссылка
не остановлена, аниматор не освободится. Цикл разрывает `stop()` — он
вызывается сам в конце анимации. Если экран закрывают раньше, вызови
`stop()` вручную:

```swift
final class TotalsViewController: UIViewController {
    private let label = UILabel()
    private let animator = CountAnimator()

    override func viewDidLoad() {
        super.viewDidLoad()
        animator.update = { [weak self] value in
            self?.label.text = "\(Int(value))"
        }
        animator.animate(from: 0, to: 100, duration: 1.0)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        animator.stop()
    }
}
```

`[weak self]` в замыкании `update` — чтобы аниматор (которым владеет
контроллер) не держал контроллер в ответ.

Для денег подставь в `update` форматтер из 31.5:
`self?.label.text = Money.tenge.string(from: value as NSNumber)`.

## 31.8 UIDatePicker

**Когда применять.** Пользователь выбирает дату или время: дата
рождения, время напоминания, срок задачи.

```swift
let picker = UIDatePicker()
picker.datePickerMode = .date   // .time / .dateAndTime / .countDownTimer
if #available(iOS 14, *) {
    picker.preferredDatePickerStyle = .compact
}
picker.minimumDate = Calendar.current.date(byAdding: .year, value: -100, to: Date())
picker.maximumDate = Date()
picker.locale = Locale(identifier: "ru_RU")
picker.addTarget(self, action: #selector(dateChanged(_:)), for: .valueChanged)

@objc private func dateChanged(_ picker: UIDatePicker) {
    print(picker.date)
}
```

Разбор:

- `datePickerMode` — что выбираем: только дату, только время, оба
  сразу или длительность таймера.
- `minimumDate` / `maximumDate` — границы. Для даты рождения: не
  раньше, чем 100 лет назад, и не позже сегодняшнего дня. Всё, что за
  границами, в пикере серое.
- `addTarget(_:action:for: .valueChanged)` — пикер сам сообщит, когда
  значение поменялось. `picker.date` — это `Date`, то есть момент
  времени; показывать его пользователю снова надо через форматтер.
- `#available(iOS 14, *)` здесь формальность: стиль `.compact`
  появился в iOS 14, а у нас минимум iOS 15. Проверку оставили, чтобы
  код можно было перенести в проект с более старым минимумом.

Стили:

- `.compact` — маленькая «таблетка» с датой; по тапу открывается
  календарь во всплывающем окне. Хорошо ложится в ячейку формы.
- `.inline` — календарь открыт прямо на экране всё время. Для экранов,
  где выбор даты — главное действие (бронирование).
- `.wheels` — классические «барабаны», как в iOS 13 и раньше.
- `.automatic` — выбор за системой (зависит от режима и места).

## 31.9 Часовые пояса

`Date` — это **момент времени**: число секунд от 1 января 2001 года по
UTC. У него нет часового пояса. Пояс появляется, только когда мы
превращаем момент в строку для человека:

```swift
let formatter = DateFormatter()
formatter.dateFormat = "HH:mm"
formatter.timeZone = TimeZone(identifier: "Asia/Almaty")
```

Один и тот же момент `2026-05-12T09:30:00Z` (буква `Z` в конце значит
«по UTC») форматтер с поясом `Asia/Almaty` покажет как 14:30, с
поясом `Europe/Moscow` — как 12:30. Момент один, подписи разные.

Правило для работы с сервером: **передавай и храни в UTC, показывай в
поясе пользователя**.

```swift
// Разбор строки ISO 8601 с сервера
let isoFormatter = ISO8601DateFormatter()
isoFormatter.formatOptions = [.withInternetDateTime]
guard let date = isoFormatter.date(from: "2026-05-12T10:30:00Z") else { return }
// date — момент, от часового пояса не зависит

// Отображение для пользователя
let display = DateFormatter()
display.dateStyle = .medium
display.timeStyle = .short
// timeZone по умолчанию = TimeZone.current → человек видит своё время
let text = display.string(from: date)
```

**ISO 8601** — международный стандарт записи даты: `2026-05-12T10:30:00Z`.
Сначала год, потом месяц и день, после `T` — время, в конце пояс.
Сервера почти всегда отдают даты так.

Ловушки, которые реально случаются:

- **Дробные секунды.** Если сервер присылает `2026-05-12T10:30:00.123Z`,
  форматтер с опциями `[.withInternetDateTime]` вернёт `nil` (проверено).
  Нужно добавить `.withFractionalSeconds`. А раз результат опциональный,
  не ставь `!` на разборе серверной строки: формат однажды поменяется,
  и приложение упадёт у всех пользователей сразу. `guard let` выше
  как раз для этого.
- **Свой формат для сервера — только с `en_US_POSIX`.** Если сервер
  шлёт `"2026-05-12 10:30:00"`, форматтеру нужно задать
  `locale = Locale(identifier: "en_US_POSIX")` и
  `timeZone = TimeZone(identifier: "UTC")`. POSIX-локаль — «никакая»
  локаль, которая не меняется от настроек пользователя. Без неё
  у человека с 12-часовым форматом времени разбор может сломаться.
- **`YYYY` вместо `yyyy`.** Большая `Y` — это «год недели» (по ISO
  неделям), а не календарный год. На симуляторе дата 29 декабря 2025
  года с форматом `"YYYY-MM-dd"` печатается как «2026-12-29»: эта
  неделя уже считается первой неделей 2026-го. Всегда пиши маленькую
  `yyyy`.

С iOS 15 есть и короткий путь для разбора:
`try Date("2026-05-12T10:30:00Z", strategy: .iso8601)`.

## 31.10 Тонкости русского плюрала

**Плюрал** (от plural — множественное число) — выбор формы слова по
числу. В английском форм две (1 minute, 2 minutes), в русском три:
«1 минута», «2 минуты», «5 минут». Правило:

- если две последние цифры числа от 11 до 14 — форма «минут»
  (11 минут, 112 минут);
- иначе смотрим на последнюю цифру: 1 — «минута», 2–4 — «минуты»,
  всё остальное (0, 5–9) — «минут».

```swift
func plural(_ n: Int, forms: (one: String, few: String, many: String)) -> String {
    let n = abs(n)
    let mod100 = n % 100
    let mod10 = n % 10
    if mod100 >= 11 && mod100 <= 14 { return forms.many }
    switch mod10 {
    case 1: return forms.one
    case 2, 3, 4: return forms.few
    default: return forms.many
    }
}

plural(1, forms: ("минута", "минуты", "минут"))    // "минута"
plural(2, forms: ("минута", "минуты", "минут"))    // "минуты"
plural(5, forms: ("минута", "минуты", "минут"))    // "минут"
plural(21, forms: ("минута", "минуты", "минут"))   // "минута"
plural(12, forms: ("минута", "минуты", "минут"))   // "минут" (исключение 11–14)
plural(111, forms: ("минута", "минуты", "минут"))  // "минут"
```

`n % 100` — остаток от деления на 100, то есть две последние цифры:
для 112 это 12. `n % 10` — последняя цифра. `abs(n)` добавлен, потому
что в Swift остаток от отрицательного числа отрицательный (−21 % 10 =
−1), и без него «−21 минута» ушла бы в ветку `default`.

**Как это делают в настоящем проекте.** Функция выше хороша для
одного-двух мест. Если приложение переводится на несколько языков,
формы слов кладут в **String Catalog** (файл `Localizable.xcstrings`):
у строки `"%lld minutes"` включается вариант «Vary by Plural», и для
русского Xcode сам предложит формы one / few / many. В коде остаётся
`String(localized: "\(minutes) minutes")`, а правила выбора формы
знает система — для каждого языка свои.

В iOS 15 появилось ещё автоматическое согласование
(`AttributedString` с разметкой `^[5 минута](inflect: true)`). На
симуляторе iOS 26.5 для русского оно не сработало: «1 минута», «2
минута», «5 минута» — строка осталась как есть. Для русского на него
не рассчитывай.

## 31.11 Размер файлов

```swift
let formatter = ByteCountFormatter()
formatter.allowedUnits = [.useMB, .useGB]
formatter.countStyle = .file
formatter.string(fromByteCount: 1234567890)  // "1,23 GB"
```

`allowedUnits` ограничивает единицы: с `[.useMB, .useGB]` 456 000 байт
станут «0,5 MB», а не «456 KB».

`countStyle` решает, сколько байт в килобайте:

- `.file` и `.decimal` — десятичные единицы, 1 KB = 1000 байт. Так
  размеры файлов показывает Finder, поэтому для «размер загрузки»
  бери `.file`: 1 234 567 890 байт = «1,23 GB».
- `.memory` и `.binary` — двоичные, 1 KB = 1024 байта. Так принято
  считать оперативную память. То же число станет «1,15 GB»: гигабайт
  здесь больше (1024 × 1024 × 1024 = 1 073 741 824 байта), поэтому
  «гигабайтов» меньше.

Две детали из прогона на симуляторе. У `ByteCountFormatter` нет
свойства `locale`: запятая берётся из текущей локали устройства, а
единицы остаются английскими («GB»). Форматирование в стиле iOS 15
переводит и единицы:

```swift
Int64(1_234_567_890).formatted(.byteCount(style: .file))
// "1,23 ГБ" при русской локали устройства
```

## 31.12 Сравнение строк с учётом локали

При сортировке списка по имени:

```swift
// Плохо — сравнение по кодам символов
items.sorted { $0.name < $1.name }

// Хорошо — сравнение по правилам языка
items.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
```

Что получилось на симуляторе для списка «Яблоко, Ёлка, Ель, Жук, Айва,
Ёж, Еда»:

- через `<`: Ёж, Ёлка, Айва, Еда, Ель, Жук, Яблоко. Буква «Ё» в
  Unicode стоит **перед** «А» (код U+0401 против U+0410), поэтому все
  слова на «Ё» улетают в начало списка.
- через `localizedStandardCompare`: Айва, Еда, Ёж, Ёлка, Ель, Жук,
  Яблоко. «Е» и «Ё» сравниваются как одна буква, и «Ёлка» встаёт между
  «Ёж» и «Ель», как в словаре.

`localizedStandardCompare` — то сравнение, которым сортирует Finder:
без учёта регистра, с учётом правил языка и с «умными» числами —
«file2» окажется раньше «file10» (при посимвольном сравнении было бы
наоборот, потому что «1» меньше «2»).

## 31.13 Деньги: Decimal вместо Double

**Когда применять.** Всегда, когда число — это деньги: цена, скидка,
налог, итог.

`Double` хранит число в **двоичной** системе. Большинство десятичных
дробей в двоичной записи бесконечны, как 1/3 = 0,333… в десятичной.
Поэтому 0,1 хранится приблизительно (в памяти это
0,1000000000000000055…), и ошибки накапливаются:

```swift
print(0.1 + 0.2)          // 0.30000000000000004
print(0.1 + 0.2 == 0.3)   // false
```

Десять раз прибавить 0,1 — получится 0,9999999999999999, а не 1. Для
длины линии на экране это неважно, для суммы в чеке — ошибка на
копейку, которую увидит бухгалтер.

**`Decimal`** хранит число в десятичной системе, поэтому 0,1 для него —
ровно одна десятая:

```swift
let a = Decimal(string: "0.1")!
let b = Decimal(string: "0.2")!
print(a + b)                               // 0.3
print(a + b == Decimal(string: "0.3")!)    // true
```

Главная ловушка — **создание `Decimal` из дробного литерала**:

```swift
print(Decimal(1234.56))             // 1234.5599999999997952
print(Decimal(string: "1234.56")!)  // 1234.56
```

`Decimal(1234.56)` сначала превращает литерал в `Double` (уже с
ошибкой), а потом переносит эту ошибку в `Decimal`. Создавай
`Decimal` из строки (`Decimal(string:)` — например, из ответа
сервера), из целого числа или храни суммы в **минимальных единицах**:
цена 1999,99 ₸ = 199 999 тиынов, целое `Int`, никаких дробей.

Операции `+`, `-`, `*`, `/` у `Decimal` обычные. Для округления в
Foundation есть функция `NSDecimalRound`; удобнее завернуть её в метод:

```swift
extension Decimal {
    func rounded(scale: Int, _ mode: NSDecimalNumber.RoundingMode = .plain) -> Decimal {
        var value = self
        var result = Decimal()
        NSDecimalRound(&result, &value, scale, mode)
        return result
    }
}

let price = Decimal(string: "1999.99")!
let total = price * 3                           // 5999.97
let tax = total * Decimal(string: "0.16")!      // 959.9952
tax.rounded(scale: 2)                           // 960 (то есть 960,00)
```

Числа словами: три товара по 1999,99 — ровно 5999,97. Налог 16% — это
умножить на 0,16, получается 959,9952: четыре знака после запятой. В
деньгах их два, поэтому округляем до сотых (`scale: 2`). Третья цифра
после запятой — 5, значит округляем вверх: 959,9952 → 960,00. Вывод
`960`, а не `960.00`, потому что `Decimal` не хранит незначащие нули —
два знака добавит форматтер при показе.

Режимы округления на числе 2,5:

- `.plain` — «школьное»: половина вверх, 2,5 → 3;
- `.bankers` — к чётному: 2,5 → 2, но 3,5 → 4 (о смысле — в 31.5);
- `.up` / `.down` — всегда вверх / всегда вниз.

Какой выбрать, решает не программист, а бухгалтерия или закон страны.
Важно одно: округлять один раз, в оговорённом месте (например, налог
по каждой строке чека или по итогу — это разные суммы).

Чтобы показать `Decimal` через `NumberFormatter`, передай его как
`NSDecimalNumber`: `Money.tenge.string(from: total as NSDecimalNumber)`.

## 31.14 FormatStyle — современный синтаксис (iOS 15+)

С iOS 15 у дат и чисел есть метод `.formatted(...)`. Он не требует
создавать и кешировать форматтер — стиль описывается значением прямо в
месте вызова:

```swift
let kz = Locale(identifier: "ru_KZ")

date.formatted(date: .long, time: .shortened)
// "12 мая 2026 г. в 14:30" (при русской локали устройства)

date.formatted(.dateTime.day().month(.wide).year().locale(kz))
// "12 мая 2026 г."

let money = Decimal(string: "1234.5")!
money.formatted(.currency(code: "KZT").locale(kz))
// "1 234,50 ₸"
money.formatted(.currency(code: "KZT").precision(.fractionLength(0)).locale(kz))
// "1 234 ₸"

0.42.formatted(.percent.locale(kz))     // "42 %"

["яблоки", "груши", "сливы"].formatted(.list(type: .and).locale(kz))
// "яблоки, груши и сливы"
```

Разбор:

- `.dateTime.day().month(.wide).year()` — перечисляешь **поля**, а
  порядок и знаки препинания выберет локаль. Это то же, что шаблон в
  `setLocalizedDateFormatFromTemplate`, только проще.
- `.currency(code:)` у `Decimal` — прямой путь для денег, без
  `NSDecimalNumber`. Правила про знак ₸ те же, что в 31.5: с локалью
  `ru_RU` вместо ₸ будет «KZT».
- `.precision(.fractionLength(0))` — сколько знаков после запятой.
  Округление по умолчанию тоже банковское: 2,5 → 2, 3,5 → 4.
- `.list(type: .and)` — список через запятую с «и» перед последним
  элементом, по правилам языка.

Что выбрать: для нового кода с минимумом iOS 15 — `formatted`, он
короче и не требует кеша. `DateFormatter` и `NumberFormatter` остаются
для разбора строк с сервера и для кода, который уже на них написан.

## Упражнения

**Упражнение 31.1.** Напиши функцию `priceText(_ amount: Decimal) -> String`,
которая печатает сумму в тенге без тиынов по правилам `ru_KZ`.
Проверь: `priceText(Decimal(string: "1234.5")!)` и
`priceText(Decimal(string: "1235.5")!)`. Объясни, почему результаты
«округлились в разные стороны».

**Упражнение 31.2.** Функция `plural` из 31.10 возвращает только слово.
Напиши `minutesText(_ n: Int) -> String`, которая возвращает число вместе
со словом: `minutesText(21)` → «21 минута», `minutesText(114)` →
«114 минут». Какие ещё числа из диапазона 100–125 стоит проверить?

**Упражнение 31.3.** Сервер присылает `"2026-05-12T10:30:00.500Z"`.
Напиши разбор этой строки в `Date` и покажи время в поясе
`Asia/Almaty` в формате `HH:mm`. Что должно получиться?

## Ответы к упражнениям

**31.1.**

```swift
func priceText(_ amount: Decimal) -> String {
    amount.formatted(
        .currency(code: "KZT")
            .precision(.fractionLength(0))
            .locale(Locale(identifier: "ru_KZ"))
    )
}

priceText(Decimal(string: "1234.5")!)   // "1 234 ₸"
priceText(Decimal(string: "1235.5")!)   // "1 236 ₸"
```

Округление банковское: ровно половина идёт к чётному соседу. У 1234,5
чётный сосед — 1234, у 1235,5 — 1236. Если нужно «половина всегда
вверх», добавь `.rounded(rule: .toNearestOrAwayFromZero)` перед
`.locale(...)` — тогда 1234,5 станет «1 235 ₸».

**31.2.**

```swift
func minutesText(_ n: Int) -> String {
    "\(n) \(plural(n, forms: ("минута", "минуты", "минут")))"
}

minutesText(21)    // "21 минута"
minutesText(114)   // "114 минут"
```

В диапазоне 100–125 стоит проверить границы правил: 101 («минута»),
102 («минуты»), 111–114 («минут», исключение по двум последним
цифрам), 115 («минут»), 121 («минута»), 122 («минуты»).

**31.3.**

```swift
let iso = ISO8601DateFormatter()
iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

let time = DateFormatter()
time.dateFormat = "HH:mm"
time.timeZone = TimeZone(identifier: "Asia/Almaty")

if let date = iso.date(from: "2026-05-12T10:30:00.500Z") {
    print(time.string(from: date))   // "15:30"
}
```

10:30 по UTC плюс 5 часов разницы Алматы — 15:30. Без
`.withFractionalSeconds` разбор вернул бы `nil`, и `if let` просто не
выполнил бы печать.

## Что мы выучили

- **Локаль** решает всё оформление: порядок полей даты, разделители,
  символ валюты. Для примеров — фиксированная локаль, в приложении —
  `Locale.current`.
- **DateFormatter**: стили `.short`…`.full` лучше ручного формата;
  для «полей без порядка» — шаблон; месяц без дня — `LLLL`. Кешируй.
- **RelativeDateTimeFormatter** — «5 минут назад», с `.named` — «вчера».
  `.spellOut` по-русски ошибается в роде.
- **DateComponentsFormatter** — длительности, `.positional` + `.pad`
  для таймера «01:05».
- **Календарь** вместо арифметики с 86 400 секундами: перевод часов и
  смена поясов (Алматы: UTC+6 → UTC+5 в 2024-м).
- **NumberFormatter `.currency`**: знак ₸ только в локалях `ru_KZ` /
  `kk_KZ`, в `ru_RU` — «KZT»; `currencyCode` меняет валюту, но не
  оформление; неразрывные пробелы; банковское округление по умолчанию.
- **CADisplayLink** — счётчик по прошедшему времени, режим `.common`,
  не забыть `stop()`.
- **Часовые пояса**: `Date` — момент без пояса; храни UTC, показывай
  локальное; `en_US_POSIX` для серверных форматов; `yyyy`, а не `YYYY`.
- **Плюрал**: три формы, исключение 11–14; в больших проектах — String
  Catalog с «Vary by Plural».
- **ByteCountFormatter**: `.file` = 1000, `.memory` = 1024.
- **`localizedStandardCompare`** — сортировка как в словаре и Finder.
- **Деньги — `Decimal`** из строки или целые тиыны; округление через
  `NSDecimalRound` один раз в оговорённом месте.
- **FormatStyle** (iOS 15+) — `.formatted(...)` без кеша форматтеров.

## Apple Developer Documentation

- [UIDatePicker](https://developer.apple.com/documentation/uikit/uidatepicker) — UIKit-контрол выбора даты/времени.
- [UIDatePickerStyle](https://developer.apple.com/documentation/uikit/uidatepickerstyle) — `.compact` / `.inline` / `.wheels` / `.automatic`.
- [DateFormatter](https://developer.apple.com/documentation/foundation/dateformatter) — форматирование `Date` ↔ `String` с учётом локали.
- [RelativeDateTimeFormatter](https://developer.apple.com/documentation/foundation/relativedatetimeformatter) — «5 минут назад» / «через 2 дня», iOS 13+.
- [DateComponentsFormatter](https://developer.apple.com/documentation/foundation/datecomponentsformatter) — длительности вида «1 ч 23 мин».
- [ISO8601DateFormatter](https://developer.apple.com/documentation/foundation/iso8601dateformatter) — разбор и запись ISO 8601.
- [Date.ISO8601FormatStyle](https://developer.apple.com/documentation/foundation/date/iso8601formatstyle) — ISO 8601 в стиле FormatStyle, iOS 15+.
- [Date.FormatStyle](https://developer.apple.com/documentation/foundation/date/formatstyle) — `date.formatted(...)`, iOS 15+.
- [NumberFormatter](https://developer.apple.com/documentation/foundation/numberformatter) — `.currency` / `.percent` / `.decimal` / `.ordinal`.
- [Decimal](https://developer.apple.com/documentation/foundation/decimal) — точная десятичная арифметика для денег.
- [Calendar](https://developer.apple.com/documentation/foundation/calendar) — календарные операции вместо ручной арифметики с `TimeInterval`.
- [TimeZone](https://developer.apple.com/documentation/foundation/timezone) — часовые пояса при отображении дат.
- [ByteCountFormatter](https://developer.apple.com/documentation/foundation/bytecountformatter) — размеры файлов «1,23 GB».
- [CADisplayLink](https://developer.apple.com/documentation/quartzcore/cadisplaylink) — таймер, синхронный с обновлением экрана.
- [Localizing and varying text with a string catalog](https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog) — String Catalog и формы множественного числа.

→ [Глава 32. Cookbook — анимации](./49-cookbook-animations.md)
