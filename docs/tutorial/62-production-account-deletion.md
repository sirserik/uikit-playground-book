# Глава 40. Production: account deletion flow

С июня 2022 Apple **требует** в каждом приложении с авторизацией —
возможность **удалить** свой аккаунт. Не отписаться, не «выйти», а
**полностью удалить** данные.

Закон обязывает (GDPR Art. 17 «Right to erasure»). Apple добавило
это в App Store Review Guidelines (раздел 5.1.1(v)).

## 40.1 Что нужно реализовать

1. В Settings (или в Profile) — кнопка **«Удалить аккаунт»**.
2. Доступна без хождения в support (нельзя «напишите нам в email»).
3. Подтверждение **внутри приложения** (alert или экран).
4. После подтверждения — данные удаляются с сервера + локально.

## 40.2 UI

В нашем Profile (Глава 19):

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

Две кнопки внизу Settings — выйти (mild) и удалить (destructive).

Confirmation:

```swift
private func confirmDelete() {
    let alert = UIAlertController(
        title: "Удалить аккаунт?",
        message: "Это действие необратимо. Все данные удалятся.",
        preferredStyle: .alert
    )
    alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
    alert.addAction(UIAlertAction(title: "Удалить", style: .destructive) { [weak self] _ in
        self?.performDelete()
    })
    present(alert, animated: true)
}

private func performDelete() {
    Task { [weak self] in
        // 1. Запрос на сервер: удалить аккаунт
        try? await API.deleteAccount()
        // 2. Очистить локальные данные
        AuthStorage.shared.clear()
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
        // 3. Очистить FileManager
        try? FileManager.default.removeItem(at: documentsURL.appendingPathComponent("Notes"))
        // 4. Перейти на login или закрыть app
        self?.dismiss(animated: true)
    }
}
```

## 40.3 Серверный flow

API endpoint обычно:

```
POST /account/delete
Authorization: Bearer <token>

Response: 200 OK
```

Сервер должен:

1. Помечать аккаунт как deleted (soft delete) или удалять записи
   (hard).
2. Анонимизировать связанные данные (комментарии, лайки) если они
   видны другим.
3. Через 30 дней — full deletion (для recovery если юзер передумал).

## 40.4 Soft vs hard delete

**Soft delete** — record остаётся в БД с `deleted_at` timestamp. Юзер
может восстановить аккаунт в течение N дней. После — реальное удаление.

```sql
UPDATE users SET deleted_at = NOW() WHERE id = 42;
-- Cron-job спустя 30 дней
DELETE FROM users WHERE deleted_at < NOW() - INTERVAL '30 days';
```

**Hard delete** — сразу удаляет. Восстановить нельзя.

Apple не диктует, но **рекомендует** soft delete с grace period.

## 40.5 Что **удалять**

Полный список:

- **Аккаунт пользователя** (запись users).
- **Personal info** — email, phone, name.
- **User content** — посты, заметки, фото.
- **Settings** — preferences.
- **Auth tokens** — все active sessions.
- **Subscriptions** — отписать от push'ей, email-рассылок.
- **Payment info** — credit card tokens, billing history.
- **Analytics** — связанные events (если можно).

Что **не нужно** удалять:

- **Логи системы** (audit, security).
- **Финансовые транзакции** — закон обязывает хранить.
- **Anonymized analytics** — уже не привязано к юзеру.

## 40.6 Apple ID / Sign in with Apple

Если используешь Sign in with Apple — должен **revoke** Apple
credential:

```swift
import AuthenticationServices

let provider = ASAuthorizationAppleIDProvider()
provider.credentialState(forUserID: userID) { state, error in
    if state == .authorized {
        // Revoke
        // ... Apple's REST API call ...
    }
}
```

