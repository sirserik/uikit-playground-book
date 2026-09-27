# Глава 24. Cookbook — empty / error / offline states

Загрузка закончилась — и не всегда списком данных. Возможных исходов три,
кроме успеха: ничего не пришло (**empty state**, «пустое состояние»), пришла
ошибка (**error state**) и нет интернета (**offline**). Каждый требует своего
экрана. Белый пустой экран в любом из трёх случаев выглядит одинаково —
как поломка.

> **Режим компиляции.** Листинги главы проверены компилятором: Swift 6,
> Default Actor Isolation = MainActor, deployment target iOS 15.0; код с
> `NWPathMonitor` и повторами запроса — ещё и в языковом режиме Swift 5.

## 24.1 EmptyStateView — общий компонент

**Когда применять.** Список без элементов: первый запуск, фильтр ничего не
нашёл, пользователь всё удалил или всё выполнил.

**Минимальный код.** Иконка, заголовок, пояснение и необязательная кнопка —
один компонент на всё приложение:

```swift
final class EmptyStateView: UIView {
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let bodyLabel = UILabel()
    private let actionButton = UIButton(configuration: .filled())
    private let stack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        iconView.tintColor = .tertiaryLabel
        iconView.contentMode = .scaleAspectFit
        iconView.preferredSymbolConfiguration =
            UIImage.SymbolConfiguration(pointSize: 56, weight: .regular)
        iconView.isAccessibilityElement = false          // картинка-украшение

        titleLabel.font = .preferredFont(forTextStyle: .title3)
        titleLabel.textColor = .secondaryLabel
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.adjustsFontForContentSizeCategory = true

        bodyLabel.font = .preferredFont(forTextStyle: .subheadline)
        bodyLabel.textColor = .secondaryLabel
        bodyLabel.textAlignment = .center
        bodyLabel.numberOfLines = 0
        bodyLabel.adjustsFontForContentSizeCategory = true

        actionButton.configuration?.cornerStyle = .capsule
        actionButton.isHidden = true                      // по умолчанию кнопки нет

        for v in [iconView, titleLabel, bodyLabel, actionButton] {
            stack.addArrangedSubview(v)
        }
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 8
        stack.setCustomSpacing(16, after: iconView)
        stack.setCustomSpacing(24, after: bodyLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: safeAreaLayoutGuide.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor, constant: -16),
        ])
    }

    required init?(coder: NSCoder) { fatalError("Создаём только из кода") }

    func configure(iconName: String, title: String, body: String) {
        iconView.image = UIImage(systemName: iconName)
        titleLabel.text = title
        bodyLabel.text = body
    }
}
```

Разберём, что тут важно.

`UIImage.SymbolConfiguration(pointSize: 56)` — SF Symbol рисуется в размере
56 точек: крупно, но не на пол-экрана. `.tertiaryLabel` — третий по яркости
системный цвет текста: иконка видна, но не спорит с заголовком.

`isAccessibilityElement = false` на иконке — картинка-украшение. VoiceOver
пропустит её и сразу прочитает заголовок; иначе он сказал бы «лоток,
изображение» — бесполезный шум.

Шрифты — `preferredFont(forTextStyle:)` с `adjustsFontForContentSizeCategory`:
это **Dynamic Type**, текст растёт вместе с настройкой размера шрифта в
системе. Ранняя версия рецепта задавала `systemFont(ofSize: 18)` и `14` —
такие шрифты не увеличиваются, и пользователю с крупным текстом пустой экран
читать трудно. `numberOfLines = 0` у обоих текстов — при крупном шрифте
заголовок переносится на вторую строку, а не обрезается троеточием.

Оба текста — `.secondaryLabel`. Соблазн взять для пояснения
`.tertiaryLabel` лучше побороть: на белом фоне это серый с низким
контрастом, который плохо читается. Для текста, который надо прочитать, не бери цвет бледнее
`secondaryLabel`.

