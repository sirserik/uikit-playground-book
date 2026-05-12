# Глава 32. Cookbook — анимации

UIView.animate, CABasicAnimation, CAEmitterLayer, и когда что
использовать.

## 32.1 UIView.animate — базовый

```swift
UIView.animate(withDuration: 0.3) {
    view.alpha = 1.0
    view.transform = .identity
}
```

Анимируемые свойства:
- `frame`, `bounds`, `center`.
- `transform` (translation, scale, rotation).
- `alpha`.
- `backgroundColor`.
- Constraint `constant` (через `view.layoutIfNeeded()`).

С completion:

```swift
UIView.animate(withDuration: 0.3, animations: {
    view.alpha = 0
}) { _ in
    view.removeFromSuperview()
}
```

## 32.2 Spring

```swift
UIView.animate(
    withDuration: 0.5,
    delay: 0,
    usingSpringWithDamping: 0.6,
    initialSpringVelocity: 0.3,
    options: [.curveEaseOut]
) {
    view.transform = .identity
}
```

- `damping`: 1.0 — без пружины. < 1.0 — пружина. 0.5 — заметный отскок.
  0.7 — мягко. Я обычно беру 0.6-0.7.
- `velocity`: 0 — стартует с нуля. 1.0+ — резкий старт.

## 32.3 Sequence (последовательность)

```swift
private func animateSequence() {
    for (i, dot) in [dot1, dot2, dot3].enumerated() {
        dot.alpha = 0
        dot.transform = CGAffineTransform(translationX: 0, y: 20)
        UIView.animate(withDuration: 0.4, delay: 0.15 * Double(i), usingSpringWithDamping: 0.7, initialSpringVelocity: 0) {
            dot.alpha = 1
            dot.transform = .identity
        }
    }
}
```

Каждая точка появляется на 150ms позже предыдущей через `delay`.

Альтернативно `UIView.animateKeyframes`:

```swift
UIView.animateKeyframes(withDuration: 1.0, delay: 0, options: []) {
    UIView.addKeyframe(withRelativeStartTime: 0.0, relativeDuration: 0.3) {
        dot1.alpha = 1
    }
    UIView.addKeyframe(withRelativeStartTime: 0.3, relativeDuration: 0.3) {
        dot2.alpha = 1
    }
    UIView.addKeyframe(withRelativeStartTime: 0.6, relativeDuration: 0.3) {
        dot3.alpha = 1
    }
}
```

`relativeStartTime` / `relativeDuration` — в долях от общей.

## 32.4 Cell appearance animation

```swift
func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
    cell.alpha = 0
    cell.transform = CGAffineTransform(translationX: 0, y: 20)
    UIView.animate(withDuration: 0.4, delay: 0.05 * Double(indexPath.row),
                   usingSpringWithDamping: 0.85, initialSpringVelocity: 0) {
        cell.alpha = 1
        cell.transform = .identity
    }
}
```

«Лесенка» появления при первом показе таблицы. `delay` зависит от
row.

Чтобы не запускать на каждый scroll — флаг `hasAppeared`.

## 32.5 SF Symbol animations (iOS 17+)

```swift
imageView.image = UIImage(systemName: "heart.fill")
imageView.addSymbolEffect(.bounce, options: .speed(1.5))
imageView.addSymbolEffect(.pulse)
imageView.addSymbolEffect(.scale, options: .repeating)
```

Apple's анимация для SF Symbol'ов. `.bounce`, `.pulse`, `.variableColor`,
`.scale`, и др. iOS 17+ обязательно.

## 32.6 CABasicAnimation — для CALayer

```swift
let pulse = CABasicAnimation(keyPath: "transform.scale")
pulse.fromValue = 1.0
pulse.toValue = 1.4
pulse.duration = 0.8
pulse.autoreverses = true
pulse.repeatCount = .infinity
view.layer.add(pulse, forKey: "pulse")
```

Когда использовать вместо `UIView.animate`:

- **Бесконечная анимация** (shimmer, pulse) — `repeatCount = .infinity`.
- **Анимация CALayer** (gradient, shape) — UIView API не работает.
- **Cross-fade contents** — `keyPath: "contents"` для imageView.

Удалить: `view.layer.removeAnimation(forKey: "pulse")`.

## 32.7 CAKeyframeAnimation — несколько точек

```swift
let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
animation.values = [-12, 12, -10, 10, -6, 6, 0]
animation.duration = 0.4
view.layer.add(animation, forKey: "shake")
```

Shake-error effect. `values` — список ключевых кадров, iOS
интерполирует между ними.

См. Главу 21 (Cookbook patterns) — `ShakeErrorDemoVC`.

## 32.8 Constraint animation

```swift
heightConstraint.constant = 200
UIView.animate(withDuration: 0.3) {
    self.view.layoutIfNeeded()
}
```

Меняем `constant`, потом `layoutIfNeeded()` **внутри** animation
block'а. iOS пересчитает layout с интерполяцией.

`view.layoutIfNeeded()` **без** animation block'а — мгновенное
применение.

## 32.9 Cross-dissolve между views

```swift
UIView.transition(from: oldView, to: newView,
                  duration: 0.3,
                  options: [.transitionCrossDissolve]) { _ in
    // ...
}
```

Один view исчезает, другой появляется. Без `transform`.

Альтернативно — `UIView.transition(with: container, ...)`:

