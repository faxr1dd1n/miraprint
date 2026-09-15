import 'header_item.dart';
import 'receipt_item.dart';
import 'social_link.dart';
import 'total_item.dart';

class ReceiptData {
  const ReceiptData({
    required this.logo,
    required this.currentNumber,
    required this.headers,
    required this.items,
    required this.totals,
    required this.barcode,
    this.socials = const [],
  });

  final String logo;
  final String currentNumber;
  final List<HeaderItem> headers;
  final List<ReceiptItem> items;
  final List<TotalItem> totals;
  final String barcode;
  final List<SocialLink> socials;

  factory ReceiptData.fromJson(Map<String, dynamic> json) {
    return ReceiptData(
      logo: json['logo'] as String? ?? '',
      currentNumber: json['current_number'] as String? ?? '',
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
    );
  }
}
