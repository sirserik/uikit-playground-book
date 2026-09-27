# Глава 36. Cookbook — индикаторы статуса

Маленькие элементы, которые сообщают состояние: зелёная точка «в
сети», три прыгающие точки «печатает», красный кружок с числом
непрочитанных, полоска и кольцо прогресса, галочки доставки.

У всех рецептов главы две общие ловушки, и они проверены на
симуляторе:

- **Цвета слоёв не следят за темой.** Рамка, обводка, цвет
  `CAShapeLayer` — это `CGColor`, и при переключении темы они
  остаются прежними (почему — в главе 35.6). Поэтому каждый
  компонент ниже сам обновляет такие цвета.
- **Бесконечные анимации слоя снимаются**, когда view уходит из окна.
  Замер: пульсирующей точке убрали и вернули родителя — список
  анимаций слоя стал пустым, точка замерла. Поэтому анимации
  запускаются в `didMoveToWindow()`, а не один раз в `init`.

И одно правило доступности: **статус нельзя передавать только
цветом**. Около 8% мужчин плохо различают красный и зелёный, а
VoiceOver цвет вообще не произносит. Цвет + текст, цвет + форма, цвет
+ `accessibilityLabel`.

## 36.1 Точка «в сети»

Зелёный кружок в углу аватарки:

```swift
final class OnlineDotView: UIView {
    var isOnline = false {
        didSet {
            backgroundColor = isOnline ? .systemGreen : .systemGray
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .systemGray
        layer.cornerRadius = 6
        layer.borderWidth = 2
        updateBorder()
        if #available(iOS 17, *) {
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
                self.updateBorder()
            }
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) не используется")
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 17, *) { return }
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateBorder()
        }
    }

    private func updateBorder() {
        layer.borderColor = UIColor.systemBackground.resolvedColor(with: traitCollection).cgColor
    }
}
```

Размещение рядом с аватаркой:

```swift
let dot = OnlineDotView()
dot.translatesAutoresizingMaskIntoConstraints = false
container.addSubview(avatar)
container.addSubview(dot)   // не в avatar: у круглой аватарки clipsToBounds = true
NSLayoutConstraint.activate([
    dot.widthAnchor.constraint(equalToConstant: 12),
    dot.heightAnchor.constraint(equalToConstant: 12),
    dot.trailingAnchor.constraint(equalTo: avatar.trailingAnchor),
    dot.bottomAnchor.constraint(equalTo: avatar.bottomAnchor),
])
dot.isOnline = true
avatar.accessibilityLabel = "Айгерим, в сети"
```

Разбор:

- `cornerRadius = 6` при размере 12 × 12 — половина стороны, поэтому
  квадрат становится кругом.
- **Рамка цвета фона** (2 точки, `systemBackground`) — «вырезает»
  точку из аватарки, иначе зелёное сливается с фото. В светлой теме
  рамка белая, в тёмной — чёрная; обновляется при смене темы через
  `updateBorder()`. Если задать цвет рамки один раз через `.cgColor`,
  после переключения на тёмную тему вокруг точки останется белое кольцо.
- **Точка добавлена в общий контейнер, а не в аватарку.** Круглую
  аватарку обычно делают через `cornerRadius` + `clipsToBounds = true`.
  Всё, что внутри неё, обрезается по кругу, — точка в правом нижнем
  углу окажется за пределами круга и пропадёт.
- `translatesAutoresizingMaskIntoConstraints = false` — без этой
  строки UIKit создаст для view свои констрейнты из `frame`, и они
  будут конфликтовать с нашими.
- Статус продублирован в `accessibilityLabel` аватарки — для VoiceOver
  (глава 34).

Цвета статусов, к которым привыкли пользователи мессенджеров:
`.systemGreen` — в сети, `.systemYellow` или `.systemOrange` — отошёл,
`.systemGray` — не в сети, `.systemRed` — «не беспокоить».

## 36.2 «Печатает…» — три прыгающие точки

