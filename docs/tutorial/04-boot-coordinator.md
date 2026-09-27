# Глава 4. BootCoordinator — оркестратор гейтов

В главах 1–3 появились три детали. `AnimatedSplashViewController` —
экран, который показывает анимацию и зовёт `onFinish`. `AppManifest` —
структура с набором флагов: какие гейты нужны этому mini-app.
`PlaygroundWindow` — окно, которое сообщает о встряхивании.

Самих **гейтов** — экранов, которые пользователь проходит до main, —
в части II появится несколько: onboarding, экран разрешения, выбор
региона, проверка возраста, «обновите приложение», «ведутся работы»,
вход в аккаунт, защита при возврате из фона. Каждый — отдельный экран.
Каждый зовёт callback, когда закончил.

Кто-то должен собрать их в правильную цепочку: посмотреть в манифест,
решить, какой гейт нужен сейчас, показать его, дождаться callback'а и
перейти к очередному. Этот «кто-то» — **BootCoordinator** (boot —
«загрузка, запуск»). А раз уж он запускает mini-app, то и лаунчер,
который его создаёт, мы соберём в этой же главе.

## 4.1 Зачем отдельный класс

Когда я впервые делал подобную систему, всё сидело в `SceneDelegate`:

```swift
// Так выглядит код, который мы НЕ пишем
func scene(_ scene: UIScene, willConnectTo ...) {
    if needsOnboarding { showOnboarding(...) }
    else if needsPermission { showPermission(...) }
    else if needsAuth { showAuth(...) }
    else { showMain() }
}
```

И каждый `show*` был длинным замыканием, которое заканчивалось вызовом
очередного `show*`. `SceneDelegate` раздулся, стал нечитаемым, любое
добавление гейта ломало два соседних.

Решение — выделить **отдельный объект**, который держит:

1. **Правила** — какой гейт идёт после какого и когда он нужен.
2. **Зависимости** — окно (куда ставить экран) и манифест (что
   показывать).
3. **Выход** — что сделать, когда mini-app закрывают.

Такой объект называют **координатором** (coordinator). Приём
популяризовал iOS-разработчик Соруш Ханлу (Soroush Khanlou) в статье
«The Coordinator» в 2015 году. Идея простая: экраны ничего не знают
друг о друге и не решают, куда идти дальше, — они только сообщают «я
закончил». Порядок знает координатор.

## 4.2 Скелет — конструктор и зависимости

Файл: `App/BootCoordinator.swift`. Начало:

```swift
import UIKit

/// Проводит mini-app через цепочку гейтов: splash → … → main.
final class BootCoordinator {

    private let manifest: AppManifest
    private weak var window: PlaygroundWindow?
    private let onExit: () -> Void

    init(manifest: AppManifest,
         window: PlaygroundWindow,
         onExit: @escaping () -> Void) {
        self.manifest = manifest
        self.window = window
        self.onExit = onExit
    }
```

Три зависимости.

- `manifest` — что показывать (глава 2). `let`: по ходу запуска не
  меняется.
- `window` — куда ставить экраны. Ссылка **`weak`** (слабая): окно
  держит `SceneDelegate`, и координатору незачем продлевать ему жизнь.
  Если окно исчезло, координатору всё равно нечего делать.
- `onExit` — callback «mini-app закрыли, верни лаунчер». Его передаёт
  лаунчер (раздел 4.6).

`@escaping` у параметра-замыкания значит: «замыкание переживёт вызов
`init`» — мы сохраняем его в свойство и вызовем позже. Без этой пометки
Swift не разрешил бы сохранить замыкание.

Координатор работает только с UIKit, поэтому должен жить на главном
потоке. Писать `@MainActor` над классом в нашем проекте не нужно: с
Default Actor Isolation = MainActor (введение, раздел 0.2) это
получается автоматически. В проекте без этой настройки пометку
пришлось бы добавить — иначе Swift 6 не даст вызвать из координатора
методы UIKit.

