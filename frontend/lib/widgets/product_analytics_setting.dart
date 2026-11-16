import 'package:flutter/material.dart';

import '../l10n/market_locale.dart';
import '../services/product_analytics.dart';

class ProductAnalyticsSetting extends StatefulWidget {
  const ProductAnalyticsSetting({super.key});

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