```swift
final class TypingIndicatorView: UIView {
    private let dots: [UIView] = (0..<3).map { _ in UIView() }

    override init(frame: CGRect) {
        super.init(frame: frame)
        let stack = UIStackView(arrangedSubviews: dots)
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        for dot in dots {
            dot.backgroundColor = .secondaryLabel
            dot.layer.cornerRadius = 4
            dot.widthAnchor.constraint(equalToConstant: 8).isActive = true
            dot.heightAnchor.constraint(equalToConstant: 8).isActive = true
        }
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        isAccessibilityElement = true
        accessibilityLabel = "Собеседник печатает"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) не используется")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { startAnimating() }
    }

    private func startAnimating() {
        for (i, dot) in dots.enumerated() {
            let animation = CABasicAnimation(keyPath: "transform.translation.y")
            animation.fromValue = 0
            animation.toValue = -5
            animation.duration = 0.5
            animation.autoreverses = true
            animation.repeatCount = .infinity
            animation.beginTime = CACurrentMediaTime() + Double(i) * 0.15
            dot.layer.add(animation, forKey: "bounce")
        }
    }
}
```

Разбор:

- Каждая точка поднимается на 5 точек вверх (`-5`: ось y в iOS
  смотрит вниз, поэтому «вверх» — минус) за 0,5 с и за 0,5 с
  возвращается: полный прыжок — 1 секунда.
- `beginTime = CACurrentMediaTime() + i × 0.15` — вторая точка
  стартует на 0,15 с позже первой, третья — на 0,3 с. Получается
  «бегущая волна». `CACurrentMediaTime()` нужен потому, что
  `beginTime` задаётся во времени Core Animation, а не как задержка
  «от сейчас».
- `didMoveToWindow()` вызывается, когда view попадает в окно или
  уходит из него. Мы запускаем анимацию каждый раз, когда view снова
  в окне: ячейку таблицы переиспользовали, экран закрыли и открыли —
  точки продолжают прыгать. `add(_:forKey:)` с тем же ключом заменяет
  старую анимацию, дублей не будет.
- Для VoiceOver весь индикатор — один элемент с понятным текстом.

Полная версия в «пузыре» чата — в главе 18.5.

## 36.3 Бейдж с числом

На вкладке таб-бара бейдж встроенный:

```swift
tabBarController?.tabBar.items?[0].badgeValue = "3"
tabBarController?.tabBar.items?[0].badgeColor = .systemRed
```

`badgeValue = nil` — убрать бейдж. Строка может быть любой, но
длинные тексты система обрежет — для счётчика ограничь сам: «99+».

Свой бейдж на любом view:

```swift
final class BadgeLabel: UILabel {
    override init(frame: CGRect) {
        super.init(frame: frame)
        font = .systemFont(ofSize: 11, weight: .bold)
        textColor = .white
        backgroundColor = .systemRed
        textAlignment = .center
        layer.cornerRadius = 9
        layer.masksToBounds = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) не используется")
    }

    // Поля по бокам: "99+" не должен касаться краёв
    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: max(size.width + 10, 18), height: 18)
    }

    func setCount(_ count: Int) {
        isHidden = count == 0
        text = count > 99 ? "99+" : "\(count)"
        accessibilityLabel = "\(count) непрочитанных"
    }
}
```

И размещение в правом верхнем углу иконки:

```swift
let badge = BadgeLabel()
badge.translatesAutoresizingMaskIntoConstraints = false
iconView.addSubview(badge)
NSLayoutConstraint.activate([
    badge.centerXAnchor.constraint(equalTo: iconView.trailingAnchor, constant: -2),
    badge.centerYAnchor.constraint(equalTo: iconView.topAnchor, constant: 2),
])
badge.setCount(128)   // покажет "99+"
```

Разбор:

- Высота 18, `cornerRadius = 9` — половина высоты: у однозначного
  числа получается круг, у многозначного — «таблетка» со скруглёнными
  торцами.
- `intrinsicContentSize` — «естественный» размер view, из которого
  Auto Layout берёт ширину и высоту, если констрейнтов на размер нет.
  Для `UILabel` это размер текста. Мы добавляем 10 точек (по 5 с
  каждой стороны) и не даём стать уже 18 — иначе у «7» бейдж был бы
  не кругом, а тонким овалом. Без полей «99+» упирается в края.