В главе 11 у координатора появится ещё одно свойство — контроллер
защиты при сворачивании (`LifecycleSecurityController`). Пока его нет.

## 4.3 Точка входа — `start()`

```swift
    // MARK: Вход и выход

    func start() {
        window?.onShake = { [weak self] in
            self?.exitToLauncher()
        }

        if manifest.hasAnimatedSplash {
            showSplash()
        } else {
            proceedAfterSplash()
        }
    }
```

Две вещи. Первая — подписываемся на встряхивание: пользователь
встряхнул — выходим в лаунчер (глава 3). `[weak self]` — чтобы окно не
удерживало координатор (подробно — в главе 3, раздел 3.4).

Вторая — запускаем цепочку. Если в манифесте включён splash — идём
через него. Если нет — сразу к тому, что после splash'а.

И выход:

```swift
    private func exitToLauncher() {
        window?.onShake = nil
        // Если открыт модальный экран (лист, алерт) — закрываем его
        // сами, без анимации, до смены корневого экрана.
        window?.rootViewController?.dismiss(animated: false)
        onExit()
    }
```

Снимаем реакцию на встряхивание, закрываем модальный экран, если он
открыт (подробнее — в конце раздела 4.5), и сообщаем лаунчеру «я
всё».

Splash:

```swift
    // MARK: Splash

    private func showSplash() {
        let splash = AnimatedSplashViewController(manifest: manifest) { [weak self] in
            self?.proceedAfterSplash()
        }
        setRoot(splash, animated: false)
    }
```

Создаём splash из главы 1 и передаём ему callback: «когда закончишь —
вызови мой `proceedAfterSplash()`». Ставим splash в окно без анимации:
пользователь только что тапнул строку, и splash должен появиться сразу.

> **Идея.** Каждый гейт **необязателен**. Для каждого есть два пути:
> «нужен — показываем» и «не нужен — пропускаем». Координатор для
> каждого гейта выбирает один из двух методов: `showX()` или
> `proceedAfterX()`. Получается единый понятный механизм переходов.

## 4.4 Цепочка гейтов: один гейт — три метода

Сейчас, в фундаменте, гейтов ещё нет. Но место для каждого мы
подготовим сразу, чтобы в части II только вписывать новое:

```swift
    // MARK: Цепочка гейтов (её заполняет часть II)

    private func proceedAfterSplash() {
        // Глава 6: если нужен онбординг — showOnboarding()
        proceedAfterOnboarding()
    }

    private func proceedAfterOnboarding() {
        // Глава 7: если нужен permission primer — showPermissionPrimer()
        proceedAfterPermission()
    }

    private func proceedAfterPermission() {
        // Глава 10: если нужен выбор региона — showRegionPicker()
        proceedAfterRegion()
    }

    private func proceedAfterRegion() {
        // Глава 10: если нужна проверка возраста — showAgeGate()
        proceedAfterAgeGate()
    }

    private func proceedAfterAgeGate() {
        // Глава 9: если нужна проверка серверного конфига — checkRemoteConfig()
        proceedAfterRemoteConfig()
    }

    private func proceedAfterRemoteConfig() {
        // Глава 8: если нужен вход в аккаунт — showAuthGate()
        showMain()
    }
```

Сейчас каждый метод просто передаёт управление дальше по цепочке, и после
splash'а цепочка сразу доходит до `showMain()`. Методы-«проходы»
выглядят лишними, но у каждого есть своё место в очереди: в главах
6–10 мы будем менять тело одного метода, не трогая соседей.

Вот как будет выглядеть блок онбординга после главы 6:

```swift
private func proceedAfterSplash() {
    if OnboardingViewController.shouldShow(for: manifest) {
        showOnboarding()
    } else {
        proceedAfterOnboarding()
    }
}

private func showOnboarding() {
    let onboarding = OnboardingViewController(manifest: manifest) { [weak self] in
        self?.proceedAfterOnboarding()
    }
    setRoot(onboarding, animated: true)
}

private func proceedAfterOnboarding() {
    // ... решение про очередной гейт ...
}
```

