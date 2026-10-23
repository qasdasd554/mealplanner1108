import 'package:flutter/material.dart';
import '../utils/lookup_market_context.dart';
import 'package:provider/provider.dart';

import '../services/barcode_lookup_service.dart';
import '../models/product.dart';
import '../models/barcode_lookup_result.dart';
import '../providers/store_provider.dart';
import '../providers/auth_provider.dart';
import '../screens/barcode_scanner_screen.dart';
import 'product_contribution_reward_banner.dart';
import '../services/api_client.dart';
import '../services/product_name_lookup_service.dart';
import '../l10n/market_locale.dart';
import 'product_form_fields_row.dart';
import '../l10n/catalog_labels.dart';
import '../utils/market_money.dart';
import '../utils/product_form_validation.dart';
import '../theme/app_theme.dart';
import '../utils/error_utils.dart';
import 'product_name_autocomplete_field.dart';
import 'product_label_recognition_sheet.dart';

/// Okno zgłoszenia własnego produktu do katalogu.
///
/// Wymagana jest tylko NAZWA. Cena i makroskładniki są opcjonalne, bo
/// użytkownik nie zawsze ma etykietę pod ręką, a produkt bez nich i tak
/// przydaje się na liście zakupów. Dziennik wymaga uzupełnienia makro.
class SubmitProductSheet extends StatefulWidget {
  /// Gdy podane — okno działa w trybie EDYCJI istniejącego zgłoszenia
  /// (pola wypełnione danymi z `Product`, zapis idzie przez PUT zamiast
  /// POST). Gdy null — zwykłe zgłoszenie nowego produktu.
  final Product? editing;
  final bool autoStartBarcodeScan;
  final String? initialBarcode;
  final ApiClient? client;
  final BarcodeLookupService? lookupService;
  final ProductNameLookupService? nameLookupService;
  final Future<String?> Function(BuildContext)? scanner;

  const SubmitProductSheet({
    super.key,
    this.editing,
    this.autoStartBarcodeScan = false,
    this.initialBarcode,
    this.client,
    this.lookupService,
    this.nameLookupService,
    this.scanner,
  });

  @override
  State<SubmitProductSheet> createState() => _SubmitProductSheetState();
}