**Стек** (`UIStackView`) сам раскладывает элементы в столбик. `spacing = 8` —
расстояние между элементами по умолчанию, `setCustomSpacing(16, after:
iconView)` — после иконки отступ больше, `setCustomSpacing(24, after:
bodyLabel)` — ещё больше перед кнопкой: кнопка — отдельное действие, а не
продолжение текста. Скрытая кнопка (`isHidden = true`) в стеке не занимает
места вовсе — стек пропускает скрытые элементы вместе с их отступами.

Стек центрирован по вертикали и растянут по ширине между **layout margins**
(внутренними полями view, по умолчанию 8 точек у обычного view, больше у
экрана VC) плюс ещё 16 точек. На iPhone 16 шириной 393 точки текст займёт
примерно 393 − 2 × (8 + 16) = 345 точек — длинное пояснение перенесётся, а не
прилипнет к краям.

**Частые ошибки.**

- **Один текст на все случаи.** «Ничего не найдено» подходит для пустого
  фильтра, но не для первого запуска. Разные ситуации — разные тексты.
- **Нет подсказки, что делать.** Пустой список — момент научить
  пользователя: «нажми плюс», «сбрось фильтры». Лучше всего — кнопкой (24.2).
- **Пустой экран во время загрузки.** Empty state показываем, только когда
  загрузка **закончилась** и данных правда нет. Пока грузится — скелет или
  спиннер (глава 23), иначе пользователь на секунду увидит «Пока пусто» при
  каждом открытии.

**Варианты по контексту.**

```swift
// Первый запуск
emptyView.configure(iconName: "tray", title: "Пока пусто",
                    body: "Добавь первую задачу — нажми «плюс» внизу.")

// Всё выполнено
emptyView.configure(iconName: "checkmark.seal.fill", title: "Всё выполнено!",
                    body: "Активных задач нет. Можно отдохнуть.")

// Фильтр ничего не нашёл
emptyView.configure(iconName: "magnifyingglass", title: "Не нашлось",
                    body: "Попробуй изменить запрос или сбросить фильтры.")
```

Три разных иконки и тона. «Пока пусто» — нейтрально и с инструкцией. «Всё
выполнено» — похвала, а не пустота. «Не нашлось» — подсказка, как расширить
поиск. (Эмодзи в строке вроде «Можно отдохнуть» не ставим: в
интерфейсе эмодзи зависят от шрифта и плохо читаются VoiceOver'ом — лучше
обойтись текстом или SF Symbol.)

## 24.2 Empty state с call-to-action

**Call-to-action** («призыв к действию») — кнопка, которая прямо говорит, что
делать дальше: «Создать первую задачу».

Кнопка уже лежит в стеке `EmptyStateView` (скрытая). Добавим метод, который
её показывает:

```swift
extension EmptyStateView {
    /// Кнопка «что делать дальше». Передай nil — кнопка спрячется.
    func setAction(title: String?, handler: (() -> Void)? = nil) {
        guard let title, let handler else {
            actionButton.isHidden = true
            return
        }
        actionButton.configuration?.title = title
        // Старый обработчик снимаем, иначе при повторном вызове их станет два.
        actionButton.removeAction(identifiedBy: UIAction.Identifier("empty.cta"), for: .touchUpInside)
        actionButton.addAction(UIAction(identifier: UIAction.Identifier("empty.cta")) { _ in handler() },
                               for: .touchUpInside)
        actionButton.isHidden = false
    }
}
```

(В файле проекта метод лежит прямо в классе: `actionButton` объявлен
`private`, а `private` в Swift виден и в расширениях того же файла.)

`UIAction.Identifier("empty.cta")` — у действия есть имя. Если один и тот же
`EmptyStateView` сначала показал «Создать первую задачу», а потом ещё раз —
без `removeAction(identifiedBy:)` на кнопке висело бы два обработчика, и тап
открыл бы редактор дважды. Действия с одинаковым идентификатором UIKit и сам
заменяет, но явное удаление читается понятнее.

