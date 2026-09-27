# Глава 37. Cookbook — photo viewer

**Photo viewer** (просмотрщик фото) — полноэкранный экран, куда
попадаешь по тапу на миниатюру: фото на чёрном фоне, приближение двумя
пальцами, двойной тап, листание соседних фото, «смахни вниз, чтобы
закрыть», кнопки «Поделиться» и «Сохранить».

В главе 16 (Галерея) у нас уже был простой просмотр одного фото с
зумом. Здесь собираем полную версию из трёх классов:

- `PhotoViewerViewController` — одна страница: одно фото, зум, жесты;
- `PhotoPagerViewController` — листание страниц, панель с кнопками,
  счётчик «1 из 3»;
- `PhotoZoomTransition` — «вырастание» миниатюры в полноэкранное фото.

Весь код главы собран в настоящий проект (минимум iOS 15, Swift 6,
изоляция `MainActor` по умолчанию) и запущен на симуляторе iPhone 16
с iOS 26.5; числа в разборах — из этого прогона. Загрузку картинок
делает `ImageCache` из главы 16.3 — в этом проекте лежит его копия.

```
┌──────────────────────────┐
│ X       1 из 3     ↓  ↑  │ ← панель: закрыть, счётчик, сохранить, поделиться
│██████████████████████████│
│                          │
│ ┌──────────────────────┐ │
│ │        фото          │ │ ← UIScrollView: pinch, double-tap
│ └──────────────────────┘ │
│                          │ ← смахнуть вниз → закрыть
│    ← листать →           │ ← UIPageViewController
└──────────────────────────┘
```

## 37.1 Одна страница: фото с зумом

Основа — **`UIScrollView`**. Это не только «прокручиваемая область»:
у него встроено масштабирование. Представь лист бумаги (`imageView`)
под лупой (`scrollView`): scroll view может увеличивать лист и двигать
его под лупой.

```swift
import UIKit
import Photos

final class PhotoViewerViewController: UIViewController {
    let imageURL: URL
    let scrollView = UIScrollView()
    let imageView = UIImageView()
    private let spinner = UIActivityIndicatorView(style: .large)
    private let doubleTap = UITapGestureRecognizer()
    private let pan = UIPanGestureRecognizer()
    var onSingleTap: (() -> Void)?

    init(imageURL: URL) {
        self.imageURL = imageURL
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) не используется")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        scrollView.frame = view.bounds
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 4.0
        scrollView.delegate = self
        view.addSubview(scrollView)

        imageView.contentMode = .scaleAspectFit
        scrollView.addSubview(imageView)

        spinner.color = .white
        spinner.center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        spinner.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin,
                                    .flexibleTopMargin, .flexibleBottomMargin]
        view.addSubview(spinner)

        setupGestures()
        loadImage()
    }
```

Разбор:

- `imageURL` не `private`: пейджер (37.6) по нему узнаёт, какое фото
  на странице.
- `required init?(coder:)` обязателен: как только у контроллера свой
  `init`, компилятор требует и этот (он нужен для Storyboard); без
  него код не соберётся.
- `autoresizingMask = [.flexibleWidth, .flexibleHeight]` — scroll view
  растягивается вместе с экраном (например, при повороте). Для такого
  простого случая это короче констрейнтов.
- `contentInsetAdjustmentBehavior = .never` — не сдвигать содержимое
  под **safe area** (зону экрана без «чёлки» и полоски жестов внизу):
  фото мы центрируем сами.
- `minimumZoomScale = 1.0`, `maximumZoomScale = 4.0` — от «фото
  целиком» до «в 4 раза крупнее».
- Спиннер держится по центру: гибкие отступы со всех сторон.

Загрузка и раскладка:

```swift
    private func loadImage() {
        spinner.startAnimating()
        Task {
            let image = await ImageCache.shared.image(for: imageURL)
            spinner.stopAnimating()
            imageView.image = image
            layoutImage()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if scrollView.zoomScale == scrollView.minimumZoomScale {
            layoutImage()
        }
    }

    private func layoutImage() {
        guard let size = imageView.image?.size, size.width > 0, size.height > 0 else { return }
        let bounds = scrollView.bounds.size
        let scale = min(bounds.width / size.width, bounds.height / size.height)
        let fitted = CGSize(width: size.width * scale, height: size.height * scale)
        imageView.frame = CGRect(origin: .zero, size: fitted)
        scrollView.contentSize = fitted
        centerImage()
    }

    private func centerImage() {
        let bounds = scrollView.bounds.size
        let content = scrollView.contentSize
        let dx = max(0, (bounds.width - content.width) / 2)
        let dy = max(0, (bounds.height - content.height) / 2)
        scrollView.contentInset = UIEdgeInsets(top: dy, left: dx, bottom: dy, right: dx)
    }

    override func viewWillTransition(to size: CGSize,
                                     with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        scrollView.setZoomScale(scrollView.minimumZoomScale, animated: false)
    }
}

extension PhotoViewerViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerImage()
    }
}
```

