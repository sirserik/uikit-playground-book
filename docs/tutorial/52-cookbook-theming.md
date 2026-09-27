# Глава 35. Cookbook — темы и цвета

Светлая и тёмная тема, системные «смысловые» цвета, своя палитра
бренда и выбор темы в настройках приложения.

В основе всего лежит **trait collection** (`UITraitCollection`) —
набор характеристик окружения, в котором сейчас показывается view:
тема (светлая или тёмная), размер шрифта Dynamic Type, повышенный
контраст, **size class** (грубая оценка ширины и высоты: «компактная»
на iPhone в портрете, «обычная» на iPad) и другие. Каждый view и
контроллер знает свою trait collection (`traitCollection`) и получает
её от родителя: окно → контроллер → его view → дочерние view. Когда
пользователь переключает тему, по всему этому дереву проходит
изменение, и адаптивные цвета перерисовываются.

Аналогия: trait collection — это «погода» в комнате, где висит view.
Цвет, подобранный под погоду, как хамелеон: сам меняется, когда
«погода» сменилась.

## 35.1 Системные цвета (адаптивные)

```swift
view.backgroundColor = .systemBackground       // белый в светлой / чёрный в тёмной
label.textColor = .label                       // чёрный / белый
label.textColor = .secondaryLabel              // серый, приглушённый
label.textColor = .tertiaryLabel               // ещё бледнее

// Фоны
view.backgroundColor = .secondarySystemBackground
view.backgroundColor = .tertiarySystemBackground
view.backgroundColor = .systemGroupedBackground     // для таблиц в стиле grouped

// Заливки (фон полей, кнопок, прогресс-баров)
view.backgroundColor = .systemFill
view.backgroundColor = .secondarySystemFill
view.backgroundColor = .tertiarySystemFill
view.backgroundColor = .quaternarySystemFill

// Разделители
view.backgroundColor = .separator
view.backgroundColor = .opaqueSeparator
```

Эти цвета называют **семантическими** (смысловыми): имя говорит не
«какой цвет», а «для чего» — «основной текст», «фон второго уровня».
Конкретное значение подставит система по trait collection. `.label` в
светлой теме — чёрный, в тёмной — белый; при повышенном контрасте —
ещё контрастнее.

Отсюда правило: для фонов и текста интерфейса бери семантические
цвета, а не `.white` и `.black`. Белый фон, заданный жёстко, в тёмной
теме останется белым — с белым же текстом `.label` на нём. `.white`
уместен там, где цвет не должен меняться: белый текст на
красной кнопке, белая иконка поверх фото.

**Уровни фона.** `systemBackground` → `secondarySystemBackground` →
`tertiarySystemBackground` — это «слои»: экран, карточка на экране,
поле внутри карточки. В светлой теме слои различаются оттенком
серого, в тёмной — становятся чуть светлее с каждым уровнем.

Есть и тонкость, о которой узнают случайно: в тёмной теме у модальных
листов и поповеров фон **светлее** чёрного. Система поднимает
«уровень» интерфейса (`traitCollection.userInterfaceLevel =
.elevated`), и тот же `.systemBackground` становится тёмно-серым, чтобы
лист отделялся от экрана под ним. Если в листе ты задал фон жёстким
чёрным, это отделение пропадёт.

