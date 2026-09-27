# Глава 25. Cookbook — поиск и фильтры

Пока список помещается на пару экранов, его листают. Когда строк
становится сотни, человек перестаёт листать и начинает искать: вводит
пару букв, сужает выдачу фильтром, меняет порядок сортировки. Эта глава
собирает рецепты для всего этого: системная строка поиска, пауза перед
поиском, области поиска, недавние запросы, фильтры-«таблетки»,
сортировка, поиск на сервере и подсветка найденного.

Как и вся часть IV, глава — справочник. Каждый рецепт устроен
одинаково: когда применять, минимальный код, частые ошибки,
альтернативы. Читать подряд не обязательно.

> **В каком режиме код.** Все листинги главы проверены компилятором в
> режиме Swift 6 с настройкой Default Actor Isolation = MainActor (так
> настроен учебный проект, см. Введение). В этом режиме каждый тип и
> функция без явных пометок принадлежат **главному актору** (main
> actor) — то есть выполняются на главном потоке, там же, где работает
> весь UIKit. Поэтому в коде ниже нет `DispatchQueue.main.async` вокруг
> обновления таблицы: мы и так на главном потоке.

## Заготовка: список товаров

Все рецепты главы примеряем к одному экрану — списку товаров
магазина. Вот его минимальная версия без поиска:

```swift
struct Product {
    let title: String
    let brand: String
    let price: Int          // цена в тенге, целым числом
}

final class ProductsViewController: UITableViewController {
    var allItems: [Product] = [
        Product(title: "Кофемашина Café Crème", brand: "Delonghi", price: 189_000),
        Product(title: "Кофемолка ручная", brand: "Hario", price: 22_500),
        Product(title: "Чайник электрический", brand: "Xiaomi", price: 14_990),
    ]
    var filtered: [Product] = []
    let searchController = UISearchController(searchResultsController: nil)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Товары"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        filtered = allItems
        setupSearch()                       // напишем в 25.1
    }

    override func tableView(_ tableView: UITableView,
                            numberOfRowsInSection section: Int) -> Int {
        filtered.count
    }

    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let product = filtered[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = product.title
        content.secondaryText = product.brand
        cell.contentConfiguration = content
        return cell
    }
}
```

Главное здесь — **два массива**. `allItems` хранит все товары и никогда
не меняется от поиска: это источник правды. `filtered` — то, что
таблица показывает прямо сейчас. Поиск и фильтры только пересчитывают
`filtered` из `allItems`, а таблица всегда читает `filtered`. Если
держать один массив и выкидывать из него «лишнее», то после стирания
запроса вернуть выкинутое будет неоткуда.

`dequeueReusableCell` берёт ячейку из очереди **переиспользования**:
таблица не создаёт новую ячейку на каждую строку, а берёт ту, что
только что уехала за край экрана, и перенастраивает её (подробно —
глава 12). `defaultContentConfiguration()` — готовый набор «текст +
подпись + картинка» для стандартной ячейки, о нём глава 27.

## 25.1 UISearchController

**Когда применять.** Любой список, в котором человек может что-то
искать: контакты, заметки, товары, настройки.

`UISearchController` — готовый системный «поисковик»: строка ввода,
кнопка «Отменить», анимация появления, затемнение фона. Тебе остаётся
сказать ему, **кого звать** при каждом изменении текста, и
отфильтровать список. Сам класс есть с iOS 8, а встраивать его прямо в
навигационную панель через `navigationItem.searchController` можно с
iOS 11.

**Минимальный код.**

```swift
extension ProductsViewController: UISearchResultsUpdating {
    func setupSearch() {
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Поиск товаров"
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true
    }

    func updateSearchResults(for searchController: UISearchController) {
        let query = (searchController.searchBar.text ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        filtered = query.isEmpty
            ? allItems
            : allItems.filter { $0.title.localizedStandardContains(query) }
        tableView.reloadData()
    }
}
```

Разберём по строкам.

`searchResultsUpdater = self` — назначаем экран «обновлятелем
результатов». Это обычный **делегат**: объект, которому другой объект
поручает часть работы. Похоже на секретаря, который звонит тебе
каждый раз, когда приходит письмо: секретарь (`UISearchController`)
сам следит за строкой, а решение «что показать» принимаешь ты в
`updateSearchResults(for:)`. Метод вызывается на каждое изменение
текста, при активации строки и при нажатии «Отменить».

`UISearchController(searchResultsController: nil)` (в заготовке) —
`nil` значит «отдельного экрана результатов нет, фильтруй в той же
таблице». Если передать сюда другой view controller, поиск будет
показывать результаты в нём, поверх списка. Так делают, когда
результаты выглядят иначе, чем исходный список (например, в
результатах смешаны товары и категории).

`obscuresBackgroundDuringPresentation = false` — по умолчанию
контроллер затемняет содержимое под строкой поиска, пока она активна.
Это нужно, когда результаты показываются на отдельном экране. У нас
результат — та же таблица, и затемнение сделает её недоступной: тап по
строке будет просто закрывать поиск.

`navigationItem.searchController = searchController` — встраиваем
строку в навигационную панель, под заголовок. Экран должен лежать
внутри `UINavigationController`, иначе панели нет и строка не
появится.

