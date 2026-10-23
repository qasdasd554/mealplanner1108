import 'package:flutter/material.dart';
import '../l10n/market_locale.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_links.dart';

/// Shared legal/contact destinations; wrapping preserves large-text layouts.
class AppDocumentLinks extends StatelessWidget {
  final bool showAccountHelp;
  final Future<bool> Function(Uri)? openLink;

  const AppDocumentLinks({
    super.key,
    this.showAccountHelp = false,
    this.openLink,
  });

  Future<void> _open(BuildContext context, Uri uri) async {
    var opened = false;
    try {
      opened =
          await (openLink?.call(uri) ??
              launchUrl(uri, mode: LaunchMode.externalApplication));
      if (!opened && openLink == null && uri.scheme == 'https') {
        opened = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      }
    } catch (_) {
      // No mail app/browser installed, or platform rejected the URI.
    }
    if (opened || !context.mounted) return;
    if (uri.scheme == 'mailto') {
      await showDialog<void>(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              title: Text(context.strings.documentContact),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.strings.documentEmailBody),
                  SizedBox(height: 8),
                  SelectableText(AppLinks.contactEmail),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    await Clipboard.setData(
                      const ClipboardData(text: AppLinks.contactEmail),
                    );
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  },
                  child: Text(context.strings.documentCopy),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(context.strings.documentClose),
                ),
              ],
            ),
      );
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(context.strings.documentOpenFailed)),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget link(String label, Uri uri) => TextButton(
      onPressed: () => _open(context, uri),
      child: Text(label, textAlign: TextAlign.center),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          children: [
            link(context.strings.documentTerms, Uri.parse(AppLinks.terms)),
            link(context.strings.documentPrivacy, Uri.parse(AppLinks.privacy)),
            if (showAccountHelp) ...[
              link(
                context.strings.documentDeletion,
                Uri.parse(AppLinks.accountDeletion),
              ),
              link(context.strings.documentHelp, Uri.parse(AppLinks.support)),
            ],
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _open(context, AppLinks.contact),
          icon: const Icon(Icons.mail_outline, size: 18),
          label: Text(
            context.strings.documentContact,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 4),
        const Text(AppLinks.contactEmail, textAlign: TextAlign.center),
      ],
    );
  }
}
