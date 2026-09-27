# Глава 42. Production: widgets + App Intents

Виджеты и App Intents — два способа, которыми приложение работает **вне**
своего окна: на главном экране и экране блокировки, в Spotlight, в Siri,
в приложении «Команды» (Shortcuts).

Это обзорная глава: у каждого фреймворка десятки возможностей, мы
разбираем минимально рабочий путь для Todo из главы 12 — виджет со
списком задач, действие «Создать задачу» для Siri и кнопку-галочку прямо
на виджете. Весь код ниже проверен компилятором Swift 6.3 (Xcode 26.5)
в режиме Swift 6 с минимальной версией iOS 15; где API новее, это
отмечено `@available`.

Версии iOS, на которые стоит опираться (по документации Apple):

| Возможность                                   | Минимальная iOS |
|-----------------------------------------------|-----------------|
| Виджеты на главном экране (WidgetKit)         | 14              |
| Виджеты на экране блокировки (`accessory…`)   | 16              |
| App Intents (Siri, Команды, Spotlight)        | 16              |
| Live Activities                               | 16.1            |
| `Activity.request(…content:pushType:)`        | 16.2            |
| Интерактивные виджеты (`Button(intent:)`)     | 17              |
| Настраиваемые виджеты на App Intents          | 17              |
| StandBy (виджеты при зарядке в альбомной ориентации) | 17       |
| Виджеты-переключатели в Пункте управления (Controls) | 18       |

## 42.1 WidgetKit — что такое виджет

**Виджет** — маленькая карточка на главном экране или экране блокировки,
которая показывает данные твоего приложения. Главное, что нужно понять:
виджет — **не** работающее мини-приложение. Это заранее подготовленная
картинка. Система время от времени просит твой код: «дай, что показывать
сейчас и в ближайшие часы», сохраняет ответ и рисует его, не запуская
приложение.

Аналогия — табло расписания на вокзале. Табло не спрашивает у каждого
поезда, где он сейчас; диспетчер заранее вывешивает расписание, а табло
просто показывает нужную строку по времени.

Интерфейс виджета пишется **только на SwiftUI**, даже если приложение
целиком на UIKit, как у нас. Пугаться не надо: виджет — это несколько
`Text` и `VStack`, их синтаксис читается с первого взгляда.

Виды виджетов:

- **Главный экран** (iOS 14+) — размеры `systemSmall`, `systemMedium`,
  `systemLarge`; на iPad ещё `systemExtraLarge`.
- **Экран блокировки** (iOS 16+) — `accessoryCircular`,
  `accessoryRectangular`, `accessoryInline`.
- **StandBy** (iOS 17+) — iPhone на зарядке в альбомной ориентации
  показывает `systemSmall`-виджеты крупно.
- **Live Activities** (iOS 16.1+) — «живая» карточка на экране
  блокировки и в Dynamic Island (вырез-пилюля вверху экрана на iPhone
  14 Pro и новее) для событий «прямо сейчас»: доставка, такси, счёт
  матча.

## 42.2 Таргет виджета

Xcode → File → New → Target → **Widget Extension**. Xcode создаст новый
таргет — **расширение** (*app extension*): отдельный исполняемый модуль,
который живёт внутри твоего приложения, но работает в своём процессе.

Про режим Swift. Настройка `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
из введения есть только в шаблоне **приложения** Xcode 26; в шаблоне
Widget Extension её нет. Значит, код виджета по умолчанию не привязан к
главному актору. Это пригодится в 42.4, когда один файл будет входить в
оба таргета.

Минимальная версия iOS у таргета расширения может быть выше, чем у
приложения. Если приложение поддерживает iOS 15, а виджет ты хочешь
делать только для iOS 17+, у расширения ставишь 17 — на iOS 15 и 16
приложение будет работать, просто без виджета. В коде ниже мы держим
расширение на iOS 15 и отмечаем новые API через `@available`, чтобы
показать, как это выглядит.

## 42.3 Модель, запись в таймлайне и провайдер

Сначала общая модель задачи и хранилище в App Group (что это — в 42.4):

```swift
import WidgetKit
import SwiftUI

