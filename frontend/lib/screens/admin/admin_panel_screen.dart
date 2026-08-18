import 'package:flutter/material.dart';
import '../../models/promotion.dart';
import '../../services/promotion_service.dart';
import '../../theme/app_theme.dart';

/// Panel administratora — na razie tylko skanowanie gazetek promocyjnych
/// przez AI i akceptacja/odrzucanie znalezionych promocji. Widoczny
/// wyłącznie dla kont z rolą "admin" (patrz wpis w profilu).
class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final PromotionService _service = PromotionService();
  final List<String> _stores = ['Biedronka', 'Lidl', 'Dino'];

  String? _scanningStore;
  bool _isLoadingPending = true;
  List<Promotion> _pending = [];
  final Set<String> _busyPromotionIds = {};

  @override
  void initState() {
    super.initState();
    _loadPending();
  }

  Future<void> _loadPending() async {
    setState(() => _isLoadingPending = true);
    try {
      final list = await _service.getPendingPromotions();
      if (!mounted) return;
      setState(() {
        _pending = list;
        _isLoadingPending = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingPending = false);
    }
  }

  Future<void> _scan(String storeName) async {
    setState(() => _scanningStore = storeName);
    try {
      final result = await _service.triggerAiScan(storeName);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Znaleziono ${result['found']}, zakolejkowano ${result['queued_for_review']} do akceptacji.',
          ),
        ),
      );
      await _loadPending();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('ApiException:', '').trim())),
      );
    } finally {
      if (mounted) setState(() => _scanningStore = null);
    }
  }

  Future<void> _act(Promotion promotion, bool approve) async {
    setState(() => _busyPromotionIds.add(promotion.id));
    try {
      if (approve) {
        await _service.approvePromotion(promotion.id);
      } else {
        await _service.rejectPromotion(promotion.id);
      }
      if (!mounted) return;
      setState(() {
        _pending.removeWhere((p) => p.id == promotion.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(approve ? 'Promocja zaakceptowana' : 'Promocja odrzucona')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nie udało się wykonać akcji')),
      );
    } finally {
      if (mounted) setState(() => _busyPromotionIds.remove(promotion.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Panel administratora')),
      body: RefreshIndicator(
        onRefresh: _loadPending,
        color: AppTheme.primaryColor,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Skanuj gazetki promocyjne', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'AI przeszuka internet w poszukiwaniu aktualnej gazetki danego '
              'sklepu i rozpozna z niej promocje. Wynik trafi poniżej do '
              'akceptacji — nic nie zmienia się automatycznie.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _stores.map((store) {
                final isBusy = _scanningStore == store;
                return ElevatedButton.icon(
                  onPressed: _scanningStore != null ? null : () => _scan(store),
                  style: ElevatedButton.styleFrom(minimumSize: const Size(0, 44)),
                  icon: isBusy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.search, size: 18),
                  label: Text('Skanuj $store'),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Oczekujące na akceptację', style: Theme.of(context).textTheme.titleLarge),
                Text('${_pending.length}', style: TextStyle(color: AppTheme.textSecondary)),
              ],
            ),
            const SizedBox(height: 12),
            if (_isLoadingPending)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(color: AppTheme.primaryColor),
                ),
              )
            else if (_pending.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Brak promocji czekających na akceptację.',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              )
            else
              ..._pending.map((promo) {
                final isBusy = _busyPromotionIds.contains(promo.id);
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                promo.productName,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Text(promo.storeName, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              '${promo.regularPrice.toStringAsFixed(2)} zł',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                decoration: TextDecoration.lineThrough,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${promo.promoPrice.toStringAsFixed(2)} zł',
                              style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            Text('-${promo.savingsPercent}%', style: TextStyle(color: AppTheme.errorColor, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: isBusy ? null : () => _act(promo, false),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.errorColor,
                                  side: const BorderSide(color: AppTheme.errorColor),
                                  minimumSize: const Size(0, 40),
                                ),
                                child: const Text('Odrzuć'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: isBusy ? null : () => _act(promo, true),
                                style: ElevatedButton.styleFrom(minimumSize: const Size(0, 40)),
                                child: isBusy
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Text('Zaakceptuj'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