- `masksToBounds = true` — без него `cornerRadius` скругляет только
  фон слоя, а у `UILabel` фон рисуется иначе, и углы остаются
  квадратными.
- Центр бейджа ставим **на угол** иконки, со сдвигом 2 точки внутрь:
  половина бейджа выходит за границы иконки. Поэтому у `iconView` не
  должно быть `clipsToBounds = true`, иначе вылезающая половина
  обрежется (та же ловушка, что с точкой в 36.1).
- `isHidden = count == 0` — бейдж «0» никто не показывает.

**Контраст.** Белый текст на `.systemRed` — 3,6:1 (замер на iOS 26.5),
ниже нормы 4.5:1 для мелкого текста. Так выглядят бейджи и в самой iOS,
пользователи к ним привыкли, но для важных чисел добавь
`accessibilityLabel`, а не надейся на цвет.

## 36.4 Полоса прогресса

```swift
let progress = UIProgressView(progressViewStyle: .default)
progress.progress = 0.42  // 42%
progress.trackTintColor = .systemFill
progress.progressTintColor = .systemBlue
```

`progress` — число от 0 до 1: 0,42 — заполнено 42% полосы. Если у
тебя «скачано 3 МБ из 12», это 3 / 12 = 0,25. `trackTintColor` —
цвет пустой части, `progressTintColor` — заполненной.

Стили: `.default` — обычная полоса, `.bar` — вариант для размещения в
навигационной панели или тулбаре (без фона дорожки).

Плавное изменение:

```swift
progress.setProgress(0.75, animated: true)
```

`animated: true` — полоса доедет от 0,42 до 0,75 плавно. Для
VoiceOver `UIProgressView` сам сообщает процент.

## 36.5 Круговой прогресс

```swift
final class CircularProgressView: UIView {
    private let trackLayer = CAShapeLayer()
    private let progressLayer = CAShapeLayer()

    var progress: CGFloat = 0 {
        didSet {
            progressLayer.strokeEnd = min(max(progress, 0), 1)
            accessibilityValue = "\(Int((progress * 100).rounded())) процентов"
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.addSublayer(trackLayer)
        layer.addSublayer(progressLayer)
        for shape in [trackLayer, progressLayer] {
            shape.lineWidth = 8
            shape.fillColor = UIColor.clear.cgColor
        }
        progressLayer.lineCap = .round
        progressLayer.strokeEnd = 0
        updateColors()
        isAccessibilityElement = true
        accessibilityLabel = "Прогресс"
        if #available(iOS 17, *) {
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
                self.updateColors()
            }
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) не используется")
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 17, *) { return }
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateColors()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) / 2 - 4
        let path = UIBezierPath(arcCenter: center, radius: radius,
                                startAngle: -.pi / 2,
                                endAngle: 1.5 * .pi,
                                clockwise: true)
        trackLayer.path = path.cgPath
        progressLayer.path = path.cgPath
    }

    private func updateColors() {
        trackLayer.strokeColor = UIColor.tertiarySystemFill.resolvedColor(with: traitCollection).cgColor
        progressLayer.strokeColor = UIColor.systemBlue.resolvedColor(with: traitCollection).cgColor
    }
}
```

Идея: два **`CAShapeLayer`** — слоя, которые рисуют заданную линию.
Нижний (дорожка) — полная серая окружность, верхний (прогресс) — та
же окружность синим, но нарисованная не целиком. Сколько нарисовать,
решает `strokeEnd`: 0 — ничего, 0,5 — половина, 1 — вся линия.

Геометрия словами:

- Радиус — половина меньшей стороны минус 4. Толщина линии 8, и линия
  рисуется **по центру** пути: 4 точки внутрь, 4 наружу. Без `- 4`
  внешняя половина линии вылезала бы за границы view.
