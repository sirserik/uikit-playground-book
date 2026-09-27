# Глава 32. Cookbook — анимации

`UIView.animate`, `CABasicAnimation`, `CAEmitterLayer` — и когда что
использовать. Все числа про кривые и пружины в этой главе не взяты из
головы: они сняты на симуляторе iOS 26.5 — квадрат двигали на 100
точек и 60 раз в секунду записывали, где он находится.

Сначала — что вообще происходит, когда iOS «анимирует».

**Анимация в UIKit** — это не покадровое рисование руками. Ты говоришь
«было `alpha = 0`, стало `alpha = 1`, за 0,3 секунды», а система сама
вычисляет все промежуточные значения. Это называется **интерполяцией**:
между двумя известными точками достраиваются промежуточные. Считает и
рисует их **Core Animation** — слой системы, который работает с
`CALayer`. У каждого `UIView` внутри есть свой слой (`view.layer`), и
именно слой отображается на экране.

Две вещи, которые важно держать в голове:

- **Модель и то, что видно.** Когда ты пишешь `view.alpha = 1` внутри
  `animate`, свойство меняется **сразу**. На экране же 0,3 секунды
  рисуется промежуточное значение из так называемого **presentation
  layer** — «слоя-отображения», копии слоя с текущими промежуточными
  значениями (`view.layer.presentation()`). Наши замеры читали именно
  его.
- **Анимация не блокирует код.** `UIView.animate` возвращается
  мгновенно, а строка после него выполняется, пока анимация ещё идёт.
  Чтобы сделать что-то **после**, есть `completion`.

## 32.1 UIView.animate — базовый

**Когда применять.** Появление, исчезновение, сдвиг, изменение цвета —
90% анимаций в обычном приложении.

```swift
UIView.animate(withDuration: 0.3) {
    view.alpha = 1.0
    view.transform = .identity
}
```

`withDuration: 0.3` — длительность в секундах, 0,3 с = 300 мс.
Ориентиры: 0,2–0,3 с — для мелких изменений (кнопка, подсказка),
0,35–0,5 с — для крупных (карточка въезжает, экран меняется). Дольше
полусекунды интерфейс начинает казаться медленным.

`transform = .identity` — «никаких преобразований», исходный размер и
положение. Обычно так заканчивают анимацию, которая началась из
сдвинутого или уменьшенного состояния.

Что можно анимировать через `UIView.animate`:

- `frame`, `bounds`, `center` — положение и размер;
- `transform` — сдвиг, масштаб, поворот;
- `alpha` — прозрачность;
- `backgroundColor`;
- `constant` у констрейнта — через `layoutIfNeeded()` (раздел 32.8).

Чего нельзя: `cornerRadius`, `shadowOpacity`, `borderColor` и другие
свойства слоя — для них `CABasicAnimation` (раздел 32.6). `isHidden`
тоже не анимируется — прячут через `alpha`.

С действием в конце:

```swift
UIView.animate(withDuration: 0.3, animations: {
    view.alpha = 0
}) { _ in
    view.removeFromSuperview()
}
```

Параметр замыкания `completion` — `Bool`: `true`, если анимация дошла
до конца, `false`, если её прервали (например, запустили новую
анимацию того же свойства).

### Кривые: разгон и торможение

По умолчанию `UIView.animate` использует кривую **ease-in-out** —
«плавный разгон и плавное торможение». Кривая отвечает на вопрос:
какая доля пути пройдена к такой-то доле времени. Замер на симуляторе,
квадрат едет 100 точек за 1 секунду:

| Кривая (`options`) | через 0,25 с | через 0,5 с | через 0,75 с |
|---|---|---|---|
| `.curveEaseInOut` (по умолчанию) | ~12 точек | ~49 | ~86 |
| `.curveEaseIn` — только разгон | ~8 | ~30 | ~60 |
| `.curveEaseOut` — только торможение | ~35 | ~66 | ~89 |
| `.curveLinear` — ровно | ~23 | ~48 | ~73 |

