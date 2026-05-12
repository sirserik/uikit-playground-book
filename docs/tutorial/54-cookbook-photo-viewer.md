# Глава 37. Cookbook — photo viewer

Полноэкранный просмотр фото с pinch-zoom, swipe-to-dismiss, share.

## 37.1 Минимальный photo viewer

```swift
final class PhotoViewerViewController: UIViewController {
    private let imageURL: URL
    private let scrollView = UIScrollView()
    private let imageView = UIImageView()

    init(imageURL: URL) {
        self.imageURL = imageURL
        super.init(nibName: nil, bundle: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        overrideUserInterfaceStyle = .dark

        scrollView.frame = view.bounds
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 4.0
        scrollView.delegate = self
        view.addSubview(scrollView)

        imageView.contentMode = .scaleAspectFit
        imageView.frame = scrollView.bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scrollView.addSubview(imageView)

        loadImage()
    }
}

extension PhotoViewerViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }
}
```

`scrollView.delegate.viewForZooming` — даёт pinch-zoom из коробки.

`overrideUserInterfaceStyle = .dark` — даже в light mode чёрный фон,
status bar белый.

## 37.2 Double-tap to zoom

```swift
let doubleTap = UITapGestureRecognizer(target: self, action: #selector(doubleTapped(_:)))
doubleTap.numberOfTapsRequired = 2
scrollView.addGestureRecognizer(doubleTap)

@objc private func doubleTapped(_ sender: UITapGestureRecognizer) {
    if scrollView.zoomScale > 1.0 {
        scrollView.setZoomScale(1.0, animated: true)
    } else {
        let point = sender.location(in: imageView)
        let size = CGSize(width: scrollView.bounds.width / 2.5,
                          height: scrollView.bounds.height / 2.5)
        let rect = CGRect(origin: CGPoint(x: point.x - size.width / 2,
                                          y: point.y - size.height / 2),
                          size: size)
        scrollView.zoom(to: rect, animated: true)
    }
}
```

Если уже зум — обратно. Если нет — приближаем **к точке тапа**.

См. Глава 16 (Gallery).

## 37.3 Pan-to-dismiss

Свайп вниз для закрытия:

```swift
private var isDragging = false
private let dismissThreshold: CGFloat = 150

@objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
    let translation = gesture.translation(in: view)
    guard translation.y > 0 || isDragging else { return }

    switch gesture.state {
    case .began:
        isDragging = true
    case .changed:
        let scale = max(1 - translation.y / 1000, 0.85)
        imageView.transform = CGAffineTransform(translationX: translation.x, y: translation.y)
            .scaledBy(x: scale, y: scale)
        let alpha = 1 - (translation.y / 400)
        view.backgroundColor = UIColor.black.withAlphaComponent(max(0, alpha))
    case .ended, .cancelled:
        isDragging = false
        if translation.y > dismissThreshold {
            dismiss(animated: true)
        } else {
            UIView.animate(withDuration: 0.3) {
                self.imageView.transform = .identity
                self.view.backgroundColor = .black
            }
        }
    default: break
    }
}
```

Тянем вниз — image уменьшается + сдвигается, фон становится прозрачным.
Дотянули >150pt — закрываем. Иначе — return с пружиной.

`.scaledBy` на transform — комбинация translation + scale.

`view.backgroundColor.alpha` — фон постепенно прозрачный, видна
**нижняя** часть (parent VC).

Чтобы pan **не работал** во время zoom:

```swift
extension MyVC: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gesture: UIGestureRecognizer) -> Bool {
        if scrollView.zoomScale > 1.01 { return false }
        return true
    }
}
panGesture.delegate = self
```

## 37.4 Share button

```swift
@objc private func shareTapped() {
    guard let image = imageView.image else { return }
    let activity = UIActivityViewController(activityItems: [image], applicationActivities: nil)
    activity.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItem
    present(activity, animated: true)
}
```

`UIActivityViewController` — стандартный share sheet.
`popoverPresentationController.barButtonItem` для iPad.

## 37.5 Save to Photos

```swift
@objc private func saveTapped() {
    guard let image = imageView.image else { return }
    UIImageWriteToSavedPhotosAlbum(image, self,
                                   #selector(saveComplete(_:didFinishSavingWithError:contextInfo:)),
                                   nil)
}

@objc func saveComplete(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
    if error != nil {
        showError("Не удалось сохранить")
    } else {
        showToast("Сохранено в Фото")
    }
}
```

`UIImageWriteToSavedPhotosAlbum` — старая C-style функция. Apple
обещала async-обёртку, но всё ещё через selector.

`Info.plist`: добавить `NSPhotoLibraryAddUsageDescription` —
обязательно, иначе крах.

Альтернативно через `PHPhotoLibrary.performChanges`:

```swift
PHPhotoLibrary.shared().performChanges {
    PHAssetChangeRequest.creationRequestForAsset(from: image)
} completionHandler: { success, error in
    DispatchQueue.main.async {
        if success {
            self.showToast("Сохранено")
        } else {
            self.showError("Не удалось")
        }
    }
}
```

Более современно, но требует Photos framework + усложнение.

## 37.6 Многостраничный viewer (swipe между фото)

```swift
let pageVC = UIPageViewController(transitionStyle: .scroll,
                                  navigationOrientation: .horizontal)
pageVC.dataSource = self
pageVC.setViewControllers([viewerVC(at: 0)], direction: .forward, animated: false)
```

Каждая страница — отдельный `PhotoViewerViewController`. DataSource
даёт соседние:

