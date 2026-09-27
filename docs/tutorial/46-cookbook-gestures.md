# Глава 29. Cookbook — жесты

Тап, двойной тап, долгое нажатие, свайп, перетаскивание, щипок —
всё это жесты. UIKit распознаёт их сам, тебе остаётся подключить
нужный «распознаватель» и решить, что делать, когда жест случился.
Эта глава — каталог жестов, математика перетаскивания (смещение и
скорость на числах) и главное — что делать, когда два жеста спорят за
одно касание.

> **В каком режиме код.** Листинги проверены компилятором в режиме
> Swift 6 с Default Actor Isolation = MainActor и минимальной версией
> iOS 15 (подробнее — в начале главы 25).

**Распознаватель жестов** (gesture recognizer) — объект, который
смотрит на поток касаний одной view и решает: «это был тап» или «это
перетаскивание». Похоже на датчики в умном доме: один реагирует на
хлопок, другой на движение, третий на открытую дверь. Каждый
распознаватель — подкласс `UIGestureRecognizer`: `UITapGestureRecognizer`,
`UIPanGestureRecognizer` и так далее. Его добавляют к view методом
`addGestureRecognizer(_:)`, а о результате он сообщает через пару
«цель — действие» (`target` + `action`, метод с пометкой `@objc`).

У распознавателя есть **состояние** (`state`). Жесты бывают двух
видов:

- **Дискретные** («разовые») — тап, свайп. Случились один раз и
  всё: распознаватель сразу переходит в `.ended` (оно же
  `.recognized`) и вызывает действие один раз.
- **Непрерывные** — перетаскивание (pan), щипок (pinch), долгое
  нажатие. Действие вызывается много раз: `.began` в начале,
  `.changed` на каждое движение пальца, `.ended` при отпускании. Если
  жест прервала система (например, пришёл звонок), будет `.cancelled`.

Есть ещё `.failed` — «это был не мой жест». Например, распознаватель
двойного тапа переходит в `.failed`, если второго тапа не последовало.

## 29.1 UIContextMenu — long-press с превью

**Когда применять.** Долгое нажатие на элемент показывает меню
действий и увеличенное превью — как на фото в «Фото» или на ссылке в
Safari. **Контекстное меню** — это меню, которое относится к
конкретному элементу, на котором его вызвали.

```swift
final class PhotoViewController: UIViewController, UIContextMenuInteractionDelegate {
    private let photoView = UIImageView()

    override func viewDidLoad() {
        super.viewDidLoad()
        photoView.isUserInteractionEnabled = true
        photoView.addInteraction(UIContextMenuInteraction(delegate: self))
    }

    func contextMenuInteraction(_ interaction: UIContextMenuInteraction,
                                configurationForMenuAtLocation location: CGPoint)
        -> UIContextMenuConfiguration? {
        UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            UIMenu(children: [
                UIAction(title: "В избранное", image: UIImage(systemName: "heart")) { _ in
                    self?.toggleFavorite()
                },
                UIAction(title: "Поделиться", image: UIImage(systemName: "square.and.arrow.up")) { _ in
                    self?.share()
                },
                UIAction(title: "Удалить", image: UIImage(systemName: "trash"),
                         attributes: .destructive) { _ in
                    self?.delete()
                },
            ])
        }
    }

    private func toggleFavorite() {}
    private func share() {}
    private func delete() {}
}
```

`UIContextMenuInteraction` — не распознаватель, а **взаимодействие**
(interaction): готовое поведение целиком — долгое нажатие, лёгкая
отдача вибрацией, размытие фона, превью, меню. Подключается через
`addInteraction`. `isUserInteractionEnabled = true` нужен, потому что
`UIImageView` по умолчанию касания не принимает (29.5).

Делегат отвечает на один вопрос: «какое меню показать в этой точке?».
`location` — точка нажатия, если меню должно зависеть от того, куда
именно нажали. Вернуть `nil` — меню не будет.

- `previewProvider: nil` — превью будет увеличенной копией самой
  view. Если передать замыкание, возвращающее view controller, в
  превью покажется этот экран (например, открытая заметка).
- Третий параметр — замыкание, которое строит меню. Оно получает
  список «предложенных» системой действий (мы его не используем, `_`).
- `attributes: .destructive` — красный пункт.

В таблице и коллекции взаимодействие подключать не нужно — у их
делегатов есть готовый метод:

```swift
override func tableView(_ tableView: UITableView,
                        contextMenuConfigurationForRowAt indexPath: IndexPath,
                        point: CGPoint) -> UIContextMenuConfiguration? {
    let item = items[indexPath.row]
    return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
        UIMenu(children: [
            UIAction(title: "Скопировать", image: UIImage(systemName: "doc.on.doc")) { _ in
                UIPasteboard.general.string = item
            },
            UIAction(title: "Удалить", image: UIImage(systemName: "trash"),
                     attributes: .destructive) { _ in
                self?.remove(item)
            },
        ])
    }
}
```

`let item = items[indexPath.row]` берём **сразу**, а не внутри
пунктов меню. Пока меню открыто, список может измениться (например,
придёт обновление с сервера), и `indexPath` будет указывать уже на
другую строку. Сам элемент — надёжнее.

## 29.2 Swipe actions (table)

**Когда применять.** Действия по свайпу строки: удалить, архивировать,
пометить прочитанным — как в «Почте».

```swift
override func tableView(_ tableView: UITableView,
                        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath)
    -> UISwipeActionsConfiguration? {
    let item = items[indexPath.row]

    let delete = UIContextualAction(style: .destructive, title: "Удалить") { [weak self] _, _, done in
        guard let self, let row = self.items.firstIndex(of: item) else {
            done(false)
            return
        }
        self.items.remove(at: row)
        tableView.deleteRows(at: [IndexPath(row: row, section: 0)], with: .automatic)
        done(true)
    }
    delete.image = UIImage(systemName: "trash")

    let archive = UIContextualAction(style: .normal, title: "Архив") { [weak self] _, _, done in
        self?.archive(item)
        done(true)
    }
    archive.image = UIImage(systemName: "archivebox")
    archive.backgroundColor = .systemOrange

    return UISwipeActionsConfiguration(actions: [delete, archive])
}
```

`trailingSwipeActions...` — кнопки, которые открываются свайпом
**влево**, с правого края строки. `leadingSwipeActions...` — свайпом
вправо, с левого края (обычно «прочитано» или «закрепить»).

Порядок в массиве: **первое** действие стоит **ближе всего к краю**.
У нас `[delete, archive]` — «Удалить» у самого правого края, «Архив»
левее.

Стили:

- `.destructive` — красный фон. Смысл «действие удаляет строку»:
  после `done(true)` таблица ожидает, что строка исчезнет.
- `.normal` — серый фон по умолчанию; цвет можно сменить через
  `backgroundColor`.

**Полный свайп** — если протянуть строку до конца, выполнится
**первое** действие без нажатия на кнопку. Это зависит не от стиля, а
от свойства `performsFirstActionWithFullSwipe` конфигурации (по
умолчанию `true`). Чтобы случайно ничего не удалить, можно поставить
первым безопасное действие или выключить полный свайп.

`done(...)` — обработчик завершения. Вызвать его **обязательно**:
`true` — «действие выполнено», `false` — «не получилось, верни строку
как было». Не вызовешь — строка останется полуоткрытой.

Почему строку ищем заново через `firstIndex(of: item)`: замыкание
выполнится позже, когда человек нажмёт кнопку. За это время список
мог измениться, и старый `indexPath.row` указал бы на чужую строку.
Для `firstIndex(of:)` элементы должны быть `Equatable` — у нас это
строки.

## 29.3 Pinch to zoom

**Когда применять.** Увеличение фото, карты, схемы двумя пальцами.

```swift
final class ZoomViewController: UIViewController, UIScrollViewDelegate {
    private let scrollView = UIScrollView()
    private let imageView = UIImageView()

    override func viewDidLoad() {
        super.viewDidLoad()
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 4.0
        scrollView.bouncesZoom = true
        scrollView.delegate = self
        scrollView.frame = view.bounds
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        imageView.frame = scrollView.bounds
        imageView.contentMode = .scaleAspectFit
        view.addSubview(scrollView)
        scrollView.addSubview(imageView)
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }
}
```

`UIScrollView` умеет масштабирование щипком **сам**. Нужно три вещи:
`minimumZoomScale` меньше `maximumZoomScale`, делегат и метод
`viewForZooming`, который говорит, **что** увеличивать.

`maximumZoomScale = 4.0` — увеличить можно в 4 раза: фото шириной 393
точки на экране станет 1572 точки, и видна будет четверть его ширины.
`bouncesZoom = true` — если растянуть сильнее, картинка «пружинит» и
возвращается к пределу.