(У линейной кривой вместо 25/50/75 получилось чуть меньше: замер
отстаёт от анимации примерно на кадр.)

Читается так. `.curveEaseInOut` первую четверть времени едет медленно
(12% пути), в середине разгоняется и последнюю четверть снова
тормозит. `.curveEaseOut` стартует быстро — треть пути уже за первую
четверть времени — и мягко останавливается: так ведут себя
появляющиеся элементы, они «влетают и садятся». `.curveEaseIn`
наоборот, разгоняется к концу: подходит для уходящих элементов,
которые «улетают» с экрана. Линейную кривую в интерфейсе почти не
используют — движение выглядит механическим; она нужна для
бесконечного вращения спиннера.

```swift
UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseOut]) {
    card.transform = .identity
}
```

## 32.2 Spring — пружина

**Когда применять.** Когда элемент должен «приехать» живо: карточка
возвращается на место, кнопка «отпрыгивает» после нажатия.

```swift
UIView.animate(
    withDuration: 0.5,
    delay: 0,
    usingSpringWithDamping: 0.6,
    initialSpringVelocity: 0.3,
    options: []
) {
    view.transform = .identity
}
```

Кривую в `options` здесь не указываем: форму движения задаёт пружина.

**`usingSpringWithDamping`** — затухание, число от 0 до 1. Проще всего
понять через «перелёт»: насколько элемент проскочит цель, прежде чем
вернуться. Замер на симуляторе, квадрат едет на 100 точек вниз:

| damping | Перелёт | Как ощущается |
|---|---|---|
| 0.5 | ~16 точек (16% пути) | заметно «прыгает» |
| 0.6 | ~9 точек | живо, с отскоком |
| 0.7 | ~5 точек | чуть перелетит и вернётся |
| 0.85 | меньше 1 точки | почти без отскока, но «мягкий» финиш |
| 1.0 | 0 | без пружины, плавная остановка |

Чем меньше damping, тем больше колебаний. Для интерфейса обычно берут
0.7–0.85: движение живое, но не игрушечное. 0.5 и ниже — для игровых и
праздничных эффектов.

**`initialSpringVelocity`** — начальная скорость, но в необычных
единицах: это доля всего пути **в секунду**. Если элемент должен
проехать 200 точек, то `initialSpringVelocity: 1` значит «стартовать
со скоростью 200 точек в секунду», а `0.3` — 60 точек в секунду. Ноль
— старт с места. Зачем это нужно: если пользователь «бросил» карточку
пальцем со скоростью 800 точек в секунду, а до места осталось 200
точек, передай `800 / 200 = 4` — и анимация продолжит движение пальца
без рывка.

С iOS 17 есть запись попроще — длительность и «прыгучесть» (0 — без
отскока, 0.3 — заметный):

```swift
if #available(iOS 17, *) {
    UIView.animate(springDuration: 0.5, bounce: 0.3) {
        view.transform = .identity
    }
}
```

У нас минимум iOS 15, поэтому без `#available` такой код не соберётся.

## 32.3 Последовательность

**Когда применять.** Несколько элементов появляются по очереди —
«лесенкой».

```swift
private func animateSequence() {
    for (i, dot) in [dot1, dot2, dot3].enumerated() {
        dot.alpha = 0
        dot.transform = CGAffineTransform(translationX: 0, y: 20)
        UIView.animate(withDuration: 0.4, delay: 0.15 * Double(i),
                       usingSpringWithDamping: 0.7, initialSpringVelocity: 0) {
            dot.alpha = 1
            dot.transform = .identity
        }
    }
}
```

Разбор:

- Сначала ставим начальное состояние без анимации: невидимо и на 20
  точек ниже (`translationX: 0, y: 20` — сдвиг по вертикали вниз, ось
  y в iOS смотрит вниз).
- `delay: 0.15 * Double(i)` — задержки 0, 0,15 и 0,3 секунды. Каждая
  анимация длится 0,4 с, значит последняя закончится через 0,3 + 0,4 =
  0,7 секунды после старта.
