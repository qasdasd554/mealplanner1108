import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/recipe.dart';
import '../../providers/auth_provider.dart';
import '../../services/recipe_service.dart';
import '../../services/api_client.dart';
import '../../theme/app_theme.dart';
import 'recipe_detail_screen.dart';
import '../profile/premium_screen.dart';
import '../../utils/error_utils.dart';

/// Ekran dodawania własnego przepisu przez AI — z wklejonego tekstu albo
/// zdjęcia. Funkcja Premium: konta bez aktywnej subskrypcji widzą tu
/// czytelną informację zamiast formularza (bez udawania niedziałającego
/// przycisku zakupu — prawdziwe płatności jeszcze nie są podłączone).
class AiAddRecipeScreen extends StatefulWidget {
  // Jeśli podany (np. z udostępnienia linku z TikToka), ekran otwiera
  // się od razu na zakładce "Link" z tym adresem wpisanym w polu.
  final String? initialUrl;
  // Jeśli podany (np. z "Co ugotować z tego, co mam" — gdy dopasowanie
  // z bazy nic nie znajdzie), ekran otwiera się od razu na zakładce
  // "Tekst" z gotowym opisem wypełnionym w polu.
  final String? initialText;

  const AiAddRecipeScreen({super.key, this.initialUrl, this.initialText});

  @override
  State<AiAddRecipeScreen> createState() => _AiAddRecipeScreenState();
}