Три метода вокруг одного гейта:

1. **`proceedAfterSplash()`** — развилка перед онбордингом: нужен этот
   гейт или нет. Если да — `showOnboarding()`. Если нет — сразу
   `proceedAfterOnboarding()`.
2. **`showOnboarding()`** — создаёт экран гейта и ставит его в окно. В
   callback передаёт «когда закончишь — `proceedAfterOnboarding()`».
3. **`proceedAfterOnboarding()`** — развилка перед очередным гейтом
   (экраном разрешения). Та же логика: нужен — показать, не нужен —
   пропустить.

Тройка повторяется для **каждого** гейта. Решение не самое короткое,
зато **читаемое** и **расширяемое**: новый гейт — это новая развилка и
новый `show`-метод между существующими.

Полная цепочка после части II, если у mini-app включены все гейты:

```
start()
 └─ showSplash()                          [если hasAnimatedSplash]
     └─ proceedAfterSplash()
         └─ showOnboarding()              [если hasOnboarding и ещё не показывали]
             └─ proceedAfterOnboarding()
                 └─ showPermissionPrimer() [если requiresPermission и ещё не спрашивали]
                     └─ proceedAfterPermission()
                         └─ showRegionPicker() [если requiresRegionPick и регион не выбран]
                             └─ proceedAfterRegion()
                                 └─ showAgeGate() [если requiresAgeGate и возраст не подтверждён]
                                     └─ proceedAfterAgeGate()
                                         └─ checkRemoteConfig() [если checksForceUpdate или hasMaintenanceCheck]
                                             └─ proceedAfterRemoteConfig()
                                                 └─ showAuthGate() [если hasAuthGate и не вошли]
                                                     └─ showMain()
```

Лесенка глубокая, но каждый узел простой: проверить флаг и перейти к
одному из двух соседей. На практике у mini-app включены один-два
гейта: у «Профиля» — вход и защита при сворачивании, у «Погоды» —
разрешение на геопозицию.

Main-экран:

```swift
    // MARK: Main

    private func showMain() {
        let main = manifest.makeMain()
        let nav = UINavigationController(rootViewController: main)
        nav.navigationBar.tintColor = manifest.brandColor
        setRoot(nav, animated: true)
        // Глава 11: здесь запустим LifecycleSecurityController
    }
```

`manifest.makeMain()` — вызываем фабрику из главы 2 и получаем свежий
main-экран. Оборачиваем его в **`UINavigationController`** — контейнер,
который держит экраны **стопкой**: `push` кладёт новый экран сверху,
кнопка «Назад» снимает верхний. Сверху у него **панель навигации**
(navigation bar) с заголовком экрана и кнопками. Многие mini-app
открывают из main-экрана вложенные экраны (карточку заметки, настройки),
и стопка им нужна.

`navigationBar.tintColor` — цвет кнопок на панели. Берём фирменный
цвет mini-app: кнопки в «Списке дел» будут синими, в «Чате» —
зелёными.

**Упражнение 4.1.** Добавь в начало каждого метода цепочки (`start`,
`showSplash`, все `proceedAfter…`, `showMain`) строку
`print(#function)` и запусти любое mini-app. Что появится в консоли и в
каком порядке? Что изменится для mini-app с `hasAnimatedSplash = false`?

## 4.5 `setRoot` — как меняем экран в окне

Координатор не кладёт экраны в стопку через `push`. Он **меняет
корневой экран окна целиком**: splash → онбординг → экран разрешения
→ main. Каждый раз `rootViewController` окна — другой экран.

Почему так? Потому что пройденный гейт **своё отработал**, и
возвращаться к нему нельзя. Будь гейты в одной стопке, пользователь мог
бы смахнуть назад из онбординга обратно в splash — бессмыслица. К тому
же у гейтов разный «верх»: у splash'а нет панели навигации, у
онбординга свои кнопки, у экрана разрешения — ничего. В общей стопке
панель навигации пришлось бы то прятать, то показывать.