- Углы в радианах (π = 180°, см. главу 32.12). Ноль радиан — это
  «3 часа» на циферблате, а углы в UIKit растут **по часовой стрелке**
  (ось y смотрит вниз). Поэтому `-π/2` — это «12 часов», верх круга.
  Конечный угол `1.5π` = `-π/2 + 2π` — снова 12 часов, но уже после
  полного оборота. Прогресс 0,25 заполнит дугу от 12 до 3 часов.
- `lineCap = .round` — скруглённые концы дуги.

Путь пересчитывается в `layoutSubviews()` — туда UIKit заходит при
каждом изменении размера view, в том числе при повороте экрана. А
цвета, наоборот, **не** в `layoutSubviews`: он не обязан вызываться
при смене темы, поэтому для них отдельный `updateColors()` с подпиской
на изменение темы.

Бесплатный бонус: `progressLayer` — самостоятельный слой, не слой
какого-то view. У таких слоёв смена свойства анимируется
автоматически (так называемая **неявная анимация**, около 0,25 с).
Поэтому `progress = 0.7` плавно «докрутит» кольцо без единой строки
анимационного кода. Если нужно мгновенно — оберни присваивание в
`CATransaction.setDisableActions(true)`.

## 36.6 Состояния экрана — один enum

```swift
final class ContentStateView: UIView {
    enum State { case loading, loaded, error, empty }

    private let spinner = UIActivityIndicatorView(style: .large)
    private let emptyView = UILabel()
    private let errorView = UILabel()
    let contentView = UIView()

    var state: State = .loading {
        didSet { update() }
    }

    private func update() {
        spinner.isHidden = state != .loading
        if state == .loading { spinner.startAnimating() } else { spinner.stopAnimating() }
        emptyView.isHidden = state != .empty
        errorView.isHidden = state != .error
        contentView.isHidden = state != .loaded
    }
}
```

**State machine** (конечный автомат) — объект, который в каждый момент
находится ровно в одном из заранее перечисленных состояний. Здесь их
четыре, и `update()` из одного места решает, что видно. Нельзя
случайно показать одновременно спиннер и ошибку: такое сочетание
просто не выразить через `enum`. Добавил новое состояние — компилятор
заставит учесть его в каждом `switch`.

Какое состояние когда показывать (скелетон, спиннер или пустой
экран) — подробно в главе 24.5.

## 36.7 Бегущее число

```swift
private func animateCount(from: Int, to: Int, label: UILabel) {
    let duration = 0.6
    let steps = 30
    for step in 0...steps {
        let progress = Double(step) / Double(steps)
        let value = Int(Double(from) + Double(to - from) * progress)
        DispatchQueue.main.asyncAfter(deadline: .now() + duration * progress) {
            label.text = "\(value)"
        }
    }
}
```

Быстрый вариант: 31 отложенная задача за 0,6 с, по одной каждые
0,02 с. На шаге 15 из 30 прошла половина времени (`progress` = 0,5),
и счётчик от 0 до 200 показывает 100.

У такого подхода есть минусы (задачи нельзя отменить, повторный вызов
«перемешивает» числа). Вариант на `CADisplayLink`, без этих проблем, —
в главе 31.7.

## 36.8 Цвета и иконки статусов

```swift
enum Status {
    case success, warning, error, info, neutral

    var color: UIColor {
        switch self {
        case .success: return .systemGreen
        case .warning: return .systemOrange
        case .error: return .systemRed
        case .info: return .systemBlue
        case .neutral: return .systemGray
        }
    }

    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        case .info: return "info.circle.fill"
        case .neutral: return "circle.fill"
        }
    }

    var spokenName: String {
        switch self {
        case .success: return "Успешно"
        case .warning: return "Внимание"
        case .error: return "Ошибка"
        case .info: return "Информация"
        case .neutral: return "Без статуса"
        }
    }
}

let status = Status.warning
let iconView = UIImageView(image: UIImage(systemName: status.icon))
iconView.tintColor = status.color
iconView.isAccessibilityElement = true
iconView.accessibilityLabel = status.spokenName
```

