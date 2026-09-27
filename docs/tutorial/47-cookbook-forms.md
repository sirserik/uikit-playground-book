# Глава 30. Cookbook — формы и валидация

Вход, регистрация, адрес доставки, заявка — любая форма сводится к
одному и тому же: поля ввода, проверка того, что в них написано,
кнопка отправки и клавиатура, которая всё это норовит закрыть. Эта
глава собирает рецепты для каждой части: проверку на лету, маску
телефона, силу пароля, растущее поле для длинного текста, пошаговую
форму, черновик, работу с клавиатурой и автозаполнение паролей и
кодов из SMS.

> **В каком режиме код.** Листинги проверены компилятором в режиме
> Swift 6 с Default Actor Isolation = MainActor и минимальной версией
> iOS 15 (подробнее — в начале главы 25).

Пара терминов, которые встретятся везде.

**First responder** («первый отвечающий») — элемент, который сейчас
принимает ввод с клавиатуры. Когда ты тапаешь в поле, оно становится
first responder, и iOS показывает клавиатуру. `becomeFirstResponder()`
— сделать поле активным из кода, `resignFirstResponder()` — отпустить,
после чего клавиатура уедет.

**Валидация** — проверка введённого: похоже ли это на email, хватает
ли длины пароля, все ли цифры телефона на месте.

## 30.1 Inline validation

**Когда применять.** Поле показывает подсказку «правильно / нет» до
нажатия кнопки отправки.

Главный вопрос — **когда** показывать ошибку. Если кричать «неверный
email» после первой же буквы, форма выглядит так, будто ругает
человека за то, что он ещё не допечатал. Хорошая схема:

- пока человек печатает — ошибку **не** показываем, а если она уже
  висит, убираем, как только поле стало правильным;
- когда он ушёл из поля (перешёл в другое) — проверяем и, если
  нужно, показываем ошибку;
- при нажатии «Отправить» — проверяем всё.

```swift
final class SignUpViewController: UIViewController {
    private let emailField = UITextField()
    private let hintLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        hintLabel.font = .preferredFont(forTextStyle: .footnote)
        hintLabel.numberOfLines = 0
        emailField.addAction(UIAction { [weak self] _ in
            self?.validateEmail(showErrors: false)
        }, for: .editingChanged)
        emailField.addAction(UIAction { [weak self] _ in
            self?.validateEmail(showErrors: true)
        }, for: .editingDidEnd)
    }

    @discardableResult
    private func validateEmail(showErrors: Bool) -> Bool {
        let text = (emailField.text ?? "").trimmingCharacters(in: .whitespaces)
        let isValid = isValidEmail(text)
        if isValid {
            hintLabel.text = "Email выглядит правильно"
            hintLabel.textColor = .systemGreen
        } else if showErrors && !text.isEmpty {
            hintLabel.text = "Нужен формат you@example.kz"
            hintLabel.textColor = .systemRed
        } else if !showErrors {
            hintLabel.text = nil
        }
        return isValid
    }
}

func isValidEmail(_ text: String) -> Bool {
    let pattern = #"^[^\s@]+@[^\s@]+\.[^\s@]{2,}$"#
    return text.range(of: pattern, options: .regularExpression) != nil
}
```

Два события `UITextField`:

- `.editingChanged` — на каждое изменение текста (нажатие клавиши,
  вставка, автозаполнение). Здесь `showErrors: false`: подтверждаем,
  если стало правильно, и молча убираем подсказку, если нет.
- `.editingDidEnd` — поле перестало быть активным (перешли в другое
  или закрыли клавиатуру). Здесь уже можно сказать «не то».

`validateEmail` возвращает `Bool` — пригодится при отправке формы.
`@discardableResult` говорит компилятору: «результат можно не
использовать», иначе на вызовах из действий были бы предупреждения.

Проверка email — **регулярное выражение** (шаблон для текста):
`[^\s@]+` — «один или больше символов, кроме пробела и @», потом `@`,
потом снова такие символы, точка и хотя бы два символа в конце.
`a@b.kz` пройдёт, `a@b`, `a b@c.kz` и `@c.kz` — нет. Это **нестрогая**
проверка, и так задумано: по-настоящему адрес проверяет только письмо,
дошедшее до получателя. Строгие «правильные» регулярки для email
занимают экран и всё равно отвергают часть реальных адресов.

Цвет — не единственный признак: ошибка ещё и написана словами. Людям,
которые плохо различают красный и зелёный, одного цвета мало.

**Частые ошибки.**

- **Ошибка на первой букве** — см. выше.
- **Подсказка не для VoiceOver.** Когда появляется ошибка, объяви её:
  `UIAccessibility.post(notification: .announcement, argument: text)`.
- **Проверка без обрезки пробелов.** Автозаполнение и вставка иногда
  приносят пробел в конце, и правильный адрес «не проходит».

## 30.2 Submit button enabled только при валидной форме

**Когда применять.** Короткие формы (вход, 2–3 поля): кнопка неактивна,
пока данных не хватает.

