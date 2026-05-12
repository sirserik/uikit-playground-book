# Глава 28. Cookbook — модалки и листы

Все способы показать что-то поверх текущего экрана.

## 28.1 Bottom sheet с детентами

**Когда применять.** Создание / редактирование чего-то «лёгкого»:
заметка, событие, фильтр. Юзер может выбрать высоту.

```swift
let editor = EditorViewController()
let nav = UINavigationController(rootViewController: editor)

if let sheet = nav.sheetPresentationController {
    sheet.detents = [.medium(), .large()]
    sheet.prefersGrabberVisible = true
    sheet.preferredCornerRadius = 24
    sheet.prefersScrollingExpandsWhenScrolledToEdge = true
}

present(nav, animated: true)
```

`UISheetPresentationController` (iOS 15+).

- `detents` — позиции, между которыми можно тянуть. `[.medium()]` —
  только половинная. `[.medium(), .large()]` — обе.
- `prefersGrabberVisible = true` — серая полоска сверху.
- `preferredCornerRadius` — скругление углов.
- `prefersScrollingExpandsWhenScrolledToEdge = true` — когда юзер
  доскроллил вверх внутри, продолжение жеста расширяет sheet до
  `.large`.

**Custom detents (iOS 16+):**

```swift
sheet.detents = [
    .custom { context in 200 },
    .custom { context in context.maximumDetentValue * 0.7 },
    .large()
]
```

200 — абсолютная высота. `* 0.7` — 70% максимальной.

## 28.2 Full-screen modal

**Когда применять.** Авторизация, force-update, фото viewer.
Полностью изолирует от текущего экрана.

```swift
let vc = LoginViewController()
let nav = UINavigationController(rootViewController: vc)
nav.modalPresentationStyle = .fullScreen
present(nav, animated: true)
```

`.fullScreen` — занимает весь экран. Парент VC деактивируется,
`viewWillDisappear` срабатывает.

`.overFullScreen` — поверх, но парент остаётся **активным**. Полезно
для прозрачных overlay'ев.

## 28.3 Page sheet (легаси)

```swift
vc.modalPresentationStyle = .pageSheet  // default since iOS 13
```

Не fullScreen, не bottom sheet. iOS-стиль модала с iOS 13+ — exposed
top, можно потянуть вниз чтобы закрыть.

С детентами через `sheetPresentationController` — то же самое, но
богаче.

## 28.4 Form sheet (iPad)

```swift
vc.modalPresentationStyle = .formSheet
vc.preferredContentSize = CGSize(width: 540, height: 620)
```

На iPad — центральный модал-окно. На iPhone — стандартный page sheet.

`preferredContentSize` — размер только на iPad. Игнорируется на iPhone.

## 28.5 Popover

**Когда применять.** Маленький контекстный popup рядом с конкретным
UI-элементом. Часто на iPad. На iPhone — fallback в action sheet.

```swift
let vc = ColorPickerViewController()
vc.modalPresentationStyle = .popover
vc.preferredContentSize = CGSize(width: 280, height: 320)

if let popover = vc.popoverPresentationController {
    popover.sourceView = colorButton
    popover.sourceRect = colorButton.bounds
    popover.permittedArrowDirections = [.up, .down]
}

present(vc, animated: true)
```

`sourceView` / `sourceRect` — откуда выходит «стрелка» popover'а.

На iPhone по умолчанию iOS превращает в fullScreen. Чтобы получить
**настоящий** popover и на iPhone — нужен делегат:

```swift
extension MyVC: UIPopoverPresentationControllerDelegate {
    func adaptivePresentationStyle(for controller: UIPresentationController,
                                   traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        .none  // не адаптируем — оставляем popover'ом
    }
}

popover.delegate = self
```

## 28.6 UIAlertController — alert

**Когда применять.** Подтверждение действия, simple choice, error.

```swift
let alert = UIAlertController(
    title: "Удалить?",
    message: "Действие необратимо.",
    preferredStyle: .alert
)
alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
alert.addAction(UIAlertAction(title: "Удалить", style: .destructive) { [weak self] _ in
    self?.delete()
})
present(alert, animated: true)
```

Три style:
- `.cancel` — отмена. По UI guidelines — слева/первая.
- `.destructive` — красная подпись. Опасные действия.
- `.default` — обычная синяя подпись.

`.cancel` сама позиционируется правильно iOS (первая вне зависимости
от порядка addAction).

## 28.7 UIAlertController — action sheet

