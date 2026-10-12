import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/services/app_review_service.dart';

void main() {
  test('bez dostępnego sklepu nie zużywa limitu konta', () async {
    var claims = 0;
    final service = AppReviewService(
      isAvailable: () async => false,
      claim: () async {
        claims++;
        return true;
      },
      requestReview: () async => fail('Okno nie może się otworzyć'),
    );
    expect(await service.maybeRequest(), isFalse);
    expect(claims, 0);
  });
  test('odmowa limitu 10 dni nie uruchamia okna', () async {
    final service = AppReviewService(
      isAvailable: () async => true,
      claim: () async => false,
      requestReview: () async => fail('Okno nie może się otworzyć'),
    );
    expect(await service.maybeRequest(), isFalse);
  });
  test('jedna udana rezerwacja uruchamia natywne API', () async {
    var reviews = 0;
    final service = AppReviewService(
      isAvailable: () async => true,
      claim: () async => true,
      requestReview: () async {
        reviews++;
      },
    );
    expect(await service.maybeRequest(), isTrue);
    expect(reviews, 1);
  });
  test('równoległe sygnały nie uruchamiają dwóch rezerwacji', () async {
    final available = Completer<bool>();
    var claims = 0;
    final service = AppReviewService(
      isAvailable: () => available.future,
      claim: () async {
        claims++;
        return true;
      },
      requestReview: () async {},
    );
    final first = service.maybeRequest();
    expect(await service.maybeRequest(), isFalse);
    available.complete(true);
    expect(await first, isTrue);
    expect(claims, 1);
  });
  test('formularz lub zmiana konta w trakcie requestu blokuje okno', () async {
    var safe = true;
    final service = AppReviewService(
      isAvailable: () async => true,
      claim: () async {
        safe = false;
        return true;
      },
      requestReview: () async => fail('Okno nie może się otworzyć'),
    );
    expect(await service.maybeRequest(stillSafe: () => safe), isFalse);
  });
  test('awaria API nie blokuje użytkownika ani kolejnej próby', () async {
    var claims = 0;
    final service = AppReviewService(
      isAvailable: () async => true,
      claim: () async {
        if (claims++ == 0) throw StateError('offline');
        return true;
      },
      requestReview: () async {},
    );
    expect(await service.maybeRequest(), isFalse);
    expect(await service.maybeRequest(), isTrue);
  });
  test('sygnał udanego zapisu nie zależy od pobierania danych', () {
    final initial = AppReviewSignal.successfulActions.value;
    AppReviewSignal.recordSuccess();
    expect(AppReviewSignal.successfulActions.value, initial + 1);
  });
}
