# Глава 29. Cookbook — жесты

Все основные gesture recognizer'ы + паттерны их применения.

## 29.1 UIContextMenu — long-press с превью

**Когда применять.** Long-press на ячейке списка или на view — даёт
меню действий + превью.

```swift
extension MyVC: UIContextMenuInteractionDelegate {
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction,
                                configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            UIMenu(children: [
                UIAction(title: "Лайк", image: UIImage(systemName: "heart")) { _ in },
                UIAction(title: "Поделиться", image: UIImage(systemName: "square.and.arrow.up")) { _ in },
                UIAction(title: "Удалить", image: UIImage(systemName: "trash"), attributes: .destructive) { _ in },
            ])
        }
    }
}

// На view
let interaction = UIContextMenuInteraction(delegate: self)
myView.addInteraction(interaction)
```

Для UITableView / UICollectionView:

```swift
func tableView(_ tableView: UITableView,
               contextMenuConfigurationForRowAt indexPath: IndexPath,
               point: CGPoint) -> UIContextMenuConfiguration? {
    UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
        UIMenu(...)
    }
}
```

`previewProvider` — кастомное превью (отдельный VC). Если nil —
показывается копия view, на которой long-press.

## 29.2 Swipe actions (table)

```swift
func tableView(_ tableView: UITableView,
               trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath)
-> UISwipeActionsConfiguration? {
    let delete = UIContextualAction(style: .destructive, title: "Удалить") { [weak self] _, _, done in
        self?.items.remove(at: indexPath.row)
        tableView.deleteRows(at: [indexPath], with: .left)
        done(true)
    }
    delete.image = UIImage(systemName: "trash")
    let archive = UIContextualAction(style: .normal, title: "Архив") { _, _, done in
        done(true)
    }
    archive.image = UIImage(systemName: "archivebox")
    archive.backgroundColor = .systemOrange
    return UISwipeActionsConfiguration(actions: [delete, archive])
}
```

`trailingSwipeActions` — справа налево (стандарт для Mail / Notes).
`leadingSwipeActions` — слева направо (обычно для «mark as read»).

Стили:
- `.destructive` — красный фон + полное удаление по long-swipe.
- `.normal` — серый фон, без full-swipe. Можно перекрашивать.

`done(true)` — обязательно вызвать. Иначе ячейка «зависает» в
полу-открытом состоянии.

## 29.3 Pinch to zoom

```swift
let scrollView = UIScrollView()
scrollView.minimumZoomScale = 1.0
scrollView.maximumZoomScale = 4.0
scrollView.delegate = self
scrollView.bouncesZoom = true

extension MyVC: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }
}
```

`UIScrollView` поддерживает pinch **из коробки** — нужно только
указать `viewForZooming` в делегате.

См. Главу 16 (Gallery / PhotoViewer) для деталей + double-tap.

## 29.4 Pan для draggable view

```swift
let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
draggableView.addGestureRecognizer(pan)

@objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
    let translation = gesture.translation(in: view)
    draggableView.center = CGPoint(
        x: dragStart.x + translation.x,
        y: dragStart.y + translation.y
    )
    if gesture.state == .began {
        dragStart = draggableView.center
    }
}
```

`gesture.state`:
- `.began` — начало (сохраняем стартовую позицию).
- `.changed` — движение.
- `.ended` / `.cancelled` — конец.

Для **draggable card с rubber-band** — добавь ограничения по
`bounds` + return to original при ended.

## 29.5 Tap gesture

```swift
let tap = UITapGestureRecognizer(target: self, action: #selector(viewTapped))
someView.addGestureRecognizer(tap)
someView.isUserInteractionEnabled = true  // обязательно для UIImageView, UILabel

@objc private func viewTapped() {
    // ...
}
```

`isUserInteractionEnabled = true` — критично! У `UIImageView` и
`UILabel` это `false` по умолчанию.

Для **double-tap**:

```swift
let doubleTap = UITapGestureRecognizer(target: self, action: #selector(doubleTapped))
doubleTap.numberOfTapsRequired = 2
view.addGestureRecognizer(doubleTap)

// Если есть single tap — конфликт. Решение:
singleTap.require(toFail: doubleTap)
```

`require(toFail:)` — single tap **ждёт** пока double tap не провалится.
Иначе single срабатывает на первом тапе, и до double не доходит.

## 29.6 Long press

```swift
let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
longPress.minimumPressDuration = 0.5
view.addGestureRecognizer(longPress)

@objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
    if gesture.state == .began {
        // ...
    }
}
```

Срабатывает после `minimumPressDuration` (default 0.5s).

Используется редко — обычно `UIContextMenuInteraction` лучше
(автоматическая haptic, превью, меню).

## 29.7 Swipe gesture (не actions)

```swift
let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(swipedLeft))
swipeLeft.direction = .left
view.addGestureRecognizer(swipeLeft)

let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(swipedRight))
swipeRight.direction = .right
view.addGestureRecognizer(swipeRight)
```

