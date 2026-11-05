import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../l10n/market_locale.dart';
import '../../l10n/measure_labels.dart';
import '../../providers/auth_provider.dart';
import '../../services/pantry_receipt_service.dart';
import '../../utils/error_utils.dart';
import '../../widgets/premium_feature_tag.dart';

Future<ReceiptSave?> openPantryReceiptScanner(BuildContext context) =>
    Navigator.of(context).push<ReceiptSave>(
      MaterialPageRoute(builder: (_) => const PantryReceiptScreen()),
    );

void showReceiptSaved(BuildContext context, ReceiptSave result) {
  final strings = context.strings;
  final message =
      result.alreadySaved
          ? strings.receiptAlreadySaved
          : strings.receiptSaved(result.savedCount);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        result.skippedCount == 0
            ? message
            : '$message ${strings.receiptSkipped(result.skippedCount)}',
      ),
    ),
  );
}

class PantryReceiptScreen extends StatefulWidget {
  const PantryReceiptScreen({super.key, this.service, this.picker});

  final PantryReceiptService? service;
  final ImagePicker? picker;

  @override
  State<PantryReceiptScreen> createState() => _PantryReceiptScreenState();
}

enum _ReceiptAction { picking, reading, saving }

class _PantryReceiptScreenState extends State<PantryReceiptScreen> {
  static const _units = ['opak', 'szt', 'g', 'ml'];
  late final _service = widget.service ?? PantryReceiptService();
  late final _picker = widget.picker ?? ImagePicker();
  late final _accountId = context.read<AuthProvider?>()?.currentUser?.id;
  late final _session = _service.sessionGeneration;
  Uint8List? _photo;
  ReceiptPreview? _preview;
  final _selected = <int>{};
  final _amounts = <int, double?>{};
  final _editedText = <int, String>{};
  final _editedUnits = <int, String>{};
  _ReceiptAction? _action;
  bool get _busy => _action != null;
  String? _error;

  bool get _sameSession =>
      mounted &&
      _session == _service.sessionGeneration &&
      _accountId == context.read<AuthProvider?>()?.currentUser?.id;

  bool get _canScan =>
      _sameSession &&
      (context.read<AuthProvider?>()?.currentUser?.hasPremiumAccess ?? false);

  Future<void> _pick(ImageSource source) async {
    if (_busy || !_canScan) return;
    setState(() {
      _action = _ReceiptAction.picking;
      _error = null;
    });
    try {
      final image = await _picker.pickImage(
        source: source,
        maxWidth: 1800,
        imageQuality: 90,
        requestFullMetadata: false,
      );
      if (!_canScan || image == null) return;
      if (await image.length() > PantryReceiptService.maxPhotoBytes) {
        if (_sameSession) {
          setState(() => _error = context.strings.receiptPhotoSize);
        }
        return;
      }
      final bytes = await image.readAsBytes();
      if (!_canScan) return;
      setState(() {
        _photo = bytes;
        _preview = null;
      });
    } catch (_) {
      if (_sameSession) {
        setState(() => _error = context.strings.receiptPhotoError);
      }
    } finally {
      if (mounted) setState(() => _action = null);
    }
  }

  Future<void> _scan() async {
    final photo = _photo;
    if (photo == null || _busy || !_canScan) return;
    setState(() {
      _action = _ReceiptAction.reading;
      _error = null;
    });
    try {
      final result = await _service.scan(photo);
      if (!_canScan) return;
      setState(() {
        _preview = result;
        _selected.clear();
        _amounts.clear();
        _editedText.clear();
        _editedUnits.clear();
        for (final (index, line) in result.items.indexed) {
          _amounts[index] = line.quantity;
          if (line.quantity != null) _selected.add(index);
        }
      });
    } catch (error) {
      if (_sameSession) {
        setState(() => _error = friendlyError(error, strings: context.strings));
      }
    } finally {
      if (mounted) setState(() => _action = null);
    }
  }

