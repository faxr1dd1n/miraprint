import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:miraprint/model/printer/print_request.dart';
import 'package:miraprint/model/receipt/receipt_data.dart';
import 'package:miraprint/model/receipt/receipt_item.dart';
import 'package:miraprint/model/receipt/receipt_settings.dart';
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

  group('show_product_numbers', () {
    test(
      'sozlama o\'qiladi, `checkSettings` va `check_settings` ikkalasi ham',
      () {
        // jsonDecode — haqiqiy so'rovdagidek ichma-ich Map<String, dynamic> beradi.
        Map<String, dynamic> body(String key, Object? show) =>
            jsonDecode(
                  jsonEncode({
                    'printer': {'name': 'P'},
                    'check': {},
                    key: {
                      'layout': {
                        'date_format': 'centered',
                        'show_product_numbers': show,
                      },
                    },
                  }),
                )
                as Map<String, dynamic>;

        for (final key in ['check_settings', 'checkSettings']) {
          final r = PrintRequest.fromJson(body(key, true));
          expect(
            r.receiptSettings?.layout.showProductNumbers,
            true,
            reason: key,
          );
          expect(r.receiptSettings?.layout.dateFormat, 'centered');
        }
        expect(
          PrintRequest.fromJson(
            body('check_settings', false),
          ).receiptSettings!.layout.showProductNumbers,
          false,
        );
        // berilmasa — o'chiq (avvalgi xulq saqlanadi)
        expect(const ReceiptLayout().showProductNumbers, false);
      },
    );

    test(
      'chek bloklarida nom oldiga raqam qo\'yiladi / qo\'yilmaydi, kasr miqdor chiqadi',
      () async {
        final receipt = _receipt([_item('suv', 7), _item('go\'sht', 2.5)]);

        Future<List<String>> texts(ReceiptSettings? s) async {
          final payload = await buildReceiptGdiPayload(receipt, settings: s);
          final blocks = (payload['blocks'] as List)
              .cast<Map<String, Object?>>();
          return [
            for (final b in blocks) ...[
              if (b['type'] == 'text') b['text'] as String,
              if (b['type'] == 'row') b['left'] as String,
            ],
          ];
        }

        final plain = await texts(null);
        expect(plain, contains('suv'));
        expect(plain, contains('go\'sht'));
        expect(plain, contains('7шт x 10 000'));
        expect(plain, contains('2.5шт x 10 000')); // kasr miqdor

        final numbered = await texts(
          ReceiptSettings.fromJson(
            jsonDecode('{"layout":{"show_product_numbers":true}}')
                as Map<String, dynamic>,
          ),
        );
        expect(numbered, contains('1. suv'));
        expect(numbered, contains('2. go\'sht'));
        expect(numbered, isNot(contains('suv')));
      },
    );
  });
}
