import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:smart_meal_planner/models/user.dart';
import 'package:smart_meal_planner/models/barcode_lookup_result.dart';
import 'package:smart_meal_planner/providers/auth_provider.dart';
import 'package:smart_meal_planner/screens/barcode_scanner_screen.dart';
import 'package:smart_meal_planner/screens/batch_barcode_scanner_screen.dart';
import 'package:smart_meal_planner/services/barcode_lookup_service.dart';

class _CountingLookup extends BarcodeLookupService {
  int lookups = 0;
  @override
  Future<BarcodeLookupResult> lookup(String code) async {
    lookups++;
    return const BarcodeLookupResult(found: false);
  }
}

class _PremiumAuth extends AuthProvider {
  _PremiumAuth() : super(readToken: () async => null);
  bool premium = true;

  void expire() {
    premium = false;
    notifyListeners();
  }

  @override
  User get currentUser => User(
    id: 'scanner-user',
    email: 'scanner@example.test',
    householdSize: 1,
    isPremium: premium,
    createdAt: DateTime.utc(2026),
  );
}

class _CameraPlatform extends MobileScannerPlatform {
  final events = <String>[];
  final starts = <StartOptions>[];
  final zooms = <double>[];
  Completer<void>? starting;
  Completer<void>? stopping;
  bool denyCamera = false;

  @override
  Stream<BarcodeCapture?> get barcodesStream => const Stream.empty();
  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();
  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();
  @override
  Widget buildCameraView() => const SizedBox.expand();
  @override
  Future<void> updateScanWindow(Rect? window) async {}
  @override
  Future<void> setZoomScale(double scale) async => zooms.add(scale);
  @override
  Future<MobileScannerViewAttributes> start(StartOptions options) async {
    starts.add(options);
    events.add('start');
    await starting?.future;
    if (denyCamera) {
      throw const MobileScannerException(
        errorCode: MobileScannerErrorCode.permissionDenied,
      );
    }
    events.add('started');
    return const MobileScannerViewAttributes(
      cameraDirection: CameraFacing.back,
      currentTorchMode: TorchState.off,
      size: Size(640, 480),
    );
  }

  @override
  Future<void> stop() async {
    events.add('stop');
    await stopping?.future;
    events.add('stopped');
  }

  @override
  Future<void> dispose() async => events.add('dispose');
}