  Future<void> _save() async {
    final preview = _preview;
    final token = preview?.token;
    if (preview == null || token == null || !_canSave || _busy || !_canScan) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _action = _ReceiptAction.saving;
      _error = null;
    });
    try {
      final result = await _service.save(token, [
        for (final index in _selected)
          (
            index: index,
            quantity: _amounts[index]!,
            unit: _editedUnits[index] ?? preview.items[index].unit,
          ),
      ]);
      if (!mounted || !_sameSession) return;
      if (result.savedCount == 0) {
        setState(() => _error = context.strings.receiptNoCompatibleStock);
      } else {
        Navigator.of(context).pop(result);
      }
    } catch (error) {
      if (_sameSession) {
        setState(() => _error = friendlyError(error, strings: context.strings));
      }
    } finally {
      if (mounted) setState(() => _action = null);
    }
  }

  bool get _canSave =>
      _selected.isNotEmpty &&
      _selected.every((index) => _amounts[index] != null);

  double? _parseQuantity(String text) {
    final normalized = text.trim().replaceAll(',', '.');
    if (!RegExp(r'^(?:\d+(?:\.\d{0,3})?|\.\d{1,3})$').hasMatch(normalized)) {
      return null;
    }
    final quantity = double.tryParse(normalized);
    return quantity != null && quantity >= 0.001 && quantity <= 100000
        ? quantity
        : null;
  }

  String _unitLabel(String unit) => switch (unit) {
    'g' || 'ml' => unit,
    _ => context.strings.measureName(unit),
  };

  Widget _errorMessage(String message) => Semantics(
    liveRegion: true,
    child: Text(
      message,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    ),
  );

  Widget _photoActions() => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      OutlinedButton.icon(
        onPressed: _busy ? null : () => _pick(ImageSource.camera),
        icon: const Icon(Icons.photo_camera_outlined),
        label: Text(context.strings.productLabelTakePhoto),
      ),
      OutlinedButton.icon(
        onPressed: _busy ? null : () => _pick(ImageSource.gallery),
        icon: const Icon(Icons.photo_library_outlined),
        label: Text(context.strings.productLabelGallery),
      ),
    ],
  );

  Widget _line(int index, ReceiptLine line) {
    final strings = context.strings;
    final selected = _selected.contains(index);
    final initial = line.quantity?.toString().replaceFirst(RegExp(r'\.0$'), '');
    final unit = _editedUnits[index] ?? line.unit;
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CheckboxListTile(
            title: Text(line.name),
            subtitle:
                !selected && line.quantity == null
                    ? Text(strings.receiptQuantityUnreadable)
                    : null,
            value: selected,
            onChanged:
                _busy
                    ? null
                    : (value) => setState(() {
                      if (value == true) {
                        _selected.add(index);
                      } else {
                        _selected.remove(index);
                      }
                    }),
          ),
          if (selected)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: 110,
                    child: TextFormField(
                      key: ValueKey('receipt-quantity-$index'),
                      initialValue: _editedText[index] ?? initial,
                      enabled: !_busy,
                      decoration: InputDecoration(
                        labelText: strings.amountQuantity,
                        errorText:
                            _amounts[index] == null
                                ? strings.receiptCheckQuantity
                                : null,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged:
                          (text) => setState(() {
                            _editedText[index] = text;
                            _amounts[index] = _parseQuantity(text);
                          }),
                    ),
                  ),
                  SizedBox(
                    width: 148,
                    child: DropdownButtonFormField<String>(
                      initialValue: unit,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: strings.amountUnit,
                      ),
                      items: [
                        for (final code in _units)
                          DropdownMenuItem(
                            value: code,
                            child: Text(_unitLabel(code)),
                          ),
                      ],
                      onChanged:
                          _busy
                              ? null
                              : (value) {
                                if (value != null) {
                                  setState(() => _editedUnits[index] = value);
                                }
                              },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final auth = context.watch<AuthProvider?>();
    final premium =
        _sameSession && (auth?.currentUser?.hasPremiumAccess ?? false);
    final items = _preview?.items ?? const <ReceiptLine>[];
    final reviewing = premium && items.isNotEmpty;
    final canStart = premium && _photo != null && !reviewing;
    final processing =
        _action == _ReceiptAction.saving || _action == _ReceiptAction.reading;
    return PopScope(
      canPop: _action != _ReceiptAction.saving,
      child: Scaffold(
        appBar: AppBar(title: Text(strings.receiptScanTitle)),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              if (!premium) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: PremiumFeatureTag(),
                ),
                const SizedBox(height: 12),
                Text(
                  strings.receiptPremiumMessage,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => Navigator.of(context).pushNamed('/premium'),
                  child: Text(strings.homeViewPremium),
                ),
              ] else ...[
                if (_error != null && !reviewing)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _errorMessage(_error!),
                  ),
                if (reviewing) ...[
                  Text(
                    strings.receiptReviewTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(strings.receiptReviewHint),
                  const SizedBox(height: 8),
                  for (final (index, line) in items.indexed) _line(index, line),
                  const SizedBox(height: 8),
                  _photoActions(),
                ] else ...[
                  Text(
                    strings.receiptPhotoGuide,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  _photoActions(),
                  const SizedBox(height: 8),
                  Text(strings.receiptPhotoPrivacy),
                  const SizedBox(height: 12),
                  if (_photo case final bytes?)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 280),
                      child: Image.memory(
                        bytes,
                        fit: BoxFit.contain,
                        errorBuilder:
                            (_, __, ___) => Text(strings.receiptPhotoError),
                      ),
                    ),
                  if (_preview != null && items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(strings.receiptEmpty),
                      ),
                    ),
                ],
              ],
            ],
          ),
        ),
        bottomNavigationBar:
            (reviewing || canStart)
                ? SafeArea(
                  minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (reviewing && _error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _errorMessage(_error!),
                        ),
                      FilledButton(
                        onPressed:
                            _busy
                                ? null
                                : reviewing
                                ? (_canSave ? _save : null)
                                : _scan,
                        child:
                            processing
                                ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox.square(
                                      dimension: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        reviewing
                                            ? strings.receiptSaving
                                            : strings.receiptReading,
                                      ),
                                    ),
                                  ],
                                )
                                : Text(
                                  reviewing
                                      ? strings.receiptSaveAction
                                      : strings.receiptReadAction,
                                ),
                      ),
                    ],
                  ),
                )
                : null,
      ),
    );
  }
}
