# Глава 39. Production: App Privacy + Privacy Manifest

Прежде чем приложение попадёт в App Store, ты дважды рассказываешь Apple,
что оно делает с данными пользователя. Первый раз — в анкете **App Privacy**
в App Store Connect: из неё на странице приложения собирается блок
«Конфиденциальность приложения», который люди называют «этикеткой
конфиденциальности» (Apple — *Privacy Nutrition Label*, по аналогии с
этикеткой состава на продуктах). Второй раз — в файле
**`PrivacyInfo.xcprivacy`** внутри самого приложения (*privacy manifest*,
«манифест конфиденциальности»).

Анкета — для людей: что ты собираешь и зачем. Манифест — для Apple и
Xcode: какие «чувствительные» системные API трогает код и какие данные
уходят с устройства. Если одно не совпадает с другим или с поведением
приложения — это повод для отказа на проверке.

Все требования ниже сверены с документацией Apple в сентябре 2026 года.
Пункты App Review Guidelines (дальше «Guidelines») указаны номерами.

## 39.1 Анкета App Privacy в App Store Connect

Анкета находится в App Store Connect: страница приложения → App Privacy.
Без неё новое приложение и обновление отправить на проверку нельзя. При
этом ответы можно менять в любой момент **без** выпуска новой версии —
например, если ты подключил аналитику на сервере.