- В анимации возвращаем `alpha = 1` и `.identity` — точки «всплывают»
  на место с лёгким отскоком (damping 0.7 — перелёт около 5%).

Альтернатива — ключевые кадры:

```swift
UIView.animateKeyframes(withDuration: 1.0, delay: 0, options: []) {
    UIView.addKeyframe(withRelativeStartTime: 0.0, relativeDuration: 0.3) {
        dot1.alpha = 1
    }
    UIView.addKeyframe(withRelativeStartTime: 0.3, relativeDuration: 0.3) {
        dot2.alpha = 1
    }
    UIView.addKeyframe(withRelativeStartTime: 0.6, relativeDuration: 0.3) {
        dot3.alpha = 1
    }
}
```

**Ключевой кадр** — отрезок общей анимации. Время задаётся долями от
общей длительности: при `withDuration: 1.0` кадр с `relativeStartTime:
0.3` и `relativeDuration: 0.3` идёт с 0,3 по 0,6 секунды. Удобство в
том, что всё остаётся одной анимацией: поменяешь 1.0 на 2.0 — все
кадры растянутся пропорционально, а один `completion` сработает в конце.

## 32.4 Появление ячеек

**Когда применять.** Первый показ списка — строки «въезжают» снизу
одна за другой.

```swift
private var animatedFirstScreen = false

func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell,
               forRowAt indexPath: IndexPath) {
    guard !animatedFirstScreen else { return }
    let visibleCount = tableView.indexPathsForVisibleRows?.count ?? 0
    if indexPath.row >= visibleCount { animatedFirstScreen = true; return }

    cell.alpha = 0
    cell.transform = CGAffineTransform(translationX: 0, y: 20)
    UIView.animate(withDuration: 0.4, delay: 0.05 * Double(indexPath.row),
                   usingSpringWithDamping: 0.85, initialSpringVelocity: 0) {
        cell.alpha = 1
        cell.transform = .identity
    }
}
```

`willDisplay` — метод делегата таблицы, который вызывается прямо
перед тем, как ячейка появится на экране. Это последний момент
поменять её вид.

Почему нужен флаг. Без него задержка считается от номера строки:
`0.05 × row`. На первом экране это приятно (строки 0…10 — задержки от 0 до 0,5 с). Но при прокрутке
до строки 200 задержка становится 0.05 × 200 = 10 секунд: ячейка
выезжает на экран пустой и появляется через 10 секунд. Поэтому
анимируем только первый экран — пока номер строки меньше количества
видимых строк — а потом флаг выключает эффект навсегда.

Про **переиспользование ячеек**: таблица не создаёт новую ячейку для
каждой строки, а берёт ушедшую за край экрана и наполняет новыми
данными. Если анимацию прервали на полпути, в переиспользованной
ячейке мог остаться `alpha = 0.4`. Здесь это не случится — анимация
всегда доводит до `1` и `.identity`, — но если меняешь вид ячейки в
`willDisplay`, всегда ставь **конечное** состояние явно.

И учти настройку «Уменьшение движения» (Reduce Motion, см. главу 34.5):
такие декоративные эффекты при ней лучше выключать совсем.

## 32.5 Анимации SF Symbols (iOS 17+)

**SF Symbols** — системная библиотека иконок Apple
(`UIImage(systemName:)`). С iOS 17 эти иконки умеют анимироваться
сами:

```swift
imageView.image = UIImage(systemName: "heart.fill")
if #available(iOS 17, *) {
    imageView.addSymbolEffect(.bounce, options: .speed(1.5))   // подпрыгнуть
    imageView.addSymbolEffect(.pulse)                          // пульсировать
    imageView.addSymbolEffect(.scale.up, options: .repeating)  // увеличиться и держать
}
```

- `.bounce` — один «подскок», `.speed(1.5)` — в полтора раза быстрее
  обычного.