```swift
final class LoginFormViewController: UIViewController {
    private let emailField = UITextField()
    private let passwordField = UITextField()
    private let submitButton = UIButton(configuration: .filled())

    override func viewDidLoad() {
        super.viewDidLoad()
        submitButton.setTitle("Войти", for: .normal)
        for field in [emailField, passwordField] {
            field.addAction(UIAction { [weak self] _ in
                self?.updateSubmitState()
            }, for: .editingChanged)
        }
        updateSubmitState()
    }

    private func updateSubmitState() {
        let emailOk = isValidEmail(emailField.text ?? "")
        let passwordOk = (passwordField.text ?? "").count >= 8
        submitButton.isEnabled = emailOk && passwordOk
    }
}
```

Одно действие на оба поля: любое изменение пересчитывает состояние
кнопки. В `viewDidLoad` вызываем `updateSubmitState()` сразу — чтобы
кнопка была неактивной с самого начала, а не только после первого
нажатия клавиши.

Кнопка создана через `UIButton.Configuration` (iOS 15+): у неё уже есть
системный неактивный вид — приглушённый цвет. Вручную менять `alpha`,
как делают со старыми кнопками, не нужно.

У этого приёма есть обратная сторона: неактивная кнопка не объясняет,
**что** не так. Для длинных форм лучше оставить кнопку активной, а по
нажатию подсветить все проблемные поля (30.1 с `showErrors: true`).
Пример экрана входа целиком — глава 8 (Auth gate).

## 30.3 Password show/hide

**Когда применять.** Поле пароля с «глазом»: нажал — пароль виден,
нажал ещё раз — снова точки.

```swift
final class PasswordField: UITextField {
    private let eyeButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        isSecureTextEntry = true
        textContentType = .password
        autocapitalizationType = .none
        autocorrectionType = .no

        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "eye.slash")
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8)
        eyeButton.configuration = config
        eyeButton.tintColor = .secondaryLabel
        eyeButton.accessibilityLabel = "Показать пароль"
        eyeButton.addAction(UIAction { [weak self] _ in
            self?.toggleVisibility()
        }, for: .touchUpInside)
        rightView = eyeButton
        rightViewMode = .always
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) не используется") }

    private func toggleVisibility() {
        isSecureTextEntry.toggle()
        let visible = !isSecureTextEntry
        eyeButton.configuration?.image = UIImage(systemName: visible ? "eye" : "eye.slash")
        eyeButton.accessibilityLabel = visible ? "Скрыть пароль" : "Показать пароль"
    }
}
```

- `isSecureTextEntry = true` — вместо символов точки. Скопировать
  текст из такого поля нельзя.
- `rightView` — view внутри поля справа. `rightViewMode = .always` —
  видна всегда (есть ещё `.whileEditing`, `.unlessEditing`, `.never`).
- Кнопка лежит в свойстве поля, а в замыкании — только `[weak self]`.
  Если бы замыкание обращалось к кнопке через захват
  (`eye.setImage(...)` внутри действия кнопки `eye`), получился бы цикл удержания: кнопка держит действие, действие —
  кнопку (подробно — глава 27, 27.2).
- `contentInsets` — отступ 8 точек слева и справа от значка, чтобы он
  не прилипал к краю поля.
- `accessibilityLabel` меняется вместе со значком: VoiceOver должен
  говорить, что **сделает** кнопка.

**Частые ошибки.**

- **Текст стирается при повторном вводе.** Когда поле снова
  переключают в скрытый режим и начинают печатать, iOS по умолчанию
  стирает всё введённое ранее — так ведут себя все поля паролей. Это
  защитная особенность, а не ошибка твоего кода, но о ней стоит знать
  до того, как тестировщик заведёт баг.
- **«Глаз» без подписи для VoiceOver** — незрячий человек услышит
  «кнопка» и не поймёт, что она делает.

## 30.4 Phone mask `+7 (___) ___-__-__`

**Когда применять.** Поле телефона, которое само расставляет скобки,
пробелы и дефисы: человек вводит только цифры.

**Маска** — шаблон, по которому форматируется ввод. Логику
форматирования держим отдельно от поля: так её легко проверить без
интерфейса.

```swift
enum PhoneFormatter {
    /// Десять цифр номера после кода страны.
    static func nationalDigits(from raw: String) -> String {
        var digits = raw.filter(\.isNumber)
        if raw.hasPrefix("+7") {
            digits.removeFirst()                  // «7» из «+7» — это код страны
        } else if digits == "8" {
            digits = ""                           // привычная «8» в начале номера
        } else if digits.count == 11, let first = digits.first, first == "7" || first == "8" {
            digits.removeFirst()                  // вставили номер целиком: «8 701 …»
        }
        return String(digits.prefix(10))
    }

    /// «7011234567» → «+7 (701) 123-45-67»; неполный номер — неполная маска.
    static func format(_ national: String) -> String {
        guard !national.isEmpty else { return "" }
        var result = "+7 ("
        for (index, digit) in national.enumerated() {
            switch index {
            case 3: result += ") "
            case 6, 8: result += "-"
            default: break
            }
            result.append(digit)
        }
        return result
    }

    /// Текст поля после правки: что было, какой диапазон заменили и на что.
    static func apply(to current: String, range: NSRange, replacement: String) -> String {
        let text = current as NSString
        var range = range
        let removed = text.substring(with: range)
        if replacement.isEmpty, range.length > 0, !removed.contains(where: \.isNumber) {
            // Стёрли только разделитель («)», «-», пробел) — сотрём и цифру перед ним.
            let head = text.substring(to: range.location) as NSString
            let lastDigit = head.rangeOfCharacter(from: .decimalDigits, options: .backwards)
            if lastDigit.location != NSNotFound {
                range = NSRange(location: lastDigit.location,
                                length: range.location + range.length - lastDigit.location)
            }
        }
        let raw = text.replacingCharacters(in: range, with: replacement)
        return format(nationalDigits(from: raw))
    }
}
```