Полный просмотрщик с двойным тапом для увеличения — глава 16
(Gallery) и глава 37 (Photo viewer).

Если масштабировать нужно не картинку в скролле, а произвольную view,
есть `UIPinchGestureRecognizer`:

```swift
@objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
    guard let target = gesture.view else { return }
    target.transform = target.transform.scaledBy(x: gesture.scale, y: gesture.scale)
    gesture.scale = 1
}
```

`gesture.scale` — во сколько раз пальцы разошлись с начала жеста:
1,0 — не двигались, 2,0 — расстояние между пальцами выросло вдвое,
0,5 — сократилось вдвое. Трюк с `gesture.scale = 1` делает шаги
**относительными**: каждый вызов умножает текущий масштаб на
изменение **с прошлого вызова**, и счётчик обнуляется. Без обнуления
масштаб бы «разгонялся»: на втором кадре 1,1 × 1,2, на третьем уже
× 1,3 поверх и так далее.

## 29.4 Pan для draggable view

**Когда применять.** Перетаскивание пальцем: карточка, стикер,
плавающая кнопка. **Pan** — жест «ведение пальцем».

```swift
final class DragViewController: UIViewController {
    private let card = UIView(frame: CGRect(x: 40, y: 200, width: 120, height: 80))
    private var dragStart = CGPoint.zero

    override func viewDidLoad() {
        super.viewDidLoad()
        card.backgroundColor = .systemBlue
        view.addSubview(card)
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        card.addGestureRecognizer(pan)
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .began:
            dragStart = card.center
        case .changed:
            let translation = gesture.translation(in: view)
            card.center = CGPoint(x: dragStart.x + translation.x,
                                  y: dragStart.y + translation.y)
        case .ended, .cancelled:
            let velocity = gesture.velocity(in: view)
            let target = CGPoint(x: card.center.x + project(velocity.x),
                                 y: card.center.y + project(velocity.y))
            UIView.animate(withDuration: 0.3) {
                self.card.center = self.clampedToScreen(target)
            }
        default:
            break
        }
    }

    /// Сколько точек карточка «докатилась» бы по инерции.
    private func project(_ velocity: CGFloat) -> CGFloat {
        let deceleration: CGFloat = 0.998
        return (velocity / 1000) * deceleration / (1 - deceleration)
    }

    private func clampedToScreen(_ point: CGPoint) -> CGPoint {
        let area = view.bounds.inset(by: view.safeAreaInsets)
        let halfW = card.bounds.width / 2
        let halfH = card.bounds.height / 2
        return CGPoint(x: min(max(point.x, area.minX + halfW), area.maxX - halfW),
                       y: min(max(point.y, area.minY + halfH), area.maxY - halfH))
    }
}
```

Две величины, на которых стоит любой pan.

**Смещение** (`translation(in:)`) — насколько палец сдвинулся **от
точки начала жеста**, в координатах указанной view. Палец начал в
(100, 300) и сейчас в (160, 280) — смещение (60, −20): 60 точек
вправо и 20 вверх (ось Y в UIKit направлена **вниз**, поэтому движение
вверх даёт минус). Отсюда схема: в `.began` запоминаем, где был центр
карточки, а в `.changed` ставим центр = старт + смещение. Смещение
меряем в координатах `view` — неподвижного родителя. Если мерить в
координатах самой карточки, которая при этом движется, отсчёт будет
ехать вместе с ней.

**Скорость** (`velocity(in:)`) — как быстро движется палец в момент
вызова, в **точках в секунду**. (800, 0) — вправо со скоростью 800
точек в секунду, то есть за секунду палец прошёл бы примерно два
экрана iPhone по ширине. Скорость нужна в `.ended`: отпустили медленно
— карточка остаётся под пальцем, «швырнули» — она должна пролететь
дальше.

**Инерция** — функция `project`. Она отвечает: «если бы карточка
тормозила как обычный список iOS, сколько бы она ещё проехала?».
0,998 — коэффициент торможения обычной прокрутки
(`UIScrollView.DecelerationRate.normal`): за каждую миллисекунду
скорость умножается на 0,998, то есть теряет 0,2%. Сложив все эти
убывающие шаги, получаем формулу из функции. На числах: при скорости
1000 точек в секунду карточка докатится ещё на
1000 / 1000 × 0,998 / 0,002 ≈ 499 точек, при 200 точках в секунду — на
100. Получается простое правило: путь по инерции — примерно половина
скорости.

