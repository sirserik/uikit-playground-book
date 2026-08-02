# Глава 36. Cookbook — индикаторы статуса

Online dot, typing indicator, badges, progress bars.

## 36.1 Online dot

Зелёный круг рядом с аватаркой:

```swift
let onlineDot = UIView()
onlineDot.backgroundColor = .systemGreen
onlineDot.layer.cornerRadius = 6
onlineDot.layer.borderColor = UIColor.systemBackground.cgColor
onlineDot.layer.borderWidth = 2
onlineDot.translatesAutoresizingMaskIntoConstraints = false
avatar.addSubview(onlineDot)
NSLayoutConstraint.activate([
    onlineDot.widthAnchor.constraint(equalToConstant: 12),
    onlineDot.heightAnchor.constraint(equalToConstant: 12),
    onlineDot.trailingAnchor.constraint(equalTo: avatar.trailingAnchor),
    onlineDot.bottomAnchor.constraint(equalTo: avatar.bottomAnchor),
])
```

Border цвета фона — даёт чёткое отделение от аватарки.

Статусы:
- `.systemGreen` — online.
- `.systemYellow` — away / idle.
- `.systemGray` — offline.
- `.systemRed` — do not disturb (редко).

## 36.2 Typing indicator (three bouncing dots)

```swift
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
```

Три точки, каждая прыгает на 5pt вверх / вниз, с задержкой 150ms друг
от друга. Получается «бегущая волна».

См. Главу 18 (Chat).

## 36.3 Badge (число на иконке)

`UITabBarItem`:

```swift
tabBarController?.tabBar.items?[0].badgeValue = "3"
tabBarController?.tabBar.items?[0].badgeColor = .systemRed
```

Кастомный badge на любом UIView:

```swift
private func addBadge(to view: UIView, text: String) {
    let badge = UILabel()
    badge.text = text
    badge.font = .systemFont(ofSize: 11, weight: .bold)
    badge.textColor = .white
    badge.backgroundColor = .systemRed
    badge.textAlignment = .center
    badge.layer.cornerRadius = 9
    badge.layer.masksToBounds = true
    badge.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(badge)
    NSLayoutConstraint.activate([
        badge.widthAnchor.constraint(greaterThanOrEqualToConstant: 18),
        badge.heightAnchor.constraint(equalToConstant: 18),
        badge.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 4),
        badge.topAnchor.constraint(equalTo: view.topAnchor, constant: -4),
    ])
}
```

`greaterThanOrEqualToConstant: 18` — для двузначных чисел растягивается.
Если число > 99 — отображай "99+".

## 36.4 Progress bar

```swift
let progress = UIProgressView(progressViewStyle: .default)
progress.progress = 0.42  // 42%
progress.trackTintColor = UIColor.tertiaryLabel.withAlphaComponent(0.3)
progress.progressTintColor = .systemBlue
```

`progressViewStyle.bar` — без скруглений, в navigation bar.
`.default` — стандартная толщина.

Animated update:

```swift
UIView.animate(withDuration: 0.3) {
    progress.setProgress(0.75, animated: false)  // animated:false внутри animate{}
}
```

## 36.5 Circular progress

```swift
class CircularProgressView: UIView {
    private let trackLayer = CAShapeLayer()
    private let progressLayer = CAShapeLayer()

    var progress: CGFloat = 0 {
        didSet {
            progressLayer.strokeEnd = progress
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.addSublayer(trackLayer)
        layer.addSublayer(progressLayer)
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
        trackLayer.lineWidth = 8
        trackLayer.strokeColor = UIColor.tertiaryLabel.cgColor
        trackLayer.fillColor = UIColor.clear.cgColor

        progressLayer.path = path.cgPath
        progressLayer.lineWidth = 8
        progressLayer.strokeColor = UIColor.systemBlue.cgColor
        progressLayer.fillColor = UIColor.clear.cgColor
        progressLayer.strokeEnd = progress
        progressLayer.lineCap = .round
    }
}
```

Two `CAShapeLayer`'а: фон (серая дуга) + прогресс (синяя). Меняем
`strokeEnd` от 0 до 1.

`startAngle: -π/2` — стартуем с 12 часов (top). `clockwise: true` —
прогресс идёт по часовой.

## 36.6 Skeleton vs spinner — в зависимости от контекста

```swift
class StatusIndicator {
    enum State { case loading, loaded, error, empty }
    var state: State = .loading {
        didSet {
            update()
        }
    }

    private func update() {
        spinner.isHidden = state != .loading
        emptyView.isHidden = state != .empty
        errorView.isHidden = state != .error
        contentView.isHidden = state != .loaded
    }
}
```

Один enum для состояний экрана, один update() для отрисовки.
Чистая `state machine`.

## 36.7 Live count animation