Три функции — три шага.

**`nationalDigits`** достаёт из любой строки цифры номера без кода
страны. Разберём ветки:

- Текст начинается с «+7» (в поле уже есть маска) — первая цифра
  «7» — это код страны, убираем её.
- Поле было пустым, и человек нажал «8» — по привычке, как при звонке
  по Казахстану или России с «восьмёрки». Эту «8» не считаем цифрой
  номера.
- Вставили номер целиком, 11 цифр, начинается с 7 или 8 («8 701 123 45
  67» из заметок) — отрезаем первую цифру.
- `prefix(10)` — номер после кода страны содержит ровно 10 цифр,
  лишнее отбрасываем.

**`format`** расставляет разделители. Индексы — позиции цифр с нуля:
перед цифрой №3 (четвёртой) закрываем скобку, перед №6 и №8 — дефис.
Для «7011234567»: «+7 (» + «701» + «) » + «123» + «-» + «45» + «-» +
«67» = «+7 (701) 123-45-67». Пустой номер даёт пустую строку, поэтому
поле можно очистить до конца.

**`apply`** — что получится после правки. Есть тонкость со стиранием.
Если курсор стоит сразу после «) » и человек жмёт «стереть», стирается
пробел — цифры не изменились, и форматирование вернуло бы тот же
текст. Кнопка «стереть» перестала бы работать. Поэтому, если удалили
только разделитель, мы расширяем диапазон назад до ближайшей цифры и
стираем её тоже.

Проверка на числах (эти примеры прогнаны через код выше):

| Ввод                               | Результат              |
|------------------------------------|------------------------|
| набрали по одной `7011234567`      | `+7 (701) 123-45-67`   |
| набрали по одной `87011234567`     | `+7 (701) 123-45-67`   |
| вставили `8 701 123 45 67`         | `+7 (701) 123-45-67`   |
| набрали `701123456789` (12 цифр)   | `+7 (701) 123-45-67`   |
| стёрли пробел в `+7 (701) 2`       | `+7 (702`              |

Поле, которое использует форматтер:

```swift
final class PhoneField: UITextField, UITextFieldDelegate {
    override init(frame: CGRect) {
        super.init(frame: frame)
        keyboardType = .phonePad
        textContentType = .telephoneNumber
        placeholder = "+7 (___) ___-__-__"
        delegate = self
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) не используется") }

    var nationalNumber: String { PhoneFormatter.nationalDigits(from: text ?? "") }

    func textField(_ textField: UITextField,
                   shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {
        textField.text = PhoneFormatter.apply(to: textField.text ?? "",
                                              range: range, replacement: string)
        let end = textField.endOfDocument
        textField.selectedTextRange = textField.textRange(from: end, to: end)
        textField.sendActions(for: .editingChanged)
        return false
    }
}
```

`textField(_:shouldChangeCharactersIn:replacementString:)` — метод
делегата, который UIKit спрашивает **перед** каждым изменением: «вот
диапазон, вот новый текст — применить?». Мы считаем результат сами,
записываем его в поле и отвечаем `false`: «сам не меняй, я уже всё
сделал».

Две строки после записи текста легко забыть:

- Курсор ставится в конец. Когда текст задают из кода, курсор может
  оказаться где угодно, а маска рассчитана на ввод по порядку.
- `sendActions(for: .editingChanged)` — когда делегат возвращает
  `false` и текст меняется из кода, событие `.editingChanged` само
  **не приходит**. Без этой строки проверка формы из 30.2 не узнает,
  что телефон изменился, и кнопка «Отправить» не включится.

`keyboardType = .phonePad` — клавиатура с цифрами, `*`, `#` и `+`.
`textContentType = .telephoneNumber` — iOS предложит номер из
карточки владельца телефона в «Контактах».

С iOS 26 у делегата есть и метод с несколькими диапазонами,
`shouldChangeCharactersInRanges`, а метод с одним диапазоном помечен
как «будет объявлен устаревшим». Для проекта с минимальной версией
iOS 15 он по-прежнему основной.

**Частые ошибки.**

- **Нет `sendActions(for: .editingChanged)`** — валидация «не видит»
  ввод.
- **Не работает «стереть»** рядом с разделителем — нет расширения
  диапазона.