`Task { ... }` в контроллере наследует главный актор, поэтому после
`await` можно сразу трогать `imageView` — без `MainActor.run`.

**`layoutImage()` на числах.** Фото 1200 × 800 пикселей, экран
iPhone 16 — 393 × 852 точки. Во сколько раз уменьшить, чтобы фото
влезло целиком? По ширине 393 / 1200 ≈ 0,33, по высоте 852 / 800 ≈
1,07. Берём **меньшее** (`min`), иначе фото вылезет по ширине: 0,33.
Получается 393 × 262 точки — то, что показал прогон на симуляторе
(`imageFrame: 393.0 × 262.0`). Соотношение сторон сохранилось: 1200 /
800 = 1,5 и 393 / 262 = 1,5.

`contentSize` — размер «листа» внутри scroll view. Мы делаем
`imageView` ровно по размеру вписанного фото, а не на весь экран. Если
`imageView` займёт весь экран с `.scaleAspectFit`, при зуме можно
уехать в чёрные поля над и под фото — лупа приблизит вместе с фото
пустоту вокруг.

**`centerImage()` на числах.** Лист 262 точки в высоту, экран 852.
Остаётся 852 − 262 = 590 точек пустоты, по 295 сверху и снизу.
`contentInset` — отступ вокруг листа внутри scroll view: с ним фото
стоит ровно посередине (в прогоне: `inset top: 295, bottom: 295`).
При зуме ×2,5 лист становится 262 × 2,5 = 655 точек, пустоты
остаётся (852 − 655) / 2 = 98,5 — и прогон показал `98.5`. Поэтому
центрирование вызывается в `scrollViewDidZoom`: при каждом изменении
масштаба. Когда фото больше экрана, `max(0, …)` обнуляет отступ, и
фото прокручивается от края до края.

`viewForZooming(in:)` — метод делегата, который отвечает: «какой view
увеличивать». Без него pinch-жест ничего не делает. **Делегат** — объект,
которому scroll view задаёт вопросы и сообщает о событиях; здесь это
наш контроллер.

`viewWillTransition` — экран поворачивается. Сбрасываем зум, и в
`viewDidLayoutSubviews` фото впишется заново под новые размеры.

## 37.2 Двойной тап — приблизить к точке

```swift
extension PhotoViewerViewController: UIGestureRecognizerDelegate {
    private func setupGestures() {
        doubleTap.addTarget(self, action: #selector(doubleTapped(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)

        let singleTap = UITapGestureRecognizer(target: self, action: #selector(singleTapped))
        singleTap.require(toFail: doubleTap)
        scrollView.addGestureRecognizer(singleTap)

        pan.addTarget(self, action: #selector(handlePan(_:)))
        pan.delegate = self
        view.addGestureRecognizer(pan)
    }

    @objc private func singleTapped() {
        onSingleTap?()
    }

    @objc private func doubleTapped(_ sender: UITapGestureRecognizer) {
        if scrollView.zoomScale > scrollView.minimumZoomScale {
            scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
        } else {
            let point = sender.location(in: imageView)
            let targetScale: CGFloat = 2.5
            let size = CGSize(width: scrollView.bounds.width / targetScale,
                              height: scrollView.bounds.height / targetScale)
            let rect = CGRect(x: point.x - size.width / 2,
                              y: point.y - size.height / 2,
                              width: size.width, height: size.height)
            scrollView.zoom(to: rect, animated: true)
        }
    }
```

Если фото уже приближено — возвращаем к целому. Если нет — приближаем
**к точке тапа**: человек дважды тапнул по лицу на фото — он хочет
видеть лицо, а не центр кадра.

Как `zoom(to:)` превращается в масштаб. Метод говорит scroll view:
«сделай так, чтобы этот прямоугольник занял весь экран».
Прямоугольник шириной 393 / 2,5 ≈ 157 точек растягивается на 393
точки — это и есть увеличение в 2,5 раза. Прогон подтвердил:
`zoomScale after zoom(to:) = 2.5`. Хочешь сильнее — уменьши
прямоугольник: при `targetScale = 3` он станет 131 точку.

`sender.location(in: imageView)` — точка тапа в координатах самой
картинки, потому что `zoom(to:)` ждёт прямоугольник в координатах
увеличиваемого view.

Одиночный тап (прячет панели, 37.9) ждёт, пока двойной «провалится»:
`singleTap.require(toFail: doubleTap)`. Без этого первый же тап
двойного нажатия прятал бы панель. Цена — одиночный тап срабатывает
с небольшой задержкой: система ждёт, не будет ли второго.

## 37.3 Смахнуть вниз, чтобы закрыть

