import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/services/api_client.dart';
import 'package:smart_meal_planner/services/promotion_service.dart';

class _Client extends Fake implements ApiClient {
  var posts = 0;
  var gets = 0;
  final List<Object> replies;
  _Client(this.replies);
  @override
  Future<dynamic> post(String path, {dynamic body, Duration? timeout}) async {
    expect(path, startsWith('/promotions/ai-scan/jobs?'));
    posts++;
    return {'id': 'job', 'status': 'queued', 'store_name': 'Carrefour'};
  }

  @override
  Future<dynamic> get(String path, {Duration? timeout}) async {
    gets++;
    final value = replies.removeAt(0);
    if (value is Exception) throw value;
    return value;
  }
}

void main() {
  test(
    'długi skan używa jednego krótkiego POST i odpytywania statusu',
    () async {
      final client = _Client([
        {'id': 'job', 'status': 'processing'},
        {
          'id': 'job',
          'status': 'completed',
          'result': {'found': 8, 'queued_for_review': 6},
        },
      ]);
      final service = PromotionService(client: client, wait: (_) async {});
      final result = await service.triggerAiScan('Carrefour');
      expect(result['queued_for_review'], 6);
      expect(client.posts, 1);
      expect(client.gets, 2);
    },
  );
  test('zamknięcie panelu nie anuluje ani nie powtarza zadania', () async {
    final client = _Client([]);
    final service = PromotionService(client: client, wait: (_) async {});
    final result = await service.triggerAiScan('Lidl', isActive: () => false);
    expect(result['status'], 'queued');
    expect(client.posts, 1);
    expect(client.gets, 0);
  });
  test('chwilowy brak sieci nie oznacza błędu skanera', () async {
    final client = _Client([
      ApiException(503, 'offline'),
      {
        'id': 'job',
        'status': 'completed',
        'result': {'found': 2},
      },
    ]);
    final result = await PromotionService(
      client: client,
      wait: (_) async {},
    ).triggerAiScan('Dino');
    expect(result['found'], 2);
    expect(client.posts, 1);
  });
  test('trwały brak sieci zostawia zadanie działające w tle', () async {
    final client = _Client(
      List.generate(3, (_) => ApiException(503, 'offline')),
    );
    final result = await PromotionService(
      client: client,
      wait: (_) async {},
    ).triggerAiScan('Dino');
    expect(result['status'], 'queued');
    expect(client.posts, 1);
  });
  test('rzeczywisty błąd AI jest pokazany zamiast timeoutu telefonu', () async {
    final client = _Client([
      {'id': 'job', 'status': 'failed', 'error': 'Limit AI wyczerpany'},
    ]);
    await expectLater(
      PromotionService(
        client: client,
        wait: (_) async {},
      ).triggerAiScan('Lidl'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          'Limit AI wyczerpany',
        ),
      ),
    );
  });
  test('wznowienie istniejącego zadania nie wysyła POST', () async {
    final client = _Client([
      {
        'id': 'job',
        'status': 'completed',
        'result': {'found': 1},
      },
    ]);
    final result = await PromotionService(
      client: client,
      wait: (_) async {},
    ).waitForScan({'id': 'job', 'status': 'processing'});
    expect(result['found'], 1);
    expect(client.posts, 0);
  });
}
