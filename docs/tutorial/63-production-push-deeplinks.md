# Глава 41. Production: push notifications + deep links

Два связанных production-сценария: отправка пушей и приём deep
link'ов (вне приложения → внутрь экрана).

## 41.1 Push setup — Apple Developer Account

1. Открой [developer.apple.com](https://developer.apple.com).
2. **Certificates, Identifiers & Profiles → Identifiers** → выбери
   свой App ID.
3. Включи **Push Notifications**.
4. Создай **APNs key** (`.p8` файл) или **certificate** (`.p12`).
5. Скачай — он понадобится backend'у.

С 2020+ Apple рекомендует **APNs key**: один для всех приложений,
не истекает. Сертификаты — старый flow, истекают через год.

## 41.2 Xcode setup

В Xcode → Project → Signing & Capabilities:

1. Add Capability → **Push Notifications**.
2. Add Capability → **Background Modes** → ✅ Remote notifications.

Это добавит entitlement `aps-environment = development` (для debug)
или `production` (для App Store).

## 41.3 Registration в коде

В `AppDelegate.application(_:didFinishLaunching:)` или в
`SceneDelegate.scene(_:willConnectTo:)`:

```swift
UNUserNotificationCenter.current().delegate = self

Task {
    let granted = try await UNUserNotificationCenter.current()
        .requestAuthorization(options: [.alert, .sound, .badge])
    if granted {
        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
}
```

После `registerForRemoteNotifications()` iOS зовёт делегат с device
token:

```swift
func application(_ application: UIApplication,
                 didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    let token = deviceToken.map { String(format: "%02x", $0) }.joined()
    // Отправь token на свой backend
    Task { try? await API.registerDevice(token: token) }
}

func application(_ application: UIApplication,
                 didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("Push registration failed: \(error)")
}
```

`deviceToken: Data` → hex string. Backend хранит этот token, при
отправке push'а — использует его для APNs запроса.

## 41.4 Permission primer для push'ей

Apple **не** обязывает использовать primer для push'ей (в отличие от
location / photos). Но conversion **сильно** выше с primer'ом.

Примерно как в Главе 7. Дополнительная мотивация:

«Включи уведомления, чтобы:
- быть в курсе новых сообщений
- получить напоминание о незавершённых задачах
- узнать о завершении длительной операции»

После primer'а → системный alert через `requestAuthorization`.

## 41.5 Notification payload

APNs принимает JSON:

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

`aps.alert` — заголовок и тело видны юзеру.
`aps.badge` — число на иконке приложения.
`aps.sound` — звук.
`deep_link` — кастомный параметр, обрабатываем в коде.

## 41.6 Receive notifications

```swift
extension AppDelegate: UNUserNotificationCenterDelegate {

    // Foreground — приложение открыто, юзер видит push
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Хочешь показать banner и звук даже при открытом приложении?
        completionHandler([.banner, .sound, .badge])
    }

    // Tap on notification
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        if let deepLink = userInfo["deep_link"] as? String,
           let url = URL(string: deepLink) {
            handleDeepLink(url)
        }
        completionHandler()
    }
}
```

`willPresent` — называется когда push приходит, а приложение в
**foreground**. Если вернёшь `[]` — push не покажется (silent).

`didReceive` — когда юзер тапает по push notification (в Notification
Center).

## 41.7 Silent push

Push без UI, только для **фоновой работы**:

```json
{
  "aps": {
    "content-available": 1
  },
  "data": { "type": "sync", "task_id": "123" }
}
```

iOS зовёт `application(_:didReceiveRemoteNotification:fetchCompletionHandler:)`:

```swift
func application(_ application: UIApplication,
                 didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                 fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    // Загрузить данные, сохранить локально
    Task {
        await syncData()
        completionHandler(.newData)
    }
}
```

`completionHandler` — обязательно. Без него iOS считает push медленным
и **перестанет доставлять** silent push'и этому приложению.

## 41.8 Deep links — URL schemes

`Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>myapp</string>
        </array>
    </dict>
</array>
```

Теперь URL `myapp://...` открывает твоё приложение.

Handler в `SceneDelegate`:

```swift
func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    guard let url = URLContexts.first?.url else { return }
    handleDeepLink(url)
}

private func handleDeepLink(_ url: URL) {
    // myapp://chat/1234
    let components = url.pathComponents
    if url.host == "chat", let chatId = components.first {
        showChat(id: chatId)
    }
}
```

URL scheme — **простой** способ, но любое приложение может объявить
такую же схему. Не подходит для секретных deep link'ов.

## 41.9 Universal Links