`clampedToScreen` не даёт карточке улететь за экран: берём безопасную
область, отступаем от её краёв на половину размера карточки (ведь
`center` — это середина) и зажимаем координату между границами через
`min(max(...))`. Точка x = 500 на экране шириной 393 превратится в
393 − 60 = 333.

**Частые ошибки.**

- **Смещение прибавляют к текущему центру** на каждом `.changed`, а
  не к стартовому. Смещение считается от начала жеста, поэтому
  карточка «разгоняется» и убегает из-под пальца. Лечение — стартовая
  точка, как в листинге, или обнулять смещение после каждого шага:
  `gesture.setTranslation(.zero, in: view)`.
- **Не обработан `.cancelled`** — после входящего звонка карточка
  остаётся посреди экрана в промежуточном положении.

**Упражнение 29.1.** Карточку отпустили со скоростью (−1500, 400).
Куда она докатится по инерции (в точках по каждой оси), если центр в
момент отпускания был (200, 400)? Что сделает `clampedToScreen` на
экране 393 × 852 с безопасной областью сверху 59 и снизу 34 и
карточкой 120 × 80?

## 29.5 Tap gesture

**Когда применять.** Тап по view, которая сама не кнопка: аватар,
картинка, метка.

```swift
final class ProfileHeaderViewController: UIViewController {
    private let avatarView = UIImageView()

    override func viewDidLoad() {
        super.viewDidLoad()
        let tap = UITapGestureRecognizer(target: self, action: #selector(avatarTapped))
        avatarView.addGestureRecognizer(tap)
        avatarView.isUserInteractionEnabled = true
        avatarView.accessibilityTraits = .button
        avatarView.accessibilityLabel = "Сменить фото профиля"
        avatarView.isAccessibilityElement = true
    }

    @objc private func avatarTapped() {
        // открыть выбор фото
    }
}
```

`isUserInteractionEnabled = true` — **обязательно** для `UIImageView`
и `UILabel`: у них это свойство по умолчанию `false`, и все касания
проходят насквозь, до view под ними. Распознаватель на такой view
просто молчит, без ошибок.

Три строки доступности превращают картинку в «кнопку» для VoiceOver:
иначе незрячий человек не узнает, что аватар нажимается. Если элемент
выглядит и работает как кнопка, часто проще сразу сделать его
`UIButton` — доступность и подсветка при нажатии будут бесплатно.

**Двойной тап** и конфликт с одинарным:

```swift
let singleTap = UITapGestureRecognizer(target: self, action: #selector(toggleControls))
let doubleTap = UITapGestureRecognizer(target: self, action: #selector(zoomIn))
doubleTap.numberOfTapsRequired = 2
singleTap.require(toFail: doubleTap)
photoView.addGestureRecognizer(singleTap)
photoView.addGestureRecognizer(doubleTap)
```

Без последней настройки двойной тап вызовет **оба** действия: первый
касание распознается как одинарный тап (интерфейс скроется), а второе
— как двойной (фото увеличится).

`singleTap.require(toFail: doubleTap)` — «одинарный тап срабатывает,
только когда двойной **провалился**». Одинарный теперь ждёт:
последует ли второй тап? Если за короткий промежуток второго касания
не было, двойной переходит в `.failed`, и только тогда срабатывает
одинарный. Цена — небольшая задержка реакции на одинарный тап, её
видно, если присмотреться. Поэтому `require(toFail:)` ставят только
там, где двойной тап действительно есть.

## 29.6 Long press

**Когда применять.** Своё действие по долгому нажатию, когда
контекстное меню (29.1) не подходит: например, начать запись голоса,
пока палец держит кнопку.

```swift
@objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
    switch gesture.state {
    case .began:
        startRecording()
    case .ended:
        stopRecording(send: true)
    case .cancelled, .failed:
        stopRecording(send: false)
    default:
        break
    }
}

// подключение:
// let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
// longPress.minimumPressDuration = 0.3
// micButton.addGestureRecognizer(longPress)
```

`minimumPressDuration` — сколько держать палец, чтобы жест начался.
По умолчанию 0,5 с, здесь 0,3 с — запись должна начинаться быстро.

Долгое нажатие — **непрерывный** жест. `.began` приходит, когда
палец продержался нужное время, а не в момент касания. `.ended` — когда
палец отпустили. Пока палец держат, можно двигать его: если сдвиг
больше `allowableMovement` (по умолчанию 10 точек) до срабатывания,
жест провалится.

