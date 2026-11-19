# miraprint

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

---

## Arca (ERA terminal ko'prigi)

Miraprint endi Mirasoft sayti va ARCA (ERA) terminali o'rtasidagi ko'prik vazifasini ham bajaradi.
Ikkita lokal server bitta ilovada ishlaydi:

| Server | Manzil | Vazifasi |
|---|---|---|
| Printer | `http://127.0.0.1:49153` | `GET /printers`, `POST /print` (chek chiqarish) |
| Arca | `https://127.0.0.1:17865` | sayt → `wss://<terminal ip>:<port>` (ARCA) → javob saytga |

Sayt `POST https://127.0.0.1:17865/` ga JSON yuboradi:

| Maqsad | Tana |
|---|---|
| Terminalni tekshirish | `{"terminal":{"ip":"...","port":8888}}` → `{"type":"check_result","success":true/false}` |
| Buyruq yuborish | `{"terminal":{...},"request":{"id":"...","command":"Login","data":{...}}}` |

- `type` ixtiyoriy: `request` bor bo'lsa — buyruq, yo'q bo'lsa — tekshirish.
- Terminalga **faqat `request`** yuboriladi, javob **o'zgarishsiz** HTTP 200 JSON bo'lib qaytadi.
- Ulanib bo'lmasa: `{"type":"bridge_error","requestId":...,"command":...,"code":"TERMINAL_UNREACHABLE"|"TERMINAL_TIMEOUT"|"BAD_REQUEST","message":...}`.
- `Sale` natijasi noma'lum qolsa, ilova uni avtomatik qayta yubormaydi.

Kod: `lib/service/arca/`, `lib/bloc/arca_bloc/`, UI: `lib/ui/home/widget/arca_status_card.dart`.
Sozlamalar (`lib/core/app_constants.dart`): `kArca*`.

### Release'dan oldin (MUHIM)

1. **`kArcaRestrictOrigins = true`** — ⚠️ **eng muhimi.** Hozir ilova **istalgan saytdan** kelgan
   so'rovni qabul qiladi. Release'da bu xavfli: foydalanuvchi ochgan har qanday sayt lokal ilova
   orqali terminalga buyruq (`Sale`, `CloseZReport`...) yuborishi mumkin. Yoqilganda faqat
   `https://*.mirasoft.io` ruxsat etiladi (`kArcaAllowedOriginDomain`).
2. **`kArcaLogBodies = false`** — hozir Arca so'rov/javob tanalari (login, parol, chek) logga to'liq
   yoziladi. (Printer serverining `requestLoggingMiddleware`i ham tanalarni yozadi — shuni ham ko'rib chiqing.)
3. **HTTPS sertifikati** — har bir kompyuter uchun alohida yaratiladi. Windows installer
   (`windows/installer/miraprint.iss`): `miraprint.exe --generate-cert "%PROGRAMDATA%\MirasoftArca\cert"`
   bilan yaratadi va `certutil -addstore -f Root` bilan Windows "Trusted Root"ga o'rnatadi
   (Chrome/Edge shunga ishonadi; Firefox o'z ro'yxatidan foydalanadi). Installer administrator
   huquqini so'raydi. **Windows installer hali Windows kompyuterda sinalmagan.**
4. **ARCA `wss` sertifikati** — hozir faqat aynan shu `ip:port` uchun sertifikat xatosi e'tiborsiz
   qoldiriladi (`WssArcaClient`, `TODO`). Ishonchli tekshirish usuli hal qilinishi kerak.

### Test uchun (macOS)

- Birinchi ishga tushishda ilova sertifikatni o'zi yaratadi:
  `~/Library/Containers/io.mirasoft.miraprint/Data/Library/Application Support/io.mirasoft.miraprint/cert/localhost.crt`
- Brauzer ishonishi uchun bir marta:
  `security add-trusted-cert -r trustRoot -p ssl -k ~/Library/Keychains/login.keychain-db "<yuqoridagi yo'l>"`
- Terminal ERP rejimida bo'lishi kerak (aks holda `Connection refused`).
- `flutter test` — soxta ARCA (wss), sertifikat yaratish va o'yin mantig'ini tekshiradi.
