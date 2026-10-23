import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/l10n/app_localizations_en.dart';
import 'package:smart_meal_planner/l10n/app_localizations_pl.dart';

void main() {
  test(
    'all plural branch messages interpolate values instead of printing a hash',
    () {
      for (final language in ['pl', 'en', 'en_GB']) {
        final values =
            jsonDecode(File('lib/l10n/app_$language.arb').readAsStringSync())
                as Map<String, dynamic>;
        for (final entry in values.entries) {
          if (entry.value is String &&
              (entry.value as String).contains(', plural,')) {
            expect(
              entry.value,
              isNot(contains('#')),
              reason: '$language ${entry.key}',
            );
          }
        }
      }
    },
  );
  test(
    'trial days, point counts and alternative uses show their real numbers',
    () {
      final polish = AppLocalizationsPl(), english = AppLocalizationsEnGb();
      expect(polish.premiumMonthlyTrial(7), '7 dni za darmo');
      expect(english.premiumMonthlyTrial(7), '7 days free');
      expect(polish.premiumDaysRemaining(2), 'Aktywne jeszcze przez 2 dni');
      expect(english.premiumDaysRemaining(2), 'Active for 2 more days');
      expect(english.premiumPointsAmount(1), '1 point');
      expect(english.premiumPointsUses(5, 10), '5 AI imports\nor 10 AI edits');
      expect(
        english.premiumQuickActionPoints('Import recipe', 2),
        contains('2 points'),
      );
    },
  );
}
