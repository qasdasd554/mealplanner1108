import 'package:flutter/material.dart';
import '../l10n/market_locale.dart';
import '../utils/barcode_utils.dart';
import '../utils/retained_dialog.dart';

/// Keep invalid input available for correction and retain the controller until
/// the closing transition has really removed the field.
Future<String?> showManualBarcodeDialog(
  BuildContext context, {
  bool batch = false,
}) async {
  final strings = context.strings;
  final controller = TextEditingController();
  String? error;
  try {
    return await showRetainedDialog<String>(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder: (dialogContext, update) {
              void submit() {
                final code = normalizeScannedBarcode(controller.text);
                if (code == null) {
                  update(() => error = strings.scanCodeInvalid);
                } else {
                  Navigator.pop(dialogContext, code);
                }
              }

              return AlertDialog(
                title: Text(strings.scanEnterCode),
                content: TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  onSubmitted: (_) => submit(),
                  onChanged: (_) {
                    if (error != null) update(() => error = null);
                  },
                  decoration: InputDecoration(
                    labelText: 'EAN/UPC',
                    hintText:
                        batch
                            ? strings.scanBatchCodeHint
                            : strings.scanCodeHint,
                    errorText: error,
                    errorMaxLines: 3,
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: Text(strings.productsCancel),
                  ),
                  FilledButton(
                    onPressed: submit,
                    child: Text(batch ? strings.add : strings.scanSearch),
                  ),
                ],
              );
            },
          ),
    );
  } finally {
    controller.dispose();
  }
}
