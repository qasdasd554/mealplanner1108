import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../../models/shopping_list.dart';

class ExportListDialog extends StatelessWidget {
  final ShoppingList shoppingList;

  const ExportListDialog({Key? key, required this.shoppingList}) : super(key: key);

  String _formatList() {
    final buffer = StringBuffer();
    buffer.writeln('Moja lista zakupów: ${shoppingList.storeName}');
    buffer.writeln('----------------------');

    shoppingList.itemsByDepartment.forEach((department, items) {
      if (items.isNotEmpty) {
        buffer.writeln('\n[$department]');
        for (var item in items) {
          final status = item.isChecked ? '[x]' : '[ ]';
          buffer.writeln('$status ${item.productName} - ${item.requiredQuantity} ${item.unit}');
        }
      }
    });

    return buffer.toString();
  }

  void _copyToClipboard(BuildContext context) {
    final text = _formatList();
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
      const SnackBar(content: Text('Skopiowano do schowka!')),
    );
    Navigator.of(context).pop();
  }

  void _shareList(BuildContext context) {
    final text = _formatList();
    Share.share(text, subject: 'Lista zakupów - ${shoppingList.storeName}');
    Navigator.of(context).pop();
  }

  Future<void> _openApp(BuildContext context, String urlScheme) async {
    try {
      if (await canLaunchUrlString(urlScheme)) {
        await launchUrlString(urlScheme);
      } else {
        ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
          const SnackBar(content: Text('Aplikacja nie jest zainstalowana.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Nie udało się otworzyć aplikacji.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Eksportuj listę'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.copy),
            title: const Text('Kopiuj do schowka'),
            onTap: () => _copyToClipboard(context),
          ),
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('Udostępnij'),
            onTap: () => _shareList(context),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.shopping_cart, color: Colors.green),
            title: const Text('Otwórz Żabka Jush'),
            onTap: () => _openApp(context, 'jush://'),
          ),
          ListTile(
            leading: const Icon(Icons.delivery_dining, color: Colors.amber),
            title: const Text('Otwórz Glovo'),
            onTap: () => _openApp(context, 'glovo://'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Anuluj'),
        ),
      ],
    );
  }
}
