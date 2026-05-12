# Глава 26. Cookbook — навигация и заголовки

Паттерны вокруг `UINavigationController`, nav-бара, переходов между
экранами.

## 26.1 Large titles + scroll fade

**Когда применять.** Главные экраны приложения (как в iOS Settings,
Apple Music). Заголовок большой сверху, превращается в обычный при
scroll'е.

```swift
navigationController?.navigationBar.prefersLargeTitles = true
navigationItem.largeTitleDisplayMode = .always
title = "Главная"
```

Принцип:

- `prefersLargeTitles` — включаем в navigation controller'е.
- `largeTitleDisplayMode = .always` — этот VC показывает large title
  (можно `.never` чтобы пропустить).
- `title` — сам текст.

iOS сама делает анимацию свёртывания при scroll вниз.

**Частые ошибки.**

- **Включил `prefersLargeTitles` после загрузки.** Иногда требует
  перерисовки. Делай в `viewDidLoad`, не в `viewDidAppear`.
- **Large title скрывается слишком рано.** Если у тебя сложный
  scroll (например, stretchy header в Главе 21), large titles
  ломаются. Используй `.never` и сам управляй размером текста.

## 26.2 Tab bar badges

**Когда применять.** Уведомление о новых элементах в табе (новые
сообщения, обновления).

```swift
// Через UITabBarController
tabBarController?.tabBar.items?[1].badgeValue = "3"

// Сбросить
tabBarController?.tabBar.items?[1].badgeValue = nil
```

`badgeValue: String?` — текст badge'а. Обычно цифра, но можно
emoji или короткий текст.

iOS сам рендерит красный кружок справа от иконки.

**Частые ошибки.**

- **Slowly updating badge.** Если число приходит асинхронно — обновляй
  badge через notification или Combine-подписку. Не забывай сбросить
  в `viewDidAppear` (юзер увидел — значит прочитал).

## 26.3 Step indicator

**Когда применять.** Wizard / onboarding со чёткими шагами:
«Регистрация: 2 из 4».

```swift
final class StepIndicatorView: UIView {
    private let totalSteps: Int
    private var currentStep: Int = 0
    private var dots: [UIView] = []

    init(totalSteps: Int) {
        self.totalSteps = totalSteps
        super.init(frame: .zero)
        setupDots()
    }

    private func setupDots() {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        for _ in 0..<totalSteps {
            let dot = UIView()
            dot.backgroundColor = UIColor.tertiaryLabel
            dot.layer.cornerRadius = 4
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.widthAnchor.constraint(equalToConstant: 8).isActive = true
            dot.heightAnchor.constraint(equalToConstant: 8).isActive = true
            dots.append(dot)
            stack.addArrangedSubview(dot)
        }
        addSubview(stack)
        // ... pin ...
    }

    func setCurrentStep(_ step: Int) {
        currentStep = step
        for (i, dot) in dots.enumerated() {
            UIView.animate(withDuration: 0.2) {
                dot.backgroundColor = i <= step ? .systemBlue : UIColor.tertiaryLabel
                dot.transform = i == step
                    ? CGAffineTransform(scaleX: 1.4, y: 1.4)
                    : .identity
            }
        }
    }
}
```

Точки. Активная — увеличена и синяя. Пройденные — синие. Будущие —
серые.

Альтернативно: тонкая полоса с заполнением (`UIProgressView`):

```swift
let progress = UIProgressView(progressViewStyle: .bar)
progress.progress = Float(currentStep + 1) / Float(totalSteps)
```

## 26.4 Breadcrumbs

**Когда применять.** Иерархическая навигация: «Главная → Электроника →
Смартфоны → Apple iPhone». В iOS редко, но иногда оправдано (admin-
панели, файловые менеджеры).

```swift
private func setupBreadcrumbs(_ path: [String]) {
    let scrollView = UIScrollView()
    scrollView.showsHorizontalScrollIndicator = false
    let stack = UIStackView()
    stack.axis = .horizontal
    stack.spacing = 4
    scrollView.addSubview(stack)

    for (i, name) in path.enumerated() {
        let button = UIButton(type: .system)
        button.setTitle(name, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
        button.addAction(UIAction { [weak self] _ in
            self?.navigateBack(toLevel: i)
        }, for: .touchUpInside)
        stack.addArrangedSubview(button)

        if i < path.count - 1 {
            let separator = UILabel()
            separator.text = "›"
            separator.textColor = .secondaryLabel
            stack.addArrangedSubview(separator)
        }
    }
}
```

Горизонтальный scroll с кнопками. Тап — `popToViewController(...)`
до нужного уровня.

## 26.5 Custom back button

**Когда применять.** Замена стандартной back-кнопки на свою иконку
или текст.

```swift
override func viewDidLoad() {
    super.viewDidLoad()
    let backButton = UIBarButtonItem(
        image: UIImage(systemName: "xmark"),
        style: .plain,
        target: self,
        action: #selector(closeTapped)
    )
    navigationItem.leftBarButtonItem = backButton
}

@objc private func closeTapped() {
    dismiss(animated: true)
}
```

`navigationItem.leftBarButtonItem` — замещает back-button (стандартный
исчезает).

Для модального экрана обычно `xmark` (закрыть). Для push'а на детальный
— стандартный chevron.

**Частые ошибки.**