В реальности это делает сервер через [Apple's REST API](https://developer.apple.com/documentation/sign_in_with_apple/revoke_tokens).

## 40.7 Subscription handling

Если у юзера активная **subscription** (через StoreKit):

- **Не отменяй её автоматически** — это deal с Apple, не с тобой.
- Покажи alert: «У тебя активная подписка. Удалить аккаунт сейчас, и
  деньги до конца периода не вернутся. Подписка автоматически
  отменится в конце цикла.»
- Дай ссылку на Settings → Apple ID → Subscriptions, где юзер может
  явно отменить.

```swift
let alert = UIAlertController(
    title: "Подписка активна",
    message: "Удалив аккаунт сейчас, ты не сможешь отменить подписку через приложение.",
    preferredStyle: .alert
)
alert.addAction(UIAlertAction(title: "Открыть Subscriptions", style: .default) { _ in
    if let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions") {
        UIApplication.shared.open(url)
    }
})
alert.addAction(UIAlertAction(title: "Удалить всё равно", style: .destructive) { _ in
    // performDelete()
})
```

`itms-apps://apps.apple.com/account/subscriptions` — deep link на
системный экран Subscriptions.

## 40.8 Re-registration (recovery)

Многие приложения позволяют **«передумать» в течение 7-30 дней**:

```swift
// При попытке login пользователем, который deleted
// Сервер возвращает 410 Gone + recovery_token
```

UI:

```
┌─────────────────────────────┐
│   Этот аккаунт удалён       │
│   (но ещё восстановим)      │
│                             │
│   Восстановить за 1 минуту  │
│   до 12 мая 2026            │
│                             │
│   [ Восстановить ]          │
│   [ Создать новый ]         │
└─────────────────────────────┘
```

После grace period сервер уже не позволяет.

## 40.9 Что **запрещено** Apple

- **«Свяжитесь с поддержкой»** — нет. Должно быть **в приложении**.
- **«Удалите приложение и переустановите»** — нет. Это не удаление
  аккаунта.
- **«Заполните форму на сайте»** — нет. Без отдельного браузера.
- **Скрытие deletion** где-то глубоко (под 5 экранами settings) — Apple
  может счесть это плохой UX и попросить улучшить.

Best practices:
- Видимая кнопка в Settings.
- Один или два confirmation step'а максимум.
- Понятный текст «что произойдёт».

## 40.10 Тестирование

Чек-лист:

- [ ] Кнопка «Удалить аккаунт» доступна без авторизации заново.
- [ ] Confirmation alert / экран показывается.
- [ ] После confirm — API запрос отправляется.
- [ ] Token из Keychain удаляется.
- [ ] UserDefaults очищается.
- [ ] FileManager данные удаляются.
- [ ] При попытке re-login с удалённым аккаунтом — соответствующая
      ошибка.
- [ ] Recovery flow (если есть) работает.

## 40.11 Documentation

В Privacy Policy / App Store description упомяни:

- Где находится кнопка удаления.
- Сколько хранятся данные после deletion.
- Что именно удаляется vs остаётся (например, anonymous analytics).

Это и юридическое требование (GDPR), и Apple просит явно.

## 📋 Что мы выучили

- **Account deletion** — обязательно по Apple Review Guidelines 5.1.1(v).
- UI: кнопка «Удалить аккаунт» в Settings, destructive стиль, под
  «Выйти».
- Confirmation **в приложении**, без отправки в support.
- Серверный flow: API request → soft delete (30 days) или hard delete.
- Локальная очистка: Keychain, UserDefaults
  (`removePersistentDomain`), FileManager files.
- Sign in with Apple — revoke через REST API.
- Subscription handling — нельзя автоотменить, направляй в Settings.
- Recovery period — допустимо предложить «передумать» в течение N
  дней.
- **Запрещено**: support-only, web-only, скрытый под глубокими
  меню.

## Apple Developer Documentation

- [App Store Review Guidelines — 5.1.1(v)](https://developer.apple.com/app-store/review/guidelines/#5.1.1) — формальное требование «account deletion внутри приложения» для всех app'ов с авторизацией.
- [`ASAuthorizationAppleIDProvider`](https://developer.apple.com/documentation/authenticationservices/asauthorizationappleidprovider) — проверка состояния Apple ID-учётки и revoke credential при удалении аккаунта.
- [Revoke tokens — Sign in with Apple REST API](https://developer.apple.com/documentation/sign_in_with_apple/revoke_tokens) — серверный endpoint, через который надо отозвать refresh-token Apple ID.
- [`SKHelper` / `Transaction.refundRequestSheet`](https://developer.apple.com/documentation/storekit/transaction/3851206-beginrefundrequest) — корректный путь для refund-сценариев при удалении аккаунта (если у юзера есть покупки).
- [HIG — Onboarding](https://developer.apple.com/design/human-interface-guidelines/onboarding) — общие принципы account creation/deletion в UX-разделе HIG.
- [`UserDefaults.removePersistentDomain(forName:)`](https://developer.apple.com/documentation/foundation/userdefaults/1417339-removepersistentdomain) — атомарная очистка всех пользовательских настроек по bundle id.
- [Keychain Services — deleting items](https://developer.apple.com/documentation/security/keychain_services/keychain_items/deleting_keychain_items) — как полностью удалить токены и пароли при удалении аккаунта.

→ [Глава 41. Production: push notifications + deep links](./63-production-push-deeplinks.md)