```swift
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === pan else { return true }
        guard scrollView.zoomScale <= scrollView.minimumZoomScale + 0.01 else { return false }
        let velocity = pan.velocity(in: view)
        return velocity.y > abs(velocity.x)
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        let dismissDistance: CGFloat = 150
        switch gesture.state {
        case .changed:
            let down = max(translation.y, 0)
            let scale = max(1 - down / 1000, 0.85)
            scrollView.transform = CGAffineTransform(translationX: translation.x, y: translation.y)
                .scaledBy(x: scale, y: scale)
            view.backgroundColor = UIColor.black.withAlphaComponent(max(0, 1 - down / 400))
        case .ended, .cancelled:
            let velocity = gesture.velocity(in: view).y
            if gesture.state == .ended && (translation.y > dismissDistance || velocity > 1000) {
                dismiss(animated: true)
            } else {
                UIView.animate(withDuration: 0.3, delay: 0,
                               usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
                    self.scrollView.transform = .identity
                    self.view.backgroundColor = .black
                }
            }
        default:
            break
        }
    }
}
```

**Когда жест вообще начинать** (`gestureRecognizerShouldBegin`, метод
делегата распознавателя):

- только при исходном масштабе — если фото приближено, движение пальца
  должно двигать фото, а не закрывать экран;
- только если палец идёт **больше вниз, чем вбок**: `velocity.y >
  |velocity.x|`. Иначе горизонтальное листание (37.6) и закрытие
  спорили бы за один и тот же жест. Скорость — в точках в секунду:
  палец идёт вниз со скоростью 400 и вбок 100 — закрываем, вбок 600 —
  отдаём жест листанию.

**Что происходит, пока тянешь** (`.changed`), на числах:

- `translation` — насколько сдвинулся палец от начала жеста. Фото едет
  вместе с пальцем.
- Масштаб `1 - down / 1000`: на каждые 100 точек вниз фото
  уменьшается на 10%, но не меньше 0,85 (85%). Сдвинул на 150 —
  масштаб 0,85: фото на 15% меньше.
- Прозрачность фона `1 - down / 400`: на 100 точках фон на 25%
  прозрачнее, на 150 — осталось 62,5% черноты, на 400 и дальше —
  фон полностью прозрачный.

**Когда отпустил** (`.ended`): закрываем, если утянул дальше 150
точек **или** бросил быстро — быстрее 1000 точек в секунду (это
короткий резкий взмах, даже на 60 точек). Иначе фото пружиной
возвращается на место (damping 0.8 — почти без отскока, см. главу
32.2). Проверка `gesture.state == .ended` не даёт закрыть экран, если
жест прервала система (`.cancelled`, например входящий звонок).

**Три частые ошибки в таком рецепте:**

1. Двигать `imageView.transform`. Но `transform` у `imageView`
   занят самим scroll view: именно через него работает зум. Жест
   ломает масштаб. Двигать нужно весь `scrollView`.
2. Ставить проверку «тянем вниз» в начало обработчика: тогда жест,
   начатый вбок, вообще не сбрасывает состояние. Делегат с
   `gestureRecognizerShouldBegin` решает это до начала жеста.
3. Прозрачный фон бессмыслен, если под экраном ничего не видно. При
   обычном показе на весь экран UIKit **убирает** экран-источник из
   окна после показа. Чтобы при смахивании просвечивала галерея,
   экран показывают со стилем `.overFullScreen` (см. 37.7).

## 37.4 Кнопка «Поделиться»

```swift
    @objc private func shareTapped(_ sender: UIBarButtonItem) {
        guard let image = currentViewer?.imageView.image else { return }
        let activity = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        activity.popoverPresentationController?.barButtonItem = sender
        present(activity, animated: true)
    }
```

`UIActivityViewController` — стандартное системное меню «Поделиться»:
AirDrop, сообщения, мессенджеры, «Сохранить в Файлы». Передаём
картинку, остальное система сделает сама.

`popoverPresentationController?.barButtonItem = sender` — на iPad это
меню показывается **поповером** (всплывающим окошком со стрелкой), и
ему надо знать, к чему прикрепить стрелку. Без этой строки на iPad
приложение падает. На iPhone `popoverPresentationController` — `nil`,
и строка ничего не делает. Этот метод и те, что ниже, живут в
`PhotoPagerViewController` (37.6), у которого есть панель с кнопками.

## 37.5 Сохранить в Фото

```swift
    @objc private func saveTapped() {
        guard let image = currentViewer?.imageView.image else { return }
        Task {
            do {
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }
                showMessage("Сохранено в Фото")
            } catch {
                showMessage("Не удалось сохранить")
            }
        }
    }

    private func showMessage(_ text: String) {
        let alert = UIAlertController(title: nil, message: text, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
```

**PhotoKit** (фреймворк `Photos`) — доступ к медиатеке. `performChanges`
выполняет изменение, `PHAssetChangeRequest.creationRequestForAsset`
— «создай новый снимок из этой картинки». Асинхронная версия
`performChanges` с `try await` есть с iOS 15, поэтому код читается
сверху вниз: получилось — одно сообщение, ошибка — другое.
Возвращаться на главный поток через `DispatchQueue.main.async` не
нужно: `Task` в контроллере выполняется на главном акторе, и после
`await` мы снова на нём.

**Info.plist обязателен.** В Info.plist (файл настроек приложения)
нужен ключ `NSPhotoLibraryAddUsageDescription` с текстом, зачем
приложению доступ, например «Чтобы сохранять понравившиеся фото». При
первом сохранении система покажет запрос с этим текстом. Без ключа
приложение аварийно завершится при первой же попытке. В Xcode этот
ключ называется «Privacy - Photo Library Additions Usage Description».