```swift
UIView.transition(with: container, duration: 0.3,
                  options: .transitionCrossDissolve,
                  animations: {
    container.subviews.first?.removeFromSuperview()
    container.addSubview(newView)
})
```

Используется в `BootCoordinator.setRoot` (см. Главу 4).

## 32.10 Confetti via CAEmitterLayer

```swift
private func launchConfetti() {
    let emitter = CAEmitterLayer()
    emitter.emitterPosition = CGPoint(x: view.bounds.midX, y: -20)
    emitter.emitterShape = .line
    emitter.emitterSize = CGSize(width: view.bounds.width, height: 1)
    let colors: [UIColor] = [.systemRed, .systemOrange, .systemYellow, .systemGreen, .systemBlue, .systemPurple]
    emitter.emitterCells = colors.map { color in
        let cell = CAEmitterCell()
        cell.birthRate = 6
        cell.lifetime = 6
        cell.velocity = 180
        cell.velocityRange = 40
        cell.emissionLongitude = .pi  // вниз
        cell.emissionRange = 0.4
        cell.spin = 2
        cell.spinRange = 3
        cell.scale = 0.1
        cell.contents = makeConfettiImage(color: color).cgImage
        return cell
    }
    view.layer.addSublayer(emitter)
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
        emitter.birthRate = 0  // остановить новые
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            emitter.removeFromSuperlayer()
        }
    }
}

private func makeConfettiImage(color: UIColor) -> UIImage {
    let size = CGSize(width: 14, height: 6)
    return UIGraphicsImageRenderer(size: size).image { ctx in
        color.setFill()
        UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 1.5).fill()
    }
}
```

Particle system. `CAEmitterLayer` создаёт частицы (`CAEmitterCell'ы),
которые «улетают» с заданной velocity / spin / lifetime.

Используется для **празднования** (выиграл уровень, выполнил все
задачи). См. Главу 21 (Cookbook).

## 32.11 Hero animation (matched geometry)

Сложный паттерн, когда элемент «переходит» из одного экрана в другой,
сохраняя geometry.

Через `UIViewControllerAnimatedTransitioning` (см. Главу 26.7):

```swift
func animateTransition(using ctx: UIViewControllerContextTransitioning) {
    let container = ctx.containerView
    // 1. Найти source view и destination view
    // 2. Снять snapshot
    // 3. Анимировать snapshot между двумя позициями
    // 4. Скрыть оригиналы во время анимации
    // 5. Показать destination, удалить snapshot
}
```

Сложно правильно реализовать. Если хочется hero легко — рассмотри
SwiftUI's `matchedGeometryEffect`.

## 32.12 Анимация на rotation

```swift
UIView.animate(withDuration: 1.0) {
    view.transform = CGAffineTransform(rotationAngle: .pi)
}

// Бесконечно
let rotate = CABasicAnimation(keyPath: "transform.rotation")
rotate.fromValue = 0
rotate.toValue = 2 * Double.pi
rotate.duration = 1.0
rotate.repeatCount = .infinity
view.layer.add(rotate, forKey: "spin")
```

`CGAffineTransform.rotationAngle` принимает радианы. `.pi` =
полоборота, `2 * .pi` = полный круг.

## 32.13 Анимация с UIPropertyAnimator

```swift
let animator = UIViewPropertyAnimator(duration: 0.3, curve: .easeOut) {
    view.alpha = 1
}
animator.startAnimation()

// Можно paus'нуть, scrub, отменить
animator.pauseAnimation()
animator.fractionComplete = 0.5
animator.continueAnimation(withTimingParameters: nil, durationFactor: 1.0)
```

iOS 10+. Более мощный API. Поддерживает реверс, паузу, скруб
(пользователь пальцем «листает» анимацию).

Используется для **interactive transitions** — например, swipe-to-
dismiss с возможностью «передумать» в середине.

## 32.14 Бытовая аналогия

`UIView.animate` — это **гайка**, которая постепенно поворачивается
от 0 до конечной позиции. Когда крутишь рукой быстро (короткий
duration) — резко. Медленно — плавно.

`CABasicAnimation` — это **маховик**, который ты запустил и он
крутится сам. Можно сказать «вот эту секунду — повернись на 360
градусов и не останавливайся» (repeatCount).

`CAEmitterLayer` — это **газонокосилка**, выбрасывающая траву во все
стороны. Каждый «лист травы» (cell) живёт пару секунд, потом исчезает.

## 📋 Что мы выучили

- **`UIView.animate`** — base. Spring через `usingSpringWithDamping`.
- **Sequence** — через delay или `animateKeyframes`.
- **Cell appearance** — `willDisplay` + `delay * indexPath.row`.
- **SF Symbol animations** (iOS 17+) — `.bounce`, `.pulse`, `.scale`.
- **`CABasicAnimation`** для бесконечных анимаций и CALayer-свойств.
- **`CAKeyframeAnimation`** — много ключевых кадров (shake-error).
- **Constraint animation** — `constant` + `layoutIfNeeded()` в
  animation block.
- **`UIView.transition`** — cross-dissolve между views.
- **`CAEmitterLayer`** — particle system (confetti).
- **`UIViewPropertyAnimator`** (iOS 10+) — для interactive animations
  с pause/scrub.

→ [Глава 33. Cookbook: haptics](./50-cookbook-haptics.md)