Для меню действий по долгому нажатию бери `UIContextMenuInteraction`
(29.1): там уже есть вибрация, превью и поддержка доступности.

## 29.7 Swipe gesture (не actions)

**Когда применять.** Короткий быстрый взмах для переключения:
другая фотография, другой день в календаре.

```swift
let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(showNext))
swipeLeft.direction = .left
view.addGestureRecognizer(swipeLeft)

let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(showPrevious))
swipeRight.direction = .right
view.addGestureRecognizer(swipeRight)
```

Свайп — **дискретный** жест: он срабатывает один раз, когда палец
быстро прошёл достаточное расстояние в нужном направлении. Медленное
ведение пальцем — это уже pan (29.4).

Почему два распознавателя, а не один с `direction = [.left, .right]`:
распознаватель с двумя направлениями сработает на оба, но **не скажет,
какое именно** было. Два отдельных распознавателя — два разных
действия.

Свайп не даёт «прилипания» к пальцу: экран не едет вслед за движением.
Если нужен листающийся ряд страниц, где соседняя страница видна во
время жеста, — это `UIPageViewController` или скролл с
`isPagingEnabled`.

## 29.8 Pan-to-dismiss modal

**Когда применять.** Свой полноэкранный модальный экран (например,
просмотр фото), который закрывается движением вниз.

```swift
final class DismissableViewController: UIViewController {
    init() {
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) не используется") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleDragDown(_:)))
        view.addGestureRecognizer(pan)
    }

    @objc private func handleDragDown(_ gesture: UIPanGestureRecognizer) {
        let dy = max(0, gesture.translation(in: view).y)

        switch gesture.state {
        case .changed:
            view.transform = CGAffineTransform(translationX: 0, y: dy)
            let progress = min(dy / 300, 1)
            view.alpha = 1 - progress * 0.5
        case .ended, .cancelled:
            let velocityY = gesture.velocity(in: view).y
            if gesture.state == .ended && (dy > 150 || velocityY > 1000) {
                dismiss(animated: true)
            } else {
                UIView.animate(withDuration: 0.35, delay: 0,
                               usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
                    self.view.transform = .identity
                    self.view.alpha = 1
                }
            }
        default:
            break
        }
    }
}
```

Тянем экран вниз: он едет за пальцем и бледнеет. Отпустили далеко или
резко — закрываем, иначе пружиной возвращаем на место.

- `max(0, translation.y)` — движение вверх не учитываем: смещение
  зажато снизу нулём. Не пиши вместо этого `guard
  translation > 0 else { return }`: если потянуть вниз, а потом вернуть
  палец выше стартовой точки и отпустить, `.ended` так и не
  обработается, и экран останется сдвинутым.
- **Прозрачность на числах**: `progress` — доля пути от 0 до 1, где
  1 — это 300 точек. Потянули на 150 — progress 0,5, `alpha = 1 − 0,5
  × 0,5 = 0,75` (экран на четверть прозрачный). Потянули на 300 и
  дальше — `alpha = 0,5`, прозрачнее не станет.
- **Порог закрытия** — два условия через «или»: оттащили дальше 150
  точек **или** отпустили со скоростью больше 1000 точек в секунду
  вниз. Второе нужно для короткого резкого взмаха: палец прошёл всего
  60 точек, но так быстро, что намерение закрыть не вызывает сомнений.
- `gesture.state == .ended` — при `.cancelled` (жест прервала система)
  не закрываем, а возвращаем экран.
- `.overFullScreen` — чтобы под экраном оставался предыдущий: когда
  экран становится полупрозрачным и съезжает, сквозь него видно, куда
  мы вернёмся. При `.fullScreen` предыдущий экран убран из иерархии, и
  сквозь полупрозрачный экран будет виден чёрный фон окна.

Для системного листа (`.pageSheet`, глава 28) всё это работает само,
писать ничего не нужно. Вариант для просмотрщика фото — глава 37,
раздел 37.3.

**Упражнение 29.2.** Человек потянул экран вниз на 90 точек и отпустил
со скоростью 1200 точек в секунду. Закроется ли экран? А если потянул
на 200 точек, остановил палец (скорость около 0) и отпустил? Какой
будет `alpha` в момент отпускания во втором случае?

## 29.9 Edge swipe (back gesture)

`UINavigationController` уже содержит распознаватель свайпа от левого
края — `interactivePopGestureRecognizer`. Он возвращает на предыдущий
экран стопки.