Меняем корневой экран так:

```swift
    // MARK: Смена root

    private func setRoot(_ vc: UIViewController, animated: Bool) {
        guard let window else { return }
        if animated {
            UIView.transition(with: window,
                              duration: 0.35,
                              options: .transitionCrossDissolve,
                              animations: {
                                  window.rootViewController = vc
                              })
        } else {
            window.rootViewController = vc
        }
    }
}
```

`guard let window` — окно слабое, и его может уже не быть; тогда
тихо выходим.

`UIView.transition(with:duration:options:animations:)` — анимированная
замена содержимого view. Внутри `animations` мы меняем
`rootViewController`, а UIKit делает «снимок до» и «снимок после» и
плавно переводит одно в другое. `.transitionCrossDissolve` —
**перекрёстное растворение**: старый экран за 0.35 секунды становится
прозрачным, новый одновременно проявляется. Около трети секунды —
достаточно, чтобы глаз заметил смену, и недостаточно, чтобы заскучать.

Без анимации (`animated: false`) экран меняется мгновенно — так
ставим splash.

> **Замена root — не бесплатна.** Старый корневой экран убирается из
> окна со всеми вложенными view, новый загружается, его view
> вставляется в окно и заново раскладывается. Для смены гейта —
> события раз в несколько секунд — это пустяк. Но делать `setRoot` в
> ответ на каждое нажатие — плохая идея.

### Модальные экраны при выходе

Если в mini-app открыт **модальный** экран — лист снизу (sheet), алерт,
полноэкранное окно поверх, — а пользователь встряхнул телефон, то в
`exitToLauncher()` мы сначала закрываем его:

```swift
window?.rootViewController?.dismiss(animated: false)
```

`dismiss` на экране, который сам что-то показал, закрывает всё, что
показано поверх него. Если поверх ничего нет — вызов ничего не делает.

Строго говоря, на iOS 26.5 эта строка не обязательна: мы проверили в
собранном playground'е — открыли лист поверх заглушки и встряхнули
**без** `dismiss`, и UIKit сам убрал лист вместе со старым корневым
экраном, а в памяти не осталось ни листа, ни экранов mini-app. На
старых версиях iOS мы это не проверяли, поэтому оставляем `dismiss`
как явное намерение и дешёвую страховку: закрыть модальный экран до
смены корня ничего не ломает.

## 4.6 Кто держит координатор. Лаунчер целиком

Координатор — обычный объект. Если на него нет ни одной **сильной
ссылки**, система освобождает его сразу после `start()`. Тогда все
callback'и с `[weak self]` получат `nil`, и цепочка оборвётся: splash
доиграет анимацию и… ничего не случится.

Держит координатор **лаунчер** — `AppListViewController`. Разберём его
целиком: он показывает список mini-app и запускает выбранное.

Файл: `App/AppListViewController.swift`.

```swift
import UIKit

/// Лаунчер: список всех mini-app из AppRegistry.
final class AppListViewController: UITableViewController {

    /// Как добраться до окна — даёт SceneDelegate.
    var windowProvider: (() -> PlaygroundWindow?)?
    /// Что сделать, когда mini-app закрылось, — тоже даёт SceneDelegate.
    var onReturnToLauncher: (() -> Void)?

    private let apps: [AppManifest] = AppRegistry.allApps
    private var activeCoordinator: BootCoordinator?
    private let cellID = "AppCell"

    init() {
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) не используется: экран создаётся только кодом")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "UIKit Playground"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellID)
    }
```

**`UITableViewController`** — готовый view controller, у которого
корневой view — **таблица** (`UITableView`): вертикальный
прокручиваемый список строк. Стиль `.insetGrouped` — строки собраны в
скруглённую «карточку» с отступами по бокам на сером фоне, как в
приложении «Настройки». Этот серый фон мы и повторили в launch screen
(глава 1).