- `.pulse` — прозрачность плавно «дышит», пока эффект не снимут.
- `.scale.up` — иконка увеличивается и остаётся увеличенной до снятия
  эффекта.

Снять всё — `imageView.removeAllSymbolEffects()`. На iOS 15–16 этих
методов нет, поэтому код обязательно в `#available(iOS 17, *)`; на
старых системах иконка просто останется статичной.

## 32.6 CABasicAnimation — анимация слоя

**Когда применять.** Бесконечные анимации и свойства `CALayer`,
которые `UIView.animate` не умеет.

```swift
let pulse = CABasicAnimation(keyPath: "transform.scale")
pulse.fromValue = 1.0
pulse.toValue = 1.4
pulse.duration = 0.8
pulse.autoreverses = true
pulse.repeatCount = .infinity
view.layer.add(pulse, forKey: "pulse")
```

Разбор:

- `keyPath: "transform.scale"` — какое свойство слоя анимировать,
  записанное строкой. Опечатка в строке компилятором не ловится:
  анимация просто ничего не сделает.
- `fromValue: 1.0` → `toValue: 1.4` — масштаб от исходного до «на 40%
  больше». Круг диаметром 60 точек вырастет до 84.
- `duration: 0.8` + `autoreverses = true` — 0,8 с растёт и ещё 0,8 с
  возвращается, полный «вдох-выдох» — 1,6 с.
- `repeatCount = .infinity` — без конца.
- `forKey: "pulse"` — имя, по которому анимацию потом снимают.

Чем это отличается от `UIView.animate`: `CABasicAnimation` **не
меняет модель**. Свойство слоя остаётся 1.0, анимация лишь рисует
промежуточные значения поверх. Когда анимация закончится или её
снимут, слой вернётся к модельному значению. Поэтому для «один раз
увеличить и оставить» сначала присваивают новое значение слою, а
потом добавляют анимацию от старого к новому.

Когда `CABasicAnimation`, а не `UIView.animate`:

- **Бесконечная анимация** (пульс, мерцание скелетона) —
  `repeatCount = .infinity`.
- **Свойства слоя**: `cornerRadius`, `shadowOpacity`, `strokeEnd` у
  `CAShapeLayer`, цвета градиента в `CAGradientLayer`.
- **Плавная смена картинки** — `keyPath: "contents"`.

Снять: `view.layer.removeAnimation(forKey: "pulse")`.

Бесконечную анимацию Core Animation может снять сама — например,
когда view убирают из окна. Надёжный приём — запускать её в
`didMoveToWindow()` (метод `UIView`, вызывается при появлении в окне)
и при возвращении приложения из фона, а не один раз в `init`.

## 32.7 CAKeyframeAnimation — несколько точек

**Когда применять.** Движение по нескольким значениям подряд: тряска
поля с ошибкой, «покачивание» иконки.

```swift
let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
animation.values = [-12, 12, -10, 10, -6, 6, 0]
animation.duration = 0.4
view.layer.add(animation, forKey: "shake")
```

Эффект «неверный пароль»: поле качается влево-вправо и успокаивается.
Числа в `values` — сдвиг по горизонтали в точках: 12 влево, 12 вправо,
10 влево… Размах уменьшается 12 → 10 → 6 → 0 — так выглядит
затухающее колебание, как у задетой струны. Последнее значение 0 —
возврат на место (иначе после анимации поле «прыгнет» обратно).

Семь значений — это шесть промежутков. За 0,4 с каждый длится 0,4 / 6
≈ 0,067 с: быстрая, но различимая тряска. Хочешь медленнее — увеличь
`duration`, промежутки растянутся одинаково.

## 32.8 Анимация констрейнта

**Констрейнт** (constraint) — правило Auto Layout вроде «высота = 120»
или «отступ слева = 16». Анимировать его напрямую нельзя: меняется
число, а кадры view пересчитываются при ближайшей раскладке.

```swift
heightConstraint.constant = 200
UIView.animate(withDuration: 0.3) {
    self.view.layoutIfNeeded()
}
```

