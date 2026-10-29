import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../l10n/market_locale.dart';
import '../../models/recipe_import_job.dart';
import '../../providers/auth_provider.dart';
import '../../services/recipe_service.dart';
import '../../services/api_client.dart';
import '../../theme/app_theme.dart';
import 'recipe_detail_screen.dart';
import '../profile/premium_screen.dart';
import '../../utils/error_utils.dart';
import '../../widgets/ai_recipe_edit_sheet.dart';

/// Dodawanie przepisu z tekstu, zdjęcia lub linku. Wynik jest zapisywany
/// przez backend w tle; ekran może zostać zamknięty po przyjęciu zadania.
class AiAddRecipeScreen extends StatefulWidget {
  // Jeśli podany (np. z udostępnienia linku z TikToka), ekran otwiera
  // się od razu na zakładce "Link" z tym adresem wpisanym w polu.
  final String? initialUrl;
  // Jeśli podany (np. z "Co ugotować z tego, co mam" — gdy dopasowanie
  // z bazy nic nie znajdzie), ekran otwiera się od razu na zakładce
  // "Tekst" z gotowym opisem wypełnionym w polu.
  final String? initialText;
  final int initialTabIndex;
  final bool autoStartImport;
  final RecipeService? recipeService;

  const AiAddRecipeScreen({
    super.key,
    this.initialUrl,
    this.initialText,
    this.initialTabIndex = 0,
    this.autoStartImport = false,
    this.recipeService,
  });

  @override
  State<AiAddRecipeScreen> createState() => _AiAddRecipeScreenState();
}

