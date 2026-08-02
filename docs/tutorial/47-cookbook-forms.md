# Глава 30. Cookbook — формы и валидация

Login, регистрация, ввод адреса, любое serious-input. Базовые
паттерны.

## 30.1 Inline validation

**Когда применять.** Поле должно показывать «правильно/нет» сразу,
без нажатия submit.

```swift
emailField.addTarget(self, action: #selector(check), for: .editingChanged)

@objc private func check() {
    let text = emailField.text ?? ""
    if text.isEmpty {
        hintLabel.text = "Введи email"
        hintLabel.textColor = .secondaryLabel
    } else if isValidEmail(text) {
        hintLabel.text = "✓ Email выглядит правильно"
        hintLabel.textColor = .systemGreen
    } else {
        hintLabel.text = "✗ Нужен формат you@example.kz"
        hintLabel.textColor = .systemRed
    }
}
```

Подсказка под полем меняется на каждое нажатие. Цвет — состояние.

**Когда не показывать ошибку:**
- Поле пустое (юзер ещё не начал).
- Юзер только что начал печатать (≤ 2 символа) — некрасиво кричать
  «ошибка» на «ab».

## 30.2 Submit button enabled только при валидной форме

```swift
@objc private func validateForm() {
    let emailOk = isValidEmail(emailField.text ?? "")
    let passOk = (passwordField.text?.count ?? 0) >= 6
    let ok = emailOk && passOk
    submitButton.isEnabled = ok
    submitButton.alpha = ok ? 1.0 : 0.5
}

emailField.addTarget(self, action: #selector(validateForm), for: .editingChanged)
passwordField.addTarget(self, action: #selector(validateForm), for: .editingChanged)
```

Кнопка disabled (полупрозрачная) пока что-то не так. Никаких alert'ов
«пароль слишком короткий» — юзер видит, что кнопка не активна.

См. Глава 8 (Auth gate) для конкретного примера.

## 30.3 Password show/hide

```swift
private let passwordField = UITextField()
private var isPasswordVisible = false

private func setupPasswordField() {
    passwordField.isSecureTextEntry = true
    let eye = UIButton(type: .system)
    eye.setImage(UIImage(systemName: "eye.slash"), for: .normal)
    eye.tintColor = .secondaryLabel
    eye.addAction(UIAction { [weak self] _ in
        guard let self else { return }
        self.isPasswordVisible.toggle()
        self.passwordField.isSecureTextEntry = !self.isPasswordVisible
        eye.setImage(UIImage(systemName: self.isPasswordVisible ? "eye" : "eye.slash"), for: .normal)
    }, for: .touchUpInside)
    passwordField.rightView = eye
    passwordField.rightViewMode = .always
}
```

`rightView` — view справа в textField. `.always` — показывается
всегда (есть ещё `.whileEditing`, `.unlessEditing`, `.never`).

## 30.4 Phone mask `+7 (___) ___-__-__`

```swift
class PhoneField: UITextField, UITextFieldDelegate {
    override init(frame: CGRect) {
        super.init(frame: frame)
        keyboardType = .phonePad
        placeholder = "+7 (___) ___-__-__"
        delegate = self
    }

    func textField(_ textField: UITextField,
                   shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {
        let raw = ((textField.text ?? "") as NSString).replacingCharacters(in: range, with: string)
        let digits = raw.filter(\.isNumber)
        textField.text = format(digits: digits)
        return false  // мы сами обновили, UIKit пусть не трогает
    }

    private func format(digits: String) -> String {
        let normalized = digits.hasPrefix("7") ? String(digits.dropFirst()) : digits
        var result = "+7"
        for (i, c) in normalized.prefix(10).enumerated() {
            switch i {
            case 0: result += " ("
            case 3: result += ") "
            case 6, 8: result += "-"
            default: break
            }
            result.append(c)
        }
        return result
    }
}
```

Перехватываем любое изменение, оставляем только цифры,
форматируем сами.

`return false` — говорим UIKit не делать стандартное обновление, мы
уже всё сами.

## 30.5 Password strength

```swift
enum Strength { case weak, medium, strong }

func passwordStrength(_ s: String) -> Strength {
    var score = 0
    if s.count >= 6 { score += 1 }
    if s.count >= 10 { score += 1 }
    if s.contains(where: \.isNumber) { score += 1 }
    if s.contains(where: { $0.isUppercase }) { score += 1 }
    if s.contains(where: { !$0.isLetter && !$0.isNumber }) { score += 1 }
    switch score {
    case 0...1: return .weak
    case 2...3: return .medium
    default: return .strong
    }
}
```

Простой scoring по длине / цифрам / регистру / спец-символам.