Два свойства-замыкания — `windowProvider` и `onReturnToLauncher` —
лаунчер получает от `SceneDelegate` (глава 5). Самому лаунчеру окно не
принадлежит, но координатору окно нужно. Поэтому `SceneDelegate`
даёт лаунчеру «способ добраться до окна» и «способ вернуть лаунчер на
экран». Такой приём — передать объекту то, что ему нужно, снаружи, а не
заставлять его искать самому, — называется **внедрением зависимостей**
(dependency injection).

`activeCoordinator` — та самая сильная ссылка на координатор.

`tableView.register(_:forCellReuseIdentifier:)` — сообщаем таблице:
«ячейки с идентификатором `AppCell` — это обычные `UITableViewCell`».
Зачем идентификатор, — сразу ниже.

### Data source — что показать

```swift
    // MARK: Data source — что показать

    override func tableView(_ tableView: UITableView,
                            numberOfRowsInSection section: Int) -> Int {
        apps.count
    }

    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellID, for: indexPath)
        let app = apps[indexPath.row]

        var content = UIListContentConfiguration.subtitleCell()
        content.text = app.name
        content.secondaryText = app.subtitle
        content.secondaryTextProperties.color = .secondaryLabel
        content.image = UIImage(systemName: app.symbolName)
        content.imageProperties.tintColor = app.brandColor
        cell.contentConfiguration = content

        // Ячейка переиспользуется: задаём ОБА варианта, а не только один.
        cell.accessoryView = app.isReady ? nil : makeSoonBadge()
        cell.accessoryType = app.isReady ? .disclosureIndicator : .none
        return cell
    }
```

Таблица сама не знает, что показывать. Она спрашивает у своего
**data source** (источника данных) — объекта, который отвечает на
вопросы «сколько строк?» и «что в строке номер N?». У
`UITableViewController` источник данных — он сам, поэтому мы
переопределяем эти два метода.

`numberOfRowsInSection` — сколько строк: столько, сколько манифестов.

`cellForRowAt` — строка номер `indexPath.row`. Здесь важное понятие —
**переиспользование ячеек**. Таблица не создаёт ячейку на каждую
строку: если строк тысяча, а на экране помещается десять, ячеек будет
около десяти. Строка ушла за верх экрана — её ячейка возвращается в
«запас» и тут же используется для строки, появившейся снизу.
`dequeueReusableCell(withIdentifier:for:)` — «дай ячейку из запаса,
а если там пусто — создай новую».

Отсюда правило: в `cellForRowAt` нужно **заново задать всё**, что
отличается между строками. Ячейка может прийти из запаса с данными
другой строки. Поэтому у пометки «СКОРО» мы задаём оба варианта: для
готового mini-app явно убираем её (`accessoryView = nil`) и ставим
стрелку `›` (`disclosureIndicator`), для заглушки — наоборот. Если бы
мы писали только `if !app.isReady { cell.accessoryView = … }`, то после
прокрутки пометка «СКОРО» из чужой строки могла бы остаться у готового
mini-app.

`UIListContentConfiguration` (iOS 14+) — готовая раскладка
содержимого ячейки: картинка слева, основной текст, дополнительный
текст под ним. Вариант `.subtitleCell()` — дополнительный текст
второй строкой. Заполняем поля и присваиваем конфигурацию ячейке, а
раскладку, отступы и поддержку Dynamic Type UIKit делает сам.

```swift
    override func tableView(_ tableView: UITableView,
                            titleForFooterInSection section: Int) -> String? {
        "Внутри mini-app встряхни устройство (в симуляторе ⌃⌘Z), чтобы вернуться сюда."
    }
```

Подпись под списком — подсказка про встряхивание. Без неё жест никто
не найдёт (глава 3).

### Delegate — что делать по тапу

