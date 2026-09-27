# Глава 23. Cookbook — загрузка

С этой главы начинается Часть IV — **UI Cookbook**. Это справочник. Каждый
рецепт устроен одинаково: когда применять / минимальный код / частые ошибки /
альтернативы. Читать подряд не нужно — открывай, когда нужен конкретный
паттерн.

В этой главе — паттерны вокруг **загрузки**: как показать пользователю, что
приложение не зависло, а работает. Правило за всеми рецептами одно: любое
ожидание дольше доли секунды должно быть **видно**. Экран, который молча
ждёт сеть, выглядит сломанным.

> **Режим компиляции.** Все листинги главы проверены компилятором в режиме
> книги: Swift 6, Default Actor Isolation = MainActor, deployment target
> iOS 15.0. Рецепты с `async/await` дополнительно проверены в языковом режиме
> Swift 5 (с тем же MainActor по умолчанию) — они собираются и там. Для
> компиляции нужны маленькие заглушки `Item`, `API.fetch(page:)` и
> `ImageCache` — в своём проекте на их месте твой сетевой слой (см. главу 15).

## 23.1 Pull-to-refresh

**Pull-to-refresh** («потяни, чтобы обновить») — список тянут пальцем вниз
дальше начала, появляется крутящийся индикатор, данные перезагружаются.

**Когда применять.** Любой список или лента, где пользователь ожидает свежие
данные «по требованию»: почта, новости, заказы. Системный контрол для этого,
`UIRefreshControl`, есть в UIKit с iOS 6.

**Минимальный код.** Экран-лента (заготовка ниже продолжится в 23.2):

```swift
final class FeedViewController: UITableViewController {
    private var items: [Item] = []
    private var nextPage = 1
    private var isLoadingPage = false
    private var hasMore = true

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")

        let refresh = UIRefreshControl()
        refresh.attributedTitle = NSAttributedString(string: "Обновляем…")
        refresh.addAction(UIAction { [weak self] _ in
            Task {
                await self?.reload()
                self?.refreshControl?.endRefreshing()
            }
        }, for: .valueChanged)
        refreshControl = refresh

        loadMore()
    }

    private func reload() async {
        do {
            let fresh = try await API.fetch(page: 1)
            items = fresh
            nextPage = 2
            hasMore = fresh.count == API.pageSize
            tableView.reloadData()
        } catch {
            // Старые данные не трогаем — только сообщаем.
            showToast("Не удалось обновить")
        }
    }
}
```

`refreshControl = refresh` — у `UITableViewController` есть готовое свойство;
у любого `UIScrollView` (а значит, и у `UITableView`, `UICollectionView`) —
тоже, `scrollView.refreshControl` (iOS 10+). До iOS 10 контрол приходилось
вставлять в иерархию view руками.

`.valueChanged` — событие «пользователь дотянул, пора обновлять». Контрол к
этому моменту уже крутится сам.

`Task { ... }` — запускаем асинхронную работу из синхронного обработчика.
Экран живёт на главном потоке (main actor), и `Task`, созданный отсюда,
**наследует** главный поток: код после `await` снова выполняется на нём.
Поэтому `tableView.reloadData()` и `endRefreshing()` можно звать без
`DispatchQueue.main.async`.

`[weak self]` в `UIAction` — контрол живёт внутри экрана, замыкание — внутри
контрола. Без `weak` получился бы круг ссылок, и экран никогда бы не
освободился.

`endRefreshing()` стоит **после** `await`, то есть вызывается и при успехе, и
при ошибке: `reload()` ловит ошибку внутри себя и не бросает её наружу.

При ошибке список **не очищаем**: пользователь видел данные минуту назад,
пусть видит их и дальше, плюс короткое сообщение (toast, см. 23.6).

**Частые ошибки.**

- **Забыли `endRefreshing()`** — индикатор крутится вечно. Если функция
  загрузки может бросить ошибку, ставь вызов в `defer { }` внутри `Task`:
  `defer` выполняется при любом выходе из блока.
- **Очистили список при ошибке.** Был список — стал пустой экран с ошибкой.
  Хуже, чем ничего не делать.
- **Свои `contentInset` и прокрутка.** Если экран сам управляет
  `contentInset.top` (как stretchy header в главе 21), индикатор появится
  в «неправильном» месте — над отступом. Проверь такой экран руками.

**Альтернативы.**

