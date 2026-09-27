# Глава 26. Cookbook — навигация и заголовки

Почти любое приложение — это стопка экранов: список, из него карточка,
из карточки — настройки. Эта глава про всё, что происходит вокруг
такой стопки: большой заголовок, который сжимается при прокрутке,
бейджи на вкладках, индикатор шагов, «хлебные крошки», своя кнопка
«назад», выбор между push и модальным показом, собственная анимация
перехода и внешний вид навигационной панели.

> **В каком режиме код.** Как и во всей части IV, листинги проверены
> компилятором в режиме Swift 6 с Default Actor Isolation = MainActor:
> весь код без пометок выполняется на главном потоке (подробнее — в
> начале главы 25).

Несколько слов, без которых дальше будет трудно.

**`UINavigationController`** — контейнер, который держит экраны
**стопкой** (стеком). Представь стопку карточек на столе: `push` кладёт
новую карточку сверху, `pop` снимает верхнюю, и снова видна
предыдущая. Видна всегда только верхняя.

**Навигационная панель** (navigation bar) — полоса сверху с
заголовком и кнопками. Она одна на весь контроллер навигации.

**`navigationItem`** — «табличка» каждого экрана: заголовок, кнопки
слева и справа, строка поиска. Панель показывает табличку того
экрана, который сейчас сверху стопки. Поэтому кнопки экрана
настраивают через его `navigationItem`, а не через панель напрямую.

## 26.1 Large titles + scroll fade

**Когда применять.** Главные экраны приложения, как в «Настройках»
или «Почте»: сверху крупный заголовок, а при прокрутке списка он
плавно сжимается в обычный, по центру панели.

```swift
// Там, где создаёшь стопку (SceneDelegate или координатор):
func makeOrdersFlow() -> UINavigationController {
    let nav = UINavigationController(rootViewController: OrdersViewController())
    nav.navigationBar.prefersLargeTitles = true
    return nav
}

final class OrdersViewController: UITableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Заказы"
        navigationItem.largeTitleDisplayMode = .always
    }
}

final class OrderDetailsViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
    }
}
```

Как это устроено:

- `prefersLargeTitles` — свойство **панели**, то есть всей стопки
  сразу. Включаем один раз, в момент создания контроллера навигации.
- `largeTitleDisplayMode` — свойство **таблички** конкретного экрана.
  `.always` — этот экран показывает большой заголовок. `.never` —
  обычный, маленький. `.automatic` (по умолчанию) — «как у
  предыдущего экрана в стопке».
- `title` — сам текст заголовка.

Типичная схема: главный список — `.always`, всё, что открывается из
него, — `.never`. Если оставить карточке `.automatic`, она унаследует
большой заголовок от списка, и длинное название заказа займёт
полэкрана.

Сжатие при прокрутке iOS делает сама, но только если понимает, **за
каким списком следить**. Когда экран — `UITableViewController` или
таблица лежит первой в иерархии, обычно всё работает само. Если между
панелью и таблицей стоят другие view, укажи список явно (iOS 15+):

```swift
setContentScrollView(tableView, for: .top)
```

`for: .top` — «этот список отвечает за верхний край экрана»: панель
будет сжиматься и менять фон по его прокрутке.

**Частые ошибки.**

- **`prefersLargeTitles` включают в каждом экране** в `viewWillAppear`.
  Это свойство общей панели — и при возврате назад заголовок дёргается
  между размерами. Включай один раз, а поведение отдельных экранов
  задавай через `largeTitleDisplayMode`.
- **Заголовок не сжимается.** Панель не нашла список: таблица не
  первая в иерархии. Лечится `setContentScrollView(_:for:)`.
- **Большой заголовок мешает своей шапке.** Если у тебя растягивающаяся
  шапка (stretchy header, глава 21), панель и шапка будут бороться за
  одно пространство. Ставь такому экрану `.never` и управляй размером
  заголовка сам.

## 26.2 Tab bar badges

**Когда применять.** Сообщить о новом внутри вкладки: непрочитанные
сообщения, обновления, товары в корзине.

**Бейдж** (badge) — маленький кружок с числом у иконки вкладки. Рисует
его сама iOS, красным, в правом верхнем углу иконки.

