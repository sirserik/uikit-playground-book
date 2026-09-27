# Глава 41. Production: push notifications + deep links

Два связанных сценария. **Push-уведомление** (дальше просто «пуш») — сообщение,
которое твой сервер отправляет на телефон через сервис Apple, даже когда
приложение закрыто. **Deep link** («глубокая ссылка») — ссылка, которая
открывает не просто приложение, а конкретный экран внутри него: чат №1234,
профиль пользователя, товар. Связаны они потому, что тап по пушу почти
всегда должен вести на конкретный экран — то есть пуш несёт в себе
deep link.

Факты о сервисе пушей сверены с документацией Apple (раздел
User Notifications) в сентябре 2026 года.

## 41.1 Как устроена доставка пуша

Участников четыре:

```
┌──────────────┐  1. device token  ┌──────────────┐
│  Приложение  │ ────────────────▶ │ Твой сервер  │
└──────────────┘                   └──────────────┘
        ▲                                  │ 2. HTTP/2 запрос:
        │ 4. iOS показывает                │    токен + JSON
        │    уведомление                   ▼
┌──────────────┐  3. доставка      ┌──────────────┐
│     iOS      │ ◀──────────────── │     APNs     │
└──────────────┘                   └──────────────┘
```

- **APNs** (Apple Push Notification service) — сервис Apple, через
  который идут все пуши на устройства Apple. Напрямую на телефон твой
  сервер ничего отправить не может.
- **Device token** («токен устройства») — адрес твоего приложения на
  конкретном телефоне. Его выдаёт APNs при регистрации. Токен уникален
  для пары «приложение + устройство»: у двух твоих приложений на одном
  iPhone токены разные.
- **Provider server** — в терминах Apple это твой сервер, который
  формирует пуш и отправляет его в APNs.

Аналогия: APNs — почта, device token — почтовый адрес, твой сервер —
отправитель. Адрес ты узнаёшь от самого получателя (приложение сообщает
токен серверу), а доставляет всегда почта.

## 41.2 Настройка в Apple Developer и ключ `.p8`

