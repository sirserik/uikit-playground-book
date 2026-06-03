# Глава 31. Cookbook — дата, время, деньги

Форматирование. Всё, что показывает Date или Decimal человеку.

## 31.1 DateFormatter — base

```swift
let formatter = DateFormatter()
formatter.locale = Locale(identifier: "ru_RU")
formatter.dateStyle = .medium  // 12 мая 2026
formatter.timeStyle = .short   // 14:30
let text = formatter.string(from: date)
```

`.short` / `.medium` / `.long` / `.full` — четыре уровня детализации.

Кастомный формат:

```swift
formatter.dateFormat = "d MMMM yyyy"   // 12 мая 2026
formatter.dateFormat = "HH:mm"          // 14:30
formatter.dateFormat = "EEEE"           // вторник
formatter.dateFormat = "yyyy-MM-dd"     // 2026-05-12
```

> ⚠ **Кешируй formatter'ы.** `DateFormatter` дорогой в инициализации.
> Создавай static / lazy.

## 31.2 RelativeDateTimeFormatter

«5 минут назад», «через 2 дня»:

```swift
let formatter = RelativeDateTimeFormatter()
formatter.locale = Locale(identifier: "ru_RU")
formatter.unitsStyle = .full   // .full / .short / .abbreviated
let text = formatter.localizedString(for: someDate, relativeTo: Date())
// "5 минут назад"
```

iOS 13+. Поддерживает плюралы для русского.

## 31.3 DateComponentsFormatter — длительности

«1 час 23 минуты»:

```swift
let formatter = DateComponentsFormatter()
formatter.allowedUnits = [.hour, .minute, .second]
formatter.unitsStyle = .abbreviated  // "1 ч 23 мин"
formatter.string(from: 4980)  // 4980 секунд
```

## 31.4 Календарные операции

```swift
let cal = Calendar.current
let now = Date()

// Начало текущего дня
let today = cal.startOfDay(for: now)

// Завтра
let tomorrow = cal.date(byAdding: .day, value: 1, to: now)

// День недели
let weekday = cal.component(.weekday, from: now)  // 1=воскресенье, 2=понедельник

// Сегодня ли?
let isToday = cal.isDateInToday(someDate)

// Возраст
let age = cal.dateComponents([.year], from: birthDate, to: now).year ?? 0
```

Никогда не делай арифметику через `TimeInterval` (`date.addingTimeInterval(86400)`) — DST, високосные годы, разные календарные системы её сломают.

## 31.5 NumberFormatter — деньги

```swift
let formatter = NumberFormatter()
formatter.numberStyle = .currency
formatter.locale = Locale(identifier: "ru_RU")  // ₽
formatter.string(from: NSNumber(value: 1234.5))  // "1 234,50 ₽"

// KZT
formatter.locale = Locale(identifier: "ru_KZ")  // ₸
formatter.string(from: NSNumber(value: 1234.5))  // "1 234,50 ₸"

// USD из любой локали
formatter.numberStyle = .currency
formatter.currencyCode = "USD"
formatter.string(from: NSNumber(value: 1234.5))  // "$1,234.50"
```

`numberStyle = .currency` — auto-разделители тысяч + знак валюты из
локали.

`currencyCode = "USD"` — переопределяет валюту, оставляя локаль (то
есть формат разделителей).

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
// Для en_US вернёт "3rd". Для русской локали порядковый
// суффикс не формируется (зависит от рода/падежа) — придёт "3".
formatter.string(from: NSNumber(value: 3))
```

## 31.7 Number animation

«Растущий счётчик»:

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

Или через `CADisplayLink` (точнее, GPU-tied):

```swift
class CountAnimator {
    private var displayLink: CADisplayLink?
    private var startValue: Double = 0
    private var endValue: Double = 0
    private var duration: Double = 1.0
    private var startTime: TimeInterval = 0
    var update: ((Double) -> Void)?

