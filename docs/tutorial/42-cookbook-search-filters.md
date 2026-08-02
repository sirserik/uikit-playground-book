# Глава 25. Cookbook — поиск и фильтры

Поиск, фильтрация, сортировка — основа работы со списками.

## 25.1 UISearchController

**Когда применять.** Любой список, в котором юзер может что-то
искать. Стандартный паттерн с iOS 8.

**Минимальный код.**

```swift
private let searchController = UISearchController(searchResultsController: nil)

override func viewDidLoad() {
    super.viewDidLoad()
    searchController.searchResultsUpdater = self
    searchController.obscuresBackgroundDuringPresentation = false
    searchController.searchBar.placeholder = "Поиск"
    navigationItem.searchController = searchController
    navigationItem.hidesSearchBarWhenScrolling = false
    definesPresentationContext = true
}

extension MyVC: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        let query = searchController.searchBar.text ?? ""
        filtered = allItems.filter { $0.title.lowercased().contains(query.lowercased()) }
        tableView.reloadData()
    }
}
```

`navigationItem.searchController` — встраивает search bar в nav-area.

`searchResultsController: nil` — фильтруем **в той же** таблице, не
показываем отдельный экран результатов.

`hidesSearchBarWhenScrolling = false` — поисковая строка всегда
видна. По умолчанию iOS прячет её при scroll'е.

**Частые ошибки.**

- **Поиск на каждое нажатие без debounce.** На 10 000 элементов —
  тормозит. Делай debounce 200ms.
- **Регистр-зависимый поиск.** `"Apple"` не находит `"apple"`.
  Используй `.lowercased()` или `range(of:options: [.caseInsensitive])`.
- **Поиск с диакритикой.** `"café"` не находит `"cafe"`. Используй
  `options: [.diacriticInsensitive]`.

## 25.2 Debounced search

**Когда применять.** Поиск тяжёлый (большой объём, сетевой запрос).

```swift
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
```

Каждый раз новый work-item, старый отменяется. 200ms — обычная
пауза, чтобы юзер успел перестать печатать.

## 25.3 Scope buttons

**Когда применять.** Поиск по разным «полям». Например, контакты:
все / по имени / по телефону.

```swift
searchController.searchBar.scopeButtonTitles = ["Все", "Имена", "Телефоны"]
searchController.searchBar.showsScopeBar = true
searchController.searchBar.delegate = self

extension MyVC: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) {
        applyFilter()
    }
}
```

Сегмент над списком, под search bar'ом. Активный scope участвует в
`applyFilter()`.

## 25.4 Recent searches

**Когда применять.** Сложный поиск (например, по магазину). Юзер
часто повторяет запросы.

```swift
private var recentSearches: [String] {
    get { UserDefaults.standard.stringArray(forKey: "recentSearches") ?? [] }
    set { UserDefaults.standard.set(Array(newValue.prefix(10)), forKey: "recentSearches") }
}

private func saveSearch(_ query: String) {
    let trimmed = query.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return }
    var list = recentSearches
    list.removeAll { $0.lowercased() == trimmed.lowercased() }
    list.insert(trimmed, at: 0)
    recentSearches = list
}
```

При активном фокусе search bar'а **без текста** — показываем список
recent. Тап по элементу — заполняет search bar и запускает поиск.

`Array(newValue.prefix(10))` — храним последние 10. Дальше отрезаем.

## 25.5 Filter chips

**Когда применять.** Несколько одновременных фильтров (категория +
ценовой диапазон + бренд).

```swift
// UICollectionView с одной горизонтальной строкой chips
let layout = UICollectionViewFlowLayout()
layout.scrollDirection = .horizontal
layout.itemSize = UICollectionViewFlowLayout.automaticSize
layout.estimatedItemSize = CGSize(width: 100, height: 32)
layout.minimumInteritemSpacing = 8
```

Каждый chip — `UIButton` с rounded background и иконкой `xmark.circle.fill`
(закрыть) или `chevron.down` (открыть picker).

При тапе:
- Если у chip'а нет значения — показать picker (sheet с опциями).
- Если есть — сбросить значение.

**Частые ошибки.**

- **Нет visible-state «активный фильтр».** Юзер думает «фильтр сброшен»,
  а он включен.
- **Слишком много chips.** Если фильтров 10+ — лучше отдельный экран
  «Все фильтры» с кнопкой «Применить».

## 25.6 Sort sheet

**Когда применять.** Дать юзеру выбор порядка сортировки. Кнопка
«сортировка» открывает sheet с вариантами.

```swift
let alert = UIAlertController(title: "Сортировка", message: nil, preferredStyle: .actionSheet)
let options: [(String, Sort)] = [
    ("По дате (новые)", .dateDesc),
    ("По дате (старые)", .dateAsc),
    ("По названию (A-Z)", .nameAsc),
    ("По цене (мин-макс)", .priceAsc),
]
for (title, sort) in options {
    alert.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
        self?.currentSort = sort
        self?.applyFilter()
    })
}
alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
present(alert, animated: true)
```