Полный список — в HIG, раздел Color:
[Apple Human Interface Guidelines — Color](https://developer.apple.com/design/human-interface-guidelines/color).

## 35.2 Tint color — цвет акцента

```swift
view.tintColor = .systemIndigo
button.tintColor = .systemRed  // переопределить для одной кнопки
```

**`tintColor`** — цвет «интерактивности»: системные кнопки, иконки в
навбаре, переключатели, выделение в пикере. Он **наследуется** вниз по
иерархии view: задал окну — подхватит всё приложение. Хочешь другой
цвет у одной кнопки — задай его ей.

`.systemBlue`, `.systemRed`, `.systemGreen` и остальные тоже
адаптивные: в тёмной теме и при повышенном контрасте у каждого свой
оттенок. Apple подстраивает их от версии к версии: в iOS 26.5
`systemBlue` в светлой теме — `#0088FF`, в тёмной — `#0091FF` (замер
на симуляторе). Поэтому не записывай системные цвета в код числами.

## 35.3 Свой адаптивный цвет в коде

```swift
let cardBackground = UIColor { traitCollection in
    if traitCollection.userInterfaceStyle == .dark {
        return UIColor(white: 0.15, alpha: 1.0)
    } else {
        return UIColor(white: 0.98, alpha: 1.0)
    }
}
```

`UIColor(dynamicProvider:)` (iOS 13+) — цвет, который определяется
замыканием. UIKit вызывает его каждый раз, когда ему нужно конкретное
значение, и передаёт текущую trait collection. `white: 0.15` — серый,
в котором 15% «белизны»: почти чёрный для тёмной темы. `0.98` — почти
белый для светлой.

Замыкание вызывается часто — держи его быстрым и без побочных
эффектов: никаких сетевых запросов и записей в `UserDefaults`.

## 35.4 Цвета в Asset Catalog

Это рекомендуемый способ для палитры бренда. В `Assets.xcassets`:

1. **+** → Color Set, назови `BrandPrimary`.
2. В инспекторе справа, в Appearances, выбери **Any, Dark** — появятся
   два квадрата.
3. Задай цвета: Any (светлая) — `#1A73E8`, Dark — `#4285F4`.
4. Если нужен вариант для повышенного контраста — там же включи
   **High Contrast** (см. главу 34.7).

В коде:

```swift
let primary = UIColor(named: "BrandPrimary") ?? .systemBlue
view.backgroundColor = primary
```

Один набор цветов сам работает в обеих темах. `UIColor(named:)`
возвращает опционал: при опечатке в имени получишь `nil`. `?? .systemBlue`
даёт запасной цвет; если хочешь, чтобы опечатку было невозможно
пропустить, лучше упасть сразу с понятным сообщением (как в 35.8), чем
молча показывать не тот цвет.

## 35.5 Принудительная тема

Конкретный экран всегда тёмный:

```swift
override func viewDidLoad() {
    super.viewDidLoad()
    overrideUserInterfaceStyle = .dark  // этот контроллер, его view и дочерние контроллеры
}
```

Так сделан Калькулятор (глава 14.9) — всегда тёмный, независимо от
системы. Так же — просмотрщик фото (глава 37).

Всё приложение:

```swift
// В SceneDelegate
window?.overrideUserInterfaceStyle = .dark
```

Окно — корень иерархии, поэтому тема окна достаётся всем экранам,
включая модальные. Если приложение **вообще** не поддерживает тёмную
тему, можно вместо кода добавить в Info.plist ключ
`UIUserInterfaceStyle` со значением `Light` (в Xcode он называется
«Appearance»). Но сделать тёмную тему обычно дешевле, чем объяснять
пользователям, почему её нет.

## 35.6 Реакция на смену темы

Семантические и `dynamicProvider`-цвета, присвоенные свойствам
`UIView` (`backgroundColor`, `textColor`, `tintColor`), меняются
сами. Не меняются цвета, которые ушли в **`CALayer`**: у слоя цвет —
`CGColor`, обычное число без привязки к теме. Когда ты пишешь
`UIColor.systemBackground.cgColor`, UIKit один раз выбирает значение
для текущей темы и отдаёт его слою. Сменилась тема — слой остался со
старым цветом.

Типичные жертвы: `layer.borderColor`, `layer.shadowColor`, цвета
`CAGradientLayer` и `CAShapeLayer`. Их обновляют вручную при смене
темы.

На iOS 17+ — регистрация на изменение нужной характеристики:

```swift
final class GradientView: UIView {
    private let gradient = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.addSublayer(gradient)
        updateColors()
        if #available(iOS 17, *) {
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
                self.updateColors()
            }
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) не используется")
    }

    // iOS 15–16: старый способ (в iOS 17 помечен устаревшим)
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 17, *) { return }
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateColors()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds
    }

    private func updateColors() {
        let tc = traitCollection
        gradient.colors = [
            UIColor.systemBlue.resolvedColor(with: tc).cgColor,
            UIColor.systemPurple.resolvedColor(with: tc).cgColor,
        ]
    }
}
```

Разбор:

- `registerForTraitChanges([UITraitUserInterfaceStyle.self])` — «сообщи,
  когда поменяется тема». Замыкание получает сам view как параметр
  (`self: Self`), поэтому `[weak self]` не нужен: UIKit не создаёт
  цикла.
- `traitCollectionDidChange` — способ для iOS 15–16. В iOS 17 он
  помечен устаревшим, поэтому внутри мы выходим сразу, если работает
  новая регистрация, — иначе на iOS 17+ цвета обновлялись бы дважды.
- `hasDifferentColorAppearance(comparedTo:)` — изменилось ли то, что
  влияет на цвета (тема, контраст, уровень интерфейса). Смена размера
  шрифта сюда не попадёт — лишней перерисовки не будет.
- `resolvedColor(with: tc)` — «какой конкретный цвет у адаптивного
  цвета для этой trait collection». Надёжнее, чем голый `.cgColor`,
  который смотрит на «текущую» trait collection потока.

Без этого кода градиент «застрянет» в теме, в которой экран
открылся: пользователь переключил тему в Пункте управления — а у
тебя на тёмном экране висит светлый градиент.

## 35.7 Выбор темы в настройках приложения

```swift
enum AppTheme: Int, CaseIterable {
    case system, light, dark

    var displayName: String {
        switch self {
        case .system: return "Как в системе"
        case .light: return "Светлая"
        case .dark: return "Тёмная"
        }
    }

    var userInterfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: return .unspecified
        case .light: return .light
        case .dark: return .dark
        }
    }

    static var saved: AppTheme {
        AppTheme(rawValue: UserDefaults.standard.integer(forKey: "settings.theme")) ?? .system
    }

    func save() {
        UserDefaults.standard.set(rawValue, forKey: "settings.theme")
    }
}
```

Разбор:

- `Int` в качестве сырого значения — чтобы хранить выбор в
  `UserDefaults` числом. `system` = 0, `light` = 1, `dark` = 2.
- `.unspecified` — «ничего не навязывать», тема будет как в системе.
- `saved` читает `integer(forKey:)`. Если пользователь ещё ничего не
  выбирал, ключа нет и метод вернёт 0 — это как раз `.system`. Удачно
  совпало не случайно: вариант «по умолчанию» поставлен первым.

Применение — при запуске, в `SceneDelegate`, до показа окна:

```swift
func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
           options connectionOptions: UIScene.ConnectionOptions) {
    guard let windowScene = scene as? UIWindowScene else { return }
    let window = UIWindow(windowScene: windowScene)
    window.overrideUserInterfaceStyle = AppTheme.saved.userInterfaceStyle
    window.rootViewController = RootViewController()
    window.makeKeyAndVisible()
    self.window = window
}
```

И при выборе в настройках — сохранить и применить к окну текущей
сцены (`view.window`):

```swift
private func themeSelected(_ theme: AppTheme) {
    theme.save()
    view.window?.overrideUserInterfaceStyle = theme.userInterfaceStyle
}
```

Меню выбора — `UIMenu` на кнопке или action sheet (см. главу 28.7).

## 35.8 Палитра бренда

```swift
enum Palette {
    static let primary = color("BrandPrimary")
    static let secondary = color("BrandSecondary")
    static let accent = color("BrandAccent")
    static let success = color("BrandSuccess")
    static let warning = color("BrandWarning")
    static let danger = color("BrandDanger")

    private static func color(_ name: String) -> UIColor {
        guard let color = UIColor(named: name) else {
            fatalError("Нет цвета \(name) в Assets.xcassets")
        }
        return color
    }
}

view.backgroundColor = Palette.primary
button.tintColor = Palette.accent
```

Это расширенная версия `Palette` из главы 5 (`Common/DesignSystem.swift`):
в проекте playground'а замени ей ту, а не заводи вторую, иначе
компилятор скажет, что `Palette` объявлен дважды. Имена `success` и
`danger` сохранены, так что код, который ими уже пользуется, не
сломается; вместо `tint` из главы 5 здесь `accent`.

Все цвета бренда — в одном месте. Код ссылается на `Palette.primary`,
а не на строку `"BrandPrimary"` в сорока местах, — опечатка возможна
только внутри `Palette`, и `fatalError` с понятным текстом покажет её
при первом же запуске экрана.

Дизайнер сказал «поменяй основной с синего на бирюзовый» — меняешь
цвет в color set `BrandPrimary`, код не трогаешь. Приложение при этом
**пересобирается**: Asset Catalog компилируется вместе с кодом, и
новый цвет попадёт к пользователям только с новой версией в App
Store. Менять цвета «на лету», без релиза, можно лишь загружая их с
сервера — это отдельная задача.

## 35.9 Контраст цветов

Требования WCAG (подробно и с числами — в главе 34.7):

- уровень **AA**: 4.5:1 для обычного текста, 3:1 для крупного и для
  значков;
- уровень **AAA**: 7:1 для обычного текста, 4.5:1 для крупного.

«Крупный» в терминах WCAG — от 18 пунктов обычным начертанием или от
14 жирным (в пикселях веба — 24 и примерно 19). Для iOS это грубо
соответствует стилям `.title3` и крупнее.

У Apple в HIG правило мягче: 3:1 хватает и жирному тексту любого
размера. Разницу между двумя стандартами разбирает глава 34, раздел
34.7; надёжнее держать мелкий жирный текст на 4.5:1.

Системные цвета **не все** проходят AA. Замер на iOS 26.5:
`.secondaryLabel` на белом — 3,4:1, `.systemGreen` на белом — 2,2:1.
Со своей палитрой проверяй каждую пару «текст/фон» в обеих темах:
Accessibility Inspector (кнопка Audit) или любой калькулятор контраста
по HEX-кодам.

Реакция на повышенный контраст — лучше всего через Asset Catalog
(вариант High Contrast у color set). Если нужен код:

```swift
let secondaryText = UIColor { traits in
    traits.accessibilityContrast == .high ? .label : .secondaryLabel
}
label.textColor = secondaryText
```

Цвет — адаптивный, поэтому сам перерисуется, когда пользователь
включит «Увеличение контраста». Проверка
`UIAccessibility.isDarkerSystemColorsEnabled` внутри
`traitCollectionDidChange` работала бы хуже: без подписки на
уведомление смена настройки может пройти мимо.

## 35.10 Цвета в Storyboard

Цвета из Asset Catalog доступны в списке цветов Interface Builder —
выбираешь `BrandPrimary`, и он работает в обеих темах. Системные
семантические цвета там тоже есть (System Background Color, Label
Color).

Цвет, заданный в Storyboard числами (`RGB 123, 45, 67`), не
адаптивный: в тёмной теме он останется таким же. В этой книге
Storyboard используется только для LaunchScreen, но правило то же:
на экране запуска — цвета из Asset Catalog, иначе тёмная тема
начнётся с белой вспышки.

## 35.11 Плавная смена темы

```swift
extension UIWindow {
    func setTheme(_ theme: AppTheme) {
        UIView.transition(with: self, duration: 0.3,
                          options: .transitionCrossDissolve,
                          animations: {
            self.overrideUserInterfaceStyle = theme.userInterfaceStyle
        })
    }
}

// Использование, например, в настройках
view.window?.setTheme(.dark)
```

Без анимации всё приложение перекрашивается мгновенно — резкая вспышка.
`transitionCrossDissolve` за 0,3 с растворяет старую картинку окна в
новой (подробнее о переходах — в главе 32.9).

## 35.12 Тема у дочерних и модальных экранов

`overrideUserInterfaceStyle` у контроллера, по документации Apple,
действует на сам контроллер, всю его иерархию view и **встроенные**
дочерние контроллеры (children — те, что добавлены через
`addChild`, например экраны внутри `UINavigationController`).

Модальный экран (`present`) дочерним не является — он показывается
поверх в своём контейнере и берёт тему **окна**. Если ты сделал тёмным
один контроллер через override, а из него показываешь лист, лист будет
в теме системы. Хочешь, чтобы он тоже был тёмным, — задай override и
ему перед `present`. А тема, заданная окну (35.5), действует на все
экраны сразу, включая модальные.

## Упражнения

**Упражнение 35.1.** У карточки есть рамка:
`card.layer.borderColor = UIColor.separator.cgColor`. Пользователь
переключает тему, и рамка становится то слишком яркой, то невидимой.
Объясни почему и исправь для iOS 15+.

**Упражнение 35.2.** Сделай адаптивный цвет «фон ценника»: светлая тема
— `#FFF4E5`, тёмная — `#3A2A14`, а при повышенном контрасте в обеих
темах — `.systemBackground`. Используй `UIColor(dynamicProvider:)`.

## Ответы к упражнениям

**35.1.** `.cgColor` превращает адаптивный цвет в конкретный в момент
присваивания; слой не знает о темах. Обновляем цвет при смене
характеристик:

```swift
final class CardView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.borderWidth = 1
        updateBorder()
        if #available(iOS 17, *) {
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
                self.updateBorder()
            }
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) не используется")
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 17, *) { return }
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateBorder()
        }
    }

    private func updateBorder() {
        layer.borderColor = UIColor.separator.resolvedColor(with: traitCollection).cgColor
    }
}
```

**35.2.**

```swift
extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}

let priceTagBackground = UIColor { traits in
    if traits.accessibilityContrast == .high {
        return .systemBackground
    }
    return traits.userInterfaceStyle == .dark
        ? UIColor(hex: 0x3A2A14)
        : UIColor(hex: 0xFFF4E5)
}
```

`hex >> 16 & 0xFF` вынимает из числа `0xFFF4E5` первые две
шестнадцатеричные цифры — красный канал `FF` = 255; `>> 8` — зелёный
`F4` = 244; последние две — синий `E5` = 229. Делим на 255, потому что
`UIColor` ждёт доли от 0 до 1. Проверку контраста ставим первой: она
важнее темы.

## Что мы выучили

- **Trait collection** — характеристики окружения (тема, контраст,
  размер шрифта, size class), передаются от окна вниз по иерархии.
- **Семантические цвета** (`.label`, `.systemBackground`) — для фонов
  и текста; `.white`/`.black` — только где цвет не должен меняться.
  В тёмной теме модальные листы «приподняты» и светлее.
- **`tintColor`** наследуется по иерархии; системные цвета меняются от
  версии iOS.
- **`UIColor(dynamicProvider:)`** — свой адаптивный цвет, быстрое
  замыкание.
- **Asset Catalog** — Any / Dark / High Contrast; `UIColor(named:)`
  опционален; смена цвета требует новой сборки.
- **`overrideUserInterfaceStyle`** — у контроллера и его children, у
  окна — для всего; модальные экраны берут тему окна.
- **`CGColor` в слоях не адаптивный** — обновлять через
  `registerForTraitChanges` (iOS 17+) или `traitCollectionDidChange`.
- **Выбор темы** — `enum` с `.unspecified`, `UserDefaults`, применение
  в `SceneDelegate` и плавная смена через `UIView.transition`.
- **Контраст** — AA 4.5:1 / 3:1; системные цвета проходят не все.

## Apple Developer Documentation

- [UITraitCollection](https://developer.apple.com/documentation/uikit/uitraitcollection) — характеристики окружения view.
- [UITraitCollection.userInterfaceStyle](https://developer.apple.com/documentation/uikit/uitraitcollection/userinterfacestyle) — текущая тема.
- [UIUserInterfaceStyle](https://developer.apple.com/documentation/uikit/uiuserinterfacestyle) — `.unspecified` / `.light` / `.dark`.
- [UIViewController.overrideUserInterfaceStyle](https://developer.apple.com/documentation/uikit/uiviewcontroller/overrideuserinterfacestyle) — тема контроллера, его иерархии и дочерних контроллеров.
- [UIColor.init(dynamicProvider:)](https://developer.apple.com/documentation/uikit/uicolor/init(dynamicprovider:)) — адаптивный цвет через замыкание, iOS 13+.
- [UIColor.resolvedColor(with:)](https://developer.apple.com/documentation/uikit/uicolor/resolvedcolor(with:)) — конкретный цвет для trait collection.
- [UITraitChangeObservable.registerForTraitChanges](https://developer.apple.com/documentation/uikit/uitraitchangeobservable-67e94) — подписка на изменение характеристик, iOS 17+.
- [UITraitEnvironment.traitCollectionDidChange(_:)](https://developer.apple.com/documentation/uikit/uitraitenvironment/traitcollectiondidchange(_:)) — старый способ, устарел в iOS 17.
- [UITraitCollection.hasDifferentColorAppearance(comparedTo:)](https://developer.apple.com/documentation/uikit/uitraitcollection/hasdifferentcolorappearance(comparedto:)) — изменилось ли то, что влияет на цвета.
- [UI element colors](https://developer.apple.com/documentation/uikit/ui-element-colors) — семантические цвета (`.label`, `.systemBackground`, заливки, разделители).
- [HIG — Dark Mode](https://developer.apple.com/design/human-interface-guidelines/dark-mode) — гайдлайн Apple по тёмной теме.
- [HIG — Color](https://developer.apple.com/design/human-interface-guidelines/color) — системные и семантические цвета.

→ [Глава 36. Cookbook — индикаторы статуса](./53-cookbook-status-indicators.md)
