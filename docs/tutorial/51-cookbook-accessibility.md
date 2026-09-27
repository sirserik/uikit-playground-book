# Глава 34. Cookbook — accessibility

**Accessibility** (доступность) — это возможность пользоваться
приложением людям с особенностями зрения, слуха, моторики: незрячему —
через экранный диктор, слабовидящему — с крупным шрифтом, человеку с
тремором — с крупными кнопками. iOS даёт для этого десятки встроенных
инструментов, и почти все они работают со стандартными компонентами
UIKit «бесплатно». Ломаются они там, где ты рисуешь что-то своё:
иконка без текста, карточка из трёх подписей, свой ползунок.

Обязательна ли доступность? В правилах App Review отдельного пункта
«приложение обязано поддерживать VoiceOver» нет. Но с 2025 года в App
Store Connect можно заполнить **Accessibility Nutrition Labels** —
метки на странице приложения «поддерживает VoiceOver, крупный текст,
…», и пользователи их видят. А в ряде стран доступность цифровых
сервисов требует закон (например, European Accessibility Act в ЕС
действует с июня 2025 года для многих видов услуг). И главное — это
твои живые пользователи.

Ключевые термины главы:

- **VoiceOver** — экранный диктор iOS. Пользователь водит пальцем по
  экрану или смахивает влево-вправо, VoiceOver переходит от элемента
  к элементу и произносит, что это. Двойное касание — «нажать».
- **Accessibility element** (элемент доступности) — то, на чём
  VoiceOver может остановиться. У каждого есть **label** (имя),
  **traits** (что это за штука: кнопка, заголовок, картинка),
  **value** (текущее значение) и **hint** (подсказка).
- **Dynamic Type** — системный размер шрифта, который пользователь
  выбирает в Настройках. Приложение должно под него подстраиваться.

## 34.1 VoiceOver — accessibilityLabel и hint

**Когда применять.** У каждого интерактивного элемента должно быть
понятное имя.

```swift
button.accessibilityLabel = "Удалить заметку"
button.accessibilityHint = "Удаляет заметку без возможности восстановления"
```

`accessibilityLabel` — **что это**, коротко. VoiceOver прочитает
«Удалить заметку, кнопка»: слово «кнопка» он добавит сам по трейту,
поэтому в label его не пиши («Кнопка удалить» прозвучит как «Кнопка
удалить, кнопка»). У кнопки с текстом label берётся из заголовка
автоматически.

`accessibilityHint` — **что произойдёт**, если нажать. Необязательна,
VoiceOver читает её после паузы, и многие пользователи подсказки
отключают. Apple в документации к `accessibilityHint` советует
описывать результат глаголом без подлежащего («Удаляет заметку»,
«Воспроизводит песню») и не описывать жест («Дважды коснитесь, чтобы
…»): жест пользователь VoiceOver знает лучше тебя, а на Apple Watch или
с клавиатурой он другой.

**Иконки без текста** — главный источник проблем:

```swift
let deleteButton = UIButton(type: .system)
deleteButton.setImage(UIImage(systemName: "trash"), for: .normal)
deleteButton.accessibilityLabel = "Удалить"
```

Без явного label VoiceOver в лучшем случае назовёт кнопку по имени
картинки — это английское «техническое» название вроде «trash» или
имя файла из твоих ресурсов, в худшем — скажет просто «кнопка».
Задавай label явно на языке интерфейса.

## 34.2 Скрыть от VoiceOver

```swift
decorativeView.isAccessibilityElement = false
decorativeView.accessibilityElementsHidden = true
```

Два свойства делают разное:

- `isAccessibilityElement = false` — **сам** view не элемент, но его
  дочерние view VoiceOver по-прежнему найдёт. У простого `UIView` и
  `UIImageView` это и так значение по умолчанию.
- `accessibilityElementsHidden = true` — спрятать view **вместе со
  всем содержимым**. Нужно, когда декоративный блок состоит из
  подписей и картинок, и ни одна из них не должна звучать (например,
  фоновая иллюстрация с надписью «Добро пожаловать» поверх
  настоящего заголовка).

Скрывай декор (фоновые картинки, разделители, иконку рядом с текстом,
который и так всё говорит), но никогда — то, что несёт смысл.

## 34.3 Группировка элементов

```swift
card.isAccessibilityElement = true
card.accessibilityLabel = "iPhone 17 Pro, 649 990 тенге"
card.accessibilityTraits = [.button]
```

