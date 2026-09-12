# Miraprint — Reja

## 1. Muammo

- POS web sayt do'konlarda sotuv jarayonida ishlatiladi.
- Sotuv oxirida chek chiqarilishi kerak, lekin brauzer/web sayt printerga to'g'ridan-to'g'ri chiqa olmaydi.
- Buning uchun kompyuterda fonda ishlaydigan kichik desktop dastur bo'lishi kerak: u web saytdan so'rov qabul qilib, printerga chek chiqaradi.
- Eski yechim — C# (WinForms) dastur, faqat Windows'da ishlaydi, GDI+ orqali chekni "rasm" qilib chizib, OS print-spooler orqali chop etadi. Uni yangilash noqulay.
- Yangi yechim **Flutter**da yoziladi: **mac va windows** uchun, chek OS-spooler orqali emas, **ESC/POS xom baytlar** ko'rinishida to'g'ridan-to'g'ri printerga yuboriladi.

## 2. Umumiy arxitektura

```
Web sayt (brauzer)
      │  HTTP so'rov (GET /printers, POST /print)
      ▼
Flutter desktop app (mac / windows)
  ├── HTTP server (127.0.0.1:49153)      — shelf + shelf_router
  ├── Chek generatori (ESC/POS baytlar)  — esc_pos_utils_plus
  └── Printer ulanish qatlami            — platformaga xos "raw write"
              │
              ▼
        Fizik chek printeri (asosan USB, keyinchalik boshqa usullar ham)
```

Muhim tamoyil: dastur **server** rolida — web sayt unga so'rov yuboradi, u esa printerga yozadi. Chek matni, jadval, logo, shtrix kod, qog'oz kesish — hammasi bitta bayt oqimi (ESC/POS) sifatida tayyorlanadi va printerga **o'zgarishsiz** yuboriladi (OS hech narsani qayta chizmaydi).

## 3. Kutubxonalar (`pubspec.yaml`)

| Kutubxona | Vazifasi |
|---|---|
| `shelf` | HTTP server yadrosi |
| `shelf_router` | `/printers`, `/print` yo'llarini boshqarish |
| `esc_pos_utils_plus` | Chekni ESC/POS xom baytlariga aylantiruvchi generator (matn, jadval qatori, rasm, shtrix kod, kesish) |
| `image` | Yuklab olingan logotip baytlarini `Image` obyektiga aylantirish (generator uchun) |
| `win32` | Windows'da printerga xom baytlarni to'g'ridan-to'g'ri yozish (`winspool.drv`) |
| `http` | Chek logotipini URL'dan yuklab olish |
| `printing` | Faqat o'rnatilgan printerlar ro'yxatini olish (mac+windows), chop etish uchun ishlatilmaydi |
| `flutter_bloc` | UI state boshqaruvi (server holati, printer tanlash va h.k.) |
| `equatable` | Bloc state/event klasslarini solishtirish uchun |
| `logging` | Markazlashgan, strukturaviy log (hozircha faqat konsolga) |

macOS'da xom bayt yozish uchun alohida kutubxona shart emas — CUPS'ning `lp -o raw` buyrug'i `dart:io Process` orqali chaqiriladi.

## 4. Arxitektura (papka tuzilmasi)

`onebuy-flutter-mobile`dagi bilan mos naqsh — bloc/service/model bo'linishi:

**Haqiqiy holat (2026-08-28, Bosqich 7dan keyin):**