- **Кнопка «Обновить» в навигационной панели** — для редко меняющихся данных
  и для экранов без прокрутки.
- **Автообновление при возврате в приложение** — подписка на
  `UIScene.didActivateNotification` (сцена снова активна) и перезагрузка.
  Удобно для лент.

## 23.2 Infinite scroll (пагинация)

**Пагинация** — загрузка данных порциями («страницами») по 20–50 штук.
**Infinite scroll** («бесконечная прокрутка») — очередная страница грузится
сама, когда пользователь долистал почти до конца.

**Когда применять.** Длинные ленты, где данных больше, чем разумно грузить
разом: соцсети, каталог магазина, история заказов.

**Минимальный код.** Продолжение `FeedViewController`:

```swift
override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    items.count
}

override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
    var content = cell.defaultContentConfiguration()
    content.text = items[indexPath.row].title
    cell.contentConfiguration = content
    return cell
}

override func tableView(_ tableView: UITableView,
                        willDisplay cell: UITableViewCell,
                        forRowAt indexPath: IndexPath) {
    if indexPath.row >= items.count - 6 {
        loadMore()
    }
}

private func loadMore() {
    guard hasMore, !isLoadingPage else { return }
    isLoadingPage = true
    Task {
        defer { isLoadingPage = false }
        do {
            let new = try await API.fetch(page: nextPage)
            let start = items.count
            items.append(contentsOf: new)
            nextPage += 1
            hasMore = new.count == API.pageSize        // неполная страница = последняя
            let paths = (start..<items.count).map { IndexPath(row: $0, section: 0) }
            tableView.performBatchUpdates {
                tableView.insertRows(at: paths, with: .automatic)
            }
        } catch {
            // Сеть упала — hasMore не трогаем: новый скролл попробует снова.
        }
    }
}
```

`willDisplay` — делегат сообщает «эта ячейка сейчас появится на экране».
Условие `row >= items.count - 6` — «показываем одну из последних шести».
Числами: загружено 20 строк (номера 0–19), триггер сработает на строке 14.
Пока пользователь долистает оставшиеся пять-шесть строк, новая страница
успеет прийти. Число 6 подбирается: на быстрой сети хватит 3, на медленной и
с короткими ячейками — лучше 10.

Три переменные состояния:

- `nextPage` — номер страницы для очередного запроса.
- `isLoadingPage` — «запрос уже в пути». `willDisplay` вызывается для каждой
  появляющейся ячейки, и без флага за одну прокрутку ушло бы пять одинаковых
  запросов.
- `hasMore` — «есть ли смысл просить ещё».

`defer { isLoadingPage = false }` — флаг сбросится при любом исходе: успех,
ошибка, ранний выход.

`hasMore = new.count == API.pageSize` — если сервер отдаёт по 20 штук, а
пришло 13, это последняя страница, и ещё один запрос за пустым массивом не
нужен. Если твоё API явно возвращает `hasNext` или общее количество —
используй его, это надёжнее.

`performBatchUpdates { insertRows }` — добавляем только новые строки, а не
перерисовываем всю таблицу. `reloadData()` здесь тоже бы сработал:
позицию прокрутки он **не** сбрасывает (мы проверили: `contentOffset` до и
после `reloadData()` одинаковый). Но `reloadData()` пересоздаёт все видимые
ячейки без анимации, и при ячейках с оценочной высотой лента может
«дёрнуться» на несколько точек. `insertRows` дешевле и спокойнее.

**Частые ошибки.**

- **Нет флага «уже грузим»** — дубли в ленте: две одинаковые страницы
  приехали одновременно.
- **Триггер на последней строке** (`count - 1`) — пользователь упирается в
  конец списка и ждёт. Запас в несколько строк убирает паузу.
- **При ошибке `hasMore = false`** — лента «кончилась» из-за одного сбоя сети.
  Ошибку показываем (например, строкой-футером «Не удалось загрузить.
  Повторить»), а `hasMore` не трогаем.
- **Смешали `reload` и `loadMore`.** Если пользователь потянул обновление,
  пока грузилась страница 5, ответ страницы 5 допишется к свежему списку
  после страницы 1. Надёжное решение — хранить `Task` загрузки и отменять его
  (`task.cancel()`) при обновлении.

**Альтернативы.**