- **Храним форматированную строку.** На сервер отправляй
  `nationalNumber` (или «+7» + цифры), а не «+7 (701) 123-45-67»: у
  маски может поменяться вид, у номера — нет.

**Упражнение 30.1.** Что вернёт `PhoneFormatter.format("70112")`? А
`PhoneFormatter.nationalDigits(from: "+7 (701) 12")`? Посчитай в уме,
потом проверь в playground.

## 30.5 Password strength

**Когда применять.** Регистрация или смена пароля: показываем, насколько
пароль надёжен, пока его печатают.

```swift
enum PasswordStrength {
    case weak, medium, strong

    var title: String {
        switch self {
        case .weak:   return "Слабый"
        case .medium: return "Средний"
        case .strong: return "Надёжный"
        }
    }

    var color: UIColor {
        switch self {
        case .weak:   return .systemRed
        case .medium: return .systemOrange
        case .strong: return .systemGreen
        }
    }
}

func passwordStrength(_ password: String) -> PasswordStrength {
    var score = 0
    if password.count >= 8  { score += 1 }
    if password.count >= 12 { score += 1 }
    if password.contains(where: \.isNumber) { score += 1 }
    if password.contains(where: \.isUppercase) && password.contains(where: \.isLowercase) {
        score += 1
    }
    if password.contains(where: { !$0.isLetter && !$0.isNumber }) { score += 1 }

    switch score {
    case 0...1: return .weak
    case 2...3: return .medium
    default:    return .strong
    }
}
```

Пять признаков, за каждый — балл: длина от 8, длина от 12, есть
цифра, есть и заглавные, и строчные буквы, есть спецсимвол. Сумма от 0
до 5 переводится в оценку: 0–1 — слабый, 2–3 — средний, 4–5 —
надёжный.

На числах:

- `qwerty` — короче 8, нет цифр, нет заглавных, нет спецсимволов: 0
  баллов, «Слабый».
- `Almaty2026` — длина 10 (≥ 8: +1), цифры (+1), заглавная и строчные
  (+1): 3 балла, «Средний».
- `Almaty-2026!` — длина 12 (+2), цифры (+1), регистры (+1),
  спецсимволы (+1): 5 баллов, «Надёжный».

У `enum` есть и `title`, и `color`: под полем показываем слово и цвет
вместе (цвет в одиночку не все различают).