```swift
// Внутри экрана, который лежит во вкладке «Чаты»:
func updateUnreadBadge(unread: Int) {
    guard let item = navigationController?.tabBarItem ?? tabBarItem else { return }
    switch unread {
    case 0:     item.badgeValue = nil
    case 1...99: item.badgeValue = "\(unread)"
    default:    item.badgeValue = "99+"
    }
}
```

`badgeValue` — строка (`String?`). Обычно число, но можно и короткий
текст вроде «new». `nil` убирает бейдж.

Почему `navigationController?.tabBarItem`: `UITabBarController` берёт
иконку и бейдж у экрана, который **непосредственно** лежит во
вкладке. Чаще всего это не твой экран, а `UINavigationController`
вокруг него. Если поставить бейдж на `tabBarItem` самого экрана, он не
появится: вкладка смотрит на табличку контроллера навигации. `?? tabBarItem`
— запасной вариант для экрана, который лежит во вкладке без
навигации.

Три ветки `switch`:

- `0` → `nil`. Бейдж «0» выглядит как «у тебя ноль новых» — это не
  новость, прячем.
- `1...99` → число как есть.
- больше 99 → «99+». Кружок растягивается под текст, и «1284» займёт
  полвкладки.

Цвет меняется через `badgeColor` (iOS 10+), если красный не подходит
под дизайн.

**Частые ошибки.**

- **Бейдж «0».** См. выше: для нуля ставь `nil`.
- **Бейдж не гаснет.** Сбрасывай его, когда человек действительно
  увидел новое: открыл вкладку (`viewDidAppear`) или прочитал чат.
- **Бейдж ставят не на тот `tabBarItem`** — на экран вместо контроллера
  навигации вокруг него.

**Альтернативы.** Число на иконке приложения на домашнем экране — это
другой бейдж, его ставит push-уведомление или API уведомлений
(глава 41).

## 26.3 Step indicator

**Когда применять.** Мастер (wizard) или онбординг с понятными
шагами: «Регистрация: шаг 2 из 4».

```swift
final class StepIndicatorView: UIView {
    private let totalSteps: Int
    private var dots: [UIView] = []

    init(totalSteps: Int) {
        self.totalSteps = totalSteps
        super.init(frame: .zero)
        setupDots()
        isAccessibilityElement = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) не используется") }

    private func setupDots() {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        for _ in 0..<totalSteps {
            let dot = UIView()
            dot.backgroundColor = .tertiaryLabel
            dot.layer.cornerRadius = 4
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.widthAnchor.constraint(equalToConstant: 8).isActive = true
            dot.heightAnchor.constraint(equalToConstant: 8).isActive = true
            dots.append(dot)
            stack.addArrangedSubview(dot)
        }
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor),
        ])
    }

    func setCurrentStep(_ step: Int) {
        UIView.animate(withDuration: 0.2) {
            for (i, dot) in self.dots.enumerated() {
                dot.backgroundColor = i <= step ? .systemBlue : .tertiaryLabel
                dot.transform = i == step
                    ? CGAffineTransform(scaleX: 1.4, y: 1.4)
                    : .identity
            }
        }
        accessibilityLabel = "Шаг \(step + 1) из \(totalSteps)"
    }
}
```

Точки в ряд. Пройденные и текущая — синие, будущие — серые, а текущая
ещё и крупнее.

Разберём то, что не бросается в глаза.

- Точка 8 × 8 точек с `cornerRadius = 4`: радиус скругления — половина
  стороны, поэтому квадрат превращается в круг.
- Стек прибит к `centerXAnchor` и к верху и низу. Ограничение
  `leadingAnchor ... greaterThanOrEqualTo` («не левее левого края»)
  не даёт стеку вылезти за границы, если шагов окажется много.
  **Ограничение** (constraint) — правило Auto Layout вида «этот край
  равен тому краю плюс 8»; из набора таких правил система вычисляет
  положение и размер каждой view.