- **Индикатор-футер** — `tableView.tableFooterView` со спиннером на время
  загрузки страницы; для `UICollectionView` — supplementary view типа footer
  (так сделано в галерее, глава 16).
- **Кнопка «Показать ещё»** — если автоматическая подгрузка раздражает или
  API медленное и дорогое.

**Упражнение 23.1.** В `API.fetch(page:)` верни 13 элементов на третьей
странице вместо 20. Сколько всего запросов уйдёт за полную прокрутку ленты?
А если убрать проверку `new.count == API.pageSize` и оставить только
«пустой ответ = конец»? Ответ — в конце главы.

## 23.3 Skeleton-плейсхолдер

**Skeleton** («скелет») — серые прямоугольники на месте будущего текста и
картинок, пока данные грузятся. Часто по ним пробегает светлый блик —
**shimmer** («мерцание»). **Placeholder** («заполнитель») — общее слово для
всего, что стоит на месте ещё не пришедшего контента.

**Когда применять.** Первое открытие экрана, пока данных нет. Скелет заранее
показывает форму будущего экрана, и появление контента воспринимается как
«проявление», а не как прыжок из пустоты.

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
            UIColor.white.withAlphaComponent(0).cgColor,
            UIColor.white.withAlphaComponent(0.35).cgColor,
            UIColor.white.withAlphaComponent(0).cgColor,
        ]
        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 0.5)
        gradient.locations = [-1, -0.5, 0]          // блик пока левее видимой области
        layer.addSublayer(gradient)
    }

    required init?(coder: NSCoder) { fatalError("Создаём только из кода") }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)        // без неявной анимации размера
        gradient.frame = bounds
        CATransaction.commit()
    }

    // Окно появилось (или вернулись в это окно) — запускаем заново.
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { startAnimating() }
    }

    func startAnimating() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }   // «Уменьшить движение»
        let animation = CABasicAnimation(keyPath: "locations")
        animation.fromValue = [-1, -0.5, 0]
        animation.toValue = [1, 1.5, 2]
        animation.duration = 1.2
        animation.repeatCount = .infinity
        gradient.add(animation, forKey: "shimmer")
    }

    func stopAnimating() {
        gradient.removeAnimation(forKey: "shimmer")
    }
}
```

Фон — серый прямоугольник: `tertiaryLabel` с прозрачностью 15%. Системный
цвет подстраивается под тёмную тему.

Блик — **градиент** из трёх цветов: прозрачный → белый на 35% → прозрачный.
`startPoint (0; 0,5)` и `endPoint (1; 0,5)` — градиент идёт слева направо по
средней линии. Координаты тут не в точках, а в долях слоя: 0 — левый край,
1 — правый.

`locations` — где вдоль этой линии стоят три цвета, тоже в долях ширины.
`[-1, -0.5, 0]`: прозрачный на −1 (на целую ширину левее слоя), яркая середина
блика на −0,5, снова прозрачный ровно на левом краю. Весь блик левее видимой
области, прямоугольник просто серый.

Анимация двигает эти три числа к `[1, 1.5, 2]`: середина блика проходит путь
от −0,5 до 1,5, то есть пересекает прямоугольник целиком (от 0 до 1) и уходит
вправо. Путь — 2 ширины за 1,2 секунды, из них видимая часть — половина
времени, 0,6 секунды. Потом `repeatCount = .infinity` запускает всё заново.

Почему анимируем `locations`, а не сдвиг слоя? Напрашивается двигать
`transform.translation.x` от `-bounds.width` до `bounds.width`. Но если
`startAnimating()` вызвать до раскладки — а так почти всегда и делают, сразу
после создания, — `bounds.width` равна нулю, анимация едет «от 0 до 0», и
блика нет. Доли ширины от размера не зависят: одна и та же анимация работает
на прямоугольнике любой ширины и даже переживает поворот экрана.

`layoutSubviews` + `CATransaction.setDisableActions(true)` — `CALayer` не
участвует в Auto Layout, поэтому размер отдельного слоя обновляем руками при
каждой раскладке. А у отдельного (не «своего» для view) слоя любое изменение
`frame` по умолчанию **неявно анимируется** за 0,25 секунды: блик бы
«догонял» растущий прямоугольник. Транзакция с выключенными действиями
отключает эту анимацию. (Проверили в симуляторе: без неё у слоя после
изменения размера появляются анимации `position` и `bounds`.)

`didMoveToWindow` — когда view снят с экрана (ячейку переиспользовали, экран
закрыли), Core Animation удаляет его анимации. Перезапуск при появлении в
окне возвращает блик.

`UIAccessibility.isReduceMotionEnabled` — у пользователя включено
«Настройки → Универсальный доступ → Движение → Уменьшение движения». Людям с
вестибулярными нарушениями бегущие блики мешают; для них оставляем
неподвижный серый скелет.

Анимация выполняется в Core Animation: главный поток только передаёт ей
параметры, дальше кадры считаются отдельно. Поэтому сотня бликов не мешает
прокрутке.

В ячейке таблицы скелет — это несколько `SkeletonView` на местах будущих
картинки и строк текста. Пример — в главе 15 (Weather).

**Частые ошибки.**

- **Скелет не похож на экран.** Серые полоски должны стоять там, где будут
  заголовок, подзаголовок и картинка. Скелет «вообще» (три одинаковые
  полосы на любом экране) ничего не сообщает.
- **Текст «Загрузка…» внутри скелета.** Скелет — это форма без содержания;
  надпись делает его похожим на настоящий, но сломанный контент.
- **Слишком много скелетов.** 3–6 строк на экран достаточно. Две сотни
  одинаковых серых ячеек выглядят как зависание.
- **Скелет висит вечно при ошибке.** Если загрузка упала, скелет меняем на
  экран ошибки (глава 24), а не оставляем мерцать.

**Альтернативы.**

- **Спиннер по центру** — проще; хорош для коротких загрузок (меньше
  секунды) и экранов без чёткой формы.
- **Кеш сначала** — сразу показываем сохранённые в прошлый раз данные, а
  свежие подменяют их, когда придут. Лучше любого скелета, если кеш есть.

## 23.4 Spinner внутри кнопки

**Spinner** («спиннер») — крутящийся индикатор активности,
`UIActivityIndicatorView`.

**Когда применять.** Кнопка, после нажатия которой идёт запрос: «Войти»,
«Сохранить», «Отправить».

**Минимальный код.**

```swift
final class LoginViewController: UIViewController {
    private let loginButton = UIButton(configuration: .filled())

