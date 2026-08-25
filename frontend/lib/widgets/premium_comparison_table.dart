import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Tabela porównawcza Premium vs Standard — lista funkcji z wartościami
/// dla obu wariantów. Wartość String (np. "5"/"1") pokazuje się jako
/// tekst, wartość bool jako checkmark/kreska.
///
/// UWAGA: dane oparte na PRAWDZIWYCH, zweryfikowanych bezpośrednio w
/// kodzie backendu ograniczeniach — nie zgadywane. Reużywalny widget,
/// żeby ta sama tabela mogła się pojawić zarówno w Profilu, jak i (w
/// razie potrzeby) gdzie indziej, bez duplikowania danych w dwóch
/// miejscach, które mogłyby się z czasem rozjechać.
class PremiumComparisonTable extends StatelessWidget {
  const PremiumComparisonTable({super.key});

  static const List<(String, Object, Object)> _comparisonRows = [
    ('Import przepisu przez AI (zdjęcie, tekst, link)', true, false),
    ('Publikacja przepisów we wspólnym katalogu', true, false),
    ('Listy zakupów z wybranych przepisów', '5', '1'),
    ('Generowanie planu posiłków', true, true),
    ('Śledzenie kalorii i makroskładników', true, true),
    ('Kalkulator zapotrzebowania kalorycznego', true, true),
    ('Baza przepisów i produktów', true, true),
    ('Porównywarka cen produktów', true, true),
  ];

  Widget _buildCell(Object value) {
    if (value is bool) {
      return Icon(
        value ? Icons.check : Icons.remove,
        size: 18,
        color: value ? AppTheme.primaryColor : AppTheme.textSecondary.withOpacity(0.4),
      );
    }
    return Text(
      value.toString(),
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.secondaryColor.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                const Expanded(flex: 3, child: SizedBox()),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Premium',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.secondaryColor, fontSize: 13),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Standard',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          for (final row in _comparisonRows)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Expanded(flex: 3, child: Text(row.$1, style: const TextStyle(fontSize: 13))),
                  Expanded(flex: 2, child: Center(child: _buildCell(row.$2))),
                  Expanded(flex: 2, child: Center(child: _buildCell(row.$3))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
