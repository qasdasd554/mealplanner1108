import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/barcode_lookup_service.dart';
import '../models/product.dart';
import '../models/barcode_lookup_result.dart';
import '../providers/store_provider.dart';
import '../screens/barcode_scanner_screen.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../utils/error_utils.dart';
import 'product_name_autocomplete_field.dart';
import 'product_label_recognition_sheet.dart';

/// Okno zgłoszenia własnego produktu do katalogu.
///
/// Wymagana jest tylko NAZWA. Cena i makroskładniki są opcjonalne, bo
/// użytkownik nie zawsze ma etykietę pod ręką, a produkt bez nich i tak
/// przydaje się na liście zakupów. Bez wartości odżywczych wpis
/// w dzienniku kalorii doda po prostu 0 kcal.
class SubmitProductSheet extends StatefulWidget {
  /// Gdy podane — okno działa w trybie EDYCJI istniejącego zgłoszenia
  /// (pola wypełnione danymi z `Product`, zapis idzie przez PUT zamiast
  /// POST). Gdy null — zwykłe zgłoszenie nowego produktu.
  final Product? editing;
  final bool autoStartBarcodeScan;
  final String? initialBarcode;

  const SubmitProductSheet({
    super.key,
    this.editing,
    this.autoStartBarcodeScan = false,
    this.initialBarcode,
  });

  @override
  State<SubmitProductSheet> createState() => _SubmitProductSheetState();
}

