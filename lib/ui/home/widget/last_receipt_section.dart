import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:miraprint/service/receipt/last_receipt_notifier.dart';
import 'package:miraprint/ui/home/widget/receipt_preview.dart';
import 'package:miraprint/ui/home/widget/section_card.dart';

class LastReceiptSection extends StatelessWidget {
  const LastReceiptSection({super.key});

  @override
  Widget build(BuildContext context) {
    LocalizationProvider.of(context);

    return SectionCard(
      title: translate('last_receipt.title'),
      child: ValueListenableBuilder<LastReceipt?>(
        valueListenable: lastReceiptNotifier,
        builder: (context, last, _) {
          if (last == null) {
            return Text(
              translate('last_receipt.empty'),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 18,
              ),
            );
          }
          return Center(
            child: ReceiptPreview(receipt: last.check, settings: last.settings),
          );
        },
      ),
    );
  }
}