```swift
let alert = UIAlertController(title: nil, message: "Что сделать?",
                              preferredStyle: .actionSheet)
alert.addAction(UIAlertAction(title: "Поделиться", style: .default))
alert.addAction(UIAlertAction(title: "Сохранить", style: .default))
alert.addAction(UIAlertAction(title: "Удалить", style: .destructive))
alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))

alert.popoverPresentationController?.sourceView = button
alert.popoverPresentationController?.sourceRect = button.bounds

present(alert, animated: true)
```

Sheet снизу. На iPad — popover (источник через
`popoverPresentationController`, ОБЯЗАТЕЛЬНО, иначе крах).

## 28.8 Alert с UITextField

```swift
let alert = UIAlertController(title: "Создать папку", message: nil, preferredStyle: .alert)
alert.addTextField { tf in
    tf.placeholder = "Название"
    tf.autocapitalizationType = .sentences
}
alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
alert.addAction(UIAlertAction(title: "Создать", style: .default) { [weak alert] _ in
    let name = alert?.textFields?.first?.text ?? ""
    // ...
})
present(alert, animated: true)
```

`addTextField` добавляет в alert поле. Доступ к нему — через
`alert.textFields`.

## 28.9 Custom alert (без UIAlertController)

**Когда применять.** Когда стандартный alert слишком ограничен —
например, нужны кастомный шрифт, картинка, цвет.

```swift
let dimming = UIView(frame: view.bounds)
dimming.backgroundColor = UIColor.black.withAlphaComponent(0.5)
dimming.alpha = 0
view.addSubview(dimming)

let card = UIView()
card.backgroundColor = .systemBackground
card.layer.cornerRadius = 20
// ... + иконка + текст + кнопка внутри ...

card.alpha = 0
card.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
view.addSubview(card)
// ... pin card по центру ...

UIView.animate(withDuration: 0.25) {
    dimming.alpha = 1
    card.alpha = 1
    card.transform = .identity
}
```

Полупрозрачный dimming + карточка по центру со spring-анимацией.
Полный контроль над дизайном.

См. Главу 21 (Cookbook patterns) для готового примера.

## 28.10 In-app banner

**Когда применять.** Уведомление сверху, не блокирующее (новое
сообщение, downloads finished).

```swift
let banner = UIView()
banner.backgroundColor = .systemBlue
banner.translatesAutoresizingMaskIntoConstraints = false
banner.transform = CGAffineTransform(translationX: 0, y: -100)
view.addSubview(banner)
NSLayoutConstraint.activate([
    banner.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
    banner.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
    banner.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
])

UIView.animate(withDuration: 0.4, delay: 0,
               usingSpringWithDamping: 0.7,
               initialSpringVelocity: 0) {
    banner.transform = .identity
}

DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
    UIView.animate(withDuration: 0.3, animations: {
        banner.transform = CGAffineTransform(translationX: 0, y: -100)
    }) { _ in banner.removeFromSuperview() }
}
```

Spring-анимация при появлении (выезжает сверху), исчезает через 3
секунды.

## 28.11 HUD — Heads-Up Display

**Когда применять.** «Сохранено!», «Скопировано», «Done». Большой
блок с иконкой и текстом по центру, на 1-2 секунды.

```swift
let hud = UIView()
hud.backgroundColor = UIColor.black.withAlphaComponent(0.85)
hud.layer.cornerRadius = 18

let icon = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
icon.tintColor = .systemGreen
let label = UILabel()
label.text = "Сохранено"
label.textColor = .white

let stack = UIStackView(arrangedSubviews: [icon, label])
stack.axis = .vertical
stack.alignment = .center
stack.spacing = 12
// ... pin stack в hud, hud по центру view ...

hud.alpha = 0
UIView.animate(withDuration: 0.2) { hud.alpha = 1 }
DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
    UIView.animate(withDuration: 0.3, animations: { hud.alpha = 0 }) { _ in
        hud.removeFromSuperview()
    }
}
```

См. Главу 23 (Cookbook patterns) для разнообразных HUD'ов.

## 28.12 Modal flow с UIViewControllerTransitioningDelegate

**Когда применять.** Полный контроль над анимацией модала.