Меняем `constant` снаружи, а внутри анимации вызываем
`layoutIfNeeded()` — «разложи view прямо сейчас». Раскладка случится
внутри анимационного блока, поэтому все новые `frame` поедут плавно:
высота со 120 до 200 точек за 0,3 с.

Вызывать `layoutIfNeeded()` нужно у **общего предка** — обычно
`self.view` контроллера. Если вызвать у самого изменившегося view,
соседи, которые от него зависят, переедут рывком.

## 32.9 Смена одного view на другой

```swift
UIView.transition(from: oldView, to: newView,
                  duration: 0.3,
                  options: [.transitionCrossDissolve]) { _ in
    // oldView уже удалён из иерархии
}
```

**Cross-dissolve** — «наплыв»: старое изображение растворяется,
новое проявляется. Этот вариант метода сам удаляет `oldView` из
родителя и добавляет `newView` на его место — не забудь, что у
`newView` должны быть свои констрейнты или `frame`.

Второй вариант — анимировать всё содержимое контейнера:

```swift
UIView.transition(with: container, duration: 0.3,
                  options: .transitionCrossDissolve,
                  animations: {
    container.subviews.first?.removeFromSuperview()
    container.addSubview(newView)
})
```

Система снимает «снимок» контейнера до и после блока `animations` и
плавно переводит один в другой. Так же `BootCoordinator.setRoot`
меняет корневой экран окна (см. главу 4.5).

## 32.10 Конфетти через CAEmitterLayer

**Когда применять.** Праздник: выполнил все задачи, прошёл уровень,
оформил первый заказ.

```swift
private func launchConfetti() {
    let emitter = CAEmitterLayer()
    emitter.emitterPosition = CGPoint(x: view.bounds.midX, y: -20)
    emitter.emitterShape = .line
    emitter.emitterSize = CGSize(width: view.bounds.width, height: 1)
    let colors: [UIColor] = [.systemRed, .systemOrange, .systemYellow,
                             .systemGreen, .systemBlue, .systemPurple]
    emitter.emitterCells = colors.map { color in
        let image = makeConfettiImage(color: color)
        let cell = CAEmitterCell()
        cell.birthRate = 6
        cell.lifetime = 6
        cell.velocity = 180
        cell.velocityRange = 40
        cell.emissionLongitude = .pi   // вниз
        cell.emissionRange = 0.4
        cell.spin = 2
        cell.spinRange = 3
        cell.contents = image.cgImage
        cell.contentsScale = image.scale
        return cell
    }
    view.layer.addSublayer(emitter)
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
        emitter.birthRate = 0   // новых частиц больше не рождать
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
            emitter.removeFromSuperlayer()
        }
    }
}

private func makeConfettiImage(color: UIColor) -> UIImage {
    let size = CGSize(width: 14, height: 6)
    return UIGraphicsImageRenderer(size: size).image { _ in
        color.setFill()
        UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 1.5).fill()
    }
}
```

**Система частиц** — генератор множества мелких картинок, у каждой
своя скорость, вращение и время жизни. `CAEmitterLayer` —
«пушка», `CAEmitterCell` — описание одного вида частиц. Параметры
словами:

- `emitterPosition` y = −20, форма `.line` шириной в экран —
  частицы рождаются на линии чуть выше верхнего края.
- `birthRate = 6` — шесть частиц в секунду **каждого** цвета; цветов
  шесть, итого около 36 в секунду.
- `lifetime = 6` — каждая живёт 6 секунд.
- `velocity = 180`, `velocityRange = 40` — скорость 180 ± 40 точек в
  секунду, то есть от 140 до 220: за 6 секунд частица пролетает
  примерно 850–1300 точек, больше высоты экрана.
- `emissionLongitude = .pi` — направление вылета. Угол в радианах
  (π радиан = 180°, подробнее в 32.12); на симуляторе с этим значением
  частицы летят вниз. `emissionRange = 0.4` — разброс ±0,4 радиана,
  примерно ±23°: конфетти летит веером, а не строем.
