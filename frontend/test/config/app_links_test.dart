import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/config/app_links.dart';

void main() {
  for (final region in <String?>['PL', null, '', 'US', 'en']) {
    test(
      'missing or unsupported market $region preserves Polish destinations',
      () {
        final links = AppLinks.forCountry(region);
        expect(links.website, AppLinks.website);
        expect(links.terms, AppLinks.terms);
        expect(links.privacy, AppLinks.privacy);
        expect(links.accountDeletion, AppLinks.accountDeletion);
        expect(links.support, AppLinks.support);
        expect(links.contactEmail, AppLinks.contactEmail);
        expect(links.contact, AppLinks.contact);
      },
    );
  }
  for (final region in ['GB', 'UK', 'gb', ' uk ']) {
    test(
      'UK market $region uses existing root pages, not a missing /en path',
      () {
        final links = AppLinks.forCountry(region);
        expect(links.website, 'https://mealplannerworld.com');
        expect(links.terms, '${links.website}/terms-of-use.html');
        expect(links.privacy, '${links.website}/privacy-policy.html');
        expect(links.accountDeletion, '${links.website}/delete-account.html');
        expect(links.support, '${links.website}/support.html');
        expect(links.contactEmail, 'support@mealplannerworld.com');
        expect(links.contact.toString(), 'mailto:support@mealplannerworld.com');
      },
    );
  }
  test(
    'resolving another market never changes a previous selection or legacy PL constants',
    () {
      final british = AppLinks.forCountry('GB');
      final polish = AppLinks.forCountry('PL');
      expect(british.website, 'https://mealplannerworld.com');
      expect(polish.website, 'https://mealplannerpolska.pl');
      expect(AppLinks.terms, 'https://mealplannerpolska.pl/terms-of-use.html');
      expect(AppLinks.contactEmail, 'kontakt@mealplannerpolska.pl');
    },
  );
}
