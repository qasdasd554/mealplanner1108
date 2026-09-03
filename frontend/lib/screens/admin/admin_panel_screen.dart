import 'package:flutter/material.dart';
import '../../models/promotion.dart';
import '../../models/recipe.dart';
import '../../services/promotion_service.dart';
import '../../services/recipe_service.dart';
import '../../services/notification_service.dart';
import '../../services/moderation_service.dart';
import 'admin_users_screen.dart';
import 'admin_comments_screen.dart';
import 'admin_photos_screen.dart';
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
  final ModerationService _moderationService = ModerationService();
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

  // Zgłoszenia treści (Guideline 1.2 Apple) — dotąd backend istniał
  // (GET/PATCH /users/admin/reports), ale nie było żadnego ekranu, więc
  // zgłoszenia były niewidoczne dla administratora mimo że użytkownicy
  // mogli je już wysyłać.
  bool _isLoadingReports = true;
  String? _reportsError;
  List<Map<String, dynamic>> _reports = [];
  final Set<String> _busyReportIds = {};

  @override
  void initState() {
    super.initState();
    _loadPendingRecipes();
    _loadPending();
    _loadReports();
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
      ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('Wysłano do $sentTo użytkowników.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(friendlyError(e)), backgroundColor: AppTheme.errorColor),
      );
    } finally {
      if (mounted) setState(() => _isSendingBroadcast = false);
    }
  }

  /// Etykiety powodów muszą odpowiadać kReportReasons w
  /// widgets/report_block_menu.dart (i REPORT_REASONS w backendzie).
  static const Map<String, String> _reasonLabels = {
    'spam': 'Spam albo reklama',
    'inappropriate_content': 'Treść nieodpowiednia',
    'harassment': 'Nękanie albo mowa nienawiści',
    'misinformation': 'Fałszywe informacje',
    'other': 'Inny powód',
  };

  Widget _buildReportsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Zgłoszenia treści', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          'Przepisy i komentarze zgłoszone przez użytkowników jako spam, nękanie '
          'albo inne naruszenie regulaminu.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 12),
        if (_isLoadingReports)
          const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
        else if (_reportsError != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_reportsError!, style: TextStyle(color: AppTheme.errorColor)),
                const SizedBox(height: 8),
                TextButton(onPressed: _loadReports, child: const Text('Spróbuj ponownie')),
              ],
            ),
          )
        else if (_reports.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text('Brak nierozpatrzonych zgłoszeń.', style: TextStyle(color: AppTheme.textSecondary)),
          )
        else
          ..._reports.map((report) {
            final id = report['id'] as String;
            final isBusy = _busyReportIds.contains(id);
            final contentType = report['content_type'] as String? ?? '?';
            final reason = report['reason'] as String? ?? 'other';
            final details = report['details'] as String?;
            final preview = report['content_preview'] as String?;
            final authorEmail = report['content_author_email'] as String?;
            final reporterEmail = report['reporter_email'] as String?;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.errorColor.withOpacity(0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        contentType == 'recipe' ? Icons.menu_book_outlined : Icons.chat_bubble_outline,
                        size: 16,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        contentType == 'recipe' ? 'Przepis' : 'Komentarz',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _reasonLabels[reason] ?? reason,
                          style: TextStyle(fontSize: 11, color: AppTheme.errorColor, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (preview != null && preview.isNotEmpty)
                    Text(
                      '"$preview"',
                      style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (details != null && details.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text('Szczegóły od zgłaszającego: $details', style: const TextStyle(fontSize: 12)),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    [
                      if (authorEmail != null) 'Autor: $authorEmail',
                      if (reporterEmail != null) 'Zgłosił: $reporterEmail',
                    ].join('  ·  '),
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  // Wrap zamiast Row: dwa przyciski z długimi etykietami
                  // ("Odrzuć zgłoszenie" + "Oznacz jako rozpatrzone") nie
                  // mieszczą się obok siebie na wąskim ekranie telefonu
                  // i powodowały overflow. Wrap przenosi drugi przycisk
                  // do nowej linii zamiast się rozjeżdżać.
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      TextButton(
                        onPressed: isBusy ? null : () => _resolveReport(id, 'dismissed'),
                        child: const Text('Odrzuć zgłoszenie'),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
                        onPressed: isBusy ? null : () => _resolveReport(id, 'resolved'),
                        child: isBusy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Oznacz jako rozpatrzone'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
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
      ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Znaleziono ${result['found']}, zakolejkowano ${result['queued_for_review']} do akceptacji.',
          ),
        ),
      );
      await _loadPending();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
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
      ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(approve ? 'Promocja zaakceptowana' : 'Promocja odrzucona')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
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

  Future<void> _loadReports() async {
    setState(() {
      _isLoadingReports = true;
      _reportsError = null;
    });
    try {
      final list = await _moderationService.getReports(status: 'pending');
      if (!mounted) return;
      setState(() {
        _reports = list;
        _isLoadingReports = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingReports = false;
        _reportsError = 'Nie udało się wczytać zgłoszeń.';
      });
    }
  }

  Future<void> _resolveReport(String reportId, String status) async {
    setState(() => _busyReportIds.add(reportId));
    try {
      await _moderationService.updateReportStatus(reportId, status);
      if (!mounted) return;
      setState(() {
        _reports.removeWhere((r) => r['id'] == reportId);
        _busyReportIds.remove(reportId);
      });
      ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(status == 'resolved' ? 'Zgłoszenie oznaczone jako rozpatrzone' : 'Zgłoszenie odrzucone'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyReportIds.remove(reportId));
      ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
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
      ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(approve ? 'Przepis zaakceptowany' : 'Przepis odrzucony')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
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
          await Future.wait([_loadPending(), _loadPendingRecipes(), _loadReports()]);
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
                // Expanded na tytule: "Oczekujące na akceptację" w stylu
                // titleLarge nie mieści się obok licznika na wąskich
                // ekranach (~360 dp) i powodowało przepełnienie — ta sama
                // klasa błędu co przy przyciskach zgłoszeń.
                Expanded(
                  child: Text(
                    'Oczekujące na akceptację',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(width: 8),
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
            // Skróty do osobnych ekranów moderacji — celowo NIE wbudowane
            // w ten ekran, bo panel jest już bardzo długi, a obie listy
            // (konta, komentarze) mają własne wyszukiwarki i paginację.
            // Wrap zamiast Row: trzy przyciski z etykietami nie mieszczą
            // się w jednym wierszu na wąskich ekranach.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.people_outline, size: 18),
                  label: const Text('Użytkownicy'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AdminUsersScreen()),
                  ),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text('Komentarze'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AdminCommentsScreen()),
                  ),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('Zdjęcia'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AdminPhotosScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildReportsSection(context),
            const SizedBox(height: 32),
            _buildBroadcastSection(context),
            // Odstęp na dole uwzględniający pasek nawigacji systemowej —
            // bez tego ostatni przycisk (wysyłka powiadomienia) chował się
            // pod gestowym paskiem systemu i nie dało się go dotknąć.
            SizedBox(height: MediaQuery.of(context).padding.bottom + 32),
          ],
        ),
      ),
    );
  }
}