- `CGAffineTransform(scaleX: 1.4, y: 1.4)` — увеличить в 1,4 раза, то
  есть **на 40%**: точка 8 × 8 выглядит как 11,2 × 11,2. Трансформация
  меняет только отрисовку, а не место в раскладке, поэтому соседние
  точки не раздвигаются — крупная точка просто чуть «налезает» на
  промежутки. `.identity` — «без трансформации», исходный размер.
- `i <= step` — шаги нумеруются с нуля. При `step = 1` синими будут
  точки 0 и 1, то есть «пройден первый шаг, идёт второй».
- Один `UIView.animate` на все точки: изменения цвета и размера
  плавно проигрываются за 0,2 секунды.
- `accessibilityLabel` — VoiceOver прочитает «Шаг 2 из 4». Без этого
  незрячий человек услышит просто «элемент».

Вместо точек можно показать тонкую полосу прогресса:

```swift
let progress = UIProgressView(progressViewStyle: .bar)
progress.setProgress(Float(currentStep + 1) / Float(totalSteps), animated: true)
```

`progress` — число от 0 до 1, доля заполнения. На шаге 2 из 4
(`currentStep = 1`) получится (1 + 1) / 4 = 0,5 — полоса заполнена
наполовину. `Float(...)` перед делением обязателен: `2 / 4` в целых
числах даёт 0, и полоса останется пустой до последнего шага.

**Частые ошибки.**

- **Деление целых чисел** в прогрессе — см. выше.
- **Нумерация шагов с нуля в тексте.** Человеку нужно «Шаг 1 из 4», а
  не «Шаг 0 из 4»: к индексу прибавляй 1.

## 26.4 Breadcrumbs

**Когда применять.** Глубокая иерархия: «Каталог › Электроника ›
Смартфоны › Apple». **Хлебные крошки** — строка из уровней, по любому
из которых можно вернуться. В iOS встречаются редко (стандартная
кнопка «назад» ведёт только на уровень выше), но оправданы в
файловых менеджерах и админках.

```swift
extension CatalogViewController {
    func makeBreadcrumbs(_ path: [String]) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stack.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),
        ])

        for (level, name) in path.enumerated() {
            let isLast = level == path.count - 1
            let button = UIButton(type: .system)
            button.setTitle(name, for: .normal)
            button.titleLabel?.font = .preferredFont(forTextStyle: .footnote)
            button.isEnabled = !isLast
            button.addAction(UIAction { [weak self] _ in
                self?.navigateBack(toLevel: level)
            }, for: .touchUpInside)
            stack.addArrangedSubview(button)

            if !isLast {
                let separator = UILabel()
                separator.text = "›"
                separator.textColor = .secondaryLabel
                separator.isAccessibilityElement = false
                stack.addArrangedSubview(separator)
            }
        }
        return scrollView
    }

    func navigateBack(toLevel level: Int) {
        guard let stack = navigationController?.viewControllers,
              level < stack.count else { return }
        navigationController?.popToViewController(stack[level], animated: true)
    }
}
```

Горизонтально прокручиваемая строка кнопок. Тап по уровню — возврат
на этот уровень.

- Стек прибит к `contentLayoutGuide` скролла — это «размер
  содержимого»: сколько места нужно всем кнопкам, столько и можно
  прокрутить. А высота стека приравнена к `frameLayoutGuide` — к
  видимой рамке скролла, иначе скроллу было бы непонятно, какой
  высоты содержимое, и появилась бы ещё и вертикальная прокрутка.
- `button.isEnabled = !isLast` — последний уровень — это экран, на
  котором ты сейчас. Возвращаться на него некуда, поэтому кнопка
  неактивна и выглядит серой.
- Разделитель «›» спрятан от VoiceOver (`isAccessibilityElement =
  false`): слушать «знак больше» между уровнями бесполезно.
- `navigateBack(toLevel:)` предполагает, что уровень крошки совпадает
  с позицией экрана в стопке: «Каталог» — нулевой экран, «Электроника»
  — первый и так далее. `popToViewController` снимает со стопки всё,
  что выше нужного экрана.
- `[weak self]` в замыкании кнопки: экран держит кнопку, кнопка —
  действие, действие — замыкание. Сильная ссылка на `self` замкнула бы
  круг, и экран никогда бы не освободился.

**Частые ошибки.**

