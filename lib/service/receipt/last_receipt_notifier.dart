import 'package:flutter/foundation.dart';

import '../../model/receipt/receipt_data.dart';
import '../../model/receipt/receipt_settings.dart';

class LastReceipt {
  const LastReceipt({required this.check, this.settings});

  final ReceiptData check;
  final ReceiptSettings? settings;
}

final ValueNotifier<LastReceipt?> lastReceiptNotifier = ValueNotifier(null);