Карточка товара из двух подписей «iPhone 17 Pro» и «649 990 ₸» без
группировки — это два отдельных элемента: пользователь смахивает,
слышит название, смахивает ещё раз, слышит цену. В длинном списке это
вдвое больше жестов. Когда сама карточка стала элементом
(`isAccessibilityElement = true`), её дочерние подписи VoiceOver больше
не видит — слышно одно объявление: «iPhone 17 Pro, 649 990 тенге,
кнопка».

Обрати внимание на «тенге» словом: значок «₸» VoiceOver может прочитать
не так, как ожидаешь. Для денег надёжнее собрать label из текста.
Трейт `.button` — потому что по карточке можно нажать и перейти к
товару.

## 34.4 Dynamic Type

**Когда применять.** Всегда, для всего текста интерфейса.

```swift
label.font = UIFont.preferredFont(forTextStyle: .body)
label.adjustsFontForContentSizeCategory = true
```

`preferredFont(forTextStyle:)` — системный шрифт для **стиля текста**
(«основной текст», «заголовок», «подпись»), размер которого зависит от
выбора пользователя: Настройки → Экран и яркость → Размер текста, а
самые крупные размеры — в Универсальном доступе → Дисплей и размер
текста → Увеличенный текст.

`adjustsFontForContentSizeCategory = true` — пересчитывать шрифт, когда
пользователь меняет размер, прямо на лету. Без этого новый размер
применится только к экранам, созданным после смены.

Насколько крупно бывает — замер на симуляторе, размер стиля `.body` в
точках:

| Настройка | `.body` | `.largeTitle` | `.caption1` |
|---|---|---|---|
| Самый мелкий (XS) | 14 | 31 | 11 |
| По умолчанию (L) | 17 | 34 | 12 |
| Самый крупный обычный (XXXL) | 23 | 40 | 18 |
| Самый крупный «универсальный доступ» (AX5) | 53 | 60 | 43 |

При максимальной настройке основной текст в **три с лишним раза**
крупнее обычного (53 против 17). Строка, которая помещалась в одну
линию, займёт три-четыре. Поэтому Dynamic Type — это не только шрифт,
но и вёрстка: `numberOfLines = 0`, вертикальные стеки вместо
горизонтальных на больших размерах (проверка —
`traitCollection.preferredContentSizeCategory.isAccessibilityCategory`),
ячейки с автоматической высотой (34.12).

Стили:

- `.largeTitle` — крупный заголовок экрана;
- `.title1` / `.title2` / `.title3` — заголовки разделов;
- `.headline` — выделенная строка; `.body` — основной текст;
  `.callout`, `.subheadline` — второстепенный;
- `.footnote`, `.caption1`, `.caption2` — мелкие подписи.

Свой шрифт:

```swift
let base = UIFont(name: "Avenir-Book", size: 16) ?? .systemFont(ofSize: 16)
label.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: base)
label.adjustsFontForContentSizeCategory = true
```

**`UIFontMetrics`** масштабирует твой шрифт так же, как система
масштабирует стиль `.body`: 16 точек при настройке по умолчанию, 21 при
XXXL, 45 при AX5 (замер на симуляторе). `?? .systemFont` вместо `!` —
если шрифта с таким именем нет (опечатка, шрифт не добавлен в
проект), приложение не упадёт.

## 34.5 Reduce Motion — «Уменьшение движения»

Людей с вестибулярными нарушениями от резких движений на экране
укачивает: параллакс, пружины, масштабирование на весь экран вызывают
головокружение. В Настройках → Универсальный доступ → Движение есть
переключатель «Уменьшение движения».

```swift
if UIAccessibility.isReduceMotionEnabled {
    // Спокойный вариант — только прозрачность
    UIView.animate(withDuration: 0.2) { view.alpha = 1 }
} else {
    // Полный вариант — пружина со сдвигом
    UIView.animate(withDuration: 0.5, delay: 0,
                   usingSpringWithDamping: 0.6,
                   initialSpringVelocity: 0.3) {
        view.transform = .identity
    }
}
```

Правило: движение заменяем на **растворение** (изменение прозрачности),
а не выключаем анимацию совсем — иначе пропадает сама подсказка «что-то
изменилось». Декоративные эффекты (лесенка ячеек из главы 32.4,
конфетти) при включённой настройке лучше не показывать вовсе.