Визуализация — текст «Слабый» / «Средний» / «Хороший» с цветом.

Для строгой оценки используй [zxcvbn](https://github.com/dropbox/zxcvbn)
— Dropbox-овская библиотека с учётом популярных паролей.

## 30.6 Auto-grow UITextView

```swift
class AutoGrowTextView: UITextView, UITextViewDelegate {
    var heightConstraint: NSLayoutConstraint!
    var minHeight: CGFloat = 44
    var maxHeight: CGFloat = 120

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        font = .preferredFont(forTextStyle: .body)
        isScrollEnabled = false
        delegate = self
    }

    func textViewDidChange(_ textView: UITextView) {
        let size = textView.sizeThatFits(CGSize(width: textView.bounds.width, height: .infinity))
        heightConstraint.constant = min(max(minHeight, size.height), maxHeight)
    }
}
```

`isScrollEnabled = false` — критично. Иначе textView сам управляет
размером.

`sizeThatFits` спрашивает «какая высота нужна для этого текста при
этой ширине».

См. Главу 18 (Chat) для использования в composer'е.

## 30.7 Form wizard (multi-step)

**Когда применять.** Регистрация со многими шагами: данные → телефон
→ верификация → согласия → готово.

```swift
class WizardViewController: UIViewController {
    private let pages: [UIViewController]
    private var currentIndex = 0
    private let pageVC = UIPageViewController(transitionStyle: .scroll,
                                              navigationOrientation: .horizontal)

    init(pages: [UIViewController]) {
        self.pages = pages
        super.init(nibName: nil, bundle: nil)
    }

    func goNext() {
        guard currentIndex < pages.count - 1 else { finish(); return }
        currentIndex += 1
        pageVC.setViewControllers([pages[currentIndex]], direction: .forward, animated: true)
        updateProgress()
    }

    private func updateProgress() {
        progressView.progress = Float(currentIndex + 1) / Float(pages.count)
    }
}
```

`UIPageViewController` как контейнер шагов. Progress-bar сверху
отражает текущий шаг.

Каждый шаг — отдельный VC, который зовёт `goNext()` родителя через
делегат.

## 30.8 Save as draft

**Когда применять.** Длинная форма (заявка, отчёт). Если юзер закроет
случайно, не должен потерять прогресс.

```swift
// При каждом изменении
private var saveWorkItem: DispatchWorkItem?

func textViewDidChange(_ textView: UITextView) {
    saveWorkItem?.cancel()
    let work = DispatchWorkItem { [weak self] in
        self?.saveDraft()
    }
    saveWorkItem = work
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: work)
}

private func saveDraft() {
    let draft = Draft(
        text: textView.text,
        savedAt: Date()
    )
    UserDefaults.standard.set(try? JSONEncoder().encode(draft), forKey: "draft.report")
}

override func viewDidLoad() {
    // Восстановление черновика
    if let data = UserDefaults.standard.data(forKey: "draft.report"),
       let draft = try? JSONDecoder().decode(Draft.self, from: data) {
        textView.text = draft.text
        // ...
    }
}
```

Debounce 1 секунда. Сохраняем JSON в UserDefaults. При следующем
открытии — восстанавливаем.

После успешной отправки — удаляем draft.

## 30.9 Keyboard avoidance

```swift
override func viewDidLoad() {
    super.viewDidLoad()
    // iOS 15+
    bottomConstraint = stack.bottomAnchor.constraint(
        equalTo: view.keyboardLayoutGuide.topAnchor, constant: -16
    )
    bottomConstraint.isActive = true
}
```

Использован уже в Главе 18 (Chat). Одна строка вместо `NotificationCenter`-
жонглирования.

Для **iOS 14 и ниже** — старый способ с notification:

```swift
NotificationCenter.default.addObserver(
    self, selector: #selector(keyboardWillChange),
    name: UIResponder.keyboardWillChangeFrameNotification, object: nil
)

@objc func keyboardWillChange(_ note: Notification) {
    guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
          let duration = note.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval
    else { return }
    let inset = view.bounds.height - view.convert(frame, from: nil).origin.y
    bottomConstraint.constant = -max(0, inset - view.safeAreaInsets.bottom)
    UIView.animate(withDuration: duration) { self.view.layoutIfNeeded() }
}
```

## 30.10 Return key flow

`returnKeyType` + `delegate` для переходов между полями:

```swift
emailField.returnKeyType = .next
emailField.delegate = self

passwordField.returnKeyType = .done
passwordField.delegate = self

extension MyVC: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField === emailField {
            passwordField.becomeFirstResponder()
        } else {
            passwordField.resignFirstResponder()
            submit()
        }
        return false
    }
}
```

Юзер жмёт Next в клавиатуре → фокус прыгает на соседнее поле. Done
на последнем → закрывается клавиатура + submit.

## 30.11 TextField suggestions / textContentType

iOS-плюшка для автозаполнения:

```swift
emailField.textContentType = .username      // или .emailAddress
passwordField.textContentType = .password   // существующий
newPasswordField.textContentType = .newPassword  // регистрация
otpField.textContentType = .oneTimeCode     // SMS-код
phoneField.textContentType = .telephoneNumber
```

iOS сама предложит:
- Email из контактов / iCloud Keychain.
- Сохранённые пароли.
- Strong password при `.newPassword`.
- SMS-коды из Messages при `.oneTimeCode`.

Не используешь — теряешь UX-фичу, которая работает «из коробки».

## 30.12 Disable autocorrect

```swift
emailField.autocapitalizationType = .none
emailField.autocorrectionType = .no
emailField.spellCheckingType = .no
```

Для email, username, password — выключи. iOS правит "ivanov" на
"Ivanov", и пользователь не понимает почему логин не работает.

## 📋 Что мы выучили

- **Inline validation** через `editingChanged` action — обновление
  hint-label на каждое нажатие.
- **Submit disabled** пока не все поля валидны.
- **Show/hide password** через `rightView` UITextField + toggle
  `isSecureTextEntry`.
- **Phone mask** — перехват `shouldChangeCharactersIn`, фильтр
  цифр, ручное форматирование, return false.
- **Password strength** — простой score по длине / цифрам / регистру.
- **Auto-grow UITextView** — `isScrollEnabled = false` + `sizeThatFits`
  + updateHeight.
- **Wizard** — `UIPageViewController` + progress-bar сверху.
- **Save as draft** — debounced JSON в UserDefaults + восстановление
  при viewDidLoad.
- **Keyboard avoidance** — `view.keyboardLayoutGuide.topAnchor`
  (iOS 15+), одна строка.
- **`returnKeyType`** + `textFieldShouldReturn` — переход между
  полями.
- **`textContentType`** — даёт iOS возможность автозаполнения.
- **Отключи autocorrect** для email / username / password.

## Apple Developer Documentation

- [`UITextField`](https://developer.apple.com/documentation/uikit/uitextfield) — однострочное поле ввода.
- [`UITextFieldDelegate`](https://developer.apple.com/documentation/uikit/uitextfielddelegate) — `shouldChangeCharactersIn:replacementString:` для фильтра, `textFieldShouldReturn:` для return-flow.
- [`UITextField.textContentType`](https://developer.apple.com/documentation/uikit/uitextfield) и [`UITextContentType`](https://developer.apple.com/documentation/uikit/uitextcontenttype) — `.emailAddress`, `.password`, `.newPassword`, `.oneTimeCode`, `.telephoneNumber` (автозаполнение iCloud Keychain + SMS).
- [`UITextField.isSecureTextEntry`](https://developer.apple.com/documentation/uikit/uitextinputtraits/1624427-issecuretextentry) — маскирование пароля.
- [`UITextField.rightView`](https://developer.apple.com/documentation/uikit/uitextfield/rightview) и [`rightViewMode`](https://developer.apple.com/documentation/uikit/uitextfield/1619607-rightviewmode) — кнопка-«глаз» внутри поля.
- [`UITextView`](https://developer.apple.com/documentation/uikit/uitextview) и [`UITextViewDelegate`](https://developer.apple.com/documentation/uikit/uitextviewdelegate) — многострочный ввод; `isScrollEnabled = false` + `sizeThatFits(_:)` для auto-grow.
- [`UIPageViewController`](https://developer.apple.com/documentation/uikit/uipageviewcontroller) — контейнер для wizard-flow между шагами.
- [`UIView.keyboardLayoutGuide`](https://developer.apple.com/documentation/uikit/uiview/3752221-keyboardlayoutguide) — один-строчная привязка к клавиатуре (iOS 15+).
- [`UIResponder.keyboardWillChangeFrameNotification`](https://developer.apple.com/documentation/uikit/uiresponder) — фолбэк для iOS 14 и ниже.
- [`UITextInputTraits`](https://developer.apple.com/documentation/uikit/uitextinputtraits) — `autocapitalizationType`, `autocorrectionType`, `spellCheckingType`, `returnKeyType`, `keyboardType`.
- [HIG — Forms](https://developer.apple.com/design/human-interface-guidelines/text-fields) — Apple про text fields, валидацию, password rules.

→ [Глава 31. Cookbook: дата, время, деньги](./48-cookbook-date-money.md)