    override func viewDidLoad() {
        super.viewDidLoad()
        loginButton.configuration?.title = "Войти"
        loginButton.addAction(UIAction { [weak self] _ in
            self?.login()
        }, for: .touchUpInside)
    }

    private func login() {
        startLoading()
        Task {
            defer { stopLoading() }
            try? await Task.sleep(nanoseconds: 1_000_000_000)   // вместо настоящего запроса
        }
    }

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
}
```

`UIButton.Configuration` (iOS 15+) — описание внешнего вида кнопки одним
значением: стиль, заголовок, картинка, отступы.
`showsActivityIndicator = true` — встроенный спиннер. По документации он
показывается **на месте картинки** кнопки (слева от заголовка, если
`imagePlacement` не менял).

`configuration` — это структура, значение, а не ссылка. Поэтому шаблон
«скопировал → поменял → записал обратно»: `var cfg = loginButton.configuration`,
правки, `loginButton.configuration = cfg`. Кнопка перерисуется при записи.

`view.endEditing(true)` — убираем клавиатуру: пользователь нажал «Войти»,
вводить больше нечего.

`isEnabled = false` — вторая половина рецепта, не менее важная, чем спиннер:
пока идёт запрос, повторный тап невозможен.

`defer { stopLoading() }` в `Task` — кнопка вернётся в обычное состояние при
любом исходе: успех, ошибка, отмена.

**Частые ошибки.**

- **Спиннер без блокировки.** Пользователь тапает пять раз — уходит пять
  запросов входа.
- **Кнопку не вернули после ошибки.** Кнопка навсегда «Входим…» и серая.
  Лечится `defer`.
- **Спиннер без текста.** Если убрать заголовок, кнопка сожмётся до размера
  спиннера, и вся раскладка вокруг «прыгнет». Меняй текст на «Входим…», а не
  убирай его.

**Альтернативы.**

- **Полноэкранный overlay** (23.7) — для долгих операций, когда трогать экран
  во время ожидания нельзя.
- **Оптимистичное действие** — показываем результат сразу («сообщение
  отправлено»), а при ошибке откатываем. Так работают мессенджеры.

## 23.5 Progressive image loading

**Когда применять.** Картинки из сети в списке или сетке. Пока картинка
грузится — нейтральная заливка; пришла — плавно проявляется (**fade-in**,
«проявление» от прозрачного к видимому).

**Минимальный код.** Самый частый случай — ячейка коллекции:

```swift
final class PhotoCell: UICollectionViewCell {
    private let imageView = UIImageView()
    private var loadTask: Task<Void, Never>?