`hidesSearchBarWhenScrolling = false` — строка видна всегда. По
умолчанию (`true`) iOS прячет её, когда список прокручен вниз, и
показывает, если потянуть список от верха.

`definesPresentationContext = true` — говорит: «поиск живёт в границах
этого экрана». Без этой строки, если во время поиска открыть карточку
товара, строка поиска может остаться висеть поверх нового экрана.

Теперь фильтр. `trimmingCharacters(in: .whitespacesAndNewlines)`
срезает пробелы по краям: запрос `" кофе"` с случайным пробелом в
начале иначе ничего бы не нашёл. `localizedStandardContains` ищет
подстроку **без учёта регистра и диакритики** и с учётом языка
устройства — так ищет Finder. Сравни:

- `"Кофемашина Café Crème".lowercased().contains("кофе")` → `true`;
- `"Кофемашина Café Crème".lowercased().contains("cafe")` → `false`,
  потому что `é` и `e` — разные символы;
- `"Кофемашина Café Crème".localizedStandardContains("cafe")` → `true`.

**Частые ошибки.**

- **Индекс из `filtered`, данные из `allItems`.** В
  `didSelectRowAt` пишут `allItems[indexPath.row]` — и при активном
  поиске открывается не тот товар. Таблица показывает `filtered`,
  значит и читать надо `filtered[indexPath.row]`.
- **Забыли `obscuresBackgroundDuringPresentation = false`** при
  `searchResultsController: nil` — строки не нажимаются.
- **Поиск с учётом регистра и диакритики.** `contains` ищет
  побайтово-точно: `"Apple"` не находит `"apple"`, `"cafe"` не находит
  `"café"`. Бери `localizedStandardContains` или
  `range(of:options: [.caseInsensitive, .diacriticInsensitive])`.
- **Тяжёлая фильтрация на каждое нажатие.** На паре сотен строк это
  незаметно. На десятках тысяч или при запросе к серверу — нужна пауза
  перед поиском, рецепт 25.2.

**Альтернативы.** Отдельный экран поиска (`searchResultsController`
не `nil`) — когда результаты устроены иначе, чем список. Голый
`UISearchBar` без контроллера — когда строка поиска должна стоять
где-то внутри экрана, а не в навигационной панели; тогда показ, скрытие
и кнопку «Отменить» делаешь сам. Ещё один живой пример поиска — глава
13 (Notes).

## 25.2 Debounced search

**Когда применять.** Поиск дорогой: большой объём данных, сложное
сравнение или запрос к серверу.

**Debounce** (по-русски иногда говорят «антидребезг») — приём «подожди,
пока поток событий затихнет, и только тогда действуй». Бытовая
аналогия — лифт: он не уезжает, пока люди заходят, и каждый новый
вошедший продлевает ожидание. Лифт трогается, только когда в дверях
никого нет пару секунд. У нас «вошедший» — нажатие клавиши, а
«поехать» — выполнить поиск.

Рядом живёт похожий приём — **throttle** («не чаще, чем раз в N
секунд»): он пропускает первое событие сразу, а остальные — не чаще
заданного интервала. Для поиска по вводу обычно нужен именно debounce:
нам важен запрос, который человек допечатал, а не промежуточные.

```swift
final class DebouncedSearchViewController: UITableViewController,
                                           UISearchResultsUpdating {
    private var searchWorkItem: DispatchWorkItem?

    func updateSearchResults(for searchController: UISearchController) {
        let query = searchController.searchBar.text ?? ""
        searchWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.performSearch(query: query)
        }
        searchWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: work)
    }

    private func performSearch(query: String) {
        print("Ищем:", query)
        // фильтруем allItems или идём в сеть
    }
}
```

`DispatchWorkItem` — «задание в конверте»: кусок кода, который можно
отдать очереди на выполнение и **отменить**, пока его не начали.

Как это работает, на числах. Пауза — `0.2` секунды, пятая доля
секунды. Человек набирает «коф»:

| Время  | Событие        | Что происходит                                   |
|--------|----------------|--------------------------------------------------|
| 0,00 с | нажал «к»      | задание «искать "к"» назначено на 0,20 с         |
| 0,12 с | нажал «о»      | задание «к» отменено, «ко» назначено на 0,32 с   |
| 0,25 с | нажал «ф»      | задание «ко» отменено, «коф» назначено на 0,45 с |
| 0,45 с | тишина         | выполняется поиск «коф» — **один** раз           |

Три нажатия — один поиск. Если между нажатиями дольше 0,2 с, поиск
успевает выполниться и для промежуточного запроса, это нормально.

Строки, которые стоит разобрать:

- `searchWorkItem?.cancel()` — отменяем предыдущее задание. `cancel()`
  лишь помечает задание: если очередь до него ещё не дошла, она его
  пропустит. Уже начавшееся задание `cancel()` не прерывает.
- `let query = ...` снаружи замыкания — мы фиксируем текст **на момент
  нажатия**. Замыкание захватит именно это значение.
- `[weak self]` — задание живёт в очереди до 0,2 с. Если за это время
  экран закрыли, слабая ссылка не даст заданию удержать экран в памяти,
  а `self?.` просто ничего не сделает.
- `DispatchQueue.main.asyncAfter` — выполнить на главной очереди через
  заданное время. Главная — потому что `performSearch` потом обновляет
  таблицу.

