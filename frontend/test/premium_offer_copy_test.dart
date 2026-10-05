import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/models/premium_offer.dart';

void main() {
  test('kontekst przepisu opisuje konkretne wejścia i wynik', () {
    final copy = PremiumOfferCopy.forContext(PremiumOfferContext.recipe);

    expect(copy.title, 'Zamień inspirację w gotowy przepis');
    expect(copy.description, contains('link'));
    expect(copy.description, contains('zdjęcie'));
    expect(copy.description, contains('składniki'));
    expect(copy.benefits, hasLength(3));
  });

  test('każdy kontekst ma krótką listę konkretnych korzyści', () {
    for (final context in PremiumOfferContext.values) {
      final copy = PremiumOfferCopy.forContext(context);
      expect(copy.title, isNotEmpty);
      expect(copy.description, isNotEmpty);
      expect(copy.benefits.length, inInclusiveRange(2, 4));
    }
  });

  test('oferta przepisu wymaga czasu, przewinięcia i aktywnego ekranu', () {
    expect(
      shouldTriggerRecipePremiumOffer(
        viewedLongEnough: true,
        scrollOffset: 220,
        alreadyAttempted: false,
        isCurrentRoute: true,
      ),
      isTrue,
    );
    expect(
      shouldTriggerRecipePremiumOffer(
        viewedLongEnough: false,
        scrollOffset: 500,
        alreadyAttempted: false,
        isCurrentRoute: true,
      ),
      isFalse,
    );
    expect(
      shouldTriggerRecipePremiumOffer(
        viewedLongEnough: true,
        scrollOffset: 100,
        alreadyAttempted: false,
        isCurrentRoute: true,
      ),
      isFalse,
    );
  });
}