Это грубая эвристика. Она не знает, что `Password1!` — один из самых
популярных паролей в мире, и поставит ему «Надёжный». Настоящие
оценщики сверяют пароль со словарями утёкших паролей; пример такого
алгоритма — [zxcvbn](https://github.com/dropbox/zxcvbn) от Dropbox
(написан на JavaScript, есть порты на другие языки). Главную проверку
всё равно делает сервер.

## 30.6 Auto-grow UITextView

**Когда применять.** Многострочное поле, которое растёт по мере ввода:
комментарий, сообщение в чате, отзыв.

```swift
final class AutoGrowTextView: UITextView, UITextViewDelegate {
    var minHeight: CGFloat = 44
    var maxHeight: CGFloat = 120
    private lazy var heightConstraint = heightAnchor.constraint(equalToConstant: minHeight)

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        font = .preferredFont(forTextStyle: .body)
        adjustsFontForContentSizeCategory = true
        isScrollEnabled = false
        delegate = self
        heightConstraint.isActive = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) не используется") }

    override var text: String! {
        didSet { updateHeight() }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateHeight()
    }

    func textViewDidChange(_ textView: UITextView) {
        updateHeight()
    }

    private func updateHeight() {
        guard bounds.width > 0 else { return }
        let fitting = sizeThatFits(CGSize(width: bounds.width, height: .greatestFiniteMagnitude))
        let newHeight = min(max(minHeight, fitting.height), maxHeight)
        isScrollEnabled = fitting.height > maxHeight
        if heightConstraint.constant != newHeight {
            heightConstraint.constant = newHeight
        }
    }
}
```

Как это работает:

- `sizeThatFits` спрашивает у текстового поля: «какой высоты ты хочешь
  быть при этой ширине?». Ширину даём текущую, высоту — «сколько
  угодно» (`greatestFiniteMagnitude`, самое большое число `CGFloat`).
- Результат зажимаем между 44 и 120 точками: `max(44, h)` не даёт
  стать ниже одной строки, `min(..., 120)` — выше примерно пяти строк.
  На числах: нужно 30 → будет 44; нужно 80 → 80; нужно 200 → 120.
- `isScrollEnabled`. Пока текст помещается, прокрутка выключена — тогда
  поле само сообщает свой размер по содержимому. Когда нужно больше
  120, прокрутку **включаем**, иначе текст ниже пятой строки нельзя
  было бы увидеть: длинный текст просто обрезался бы.
- Ограничение высоты создаётся в `init` — `lazy var` откладывает его
  создание до первого обращения, когда `self` уже готов. Никаких
  `NSLayoutConstraint!`, которые упадут, если их забыли задать
  снаружи.
- Высота пересчитывается в трёх местах: при вводе
  (`textViewDidChange`), при смене текста из кода (`didSet` у `text` —
  делегат в этом случае не вызывается) и при смене ширины
  (`layoutSubviews`, например после поворота экрана). `guard
  bounds.width > 0` — до первой раскладки ширина нулевая, и считать
  нечего.

Полный пример в строке сообщения чата — глава 18 (Chat).

## 30.7 Form wizard (multi-step)

**Когда применять.** Длинная регистрация, которую удобнее пройти по
шагам: данные → телефон → код из SMS → согласия. **Мастер** (wizard)
— форма из нескольких экранов с «Далее» и индикатором прогресса.

```swift
final class WizardViewController: UIViewController {
    var onFinish: (() -> Void)?

    private let pages: [UIViewController]
    private var currentIndex = 0
    private let pageVC = UIPageViewController(transitionStyle: .scroll,
                                              navigationOrientation: .horizontal)
    private let progressView = UIProgressView(progressViewStyle: .bar)

    init(pages: [UIViewController]) {
        precondition(!pages.isEmpty, "Мастеру нужен хотя бы один шаг")
        self.pages = pages
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) не используется") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        addChild(pageVC)
        pageVC.view.translatesAutoresizingMaskIntoConstraints = false
        progressView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(progressView)
        view.addSubview(pageVC.view)
        NSLayoutConstraint.activate([
            progressView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pageVC.view.topAnchor.constraint(equalTo: progressView.bottomAnchor),
            pageVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pageVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pageVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        pageVC.didMove(toParent: self)

        pageVC.setViewControllers([pages[0]], direction: .forward, animated: false)
        updateProgress()
    }

    func goNext() {
        guard currentIndex < pages.count - 1 else {
            onFinish?()
            return
        }
        currentIndex += 1
        pageVC.setViewControllers([pages[currentIndex]], direction: .forward, animated: true)
        updateProgress()
    }

    func goBack() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
        pageVC.setViewControllers([pages[currentIndex]], direction: .reverse, animated: true)
        updateProgress()
    }

    private func updateProgress() {
        progressView.setProgress(Float(currentIndex + 1) / Float(pages.count), animated: true)
    }
}
```

`UIPageViewController` — контейнер, который показывает по одному
экрану и умеет анимировать переход к другому. Он встроен в мастер
как **дочерний контроллер**: `addChild`, добавить его view, прибить
ограничениями, `didMove(toParent:)`. Эти три шага обязательны — без
`addChild` дочерний экран не получает событий жизненного цикла
(`viewWillAppear` и другие).

Обрати внимание: у `pageVC` **нет источника данных** (`dataSource`).
Поэтому листать шаги пальцем нельзя — только кнопками «Далее» и
«Назад», которые вызывают `goNext()` и `goBack()`. Для формы это
правильно: иначе человек проскочит шаг, не заполнив его, свайпом.

Прогресс на числах: четыре шага; на первом `(0 + 1) / 4 = 0,25` —
полоса заполнена на четверть, на последнем `4 / 4 = 1` — полностью.

Каждый шаг — отдельный экран со своей проверкой полей. Кнопка «Далее»
внутри шага вызывает мастер через замыкание или делегата:
`step.onNext = { [weak wizard] in wizard?.goNext() }`.

## 30.8 Save as draft

**Когда применять.** Длинная форма: заявка, отзыв, отчёт. Если
человек случайно закроет экран или приложение выгрузится из памяти,
написанное не должно пропасть.

```swift
struct ReportDraft: Codable {
    var text: String
    var savedAt: Date
}

final class ReportViewController: UIViewController, UITextViewDelegate {
    private static let draftKey = "draft.report"
    private let textView = UITextView()
    private var saveWorkItem: DispatchWorkItem?

    override func viewDidLoad() {
        super.viewDidLoad()
        textView.delegate = self
        if let data = UserDefaults.standard.data(forKey: Self.draftKey),
           let draft = try? JSONDecoder().decode(ReportDraft.self, from: data) {
            textView.text = draft.text
        }
    }

    func textViewDidChange(_ textView: UITextView) {
        saveWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.saveDraft()
        }
        saveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: work)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        saveWorkItem?.cancel()
        saveDraft()
    }

    private func saveDraft() {
        let draft = ReportDraft(text: textView.text, savedAt: Date())
        guard let data = try? JSONEncoder().encode(draft) else { return }
        UserDefaults.standard.set(data, forKey: Self.draftKey)
    }

    func didSubmitSuccessfully() {
        saveWorkItem?.cancel()
        UserDefaults.standard.removeObject(forKey: Self.draftKey)
    }
}
```

- **Сохранение с паузой** — тот же debounce, что в поиске (глава 25,
  25.2): каждое изменение отменяет прошлое задание и назначает новое
  через 1 секунду. Пока человек печатает, запись не идёт; замолчал на
  секунду — черновик сохранён.
- `viewWillDisappear` — при уходе с экрана сохраняем **сразу**, не
  дожидаясь секунды: иначе последние слова, набранные прямо перед
  закрытием, пропадут вместе с отменённым заданием.
- `Codable` — черновик превращается в JSON (`JSONEncoder`) и обратно
  (`JSONDecoder`). `UserDefaults` хранит получившиеся байты (`Data`).
- `didSubmitSuccessfully` — после успешной отправки черновик удаляем.
  Иначе в другой раз форма откроется со старым, уже отправленным
  текстом.
- `super.viewDidLoad()` — не пропускай вызов родителя в методах
  жизненного цикла.

`UserDefaults` подходит для черновика в несколько килобайт. Если в
черновике фотографии или десятки страниц текста — сохраняй в файл
(глава 13, FileManager).

## 30.9 Keyboard avoidance

**Когда применять.** Всегда, когда на экране есть поля ввода:
клавиатура занимает около 40% высоты iPhone и закрывает всё, что было
в нижней части экрана.

С iOS 15 у каждой view есть **направляющая клавиатуры**
(`keyboardLayoutGuide`) — невидимая рамка, которая совпадает с
клавиатурой, пока та на экране, и прилегает к нижнему краю безопасной
области, когда клавиатуры нет. Достаточно привязать к ней низ формы:

```swift
final class AddressFormViewController: UIViewController {
    private let scrollView = UIScrollView()
    private let stack = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        scrollView.keyboardDismissMode = .interactive
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -16),
        ])
    }
}
```

Главная строка — `scrollView.bottomAnchor ... keyboardLayoutGuide.topAnchor`:
низ прокручиваемой области всегда стоит над клавиатурой. Клавиатура
выехала — область стала короче, и нижние поля можно докрутить до
видимой части. Анимация сжатия идёт синхронно с клавиатурой, без
единой строки кода. Пример с полем сообщения в чате — глава 18,
раздел 18.6.

Форма лежит в `UIScrollView` не случайно. Если просто прибить кнопку
«Отправить» к клавиатуре без прокрутки, на маленьком экране поля
окажутся **под** верхним краем: для формы из восьми полей по 44 точки
плюс промежутки нужно около 450 точек, а над клавиатурой на iPhone SE
остаётся около 300.

- `stack` прибит к `contentLayoutGuide` сверху и снизу — это задаёт
  высоту прокручиваемого содержимого.
- По бокам — к `frameLayoutGuide` (видимой рамке скролла): ширина
  содержимого равна ширине экрана, горизонтальной прокрутки нет.
- `keyboardDismissMode = .interactive` — клавиатуру можно «утащить»
  вниз пальцем, прокручивая форму, как в «Сообщениях».

UIKit сам прокручивает скролл так, чтобы активное поле было видно над
клавиатурой. Если поле закрывает что-то своё (например, подсказку под
полем), докрути вручную:

```swift
func textFieldDidBeginEditing(_ textField: UITextField) {
    let rect = textField.convert(textField.bounds, to: scrollView)
        .insetBy(dx: 0, dy: -40)
    scrollView.scrollRectToVisible(rect, animated: true)
}
```

`convert(_:to:)` переводит рамку поля в координаты скролла.
`insetBy(dx: 0, dy: -40)` **расширяет** прямоугольник на 40 точек
вверх и вниз (отрицательный отступ — наружу), чтобы вместе с полем
была видна и подсказка под ним.

В старом коде ты встретишь другой способ — подписку на уведомления
клавиатуры:

```swift
@objc func keyboardWillChange(_ note: Notification) {
    guard let value = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue,
          let duration = note.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double
    else { return }
    let keyboardFrame = view.convert(value.cgRectValue, from: nil)
    let overlap = max(0, view.bounds.maxY - keyboardFrame.minY - view.safeAreaInsets.bottom)
    bottomConstraint.constant = -overlap
    UIView.animate(withDuration: duration) { self.view.layoutIfNeeded() }
}
```

Его подключают через `NotificationCenter` на
`keyboardWillChangeFrameNotification`. Рамка клавиатуры приходит в
координатах экрана, `convert(_:from: nil)` переводит её в координаты
view. **Перекрытие** — сколько клавиатура залезла на view снизу:
экран высотой 852, клавиатура начинается на 516 — перекрытие 336
точек, минус нижний отступ безопасной области 34 — поднимаем
содержимое на 302. При минимальной версии iOS 15 этот код не нужен:
`keyboardLayoutGuide` делает то же самое сам и не забывает про
поворот, плавающую клавиатуру iPad и смену высоты при переключении
языка.

## 30.10 Return key flow

**Когда применять.** Форма из нескольких полей: кнопка на клавиатуре
переводит в соседнее поле, на последнем — отправляет.

```swift
final class CredentialsViewController: UIViewController, UITextFieldDelegate {
    private let emailField = UITextField()
    private let passwordField = UITextField()

    override func viewDidLoad() {
        super.viewDidLoad()
        emailField.returnKeyType = .next
        emailField.delegate = self
        passwordField.returnKeyType = .go
        passwordField.delegate = self
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField === emailField {
            passwordField.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
            submit()
        }
        return false
    }

    private func submit() {}
}
```

`returnKeyType` — надпись на синей кнопке клавиатуры: `.next`
(«Далее»), `.go`/`.done` («Готово»), `.send`, `.search`. Надпись не
меняет поведения — поведение пишешь сам в `textFieldShouldReturn`.

`textFieldShouldReturn` вызывается при нажатии этой кнопки. На поле
email делаем активным поле пароля: `becomeFirstResponder()`, и
клавиатура не прячется, а просто «переезжает». На поле пароля
отпускаем фокус (клавиатура уедет) и отправляем форму. Возвращаем
`false`: стандартная обработка (вставить перевод строки) не нужна.

`===` сравнивает **объекты**: это то же самое поле, а не поле с таким
же текстом.

## 30.11 TextField suggestions / textContentType

**Когда применять.** Любое поле, для которого iOS умеет что-то
подсказать: логин, пароль, код из SMS, адрес, телефон, имя.

```swift
func configureAutoFill() {
    loginField.textContentType = .username
    loginField.keyboardType = .emailAddress
    passwordField.textContentType = .password
    passwordField.isSecureTextEntry = true

    newPasswordField.textContentType = .newPassword
    newPasswordField.isSecureTextEntry = true
    newPasswordField.passwordRules = UITextInputPasswordRules(
        descriptor: "required: lower; required: upper; required: digit; minlength: 8;"
    )

    codeField.textContentType = .oneTimeCode
    codeField.keyboardType = .numberPad

    phoneField.textContentType = .telephoneNumber
}
```

`textContentType` говорит системе, **что** в поле, и от этого зависит
подсказка над клавиатурой (строка QuickType):

- `.username` — логин. Если логин — это email, всё равно ставь
  `.username`, а email-клавиатуру задай отдельно через `keyboardType`:
  так рекомендует Apple, иначе автозаполнение паролей хуже понимает,
  что это форма входа.
- `.password` — существующий пароль: iOS предложит сохранённый.
- `.newPassword` — новый пароль при регистрации: iOS предложит
  сгенерированный надёжный пароль и сохранит его. `passwordRules`
  описывает требования сервера — строчная и заглавная буквы, цифра, не
  короче 8 символов, — и сгенерированный пароль им будет
  соответствовать.
- `.oneTimeCode` — одноразовый код. Когда приходит SMS с кодом, iOS
  показывает его над клавиатурой: один тап — и код в поле. По
  документации Apple, подсказка держится до трёх минут после прихода
  сообщения.
- `.telephoneNumber` — номер из карточки владельца в «Контактах».

Что нужно, чтобы это работало в полную силу:

- **Связанный домен** (associated domains). Сохранённые пароли для
  твоего сайта iOS предлагает сразу в строке подсказок, а надёжный
  пароль для `.newPassword` генерирует, только если приложение связано
  со своим доменом: в проекте включена возможность Associated Domains
  с записью `webcredentials:example.kz`, а на сайте лежит файл
  `apple-app-site-association`. Без связи человек всё равно может
  выбрать пароль вручную, через значок ключа.
- **Для кода из SMS** ничего дополнительно настраивать не нужно, но
  текст сообщения должен быть таким, чтобы iOS распознала в нём код.
  Проверить просто: отправь такое SMS себе. Если код в нём
  подчёркнут и по тапу есть «Скопировать код», система его понимает.
- **Не прячь интерфейс при уходе в фон.** Когда человек выбирает
  пароль из подсказки, iOS просит Face ID, и приложение на мгновение
  становится неактивным. Если в этот момент твой экран закрывает
  форму заглушкой (как в главе 11), автозаполнению некуда будет
  подставить данные.

## 30.12 Disable autocorrect

```swift
func configureLoginField(_ field: UITextField) {
    field.autocapitalizationType = .none
    field.autocorrectionType = .no
    field.spellCheckingType = .no
    field.smartQuotesType = .no
    field.smartDashesType = .no
}
```

По умолчанию `UITextField` делает первую букву предложения заглавной
(`autocapitalizationType = .sentences`) и исправляет «опечатки». В
обычном тексте это удобно, а в логине — вредно: «ivanov» превращается
в «Ivanov», и вход не проходит, хотя человек уверен, что ввёл всё
правильно.

Выключаем для email, логина, пароля, промокода, адреса сайта:

- `autocapitalizationType = .none` — без автоматических заглавных.
  Email-клавиатура (`keyboardType = .emailAddress`) эту настройку сама
  **не** меняет — выключай явно.
- `autocorrectionType = .no` — без автоисправления.
- `spellCheckingType = .no` — без красного подчёркивания «ошибок».
- `smartQuotesType`, `smartDashesType` (iOS 11+) — без замены прямых
  кавычек на «ёлочки» и двух дефисов на тире: в пароле `"--"` должно
  остаться `"--"`.

**Упражнение 30.2.** Собери экран регистрации из трёх полей: email,
новый пароль, повтор пароля. Какие `textContentType`, `keyboardType`,
`returnKeyType` и настройки автоисправления ты поставишь каждому полю?
Какое условие включает кнопку «Создать аккаунт»?

## Ответы к упражнениям

**30.1.** `format("70112")`: цифры с индексами 0–4. Перед индексом 3
ставится «) », поэтому результат — «+7 (701) 12». `nationalDigits(from:
"+7 (701) 12")`: все цифры — «770112», строка начинается с «+7»,
поэтому первая «7» (код страны) отрезается — остаётся «70112».