Сколько ждать: 0,2–0,3 с для локального поиска, 0,3–0,5 с для
сетевого. Меньше — поиск будет срабатывать посреди слова. Больше —
выдача начнёт ощутимо «запаздывать» за вводом.

**Частые ошибки.**

- **Debounce не ускоряет сам поиск.** Он уменьшает **число** поисков,
  но каждый поиск по-прежнему выполняется на главном потоке. Если
  один проход по массиву занимает 100 мс, интерфейс всё так же
  подвиснет на 0,1 с после паузы. Лечится ускорением самого поиска
  (заранее приготовленные строки в нижнем регистре, индекс) или
  выносом его с главного потока.
- **Забыли `cancel()`** — тогда каждое нажатие запускает свой поиск,
  просто с опозданием на 0,2 с. Это уже не debounce, а задержка.

**Альтернативы.** То же самое через `Task` и `Task.sleep` — рецепт
25.7. Для поиска по сети этот вариант удобнее: отмена задачи
автоматически отменяет и сетевой запрос.

**Упражнение 25.1.** Подключи `DebouncedSearchViewController` к
`UISearchController` (как в 25.1) и быстро набери «кофе». Сколько раз
напечатается «Ищем:»? Потом поставь паузу `1.0` и снова набери слово.
Что изменилось для пользователя?

## 25.3 Scope buttons

**Когда применять.** Поиск по разным «полям»: контакты — все / по
имени / по телефону; товары — везде / в названии / в бренде.

**Scope bar** (панель областей поиска) — ряд сегментов под строкой
поиска. Выбранный сегмент задаёт, **где** искать.

```swift
enum SearchScope: Int, CaseIterable {
    case all, title, brand

    var buttonTitle: String {
        switch self {
        case .all:   return "Везде"
        case .title: return "Название"
        case .brand: return "Бренд"
        }
    }

    func matches(_ product: Product, query: String) -> Bool {
        switch self {
        case .all:
            return product.title.localizedStandardContains(query)
                || product.brand.localizedStandardContains(query)
        case .title:
            return product.title.localizedStandardContains(query)
        case .brand:
            return product.brand.localizedStandardContains(query)
        }
    }
}
```

Сначала — перечисление областей. `rawValue` типа `Int` совпадает с
индексом сегмента: 0 — «Везде», 1 — «Название», 2 — «Бренд». Так
индекс из `UISearchBar` превращается в область одной строкой. Логику
«подходит ли товар» кладём прямо в перечисление: одна область — одно
правило.

```swift
extension ProductsViewController: UISearchBarDelegate {
    func setupScopes() {
        searchController.searchBar.scopeButtonTitles =
            SearchScope.allCases.map(\.buttonTitle)
        searchController.searchBar.delegate = self
    }

    func searchBar(_ searchBar: UISearchBar,
                   selectedScopeButtonIndexDidChange selectedScope: Int) {
        applyFilter()
    }

    func applyFilter() {
        let bar = searchController.searchBar
        let query = (bar.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let scope = SearchScope(rawValue: bar.selectedScopeButtonIndex) ?? .all
        filtered = query.isEmpty
            ? allItems
            : allItems.filter { scope.matches($0, query: query) }
        tableView.reloadData()
    }
}
```

`scopeButtonTitles` — подписи сегментов. Пока их нет, панели нет.

По умолчанию `UISearchController` сам показывает панель областей,
когда строка поиска активна, и прячет, когда поиск закрыт. Если
вместо этого написать `searchBar.showsScopeBar = true`, контроллер
переключится в ручной режим: панель будет видна всегда, и прятать её
придётся самому.

`searchBar.delegate = self` — делегат строки поиска сообщает о
нажатиях: смена сегмента, кнопка «Найти» на клавиатуре, «Отменить».
Строку внутри `UISearchController` разрешено делать делегатом своего
экрана, контроллер при этом продолжает работать.

`selectedScopeButtonIndexDidChange` — смена сегмента. Текст не
менялся, поэтому пересчитываем выдачу сами через `applyFilter()`.
Из `updateSearchResults(for:)` тоже зови `applyFilter()` — тогда
правило фильтрации живёт в одном месте.

**Частые ошибки.**

- **Больше трёх-четырёх сегментов.** На узком iPhone подписи
  обрежутся до «Наз…». Если областей много — выбирай область фильтром
  (25.5) или меню.
- **Сегмент поменяли, а выдача старая.** Забыли пересчитать фильтр в
  `selectedScopeButtonIndexDidChange`.

## 25.4 Recent searches

**Когда применять.** Сложный поиск, где люди часто повторяют запросы:
магазин, карты, справочник.

```swift
extension ProductsViewController {
    private static let recentKey = "recentSearches"

    var recentSearches: [String] {
        get { UserDefaults.standard.stringArray(forKey: Self.recentKey) ?? [] }
        set { UserDefaults.standard.set(Array(newValue.prefix(10)),
                                        forKey: Self.recentKey) }
    }

    func saveSearch(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var list = recentSearches
        list.removeAll { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        list.insert(trimmed, at: 0)
        recentSearches = list
    }
}
```

`UserDefaults` — маленькое хранилище «ключ — значение» внутри
приложения. Оно рассчитано на настройки и короткие списки; десяток
строк истории — как раз его масштаб. Хранить там большие данные,
пароли и токены нельзя: для секретов есть Keychain (глава 8).