Есть и старый способ — C-функция `UIImageWriteToSavedPhotosAlbum`:

```swift
UIImageWriteToSavedPhotosAlbum(image, self,
                               #selector(image(_:didFinishSavingWithError:contextInfo:)),
                               nil)

@objc func image(_ image: UIImage, didFinishSavingWithError error: Error?,
                 contextInfo: UnsafeRawPointer) {
    showMessage(error == nil ? "Сохранено в Фото" : "Не удалось сохранить")
}
```

Результат приходит в метод с особой сигнатурой через селектор — это
наследие Objective-C. Ключ в Info.plist нужен тот же. Для нового кода
удобнее `performChanges`.

## 37.6 Листание фото — UIPageViewController

**`UIPageViewController`** — контейнер, который листает экраны
(«страницы») свайпом, как книгу. Каждая страница — отдельный
`PhotoViewerViewController`. Подробно о нём — в главе 6
(Onboarding).

```swift
final class PhotoPagerViewController: UIViewController {
    private let urls: [URL]
    private var currentIndex: Int
    private let pageVC = UIPageViewController(transitionStyle: .scroll,
                                              navigationOrientation: .horizontal,
                                              options: [.interPageSpacing: 16])
    private let counterLabel = UILabel()
    private var isUIHidden = false

    init(urls: [URL], startIndex: Int) {
        self.urls = urls
        self.currentIndex = startIndex
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) не используется")
    }

    var currentViewer: PhotoViewerViewController? {
        pageVC.viewControllers?.first as? PhotoViewerViewController
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
    override var prefersStatusBarHidden: Bool { isUIHidden }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        overrideUserInterfaceStyle = .dark

        addChild(pageVC)
        pageVC.view.frame = view.bounds
        pageVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(pageVC.view)
        pageVC.didMove(toParent: self)
        pageVC.dataSource = self
        pageVC.delegate = self
        pageVC.setViewControllers([makeViewer(at: currentIndex)],
                                  direction: .forward, animated: false)

        setupNavigationBar()
        updateCounter()
        preloadNeighbors()
    }

    private func makeViewer(at index: Int) -> PhotoViewerViewController {
        let viewer = PhotoViewerViewController(imageURL: urls[index])
        viewer.onSingleTap = { [weak self] in self?.toggleUI() }
        return viewer
    }
```

Разбор:

- `.interPageSpacing: 16` — чёрная щель 16 точек между фото при
  листании, как в «Фото».
- `addChild` → `addSubview` → `didMove(toParent:)` — три шага
  встраивания **дочернего контроллера**: сообщаем UIKit, что
  `pageVC` — наш ребёнок, чтобы он получал события жизненного цикла
  (`viewWillAppear` и другие) и повороты.
- `view.backgroundColor = .clear` — фон пейджера прозрачный, чёрный фон
  рисует каждая страница: так при смахивании вниз (37.3) сквозь него
  видна галерея.
- `overrideUserInterfaceStyle = .dark` — тёмная тема для просмотрщика
  независимо от системной (см. главу 35.5).
- `[weak self]` в `onSingleTap`: страницу держит `pageVC`, его —
  пейджер; если бы страница держала пейджер сильно, получился бы цикл.

Источник данных — соседние страницы:

```swift
extension PhotoPagerViewController: UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    func pageViewController(_ pageViewController: UIPageViewController,
                            viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let viewer = viewController as? PhotoViewerViewController,
              let index = urls.firstIndex(of: viewer.imageURL),
              index > 0 else { return nil }
        return makeViewer(at: index - 1)
    }

    func pageViewController(_ pageViewController: UIPageViewController,
                            viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let viewer = viewController as? PhotoViewerViewController,
              let index = urls.firstIndex(of: viewer.imageURL),
              index < urls.count - 1 else { return nil }
        return makeViewer(at: index + 1)
    }

    func pageViewController(_ pageViewController: UIPageViewController,
                            didFinishAnimating finished: Bool,
                            previousViewControllers: [UIViewController],
                            transitionCompleted completed: Bool) {
        guard completed,
              let viewer = currentViewer,
              let index = urls.firstIndex(of: viewer.imageURL) else { return }
        currentIndex = index
        updateCounter()
        preloadNeighbors()
    }
}
```

**Data source** («источник данных») — объект, у которого контейнер
спрашивает: «какая страница перед этой?», «какая после?». `nil` —
«страниц больше нет», дальше не листается.

`didFinishAnimating ... transitionCompleted` — метод **делегата**:
листание закончилось. Проверяем `completed`: пользователь мог начать
листать и передумать, тогда страница не сменилась, и счётчик трогать
нельзя.

`urls.firstIndex(of:)` ищет номер фото по адресу. Если в галерее одно
фото повторяется дважды, номер будет найден неверно; тогда храни
индекс прямо в `PhotoViewerViewController`.