    override init(frame: CGRect) {
        super.init(frame: frame)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = .secondarySystemFill      // заглушка, пока грузим
        imageView.frame = contentView.bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        contentView.addSubview(imageView)
    }

    required init?(coder: NSCoder) { fatalError("Создаём только из кода") }

    func configure(with url: URL) {
        loadTask?.cancel()
        imageView.image = nil
        imageView.alpha = 0
        loadTask = Task { [weak self] in
            let image = await ImageCache.shared.image(for: url)
            guard !Task.isCancelled, let self else { return }   // ячейку уже отдали другому URL
            self.imageView.image = image
            UIView.animate(withDuration: 0.25) { self.imageView.alpha = 1 }
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        loadTask?.cancel()
        loadTask = nil
        imageView.image = nil
    }
}
```

Главная опасность здесь — **переиспользование ячеек**. Таблица и коллекция не
создают ячейку на каждую строку: ушедшая за край экрана ячейка
переиспользуется для новой строки. Сценарий бага: ячейка начала грузить фото
A, пользователь пролистал, та же ячейка теперь показывает строку с фото B.
Если A придёт позже B, оно перезапишет правильную картинку — в ленте
«чужие» фото.

Защита — хранить задачу загрузки и отменять её:

- в `configure(with:)` перед новой загрузкой отменяем старую;
- в `prepareForReuse()` (UIKit зовёт его прямо перед переиспользованием) —
  тоже отменяем и чистим картинку;
- после `await` проверяем `Task.isCancelled`: отменённая задача не имеет
  права трогать ячейку.

`imageView.alpha = 0` + `UIView.animate(withDuration: 0.25) { alpha = 1 }` —
картинка проявляется за четверть секунды поверх серой заливки
`secondarySystemFill`.

`Task { [weak self] in ... }` создан внутри класса ячейки, а весь код книги
живёт на главном потоке (MainActor по умолчанию) — задача **наследует**
главный поток. Поэтому после `await` можно сразу менять `imageView`, без
`await MainActor.run { }` — здесь это лишняя обёртка, которая только
запутывает.

`[weak self]` — ячейку могут выбросить из памяти, пока картинка грузится;
держать её сильной ссылкой ради картинки, которую никто не увидит, незачем.

`ImageCache` — кеш картинок из главы 16 (Gallery): сначала память, потом сеть.

**Частые ошибки.**

- **Нет отмены / проверки при переиспользовании** — «чужие» картинки в
  ячейках при быстрой прокрутке.
- **Не обнулили картинку.** Пока грузится новая, в ячейке видна старая
  картинка от прошлой строки.
- **Картинка на весь экран в ячейке 80×80.** Декодированная фотография
  4000×3000 занимает около 48 МБ памяти (4000 × 3000 точек × 4 байта на
  пиксель). Для миниатюр проси у сервера маленькую версию или уменьшай
  картинку перед показом (`UIImage.preparingThumbnail(of:)`, iOS 15+).

**Альтернативы.**

- **BlurHash** — сервер вместе со ссылкой отдаёт строку в 20–30 символов,
  из которой мгновенно рисуется размытое «пятно» с цветами будущей
  фотографии. Нужна сторонняя библиотека декодирования.
- **Сначала маленькая, потом большая** — показываем миниатюру, поверх неё
  проявляется полная версия. Два запроса вместо одного.

**Упражнение 23.2.** Убери из `PhotoCell` строку
`guard !Task.isCancelled, let self else { return }`, заменив на
`guard let self else { return }`, и сделай так, чтобы `ImageCache` отвечал
случайно от 0,1 до 2 секунд. Что увидишь при быстрой прокрутке сетки?
Ответ — в конце главы.

## 23.6 Toast / Snackbar

**Toast** («тост») или **snackbar** — короткое сообщение внизу экрана, которое
само появляется и само исчезает через пару секунд: «Сохранено», «Нет сети».
В UIKit готового компонента нет, делаем сами.

**Когда применять.** Подтверждение завершённого действия или некритичная
ошибка, на которую пользователю не нужно отвечать.

**Минимальный код.**

```swift
extension UIViewController {
    func showToast(_ text: String) {
        let label = PaddedLabel()
        label.text = text
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        label.textAlignment = .center
        label.textColor = .white
        label.backgroundColor = UIColor.black.withAlphaComponent(0.85)
        label.layer.cornerRadius = 18
        label.layer.masksToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -32),
            label.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: 100),
        ])
        UIAccessibility.post(notification: .announcement, argument: text)   // VoiceOver прочитает

        UIView.animate(withDuration: 0.35) {
            label.transform = CGAffineTransform(translationX: 0, y: -120)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            UIView.animate(withDuration: 0.35, animations: {
                label.transform = .identity
                label.alpha = 0
            }, completion: { _ in
                label.removeFromSuperview()
            })
        }
    }
}