Использование на экране списка:

```swift
final class TodoListDemoViewController: UIViewController {
    private let emptyView = EmptyStateView()

    func showFirstLaunch() {
        emptyView.configure(iconName: "tray", title: "Пока пусто",
                            body: "Добавь первую задачу — нажми «плюс» внизу.")
        emptyView.setAction(title: "Создать первую задачу") { [weak self] in
            self?.openEditor()
        }
    }

    func showAllDone() {
        emptyView.configure(iconName: "checkmark.seal.fill", title: "Всё выполнено!",
                            body: "Активных задач нет. Можно отдохнуть.")
        emptyView.setAction(title: nil)
    }

    private func openEditor() {}
}
```

`[weak self]` — экран держит `emptyView`, тот держит кнопку, кнопка —
замыкание. Сильный `self` в замыкании замкнул бы круг, и экран не
освободился бы после закрытия.

Кнопку нельзя создать снаружи и добавить в `stack`: `stack` —
локальная переменная внутри `init`, снаружи её не видно, и такой код не
соберётся. Поэтому кнопка — часть компонента.

**Упражнение 24.1.** Вызови `setAction(title: "Создать") { print("tap") }`
дважды подряд, но закомментируй строку `removeAction(identifiedBy:)` и
создавай действие **без** идентификатора: `UIAction { _ in handler() }`.
Сколько раз напечатается «tap» на одно нажатие? Ответ — в конце главы.

## 24.3 Error state — иконка ошибки + retry

**Retry** — «повторить попытку».

**Когда применять.** Запрос упал: нет сети, сервер ответил ошибкой, данные не
разобрались. Пользователю нужно понять, что случилось, и дать кнопку
«Повторить».

**Минимальный код.**

```swift
func makeErrorState(onRetry: @escaping () -> Void) -> UIStackView {
    let icon = UIImageView(image: UIImage(systemName: "exclamationmark.icloud.fill"))
    icon.tintColor = .systemRed
    icon.contentMode = .scaleAspectFit
    icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 56)

    let title = UILabel()
    title.text = "Не удалось загрузить"
    title.font = .preferredFont(forTextStyle: .title2)
    title.adjustsFontForContentSizeCategory = true
    title.textAlignment = .center
    title.numberOfLines = 0

    let body = UILabel()
    body.text = "Проверь интернет и попробуй ещё раз."
    body.font = .preferredFont(forTextStyle: .body)
    body.adjustsFontForContentSizeCategory = true
    body.textColor = .secondaryLabel
    body.textAlignment = .center
    body.numberOfLines = 0

    var cfg = UIButton.Configuration.filled()
    cfg.title = "Повторить"
    cfg.cornerStyle = .capsule
    cfg.image = UIImage(systemName: "arrow.clockwise")
    cfg.imagePlacement = .leading
    cfg.imagePadding = 8
    let retry = UIButton(configuration: cfg, primaryAction: UIAction { _ in onRetry() })

    let stack = UIStackView(arrangedSubviews: [icon, title, body, retry])
    stack.axis = .vertical
    stack.alignment = .center
    stack.spacing = 12
    return stack
}
```

Красная иконка «облако с восклицательным знаком», заголовок, пояснение и
кнопка с круговой стрелкой.

`UIButton(configuration:primaryAction:)` (iOS 15+) — кнопка и её действие
одной строкой.

`imagePlacement = .leading` — картинка перед текстом («leading» — со стороны
начала строки: слева в русском, справа в арабском и иврите). `imagePadding
= 8` — 8 точек между стрелкой и словом.

`onRetry` — `@escaping`, потому что замыкание сохраняется внутри кнопки и
вызывается позже, когда функция давно вернулась.

Текст ошибки человеческим языком — из типа ошибки:

```swift
func userMessage(for error: Error) -> String {
    guard let urlError = error as? URLError else { return "Что-то пошло не так. Попробуй ещё раз." }
    switch urlError.code {
    case .notConnectedToInternet, .networkConnectionLost:
        return "Нет интернета. Проверь Wi-Fi или мобильную сеть."
    case .timedOut:
        return "Сервер долго не отвечает. Попробуй чуть позже."
    default:
        return "Сервер недоступен. Попробуй чуть позже."
    }
}
```

`URLError` — ошибка сетевого уровня от `URLSession`. Код
`.notConnectedToInternet` — это тот самый «NSURLErrorDomain −1009», который
иначе увидел бы пользователь.

**Повтор с растущей паузой.** Если повторяешь запрос автоматически — не
подряд. Паузы удваиваются: это **exponential backoff** («экспоненциальная
задержка»):

```swift
// Повтор с растущей паузой: 1 с, 2 с — и после третьей неудачи сдаёмся.
func withRetry<T>(maxAttempts: Int = 3,
                  _ operation: () async throws -> T) async throws -> T {
    var delay: Double = 1
    for attempt in 1...maxAttempts {
        do {
            return try await operation()
        } catch {
            if attempt == maxAttempts { throw error }
            let jitter = Double.random(in: 0...0.3)           // разброс, чтобы клиенты не били синхронно
            try await Task.sleep(nanoseconds: UInt64((delay + jitter) * 1_000_000_000))
            delay *= 2
        }
    }
    fatalError("сюда не доходим: цикл либо вернул значение, либо бросил ошибку")
}
```

Проследим по шагам при трёх попытках:

1. Попытка 1 упала → ждём 1 с (+ случайные 0–0,3 с) → `delay` становится 2.
2. Попытка 2 упала → ждём 2 с (+ 0–0,3 с) → `delay` становится 4.
3. Попытка 3 упала → это последняя, бросаем ошибку наружу, показываем
   error state с кнопкой.

Всего пауз две, суммарно около 3 секунд. Если бы попыток было пять, паузы
были бы 1, 2, 4, 8 — каждая вдвое длиннее предыдущей, вместе 15 секунд.

**Jitter** («дрожание») — случайная добавка к паузе. Представь: сервер упал,
у десяти тысяч пользователей одновременно отвалился запрос. Без разброса все
десять тысяч повторят ровно через 1 с, потом ровно через 2 с — синхронными
волнами, которые мешают серверу подняться. Разброс в 0–0,3 с размазывает
волну.

`Task.sleep(nanoseconds:)` — пауза в наносекундах (1 секунда =
1 000 000 000). Вариант `Task.sleep(for: .seconds(1))` удобнее, но доступен
только с iOS 16, а книга поддерживает iOS 15.

`fatalError` в конце нужен только компилятору: он не может доказать, что цикл
всегда либо вернёт значение, либо бросит ошибку.

**Частые ошибки.**

- **Технический текст.** «The operation couldn't be completed.
  (NSURLErrorDomain error −1009.)» пользователю ничего не говорит.
- **Нет кнопки повтора.** Пользователь видит «ошибка» — и всё, остаётся
  только закрыть приложение.
- **Автоповтор без пауз.** Сервер ответил 500 → клиент тут же повторяет →
  500 → повторяет. Тысячи клиентов в таком цикле сами создают нагрузку,
  которая не даёт серверу подняться. Растущая пауза и потолок попыток
  обязательны.
- **Повтор того, что нельзя повторять.** Запрос «списать деньги» повторять
  автоматически нельзя без защиты на сервере (ключ идемпотентности):
  первый запрос мог дойти, а упал только ответ.

## 24.4 Offline баннер — top-of-screen

**Когда применять.** Связи нет, но есть сохранённые данные (**кеш**). Экран
работает, но пользователь должен знать, что видит не самое свежее.

**Минимальный код.**

