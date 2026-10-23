import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/screens/admin/admin_campaigns_screen.dart';
import 'package:smart_meal_planner/services/api_client.dart';
import 'package:smart_meal_planner/l10n/app_localizations.dart';

Map<String, dynamic> campaign(String market, {bool active = true}) => {
  'id': 'campaign-$market',
  'country_code': market,
  'name': 'Offer $market',
  'kind': 'points',
  'product_id': 'points_20',
  'audience': 'all',
  'platform': 'android',
  'discount_percent': 30,
  'is_active': active,
  'starts_at': '2026-10-21T00:00:00Z',
  'ends_at': '2026-10-24T00:00:00Z',
};

class Client implements ApiClient {
  final gets = <String>[];
  final writes = <String>[];
  final pending = <String, Completer<dynamic>>{};
  List<dynamic>? overrideRows;
  Completer<dynamic>? write;
  @override
  Future<dynamic> get(String path, {Duration? timeout}) async {
    gets.add(path);
    final market = Uri.parse(path).queryParameters['market'] ?? 'PL';
    return pending[market]?.future ?? overrideRows ?? [campaign(market)];
  }

  @override
  Future<dynamic> patch(String path, {dynamic body}) async {
    writes.add(path);
    return write?.future;
  }

  @override
  Future<dynamic> delete(String path) async {
    writes.add(path);
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation call) => super.noSuchMethod(call);
}

Future<void> open(
  WidgetTester tester,
  Client client,
  String market, {
  bool narrow = false,
  bool english = false,
}) async {
  tester.view.physicalSize = Size(narrow ? 320 : 390, 844);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    MaterialApp(
      locale: english ? const Locale('en', 'GB') : const Locale('pl', 'PL'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder:
          (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(narrow ? 1.5 : 1)),
            child: child!,
          ),
      home: AdminCampaignsScreen(market: market, client: client),
    ),
  );
  await tester.pump();
}

Future<void> reveal(WidgetTester tester, String name) async {
  await tester.scrollUntilVisible(
    find.text(name),
    300,
    maxScrolls: 30,
    scrollable:
        find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'campaign form and confirmations use English without changing API market',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final client = Client();
      await open(tester, client, 'PL', narrow: true, english: true);
      await tester.pumpAndSettle();
      expect(find.text('Campaigns'), findsOneWidget);
      expect(find.text('Market: Poland • PLN • Europe/Warsaw'), findsOneWidget);
      await reveal(tester, 'Offer PL');
      await tester.tap(find.byTooltip('Delete campaign'));
      await tester.pumpAndSettle();
      expect(find.text('Delete campaign?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(client.writes, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'campaign card shows selected UK calendar days, not UTC boundaries',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final client =
          Client()
            ..overrideRows = [
              {
                ...campaign('GB'),
                'starts_at': '2026-06-30T23:00:00Z',
                'ends_at': '2026-07-10T23:00:00Z',
              },
            ];
      await open(tester, client, 'GB', english: true);
      await tester.pumpAndSettle();
      await reveal(tester, 'Offer GB');
      expect(find.text('01/07/2026 – 10/07/2026'), findsOneWidget);
    },
  );
  for (final market in ['PL', 'GB']) {
    testWidgets('list and disable stay in selected $market market', (
      tester,
    ) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final client = Client()..write = Completer<dynamic>();
      await open(tester, client, market);
      expect(client.gets.single, '/purchase-campaigns/admin?market=$market');
      await reveal(tester, 'Offer $market');
      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.tap(find.byType(Switch));
      expect(client.writes, [
        '/purchase-campaigns/admin/campaign-$market?market=$market&is_active=false',
      ]);
      client.write!.complete(null);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
    testWidgets('delete stays in selected $market market', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final client = Client();
      await open(tester, client, market);
      await reveal(tester, 'Offer $market');
      await tester.tap(find.byTooltip('Usuń kampanię'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Usuń'));
      await tester.pumpAndSettle();
      expect(
        client.writes.single,
        '/purchase-campaigns/admin/campaign-$market?market=$market',
      );
      expect(tester.takeException(), isNull);
    });
    testWidgets('campaign form and card fit 320px enlarged text ($market)', (
      tester,
    ) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final client = Client();
      await open(tester, client, market, narrow: true);
      expect(tester.takeException(), isNull);
      await reveal(tester, 'Offer $market');
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('late response from old market cannot replace the new market', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final old = Completer<dynamic>();
    final client = Client()..pending['PL'] = old;
    await open(tester, client, 'PL');
    await open(tester, client, 'GB');
    old.complete([campaign('PL')]);
    await tester.pumpAndSettle();
    await reveal(tester, 'Offer GB');
    expect(find.text('Offer PL'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'rejects a cross-market response rather than showing its actions',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final client = Client()..overrideRows = [campaign('PL')];
      await open(tester, client, 'GB');
      await tester.pumpAndSettle();
      expect(find.text('Offer PL'), findsNothing);
      expect(find.byTooltip('Usuń kampanię'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