`recentSearches` — вычисляемое свойство: читает и пишет прямо в
`UserDefaults`. Сеттер отрезает список до 10 элементов: `prefix(10)`
берёт первые десять, остальные пропадают. Новые запросы вставляются
в начало, значит отрезаются самые старые.

`saveSearch` делает три вещи. Срезает пробелы и отбрасывает пустой
запрос. Удаляет из истории **такой же** запрос без учёта регистра:
`caseInsensitiveCompare` вернёт `.orderedSame` для «Кофе» и «кофе» —
иначе история заполнится дублями. И вставляет запрос первым.

**Когда сохранять.** Не на каждое нажатие — иначе в истории окажутся
«к», «ко», «коф». Сохраняй, когда запрос «состоялся»: человек нажал
«Найти» на клавиатуре или открыл товар из результатов.

```swift
extension ProductsViewController {
    var showsRecent: Bool {
        searchController.isActive
            && (searchController.searchBar.text ?? "").isEmpty
            && !recentSearches.isEmpty
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        saveSearch(searchBar.text ?? "")
    }

    func didSelectRecent(at row: Int) {
        let query = recentSearches[row]
        searchController.searchBar.text = query
        applyFilter()
    }
}
```

`showsRecent` — «показываем историю, а не товары»: строка поиска
активна, текст пуст, история не пуста. В `numberOfRowsInSection` и
`cellForRowAt` проверяй этот флаг и отдавай либо
`recentSearches.count` и текст запроса, либо товары. В `didSelectRowAt`
при `showsRecent` зови `didSelectRecent(at:)`: он подставит запрос в
строку и пересчитает выдачу.

`searchBarSearchButtonClicked` — метод `UISearchBarDelegate`, кнопка
«Найти» на клавиатуре. Работает, потому что в 25.3 мы уже назначили
экран делегатом строки.

**Частые ошибки.**

- **Нет кнопки «Очистить историю».** История поиска — личные данные.
  Дай способ её стереть: `recentSearches = []`.
- **История не обновляется на экране.** После `saveSearch` таблицу
  надо перезагрузить, если история сейчас видна.

## 25.5 Filter chips

**Когда применять.** Несколько фильтров одновременно: категория +
цена + бренд. **Chips** («таблетки», «чипсы») — маленькие скруглённые
кнопки в горизонтальную строку над списком. У каждой два состояния:
фильтр не задан («Бренд» со стрелкой вниз) и задан («Hario» с крестиком).

Строку таблеток удобно сделать горизонтальным `UICollectionView`.
Разметка:

```swift
func makeChipsLayout() -> UICollectionViewFlowLayout {
    let layout = UICollectionViewFlowLayout()
    layout.scrollDirection = .horizontal
    layout.estimatedItemSize = UICollectionViewFlowLayout.automaticSize
    layout.minimumLineSpacing = 8
    layout.sectionInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
    return layout
}
```

`scrollDirection = .horizontal` — ячейки идут в ряд и листаются вбок.

`estimatedItemSize = automaticSize` — включает **самоподбор размера**:
ширину каждой таблетки считает Auto Layout по её содержимому. «Все»
получится узкой, «Кофемашины» — широкой.

`minimumLineSpacing = 8` — отступ **между таблетками**. Тут легко
ошибиться. `UICollectionViewFlowLayout` раскладывает ячейки
«линиями». При вертикальной прокрутке линия — это строка, а при
горизонтальной — **столбец**. Наши таблетки стоят в одну строку, то
есть каждая — отдельный столбец, и расстояние между ними задаёт
`minimumLineSpacing`. А `minimumInteritemSpacing` при горизонтальной
прокрутке — расстояние между ячейками **внутри одного столбца**, по
вертикали; в строке таблеток оно ни на что не влияет.

`sectionInset` — поля по краям: первая таблетка начнётся в 16 точках
от левого края экрана, как и текст в ячейках таблицы.

Сама таблетка:

```swift
final class ChipCell: UICollectionViewCell {
    static let reuseID = "ChipCell"
    private let titleLabel = UILabel()
    private let iconView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.layer.cornerRadius = 16
        titleLabel.font = .preferredFont(forTextStyle: .subheadline)
        titleLabel.adjustsFontForContentSizeCategory = true
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(scale: .small)

        let stack = UIStackView(arrangedSubviews: [titleLabel, iconView])
        stack.spacing = 4
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
        ])
        isAccessibilityElement = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) не используется") }

    func configure(title: String, isActive: Bool) {
        titleLabel.text = title
        iconView.image = UIImage(systemName: isActive ? "xmark.circle.fill" : "chevron.down")
        contentView.backgroundColor = isActive ? .systemBlue : .secondarySystemFill
        titleLabel.textColor = isActive ? .white : .label
        iconView.tintColor = titleLabel.textColor
        accessibilityLabel = title
        accessibilityTraits = isActive ? [.button, .selected] : .button
    }
}
```

Разбор:

- Стек «текст + иконка» прибит к `contentView` со всех четырёх сторон.
  Это обязательное условие самоподбора размера: Auto Layout должен
  по цепочке ограничений «дотянуться» от краёв ячейки до содержимого,
  иначе ему не из чего вычислить ширину.