// Этот файл входит в оба таргета — приложение и виджет
nonisolated struct Todo: Codable, Identifiable, Hashable {
    var id = UUID()
    var title: String
    var isDone: Bool = false
}

extension Todo {
    static let previewList = [
        Todo(title: "Забрать посылку"),
        Todo(title: "Купить продукты", isDone: true),
    ]
}

nonisolated enum SharedTodoStore {
    static let appGroup = "group.kz.example.playground"
    static let key = "todos"

    static func load() -> [Todo] {
        guard let defaults = UserDefaults(suiteName: appGroup),
              let data = defaults.data(forKey: key),
              let todos = try? JSONDecoder().decode([Todo].self, from: data)
        else { return [] }
        return todos
    }

    static func save(_ todos: [Todo]) {
        guard let defaults = UserDefaults(suiteName: appGroup),
              let data = try? JSONEncoder().encode(todos) else { return }
        defaults.set(data, forKey: key)
    }
}
```

- `Identifiable` нужен SwiftUI, чтобы строить список через `ForEach`:
  у каждой задачи есть стабильный `id`.
- `nonisolated` у `Todo` и `SharedTodoStore` — потому что файл входит в
  **оба** таргета. В приложении по умолчанию всё на главном акторе, в
  виджете — нет. Без `nonisolated` в приложении эти типы стали бы
  «главноакторными», и код интента из 42.8, который выполняется вне
  главного актора, не смог бы их вызвать: компилятор ответил бы
  «main actor-isolated static method 'load()' cannot be called from
  outside of the actor». Мы поймали эту ошибку на проверке.
- `UserDefaults(suiteName:)` — общие настройки группы приложений,
  а не личные настройки одного таргета.
- Никаких `!`: если группа не настроена, `load()` вернёт пустой массив,
  и виджет покажет «Задач нет», а не упадёт.

Дальше — **запись таймлайна** (*timeline entry*) и **провайдер**:

```swift
struct TodoEntry: TimelineEntry {
    let date: Date
    let todos: [Todo]
}

struct TodoProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodoEntry {
        TodoEntry(date: Date(), todos: Todo.previewList)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodoEntry) -> Void) {
        if context.isPreview {
            completion(TodoEntry(date: Date(), todos: Todo.previewList))
        } else {
            completion(TodoEntry(date: Date(), todos: SharedTodoStore.load()))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodoEntry>) -> Void) {
        let now = Date()
        let entry = TodoEntry(date: now, todos: SharedTodoStore.load())
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: now)
            ?? now.addingTimeInterval(30 * 60)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}
```

**Таймлайн** (*timeline*) — то самое «расписание» из аналогии: массив
записей, у каждой — дата, с которой её показывать. Провайдер отвечает
на три вопроса системы:

- `placeholder` — «что нарисовать, пока данных ещё нет». Система
  покажет это размытым силуэтом. Работать должно мгновенно, без чтения
  диска.
- `getSnapshot` — «один кадр прямо сейчас». Вызывается, в частности, в
  галерее выбора виджетов. `context.isPreview == true` — это как раз
  галерея: показываем красивые демо-задачи. Если бы мы читали реальные
  данные, у нового пользователя в галерее был бы пустой прямоугольник, и
  он прошёл бы мимо.
- `getTimeline` — «расписание вперёд». Мы отдаём одну запись «сейчас» и
  политику `.after(nextUpdate)`: «спроси меня снова не раньше чем через
  30 минут».

`Calendar.current.date(byAdding:...)` возвращает опционал: в теории
календарь может не суметь прибавить. Вместо `!` у нас запасной вариант —
прибавить 30 × 60 = 1800 секунд.

**Виджет не обновляется точно по расписанию.** По документации
[Keeping a widget up to date](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date)
у каждого виджета есть дневной **бюджет** обновлений: для виджета,
который человек часто видит, — обычно **от 40 до 70** обновлений в сутки.
На числах: сутки — 1440 минут; 1440 / 70 ≈ 20 минут, 1440 / 40 = 36 минут.
Отсюда ориентир Apple «примерно раз в 15–60 минут». Просить обновление
каждую минуту бессмысленно — бюджет кончится к обеду.

Не расходует бюджет перезагрузка, которую приложение просит, пока
открыто, — об этом в 42.4.

## 42.4 Общие данные — App Group

Виджет — отдельный процесс со своей песочницей (изолированной папкой
на диске). Он **не видит** `UserDefaults.standard` и папку `Documents`
приложения. Мостик между ними — **App Group** («группа приложений»):
общая папка и общий `UserDefaults` для приложений и расширений одной
команды.

1. Таргет приложения → Signing & Capabilities → **+ Capability** →
   **App Groups** → добавь `group.kz.example.playground`.
2. То же самое у таргета виджета — **та же** группа.

Приложение сохраняет задачи в группу и просит WidgetKit перерисовать
виджет:

```swift
import WidgetKit

