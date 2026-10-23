import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../../l10n/catalog_labels.dart';
import '../../l10n/market_locale.dart';
import '../../models/shopping_list.dart';

class ExportListDialog extends StatelessWidget {
  final ShoppingList shoppingList;
  final String accountCountry;

  const ExportListDialog({
    Key? key,
    required this.shoppingList,
    this.accountCountry = 'PL',
  }) : super(key: key);

  String _formatList(BuildContext context) {
    final buffer = StringBuffer();
    final strings = context.strings;
    final english = strings.localeName.startsWith('en');
    buffer.writeln(strings.exportListHeading(shoppingList.storeName));
    buffer.writeln('----------------------');

    shoppingList.itemsByDepartment.forEach((department, items) {
      if (items.isNotEmpty) {
        final departmentLabel =
            !english
                ? department
                : items.every((item) => item.isFromPantry)
                ? strings.shoppingInPantry
                : department == 'Inne'
                ? strings.shoppingOther
                : department;
        buffer.writeln('\n[$departmentLabel]');
        for (var item in items) {
          final status = item.isChecked ? '[x]' : '[ ]';
          buffer.writeln(
            '$status ${item.productName} - ${item.requiredQuantity} ${english ? strings.unitLabel(item.unit) : item.unit}',
          );
        }
      }
    });

    return buffer.toString();
  }

  void _copyToClipboard(BuildContext context) {
    final text = _formatList(context);
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          content: Text(context.strings.exportListCopied),
        ),
      );
    Navigator.of(context).pop();
  }

  void _shareList(BuildContext context) {
    final text = _formatList(context);
    Share.share(
      text,
      subject: context.strings.exportListSubject(shoppingList.storeName),
    );
    Navigator.of(context).pop();
  }

  Future<void> _openApp(BuildContext context, String urlScheme) async {
    try {
      final canLaunch = await canLaunchUrlString(urlScheme);
      if (!context.mounted) return;
      if (canLaunch) {
        await launchUrlString(urlScheme);
      } else {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 3),
              content: Text(context.strings.exportListAppMissing),
            ),
          );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text(context.strings.exportListAppFailed),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uk = accountCountry == 'GB';
    final disabledColor = Theme.of(context).disabledColor;
    return AlertDialog(
      title: Text(context.strings.exportListTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.copy),
            title: Text(context.strings.exportListCopy),
            onTap: () => _copyToClipboard(context),
          ),
          ListTile(
            leading: const Icon(Icons.share),
            title: Text(context.strings.shoppingShare),
            onTap: () => _shareList(context),
          ),
          const Divider(),
          ListTile(
            enabled: !uk,
            leading: Icon(
              Icons.shopping_cart,
              color: uk ? disabledColor : Colors.green,
            ),
            title: Text(
              context.strings.exportListOpenApp(
                uk ? 'Deliveroo' : 'Żabka Jush',
              ),
            ),
            subtitle: uk ? Text(context.strings.exportListComingSoon) : null,
            onTap: uk ? null : () => _openApp(context, 'jush://'),
          ),
          ListTile(
            enabled: !uk,
            leading: Icon(
              Icons.delivery_dining,
              color: uk ? disabledColor : Colors.amber,
            ),
            title: Text(
              context.strings.exportListOpenApp(uk ? 'Tesco' : 'Glovo'),
            ),
            subtitle: uk ? Text(context.strings.exportListComingSoon) : null,
            onTap: uk ? null : () => _openApp(context, 'glovo://'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.strings.planCancel),
        ),
      ],
    );
  }
}
