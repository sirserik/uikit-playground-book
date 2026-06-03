# Глава 43. Production: accessibility audit перед релизом

Финальная глава книги. Перед каждым релизом — пройди этот чек-лист.
Это **обязательно** по Apple guidelines и часто решает 5-10% юзеров.

## 43.1 Полный чек-лист

### VoiceOver
- [ ] Каждый интерактивный элемент имеет `accessibilityLabel`.
- [ ] Иконки без текста — `accessibilityLabel` явно.
- [ ] Декоративные view'ы — `isAccessibilityElement = false`.
- [ ] Cell'ы группированы в один элемент (не читаются по 5 строк).
- [ ] Custom actions для swipe-actions (`accessibilityCustomActions`).
- [ ] Тестирование пройдено: включить VoiceOver (`Cmd+F5` в симуляторе)
      и пройти main flow.

### Dynamic Type
- [ ] Все тексты используют `UIFont.preferredFont(forTextStyle:)`.
- [ ] `adjustsFontForContentSizeCategory = true` везде.
- [ ] Custom fonts через `UIFontMetrics.scaledFont(for:)`.
- [ ] Таблицы с `automaticDimension` + `numberOfLines = 0`.
- [ ] Test на максимальном размере (Settings → Display & Brightness
      → Text Size → max).

### Color contrast
- [ ] Все текст-цвета имеют contrast 4.5:1 минимум (3:1 для large
      text ≥ 24pt).
- [ ] Custom colors проверены в Accessibility Inspector.
- [ ] `UIAccessibility.isDarkerSystemColorsEnabled` подхватывается.
- [ ] Кнопки имеют отличный border / shadow / contrast — не только
      цвет (для colorblind юзеров).

### Hit targets
- [ ] Min size 44×44 points для всех tappable элементов.
- [ ] Маленькие иконки имеют content insets для увеличения hit area.

### Motion
- [ ] Sophisticated animations проверены при
      `UIAccessibility.isReduceMotionEnabled`.
- [ ] Spring-анимации упрощены до fade при Reduce Motion.
- [ ] Parallax эффекты отключаются при Reduce Motion.

### Captions / subtitles
- [ ] Все важные UI-elements не зависят **только** от цвета (например,
      красная подсветка для error дополняется иконкой).
- [ ] Auto-play видео имеют captions если есть speech.

### Keyboard / Switch Control
- [ ] Все элементы доступны через keyboard (для iPad с external
      keyboard).
- [ ] Tab order логичный.
- [ ] Focused elements visible (есть focus indicator).

## 43.2 Accessibility Inspector

`Xcode → Open Developer Tool → Accessibility Inspector`.

Подключается к симулятору. Показывает:

- **Hierarchy** — все accessible elements.
- **Inspection** — выбрав элемент, видишь его label, traits, hint.
- **Audit** — автоматический поиск проблем:
  - Низкий contrast.
  - Слишком маленькие hit targets.
  - Отсутствие accessibilityLabel.
  - Дубликаты label.

Пройдись по всем главным экранам с включённым audit.

## 43.3 VoiceOver test scenarios

Минимум:

1. **Запуск приложения** — VoiceOver читает все элементы splash, главного
   экрана.
2. **Главное действие** — например, создание задачи. VoiceOver
   проводит через шаги.
3. **Список + детальный** — листание, открытие элемента.
4. **Modal / sheet** — могут ли закрыть.
5. **Form** — заполнение полей с keyboard hints.

Если что-то «не сказано» или «непонятно сказано» — нужен явный
`accessibilityLabel` / `accessibilityHint`.

## 43.4 Dynamic Type test scenarios

В Settings → Display & Brightness → Text Size → крайние позиции:

- **Минимум** (1-я позиция) — текст не должен быть нечитаемым (хотя
  ничто не сломается).
- **Default** — стандарт.
- **Большие шрифты** (max position): **проверь обязательно**:
  - Текст не обрезается.
  - Кнопки растягиваются вместе с текстом.
  - Multi-line корректно отображается.