Для **навигации между screens по свайпу** (без UIPageViewController).

Срабатывает на **короткий и быстрый** свайп. Для медленного — это
pan, не swipe.

## 29.8 Pan-to-dismiss modal

**Когда применять.** Кастомный full-screen modal, который можно
закрыть свайпом вниз.

```swift
let pan = UIPanGestureRecognizer(target: self, action: #selector(handleDragDown(_:)))
view.addGestureRecognizer(pan)

@objc private func handleDragDown(_ gesture: UIPanGestureRecognizer) {
    let translation = gesture.translation(in: view).y
    guard translation > 0 else { return }  // только вниз

    switch gesture.state {
    case .changed:
        view.transform = CGAffineTransform(translationX: 0, y: translation)
        let progress = min(translation / 200, 1)
        view.alpha = 1 - progress * 0.5
    case .ended, .cancelled:
        if translation > 150 {
            dismiss(animated: true)
        } else {
            UIView.animate(withDuration: 0.3) {
                self.view.transform = .identity
                self.view.alpha = 1
            }
        }
    default: break
    }
}
```

Тянем view вниз. Если оттащили дальше 150pt — dismiss. Иначе —
возврат с пружиной.

Для `UISheetPresentationController` это работает **из коробки** (см.
28.1).

## 29.9 Edge swipe (back gesture)

`UINavigationController` имеет встроенный `interactivePopGestureRecognizer`.
Чтобы кастомизировать:

```swift
override func viewDidLoad() {
    super.viewDidLoad()
    navigationController?.interactivePopGestureRecognizer?.delegate = self
}

extension MyVC: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gesture: UIGestureRecognizer) -> Bool {
        // Запрещаем swipe-back для root VC
        navigationController?.viewControllers.count ?? 0 > 1
    }
}
```

Чаще — **восстановить** swipe-back, который сломался при кастомном
`leftBarButtonItem`:

```swift
navigationController?.interactivePopGestureRecognizer?.delegate = nil
```

## 29.10 Конфликт gesture'ов

Когда **на одном view** несколько recognizer'ов:

```swift
extension MyVC: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gesture: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        return true  // оба работают одновременно
    }
}

pan.delegate = self
swipe.delegate = self
```

По умолчанию срабатывает **один** (тот, что увидел первым событие).
С `simultaneouslyWith: true` — оба обрабатывают.

Полезно для **pan внутри scroll view** — обычно scroll view
«поглощает» pan. С разрешением одновременного — можно делать кастомные
жесты.

## 29.11 Гesture inside UITableView

Tap по cell — обрабатывается `didSelectRowAt`. Если хочешь **tap
по конкретному элементу внутри cell** (например, аватарке):

```swift
// В cellForRowAt или внутри cell:
let tap = UITapGestureRecognizer(target: self, action: #selector(avatarTapped(_:)))
avatarView.addGestureRecognizer(tap)
avatarView.isUserInteractionEnabled = true
```

Tap по avatarView **не** будет триггерить cell-selection — gesture
поглощает событие.

Можно через `accessoryView` и `accessoryButtonTappedForRowWith` —
если accessory это `.detailDisclosureButton`.

## 29.12 Бытовая аналогия

Recognizer'ы — это **сенсоры в комнате**. Каждый ловит свой тип
движения: touch (тап), хлопок (long-press), штора (swipe), две руки
(pinch). Каждое движение запускает соответствующий обработчик.

Когда несколько сенсоров в одном месте — нужно либо ставить
приоритет (`require(toFail:)`), либо разрешить одновременную работу
(`simultaneouslyWith`).

## 📋 Что мы выучили

- **`UIContextMenuInteraction`** — long-press с меню и превью.
  Для table/collection — `contextMenuConfigurationFor...`.
- **Swipe actions** — `UISwipeActionsConfiguration` с `UIContextualAction`.
  Trailing для destructive, leading для toggle. `done(true)`
  обязательно.
- **Pinch to zoom** — `UIScrollView` + `viewForZooming` делегат.
- **Pan** — `gesture.translation(in:)` + `gesture.state` для
  drag. `dragStart` сохраняется в `.began`.
- **Tap** — `isUserInteractionEnabled = true` для `UIImageView` и
  `UILabel`.
- **Double-tap conflict** — `singleTap.require(toFail: doubleTap)`.
- **Pan-to-dismiss** — `transform.translationY`, alpha
  пропорциональна. Threshold 150pt для dismiss.
- **Edge swipe back** — `interactivePopGestureRecognizer`. Восстановить
  через `delegate = nil` при кастомном `leftBarButtonItem`.
- **Конфликт recognizer'ов** — `simultaneouslyWith: true` через
  delegate.

→ [Глава 30. Cookbook: формы и валидация](./47-cookbook-forms.md)
