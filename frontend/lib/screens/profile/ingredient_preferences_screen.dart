import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/ingredient_preferences.dart';
import '../../models/product.dart';
import '../../providers/auth_provider.dart';
import '../../services/ingredient_preferences_service.dart';
import '../../services/product_search_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_utils.dart';

class IngredientPreferencesScreen extends StatefulWidget {
  final IngredientPreferencesService? service;
  final ProductSearchService? searchService;
  const IngredientPreferencesScreen({
    super.key,
    this.service,
    this.searchService,
  });

  @override
  State<IngredientPreferencesScreen> createState() =>
      _IngredientPreferencesScreenState();
}

class _IngredientPreferencesScreenState
    extends State<IngredientPreferencesScreen> {
  late final IngredientPreferencesService _service;
  late final ProductSearchService _searchService;
  final _search = TextEditingController();
  Timer? _debounce;
  int _queryVersion = 0;
  bool _loading = true;
  bool _saving = false;
  bool _searching = false;
  bool _addingLiked = true;
  bool _dirty = false;
  String? _loadError;
  String? _saveError;
  String? _searchError;
  List<IngredientChoice> _liked = [];
  List<IngredientChoice> _disliked = [];
  List<Product> _results = [];
  bool _hadPremium = false;
  Color get _premiumGold =>
      AppTheme.isDark ? const Color(0xFFFFD166) : const Color(0xFF8A5C00);

  bool get _premium =>
      context.read<AuthProvider>().currentUser?.hasPremiumAccess ?? false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? IngredientPreferencesService();
    _searchService = widget.searchService ?? ProductSearchService();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final premium =
        context.watch<AuthProvider>().currentUser?.hasPremiumAccess ?? false;
    if (premium && !_hadPremium) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
    _hadPremium = premium;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final data = await _service.load();
      if (!mounted) return;
      setState(() {
        _liked = data.liked.toList();
        _disliked = data.disliked.toList();
        _dirty = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loadError = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _searchChanged(String text) {
    _debounce?.cancel();
    final version = ++_queryVersion;
    setState(() {
      _searchError = null;
      _results = [];
      _searching = text.trim().isNotEmpty;
    });
    if (text.trim().isEmpty) return;
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final results = await _searchService.search(text.trim());
        if (!mounted || version != _queryVersion) return;
        setState(() {
          _results =
              results.where((p) => p.reviewStatus == 'approved').toList();
          _searching = false;
        });
      } catch (e) {
        if (!mounted || version != _queryVersion) return;
        setState(() {
          _searchError = friendlyError(e);
          _searching = false;
        });
      }
    });
  }

  void _add(Product product) {
    final selected = _addingLiked ? _liked : _disliked;
    if (selected.any((p) => p.id == product.id)) return;
    if (selected.length >= 50) {
      setState(
        () => _saveError = 'Możesz wybrać do 50 składników w każdej grupie.',
      );
      return;
    }
    setState(() {
      (_addingLiked ? _disliked : _liked).removeWhere(
        (p) => p.id == product.id,
      );
      selected.add(IngredientChoice(id: product.id, name: product.name));
      _dirty = true;
      _saveError = null;
    });
  }

  Future<void> _save() async {
    if (_saving || !_premium) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final saved = await _service.save(
        IngredientPreferences(liked: _liked, disliked: _disliked),
      );
      if (!mounted) return;
      setState(() {
        _liked = saved.liked.toList();
        _disliked = saved.disliked.toList();
        _dirty = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zapisano preferencje składników.')),
      );
    } catch (e) {
      if (mounted) setState(() => _saveError = friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _confirmLeave() async {
    if (!_dirty || _saving) return !_saving;
    return await showDialog<bool>(
          context: context,
          builder:
              (ctx) => AlertDialog(
                title: const Text('Niezapisane preferencje'),
                content: const Text(
                  'Masz niezapisane zmiany. Wrócić bez zapisywania?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Zostań'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Wróć bez zapisu'),
                  ),
                ],
              ),
        ) ??
        false;
  }

  Widget _choices(String title, List<IngredientChoice> choices) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      if (choices.isEmpty)
        Text(
          'Jeszcze nie wybrano składników.',
          style: TextStyle(color: AppTheme.textSecondary),
        )
      else
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children:
              choices
                  .map(
                    (p) => InputChip(
                      label: Text(p.name),
                      tooltip: p.name,
                      onDeleted:
                          _saving
                              ? null
                              : () => setState(() {
                                choices.remove(p);
                                _dirty = true;
                                _saveError = null;
                              }),
                      deleteButtonTooltipMessage: 'Usuń ${p.name}',
                    ),
                  )
                  .toList(),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final premium =
        context.watch<AuthProvider>().currentUser?.hasPremiumAccess ?? false;
    return PopScope(
      canPop: !_dirty && !_saving,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _confirmLeave() && context.mounted) {
          setState(() => _dirty = false);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.of(context).pop();
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Preferencje składników')),
        body: SafeArea(
          child:
              !premium
                  ? _locked(context)
                  : _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _loadError != null
                  ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_loadError!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: _load,
                            child: const Text('Spróbuj ponownie'),
                          ),
                        ],
                      ),
                    ),
                  )
                  : Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Premium',
                                style: TextStyle(
                                  color: _premiumGold,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Uwzględnimy preferencje w jednym daniu dziennie, jeśli znajdziemy pasujący przepis. Alergie i dieta mają pierwszeństwo.',
                              ),
                              const SizedBox(height: 20),
                              _choices('Lubię', _liked),
                              const SizedBox(height: 20),
                              _choices('Nie lubię', _disliked),
                              const SizedBox(height: 24),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  ChoiceChip(
                                    label: const Text('Dodaj do: Lubię'),
                                    selected: _addingLiked,
                                    onSelected:
                                        _saving
                                            ? null
                                            : (_) => setState(
                                              () => _addingLiked = true,
                                            ),
                                  ),
                                  ChoiceChip(
                                    label: const Text('Dodaj do: Nie lubię'),
                                    selected: !_addingLiked,
                                    onSelected:
                                        _saving
                                            ? null
                                            : (_) => setState(
                                              () => _addingLiked = false,
                                            ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _search,
                                enabled: !_saving,
                                onChanged: _searchChanged,
                                decoration: InputDecoration(
                                  labelText: 'Szukaj składnika',
                                  prefixIcon: const Icon(Icons.search),
                                  suffixIcon:
                                      _search.text.isEmpty
                                          ? null
                                          : IconButton(
                                            tooltip: 'Wyczyść wyszukiwanie',
                                            icon: const Icon(Icons.close),
                                            onPressed: () {
                                              _search.clear();
                                              _searchChanged('');
                                            },
                                          ),
                                  helperText:
                                      'Wybranie w drugiej grupie przenosi składnik.',
                                  helperMaxLines: 2,
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (_searching)
                                const LinearProgressIndicator()
                              else if (_searchError != null)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_searchError!),
                                    TextButton(
                                      onPressed:
                                          () => _searchChanged(_search.text),
                                      child: const Text('Ponów wyszukiwanie'),
                                    ),
                                  ],
                                )
                              else if (_search.text.trim().isNotEmpty &&
                                  _results.isEmpty)
                                const Text('Brak składników o tej nazwie.')
                              else
                                for (final product in _results)
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(product.name),
                                    trailing: Icon(
                                      (_addingLiked ? _liked : _disliked).any(
                                            (p) => p.id == product.id,
                                          )
                                          ? Icons.check
                                          : Icons.add,
                                    ),
                                    onTap: _saving ? null : () => _add(product),
                                  ),
                              if (_saveError != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 16),
                                  child: Semantics(
                                    liveRegion: true,
                                    child: Text(
                                      'Nie zapisano: $_saveError',
                                      style: const TextStyle(
                                        color: AppTheme.errorColor,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _saving || !_dirty ? null : _save,
                            child: Text(
                              _saving
                                  ? 'Zapisywanie…'
                                  : _dirty
                                  ? 'Zapisz preferencje'
                                  : 'Preferencje zapisane',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
        ),
      ),
    );
  }

  Widget _locked(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium_outlined, size: 40, color: _premiumGold),
          const SizedBox(height: 12),
          Text(
            'Premium',
            style: TextStyle(color: _premiumGold, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          const Text(
            'Wybierz składniki, które lubisz i których nie lubisz. Premium uwzględni je w jednym daniu dziennie, jeśli znajdziemy pasujący przepis.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => Navigator.of(context).pushNamed('/premium'),
            child: const Text('Zobacz Premium'),
          ),
        ],
      ),
    ),
  );
}