```swift
final class OfflineBannerView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .systemOrange
        let label = UILabel()
        label.text = "Нет подключения — показываем сохранённое"
        label.font = .preferredFont(forTextStyle: .footnote)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        label.textColor = .black
        let icon = UIImageView(image: UIImage(systemName: "wifi.slash"))
        icon.tintColor = .black
        icon.setContentHuggingPriority(.required, for: .horizontal)
        let stack = UIStackView(arrangedSubviews: [icon, label])
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 16),
        ])
        isUserInteractionEnabled = false     // тапы проходят сквозь баннер
        isAccessibilityElement = true
        accessibilityLabel = label.text
    }

    required init?(coder: NSCoder) { fatalError("Создаём только из кода") }
}
```

Ранняя версия объявляла только `init()` без `required init?(coder:)`. Такой
класс **не собирается**: если у наследника `UIView` есть свой назначенный
инициализатор, Swift требует и `init(coder:)`. Теперь — стандартная пара
`init(frame:)` + `init?(coder:)`; создаётся как `OfflineBannerView()`
(у `UIView` есть удобный `init()`, который зовёт `init(frame: .zero)`).

Цвет — оранжевый, а не красный: «нет сети» — предупреждение, а не авария;
красный оставим для ошибок. Чёрный текст на `systemOrange` контрастнее
белого.

`setContentHuggingPriority(.required, for: .horizontal)` — **hugging**
(«обнимание») — насколько view сопротивляется растягиванию шире своего
естественного размера. Максимальный приоритет у иконки означает: «растягивать
нельзя, лишнее место отдайте тексту».

Стек по центру, но не ближе 16 точек к краю (`greaterThanOrEqualTo`):
короткий текст по центру, длинный переносится.

`isUserInteractionEnabled = false` — баннер ничего не делает при тапе,
пусть касания проходят к тому, что под ним.

`isAccessibilityElement = true` + `accessibilityLabel` — VoiceOver читает
баннер одной фразой, а не «Wi-Fi, перечёркнуто» + текст по отдельности.

Баннер прикрепляют к `safeAreaLayoutGuide.topAnchor` экрана и показывают или
прячут через `isHidden` или анимацию `alpha`. Узнать о сети помогает
`NWPathMonitor` из фреймворка Network:

```swift
import Network

final class ConnectivityWatcher {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "connectivity")

    /// Вызывается на главном потоке: true — сеть есть.
    var onChange: ((Bool) -> Void)?

    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            let isOnline = path.status == .satisfied
            // Обработчик приходит на фоновой очереди `queue` — прыгаем на главный.
            Task { @MainActor in
                self?.onChange?(isOnline)
            }
        }
        monitor.start(queue: queue)
    }

    func stop() {
        monitor.cancel()
    }
}
```

`NWPathMonitor` сообщает о каждом изменении «пути» в сеть: Wi-Fi появился,
сотовая связь пропала. `monitor.start(queue:)` — обработчик будет вызываться
на **нашей фоновой очереди**, а не на главном потоке. Трогать UI оттуда
нельзя, поэтому внутри — `Task { @MainActor in … }`: «выполни это на главном
потоке». В SDK обработчик объявлен как `@Sendable` — Swift 6 сам не даст
забыть про переход между потоками.

`path.status == .satisfied` — «путь в сеть есть». Возможные значения:
`.satisfied` (есть), `.unsatisfied` (нет), `.requiresConnection` (есть, но
соединение надо поднять — например, VPN по запросу).

Честная оговорка: `.satisfied` означает «есть подключение к сети», а не
«интернет работает». Wi-Fi в кафе без авторизации даст `.satisfied`, а
запросы при этом будут падать. Поэтому баннер «нет сети» — подсказка, а
окончательное слово за ошибкой реального запроса (24.3).

**Частые ошибки.**

- **Баннер не пропадает.** Показали при `.unsatisfied` и забыли спрятать
  при `.satisfied`.