Чтобы среагировать на переключение, не перезапуская экран, подпишись
на `UIAccessibility.reduceMotionStatusDidChangeNotification`.

## 34.6 Зона нажатия — минимум 44 × 44 точки

Apple Human Interface Guidelines: минимальный размер элемента, по
которому нажимают пальцем, — **44 × 44 точки** (около 7 мм на экране
iPhone). Меньше — промахи, особенно у людей с тремором и у всех
остальных на ходу.

```swift
button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
button.widthAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
```

`greaterThanOrEqualToConstant` — «не меньше 44», но может быть больше,
если содержимое крупнее (например, при большом Dynamic Type).

Маленькую иконку можно оставить маленькой визуально, увеличив отступы
внутри кнопки:

```swift
var cfg = UIButton.Configuration.plain()
cfg.image = UIImage(systemName: "xmark")
cfg.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
let button = UIButton(configuration: cfg)
```

Арифметика на глаз: иконка «xmark» около 17 × 15 точек, плюс отступ
12 с каждой стороны — примерно 41 × 39, меньше нормы. Замер на
симуляторе дал другое: `button.intrinsicContentSize` — 46 × 44 точки,
потому что конфигурация кнопки добавляет к картинке ещё немного своего
поля. Вывод: не считай размер в уме, а смотри `intrinsicContentSize`
(или рамку элемента в Accessibility Inspector) и страхуй констрейнтами
«не меньше 44» из примера выше.

## 34.7 Контраст и Increase Contrast

**Контраст** — насколько текст отличается по яркости от фона.
Стандарт WCAG (международные правила доступности веб-контента, на них
ссылается и Apple) требует для обычного текста **4.5:1**, для крупного
(от 18 точек, или от 14 жирным) и для значков — **3:1**. В HIG та же
норма сведена в таблицу попроще, по ней проверяет Accessibility
Inspector: текст до 17 pt — 4.5:1, от 18 pt — 3:1, жирный любого
размера — 3:1 (эта таблица — в чек-листе главы 43). Мелкий жирный текст
надёжнее всё же держать на 4.5:1: так он проходит оба правила.

Что значит «4.5:1» словами. У каждого цвета считают «светлоту» — число
от 0 (чёрный) до 1 (белый). Зелёный канал вносит в неё больше всего
(около 72%), красный — около 21%, синий — всего 7%: глаз гораздо
чувствительнее к зелёному. Потом берут светлоту более светлого цвета
и более тёмного, к обеим прибавляют 0,05 и делят одно на другое.
Чёрный на белом: (1 + 0,05) / (0 + 0,05) = 21, максимум. Одинаковые
цвета: 1:1, текста не видно. Порог 4.5:1 — это, например, серый
`#767676` на белом (4,54:1): чуть светлее — и уже не проходит.

Системные цвета — не гарантия. Замер на симуляторе iOS 26.5, цвет
текста на `systemBackground`:

| Цвет | Светлая тема | Тёмная тема | Светлая + Increase Contrast |
|---|---|---|---|
| `.label` | 21:1 | 21:1 | 21:1 |
| `.secondaryLabel` | **3,4:1** | 6,4:1 | 6,0:1 |
| `.tertiaryLabel` | **1,7:1** | **2,2:1** | 4,5:1 |
| `.systemBlue` | **3,5:1** | 6,5:1 | 4,6:1 |
| `.systemGreen` | **2,2:1** | 10,4:1 | 4,5:1 |

Выводы. `.secondaryLabel` в светлой теме — 3,4:1: для мелких подписей
это ниже нормы 4.5:1, для крупного текста — проходит. `.tertiaryLabel`
годится только для совсем второстепенного (плейсхолдеры, неактивное).
Зелёный текст на белом (2,2:1) читается плохо — зелёный хорош для
значков и заливок, но не для текста. При этом в режиме **Increase
Contrast** («Увеличение контраста», Настройки → Универсальный доступ →
Дисплей и размер текста) система сама темнеет цвета, и почти все
доходят до 4.5:1. Своим цветам ты должен дать такую же возможность.

Как узнать, что режим включён:

```swift
if traitCollection.accessibilityContrast == .high {
    label.textColor = .label
} else {
    label.textColor = .secondaryLabel
}
```