Самый частый вопрос — как его **сохранить** или **восстановить**, если
ты поставил свою левую кнопку. Правильный способ с подклассом
контроллера навигации разобран в главе 26, раздел 26.5: контроллер
становится делегатом жеста и разрешает его, только когда в стопке
больше одного экрана.

С iOS 26 у стопки появился ещё один системный жест —
`interactiveContentPopGestureRecognizer`: возврат назад свайпом
вправо **из любой точки содержимого**, а не только от края. Если на
экране есть свой горизонтальный жест (карусель, слайдер,
перетаскиваемая карточка), он может конфликтовать с этим возвратом.
Apple прямо пишет, что это свойство предназначено для настройки
зависимостей, например:

```swift
if #available(iOS 26.0, *),
   let contentPop = navigationController?.interactiveContentPopGestureRecognizer {
    contentPop.require(toFail: carouselPan)
}
```

«Возврат из контента начнётся, только если мой жест карусели
провалился» — пока палец листает карусель, экран назад не уедет.

Свой жест от края экрана — `UIScreenEdgePanGestureRecognizer`:

```swift
let edgePan = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(openMenu(_:)))
edgePan.edges = .right
view.addGestureRecognizer(edgePan)
```

Это pan, который начинается только у указанного края экрана (здесь
правого). Удобно для выдвижного бокового меню. Обработчик — такой же,
как у pan в 29.4.

## 29.10 Конфликт gesture'ов

Чаще всего жесты ломаются не поодиночке, а когда их несколько: pan
внутри скролла, тап внутри ячейки, свайп назад поверх карусели.

**Правило по умолчанию.** Если на одном касании могут сработать два
распознавателя (на одной view или на view и её родителе), UIKit
разрешает сработать **только одному**: первый распознавший жест
побеждает, остальные переходят в `.failed`. Отсюда инструменты:

**1. Направление — `gestureRecognizerShouldBegin`.** Классика:
горизонтальный pan на ячейке вертикального списка. Список прокручивается
вертикальным pan'ом, твоя ячейка должна уезжать вбок. Разрешим своему
жесту начаться, только если движение **больше горизонтальное, чем
вертикальное**:

```swift
extension SwipeCell {
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
        let velocity = pan.velocity(in: self)
        return abs(velocity.x) > abs(velocity.y)
    }
}
```

`abs` — модуль числа, без знака. Сравниваем, какая составляющая
скорости больше. Скорость (300, −80): по горизонтали 300, по вертикали
80 — жест горизонтальный, ячейка поедет. Скорость (40, 500) — палец
идёт вниз, наш жест не начнётся, и касание достанется списку.

Обрати внимание: метод объявлен с `override`. У `UIView` уже есть свой
`gestureRecognizerShouldBegin(_:)`, и ячейка — это view. Для жестов,
которые ты сам добавил к ячейке, UIKit спросит именно этот метод —
делегата назначать не обязательно.

**2. Одновременность — `shouldRecognizeSimultaneouslyWith`.** Иногда
оба жеста должны работать вместе: щипок и поворот фотографии двумя
пальцами, свой pan поверх скролла для эффекта параллакса.

```swift
final class StickerViewController: UIViewController, UIGestureRecognizerDelegate {
    private let pinch = UIPinchGestureRecognizer()
    private let rotation = UIRotationGestureRecognizer()

    override func viewDidLoad() {
        super.viewDidLoad()
        pinch.delegate = self
        rotation.delegate = self
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        (gestureRecognizer === pinch && other === rotation)
            || (gestureRecognizer === rotation && other === pinch)
    }
}
```

Отвечаем «да» **только** для нужной пары — щипок с поворотом. Голое
`return true` разрешило бы одновременность со всем подряд, включая
системный свайп назад и прокрутку, и тогда при вращении стикера
заодно ехал бы экран.

`===` — сравнение **объектов** («это тот же самый распознаватель»), а
не значений.

**3. Очерёдность — `require(toFail:)`.** Уже встречался в 29.5: «мой
жест ждёт, пока тот провалится». Работает и между разными видами
жестов: `swipe.require(toFail: pan)` — свайп сработает, только если pan
не распознан.

Сводка:

| Ситуация                                         | Инструмент                                |
|--------------------------------------------------|-------------------------------------------|
| Жесты по разным направлениям                     | `gestureRecognizerShouldBegin` + скорость |
| Оба жеста должны работать вместе                 | `shouldRecognizeSimultaneouslyWith`, точечно |
| Один жест — частный случай другого (1 и 2 тапа)  | `require(toFail:)`                        |

