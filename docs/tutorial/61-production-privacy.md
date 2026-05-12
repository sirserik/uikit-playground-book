# Глава 39. Production: App Privacy + Privacy Manifest

С 2024 Apple усилили требования к privacy. Без правильного заявления
данных приложение **не пропустят** в App Store.

Разбираем, что нужно заполнить в App Store Connect и что положить
в сам проект.

## 39.1 App Privacy Questionnaire (в App Store Connect)

Перед submission ты заполняешь форму **App Privacy** — какие данные
собираешь, для чего, привязаны ли к пользователю.

Категории данных:

- **Contact Info** — name, email, phone, address.
- **Health & Fitness** — медицинские, спортивные.
- **Financial Info** — payment, credit.
- **Location** — точное, приблизительное.
- **Sensitive Info** — раса, ориентация, политические взгляды.
- **Contacts** — список контактов из адресной книги.
- **User Content** — emails, messages, photos.
- **Browsing History**.
- **Search History**.
- **Identifiers** — ID устройства, account ID.
- **Purchases** — история покупок.
- **Usage Data** — что юзер делает в приложении.
- **Diagnostics** — crash logs, performance.
- **Other Data**.

Для каждой категории — три вопроса:

1. Собираешь ли? Да или нет.
2. Привязаны ли к user identity? Yes или No.
3. Для чего используются? Analytics, App Functionality, Product
   Personalization, Third-Party Advertising, Developer's Advertising
   или Other.

Анкета — legally binding. Apple проверяет, и за расхождение с
реальным поведением приложение блокируют.

## 39.2 Privacy Manifest (`PrivacyInfo.xcprivacy`)

С iOS 17 / Xcode 15 — обязателен для **новых** apps и обновлений.

Это XML/Plist файл, где ты декларируешь:

1. Какие user data собираешь.
2. Какие «required reason APIs» используешь (см. ниже).
3. Tracking domains.

Файл создаётся в Xcode: `File → New → File → Privacy → App Privacy`.
Имя — `PrivacyInfo.xcprivacy`. Кладётся в bundle.

Пример минимального:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
    <key>NSPrivacyTracking</key>
    <false/>
    <key>NSPrivacyCollectedDataTypes</key>
    <array/>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryFileTimestamp</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>C617.1</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```

## 39.3 Required Reason APIs

Apple ввели список **«chink» API**, которые часто используют для
fingerprint'инга. Если используешь — должен указать legitimate
reason в Privacy Manifest.

Категории и примеры:

- **`NSPrivacyAccessedAPICategoryFileTimestamp`** — `creationDate`,
  `modificationDate` файлов. Reason `C617.1` — для отображения юзеру.
- **`NSPrivacyAccessedAPICategorySystemBootTime`** — `mach_absolute_time`.
- **`NSPrivacyAccessedAPICategoryDiskSpace`** — свободное место на
  диске.
- **`NSPrivacyAccessedAPICategoryActiveKeyboards`** — список клавиатур.
- **`NSPrivacyAccessedAPICategoryUserDefaults`** — да, **UserDefaults
  тоже** в списке.

Полный список и reasons — в [Apple docs](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files/describing_use_of_required_reason_api).

Для UserDefaults default reason — `CA92.1` (App functionality).

## 39.4 Collected data types

Если приложение собирает данные:

```xml
<key>NSPrivacyCollectedDataTypes</key>
<array>
    <dict>
        <key>NSPrivacyCollectedDataType</key>
        <string>NSPrivacyCollectedDataTypeName</string>
        <key>NSPrivacyCollectedDataTypeLinked</key>
        <true/>
        <key>NSPrivacyCollectedDataTypeTracking</key>
        <false/>
        <key>NSPrivacyCollectedDataTypePurposes</key>
        <array>
            <string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
        </array>
    </dict>
</array>
```

- `NSPrivacyCollectedDataType` — тип (Name, Email, Phone, ...).
- `Linked` — привязаны ли к user account.
- `Tracking` — используется ли для tracking.
- `Purposes` — для чего (AppFunctionality, Analytics, Advertising, ...).

Должно **совпадать** с тем, что в App Privacy Questionnaire.

## 39.5 SDK Privacy Manifests

Если используешь third-party SDK (Firebase, AppsFlyer, и т.д.), у
них **обязательно** свой `PrivacyInfo.xcprivacy`. Если у SDK нет —
Apple отказывает в submission.

С 2024 года Apple **отзывает** apps использующие SDKs без манифеста.

Проверь: в навигаторе Xcode → выдвинь `Frameworks` → у каждой
зависимости должен быть `PrivacyInfo.xcprivacy`. Если нет — обнови
SDK или замени.

## 39.6 Info.plist usage descriptions

Параллельно с Privacy Manifest, ты должен заполнить usage description
для каждого permission'а в `Info.plist`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Нужно, чтобы показать погоду в твоём городе.</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>Нужно, чтобы вставить фото в заметку.</string>

<key>NSCameraUsageDescription</key>
<string>Нужно, чтобы сделать аватарку.</string>

<key>NSMicrophoneUsageDescription</key>
<string>Нужно, чтобы записать голосовое сообщение.</string>

<key>NSContactsUsageDescription</key>
<string>Нужно, чтобы пригласить друзей.</string>

<key>NSFaceIDUsageDescription</key>
<string>Используем Face ID для безопасного входа в Профиль.</string>
```

