import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:miraprint/model/printer/print_request.dart';
import 'package:miraprint/model/receipt/receipt_data.dart';
import 'package:miraprint/model/receipt/receipt_item.dart';
import 'package:miraprint/service/receipt/receipt_gdi_blocks.dart';

ReceiptData _receipt(List<Map<String, Object?>> items) => ReceiptData.fromJson({
  'items': items,
  'totals': [
    {'title': 'Итого', 'val': '1', 'big': true},
  ],
});

Map<String, Object?> _item(String name, Object? qty) => {
  'name': name,
  'qty': qty,
  'price': '10 000',
  'total_price': '10 000',
};

void main() {
  group('qty: butun va kasr', () {
    String text(Object? qty) =>
        ReceiptItem.fromJson({'name': 'x', 'qty': qty}).qtyText;

    test('butun, kasr, matn va vergulli qiymatlar', () {
      expect(text(7), '7');
      expect(text(7.0), '7');
      expect(text(7.5), '7.5');
      expect(text(0.25), '0.25');
      expect(text(2.125), '2.125');
      expect(text(1.10), '1.1'); // ortiqcha nol yo'q
      expect(text('2.5'), '2.5');
      expect(text('2,5'), '2.5');
      expect(text(null), '0');
      expect(text('abc'), '0');
    });
  });

  group('check_settings (yangi format)', () {
    // Haqiqiy so'rovdan olingan namuna (printer alohida, qolgani
    // check_settings ichida; `check` kaliti endi o'qilmaydi).
    Map<String, dynamic> body(String key, {Map<String, Object?>? extra}) =>
        jsonDecode(
              jsonEncode({
                'printer': {'name': 'Printer_POS_80'},
                key: {
                  'headers': [
                    {'title': 'Дата', 'val': '21.11.2026, 11:13:16'},
                    {'title': 'Филиал', 'val': 'Malika'},
                  ],
                  'items': [_item('Kartoshka Somsa', 1)],
                  'totals': [
                    {'title': 'Итого', 'val': '8 000.00 сўм', 'big': true},
                  ],
                  'logo': 'https://example.com/logo.jpg',
                  'current_number': '60',
                  'spacing': 'compact',
                  'fields_layout': 'space-between',
                  'footer_note_text': 'Спасибо!',
                  ...?extra,
                },
              }),
            )
            as Map<String, dynamic>;

    test('`check_settings` va `checkSettings` ikkalasi ham o\'qiladi', () {
      for (final key in ['check_settings', 'checkSettings']) {
        final r = PrintRequest.fromJson(body(key));
        expect(r.printer.name, 'Printer_POS_80', reason: key);
        expect(r.check.headers.length, 2, reason: key);
        expect(r.check.items.single.name, 'Kartoshka Somsa', reason: key);
        expect(r.check.currentNumber, '60', reason: key);
        expect(r.receiptSettings.spacing, 'compact', reason: key);
        expect(r.receiptSettings.fieldsLayout, 'space-between', reason: key);
        expect(r.receiptSettings.footerNoteText, 'Спасибо!', reason: key);
      }
    });

    test('kalitlar kelmasa — default va null', () {
      final r = PrintRequest.fromJson({
        'printer': {'name': 'P'},
        'check_settings': <String, dynamic>{},
      });
      expect(r.receiptSettings.spacing, 'normal');
      expect(r.receiptSettings.fieldsLayout, 'standard');
      expect(r.receiptSettings.footerNoteText, isNull);
      expect(r.check.currentNumber, isNull);
      expect(r.check.status, isNull);
    });

    test('check_settings bo\'lmasa xato', () {
      expect(
        () => PrintRequest.fromJson({
          'printer': {'name': 'P'},
        }),
        throwsFormatException,
      );
    });

    test('status va current_number chek bloklarida chiqadi', () async {
      final r = PrintRequest.fromJson(
        body('check_settings', extra: {'status': 'НЕДЕЙСТВИТЕЛЬНЫЙ ЧЕК'}),
      );
      final payload = await buildReceiptGdiPayload(
        r.check,
        settings: r.receiptSettings,
      );
      final blocks = (payload['blocks'] as List).cast<Map<String, Object?>>();
      expect(
        blocks.any(
          (b) =>
              b['type'] == 'statusBox' && b['text'] == 'НЕДЕЙСТВИТЕЛЬНЫЙ ЧЕК',
        ),
        isTrue,
      );
      expect(
        blocks.any((b) => b['type'] == 'text' && b['text'] == '60'),
        isTrue,
      );
      // space-between: header'lar `row` bloki bo'lib chiqadi
      expect(
        blocks.any((b) => b['type'] == 'row' && b['left'] == 'Дата'),
        isTrue,
      );
    });

    test('kasr miqdor chek bloklarida chiqadi', () async {
      final receipt = _receipt([_item('suv', 7), _item('go\'sht', 2.5)]);
      final payload = await buildReceiptGdiPayload(receipt);
      final blocks = (payload['blocks'] as List).cast<Map<String, Object?>>();
      final rows = [
        for (final b in blocks)
          if (b['type'] == 'row') b['left'] as String,
      ];
      expect(rows, contains('7шт x 10 000'));
      expect(rows, contains('2.5шт x 10 000'));
    });

    test(
      'chegirmali mahsulot: asl narx chiziladi, chegirma qatori chiqadi',
      () async {
        final receipt = _receipt([
          {
            ..._item('Somsa', 1),
            'discount_text': 'Скидка 10%',
            'discount_price': '9 000.00 сўм',
          },
          {..._item('Choy', 1), 'discount_text': '', 'discount_price': ''},
          _item('Non', 1),
        ]);
        final payload = await buildReceiptGdiPayload(receipt);
        final rows = (payload['blocks'] as List)
            .cast<Map<String, Object?>>()
            .where(
              (b) => b['type'] == 'row' && b['left'].toString().contains('шт'),
            )
            .toList();
        expect(rows.map((r) => r['rightStrike']), [true, false, false]);

        final all = (payload['blocks'] as List).cast<Map<String, Object?>>();
        expect(all.where((b) => b['left'] == 'Скидка 10%').length, 1);
        // bo'sh `discount_text` — qo'shimcha qator chiqmaydi
        expect(all.where((b) => b['right'] == '').length, 0);
      },
    );
  });
}
