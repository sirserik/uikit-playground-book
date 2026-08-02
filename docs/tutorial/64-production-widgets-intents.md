# Глава 42. Production: widgets + App Intents

Виджеты и App Intents — два механизма, чтобы твоё приложение работало
**вне** своего основного UI: на главном экране, в Spotlight, в Siri,
в Shortcuts.

Здесь короткий обзор обоих, без deep dive — каждый из этих
фреймворков тянет на отдельную книгу.

## 42.1 WidgetKit — что это

Widget — это **картинка на главном экране**, которая показывает данные
твоего приложения. iOS 14+.

Виды:
- **Home Screen Widget** — на главном экране iPhone/iPad.
- **Lock Screen Widget** (iOS 16+) — на экране блокировки.
- **StandBy Widget** (iOS 17+) — в landscape при зарядке.
- **Live Activities** (iOS 16+) — динамический виджет на Dynamic
  Island и lock screen (доставка, заказ такси).

Технически — **SwiftUI**. Даже если основное приложение на UIKit,
виджет писать в SwiftUI.

## 42.2 Создание widget target

Xcode → File → New → Target → **Widget Extension**.

Создаст новый target с шаблоном:

```swift
import WidgetKit
import SwiftUI

struct TodoWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TodoWidget",
                            provider: TodoProvider()) { entry in
            TodoWidgetView(entry: entry)
        }
        .configurationDisplayName("Список дел")
        .description("Покажи 5 ближайших задач")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct TodoWidgetView: View {
    let entry: TodoEntry

    var body: some View {
        VStack(alignment: .leading) {
            ForEach(entry.todos.prefix(5)) { todo in
                Text(todo.title)
            }
        }
        .padding()
    }
}
```

## 42.3 Provider — как обновляются данные

```swift
struct TodoProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodoEntry {
        TodoEntry(date: Date(), todos: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (TodoEntry) -> Void) {
        // снимок для галереи виджетов — показываем пару демо-задач
        completion(TodoEntry(date: Date(), todos: Todo.previewList))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodoEntry>) -> Void) {
        let todos = loadTodos()  // из shared storage
        let entry = TodoEntry(date: Date(), todos: todos)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}
```

`getTimeline` — iOS зовёт периодически, виджет получает обновлённые
данные. `policy: .after(date)` — очередное обновление в указанное время.

`Todo.previewList` — это просто пара статических задач для снимка:

```swift
extension Todo {
    static let previewList = [
        Todo(title: "Забрать посылку", isDone: false),
        Todo(title: "Купить продукты", isDone: true),
    ]
}
```

`getSnapshot` вызывают, когда виджет показывают в галерее выбора и когда
нужен быстрый предпросмотр, — лезть за реальными данными там незачем и
вредно: если хранилище пустое, пользователь увидит пустой прямоугольник и
пройдёт мимо.

**Виджет НЕ всегда обновляется** в указанное время. iOS решает по
бюджету (battery, использование). Чем чаще обновляется виджет, тем
меньше времени iOS даёт.

## 42.4 Shared storage — App Group

Виджет — отдельный процесс. Не имеет доступа к UserDefaults / Files
приложения. Решение — **App Group**:

1. Xcode → main app target → Signing & Capabilities → **App Groups**
   → создай `group.com.your.app`.
2. То же самое в widget target.

Использование:

```swift
// В приложении при сохранении:
let shared = UserDefaults(suiteName: "group.com.your.app")
shared?.set(data, forKey: "todos")

// В виджете при чтении:
let shared = UserDefaults(suiteName: "group.com.your.app")
let data = shared?.data(forKey: "todos")
```

Аналогично для FileManager:

```swift
let container = FileManager.default
    .containerURL(forSecurityApplicationGroupIdentifier: "group.com.your.app")!
let fileURL = container.appendingPathComponent("todos.json")
```

## 42.5 Deep link из виджета

Когда юзер тапает виджет:

```swift
struct TodoWidgetView: View {
    let entry: TodoEntry

    var body: some View {
        Link(destination: URL(string: "myapp://todos/all")!) {
            Text("Open All")
        }
    }
}
```

iOS откроет приложение по URL scheme. В `SceneDelegate.scene(_:openURLContexts:)`
обработай (Глава 41).

Для `systemSmall` widget — один tap на весь виджет → `widgetURL`:

```swift
TodoWidgetView(entry: entry)
    .widgetURL(URL(string: "myapp://todos/all")!)
```

## 42.6 App Intents — что это

С iOS 16 / Xcode 14 — фреймворк для:

1. **Shortcuts** — кастомные комбинации действий, юзер создаёт в
   приложении Shortcuts.
2. **Siri** — голосовые команды.
3. **Spotlight** — поиск по содержимому приложения.
4. **Focus** modes — Custom Focus filter.

Простой App Intent:

```swift
import AppIntents

struct CreateTodoIntent: AppIntent {
    static let title: LocalizedStringResource = "Создать задачу"
    static let description = IntentDescription("Добавить задачу в список дел")

    @Parameter(title: "Текст задачи")
    var todoText: String

    func perform() async throws -> some IntentResult {
        // Создать задачу
        TodoStorage.shared.add(Todo(title: todoText))
        return .result(dialog: "Создано: \(todoText)")
    }
}
```

Два момента, на которых спотыкаются при переносе старых примеров.

`static let`, а не `static var`: в Swift 6 изменяемое статическое
свойство — это глобальное общее состояние, и компилятор откажется
собирать («static property 'title' is not concurrency-safe»). Менять
заголовок интента в рантайме всё равно незачем, так что `let` тут и
правильнее, и короче.

