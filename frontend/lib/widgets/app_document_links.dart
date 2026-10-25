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
      // Keep the exact destination from the attempted action, including if the
      // app locale changes while the platform mail launcher is completing.
      final email = uri.path;
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
                  const SizedBox(height: 8),
                  SelectableText(email),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: email));
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
    final links = AppLinks.forCountry(
      Localizations.localeOf(context).countryCode,
    );
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
            link(context.strings.documentTerms, Uri.parse(links.terms)),
            link(context.strings.documentPrivacy, Uri.parse(links.privacy)),
            if (showAccountHelp) ...[
              link(
                context.strings.documentDeletion,
                Uri.parse(links.accountDeletion),
              ),
              link(context.strings.documentHelp, Uri.parse(links.support)),
            ],
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _open(context, links.contact),
          icon: const Icon(Icons.mail_outline, size: 18),
          label: Text(
            context.strings.documentContact,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 4),
        Text(links.contactEmail, textAlign: TextAlign.center),
      ],
    );
  }
}