Один `enum` на все индикаторы приложения: цвет, иконка SF Symbols и
слово для VoiceOver рядом. Иконки специально разной **формы** —
галочка, треугольник, крестик, «i», — чтобы статус различался и без
цвета. Цвет иконки задаёт `tintColor`: SF Symbols по умолчанию
рисуются как шаблон и красятся в цвет акцента.

## 36.9 «Подпрыгивание» бейджа при смене числа

```swift
private func updateBadge(_ count: Int) {
    badge.setCount(count)
    UIView.animate(withDuration: 0.15, animations: {
        self.badge.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
    }) { _ in
        UIView.animate(withDuration: 0.15) {
            self.badge.transform = .identity
        }
    }
}
```

За 0,15 с бейдж вырастает на 30% (`1.3` — 130% размера: бейдж 18
точек становится 23,4), ещё за 0,15 с возвращается. Итого 0,3 с —
достаточно, чтобы глаз заметил «число изменилось», и не мешает.
`transform` не трогает Auto Layout: констрейнты не пересчитываются,
бейдж увеличивается вокруг своего центра.

## 36.10 Индикатор страниц

```swift
let pageControl = UIPageControl()
pageControl.numberOfPages = 4
pageControl.currentPage = 0
pageControl.currentPageIndicatorTintColor = .systemBlue
pageControl.pageIndicatorTintColor = .quaternaryLabel
pageControl.allowsContinuousInteraction = true  // iOS 14+
```

`UIPageControl` — ряд точек «страница N из M» под листаемым
контентом. `allowsContinuousInteraction = true` — если зажать палец на
точках и вести в сторону, страницы перелистываются одна за другой, как
ползунком.

Как связать точки с `UIPageViewController` — в главе 6.5.

## 36.11 Галочки доставки

```swift
enum MessageStatus {
    case sending, sent, delivered, read

    var glyph: String? {
        switch self {
        case .sending: return nil          // вместо текста — иконка часов
        case .sent: return "✓"
        case .delivered, .read: return "✓✓"
        }
    }

    var symbolName: String? {
        self == .sending ? "clock" : nil
    }

    var color: UIColor {
        self == .read ? .systemBlue : .secondaryLabel
    }

    var spokenName: String {
        switch self {
        case .sending: return "отправляется"
        case .sent: return "отправлено"
        case .delivered: return "доставлено"
        case .read: return "прочитано"
        }
    }
}
```

Одна галочка — ушло на сервер, две — доставлено собеседнику, две
синие — прочитано. «Доставлено» и «прочитано» отличаются **только
цветом**, поэтому `spokenName` для VoiceOver здесь обязателен.
«Отправляется» показываем SF Symbol `clock`, а не эмодзи песочных
часов: эмодзи в интерфейсе выглядят по-разному на разных версиях системы и плохо красятся в цвет
текста.

Живой пример с оптимистичной отправкой — в главе 18.

## 36.12 Качество связи

```swift
enum ConnectionQuality {
    case excellent, good, fair, poor, offline

    var color: UIColor {
        switch self {
        case .excellent, .good: return .systemGreen
        case .fair: return .systemYellow
        case .poor: return .systemOrange
        case .offline: return .systemRed
        }
    }

    var bars: Int {
        switch self {
        case .excellent: return 4
        case .good: return 3
        case .fair: return 2
        case .poor: return 1
        case .offline: return 0
        }
    }
}
```

Индикатор в видеозвонках: четыре полоски разной высоты, из них
закрашено `bars` штук цветом `color`, остальные — серые. «Отлично» —
4 зелёных, «плохо» — 1 оранжевая и 3 серые. Здесь снова работает
правило «не только цветом»: число закрашенных полосок читается и без
него.

## Упражнения

**Упражнение 36.1.** В `CircularProgressView` прогресс рисуется от «12
часов» по часовой стрелке. Как изменить параметры дуги, чтобы
прогресс начинался снизу, с «6 часов»? Чему равны `startAngle` и
`endAngle`?

**Упражнение 36.2.** Сделай бейдж, который показывает «99+» для чисел
больше 99, прячется при 0 и для VoiceOver говорит «Нет непрочитанных»
/ «1 непрочитанное» / «5 непрочитанных». Используй функцию `plural`
из главы 31.10.