## 37.7 Hero-анимация: миниатюра вырастает в фото

**Hero-анимация** — миниатюра из сетки «перелетает» и вырастает в
полноэкранное фото, а при закрытии улетает обратно в свою ячейку.
Делается через собственный переход: объект-аниматор
(`UIViewControllerAnimatedTransitioning`) и делегат перехода, который
его выдаёт (о протоколах — в главе 26.7).

```swift
final class PhotoZoomTransition: NSObject, UIViewControllerAnimatedTransitioning {
    private let isPresenting: Bool
    private let thumbnail: UIImageView
    private let fullImageView: () -> UIImageView?

    init(isPresenting: Bool, thumbnail: UIImageView, fullImageView: @escaping () -> UIImageView?) {
        self.isPresenting = isPresenting
        self.thumbnail = thumbnail
        self.fullImageView = fullImageView
    }

    func transitionDuration(using ctx: UIViewControllerContextTransitioning?) -> TimeInterval {
        0.35
    }

    func animateTransition(using ctx: UIViewControllerContextTransitioning) {
        let container = ctx.containerView
        let thumbFrame = thumbnail.convert(thumbnail.bounds, to: container)
        let flying = UIImageView(image: thumbnail.image)
        flying.contentMode = .scaleAspectFill
        flying.clipsToBounds = true
        let duration = transitionDuration(using: ctx)

        if isPresenting {
            guard let toVC = ctx.viewController(forKey: .to),
                  let toView = ctx.view(forKey: .to) else {
                ctx.completeTransition(false)
                return
            }
            toView.frame = ctx.finalFrame(for: toVC)
            toView.alpha = 0
            container.addSubview(toView)

            let imageSize = thumbnail.image?.size ?? thumbFrame.size
            let endFrame = Self.aspectFitFrame(for: imageSize, in: container.bounds)
            flying.frame = thumbFrame
            container.addSubview(flying)
            thumbnail.isHidden = true

            UIView.animate(withDuration: duration, delay: 0,
                           usingSpringWithDamping: 0.9, initialSpringVelocity: 0) {
                flying.frame = endFrame
                toView.alpha = 1
            } completion: { _ in
                flying.removeFromSuperview()
                self.thumbnail.isHidden = false
                ctx.completeTransition(!ctx.transitionWasCancelled)
            }
        } else {
            guard let fromView = ctx.view(forKey: .from) else {
                ctx.completeTransition(false)
                return
            }
            let full = fullImageView()
            flying.frame = full.map { $0.convert($0.bounds, to: container) } ?? container.bounds
            container.addSubview(flying)
            full?.isHidden = true
            thumbnail.isHidden = true

            UIView.animate(withDuration: duration, delay: 0,
                           usingSpringWithDamping: 0.9, initialSpringVelocity: 0) {
                flying.frame = thumbFrame
                fromView.alpha = 0
            } completion: { _ in
                flying.removeFromSuperview()
                self.thumbnail.isHidden = false
                full?.isHidden = false
                ctx.completeTransition(!ctx.transitionWasCancelled)
            }
        }
    }

    static func aspectFitFrame(for imageSize: CGSize, in bounds: CGRect) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return bounds }
        let scale = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2,
                      width: size.width, height: size.height)
    }
}
```

Идея: настоящие экраны не двигаются. Вместо них летит **копия
картинки** (`flying`) — временный `UIImageView`, который живёт только
во время анимации.

По шагам для открытия:

1. `containerView` — «сцена» перехода, общий view, в котором на время
   анимации лежат оба экрана.
2. `thumbnail.convert(thumbnail.bounds, to: container)` — где
   миниатюра находится в координатах сцены. У миниатюры свой `frame`
   внутри ячейки (например, x = 20 в ячейке), а нам нужна её позиция
   на всём экране. `convert` пересчитывает.
3. Новый экран кладём на сцену прозрачным (`alpha = 0`).
4. Конечная рамка — фото, вписанное в экран, тем же расчётом, что в
   37.1: для фото 1200 × 800 это 393 × 262 точки по центру.
5. Прячем настоящую миниатюру (иначе на её месте осталась бы копия) и
   анимируем: копия растёт, новый экран проявляется.
6. В конце удаляем копию, возвращаем миниатюру и **обязательно**
   вызываем `completeTransition` — без него UIKit считает переход
   незаконченным, и экран перестаёт реагировать на касания.

Закрытие — то же в обратную сторону: копия берёт рамку текущего
большого фото и улетает в рамку миниатюры. `contentMode =
.scaleAspectFill` у копии — чтобы на финише она совпала с квадратной
обрезанной миниатюрой.

Прогон на симуляторе: открытие и закрытие прошли, после закрытия
экран снят (`dismissed: true`), миниатюра видима (`thumb hidden:
false`).

Делегат, который выдаёт аниматор, и сам показ из галереи:

```swift
final class PhotoZoomTransitioningDelegate: NSObject, UIViewControllerTransitioningDelegate {
    private let thumbnail: UIImageView
    private let fullImageView: () -> UIImageView?

    init(thumbnail: UIImageView, fullImageView: @escaping () -> UIImageView?) {
        self.thumbnail = thumbnail
        self.fullImageView = fullImageView
    }

    func animationController(forPresented presented: UIViewController,
                             presenting: UIViewController,
                             source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        PhotoZoomTransition(isPresenting: true, thumbnail: thumbnail, fullImageView: fullImageView)
    }

    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        PhotoZoomTransition(isPresenting: false, thumbnail: thumbnail, fullImageView: fullImageView)
    }
}

final class PhotoNavigationController: UINavigationController {
    override var childForStatusBarStyle: UIViewController? { topViewController }
    override var childForStatusBarHidden: UIViewController? { topViewController }
}

// В контроллере галереи:
final class GalleryViewController: UIViewController {
    private var urls: [URL] = []
    private var thumbnails: [UIImageView] = []
    private var zoomDelegate: PhotoZoomTransitioningDelegate?

    private func openPhoto(at index: Int) {
        let pager = PhotoPagerViewController(urls: urls, startIndex: index)
        let nav = PhotoNavigationController(rootViewController: pager)
        nav.modalPresentationStyle = .overFullScreen
        nav.modalPresentationCapturesStatusBarAppearance = true
        nav.overrideUserInterfaceStyle = .dark
        let delegate = PhotoZoomTransitioningDelegate(thumbnail: thumbnails[index]) { [weak pager] in
            pager?.currentViewer?.imageView
        }
        zoomDelegate = delegate
        nav.transitioningDelegate = delegate
        present(nav, animated: true)
    }
}
```

Разбор деталей, на которых спотыкаются:

- `zoomDelegate = delegate` — `transitioningDelegate` у контроллера
  хранится **слабой** ссылкой. Если не держать делегата в свойстве, он
  исчезнет сразу после `present`, и закрытие пройдёт без нашей
  анимации.
- `fullImageView` — замыкание, а не готовый view: к моменту закрытия
  пользователь мог перелистать на третье фото, и лететь обратно должно
  то, что на экране сейчас. `[weak pager]` — чтобы делегат, который
  живёт в галерее, не удерживал закрытый просмотрщик.
- `.overFullScreen` — экран-источник остаётся под новым, поэтому
  работает прозрачность при смахивании (37.3).
- `PhotoNavigationController` и `modalPresentationCapturesStatusBarAppearance`
  — чтобы цветом статус-бара (часы, батарея) управлял просмотрщик.
  Обычный `UINavigationController` решает это по своей панели, и в
  прогоне на iOS 26.5 время показывалось чёрным по чёрному. Подкласс
  отдаёт решение верхнему экрану, а тот просит светлый текст.

Хочешь закрытие вслед за пальцем, с возможностью «передумать», —
поверх этого аниматора добавляют `UIPercentDrivenInteractiveTransition`.
А с iOS 18 похожий эффект даёт готовый zoom-переход (глава 32.11), но
для iOS 15–17 нужен код выше.

## 37.8 Панель навигации над фото

```swift
    private func setupNavigationBar() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .black
        appearance.shadowColor = .clear
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navigationItem.standardAppearance = appearance
        navigationItem.scrollEdgeAppearance = appearance

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close, target: self, action: #selector(closeTapped))
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(shareTapped(_:))),
            UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.down"),
                            style: .plain, target: self, action: #selector(saveTapped)),
        ]
        navigationItem.titleView = counterLabel
        counterLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        counterLabel.textColor = .white
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }
```

`UINavigationBarAppearance` (iOS 13+) — описание внешнего вида панели:
фон, тень, цвет заголовка. Задаём его **через `navigationItem`** этого
экрана, а не через `navigationBar` — так настройка действует только
пока этот экран наверху и не «протекает» на другие экраны того же
навигационного стека. `standardAppearance` — обычное состояние,
`scrollEdgeAppearance` — когда контент прокручен к самому верху.
`shadowColor = .clear` убирает тонкую линию под панелью.

**Почему чёрный фон, а не прозрачный.** Классический рецепт —
`configureWithTransparentBackground()`, чтобы фото было видно и под
панелью. Мы проверили его на симуляторе iOS 26.5: при показе
`.overFullScreen` сквозь прозрачную (и даже полупрозрачную) панель
проступала панель **галереи** под просмотрщиком — заголовок «Галерея»
наезжал на «1 из 3». С непрозрачным чёрным фоном картинка чистая. На
фото это почти не влияет: панель чёрная, как и фон вокруг фото, и её
можно спрятать тапом (37.9).

Кнопки системные: `.close` — крестик, `.action` — стандартный значок
«Поделиться», для сохранения — SF Symbol `square.and.arrow.down`.

## 37.9 Спрятать панель тапом

```swift
    private func toggleUI() {
        isUIHidden.toggle()
        navigationController?.setNavigationBarHidden(isUIHidden, animated: true)
        UIView.animate(withDuration: 0.2) {
            self.navigationController?.setNeedsStatusBarAppearanceUpdate()
        }
    }
```

