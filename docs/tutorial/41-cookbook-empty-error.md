# Глава 24. Cookbook — empty / error / offline states

После загрузки данных есть **три** возможных результата: ничего не
пришло (empty), пришла ошибка (error), нет интернета (offline). Все
три требуют визуального отклика.

## 24.1 EmptyStateView — общий компонент

**Когда применять.** Список без элементов: первый запуск, фильтр
ничего не нашёл, юзер всё удалил.

**Минимальный код.**

```swift
final class EmptyStateView: UIView {
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let bodyLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        iconView.tintColor = .tertiaryLabel
        iconView.contentMode = .scaleAspectFit
        iconView.preferredSymbolConfiguration =
            UIImage.SymbolConfiguration(pointSize: 56, weight: .regular)

        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = .secondaryLabel
        titleLabel.textAlignment = .center

        bodyLabel.font = .systemFont(ofSize: 14)
        bodyLabel.textColor = .tertiaryLabel
        bodyLabel.textAlignment = .center
        bodyLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [iconView, titleLabel, bodyLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 8
        stack.setCustomSpacing(16, after: iconView)
        // ... pin stack to self ...
    }

    func configure(iconName: String, title: String, body: String) {
        iconView.image = UIImage(systemName: iconName)
        titleLabel.text = title
        bodyLabel.text = body
    }
}
```

Используется в Todo, Notes, Gallery, Weather. Универсальный компонент
с иконкой / заголовком / описанием.

**Частые ошибки.**

- **Один empty state на все случаи.** «Ничего не найдено» подходит
  для пустого фильтра, но не для первого запуска. Делай **разные**
  для разных контекстов.
- **Без call-to-action.** Пустой список — это момент учить юзера.
  Добавь кнопку «Создать первую задачу» (см. ниже).

**Варианты по контексту.**

```swift
// Первый запуск
emptyView.configure(
    iconName: "tray",
    title: "Пока пусто",
    body: "Добавь первую задачу — нажми «плюс» внизу."
)

// Все задачи выполнены
emptyView.configure(
    iconName: "checkmark.seal.fill",
    title: "Всё выполнено!",
    body: "Активных задач нет. Можно отдохнуть ☕"
)

// Фильтр ничего не нашёл
emptyView.configure(
    iconName: "magnifyingglass",
    title: "Не нашлось",
    body: "Попробуй изменить запрос или сбросить фильтры."
)
```

## 24.2 Empty state с call-to-action

Доработка для **первого запуска** — добавляем кнопку:

```swift
let createButton = UIButton(configuration: .filled())
var cfg = UIButton.Configuration.filled()
cfg.title = "Создать первую задачу"
cfg.cornerStyle = .capsule
createButton.configuration = cfg
createButton.addAction(UIAction { [weak self] _ in
    self?.openEditor()
}, for: .touchUpInside)

stack.addArrangedSubview(createButton)
stack.setCustomSpacing(24, after: bodyLabel)
```

Кнопка под body label'ом. Прямая инструкция «что делать дальше».

## 24.3 Error state — иконка ошибки + retry

**Когда применять.** Запрос упал (сеть, сервер, парсинг). Юзеру
нужно дать возможность повторить.

**Минимальный код.**

```swift
let icon = UIImageView(image: UIImage(systemName: "exclamationmark.icloud.fill"))
icon.tintColor = .systemRed
icon.contentMode = .scaleAspectFit

let title = UILabel()
title.text = "Не удалось загрузить"
title.font = .systemFont(ofSize: 20, weight: .heavy)
title.textAlignment = .center

let body = UILabel()
body.text = "Проверь интернет и попробуй ещё раз."
body.textColor = .secondaryLabel
body.textAlignment = .center
body.numberOfLines = 0

var cfg = UIButton.Configuration.filled()
cfg.title = "Повторить"
cfg.cornerStyle = .capsule
cfg.image = UIImage(systemName: "arrow.clockwise")
cfg.imagePlacement = .leading
cfg.imagePadding = 8
let retry = UIButton(configuration: cfg)
```

Красная иконка + заголовок + объяснение + retry-кнопка с круговой
стрелкой.

**Частые ошибки.**

- **Технический текст** — «Network error: NSURLErrorDomain code -1009».
  Юзеру не интересно. Покажи «Нет интернета» или «Сервер недоступен».
- **Без retry.** Юзер видит «ошибка» и стоит. Добавь кнопку.
- **Auto-retry в loop'е.** Сервер вернул 500 → клиент сразу же
  повторяет → 500 → повторяет → DDoS. Делай **exponential backoff**
  (1с, 2с, 4с, 8с) и кэп (≤ 3 попыток).