## Ответы к упражнениям

**36.1.** «6 часов» — это четверть оборота **после** «3 часов» по часовой
стрелке, то есть угол +π/2. Полный круг — ещё 2π:

```swift
let path = UIBezierPath(arcCenter: center, radius: radius,
                        startAngle: .pi / 2,
                        endAngle: .pi / 2 + 2 * .pi,
                        clockwise: true)
```

`endAngle` = π/2 + 2π = 2,5π. Прогресс 0,25 теперь заполнит дугу от 6
до 9 часов.

**36.2.**

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

final class UnreadBadge: UILabel {
    func setCount(_ count: Int) {
        isHidden = count == 0
        text = count > 99 ? "99+" : "\(count)"
        accessibilityLabel = count == 0
            ? "Нет непрочитанных"
            : "\(count) \(plural(count, forms: ("непрочитанное", "непрочитанных", "непрочитанных")))"
    }
}
```

Для 1 и 21 — «непрочитанное», для 2–4 и остальных — «непрочитанных»
(в этом слове формы few и many совпадают). Обрати внимание: для
VoiceOver мы говорим настоящее число, даже если на экране «99+».

## Что мы выучили

- **Цвета слоёв** (`borderColor`, `strokeColor`) обновляем при смене
  темы; **бесконечные анимации** перезапускаем в `didMoveToWindow()`.
- **Статус не только цветом**: форма, текст, `accessibilityLabel`.
- **Точка «в сети»** — круг с рамкой цвета фона, в общем контейнере,
  а не внутри круглой аватарки.
- **«Печатает»** — три точки с `beginTime` со сдвигом 0,15 с.
- **Бейдж** — `UILabel` с полями через `intrinsicContentSize`, «99+»,
  скрыт при 0; у родителя не должно быть `clipsToBounds`.
- **`UIProgressView`** — доля от 0 до 1, `setProgress(_:animated:)`.
- **Круговой прогресс** — два `CAShapeLayer`, `strokeEnd`, старт в
  `-π/2`, радиус минус половина толщины линии, неявная анимация.
- **Состояния экрана** — один `enum` и один `update()`.
- **Бегущее число** — быстрый вариант здесь, правильный — в 31.7.
- **Статусы, галочки, качество связи** — `enum` с цветом, иконкой и
  словом для VoiceOver.
- **`allowsContinuousInteraction`** у `UIPageControl` (iOS 14+).

## Apple Developer Documentation

- [UIProgressView](https://developer.apple.com/documentation/uikit/uiprogressview) — линейный прогресс с `progress` / `setProgress(_:animated:)`.
- [UIProgressView.Style](https://developer.apple.com/documentation/uikit/uiprogressview/style) — `.default` и `.bar`.
- [UIPageControl](https://developer.apple.com/documentation/uikit/uipagecontrol) — индикатор страниц и `allowsContinuousInteraction` (iOS 14+).
- [UIActivityIndicatorView](https://developer.apple.com/documentation/uikit/uiactivityindicatorview) — стандартный спиннер `.medium` / `.large`.
- [UITabBarItem.badgeValue](https://developer.apple.com/documentation/uikit/uitabbaritem/badgevalue) — текст бейджа на вкладке.
- [UITabBarItem.badgeColor](https://developer.apple.com/documentation/uikit/uitabbaritem/badgecolor) — цвет бейджа.
- [CAShapeLayer](https://developer.apple.com/documentation/quartzcore/cashapelayer) — `strokeEnd` для кругового прогресса.
- [UIBezierPath](https://developer.apple.com/documentation/uikit/uibezierpath) — дуга для кругового индикатора.
- [CABasicAnimation](https://developer.apple.com/documentation/quartzcore/cabasicanimation) — бесконечная анимация точек «печатает».
- [UIView.didMoveToWindow()](https://developer.apple.com/documentation/uikit/uiview/didmovetowindow()) — момент, когда view попал в окно или покинул его.

→ [Глава 37. Cookbook — photo viewer](./54-cookbook-photo-viewer.md)