URL вида `https://example.com/share/abc` открывают приложение, если
оно установлено, иначе — Safari. Безопасно (домен принадлежит тебе).

Setup:

1. **`apple-app-site-association`** на твоём сервере по адресу
   `https://example.com/.well-known/apple-app-site-association`:

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "TEAMID.com.yourcompany.app",
        "paths": [ "/share/*", "/profile/*" ]
      }
    ]
  }
}
```

2. Xcode → Project → Signing & Capabilities → **Associated Domains** →
   `applinks:example.com`.

3. В `SceneDelegate`:

```swift
func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
          let url = userActivity.webpageURL else { return }
    handleDeepLink(url)
}
```

iOS теперь:
- Если приложение установлено — `continue userActivity` срабатывает.
- Если не установлено — открывается Safari с URL.

## 41.10 Когда что использовать

| Сценарий                         | Способ            |
|----------------------------------|-------------------|
| OAuth callback                   | URL scheme        |
| Sharable link «открой профиль»   | Universal Link    |
| Push с конкретным экраном        | Deep link в payload |
| Open from another app (Twitter)  | URL scheme        |
| QR code → open product           | Universal Link    |

Universal Links предпочтительнее, потому что **безопасны** (нельзя
украсть схему) и **fallback в web** (URL открывается, даже если
приложения нет).

## 41.11 Push категории и actions

Можно добавить **кнопки** в push notification:

```swift
let acceptAction = UNNotificationAction(
    identifier: "ACCEPT",
    title: "Принять",
    options: [.foreground]
)
let declineAction = UNNotificationAction(
    identifier: "DECLINE",
    title: "Отклонить",
    options: [.destructive]
)
let category = UNNotificationCategory(
    identifier: "INVITATION",
    actions: [acceptAction, declineAction],
    intentIdentifiers: [],
    options: []
)
UNUserNotificationCenter.current().setNotificationCategories([category])
```

В payload:

```json
{
  "aps": { "alert": "...", "category": "INVITATION" },
  "invitation_id": "abc123"
}
```

Юзер видит кнопки прямо в push (long-press или swipe в Notification
Center). Их action прилетает в делегат `didReceive`.

## 41.12 Notification Service Extension

Для **изменения** содержимого push notification на устройстве (например,
расшифровать, скачать картинку):

1. Xcode → New Target → **Notification Service Extension**.
2. В extension:

```swift
class NotificationService: UNNotificationServiceExtension {
    override func didReceive(_ request: UNNotificationRequest,
                             withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        let mutable = request.content.mutableCopy() as! UNMutableNotificationContent
        mutable.title = "Расшифровано: \(mutable.title)"
        contentHandler(mutable)
    }
}
```

В payload — `mutable-content: 1`:

```json
{
  "aps": { "alert": "...", "mutable-content": 1 }
}
```

## 41.13 Testing push'ей

**Симулятор** (iOS 16+):

```bash
xcrun simctl push booted com.your.app payload.apns
```

`payload.apns`:

```json
{
  "Simulator Target Bundle": "com.your.app",
  "aps": {
    "alert": "Test push",
    "sound": "default"
  }
}
```

**Реальное устройство** — через [Pusher app](https://pusher.tech) или
свой backend.

## 41.14 Best practices

- **Личные** уведомления, не шумные. Не каждый like'ом trigger'ить
  push.
- **Категоризация** в Settings. Юзер должен выключить отдельные
  категории, не все целиком.
- **Quiet hours** — не пинговать ночью (используй timezone юзера).
- **`provisional`** authorization — iOS 12+ позволяет тихо отправлять
  push без alert'а, юзер сам решит включать.

## 📋 Что мы выучили

- **Push setup**: developer.apple.com → APNs key + Xcode capability
  + entitlement.
- **Registration** через `UNUserNotificationCenter.requestAuthorization`
  + `UIApplication.registerForRemoteNotifications()`.
- **Device token** → отправь backend'у.
- **Receive**: `willPresent` (foreground), `didReceive` (tap).
- **Silent push** — `content-available: 1`, `completionHandler`
  обязательно.
- **URL scheme** для простых deep link'ов, `CFBundleURLTypes` в
  Info.plist.
- **Universal Links** — secure, `apple-app-site-association` на
  сервере + Associated Domains в Xcode.
- **Notification categories** — кнопки прямо в push.
- **Notification Service Extension** — modification (decrypt,
  download).
- **Simulator** — `xcrun simctl push booted ... payload.apns`.

→ [Глава 42. Production: widgets + App Intents](./64-production-widgets-intents.md)