- **Кликабельный текущий уровень** — тап ничего не делает, человек
  думает, что приложение зависло.
- **Уровни не совпадают со стопкой** (например, часть уровней
  открыта модально). Тогда `level` уже не индекс в
  `viewControllers`, и нужно искать экран по-другому.

## 26.5 Custom back button

**Когда применять.** Две разные задачи, которые часто путают.

**Задача 1: кнопка «закрыть» на модальном экране.** У первого экрана
модального окна кнопки «назад» нет вовсе — возвращаться некуда, окно
надо закрыть. Здесь своя левая кнопка — правильное решение:

```swift
final class EditorViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: self,
            action: #selector(closeTapped)
        )
        navigationItem.leftBarButtonItem?.accessibilityLabel = "Закрыть"
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }
}
```

`leftBarButtonItem` — кнопка в левом слоте таблички экрана. Иконка
`xmark` («крестик») — системный символ SF Symbols. У кнопки-картинки
нет текста, поэтому VoiceOver нужно подсказать, что это «Закрыть».

`target: self, action: #selector(...)` — классический способ UIKit
сказать «при нажатии вызови у этого объекта этот метод». Метод
помечен `@objc`, потому что механизм селекторов пришёл из
Objective-C.

**Задача 2: поменять вид стандартной кнопки «назад» в стопке.** Здесь
`leftBarButtonItem` — **плохое** решение: своя левая кнопка заменяет
системную «назад», и вместе с ней перестаёт работать свайп от левого
края экрана. Правильнее настроить саму системную кнопку:

```swift
// В экране, КУДА вернёмся (например, в списке):
navigationItem.backButtonTitle = "Список"        // текст кнопки «назад» на экране, открытом из списка

// Или в экране, ГДЕ кнопка показана (iOS 14+):
navigationItem.backButtonDisplayMode = .minimal  // только стрелка, без текста

// Своя стрелка для всей панели:
let appearance = UINavigationBarAppearance()
appearance.configureWithDefaultBackground()
let arrow = UIImage(systemName: "arrow.left")
appearance.setBackIndicatorImage(arrow, transitionMaskImage: arrow)
navigationController?.navigationBar.standardAppearance = appearance
```

Обрати внимание на хитрость с `backButtonTitle`: текст кнопки «назад»
задаёт **предыдущий** экран, а не текущий. Логика такая: кнопка
ведёт на список, значит и называться должна так, как хочет список.

`backButtonDisplayMode` работает иначе — его ставят на экран, где
кнопка видна: `.default` — стрелка и заголовок предыдущего экрана,
`.generic` — стрелка и «Назад», `.minimal` — одна стрелка.

`setBackIndicatorImage(_:transitionMaskImage:)` меняет саму стрелку.
Вторая картинка — маска, по которой текст кнопки «уезжает» под
стрелку во время анимации перехода; чаще всего передают ту же
картинку. Подробнее о `UINavigationBarAppearance` — в 26.9.

Все три способа сохраняют системную кнопку, а значит и свайп назад.

**Частые ошибки.**

- **Своя `leftBarButtonItem` в стопке ломает свайп назад.** Если без
  неё никак, восстанавливай жест правильно. Часто советуют
  `interactivePopGestureRecognizer?.delegate = nil`, но у этого хака
  есть ловушка: на **первом** экране стопки свайп от края тоже
  срабатывает, возвращаться некуда, и навигация может перестать
  реагировать на касания. Надёжнее сделать контроллер навигации
  делегатом жеста и разрешать свайп, только когда в стопке больше
  одного экрана:

```swift
final class AppNavigationController: UINavigationController,
                                     UIGestureRecognizerDelegate {
    override func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}
```

`gestureRecognizerShouldBegin` спрашивают прямо перед стартом жеста:
«можно начинать?». Ответ «да, если в стопке больше одного экрана»
отключает свайп на корневом экране и возвращает его на всех остальных,
даже с кастомной левой кнопкой. Подробнее о делегатах жестов — глава
29.

## 26.6 Modal vs push — когда какой

**Push** — положить экран в стопку навигации: он въезжает справа,
слева появляется «назад». **Modal** (модальный показ) — открыть экран
**поверх** текущего, как отдельное окно: он выезжает снизу и живёт в
своей стопке, пока его не закроют.