1. Открой [developer.apple.com/account](https://developer.apple.com/account)
   → **Certificates, Identifiers & Profiles** → **Identifiers**, выбери
   App ID приложения и включи **Push Notifications**. (Если включишь
   capability в Xcode при автоматической подписи, Xcode сделает это сам.)
2. Там же, в разделе **Keys**, создай ключ с галочкой **Apple Push
   Notifications service (APNs)**. Apple выдаст:
   - файл ключа с расширением `.p8` — его можно скачать **только один
     раз**;
   - **Key ID** — строка из 10 символов;
   - понадобится ещё **Team ID** — идентификатор твоей команды
     разработчика (виден в Membership details).
3. Файл `.p8`, Key ID, Team ID и bundle ID приложения отдай тем, кто
   делает сервер. Ключ — секрет: кто им владеет, может слать пуши твоим
   пользователям.

Что сервер делает с ключом. Он подписывает им короткий JSON-токен
(JWT — JSON Web Token), в котором Team ID и время создания, и кладёт
его в заголовок `authorization: bearer <токен>` каждого запроса к APNs.
По документации
[Establishing a token-based connection to APNs](https://developer.apple.com/documentation/usernotifications/establishing-a-token-based-connection-to-apns)
этот JWT нужно обновлять **не реже раза в 60 минут и не чаще раза в
20 минут**: APNs отклоняет токен старше часа с ошибкой
`ExpiredProviderToken (403)`.

Сам ключ `.p8` не истекает — его можно только отозвать. Сейчас Apple
предлагает два вида ключей:

- **Team-scoped** — на все приложения команды, но для **одной** среды
  (Sandbox или Production), максимум два ключа на среду;
- **Topic-specific** — только для выбранных приложений.

Старые ключи, которые работают сразу в обеих средах, продолжают
работать, но Apple советует разделять ключи по средам.

Альтернатива ключу — **сертификат** `.p12` для конкретного приложения.
Он действует **год**, потом его нужно выпускать заново, иначе пуши
перестанут доходить. Поэтому для новых проектов бери ключ.

## 41.3 Две среды APNs: sandbox и production

У APNs два сервера:

- **development (sandbox)** — `api.sandbox.push.apple.com:443`;
- **production** — `api.push.apple.com:443`.

Какая среда у сборки, решает entitlement `aps-environment`.
**Entitlement** — это разрешение, вшитое в подпись приложения: «этому
приложению можно получать пуши, в такой-то среде». По документации
ключа [aps-environment](https://developer.apple.com/documentation/bundleresources/entitlements/aps-environment)
Xcode ставит значение по профилю подписи (provisioning profile — файл
Apple, который связывает приложение, команду и устройства):

| Как установлена сборка                  | `aps-environment` | Сервер APNs            |
|-----------------------------------------|-------------------|------------------------|
| Запуск из Xcode на своём iPhone         | `development`     | sandbox                |
| TestFlight                              | `production`      | production             |
| App Store                               | `production`      | production             |

**TestFlight** — сервис Apple для бета-тестирования: сборку загружают
в App Store Connect, а тестировщики ставят её через приложение
TestFlight ещё до выхода в App Store.

Ошибка номер один на практике: сборка из TestFlight регистрируется в
production, а сервер шлёт в sandbox — или наоборот. Токен из одной
среды в другой не работает, APNs отвечает ошибкой `BadDeviceToken`.
Поэтому вместе с токеном отправляй на сервер и среду (например, по
флагу сборки `DEBUG`).

## 41.4 Xcode: capability

В Xcode → таргет приложения → **Signing & Capabilities** → **+
Capability**:

1. **Push Notifications** — обязательно. Добавляет в файл
   `.entitlements` ключ `aps-environment`.
2. **Background Modes** → галочка **Remote notifications** — **только**
   если нужны тихие (фоновые) пуши из 41.9. Для обычных видимых пушей
   это не требуется.

**Capability** («возможность») в Xcode — переключатель, который
одновременно добавляет entitlement в подпись и включает соответствующую
функцию у App ID.

## 41.5 Регистрация и device token

Регистрация и запрос разрешения — две **разные** вещи:

- `registerForRemoteNotifications()` — получить device token. Работает
  без разрешения пользователя (тихие пуши приходят и без него).
- `requestAuthorization(options:)` — спросить разрешение **показывать**
  уведомления: баннер, звук, бейдж.

По документации
[Registering your app with APNs](https://developer.apple.com/documentation/usernotifications/registering-your-app-with-apns)
регистрироваться нужно **при каждом запуске**: APNs выдаёт новый токен
после восстановления из резервной копии, установки на новое устройство
и переустановки системы. Там же прямо сказано: не кэшируй токен
локально.

```swift
import UIKit
import UserNotifications

enum API {
    static func registerDevice(token: String) async throws { /* POST на сервер */ }
}

final class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Делегат ставим до конца запуска — иначе тап по пушу,
        // который запустил приложение, может потеряться
        UNUserNotificationCenter.current().delegate = self
        // Токен — при каждом запуске
        application.registerForRemoteNotifications()
        return true
    }

    /// Вызываем из экрана-объяснения (primer), а не при запуске
    func requestPushPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            print("Ошибка запроса разрешения: \(error)")
            return false
        }
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task {
            try? await API.registerDevice(token: token)
        }
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Не удалось зарегистрироваться в APNs: \(error)")
    }
}
```

Разбор:

- `UNUserNotificationCenter.current().delegate = self` — в
  `didFinishLaunching`. В заголовке SDK сказано, что делегат нужно
  установить до того, как приложение вернётся из этого метода: иначе
  событие «пользователь тапнул уведомление, и оно запустило приложение»
  некому будет получить.
- `registerForRemoteNotifications()` — асинхронный запрос к APNs.
  Результат придёт в один из двух методов ниже.
- `requestPushPermission()` — отдельно, чтобы вызвать его в удачный
  момент, после объяснения (41.6). `async`-версия возвращает `true`, если
  человек разрешил.
- `deviceToken: Data` — 32 байта (сейчас; Apple не гарантирует длину).
  `map { String(format: "%02x", $0) }` превращает каждый байт в две
  шестнадцатеричные цифры: байт 255 → `"ff"`, байт 10 → `"0a"`.
  `joined()` склеивает — получается строка из 64 символов, которую
  ждёт сервер.
- `didFailToRegister...` — на симуляторе без поддержки удалённых пушей,
  без сети или без entitlement сюда приходит ошибка. Документация
  советует запомнить это и попробовать позже.

Режим Swift 6 и `MainActor`. Протокол `UNUserNotificationCenterDelegate`
в заголовке SDK **не** помечен `@MainActor`. Наш `AppDelegate` — на
главном акторе (режим по умолчанию из введения), поэтому Swift 6.2+
делает его соответствие протоколу **изолированным**: методы делегата
рассчитаны на вызов с главного потока. Код ниже собирается в режиме
Swift 6 без ошибок. Если бы система вызвала делегат не с главного
потока, в режиме Swift 6 проверка изоляции остановила бы приложение,
а не дала бы тихую гонку данных. Хочешь убедиться у себя — добавь в
`willPresent` строку `print(Thread.isMainThread)` и отправь пуш
командой из 41.15.

## 41.6 Объяснение перед запросом разрешения

Apple не требует показывать собственный экран-объяснение (*primer*,
глава 7) перед системным диалогом пушей. Но системный диалог
показывается **один раз**: если человек нажал «Не разрешать», вернуть
разрешение он сможет только в Настройках. Поэтому сначала объясни
выгоду своими словами:

«Включи уведомления, чтобы:
- знать о новых сообщениях в чате;
- получать напоминания о задачах со сроком;
- узнать, когда закончилась долгая загрузка».

И только после «Включить» на твоём экране — `requestPushPermission()`.

Требования Guidelines:

- **4.5.4** — пуши **не должны быть обязательными** для работы
  приложения и не должны нести конфиденциальную информацию. Рекламу и
  маркетинг пушами можно слать, только если человек **явно согласился**
  на это в интерфейсе приложения и может там же отказаться.
- **5.1.2(i)** — нельзя требовать включить пуши в обмен на доступ к
  функциям или награды.

Для рекламных пушей это значит: отдельный переключатель «Акции и
скидки» в настройках (как в Profile, глава 19), выключенный по
умолчанию.

## 41.7 Содержимое пуша (payload)

Сервер отправляет в APNs JSON — *payload* («полезная нагрузка»):

```json
{
  "aps": {
    "alert": {
      "title": "Новое сообщение",
      "body": "Айдос: Привет! Когда встречаемся?"
    },
    "badge": 5,
    "sound": "default"
  },
  "deep_link": "myapp://chat/1234"
}
```

- `aps` — словарь, который читает iOS. Все системные ключи — внутри него.
- `aps.alert.title` и `aps.alert.body` — заголовок и текст уведомления.
- `aps.badge` — число на иконке приложения. `0` убирает бейдж.
- `aps.sound` — `"default"` для системного звука или имя файла из бандла.
- `deep_link` — наш собственный ключ **вне** `aps`. iOS его не трогает,
  приложение прочитает его из `userInfo`.

Ограничение размера — **4 КБ** (4096 байт) на весь JSON. Картинки в
пуш не кладут: кладут ссылку, а скачивает её расширение из 41.12.

Кроме тела, сервер указывает заголовки HTTP/2-запроса:

- `apns-topic` — bundle ID приложения;
- `apns-push-type` — `alert` для видимого пуша, `background` для тихого.
  Документация просит отправлять его с каждым пушем;
- `apns-priority` — `10` (доставить сразу) или `5` (можно отложить для
  экономии батареи). Для `background` — только `5`.

## 41.8 Получение: приложение открыто и тап по уведомлению

```swift
extension AppDelegate: UNUserNotificationCenterDelegate {

    // Пуш пришёл, когда приложение на экране
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound, .badge])
    }

    // Пользователь тапнул уведомление (или кнопку в нём)
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        if let deepLink = userInfo["deep_link"] as? String,
           let url = URL(string: deepLink) {
            DeepLinkRouter.shared.open(url)
        }
        completionHandler()
    }
}
```

`willPresent` вызывается, только если приложение **на экране**
(foreground). По умолчанию в этом состоянии iOS пуш **не показывает** —
считается, что человек и так видит приложение. Параметр
`completionHandler` решает, что сделать:

- `.banner` — показать баннер сверху (iOS 14+);
- `.list` — оставить в Центре уведомлений (iOS 14+);
- `.sound`, `.badge` — звук и число на иконке;
- `[]` — ничего не показывать. Удобно, если человек сейчас в том же чате,
  куда пришло сообщение.

`didReceive` вызывается, когда человек **тапнул** уведомление: на
заблокированном экране, в Центре уведомлений или баннер. Если приложение
было закрыто, iOS сначала запустит его, а потом вызовет этот метод — вот
почему делегат ставится в `didFinishLaunching`.

`DeepLinkRouter` — наш маршрутизатор ссылок из 41.10: одна точка, куда
сходятся ссылки из пушей, URL-схем и Universal Links.

`completionHandler()` — обязательно вызвать, когда обработка закончена.

В SDK есть и `async`-варианты этих методов. Мы берём версии с
`completionHandler`, чтобы явно видеть момент, когда сообщаем системе
«готово».

**Упражнение.** Сделай так, чтобы пуш про чат `1234` **не показывался**,
если человек сейчас открыт именно в этом чате. Подсказка: где-то должно
храниться «текущий открытый чат». Решение — в конце главы.

## 41.9 Тихие (фоновые) пуши

Пуш без баннера и звука — чтобы разбудить приложение и обновить данные:

```json
{
  "aps": {
    "content-available": 1
  },
  "type": "sync",
  "task_id": "123"
}
```

По документации
[Pushing background updates to your app](https://developer.apple.com/documentation/usernotifications/pushing-background-updates-to-your-app):

- в `aps` только `content-available: 1` — никаких `alert`, `sound`,
  `badge`;
- заголовки `apns-push-type: background` и `apns-priority: 5`;
- в приложении нужен Background Modes → Remote notifications (41.4);
- система считает такие пуши низкоприоритетными: доставка **не
  гарантирована**, их могут придержать и объединить. Apple советует
  не больше **двух-трёх в час**;
- если человек принудительно закрыл приложение смахиванием, отложенный
  тихий пуш система выбросит.

iOS будит приложение и вызывает:

```swift
extension AppDelegate {
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        Task {
            let changed = await syncData()
            completionHandler(changed ? .newData : .noData)
        }
    }

    func syncData() async -> Bool {
        // Загрузить изменения с сервера и сохранить локально
        return true
    }
}
```

На всю работу у приложения **30 секунд**. `completionHandler` нужно
вызвать обязательно и честно: `.newData` — что-то загрузили, `.noData` —
нечего было, `.failed` — ошибка. Система учитывает, сколько времени и
энергии тратит приложение на фоновую работу, и может реже будить тех,
кто работает долго.

## 41.10 Deep links через URL-схему

**URL-схема** — префикс ссылки вида `myapp://`, который ты регистрируешь
за своим приложением. Регистрация в `Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>kz.example.playground</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>myapp</string>
        </array>
    </dict>
</array>
```

Теперь ссылка `myapp://chat/1234` из Safari, заметок или другого
приложения откроет наше. Проверить на симуляторе:

```bash
xcrun simctl openurl booted "myapp://chat/1234"
```

Разбор ссылки — отдельный тип, чтобы не размазывать `if` по делегатам:

```swift
enum DeepLink: Equatable {
    case chat(id: String)
    case profile(id: String)
    case todos

    init?(url: URL) {
        let parts = url.pathComponents.filter { $0 != "/" }
        switch url.scheme {
        case "myapp":
            // myapp://chat/1234 → host = "chat", parts = ["1234"]
            switch (url.host, parts.count) {
            case ("chat", 1):  self = .chat(id: parts[0])
            case ("todos", _): self = .todos
            default: return nil
            }
        case "https":
            // https://example.com/share/chat/1234 → parts = ["share", "chat", "1234"]
            guard url.host == "example.com" else { return nil }
            switch (parts.first, parts.count) {
            case ("profile", 2): self = .profile(id: parts[1])
            case ("share", 3) where parts[1] == "chat": self = .chat(id: parts[2])
            default: return nil
            }
        default:
            return nil
        }
    }
}
```

Разбор на примерах:

- `myapp://chat/1234`: схема `myapp`, **хост** (то, что после `://`) —
  `chat`, путь — `/1234`. `pathComponents` для пути `/1234` возвращает
  `["/", "1234"]`: первый элемент — сам корневой слеш. Мы выкидываем
  его фильтром и получаем `["1234"]`.
- `myapp://chat/` и `myapp://chat` — частей пути нет, `parts.count == 0`,
  ссылка не распознана, `init` вернёт `nil`. Проверка
  `components.last != "/"` тоже сработала бы, но читается хуже.
- `https://example.com/share/chat/77` — это Universal Link из 41.11,
  разбирается той же функцией: `.chat(id: "77")`.
- `https://evil.com/profile/5` — чужой домен, `nil`.

Мы прогнали эти адреса (и ещё `myapp://todos/all`, `https://example.com/profile/5`,
`https://example.com/share/x`) через `DeepLink(url:)` в отдельной
программе и получили ровно такие результаты: `.todos`, `.profile(id: "5")`
и `nil`.

Сам переход — в маршрутизаторе:

```swift
final class DeepLinkRouter {
    static let shared = DeepLinkRouter()
    weak var navigationController: UINavigationController?

    func open(_ url: URL) {
        guard let link = DeepLink(url: url) else {
            print("Неизвестная ссылка, игнорируем: \(url)")
            return
        }
        guard let nav = navigationController else { return }
        nav.popToRootViewController(animated: false)
        switch link {
        case .chat(let id):
            let vc = UIViewController()
            vc.title = "Чат \(id)"
            nav.pushViewController(vc, animated: true)
        case .profile(let id):
            let vc = UIViewController()
            vc.title = "Профиль \(id)"
            nav.pushViewController(vc, animated: true)
        case .todos:
            break // корневой экран и есть список
        }
    }
}
```

`weak var navigationController` — маршрутизатор живёт всё время работы
приложения (`static let shared`), а контроллер навигации — только пока
показано окно. Сильная ссылка удерживала бы его в памяти. Вместо
`UIViewController()` в реальном коде — твои экраны чата и профиля.

И два места в `SceneDelegate`, откуда приходят ссылки:

```swift
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let nav = UINavigationController(rootViewController: UIViewController())
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = nav
        window.makeKeyAndVisible()
        self.window = window
        DeepLinkRouter.shared.navigationController = nav

        // Холодный старт: приложение не работало, ссылка пришла вместе с запуском
        if let url = connectionOptions.urlContexts.first?.url {
            DeepLinkRouter.shared.open(url)
        }
        if let activity = connectionOptions.userActivities.first(where: {
            $0.activityType == NSUserActivityTypeBrowsingWeb
        }), let url = activity.webpageURL {
            DeepLinkRouter.shared.open(url)
        }
    }

    // Приложение уже запущено: пришла ссылка по URL-схеме
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        DeepLinkRouter.shared.open(url)
    }

    // Приложение уже запущено: пришла Universal Link (41.11)
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL else { return }
        DeepLinkRouter.shared.open(url)
    }
}
```

Главная ловушка — **холодный старт**. Если приложение не было запущено, iOS **не** вызывает
`scene(_:openURLContexts:)` — ссылка приезжает в
`connectionOptions.urlContexts` внутри `scene(_:willConnectTo:options:)`.
Аналогично Universal Link приезжает в `connectionOptions.userActivities`.
Кто обрабатывает ссылки только в `openURLContexts`, получает баг
«по ссылке приложение открывается, но на главном экране». Для Universal
Links это прямо написано в документации Supporting universal links in
your app: не запущенное приложение получает ссылку в
`scene(_:willConnectTo:options:)`, запущенное — в `scene(_:continue:)`.
С URL-схемой то же самое: `UIScene.ConnectionOptions.urlContexts` —
ссылки, с которыми сцену создали. Проверить у себя: закрой приложение
в симуляторе и выполни `xcrun simctl openurl booted "myapp://chat/1234"`
(симулятор может спросить «Открыть в …?»), затем повтори при открытом
приложении.

Слабое место URL-схем: **любое** приложение может объявить ту же схему
`myapp`, и iOS не гарантирует, какое откроется. Поэтому через схему
нельзя передавать ничего секретного (токены, коды входа).

## 41.11 Universal Links

**Universal Link** («универсальная ссылка») — обычная https-ссылка на
твой сайт, например `https://example.com/share/chat/1234`. Если
приложение установлено — iOS откроет его и передаст ссылку. Если нет —
откроется сайт в Safari. Подделать нельзя: связь приложения и домена
подтверждает файл на твоём сервере, а сервер контролируешь только ты.

Настройка из трёх частей.

**1. Файл `apple-app-site-association` на сервере.** Имя — ровно такое,
**без** расширения `.json`. Адрес — `https://example.com/.well-known/apple-app-site-association`.
Отдавать по **https** с действительным сертификатом и **без
редиректов**. Для каждого поддомена (`www.example.com`, `m.example.com`)
нужен свой файл. Содержимое в актуальном формате (iOS 13+):

```json
{
  "applinks": {
    "details": [
      {
        "appIDs": [ "ABCDE12345.kz.example.playground" ],
        "components": [
          { "/": "/share/*", "comment": "Все ссылки, которыми делятся из приложения" },
          { "/": "/profile/*" },
          { "/": "/profile/settings", "exclude": true, "comment": "Эту страницу открываем в браузере" }
        ]
      }
    ]
  }
}
```

- `appIDs` — список приложений в формате `<Team ID>.<bundle ID>`.
  `ABCDE12345` — Team ID из 41.2.
- `components` — шаблоны адресов. Ключ `"/"` — путь, `*` — любая
  последовательность символов, `?` — ровно один символ. Есть ключи
  `"?"` для параметров запроса и `"#"` для фрагмента.
- `"exclude": true` — «эти адреса **не** открывать в приложении».
  Правила проверяются по порядку, срабатывает первое подходящее, поэтому
  исключения ставят **выше** общих правил, которые их перекрывают.
  В нашем примере `/profile/settings` стоит **после** `/profile/*`, и
  исключение не сработает — это задание для упражнения ниже.

В старых статьях встречается формат `"apps": []` + `"appID"` + `"paths"`
— это прежний формат для iOS 12 и старше. Раз у нас iOS 15+, нужен
только новый.

С iOS 14 устройства не скачивают этот файл с твоего сервера напрямую:
его забирает CDN Apple (сеть серверов Apple) — в течение 24 часов после
изменения, а устройства проверяют обновления примерно раз в неделю
после установки приложения. Значит, сервер должен быть доступен из
интернета, а правки файла доходят не мгновенно. Для разработки есть
режим в обход CDN: в entitlement пишут `applinks:example.com?mode=developer`,
а на устройстве включают Настройки → Разработчик → Associated Domains
Development.

**2. Entitlement в Xcode.** Signing & Capabilities → **+ Capability** →
**Associated Domains** → добавь строку `applinks:example.com`. Без
`https://`, без пути и без слеша в конце.

**3. Обработка в `SceneDelegate`** — уже написана в 41.10: метод
`scene(_:continue:)` для запущенного приложения и
`connectionOptions.userActivities` для холодного старта. Тип активности
— `NSUserActivityTypeBrowsingWeb`, адрес — `webpageURL`.

Документация
[Supporting universal links in your app](https://developer.apple.com/documentation/xcode/supporting-universal-links-in-your-app)
предупреждает: Universal Link — такой же вход в приложение извне, как
любой другой. Проверяй все параметры, отбрасывай кривые ссылки и не
давай ссылке **действовать** без подтверждения — например, удалять
данные.

Когда Universal Link **не** откроет приложение: если человек ввёл адрес
вручную в Safari, и если ссылка ведёт на тот же домен, на странице
которого он уже находится в Safari.

**Упражнение.** Исправь `components` так, чтобы `/profile/settings`
действительно открывался в браузере, а остальные `/profile/...` — в
приложении. Ответ — в конце главы.

## 41.12 Что когда использовать

| Сценарий                                   | Способ                             |
|--------------------------------------------|------------------------------------|
| Вход через внешний сервис (OAuth)          | `ASWebAuthenticationSession`, схема для возврата |
| Ссылка «посмотри профиль», которой делятся | Universal Link                     |
| Пуш, ведущий на экран                      | deep link в payload                |
| Переход из своего второго приложения       | URL-схема                          |
| QR-код на товаре                           | Universal Link                     |
| Ссылка в рекламе и письмах                 | Universal Link                     |

Universal Links предпочтительнее почти везде: их нельзя перехватить,
и они работают без приложения (откроется сайт). Для входа через
сторонний сервис Apple предлагает `ASWebAuthenticationSession`: он
показывает страницу входа и возвращает результат прямо в приложение,
перехват схемы другим приложением ему не страшен.

## 41.13 Кнопки в уведомлении: категории

К уведомлению можно добавить кнопки. Кнопки описываются заранее, при
запуске, и объединяются в **категорию**:

```swift
import UserNotifications

func registerNotificationCategories() {
    let accept = UNNotificationAction(
        identifier: "ACCEPT",
        title: "Принять",
        options: [.foreground]
    )
    let decline = UNNotificationAction(
        identifier: "DECLINE",
        title: "Отклонить",
        options: [.destructive]
    )
    let invitation = UNNotificationCategory(
        identifier: "INVITATION",
        actions: [accept, decline],
        intentIdentifiers: [],
        options: []
    )
    UNUserNotificationCenter.current().setNotificationCategories([invitation])
}

func handleInvitation(_ response: UNNotificationResponse) {
    switch response.actionIdentifier {
    case "ACCEPT":
        print("Принял приглашение")
    case "DECLINE":
        print("Отклонил приглашение")
    case UNNotificationDefaultActionIdentifier:
        print("Просто тапнул уведомление")
    default:
        break
    }
}
```

- `options: [.foreground]` — нажатие «Принять» открывает приложение.
- `options: [.destructive]` — кнопка «Отклонить» красная, приложение
  не открывается: действие обрабатывается в фоне.
- `setNotificationCategories` вызывают при каждом запуске, например из
  `didFinishLaunching`.
- `UNNotificationDefaultActionIdentifier` — тап по самому уведомлению,
  а не по кнопке.

В payload указывается категория:

```json
{
  "aps": {
    "alert": { "title": "Приглашение", "body": "Айгерим зовёт тебя в группу «Бег»" },
    "category": "INVITATION"
  },
  "invitation_id": "abc123"
}
```

Кнопки появляются, когда человек раскрывает уведомление (долгое нажатие
или свайп вниз). Нажатие прилетает в тот же `didReceive` из 41.8 — там
вызываешь `handleInvitation(response)`.

## 41.14 Notification Service Extension

Расширение, которое получает пуш **до** показа и может изменить его:
расшифровать текст, скачать картинку и прикрепить её. **Расширение**
(*app extension*) — отдельный небольшой исполняемый модуль внутри
твоего приложения со своим таргетом, который система запускает сама.

1. Xcode → File → New → Target → **Notification Service Extension**.
2. В payload — `"mutable-content": 1` и обязательно `alert`: расширение
   вызывается только для видимых уведомлений.

```json
{
  "aps": { "alert": { "title": "Новое фото", "body": "…" }, "mutable-content": 1 },
  "image_url": "https://example.com/p/1.jpg"
}
```

Код расширения, по мотивам шаблона Xcode 26:

```swift
import UserNotifications

final class NotificationService: UNNotificationServiceExtension {

    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttempt: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest,
                             withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        guard let content = request.content.mutableCopy() as? UNMutableNotificationContent else {
            contentHandler(request.content)
            return
        }
        bestAttempt = content
        content.title = "Расшифровано: \(content.title)"
        contentHandler(content)
    }

    override func serviceExtensionTimeWillExpire() {
        // Время почти вышло — отдаём то, что успели
        if let contentHandler, let bestAttempt {
            contentHandler(bestAttempt)
        }
    }
}
```

- `mutableCopy() as? UNMutableNotificationContent` — копия содержимого,
  которую можно менять. Не пиши `as!`: если
  приведение не удастся, расширение упадёт, и уведомление покажется
  без изменений. С `guard` мы явно отдаём оригинал.
- `contentHandler(content)` — «показывай вот это». Вызвать нужно ровно
  один раз.
- `serviceExtensionTimeWillExpire()` — у расширения ограниченное время
  (около 30 секунд). Если скачивание картинки не успело, система
  вызовет этот метод, и мы покажем хотя бы изменённый текст.

**Режим изоляции в расширении.** Настройка `SWIFT_DEFAULT_ACTOR_ISOLATION
= MainActor` есть в шаблоне **приложения** Xcode 26, а в шаблонах
расширений её нет: код расширения по умолчанию не привязан к главному
актору. Если ты для единообразия включишь MainActor и в расширении, этот
класс перестанет собираться: «main actor-isolated instance method
'didReceive(_:withContentHandler:)' has different actor isolation from
nonisolated overridden declaration». Лечится пометкой
`nonisolated final class NotificationService`. Мы проверили оба варианта
компилятором.

## 41.15 Тестирование пушей

**Симулятор.** Команда `simctl push` доставляет пуш прямо в симулятор,
без APNs и без сервера:

```bash
xcrun simctl push booted kz.example.playground payload.apns
```

Файл `payload.apns` — тот же JSON, что и для APNs. Bundle ID можно не
писать в команде, если добавить в JSON ключ верхнего уровня:

```json
{
  "Simulator Target Bundle": "kz.example.playground",
  "aps": {
    "alert": { "title": "Тест", "body": "Проверяем deep link" },
    "sound": "default"
  },
  "deep_link": "myapp://chat/1234"
}
```

Ограничения по справке `simctl push`: не больше 4096 байт и только
обычные пуши приложения (VoIP и другие типы не поддерживаются). Ещё
удобнее — перетащить файл `.apns` на окно симулятора.

**Реальное устройство.** В Apple Developer есть веб-инструмент **Push
Notifications Console** (из раздела CloudKit Console): вставляешь device
token, собираешь payload и отправляешь — без своего сервера. Там же
журнал доставки. Не забудь выбрать среду: сборка из Xcode — Development,
из TestFlight — Production (41.3).

## 41.16 Практика хороших пушей

- **Только то, что важно человеку.** Не каждый лайк стоит пуша.
- **Настройки по типам.** Дай выключить отдельные виды уведомлений,
  а не только все сразу. Рекламные — отдельно и выключены по умолчанию
  (4.5.4).
- **Тихие часы.** Не шли несрочное ночью по часовому поясу человека:
  22:00 в Алматы (UTC+5) — это 17:00 по UTC, поэтому сервер должен
  хранить часовой пояс пользователя, а не считать «ночь» по своему времени.
- **Provisional authorization** (iOS 12+): опция `.provisional` в
  `requestAuthorization`. Системный диалог не показывается, уведомления
  тихо попадают в Центр уведомлений, и человек сам решает там,
  «Оставить» их или «Выключить».

## 41.17 Ответы к упражнениям

**41.8 — не показывать пуш открытого чата.** Храним открытый чат в
маршрутизаторе и сравниваем в `willPresent`:

```swift
extension DeepLinkRouter {
    // В реальном коде экран чата выставляет id в viewWillAppear и сбрасывает в viewWillDisappear
    static var currentChatID: String?
}

extension AppDelegate {
    func presentationOptions(for notification: UNNotification) -> UNNotificationPresentationOptions {
        let userInfo = notification.request.content.userInfo
        if let link = (userInfo["deep_link"] as? String).flatMap(URL.init(string:)),
           case .chat(let id)? = DeepLink(url: link),
           id == DeepLinkRouter.currentChatID {
            return []           // человек уже в этом чате
        }
        return [.banner, .list, .sound, .badge]
    }
}
```

В `willPresent` вызываем `completionHandler(presentationOptions(for: notification))`.
Проверка: открой «чат 1234», отправь `simctl push` с `myapp://chat/1234` —
баннера нет; с `myapp://chat/77` — баннер есть.

`static var` в классе на главном акторе компилятор Swift 6 пропускает:
переменная изолирована главным актором, гонки нет.

**41.11 — исключение.** Исключение ставим **перед** общим правилом:

```json
"components": [
  { "/": "/profile/settings", "exclude": true },
  { "/": "/share/*" },
  { "/": "/profile/*" }
]
```

Теперь `/profile/settings` совпадает с первым правилом и открывается в
браузере, а `/profile/42` проходит мимо него и совпадает с третьим.

## Что мы выучили

- **APNs** доставляет пуши; сервер подписывает запросы ключом `.p8`
  (JWT обновлять раз в 20–60 минут). Ключ не истекает, сертификат `.p12`
  живёт год.
- **Две среды**: sandbox для сборок из Xcode, production для TestFlight
  и App Store. Токены из разных сред не взаимозаменяемы.
- **Регистрация** при каждом запуске, токен не кэшировать. Разрешение
  на показ — отдельно, после объяснения.
- **4.5.4**: пуши не обязательны для работы, реклама — только с явного
  согласия и с возможностью отказаться.
- **Payload** до 4 КБ; свои ключи — вне `aps`; заголовки
  `apns-push-type`, `apns-priority`, `apns-topic`.
- **`willPresent`** — приложение на экране, **`didReceive`** — тап.
  Делегат ставить в `didFinishLaunching`.
- **Тихие пуши**: `content-available: 1`, priority 5, 30 секунд работы,
  доставка не гарантирована.
- **Deep links**: один `DeepLink`-парсер и один маршрутизатор; ссылки
  на холодном старте приходят в `connectionOptions`.
- **Universal Links**: `apple-app-site-association` без расширения в
  `/.well-known/`, формат `appIDs` + `components`, https без редиректов,
  Associated Domains `applinks:домен`.
- **Notification Service Extension**: `mutable-content: 1`, без `as!`;
  расширения по умолчанию не на главном акторе.
- **Тесты**: `xcrun simctl push`, Push Notifications Console для
  устройства.

## Apple Developer Documentation

- [Registering your app with APNs](https://developer.apple.com/documentation/usernotifications/registering-your-app-with-apns) — регистрация, device token, почему не кэшировать токен.
- [Establishing a token-based connection to APNs](https://developer.apple.com/documentation/usernotifications/establishing-a-token-based-connection-to-apns) — ключ `.p8`, team-scoped и topic-specific ключи, обновление JWT.
- [Sending notification requests to APNs](https://developer.apple.com/documentation/usernotifications/sending-notification-requests-to-apns) — серверы sandbox/production, заголовки, лимит 4 КБ.
- [Generating a remote notification](https://developer.apple.com/documentation/usernotifications/generating-a-remote-notification) — ключи словаря `aps`.
- [Pushing background updates to your app](https://developer.apple.com/documentation/usernotifications/pushing-background-updates-to-your-app) — тихие пуши и их ограничения.
- [`aps-environment`](https://developer.apple.com/documentation/bundleresources/entitlements/aps-environment) — какая среда APNs у какой сборки.
- [`UNUserNotificationCenterDelegate`](https://developer.apple.com/documentation/usernotifications/unusernotificationcenterdelegate) — `willPresent` и `didReceive`.
- [`UNNotificationCategory`](https://developer.apple.com/documentation/usernotifications/unnotificationcategory) — кнопки в уведомлениях.
- [`UNNotificationServiceExtension`](https://developer.apple.com/documentation/usernotifications/unnotificationserviceextension) — изменение содержимого пуша перед показом.
- [Testing notifications using the Push Notification Console](https://developer.apple.com/documentation/usernotifications/testing-notifications-using-the-push-notification-console) — отправка тестовых пушей на устройство.
- [Supporting associated domains](https://developer.apple.com/documentation/xcode/supporting-associated-domains) — файл `apple-app-site-association`, CDN Apple, режим разработчика.
- [Supporting universal links in your app](https://developer.apple.com/documentation/xcode/supporting-universal-links-in-your-app) — обработка Universal Links в приложении со сценами.
- [Defining a custom URL scheme for your app](https://developer.apple.com/documentation/xcode/defining-a-custom-url-scheme-for-your-app) — регистрация URL-схемы и её ограничения.
- [App Review Guidelines — 4.5.4](https://developer.apple.com/app-store/review/guidelines/#apple-sites-and-services) — правила для push-уведомлений.

→ [Глава 42. Production: widgets + App Intents](./64-production-widgets-intents.md)