- Высота на числах: у шрифта `subheadline` при стандартном размере
  текста строка около 20 точек, плюс 6 сверху и 6 снизу — таблетка
  высотой около 32 точек. `cornerRadius = 16` — половина высоты, края
  получаются полукруглыми.
- `preferredFont(forTextStyle:)` и `adjustsFontForContentSizeCategory`
  — поддержка **Dynamic Type**: если человек в настройках увеличил
  шрифт, таблетка вырастет вместе с текстом.
- `configure` — единственное место, где задаётся внешний вид. Ячейки
  переиспользуются, поэтому каждое свойство, которое зависит от
  состояния (текст, иконка, цвет), выставляется **в обе стороны**:
  и для активной, и для неактивной. Иначе переиспользованная ячейка
  унесёт синий фон из прошлой жизни.
- `accessibilityTraits` с `.selected` — VoiceOver (экранный диктор для
  незрячих) прочитает «Hario, выбрано, кнопка». Без этого разница
  между активной и неактивной таблеткой видна только глазами.

Поведение по тапу:

```swift
struct FilterChip {
    let name: String            // «Бренд»
    var value: String?          // «Hario» или nil, если фильтр не задан

    var displayTitle: String { value ?? name }
}

final class ChipsController: NSObject, UICollectionViewDelegate {
    var chips: [FilterChip] = [FilterChip(name: "Бренд"), FilterChip(name: "Цена")]
    var onPick: ((Int) -> Void)?        // показать выбор значения
    var onChange: (() -> Void)?         // пересчитать выдачу

    func collectionView(_ collectionView: UICollectionView,
                        didSelectItemAt indexPath: IndexPath) {
        if chips[indexPath.item].value == nil {
            onPick?(indexPath.item)
        } else {
            chips[indexPath.item].value = nil
            collectionView.reloadItems(at: [indexPath])
            onChange?()
        }
    }
}
```

Логика та же, что в любом магазине. У таблетки нет значения — тап
открывает выбор (например, лист со списком брендов, глава 28).
Значение есть — тап сбрасывает фильтр, таблетка перерисовывается, а
выдача пересчитывается. `displayTitle` показывает на таблетке
выбранное значение, а пока его нет — название фильтра.

**Частые ошибки.**

- **Нет видимой разницы «фильтр включён / выключен».** Человек думает,
  что фильтр сброшен, а выдача почему-то короткая. Активная таблетка
  должна отличаться цветом **и** значком, а не одним оттенком.
- **`minimumInteritemSpacing` вместо `minimumLineSpacing`** в
  горизонтальной строке — таблетки слипаются, и непонятно почему.
- **`itemSize = automaticSize`.** `automaticSize` — особое значение
  только для `estimatedItemSize`. В `itemSize` оно превращается в
  бессмысленный размер.
- **Слишком много таблеток.** Если фильтров больше пяти-шести, строка
  уезжает далеко за край. Лучше одна кнопка «Фильтры» и отдельный
  экран со всеми фильтрами и кнопкой «Применить».

**Альтернативы.** Если таблеток три-четыре и они не меняются —
`UIStackView` с кнопками внутри горизонтального `UIScrollView`: меньше
кода, но без переиспользования ячеек. Для длинной строки
переиспользование в `UICollectionView` уже окупается.

**Упражнение 25.2.** В строке шесть таблеток по 90 точек шириной,
`minimumLineSpacing = 8`, `sectionInset` слева и справа по 16. Какая
ширина у всей строки? Поместится ли она без прокрутки на экране
шириной 393 точки (iPhone 16)?

## 25.6 Sort sheet

**Когда применять.** Дать выбор порядка: по дате, по названию, по
цене. Кнопка «Сортировка» открывает список вариантов.

```swift
enum Sort: CaseIterable {
    case dateDesc, dateAsc, nameAsc, priceAsc

    var title: String {
        switch self {
        case .dateDesc: return "По дате (новые)"
        case .dateAsc:  return "По дате (старые)"
        case .nameAsc:  return "По названию (А–Я)"
        case .priceAsc: return "По цене (сначала дешёвые)"
        }
    }
}

final class SortableViewController: UIViewController {
    private let sortButton = UIButton(type: .system)
    private var currentSort: Sort = .dateDesc

    private func showSortSheet() {
        let alert = UIAlertController(title: "Сортировка", message: nil,
                                      preferredStyle: .actionSheet)
        for sort in Sort.allCases {
            alert.addAction(UIAlertAction(title: sort.title, style: .default) { [weak self] _ in
                self?.currentSort = sort
                self?.applySort()
            })
        }
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.popoverPresentationController?.sourceView = sortButton
        alert.popoverPresentationController?.sourceRect = sortButton.bounds
        present(alert, animated: true)
    }

    private func applySort() {
        // пересортировать данные и перезагрузить список
    }
}
```

**Action sheet** — список действий, который выезжает снизу экрана.
Хорош для 3–6 вариантов: больше — и список начнёт прокручиваться.

Цикл по `Sort.allCases` добавляет по кнопке на каждый вариант.
Кнопка со стилем `.cancel` («Отмена») встаёт отдельно, внизу — iOS
ставит её туда сама, в каком бы порядке ты ни добавлял кнопки.