| Сценарий                          | Способ показа                              |
|-----------------------------------|--------------------------------------------|
| Карточка из списка                | push                                       |
| Создание нового элемента          | модальный лист (`.medium` или `.large`)    |
| Редактирование одной настройки    | push (внутри «Настроек»)                   |
| Авторизация                       | модальный на весь экран                    |
| Подтверждение действия            | `UIAlertController`                        |
| «Поделиться»                      | `UIActivityViewController`                 |
| Быстрый выбор из нескольких опций | `UIMenu` или action sheet                  |

**Правило большого пальца.** Если человек **смотрит и возвращается**
(углубляется в иерархию, чтобы посмотреть подробности) — push. Если он
**выполняет отдельную задачу и закрывает** её (создаёт, редактирует,
соглашается, входит) — модальный показ. У модального окна должен быть
явный выход: «Готово», «Отмена» или крестик.

Бытовая аналогия: push — ты листаешь папку и заходишь в подпапки;
модальное окно — тебе выдали анкету, ты её заполнил и сдал.

Подробный разбор всех видов модального показа — глава 28.

## 26.7 Custom transitions

**Когда применять.** Стандартного въезда справа мало: например,
миниатюра должна «вырасти» в полноэкранную карточку (такой переход
называют **hero-анимацией**).

Переход между экранами в UIKit описывает объект-**аниматор**. Когда
контроллер навигации собирается сделать push или pop, он спрашивает
своего делегата: «есть у тебя аниматор для этого перехода?». Ответил
`nil` — будет стандартная анимация.

```swift
final class ScaleTransition: NSObject, UIViewControllerAnimatedTransitioning {
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?)
        -> TimeInterval {
        0.4
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let toVC = transitionContext.viewController(forKey: .to),
              let toView = transitionContext.view(forKey: .to) else {
            transitionContext.completeTransition(false)
            return
        }
        let container = transitionContext.containerView
        toView.frame = transitionContext.finalFrame(for: toVC)
        container.addSubview(toView)
        toView.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
        toView.alpha = 0

        UIView.animate(withDuration: transitionDuration(using: transitionContext),
                       delay: 0,
                       usingSpringWithDamping: 0.8,
                       initialSpringVelocity: 0) {
            toView.transform = .identity
            toView.alpha = 1
        } completion: { _ in
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }
    }
}
```

`UIViewControllerAnimatedTransitioning` — протокол аниматора, два
обязательных метода:

- `transitionDuration` — длительность, 0,4 секунды.
- `animateTransition` — сама анимация. UIKit передаёт **контекст
  перехода**: откуда уходим (`.from`), куда приходим (`.to`) и
  `containerView` — «сцену», на которой разыгрывается переход.

Разбор по шагам:

1. `finalFrame(for:)` — где должен оказаться новый экран в конце.
   Без этой строки размер новой view не определён, и экран может
   появиться со смещением или не на весь размер.
2. Добавляем новый экран на сцену и уменьшаем до 30% (`scaleX: 0.3`),
   делаем прозрачным (`alpha = 0`).
3. Анимация с пружиной возвращает `transform` к `.identity` (100%) и
   `alpha` к 1. `usingSpringWithDamping: 0.8` — «гашение» пружины от
   0 до 1: при 1 движение плавно останавливается без перелёта, при 0,8
   экран чуть-чуть перелетит полный размер и вернётся, при 0,5 —
   заметно качнётся. `initialSpringVelocity: 0` — стартуем с места.
4. `completeTransition(...)` — **обязательно**. Это сигнал «переход
   закончен», после которого UIKit убирает старый экран и снова
   принимает касания. Передаём `!transitionWasCancelled`: если переход
   отменили (например, интерактивно), он не должен считаться
   состоявшимся.

Подключаем через делегата контроллера навигации:

```swift
final class HeroNavigationController: UINavigationController,
                                      UINavigationControllerDelegate {
    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
    }

    func navigationController(_ navigationController: UINavigationController,
                              animationControllerFor operation: UINavigationController.Operation,
                              from fromVC: UIViewController,
                              to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        operation == .push ? ScaleTransition() : nil
    }
}
```

