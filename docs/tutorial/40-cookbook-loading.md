# Глава 23. Cookbook — загрузка

С этой главы начинается Часть IV — **UI Cookbook**. Это справочник.
Каждый рецепт: когда применять / минимальный код / частые ошибки /
альтернативы. Не нужно читать подряд — открывай главу когда нужен
конкретный паттерн.

В этой главе — паттерны вокруг **загрузки**: показать пользователю,
что что-то происходит.

## 23.1 Pull-to-refresh

**Когда применять.** Любой список/feed, который пользователь
ожидает обновлять «потянув вниз». Стандарт iOS с iOS 6.

**Минимальный код.**

```swift
private let refreshControl = UIRefreshControl()

override func viewDidLoad() {
    super.viewDidLoad()
    tableView.refreshControl = refreshControl
    refreshControl.attributedTitle = NSAttributedString(string: "Обновляем…")
    refreshControl.addAction(UIAction { [weak self] _ in
        Task {
            await self?.reload()
            self?.refreshControl.endRefreshing()
        }
    }, for: .valueChanged)
}
```

`tableView.refreshControl` (iOS 10+) — встроенная поддержка. До этого
надо было руками добавлять в `subviews` scrollView.

Для `UICollectionView` — то же самое: `collectionView.refreshControl`.
Для голого `UIScrollView` — `scrollView.refreshControl`.

**Частые ошибки.**

- **Забыли `endRefreshing()`** — индикатор крутится вечно. Гарантируй
  вызов в `defer` или `Task { ... }` с `defer`.
- **Возврат к старым данным после fail'а.** Если refresh упал —
  оставь старые данные, не очищай список. Покажи toast «не удалось
  обновить» (см. 23.6).