`actionSheet` хорош для 3-6 опций. Больше — отдельный picker-screen.

У `UIAlertAction` нет публичного способа поставить галочку у текущей
опции (есть только приватный `setValue(true, forKey: "checked")` — его
использовать **нельзя**: это не public API, ревью может отклонить, и в
любой версии iOS оно может отвалиться).

Если нужна отметка текущего выбора — бери `UIMenu`: у `UIAction` есть
публичное свойство `state`, и `.on` рисует галочку само:

```swift
let actions = options.map { title, sort in
    UIAction(title: title,
             state: sort == currentSort ? .on : .off) { [weak self] _ in
        self?.currentSort = sort
        self?.applyFilter()
    }
}
sortButton.menu = UIMenu(title: "Сортировка", children: actions)
sortButton.showsMenuAsPrimaryAction = true
```

## 25.7 Live API search (autocomplete)

**Когда применять.** Поиск с сервера (товары, адреса, юзеры в чате).

```swift
private var searchTask: Task<Void, Never>?

func updateSearchResults(for searchController: UISearchController) {
    let query = searchController.searchBar.text ?? ""
    searchTask?.cancel()
    searchTask = Task { [weak self] in
        try? await Task.sleep(nanoseconds: 200_000_000)  // debounce
        guard !Task.isCancelled else { return }
        guard let results = try? await API.search(query: query) else { return }
        await MainActor.run {
            self?.results = results
            self?.tableView.reloadData()
        }
    }
}
```

`searchTask?.cancel()` — отменяем предыдущий, если новый запрос
пришёл быстрее.

`Task.sleep` для debounce, потом `Task.isCancelled` check — если за
200ms пришёл новый input, мы отменены, не делаем сетевой запрос.

## 25.8 Search highlight

**Когда применять.** Выделить найденную часть в результате —
например, **подсветить** слово в названии.

```swift
func highlight(_ text: String, query: String) -> NSAttributedString {
    let attributed = NSMutableAttributedString(string: text)
    let range = (text as NSString).range(of: query, options: [.caseInsensitive])
    if range.location != NSNotFound {
        attributed.addAttributes([
            .backgroundColor: UIColor.systemYellow.withAlphaComponent(0.4),
            .foregroundColor: UIColor.label
        ], range: range)
    }
    return attributed
}
```

Жёлтый highlight на найденной подстроке. Используй в `cellForRowAt`:

```swift
cell.titleLabel.attributedText = highlight(item.title, query: currentQuery)
```

## 📋 Что мы выучили

- **`UISearchController`** в `navigationItem.searchController`,
  фильтр в той же таблице через `searchResultsController: nil`.
- **Debounce** через `DispatchWorkItem` или `Task` с
  `Task.sleep` + `Task.isCancelled` check.
- **Scope buttons** — сегмент над списком для разных полей поиска.
- **Recent searches** в UserDefaults, последние 10 запросов.
- **Filter chips** — горизонтальный collection с кнопками, активные
  имеют visible-state.
- **Sort sheet** через `UIAlertController(.actionSheet)`.
- **Live API search** с отменой предыдущего запроса.
- **Highlight** найденной подстроки через `NSMutableAttributedString`.

## Apple Developer Documentation

- [`UISearchController`](https://developer.apple.com/documentation/uikit/uisearchcontroller) — стандартный контроллер поиска; крепится к `navigationItem.searchController`.
- [`UISearchBar`](https://developer.apple.com/documentation/uikit/uisearchbar) — сама строка ввода (scope buttons, placeholder, кнопки cancel/bookmarks).
- [`UISearchResultsUpdating`](https://developer.apple.com/documentation/uikit/uisearchresultsupdating) — протокол обновления результатов при каждом изменении текста.
- [`UISearchBarDelegate`](https://developer.apple.com/documentation/uikit/uisearchbardelegate) — клики по cancel, scope-сегментам, начало/окончание редактирования.
- [`UINavigationItem.searchController`](https://developer.apple.com/documentation/uikit/uinavigationitem/2897305-searchcontroller) — встраивание search bar в навигационную область.
- [`NSAttributedString.Key.backgroundColor`](https://developer.apple.com/documentation/foundation/nsattributedstring/key/backgroundcolor) — атрибут подсветки совпадения.
- [`String.range(of:options:)`](https://developer.apple.com/documentation/swift/string) — поиск с `caseInsensitive` и `diacriticInsensitive`.
- [`Task.sleep(nanoseconds:)`](https://developer.apple.com/documentation/swift/task/sleep(nanoseconds:)) и [`Task.isCancelled`](https://developer.apple.com/documentation/swift/task/iscancelled-swift.type.property) — для debounce и отмены прошлого запроса.
- [HIG — Searching](https://developer.apple.com/design/human-interface-guidelines/searching) — Apple про паттерны поиска, scope-баров, recent searches.

→ [Глава 26. Cookbook: навигация и заголовки](./43-cookbook-navigation.md)