// Этот код — в таргете приложения
final class TodoStorage {
    static let shared = TodoStorage()
    private(set) var todos: [Todo] = SharedTodoStore.load()

    func add(_ todo: Todo) {
        todos.append(todo)
        SharedTodoStore.save(todos)
        WidgetCenter.shared.reloadTimelines(ofKind: "TodoWidget")
    }
}
```

`WidgetCenter.shared.reloadTimelines(ofKind:)` — «данные изменились,
перезапроси таймлайн у виджета с таким `kind`». Без этого вызова новая
задача появится на виджете, только когда подойдёт очередь по
расписанию — через полчаса.

Для файлов (например, картинок) у App Group есть общая папка:

```swift
func sharedFileURL(named name: String) -> URL? {
    FileManager.default
        .containerURL(forSecurityApplicationGroupIdentifier: "group.kz.example.playground")?
        .appendingPathComponent(name)
}
```

`containerURL(...)` возвращает `nil`, если группа не подключена к
таргету. Опциональная цепочка `?.` вместо `!` превращает забытую
настройку в понятный `nil`, а не в падение.

И про Privacy Manifest (глава 39): `UserDefaults(suiteName:)` — это тот
же required reason API. Для App Group причина — `1C8F.1`, а манифест нужен
и приложению, и расширению.

## 42.5 Интерфейс виджета

```swift
struct TodoWidgetView: View {
    let entry: TodoEntry
    @Environment(\.widgetFamily) private var family

