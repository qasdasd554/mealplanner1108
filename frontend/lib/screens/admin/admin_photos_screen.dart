import 'dart:convert';

import 'package:flutter/material.dart';

import '../../services/moderation_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_utils.dart';

/// Kolejka zdjęć zgłoszonych przez użytkowników do istniejących przepisów.
///
/// Zdjęcie zostaje podmienione dopiero po akceptacji — do tego czasu
/// przepis pokazuje dotychczasowe (albo ilustrację kategorii). Dzięki temu
/// nikt nie może samowolnie podmienić zdjęcia w cudzym ani w oficjalnym
/// przepisie.
class AdminPhotosScreen extends StatefulWidget {
  const AdminPhotosScreen({super.key});

  @override
  State<AdminPhotosScreen> createState() => _AdminPhotosScreenState();
}

class _AdminPhotosScreenState extends State<AdminPhotosScreen> {
  final ModerationService _service = ModerationService();

  List<Map<String, dynamic>> _photos = [];
  bool _isLoading = true;
  String? _error;
  final Set<String> _busyIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final list = await _service.getPendingPhotos();
      if (!mounted) return;
      setState(() {
        _photos = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = friendlyError(e);
      });
    }
  }

  Future<void> _decide(Map<String, dynamic> entry, bool approve) async {
    final id = entry['recipe_id'] as String;
    setState(() => _busyIds.add(id));
    try {
      if (approve) {
        await _service.approvePhoto(id);
      } else {
        await _service.rejectPhoto(id);
      }
      if (!mounted) return;
      setState(() {
        _photos.removeWhere((p) => p['recipe_id'] == id);
        _busyIds.remove(id);
      });
      ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(approve ? 'Zdjęcie zaakceptowane' : 'Zdjęcie odrzucone')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyIds.remove(id));
      ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(friendlyError(e)), backgroundColor: AppTheme.errorColor),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Zdjęcia do akceptacji')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: TextStyle(color: AppTheme.errorColor)),
                      TextButton(onPressed: _load, child: const Text('Spróbuj ponownie')),
                    ],
                  ),
                )
              : _photos.isEmpty
                  ? Center(
                      child: Text(
                        'Brak zdjęć oczekujących na akceptację.',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _photos.length,
                        itemBuilder: (context, index) {
                          final entry = _photos[index];
                          final id = entry['recipe_id'] as String;
                          final isBusy = _busyIds.contains(id);
                          final hasCurrent = entry['has_current_photo'] as bool? ?? false;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildPhoto(entry['photo_base64'] as String?),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entry['recipe_name'] as String? ?? 'Przepis',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Zgłosił: ${entry['submitted_by'] ?? 'nieznany'}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                      if (hasCurrent)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 6),
                                          child: Text(
                                            'Uwaga: ten przepis ma już zdjęcie — akceptacja je zastąpi.',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.errorColor,
                                            ),
                                          ),
                                        ),
                                      const SizedBox(height: 12),
                                      // Wrap, nie Row — dwa przyciski z pełnymi
                                      // etykietami nie mieszczą się obok siebie
                                      // na wąskim ekranie.
                                      Wrap(
                                        alignment: WrapAlignment.end,
                                        spacing: 8,
                                        runSpacing: 4,
                                        children: [
                                          TextButton(
                                            onPressed: isBusy ? null : () => _decide(entry, false),
                                            child: const Text('Odrzuć'),
                                          ),
                                          FilledButton(
                                            onPressed: isBusy ? null : () => _decide(entry, true),
                                            child: isBusy
                                                ? const SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                                  )
                                                : const Text('Zaakceptuj'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _buildPhoto(String? base64Data) {
    if (base64Data == null || base64Data.isEmpty) {
      return const SizedBox.shrink();
    }
    try {
      // Backend przechowuje samo base64 bez prefiksu "data:", ale
      // odcinamy go defensywnie, gdyby kiedyś przyszło z prefiksem.
      final cleaned = base64Data.contains(',')
          ? base64Data.substring(base64Data.indexOf(',') + 1)
          : base64Data;
      return Image.memory(
        base64Decode(cleaned),
        width: double.infinity,
        height: 220,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _photoError(),
      );
    } catch (_) {
      return _photoError();
    }
  }

  Widget _photoError() => Container(
        height: 120,
        width: double.infinity,
        color: AppTheme.textSecondary.withOpacity(0.1),
        child: Center(
          child: Text(
            'Nie udało się wczytać zdjęcia',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      );
}