Две строки с `popoverPresentationController` обязательны. На iPad
action sheet показывается не снизу, а **поповером** — облачком со
стрелкой, указывающей на кнопку. Облачку нужно знать, откуда
расти: `sourceView` — view-источник, `sourceRect` — прямоугольник в
его координатах (здесь — вся кнопка). Без этих строк на iPad
приложение **упадёт** при показе. На iPhone `popoverPresentationController`
равен `nil`, и строки с `?.` просто ничего не делают.

У `UIAlertAction` нет публичного способа поставить галочку у текущего
варианта. Встречается совет `setValue(true, forKey: "checked")` — это
обращение к приватному свойству. Его не видно в документации, Apple
может убрать его в любой версии iOS, а приложение с таким кодом рискует
не пройти проверку App Review. Не используй.

Если нужна отметка текущего выбора — бери меню `UIMenu`:

```swift
extension SortableViewController {
    func setupSortMenu() {
        let actions = Sort.allCases.map { sort in
            UIAction(title: sort.title,
                     state: sort == currentSort ? .on : .off) { [weak self] _ in
                self?.currentSort = sort
                self?.applySort()
            }
        }
        sortButton.menu = UIMenu(title: "Сортировка",
                                 options: .singleSelection,
                                 children: actions)
        sortButton.showsMenuAsPrimaryAction = true
    }
}
```

`UIAction` — пункт меню с заголовком и замыканием. Свойство `state`
со значением `.on` рисует у пункта галочку.

`showsMenuAsPrimaryAction = true` — меню открывается обычным тапом по
кнопке. Без этого — только долгим нажатием.

`options: .singleSelection` (iOS 15+) — «в меню может быть включён
только один пункт». Без этой опции есть ловушка: `state` вычисляется
**один раз**, в момент создания меню. Человек выбрал «По цене»,
`currentSort` поменялся, а галочка при новом открытии стоит на
«По дате» — меню-то старое. С `.singleSelection` UIKit сам переносит
галочку на выбранный пункт. Без неё пришлось бы пересобирать меню
после каждого выбора (вызывать `setupSortMenu()` в замыкании).

`Sort` сравнивается через `==` без явного `Equatable`: Swift сам
добавляет сравнение перечислениям без связанных значений.

**Частые ошибки.**

- **Action sheet без `sourceView` на iPad** — падение.
- **Сортировка «не держится».** После перезагрузки данных с сервера
  список приходит в серверном порядке. Применяй `currentSort` каждый
  раз, когда обновляешь данные, а не только в момент выбора.

## 25.7 Live API search (autocomplete)

**Когда применять.** Поиск на сервере: товары, адреса, люди в чате.
Выдача меняется по мере ввода — **autocomplete** («автодополнение»).

```swift
struct ProductDTO: Decodable {
    let title: String
    let brand: String?
    let price: Double
}

struct SearchResponse: Decodable {
    let products: [ProductDTO]
}

enum ProductsAPI {
    static func search(query: String) async throws -> [ProductDTO] {
        var components = URLComponents(string: "https://dummyjson.com/products/search")
        components?.queryItems = [URLQueryItem(name: "q", value: query)]
        guard let url = components?.url else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(SearchResponse.self, from: data).products
    }
}
```

Сначала — сетевой слой. `ProductDTO` описывает товар так, как его
присылает сервер (DTO — «объект для передачи данных», форма ответа
сервера, а не модель приложения). `brand` опциональный: у части
товаров бренда в ответе нет, и без `?` расшифровка упала бы на первом
же таком товаре.

`URLComponents` собирает адрес и сам **экранирует** запрос: пробел
станет `%20`, кириллица — байтами вида `%D0%BA`. Склеивать адрес
строками (`"...?q=" + query`) нельзя — на запросе «кофе машина»
адрес сломается.

`URLSession.shared.data(from:)` — асинхронная загрузка (есть с
iOS 15). `await` значит «здесь функция приостанавливается, пока не
придёт ответ», главный поток при этом свободен и интерфейс не
замирает.

Теперь сам поиск с паузой и отменой:

```swift
final class LiveSearchViewController: UITableViewController,
                                      UISearchResultsUpdating {
    private var results: [ProductDTO] = []
    private var searchTask: Task<Void, Never>?

    func updateSearchResults(for searchController: UISearchController) {
        let query = (searchController.searchBar.text ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        searchTask?.cancel()

        guard query.count >= 2 else {
            results = []
            tableView.reloadData()
            return
        }

        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)   // 0,3 с
            guard !Task.isCancelled else { return }

            let found = try? await ProductsAPI.search(query: query)
            guard !Task.isCancelled, let found else { return }

            self?.results = found
            self?.tableView.reloadData()
        }
    }
}
```

`searchTask?.cancel()` — отменяем предыдущую задачу. Отмена в Swift
**кооперативная**: `cancel()` не убивает задачу, а поднимает флажок
«тебя отменили». Задача сама должна его проверить — отсюда
`Task.isCancelled` ниже.

`guard query.count >= 2` — на одну букву сервер вернёт пол-каталога,
а человек всё равно продолжит печатать. Пустой запрос очищает выдачу.

`Task { ... }` — новая асинхронная задача. В нашем режиме (весь код на
главном акторе) она **наследует** главный актор от места создания. Это
значит, что строки `self?.results = found` и `reloadData()` и так
выполняются на главном потоке — оборачивать их в `MainActor.run` не
нужно.