- **Сломал swipe-back.** Кастомный leftBarButtonItem **отключает**
  swipe-back-жест. Восстановить: `navigationController?
  .interactivePopGestureRecognizer?.delegate = nil`.

## 26.6 Modal vs push — когда какой

| Сценарий                          | Способ показа          |
|-----------------------------------|------------------------|
| Деталка из списка                 | push                   |
| Создание нового элемента          | modal sheet (medium)   |
| Редактирование настройки          | push (внутри Settings) |
| Авторизация                       | modal fullScreen       |
| Подтверждение действия            | UIAlertController      |
| Share                             | UIActivityViewController |
| Quick action (несколько опций)    | UIAlertController(.actionSheet) или UIMenu |

**Правило большого пальца:** если **возвращаешься назад без действия**
(просто чтобы посмотреть и вернуться) — `push`. Если **выполняешь
действие и закрываешь** (создаёшь / редактируешь / соглашаешься) —
`modal`.

## 26.7 Custom transitions

**Когда применять.** Когда стандартного `pushViewController(animated:
true)` мало. Например, hero animation — миниатюра «вырастает» до
полноэкранной.

```swift
class CustomTransition: NSObject, UIViewControllerAnimatedTransitioning {
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        0.4
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let to = transitionContext.viewController(forKey: .to),
              let toView = transitionContext.view(forKey: .to) else {
            transitionContext.completeTransition(false)
            return
        }
        let container = transitionContext.containerView
        container.addSubview(toView)
        toView.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
        toView.alpha = 0
        UIView.animate(withDuration: 0.4, delay: 0,
                       usingSpringWithDamping: 0.7,
                       initialSpringVelocity: 0.3) {
            toView.transform = .identity
            toView.alpha = 1
        } completion: { _ in
            transitionContext.completeTransition(true)
        }
    }
}

// Подключаем
extension MyNavController: UINavigationControllerDelegate {
    func navigationController(_ navigationController: UINavigationController,
                              animationControllerFor operation: UINavigationController.Operation,
                              from fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return CustomTransition()
    }
}
```

Создаём свой `Transitioning`, подключаем через `delegate` nav-controller'а.

Для **modal** — `transitioningDelegate` на presented VC, отдельные
методы `animationController(forPresented:)` и
`animationController(forDismissed:)`.

**Частые ошибки.**

- **Забыли `completeTransition(true)`.** iOS «зависает» —
  навигация не завершена.
- **Сложно с interactivity** (swipe-to-dismiss). Нужен ещё
  `interactionController` + `UIPercentDrivenInteractiveTransition`.

## 26.8 Title view с двумя строками

**Когда применять.** Заголовок + подзаголовок в nav-баре (название
чата + статус «онлайн»).

```swift
private func setupTitleView(name: String, status: String) {
    let container = UIView()
    let title = UILabel()
    title.text = name
    title.font = .systemFont(ofSize: 16, weight: .semibold)
    title.textAlignment = .center
    let subtitle = UILabel()
    subtitle.text = status
    subtitle.font = .systemFont(ofSize: 12)
    subtitle.textColor = .secondaryLabel
    subtitle.textAlignment = .center
    let stack = UIStackView(arrangedSubviews: [title, subtitle])
    stack.axis = .vertical
    stack.alignment = .center
    stack.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(stack)
    // ... pin ...
    navigationItem.titleView = container
}
```

`navigationItem.titleView` принимает любой `UIView`. Размер
подгоняется автоматически.

## 26.9 Nav bar appearance — кастомизация

iOS 13+ через `UINavigationBarAppearance`:

```swift
let appearance = UINavigationBarAppearance()
appearance.configureWithOpaqueBackground()
appearance.backgroundColor = .systemBlue
appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]

navigationController?.navigationBar.standardAppearance = appearance
navigationController?.navigationBar.scrollEdgeAppearance = appearance
navigationController?.navigationBar.compactAppearance = appearance
```

Три аппеаранса:
- `standardAppearance` — обычное положение.
- `scrollEdgeAppearance` — когда content прижат к верху (для
  large titles).
- `compactAppearance` — на landscape iPhone (узкий nav bar).

Установи все три, иначе при scroll'е появится разный цвет.

`configureWithOpaqueBackground()` — solid, не translucent.
`configureWithTransparentBackground()` — прозрачный.
`configureWithDefaultBackground()` — translucent с системным material.

## 📋 Что мы выучили

- **Large titles** — `prefersLargeTitles = true` +
  `largeTitleDisplayMode`.
- **Tab bar badges** — `badgeValue: String?` на `UITabBarItem`.
- **Step indicator** — точки или прогресс-бар, разный визуальный
  state.
- **Breadcrumbs** — горизонтальный scroll с кнопками-уровнями (редко
  в iOS).
- **Custom back button** через `navigationItem.leftBarButtonItem` —
  ломает swipe-back, восстанавливать через
  `interactivePopGestureRecognizer.delegate = nil`.
- **Modal vs push** — таблица паттернов.
- **Custom transitions** через `UIViewControllerAnimatedTransitioning`.
- **Two-line title view** — `UIStackView` в `navigationItem.titleView`.
- **`UINavigationBarAppearance`** — обязательно все три аппеаранса
  (standard, scrollEdge, compact).

→ [Глава 27. Cookbook: разные типы ячеек](./44-cookbook-cells.md)