class _AiAddRecipeScreenState extends State<AiAddRecipeScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final RecipeService _recipeService = RecipeService();
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  File? _pickedImage;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    if (widget.initialUrl != null && widget.initialUrl!.isNotEmpty) {
      _urlController.text = widget.initialUrl!;
      // Indeks 2 = zakładka "Link" (Tekst=0, Zdjęcie=1, Link=2).
      _tabController.index = 2;
    } else if (widget.initialText != null && widget.initialText!.isNotEmpty) {
      _textController.text = widget.initialText!;
      // Indeks 0 = zakładka "Tekst" — już domyślna, ale jawnie dla jasności.
      _tabController.index = 0;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _textController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
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
        const SnackBar(content: Text('Nie udało się pobrać zdjęcia')),
      );
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Zrób zdjęcie'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Wybierz z galerii'),
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
      final recipe = await _recipeService.importRecipeFromText(text);
      await _onSuccess(recipe);
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
      final recipe = await _recipeService.importRecipeFromUrl(url);
      await _onSuccess(recipe);
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
      final recipe = await _recipeService.importRecipeFromPhoto(base64Photo);
      await _onSuccess(recipe);
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
    setState(() {
      _error = friendlyError(e);
    });
  }

  Future<void> _showPointsNeededDialog(String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Potrzebujesz Premium albo punktów'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Anuluj')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PremiumScreen()),
              );
            },
            child: const Text('Kup punkty'),
          ),
        ],
      ),
    );
  }

  Future<void> _onSuccess(Recipe recipe) async {
    if (!mounted) return;
    // UWAGA (naprawa — "punkty nie ubywają"): backend POPRAWNIE odejmuje
    // punkty w bazie po udanym imporcie, ale to konto (AuthProvider)
    // nigdy nie było odświeżane po tej operacji — więc wyświetlane
    // saldo pozostawało STARE, sprzed wysłania zapytania, dopóki
    // aplikacja nie została zrestartowana (co wymusza nowe pobranie
    // profilu przy starcie). Odświeżamy tutaj, PRZED nawigacją dalej,
    // żeby saldo widoczne gdziekolwiek w aplikacji było już aktualne.
    await Provider.of<AuthProvider>(context, listen: false).loadProfile();
    if (!mounted) return;
    // Przejdź od razu do widoku nowego przepisu — użytkownik widzi
    // natychmiast, co AI rozpoznało, zamiast dodatkowego ekranu
    // potwierdzenia.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => RecipeDetailScreen(),
        settings: RouteSettings(arguments: recipe),
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
    final hasAccess = (currentUser?.hasPremiumAccess ?? false) || (currentUser?.premiumPoints ?? 0) >= 2;

    if (!hasAccess) {
      return _buildPaywall(context);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dodaj przepis przez AI'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          tabs: const [
            Tab(text: 'Wklej tekst', icon: Icon(Icons.text_snippet_outlined)),
            Tab(text: 'Zdjęcie', icon: Icon(Icons.photo_camera_outlined)),
            Tab(text: 'Link', icon: Icon(Icons.link)),
          ],
        ),
      ),
      // UWAGA (naprawa — ten sam błąd co wcześniej z wyborem awatara):
      // przyciski na dole każdej z trzech zakładek nie były chronione
      // SafeArea, więc w trybie edge-to-edge mogły częściowo chować się
      // pod systemowym paskiem nawigacji na dole ekranu.
      body: SafeArea(
        child: _isSubmitting
            ? _buildLoadingState()
            : TabBarView(
                controller: _tabController,
                children: [_buildTextTab(), _buildPhotoTab(), _buildLinkTab()],
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
              'Rozpoznaję przepis...',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'To może potrwać kilka-kilkanaście sekund.',
              style: TextStyle(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextTab() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Wklej treść przepisu',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Wklej gotowy przepis (z notatnika, wiadomości, strony internetowej) — '
            'AI rozpozna składniki i kroki. Albo po prostu wpisz samą nazwę dania '
            '(np. "rosół" albo "lasagne") — AI ułoży dla Ciebie cały przepis od zera.',
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
              buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
              decoration: InputDecoration(
                hintText: 'np. "rosół" albo pełny przepis ze składnikami i krokami...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: AppTheme.errorColor, fontSize: 13)),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitText,
              child: const Text('Rozpoznaj przepis'),
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
            'Zrób zdjęcie przepisu',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Zdjęcie karty przepisu, strony książki kucharskiej, albo '
            'gotowego dania — AI oszacuje wtedy prawdopodobny przepis.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _pickedImage != null
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
                          onPressed: () => setState(() => _pickedImage = null),
                          icon: const Icon(Icons.close),
                          style: IconButton.styleFrom(backgroundColor: Colors.black54),
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
                        border: Border.all(color: AppTheme.textSecondary.withOpacity(0.3)),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo_outlined, size: 48, color: AppTheme.textSecondary),
                            const SizedBox(height: 8),
                            Text('Dotknij, aby dodać zdjęcie', style: TextStyle(color: AppTheme.textSecondary)),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: AppTheme.errorColor, fontSize: 13)),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _pickedImage != null ? _submitPhoto : null,
              child: const Text('Rozpoznaj przepis'),
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
            'Wklej link do przepisu',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Blog kulinarny, TikTok, Instagram — AI spróbuje rozpoznać przepis '
            'na podstawie treści strony. Jeśli przepis pada wyłącznie w mowie '
            'w nagraniu (nie ma go w opisie), rozpoznanie może się nie udać.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _urlController,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              hintText: 'https://...',
              prefixIcon: const Icon(Icons.link),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: AppTheme.errorColor, fontSize: 13)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitUrl,
              child: const Text('Rozpoznaj przepis'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaywall(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dodaj przepis przez AI')),
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
              child: const Icon(Icons.workspace_premium_outlined, size: 40, color: AppTheme.secondaryColor),
            ),
            const SizedBox(height: 24),
            Text(
              'Funkcja Premium',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Dodawanie własnych przepisów przez AI (z tekstu albo zdjęcia) '
              'jest dostępne dla kont z aktywną subskrypcją Premium — albo za 2 punkty premium, '
              'bez subskrypcji.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 8),
            Text(
              'Zobacz, co jeszcze zyskujesz z Premium, albo kup pakiet punktów.',
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
                label: const Text('Zobacz Premium'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
