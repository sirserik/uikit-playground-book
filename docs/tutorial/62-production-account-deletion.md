# Глава 40. Production: account deletion flow

С 30 июня 2022 года Apple требует: если в приложении можно **создать**
аккаунт, в нём же должно быть можно этот аккаунт **удалить**. Не выйти,
не «деактивировать», а инициировать полное удаление аккаунта вместе с
данными.

Это правило самой Apple, а не пересказ закона. Оно записано в App Review
Guidelines (дальше «Guidelines»), пункт **5.1.1(v) Account Sign-In**:

> If your app supports account creation, you must also offer account
> deletion within the app.

Подробности Apple разобрала на отдельной странице
[Offering account deletion in your app](https://developer.apple.com/support/offering-account-deletion-in-your-app/)
— дальше я ссылаюсь на неё как на «страницу Apple про удаление». Законы
вроде европейского GDPR (статья 17, «право на удаление») требуют похожего,
но Apple прямо пишет: если удаление есть только для жителей ЕС или
Калифорнии, этого **недостаточно**, удалять аккаунт должны мочь все
пользователи, где бы они ни жили.

Требование касается и «гостевых» аккаунтов, которые приложение создаёт
само, без регистрации: их тоже должно быть можно удалить. И даже если
регистрация идёт через сайт в браузере, кнопка удаления всё равно нужна
в приложении.

## 40.1 Что нужно реализовать

По странице Apple про удаление:

1. **Кнопку легко найти.** Обычно — в настройках аккаунта. В нашем
   Profile из главы 19 — внизу экрана, под «Выйти».
2. **Удалить можно весь аккаунт** вместе с персональными данными. Можно
   дополнительно предложить «временно отключить», но **только**
   отключения недостаточно.
3. **Без звонков, писем и тикетов в поддержку.** Исключение — приложения
   из строго регулируемых отраслей (банки, медицина и т.п., пункт
   5.1.1(ix)): им можно добавить шаги через поддержку.
4. **Можно подтверждать.** Разрешено спросить «вы уверены?», попросить
   ввести пароль или код из письма, чтобы аккаунт не удалил кто-то
   другой. Но процесс не должен быть «неоправданно сложным» — иначе
   отказ на проверке.
5. **Держи человека в курсе.** Если удаление занимает время (например,
   ручная обработка), скажи, сколько, и сообщи, когда закончено.
6. **Если нужен сайт** для завершения удаления — дай прямую ссылку на
   нужную страницу, а не на главную.

## 40.2 Кнопка в Profile

В главе 19 мы описывали экран настроек массивом секций. Добавляем
секцию с двумя кнопками:

```swift
Section(title: nil, footer: nil, rows: [
    .button(title: "Выйти из аккаунта", isDestructive: false) { [weak self] in
        self?.logout()
    },
    .button(title: "Удалить аккаунт", isDestructive: true) { [weak self] in
        self?.confirmDelete()
    },
]),
```

`Row.button` и `Section` — из раздела 19.1: строка-кнопка с заголовком,
флагом «разрушительное действие» (красный текст) и замыканием.
`[weak self]` нужен, потому что массив секций хранит контроллер
(`self.sections`), а замыкания лежат внутри этого массива. Без `weak`
контроллер держал бы замыкание, а замыкание — контроллер: цикл
сильных ссылок, и экран никогда не освободился бы из памяти.

«Выйти» — обычная синяя кнопка: после выхода аккаунт остаётся, войти
можно снова. «Удалить» — красная: действие необратимое.

## 40.3 Подтверждение и удаление

Весь поток в коде. Сначала — вспомогательные типы. Сетевой клиент для
удаления:

```swift
import UIKit
import StoreKit

enum APIError: Error {
    case unauthorized
    case server(Int)
}

nonisolated struct DeletionReceipt: Decodable {
    /// Когда данные будут стёрты окончательно; nil — уже стёрты.
    let purgeDate: Date?
}

enum AccountAPI {
    /// DELETE /account — сервер удаляет аккаунт или ставит его в очередь на удаление.
    static func deleteAccount(token: String) async throws -> DeletionReceipt {
        guard let url = URL(string: "https://api.example.com/account") else {
            throw APIError.server(0)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.server(0) }

        switch http.statusCode {
        case 200, 202:
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(DeletionReceipt.self, from: data)
        case 401:
            throw APIError.unauthorized
        default:
            throw APIError.server(http.statusCode)
        }
    }
}
```

Разбор:

- `DELETE /account` с токеном в заголовке `Authorization` — сервер
  понимает, чей аккаунт удалять, из токена. Никаких `userId` в теле
  запроса: иначе злоумышленник мог бы подставить чужой.
- Ответ `200 OK` — удалено сразу. `202 Accepted` («принято к
  исполнению») — сервер поставил удаление в очередь; в теле он
  возвращает дату, когда данные будут стёрты окончательно.
- `nonisolated struct DeletionReceipt` — в нашем проекте весь код по
  умолчанию на главном акторе (введение, раздел 0.2).
  Модель, которую декодируют из JSON, помечаем `nonisolated`, чтобы
  её можно было спокойно передавать между потоками.
- `dateDecodingStrategy = .iso8601` — сервер присылает дату строкой вида
  `"2026-10-27T00:00:00Z"`.
- `guard let url` вместо `URL(string:)!` — восклицательный знак
  (force unwrap) уронил бы приложение, если бы в адресе случайно
  оказался недопустимый символ.

Локальная очистка — отдельной функцией:

```swift
enum LocalData {
    static func wipe() {
        // 1. Токен из Keychain (глава 8)
        AuthStorage.shared.clear()

        // 2. Все настройки приложения в UserDefaults
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }

        // 3. Файлы пользователя: Documents и Caches
        let fm = FileManager.default
        let folders = [
            fm.urls(for: .documentDirectory, in: .userDomainMask).first,
            fm.urls(for: .cachesDirectory, in: .userDomainMask).first,
        ].compactMap { $0 }

        for folder in folders {
            let items = (try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
            for item in items {
                try? fm.removeItem(at: item)
            }
        }
    }
}
```

- `AuthStorage.shared.clear()` — наш Keychain-класс из главы 8. Токен
  нужно стереть явно: записи Keychain на практике переживают даже
  удаление приложения.
- `removePersistentDomain(forName:)` — удаляет **все** ключи
  `UserDefaults.standard` этого приложения разом. Домен (*domain*) здесь —
  «раздел» настроек; у приложения он называется по bundle ID.
- Папки мы не удаляем, а **очищаем**: `Documents` и `Caches` — системные
  папки песочницы, их содержимое можно удалять, а саму папку лучше
  оставить.

Теперь сам контроллер:

```swift
final class ProfileViewController: UIViewController {

    /// Координатор (глава 4) подставляет сюда переход на экран входа.
    var onAccountDeleted: (() -> Void)?

    func confirmDelete() {
        let alert = UIAlertController(
            title: "Удалить аккаунт?",
            message: "Мы удалим профиль, заметки и фото с сервера и с этого устройства. Отменить это нельзя.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(UIAlertAction(title: "Удалить", style: .destructive) { [weak self] _ in
            self?.performDelete()
        })
        present(alert, animated: true)
    }

    private func performDelete() {
        guard let token = AuthStorage.shared.token else {
            // Не вошёл — удалять на сервере нечего, чистим устройство
            LocalData.wipe()
            onAccountDeleted?()
            return
        }

        let spinner = UIActivityIndicatorView(style: .large)
        spinner.center = view.center
        view.addSubview(spinner)
        spinner.startAnimating()
        view.isUserInteractionEnabled = false

        Task { [weak self] in
            do {
                let receipt = try await AccountAPI.deleteAccount(token: token)
                LocalData.wipe()
                spinner.removeFromSuperview()
                self?.view.isUserInteractionEnabled = true
                self?.showDone(receipt: receipt)
            } catch {
                spinner.removeFromSuperview()
                self?.view.isUserInteractionEnabled = true
                self?.showError()
            }
        }
    }

    private func showDone(receipt: DeletionReceipt) {
        var message = "Аккаунт удалён."
        if let date = receipt.purgeDate {
            let day = date.formatted(date: .long, time: .omitted)
            message = "Аккаунт отключён. Все данные будут окончательно стёрты \(day)."
        }
        let alert = UIAlertController(title: "Готово", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.onAccountDeleted?()
        })
        present(alert, animated: true)
    }

    private func showError() {
        let alert = UIAlertController(
            title: "Не получилось удалить аккаунт",
            message: "Проверь интернет и попробуй ещё раз. Данные на устройстве мы не трогали.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
        present(alert, animated: true)
    }
}
```

Разбор по шагам:

- `confirmDelete()` — одно подтверждение. Текст говорит, **что именно**
  удалится и что это необратимо. Кнопка «Удалить» в стиле
  `.destructive` (красная), «Отмена» — `.cancel`.
- `performDelete()` сначала проверяет токен. Нет токена — человек не
  вошёл, серверного аккаунта нет, чистим только устройство.
- Спиннер и `isUserInteractionEnabled = false` — пока идёт запрос,
  экран заблокирован от повторных нажатий. Иначе человек нажмёт
  «Удалить» дважды и отправит два запроса.
- `Task { ... }` — запускаем асинхронную работу. Контроллер в нашем
  режиме на главном акторе, поэтому код внутри `Task` тоже выполняется
  на главном потоке, и трогать `view` после `await` безопасно.
- `[weak self]` в `Task` — если пользователь закроет экран, пока идёт
  запрос, контроллер не будет удерживаться до конца запроса.
- **Порядок важен:** сначала сервер, потом устройство. Если запрос
  упал, мы **не** стираем локальные данные и показываем ошибку. С
  `try? await API.deleteAccount()` и сразу очисткой при отсутствии
  сети человек думал бы, что аккаунт
  удалён, хотя на сервере всё осталось.
- `showDone` различает два исхода: удалено сразу или поставлено в
  очередь с датой. Это требование страницы Apple: сказать, сколько
  займёт удаление.
- `onAccountDeleted` — вместо `dismiss` переход на экран входа отдаём
  координатору. Контроллер не знает, кто его показал и куда вести
  дальше.

**Упражнение.** Добавь в `showError` кнопку «Повторить», которая снова
вызывает `performDelete()`. Подумай, нужен ли в ней `[weak self]`.
Решение — в конце главы.

## 40.4 Серверная часть: что значит «удалить»

Серверный код — за рамками книги, но от него зависит, пройдёт ли
приложение проверку. По странице Apple про удаление:

- **Удалить нужно аккаунт и все связанные данные**, которые ты не
  обязан хранить по закону.
- **Контент, который видели другие, тоже удаляется**: фото, видео,
  посты, отзывы. «Люди ожидают, что все данные, связанные с аккаунтом,
  будут удалены». Если закон обязывает что-то хранить — предупреди об
  этом пользователя.
- **Удаление не обязано быть мгновенным.** Если процесс ручной или
  занимает время — это допустимо, если ты сообщил срок и уведомил о
  завершении. Срок должен соответствовать местным законам.

Что обычно **остаётся** на законных основаниях:

- **Финансовые документы** — чеки и транзакции: бухгалтерию хранят по
  закону несколько лет.
- **Журналы безопасности** — в объёме, который требует закон.
- **Обезличенная статистика** — если она действительно не связана с
  человеком (например, «в сентябре было 1200 заказов»).

Что удаляется точно: запись пользователя, имя, email, телефон, контент,
настройки, все активные сессии и токены, токены пушей (глава 41),
подписки на рассылки, сохранённые токены карт у платёжного провайдера.

## 40.5 Мягкое и жёсткое удаление

**Жёсткое удаление** (*hard delete*) — строки из базы стираются сразу.

**Мягкое удаление** (*soft delete*) — в строке пользователя ставится
отметка времени `deleted_at`, аккаунт перестаёт работать, а через N дней
фоновая задача стирает его окончательно:

```sql
-- В момент запроса: аккаунт отключён, вход невозможен
UPDATE users SET deleted_at = NOW() WHERE id = 42;

-- Раз в сутки: окончательно стираем тех, кто удалён больше 30 дней назад
DELETE FROM users WHERE deleted_at < NOW() - INTERVAL '30 days';
```

На числах: человек удалил аккаунт 1 октября в 10:00. Проверка «прошло
больше 30 дней» станет истинной после 31 октября, 10:00, и ближайший
ночной запуск задачи сотрёт запись.

Apple **не требует** и **не рекомендует** ни один из вариантов. Мягкое
удаление с отсрочкой допустимо, если:

- аккаунт сразу перестаёт работать;
- ты **сказал** человеку, когда данные будут стёрты окончательно
  (наш `purgeDate` в `showDone`);
- по истечении срока данные действительно удаляются.

Не путай это с «деактивацией»: если после «удаления» данные хранятся
вечно, это и есть деактивация, а её одной, по странице Apple,
недостаточно.

## 40.6 Восстановление в течение отсрочки

Если у тебя мягкое удаление, можно дать передумать. Сервер при попытке
входа удалённого, но ещё не стёртого аккаунта отвечает особым кодом,
например `409 Conflict` с датой окончательного удаления, а приложение
показывает:

```
┌─────────────────────────────┐
│   Этот аккаунт удалён       │
│                             │
│   Данные будут стёрты       │
│   27 октября 2026 года.     │
│   До этого его можно        │
│   восстановить.             │
│                             │
│   [ Восстановить ]          │
│   [ Создать новый ]         │
└─────────────────────────────┘
```

После даты окончательного удаления сервер восстановить уже не может —
данных нет.

## 40.7 Sign in with Apple — отзыв токенов

Если в приложении есть вход через Apple (Sign in with Apple), страница
Apple про удаление требует при удалении аккаунта **отозвать токены**
через Sign in with Apple REST API. После отзыва приложение пропадает из
списка «Приложения, использующие Apple ID» в настройках человека, и
при новом входе он увидит экран согласия заново, как новый
пользователь.

Отзыв делает **сервер**, а не приложение: запрос
`POST https://appleid.apple.com/auth/revoke` с параметрами
`client_id` (твой идентификатор приложения), `client_secret` (JWT,
подписанный ключом Sign in with Apple — секрет живёт только на
сервере), `token` (refresh-токен или access-токен пользователя) и
`token_type_hint`.

Где сервер возьмёт токен пользователя? При входе приложение получает от
Apple **authorization code** (`ASAuthorizationAppleIDCredential.authorizationCode`)
и отправляет его на сервер, а сервер обменивает код на refresh-токен и
хранит его. Если сервер этого не делал, приложению придётся перед
удалением попросить человека ещё раз войти через Apple — чтобы получить
свежий authorization code и отдать его серверу для обмена и отзыва.

В приложении можно дополнительно проверить, не отозвал ли человек доступ
сам (через настройки Apple ID):

```swift
import AuthenticationServices

func checkAppleCredential(userID: String) async -> Bool {
    let provider = ASAuthorizationAppleIDProvider()
    do {
        let state = try await provider.credentialState(forUserID: userID)
        return state == .authorized
    } catch {
        return false
    }
}
```

`credentialState(forUserID:)` возвращает `.authorized`, `.revoked` или
`.notFound`. Если `.revoked` — человек сам отключил приложение от
Apple ID; сессию в приложении стоит завершить. Этот метод **не
отзывает** токены — он только читает состояние.

## 40.8 Подписки

Если у человека активная автовозобновляемая подписка через App Store,
удаление аккаунта её **не отменяет**: платит он Apple, а не тебе.
Страница Apple про удаление говорит так: предупреди, что списания
продолжатся через Apple, и попроси отменить подписку **до** удаления.
Можно предложить запланировать удаление на дату окончания подписки,
но только если **есть и вариант удалить сразу**.

Как открыть системный экран управления подписками (iOS 15+):

```swift
extension ProfileViewController {

    func hasActiveSubscription() async -> Bool {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productType == .autoRenewable,
               transaction.revocationDate == nil {
                return true
            }
        }
        return false
    }

    func openSubscriptions() {
        guard let scene = view.window?.windowScene else { return }
        Task {
            do {
                try await AppStore.showManageSubscriptions(in: scene)
            } catch {
                if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                    await UIApplication.shared.open(url)
                }
            }
        }
    }

    func warnAboutSubscription() {
        let alert = UIAlertController(
            title: "Подписка активна",
            message: "Удаление аккаунта не отменяет подписку: списания через Apple продолжатся. Сначала отмени её, потом удаляй аккаунт.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Управлять подписками", style: .default) { [weak self] _ in
            self?.openSubscriptions()
        })
        alert.addAction(UIAlertAction(title: "Удалить всё равно", style: .destructive) { [weak self] _ in
            self?.confirmDelete()
        })
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        present(alert, animated: true)
    }
}
```

Разбор:

- `Transaction.currentEntitlements` (StoreKit 2, iOS 15+) — асинхронная
  последовательность текущих прав пользователя: активные подписки и
  купленные товары. Перебираем через `for await`.
- `.verified(let transaction)` — StoreKit проверил подпись транзакции.
  Непроверенные (`.unverified`) пропускаем.
- `productType == .autoRenewable` и `revocationDate == nil` — это
  автовозобновляемая подписка, и Apple её не отзывала (например, после
  возврата денег).
- `AppStore.showManageSubscriptions(in:)` — системный лист управления
  подписками прямо поверх приложения. Ему нужна сцена окна
  (`UIWindowScene`), берём её у `view.window`.
- Если лист показать не удалось, открываем ссылку
  `https://apps.apple.com/account/subscriptions` — её Apple приводит на
  странице про удаление. Схема `itms-apps://`
  тоже откроет App Store, но официальная ссылка — https.
- `warnAboutSubscription()` показывается **вместо** `confirmDelete()`,
  если `hasActiveSubscription()` вернул `true`. Вариант «Удалить всё
  равно» обязателен — нельзя заставлять человека сначала отменять
  подписку.

Для возврата денег за покупки у StoreKit есть
`Transaction.beginRefundRequest(for:in:)` (iOS 15+) — системный лист
запроса возврата. Предлагать его при удалении не обязательно, Apple
упоминает его как возможность.

## 40.9 Что Apple не пропустит

По Guidelines 5.1.1(v) и странице Apple про удаление:

- **«Напишите в поддержку»**, «позвоните», «отправьте email» — нельзя
  (кроме строго регулируемых отраслей).
- **Только деактивация** без удаления данных — недостаточно.
- **«Удалите приложение»** — это не удаление аккаунта, данные остаются
  на сервере.
- **Удаление только для отдельных стран** — недостаточно.
- **Неоправданно сложный путь**: пять экранов, капча, опрос «почему
  уходите» без кнопки «пропустить».

Что можно:

- Подтверждение, повторный ввод пароля, код из письма.
- Ссылка на страницу сайта, если удаление завершается там, — **прямая**
  ссылка на эту страницу, а начинается процесс всё равно в приложении.
- Отсрочка с понятной датой окончательного удаления.

Про оформление есть раздел HIG (Human Interface Guidelines — руководство
Apple по дизайну интерфейсов)
[Managing accounts](https://developer.apple.com/design/human-interface-guidelines/managing-accounts).
Из него стоит взять три мысли: ссылку на удаление не прятать в политику
конфиденциальности или условия использования; удаление в приложении и
на сайте должно быть одинаково простым; если закон обязывает что-то
хранить (например, медицинские записи), прямо объясни это человеку.

## 40.10 Тестирование

Чек-лист перед отправкой:

- [ ] Кнопка «Удалить аккаунт» видна в настройках аккаунта без поиска.
- [ ] Подтверждение показывается, «Отмена» ничего не удаляет.
- [ ] Запрос к серверу отправляется с токеном; на сервере аккаунт
      перестаёт работать сразу.
- [ ] Нет сети → ошибка, локальные данные на месте.
- [ ] После успеха: токен в Keychain удалён, `UserDefaults` пуст,
      `Documents` и `Caches` пусты, приложение на экране входа.
- [ ] Повторный вход удалённым аккаунтом → понятное сообщение (или
      экран восстановления из 40.6).
- [ ] Для входа через Apple: после удаления приложение пропало из
      списка в настройках Apple ID.
- [ ] С активной подпиской: показывается предупреждение и открывается
      экран управления подписками.
- [ ] В заметках для проверяющего (App Review Notes) — тестовый аккаунт,
      который не жалко удалить, и где искать кнопку. Проверяющий
      действительно нажмёт «Удалить».

## 40.11 Политика конфиденциальности

Guidelines **5.1.1(i)** требует, чтобы политика конфиденциальности
объясняла, как долго хранятся данные, как их удалить и как отозвать
согласие. Для удаления аккаунта напиши там:

- где в приложении кнопка удаления;
- сколько времени занимает удаление и что происходит с данными в это
  время;
- что остаётся после удаления и почему (например, чеки — по налоговому
  закону).

## 40.12 Ответы к упражнениям

**40.3.** Кнопка «Повторить»:

```swift
private func showError() {
    let alert = UIAlertController(
        title: "Не получилось удалить аккаунт",
        message: "Проверь интернет и попробуй ещё раз. Данные на устройстве мы не трогали.",
        preferredStyle: .alert
    )
    alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
    alert.addAction(UIAlertAction(title: "Повторить", style: .default) { [weak self] _ in
        self?.performDelete()
    })
    present(alert, animated: true)
}
```

`[weak self]` здесь нужен не из-за цикла: алерт не хранится в
контроллере, так что цикла ссылок нет. Но замыкание кнопки живёт, пока
живёт алерт, а с `weak` нажатие «Повторить» после закрытия экрана
просто ничего не сделает, вместо того чтобы отправлять запрос от
имени уже ненужного контроллера. Это дешёвая привычка, и в книге мы её
держим во всех замыканиях `UIAlertAction`.

## Что мы выучили

- **5.1.1(v)**: если можно создать аккаунт, в приложении должно быть
  можно его удалить. Требование с 30 июня 2022 года, для всех стран,
  включая гостевые аккаунты.
- Только деактивации мало; звонки, письма и поддержка — нельзя
  (кроме регулируемых отраслей); подтверждение и повторный вход — можно.
- **Сначала сервер, потом устройство.** Упал запрос — ничего не стираем
  и показываем ошибку.
- Локально: Keychain, `removePersistentDomain(forName:)`, содержимое
  `Documents` и `Caches`.
- Удаляется и контент, который видели другие. Храним только то, что
  требует закон, и сообщаем об этом.
- Отсрочка допустима, если человек знает дату окончательного удаления.
- **Sign in with Apple**: сервер отзывает токены через
  `POST https://appleid.apple.com/auth/revoke`. `credentialState` только
  читает состояние.
- **Подписки** не отменяются удалением аккаунта: предупреди и открой
  `AppStore.showManageSubscriptions(in:)`, но оставь вариант удалить сразу.

## Apple Developer Documentation

- [Offering account deletion in your app](https://developer.apple.com/support/offering-account-deletion-in-your-app/) — требования и FAQ Apple по удалению аккаунта.
- [App Review Guidelines — 5.1.1 Data Collection and Storage](https://developer.apple.com/app-store/review/guidelines/#data-collection-and-storage) — пункт (v) об удалении аккаунта и (i) о политике конфиденциальности.
- [HIG — Managing accounts](https://developer.apple.com/design/human-interface-guidelines/managing-accounts) — рекомендации по интерфейсу входа и удаления аккаунта.
- [Revoke tokens](https://developer.apple.com/documentation/signinwithapplerestapi/revoke-tokens) — серверный запрос отзыва токенов Sign in with Apple.
- [`ASAuthorizationAppleIDProvider`](https://developer.apple.com/documentation/authenticationservices/asauthorizationappleidprovider) — проверка состояния учётных данных Apple ID.
- [`showManageSubscriptions(in:)`](https://developer.apple.com/documentation/storekit/appstore/showmanagesubscriptions(in:)) — системный экран управления подписками.
- [`Transaction.currentEntitlements`](https://developer.apple.com/documentation/storekit/transaction/currententitlements) — текущие подписки и покупки пользователя.
- [`beginRefundRequest(for:in:)`](https://developer.apple.com/documentation/storekit/transaction/beginrefundrequest(for:in:)-65tph) — системный лист запроса возврата.
- [`removePersistentDomain(forName:)`](https://developer.apple.com/documentation/foundation/userdefaults/removepersistentdomain(forname:)) — очистка всех настроек приложения.
- [Keychain services](https://developer.apple.com/documentation/security/keychain-services) — удаление токенов и паролей из связки ключей.

→ [Глава 41. Production: push notifications + deep links](./63-production-push-deeplinks.md)