**Упражнение 29.3.** В ячейке горизонтальный pan с проверкой из
листинга выше. Человек повёл пальцем почти по диагонали, скорость
(250, 260). Что произойдёт: поедет ячейка или прокрутится список? Как
изменить условие, чтобы ячейка реагировала только на явно
горизонтальное движение — например, когда горизонтальная скорость
хотя бы вдвое больше вертикальной?

## 29.11 Gesture inside UITableView

Тап по ячейке обрабатывает `didSelectRowAt`. Если нужно отдельное
действие по тапу на **часть** ячейки — например, на аватарку, —
распознаватель ставится в **самой ячейке**, один раз:

```swift
final class CommentCell: UITableViewCell {
    var onAvatarTap: (() -> Void)?
    let avatarView = UIImageView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        avatarView.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(avatarTapped))
        avatarView.addGestureRecognizer(tap)
        contentView.addSubview(avatarView)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) не используется") }

    @objc private func avatarTapped() { onAvatarTap?() }

    override func prepareForReuse() {
        super.prepareForReuse()
        onAvatarTap = nil
    }
}

// в cellForRowAt:
// cell.onAvatarTap = { [weak self] in self?.openProfile(of: comment.author) }
```

Почему не в `cellForRowAt`: `cellForRowAt` вызывается при каждом
появлении строки. Если добавлять распознаватель там, то
переиспользованная ячейка накопит их десяток, и один тап вызовет
действие десять раз. В `init` ячейки распознаватель добавляется ровно
один раз за её жизнь, а в `cellForRowAt` меняется только замыкание
`onAvatarTap` — оно и знает, чей это аватар.

Тап по аватарке **не** выделит строку: у распознавателя по умолчанию
`cancelsTouchesInView = true` — распознав тап, он отменяет касание для
view, и таблица не видит «нажатия на строку». Если нужно и то, и
другое, поставь `tap.cancelsTouchesInView = false`.

Альтернатива без жестов — положить в ячейку `UIButton` с картинкой
аватара. Это проще и сразу доступно для VoiceOver. Для кнопки
«подробнее» справа есть стандартный аксессуар `.detailButton` и метод
делегата `accessoryButtonTappedForRowWith`.

## 29.12 Бытовая аналогия

Распознаватели — это **датчики в комнате**. Один срабатывает на
хлопок (тап), другой на долгое касание выключателя (long press),
третий на взмах рукой (swipe), четвёртый — когда двигают мебель (pan),
пятый — когда разводят руками (pinch). Каждый датчик запускает своё
действие.

Когда датчики стоят рядом и видят одно и то же движение, их нужно
договорить: либо дать им приоритет («сначала убедись, что это не
двойной хлопок» — `require(toFail:)`), либо разрешить работать вместе
(`shouldRecognizeSimultaneouslyWith`), либо научить отличать движения
по направлению (`gestureRecognizerShouldBegin`).

## Ответы к упражнениям

**29.1.** Инерция — примерно половина скорости: по X
−1500 / 1000 × 0,998 / 0,002 ≈ −748 точек, по Y ≈ +200 точек. Цель
(200 − 748, 400 + 200) = (−548, 600). `clampedToScreen`: безопасная
область по X — от 0 до 393, по Y — от 59 до 852 − 34 = 818. Отступаем
на половину карточки (60 по X, 40 по Y): X зажимается в диапазон
60…333, Y — в 99…778. −548 меньше 60, поэтому X = 60; 600 внутри
диапазона. Карточка уедет в (60, 600) — прижмётся к левому краю.

**29.2.** В первом случае закроется: 90 точек меньше порога 150, но
скорость 1200 больше 1000, а условия соединены «или». Во втором тоже
закроется: 200 больше 150. `alpha` в момент отпускания: progress =
200 / 300 ≈ 0,67, `alpha = 1 − 0,67 × 0,5 ≈ 0,67`.

**29.3.** 250 < 260, условие `abs(x) > abs(y)` ложно — ячейка не
поедет, прокрутится список. Для «явно горизонтального» движения:

```swift
return abs(velocity.x) > 2 * abs(velocity.y)
```

Скорость (250, 260) — не пройдёт, (600, 200) — пройдёт (600 > 400).

## Что мы выучили