```
lib/
  main.dart                          — MyApp + runApp()

  core/
    app_logger.dart                  — markazlashgan logger
    app_constants.dart               — kHttpPort va h.k.

  model/
    printer/
      printer_info.dart
      print_request.dart
      print_response.dart
    receipt/
      receipt_data.dart
      header_item.dart
      receipt_item.dart
      total_item.dart

  service/
    http/
      http_service.dart              — faqat server yaratish/ishga tushirish
      route/
        printers_route.dart          — GET /printers logikasi
        print_route.dart             — POST /print logikasi
    printer/
      printer_connection.dart        — abstraksiya (interfeys) + forPlatform factory
      mac_raw_printer_connection.dart
      windows_raw_printer_connection.dart
    receipt/
      receipt_builder.dart           — ESC/POS bayt generatori
      cp1251_codec.dart              — kirill matn uchun qo'lda yozilgan CP1251 kodlash

  bloc/
    server_bloc/
      server_bloc.dart
      server_event.dart
      server_state.dart

  ui/
    home/
      screen/
        home_screen.dart             — printer ro'yxati + Test Print (diagnostika)
      widget/
        server_status_widget.dart
```

(Dastlabki rejadagi `model/printer_info.dart` (flat), `ui/home/home_page.dart` kabi yo'llar — amalda `model/printer/`, `ui/home/screen/home_screen.dart` bo'lib chiqdi, alohida `app.dart` yozilmadi — `MyApp` `main.dart`ning o'zida.)

Qoida: har bir fayl **bitta vazifaga** javobgar bo'ladi. `http_service.dart` faqat server yaratadi/to'xtatadi — endpoint logikasi `route/` papkasiga chiqadi. Shu tufayli hech bir fayl kattalashib ketmaydi.

## 5. Bosqichlar

### Bosqich 0 — Kutubxonalar (bajarildi)
`flutter_bloc`, `equatable`, `logging` qo'shiladi (arxitektura uchun). `image` paketi keyinroq (logo bosqichida) qo'shildi.

### Bosqich 1 — HTTP server skeleti (bajarildi)
- Mavjud `lib/services/http_service.dart`dagi kod yangi tuzilmaga ko'chiriladi: `service/http/http_service.dart` (faqat server yaratish) + `service/http/route/printers_route.dart` (GET /printers logikasi).
- `core/constants/app_constants.dart` — `kHttpPort` shu yerga ko'chadi.
- `core/logging/app_logger.dart` — logger qo'shiladi, `http_service.dart`da ishlatiladi.
- CORS middleware qo'shiladi.
- `bloc/server_bloc/` — server holatini (`initial → starting → running → error`) boshqaradi.
- `ui/home/home_page.dart` — `BlocBuilder` bilan server holatini ko'rsatadi.
- `POST /print` (stub) — keyingi qismda, shu bosqich ichida oxirida qo'shiladi.

### Bosqich 2 — Ma'lumot modellari (bajarildi)

JSON kontrakt eski C# ilova (`MainForm.cs`, 845-895 va 243-264-qatorlar) bilan **aynan bir xil** saqlanadi — veb-sayt tarafida hech narsa o'zgarmaydi. Deserializatsiya case-insensitive, shu sababli faqat pastki chiziqli maydonlarga aniq JSON key kerak.

**`ReceiptData`** (`lib/model/receipt/receipt_data.dart`) — chekning o'zi:
| Dart maydon | JSON key | Tur | Vazifa |
|---|---|---|---|
| `logo` | `logo` | `String` | URL — chekning tepasiga rasm sifatida chiziladi |
| `currentNumber` | `current_number` | `String` | Navbat raqami — 24pt, markazlashtirilgan |
| `headers` | `headers` | `List<HeaderItem>` | Sarlavha qatorlari; `title == "Компания"` bo'lsa qalin shrift |
| `items` | `items` | `List<ReceiptItem>` | Mahsulotlar |
| `totals` | `totals` | `List<TotalItem>` | Summalar (jami, chegirma, sdacha va h.k.) |
| `barcode` | `barcode` | `String` | Pastda shtrix-kod sifatida chiziladi |

**`HeaderItem`** (`header_item.dart`): `title`(`title`), `val`(`val`) — ikkalasi ham `String`.

**`ReceiptItem`** (`receipt_item.dart`): `name`(`name`, `String`), `qty`(`qty`, `int`), `price`(`price`, `String` — **tayyor formatlangan matn, raqam emas**), `totalPrice`(`total_price`, `String`), `discountText`(`discount_text`, `String?`), `discountPrice`(`discount_price`, `String?`) — chegirma qatori faqat ikkalasi ham bo'sh bo'lmasa chiqadi.

**`TotalItem`** (`total_item.dart`): `title`(`title`), `val`(`val`), `big`(`big`, `bool` — katta shrift + qo'shimcha bo'shliq), `light`(`light`, `bool`, **eski kodda deklaratsiya qilingan lekin render logikasida hech qayerda ishlatilmagan** — saqlab qolinadi, kelajakda kulrang/ingichka matn uchun ishlatilishi mumkin).

**`PrintRequest`** (`print_request.dart`): `printer`(`printer`, `PrinterInfo`), `check`(`check`, `ReceiptData`) — `POST /print` tanasi shu klass.

**`PrinterInfo`** (`printer_info.dart`) — ham `PrintRequest.printer`da (so'rov), ham `GET /printers` javobida (ro'yxat elementi) ishlatiladi: `name`(`name`, `String`), `vendorId`(`vendorId`, `String`), `productId`(`productId`, `String`), `isDefault`(`isDefault`, `bool`, faqat javobda ma'noli — so'rovda odatda `false`). Eski ilovada `vendorId`/`productId` doim bo'sh qaytarilgan ("USB orqali olish qiyin" izohi bilan); yangi Flutter ilova buni USB orqali real to'ldirishi kerak — Bosqich 3dagi `PrinterConnection` shu maqsadda.

**`PrintResponse`** (`print_response.dart`) — `POST /print` javobi, eski ilovada anonim `{success, message}` obyekt edi: `success`(`success`, `bool`), `message`(`message`, `String`).

### Bosqich 3 — `GET /printers` to'liq ishga tushirish (kod tayyor, hali jismoniy printer bilan sinalmagan)
- **Foydalanuvchi qarori (2026-08-28):** eski rejada bu ish Bosqich 5ga (Endpointlarni ulash) qoldirilgan edi, lekin bu noto'g'ri tartib — `GET /printers` uchun `PrinterConnection`/ESC/POS generatori shart emas, faqat `PrinterInfo` modeli kifoya. Shu sababli bu bosqich oldinga ko'chirildi: model klasslar tayyor bo'lishi bilanoq (Bosqich 2 tugagach) darhol shu ishga o'tiladi, printer ulanish/chek generatori kutilmaydi.
- `http_service.dart`dagi hozirgi `handleGetPrinters` — **stub**, doim bo'sh massiv (`[]`) qaytaradi.
- Uni `printing` paketi (`Printing.listPrinters()`) orqali kompyuterdagi haqiqiy o'rnatilgan printerlar ro'yxatini olib, har birini `PrinterInfo.toJson()` bilan (`name`, `vendorId`, `productId`, `isDefault`) JSON massiv sifatida qaytaradigan qilib to'ldirish.
- `vendorId`/`productId` — `printing` paketi bermasa, hozircha bo'sh string qoldiriladi (eski C# ilova ham shunday qilgan); USB orqali haqiqiy vendor/product ID olish alohida masala, kerak bo'lsa keyinroq alohida muhokama qilinadi.

### Bosqich 4 — Printer ulanish qatlami (abstraksiya) (bajarildi; Windows qismi hali haqiqiy Windows'da sinalmagan)
- `PrinterConnection` interfeysi: `Future<void> sendRaw(List<int> bytes)` + `factory PrinterConnection.forPlatform(String printerName)` (Platform.isMacOS/isWindows bo'yicha tanlaydi).
- `WindowsRawPrinterConnection` — `win32` orqali `winspool` (`OpenPrinter` → `StartDocPrinter(RAW)` → `StartPagePrinter` → `WritePrinter` → `EndPagePrinter`/`EndDocPrinter`/`ClosePrinter`).
- `MacRawPrinterConnection` — CUPS `lp -o raw -d <printer>` orqali (`Process.start`, stdin'ga baytlar yozib yuboriladi); printersiz, noto'g'ri printer nomi bilan xato yo'li sinaldi va tasdiqlandi.
- Hozircha faqat **USB/o'rnatilgan printer** stsenariysi; kelajakda tarmoq (`NetworkPrinterConnection`) yoki boshqa usullar shu interfeys orqali qo'shiladi.

### Bosqich 5 — Chek generatori (bajarildi, 2026-09-04'da qayta yozildi)
- **Birinchi versiya (ESC/POS matn + CP1251) — real printerda ishlamadi, olib tashlandi:**
  - Boshida `receipt_builder.dart` matnni `esc_pos_utils_plus`ning `generator.text()`/`generator.row()` orqali, qo'lda yozilgan CP1251 kodlash (`cp1251_codec.dart`, endi o'chirilgan) va `setGlobalCodeTable('CP1251')` (kod jadvali ID=46, kutubxonaning "default" profilidan) bilan yasagan.
  - **Haqiqiy xPrinter (`Printer_POS_80`, 80mm) bilan sinalganda kirill matn (`Компания`) doimiy ravishda buzuq chiqdi.** Sabab qidirilib, ko'plab tajriba o'tkazildi: turli kod jadvali ID'lari (0-255 oralig'idan bir nechtasi), Kanji (ikki baytli) rejimni majburan o'chirish (`FS .`), printerni qayta yoqish, hatto printerning o'z self-test sahifasidan olingan **rasmiy** ID (`73: WPC1251 (Cyrillic)`) — birortasi ham barqaror ishlamadi.
  - **Yakuniy xulosa:** printerning self-test sahifasida "Resident Character: Alphanumeric, Simplified Chinese GB18030" deb ko'rsatilgan — ya'ni bu aniq printer modelida kirill uchun **haqiqiy hardware/firmware qo'llab-quvvatlovi yo'q** (faqat lotin-raqamli va xitoycha). ESC/POS matn+kod-jadvali yo'li bu klass qurilmalar uchun printerga qarab tamomila ishonchsiz bo'lishi mumkin.
  - Bonus topilma: printer quvvat yoqilgandan keyingi **birinchi** print job'ida ma'lumotning boshlang'ich qismini yo'qotadi (keyingi job'lar barqaror) — shuning uchun "sovuq" holatdagi sinovlar chalg'ituvchi bo'lishi mumkin.
- **Yangi versiya (Canvas → rasm, eski C# ilova qilgan yo'lning o'zi):**
  - Eski C# ilova (`~/Desktop/PrinterTestApp — Latest/MainForm.cs`) hech qachon bu muammoga duch kelmagan, chunki u matnni printerga bayt sifatida yubormagan — GDI+ (`Graphics.DrawString`) orqali to'g'ridan-to'g'ri piksellarga chizib, Windows drayveri orqali chiqargan. Printer faqat tayyor qora/oq nuqtalarni ko'rgan, "qaysi harf" degan savol umuman bo'lmagan.
  - Shu tamoyil endi Flutter'da takrorlandi: **`lib/service/receipt/receipt_canvas_renderer.dart`** — `dart:ui`/`Canvas`/`TextPainter` orqali navbat raqami, header'lar (`Компания` qalin), mahsulotlar (nom + miqdor/narx qatori + chegirma), jami summalar (`big` bo'lsa kattaroq shrift) — hammasi bitta rasm (`img.Image`, `package:image`) sifatida chiziladi, so'ng `receipt_builder.dart`da `generator.image(...)` orqali printerga yuboriladi. Endi shrift o'lchamlarini ESC/POS'ning 1x/2x/3x cheklovisiz, eski ilovadagiga yaqin **aniq nisbatlarda** (masalan mahsulot nomi headerdan ~20% katta, ESC/POS'dagi 2x emas) sozlash mumkin.
  - `cp1251_codec.dart` butunlay o'chirildi — endi kerak emas.
  - **Shtrix kod (`generator.barcode(Barcode.code128(...))`) o'zgarishsiz qoldi** — bu native ESC/POS buyrug'i, lekin ma'lumoti doim ASCII raqamlar bo'lgani uchun kirill-kod-jadvali muammosiga umuman aloqasi yo'q.
  - Haqiqiy printerda (`Printer_POS_80`) to'liq chek — logotip, kirill header/mahsulot nomi, summalar, shtrix kod — sinaldi va **muvaffaqiyatli, to'g'ri chiqdi** (2026-09-04).
- **Logo (o'zgarishsiz, 2026-08-28'da qo'shilgan):** `lib/service/receipt/logo_loader.dart` — `receipt.logo` URL'idan rasm yuklaydi (`http`, 5 soniya timeout), `image` paketi bilan dekodlaydi va bosma kenglikka nisbatini saqlab moslashtiradi (`maxWidth` endi 520 — 80mm qog'ozning 576 nuqta kengligiga mos, xavfsizlik uchun biroz kam). Eski C# ilovadagi kabi **har qanday xatoda (tarmoq, timeout, buzilgan rasm) jim `null` qaytaradi**.
- **Qog'oz o'lchami muhim tuzatish (2026-09-04):** `Generator(PaperSize.mm80, ...)` — boshida xato ravishda `mm58` ishlatilgan edi, lekin haqiqiy printer 80mm (`POS-80`, self-test sahifasida "Printing width: 72mm" = 576 nuqta, `mm80.width` bilan mos).

### Bosqich 6 — `POST /print` endpointini ulash (bajarildi)
- JSON'ni `PrintRequest`ga aylantiradi → `receipt_builder` bilan baytlarni yasaydi → tanlangan `PrinterConnection` orqali printerga yuboradi → `PrintResponse` (`success`, `message`) JSON qaytaradi.
- Foydalanuvchi Postman orqali sinadi: mavjud bo'lmagan printer nomi bilan `400` + `{"success": false, "message": "Exception: Printerga yuborib bo'lmadi (test_printer): lp: No such file or directory"}` — kutilgan xato yo'li to'g'ri ishladi, butun zanjir (JSON parse → receipt_builder → PrinterConnection) tasdiqlandi.

### Bosqich 7 — UI (diagnostika paneli) (bajarildi va vizual tasdiqlangan)
- Skrinshotda tekshirildi: server holati (`ServerStatus.running`), "Printer topilmadi" xabari (printer yo'qligi uchun to'g'ri) va "Test Print" tugmasining avtomatik disabled bo'lishi (printer tanlanmagan holatda) — barchasi kutilganidek ishladi.
- **Foydalanuvchi qarori (2026-08-28):** bu UI haqiqiy sotuv oqimiga aloqasi yo'q — sotuv paytida chekni web sayt o'zi `POST /print` orqali chiqaradi, kassir bu ilova UI'siga umuman tegmaydi. Bu ekran faqat **o'rnatish/nosozlikni tekshirish** uchun (printer to'g'ri ulanganmi, server ishlayaptimi).
- `ui/home/home_page.dart` — `main.dart`dagi inline `HomeScreen`dan ko'chiriladi.
- `ui/home/widget/server_status_widget.dart` (`ServerStatusWidget`) — server holatini ko'rsatuvchi widget (bajarildi).
- Printer ro'yxati: `Printing.listPrinters()` to'g'ridan-to'g'ri chaqiriladi (xuddi `GET /printers` ichida ishlatilgandek) — dropdown sifatida ko'rsatiladi.
- "Test Print" tugmasi: namuna `ReceiptData` bilan `buildReceiptBytes` → tanlangan printerga `PrinterConnection.forPlatform(...).sendRaw(...)` — natija (muvaffaqiyat/xato) ekranda ko'rsatiladi.
- Holat boshqaruvi: oddiy `StatefulWidget`/`setState` bilan (bu — ekranga xos, global bo'lmagan holat; `ServerBloc`dagi kabi alohida bloc ortiqcha bo'lardi).
- **"Chekni ko'rish" (2026-08-28):** haqiqiy printersiz chekni tekshirish uchun `ui/home/widget/receipt_preview.dart` — `ReceiptData`ni `receipt_builder.dart` bilan bir xil tartibda (header/items/totals/barcode/logo) Flutter widget sifatida chizadi, ESC/POS baytlarsiz.
- **Real vaqtli oxirgi chek ko'rinishi (2026-08-28):** `lib/service/receipt/last_receipt_notifier.dart` — global `ValueNotifier<ReceiptData?>`. `print_route.dart`dagi `handlePostPrint` har bir so'rovni parse qilgach (chop etish muvaffaqiyatli/muvaffaqiyatsiz bo'lishidan qat'i nazar) shu notifier'ga yozadi. `home_screen.dart`da yangi karta (`ValueListenableBuilder` + `ReceiptPreview`) shuni tinglab, Postman orqali `POST /print` yuborilganda UI'da avtomatik yangilanadi — printersiz, veb-sayt integratsiyasini to'liq vizual tekshirish imkonini beradi.

### Bosqich 8 — Xatoliklar va mustahkamlik
- Printer topilmasa, server porti band bo'lsa, logotip yuklanmasa — foydalanuvchiga aniq xabar.
- Loglash (konsolga yoki faylga).

### Bosqich 9 — Build va tarqatish
- macOS entitlements (bajarildi, 2026-08-28): `network.server` (HTTP serverni qabul qilish uchun) + `network.client` (logotipni URL'dan yuklash kabi chiquvchi so'rovlar uchun) — ikkalasi ham endi **Debug va Release**da bor. `network.client` yo'qligi sabab bo'lib, ilova ichida (`Image.network`, `loadLogoImage`) logotip yuklanmagan edi (`dart run`da sandboxsiz ishlagani uchun bu muammo o'shanda ko'rinmagan edi) — endi tuzatildi.
- Windows: `.exe` build, avtomatik yangilanish masalasi (bu loyihaning asosiy sababi — keyinroq alohida muhokama qilinadi).

### Bosqich 10 — X tugmasi bosilganda ham fonda ishlashda davom etish (tray)

- **Muammo:** hozir oyna X (window close) tugmasi bilan yopilsa, butun process — demak HTTP server ham — to'xtaydi. Web sayt endi `/print`ga so'rov yubora olmaydi, chek chiqmaydi. Eski C# ilovada ham xuddi shunday edi — tekshirildi: `MainForm.cs:141-149`dagi `FormClosing` faqat `httpListener.Stop()/Close()` chaqiradi, tray ikonkasi yoki "yashirish" logikasi yo'q edi.
- **Yechim:** X bosilganda ilova butunlay chiqib ketmaydi, balki oyna **tray (menu bar / system tray) ikonkasiga yashiriniladi**, server fonda ishlashda davom etadi. Tray ikonkasi ustiga bosilganda kontekst menyu: **"Ochish"** (oynani qaytarib ko'rsatish) va **"Chiqish"** (haqiqiy to'xtatish — server ham to'xtaydi, process tugaydi).
- **Kutubxona:** `tray_manager` qo'shiladi (`window_manager` allaqachon `pubspec.yaml`da bor, hozircha faqat oynani ochishda ishlatilgan).
- **macOS uchun muhim tuzatish:** `macos/Runner/AppDelegate.swift`dagi `applicationShouldTerminateAfterLastWindowClosed` hozir `true` qaytaryapti — bu degani, oynani shunchaki `hide()` qilsak ham, macOS "oxirgi oyna yopildi" deb ilovani baribir butunlay o'chirib yuboradi. Shu funksiya `false` qaytaradigan qilib o'zgartiriladi.
- **Windows'da** bu muammo yo'q (process oyna yopilgandan keyin ham davom etaveradi), lekin bir xil `window_manager`/`tray_manager` kodi ikkala platformada ham ishlaydi — platformaga qarab shart yozilmaydi.
- **Qadamlar:** 1) `pubspec.yaml`ga `tray_manager` qo'shish, 2) tray uchun ikonka fayli tayyorlash (macOS — kichik `.png`, Windows — mavjud `windows/runner/resources/app_icon.ico` qayta ishlatiladi), 3) `AppDelegate.swift` tuzatish, 4) `main.dart`da `WindowListener` (`onWindowClose` → `hide()`) + `TrayListener` (menyu: Ochish/Chiqish) ulash, 5) real build bilan sinash (X bosish → oyna yo'qoladi, server ishlab turadi, tray'dan qaytarish/chiqish ishlaydi).
- **Bajarildi (2026-09-12):** `lib/service/window/app_window_service.dart` (`AppWindowService`, `WindowListener`+`TrayListener`) yaratildi va `main.dart`da ulandi. `AppDelegate.swift`ga yana bitta metod qo'shildi — `applicationShouldHandleReopen`: `hide()` bilan yashirilgan oyna Dock ikonkasiga bosilganda avtomatik qaytmagani uchun (macOS'ning standart "reopen" xatti-harakati ordered-out oynalarni qaytarmaydi), bu yerda oynalar qo'lda `makeKeyAndOrderFront` bilan qaytariladi. Dock ikonkasi ataylab **ko'rinishda qoldirildi** (foydalanuvchi qarori) — kassir uchun oynani qaytarishning qo'shimcha, zaxira yo'li.
- **Qo'shimcha topilgan/tuzatilgan muammo — oyna startda avval kichik o'lchamda ochilib, keyin kattalashishi:**
  - Birinchi urinish (`windowManager.maximize()`ni `show()`dan keyinga surish, keyin `screen_retriever` bilan Dart tomonda `WindowOptions.size`ni ekran ish maydoniga o'rnatish) muammoni to'liq hal qilmadi — chunki Dart kodi har doim macOS oynani birinchi marta ekranga chiqarishidan **keyinroq** ishga tushadi, shu bilan bir lahzalik "kichik oyna" muqarrar qolaverdi.
  - **Haqiqiy sabab va yechim** — `pos_app` (`~/StudioProjects/pos_app`) tekshirildi: u umuman `window_manager`/`screen_retriever` ishlatmaydi. O'lcham to'g'ridan-to'g'ri **native** kodda, Dart ishga tushishidan oldin belgilanadi: macOS'da `macos/Runner/MainFlutterWindow.swift`ning `awakeFromNib()`ida `NSScreen.main.visibleFrame` bilan (`pos_app/macos/Runner/MainFlutterWindow.swift:9-21`), Windows'da `windows/runner/main.cpp`da `SPI_GETWORKAREA` bilan (`pos_app/windows/runner/main.cpp:47-58`).
  - Shu tamoyil Miraprint'ning `macos/Runner/MainFlutterWindow.swift`iga ham qo'llanildi: `awakeFromNib()`da oyna `NSScreen.main.visibleFrame`ga o'rnatiladi — hali ekranga birinchi marta chiqarilmasdan turib. `screen_retriever` paketi endi keraksiz — `pubspec.yaml`dan olib tashlandi.
  - **Ikkinchi topilma — `window_manager`ning o'zi orqaga qisib qo'ygan:** native frame to'g'ri o'rnatilgandan keyin ham oyna ~96%da qolayotgani debug bilan aniqlandi (`self.frame(after)` aynan `screen.visibleFrame`ga teng ekani tasdiqlandi — demak muammo native kodda emas). Sabab: `window_manager`ning Dart kodidagi `waitUntilReadyToShow()` (`window_manager.dart:137`) oyna allaqachon ekranni to'liq egallagani uchun uni `isZoomed == true` (= "maximized") deb hisoblab, avtomatik `unmaximize()` (`NSWindow.zoom(nil)`) chaqirib, orqaga qisib qo'yar ekan.
  - **Yakuniy, pos_app'ga to'liq mos yechim:** pos_app umuman `window_manager`ning `show()`/`waitUntilReadyToShow()`/`maximize()` funksiyalarini chaqirmaydi — oyna faqat native kodda joylanadi, ko'rsatilishini esa macOS'ning standart Cocoa ilova ishga tushish jarayonining o'ziga qoldiradi. Xuddi shunday, `main.dart`dan `waitUntilReadyToShow`/`show`/`focus`/`maximize` chaqiruvlari butunlay olib tashlandi — faqat `windowManager.ensureInitialized()` qoldirildi (bu vizual ta'sirsiz, faqat `AppWindowService`ning tray/`onWindowClose` funksiyalari ishlashi uchun kerak). Oyna sarlavhasi ham `window_manager`siz ishlaydi — `MainMenu.xib`dagi `title="APP_NAME"` AppKit'ning maxsus placeholder'i, `Info.plist`dagi `CFBundleName`ga avtomatik almashadi.
  - **Windows uchun ham qo'llanildi (2026-09-12, hali Windows'da sinalmagan):** `windows/runner/main.cpp`da qattiq belgilangan `Win32Window::Size size(1280, 720)` o'rniga, pos_app'dagi kabi `SPI_GETWORKAREA` bilan ish maydoni oldindan hisoblanib, oyna boshidanoq shu o'lchamda yaratiladi. Bu ayni zarur edi — `main.dart`dan `maximize()` chaqiruvi butunlay olib tashlangani (yuqoridagi bandda) Windows uchun ham ta'sir qilgan bo'lardi, aks holda ilova endi hech qachon to'liq ekranga moslashmay, doim 1280x720'da ochilib qolar edi.
  - **Fonda ishlash (tray) Windows'da tekshirildi (kod darajasida):** `window_manager`ning Windows plugin manbasi (`window_manager_plugin.cpp:319-323`) `WM_CLOSE`ni xuddi macOS'dagidek ushlab, `setPreventClose(true)` bo'lsa native yopilishning oldini oladi — shuning uchun `AppWindowService` qo'shimcha o'zgarishsiz Windows'da ham ishlashi kerak. `windows/runner/win32_window.cpp:182-187`dagi `quit_on_close_` faqat haqiqiy `WM_DESTROY`da ishlaydi, `window_manager` xabarni `WM_CLOSE` bosqichida "yutib qo'ygani" uchun bunga yetib bormaydi.

## 6. Ish uslubi

- Har bosqich kichik va real (toy misollar yo'q) — to'g'ridan-to'g'ri yakuniy kodning bir qismi.
- Foydalanuvchi kodni o'zi yozadi, men tushuntiraman va tekshiraman.
- Har bosqich tugagach — birga sinovdan o'tkazamiz (curl, `flutter run`), keyin keyingi bosqichga o'tamiz.

## 7. Ochiq savollar (keyinroq hal qilinadi)

- Windows'da eski C# app bilan portlar/joylar to'qnashmasligi (ikkalasi ham 49153 ishlatadi — bir vaqtda ishlamasligi kerak).
- Avtomatik yangilanish mexanizmi (bu loyihaning asosiy maqsadi — qanday amalga oshirilishi alohida muhokama qilinadi).
- Tarmoq orqali ulanadigan printerlar qo'shilsa, `PrinterConnection` interfeysiga yangi implementatsiya qo'shiladi, xolos.