**30.2.** Возможный вариант:

```swift
emailField.textContentType = .username
emailField.keyboardType = .emailAddress
emailField.returnKeyType = .next
emailField.autocapitalizationType = .none
emailField.autocorrectionType = .no

passwordField.textContentType = .newPassword
passwordField.isSecureTextEntry = true
passwordField.returnKeyType = .next

repeatField.textContentType = .newPassword
repeatField.isSecureTextEntry = true
repeatField.returnKeyType = .done

let canSubmit = isValidEmail(emailField.text ?? "")
    && (passwordField.text ?? "").count >= 8
    && passwordField.text == repeatField.text
```

Оба поля пароля — `.newPassword`: тогда iOS подставит сгенерированный
пароль сразу в оба. Кнопка включается, когда email похож на адрес,
пароль не короче 8 символов и повтор совпадает с паролем. В
`textFieldShouldReturn` первые два поля передают фокус дальше, а
последнее отправляет форму (как в 30.10).

## Что мы выучили

- **Проверка на лету**: `.editingChanged` — только подтверждать и
  убирать ошибку, `.editingDidEnd` и отправка — показывать ошибку;
  цвет плюс текст.
- **Email** проверяем нестрого (`something@domain.xx`); настоящая
  проверка — письмо.
- **Кнопка отправки** неактивна, пока форма неполна; `UIButton.Configuration`
  сам рисует неактивный вид.