class _AiAddRecipeScreenState extends State<AiAddRecipeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final RecipeService _recipeService;
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  File? _pickedImage;
  bool _isSubmitting = false;
  String? _error;
  RecipeImportJob? _currentJob;
  Timer? _jobPollTimer;
  bool _pollingJob = false;

  @override
  void initState() {
    super.initState();
    _recipeService = widget.recipeService ?? RecipeService();
    _tabController = TabController(length: 3, vsync: this);
    if (widget.initialUrl != null && widget.initialUrl!.isNotEmpty) {
      _urlController.text = widget.initialUrl!;
      // Indeks 2 = zakładka "Link" (Tekst=0, Zdjęcie=1, Link=2).
      _tabController.index = 2;
    } else if (widget.initialText != null && widget.initialText!.isNotEmpty) {
      _textController.text = widget.initialText!;
      // Indeks 0 = zakładka "Tekst" — już domyślna, ale jawnie dla jasności.
      _tabController.index = 0;
    } else {
      _tabController.index = widget.initialTabIndex.clamp(0, 2).toInt();
    }
    _initializeImport();
  }

  @override
  void dispose() {
    _jobPollTimer?.cancel();
    _tabController.dispose();
    _textController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _loadActiveJob() async {
    try {
      final jobs = await _recipeService.getRecentRecipeImportJobs();
      if (!mounted ||
          _currentJob != null ||
          jobs.isEmpty ||
          !jobs.first.isActive)
        return;
      _watchJob(jobs.first);
    } catch (_) {
      // Formularz pozostaje dostępny przy chwilowym błędzie sieci.
    }
  }

  Future<void> _initializeImport() async {
    await _loadActiveJob();
    if (!mounted ||
        !widget.autoStartImport ||
        _currentJob != null ||
        _urlController.text.isEmpty)
      return;
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null || (!user.hasPremiumAccess && user.premiumPoints < 2))
      return;
    await _submitUrl();
  }

  void _watchJob(RecipeImportJob job) {
    if (!mounted) return;
    setState(() => _currentJob = job);
    _jobPollTimer?.cancel();
    if (job.isActive) {
      _jobPollTimer = Timer.periodic(
        const Duration(seconds: 6),
        (_) => _pollJob(),
      );
    }
  }

  Future<void> _pollJob() async {
    final id = _currentJob?.id;
    if (id == null || _pollingJob) return;
    _pollingJob = true;
    try {
      final updated = await _recipeService.getRecipeImportJob(id);
      if (!mounted || _currentJob?.id != id) return;
      _watchJob(updated);
      if (!updated.isActive) {
        await Provider.of<AuthProvider>(context, listen: false).loadProfile();
      }
    } catch (_) {
      // Kolejna próba za sześć sekund; praca serwera trwa dalej.
    } finally {
      _pollingJob = false;
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        // Mniejszy JPEG skraca przesłanie zdjęcia i analizę obrazu.
        // 1400 px zachowuje czytelność większości fotografowanych stron.
        maxWidth: 1400,
        maxHeight: 1400,
        imageQuality: 80,
      );
      if (picked != null) {
        if (!mounted) return;
        setState(() {
          _pickedImage = File(picked.path);
          _error = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text(context.strings.aiRecipePhotoLoadFailed),
          ),
        );
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      builder:
          (ctx) => SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: Text(context.strings.takeRecipePhoto),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: Text(context.strings.aiRecipeChooseGallery),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
    );
  }

  Future<void> _submitText() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final job = await _recipeService.startRecipeImport(text: text);
      _watchJob(job);
      if (!job.isActive && mounted) {
        await context.read<AuthProvider>().loadProfile();
      }
    } catch (e) {
      _handleError(e);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final job = await _recipeService.startRecipeImport(url: url);
      _watchJob(job);
      if (!job.isActive && mounted) {
        await context.read<AuthProvider>().loadProfile();
      }
    } catch (e) {
      _handleError(e);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitPhoto() async {
    if (_pickedImage == null) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final bytes = await _pickedImage!.readAsBytes();
      final base64Photo = base64Encode(bytes);
      final job = await _recipeService.startRecipeImport(
        photoBase64: base64Photo,
      );
      _watchJob(job);
      if (!job.isActive && mounted) {
        await context.read<AuthProvider>().loadProfile();
      }
    } catch (e) {
      _handleError(e);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _handleError(Object e) {
    if (!mounted) return;
    // UWAGA (rozszerzenie — punkty premium): kod 402 oznacza konkretnie
    // "brak Premium i za mało punktów" (patrz backend, ai_import_recipe)
    // — zamiast zwykłego komunikatu błędu, pokazujemy dialog z
    // bezpośrednim przejściem do zakupu punktów/Premium, żeby nie
    // zostawiać użytkownika z samą informacją "nie udało się", bez
    // wskazania, co dalej.
    if (e is ApiException && e.statusCode == 402) {
      _showPointsNeededDialog(e.message);
      return;
    }
    if (e is ApiException &&
        e.statusCode == 404 &&
        e.message.toLowerCase() == 'not found') {
      setState(() => _error = context.strings.aiRecipeServerUnavailable);
      return;
    }
    setState(() {
      _error = friendlyError(e, strings: context.strings);
    });
  }

  Future<void> _showPointsNeededDialog(String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(context.strings.aiRecipePremiumOrPointsTitle),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(context.strings.aiRecipeCancel),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PremiumScreen()),
                  );
                },
                child: Text(context.strings.aiRecipeBuyPoints),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<AuthProvider>(context).currentUser;
    // UWAGA (naprawa — "wymiana punktów na AI jakby nie istniała"): ten
    // ekran miał WŁASNĄ, starszą bramkę sprawdzającą TYLKO
    // hasPremiumAccess (subskrypcja/admin) — kompletnie nieświadomą
    // punktów. Skutek: użytkownik z punktami NIGDY nie docierał do
    // formularza, więc backend (który POPRAWNIE obsługuje płatność
    // punktami przy wysyłce) nigdy nie dostawał szansy zadziałać.
    // Dodajemy TYLKO tutaj (nie zmieniając samego hasPremiumAccess,
    // które słusznie oznacza gdzie indziej "ma AKTYWNĄ subskrypcję")
    // dodatkowy warunek: wystarczające punkty też otwierają formularz —
    // faktyczne pobranie 2 punktów i tak następuje dopiero po stronie
    // backendu, po udanym rozpoznaniu (patrz ai_import_recipe).
    final hasAccess =
        (currentUser?.hasPremiumAccess ?? false) ||
        (currentUser?.premiumPoints ?? 0) >= 2;

    if (!hasAccess && _currentJob == null) {
      return _buildPaywall(context);
    }

    return PopScope(
      canPop: Navigator.of(context).canPop(),
      onPopInvoked: (didPop) {
        if (!didPop) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _leaveImport());
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: context.strings.aiRecipeBackToApp,
            icon: const Icon(Icons.arrow_back),
            onPressed: _leaveImport,
          ),
          title: Text(context.strings.aiRecipeTitle),
          bottom:
              _currentJob != null
                  ? null
                  : TabBar(
                    controller: _tabController,
                    labelColor: AppTheme.primaryColor,
                    tabs: [
                      Tab(
                        text: context.strings.pasteText,
                        icon: const Icon(Icons.text_snippet_outlined),
                      ),
                      Tab(
                        text: context.strings.aiRecipePhoto,
                        icon: const Icon(Icons.photo_camera_outlined),
                      ),
                      Tab(
                        text: context.strings.aiRecipeLink,
                        icon: const Icon(Icons.link),
                      ),
                    ],
                  ),
        ),
        body: SafeArea(
          child:
              _isSubmitting
                  ? _buildLoadingState()
                  : _currentJob != null
                  ? _buildJobState(_currentJob!)
                  : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTextTab(),
                      _buildPhotoTab(),
                      _buildLinkTab(),
                    ],
                  ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppTheme.primaryColor),
            const SizedBox(height: 24),
            Text(
              context.strings.aiRecipeAccepting,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              context.strings.aiRecipeAcceptingHint,
              style: TextStyle(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobState(RecipeImportJob job) {
    final active = job.isActive;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (active)
              const CircularProgressIndicator()
            else
              Icon(
                job.status == 'completed'
                    ? Icons.check_circle
                    : Icons.error_outline,
                size: 48,
                color:
                    job.status == 'completed'
                        ? AppTheme.primaryColor
                        : AppTheme.errorColor,
              ),
            const SizedBox(height: 20),
            Text(
              active
                  ? context.strings.aiRecipePreparing
                  : job.status == 'completed'
                  ? context.strings.aiRecipeReady
                  : context.strings.aiRecipeRecognitionFailed,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              active
                  ? context.strings.aiRecipeBackgroundHint
                  : job.status == 'completed'
                  ? context.strings.aiRecipeFindInMine
                  : (job.error ?? context.strings.aiRecipeRetrySentence),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (job.status == 'completed' && job.recipeId != null)
              FilledButton(
                onPressed: () async {
                  try {
                    final recipe = await _recipeService.getRecipe(
                      job.recipeId!,
                    );
                    if (!mounted) return;
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const RecipeDetailScreen(),
                        settings: RouteSettings(arguments: recipe),
                      ),
                    );
                  } catch (error) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          friendlyError(error, strings: context.strings),
                        ),
                      ),
                    );
                  }
                },
                child: Text(context.strings.aiRecipeOpen),
              ),
            if (job.status == 'completed' && job.recipeId != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  try {
                    final recipe = await _recipeService.getRecipe(
                      job.recipeId!,
                    );
                    if (!mounted) return;
                    final updated = await showAiRecipeEditSheet(
                      context,
                      recipe,
                    );
                    if (updated == null || !mounted) return;
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const RecipeDetailScreen(),
                        settings: RouteSettings(arguments: updated),
                      ),
                    );
                  } catch (error) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          friendlyError(error, strings: context.strings),
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.auto_awesome_outlined),
                label: Text(context.strings.aiRecipeEditOnePoint),
              ),
            ],
            if (job.status == 'completed')
              TextButton(
                onPressed: () => setState(() => _currentJob = null),
                child: Text(context.strings.aiRecipeAddAnother),
              ),
            if (!active && job.status != 'completed')
              OutlinedButton(
                onPressed: () => setState(() => _currentJob = null),
                child: Text(context.strings.homeRetry),
              ),
            if (active)
              TextButton(
                onPressed: _leaveImport,
                child: Text(context.strings.aiRecipeBackToApp),
              ),
          ],
        ),
      ),
    );
  }

  void _leaveImport() {
    if (!mounted) return;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushReplacementNamed('/home');
    }
  }

  Widget _buildTextTab() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.strings.aiRecipePasteTextTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            context.strings.aiRecipeTextDescription,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TextField(
              controller: _textController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              maxLength: 10000,
              // UWAGA (naprawa): expands:true razem z maxLength to znany,
              // problematyczny wzorzec w Flutterze — domyślny licznik
              // znaków na dole (np. "123/10000") koliduje z polem
              // rozciąganym do pełnej dostępnej wysokości, co objawiało
              // się jako tekst "nie mieszczący się" w ramce do wpisywania.
              // Ukrycie licznika to standardowa, zalecana poprawka tej
              // niekompatybilności.
              buildCounter:
                  (
                    context, {
                    required currentLength,
                    required isFocused,
                    maxLength,
                  }) => null,
              decoration: InputDecoration(
                hintText: context.strings.aiRecipeTextHint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: AppTheme.errorColor, fontSize: 13),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitText,
              child: Text(context.strings.aiRecipeRecognise),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoTab() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.strings.aiRecipePhotoTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            context.strings.aiRecipePhotoDescription,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Expanded(
            child:
                _pickedImage != null
                    ? Stack(
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.file(_pickedImage!, fit: BoxFit.cover),
                          ),
                        ),
                        Positioned(
                          right: 8,
                          top: 8,
                          child: IconButton.filled(
                            onPressed:
                                () => setState(() => _pickedImage = null),
                            icon: const Icon(Icons.close),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    )
                    : InkWell(
                      onTap: _showImageSourceSheet,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppTheme.textSecondary.withOpacity(0.3),
                          ),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_a_photo_outlined,
                                size: 48,
                                color: AppTheme.textSecondary,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                context.strings.aiRecipeTapAddPhoto,
                                style: TextStyle(color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: AppTheme.errorColor, fontSize: 13),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _pickedImage != null ? _submitPhoto : null,
              child: Text(context.strings.aiRecipeRecognise),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkTab() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.strings.aiRecipePasteLinkTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            context.strings.aiRecipeLinkDescription,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _urlController,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              hintText: 'https://...',
              prefixIcon: const Icon(Icons.link),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: AppTheme.errorColor, fontSize: 13),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitUrl,
              child: Text(context.strings.aiRecipeRecognise),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaywall(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.strings.aiRecipeTitle)),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppTheme.secondaryColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.workspace_premium_outlined,
                size: 40,
                color: AppTheme.secondaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              context.strings.aiRecipePremiumFeature,
              style: Theme.of(
                context,
              ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              context.strings.aiRecipePremiumDescription,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.strings.aiRecipePremiumHint,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PremiumScreen()),
                  );
                },
                icon: const Icon(Icons.workspace_premium),
                label: Text(context.strings.homeViewPremium),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