`accessibilityContrast` — свойство **trait collection** (набора
характеристик окружения: тема, размер шрифта, контраст; подробно — в
главе 35). Есть и глобальный флаг `UIAccessibility.isDarkerSystemColorsEnabled`
с уведомлением `darkerSystemColorsStatusDidChangeNotification`.

Проще всего — не писать условия руками. Для своих цветов в Asset
Catalog у набора цветов включи **High Contrast**: рядом с вариантами
«Any» и «Dark» появятся высококонтрастные, и iOS подставит их сама.

## 34.8 Accessibility traits

```swift
button.accessibilityTraits = [.button]
imageView.accessibilityTraits = [.image]
headerLabel.accessibilityTraits = [.header]
customSlider.accessibilityTraits = [.adjustable]  // VoiceOver: смахивание вверх/вниз меняет значение

// Несколько сразу
tabButton.accessibilityTraits = [.button, .selected]  // выбранная вкладка
```

**Трейт** — «что это за элемент и в каком он состоянии». VoiceOver
читает трейт после label: «Настройки, кнопка», «Профиль, заголовок»,
«Громкость, регулируемый элемент».

- `.header` — заголовок раздела. Незрячие пользователи часто
  перемещаются **по заголовкам** (через ротор — «колёсико» VoiceOver,
  которое переключает режим навигации поворотом двух пальцев), поэтому
  заголовки экранов и секций помечай обязательно.
- `.adjustable` — элемент со значением, которое меняют смахиванием
  вверх/вниз. Для своего контрола тогда нужно переопределить
  `accessibilityIncrement()` и `accessibilityDecrement()`.
- `.selected` — выбранное состояние (вкладка, сегмент, отмеченная
  строка).

Стандартные `UIButton`, `UISlider`, `UISwitch` проставляют трейты
сами. Свой view, собранный из `UIView` с жестом нажатия, — нет: без
трейтов VoiceOver не поймёт, что по нему можно нажать.

## 34.9 accessibilityValue — текущее значение

```swift
ratingView.accessibilityValue = "4 из 5 звёзд"
// VoiceOver: "Оценка, 4 из 5 звёзд, регулируемый элемент"
```

Value — то, что **меняется**, в отличие от label, который постоянен:
label «Громкость», value «50 процентов». Стандартные `UISlider` и
`UIStepper` сообщают значение сами. Задавать value вручную нужно для
своих контролов: рейтинг звёздами, круговой прогресс, свой
переключатель.

## 34.10 Проверка через VoiceOver

**В симуляторе VoiceOver нет.** Сочетание Cmd+F5 на Mac включает
VoiceOver **самого Mac**, а не iOS внутри симулятора — это другой
диктор с другими жестами. В симуляторе проверяй разметку через
Accessibility Inspector (34.11).

На устройстве:

- Настройки → Универсальный доступ → VoiceOver → включить;
- удобнее — **быстрая команда**: Настройки → Универсальный доступ →
  Быстрая команда → VoiceOver. Тогда тройное нажатие боковой кнопки
  включает и выключает диктор.

Базовые жесты: смахивание вправо/влево одним пальцем — очередной /
предыдущий элемент, двойное касание — нажать, смахивание вверх/вниз —
изменить регулируемый элемент или выбрать действие (34.14).

Пройди с VoiceOver главный сценарий приложения — вход, основной экран,
покупку — перед каждым крупным релизом. Это 15 минут, которые находят
больше, чем любой автоматический аудит.

## 34.11 Accessibility Inspector (Xcode)

`Xcode → Open Developer Tool → Accessibility Inspector`. Инструмент
подключается к симулятору, и при наведении на элемент показывает его
label, value, traits и место в иерархии. Кнопка **Audit** прогоняет
экран через автоматические проверки: низкий контраст, маленькие зоны
нажатия, элементы без label, текст, который не масштабируется под
Dynamic Type.

С iOS 17 такой же аудит можно запускать в UI-тестах:
`try app.performAccessibilityAudit()` — тест упадёт, если на экране
появится элемент без имени.

## 34.12 Dynamic Type в ячейках таблицы

```swift
tableView.rowHeight = UITableView.automaticDimension
tableView.estimatedRowHeight = 44

// В ячейке
label.numberOfLines = 0
label.font = UIFont.preferredFont(forTextStyle: .body)
label.adjustsFontForContentSizeCategory = true
```