class _SubmitProductSheetState extends State<SubmitProductSheet> {
  late final BarcodeLookupService _barcodeLookupService =
      widget.lookupService ??
      BarcodeLookupService(
        accountCountry: () => context.registeredLookupCountry,
      );
  late final ApiClient _client = widget.client ?? ApiClient();
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.editing?.name ?? '');
  late final _brand = TextEditingController(text: widget.editing?.brand ?? '');
  late final _price = TextEditingController(
    text: widget.editing?.submittedPrice?.toStringAsFixed(2) ?? '',
  );
  late final _kcal = TextEditingController(
    text: formatProductFormNumber(
      widget.editing?.nutritionPer100.knownValue('kcal'),
    ),
  );
  late final _protein = TextEditingController(
    text: formatProductFormNumber(
      widget.editing?.nutritionPer100.knownValue('protein'),
    ),
  );
  late final _fat = TextEditingController(
    text: formatProductFormNumber(
      widget.editing?.nutritionPer100.knownValue('fat'),
    ),
  );
  late final _carbs = TextEditingController(
    text: formatProductFormNumber(
      widget.editing?.nutritionPer100.knownValue('carbs'),
    ),
  );

  late String _unit = widget.editing?.unit ?? 'szt';
  late final _serving = TextEditingController(
    text: formatProductFormNumber(widget.editing?.servingQuantity),
  );
  late String? _servingUnit = _initialServingUnit(widget.editing);
  late bool _showNutrition = const [
    'kcal',
    'protein',
    'fat',
    'carbs',
  ].any((key) => widget.editing?.nutritionPer100.knownValue(key) != null);
  bool _isSaving = false;

  bool get _isEditing => widget.editing != null;

  static String? _initialServingUnit(Product? product) {
    if (product == null) return 'g';
    if (product.unit == 'ml' || product.unit == 'l') return 'ml';
    if (product.unit == 'g' || product.unit == 'kg') return 'g';
    for (final measure in product.measureOptions) {
      if (measure.code == 'opak' &&
          const {'g', 'ml'}.contains(measure.baseUnit) &&
          measure.baseQuantity.isFinite &&
          measure.baseQuantity > 0) {
        return measure.baseUnit;
      }
    }
    // Legacy pack/item records without physical metadata are ambiguous.
    // Ask for g/ml instead of silently relabelling their stored quantity.
    return null;
  }

  String get _country =>
      widget.editing?.submittedCountryCode ??
      context.read<AuthProvider>().currentUser?.countryCode ??
      'PL';
  String get _currency => currencyForAccountCountry(_country);

  /// Sklepy zaznaczone do zaproponowania — OPCJONALNE. Przy edycji
  /// odczytujemy z requestedStoreIds, jeśli backend je zna; API zwraca
  /// je jako listę identyfikatorów, nie obiektów Store, więc porównanie
  /// idzie po samym ID.
  final Set<String> _selectedStoreIds = {};
  bool _storesInitialized = false;

  /// Kod kreskowy — ze skanowania ALBO już istniejący przy edycji.
  /// Osobne pole od formularza (nie TextEditingController), bo nie
  /// jest edytowalne ręcznie — tylko przez ponowne zeskanowanie.
  String? _barcode;
  bool _isScanning = false;
  int _lookupGeneration = 0;
  String? _dataBarcode;
  double? _priceMin;
  double? _priceMax;
  String? _existingProductId;

  @override
  void initState() {
    super.initState();
    if (widget.editing?.requestedStoreIds != null) {
      _selectedStoreIds.addAll(widget.editing!.requestedStoreIds!);
    }
    _barcode = widget.editing?.barcode ?? widget.initialBarcode;
    _dataBarcode = widget.editing?.barcode;
    if (widget.initialBarcode != null || widget.autoStartBarcodeScan) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (widget.initialBarcode != null) {
          _lookupBarcode(widget.initialBarcode!);
        } else {
          _scanBarcode();
        }
      });
    }
  }

  @override
  void dispose() {
    _barcodeLookupService.close();
    for (final c in [
      _name,
      _brand,
      _price,
      _serving,
      _kcal,
      _protein,
      _fat,
      _carbs,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _parse(TextEditingController c) {
    return parseProductFormNumber(c.text);
  }

  void _applyNameSuggestion(BarcodeLookupResult result) {
    if (_isSaving) return;
    // A deliberate selection wins over any outstanding barcode response.
    _lookupGeneration++;
    const supportedUnits = {'szt', 'g', 'kg', 'ml', 'l'};
    setState(() {
      _isScanning = false;
      if (result.name != null) _name.text = result.name!;
      _brand.text = result.brand ?? '';
      _unit = supportedUnits.contains(result.unit) ? result.unit : 'szt';
      // Kod kreskowy nie dowodzi gramatury opakowania. Zachowujemy bazową
      // jednostkę z etykiety/OFF; backend i tak zapisze fizyczny produkt,
      // a opcja „opakowanie” pojawi się dopiero przy znanej masie netto.
      _serving.text =
          const {'g', 'ml'}.contains(result.unit)
              ? formatProductFormNumber(result.servingQuantity)
              : '';
      _servingUnit =
          const {'g', 'ml'}.contains(result.unit) ? result.unit : 'g';
      _barcode = result.barcode;
      _dataBarcode = result.barcode;
      _existingProductId = _isEditing ? null : result.existingProductId;
      _priceMin = result.priceMin;
      _priceMax = result.priceMax;

      final hasNutrition =
          result.kcalPer100 != null ||
          result.proteinPer100 != null ||
          result.fatPer100 != null ||
          result.carbsPer100 != null;
      if (hasNutrition) {
        _showNutrition = true;
      }
      // An explicit product selection replaces identity-specific metadata.
      // Missing values from B must never retain A's nutrition or pack size.
      _kcal.text = formatProductFormNumber(result.kcalPer100);
      _protein.text = formatProductFormNumber(result.proteinPer100);
      _fat.text = formatProductFormNumber(result.fatPer100);
      _carbs.text = formatProductFormNumber(result.carbsPer100);
    });
  }

  Future<void> _scanBarcode() async {
    if (_isSaving || _isScanning) return;
    final code = await (widget.scanner ?? scanBarcode)(context);
    if (code == null || !mounted) return;

    await _lookupBarcode(code);
  }

  Future<void> _lookupBarcode(String code) async {
    if (!mounted) return;
    final generation = ++_lookupGeneration;

    setState(() {
      // A changed barcode identifies another product, even if its lookup
      // later fails. Never submit A's nutrition/pack under B's barcode.
      if (_dataBarcode != null && _dataBarcode != code) {
        for (final controller in [
          _name,
          _brand,
          _price,
          _serving,
          _kcal,
          _protein,
          _fat,
          _carbs,
        ]) {
          controller.clear();
        }
        _selectedStoreIds.clear();
        _unit = 'szt';
        _servingUnit = 'g';
        _priceMin = null;
        _priceMax = null;
      }
      _existingProductId = null;
      _dataBarcode = code;
      _barcode = code;
      _isScanning = true;
    });

    try {
      var result = await _barcodeLookupService.lookup(code);
      if (!mounted || generation != _lookupGeneration) return;

      if (!result.found || !result.hasCompleteNutrition) {
        final recognized = await showProductLabelRecognitionSheet(
          context,
          barcode: code,
        );
        if (!mounted || generation != _lookupGeneration) return;
        if (recognized == null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                duration: const Duration(seconds: 3),
                content: Text(context.strings.productFormManualAfterScan),
              ),
            );
          return;
        }
        result = recognized;
      }

      // Wypełniamy TYLKO puste pola — nie nadpisujemy tego, co
      // użytkownik już zdążył wpisać ręcznie przed skanowaniem.
      setState(() {
        _existingProductId = _isEditing ? null : result.existingProductId;
        _unit = const {'g', 'ml'}.contains(result.unit) ? result.unit : 'g';
        if (result.servingQuantity != null) {
          _serving.text = formatProductFormNumber(result.servingQuantity);
        }
        _servingUnit =
            const {'g', 'ml'}.contains(result.unit) ? result.unit : 'g';
        if (_name.text.trim().isEmpty && result.name != null) {
          _name.text = result.name!;
        }
        if (_brand.text.trim().isEmpty && result.brand != null) {
          _brand.text = result.brand!;
        }
        _priceMin = result.priceMin;
        _priceMax = result.priceMax;
        final hasNutrition =
            result.kcalPer100 != null ||
            result.proteinPer100 != null ||
            result.fatPer100 != null ||
            result.carbsPer100 != null;
        if (hasNutrition) {
          _showNutrition = true;
          if (_kcal.text.trim().isEmpty && result.kcalPer100 != null) {
            _kcal.text = formatProductFormNumber(result.kcalPer100);
          }
          if (_protein.text.trim().isEmpty && result.proteinPer100 != null) {
            _protein.text = formatProductFormNumber(result.proteinPer100);
          }
          if (_fat.text.trim().isEmpty && result.fatPer100 != null) {
            _fat.text = formatProductFormNumber(result.fatPer100);
          }
          if (_carbs.text.trim().isEmpty && result.carbsPer100 != null) {
            _carbs.text = formatProductFormNumber(result.carbsPer100);
          }
        }
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text(
              result.isFromOwnCatalog
                  ? context.strings.productFormCatalogFilled
                  : context.strings.productFormScanFilled,
            ),
          ),
        );
    } catch (e) {
      if (!mounted || generation != _lookupGeneration) return;
      // Nieudane wyszukiwanie NIE blokuje ręcznego wypełnienia — kod
      // został już zapisany w _barcode, więc i tak trafi do zgłoszenia.
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text(
              context.strings.localeName.startsWith('en')
                  ? context.strings.productFormLookupFailed
                  : friendlyError(e, strings: context.strings),
            ),
          ),
        );
    } finally {
      if (mounted && generation == _lookupGeneration) {
        setState(() => _isScanning = false);
      }
    }
  }

  Future<void> _submit() async {
    if (_isSaving || _isScanning) return;
    final invalidNutrition = [_kcal, _protein, _fat, _carbs].any(
      (field) =>
          !validProductFormNumber(
            field.text,
            maximum: field == _kcal ? 2000 : 200,
          ),
    );
    if (invalidNutrition && !_showNutrition) {
      setState(() => _showNutrition = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _validateForm();
      });
      return;
    }
    if (!_validateForm()) return;

    setState(() => _isSaving = true);
    try {
      final body = {
        'name': _name.text.trim(),
        if (_parse(_price) != null) 'price': _parse(_price),
        'unit': _unit,
        if (_brand.text.trim().isNotEmpty) 'brand': _brand.text.trim(),
        if (_parse(_kcal) != null) 'kcal_per_100': _parse(_kcal),
        if (_parse(_protein) != null) 'protein_per_100': _parse(_protein),
        if (_parse(_fat) != null) 'fat_per_100': _parse(_fat),
        if (_parse(_carbs) != null) 'carbs_per_100': _parse(_carbs),
        // The server validates store market membership. Do not erase prior
        // selections merely because the lazy shop list has not loaded yet.
        'store_ids': _selectedStoreIds.toList(),
        if (_barcode != null) 'barcode': _barcode,
        if (_parse(_serving) != null) 'serving_quantity': _parse(_serving),
        if (_parse(_serving) != null) 'serving_unit': _servingUnit,
      };
      var pointsAwarded = 0;
      int? premiumPoints;
      if (_isEditing) {
        await _client.put('/products/${widget.editing!.id}', body: body);
      } else {
        final response = await _client.post('/products/submit', body: body);
        if (response is Map<String, dynamic>) {
          pointsAwarded = (response['points_awarded'] as num?)?.toInt() ?? 0;
          premiumPoints = (response['premium_points'] as num?)?.toInt();
        }
        if (mounted) {
          await context.read<AuthProvider>().loadProfile();
        }
      }
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop(true);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 4),
            content: Text(
              _isEditing
                  ? context.strings.productFormEditSaved
                  : pointsAwarded > 0
                  ? context.strings.productFormReward(pointsAwarded) +
                      (premiumPoints == null
                          ? ''
                          : context.strings.productFormBalance(premiumPoints))
                  : context.strings.productFormAdded,
            ),
          ),
        );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text(
              context.strings.localeName.startsWith('en')
                  ? context.strings.productFormRequestFailed
                  : friendlyError(e, strings: context.strings),
            ),
            backgroundColor: AppTheme.errorColor,
          ),
        );
    }
  }

  bool _validateForm() {
    final invalid = _formKey.currentState!.validateGranularly();
    if (invalid.isEmpty) return true;
    Scrollable.ensureVisible(
      invalid.first.context,
      alignment: 0.2,
      duration: const Duration(milliseconds: 200),
    );
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Form(
            key: _formKey,
            child: ListView(
              controller: scrollController,
              // NAPRAWA: poprzedni padding (stałe 20 z każdej strony)
              // nie uwzględniał dolnego paska systemowego (gesty
              // nawigacji na Androidzie) — ostatni element listy, czyli
              // przycisk "Dodaj produkt", kończył się dokładnie na
              // granicy tego paska albo lekko za nim. Dodatkowe 20 px
              // NA WIERZCHU bezpiecznego marginesu systemowego daje mu
              // realny oddech, niezależnie od kształtu nawigacji
              // systemowej na danym telefonie.
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                20 + MediaQuery.of(context).viewPadding.bottom,
              ),
              children: [
                Text(
                  _isEditing
                      ? context.strings.productFormEdit
                      : context.strings.productFormAdd,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  context.strings.productFormVisibility,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    height: 1.35,
                  ),
                ),
                if (!_isEditing) ...[
                  const SizedBox(height: 12),
                  const ProductContributionRewardBanner(compact: true),
                ],
                const SizedBox(height: 20),
                // Skanowanie kodu kreskowego — OPCJONALNE, ale znacznie
                // przyspiesza wypełnienie: jeśli produkt jest w Waszym
                // katalogu albo w Open Food Facts, nazwa i wartości
                // odżywcze wypełniają się same.
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isScanning || _isSaving ? null : _scanBarcode,
                    icon:
                        _isScanning
                            ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.barcode_reader, size: 18),
                    label: Text(
                      _barcode == null
                          ? 'Skanuj kod kreskowy'
                          : context.strings.productFormScanned(_barcode!),
                      maxLines: 2,
                      softWrap: true,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_existingProductId != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.primaryColor.withOpacity(0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(context.strings.productFormAlreadyExists),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                ProductNameAutocompleteField(
                  service: widget.nameLookupService,
                  controller: _name,
                  maxLength: 300,
                  labelText: context.strings.productFormName,
                  hintText: context.strings.productFormNameHint,
                  onSelected: _applyNameSuggestion,
                  validator:
                      (v) =>
                          (v == null ||
                                  v.trim().length < 2 ||
                                  v.trim().length > 300)
                              ? context.strings.productFormNameRequired
                              : null,
                ),
                TextFormField(
                  controller: _brand,
                  maxLength: 200,
                  validator:
                      (value) =>
                          (value?.trim().length ?? 0) > 200
                              ? context.strings.productFormBrandError
                              : null,
                  decoration: InputDecoration(
                    labelText: context.strings.productFormBrandOptional,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                // Lookup price ranges are legacy PLN estimates, not GBP.
                if (_country == 'PL' &&
                    _priceMin != null &&
                    _priceMax != null &&
                    _priceMin!.isFinite &&
                    _priceMax!.isFinite &&
                    _priceMin! >= 0 &&
                    _priceMax! >= _priceMin!) ...[
                  Text(
                    context.strings.productFormTypicalPrice(
                      _priceMin!.toStringAsFixed(0),
                      _priceMax!.toStringAsFixed(0),
                    ),
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                ProductFormFieldsRow(
                  firstFlex: 2,
                  first: TextFormField(
                    controller: _price,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: context.strings.productFormPrice,
                      errorMaxLines: 3,
                      suffixText: _currency == 'GBP' ? '£' : 'zł',
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (!validProductFormNumber(
                        v ?? '',
                        maximum: 10000,
                        allowZero: false,
                      )) {
                        return context.strings.productFormPriceError;
                      }
                      return null;
                    },
                  ),
                  second: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _unit,
                    decoration: InputDecoration(
                      labelText: context.strings.productFormUnit,
                      border: const OutlineInputBorder(),
                    ),
                    items:
                        [
                              'szt',
                              'g',
                              'kg',
                              'ml',
                              'l',
                              if (_isEditing &&
                                  !const {
                                    'szt',
                                    'g',
                                    'kg',
                                    'ml',
                                    'l',
                                  }.contains(_unit))
                                _unit,
                            ]
                            .map(
                              (u) => DropdownMenuItem(
                                value: u,
                                child: Text(context.strings.unitLabel(u)),
                              ),
                            )
                            .toList(),
                    onChanged: (v) => setState(() => _unit = v ?? 'szt'),
                  ),
                ),
                const SizedBox(height: 14),
                ProductFormFieldsRow(
                  firstFlex: 2,
                  first: TextFormField(
                    controller: _serving,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: context.strings.productFormPack,
                      errorMaxLines: 3,
                      hintText: context.strings.productFormPackExample,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      return !validProductFormNumber(
                            value ?? '',
                            maximum: 100000,
                            allowZero: false,
                          )
                          ? context.strings.productFormPackError
                          : null;
                    },
                  ),
                  second: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _servingUnit,
                    validator:
                        (value) =>
                            _serving.text.trim().isNotEmpty && value == null
                                ? context.strings.productFormChooseUnit
                                : null,
                    decoration: InputDecoration(
                      errorMaxLines: 4,
                      labelText: context.strings.productFormUnit,
                      border: const OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'g', child: Text('g')),
                      DropdownMenuItem(value: 'ml', child: Text('ml')),
                    ],
                    onChanged:
                        (value) => setState(
                          () => _servingUnit = value ?? _servingUnit,
                        ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    context.strings.productFormPackHelp,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // Makroskładniki chowamy domyślnie — to pola opcjonalne,
                // a rozwinięty formularz z siedmioma polami zniechęcałby
                // do dodania czegokolwiek.
                InkWell(
                  onTap: () => setState(() => _showNutrition = !_showNutrition),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          _showNutrition
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            context.strings.productFormNutrition(
                              _servingUnit ?? 'g/ml',
                            ),
                            maxLines: 2,
                            softWrap: true,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_showNutrition) ...[
                  const SizedBox(height: 6),
                  Text(
                    context.strings.productFormNutritionHelp,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _numField(
                          _kcal,
                          context.strings.productFormCalories,
                          'kcal',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _numField(
                          _protein,
                          context.strings.productFormProtein,
                          'g',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _numField(
                          _fat,
                          context.strings.productFormFat,
                          'g',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _numField(
                          _carbs,
                          context.strings.productFormCarbs,
                          'g',
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 18),
                // Wybór sklepów — OPCJONALNY. Sama lista niczego jeszcze
                // nie tworzy; dopiero akceptacja administratora zamienia
                // każdy zaznaczony sklep w prawdziwy wpis w bazie danego
                // sklepu, z podaną tu ceną.
                Consumer<StoreProvider>(
                  builder: (context, storeProvider, _) {
                    if (storeProvider.stores.isEmpty) {
                      // Ładujemy leniwie, tylko gdy ktoś faktycznie
                      // otworzy to okno — bez sensu ciągnąć listę
                      // sklepów przy każdym uruchomieniu aplikacji.
                      if (!_storesInitialized) {
                        _storesInitialized = true;
                        WidgetsBinding.instance.addPostFrameCallback(
                          (_) => storeProvider.loadStores(),
                        );
                      }
                      return const SizedBox.shrink();
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.strings.productFormShops,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.strings.productFormShopsHelp,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children:
                              storeProvider.stores
                                  .where(
                                    (store) =>
                                        store.countryCode == _country &&
                                        store.currencyCode == _currency,
                                  )
                                  .map((store) {
                                    final selected = _selectedStoreIds.contains(
                                      store.id,
                                    );
                                    return FilterChip(
                                      label: Text(store.name),
                                      selected: selected,
                                      onSelected:
                                          (v) => setState(() {
                                            if (v) {
                                              _selectedStoreIds.add(store.id);
                                            } else {
                                              _selectedStoreIds.remove(
                                                store.id,
                                              );
                                            }
                                          }),
                                    );
                                  })
                                  .toList(),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 22),
                SizedBox(
                  // Let larger text wrap without clipping the existing action.
                  width: double.infinity,
                  child: FilledButton(
                    onPressed:
                        _isSaving || _isScanning
                            ? null
                            : (_existingProductId != null
                                ? () => Navigator.of(context).pop(false)
                                : _submit),
                    child:
                        _isSaving
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : Text(
                              _existingProductId != null
                                  ? context.strings.productFormCloseExisting
                                  : (_isEditing
                                      ? context.strings.productFormSaveChanges
                                      : context.strings.productFormSave),
                            ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _numField(TextEditingController c, String label, String suffix) {
    return TextFormField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator:
          (value) =>
              validProductFormNumber(
                    value ?? '',
                    maximum: c == _kcal ? 2000 : 200,
                  )
                  ? null
                  : context.strings.productFormNumberRange(
                    c == _kcal ? '2000' : '200',
                  ),
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        errorMaxLines: 3,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }
}