```swift
    // MARK: Delegate — что делать по тапу

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        launch(apps[indexPath.row])
    }
```

Второй помощник таблицы — **delegate** (делегат): объект, которому
таблица сообщает о событиях — «тапнули строку», «строка сейчас
появится». Data source отвечает на вопрос «что показать», delegate —
«что делать». Аналогия: data source — повар, который готовит блюда,
delegate — официант, которому говорят «вот этот столик позвал».

По тапу снимаем выделение со строки (иначе, вернувшись в лаунчер,
пользователь увидит её подсвеченной серым) и запускаем mini-app.

### Запуск mini-app

```swift
    // MARK: Запуск mini-app

    private func launch(_ manifest: AppManifest) {
        guard let window = windowProvider?() else { return }
        let coordinator = BootCoordinator(
            manifest: manifest,
            window: window,
            onExit: { [weak self] in
                self?.activeCoordinator = nil
                self?.onReturnToLauncher?()
            }
        )
        activeCoordinator = coordinator
        coordinator.start()
    }

    private func makeSoonBadge() -> UIView {
        let label = UILabel()
        label.text = "СКОРО"
        label.font = .preferredFont(forTextStyle: .caption2)
        label.textColor = .secondaryLabel
        label.sizeToFit()
        return label
    }
}
```

`windowProvider?()` — вызываем опциональное замыкание: получаем окно
(или `nil`, если замыкание не задано или окна уже нет).

Создаём координатор и **сохраняем** его в `activeCoordinator` —
лаунчер держит его, **пока пользователь в mini-app**. Когда сработает
`onExit` (встряхнули или гейт сам попросил выйти, как проверка
возраста в разделе 4.7), лаунчер обнуляет ссылку:
`self?.activeCoordinator = nil`. На координатор больше никто не
ссылается, и **ARC** (автоматический подсчёт ссылок Swift) освобождает
его. Вместе с ним уходят и экраны mini-app.

В `onExit` — `[weak self]`: координатор хранит это замыкание, а
лаунчер хранит координатор. Сильный захват лаунчера замкнул бы круг:
лаунчер → координатор → замыкание → лаунчер. Это **цикл сильных
ссылок** (retain cycle): объекты держат друг друга и не освобождаются
никогда.

`makeSoonBadge()` — пометка «СКОРО»: маленький серый лейбл.
`sizeToFit()` подгоняет размер лейбла под текст — `accessoryView`
раскладывается без Auto Layout, по размеру самого view.

Мы проверили цепочку жизни объектов в собранном playground'е: после
встряхивания и возврата в лаунчер не остаётся в памяти ни
координатора, ни splash'а, ни main-экрана.

> **Признак «забыли удержать».** Запустил mini-app, splash доиграл — и
> ничего не происходит, callback'и не срабатывают. Почти всегда это
> значит, что координатор освободился посередине. Проверь, что у
> кого-то есть сильная ссылка вида `var coordinator: ...`.

**Упражнение 4.2.** Замени в `launch(_:)` строку `activeCoordinator =
coordinator` на `_ = coordinator` (то есть не сохраняй координатор).
Что произойдёт, когда ты запустишь mini-app? Объясни по шагам.

## 4.7 Гейт может сам **выйти** в лаунчер

Большинство гейтов пропускают пользователя дальше. Но проверка
возраста (глава 10) особая: если пользователь слишком молод, дальше
его не пускаем, и кнопка «Вернуться» ведёт в лаунчер. Поэтому у этого
гейта **два** callback'а — `onPass` и `onTooYoung`. Так этот блок будет
выглядеть в координаторе после главы 10:

```swift
private func showAgeGate() {
    let gate = AgeGateViewController(
        manifestId: manifest.id,
        brandColor: manifest.brandColor,
        minAge: manifest.minAgeYears,
        onPass: { [weak self] in self?.proceedAfterAgeGate() },
        onTooYoung: { [weak self] in self?.exitToLauncher() }
    )
    setRoot(gate, animated: true)
}
```