- **Распознаватель жестов** — подкласс `UIGestureRecognizer` на view;
  дискретные жесты (тап, свайп) срабатывают один раз, непрерывные
  (pan, pinch, long press) проходят `.began → .changed → .ended`.
- **`UIContextMenuInteraction`** — долгое нажатие с меню и превью;
  в таблице — `contextMenuConfigurationForRowAt`, элемент берём сразу.
- **Swipe actions** — первое действие ближе к краю и выполняется
  полным свайпом (`performsFirstActionWithFullSwipe`); `done(...)`
  обязателен; строку ищем заново в момент нажатия.
- **Pinch** — `UIScrollView` + `viewForZooming`; для своей view —
  `scaledBy` и `gesture.scale = 1`.
- **Pan** — смещение от начала жеста + стартовая точка; скорость в
  точках в секунду; инерция ≈ половина скорости; зажим в безопасную
  область.
- **Тап** по `UIImageView`/`UILabel` — только с
  `isUserInteractionEnabled = true`; одинарный с двойным —
  `require(toFail:)`.
- **Pan-to-dismiss** — `max(0, dy)`, порог по расстоянию **или**
  скорости, `.overFullScreen`, пружина при возврате.
- **Конфликты** — направление через `gestureRecognizerShouldBegin`,
  одновременность только для нужной пары, очерёдность через
  `require(toFail:)`; в iOS 26 — зависимость от
  `interactiveContentPopGestureRecognizer`.
- **Жест в ячейке** — добавляем в `init` ячейки, а не в
  `cellForRowAt`; `cancelsTouchesInView` решает, выделится ли строка.

## Apple Developer Documentation

- [`UIGestureRecognizer`](https://developer.apple.com/documentation/uikit/uigesturerecognizer) — базовый класс, состояния, `require(toFail:)`, `cancelsTouchesInView`.
- [`UIGestureRecognizerDelegate`](https://developer.apple.com/documentation/uikit/uigesturerecognizerdelegate) — `gestureRecognizerShouldBegin(_:)`, `gestureRecognizer(_:shouldRecognizeSimultaneouslyWith:)`.
- [`UIPanGestureRecognizer`](https://developer.apple.com/documentation/uikit/uipangesturerecognizer) — `translation(in:)`, `velocity(in:)`, `setTranslation(_:in:)`.
- [`UITapGestureRecognizer`](https://developer.apple.com/documentation/uikit/uitapgesturerecognizer), [`UILongPressGestureRecognizer`](https://developer.apple.com/documentation/uikit/uilongpressgesturerecognizer), [`UIPinchGestureRecognizer`](https://developer.apple.com/documentation/uikit/uipinchgesturerecognizer), [`UIRotationGestureRecognizer`](https://developer.apple.com/documentation/uikit/uirotationgesturerecognizer), [`UISwipeGestureRecognizer`](https://developer.apple.com/documentation/uikit/uiswipegesturerecognizer), [`UIScreenEdgePanGestureRecognizer`](https://developer.apple.com/documentation/uikit/uiscreenedgepangesturerecognizer) — стандартные распознаватели.
- [`UIContextMenuInteraction`](https://developer.apple.com/documentation/uikit/uicontextmenuinteraction) и [`UIContextMenuConfiguration`](https://developer.apple.com/documentation/uikit/uicontextmenuconfiguration) — контекстное меню с превью.
- [`UISwipeActionsConfiguration`](https://developer.apple.com/documentation/uikit/uiswipeactionsconfiguration) и [`UIContextualAction`](https://developer.apple.com/documentation/uikit/uicontextualaction) — действия по свайпу строки.
- [`UIScrollView.DecelerationRate`](https://developer.apple.com/documentation/uikit/uiscrollview/decelerationrate-swift.struct) — коэффициенты торможения прокрутки (`.normal` = 0,998).
- [`UINavigationController.interactivePopGestureRecognizer`](https://developer.apple.com/documentation/uikit/uinavigationcontroller/interactivepopgesturerecognizer) и [`interactiveContentPopGestureRecognizer`](https://developer.apple.com/documentation/uikit/uinavigationcontroller/interactivecontentpopgesturerecognizer) — системные жесты возврата (второй — iOS 26+).
- [HIG — Gestures](https://developer.apple.com/design/human-interface-guidelines/gestures) — Apple о стандартных жестах и их смысле.

→ [Глава 30. Cookbook — формы и валидация](./47-cookbook-forms.md)