- `spin = 2`, `spinRange = 3` — вращение 2 ± 3 радиана в секунду:
  кто-то крутится быстро, кто-то медленно и в другую сторону.

**Частая ошибка** — `cell.scale = 0.1` без `contentsScale`. Скриншот с
симулятора показывает крошечные
цветные точки вместо конфетти: картинка 14 × 6 точек, уменьшенная до
10%, — это 1,4 × 0,6 точки. `contentsScale = image.scale` говорит
слою, что в картинке 3 пикселя на точку (экран @3x), и частица
рисуется ровно 14 × 6 точек. Без неё, наоборот, частица получается в
три раза крупнее — 42 × 18 точек.

`emitter.birthRate = 0` через секунду — «перестань рождать новые»:
уже летящие частицы долетают. Их `lifetime` 6 секунд, поэтому слой
удаляем ещё через 6 секунд, а не раньше — иначе конфетти исчезнет
посреди экрана.

## 32.11 Hero-анимация (перелёт элемента между экранами)

**Hero-анимация** — элемент «перелетает» с одного экрана на другой:
миниатюра в списке вырастает в полноэкранное фото. Классический путь
— собственный переход через `UIViewControllerAnimatedTransitioning`
(протокол «аниматора перехода»; подробно в главе 26.7):

```swift
func animateTransition(using ctx: UIViewControllerContextTransitioning) {
    let container = ctx.containerView
    // 1. Найти исходный view и конечный view
    // 2. Снять snapshot (снимок) исходного
    // 3. Анимировать снимок между двумя позициями
    // 4. Скрыть оригиналы во время анимации
    // 5. Показать конечный экран, удалить снимок
}
```

Это каркас, полная рабочая версия для фото — в главе 37.7.
Реализовать переход правильно непросто: нужно пересчитать координаты
между экранами, учесть поворот и отмену жестом.

С iOS 18 в UIKit появился готовый zoom-переход:

```swift
let thumbnail = cell.imageView   // миниатюра, из которой «вырастет» экран
if #available(iOS 18, *) {
    detail.preferredTransition = .zoom { _ in thumbnail }
}
navigationController?.pushViewController(detail, animated: true)
```

Замыкание возвращает view, **из которого** вырастает новый экран.
Миниатюру кладём в локальную константу, чтобы замыкание не захватывало
весь контроллер через `self`. На
iOS 15–17 условие не выполнится, и экран откроется обычным переходом.

## 32.12 Вращение

```swift
UIView.animate(withDuration: 1.0) {
    view.transform = CGAffineTransform(rotationAngle: .pi)
}

// Бесконечно
let rotate = CABasicAnimation(keyPath: "transform.rotation")
rotate.fromValue = 0
rotate.toValue = 2 * Double.pi
rotate.duration = 1.0
rotate.repeatCount = .infinity
view.layer.add(rotate, forKey: "spin")
```

Углы в iOS задаются в **радианах**, не в градусах. Перевод простой:
π (≈ 3,14) радиан — это пол-оборота, 180°; 2π — полный оборот, 360°;
π / 2 — четверть, 90°. Чтобы перевести градусы в радианы, умножь на π
и раздели на 180: 45° = π / 4 ≈ 0,785.

Две особенности `UIView.animate` с поворотом:

- Он анимирует от старого `transform` к новому **кратчайшим путём**.
  Поворот на 2π даёт ту же матрицу, что и 0, — анимация не сделает
  ничего. Поэтому бесконечное вращение делают через
  `CABasicAnimation` с `transform.rotation`: там анимируется само
  число от 0 до 2π.
- При повороте ровно на π оба направления одинаково «коротки», и
  сторону выбирает система. Нужно гарантированно по часовой — поверни
  на чуть меньший угол (`.pi * 0.999`) или используй
  `CABasicAnimation`.

В координатах iOS ось y смотрит вниз, поэтому положительный угол —
поворот **по часовой стрелке**.