Главное слово анкеты — **collect** («собирать»). По определению Apple
на странице
[App privacy details](https://developer.apple.com/app-store/app-privacy-details/)
«собирать» — значит **передавать данные с устройства** так, что ты или
твои партнёры (сторонние SDK — чужие библиотеки внутри твоего
приложения: аналитика, реклама, крэш-репорты) можете получить к ним
доступ дольше, чем нужно, чтобы ответить на запрос прямо сейчас.

Два примера, чтобы почувствовать границу:

- Приложение «Погода» (глава 15) отправляет координаты на сервер прогноза,
  сервер отвечает и **ничего не сохраняет** — это не сбор. Если сервер
  пишет координаты в лог и хранит месяц — это сбор (Location).
- Заметки хранятся только на телефоне и никуда не уходят — не сбор,
  даже если это личные тексты.

Для каждого типа данных, который ты собираешь, анкета спрашивает три вещи:

1. **Для чего** используются данные (можно выбрать несколько целей).
2. **Связаны ли с личностью** (*linked to the user*) — через аккаунт,
   устройство или другие детали. Apple прямо пишет, что «персональные
   данные» по законам о приватности считаются связанными.
3. **Используются ли для трекинга** (*tracking*) — о нём в 39.7.

Категории данных по актуальному списку Apple:

| Категория         | Что внутри (примеры)                                        |
|-------------------|-------------------------------------------------------------|
| Contact Info      | имя, email, телефон, адрес                                  |
| Health & Fitness  | медицинские данные, данные о тренировках                   |
| Financial Info    | платёжные данные, кредитная история, доходы                 |
| Location          | точная и приблизительная геопозиция                         |
| Sensitive Info    | этническая принадлежность, взгляды, биометрия и т.п.        |
| Contacts          | адресная книга, социальный граф                              |
| User Content      | сообщения, фото и видео, аудио, игровые сохранения, обращения в поддержку |
| Browsing History  | что человек смотрел вне приложения (сайты)                  |
| Search History    | поисковые запросы внутри приложения                          |
| Identifiers       | User ID, Device ID (в том числе рекламный идентификатор)    |
| Purchases         | история покупок                                              |
| Usage Data        | нажатия, запуски, просмотренная реклама                     |
| Diagnostics       | крэши, скорость запуска, расход энергии                     |
| Surroundings      | сканирование окружения (AR)                                  |
| Body              | движения рук и головы (Apple Vision Pro)                     |
| Other Data        | всё остальное                                                |

Граница «точная / приблизительная геопозиция» у Apple задана числом:
точная — координаты с **тремя и более** знаками после запятой. Три знака
широты — это примерно 100 метров (один градус широты ≈ 111 км, тысячная
доля ≈ 111 м). Координаты `43.238, 76.945` уже указывают на квартал в
Алматы, а `43.2, 76.9` — на район в несколько километров.

Цели (*purposes*):

- **Third-Party Advertising** — чужая реклама в твоём приложении или
  передача данных тем, кто её показывает;
- **Developer's Advertising or Marketing** — твоя реклама и рассылки;
- **Analytics** — изучение поведения пользователей;
- **Product Personalization** — рекомендации, персональная лента;
- **App Functionality** — вход, работа функций, защита от мошенничества,
  крэш-репорты, поддержка;
- **Other Purposes** — остальное.

Некоторые данные можно не указывать (*optional disclosure*), только если
выполнены **все** условия сразу: данные не для трекинга и не для рекламы,
собираются редко, не входят в основную функцию, человек сам каждый раз
заполняет форму и видит, что отправляет. Типичный пример — необязательная
форма обратной связи. Если выполнено не всё — указывать нужно.

Ещё пара правил, на которых часто ошибаются:

- **Данные SDK — тоже твои.** Если Firebase Crashlytics отправляет
  крэш-логи, в анкете должна быть Diagnostics → Crash Data.
- **IP-адрес** указывается по тому, как ты его используешь: для
  геолокации — как Location, для диагностики — как Diagnostics.
- **Чат между пользователями** — это Emails or Text Messages, даже если
  это не SMS.

Отвечать за точность анкеты по Guidelines обязан ты: раздел **2.3**
требует, чтобы метаданные, «включая информацию о конфиденциальности»,
соответствовали поведению приложения, а раздел **5.1.2** запрещает
передавать персональные данные без разрешения человека. Приложения,
которые делятся данными без согласия, по 5.1.2(i) могут снять с продажи.

**Упражнение.** Заполни анкету «на бумаге» для Todo из главы 12: задачи
хранятся в `UserDefaults`, при первом запуске загружаются демо-задачи
с `dummyjson.com`, аналитики нет. Что будет в анкете? Ответ — в конце
главы.

## 39.2 Privacy Manifest — `PrivacyInfo.xcprivacy`

Манифест — это файл в формате property list (тот же формат, что у
`Info.plist`: XML со словарями и массивами), который лежит внутри
бандла приложения. Бандл (*bundle*) — папка `.app`, в которую Xcode
складывает бинарник, картинки, `Info.plist` и остальные ресурсы.

В манифесте четыре ключа верхнего уровня:

| Ключ                            | Что описывает                                           |
|---------------------------------|---------------------------------------------------------|
| `NSPrivacyTracking`             | используется ли что-то в приложении для трекинга        |
| `NSPrivacyTrackingDomains`      | домены, к которым обращается код для трекинга           |
| `NSPrivacyCollectedDataTypes`   | какие данные собираются (то же, что в анкете 39.1)      |
| `NSPrivacyAccessedAPITypes`     | какие required reason API используются и по какой причине |

Требование к манифесту приходит от App Store, а не от версии iOS. В
документации
[Describing use of required reason API](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)
сказано: с **1 мая 2024 года** App Store Connect **не принимает**
приложения, которые используют required reason API и не описали причину
в манифесте. Минимальная версия iOS у приложения значения не имеет:
приложение с iOS 15 обязано иметь манифест так же, как с iOS 26.

Как создать в Xcode 26: **File → New → File from Template…** → раздел
**Resource** → **App Privacy**. Имя по умолчанию — `PrivacyInfo`, файл
получит расширение `.xcprivacy`. Убедись, что галочка стоит у таргета
приложения: файл должен попасть в бандл. Xcode открывает его в
табличном редакторе; на исходный XML можно переключиться через
контекстное меню файла → Open As → Source Code.

Минимальный манифест для нашего playground-приложения:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyTracking</key>
    <false/>
    <key>NSPrivacyTrackingDomains</key>
    <array/>
    <key>NSPrivacyCollectedDataTypes</key>
    <array/>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>CA92.1</string>
            </array>
        </dict>
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

Разбор:

- `NSPrivacyTracking = false` — мы никого не трекаем.
- `NSPrivacyTrackingDomains` — пустой массив: трекинговых доменов нет.
  Если бы `NSPrivacyTracking` был `true`, сюда пришлось бы перечислить
  домены рекламных сетей. iOS блокирует обращения к этим доменам, пока
  человек не разрешил трекинг (39.7).
- `NSPrivacyCollectedDataTypes` — пустой массив: с устройства ничего
  не собираем (в смысле 39.1).
- `NSPrivacyAccessedAPITypes` — два словаря. Первый: мы пользуемся
  `UserDefaults` (Todo, настройки Profile), причина `CA92.1`. Второй:
  Notes из главы 13 читает даты изменения файлов в своей папке,
  причина `C617.1`. Что значат эти коды — в 39.3.

Проверить, что XML не сломан, можно командой `plutil -lint PrivacyInfo.xcprivacy` —
она ответит `OK` или покажет строку с ошибкой.

## 39.3 Required reason API — что это и какие коды выбрать

Некоторые системные API сами по себе безобидны, но их можно использовать
для **fingerprinting** — «снятия отпечатка»: сложить много мелких
признаков устройства (время загрузки системы, объём диска, список
клавиатур) в уникальный номер и узнавать человека без его согласия.
Apple пишет прямо: fingerprinting запрещён, **даже если** человек
разрешил трекинг.

Поэтому для таких API нужно объявить причину — короткий код из
фиксированного списка Apple. Причина ограничивает, что ты имеешь право
делать с данными. Например, `DDA9.1` разрешает показывать даты файлов
пользователю, но запрещает отправлять их с устройства.

Актуальные категории и коды (сентябрь 2026, из справки ключа
[NSPrivacyAccessedAPIType](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype)):

**`NSPrivacyAccessedAPICategoryUserDefaults`** — `UserDefaults`.

- `CA92.1` — читаешь и пишешь данные, доступные только самому приложению.
  Это наш случай почти всегда.
- `1C8F.1` — данные общие для приложений, расширений и App Clip одной
  App Group (например, приложение и виджет из главы 42).
- `C56D.1` — только для сторонних SDK, которые дают обёртку над
  `UserDefaults`.
- `AC6B.1` — чтение настроек MDM (управление корпоративными устройствами).

**`NSPrivacyAccessedAPICategoryFileTimestamp`** — даты создания и
изменения файлов: `FileAttributeKey.creationDate`/`.modificationDate`,
`URLResourceKey.creationDateKey`/`.contentModificationDateKey`,
`UIDocument.fileModificationDate`, низкоуровневые `stat`, `getattrlist` и
родственные.

- `DDA9.1` — показать даты файлов пользователю; с устройства не
  отправлять.
- `C617.1` — даты, размер и другие метаданные файлов **внутри контейнера
  приложения**, контейнера App Group или CloudKit-контейнера приложения.
- `3B52.1` — метаданные файлов, к которым пользователь сам дал доступ
  (например, выбрал через document picker).
- `0A2A.1` — только для SDK-обёрток.

**`NSPrivacyAccessedAPICategorySystemBootTime`** — время с загрузки
системы: `ProcessInfo.systemUptime`, `mach_absolute_time()`.

- `35F9.1` — измерить время между событиями в приложении или сделать
  таймер. Отправлять с устройства можно только сами интервалы.
- `8FFB.1` — вычислить абсолютное время событий в приложении (например,
  событий UIKit).
- `3D61.1` — включить в необязательный баг-репорт, который человек
  отправляет сам.

**`NSPrivacyAccessedAPICategoryDiskSpace`** — свободное и общее место:
`volumeAvailableCapacityKey` и родственные ключи, `statfs`, `statvfs`.

- `85F4.1` — показать место на диске пользователю.
- `E174.1` — проверить, хватит ли места записать файл, или почистить
  кэш при нехватке. Поведение приложения должно заметно меняться.
- `7D9E.1` — в необязательный баг-репорт.
- `B728.1` — только для приложений медицинских исследований.

**`NSPrivacyAccessedAPICategoryActiveKeyboards`** — список активных
клавиатур (`UITextInputMode.activeInputModes`).

- `3EC4.1` — ты сам делаешь приложение-клавиатуру.
- `54BD.1` — подстроить интерфейс под активную клавиатуру.

Как понять, что код трогает эти API. Вот знакомые строки из разных глав
книги, и каждая попадает в свою категорию:

```swift
import UIKit

func requiredReasonExamples(noteURL: URL) {
    // 1. UserDefaults — категория UserDefaults, причина CA92.1
    UserDefaults.standard.set(true, forKey: "onboarding.done")

    // 2. Дата изменения файла — категория FileTimestamp
    let attributes = try? FileManager.default.attributesOfItem(atPath: noteURL.path)
    let modified = attributes?[.modificationDate] as? Date
    print("Заметка изменена: \(String(describing: modified))")

    // 3. Время с момента загрузки системы — категория SystemBootTime
    let uptime = ProcessInfo.processInfo.systemUptime
    print("Прошло с загрузки: \(uptime) с")

    // 4. Свободное место — категория DiskSpace
    let home = URL(fileURLWithPath: NSHomeDirectory())
    let values = try? home.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
    print("Свободно: \(values?.volumeAvailableCapacityForImportantUsage ?? 0) байт")
}
```

Разбор по строкам:

- `UserDefaults.standard.set` — любой вызов `UserDefaults`, даже просто
  флаг «онбординг показан», уже требует записи в манифесте.
- `attributesOfItem(atPath:)` сам по себе возвращает много атрибутов, но
  как только мы достаём `.modificationDate` — это FileTimestamp. Если
  заметки лежат в папке приложения и дата нужна для сортировки — `C617.1`;
  если дату показываем в списке — подходит и `DDA9.1`. Можно указать обе.
- `systemUptime` — например, чтобы мерить, сколько секунд пользователь
  был на экране. Это `35F9.1`.
- `volumeAvailableCapacityForImportantUsageKey` — перед скачиванием
  большого файла проверяем место. Это `E174.1`.

Если причина твоего использования в списке не найдена — значит, так
использовать API нельзя. Apple предлагает отправить запрос на новую
причину через форму, ссылка на неё есть в той же статье.

> **Где проверить весь проект.** После Product → Archive открой
> Organizer, выбери архив и в контекстном меню — **Generate Privacy
> Report**. Xcode соберёт манифесты приложения и всех SDK в один
> PDF-отчёт. По нему удобно сверять анкету App Privacy.

**Упражнение.** Какие записи нужны в манифесте для такого кода:
приложение сохраняет тему оформления в `UserDefaults(suiteName:
"group.kz.example.playground")`, которую читает и виджет? Ответ — в конце
главы.

## 39.4 Собираемые данные в манифесте

Если приложение всё-таки собирает данные (например, email для входа
в главе 8), в манифесте появляется словарь на каждый тип:

```xml
<key>NSPrivacyCollectedDataTypes</key>
<array>
    <dict>
        <key>NSPrivacyCollectedDataType</key>
        <string>NSPrivacyCollectedDataTypeEmailAddress</string>
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

- `NSPrivacyCollectedDataType` — тип данных. Имена повторяют анкету:
  `...Name`, `...EmailAddress`, `...PhoneNumber`, `...PreciseLocation`,
  `...CrashData` и т.д.
- `NSPrivacyCollectedDataTypeLinked` — связаны ли с личностью. Email для
  входа — связан.
- `NSPrivacyCollectedDataTypeTracking` — используются ли для трекинга.
- `NSPrivacyCollectedDataTypePurposes` — цели: `...PurposeAppFunctionality`,
  `...PurposeAnalytics`, `...PurposeProductPersonalization`,
  `...PurposeDeveloperAdvertising`, `...PurposeThirdPartyAdvertising`,
  `...PurposeOther`.

Содержимое этого блока должно совпадать с анкетой App Store Connect.
Анкету Apple сама из манифеста не заполняет, но Privacy Report из 39.3
помогает ничего не забыть.

## 39.5 Манифесты сторонних SDK

Требование к SDK написано на странице
[Third-party SDK requirements](https://developer.apple.com/support/third-party-SDK-requirements/).
Apple опубликовала список часто используемых SDK: Alamofire,
AFNetworking, Firebase (Core, Auth, Crashlytics, Messaging, Firestore и
другие), Facebook SDK, OneSignal, SDWebImage, Kingfisher и ещё несколько
десятков. Если в новом приложении или в обновлении, которое
**добавляет** такой SDK, у него нет своего манифеста, App Store Connect
сборку не примет. Для SDK, подключённых как готовый бинарник
(`.xcframework`), нужна ещё и **подпись** разработчика SDK.

Для SDK не из списка манифест пока не обязателен, но Apple призывает
авторов его добавлять. И главное правило со страницы Apple: за код
стороннего SDK в твоём приложении отвечаешь ты.

Как проверить: в навигаторе проекта раскрой Package Dependencies, найди
пакет и посмотри, есть ли в нём `PrivacyInfo.xcprivacy`. Надёжнее — тот
же Privacy Report из 39.3: SDK без манифеста там просто не будет. Если у
SDK из списка манифеста нет — обнови его до свежей версии, почти все
популярные библиотеки добавили манифесты ещё в 2024 году.

## 39.6 Usage description в Info.plist

Отдельно от манифеста, для каждого разрешения нужна строка-объяснение
в `Info.plist` (подробно — глава 7, раздел 7.7). Эту строку человек
видит в системном диалоге «Разрешить доступ к камере?».

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Чтобы показать погоду в твоём городе.</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>Чтобы вставить фото в заметку.</string>

<key>NSCameraUsageDescription</key>
<string>Чтобы сделать фото для аватарки.</string>

<key>NSMicrophoneUsageDescription</key>
<string>Чтобы записать голосовое сообщение в чат.</string>

<key>NSContactsUsageDescription</key>
<string>Чтобы найти друзей, которые уже пользуются приложением.</string>

<key>NSFaceIDUsageDescription</key>
<string>Face ID защищает вход в раздел «Профиль».</string>
```

Что будет, если ключа нет: для камеры, микрофона, фото, контактов и
геолокации система **завершает приложение** в момент запроса доступа —
в консоли Xcode будет сообщение о нарушении приватности с именем
недостающего ключа. Для Face ID документация ключа
`NSFaceIDUsageDescription` называет его обязательным, если приложение
пользуется Face ID.

Guidelines **5.1.1(ii)** требует, чтобы строки «ясно и полностью»
описывали использование данных. «Нужно для работы приложения» —
плохо: непонятно зачем. «Чтобы вставить фото в заметку» — хорошо:
конкретная функция.

И ещё два пункта рядом: **5.1.1(iii)** — просить доступ только к тому,
что нужно основной функции, и по возможности пользоваться системными
пикерами (`PHPickerViewController` не требует доступа ко всей
фотобиблиотеке). **5.1.1(iv)** — уважать отказ: если человек не дал
геопозицию, предложи ввести город вручную, а не блокируй приложение.

## 39.7 App Tracking Transparency (ATT)

**Трекинг** по определению Apple — это связывание данных о человеке из
твоего приложения с данными **других компаний** (чужих приложений, сайтов)
для таргетированной рекламы или измерения рекламы, а также передача
данных брокерам данных. Показывать свою рекламу по данным своего же
приложения — не трекинг.

Если приложение трекает, нужно разрешение через фреймворк
AppTrackingTransparency (Guidelines **5.1.2(i)**: «You must receive
explicit permission from users via the App Tracking Transparency APIs to
track their activity»). Пока человек не разрешил, рекламный
идентификатор устройства (IDFA) возвращается из одних нулей:
`00000000-0000-0000-0000-000000000000`.

```swift
import AppTrackingTransparency
import AdSupport

func askForTracking() async {
    // Спрашиваем только если ещё не спрашивали
    guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
    let status = await ATTrackingManager.requestTrackingAuthorization()
    switch status {
    case .authorized:
        let idfa = ASIdentifierManager.shared().advertisingIdentifier
        print("IDFA доступен: \(idfa)")
    case .denied, .restricted, .notDetermined:
        print("Трекинга нет — IDFA из одних нулей")
    @unknown default:
        break
    }
}
```

Разбор:

- `trackingAuthorizationStatus` — текущий статус без показа диалога.
  Если человек уже ответил, второй раз система диалог не покажет.
- `await requestTrackingAuthorization()` — async-версия (iOS 14+).
  Версия с замыканием тоже есть, но Swift импортирует её замыкание
  как `@Sendable`: оно не привязано к главному потоку. Если внутри
  написать `label.text = ...`, компилятор Swift 6.3 предупредит «main
  actor-isolated property 'text' can not be mutated from a Sendable
  closure» — и будет прав. Async-версия снимает вопрос: после `await`
  мы снова в контексте вызывающего кода (в нашем проекте — на главном
  акторе), и интерфейс можно трогать сразу.
- `ASIdentifierManager.shared().advertisingIdentifier` — сам IDFA из
  фреймворка AdSupport.
- `.restricted` — трекинг запрещён на уровне устройства (например,
  детский аккаунт).
- `.notDetermined` после запроса — система закрыла диалог без ответа;
  документация советует спросить снова позже.

Нюансы из документации метода:

- Диалог показывается, **только если приложение активно** (состояние
  `UIApplication.State.active`). Вызов из `application(_:didFinishLaunchingWithOptions:)`
  часто приходится на момент, когда приложение ещё не активно, —
  тогда диалога не будет, а статус останется прежним. Вызывай после
  того, как первый экран появился.
- Если в Настройках → Конфиденциальность и безопасность → Отслеживание
  выключено «Трекинг-запросы от приложений», диалога не будет вовсе.
- В ЕС после ответа повторно спросить можно через год.

Ключ в `Info.plist` обязателен, без него диалог не покажется:

```xml
<key>NSUserTrackingUsageDescription</key>
<string>Чтобы показывать рекламу, которая тебе интересна. Можно отказаться — приложение будет работать так же.</string>
```

Если трекинга нет — не вызывай ATT вообще. Диалог без причины только
пугает людей, а по 5.1.2(i) приложение не может требовать разрешения на
трекинг ради доступа к функциям или наградам.

## 39.8 Где хранить данные на устройстве

Это не требование Apple, а практика, которая напрямую влияет на то, что
ты пишешь в анкете и манифесте.

**Keychain** (связка ключей — защищённое системное хранилище, глава 8) —
для токенов, паролей и другой чувствительной мелочи. Содержимое
шифруется ключами устройства. На практике записи Keychain **остаются
после удаления приложения** и видны ему после переустановки — Apple не
обещает это как гарантию, поэтому на это нельзя опираться, но и забыть
про это нельзя: при удалении аккаунта токены нужно стирать явно
(глава 40).

**UserDefaults** — для настроек, флагов и мелких данных интерфейса.
Хранится в обычном plist-файле внутри песочницы (sandbox — отдельной
папки приложения, куда другие приложения не имеют доступа). Файл не
зашифрован отдельно, поэтому секреты туда класть нельзя. И, как мы
видели в 39.3, `UserDefaults` — required reason API.

**`Documents/`** — пользовательский контент: заметки, фото, документы.
Эта папка попадает в резервную копию iCloud и Finder, поэтому после
восстановления из копии на новом iPhone заметки вернутся.

**`Library/Caches/`** — кэш, который можно потерять без последствий.
В резервную копию не попадает, и iOS может очистить эту папку, когда
на устройстве мало места.

**`tmp/`** — временные файлы на время одной операции. iOS может
удалить их в любой момент, когда приложение не запущено.

## 39.9 Законы: GDPR, CCPA, казахстанский закон о персональных данных

Guidelines — это правила App Store. Поверх них действуют законы страны,
где живут твои пользователи. Несколько примеров:

- **GDPR** — регламент ЕС о защите данных. Требует законного основания
  для обработки (часто — согласие), права на доступ к своим данным,
  на исправление и удаление.
- **CCPA/CPRA** — закон Калифорнии: право узнать, какие данные собраны,
  и запретить их продажу.
- **Закон Республики Казахстан «О персональных данных и их защите»**
  (№ 94-V от 21 мая 2013 года) — согласие на сбор и обработку,
  требование хранить базы с персональными данными граждан на территории
  Казахстана. Детали — у юриста, закон регулярно дополняют.

Что из этого точно нужно в приложении, независимо от страны, — потому
что этого требует Apple:

- **Privacy Policy** — ссылка на политику конфиденциальности в App Store
  Connect **и** внутри приложения на видном месте (5.1.1(i)). Политика
  должна описывать, какие данные собираются и зачем, кому передаются,
  сколько хранятся и как отозвать согласие или удалить данные.
- **Отзыв согласия** — понятный способ передумать (5.1.1(ii)).
- **Удаление аккаунта** внутри приложения, если в нём можно создать
  аккаунт (5.1.1(v), глава 40).

Для страницы в App Store есть ещё необязательное поле **Privacy Choices
URL** — ссылка на страницу, где человек управляет своими данными.

Playground из книги ничего не собирает, поэтому баннер согласия ему не
нужен. В реальном приложении с аналитикой и рекламой — обсуди с юристом.

## 39.10 Что запрещено

- **Fingerprinting** — вычислять устройство по набору признаков.
  Запрещено всегда, даже при разрешённом трекинге (статья о required
  reason API).
- **Скрытое построение профиля** из данных, которые ты называешь
  «анонимными», и попытки деанонимизировать людей (5.1.2(iii)).
- **Сбор списка установленных приложений** для аналитики и рекламы
  (5.1.2(iv)).
- **Передача данных третьим сторонам без явного согласия** — в том
  числе в сторонние AI-сервисы (5.1.2(i) это прямо упоминает).
- **Требовать включить пуши, геолокацию или трекинг** в обмен на доступ
  к функциям или награды (5.1.2(i)).

## 39.11 App Transport Security

App Transport Security (ATS) — механизм iOS, который по умолчанию
разрешает сетевые запросы только по HTTPS с современным TLS. Отключить
его для всех доменов можно так:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

В production так не делай. Исключение для одного домена выглядит так:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSExceptionDomains</key>
    <dict>
        <key>legacy.example.com</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
        </dict>
    </dict>
</dict>
```

По документации
[Preventing insecure network connections](https://developer.apple.com/documentation/security/preventing-insecure-network-connections)
**оба** варианта требуют обоснования при отправке в App Store и могут
вызвать дополнительную проверку: и `NSAllowsArbitraryLoads`, и
`NSExceptionAllowsInsecureHTTPLoads` для отдельного домена (а также
`NSAllowsArbitraryLoadsForMedia`, `NSAllowsArbitraryLoadsInWebContent`,
`NSExceptionMinimumTLSVersion`). Примеры допустимых причин от Apple:
сервер чужой компании без HTTPS, устройства в сети, которые нельзя
обновить. Правильное решение почти всегда — включить HTTPS на сервере.

## 39.12 Ответы к упражнениям

**39.1 (анкета для Todo).** Задачи хранятся только в `UserDefaults` на
устройстве и никуда не отправляются — это не сбор. Демо-задачи мы
**получаем** с `dummyjson.com`, но ничего о человеке туда не **передаём**
(кроме технического запроса). Аналитики нет. Итог: в анкете ответ
«Data Not Collected». На странице App Store появится «Разработчик не
собирает данные».

Проверка себя: если позже ты добавишь Firebase Crashlytics, ответ
изменится — Diagnostics → Crash Data, цель App Functionality; связаны ли
с пользователем — зависит от того, передаёшь ли ты в Crashlytics User ID.

**39.3 (App Group).** Категория `NSPrivacyAccessedAPICategoryUserDefaults`
с причиной `1C8F.1` — данные общие для приложения и расширений одной
App Group. Если приложение пользуется и обычным `UserDefaults.standard`,
в том же словаре указывают обе причины: `CA92.1` и `1C8F.1`. Манифест
нужен и приложению, и расширению виджета — у каждого исполняемого
модуля свой бандл.

```xml
<dict>
    <key>NSPrivacyAccessedAPIType</key>
    <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
    <key>NSPrivacyAccessedAPITypeReasons</key>
    <array>
        <string>CA92.1</string>
        <string>1C8F.1</string>
    </array>
</dict>
```

## Что мы выучили

- **Анкета App Privacy** в App Store Connect обязательна для отправки на
  проверку. «Собирать» = передавать с устройства и хранить дольше, чем
  нужно для ответа. Три вопроса на тип данных: цель, связь с личностью,
  трекинг.
- **`PrivacyInfo.xcprivacy`** — манифест в бандле: `NSPrivacyTracking`,
  `NSPrivacyTrackingDomains`, `NSPrivacyCollectedDataTypes`,
  `NSPrivacyAccessedAPITypes`. С 1 мая 2024 без причин для required
  reason API сборку не принимают.
- **Required reason API**: UserDefaults (`CA92.1`, `1C8F.1`), FileTimestamp
  (`DDA9.1`, `C617.1`, `3B52.1`), SystemBootTime (`35F9.1`, `8FFB.1`,
  `3D61.1`), DiskSpace (`85F4.1`, `E174.1`, `7D9E.1`), ActiveKeyboards
  (`3EC4.1`, `54BD.1`).
- **SDK из списка Apple** обязаны иметь манифест (и подпись, если это
  бинарник). Privacy Report в Organizer собирает всё в один отчёт.
- **Usage description** в `Info.plist` — конкретно «зачем» (5.1.1(ii));
  без ключа доступ к камере, фото, микрофону завершает приложение.
- **ATT** — только если действительно трекаешь; async-версия запроса;
  диалог появляется только в активном приложении.
- **Privacy Policy** — ссылка в App Store Connect и в приложении (5.1.1(i)).
- **ATS-исключения**, включая исключение для одного домена, требуют
  обоснования при проверке.

## Apple Developer Documentation

- [App privacy details on the App Store](https://developer.apple.com/app-store/app-privacy-details/) — определения «collect», «linked», «tracking», полный список типов данных и целей.
- [Privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files) — структура `PrivacyInfo.xcprivacy` и как его создать.
- [Describing use of required reason API](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api) — правила для required reason API и дата 1 мая 2024.
- [NSPrivacyAccessedAPIType](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype) — список категорий, API и кодов причин.
- [Third-party SDK requirements](https://developer.apple.com/support/third-party-SDK-requirements/) — список SDK, которым обязательны манифест и подпись.
- [App Review Guidelines — 5.1 Privacy](https://developer.apple.com/app-store/review/guidelines/#privacy) — политика конфиденциальности, согласие, минимизация данных, трекинг.
- [App Tracking Transparency](https://developer.apple.com/documentation/apptrackingtransparency) — фреймворк ATT.
- [`requestTrackingAuthorization(completionHandler:)`](https://developer.apple.com/documentation/apptrackingtransparency/attrackingmanager/requesttrackingauthorization(completionhandler:)) — когда показывается диалог и когда нет.
- [Preventing insecure network connections](https://developer.apple.com/documentation/security/preventing-insecure-network-connections) — ATS и исключения, требующие обоснования.
- [Information property list](https://developer.apple.com/documentation/bundleresources/information-property-list) — все ключи `Info.plist`, включая `NS…UsageDescription`.

→ [Глава 40. Production: account deletion flow](./62-production-account-deletion.md)