void main() {
  late MobileScannerPlatform original;
  late _CameraPlatform platform;
  setUp(() {
    original = MobileScannerPlatform.instance;
    platform = _CameraPlatform();
    MobileScannerPlatform.instance = platform;
    MobileScannerController.resetPlatformSessionOwner();
  });
  tearDown(() {
    MobileScannerPlatform.instance = original;
    MobileScannerController.resetPlatformSessionOwner();
  });

  testWidgets('custom-controller scanner releases camera while inactive', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const MaterialApp(home: BarcodeScannerScreen()));
    await tester.pumpAndSettle();
    expect(platform.events, contains('started'));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(platform.events, contains('stopped'));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(platform.events.where((event) => event == 'start'), hasLength(2));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  for (final batch in [false, true]) {
    testWidgets(
      '${batch ? 'batch' : 'single'} manual typing ignores live barcode detections',
      (tester) async {
        final auth = _PremiumAuth();
        final lookup = _CountingLookup();
        addTearDown(auth.dispose);
        Object? result;
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpWidget(
          ChangeNotifierProvider<AuthProvider>.value(
            value: auth,
            child: MaterialApp(
              home: Builder(
                builder:
                    (context) => TextButton(
                      onPressed: () async {
                        result = await Navigator.of(context).push<Object?>(
                          MaterialPageRoute<Object?>(
                            builder:
                                (_) =>
                                    batch
                                        ? BatchBarcodeScannerScreen(
                                          lookupService: lookup,
                                        )
                                        : const BarcodeScannerScreen(),
                          ),
                        );
                      },
                      child: const Text('Open scanner'),
                    ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open scanner'));
        await tester.pumpAndSettle();
        final scanner = tester.widget<MobileScanner>(
          find.byType(MobileScanner),
        );
        await tester.tap(find.byIcon(Icons.keyboard));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '123');
        const capture = BarcodeCapture(
          barcodes: [
            Barcode(rawValue: '5901234123457', format: BarcodeFormat.ean13),
          ],
        );
        scanner.onDetect!(capture);
        scanner.onDetect!(capture);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          '123',
        );
        expect(result, isNull);
        expect(lookup.lookups, 0);
        expect(platform.events, contains('stopped'));
        // Returning from another app must not reactivate a scanner behind the dialog.
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        expect(platform.starts, hasLength(1));
        await tester.tap(find.text('Anuluj'));
        await tester.pumpAndSettle();
        expect(platform.starts, hasLength(2));
        expect(result, isNull);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );

    testWidgets(
      '${batch ? 'batch' : 'single'} zoom label resets after actual restart',
      (tester) async {
        final auth = _PremiumAuth();
        addTearDown(auth.dispose);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpWidget(
          ChangeNotifierProvider<AuthProvider>.value(
            value: auth,
            child: MaterialApp(
              home:
                  batch
                      ? const BatchBarcodeScannerScreen()
                      : const BarcodeScannerScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final camera =
            tester
                .widget<MobileScanner>(find.byType(MobileScanner))
                .controller!;
        // Production zoom interaction uses 2 as its selected-state marker.
        await tester.tap(find.byIcon(Icons.zoom_in));
        await tester.pump();
        expect(platform.zooms, isNotEmpty);
        expect(
          batch ? find.byIcon(Icons.zoom_out) : find.text('1×'),
          findsOneWidget,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        expect(platform.starts, hasLength(2));
        expect(platform.starts.last.initialZoom, isNull);
        expect(camera.value.isRunning, isTrue);
        expect(
          batch ? find.byIcon(Icons.zoom_in) : find.text('2×'),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );

    testWidgets(
      '${batch ? 'batch' : 'single'} zoom label survives a coalesced no-stop interruption',
      (tester) async {
        final auth = _PremiumAuth();
        addTearDown(auth.dispose);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpWidget(
          ChangeNotifierProvider<AuthProvider>.value(
            value: auth,
            child: MaterialApp(
              home:
                  batch
                      ? const BatchBarcodeScannerScreen()
                      : const BarcodeScannerScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.zoom_in));
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        expect(platform.starts, hasLength(1));
        expect(platform.events, isNot(contains('stop')));
        expect(
          batch ? find.byIcon(Icons.zoom_out) : find.text('1×'),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );
  }

  for (final disabled in [false, true]) {
    testWidgets(
      'manual cancel does not ${disabled ? 'start disabled' : 'retry denied'} camera',
      (tester) async {
        platform.denyCamera = !disabled;
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: BarcodeScannerScreen(
              controller:
                  disabled ? MobileScannerController(autoStart: false) : null,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.keyboard));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Anuluj'));
        await tester.pumpAndSettle();
        expect(platform.starts, hasLength(disabled ? 0 : 1));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );
  }

  testWidgets('accepted single manual code returns without restarting camera', (
    tester,
  ) async {
    String? result;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder:
              (context) => TextButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<String>(
                    MaterialPageRoute<String>(
                      builder: (_) => const BarcodeScannerScreen(),
                    ),
                  );
                },
                child: const Text('Open scanner'),
              ),
        ),
      ),
    );
    await tester.tap(find.text('Open scanner'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.keyboard));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '5901234123457');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(result, '5901234123457');
    expect(platform.starts, hasLength(1));
    expect(platform.events.last, 'dispose');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'repeated manual press during camera stop opens only one dialog',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(const MaterialApp(home: BarcodeScannerScreen()));
      await tester.pumpAndSettle();
      platform.stopping = Completer<void>();
      final press =
          tester
              .widget<TextButton>(
                find.ancestor(
                  of: find.byIcon(Icons.keyboard),
                  matching: find.byType(TextButton),
                ),
              )
              .onPressed!;
      press();
      press();
      await tester.pump();
      expect(find.byType(AlertDialog), findsNothing);
      platform.stopping!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Anuluj'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(platform.starts, hasLength(2));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets('premium batch scanner also releases and resumes its camera', (
    tester,
  ) async {
    final auth = _PremiumAuth();
    addTearDown(auth.dispose);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: const MaterialApp(home: BatchBarcodeScannerScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(platform.events, ['start', 'started']);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    expect(platform.events, ['start', 'started', 'stop', 'stopped']);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(platform.events.where((event) => event == 'start'), hasLength(2));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('permission transitions do not race an unfinished start', (
    tester,
  ) async {
    platform.starting = Completer<void>();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const MaterialApp(home: BarcodeScannerScreen()));
    await tester.pump();
    expect(platform.events, ['start']);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(platform.events, ['start']);
    platform.starting!.complete();
    await tester.pumpAndSettle();
    expect(platform.events, ['start', 'started']);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets(
    'injected auto-start controller also stops after background startup',
    (tester) async {
      platform.starting = Completer<void>();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(
        MaterialApp(
          home: BarcodeScannerScreen(controller: MobileScannerController()),
        ),
      );
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      platform.starting!.complete();
      await tester.pump();
      expect(platform.events, ['start', 'started', 'stop', 'stopped']);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('barcode confirmation requires two fresh hits after resume', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder:
              (context) => TextButton(
                onPressed:
                    () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const BarcodeScannerScreen(),
                      ),
                    ),
                child: const Text('Scan'),
              ),
        ),
      ),
    );
    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();
    const capture = BarcodeCapture(
      barcodes: [
        Barcode(rawValue: '5901234123457', format: BarcodeFormat.ean13),
      ],
    );
    void detect() => tester
        .widget<MobileScanner>(find.byType(MobileScanner))
        .onDetect!(capture);
    detect();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    detect();
    await tester.pumpAndSettle();
    expect(find.byType(BarcodeScannerScreen), findsOneWidget);
    detect();
    await tester.pumpAndSettle();
    expect(find.byType(BarcodeScannerScreen), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('batch premium expiration cannot restart camera on resume', (
    tester,
  ) async {
    final auth = _PremiumAuth();
    addTearDown(auth.dispose);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: const MaterialApp(home: BatchBarcodeScannerScreen()),
      ),
    );
    await tester.pumpAndSettle();
    auth.expire();
    await tester.pumpAndSettle();
    expect(find.byType(MobileScanner), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(platform.events, ['start', 'started', 'stop', 'stopped']);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('a start completing in the background releases the camera', (
    tester,
  ) async {
    platform.starting = Completer<void>();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const MaterialApp(home: BarcodeScannerScreen()));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    platform.starting!.complete();
    await tester.pump();
    expect(platform.events, ['start', 'started', 'stop', 'stopped']);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(platform.events.where((event) => event == 'start'), hasLength(2));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('slow stop serializes resume and honors the latest state', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const MaterialApp(home: BarcodeScannerScreen()));
    await tester.pumpAndSettle();
    platform.stopping = Completer<void>();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(platform.events, ['start', 'started', 'stop']);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    platform.stopping!.complete();
    await tester.pump();
    expect(platform.events, ['start', 'started', 'stop', 'stopped']);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(platform.events.where((event) => event == 'start'), hasLength(2));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('disposing during camera startup never restarts it', (
    tester,
  ) async {
    platform.starting = Completer<void>();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const MaterialApp(home: BarcodeScannerScreen()));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    platform.starting!.complete();
    await tester.pump();
    expect(platform.events, ['start', 'started', 'stop', 'stopped', 'dispose']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('batch preview never allocates or disposes a native camera', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      const MaterialApp(home: BatchBarcodeScannerScreen(previewOnly: true)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MobileScanner), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(platform.events, isEmpty);
  });
}