## 24.4 Offline баннер — top-of-screen

**Когда применять.** Связи нет, но кешированные данные есть. Юзер
должен знать, что данные могут быть устаревшими.

**Минимальный код.**

```swift
final class OfflineBannerView: UIView {
    init() {
        super.init(frame: .zero)
        backgroundColor = UIColor.systemRed.withAlphaComponent(0.92)
        let label = UILabel()
        label.text = "Нет подключения — показываем кеш"
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .white
        let icon = UIImageView(image: UIImage(systemName: "wifi.slash"))
        icon.tintColor = .white
        let stack = UIStackView(arrangedSubviews: [icon, label])
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        addSubview(stack)
        // ... pin to centerX, top/bottom with 8pt padding ...
    }
}
```

Красная плашка с иконкой `wifi.slash` + текст. Прикреплена к
`safeAreaLayoutGuide.top`. См. Главу 15 (Weather) для интеграции с
`NWPathMonitor`.

Появляется/исчезает через `isHidden` или `alpha`.

**Частые ошибки.**

- **Постоянно красный** даже когда WiFi появился. Подпишись на
  `NWPathMonitor` и убирай баннер при восстановлении.
- **Блокирует тапы.** Если баннер съел тап по navbar — расскажи UIKit
  что он не нужен через `isUserInteractionEnabled = false` (или
  вешай баннер ниже navbar).

## 24.5 Skeleton vs spinner vs blank — что когда

| Сценарий                          | Что показать                  |
|-----------------------------------|-------------------------------|
| Первый запуск, нет кеша           | Skeleton (создаёт ожидание)   |
| Reload с кешем                    | Спиннер сверху + старые данные|
| Pull-to-refresh                   | Refresh control индикатор     |
| Action button (login, send)       | Спиннер в кнопке              |
| Долгая операция (5+ сек)          | Loading overlay с прогрессом  |
| Пустой результат                  | EmptyStateView                |
| Ошибка                            | Error state + retry           |
| Нет сети                          | OfflineBannerView сверху      |

## 24.6 Empty state для search

Особый случай — пустой результат **поиска**:

```swift
emptyView.configure(
    iconName: "magnifyingglass",
    title: "Не нашлось «\(query)»",
    body: "Попробуй изменить запрос или убрать фильтры."
)
```

Покажи **сам query** в подзаголовке — юзер видит, что он искал.
Полезно если он сам не помнит, что вводил («ах, опечатка»).

## 📋 Что мы выучили

- **EmptyStateView** — универсальный компонент: иконка + заголовок +
  body, по желанию call-to-action.
- **Разный контент** для разных пустых состояний (первый запуск,
  пустой фильтр, всё выполнено).
- **Error state** — красная иконка + retry-кнопка. Exponential
  backoff против DDoS.
- **OfflineBannerView** — красная плашка сверху, подключается через
  `NWPathMonitor`.
- **Сравнительная таблица** — какое состояние когда показывать.

## Apple Developer Documentation

- [`UIContentUnavailableConfiguration`](https://developer.apple.com/documentation/uikit/uicontentunavailableconfiguration) — системный API для empty / loading / error state'ов (iOS 17+); содержит готовые `.empty()`, `.loading()`, `.search()`.
- [`UIViewController.contentUnavailableConfiguration`](https://developer.apple.com/documentation/uikit/uiviewcontroller/4202955-contentunavailableconfiguration) — слот контроллера для подсовывания unavailable-конфигурации (iOS 17+); до этого — `EmptyStateView` вручную.
- [`UIImage.SymbolConfiguration`](https://developer.apple.com/documentation/uikit/uiimage/symbolconfiguration) — настройка SF Symbols (размер, вес, иерархия).
- [`Network/NWPathMonitor`](https://developer.apple.com/documentation/network/nwpathmonitor) — отслеживание доступности сети для offline-баннера.
- [`Network/NWPath.Status`](https://developer.apple.com/documentation/network/nwpath/status-swift.enum) — состояние пути (`satisfied`, `unsatisfied`, `requiresConnection`).
- [HIG — Loading](https://developer.apple.com/design/human-interface-guidelines/loading) — Apple о пустых и переходных состояниях.
- [HIG — Onboarding](https://developer.apple.com/design/human-interface-guidelines/onboarding) — про первый запуск и call-to-action в пустом состоянии.

→ [Глава 25. Cookbook: поиск и фильтры](./42-cookbook-search-filters.md)