- **Показ пароля** — `isSecureTextEntry.toggle()`, кнопка в `rightView`
  без захвата самой себя в замыкании.
- **Маска телефона** — отдельный форматтер (`nationalDigits`, `format`,
  `apply`), `return false` в делегате, курсор в конец и
  `sendActions(for: .editingChanged)`.
- **Сила пароля** — баллы за длину и разнообразие символов; это
  подсказка, главная проверка на сервере.
- **Растущее поле** — `sizeThatFits`, зажим между минимумом и
  максимумом, прокрутка включается выше максимума.
- **Мастер** — `UIPageViewController` без `dataSource`, дочерний
  контроллер через `addChild`/`didMove`, прогресс `(шаг + 1) / всего`.
- **Черновик** — сохранение с паузой 1 с, немедленное при уходе с
  экрана, удаление после отправки.
- **Клавиатура** — форма в `UIScrollView`, низ скролла к
  `keyboardLayoutGuide.topAnchor` (iOS 15+).
- **Return** — `returnKeyType` + `textFieldShouldReturn` для перехода
  между полями.
- **Автозаполнение** — `.username` (даже для email), `.password`,
  `.newPassword` + `passwordRules`, `.oneTimeCode`; для паролей нужен
  связанный домен.
- **Автоисправление** выключаем для логинов, паролей и email явно.