- **UI из фонового обработчика.** `pathUpdateHandler` приходит не на главном
  потоке; прямой вызов `banner.isHidden = false` оттуда — гонка данных.
- **Баннер закрывает навигацию.** Если он лежит поверх навигационной панели и
  принимает касания, кнопка «Назад» перестаёт работать. Наш баннер касания не
  принимает — и всё равно лучше класть его под панелью.

## 24.5 Skeleton vs spinner vs blank — что когда

| Сценарий                          | Что показать                   |
|-----------------------------------|--------------------------------|
| Первое открытие, кеша нет         | Skeleton (глава 23.3)          |
| Повторное открытие, кеш есть      | Кеш сразу + тихое обновление   |
| Pull-to-refresh                   | Индикатор `UIRefreshControl`   |
| Кнопка-действие (вход, отправка)  | Спиннер в кнопке (23.4)        |
| Долгая блокирующая операция       | Overlay с подписью (23.7)      |
| Загрузка закончилась, данных нет  | EmptyStateView (24.1)          |
| Запрос упал                       | Error state + «Повторить»      |
| Нет сети, но есть кеш             | Баннер + кеш (24.4)            |
| Нет сети и нет кеша               | Error state «Нет интернета»    |

Главное правило таблицы: состояние экрана — это **одно** значение. Удобно
завести `enum` и рисовать экран по нему:

```swift
enum ScreenState<Value> {
    case loading
    case loaded(Value)
    case empty
    case failed(String)
}
```

Экран в каждый момент в ровно одном состоянии. Так не бывает «спиннер крутится
поверх сообщения об ошибке» — классического бага, когда состояние разнесено
по трём булевым флагам.

**Упражнение 24.2.** Напиши функцию `render(_ state: ScreenState<[String]>)` для
экрана со списком, `EmptyStateView` и error state. Что она делает в каждом
из четырёх случаев? Ответ — в конце главы.

## 24.6 Empty state для search

Особый случай — пустой результат **поиска**:

```swift
emptyView.configure(iconName: "magnifyingglass",
                    title: "Не нашлось «\(query)»",
                    body: "Попробуй изменить запрос или убрать фильтры.")
```

Покажи **сам запрос** в заголовке — пользователь видит, что искал, и
замечает опечатку («ах, “кросовки” через одну “с”»). Строковая интерполяция
`\(query)` вставляет текст запроса внутрь кавычек-«ёлочек».

Длинный запрос не сломает вёрстку: у заголовка `numberOfLines = 0`, он
перенесётся.

## 24.7 iOS 17+: UIContentUnavailableConfiguration

В iOS 17 Apple добавила готовый пустой экран: `UIContentUnavailableConfiguration`
и свойство `contentUnavailableConfiguration` у `UIViewController`. Система
сама рисует иконку, заголовок, пояснение и кнопку в стиле iOS и сама
центрирует. Есть готовые заготовки `.empty()`, `.loading()` и `.search()`.

Книга поддерживает iOS 15, поэтому код с проверкой версии:

```swift
final class ModernEmptyViewController: UIViewController {
    private var items: [String] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        updateEmptyState()
    }

    private func updateEmptyState() {
        if #available(iOS 17.0, *) {
            if items.isEmpty {
                var config = UIContentUnavailableConfiguration.empty()
                config.image = UIImage(systemName: "tray")
                config.text = "Пока пусто"
                config.secondaryText = "Добавь первую задачу — нажми «плюс» внизу."
                contentUnavailableConfiguration = config
            } else {
                contentUnavailableConfiguration = nil
            }
        } else {
            // iOS 15–16: наш EmptyStateView из 24.1.
        }
    }
}
```

`if #available(iOS 17.0, *)` — ветка выполнится только на iOS 17 и новее; на
iOS 15–16 работает `else` с нашим компонентом. Без проверки проект с
deployment target 15.0 не соберётся: компилятор знает, что API нет на старых
системах. `nil` в `contentUnavailableConfiguration` убирает пустой экран, когда
данные появились.