`automaticDimension` — высота ячейки считается из её констрейнтов,
`estimatedRowHeight` — примерная высота для расчёта полосы прокрутки
до того, как ячейку разложат. `numberOfLines = 0` — сколько угодно
строк. Вместе с `preferredFont` получаем ячейку, которая при размере
AX5 вырастает в высоту, а не обрезает текст многоточием. Работает,
только если подпись привязана констрейнтами к верху **и** к низу
`contentView` — иначе таблице не из чего вычислить высоту.

## 34.13 Картинки

```swift
productImage.isAccessibilityElement = true
productImage.accessibilityLabel = "Красные кроссовки, вид сбоку"

// Декоративная картинка (фон) — ничего не нужно:
// у UIImageView isAccessibilityElement по умолчанию false
```

Содержательная картинка (фото товара, график, схема) должна быть
элементом с описанием **того, что на ней**, а не «картинка» или имя
файла. Декоративная — наоборот, остаётся невидимой для VoiceOver: у
`UIImageView` по умолчанию `isAccessibilityElement == false`.

## 34.14 Custom actions — свои действия

Смахивания в ячейках (swipe actions) и контекстные меню незрячему
пользователю неудобны или недоступны. Для них есть **custom actions**
— действия, которые VoiceOver предлагает прямо на элементе:

```swift
let noteID = note.id
cell.accessibilityCustomActions = [
    UIAccessibilityCustomAction(name: "Удалить") { [weak self] _ in
        self?.deleteNote(id: noteID)
        return true
    },
    UIAccessibilityCustomAction(name: "В архив") { [weak self] _ in
        self?.archiveNote(id: noteID)
        return true
    },
]
```

На такой ячейке VoiceOver скажет «Доступны действия». Смахивание
вверх/вниз перебирает их («Удалить», «В архив»), двойное касание
выполняет. Замыкание возвращает `true`, если действие удалось.

Две детали в коде:

- `[weak self]` — ячейку держит таблица, таблицу — контроллер; если
  действие будет держать контроллер сильно, получится цикл удержания.
- Захватываем **идентификатор заметки**, а не `indexPath`. Номер строки
  меняется после удаления соседних строк, а ячейку со старыми
  действиями могут не успеть перенастроить, — и «Удалить» удалит не ту
  заметку.

## 34.15 Бытовая аналогия

Accessibility — как **таблички в здании**. Зрячий человек найдёт
кабинет по номеру на двери. Незрячий — по табличке со шрифтом Брайля
(`accessibilityLabel`). Человек на коляске — по пандусу вместо
ступенек (крупные зоны нажатия). Пожилой — по крупным цифрам на
указателях (Dynamic Type).

Здание без табличек формально работает — стены, двери, всё на месте,
— но половина посетителей в нём заблудится. Табличку повесить
дёшево, если делать это сразу, и дорого, если потом обходить всё
здание заново.

## Упражнения

**Упражнение 34.1.** В ячейке заметки три подписи: заголовок «Купить
молоко», дата «12 мая» и значок-скрепка «есть вложение» (SF Symbol
`paperclip`). Сделай так, чтобы VoiceOver читал ячейку одним
объявлением. Что должно прозвучать?

**Упражнение 34.2.** Кнопка «Закрыть» — иконка `xmark` 16 точек без
текста. Перечисли, что с ней нужно сделать, чтобы она прошла
Accessibility Inspector Audit, и напиши код.

## Ответы к упражнениям

**34.1.**

```swift
func configureAccessibility(of cell: UITableViewCell,
                            title: String, dateText: String, hasAttachment: Bool) {
    cell.isAccessibilityElement = true
    var parts = [title, dateText]
    if hasAttachment { parts.append("есть вложение") }
    cell.accessibilityLabel = parts.joined(separator: ", ")
}
```

Прозвучит: «Купить молоко, 12 мая, есть вложение». Если по ячейке
можно нажать и открыть заметку, добавь `cell.accessibilityTraits
.insert(.button)` — тогда VoiceOver допишет «кнопка». Иконку скрепки
мы озвучили словами, а сама по себе она больше не звучит:
ячейка стала элементом, и её дочерние view VoiceOver не видит.

**34.2.** Нужно: понятное имя на языке интерфейса и зона нажатия не
меньше 44 × 44 точек.