Контроллер навигации сам себе делегат — это удобно: `delegate`
хранится **слабой** ссылкой, и отдельный объект-делегат, созданный
«на лету» и никем не удержанный, исчез бы сразу. Свой контроллер
никуда не денется, пока жива стопка.

Аниматор отдаём только для `.push`. Для `.pop` возвращаем `nil`, и
тогда работает стандартный возврат — **вместе со свайпом от края**.
Если отдавать аниматор и на pop, системный интерактивный свайп
перестаёт работать: UIKit ждёт от тебя ещё и **интерактивный
контроллер** (`UIPercentDrivenInteractiveTransition`), который
переводит движение пальца в процент перехода.

Для **модальных** экранов схема та же, но делегат другой —
`transitioningDelegate` у показываемого экрана (глава 28, раздел
28.12).

**Частые ошибки.**

- **Забыли `completeTransition`** — анимация доиграла, а приложение
  «зависло»: UIKit ждёт сигнала и не принимает касания.
- **Забыли `finalFrame(for:)`** — экран появляется не того размера.
- **Аниматор на pop без интерактивного контроллера** — пропал свайп
  назад.
- **Делегат не удержан.** `navigationController.delegate =
  SomeDelegate()` — объект тут же освободится, и анимация молча
  станет стандартной.

## 26.8 Title view с двумя строками

**Когда применять.** Заголовок и подзаголовок в панели: имя в чате и
статус «в сети», название документа и «изменён 5 минут назад».

В iOS 26 для этого появилось готовое свойство. Для более ранних
версий собираем подзаголовок сами:

```swift
extension ChatViewController {
    func setTitle(name: String, status: String) {
        if #available(iOS 26.0, *) {
            navigationItem.title = name
            navigationItem.subtitle = status
        } else {
            navigationItem.titleView = makeTwoLineTitle(name: name, status: status)
        }
    }

    private func makeTwoLineTitle(name: String, status: String) -> UIView {
        let titleLabel = UILabel()
        titleLabel.text = name
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.textAlignment = .center

        let subtitleLabel = UILabel()
        subtitleLabel.text = status
        subtitleLabel.font = .preferredFont(forTextStyle: .caption1)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.isAccessibilityElement = true
        stack.accessibilityLabel = "\(name), \(status)"
        stack.accessibilityTraits = .header
        return stack
    }
}
```

`#available(iOS 26.0, *)` — проверка версии во время работы: на iOS 26
и новее используем системный подзаголовок, на iOS 15–18 — свою
сборку. Минимальная версия проекта — iOS 15, поэтому без этой
проверки код с `subtitle` не соберётся.

`titleView` принимает любую view и ставит её на место заголовка.
Стек сам сообщает свой размер через Auto Layout: ширину — по самой
длинной строке, высоту — по сумме двух строк. Поэтому оборачивать его
в дополнительный контейнер не нужно.

Шрифты `headline` и `caption1` — стили Dynamic Type: они совпадают с
тем, чем iOS рисует обычный заголовок и мелкие подписи, и
увеличиваются вместе с системным размером текста.

Для VoiceOver стек объявлен одним элементом с меткой «Анна, в сети»
и признаком заголовка — иначе диктор прочитает две строки как две
разрозненные метки.

**Частые ошибки.**

- **Жёсткие размеры шрифта** (`systemFont(ofSize: 16)`) — при крупном
  системном тексте подзаголовок останется мелким.
- **`titleView` без размеров.** Если отдать в `titleView` пустой
  `UIView`, внутри которого стек не прибит ко всем краям, контейнер
  окажется нулевого размера, и заголовок не будет виден.

## 26.9 Nav bar appearance — кастомизация

**Когда применять.** Панель должна быть фирменного цвета, с другим
шрифтом заголовка или без тени снизу.

С iOS 13 внешний вид панели описывает объект
`UINavigationBarAppearance`:

```swift
let appearance = UINavigationBarAppearance()
appearance.configureWithOpaqueBackground()
appearance.backgroundColor = .systemBlue
appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]

let bar = navigationController?.navigationBar
bar?.standardAppearance = appearance
bar?.scrollEdgeAppearance = appearance
bar?.compactAppearance = appearance
bar?.tintColor = .white
```