`Task.sleep(nanoseconds: 300_000_000)` — пауза 0,3 с (300 миллионов
наносекунд; в секунде миллиард наносекунд). Это и есть debounce. Если
за время паузы задачу отменили, `sleep` бросает ошибку отмены и
заканчивается сразу; `try?` эту ошибку глотает. Более удобный
`Task.sleep(for: .milliseconds(300))` появился только в iOS 16, а у нас
минимальная версия — iOS 15.

Первый `guard !Task.isCancelled` — после паузы: если нас отменили, в
сеть не идём.

Второй `guard !Task.isCancelled` — **после ответа сервера**. Без него
возможна гонка. Пример на числах: запрос «ко» ушёл в 0,30 с, сервер
отвечает 1,5 с. В 0,50 с человек допечатал «коф», запрос «коф» ушёл в
0,80 с и вернулся уже в 1,20 с. Ответ на «ко» придёт позже, в 1,80 с,
и без проверки перезапишет свежую выдачу старой. `URLSession` при
отмене задачи обычно прерывает запрос и бросает ошибку, но полагаться
только на это не стоит: проверка флажка стоит одну строку.

`[weak self]` — задача может жить дольше экрана (медленная сеть). Слабая
ссылка не удерживает закрытый экран в памяти.

**Частые ошибки.**

- **Нет проверки после `await`** — старые ответы перетирают новые.
- **Нет отмены при уходе с экрана.** Добавь в `viewWillDisappear`
  строку `searchTask?.cancel()`, чтобы не тратить трафик на выдачу,
  которую уже никто не увидит.
- **Нет состояния ошибки.** `try?` превращает ошибку сети в `nil`, и
  выдача просто не меняется. Для настоящего экрана покажи «Нет
  соединения» (глава 24).

## 25.8 Search highlight

**Когда применять.** Показать, **где** в результате нашлось
совпадение: подсветить «кофе» в «Кофемашина Café Crème».

```swift
func highlight(_ text: String, query: String) -> NSAttributedString {
    let result = NSMutableAttributedString(string: text)
    let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !needle.isEmpty else { return result }

    let source = text as NSString
    var searchRange = NSRange(location: 0, length: source.length)
    while true {
        let found = source.range(of: needle,
                                 options: [.caseInsensitive, .diacriticInsensitive],
                                 range: searchRange)
        if found.location == NSNotFound { break }
        result.addAttributes([
            .backgroundColor: UIColor.systemYellow.withAlphaComponent(0.4),
            .font: UIFont.preferredFont(forTextStyle: .body).withBoldTrait(),
        ], range: found)
        let next = found.location + found.length
        searchRange = NSRange(location: next, length: source.length - next)
    }
    return result
}

extension UIFont {
    func withBoldTrait() -> UIFont {
        guard let descriptor = fontDescriptor.withSymbolicTraits(.traitBold) else {
            return self
        }
        return UIFont(descriptor: descriptor, size: 0)
    }
}
```

`NSMutableAttributedString` — строка, у кусков которой могут быть
свои **атрибуты**: цвет, шрифт, фон. Метки (`UILabel`) и ячейки умеют
такую строку показывать.

Почему `NSString` и `NSRange`, а не обычный `String`: атрибуты
задаются диапазонами в единицах UTF-16 — так строки хранит
Foundation. `(text as NSString).range(of:)` сразу возвращает диапазон
в тех же единицах, и его можно передать в `addAttributes` без
пересчёта.

Цикл нужен, чтобы подсветить **все** вхождения, а не первое. На
числах: в «Кофе и кофемолка» запрос «кофе» найдётся с позиции 0
длиной 4. Второй поиск начинается с позиции 4 и идёт до конца;
второе «кофе» найдётся с позиции 7. Третий поиск вернёт `NSNotFound`
— «не найдено», цикл закончится.

`.caseInsensitive` и `.diacriticInsensitive` — те же правила, что у
поиска в 25.1: «Кофе» подсветится на запрос «кофе», «Café» — на
«cafe». Подсветка должна совпадать с тем, по какому правилу искали,
иначе строка найдётся, а подсвечено в ней ничего не будет.

Подсветка двумя способами — фоном **и** жирным шрифтом. Один только
цвет плохо различают люди с нарушениями цветового зрения, а жирное
начертание видно всем. `withBoldTrait()` — маленькое расширение:
берёт описание шрифта, добавляет признак «жирный» и строит шрифт
заново; `size: 0` значит «размер оставить как был». Шрифт `body`
совпадает с тем, которым ячейка по умолчанию рисует основной текст.

В ячейке используй так:

```swift
var content = cell.defaultContentConfiguration()
content.attributedText = highlight(product.title, query: currentQuery)
cell.contentConfiguration = content
```

**Частые ошибки.**

- **Подсветка по другому правилу, чем поиск.** Искали без учёта
  диакритики, а подсвечиваем с учётом — «Café» в выдаче есть, а
  подсветки нет.
- **Диапазон из `String` в `NSRange` «на глаз».** Эмодзи и некоторые
  символы занимают в UTF-16 две единицы, и позиции из `String.count`
  съезжают. Бери диапазон из того же `NSString`, в котором искал.