## Apple Developer Documentation

- [`UITextField`](https://developer.apple.com/documentation/uikit/uitextfield) — однострочное поле, `rightView`, `rightViewMode`, `isSecureTextEntry`.
- [`UITextFieldDelegate`](https://developer.apple.com/documentation/uikit/uitextfielddelegate) — `textField(_:shouldChangeCharactersIn:replacementString:)`, `textFieldShouldReturn(_:)`.
- [`UITextContentType`](https://developer.apple.com/documentation/uikit/uitextcontenttype) — `.username`, `.password`, `.newPassword`, `.oneTimeCode`, `.telephoneNumber`.
- [Password AutoFill](https://developer.apple.com/documentation/security/password-autofill) — как работает автозаполнение паролей и зачем связанный домен.
- [Enabling Password AutoFill on a text input view](https://developer.apple.com/documentation/security/enabling-password-autofill-on-a-text-input-view) — какие `textContentType` ставить в форме входа и регистрации.
- [`UITextInputPasswordRules`](https://developer.apple.com/documentation/uikit/uitextinputpasswordrules) — требования к сгенерированному паролю.
- [`UITextInputTraits`](https://developer.apple.com/documentation/uikit/uitextinputtraits) — `autocapitalizationType`, `autocorrectionType`, `spellCheckingType`, `returnKeyType`, `keyboardType`.
- [`UITextView`](https://developer.apple.com/documentation/uikit/uitextview) и [`UITextViewDelegate`](https://developer.apple.com/documentation/uikit/uitextviewdelegate) — многострочный ввод.
- [`UIPageViewController`](https://developer.apple.com/documentation/uikit/uipageviewcontroller) — контейнер шагов мастера.
- [`UIView.keyboardLayoutGuide`](https://developer.apple.com/documentation/uikit/uiview/keyboardlayoutguide) — направляющая клавиатуры (iOS 15+).
- [`UIResponder.keyboardWillChangeFrameNotification`](https://developer.apple.com/documentation/uikit/uiresponder/keyboardwillchangeframenotification) — уведомление о смене рамки клавиатуры (старый способ).
- [HIG — Text fields](https://developer.apple.com/design/human-interface-guidelines/text-fields) — Apple о полях ввода и подсказках.

→ [Глава 31. Cookbook — дата, время, деньги](./48-cookbook-date-money.md)