- **Конфликт с `contentOffset`-логикой.** Если ты вручную меняешь
  scroll position (например, для stretchy header'а), pull-to-refresh
  может ломаться. Проверь, что `contentInset.top` учтён.

**Альтернативы.**

- **Кнопка «обновить» в navbar** — для редко обновляемых данных,
  чтобы пользователь явно решал.
- **Auto-refresh при возврате с фона** — `UIScene.didActivateNotification`
  trigger'ит reload. Удобно для feed'ов соцсетей.

## 23.2 Infinite scroll (пагинация)

**Когда применять.** Бесконечная лента (Instagram, Twitter, Reddit) —
данных много, грузим порциями.

**Минимальный код.**

```swift
private var items: [Item] = []
private var nextPage = 1
private var isLoadingPage = false
private var hasMore = true

func tableView(_ tableView: UITableView,
               willDisplay cell: UITableViewCell,
               forRowAt indexPath: IndexPath) {
    if indexPath.row >= items.count - 6 {
        loadMore()
    }
}

private func loadMore() {
    guard hasMore, !isLoadingPage else { return }
    isLoadingPage = true
    Task { [weak self] in
        guard let self else { return }
        do {
            let new = try await API.fetch(page: nextPage)
            self.items.append(contentsOf: new)
            self.nextPage += 1
            if new.isEmpty { self.hasMore = false }
            self.tableView.reloadData()
        } catch { /* show error */ }
        self.isLoadingPage = false
    }
}
```

Триггер на `willDisplay` за **6 строк до конца**. Точное число
подбирается под скорость сети.

Три флага:
- `hasMore` — `false` когда сервер вернул пустой массив.
- `isLoadingPage` — защита от двойной загрузки.
- `nextPage` — следующая страница.

**Частые ошибки.**

- **Двойной триггер.** Без `isLoadingPage` две страницы могут
  загрузиться одновременно — дубликаты в списке.
- **Сравнение по `count - 1`.** Тогда триггер срабатывает только при
  самой последней ячейке, юзер уже видит конец. 6 ячеек — нормальный
  запас.
- **`reloadData()` сбрасывает scroll position.** Используй
  `performBatchUpdates { insertRows(...) }` для плавного добавления.

**Альтернативы.**

- **Footer-loader** внутри tableView — `UICollectionReusableView`
  типа footer показывает спиннер во время загрузки (см. Главу 16,
  Gallery).
- **Manual «Load more» кнопка** — для медленных API, где автоматика
  раздражает.

## 23.3 Skeleton-плейсхолдер

**Когда применять.** Сразу после открытия экрана, до того как данные
загружены. Лучше пустого экрана.

**Минимальный код.**

```swift
final class SkeletonView: UIView {
    private let gradient = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = 8
        clipsToBounds = true
        backgroundColor = UIColor.tertiaryLabel.withAlphaComponent(0.15)
        gradient.colors = [
            UIColor.tertiaryLabel.withAlphaComponent(0.0).cgColor,
            UIColor.tertiaryLabel.withAlphaComponent(0.45).cgColor,
            UIColor.tertiaryLabel.withAlphaComponent(0.0).cgColor,
        ]
        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 0.5)
        layer.addSublayer(gradient)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds
    }

    func startAnimating() {
        let animation = CABasicAnimation(keyPath: "transform.translation.x")
        animation.fromValue = -bounds.width
        animation.toValue = bounds.width
        animation.duration = 1.2
        animation.repeatCount = .infinity
        gradient.add(animation, forKey: "shimmer")
    }
}
```

Принцип: серый фон + светлый shimmer-градиент, который бесконечно
движется слева направо. Анимация на CALayer — GPU, не тормозит.

В ячейках таблицы — отдельный `SkeletonCell`, который рисует
несколько `SkeletonView`'ов в местах будущих текста/картинки. См.
Главу 15 (Weather) для конкретного примера.

**Частые ошибки.**

- **Не вызвали `startAnimating()`** — серый прямоугольник без
  движения смотрится как баг.
- **Skeleton выглядит точь-в-точь как реальный контент.**
  Skeleton должен быть **очевидно** placeholder'ом. Серые
  прямоугольники, не текст «Loading...».
- **Слишком много skeleton-ячеек.** 3-5 штук на экране — нормально.
  10+ — выглядит как реальная сетка, путает.

**Альтернативы.**

- **Spinner посередине** — проще, но скучнее. Подходит для коротких
  загрузок (< 1 сек).
- **Progressive disclosure** — показываем кешированные данные сразу,
  обновляем когда придут свежие.

## 23.4 Spinner внутри кнопки

**Когда применять.** Action-кнопка, после нажатия которой идёт запрос
(login, save, send).

**Минимальный код.**

```swift
private func startLoading() {
    view.endEditing(true)
    loginButton.isEnabled = false
    var cfg = loginButton.configuration
    cfg?.showsActivityIndicator = true
    cfg?.title = "Входим…"
    loginButton.configuration = cfg
}

private func stopLoading() {
    var cfg = loginButton.configuration
    cfg?.showsActivityIndicator = false
    cfg?.title = "Войти"
    loginButton.configuration = cfg
    loginButton.isEnabled = true
}
```

`UIButton.Configuration.showsActivityIndicator = true` (iOS 15+) —
встроенный спиннер. Замещает иконку, появляется рядом с заголовком.

Меняем title на «Входим…» — даём понять, что что-то происходит.
`isEnabled = false` — защита от двойного нажатия.

**Частые ошибки.**

- **Спиннер без disabled-state.** Юзер тапает 5 раз — 5 запросов.
- **Не убрали спиннер в случае ошибки.** Кнопка остаётся залипшей.
  Поставь `stopLoading()` в `defer`.
- **Текст пропал.** Если не задаёшь `title` при `showsActivityIndicator
  = true` — Apple сама уменьшает кнопку. Лучше явный текст.

**Альтернативы.**

- **Скрыть кнопку, показать overlay** — для долгих операций (5+ сек).
- **Snackbar «отправляется»** — если действие не блокирует
  пользователя и он может продолжать работать.

## 23.5 Progressive image loading

**Когда применять.** Большие картинки. Сначала тёмная заглушка,
потом картинка появляется с fade-in.

**Минимальный код.**

```swift
extension UIImageView {
    func loadAsync(from url: URL) {
        self.image = nil
        self.alpha = 0
        Task { [weak self] in
            let image = await ImageCache.shared.image(for: url)
            await MainActor.run {
                self?.image = image
                UIView.animate(withDuration: 0.25) {
                    self?.alpha = 1.0
                }
            }
        }
    }
}
```

При установке нового URL — обнуляем image и alpha. После загрузки —
ставим image и fade-in за 250ms.

Для cell-reuse — `currentURL` check, как в Главе 16 (Gallery).

**Частые ошибки.**

- **Race condition при reuse.** Ячейка показала фото А, начала грузить
  B. Грузится медленно. Юзер скроллит обратно, ячейка теперь
  показывает A снова. Загрузка B заканчивается → перетирает A.
  Проверяй `currentURL == url` перед установкой.
- **Fade-in без обнуления.** Старая картинка остаётся видимой пока
  новая грузится. Сначала `image = nil`, потом загружай.

**Альтернативы.**

- **Blurhash placeholder** — компактная (~30 байт) preview, отдаётся с
  сервера. Декодируется мгновенно, фоновый цвет ≈ фотография.
- **Low-res → high-res** — сначала маленькая 100×100, потом полная.
  Требует двух запросов.

## 23.6 Toast / Snackbar

**Когда применять.** Краткое сообщение о завершении действия
(«Сохранено», «Ошибка сети»). Появляется и исчезает само через 1.5-2
секунды.

**Минимальный код.**

```swift
func showToast(_ text: String) {
    let label = PaddedLabel()
    label.text = text
    label.font = .systemFont(ofSize: 14, weight: .medium)
    label.textColor = .white
    label.backgroundColor = UIColor.black.withAlphaComponent(0.85)
    label.layer.cornerRadius = 18
    label.layer.masksToBounds = true
    label.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(label)
    NSLayoutConstraint.activate([
        label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        label.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: 100),
    ])
    UIView.animate(withDuration: 0.35) {
        label.transform = CGAffineTransform(translationX: 0, y: -120)
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
        UIView.animate(withDuration: 0.35, animations: {
            label.transform = .identity
            label.alpha = 0
        }) { _ in label.removeFromSuperview() }
    }
}

private final class PaddedLabel: UILabel {
    private let inset = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
    override func drawText(in rect: CGRect) { super.drawText(in: rect.inset(by: inset)) }
    override var intrinsicContentSize: CGSize {
        let s = super.intrinsicContentSize
        return CGSize(width: s.width + inset.left + inset.right, height: s.height + inset.top + inset.bottom)
    }
}
```

Принцип: label с padding'ом, появляется снизу через `transform`,
исчезает обратно. Никаких сторонних SDK не надо.

Для длинного текста / нескольких строк — `numberOfLines = 0` и
`widthAnchor.lessThanOrEqual`.

**Частые ошибки.**

- **Очередь toast'ов.** Юзер быстро триггерит несколько toast'ов —
  они накладываются друг на друга. Если важно — сделай queue с
  обработкой по одному.
- **Tap внутри toast'а.** По умолчанию toast блокирует тапы под
  собой (потому что он subview). Если действие — например, undo —
  оставь user interaction enabled и обработай тап.

**Альтернативы.**

- **`UIAlertController`** — для важных сообщений с явным «OK».
  Прерывает поток.
- **In-app notification (баннер сверху)** — для уведомлений типа
  «новое сообщение». Можно сделать через `UIWindow.overlay`.

## 23.7 Loading overlay (полноэкранный)

**Когда применять.** Длинная операция (3+ сек), которая блокирует
весь экран (генерация PDF, экспорт, синхронизация).

**Минимальный код.**

```swift
func showOverlay() {
    let overlay = UIView(frame: view.bounds)
    overlay.backgroundColor = UIColor.black.withAlphaComponent(0.5)
    overlay.alpha = 0
    let spinner = UIActivityIndicatorView(style: .large)
    spinner.color = .white
    spinner.startAnimating()
    spinner.translatesAutoresizingMaskIntoConstraints = false
    overlay.addSubview(spinner)
    NSLayoutConstraint.activate([
        spinner.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
        spinner.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
    ])
    view.addSubview(overlay)
    UIView.animate(withDuration: 0.2) { overlay.alpha = 1 }
}
```

Полупрозрачный чёрный поверх всего + большой спиннер по центру.
`alpha = 0 → 1` для плавности.

Снимается обратной анимацией → `removeFromSuperview`.

**Частые ошибки.**

- **Спиннер без надписи.** Юзер видит крутящийся круг, не понимает
  что происходит. Добавь label «Готовим отчёт…».
- **Overlay не отменяемый.** При долгой операции пользователь должен
  иметь возможность отменить (кнопка «Отмена» в overlay'е).

**Альтернативы.**

- **Прогресс-бар** — если знаешь процент выполнения. Точнее, чем
  спиннер.
- **Push notification по завершении** — для **очень** долгих операций
  (минуты). Юзер уходит из приложения, возвращается на пуш.

## 📋 Что мы выучили

- **Pull-to-refresh** через `UIRefreshControl` на tableView. Не
  забыть `endRefreshing()`.
- **Infinite scroll** через `willDisplay` + 3 флага (`hasMore`,
  `isLoadingPage`, `nextPage`).
- **Skeleton** — серый прямоугольник + `CAGradientLayer` + shimmer
  через `CABasicAnimation(transform.translation.x)`.
- **Спиннер в кнопке** — `UIButton.Configuration.showsActivityIndicator
  = true` (iOS 15+).
- **Progressive image loading** с fade-in и `currentURL` check
  против race condition при reuse.
- **Toast** — label поверх view, появляется через `transform`,
  исчезает по таймеру.
- **Loading overlay** — полупрозрачный чёрный + спиннер для долгих
  blocking-операций.

## Apple Developer Documentation

- [`UIRefreshControl`](https://developer.apple.com/documentation/uikit/uirefreshcontrol) — стандартный контрол pull-to-refresh.
- [`UIScrollView.refreshControl`](https://developer.apple.com/documentation/uikit/uiscrollview/2127691-refreshcontrol) — слот для `UIRefreshControl` (iOS 10+); работает в `UITableView`, `UICollectionView`, голом `UIScrollView`.
- [`UIScrollViewDelegate.scrollViewDidScroll(_:)`](https://developer.apple.com/documentation/uikit/uiscrollviewdelegate/1619392-scrollviewdidscroll) — обработчик скролла; используется для infinite scroll и shrinking-header.
- [`UITableViewDelegate.tableView(_:willDisplay:forRowAt:)`](https://developer.apple.com/documentation/uikit/uitableviewdelegate/1614883-tableview) — точка триггера пагинации за N ячеек до конца.
- [`UIActivityIndicatorView`](https://developer.apple.com/documentation/uikit/uiactivityindicatorview) — встроенный спиннер для overlay'ев.
- [`UIButton.Configuration.showsActivityIndicator`](https://developer.apple.com/documentation/uikit/uibutton/configuration/3784627-showsactivityindicator) — спиннер внутри кнопки (iOS 15+).
- [`CAGradientLayer`](https://developer.apple.com/documentation/quartzcore/cagradientlayer) и [`CABasicAnimation`](https://developer.apple.com/documentation/quartzcore/cabasicanimation) — основа shimmer-анимации для skeleton'ов.
- [`URLSession.dataTask(with:)`](https://developer.apple.com/documentation/foundation/urlsession/1411554-datatask) — асинхронная загрузка изображений; в современном коде используется `data(from:)` с async/await.
- [HIG — Loading](https://developer.apple.com/design/human-interface-guidelines/loading) — рекомендации Apple по показу прогресса и пустых состояний во время загрузки.

→ [Глава 24. Cookbook: empty/error states + offline](./41-cookbook-empty-error.md)
