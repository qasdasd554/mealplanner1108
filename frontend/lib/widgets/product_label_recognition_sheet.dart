import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../utils/lookup_market_context.dart';
import 'package:image_picker/image_picker.dart';

import '../models/barcode_lookup_result.dart';
import '../services/barcode_lookup_service.dart';
import '../theme/app_theme.dart';
import '../utils/error_utils.dart';
import '../utils/product_form_validation.dart';
import '../l10n/market_locale.dart';
import 'product_form_fields_row.dart';

Future<BarcodeLookupResult?> showProductLabelRecognitionSheet(
  BuildContext context, {
  required String barcode,
  BarcodeLookupService? service,
  ImagePicker? imagePicker,
}) {
  return showModalBottomSheet<BarcodeLookupResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.92,
    ),
    builder:
        (_) => _ProductLabelRecognitionSheet(
          barcode: barcode,
          service: service,
          imagePicker: imagePicker,
        ),
  );
}

class _ProductLabelRecognitionSheet extends StatefulWidget {
  final String barcode;
  final BarcodeLookupService? service;
  final ImagePicker? imagePicker;

  const _ProductLabelRecognitionSheet({
    required this.barcode,
    this.service,
    this.imagePicker,
  });

  @override
  State<_ProductLabelRecognitionSheet> createState() =>
      _ProductLabelRecognitionSheetState();
}

class _ProductLabelRecognitionSheetState
    extends State<_ProductLabelRecognitionSheet> {
  late final _picker = widget.imagePicker ?? ImagePicker();
  late final _service =
      widget.service ??
      BarcodeLookupService(
        accountCountry: () => context.registeredLookupCountry,
      );
  final _name = TextEditingController();
  final _brand = TextEditingController();
  final _serving = TextEditingController();
  final _kcal = TextEditingController();
  final _protein = TextEditingController();
  final _fat = TextEditingController();
  final _carbs = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  bool _pickingPhoto = false;
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
    return parseProductFormNumber(controller.text);
  }

  Future<ImageSource?> _chooseSource() => showModalBottomSheet<ImageSource>(
    context: context,
    builder:
        (context) => SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: Text(context.strings.productLabelTakePhoto),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(context.strings.productLabelGallery),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
  );

  Future<void> _pickPhoto({required bool front}) async {
    if (_busy || _pickingPhoto) return;
    setState(() => _pickingPhoto = true);
    try {
      final source = await _chooseSource();
      if (source == null || !mounted) return;
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
    } catch (_) {
      if (mounted) {
        setState(() => _error = context.strings.productLabelPhotoFailed);
      }
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  Future<void> _recognize() async {
    if (_busy || _pickingPhoto) return;
    if (_frontBase64 == null || _nutritionBase64 == null) {
      setState(() => _error = context.strings.productLabelBothPhotos);
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
      _serving.text = formatProductFormNumber(result.servingQuantity);
      _kcal.text = formatProductFormNumber(result.kcalPer100);
      _protein.text = formatProductFormNumber(result.proteinPer100);
      _fat.text = formatProductFormNumber(result.fatPer100);
      _carbs.text = formatProductFormNumber(result.carbsPer100);
      setState(() {
        _recognized = result;
        _unit = const {'g', 'ml'}.contains(result.unit) ? result.unit : 'g';
      });
    } catch (error) {
      if (mounted) {
        setState(
          () =>
              _error =
                  context.strings.localeName.startsWith('en')
                      ? context.strings.productLabelReadFailed
                      : friendlyError(error, strings: context.strings),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    if (_busy || _pickingPhoto) return;
    final invalid = _formKey.currentState!.validateGranularly();
    if (invalid.isNotEmpty) {
      Scrollable.ensureVisible(
        invalid.first.context,
        alignment: 0.2,
        duration: const Duration(milliseconds: 200),
      );
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
      if (mounted) {
        setState(
          () =>
              _error =
                  context.strings.localeName.startsWith('en')
                      ? context.strings.productFormRequestFailed
                      : friendlyError(error, strings: context.strings),
        );
      }
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
      child: Form(
        key: _formKey,
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
                context.strings.productLabelTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                context.strings.productLabelIntro(widget.barcode),
                style: TextStyle(color: AppTheme.textSecondary, height: 1.35),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _photoCard(
                      title: context.strings.productLabelFront,
                      value: _frontBase64,
                      onTap: () => _pickPhoto(front: true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _photoCard(
                      title: context.strings.productLabelNutrition,
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
                    onPressed: _busy || _pickingPhoto ? null : _recognize,
                    icon:
                        _busy
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.auto_awesome),
                    label: Text(
                      _busy
                          ? context.strings.productLabelReading
                          : context.strings.productLabelRead,
                    ),
                  ),
                )
              else ...[
                Text(
                  context.strings.productLabelReview,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                _field(_name, context.strings.productFormName),
                _field(_brand, context.strings.productFormBrand),
                ProductFormFieldsRow(
                  secondWidth: 100,
                  first: _numberField(
                    _serving,
                    context.strings.productFormPack,
                  ),
                  second: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _unit,
                    decoration: InputDecoration(
                      labelText: context.strings.productFormUnit,
                      border: const OutlineInputBorder(),
                    ),
                    items:
                        const ['g', 'ml']
                            .map(
                              (unit) => DropdownMenuItem(
                                value: unit,
                                child: Text(unit),
                              ),
                            )
                            .toList(),
                    onChanged:
                        _busy
                            ? null
                            : (value) => setState(() => _unit = value ?? 'g'),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  context.strings.productFormPackHelp,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  context.strings.productLabelPer100(_unit),
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _numberField(_kcal, 'kcal')),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _numberField(
                        _protein,
                        context.strings.productFormProtein,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _numberField(_fat, context.strings.productFormFat),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _numberField(
                        _carbs,
                        context.strings.productFormCarbs,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _busy || _pickingPhoto ? null : _confirm,
                    icon:
                        _busy
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.check),
                    label: Text(context.strings.productLabelConfirm),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 10),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppTheme.errorColor),
                  ),
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
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
      onTap: _busy || _pickingPhoto ? null : onTap,
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
    child: TextFormField(
      controller: controller,
      readOnly: _busy,
      maxLength: controller == _name ? 300 : 200,
      validator:
          (value) =>
              controller == _name
                  ? ((value?.trim().length ?? 0) < 2 ||
                          (value?.trim().length ?? 0) > 300
                      ? context.strings.productLabelNameError
                      : null)
                  : ((value?.trim().length ?? 0) > 200
                      ? context.strings.productFormBrandError
                      : null),
      decoration: InputDecoration(
        labelText: label,
        errorMaxLines: 3,
        border: const OutlineInputBorder(),
      ),
    ),
  );

  Widget _numberField(
    TextEditingController controller,
    String label,
  ) => TextFormField(
    controller: controller,
    readOnly: _busy,
    validator: (value) {
      final pack = controller == _serving;
      final maximum = pack ? 100000.0 : (controller == _kcal ? 2000.0 : 200.0);
      if (validProductFormNumber(
        value ?? '',
        maximum: maximum,
        allowZero: !pack,
        required: !pack,
      )) {
        return null;
      }
      return pack
          ? context.strings.productFormPackError
          : context.strings.productFormNumberRange(maximum.toStringAsFixed(0));
    },
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(
      labelText: label,
      errorMaxLines: 3,
      border: const OutlineInputBorder(),
    ),
  );
}