```swift
func makeCloseButton() -> UIButton {
    var cfg = UIButton.Configuration.plain()
    cfg.image = UIImage(systemName: "xmark")
    cfg.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 12,
                                                bottom: 12, trailing: 12)
    let button = UIButton(configuration: cfg)
    button.accessibilityLabel = "Закрыть"
    button.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
    ])
    return button
}
```

С отступами 12 такая кнопка на симуляторе получилась 46 × 44 точки
(см. 34.6), а констрейнты «не меньше 44» страхуют, если иконку заменят
на меньшую или уберут отступы. Трейт `.button` у `UIButton` уже есть.

## Что мы выучили

- **Label** — «что это», без слова «кнопка»; у иконок — обязательно и
  по-русски. **Hint** — «что произойдёт», глаголом, без описания жеста.
- **`isAccessibilityElement = false`** скрывает сам view,
  **`accessibilityElementsHidden`** — view со всем содержимым.
- **Группировка**: карточка — один элемент с общим label.
- **Dynamic Type**: `preferredFont` + `adjustsFontForContentSizeCategory`;
  размер `.body` от 14 до 53 точек; свои шрифты — через `UIFontMetrics`.
- **Reduce Motion** — движение заменяем растворением.
- **Зона нажатия** не меньше 44 × 44 точек.
- **Контраст** 4.5:1 для текста, 3:1 для крупного и значков;
  `.secondaryLabel` в светлой теме — 3,4:1; High Contrast в Asset
  Catalog.
- **Traits**: `.header` для навигации по заголовкам, `.adjustable`,
  `.selected`.
- **Value** — меняющееся значение своих контролов.
- **VoiceOver** проверяется только на устройстве; в симуляторе —
  Accessibility Inspector и `performAccessibilityAudit()` (iOS 17).
- **Custom actions** — замена свайпам, захватывать ID, а не `indexPath`.

## Apple Developer Documentation

- [UIAccessibility](https://developer.apple.com/documentation/uikit/uiaccessibility) — глобальные настройки доступности и уведомления.
- [UIAccessibility.isVoiceOverRunning](https://developer.apple.com/documentation/uikit/uiaccessibility/isvoiceoverrunning) — VoiceOver включён.
- [UIAccessibility.isReduceMotionEnabled](https://developer.apple.com/documentation/uikit/uiaccessibility/isreducemotionenabled) — пользователь просит уменьшить движение.
- [UIAccessibility.isDarkerSystemColorsEnabled](https://developer.apple.com/documentation/uikit/uiaccessibility/isdarkersystemcolorsenabled) — включено Increase Contrast.
- [UITraitCollection.accessibilityContrast](https://developer.apple.com/documentation/uikit/uitraitcollection/accessibilitycontrast) — контраст как характеристика окружения.
- [accessibilityLabel](https://developer.apple.com/documentation/objectivec/nsobject-swift.class/accessibilitylabel) — короткое имя элемента для VoiceOver.
- [accessibilityHint](https://developer.apple.com/documentation/objectivec/nsobject-swift.class/accessibilityhint) — подсказка о результате действия.
- [accessibilityValue](https://developer.apple.com/documentation/objectivec/nsobject-swift.class/accessibilityvalue) — текущее значение элемента.
- [accessibilityTraits](https://developer.apple.com/documentation/objectivec/nsobject-swift.class/accessibilitytraits) — `.button`, `.header`, `.adjustable` и т. д.
- [UIAccessibilityCustomAction](https://developer.apple.com/documentation/uikit/uiaccessibilitycustomaction) — свои действия для VoiceOver.
- [UIContentSizeCategory](https://developer.apple.com/documentation/uikit/uicontentsizecategory) — текущий размер Dynamic Type.
- [UIFontMetrics](https://developer.apple.com/documentation/uikit/uifontmetrics) — масштабирование своих шрифтов под Dynamic Type.
- [UIFont.preferredFont(forTextStyle:)](https://developer.apple.com/documentation/uikit/uifont/preferredfont(fortextstyle:)) — системный шрифт под Dynamic Type.
- [XCUIApplication.performAccessibilityAudit](https://developer.apple.com/documentation/xcuiautomation/xcuiapplication/performaccessibilityaudit(for:_:)) — автоматический аудит в UI-тестах, iOS 17+.
- [HIG — Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility) — гайдлайн Apple по доступности.

→ [Глава 35. Cookbook — темы и цвета](./52-cookbook-theming.md)
