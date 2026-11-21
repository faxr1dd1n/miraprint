import 'header_item.dart';
import 'receipt_item.dart';
import 'social_link.dart';
import 'total_item.dart';

/// `check_settings` ichidagi chek mazmuni. Ixtiyoriy bloklar (`logo`,
/// `status`, `current_number`, `barcode`, `socials`) o'chirilgan bo'lsa
/// serverdan umuman kelmaydi — bo'sh/yo'q qiymat chizilmaydi.
class ReceiptData {
  const ReceiptData({
    required this.logo,
    required this.headers,
    required this.items,
    required this.totals,
    required this.barcode,
    this.socials = const [],
    this.currentNumber,
    this.status,
  });

  final String logo;
  final List<HeaderItem> headers;
  final List<ReceiptItem> items;
  final List<TotalItem> totals;
  final String barcode;
  final List<SocialLink> socials;

  /// "Счётчик заказов" — logotip ostida katta raqam bo'lib chiqadi.
  final String? currentNumber;

  /// Chek holati matni (masalan "НЕДЕЙСТВИТЕЛЬНЫЙ ЧЕК") — ramkali blok.
  final String? status;

  static String? _text(Object? v) {
    final s = v?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  factory ReceiptData.fromJson(Map<String, dynamic> json) {
    return ReceiptData(
      logo: json['logo'] as String? ?? '',
      headers: (json['headers'] as List<dynamic>? ?? [])
          .map((e) => HeaderItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      items: (json['items'] as List<dynamic>? ?? [])
          .map((e) => ReceiptItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      totals: (json['totals'] as List<dynamic>? ?? [])
          .map((e) => TotalItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      barcode: json['barcode'] as String? ?? '',
      socials: (json['socials'] as List<dynamic>? ?? [])
          .map((e) => SocialLink.fromJson(e as Map<String, dynamic>))
          .toList(),
      currentNumber: _text(json['current_number']),
      status: _text(json['status']),
    );
  }
}