Первая строка после создания — «базовая заготовка» фона:

- `configureWithOpaqueBackground()` — сплошной непрозрачный фон.
- `configureWithDefaultBackground()` — системный полупрозрачный фон
  с размытием (как в «Настройках»).
- `configureWithTransparentBackground()` — полностью прозрачный, без
  тени.

`titleTextAttributes` и `largeTitleTextAttributes` — оформление
обычного и большого заголовка (цвет, шрифт).

Панель бывает в разных **состояниях**, и на каждое есть свой слот:

- `standardAppearance` — обычное состояние, когда под панелью
  прокручен контент.
- `scrollEdgeAppearance` — когда список прокручен **к самому верху**
  (контент «упирается» в край панели). Это состояние особенно заметно
  с большими заголовками.
- `compactAppearance` — **компактная** панель, пониже: на iPhone в
  горизонтальной ориентации.
- `compactScrollEdgeAppearance` (iOS 15+) — компактная и у края
  прокрутки одновременно.

Что будет, если какой-то слот не задать. `compactAppearance` возьмёт
значение из `standardAppearance` — это безопасно. А вот
`scrollEdgeAppearance` с iOS 15 без явного значения делает фон у края
прокрутки **прозрачным** — это системная версия по умолчанию для всех
панелей. Если задать только `standardAppearance`, панель будет синей
при прокрутке и прозрачной, когда список наверху. Поэтому задавай как
минимум `standardAppearance` и `scrollEdgeAppearance`.

`tintColor` — цвет **кнопок** панели («назад», кнопки справа). Он не
входит в `UINavigationBarAppearance`. Без этой строки на синей панели
останутся синие кнопки, и их не будет видно.

Внешний вид можно задать и отдельному экрану — через
`navigationItem.standardAppearance` и
`navigationItem.scrollEdgeAppearance`. Тогда он действует, только
пока этот экран сверху стопки, и не «протекает» на остальные.

**Частые ошибки.**

- **Задан только `standardAppearance`** — панель прозрачная в верхней
  точке списка.
- **Забыт `tintColor`** — кнопки сливаются с фоном.
- **Настройка панели из дочернего экрана** через
  `navigationController?.navigationBar` меняет её для всей стопки, и
  при возврате назад цвет «прилипает» к предыдущим экранам. Для одного
  экрана используй `navigationItem`.
- **Белый текст на светлом фоне** — проверь контраст: для обычного текста
  относительная яркость светлого цвета должна быть хотя бы в 4,5 раза
  больше, чем тёмного (в формуле есть небольшая поправка, подробно —
  глава 34).

**Упражнение 26.1.** Настрой синюю панель так, как в листинге выше,
но задай только `standardAppearance`. Открой список, прокрути его вниз
и снова к самому верху. Что происходит с цветом панели? Исправь.

**Упражнение 26.2.** В приложении три вкладки, вторая — «Чаты»
внутри `UINavigationController`. Из `ChatsViewController` ты пишешь
`tabBarItem.badgeValue = "3"`, но бейдж не появляется. Почему и как
починить?

## Ответы к упражнениям

**26.1.** Пока список прокручен вниз, панель синяя (работает
`standardAppearance`). Когда список доходит до самого верха, панель
переключается на `scrollEdgeAppearance`. Он не задан, и с iOS 15 фон в
этом состоянии прозрачный: синий исчезает, а белый заголовок
оказывается на белом фоне. Лечение — добавить
`bar?.scrollEdgeAppearance = appearance`.

**26.2.** Вкладка берёт бейдж у экрана, который непосредственно лежит
в `UITabBarController`, — у `UINavigationController`, а не у
`ChatsViewController`. Бейдж надо ставить на
`navigationController?.tabBarItem.badgeValue = "3"` (или
использовать функцию `updateUnreadBadge` из 26.2, которая это
учитывает).

## Что мы выучили

- **`UINavigationController`** — стопка экранов; у каждого экрана своя
  табличка `navigationItem`.