## 32.13 UIViewPropertyAnimator — анимация под управлением

```swift
let animator = UIViewPropertyAnimator(duration: 0.3, curve: .easeOut) {
    view.alpha = 1
}
animator.startAnimation()

// Можно поставить на паузу, перемотать и продолжить
animator.pauseAnimation()
animator.fractionComplete = 0.5
animator.continueAnimation(withTimingParameters: nil, durationFactor: 1.0)
```

`UIViewPropertyAnimator` (iOS 10+) — анимация-объект. В отличие от
`UIView.animate`, её можно держать в свойстве и управлять:

- `pauseAnimation()` — заморозить;
- `fractionComplete = 0.5` — перемотать на середину: `alpha` станет
  0,5 (с учётом кривой);
- `isReversed = true` — пустить назад;
- `continueAnimation(...)` — доиграть с текущего места;
  `durationFactor: 1.0` — оставшаяся часть займёт ту же долю исходной
  длительности.

Главное применение — **интерактивные переходы**: пользователь тянет
пальцем, и анимация идёт вслед за ним (`fractionComplete` = пройденная
пальцем доля), а если отпустил не дотянув — `isReversed = true`, и
всё возвращается. Так устроен свайп-закрытие листа, который можно
«передумать» на середине.

## 32.14 Бытовая аналогия

`UIView.animate` — это **дверь с доводчиком**. Ты говоришь, где она
должна оказаться («закрыта»), а доводчик сам ведёт её туда за нужное
время — с разгоном и торможением.

Пружина — та же дверь на тугой петле: немного проскочит упор и
вернётся. Чем слабее демпфер (меньше damping), тем больше «хлопает».

`CABasicAnimation` с `repeatCount = .infinity` — **маятник часов**:
запустил, и он качается сам, пока не остановишь. Положение маятника
при этом ничего не меняет в механизме — как анимация слоя не меняет
модельное значение.

`CAEmitterLayer` — **хлопушка**: одна точка вылета, сотни конфетти, у
каждого своя траектория и время падения.

## Упражнения

**Упражнение 32.1.** Сделай функцию `shake(_ view: UIView)` с амплитудой
8 точек, пятью «качаниями» и длительностью 0,3 с, которая возвращает
view точно на место. Сколько значений будет в `values` и сколько
длится каждый промежуток?

**Упражнение 32.2.** Кнопка «В корзину» при нажатии уменьшается до 90% и
пружиной возвращается. Напиши `pressAnimation(_ button: UIButton)`:
сжатие за 0,1 с, возврат — пружина с перелётом около 5% за 0,4 с.
Какое значение damping взять?

## Ответы к упражнениям

**32.1.**

```swift
func shake(_ view: UIView) {
    let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
    animation.values = [-8, 8, -6, 6, -3, 0]
    animation.duration = 0.3
    view.layer.add(animation, forKey: "shake")
}
```

Пять движений (влево, вправо, влево, вправо, влево) и возврат в ноль —
шесть значений, пять промежутков. Каждый длится 0,3 / 5 = 0,06 с. Ноль
в конце обязателен: без него на последнем кадре поле стоит сдвинутым
на 3 точки, а потом «прыгает» на место.

**32.2.**

```swift
func pressAnimation(_ button: UIButton) {
    UIView.animate(withDuration: 0.1, animations: {
        button.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
    }) { _ in
        UIView.animate(withDuration: 0.4, delay: 0,
                       usingSpringWithDamping: 0.7, initialSpringVelocity: 0) {
            button.transform = .identity
        }
    }
}
```

`scaleX: 0.9, y: 0.9` — 90% от исходного размера, то есть на 10%
меньше. Перелёт около 5% по замеру из 32.2 даёт damping 0.7.
Возврат запускается в `completion` первой анимации — после того, как
сжатие закончилось.

## Что мы выучили

- **`UIView.animate`** — задаёшь конечное значение, система
  интерполирует. Модель меняется сразу, на экране — presentation layer.
