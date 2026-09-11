import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/barcode_lookup_result.dart';
import '../models/product.dart';
import '../providers/store_provider.dart';
import '../screens/barcode_scanner_screen.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../utils/error_utils.dart';

/// Okno zgłoszenia własnego produktu do katalogu.
///
/// Wymagane są tylko NAZWA i CENA. Makroskładniki są opcjonalne, bo
/// użytkownik nie zawsze ma etykietę pod ręką, a produkt bez nich i tak
/// przydaje się na liście zakupów. Bez wartości odżywczych wpis
/// w dzienniku kalorii doda po prostu 0 kcal.
class SubmitProductSheet extends StatefulWidget {
  /// Gdy podane — okno działa w trybie EDYCJI istniejącego zgłoszenia
  /// (pola wypełnione danymi z `Product`, zapis idzie przez PUT zamiast
  /// POST). Gdy null — zwykłe zgłoszenie nowego produktu.
  final Product? editing;

  const SubmitProductSheet({super.key, this.editing});

  @override
  State<SubmitProductSheet> createState() => _SubmitProductSheetState();
}

class _SubmitProductSheetState extends State<SubmitProductSheet> {
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

  @override
  void initState() {
    super.initState();
    if (widget.editing?.requestedStoreIds != null) {
      _selectedStoreIds.addAll(widget.editing!.requestedStoreIds!);
    }
    _barcode = widget.editing?.barcode;
  }

  @override
  void dispose() {
    for (final c in [_name, _brand, _price, _kcal, _protein, _fat, _carbs]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _parse(TextEditingController c) {
    final t = c.text.trim().replaceAll(',', '.');
    return t.isEmpty ? null : double.tryParse(t);
  }

  Future<void> _scanBarcode() async {
    final code = await scanBarcode(context);
    if (code == null || !mounted) return;

    setState(() {
      _barcode = code;
      _isScanning = true;
    });

    try {
      final response = await ApiClient().get('/products/barcode/$code');
      final result = BarcodeLookupResult.fromJson(response as Map<String, dynamic>);
      if (!mounted) return;

      if (!result.found) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
            duration: Duration(seconds: 3),
            content: Text(
              'Nie znaleziono tego kodu — uzupełnij dane ręcznie, kod zapisze się przy produkcie.',
            ),
          ));
        return;
      }

      // Wypełniamy TYLKO puste pola — nie nadpisujemy tego, co
      // użytkownik już zdążył wpisać ręcznie przed skanowaniem.
      setState(() {
        if (_name.text.trim().isEmpty && result.name != null) {
          _name.text = result.name!;
        }
        if (_brand.text.trim().isEmpty && result.brand != null) {
          _brand.text = result.brand!;
        }
        if (result.kcalPer100 != null) {
          _showNutrition = true;
          if (_kcal.text.trim().isEmpty) _kcal.text = result.kcalPer100!.toStringAsFixed(0);
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
                : 'Znaleziono w Open Food Facts — sprawdź dane przed zapisaniem.',
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
        'price': _parse(_price),
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
              padding: const EdgeInsets.all(20),
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
                    label: Text(_barcode == null
                        ? 'Wpisz kod kreskowy'
                        : 'Kod: $_barcode (zmień)'),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _name,
                  maxLength: 300,
                  decoration: const InputDecoration(
                    labelText: 'Nazwa produktu *',
                    hintText: 'np. Jogurt naturalny 400 g',
                    border: OutlineInputBorder(),
                  ),
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
                          labelText: 'Cena *',
                          suffixText: 'zł',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final d = _parse(_price);
                          if (d == null || d <= 0) return 'Podaj cenę';
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
                        Text(
                          'Wartości odżywcze na 100 g (opcjonalnie)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
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
                    onPressed: _isSaving ? null : _submit,
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text(_isEditing ? 'Zapisz zmiany' : 'Dodaj produkt'),
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