- **Large titles** — `prefersLargeTitles` один раз на всю стопку,
  `largeTitleDisplayMode` на каждом экране; для сжатия панель должна
  знать список (`setContentScrollView`).
- **Бейдж вкладки** ставится на `tabBarItem` того контроллера, что
  лежит во вкладке; `0` → `nil`, больше 99 → «99+».
- **Step indicator** — точки с `CGAffineTransform` (1,4 = на 40%
  крупнее) или `UIProgressView` с дробным делением.
- **Breadcrumbs** — скролл с кнопками, возврат через
  `popToViewController`; текущий уровень неактивен.
- **Кнопка «назад»**: для модального окна — своя `leftBarButtonItem`;
  для стопки — `backButtonTitle`, `backButtonDisplayMode`,
  `setBackIndicatorImage`, чтобы не потерять свайп назад.
- **Push или modal**: смотрю и возвращаюсь — push; выполняю задачу и
  закрываю — modal.
- **Custom transition** — аниматор с `finalFrame(for:)` и
  обязательным `completeTransition`; только для push, чтобы сохранить
  системный свайп назад.
- **Два уровня заголовка** — `navigationItem.subtitle` в iOS 26, стек
  в `titleView` для более ранних версий.
- **`UINavigationBarAppearance`** — задавай минимум `standardAppearance`
  и `scrollEdgeAppearance`, плюс `tintColor` для кнопок.

## Apple Developer Documentation

- [`UINavigationController`](https://developer.apple.com/documentation/uikit/uinavigationcontroller) — стопка экранов с навигационной панелью.
- [`UINavigationBar`](https://developer.apple.com/documentation/uikit/uinavigationbar) — сама панель, `prefersLargeTitles`, слоты внешнего вида.
- [`UINavigationBarAppearance`](https://developer.apple.com/documentation/uikit/uinavigationbarappearance) — описание внешнего вида; `configureWith…Background`, `setBackIndicatorImage(_:transitionMaskImage:)`.
- [`UINavigationItem.largeTitleDisplayMode`](https://developer.apple.com/documentation/uikit/uinavigationitem/largetitledisplaymode-swift.property) — `.always` / `.never` / `.automatic`.
- [`UINavigationItem.backButtonDisplayMode`](https://developer.apple.com/documentation/uikit/uinavigationitem/backbuttondisplaymode-swift.property) — вид системной кнопки «назад» (iOS 14+).
- [`UINavigationItem.titleView`](https://developer.apple.com/documentation/uikit/uinavigationitem/titleview) — слот для произвольной view на месте заголовка.
- [`UINavigationItem.subtitle`](https://developer.apple.com/documentation/uikit/uinavigationitem/subtitle) — подзаголовок в панели (iOS 26+).
- [`UIViewController.setContentScrollView(_:for:)`](https://developer.apple.com/documentation/uikit/uiviewcontroller/setcontentscrollview(_:for:)) — какой список отслеживает панель (iOS 15+).
- [`UITabBarItem.badgeValue`](https://developer.apple.com/documentation/uikit/uitabbaritem/badgevalue) — текст бейджа вкладки.
- [`UIViewControllerAnimatedTransitioning`](https://developer.apple.com/documentation/uikit/uiviewcontrolleranimatedtransitioning) — аниматор перехода с `animateTransition(using:)`.
- [`UINavigationControllerDelegate`](https://developer.apple.com/documentation/uikit/uinavigationcontrollerdelegate) — выдаёт аниматоры для push и pop.
- [`UIPercentDrivenInteractiveTransition`](https://developer.apple.com/documentation/uikit/uipercentdriveninteractivetransition) — интерактивный переход, управляемый пальцем.
- [`UINavigationController.interactivePopGestureRecognizer`](https://developer.apple.com/documentation/uikit/uinavigationcontroller/interactivepopgesturerecognizer) — системный свайп назад от края.
- [HIG — Navigation bars](https://developer.apple.com/design/human-interface-guidelines/navigation-bars) — Apple про заголовки, кнопки и иерархию.
- [HIG — Modality](https://developer.apple.com/design/human-interface-guidelines/modality) — когда показывать экран модально.

→ [Глава 27. Cookbook — типы ячеек](./44-cookbook-cells.md)
