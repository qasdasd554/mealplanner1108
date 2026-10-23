import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smart_meal_planner/l10n/app_localizations.dart';
import 'package:smart_meal_planner/models/barcode_lookup_result.dart';
import 'package:smart_meal_planner/services/barcode_lookup_service.dart';
import 'package:smart_meal_planner/widgets/product_label_recognition_sheet.dart';
import 'package:smart_meal_planner/theme/app_theme.dart';
import '../helpers/product_form_render.dart';

class _Photos extends ImagePicker {
  bool fail = false;
  bool cancel = false;
  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    if (fail) throw Exception('camera denied');
    if (cancel) return null;
    return XFile.fromData(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNgYAAAAAMAASsJTYQAAAAASUVORK5CYII=',
      ),
      mimeType: 'image/png',
    );
  }
}

class _Labels extends BarcodeLookupService {
  BarcodeLookupResult result = const BarcodeLookupResult(
    found: true,
    source: 'product_label_ai',
    name: 'Milk',
    unit: 'ml',
    servingQuantity: 500,
    kcalPer100: 60,
    proteinPer100: 3,
    fatPer100: 2,
    carbsPer100: 5,
  );
  final confirms = <BarcodeLookupResult>[];
  int reads = 0;
  bool failRead = false, failConfirm = false;
  Completer<BarcodeLookupResult>? pending;
  @override
  Future<BarcodeLookupResult> recognizeLabel({
    required String barcode,
    required String frontPhotoBase64,
    required String nutritionPhotoBase64,
  }) async {
    reads++;
    expect(frontPhotoBase64, isNotEmpty);
    expect(nutritionPhotoBase64, isNotEmpty);
    if (failRead) throw Exception('offline');
    return pending?.future ?? result;
  }

  @override
  Future<BarcodeLookupResult> confirmRecognizedLabel(
    BarcodeLookupResult result,
  ) async {
    confirms.add(result);
    if (failConfirm) throw Exception('offline');
    return result;
  }
}