Без них — **крах** приложения при первой попытке доступа.

И эти строки **видит юзер** в системном диалоге permission'а.
Сформулируй понятно «зачем».

## 39.7 App Tracking Transparency (ATT)

Если приложение трекает юзера **между приложениями** (advertising IDFA),
нужен ATT prompt:

```swift
import AppTrackingTransparency

ATTrackingManager.requestTrackingAuthorization { status in
    switch status {
    case .authorized: // can use IDFA
    case .denied, .notDetermined, .restricted: // anonymous
    @unknown default: break
    }
}
```

iOS показывает alert «Ask App not to track / Allow». Без явного
разрешения — IDFA = `00000000-0000-0000-0000-000000000000`.

Если **не** делаешь tracking — не вызывай ATT. Apple обращает
внимание.

`NSUserTrackingUsageDescription` — отдельный ключ в Info.plist:

```xml
<key>NSUserTrackingUsageDescription</key>
<string>Используем для персонализации рекламы. Можно отказаться.</string>
```

## 39.8 Local data — что хранить, что нет

В Keychain держим токены, пароли и любую чувствительную мелочь.
Содержимое шифруется ключом устройства, а сами записи переживают
переустановку приложения (нюанс: при удалении приложения они тоже
остаются, пока ты явно не вычистишь — см. главу 40 про account
deletion).

UserDefaults — это про настройки, флаги и мелкие данные интерфейса.
Хранится в plain plist, поэтому для секретов не подходит. По той же
причине UserDefaults сейчас попал в список Required Reason API
(см. 39.3).

В `Documents/` кладём пользовательский контент: заметки, фото,
сгенерированные документы. iCloud бэкап подхватывает эту директорию,
поэтому юзер увидит свои данные на новом устройстве.

`Library/Caches/` — для кэша, который можно потерять без последствий.
iOS освобождает эту директорию при нехватке места.

`tmp/` — для временных файлов на время одного сеанса. iOS может
вычистить её в любой момент.

## 39.9 GDPR / CCPA / российский 152-ФЗ

Если работаешь в EU / California / России — нужно дополнительно:

- **Consent banner** при первом запуске.
- **Privacy Policy URL** — обязательное поле в App Store Connect.
- **Account deletion** — закон требует (см. Глава 40).
- **Data export** — пользователь может попросить копию своих данных.

В playground мы это пропускаем, но в production — обязательно.

## 39.10 Что **запрещено**

- **Fingerprinting** — определять юзера по hardware-параметрам
  (mac address, IMEI, точная конфигурация). Apple banned.
- **Прокачка `UDID`** через workaround'ы — мгновенный bann.
- **Trade user data** — продавать кому-то без согласия.

## 39.11 Network security

`Info.plist` для разрешения HTTP (не HTTPS):

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

**Никогда не делай в production**. Apple просит обоснование при
review.

Для **одного домена**:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSExceptionDomains</key>
    <dict>
        <key>example.com</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
        </dict>
    </dict>
</dict>
```

## 📋 Что мы выучили

- **App Privacy Questionnaire** в App Store Connect — обязательно.
  Legally binding.
- **`PrivacyInfo.xcprivacy`** — Privacy Manifest. Required APIs +
  Collected Data + Tracking.
- **Required Reason APIs** — даже UserDefaults в списке. Указывай
  reason code.
- **SDK Privacy Manifests** — третьи SDK обязаны иметь свой манифест
  с 2024.
- **Info.plist usage descriptions** — для каждого permission'а
  (`NSCameraUsageDescription`, etc.). Без них — крах.
- **ATT** — только если действительно trackуешь между приложениями.
- **Keychain** для secrets, **UserDefaults** для settings,
  **Documents** для контента.
- **GDPR / CCPA / 152-ФЗ** — consent banner, privacy policy URL,
  data export, account deletion.
- **`NSAppTransportSecurity`** — никогда `NSAllowsArbitraryLoads` в
  production. Только exception для конкретного домена.

## Apple Developer Documentation

- [App Privacy Details on the App Store](https://developer.apple.com/app-store/app-privacy-details/) — что и как заполнять в анкете App Privacy в App Store Connect.
- [Privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files) — структура `PrivacyInfo.xcprivacy`, типы данных, tracking-домены.
- [Describing use of required reason API](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files/describing_use_of_required_reason_api) — полный список категорий и reason-кодов (UserDefaults, FileTimestamp, SystemBootTime и пр.).
- [App Tracking Transparency](https://developer.apple.com/documentation/apptrackingtransparency) — фреймворк ATT, статусы авторизации, IDFA.
- [`ATTrackingManager`](https://developer.apple.com/documentation/apptrackingtransparency/attrackingmanager) — конкретный класс, его `requestTrackingAuthorization(completionHandler:)`.
- [App Transport Security](https://developer.apple.com/documentation/security/preventing_insecure_network_connections) — правила HTTPS-only и допустимые исключения.
- [Info.plist keys reference](https://developer.apple.com/documentation/bundleresources/information_property_list) — список всех `NSXxxUsageDescription` ключей.

→ [Глава 40. Production: Account deletion flow](./62-production-account-deletion.md)