    private var limit: Int {
        switch family {
        case .systemSmall: return 3
        case .systemMedium: return 4
        default: return 8
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Список дел")
                .font(.headline)
            if entry.todos.isEmpty {
                Text("Задач нет")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(entry.todos.prefix(limit)) { todo in
                    Text(todo.title)
                        .font(.subheadline)
                        .strikethrough(todo.isDone)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetBackground(Color(.systemBackground))
        .widgetURL(URL(string: "myapp://todos"))
    }
}

extension View {
    // На iOS 17+ фон виджета задаётся через containerBackground,
    // иначе система покажет заглушку вместо виджета. На iOS 14–16 — обычный фон.
    @ViewBuilder
    func widgetBackground(_ color: Color) -> some View {
        if #available(iOS 17.0, *) {
            containerBackground(color, for: .widget)
        } else {
            padding().background(color)
        }
    }
}
```

Для тех, кто SwiftUI не видел:

- `VStack(alignment: .leading, spacing: 4)` — вертикальная стопка с
  выравниванием по левому краю и отступом 4 точки, аналог
  вертикального `UIStackView`.
- `@Environment(\.widgetFamily)` — размер, в котором система сейчас
  рисует виджет. В маленький влезает 3 строки, в средний — 4.
- `ForEach(entry.todos.prefix(limit))` — первые `limit` задач.
- `.strikethrough(todo.isDone)` — зачеркнуть выполненные.
- `widgetBackground` — наш помощник. С iOS 17 виджет **обязан** задать
  фон через `containerBackground(_:for: .widget)`: система сама решает,
  когда фон показать, а когда убрать (например, в StandBy). Без него на
  iOS 17+ вместо виджета будет сообщение с просьбой перейти на новый
  API. Этот API есть только с iOS 17, поэтому ветка `if #available`.
- `.widgetURL(...)` — куда вести при тапе. Об этом в 42.7.

И сам виджет:

```swift
@main
struct TodoWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TodoWidget", provider: TodoProvider()) { entry in
            TodoWidgetView(entry: entry)
        }
        .configurationDisplayName("Список дел")
        .description("Ближайшие задачи из приложения")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
```

- `@main` — точка входа расширения. Если виджетов несколько, `@main`
  ставят на `WidgetBundle` (42.9).
- `StaticConfiguration` — виджет без пользовательских настроек.
  `kind` — строковый идентификатор, тот же, что в `reloadTimelines(ofKind:)`.
- `configurationDisplayName` и `description` — название и описание в
  галерее виджетов.
- `supportedFamilies` — какие размеры предлагать.

**Упражнение.** Добавь в заголовок виджета счётчик «Список дел · 3»,
где 3 — число невыполненных задач. Ответ — в конце главы.

## 42.6 Как посмотреть виджет

1. Выбери схему таргета виджета (Xcode создаёт её вместе с таргетом)
   и запусти на симуляторе. Xcode установит приложение с расширением.
2. На симуляторе: долгое нажатие на главном экране → «Изменить» →
   «Добавить виджет» → найди своё приложение.

Для быстрой отладки внешнего вида в Xcode есть превью (`#Preview(as:
.systemSmall)`, iOS 17+). Для проверки таймлайна полезно запустить
приложение, добавить задачу и убедиться, что виджет обновился сразу —
это и есть работа `reloadTimelines`.

## 42.7 Тап по виджету — deep link

Тап по виджету открывает приложение. Куда именно — задаётся ссылкой:

- `.widgetURL(URL)` — одна ссылка на весь виджет. Для `systemSmall` это
  **единственный** вариант: маленький виджет — одна зона нажатия.
- `Link(destination:) { ... }` — отдельные зоны в среднем и большом
  виджете: тап по конкретной задаче ведёт в неё.

```swift
Link(destination: URL(string: "myapp://todos") ?? URL(fileURLWithPath: "/")) {
    Text("Все задачи")
}
```

Ссылка `myapp://todos` приходит в приложение как обычная URL-схема:
`scene(_:openURLContexts:)` или, при холодном старте,
`connectionOptions.urlContexts` — всё это разобрано в главе 41 (41.10),
вместе с `DeepLink` и `DeepLinkRouter`.

## 42.8 App Intents — действия для Siri и «Команд»

**App Intent** («намерение») — действие твоего приложения, которое
система может вызвать сама: из Siri, из приложения «Команды», из
Spotlight, с кнопки на виджете. Ты описываешь действие структурой, а
система строит вокруг неё интерфейс. Фреймворк App Intents появился в
**iOS 16**.

```swift
import AppIntents

@available(iOS 16.0, *)
struct CreateTodoIntent: AppIntent {
    static let title: LocalizedStringResource = "Создать задачу"
    static let description = IntentDescription("Добавить задачу в список дел")

    @Parameter(title: "Текст задачи")
    var todoText: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let text = todoText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw $todoText.needsValueError("Какую задачу добавить?")
        }
        TodoStorage.shared.add(Todo(title: text))
        return .result(dialog: "Создано: \(text)")
    }
}
```

Разбор:

- `@available(iOS 16.0, *)` — у нас приложение с iOS 15, а App Intents —
  с 16. На iOS 15 этого действия просто не будет.
- `static let title` — название действия в «Командах». Именно `let`, а
  не `var`: в Swift 6 изменяемое статическое свойство — общее
  изменяемое состояние, и компилятор откажется его собирать
  («static property 'title' is not concurrency-safe»).
- `static let description` — тип `IntentDescription`, а не строка. Кроме
  текста у него есть `categoryName` (группировка в «Командах») и массив
  `searchKeywords` (ключевые слова для поиска) — оба с iOS 17.
- `@Parameter(title:)` — входной параметр. Если его не передали, Siri
  спросит голосом, «Команды» — полем ввода.
- `@MainActor func perform()` — сама работа. Протокол `AppIntent` не
  привязывает `perform()` к главному актору, а наш `TodoStorage` в
  приложении — главноакторный. Если `perform()` зовёт
  `TodoStorage.shared.add` без пометки, Swift 6 выдаёт ошибку
  «expression is 'async' but is not marked with 'await'». `@MainActor`
  на методе решает это: вся работа идёт на главном потоке, как и
  остальной код приложения.
- `some IntentResult & ProvidesDialog` — результат, в котором есть
  фраза для Siri. Без `& ProvidesDialog` вызов `.result(dialog:)` не
  соберётся.
- `$todoText.needsValueError(...)` — «параметр пустой, переспроси».
  Siri задаст этот вопрос вслух.

Чтобы действие было доступно голосом **без** ручной настройки в
«Командах», его объявляют в `AppShortcutsProvider`:

```swift
@available(iOS 16.0, *)
struct PlaygroundShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CreateTodoIntent(),
            phrases: [
                "Создать задачу в \(.applicationName)",
                "Добавить дело в \(.applicationName)",
            ],
            shortTitle: "Создать задачу",
            systemImageName: "plus.circle"
        )
    }
}
```

- `phrases` — фразы для Siri. Каждая **обязана** содержать
  `\(.applicationName)` — название приложения: так Siri понимает, к
  какому приложению обращаются.
- `shortTitle` и `systemImageName` — подпись и иконка SF Symbols на
  плашке в «Командах» и Spotlight.
- Провайдер ничего не нужно регистрировать: Xcode при сборке извлекает
  метаданные интентов из кода, и система узнаёт о них после установки.

Проверка: запусти приложение на симуляторе iOS 16+, открой «Команды» →
вкладка приложений → найди своё приложение. Там будет «Создать задачу».
Голосом — на реальном устройстве с Siri.

## 42.9 Экран блокировки (iOS 16+)

Для экрана блокировки — отдельные размеры `accessory…`. Их интерфейс
**монохромный**: система перекрашивает виджет в цвет экрана блокировки.

```swift
@available(iOS 16.0, *)
struct TodoCountAccessoryView: View {
    let entry: TodoEntry
    @Environment(\.widgetFamily) private var family

    private var left: Int { entry.todos.filter { !$0.isDone }.count }

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Text("\(left)")
                    .font(.title2.bold())
            }
        case .accessoryRectangular:
            VStack(alignment: .leading) {
                Text("Осталось задач: \(left)")
                    .font(.headline)
                    .widgetAccentable()
                Text(entry.todos.first(where: { !$0.isDone })?.title ?? "Всё сделано")
                    .privacySensitive()
            }
        default:
            Text("\(left)")
        }
    }
}

@available(iOS 16.0, *)
struct TodoLockWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TodoLockWidget", provider: TodoProvider()) { entry in
            TodoCountAccessoryView(entry: entry)
                .widgetBackground(Color.clear)
        }
        .configurationDisplayName("Задачи на экране блокировки")
        .description("Сколько задач осталось")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

@main
struct PlaygroundWidgets: WidgetBundle {
    var body: some Widget {
        TodoWidget()
        if #available(iOS 16.1, *) {
            TodoLockWidget()
        }
    }
}
```

- `accessoryCircular` — кружок (как кольца активности),
  `accessoryRectangular` — прямоугольник на две-три строки.
- `AccessoryWidgetBackground()` — стандартная полупрозрачная подложка
  кружка.
- `.widgetAccentable()` — эта часть окрасится акцентным цветом.
- `.privacySensitive()` — текст задачи **скрывается**, пока телефон
  заблокирован. Название задачи может быть личным («Записаться к
  врачу»), а экран блокировки видит кто угодно. Это правильный ответ на
  вопрос «как защитить данные в виджете»; ключ `NSWidgetWantsLocation`
  про другое — он нужен виджетам, которые
  запрашивают геопозицию.
- `WidgetBundle` — несколько виджетов в одном расширении; `@main` теперь
  стоит на нём, а у `TodoWidget` его нужно убрать.
- `if #available(iOS 16.1, *)` — внутри `WidgetBundle` компилятор требует
  именно 16.1 или новее: на `16.0` он предупреждает, что код «may crash
  on earlier versions of the OS». Мы получили это предупреждение и
  исправили. На iOS 16.0 виджет экрана блокировки не появится — это
  цена поддержки старых версий.

## 42.10 Интерактивный виджет (iOS 17+)

С iOS 17 в виджете можно поставить кнопку или переключатель, которые
выполняют действие **без открытия приложения**. Действие — это App
Intent:

```swift
import AppIntents
import SwiftUI
import WidgetKit

// Файл входит в оба таргета: приложение и виджет
@available(iOS 17.0, *)
struct ToggleTodoIntent: AppIntent {
    static let title: LocalizedStringResource = "Отметить задачу"

    @Parameter(title: "ID задачи")
    var todoID: String

    init() {}

    init(todoID: UUID) {
        self.todoID = todoID.uuidString
    }

    func perform() async throws -> some IntentResult {
        var todos = SharedTodoStore.load()
        if let index = todos.firstIndex(where: { $0.id.uuidString == todoID }) {
            todos[index].isDone.toggle()
            SharedTodoStore.save(todos)
        }
        return .result()
    }
}

@available(iOS 17.0, *)
struct TodoRow: View {
    let todo: Todo

    var body: some View {
        Button(intent: ToggleTodoIntent(todoID: todo.id)) {
            Label(todo.title, systemImage: todo.isDone ? "checkmark.circle.fill" : "circle")
                .strikethrough(todo.isDone)
        }
        .buttonStyle(.plain)
    }
}
```

- `init()` — пустой инициализатор обязателен для `AppIntent`: система
  создаёт интент сама, а потом заполняет параметры.
- `init(todoID:)` — наш удобный инициализатор для кнопки.
- `@Parameter var todoID: String` — храним `UUID` строкой: параметры
  интентов поддерживают ограниченный набор типов, а строка есть всегда.
- `perform()` здесь **без** `@MainActor`: интент выполняется в процессе
  виджета, и он трогает только `SharedTodoStore`, помеченный
  `nonisolated` (42.3).
- После выполнения интента, запущенного кнопкой виджета, система сама
  перезагружает таймлайн — виджет перерисуется с новой галочкой.
- `Button(intent:)` — кнопка SwiftUI, которая вместо замыкания
  запускает интент. Работает с iOS 17.

Чтобы использовать строку, в `TodoWidgetView` вместо `Text(todo.title)`
на iOS 17+ показываешь `TodoRow(todo: todo)`.

## 42.11 Live Activities (iOS 16.1+)

Live Activity — карточка «здесь и сейчас» на экране блокировки и в
Dynamic Island. Данные делятся на **постоянные** (номер заказа) и
**меняющиеся** (этап, минуты до доставки).

Описание данных — общий файл для приложения и расширения:

```swift
import ActivityKit
import Foundation

@available(iOS 16.1, *)
nonisolated struct DeliveryAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var stage: String          // «Готовится», «В пути», «Доставлено»
        var minutesRemaining: Int
    }
    var orderId: String
}
```

Управление из приложения:

```swift
@available(iOS 16.2, *)
final class DeliveryTracker {
    private var activity: Activity<DeliveryAttributes>?

    func start(orderId: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("Live Activities выключены в настройках")
            return
        }
        do {
            activity = try Activity.request(
                attributes: DeliveryAttributes(orderId: orderId),
                content: ActivityContent(
                    state: .init(stage: "Готовится", minutesRemaining: 25),
                    staleDate: nil
                ),
                pushType: nil
            )
        } catch {
            print("Не удалось запустить Live Activity: \(error)")
        }
    }

    func update(stage: String, minutes: Int) async {
        await activity?.update(
            ActivityContent(state: .init(stage: stage, minutesRemaining: minutes),
                            staleDate: nil)
        )
    }

    func finish() async {
        await activity?.end(
            ActivityContent(state: .init(stage: "Доставлено", minutesRemaining: 0),
                            staleDate: nil),
            dismissalPolicy: .default
        )
        activity = nil
    }
}
```

- `ActivityAuthorizationInfo().areActivitiesEnabled` — человек мог
  выключить Live Activities для приложения в настройках.
- `Activity.request(attributes:content:pushType:)` — с iOS 16.2.
  `pushType: nil` — обновляем только из приложения; с `.token` можно
  обновлять пушами с сервера (тип пуша `liveactivity`, глава 41).
- `staleDate` — момент, после которого данные считаются устаревшими
  (`nil` — не устаревают).
- `end(_:dismissalPolicy: .default)` — финальное состояние «Доставлено»
  остаётся на экране блокировки какое-то время, чтобы человек увидел
  итог.

Ограничения из документации ActivityKit:

- в `Info.plist` приложения нужен ключ `NSSupportsLiveActivities = YES`;
- данные (постоянные + меняющиеся) — не больше **4 КБ**;
- активность живёт до **8 часов**, после чего система её завершает;
  на экране блокировки она может провисеть ещё до 4 часов — максимум
  12 часов суммарно.

И внешний вид — в расширении виджета:

```swift
import ActivityKit
import SwiftUI
import WidgetKit

@available(iOS 16.1, *)
struct DeliveryLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DeliveryAttributes.self) { context in
            // Экран блокировки и баннер на iPhone без Dynamic Island
            HStack {
                Text(context.state.stage).font(.headline)
                Spacer()
                Text("\(context.state.minutesRemaining) мин")
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("Заказ \(context.attributes.orderId)")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.minutesRemaining) мин")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.stage)
                }
            } compactLeading: {
                Image(systemName: "bag")
            } compactTrailing: {
                Text("\(context.state.minutesRemaining)м")
            } minimal: {
                Image(systemName: "bag")
            }
        }
    }
}
```

У Dynamic Island три вида: **expanded** (развёрнутый, по долгому
нажатию), **compact** (две половинки слева и справа от камеры) и
**minimal** (маленький кружок, когда активностей несколько). Эту
структуру добавляешь в `WidgetBundle` из 42.9 (с проверкой
`if #available(iOS 16.2, *)`).

## 42.12 Что когда использовать

| Задача                                   | Решение                         |
|------------------------------------------|---------------------------------|
| Данные на главном экране                 | Виджет (WidgetKit)              |
| Действие голосом через Siri              | App Intent + App Shortcut       |
| Кнопка в «Командах»                      | App Intent                      |
| Галочка прямо на виджете                 | App Intent + `Button(intent:)` (iOS 17+) |
| Поиск своего контента в Spotlight        | Core Spotlight; с iOS 18 — ещё и App Intents для сущностей |
| Отслеживание заказа в реальном времени   | Live Activity                   |
| Статус на экране блокировки              | `accessory`-виджет              |

## 42.13 Приватность виджетов

Виджет видят люди рядом с тобой: на главном экране, на экране
блокировки, в StandBy на тумбочке. Правила:

- **`.privacySensitive()`** на всём, что личное: суммы, сообщения,
  названия задач. На заблокированном устройстве система заменит такой
  текст заглушкой.
- **Privacy Manifest** — отдельный у расширения, если оно пользуется
  required reason API (App Group `UserDefaults` — это `1C8F.1`).
- **Геопозиция в виджете** — если виджет сам запрашивает местоположение,
  в `Info.plist` расширения нужен ключ `NSWidgetWantsLocation = YES`,
  а у приложения — разрешение на геопозицию.

## 42.14 Нужен ли виджет

Если приложение **функциональное** — список дел, заметки, трекер
привычек, погода, — виджет часто становится главным способом им
пользоваться: человек видит данные, не открывая приложение.

Если приложение **сессионное** — игра, магазин, утилита «открыл и
закрыл», — виджет не обязателен. Начни с App Intent: одно действие
для Siri и «Команд» стоит дешевле и полезнее «витринного» виджета.

## 42.15 Ответы к упражнениям

**42.5 — счётчик в заголовке.**

```swift
struct TodoWidgetHeader: View {
    let todos: [Todo]

    var body: some View {
        let left = todos.filter { !$0.isDone }.count
        Text("Список дел · \(left)")
            .font(.headline)
    }
}
```

В `TodoWidgetView` заменяешь `Text("Список дел")` на
`TodoWidgetHeader(todos: entry.todos)`. Проверка: для
`Todo.previewList` (одна задача выполнена, одна нет) заголовок в
галерее виджетов — «Список дел · 1».

## Что мы выучили

- **WidgetKit** (iOS 14+): виджет — расписание снимков, а не
  работающая программа. Интерфейс — на SwiftUI.
- **`TimelineProvider`**: `placeholder`, `getSnapshot` (с
  `context.isPreview`), `getTimeline` с политикой `.after`.
- **Бюджет** — обычно 40–70 обновлений в сутки; после изменения данных
  в приложении — `WidgetCenter.shared.reloadTimelines(ofKind:)`.
- **App Group** — общий `UserDefaults` и папка для приложения и
  виджета. Общие типы в файлах для двух таргетов — `nonisolated`.
- **iOS 17+**: фон через `containerBackground(_:for: .widget)`,
  интерактивные виджеты через `Button(intent:)`.
- **Тап**: `widgetURL` (единственный вариант для `systemSmall`) и `Link`.
- **App Intents** (iOS 16+): `static let title`, `@Parameter`,
  `perform()`; `@MainActor` на `perform`, если трогаешь главноакторный
  код; `AppShortcutsProvider` с `\(.applicationName)` в каждой фразе.
- **Экран блокировки** (iOS 16+): `accessoryCircular`,
  `accessoryRectangular`, `.privacySensitive()`.
- **Live Activities** (iOS 16.1+): `ActivityAttributes`,
  `Activity.request(...content:pushType:)` с iOS 16.2,
  `NSSupportsLiveActivities`, до 8 часов и 4 КБ данных.

## Apple Developer Documentation

- [WidgetKit](https://developer.apple.com/documentation/widgetkit) — фреймворк виджетов.
- [Creating a widget extension](https://developer.apple.com/documentation/widgetkit/creating-a-widget-extension) — таргет виджета, провайдер, конфигурация.
- [`TimelineProvider`](https://developer.apple.com/documentation/widgetkit/timelineprovider) — `placeholder`, `getSnapshot`, `getTimeline`.
- [Keeping a widget up to date](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date) — бюджет обновлений и `reloadTimelines`.
- [Adding interactivity to widgets and Live Activities](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities) — `Button(intent:)` и `Toggle(isOn:intent:)`.
- [Creating accessory widgets and watch complications](https://developer.apple.com/documentation/widgetkit/creating-accessory-widgets-and-watch-complications) — виджеты экрана блокировки.
- [`widgetURL(_:)`](https://developer.apple.com/documentation/swiftui/view/widgeturl(_:)) — ссылка при тапе по виджету.
- [App Intents](https://developer.apple.com/documentation/appintents) — фреймворк действий для Siri, «Команд» и Spotlight.
- [`AppShortcutsProvider`](https://developer.apple.com/documentation/appintents/appshortcutsprovider) — фразы Siri для твоих интентов.
- [Displaying live data with Live Activities](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities) — ActivityKit, Dynamic Island, лимиты.
- [Configuring App Groups](https://developer.apple.com/documentation/xcode/configuring-app-groups) — общая группа для приложения и расширений.

→ [Глава 43. Production: accessibility audit перед релизом](./65-production-accessibility-audit.md)