## Ответы к упражнениям

**Упражнение 24.1.** Два раза: на кнопке висят два обработчика, оба
срабатывают на одно нажатие. С `removeAction(identifiedBy:)` и именованным
действием — ровно один.

**Упражнение 24.2.** Например:

```swift
final class ListScreen: UIViewController {
    private let tableView = UITableView()
    private let emptyView = EmptyStateView()
    private let spinner = UIActivityIndicatorView(style: .large)
    private var errorView: UIView?
    private var rows: [String] = []

    func render(_ state: ScreenState<[String]>) {
        errorView?.removeFromSuperview()
        errorView = nil
        spinner.stopAnimating()
        tableView.isHidden = true
        emptyView.isHidden = true

        switch state {
        case .loading:
            spinner.startAnimating()
        case .loaded(let items):
            rows = items
            tableView.isHidden = false
            tableView.reloadData()
        case .empty:
            emptyView.configure(iconName: "tray", title: "Пока пусто",
                                body: "Добавь первую задачу — нажми «плюс» внизу.")
            emptyView.isHidden = false
        case .failed(let message):
            let error = makeErrorState { [weak self] in self?.render(.loading) }
            view.addSubview(error)
            errorView = error
            _ = message   // покажи message в заголовке ошибки
        }
    }
}
```

Сначала всё прячем, потом показываем ровно то, что нужно состоянию. Поэтому
два состояния одновременно на экране не окажутся.

## Что мы выучили

- **EmptyStateView** — иконка + заголовок + пояснение + необязательная кнопка;
  Dynamic Type, `numberOfLines = 0`, иконка скрыта от VoiceOver.
- Разные пустые состояния — разные тексты: первый запуск, всё выполнено,
  ничего не нашлось (с самим запросом в заголовке).
- **Error state** — человеческий текст по `URLError.code`, кнопка «Повторить».
- **Exponential backoff** — паузы 1, 2, 4… секунды с небольшим случайным
  разбросом и потолок попыток.
- **Offline-баннер** — `NWPathMonitor`, обработчик на фоновой очереди →
  `Task { @MainActor in }`; `.satisfied` не гарантирует работающий интернет.
- Наследник `UIView` со своим инициализатором обязан иметь `init?(coder:)`.
- Состояние экрана — один `enum`, а не набор флагов.
- iOS 17+: `UIContentUnavailableConfiguration` под `#available`.

## Apple Developer Documentation

- [`UIContentUnavailableConfiguration`](https://developer.apple.com/documentation/uikit/uicontentunavailableconfiguration-swift.struct) — системный пустой/загрузочный/поисковый экран (iOS 17+).
- [`contentUnavailableConfiguration`](https://developer.apple.com/documentation/uikit/uiviewcontroller/contentunavailableconfiguration-4b95e) — свойство контроллера для такого экрана (iOS 17+).
- [`UIImage.SymbolConfiguration`](https://developer.apple.com/documentation/uikit/uiimage/symbolconfiguration-swift.class) — размер и вес SF Symbols.
- [`URLError`](https://developer.apple.com/documentation/foundation/urlerror) — коды сетевых ошибок (`notConnectedToInternet`, `timedOut`…).
- [`NWPathMonitor`](https://developer.apple.com/documentation/network/nwpathmonitor) — наблюдение за доступностью сети.
- [`NWPath.Status`](https://developer.apple.com/documentation/network/nwpath/status-swift.enum) — `satisfied`, `unsatisfied`, `requiresConnection`.
- [HIG — Loading](https://developer.apple.com/design/human-interface-guidelines/loading) — Apple о загрузке и переходных состояниях.
- [HIG — Onboarding](https://developer.apple.com/design/human-interface-guidelines/onboarding) — первый запуск и подсказки в пустых экранах.

→ [Глава 25. Cookbook — поиск и фильтры](./42-cookbook-search-filters.md)