    func animate(from: Double, to: Double, duration: Double = 1.0) {
        self.startValue = from
        self.endValue = to
        self.duration = duration
        startTime = CACurrentMediaTime()
        displayLink?.invalidate()
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    @objc private func tick() {
        let elapsed = CACurrentMediaTime() - startTime
        let progress = min(elapsed / duration, 1.0)
        let value = startValue + (endValue - startValue) * progress
        update?(value)
        if progress >= 1.0 { displayLink?.invalidate(); displayLink = nil }
    }
}
```

Использование:

```swift
let animator = CountAnimator()
animator.update = { value in
    label.text = "\(Int(value))"
}
animator.animate(from: 0, to: 100, duration: 1.0)
```

`CADisplayLink` синхронизирован с frame rate экрана — плавнее, чем
DispatchQueue chain.

## 31.8 UIDatePicker

```swift
let picker = UIDatePicker()
picker.datePickerMode = .date  // .time / .dateAndTime / .countDownTimer
picker.preferredDatePickerStyle = .compact  // iOS 14+
picker.minimumDate = Calendar.current.date(byAdding: .year, value: -100, to: Date())
picker.maximumDate = Date()
picker.locale = Locale(identifier: "ru_RU")
picker.addTarget(self, action: #selector(dateChanged), for: .valueChanged)
```

Стили:

- `.compact` — маленькая «таблетка», open inline (iOS 14+).
- `.inline` — постоянно открытый календарь (iOS 14+).
- `.wheels` — three-wheel picker (legacy, всё ещё работает).
- `.automatic` — iOS выбирает.

`.compact` — самый компактный, хорошо в ячейке. `.inline` — для
date-pickers, которые должны быть всегда видны.

## 31.9 Time zone

Дата — это **момент времени** (timestamp). Отображение зависит от
часового пояса:

```swift
let formatter = DateFormatter()
formatter.dateFormat = "HH:mm"
formatter.timeZone = TimeZone(identifier: "Asia/Almaty")
```

При работе с серверными датами **храни в UTC**, **показывай в
локальной**:

```swift
// Парсинг ISO8601 с UTC
let isoFormatter = ISO8601DateFormatter()
isoFormatter.formatOptions = [.withInternetDateTime]
let date = isoFormatter.date(from: "2026-05-12T10:30:00Z")!
// date — момент времени, не зависит от TZ

// Отображение для пользователя
let display = DateFormatter()
display.dateStyle = .medium
display.timeStyle = .short
// timeZone default = current → юзер видит своё время
let text = display.string(from: date)
```

## 31.10 Тонкости русского плюрала

«1 минута», «2 минуты», «5 минут», «11 минут», «21 минута»:

```swift
func plural(_ n: Int, forms: (one: String, few: String, many: String)) -> String {
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
plural(12, forms: ("минута", "минуты", "минут"))   // "минут" (исключение)
```

iOS 15+: `AttributedString.inflect(...)` обещает то же самое, но для
русского работает неидеально. Своя функция надёжнее.

## 31.11 Размер файлов

```swift
let formatter = ByteCountFormatter()
formatter.allowedUnits = [.useMB, .useGB]
formatter.countStyle = .file
formatter.string(fromByteCount: 1234567890)  // "1.23 GB"
```

`countStyle`:
- `.file` — десятичные (1KB = 1000 B). Apple стандарт.
- `.memory` — бинарные (1KiB = 1024 B). Старый Linux стандарт.
- `.binary` — то же что memory.
- `.decimal` — то же что file.

## 31.12 Locale-aware comparison

При сортировке строк:

```swift
// Плохо — лексикографическое сравнение
items.sorted { $0.name < $1.name }
// "Ёлка" окажется после "Я"

// Хорошо — locale-aware
items.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
// "Ёлка" между "Е" и "Ж"
```

`.localizedStandardCompare` — Apple's "smart" comparison: учитывает
диакритику, числа («File 2» < «File 10», не алфавитно), регистр.

## 📋 Что мы выучили

- **DateFormatter** — `.dateStyle`/`.timeStyle` или кастомный
  `dateFormat`. Кешируй, дорогой в init.
- **RelativeDateTimeFormatter** — «5 минут назад», плюралы для
  русского.
- **DateComponentsFormatter** — длительности «1 ч 23 мин».
- **Календарные операции** — `Calendar.current` (никогда не через
  TimeInterval).
- **NumberFormatter** — `.currency`/`.percent`/`.decimal`/`.ordinal`.
  `currencyCode` для override.
- **CADisplayLink** для smooth number animation.
- **UIDatePicker `.compact`** — современный (iOS 14+) inline-style.
- **Time zone** — храни UTC, показывай локальное. `ISO8601DateFormatter`
  для парсинга.
- **Русский плюрал** — своя функция через `% 100` / `% 10` (учитывая
  исключения 11-14).
- **`ByteCountFormatter`** для размеров файлов.
- **`.localizedStandardCompare`** для сортировки строк.

## Apple Developer Documentation

- [UIDatePicker](https://developer.apple.com/documentation/uikit/uidatepicker) — UIKit-контрол выбора даты/времени.
- [UIDatePicker.Style](https://developer.apple.com/documentation/uikit/uidatepicker/style) — `.compact` / `.inline` / `.wheels` / `.automatic` (iOS 14+).
- [DateFormatter](https://developer.apple.com/documentation/foundation/dateformatter) — форматирование `Date` ↔ `String` с учётом локали.
- [RelativeDateTimeFormatter](https://developer.apple.com/documentation/foundation/relativedatetimeformatter) — «5 минут назад» / «через 2 дня», iOS 13+.
- [DateComponentsFormatter](https://developer.apple.com/documentation/foundation/datecomponentsformatter) — длительности вида «1 ч 23 мин».
- [ISO8601DateFormatter](https://developer.apple.com/documentation/foundation/iso8601dateformatter) — парсинг и сериализация ISO 8601.
- [Date.ISO8601FormatStyle](https://developer.apple.com/documentation/foundation/date/iso8601formatstyle) — современный formatter-style API, iOS 15+.
- [NumberFormatter](https://developer.apple.com/documentation/foundation/numberformatter) — `.currency` / `.percent` / `.decimal` / `.ordinal`.
- [Decimal](https://developer.apple.com/documentation/foundation/decimal) — точная десятичная арифметика для денег.
- [Calendar](https://developer.apple.com/documentation/foundation/calendar) — календарные операции вместо ручной арифметики с `TimeInterval`.
- [TimeZone](https://developer.apple.com/documentation/foundation/timezone) — часовые пояса при отображении дат.
- [ByteCountFormatter](https://developer.apple.com/documentation/foundation/bytecountformatter) — размеры файлов «1.23 GB» / «456 KB».
- [CADisplayLink](https://developer.apple.com/documentation/quartzcore/cadisplaylink) — синхронизация с frame rate экрана для плавной анимации чисел.

→ [Глава 32. Cookbook: анимации](./49-cookbook-animations.md)
