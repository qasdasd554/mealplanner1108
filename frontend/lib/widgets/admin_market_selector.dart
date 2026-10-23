import 'package:flutter/material.dart';
import '../l10n/market_locale.dart';

/// Catalogue context only. This control must never edit User.countryCode.
class AdminMarketSelector extends StatelessWidget {
  const AdminMarketSelector({
    super.key,
    required this.countryCode,
    required this.isAdmin,
    required this.onChanged,
    this.isBusy = false,
  });

  final String countryCode;
  final bool isAdmin;
  final bool isBusy;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    if (!isAdmin) return const SizedBox.shrink();
    return DropdownButtonFormField<String>(
      key: ValueKey('admin-market-$countryCode'),
      initialValue: countryCode,
      isExpanded: true,
      itemHeight: null,
      decoration: InputDecoration(
        labelText: context.strings.adminMarketLabel,
        helperText:
            isBusy
                ? context.strings.adminMarketBusy
                : context.strings.adminMarketHelp,
        helperMaxLines: 3,
      ),
      items: [
        DropdownMenuItem(
          value: 'PL',
          child: Text(context.strings.adminMarketPl, maxLines: 2),
        ),
        DropdownMenuItem(
          value: 'GB',
          child: Text(context.strings.adminMarketGb, maxLines: 2),
        ),
      ],
      onChanged:
          isBusy
              ? null
              : (value) {
                if (value != null && value != countryCode) onChanged(value);
              },
    );
  }
}