- **Кривые**: ease-in-out (по умолчанию) — разгон и торможение;
  ease-out — для появления; ease-in — для ухода; linear — для
  вращения.
- **Пружина**: damping 0.5 — перелёт ~16%, 0.7 — ~5%, 1.0 — без
  перелёта. Velocity — доля пути в секунду. В iOS 17+ —
  `animate(springDuration:bounce:)`.
- **Последовательность** — через `delay` или `animateKeyframes` с
  долями общего времени.
- **Появление ячеек** — только первый экран, иначе задержка растёт
  с номером строки.
- **SF Symbol effects** (iOS 17+) — только внутри `#available`.
- **`CABasicAnimation`** — бесконечные анимации и свойства слоя; не
  меняет модель.
- **`CAKeyframeAnimation`** — тряска с затухающей амплитудой и нулём в
  конце.
- **Констрейнты** — `constant` снаружи, `layoutIfNeeded()` общего
  предка внутри анимации.
- **`UIView.transition`** — наплыв между view.
- **`CAEmitterLayer`** — конфетти; `contentsScale` у частиц, удалять
  слой после `lifetime`.
- **Радианы**: π = 180°; бесконечное вращение — через
  `CABasicAnimation`.
- **`UIViewPropertyAnimator`** — пауза, перемотка, реверс для
  интерактивных анимаций. Zoom-переход — iOS 18+.

## Apple Developer Documentation

- [UIView.animate(withDuration:animations:)](https://developer.apple.com/documentation/uikit/uiview/1622418-animate) — базовая блочная анимация.
- [UIView.animate(withDuration:delay:usingSpringWithDamping:initialSpringVelocity:options:animations:completion:)](https://developer.apple.com/documentation/uikit/uiview/1622594-animate) — пружинная анимация.
- [UIView.animateKeyframes(withDuration:delay:options:animations:completion:)](https://developer.apple.com/documentation/uikit/uiview/1622552-animatekeyframes) — последовательность через ключевые кадры.
- [UIView.transition(with:duration:options:animations:completion:)](https://developer.apple.com/documentation/uikit/uiview/1622574-transition) — наплыв и переворот между view.
- [UIViewPropertyAnimator](https://developer.apple.com/documentation/uikit/uiviewpropertyanimator) — пауза / перемотка / реверс, iOS 10+.
- [UISpringTimingParameters](https://developer.apple.com/documentation/uikit/uispringtimingparameters) — параметры пружины для `UIViewPropertyAnimator`.
- [UICubicTimingParameters](https://developer.apple.com/documentation/uikit/uicubictimingparameters) — собственные кривые разгона и торможения.
- [CABasicAnimation](https://developer.apple.com/documentation/quartzcore/cabasicanimation) — анимация свойств `CALayer`.
- [CAKeyframeAnimation](https://developer.apple.com/documentation/quartzcore/cakeyframeanimation) — несколько ключевых значений (тряска и др.).
- [CAEmitterLayer](https://developer.apple.com/documentation/quartzcore/caemitterlayer) — система частиц (конфетти).
- [CAEmitterCell](https://developer.apple.com/documentation/quartzcore/caemittercell) — параметры одного вида частиц.
- [UIViewControllerTransitioningDelegate](https://developer.apple.com/documentation/uikit/uiviewcontrollertransitioningdelegate) — точка входа для собственного перехода.
- [UIViewControllerAnimatedTransitioning](https://developer.apple.com/documentation/uikit/uiviewcontrolleranimatedtransitioning) — протокол анимации перехода.
- [UIViewController.Transition](https://developer.apple.com/documentation/uikit/uiviewcontroller/transition) — готовый zoom-переход, iOS 18+.
- [UIImageView/addSymbolEffect(_:options:animated:)](https://developer.apple.com/documentation/uikit/uiimageview) — анимации SF Symbols, iOS 17+.

→ [Глава 33. Cookbook — haptics](./50-cookbook-haptics.md)