Future<void> _open(
  WidgetTester tester,
  _Labels service, {
  Locale locale = const Locale('pl', 'PL'),
  _Photos? photos,
  Size viewport = const Size(800, 2100),
  double textScale = 1,
  double keyboardBottom = 0,
  bool dark = false,
}) async {
  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetViewInsets);
  AppTheme.setDark(dark);
  addTearDown(() => AppTheme.setDark(false));
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: productFormTheme(dark),
      builder:
          (context, child) => RepaintBoundary(
            key: productFormProofKey,
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(textScale),
                viewInsets: EdgeInsets.only(
                  bottom:
                      keyboardBottom > 0
                          ? keyboardBottom
                          : MediaQuery.of(context).viewInsets.bottom,
                ),
                viewPadding: const EdgeInsets.only(bottom: 24),
              ),
              child: child!,
            ),
          ),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: Builder(
          builder:
              (context) => TextButton(
                onPressed:
                    () => showProductLabelRecognitionSheet(
                      context,
                      barcode: '5901234123457',
                      service: service,
                      imagePicker: photos ?? _Photos(),
                    ),
                child: const Text('Open'),
              ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

Future<void> _photo(WidgetTester tester, String title) async {
  await tester.ensureVisible(find.text(title));
  await tester.tap(find.text(title));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(ListTile).last);
  await tester.pumpAndSettle();
}

Future<void> _read(WidgetTester tester) async {
  await _photo(tester, 'Przód opakowania');
  await _photo(tester, 'Tabela wartości');
  await tester.tap(find.byType(FilledButton));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadProductFormFonts);
  testWidgets(
    'recognised fractional nutrition is not rounded to invented zeros',
    (tester) async {
      final service =
          _Labels()
            ..result = const BarcodeLookupResult(
              found: true,
              source: 'product_label_ai',
              name: 'Drink',
              unit: 'ml',
              kcalPer100: 0.04,
              proteinPer100: 0.01,
              fatPer100: 0.02,
              carbsPer100: 0.03,
            );
      await _open(tester, service);
      await _read(tester);
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(service.confirms.single.kcalPer100, 0.04);
      expect(service.confirms.single.proteinPer100, 0.01);
    },
  );

  testWidgets('Escape cancels label review without confirmation', (
    tester,
  ) async {
    final service = _Labels();
    await _open(tester, service);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(FilledButton), findsNothing);
    expect(service.confirms, isEmpty);
  });
  for (final locale in [const Locale('pl', 'PL'), const Locale('en', 'GB')]) {
    for (final dark in [false, true]) {
      testWidgets(
        'label review fits keyboard 320px text150 ${locale.countryCode} dark=$dark',
        (tester) async {
          final english = locale.countryCode == 'GB';
          await _open(
            tester,
            _Labels(),
            locale: locale,
            viewport: const Size(320, 740),
            textScale: 1.5,
            dark: dark,
          );
          await captureProductForm(
            tester,
            'label-${locale.countryCode}-${dark ? 'dark' : 'light'}-photos',
          );
          await _photo(tester, english ? 'Front of pack' : 'Przód opakowania');
          await _photo(tester, english ? 'Nutrition label' : 'Tabela wartości');
          await tester.ensureVisible(find.byType(FilledButton));
          await tester.tap(find.byType(FilledButton));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.byType(TextField).first);
          await tester.showKeyboard(find.byType(TextField).first);
          // Simulate native keyboard insets without requiring a device.
          tester.view.viewInsets = const FakeViewPadding(bottom: 280);
          await tester.pumpAndSettle();
          final button = find.byType(FilledButton);
          await tester.ensureVisible(button);
          await tester.pumpAndSettle();
          final bounds = tester.getRect(button);
          expect(bounds.left, greaterThanOrEqualTo(0));
          expect(bounds.right, lessThanOrEqualTo(320));
          expect(bounds.bottom, lessThanOrEqualTo(740 - 280 - 24));
          expect(tester.takeException(), isNull);
          await captureProductForm(
            tester,
            'label-${locale.countryCode}-${dark ? 'dark' : 'light'}-review',
          );
          tester.view.resetViewInsets();
        },
      );
    }
  }
  testWidgets('missing photos do not call OCR or save', (tester) async {
    final service = _Labels();
    await _open(tester, service);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(service.reads, 0);
    expect(service.confirms, isEmpty);
    expect(find.textContaining('Dodaj oba zdjęcia'), findsOneWidget);
  });

  testWidgets('read error retains photos and allows retry', (tester) async {
    final service = _Labels()..failRead = true;
    await _open(tester, service);
    await _read(tester);
    expect(find.byType(Image), findsNWidgets(2));
    expect(service.confirms, isEmpty);
    service.failRead = false;
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(service.reads, 2);
    expect(find.text('Milk'), findsOneWidget);
  });

  testWidgets('closing sheet during OCR ignores late response without saving', (
    tester,
  ) async {
    final service = _Labels()..pending = Completer<BarcodeLookupResult>();
    await _open(tester, service);
    await _photo(tester, 'Przód opakowania');
    await _photo(tester, 'Tabela wartości');
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    service.pending!.complete(service.result);
    await tester.pumpAndSettle();
    expect(service.confirms, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'English review uses ml and rejects out of range macros in place',
    (tester) async {
      final service = _Labels();
      await _open(tester, service, locale: const Locale('en', 'GB'));
      await _photo(tester, 'Front of pack');
      await _photo(tester, 'Nutrition label');
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.text('Values per 100 ml'), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(4), '201');
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(service.confirms, isEmpty);
      expect(find.text('Enter a number from 0 to 200.'), findsOneWidget);
    },
  );
  testWidgets(
    'English label sheet explains missing details without claiming barcode is absent',
    (tester) async {
      await _open(tester, _Labels(), locale: const Locale('en', 'GB'));
      expect(find.text('Add missing product details'), findsOneWidget);
      expect(
        find.textContaining('Details are missing for barcode'),
        findsOneWidget,
      );
    },
  );

  for (final invalid in ['NaN', 'Infinity', '-1', '0', '100001', 'abc']) {
    testWidgets('OCR confirmation rejects invalid whole pack $invalid', (
      tester,
    ) async {
      final service = _Labels();
      await _open(tester, service);
      await _read(tester);
      // Includes TextField descendants before Form migration, keeping the red
      // test focused on behaviour rather than a particular implementation.
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(2), invalid);
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(service.confirms, isEmpty);
      expect(find.text(invalid), findsOneWidget);
    });
  }

  testWidgets('unknown OCR nutrients stay empty, user correction is required', (
    tester,
  ) async {
    final service =
        _Labels()
          ..result = const BarcodeLookupResult(
            found: true,
            source: 'product_label_ai',
            name: 'Food',
            unit: 'g',
            kcalPer100: 80,
          );
    await _open(tester, service);
    await _read(tester);
    final fields =
        tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields[4].controller!.text, '');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(service.confirms, isEmpty);
  });

  testWidgets(
    'empty pack remains unknown, comma macro and explicit zero are confirmed',
    (tester) async {
      final service = _Labels();
      await _open(tester, service);
      await _read(tester);
      await tester.enterText(find.byType(TextField).at(2), '');
      await tester.enterText(find.byType(TextField).at(4), '0');
      await tester.enterText(find.byType(TextField).at(5), '2,5');
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(service.confirms.single.servingQuantity, isNull);
      expect(service.confirms.single.unit, 'ml');
      expect(service.confirms.single.proteinPer100, 0);
      expect(service.confirms.single.fatPer100, 2.5);
    },
  );

  testWidgets('failed confirmation preserves corrections and retries', (
    tester,
  ) async {
    final service = _Labels()..failConfirm = true;
    await _open(tester, service);
    await _read(tester);
    await tester.enterText(find.byType(TextField).first, 'My milk');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.text('My milk'), findsOneWidget);
    service.failConfirm = false;
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(service.confirms, hasLength(2));
    expect(service.confirms.last.name, 'My milk');
  });

  testWidgets(
    'photo permission failure is recoverable, not an unhandled error',
    (tester) async {
      final photos = _Photos()..fail = true;
      await _open(tester, _Labels(), photos: photos);
      await _photo(tester, 'Przód opakowania');
      expect(tester.takeException(), isNull);
      expect(
        find.textContaining('Nie udało się otworzyć zdjęcia'),
        findsOneWidget,
      );
    },
  );

  testWidgets('cancelled photo picker neither recognises nor saves', (
    tester,
  ) async {
    final service = _Labels();
    await _open(tester, service, photos: _Photos()..cancel = true);
    await _photo(tester, 'Przód opakowania');
    expect(service.reads, 0);
    expect(service.confirms, isEmpty);
  });
}