final class PaddedLabel: UILabel {
    private let inset = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: inset))
    }

    // Размер = размер текста в «урезанной» рамке + отступы обратно.
    override func textRect(forBounds bounds: CGRect, limitedToNumberOfLines numberOfLines: Int) -> CGRect {
        let inner = super.textRect(forBounds: bounds.inset(by: inset), limitedToNumberOfLines: numberOfLines)
        return inner.inset(by: UIEdgeInsets(top: -inset.top, left: -inset.left,
                                            bottom: -inset.bottom, right: -inset.right))
    }
}
```

Сначала геометрия, на числах. Низ плашки привязан на **100 точек ниже**
нижней границы safe area — то есть плашка стартует за нижним краем видимой
области. Затем `CGAffineTransform(translationX: 0, y: -120)` — сдвиг на
120 точек вверх. Итог: 100 − 120 = −20, плашка встаёт на 20 точек **выше**
safe area. `transform` — это визуальный сдвиг поверх Auto Layout: constraints
не меняются, view просто рисуется в другом месте.

Исчезновение — `transform = .identity` («без сдвига») и `alpha = 0`
одновременно: плашка уезжает вниз и тает за 0,35 секунды. Затем
`removeFromSuperview()` в `completion` — иначе прозрачные плашки копились бы
в иерархии.

Время на экране: 0,35 с въезд, потом `asyncAfter(1.6)` отсчитывает
1,6 секунды от начала, то есть плашка стоит неподвижно около 1,25 секунды,
затем 0,35 с уезжает. Короткое «Сохранено» так прочитать успевают. Для
текста длиннее пяти-шести слов увеличь паузу.

`widthAnchor ≤ ширина экрана − 32` + `numberOfLines = 0` — длинный текст
переносится на несколько строк и оставляет по 16 точек с краёв, а не уезжает
за экран.

`PaddedLabel` — `UILabel` с внутренними отступами 10 сверху и снизу, 16 слева
и справа. `drawText(in:)` рисует текст в рамке, уменьшенной на отступы.
`textRect(forBounds:limitedToNumberOfLines:)` — метод, которым UILabel считает
свой размер: берём размер текста в урезанной ширине и «наращиваем» отступы
обратно (отрицательные inset'ы расширяют прямоугольник). Первая версия
рецепта переопределяла `intrinsicContentSize` — это работает для одной
строки, но многострочный текст считался бы по полной ширине и обрезался.

`layer.masksToBounds = true` — без него `cornerRadius` скруглил бы только
«рамку» слоя, а фон label остался бы прямоугольным.

`UIAccessibility.post(notification: .announcement, argument: text)` —
VoiceOver прочитает сообщение вслух. Иначе незрячий пользователь toast не
узнает: он не получает фокус.

Касания: у `UILabel` по умолчанию `isUserInteractionEnabled == false`
(проверили в симуляторе), поэтому тап по плашке **проходит сквозь** неё к
тому, что под ней. Если нужна кнопка «Отменить» внутри toast'а — делай
плашку из `UIView` с кнопкой внутри.

**Частые ошибки.**

- **Очередь сообщений.** Три toast'а подряд лягут друг на друга. Если
  сообщения могут идти пачкой — держи очередь и показывай по одному.
- **Toast для важного.** «Платёж не прошёл» не должен исчезать сам через
  две секунды. Для этого — алерт или экран ошибки.
- **Забыли про VoiceOver** — сообщение видят все, кроме тех, кто не видит.

**Альтернативы.**

- **`UIAlertController`** — для важного: требует явного «OK», прерывает
  работу.
- **Баннер сверху поверх всего приложения** (как системное уведомление) —
  отдельное `UIWindow` с `windowLevel = .alert`, в которое кладётся плашка.
  Так баннер переживает смену экранов.

## 23.7 Loading overlay (полноэкранный)

**Overlay** — полупрозрачный слой поверх экрана, который блокирует касания.

**Когда применять.** Операция, во время которой пользователю нельзя ничего
трогать: оплата, экспорт файла, долгая синхронизация.

**Минимальный код.**

```swift
extension UIViewController {
    @discardableResult
    func showOverlay(text: String) -> UIView {
        let overlay = UIView(frame: view.bounds)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]   // растёт при повороте
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        overlay.alpha = 0
        overlay.accessibilityViewIsModal = true

        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = .white
        spinner.startAnimating()