```swift
func pageViewController(_ pageVC: UIPageViewController,
                        viewControllerBefore vc: UIViewController) -> UIViewController? {
    guard let viewer = vc as? PhotoViewerViewController,
          let index = images.firstIndex(of: viewer.imageURL),
          index > 0 else { return nil }
    return viewerVC(at: index - 1)
}
```

См. Главу 6 (Onboarding) для деталей UIPageViewController.

## 37.7 Hero animation (thumbnail → full)

При тапе на маленькую миниатюру — она **вырастает** до полноэкранной.
Делается через custom `UIViewControllerTransitioning`.

```swift
class PhotoZoomTransition: NSObject, UIViewControllerAnimatedTransitioning {
    let isPresenting: Bool
    let sourceFrame: CGRect  // позиция thumbnail в parent
    let image: UIImage

    func transitionDuration(...) -> TimeInterval { 0.4 }

    func animateTransition(using ctx: UIViewControllerContextTransitioning) {
        let container = ctx.containerView

        if isPresenting {
            // 1. Создать фейковый imageView в sourceFrame
            // 2. Поставить toView в final position, alpha=0
            // 3. Анимировать фейковый imageView из source в final frame
            // 4. На complete: alpha=1 toView, удалить фейковый
        } else {
            // Обратное: imageView из full в source, dismiss
        }
    }
}
```

Сложный паттерн. Альтернатива — `UIView.transition(...)` с simpler
crossfade.

## 37.8 Прозрачный navigation bar

Чтобы UI не загораживал фото:

```swift
navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
navigationController?.navigationBar.shadowImage = UIImage()
navigationController?.navigationBar.isTranslucent = true
view.backgroundColor = .black
```

Или через `UINavigationBarAppearance`:

```swift
let appearance = UINavigationBarAppearance()
appearance.configureWithTransparentBackground()
navigationController?.navigationBar.standardAppearance = appearance
navigationController?.navigationBar.scrollEdgeAppearance = appearance
```

## 37.9 Hide UI on tap

```swift
private var isUIHidden = false

@objc private func toggleUI() {
    isUIHidden.toggle()
    UIView.animate(withDuration: 0.2) {
        self.navigationController?.setNavigationBarHidden(self.isUIHidden, animated: false)
        self.bottomBar.alpha = self.isUIHidden ? 0 : 1
    }
}

let singleTap = UITapGestureRecognizer(target: self, action: #selector(toggleUI))
view.addGestureRecognizer(singleTap)

// НЕ конфликтовать с double-tap
singleTap.require(toFail: doubleTap)
```

Тап по фото — скрывает navigation / bottom bar. Ещё тап — показывает.
`singleTap.require(toFail: doubleTap)` — single tap ждёт пока double
не провалится.

## 37.10 Indicator «фото N из M»

```swift
private func updateCounter(current: Int, total: Int) {
    let label = UILabel()
    label.text = "\(current + 1) из \(total)"
    label.font = .systemFont(ofSize: 14, weight: .medium)
    label.textColor = .white
    navigationItem.titleView = label
}
```

В nav-баре. Альтернативно — `UIPageControl` (для маленького count) или
swipe-индикатор внизу.

## 37.11 Predicate-based loading

Большие фото грузим **только текущее**, рядом — placeholder'ы:

```swift
// При показе viewer'а
private func loadFullImage(for index: Int) {
    guard let url = images[safe: index] else { return }
    Task { [weak self] in
        let image = await ImageCache.shared.image(for: url)
        await MainActor.run { self?.imageView.image = image }
    }
}

// При смене страницы
func pageViewController(_ pageVC: UIPageViewController, didFinishAnimating ...) {
    if let current = currentVC, let index = images.firstIndex(of: current.imageURL) {
        // Pre-load соседних
        loadFullImage(for: index)
        loadFullImage(for: index + 1)  // запас вперёд
    }
}
```

## 37.12 Photo viewer best practices

1. **Чёрный фон** — стандарт для photo viewer'ов.
2. **`overrideUserInterfaceStyle = .dark`** — status bar белый.
3. **Pinch + double-tap + pan-to-dismiss** — три стандартных жеста.
4. **Hide UI on tap** — даёт полностью смотреть фото.
5. **Share + Save** в bottom bar или nav bar.
6. **"N из M"** counter, если есть несколько фото.
7. **Lazy loading** соседних фото при swipe'е.
8. **Loading indicator** пока фото грузится.

## 📋 Что мы выучили

- **`UIScrollView.viewForZooming`** — pinch-zoom из коробки.
- **Double-tap to zoom** — к точке тапа, не в центр.
- **Pan-to-dismiss** — `transform.translation` + scale + alpha,
  threshold 150pt.
- **Share** через `UIActivityViewController`.
- **Save to Photos** через `UIImageWriteToSavedPhotosAlbum` (Info.plist
  `NSPhotoLibraryAddUsageDescription`).
- **`UIPageViewController`** для swipe между фото.
- **Hero animation** через custom transitioning — сложно, для
  серьёзных проектов.
- **Transparent navbar** через `configureWithTransparentBackground`.
- **Hide UI on tap** — `setNavigationBarHidden`. `singleTap.require
  (toFail: doubleTap)` против conflict.

---

🎉 **Это конец Части IV (UI Cookbook).** Дальше — Часть V, production
checklist: screenshots, Privacy Manifest, account deletion, push +
deep links, widgets + intents, accessibility audit. Это **не код**,
а методичка «что подготовить перед первым релизом».

→ [Глава 38. Production: screenshots для App Store](./60-production-screenshots.md)