```swift
class FadeTransition: NSObject, UIViewControllerAnimatedTransitioning {
    let isPresenting: Bool
    init(isPresenting: Bool) { self.isPresenting = isPresenting }

    func transitionDuration(...) -> TimeInterval { 0.3 }

    func animateTransition(using ctx: UIViewControllerContextTransitioning) {
        let container = ctx.containerView
        if isPresenting {
            guard let to = ctx.view(forKey: .to) else { return }
            to.alpha = 0
            container.addSubview(to)
            UIView.animate(withDuration: 0.3, animations: {
                to.alpha = 1
            }) { _ in ctx.completeTransition(true) }
        } else {
            guard let from = ctx.view(forKey: .from) else { return }
            UIView.animate(withDuration: 0.3, animations: {
                from.alpha = 0
            }) { _ in ctx.completeTransition(true) }
        }
    }
}

class MyTransitioning: NSObject, UIViewControllerTransitioningDelegate {
    func animationController(forPresented presented: ..., presenting: ..., source: ...) -> UIViewControllerAnimatedTransitioning? {
        FadeTransition(isPresenting: true)
    }
    func animationController(forDismissed dismissed: ...) -> UIViewControllerAnimatedTransitioning? {
        FadeTransition(isPresenting: false)
    }
}

// Использование
vc.transitioningDelegate = myTransitioning
vc.modalPresentationStyle = .custom
present(vc, animated: true)
```

`.custom` — отказываемся от стандартной анимации, используем свою.

Сложный API, но полная свобода. Hero-animation, slide-from-anywhere,
3D-flip — всё через это.

## 📋 Что мы выучили

- **`UISheetPresentationController`** (iOS 15+) — bottom sheet с
  детентами. `[.medium(), .large()]`, grabber, custom detents (iOS 16+).
- **`.fullScreen` vs `.overFullScreen` vs `.pageSheet`** — разные
  степени «изоляции» парента.
- **`.popover`** на iPad, fallback в `.actionSheet` на iPhone (по
  умолчанию). Через `popoverPresentationControllerDelegate` можно
  заставить popover работать и на iPhone.
- **`UIAlertController`** — `.alert` (центр) и `.actionSheet` (низ).
  На iPad action sheet требует `popoverPresentationController.sourceView`.
- **`addTextField`** на alert — встроенный input.
- **Custom alert** — полупрозрачный dimming + карточка со spring.
  Полный контроль над дизайном.
- **In-app banner** — выезжает сверху, исчезает по таймеру.
- **HUD** — короткое подтверждение «Готово!» с иконкой по центру.
- **`UIViewControllerTransitioningDelegate`** + `.custom` —
  полный контроль над анимацией модала.

## Apple Developer Documentation

- [`UISheetPresentationController`](https://developer.apple.com/documentation/uikit/uisheetpresentationcontroller) — bottom sheet с детентами (iOS 15+).
- [`UISheetPresentationController.Detent`](https://developer.apple.com/documentation/uikit/uisheetpresentationcontroller/detent) — `.medium()`, `.large()`, `.custom { ... }` (iOS 16+).
- [`UIViewController.sheetPresentationController`](https://developer.apple.com/documentation/uikit/uiviewcontroller/3801906-sheetpresentationcontroller) — слот контроллера для конфигурации sheet'а.
- [`UIViewController.presentationController`](https://developer.apple.com/documentation/uikit/uiviewcontroller/1621426-presentationcontroller) — общий presentation controller, отсюда получаем popover, sheet, alert.
- [`UIModalPresentationStyle`](https://developer.apple.com/documentation/uikit/uimodalpresentationstyle) — `.fullScreen`, `.overFullScreen`, `.pageSheet`, `.formSheet`, `.popover`, `.custom`.
- [`UIAlertController`](https://developer.apple.com/documentation/uikit/uialertcontroller) — `.alert` и `.actionSheet`.
- [`UIAlertAction.Style`](https://developer.apple.com/documentation/uikit/uialertaction/style) — `.default`, `.cancel`, `.destructive`.
- [`UIPopoverPresentationController`](https://developer.apple.com/documentation/uikit/uipopoverpresentationcontroller) — `sourceView`/`sourceRect`/`barButtonItem`, обязательно при `.actionSheet` на iPad.
- [`UIPopoverPresentationControllerDelegate`](https://developer.apple.com/documentation/uikit/uipopoverpresentationcontrollerdelegate) — `adaptivePresentationStyle(for:traitCollection:)` для popover'а на iPhone.
- [`UIViewControllerTransitioningDelegate`](https://developer.apple.com/documentation/uikit/uiviewcontrollertransitioningdelegate) и [`UIViewControllerAnimatedTransitioning`](https://developer.apple.com/documentation/uikit/uiviewcontrolleranimatedtransitioning) — кастомные модальные переходы.
- [HIG — Sheets](https://developer.apple.com/design/human-interface-guidelines/sheets) и [HIG — Alerts](https://developer.apple.com/design/human-interface-guidelines/alerts) — Apple про когда какой модал использовать.

→ [Глава 29. Cookbook: жесты](./46-cookbook-gestures.md)
