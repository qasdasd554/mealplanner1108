import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/services/share_intent_handler.dart';

void main() {
  test('wyciąga link TikToka z udostępnionego opisu', () {
    expect(
      ShareIntentHandler.extractUrl(
        'Zobacz ten przepis! https://vm.tiktok.com/ZMTest123/ Skopiowano z TikToka',
      ),
      'https://vm.tiktok.com/ZMTest123/',
    );
  });

  test('usuwa końcowe znaki interpunkcyjne', () {
    expect(
      ShareIntentHandler.extractUrl('Przepis: https://example.com/obiad).'),
      'https://example.com/obiad',
    );
  });

  test('nie otwiera ekranu AI bez linku', () {
    expect(ShareIntentHandler.extractUrl('Tylko opis, bez adresu'), isNull);
  });
}