`onPass` → идём дальше по цепочке. `onTooYoung` → сразу в лаунчер.

Полезный приём: у гейта может быть **больше одного выхода**, и
координатор решает, куда ведёт каждый. Сам гейт про лаунчер не знает —
он только сообщает, чем всё закончилось.

## 4.8 Бытовая аналогия

Координатор — **администратор поликлиники**. Пациент приходит,
администратор смотрит в карту (манифест): «нужна справка — в кабинет
3, нужны анализы — в кабинет 7, всё в порядке — к врачу».

Кабинеты (splash, онбординг, экран разрешения) друг о друге не
знают. Каждый делает своё и отправляет пациента обратно к
администратору: «у нас всё». Куда дальше — решает администратор.

Если бы кабинеты сами отправляли пациента в другой кабинет, поменять
порядок было бы мучением: пришлось бы переучивать каждый кабинет. С
администратором достаточно поменять пару строк в его инструкции.

## 4.9 Что можно улучшить

Текущая реализация практичная, но не единственная. Если цепочка
станет длиннее, есть варианты.

- **Конечный автомат** (state machine). Каждый гейт — состояние,
  координатор — таблица переходов между состояниями. Порядок виден
  целиком в одном месте.
- **Цепочка через общий протокол «гейт»**:
  ```swift
  Chain
      .start(SplashGate())
      .then(OnboardingGate.if(manifest.hasOnboarding))
      .then(PermissionGate.if(manifest.requiresPermission != nil))
      .terminate(MainGate())
  ```
  Это псевдокод — такого API нет, его пришлось бы написать. Выглядит
  чище, но требует общей абстракции «гейт», а наши гейты слишком
  разные: у проверки возраста два выхода, у проверки конфига —
  асинхронный запрос к серверу.
- **Цепочка на async/await**:
  ```swift
  await splashGate.show(in: window)
  if shouldShowOnboarding { await onboardingGate.show(in: window) }
  ```
  Линейный код вместо лесенки callback'ов. Но каждый гейт должен
  уметь «показаться и дождаться окончания» как `async`-функция.

Всё это можно прикрутить позже. На нашем масштабе — около восьми
гейтов — «простой» подход с тройками методов даёт лучший баланс
читаемости и простоты.

**Упражнение 4.3.** Допустим, после части II ты решил, что вход в
аккаунт должен идти **раньше** экрана разрешения: сначала войти, потом
просить геопозицию. Какие методы координатора придётся поменять и как?
Ответь, не запуская код.

## Ответы к упражнениям

**4.1.** Для mini-app со splash'ем в консоли будет:

```
start()
showSplash()
proceedAfterSplash()
proceedAfterOnboarding()
proceedAfterPermission()
proceedAfterRegion()
proceedAfterAgeGate()
proceedAfterRemoteConfig()
showMain()
```

Причём `start()` и `showSplash()` — сразу по тапу, а остальное —
одной пачкой примерно через 1.65 секунды, когда splash вызовет
`onFinish`. Все `proceedAfter…` пока только передают управление
дальше, поэтому идут подряд без пауз. `#function` — специальный
литерал Swift, который подставляет имя текущей функции.

Для mini-app с `hasAnimatedSplash = false` строки `showSplash()` не
будет, и вся цепочка напечатается сразу после тапа.

**4.2.** Координатор создастся, `start()` поставит splash и повесит
`onShake`, а после выхода из `launch(_:)` на координатор не останется
ни одной сильной ссылки — ARC освободит его. Splash доиграет анимацию
и вызовет `onFinish`, но в этом замыкании `self` (координатор) уже
`nil`, и `proceedAfterSplash()` не вызовется. Пользователь застрянет на
splash'е. Встряхивание тоже не поможет: замыкание `onShake` захватило
координатор слабо и теперь ничего не делает.

