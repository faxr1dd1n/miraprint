const int kHttpPort = 49153;

/// Yangilanish fayllari GitHub Releases'da turadi. `latest` doim eng oxirgi
/// release'ga yo'naltiradi. `/version.json` qismini `checkForUpdate()` qo'shadi.
const String kUpdateServerUrl =
    'https://github.com/faxr1dd1n/miraprint/releases/latest/download';

// ───────────── Arca (ERA terminal ko'prigi) ─────────────

/// Sayt murojaat qiladigan lokal manzil.
const int kArcaPort = 17865;

/// true — https://127.0.0.1:17865 (sertifikat har kompyuterda yaratiladi);
/// false — oddiy HTTP (faqat test uchun).
const bool kArcaUseTls = true;

/// TEST: false — har qanday domendan so'rov qabul qilinadi.
/// RELEASE'DA ALBATTA true QILING! (README.md → "Release'dan oldin")
const bool kArcaRestrictOrigins = false;

/// kArcaRestrictOrigins yoqilganda: faqat shu domen va uning subdomenlari
/// (`*.mirasoft.io`) HTTPS orqali ruxsat etiladi.
const String kArcaAllowedOriginDomain = 'mirasoft.io';

/// TEST: true — so'rov/javob tanalari logga to'liq yoziladi.
/// Release'dan oldin false qiling (login, PIN, chek ma'lumotlari bo'lishi mumkin).
const bool kArcaLogBodies = true;

/// `execute` buyrug'iga terminal javobini kutish vaqti.
const Duration kArcaExecuteTimeout = Duration(seconds: 60);

/// `check` so'rovi uchun kutish vaqti (sayt 10 soniyagacha kutadi).
const Duration kArcaCheckTimeout = Duration(seconds: 8);

const String kArcaServerUrl =
    '${kArcaUseTls ? 'https' : 'http'}://127.0.0.1:$kArcaPort';