        let label = UILabel()
        label.text = text
        label.textColor = .white
        label.font = .preferredFont(forTextStyle: .headline)
        label.adjustsFontForContentSizeCategory = true

        let stack = UIStackView(arrangedSubviews: [spinner, label])
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
        ])

        view.addSubview(overlay)
        UIView.animate(withDuration: 0.2) { overlay.alpha = 1 }
        return overlay
    }

    func hideOverlay(_ overlay: UIView) {
        UIView.animate(withDuration: 0.2, animations: {
            overlay.alpha = 0
        }, completion: { _ in
            overlay.removeFromSuperview()
        })
    }
}
```

Чёрный с прозрачностью 50% затемняет экран наполовину: видно, что экран на
месте, но «занят». Большой белый спиннер и подпись по центру.

`UIView(frame: view.bounds)` + `autoresizingMask = [.flexibleWidth,
.flexibleHeight]` — overlay создан рамкой, а не constraints, поэтому ему
нужна «маска авторесайза»: растягиваться вслед за родителем. Без маски при
повороте экрана overlay остался бы старого размера, и половина экрана
оказалась бы не закрыта (и доступна для тапов).

`UIView` по умолчанию принимает касания — поэтому overlay их и «съедает»:
тап по затемнению не доходит до кнопок под ним.

`accessibilityViewIsModal = true` — VoiceOver не будет читать элементы под
затемнением.

Функция возвращает overlay, чтобы потом снять именно его через
`hideOverlay(_:)`. `@discardableResult` — не ругаться, если результат не
используют.

Показ и скрытие — 0,2 секунды на прозрачность: плавно, но без задержки.

Ограничение: overlay лежит внутри `view` текущего экрана. Если экран внутри
`UINavigationController`, навигационная панель **не** закрыта — кнопка
«Назад» останется нажимаемой. Если это недопустимо, клади overlay в
`navigationController?.view` или в окно (`view.window`).

**Частые ошибки.**

- **Спиннер без подписи.** «Крутится — а что происходит?» Подпись
  «Готовим отчёт…» снимает вопрос.
- **Нет отмены.** Если операция может длиться минуту, дай кнопку «Отмена».
- **Overlay на каждую мелочь.** Блокировать экран ради запроса в 300 мс —
  мигание. Для коротких операций хватит спиннера в кнопке (23.4).

**Альтернативы.**

- **Прогресс-бар** (`UIProgressView`) — если известна доля выполнения:
  «Загружено 45%» честнее бесконечного спиннера.
- **Фоновая работа + уведомление** — для операций на минуты: пользователь
  уходит, приложение сообщает по готовности.

**Упражнение 23.3.** Вызови `showOverlay(text: "Готовим отчёт…")` на экране
внутри `UINavigationController` и попробуй нажать «Назад». Потом поменяй
`view.addSubview(overlay)` на добавление в окно. Что изменится? И что будет
с overlay при повороте симулятора, если убрать `autoresizingMask`? Ответ —
в конце главы.

## Ответы к упражнениям

**Упражнение 23.1.** Страницы 1 и 2 приходят полными (по 20), третья — 13
элементов: `13 == 20` ложно, `hasMore` становится `false`. Итого **3 запроса**.
Если оставить только «пустой ответ = конец», после страницы 3 уйдёт
**четвёртый** запрос, вернёт пустой массив, и только тогда лента поймёт, что
всё. Лишний запрос на каждую полную прокрутку каждого пользователя.

**Упражнение 23.2.** При быстрой прокрутке в ячейках сначала появляются
правильные фото, а через долю секунды некоторые меняются на «чужие» — от
строк, которые эта ячейка показывала раньше. Медленный ответ старого запроса
пришёл после быстрого нового и перезаписал картинку. Вернёшь проверку
`Task.isCancelled` — эффект пропадёт.

**Упражнение 23.3.** В первом варианте кнопка «Назад» в навигационной панели
остаётся доступной: overlay закрывает только область экрана под панелью.
Вариант с окном:

```swift
func showWindowOverlay(text: String) -> UIView? {
    guard let window = view.window else { return nil }
    let overlay = UIView(frame: window.bounds)
    overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    overlay.backgroundColor = UIColor.black.withAlphaComponent(0.5)
    window.addSubview(overlay)
    return overlay
}
```

— закрывает и панель, «Назад» не нажимается. Без `autoresizingMask` после
поворота в альбомную ориентацию overlay остаётся портретного размера
(393 точки в ширину на iPhone 16), правая часть экрана открыта и нажимается.

## Что мы выучили

- **Pull-to-refresh** — `UIRefreshControl` в `refreshControl`, `endRefreshing()`
  при любом исходе, старые данные при ошибке не трогаем.
- **Пагинация** — триггер в `willDisplay` за N строк до конца, флаг
  «уже грузим», конец ленты по неполной странице, `insertRows` вместо
  `reloadData()`.
- **Skeleton** — серый фон + градиент-блик; анимируем `locations` (доли
  ширины), а не сдвиг в точках; без неявной анимации размера; перезапуск в
  `didMoveToWindow`; уважаем «Уменьшение движения».
- **Спиннер в кнопке** — `UIButton.Configuration.showsActivityIndicator`
  (iOS 15+) + `isEnabled = false` + `defer`.
- **Картинки в ячейках** — отмена `Task` в `prepareForReuse`, проверка
  `Task.isCancelled` после `await`, fade-in за 0,25 с.
- **Toast** — плашка за нижним краем + `transform` вверх; VoiceOver-объявление;
  `UILabel` пропускает касания сквозь себя.
- **Overlay** — `autoresizingMask`, блокировка касаний, модальность для
  VoiceOver; навигационную панель закрывает только overlay на окне.

## Apple Developer Documentation

- [`UIRefreshControl`](https://developer.apple.com/documentation/uikit/uirefreshcontrol) — стандартный контрол pull-to-refresh.
- [`UIScrollView.refreshControl`](https://developer.apple.com/documentation/uikit/uiscrollview/refreshcontrol) — слот для `UIRefreshControl` (iOS 10+) у любого scroll view.
- [`tableView(_:willDisplay:forRowAt:)`](https://developer.apple.com/documentation/uikit/uitableviewdelegate/tableview(_:willdisplay:forrowat:)) — точка триггера пагинации.
- [`performBatchUpdates(_:completion:)`](https://developer.apple.com/documentation/uikit/uitableview/performbatchupdates(_:completion:)) — вставка новых строк без полной перезагрузки.
- [`UIActivityIndicatorView`](https://developer.apple.com/documentation/uikit/uiactivityindicatorview) — системный спиннер.
- [`UIButton.Configuration.showsActivityIndicator`](https://developer.apple.com/documentation/uikit/uibutton/configuration-swift.struct/showsactivityindicator) — спиннер внутри кнопки (iOS 15+).
- [`CAGradientLayer`](https://developer.apple.com/documentation/quartzcore/cagradientlayer) и [`CABasicAnimation`](https://developer.apple.com/documentation/quartzcore/cabasicanimation) — основа блика для скелета.
- [`UIAccessibility.isReduceMotionEnabled`](https://developer.apple.com/documentation/uikit/uiaccessibility/isreducemotionenabled) — настройка «Уменьшение движения».
- [`prepareForReuse()`](https://developer.apple.com/documentation/uikit/uicollectionreusableview/prepareforreuse()) — сброс ячейки перед переиспользованием.
- [`URLSession.data(from:)`](https://developer.apple.com/documentation/foundation/urlsession/data(from:delegate:)) — загрузка данных через async/await (iOS 15+).
- [HIG — Loading](https://developer.apple.com/design/human-interface-guidelines/loading) — рекомендации Apple по показу загрузки.

→ [Глава 24. Cookbook — empty / error / offline states](./41-cookbook-empty-error.md)
