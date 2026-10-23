import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/promotion.dart';
import '../../config/constants.dart';
import '../../models/recipe.dart';
import '../../services/promotion_service.dart';
import '../../services/recipe_service.dart';
import '../../services/notification_service.dart';
import '../../services/moderation_service.dart';
import 'admin_users_screen.dart';
import 'admin_comments_screen.dart';
import 'admin_photos_screen.dart';
import 'admin_products_screen.dart';
import 'admin_all_recipes_screen.dart';
import 'admin_campaigns_screen.dart';
import '../recipes/recipe_detail_screen.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_utils.dart';
import '../../l10n/market_locale.dart';
import '../../l10n/recipe_content.dart';
import '../../l10n/catalog_labels.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/admin_market_selector.dart';
import '../../providers/auth_provider.dart';

/// Panel moderacji produktów, przepisów, zgłoszeń i promocji.
/// Widoczny wyłącznie dla kont z rolą administratora.
class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({
    super.key,
    this.promotionService,
    this.recipeService,
    this.notificationService,
    this.moderationService,
  });
  final PromotionService? promotionService;
  final RecipeService? recipeService;
  final NotificationService? notificationService;
  final ModerationService? moderationService;

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  late final PromotionService _service;
  late final RecipeService _recipeService;
  late final NotificationService _notificationService;
  late final ModerationService _moderationService;
  final TextEditingController _broadcastController = TextEditingController();
  bool _isSendingBroadcast = false;
  final List<String> _stores = kPromotionScanStores;
  String _market = 'PL';
  int _marketGeneration = 0;

  void _changeMarket(String market) {
    if (market == _market) return;
    setState(() {
      _market = market;
      _marketGeneration++;
      _pending = [];
      _pendingRecipes = [];
    });
    _loadPending();
    _loadPendingRecipes();
  }

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
    _service = widget.promotionService ?? PromotionService();
    _recipeService = widget.recipeService ?? RecipeService();
    _notificationService = widget.notificationService ?? NotificationService();
    _moderationService = widget.moderationService ?? ModerationService();
    _loadPendingRecipes();
    _loadPending();
    _loadReports();
    _resumeScan();
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
    if (_isSendingBroadcast) return;
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
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text(
              context.strings.adminMainBroadcastSent(sentTo.toString()),
            ),
          ),
        );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text(friendlyError(e, strings: context.strings)),
            backgroundColor: AppTheme.errorColor,
          ),
        );
    } finally {
      if (mounted) setState(() => _isSendingBroadcast = false);
    }
  }

  /// Etykiety powodów muszą odpowiadać kReportReasons w
  /// widgets/report_block_menu.dart (i REPORT_REASONS w backendzie).
  Map<String, String> get _reasonLabels => {
    'spam': context.strings.reportSpam,
    'inappropriate_content': context.strings.reportInappropriate,
    'harassment': context.strings.reportHarassment,
    'misinformation': context.strings.reportMisinformation,
    'other': context.strings.reportOther,
  };

  Widget _buildReportsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.strings.adminMainReportsTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          context.strings.adminMainReportsHelp,
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 12),
        if (_isLoadingReports)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_reportsError != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _reportsError!,
                  style: TextStyle(color: AppTheme.errorColor),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _loadReports,
                  child: const Text('Spróbuj ponownie'),
                ),
              ],
            ),
          )
        else if (_reports.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              context.strings.adminMainReportsEmpty,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
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
                border: Border.all(
                  color: AppTheme.errorColor.withOpacity(0.25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        contentType == 'recipe'
                            ? Icons.menu_book_outlined
                            : Icons.chat_bubble_outline,
                        size: 16,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        contentType == 'recipe'
                            ? context.strings.adminMainRecipeType
                            : context.strings.adminMainCommentType,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.errorColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _reasonLabels[reason] ?? reason,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.errorColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (preview != null && preview.isNotEmpty)
                    Text(
                      '"$preview"',
                      style: const TextStyle(
                        fontStyle: FontStyle.italic,
                        fontSize: 13,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (details != null && details.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      context.strings.adminMainReportDetails(details),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    [
                      if (authorEmail != null)
                        context.strings.adminMainAuthor(authorEmail),
                      if (reporterEmail != null)
                        context.strings.adminMainReporter(reporterEmail),
                    ].join('  ·  '),
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
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
                        onPressed:
                            isBusy
                                ? null
                                : () => _resolveReport(id, 'dismissed'),
                        child: Text(context.strings.adminMainDismiss),
                      ),
                      // Usunięcie SAMEJ TREŚCI. Wcześniej panel pozwalał
                      // wyłącznie zamknąć zgłoszenie, a obraźliwy komentarz
                      // zostawał w aplikacji — moderacja kończyła się na
                      // odhaczeniu, bez żadnego skutku dla użytkowników.
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.errorColor,
                        ),
                        onPressed:
                            isBusy ? null : () => _deleteReportedContent(id),
                        child: Text(context.strings.adminMainDeleteContent),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.errorColor,
                        ),
                        onPressed:
                            isBusy
                                ? null
                                : () => _resolveReport(id, 'resolved'),
                        child:
                            isBusy
                                ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : Text(context.strings.adminMainResolve),
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
        Text(
          context.strings.adminMainBroadcastTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          context.strings.adminMainBroadcastHelp,
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _broadcastController,
          maxLines: 3,
          maxLength: 500,
          decoration: InputDecoration(
            hintText: context.strings.adminMainBroadcastHint,
            border: OutlineInputBorder(),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _isSendingBroadcast ? null : _sendBroadcast,
            icon:
                _isSendingBroadcast
                    ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                    : const Icon(Icons.campaign_outlined),
            label: Text(context.strings.adminMainBroadcastSend),
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
        _aiStatusError = friendlyError(e, strings: context.strings);
      });
    }
  }

  Future<void> _loadPending() async {
    final generation = _marketGeneration;
    setState(() {
      _isLoadingPending = true;
      _pendingError = null;
    });
    try {
      final list = await _service.getPendingPromotions(market: _market);
      if (!mounted || generation != _marketGeneration) return;
      setState(() {
        _pending = list;
        _isLoadingPending = false;
      });
    } catch (e) {
      if (!mounted || generation != _marketGeneration) return;
      // UWAGA (naprawa): wcześniej błąd był tu całkowicie połykany —
      // lista po prostu zostawała pusta, bez żadnej wskazówki, że coś
      // poszło nie tak (np. gdy odpowiedź serwera nie dała się
      // poprawnie sparsować). Teraz pokazujemy czytelny komunikat
      // zamiast fałszywego "brak promocji do akceptacji".
      setState(() {
        _isLoadingPending = false;
        _pendingError = context.strings.adminMainPromotionsLoadFailed;
      });
    }
  }

  Future<void> _scan(String storeName) async {
    setState(() => _scanningStore = storeName);
    try {
      final result = await _service.triggerAiScan(
        storeName,
        isActive: () => mounted,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text(
              result['status'] == 'completed'
                  ? context.strings.adminMainScanSummary(
                    '${result['found']}',
                    '${result['queued_for_review']}',
                  )
                  : context.strings.adminMainScanPending,
            ),
          ),
        );
      await _loadPending();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text(friendlyError(e, strings: context.strings)),
          ),
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
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text(
              approve
                  ? context.strings.adminMainPromotionApproved
                  : context.strings.adminMainPromotionRejected,
            ),
          ),
        );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: Duration(seconds: 3),
            content: Text(context.strings.adminMainActionFailed),
          ),
        );
    } finally {
      if (mounted) setState(() => _busyPromotionIds.remove(promotion.id));
    }
  }

  Future<void> _resumeScan() async {
    var resumed = false;
    try {
      final jobs = await _service.activeScans();
      if (!mounted || jobs.isEmpty || _scanningStore != null) return;
      resumed = true;
      setState(() => _scanningStore = jobs.first['store_name'] as String);
      await _service.waitForScan(jobs.first, isActive: () => mounted);
      if (mounted) await _loadPending();
    } catch (error) {
      if (mounted && resumed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyError(error, strings: context.strings)),
          ),
        );
      }
    } finally {
      if (mounted && resumed) setState(() => _scanningStore = null);
    }
  }

  Future<void> _loadPendingRecipes() async {
    final generation = _marketGeneration;
    setState(() {
      _isLoadingPendingRecipes = true;
      _pendingRecipesError = null;
    });
    try {
      final list = await _recipeService.getPendingRecipes(market: _market);
      if (!mounted || generation != _marketGeneration) return;
      setState(() {
        _pendingRecipes = list;
        _isLoadingPendingRecipes = false;
      });
    } catch (e) {
      if (!mounted || generation != _marketGeneration) return;
      setState(() {
        _isLoadingPendingRecipes = false;
        _pendingRecipesError = context.strings.adminMainRecipesLoadFailed;
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
        _reportsError = context.strings.adminMainReportsLoadFailed;
      });
    }
  }

  Future<void> _deleteReportedContent(String reportId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(context.strings.adminMainDeleteContentTitle),
            content: Text(context.strings.adminMainDeleteContentHelp),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(context.strings.planCancel),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.errorColor,
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(context.strings.productsDelete),
              ),
            ],
          ),
    );
    if (confirmed != true) return;

    setState(() => _busyReportIds.add(reportId));
    try {
      await _moderationService.deleteReportedContent(reportId);
      if (!mounted) return;
      setState(() {
        _reports.removeWhere((r) => r['id'] == reportId);
        _busyReportIds.remove(reportId);
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: Duration(seconds: 3),
            content: Text(context.strings.adminMainContentDeleted),
          ),
        );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyReportIds.remove(reportId));
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text(friendlyError(e, strings: context.strings)),
            backgroundColor: AppTheme.errorColor,
          ),
        );
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
            duration: const Duration(seconds: 3),
            content: Text(
              status == 'resolved'
                  ? context.strings.adminMainReportResolved
                  : context.strings.adminMainReportDismissed,
            ),
          ),
        );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyReportIds.remove(reportId));
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text(friendlyError(e, strings: context.strings)),
          ),
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
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text(
              approve
                  ? context.strings.adminMainRecipeApproved
                  : context.strings.adminMainRecipeRejected,
            ),
          ),
        );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text(friendlyError(e, strings: context.strings)),
          ),
        );
    } finally {
      if (mounted) setState(() => _busyRecipeIds.remove(recipe.id));
    }
  }

  Future<void> _openRecipeForReview(Recipe recipe) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const RecipeDetailScreen(),
        settings: RouteSettings(arguments: recipe),
      ),
    );
    // Na ekranie szczegółów administrator ma również pasek decyzji.
    // Po powrocie odświeżamy kolejkę, żeby zaakceptowany lub odrzucony
    // przepis nie pozostał na liście jako oczekujący.
    if (mounted) await _loadPendingRecipes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.strings.adminMainTitle)),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            _loadPending(),
            _loadPendingRecipes(),
            _loadReports(),
          ]);
        },
        color: AppTheme.primaryColor,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            AdminMarketSelector(
              countryCode: _market,
              isAdmin:
                  context.watch<AuthProvider>().currentUser?.isAdmin ?? false,
              isBusy:
                  _scanningStore != null ||
                  _busyPromotionIds.isNotEmpty ||
                  _busyRecipeIds.isNotEmpty,
              onChanged: _changeMarket,
            ),
            const SizedBox(height: 20),
            // Przepisy oczekujące na akceptację do wspólnego katalogu —
            // wcześniej nie było tu żadnej listy, mimo że backend i
            // przyciski akceptacji/odrzucenia (RecipeApprovalBar) już
            // istniały — admin nie miał jak w ogóle odkryć, że coś czeka.
            Text(
              context.strings.adminMainRecipesTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              context.strings.adminMainRecipesHelp,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            if (_isLoadingPendingRecipes)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_pendingRecipesError != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _pendingRecipesError!,
                      style: TextStyle(color: AppTheme.errorColor),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _loadPendingRecipes,
                      child: const Text('Spróbuj ponownie'),
                    ),
                  ],
                ),
              )
            else if (_pendingRecipes.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  context.strings.adminMainRecipesEmpty,
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              )
            else
              ..._pendingRecipes.map((recipe) {
                final isBusy = _busyRecipeIds.contains(recipe.id);
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: isBusy ? null : () => _openRecipeForReview(recipe),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              UserAvatar(
                                avatar: recipe.createdByAvatar,
                                avatarPhotoBase64: recipe.createdByAvatarPhoto,
                                size: 38,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      recipe.displayName(context),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (recipe.createdByName != null)
                                      Text(
                                        context.strings.adminMainAuthor(
                                          recipe.createdByName!,
                                        ),
                                        style: TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 11,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                color: AppTheme.actionPrimaryColor,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            context.strings.adminMainRecipeMeta(
                              context.strings.mealTypeLabel(recipe.mealType),
                              recipe.servings.toString(),
                              context.strings.difficultyLabel(
                                recipe.difficulty,
                              ),
                            ),
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          if (recipe
                                  .displayDescription(context)
                                  ?.trim()
                                  .isNotEmpty ??
                              false) ...[
                            const SizedBox(height: 6),
                            Text(
                              recipe.displayDescription(context)!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.visibility_outlined,
                                size: 17,
                                color: AppTheme.actionPrimaryColor,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  context.strings.adminMainRecipePreview,
                                  style: TextStyle(
                                    color: AppTheme.actionPrimaryColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed:
                                      isBusy
                                          ? null
                                          : () => _actOnRecipe(recipe, false),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.errorColor,
                                    side: const BorderSide(
                                      color: AppTheme.errorColor,
                                    ),
                                  ),
                                  child: const Text('Odrzuć'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilledButton(
                                  onPressed:
                                      isBusy
                                          ? null
                                          : () => _actOnRecipe(recipe, true),
                                  child:
                                      isBusy
                                          ? SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.onPrimary,
                                            ),
                                          )
                                          : Text(
                                            context.strings.adminMainApprove,
                                          ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            const SizedBox(height: 32),
            // Sprawdzanie stanu klucza/limitów Gemini API — proaktywnie,
            // zanim na wyczerpany limit natrafi prawdziwy użytkownik
            // próbujący dodać przepis przez AI albo zeskanować gazetkę.
            Text(
              context.strings.adminMainAiTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              context.strings.adminMainAiHelp,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isCheckingAiStatus ? null : _checkAiStatus,
              icon:
                  _isCheckingAiStatus
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primaryColor,
                        ),
                      )
                      : const Icon(Icons.health_and_safety_outlined, size: 18),
              label: Text(context.strings.adminMainAiCheck),
            ),
            if (_aiStatusError != null) ...[
              const SizedBox(height: 10),
              Text(
                _aiStatusError!,
                style: TextStyle(color: AppTheme.errorColor),
              ),
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
                    _aiStatus!['summary'] as String? ??
                        context.strings.adminMainAiKeyMissing,
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
                        Text(
                          '${m['model']}: ',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            m['detail'] as String,
                            style: TextStyle(
                              color: ok ? Colors.green : AppTheme.errorColor,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 4),
                Text(
                  _aiStatus!['summary'] as String? ?? '',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
            const SizedBox(height: 32),
            Text(
              context.strings.adminMainScanTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              context.strings.adminMainScanHelp,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            if (_market == 'GB')
              Text(context.strings.adminMainUkScanUnavailable)
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children:
                    _stores.map((store) {
                      final isBusy = _scanningStore == store;
                      return ElevatedButton.icon(
                        onPressed:
                            _scanningStore != null ? null : () => _scan(store),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                        ),
                        icon:
                            isBusy
                                ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : const Icon(Icons.search, size: 18),
                        label: Text(context.strings.adminMainScanShop(store)),
                      );
                    }).toList(),
              ),
            if (_scanningStore != null) ...[
              const SizedBox(height: 8),
              Text(
                context.strings.adminMainScanningShop(_scanningStore!),
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
            ],
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
                    context.strings.adminMainPendingTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_pending.length}',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isLoadingPending)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(
                    color: AppTheme.primaryColor,
                  ),
                ),
              )
            else if (_pendingError != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _pendingError!,
                      style: TextStyle(color: AppTheme.errorColor),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _loadPending,
                      child: const Text('Spróbuj ponownie'),
                    ),
                  ],
                ),
              )
            else if (_pending.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  context.strings.adminMainPromotionsEmpty,
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
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Text(
                              promo.storeName,
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
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
                              Icon(
                                Icons.info_outline,
                                size: 13,
                                color: AppTheme.secondaryColor,
                              ),
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
                              style: const TextStyle(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '-${promo.savingsPercent}%',
                              style: TextStyle(
                                color: AppTheme.errorColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed:
                                    isBusy ? null : () => _act(promo, false),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.errorColor,
                                  side: const BorderSide(
                                    color: AppTheme.errorColor,
                                  ),
                                  minimumSize: const Size(0, 40),
                                ),
                                child: const Text('Odrzuć'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed:
                                    isBusy ? null : () => _act(promo, true),
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(0, 40),
                                ),
                                child:
                                    isBusy
                                        ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                        : Text(
                                          context.strings.adminMainApprove,
                                        ),
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
                  label: Text(context.strings.adminUsersTitle),
                  onPressed:
                      () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AdminUsersScreen(),
                        ),
                      ),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: Text(context.strings.adminCommentsTitle),
                  onPressed:
                      () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AdminCommentsScreen(),
                        ),
                      ),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: Text(context.strings.adminPhotosTitle),
                  onPressed:
                      () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AdminPhotosScreen(),
                        ),
                      ),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.inventory_2_outlined, size: 18),
                  label: Text(context.strings.adminMainProductsNav),
                  onPressed:
                      () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AdminProductsScreen(market: _market),
                        ),
                      ),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.menu_book_outlined, size: 18),
                  label: Text(context.strings.adminMainUserRecipesNav),
                  onPressed:
                      () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder:
                              (_) => AdminAllRecipesScreen(market: _market),
                        ),
                      ),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.local_offer_outlined, size: 18),
                  label: Text(context.strings.campaignTitle),
                  onPressed:
                      () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AdminCampaignsScreen(market: _market),
                        ),
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
