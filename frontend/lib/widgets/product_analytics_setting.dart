import 'package:flutter/material.dart';

import '../l10n/market_locale.dart';
import '../services/product_analytics.dart';
import 'app_document_links.dart';

class ProductAnalyticsSetting extends StatefulWidget {
  const ProductAnalyticsSetting({super.key, this.initialChoice = false});

  final bool initialChoice;

  @override
  State<ProductAnalyticsSetting> createState() =>
      _ProductAnalyticsSettingState();
}

class _ProductAnalyticsSettingState extends State<ProductAnalyticsSetting> {
  bool _saving = false;

  Future<void> _update(bool enabled) async {
    if (_saving) return;
    setState(() => _saving = true);
    final saved = await ProductAnalytics.instance.setEnabled(enabled);
    if (!mounted) return;
    setState(() => _saving = false);
    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.profileAnalyticsSaveError)),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool?>(
    valueListenable: ProductAnalytics.instance.choice,
    builder: (context, enabled, _) {
      if (enabled == null) return const SizedBox.shrink();
      if (widget.initialChoice) {
        if (!ProductAnalytics.instance.needsChoice) {
          return const SizedBox.shrink();
        }
        final strings = context.strings;
        return Card(
          margin: const EdgeInsets.only(top: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.profileAnalytics,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(strings.profileAnalyticsHint),
                const AppDocumentLinks(privacyOnly: true),
                OverflowBar(
                  alignment: MainAxisAlignment.start,
                  spacing: 8,
                  overflowSpacing: 4,
                  children: [
                    FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        backgroundColor:
                            Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                        foregroundColor:
                            Theme.of(context).colorScheme.onSurface,
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      onPressed: _saving ? null : () => _update(false),
                      child: Text(strings.profileAnalyticsDecline),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: _saving ? null : () => _update(true),
                      child: Text(strings.profileAnalyticsEnable),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }
      return SwitchListTile(
        contentPadding: EdgeInsets.zero,
        secondary: const Icon(Icons.insights_outlined),
        title: Text(context.strings.profileAnalytics),
        subtitle: Text(context.strings.profileAnalyticsHint),
        value: enabled,
        onChanged: _saving ? null : _update,
      );
    },
  );
}
