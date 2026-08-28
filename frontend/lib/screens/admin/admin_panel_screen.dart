import 'package:flutter/material.dart';
import '../../models/promotion.dart';
import '../../models/recipe.dart';
import '../../services/promotion_service.dart';
import '../../services/recipe_service.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_utils.dart';

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
  final RecipeService _recipeService = RecipeService();
  final NotificationService _notificationService = NotificationService();
  final TextEditingController _broadcastController = TextEditingController();
  bool _isSendingBroadcast = false;
  final List<String> _stores = ['Biedronka', 'Lidl', 'Dino'];

  String? _scanningStore;
  bool _isLoadingPending = true;
  String? _pendingError;
  List<Promotion> _pending = [];
  final Set<String> _busyPromotionIds = {};

  // Przepisy oczekujące na akceptację do wspólnego katalogu — wcześniej
  // nie było żadnej listy w interfejsie, więc admin nie miał jak w ogóle
  // odkryć, że coś czeka na decyzję (backend to już miał, brakowało UI).
  bool _isLoadingPendingRecipes = true;
  String? _pendingRecipesError;
  List<Recipe> _pendingRecipes = [];
  final Set<String> _busyRecipeIds = {};

  bool _isCheckingAiStatus = false;
  Map<String, dynamic>? _aiStatus;
  String? _aiStatusError;

  @override
  void initState() {
    super.initState();
    _loadPendingRecipes();
    _loadPending();
  }

  @override
  void dispose() {
    _broadcastController.dispose();
    super.dispose();
  }

  /// Wysyła powiadomienie do WSZYSTKICH użytkowników aplikacji — to
  /// powiadomienie WEWNĄTRZ aplikacji (dzwoneczek), nie prawdziwy push
  /// (który wymagałby Firebase Cloud Messaging).
  Future<void> _sendBroadcast() async {
    final message = _broadcastController.text.trim();
    if (message.isEmpty) return;

    setState(() => _isSendingBroadcast = true);
    try {
      final sentTo = await _notificationService.sendBroadcast(message);
      if (!mounted) return;
      _broadcastController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Wysłano do $sentTo użytkowników.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e)), backgroundColor: AppTheme.errorColor),
      );
    } finally {
      if (mounted) setState(() => _isSendingBroadcast = false);
    }
  }

  Widget _buildBroadcastSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Wyślij powiadomienie do wszystkich', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          'Trafi do dzwoneczka powiadomień KAŻDEGO użytkownika aplikacji — nieodwracalne, sprawdź treść przed wysłaniem.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _broadcastController,
          maxLines: 3,
          maxLength: 500,
          decoration: const InputDecoration(
            hintText: 'Treść powiadomienia...',
            border: OutlineInputBorder(),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _isSendingBroadcast ? null : _sendBroadcast,
            icon: _isSendingBroadcast
                ? const SizedBox(
                    width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.campaign_outlined),
            label: const Text('Wyślij do wszystkich'),
          ),
        ),
      ],
    );
  }

  Future<void> _checkAiStatus() async {
    setState(() {
      _isCheckingAiStatus = true;
      _aiStatusError = null;
    });
    try {
      final result = await _recipeService.getAiStatus();
      if (!mounted) return;
      setState(() {
        _aiStatus = result;
        _isCheckingAiStatus = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCheckingAiStatus = false;
        _aiStatusError = friendlyError(e);
      });
    }
  }

  Future<void> _loadPending() async {
    setState(() {
      _isLoadingPending = true;
      _pendingError = null;
    });
    try {
      final list = await _service.getPendingPromotions();
      if (!mounted) return;
      setState(() {
        _pending = list;
        _isLoadingPending = false;
      });
    } catch (e) {
      if (!mounted) return;
      // UWAGA (naprawa): wcześniej błąd był tu całkowicie połykany —
      // lista po prostu zostawała pusta, bez żadnej wskazówki, że coś
      // poszło nie tak (np. gdy odpowiedź serwera nie dała się
      // poprawnie sparsować). Teraz pokazujemy czytelny komunikat
      // zamiast fałszywego "brak promocji do akceptacji".
      setState(() {
        _isLoadingPending = false;
        _pendingError = 'Nie udało się wczytać listy oczekujących promocji.';
      });
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
        SnackBar(content: Text(friendlyError(e))),
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

  Future<void> _loadPendingRecipes() async {
    setState(() {
      _isLoadingPendingRecipes = true;
      _pendingRecipesError = null;
    });
    try {
      final list = await _recipeService.getPendingRecipes();
      if (!mounted) return;
      setState(() {
        _pendingRecipes = list;
        _isLoadingPendingRecipes = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingPendingRecipes = false;
        _pendingRecipesError = 'Nie udało się wczytać listy oczekujących przepisów.';
      });
    }
  }

  Future<void> _actOnRecipe(Recipe recipe, bool approve) async {
    setState(() => _busyRecipeIds.add(recipe.id));
    try {
      if (approve) {
        await _recipeService.approveRecipe(recipe.id);
      } else {
        await _recipeService.rejectRecipe(recipe.id);
      }
      if (!mounted) return;
      setState(() {
        _pendingRecipes.removeWhere((r) => r.id == recipe.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(approve ? 'Przepis zaakceptowany' : 'Przepis odrzucony')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    } finally {
      if (mounted) setState(() => _busyRecipeIds.remove(recipe.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Panel administratora')),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([_loadPending(), _loadPendingRecipes()]);
        },
        color: AppTheme.primaryColor,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Przepisy oczekujące na akceptację do wspólnego katalogu —
            // wcześniej nie było tu żadnej listy, mimo że backend i
            // przyciski akceptacji/odrzucenia (RecipeApprovalBar) już
            // istniały — admin nie miał jak w ogóle odkryć, że coś czeka.
            Text('Przepisy oczekujące na akceptację', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Przepisy zgłoszone przez użytkowników Premium do wspólnego, publicznego katalogu.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            if (_isLoadingPendingRecipes)
              const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
            else if (_pendingRecipesError != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_pendingRecipesError!, style: TextStyle(color: AppTheme.errorColor)),
                    const SizedBox(height: 8),
                    TextButton(onPressed: _loadPendingRecipes, child: const Text('Spróbuj ponownie')),
                  ],
                ),
              )
            else if (_pendingRecipes.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Brak przepisów czekających na akceptację.',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              )
            else
              ..._pendingRecipes.map((recipe) {
                final isBusy = _busyRecipeIds.contains(recipe.id);
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(recipe.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(
                          '${recipe.mealType} • ${recipe.servings} porcji • ${recipe.difficulty}',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: isBusy ? null : () => _actOnRecipe(recipe, false),
                                style: OutlinedButton.styleFrom(foregroundColor: AppTheme.errorColor),
                                child: const Text('Odrzuć'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton(
                                onPressed: isBusy ? null : () => _actOnRecipe(recipe, true),
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
            const SizedBox(height: 32),
            // Sprawdzanie stanu klucza/limitów Gemini API — proaktywnie,
            // zanim na wyczerpany limit natrafi prawdziwy użytkownik
            // próbujący dodać przepis przez AI albo zeskanować gazetkę.
            Text('Stan usługi AI', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Sprawdza, czy klucz Gemini działa i czy limit tokenów/zapytań '
              'nie został wyczerpany — dla każdego modelu z osobna.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isCheckingAiStatus ? null : _checkAiStatus,
              icon: _isCheckingAiStatus
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
                    )
                  : const Icon(Icons.health_and_safety_outlined, size: 18),
              label: const Text('Sprawdź stan AI'),
            ),
            if (_aiStatusError != null) ...[
              const SizedBox(height: 10),
              Text(_aiStatusError!, style: TextStyle(color: AppTheme.errorColor)),
            ],
            if (_aiStatus != null) ...[
              const SizedBox(height: 10),
              if (_aiStatus!['configured'] == false)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _aiStatus!['summary'] as String? ?? 'Klucz API nie jest skonfigurowany.',
                    style: TextStyle(color: AppTheme.errorColor, fontSize: 13),
                  ),
                )
              else ...[
                ...(_aiStatus!['models'] as List).map((m) {
                  final ok = m['ok'] == true;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Icon(
                          ok ? Icons.check_circle : Icons.error_outline,
                          color: ok ? Colors.green : AppTheme.errorColor,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text('${m['model']}: ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Expanded(
                          child: Text(
                            m['detail'] as String,
                            style: TextStyle(color: ok ? Colors.green : AppTheme.errorColor, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 4),
                Text(
                  _aiStatus!['summary'] as String? ?? '',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ],
            ],
            const SizedBox(height: 32),
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
            else if (_pendingError != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_pendingError!, style: TextStyle(color: AppTheme.errorColor)),
                    const SizedBox(height: 8),
                    TextButton(onPressed: _loadPending, child: const Text('Spróbuj ponownie')),
                  ],
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
                        // Warunek promocji (np. "Kup 2, zapłać za 1") —
                        // administrator MUSI to widzieć PRZED akceptacją,
                        // bo od tego zależy, czy cena jest wprowadzająca
                        // w błąd bez dodatkowego kontekstu.
                        if (promo.promoDescription != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline, size: 13, color: AppTheme.secondaryColor),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  promo.promoDescription!,
                                  style: TextStyle(
                                    color: AppTheme.secondaryColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
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
            const SizedBox(height: 32),
            _buildBroadcastSection(context),
          ],
        ),
      ),
    );
  }
}