```swift
private func animateCount(from: Int, to: Int, label: UILabel) {
    let duration = 0.6
    let steps = 30
    for step in 0...steps {
        let progress = Double(step) / Double(steps)
        let value = Int(Double(from) + Double(to - from) * progress)
        DispatchQueue.main.asyncAfter(deadline: .now() + (duration * Double(step) / Double(steps))) {
            label.text = "\(value)"
        }
    }
}
```

См. Главу 31.7 (CADisplayLink-based) для более правильной реализации.

## 36.8 Status colors

Цвета для разных состояний:

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
}
```

Универсальный enum для status indicator'ов. Иконка + цвет — мгновенно
читаемо.

## 36.9 Animated badge change

```swift
private func updateBadge(_ count: Int) {
    badge.text = "\(count)"
    UIView.animate(withDuration: 0.15, animations: {
        self.badge.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
    }) { _ in
        UIView.animate(withDuration: 0.15) {
            self.badge.transform = .identity
        }
    }
}
```

Pop animation при обновлении badge — пользователь замечает, что
число изменилось.

## 36.10 Page control

```swift
let pageControl = UIPageControl()
pageControl.numberOfPages = 4
pageControl.currentPage = 0
pageControl.currentPageIndicatorTintColor = .systemBlue
pageControl.pageIndicatorTintColor = .quaternaryLabel
pageControl.allowsContinuousInteraction = true  // iOS 14+
```

`allowsContinuousInteraction = true` — long-press на page control
показывает scrubber, можно swipe'ом между точками выбирать страницу.

См. Главу 6 (Onboarding) для использования.

## 36.11 Read receipts

Галочки «прочитано / доставлено»:

```swift
enum MessageStatus {
    case sending, sent, delivered, read
    var glyph: String {
        switch self {
        case .sending: return "⏳"
        case .sent: return "✓"
        case .delivered: return "✓✓"
        case .read: return "✓✓"
        }
    }
    var color: UIColor {
        switch self {
        case .read: return .systemBlue
        default: return .secondaryLabel
        }
    }
}
```

Символьные галочки или SF Symbols. Для прочитанного — синие (как в
Telegram).

См. Главу 18 (Chat).

## 36.12 Connection quality

```swift
enum ConnectionQuality {
    case excellent, good, fair, poor, offline

    var color: UIColor {
        switch self {
        case .excellent: return .systemGreen
        case .good: return .systemGreen
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

Используется в video-call приложениях. Показывает 4 полоски — каждая
становится цветной в зависимости от качества.

## 📋 Что мы выучили

- **Online dot** — `UIView` с `cornerRadius` + border цвета фона.
- **Typing indicator** — 3 точки с `CABasicAnimation` на
  `transform.translation.y` + offset begin time.
- **Badge** — `UILabel` с `cornerRadius` + `greaterThanOrEqualTo` для
  двузначных чисел.
- **`UIProgressView`** + animated update через
  `UIView.animate { setProgress(...) }`.
- **Circular progress** — два `CAShapeLayer`'а, меняем `strokeEnd`.
- **State enum** для индикаторов состояния — loading/loaded/error/empty.
- **Live count animation** — CADisplayLink-based или manual chain.
- **Status colors** — enum с `color`/`icon` для всех типов.
- **Animated badge** — pop при обновлении (scaleX/Y 1.3).
- **`allowsContinuousInteraction`** на UIPageControl (iOS 14+).

## Apple Developer Documentation

- [UIProgressView](https://developer.apple.com/documentation/uikit/uiprogressview) — линейный progress bar с `progress` / `setProgress(_:animated:)`.
- [UIProgressView.Style](https://developer.apple.com/documentation/uikit/uiprogressview/style) — `.default` и `.bar` для размещения в nav bar.
- [UIPageControl](https://developer.apple.com/documentation/uikit/uipagecontrol) — индикатор страниц и `allowsContinuousInteraction` (iOS 14+).
- [UIActivityIndicatorView](https://developer.apple.com/documentation/uikit/uiactivityindicatorview) — стандартный «спиннер» с `.medium` / `.large`.
- [UITabBarItem/badgeValue](https://developer.apple.com/documentation/uikit/uitabbaritem/badgevalue) — текст бейджа на вкладке.
- [UITabBarItem/badgeColor](https://developer.apple.com/documentation/uikit/uitabbaritem/badgecolor) — цвет бейджа.
- [CAShapeLayer](https://developer.apple.com/documentation/quartzcore/cashapelayer) — `strokeEnd` для circular progress.
- [UIBezierPath](https://developer.apple.com/documentation/uikit/uibezierpath) — рисование дуги для кругового индикатора.
- [CABasicAnimation](https://developer.apple.com/documentation/quartzcore/cabasicanimation) — бесконечная анимация typing dots через `transform.translation.y`.

→ [Глава 37. Cookbook: photo viewer](./54-cookbook-photo-viewer.md)