**4.3.** Сейчас порядок такой: … → `proceedAfterOnboarding()` →
экран разрешения → `proceedAfterPermission()` → … →
`proceedAfterRemoteConfig()` → вход → `showMain()`. Чтобы вход шёл
раньше разрешения:

1. В `proceedAfterOnboarding()` вместо развилки «разрешение» поставить
   развилку «вход»: если нужен — `showAuthGate()`, иначе — сразу то,
   что после входа.
2. Callback экрана входа (и ветка «вход не нужен») теперь ведёт не в
   `showMain()`, а в развилку «разрешение» — то, что раньше было телом
   `proceedAfterOnboarding()`.
3. В `proceedAfterRemoteConfig()` вместо развилки «вход» — сразу
   `showMain()`.

Сами экраны гейтов не меняются вовсе: они по-прежнему сообщают только
«я закончил». Весь порядок — в координаторе.

## Что мы выучили

- `BootCoordinator` — отдельный класс, который знает порядок гейтов.
  Без него вся логика запуска осела бы в `SceneDelegate`.
- Зависимости: `manifest` (что показывать), `window` (куда, `weak`),
  `onExit` (как вернуть лаунчер).
- Один гейт = три метода: развилка `proceedAfter…` (нужен или нет),
  `show…` (создать экран), callback экрана → очередная развилка. В
  фундаменте развилки пока пустые — их заполняет часть II.
- `showMain()` оборачивает main-экран в `UINavigationController` с
  фирменным цветом кнопок.
- `setRoot` меняет `window.rootViewController` целиком, с
  перекрёстным растворением за 0.35 секунды. Открытый модальный экран
  перед выходом закрываем через `dismiss`.
- Лаунчер (`AppListViewController`) — таблица: data source отвечает
  «что показать», delegate — «что делать по тапу». Ячейки
  переиспользуются, поэтому в `cellForRowAt` задаём все отличающиеся
  свойства заново.
- Координатор держит лаунчер (`activeCoordinator`); при выходе ссылку
  обнуляем, и ARC освобождает координатор вместе с экранами mini-app.
- У гейта может быть несколько выходов (`onPass` / `onTooYoung`), а
  куда какой ведёт — решает координатор.

## Apple Developer Documentation

Паттерна «координатор» в документации Apple нет — это приём сообщества
разработчиков. Но все API, на которых он стоит, — обычные UIKit и Swift.

- [`UIWindow.rootViewController`](https://developer.apple.com/documentation/uikit/uiwindow/rootviewcontroller) — корневой экран окна, который меняет `setRoot`.
- [`UIView.transition(with:duration:options:animations:completion:)`](https://developer.apple.com/documentation/uikit/uiview/1622574-transition) — анимация перекрёстного растворения при смене корневого экрана.
- [`UINavigationController`](https://developer.apple.com/documentation/uikit/uinavigationcontroller) — стопка экранов с панелью навигации, в которую `showMain()` кладёт main-экран.
- [`UITableViewController`](https://developer.apple.com/documentation/uikit/uitableviewcontroller) и [`UITableViewDataSource`](https://developer.apple.com/documentation/uikit/uitableviewdatasource) — основа лаунчера.
- [`dequeueReusableCell(withIdentifier:for:)`](https://developer.apple.com/documentation/uikit/uitableview/1614878-dequeuereusablecell) — переиспользование ячеек.
- [`UIListContentConfiguration`](https://developer.apple.com/documentation/uikit/uilistcontentconfiguration) — готовая раскладка содержимого ячейки.
- [`dismiss(animated:completion:)`](https://developer.apple.com/documentation/uikit/uiviewcontroller/1621505-dismiss) — закрытие модальных экранов перед выходом в лаунчер.
- [Automatic Reference Counting — Swift Book](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/automaticreferencecounting) — сильные и слабые ссылки, циклы сильных ссылок и почему координатор должен кто-то держать.

→ [Глава 5. Lifecycle App → Scene → VC и @MainActor под капотом](./05-lifecycle.md)