**Упражнение 25.3.** Что вернёт `highlight("Кофе и кофемолка", query:
"  КОФЕ ")`: сколько кусков будет подсвечено и с каких позиций они
начинаются? А при `query: ""`?

## Ответы к упражнениям

**25.1.** Если печатать быстро (между нажатиями меньше 0,2 с),
«Ищем:» напечатается один раз — `Ищем: кофе`. Если где-то задержался
дольше 0,2 с, появится и промежуточный запрос, например `Ищем: ко`.
С паузой 1.0 промежуточных запросов почти не будет, но результат
появится через целую секунду после последнего нажатия — для
пользователя поиск станет «задумчивым».

**25.2.** Шесть таблеток: 6 × 90 = 540 точек. Промежутков между ними
пять: 5 × 8 = 40. Поля: 16 + 16 = 32. Итого 540 + 40 + 32 = 612
точек. Это больше 393, так что строка прокручивается: видно примерно
первые три-четыре таблетки, остальные — свайпом влево.

**25.3.** Запрос сначала обрезается до «КОФЕ». Поиск без учёта
регистра найдёт два вхождения: с позиции 0 («Кофе») и с позиции 7
(«кофе» в «кофемолка»), каждое длиной 4. Если запрос пустой (или из
одних пробелов), `guard` вернёт строку без подсветки.

## Что мы выучили

- **`UISearchController`** встраивается в `navigationItem.searchController`;
  с `searchResultsController: nil` фильтруем ту же таблицу и
  выключаем `obscuresBackgroundDuringPresentation`.
- **Два массива**: `allItems` — источник правды, `filtered` — то, что
  на экране. Индексы строк берём из `filtered`.
- **`localizedStandardContains`** ищет без учёта регистра и
  диакритики.
- **Debounce** — ждём паузу во вводе и отменяем прошлое задание:
  `DispatchWorkItem` + `cancel()` или `Task` + `Task.sleep` +
  `Task.isCancelled`. Debounce уменьшает число поисков, но не ускоряет
  каждый.
- **Scope bar** — сегменты «где искать»; смена сегмента требует
  пересчёта выдачи вручную.
- **Recent searches** — 10 последних запросов в `UserDefaults`,
  без дублей, сохраняются по «Найти», а не по каждой букве.
- **Filter chips** — горизонтальный collection view; отступ между
  таблетками задаёт `minimumLineSpacing`; активная таблетка отличается
  цветом, значком и признаком `.selected` для VoiceOver.
- **Сортировка** — action sheet (на iPad обязательно `sourceView`) или
  `UIMenu` с `.singleSelection`, чтобы галочка переезжала сама.
- **Live search** — отмена прошлой задачи и проверка `isCancelled`
  **после** ответа сервера, иначе старый ответ перетрёт новый.
- **Подсветка** — все вхождения, по тем же правилам, что и поиск,
  цветом и жирным шрифтом.

## Apple Developer Documentation

- [`UISearchController`](https://developer.apple.com/documentation/uikit/uisearchcontroller) — стандартный контроллер поиска; крепится к `navigationItem.searchController`.
- [`UISearchBar`](https://developer.apple.com/documentation/uikit/uisearchbar) — сама строка ввода (scope buttons, placeholder, кнопка «Отменить»).
- [`UISearchResultsUpdating`](https://developer.apple.com/documentation/uikit/uisearchresultsupdating) — протокол обновления результатов при каждом изменении текста.
- [`UISearchBarDelegate`](https://developer.apple.com/documentation/uikit/uisearchbardelegate) — «Найти», «Отменить», смена сегмента области поиска.
- [`UINavigationItem.searchController`](https://developer.apple.com/documentation/uikit/uinavigationitem/searchcontroller) — встраивание строки поиска в навигационную панель.
- [`localizedStandardContains(_:)`](https://developer.apple.com/documentation/foundation/nsstring/localizedstandardcontains(_:)) — поиск подстроки без учёта регистра и диакритики.
- [`UICollectionViewFlowLayout`](https://developer.apple.com/documentation/uikit/uicollectionviewflowlayout) — `minimumLineSpacing`, `estimatedItemSize`, `automaticSize`.
- [`UIMenu.Options.singleSelection`](https://developer.apple.com/documentation/uikit/uimenu/options-swift.struct/singleselection) — меню с одним выбранным пунктом (iOS 15+).
- [`UIPopoverPresentationController`](https://developer.apple.com/documentation/uikit/uipopoverpresentationcontroller) — `sourceView` / `sourceRect` для action sheet на iPad.
- [`NSAttributedString.Key.backgroundColor`](https://developer.apple.com/documentation/foundation/nsattributedstring/key/backgroundcolor) — атрибут подсветки совпадения.
- [`Task.sleep(nanoseconds:)`](https://developer.apple.com/documentation/swift/task/sleep(nanoseconds:)) и [`Task.isCancelled`](https://developer.apple.com/documentation/swift/task/iscancelled-swift.type.property) — пауза и проверка отмены.
- [HIG — Searching](https://developer.apple.com/design/human-interface-guidelines/searching) — Apple про паттерны поиска, области поиска и недавние запросы.

→ [Глава 26. Cookbook — навигация и заголовки](./43-cookbook-navigation.md)