class _SubmitProductSheetState extends State<SubmitProductSheet> {
  final BarcodeLookupService _barcodeLookupService = BarcodeLookupService();
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.editing?.name ?? '');
  late final _brand = TextEditingController(text: widget.editing?.brand ?? '');
  late final _price = TextEditingController(
      text: widget.editing?.submittedPrice?.toStringAsFixed(2) ?? '');
  late final _kcal = TextEditingController(text: _prefillNum(widget.editing?.nutritionPer100.kcal));
  late final _protein = TextEditingController(text: _prefillNum(widget.editing?.nutritionPer100.protein, decimals: 1));
  late final _fat = TextEditingController(text: _prefillNum(widget.editing?.nutritionPer100.fat, decimals: 1));
  late final _carbs = TextEditingController(text: _prefillNum(widget.editing?.nutritionPer100.carbs, decimals: 1));

  /// Puste pole zamiast "0" — zero na starcie formularza wygląda jak
  /// świadomie wpisana wartość, a najczęściej oznacza po prostu brak danych.
  static String _prefillNum(double? value, {int decimals = 0}) {
    if (value == null || value <= 0) return '';
    return value.toStringAsFixed(decimals);
  }

  late String _unit = widget.editing?.unit ?? 'szt';
  late bool _showNutrition = (widget.editing?.nutritionPer100.kcal ?? 0) > 0;
  bool _isSaving = false;

  bool get _isEditing => widget.editing != null;

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
    for (final c in [_name, _brand, _price, _kcal, _protein, _fat, _carbs]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _parse(TextEditingController c) {
    final t = c.text.trim().replaceAll(',', '.');
    return t.isEmpty ? null : double.tryParse(t);
  }

  void _applyNameSuggestion(BarcodeLookupResult result) {
    const supportedUnits = {'szt', 'g', 'kg', 'ml', 'l', 'opak'};
    setState(() {
      if (result.name != null) _name.text = result.name!;
      if (result.brand?.trim().isNotEmpty == true) {
        _brand.text = result.brand!;
      }
      if (supportedUnits.contains(result.unit)) _unit = result.unit;
      _barcode = result.barcode ?? _barcode;
      _priceMin = result.priceMin;
      _priceMax = result.priceMax;

      final hasNutrition = result.kcalPer100 != null ||
          result.proteinPer100 != null ||
          result.fatPer100 != null ||
          result.carbsPer100 != null;
      if (hasNutrition) {
        _showNutrition = true;
        if (result.kcalPer100 != null) {
          _kcal.text = result.kcalPer100!.toStringAsFixed(0);
        }
        if (result.proteinPer100 != null) {
          _protein.text = result.proteinPer100!.toStringAsFixed(1);
        }
        if (result.fatPer100 != null) {
          _fat.text = result.fatPer100!.toStringAsFixed(1);
        }
        if (result.carbsPer100 != null) {
          _carbs.text = result.carbsPer100!.toStringAsFixed(1);
        }
      }
    });
  }

  Future<void> _scanBarcode() async {
    final code = await scanBarcode(context);
    if (code == null || !mounted) return;

    await _lookupBarcode(code);
  }

  Future<void> _lookupBarcode(String code) async {
    if (!mounted) return;

    setState(() {
      _barcode = code;
      _isScanning = true;
    });

    try {
      var result = await _barcodeLookupService.lookup(code);
      if (!mounted) return;

      if (!result.found) {
        final recognized = await showProductLabelRecognitionSheet(
          context,
          barcode: code,
        );
        if (!mounted) return;
        if (recognized == null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(const SnackBar(
              duration: Duration(seconds: 3),
              content: Text(
                'Możesz nadal wpisać dane ręcznie. Kod zostanie zachowany.',
              ),
            ));
          return;
        }
        result = recognized;
      }

      // Wypełniamy TYLKO puste pola — nie nadpisujemy tego, co
      // użytkownik już zdążył wpisać ręcznie przed skanowaniem.
      setState(() {
        _existingProductId = _isEditing ? null : result.existingProductId;
        if (_name.text.trim().isEmpty && result.name != null) {
          _name.text = result.name!;
        }
        if (_brand.text.trim().isEmpty && result.brand != null) {
          _brand.text = result.brand!;
        }
        _priceMin = result.priceMin;
        _priceMax = result.priceMax;
        final hasNutrition = result.kcalPer100 != null ||
            result.proteinPer100 != null ||
            result.fatPer100 != null ||
            result.carbsPer100 != null;
        if (hasNutrition) {
          _showNutrition = true;
          if (_kcal.text.trim().isEmpty && result.kcalPer100 != null) {
            _kcal.text = result.kcalPer100!.toStringAsFixed(0);
          }
          if (_protein.text.trim().isEmpty && result.proteinPer100 != null) {
            _protein.text = result.proteinPer100!.toStringAsFixed(1);
          }
          if (_fat.text.trim().isEmpty && result.fatPer100 != null) {
            _fat.text = result.fatPer100!.toStringAsFixed(1);
          }
          if (_carbs.text.trim().isEmpty && result.carbsPer100 != null) {
            _carbs.text = result.carbsPer100!.toStringAsFixed(1);
          }
        }
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          duration: const Duration(seconds: 3),
          content: Text(
            result.isFromOwnCatalog
                ? 'Znaleziono w katalogu — dane wypełnione automatycznie.'
                : 'Znaleziono produkt — nazwa, marka i makro zostały uzupełnione.',
          ),
        ));
    } catch (e) {
      if (!mounted) return;
      // Nieudane wyszukiwanie NIE blokuje ręcznego wypełnienia — kod
      // został już zapisany w _barcode, więc i tak trafi do zgłoszenia.
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          duration: const Duration(seconds: 3),
          content: Text(friendlyError(e)),
        ));
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

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
        'store_ids': _selectedStoreIds.toList(),
        if (_barcode != null) 'barcode': _barcode,
      };
      if (_isEditing) {
        await ApiClient().put('/products/${widget.editing!.id}', body: body);
      } else {
        await ApiClient().post('/products/submit', body: body);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          duration: const Duration(seconds: 4),
          content: Text(
            _isEditing
                ? 'Zapisano. Zmiany trafiają ponownie do sprawdzenia przez administratora.'
                : 'Produkt dodany. Możesz go już używać — pozostali zobaczą go '
                    'po zatwierdzeniu przez administratora.',
          ),
        ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          duration: const Duration(seconds: 3),
          content: Text(friendlyError(e)),
          backgroundColor: AppTheme.errorColor,
        ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
                20 + MediaQuery.of(context).padding.bottom,
              ),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.textSecondary.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(_isEditing ? 'Edytuj produkt' : 'Dodaj własny produkt',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  'Produkt będzie od razu dostępny dla Ciebie. Pozostali '
                  'użytkownicy zobaczą go po zatwierdzeniu przez administratora.',
                  style: TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary, height: 1.35),
                ),
                const SizedBox(height: 20),
                // Skanowanie kodu kreskowego — OPCJONALNE, ale znacznie
                // przyspiesza wypełnienie: jeśli produkt jest w Waszym
                // katalogu albo w Open Food Facts, nazwa i wartości
                // odżywcze wypełniają się same.
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isScanning ? null : _scanBarcode,
                    icon: _isScanning
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.barcode_reader, size: 18),
                    label: Text(
                      _barcode == null
                          ? 'Skanuj kod kreskowy'
                          : 'Zeskanowano: $_barcode (zmień)',
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
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle_outline,
                            color: AppTheme.primaryColor),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Ten produkt jest już zapisany w bazie. Nie trzeba dodawać go ponownie.',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                ProductNameAutocompleteField(
                  controller: _name,
                  maxLength: 300,
                  labelText: 'Nazwa produktu *',
                  hintText: 'Wpisz nazwę lub wybierz podpowiedź',
                  onSelected: _applyNameSuggestion,
                  validator: (v) => (v == null || v.trim().length < 2)
                      ? 'Podaj nazwę produktu'
                      : null,
                ),
                TextFormField(
                  controller: _brand,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    labelText: 'Marka (opcjonalnie)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                if (_priceMin != null && _priceMax != null) ...[
                  Text(
                    'Typowy zakres cen: ${_priceMin!.toStringAsFixed(0)}–${_priceMax!.toStringAsFixed(0)} zł',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _price,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Cena widoczna w sklepie (opcjonalnie)',
                          suffixText: 'zł',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final d = _parse(_price);
                          if (v != null && v.trim().isNotEmpty &&
                              (d == null || d <= 0)) {
                            return 'Podaj prawidłową cenę';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _unit,
                        decoration: const InputDecoration(
                          labelText: 'Jedn.',
                          border: OutlineInputBorder(),
                        ),
                        items: const ['szt', 'g', 'kg', 'ml', 'l', 'opak']
                            .map((u) =>
                                DropdownMenuItem(value: u, child: Text(u)))
                            .toList(),
                        onChanged: (v) => setState(() => _unit = v ?? 'szt'),
                      ),
                    ),
                  ],
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
                            'Wartości odżywcze na 100 g (opcjonalnie)',
                            maxLines: 2,
                            softWrap: true,
                            style: TextStyle(
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
                    'Bez tych danych produkt doda 0 kcal do dziennika — '
                    'nadal jednak przyda się na liście zakupów.',
                    style:
                        TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _numField(_kcal, 'Kalorie', 'kcal')),
                      const SizedBox(width: 10),
                      Expanded(child: _numField(_protein, 'Białko', 'g')),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _numField(_fat, 'Tłuszcze', 'g')),
                      const SizedBox(width: 10),
                      Expanded(child: _numField(_carbs, 'Węglow.', 'g')),
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
                          'W jakich sklepach ma być dostępny? (opcjonalnie)',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Można zaznaczyć kilka. Widoczność w wybranych '
                          'sklepach pojawi się dopiero po akceptacji.',
                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: storeProvider.stores.map((store) {
                            final selected = _selectedStoreIds.contains(store.id);
                            return FilterChip(
                              label: Text(store.name),
                              selected: selected,
                              onSelected: (v) => setState(() {
                                if (v) {
                                  _selectedStoreIds.add(store.id);
                                } else {
                                  _selectedStoreIds.remove(store.id);
                                }
                              }),
                            );
                          }).toList(),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 22),
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: _isSaving
                        ? null
                        : (_existingProductId != null
                            ? () => Navigator.of(context).pop(false)
                            : _submit),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            _existingProductId != null
                                ? 'Zamknij — produkt jest już w bazie'
                                : (_isEditing
                                    ? 'Zapisz zmiany'
                                    : 'Dodaj produkt'),
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
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }
}
