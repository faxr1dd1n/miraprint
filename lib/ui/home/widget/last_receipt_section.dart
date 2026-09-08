import 'package:flutter/material.dart';
import 'package:miraprint/model/receipt/receipt_data.dart';
import 'package:miraprint/service/receipt/last_receipt_notifier.dart';
import 'package:miraprint/ui/home/widget/receipt_preview.dart';
import 'package:miraprint/ui/home/widget/section_card.dart';

class LastReceiptSection extends StatelessWidget {
  const LastReceiptSection({super.key});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: "So'nggi qabul qilingan chek (POST /print)",
      child: ValueListenableBuilder<ReceiptData?>(
        valueListenable: lastReceiptNotifier,
        builder: (context, receipt, _) {
          if (receipt == null) {
            return Text(
              "Hali hech qanday chek qabul qilinmagan",
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 18,
              ),
            );
          }
          return Center(child: ReceiptPreview(receipt: receipt));
        },
      ),
    );
  }
}
