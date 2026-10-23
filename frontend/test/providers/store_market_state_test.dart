import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/models/store.dart';
import 'package:smart_meal_planner/providers/store_provider.dart';
import 'package:smart_meal_planner/services/api_client.dart';
import 'package:smart_meal_planner/services/store_service.dart';

Store _store(String id) => Store(
  id: id,
  name: id,
  createdAt: DateTime.utc(2026, 10, 15),
  updatedAt: null,
);

class _StoreService extends StoreService {
  final requests = <Completer<List<Store>>>[];

  @override
  Future<List<Store>> getStores() {
    final pending = Completer<List<Store>>();
    requests.add(pending);
    return pending.future;
  }
}

void main() {
  late _StoreService service;
  late StoreProvider provider;

  setUp(() {
    service = _StoreService();
    provider = StoreProvider(service: service);
  });

  tearDown(() => provider.dispose());

  test(
    'a late Polish response cannot replace the next British account',
    () async {
      final polish = provider.loadStores();
      provider.clear();
      final british = provider.loadStores();
      service.requests[1].complete([_store('gb-tesco')]);
      await british;
      provider.selectStoreById('gb-tesco');
      service.requests[0].complete([_store('pl-biedronka')]);
      await polish;
      expect(provider.stores.single.id, 'gb-tesco');
      expect(provider.selectedStore!.id, 'gb-tesco');
      expect(provider.errorMessage, isNull);
      expect(provider.isLoading, isFalse);
    },
  );

  test(
    'old account errors and finally cannot end the new loading state',
    () async {
      final polish = provider.loadStores();
      provider.clear();
      final british = provider.loadStores();
      service.requests[0].completeError(
        ApiException(503, 'Old request failed'),
      );
      await polish;
      expect(provider.errorMessage, isNull);
      expect(provider.isLoading, isTrue);
      service.requests[1].complete([_store('gb-tesco')]);
      await british;
      expect(provider.stores.single.id, 'gb-tesco');
      expect(provider.isLoading, isFalse);
    },
  );

  test('the most recent request wins even without a clear', () async {
    final first = provider.loadStores();
    final second = provider.loadStores();
    service.requests[1].complete([_store('new')]);
    await second;
    service.requests[0].complete([_store('old')]);
    await first;
    expect(provider.stores.single.id, 'new');
  });

  test(
    'refresh clears a selected store absent from the new server list',
    () async {
      provider.selectStore(_store('pl-biedronka'));
      final refresh = provider.loadStores();
      service.requests.single.complete([_store('gb-tesco')]);
      await refresh;
      expect(provider.selectedStore, isNull);
    },
  );

  test(
    'refresh uses the current server object for a retained selection',
    () async {
      provider.selectStore(_store('gb-tesco'));
      final updated = _store('gb-tesco');
      final refresh = provider.loadStores();
      service.requests.single.complete([updated]);
      await refresh;
      expect(identical(provider.selectedStore, updated), isTrue);
    },
  );

  test('clear stays empty after a pending request completes', () async {
    final refresh = provider.loadStores();
    provider.clear();
    service.requests.single.complete([_store('pl-biedronka')]);
    await refresh;
    expect(provider.stores, isEmpty);
    expect(provider.selectedStore, isNull);
    expect(provider.isLoading, isFalse);
  });
}
