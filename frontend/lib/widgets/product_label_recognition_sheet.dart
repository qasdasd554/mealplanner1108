import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/barcode_lookup_result.dart';
import '../services/barcode_lookup_service.dart';
import '../theme/app_theme.dart';
import '../utils/error_utils.dart';

Future<BarcodeLookupResult?> showProductLabelRecognitionSheet(
  BuildContext context, {
  required String barcode,
}) {
  return showModalBottomSheet<BarcodeLookupResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.92,
    ),
    builder: (_) => _ProductLabelRecognitionSheet(barcode: barcode),
  );
}

class _ProductLabelRecognitionSheet extends StatefulWidget {
  final String barcode;

  const _ProductLabelRecognitionSheet({required this.barcode});

  @override
  State<_ProductLabelRecognitionSheet> createState() =>
      _ProductLabelRecognitionSheetState();
}

class _ProductLabelRecognitionSheetState
    extends State<_ProductLabelRecognitionSheet> {
  final _picker = ImagePicker();
  final _service = BarcodeLookupService();
  final _name = TextEditingController();
  final _brand = TextEditingController();
  final _serving = TextEditingController();
  final _kcal = TextEditingController();
  final _protein = TextEditingController();
  final _fat = TextEditingController();
  final _carbs = TextEditingController();

  String? _frontBase64;
  String? _nutritionBase64;
  BarcodeLookupResult? _recognized;
  String _unit = 'g';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _service.close();
    for (final controller in [
      _name,
      _brand,
      _serving,
      _kcal,
      _protein,
      _fat,
      _carbs,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  double? _number(TextEditingController controller) {
    final value = controller.text.trim().replaceAll(',', '.');
    return value.isEmpty ? null : double.tryParse(value);
  }

  Future<ImageSource?> _chooseSource() => showModalBottomSheet<ImageSource>(
    context: context,
    builder:
        (context) => SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Zrób zdjęcie'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Wybierz z galerii'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
  );

  Future<void> _pickPhoto({required bool front}) async {
    final source = await _chooseSource();
    if (source == null) return;
    final file = await _picker.pickImage(
      source: source,
      imageQuality: 75,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (file == null || !mounted) return;
    final encoded = base64Encode(await file.readAsBytes());
    if (!mounted) return;
    setState(() {
      if (front) {
        _frontBase64 = encoded;
      } else {
        _nutritionBase64 = encoded;
      }
      _recognized = null;
      _error = null;
    });
  }

  Future<void> _recognize() async {
    if (_frontBase64 == null || _nutritionBase64 == null) {
      setState(() => _error = 'Dodaj oba zdjęcia: przód i tabelę wartości.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await _service.recognizeLabel(
        barcode: widget.barcode,
        frontPhotoBase64: _frontBase64!,
        nutritionPhotoBase64: _nutritionBase64!,
      );
      if (!mounted) return;
      _name.text = result.name ?? '';
      _brand.text = result.brand ?? '';
      _serving.text = _format(result.servingQuantity);
      _kcal.text = _format(result.kcalPer100);
      _protein.text = _format(result.proteinPer100);
      _fat.text = _format(result.fatPer100);
      _carbs.text = _format(result.carbsPer100);
      setState(() {
        _recognized = result;
        _unit =
            const {'g', 'ml', 'szt'}.contains(result.unit) ? result.unit : 'g';
      });
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _format(double? value) {
    if (value == null) return '';
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
  }

  Future<void> _confirm() async {
    if (_name.text.trim().length < 2) {
      setState(() => _error = 'Sprawdź i uzupełnij nazwę produktu.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final confirmed = await _service.confirmRecognizedLabel(
        BarcodeLookupResult(
          found: true,
          source: 'product_label_ai',
          barcode: widget.barcode,
          name: _name.text.trim(),
          brand: _brand.text.trim().isEmpty ? null : _brand.text.trim(),
          unit: _unit,
          servingQuantity: _number(_serving),
          kcalPer100: _number(_kcal),
          proteinPer100: _number(_protein),
          fatPer100: _number(_fat),
          carbsPer100: _number(_carbs),
          priceMin: _recognized?.priceMin,
          priceMax: _recognized?.priceMax,
        ),
      );
      if (mounted) Navigator.of(context).pop(confirmed);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 8),
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          24 + media.viewInsets.bottom + media.viewPadding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dodaj brakujący produkt',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              'Kod ${widget.barcode} nie występuje w dostępnych bazach. '
              'Dwa wyraźne zdjęcia pozwolą odczytać dane bez ręcznego przepisywania.',
              style: TextStyle(color: AppTheme.textSecondary, height: 1.35),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _photoCard(
                    title: 'Przód opakowania',
                    value: _frontBase64,
                    onTap: () => _pickPhoto(front: true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _photoCard(
                    title: 'Tabela wartości',
                    value: _nutritionBase64,
                    onTap: () => _pickPhoto(front: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (_recognized == null)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _recognize,
                  icon:
                      _busy
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.auto_awesome),
                  label: Text(
                    _busy ? 'Odczytywanie etykiety…' : 'Odczytaj dane',
                  ),
                ),
              )
            else ...[
              Text(
                'Sprawdź dane przed zapisaniem',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              _field(_name, 'Nazwa produktu *'),
              _field(_brand, 'Marka'),
              Row(
                children: [
                  Expanded(child: _numberField(_serving, 'Porcja/opakowanie')),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 100,
                    child: DropdownButtonFormField<String>(
                      value: _unit,
                      decoration: const InputDecoration(
                        labelText: 'Jedn.',
                        border: OutlineInputBorder(),
                      ),
                      items:
                          const ['g', 'ml', 'szt']
                              .map(
                                (unit) => DropdownMenuItem(
                                  value: unit,
                                  child: Text(unit),
                                ),
                              )
                              .toList(),
                      onChanged:
                          (value) => setState(() => _unit = value ?? 'g'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Wartości na 100 ${_unit == 'ml' ? 'ml' : 'g'}',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _numberField(_kcal, 'kcal')),
                  const SizedBox(width: 8),
                  Expanded(child: _numberField(_protein, 'Białko')),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _numberField(_fat, 'Tłuszcz')),
                  const SizedBox(width: 8),
                  Expanded(child: _numberField(_carbs, 'Węglowodany')),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _confirm,
                  icon:
                      _busy
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.check),
                  label: const Text('Potwierdź i zapisz'),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: AppTheme.errorColor)),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _photoCard({
    required String title,
    required String? value,
    required VoidCallback onTap,
  }) {
    final Uint8List? bytes = value == null ? null : base64Decode(value);
    return InkWell(
      onTap: _busy ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 132,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.35)),
        ),
        clipBehavior: Clip.antiAlias,
        child:
            bytes == null
                ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.add_a_photo_outlined,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                )
                : Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(bytes, fit: BoxFit.cover),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        width: double.infinity,
                        color: Colors.black54,
                        padding: const EdgeInsets.all(5),
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    ),
  );

  Widget _numberField(TextEditingController controller, String label) =>
      TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      );
}