В Accessibility → Display & Text Size → **Large Text → Larger
Accessibility Sizes** → ещё больше, в 4-5 раз. Здесь часто всё ломается.

## 43.5 Reduce Motion test

Settings → Accessibility → Motion → **Reduce Motion** → On.

Проверь:

- Spring-анимации стали fade'ами или мгновенными.
- Parallax эффекты отключены.
- Auto-play hero видео не играет.
- Modal transitions упрощены.

## 43.6 Color filter testing

Settings → Accessibility → Display & Text Size → Color Filters.

Симулирует разные типы дальтонизма:
- **Greyscale** — полная монохромная.
- **Red/Green Filter** — protanopia, deuteranopia.
- **Blue/Yellow Filter** — tritanopia.

Проверь:
- UI остаётся understandable.
- Кнопки различимы (не только по цвету).
- Error-states имеют иконку, не только цвет.

## 43.7 Test on actual device

Симулятор — приближение. На реальном устройстве:

- **VoiceOver** ощущается иначе (физические swipe'ы).
- **Touch targets** — пальцы больше чем mouse pointer.
- **Battery / performance** — анимации тормозят?
- **Slower devices** — на iPhone X / 8 анимации могут лагать.

Минимум — проверь на устройстве 2-3 года назад (не latest).

## 43.8 Localization

Если приложение многоязычное:

- [ ] Длинные слова в немецком / русском не обрезаются.
- [ ] RTL (Arabic, Hebrew) — `NSDirectionalEdgeInsets`, не
      `UIEdgeInsets`.
- [ ] Multi-line label growth tested.
- [ ] Numbers / dates / currency используют `NumberFormatter` /
      `DateFormatter` с локалью.

## 43.9 Performance regression

- [ ] App launch < 2 секунды на cold start.
- [ ] Main thread не блокирован дольше 16ms (60fps).
- [ ] Memory < 100MB при обычном использовании.
- [ ] Battery usage в Xcode Energy Inspector — нормальный.

`Instruments → Time Profiler` для нагрузки. `Allocations` для
памяти.

## 43.10 Final checklist перед submission

### Build
- [ ] Release configuration используется.
- [ ] Debug код (print, NSLog) удалён или гарантированно отключён.
- [ ] Version + build numbers обновлены.

### Permissions
- [ ] Все `NSXxxUsageDescription` в Info.plist человеческими словами.
- [ ] Permission primers перед системными диалогами.
- [ ] App работает корректно при denied permissions (graceful
      degradation).

### App Store metadata
- [ ] Screenshots (Глава 38).
- [ ] App Privacy questionnaire (Глава 39).
- [ ] Privacy Manifest `.xcprivacy` (Глава 39).
- [ ] Описание приложения, keywords, support URL.

### Account / data
- [ ] Account deletion flow (Глава 40).
- [ ] Logout работает корректно.
- [ ] Data export если требуется (GDPR).

### Network
- [ ] HTTPS везде, не HTTP.
- [ ] Error handling для timeouts, 4xx, 5xx.
- [ ] Offline mode (или хотя бы informative banner — Глава 24).

### Submission
- [ ] Test flight перед submission.
- [ ] App Store review notes с тестовым аккаунтом.
- [ ] Demo video / instruction (если требуется).

## 43.11 После релиза

- **Crash reporting** — Firebase Crashlytics или Apple's Xcode
  Organizer.
- **Analytics** — Firebase, Mixpanel, или собственный.
- **A/B testing** — Firebase Remote Config + App Store screenshots
  (Глава 38).
- **App Store Connect Reviews** — следи и отвечай.
- **Apple Search Ads** для discovery.

## 43.12 Что мы выучили (вся книга)

Прошли путь от «пустого Xcode-проекта» до:

- **Foundation** (Часть I) — playground-инфраструктура: AppManifest,
  BootCoordinator, PlaygroundWindow, AnimatedSplash.
- **Launch gates** (Часть II) — onboarding, permission primer, auth
  (Login/Register/Forgot + Keychain), force-update / maintenance,
  region + age, privacy blur + biometric.
- **Mini-apps** (Часть III) — Todo, Notes, Calculator, Weather,
  Gallery, Music, Chat, Profile, Custom Tab Bar, Complex Layouts,
  Anatomy.
- **UI Cookbook** (Часть IV) — 60+ паттернов: loading, empty states,
  search, navigation, cells, modals, gestures, forms, date/money,
  animations, haptics, accessibility, theming, status indicators,
  photo viewer.
- **Production** (Часть V) — screenshots, Privacy Manifest, account
  deletion, push + deep links, widgets + App Intents, accessibility
  audit.

Каждый паттерн — **проверен на работающем коде** в companion-проекте
`beginner-testing-app`. Можешь клонировать репозиторий, запустить
любой mini-app, потрогать пальцами, забрать кусок в свой проект.

## 📋 Что мы выучили в этой главе

- **Полный чек-лист** перед релизом: VoiceOver, Dynamic Type, color
  contrast, hit targets, motion, captions, keyboard.
- **Accessibility Inspector** в Xcode — automated audit.
- **VoiceOver scenarios** — пройти main flow, найти «не сказанное».
- **Dynamic Type extremes** — тестировать на min и max размере.
- **Reduce Motion** — упрощать анимации.
- **Color filters** для colorblind testing.
- **Performance regression** — Time Profiler, Allocations.
- **Final submission checklist** — build, permissions, metadata,
  account, network, submission.

## Apple Developer Documentation

- [`UIAccessibility`](https://developer.apple.com/documentation/uikit/uiaccessibility) — корневой namespace с константами, notification'ами и helper-функциями для accessibility.
- [`UIAccessibilityIdentification`](https://developer.apple.com/documentation/uikit/uiaccessibilityidentification) — протокол `accessibilityIdentifier`, опора UI-тестов и audit-инструментов.
- [`UIAccessibilityElement`](https://developer.apple.com/documentation/uikit/uiaccessibilityelement) — программный элемент для случаев, когда `isAccessibilityElement` недостаточно (custom drawing, canvas).
- [`UIAccessibility.isVoiceOverRunning`](https://developer.apple.com/documentation/uikit/uiaccessibility/1615187-isvoiceoverrunning) — проверка, что VoiceOver включён; основа для условного рендеринга вспомогательных подсказок.
- [`UIAccessibility.isReduceMotionEnabled`](https://developer.apple.com/documentation/uikit/uiaccessibility/1615133-isreducemotionenabled) — флаг «уменьшить движение»; на нём вешаем упрощённые анимации.
- [`accessibilityElements`](https://developer.apple.com/documentation/objectivec/nsobject/1615147-accessibilityelements) — управляемый порядок чтения VoiceOver для контейнеров.
- [`UIFontMetrics`](https://developer.apple.com/documentation/uikit/uifontmetrics) — масштабирование кастомных шрифтов под Dynamic Type.
- [Accessibility Inspector](https://developer.apple.com/documentation/accessibility/accessibility-inspector) — встроенный инструмент Xcode для аудита иерархии и contrast'а.
- [HIG — Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility) — общая методичка по доступному дизайну (VoiceOver, Dynamic Type, контраст, motion).
- [HIG — Inclusion](https://developer.apple.com/design/human-interface-guidelines/inclusion) — про colorblind-дружественные палитры, локализацию и культурную чувствительность.

---

🎉 **Это конец книги.**

Спасибо, что прошёл этот путь. iOS разработка — большой мир, эта
книга — карта основных регионов. Дальше — практика на собственном
проекте.

→ Хочешь скачать companion-app или посмотреть исходники глав?
[Repository](https://github.com/sirserik/uikit-playground-book)
(когда опубликуем).

Удачи в App Store!