Тап по фото (одиночный, из 37.2) прячет панель и статус-бар — фото
остаётся одно на чёрном. Ещё тап — всё возвращается.

- `setNavigationBarHidden(_:animated:)` — панель уезжает вверх с
  анимацией.
- Статус-бар прячется через `prefersStatusBarHidden`, который мы
  переопределили в пейджере (37.6). Просто поменять `isUIHidden`
  мало: UIKit должен узнать, что ответ изменился, —
  `setNeedsStatusBarAppearanceUpdate()`. Вызов внутри
  `UIView.animate` делает исчезновение плавным.

## 37.10 Счётчик «N из M»

```swift
    private func updateCounter() {
        counterLabel.text = "\(currentIndex + 1) из \(urls.count)"
        counterLabel.sizeToFit()
    }
```

`currentIndex + 1` — номера в массиве идут с нуля, а люди считают с
одного: первое фото — «1 из 3». `sizeToFit()` подгоняет размер подписи
под текст: без него у `titleView` может остаться нулевая ширина. В
прогоне заголовок показал «1 из 3».

Подпись создаётся **один раз** (`counterLabel` — свойство), а
обновляется только текст. Создавать новый `UILabel` при каждом
листании — лишняя работа на каждой странице.

Для небольшого числа фото вместо счётчика можно поставить внизу
`UIPageControl` с точками (глава 36.10), но при 30 фото точки уже не
помещаются — счётчик универсальнее.

## 37.11 Подгрузка соседних фото

```swift
    private func preloadNeighbors() {
        for index in [currentIndex - 1, currentIndex + 1] where urls.indices.contains(index) {
            let url = urls[index]
            Task { _ = await ImageCache.shared.image(for: url) }
        }
    }
}
```

Пока пользователь смотрит фото номер 5, заранее грузим 4 и 6 в кеш.
Когда он перелистнёт, страница возьмёт картинку из кеша мгновенно, без
спиннера. Дальние фото не грузим: при галерее из 500 снимков
загружать всё сразу — лишний трафик и память.

- `urls.indices.contains(index)` — у первого фото нет «предыдущего»
  (индекс −1), у последнего нет «после него». Проверка отсекает
  несуществующие номера без падения.
- `_ = await` — результат нам не нужен, важен сам факт: картинка легла
  в кеш. `ImageCache` (глава 16.3) к тому же склеивает одинаковые
  запросы: если страница попросит то же фото, пока идёт подгрузка,
  второго скачивания не будет.

## 37.12 Что должно быть в хорошем просмотрщике

1. **Чёрный фон** и тёмная тема — фото ничто не перебивает.
2. **Три жеста**: pinch, двойной тап к точке, смахивание вниз для
   закрытия (только при исходном масштабе).
3. **Фото вписано и по центру** — `contentSize` по размеру фото,
   центрирование через `contentInset` при каждом зуме.
4. **Тап прячет интерфейс** — панель и статус-бар.
5. **«Поделиться» и «Сохранить»** — с поповером для iPad и ключом
   `NSPhotoLibraryAddUsageDescription`.
6. **«N из M»**, если фото несколько.
7. **Подгрузка соседних** фото.
8. **Спиннер**, пока фото грузится.
9. **Поворот экрана** — фото вписывается заново.
10. **Доступность**: у кнопок системные подписи уже есть; самому фото
    дай `accessibilityLabel` с описанием, если оно известно (глава
    34.13).

## Упражнения

**Упражнение 37.1.** Сделай порог закрытия не фиксированным (150
точек), а равным 20% высоты экрана. Сколько это точек на iPhone 16
(высота 852 точки) и на iPad с высотой 1024 точки в альбомной
ориентации?

**Упражнение 37.2.** Двойной тап сейчас увеличивает в 2,5 раза. Сделай,
чтобы он приближал **до максимума** (`maximumZoomScale`, то есть в 4
раза). Какого размера будет прямоугольник для `zoom(to:)` на экране
393 × 852?

## Ответы к упражнениям

**37.1.**

```swift
func dismissThreshold(for view: UIView) -> CGFloat {
    view.bounds.height * 0.2
}
```

В `handlePan` вместо `let dismissDistance: CGFloat = 150` пиши
`let dismissDistance = dismissThreshold(for: view)`. На iPhone 16:
852 × 0,2 = 170,4 точки. На iPad в альбомной ориентации: 1024 × 0,2
= 204,8 точки. Порог в процентах ведёт себя одинаково на всех
экранах — на маленьком телефоне не приходится тянуть «через весь
экран».

**37.2.**

```swift
func zoomRect(around point: CGPoint, in scrollView: UIScrollView) -> CGRect {
    let targetScale = scrollView.maximumZoomScale
    let size = CGSize(width: scrollView.bounds.width / targetScale,
                      height: scrollView.bounds.height / targetScale)
    return CGRect(x: point.x - size.width / 2,
                  y: point.y - size.height / 2,
                  width: size.width, height: size.height)
}
```

