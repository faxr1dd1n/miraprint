/// `checkSettings.layout.date_format` — sana logotip ostida alohida
/// markazlashtirilishi kerakmi, degan savolga javob beradi.
/// `'centered'` — Receipt.vue'ning haqiqiy shartida tekshiriladigan qiymat
/// (`message.txt:23`), `'cashier'` — sayt hujjatlarida ko'rsatilgan
/// kelajakdagi nom — ikkalasini ham xavfsiz tomondan qo'llab-quvvatlaymiz.
bool isCenteredDateFormat(String dateFormat) =>
    dateFormat == 'centered' || dateFormat == 'cashier';

/// `key == "receipt_date"` header qiymati serverdan tayyor matn
/// ("15.09.2026, 10:55") sifatida keladi — shuni `layout.date_format`ga
/// qarab qisqartiradi (Receipt.vue'dagi `moment(...)` formatlariga mos):
/// - 'date' -> faqat sana ("15.09.2026")
/// - 'centered'/'cashier' -> sana va vaqt, vergulsiz, probel bilan
///   ("15.09.2026 10:55") — logotip ostida markazlashtirilgan holat
/// - boshqa (masalan noma'lum qiymat) -> sana va vaqt, vergul bilan,
///   soniyasiz ("15.09.2026, 10:55")
String formatReceiptDate(String raw, String dateFormat) {
  final parts = raw.split(',');
  final datePart = parts.first.trim();
  if (dateFormat == 'date') return datePart;

  if (parts.length < 2) return raw;
  final timeSegments = parts[1].trim().split(':');
  final shortTime = timeSegments.length >= 2
      ? '${timeSegments[0]}:${timeSegments[1]}'
      : parts[1].trim();
  return isCenteredDateFormat(dateFormat)
      ? '$datePart $shortTime'
      : '$datePart, $shortTime';
}