Тип у `description` — **`IntentDescription`**, а не
`LocalizedStringResource`. Он умеет больше: кроме текста в нём живут
`categoryName` для группировки в Shortcuts и флаг
`searchKeywords`.

После этого юзер может:

- Сказать Siri «Создать задачу в YourApp».
- Создать Shortcut «При запуске моей утренней routine — добавить
  задачу `утренняя пробежка`».
- Через iOS 16 Shortcuts UI.

## 42.7 AppShortcutsProvider

Чтобы Shortcuts видели твои intents:

```swift
struct YourAppShortcutsProvider: AppShortcutsProvider {
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

`phrases` — что юзер может сказать Siri.

## 42.8 Lock Screen widgets (iOS 16+)

```swift
.supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
```

`accessoryCircular` — маленький кружок (как Activity rings).
`accessoryRectangular` — прямоугольная полоска.

Только monochrome дизайн (tint от lock screen стиля).

## 42.9 Live Activities (iOS 16+)

Динамический widget на lock screen + Dynamic Island:

```swift
import ActivityKit

struct DeliveryAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var stage: String  // "Готовится", "В пути", "Доставлено"
        var minutesRemaining: Int
    }
    var orderId: String
}

// Start (iOS 16.2+ API — contentState:/update(using:) устарели)
let activity = try Activity.request(
    attributes: DeliveryAttributes(orderId: "abc"),
    content: ActivityContent(
        state: .init(stage: "Готовится", minutesRemaining: 25),
        staleDate: nil
    ),
    pushType: nil   // обязательный аргумент; nil — local-only Live Activity
)

// Update
await activity.update(
    ActivityContent(state: .init(stage: "В пути", minutesRemaining: 15),
                    staleDate: nil)
)

// End
await activity.end(nil, dismissalPolicy: .immediate)
```

Используется в food delivery, ride sharing, sports scores.

## 42.10 Когда использовать что

| Задача                              | Решение            |
|-------------------------------------|--------------------|
| Информация на главном экране        | WidgetKit          |
| Быстрый доступ через Siri           | App Intent         |
| Кнопка в Shortcuts                  | App Intent         |
| Поиск содержимого через Spotlight   | CoreSpotlight + App Intent |
| Real-time order tracking            | Live Activities    |
| Lock screen status                  | Lock Screen Widget |
| Динамические рекомендации в Today   | Smart Stack widget |

## 42.11 Test и debug

**Widget debug** в Xcode:
1. Scheme → Edit Scheme → выбери widget target.
2. Run on simulator.
3. Симулятор покажет widget в isolation.

Можно симулировать timeline events:
```
Debug → View Widget Display Sizes → ...
```

**App Intents test**:
- Команда `Test in Shortcuts` в Xcode (iOS 16+).
- Через Siri на устройстве.

## 42.12 App Privacy

Виджет имеет свой `Info.plist`. Если виджет показывает чувствительные
данные (баланс, сообщения) — добавь:

```xml
<key>NSWidgetWantsLocation</key>
<true/>
```

И обрати внимание в Privacy Manifest.

## 42.13 Без widget'ов — нужно ли?

Если приложение **функциональное** (Todo, Notes, Habit tracker) —
widget значительно повышает retention. Юзер видит данные каждый раз
смотря на главный экран.

Если приложение **сессионное** (игра, утилита, маркетплейс) — widget
не критичен.

## 📋 Что мы выучили

- **WidgetKit** — виджеты в SwiftUI, даже если основное приложение на
  UIKit.
- **Widget Extension target** + `TimelineProvider` для обновлений.
- **App Group** для shared storage между app и widget (UserDefaults,
  Files).
- **`widgetURL`** для tap → deep link открывает приложение.
- **App Intents** (iOS 16+) — Siri, Shortcuts, Spotlight, Focus.
- **`AppShortcutsProvider.appShortcuts`** для phrases юзера.
- **Lock Screen widgets** — `.accessoryCircular`, `.accessoryRectangular`.
- **Live Activities** — динамический widget с `ActivityKit`. Dynamic
  Island.
- **Testing** через `xcrun simctl` или Shortcuts app.

## Apple Developer Documentation

- [WidgetKit](https://developer.apple.com/documentation/widgetkit) — фреймворк виджетов; даже если основное приложение на UIKit, сами виджеты пишутся в SwiftUI.
- [`TimelineProvider`](https://developer.apple.com/documentation/widgetkit/timelineprovider) — протокол поставщика обновлений (`placeholder`, `getSnapshot`, `getTimeline`).
- [`TimelineEntry`](https://developer.apple.com/documentation/widgetkit/timelineentry) — единичный «слепок» данных виджета на момент времени.
- [Keeping a widget up to date](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date) — политика обновлений, бюджет iOS, `WidgetCenter.reloadTimelines`.
- [App Intents](https://developer.apple.com/documentation/appintents) — фреймворк для Siri, Shortcuts, Spotlight, Focus filter.
- [`AppShortcutsProvider`](https://developer.apple.com/documentation/appintents/appshortcutsprovider) — регистрирует фразы, по которым Siri и Shortcuts видят твои intents.
- [ActivityKit / Live Activities](https://developer.apple.com/documentation/activitykit) — динамические виджеты на lock screen и Dynamic Island.
- [Sharing data with your containing app](https://developer.apple.com/documentation/widgetkit/creating-a-widget-extension) — App Group для UserDefaults и FileManager между приложением и виджетом.
- [`Link` и `widgetURL(_:)`](https://developer.apple.com/documentation/widgetkit/making-a-configurable-widget) — открыть приложение по deep link из виджета.

→ [Глава 43. Production: accessibility audit](./65-production-accessibility-audit.md)