В `doubleTapped` замени расчёт на
`scrollView.zoom(to: zoomRect(around: point, in: scrollView), animated: true)`.
Прямоугольник: 393 / 4 ≈ 98 точек в ширину и 852 / 4 = 213 в высоту.
Именно он растянется на весь экран — увеличение в 4 раза.

## Что мы выучили

- **`UIScrollView` + `viewForZooming`** — зум из коробки;
  `imageView` по размеру вписанного фото, а не на весь экран.
- **Вписывание**: масштаб — меньшее из двух отношений сторон; 1200 × 800
  на экране 393 × 852 → 393 × 262.
- **Центрирование** через `contentInset` в `scrollViewDidZoom`.
- **Двойной тап** — `zoom(to:)` с прямоугольником «экран / масштаб»
  вокруг точки тапа; одиночный тап ждёт `require(toFail:)`.
- **Смахивание вниз** — двигаем `scrollView`, а не `imageView`; жест
  только при исходном масштабе и вертикальном движении; порог 150
  точек или 1000 точек в секунду.
- **`.overFullScreen`**, чтобы под просмотрщиком была видна галерея.
- **Поделиться** — `UIActivityViewController` с поповером для iPad.
- **Сохранить** — `PHPhotoLibrary.performChanges` (async с iOS 15) и
  ключ `NSPhotoLibraryAddUsageDescription`.
- **`UIPageViewController`** — data source с соседями, счётчик по
  `transitionCompleted`.
- **Hero-переход** — летит копия картинки; делегат перехода держим в
  свойстве; `completeTransition` обязателен.
- **Панель** — через `navigationItem`, на iOS 26.5 — непрозрачная
  чёрная; статус-бар — подкласс навигационного контроллера.
- **Подгрузка соседей** — в кеш, с проверкой границ массива.

## Apple Developer Documentation

- [UIScrollView](https://developer.apple.com/documentation/uikit/uiscrollview) — прокрутка и масштабирование, основа просмотрщика.
- [UIScrollView.zoom(to:animated:)](https://developer.apple.com/documentation/uikit/uiscrollview/zoom(to:animated:)) — приблизить к прямоугольнику.
- [UIScrollViewDelegate.viewForZooming(in:)](https://developer.apple.com/documentation/uikit/uiscrollviewdelegate/viewforzooming(in:)) — какой view масштабировать.
- [UIScrollViewDelegate.scrollViewDidZoom(_:)](https://developer.apple.com/documentation/uikit/uiscrollviewdelegate/scrollviewdidzoom(_:)) — реакция на изменение масштаба (центрирование).
- [UIPanGestureRecognizer](https://developer.apple.com/documentation/uikit/uipangesturerecognizer) — основа закрытия смахиванием.
- [UIGestureRecognizerDelegate.gestureRecognizerShouldBegin(_:)](https://developer.apple.com/documentation/uikit/uigesturerecognizerdelegate/gesturerecognizershouldbegin(_:)) — разрешить или запретить начало жеста.
- [UITapGestureRecognizer](https://developer.apple.com/documentation/uikit/uitapgesturerecognizer) — двойной и одиночный тап; см. `require(toFail:)`.
- [UIPageViewController](https://developer.apple.com/documentation/uikit/uipageviewcontroller) — листание страниц.
- [UIViewControllerTransitioningDelegate](https://developer.apple.com/documentation/uikit/uiviewcontrollertransitioningdelegate) — выдаёт аниматор перехода.
- [UIViewControllerAnimatedTransitioning](https://developer.apple.com/documentation/uikit/uiviewcontrolleranimatedtransitioning) — протокол аниматора.
- [UIPercentDrivenInteractiveTransition](https://developer.apple.com/documentation/uikit/uipercentdriveninteractivetransition) — интерактивный переход вслед за пальцем.
- [UIModalPresentationStyle.overFullScreen](https://developer.apple.com/documentation/uikit/uimodalpresentationstyle/overfullscreen) — показ, при котором экран-источник остаётся под новым.
- [UIActivityViewController](https://developer.apple.com/documentation/uikit/uiactivityviewcontroller) — системное меню «Поделиться».
- [PHPhotoLibrary](https://developer.apple.com/documentation/photos/phphotolibrary) — изменения медиатеки через `performChanges`.
- [NSPhotoLibraryAddUsageDescription](https://developer.apple.com/documentation/bundleresources/information-property-list/nsphotolibraryaddusagedescription) — ключ Info.plist для сохранения в Фото.
- [UIImageWriteToSavedPhotosAlbum(_:_:_:_:)](https://developer.apple.com/documentation/uikit/uiimagewritetosavedphotosalbum(_:_:_:_:)) — старый способ сохранения.
- [UINavigationBarAppearance](https://developer.apple.com/documentation/uikit/uinavigationbarappearance) — внешний вид панели навигации.

---

**Это конец Части IV (UI Cookbook).** Дальше — Часть V, чек-лист перед
релизом: скриншоты, Privacy Manifest, удаление аккаунта, push и
deep links, виджеты и App Intents, аудит доступности. Это не код, а
методичка «что подготовить перед первым релизом».

→ [Глава 38. Production: screenshots для App Store](./60-production-screenshots.md)
