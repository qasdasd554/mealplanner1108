import 'package:flutter/material.dart';
import '../../models/product.dart';
import '../../services/pantry_service.dart';
import '../../services/product_search_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_utils.dart';
import '../../utils/quantity_formatter.dart';

/// Spiżarnia — trwała lista produktów, które użytkownik faktycznie ma w
/// domu. Źródło dla "Co ugotować z tego, co mam" — zamiast wyszukiwać
/// składniki za każdym razem od nowa, wystarczy raz zbudować spiżarnię i
/// aktualizować ją na bieżąco.
class PantryScreen extends StatefulWidget {
  const PantryScreen({super.key});

  @override
  State<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends State<PantryScreen> {
  final PantryService _pantryService = PantryService();
  List<PantryItem> _items = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final items = await _pantryService.getPantry();
      if (!mounted) return;
      setState(() => _items = items);
    } catch (e) {
      if (!mounted) return;
      // UWAGA (naprawa wzorca błędu): pokazujemy PRAWDZIWY komunikat
      // błędu zamiast po cichu zostawiać pustą listę — wcześniejsza
      // wersja ekranu wyboru składników cicho łykała błędy (catch (_)),
      // co uniemożliwiało zdiagnozowanie prawdziwej przyczyny problemów.
      setState(() => _errorMessage = friendlyError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _delete(PantryItem item) async {
    // Optymistyczne usunięcie z UI, z przywróceniem przy błędzie —
    // czuje się natychmiastowe, bez migania stanu ładowania.
    final removedIndex = _items.indexOf(item);
    setState(() => _items.remove(item));
    try {
      await _pantryService.deleteItem(item.id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _items.insert(removedIndex, item));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e)), backgroundColor: AppTheme.errorColor),
      );
    }
  }

  /// Prosty dialog do wpisania/zmiany ilości produktu już zapisanego w
  /// spiżarni — jednostka domyślnie wypełniona z produktu (np. "kg",
  /// "szt"), użytkownik wpisuje samą liczbę.
  Future<void> _editQuantity(PantryItem item) async {
    final controller = TextEditingController(
      text: item.quantity != null ? formatQuantity(item.quantity!, item.unit ?? item.product.unit) : '',
    );
    final unit = item.unit ?? item.product.unit;

    final newQuantity = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item.product.name),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Ile masz? ($unit)',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () {
              // UWAGA: polska klawiatura zwykle wpisuje przecinek jako
              // separator dziesiętny — double.tryParse w Dart rozumie
              // tylko kropkę, stąd zamiana przed parsowaniem (ten sam
              // wzorzec, który już wcześniej naprawił podobny problem
              // w formularzu ręcznego dodawania przepisu).
              final value = double.tryParse(controller.text.trim().replaceAll(',', '.'));
              Navigator.pop(ctx, value);
            },
            child: const Text('Zapisz'),
          ),
        ],
      ),
    );

    if (newQuantity == null) return;

    try {
      final updated = await _pantryService.updateQuantity(item.id, quantity: newQuantity, unit: unit);
      if (!mounted) return;
      setState(() {
        final index = _items.indexWhere((i) => i.id == item.id);
        if (index != -1) _items[index] = updated;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e)), backgroundColor: AppTheme.errorColor),
      );
    }
  }

  Future<void> _showAddDialog() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _AddToPantrySheet(pantryService: _pantryService),
    );
    if (added == true) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Spiżarnia')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        icon: const Icon(Icons.add),
        label: const Text('Dodaj produkt'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.cloud_off_outlined, size: 48, color: AppTheme.textSecondary),
                            const SizedBox(height: 16),
                            Text(_errorMessage!, textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            OutlinedButton(onPressed: _load, child: const Text('Spróbuj ponownie')),
                          ],
                        ),
                      ),
                    )
                  : _items.isEmpty
                      ? ListView(
                          // ListView (nie Center) — żeby RefreshIndicator
                          // działał nawet przy pustej spiżarni.
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 32),
                              child: Column(
                                children: [
                                  Icon(Icons.kitchen_outlined, size: 56, color: AppTheme.textSecondary),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Spiżarnia jest pusta. Dodaj produkty, które masz w domu, żeby móc szybko sprawdzić, co z nich ugotować.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                          itemCount: _items.length,
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: Icon(Icons.check_circle, color: AppTheme.primaryColor),
                                title: Text(item.product.name),
                                subtitle: Text(
                                  item.quantity != null
                                      ? '${formatQuantity(item.quantity!, item.unit ?? item.product.unit)} ${item.unit ?? item.product.unit}'
                                      : 'Dotknij, aby wpisać ilość',
                                  style: TextStyle(
                                    color: item.quantity != null ? AppTheme.textSecondary : AppTheme.primaryColor,
                                    fontStyle: item.quantity != null ? FontStyle.normal : FontStyle.italic,
                                  ),
                                ),
                                onTap: () => _editQuantity(item),
                                trailing: IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () => _delete(item),
                                  tooltip: 'Usuń ze spiżarni',
                                ),
                              ),
                            );
                          },
                        ),
        ),
      ),
    );
  }
}

/// Dolny panel do wyszukania i dodania produktów do spiżarni. Osobny
/// widget (nie metoda) — bo potrzebuje własnego stanu (wyniki
/// wyszukiwania), inaczej `showModalBottomSheet`'s builder nie
/// odświeżałby się poprawnie przy wpisywaniu tekstu.
class _AddToPantrySheet extends StatefulWidget {
  final PantryService pantryService;

  const _AddToPantrySheet({required this.pantryService});

  @override
  State<_AddToPantrySheet> createState() => _AddToPantrySheetState();
}

class _AddToPantrySheetState extends State<_AddToPantrySheet> {
  final ProductSearchService _searchService = ProductSearchService();
  final TextEditingController _controller = TextEditingController();
  List<Product> _results = [];
  bool _isSearching = false;
  bool _isSaving = false;

  Future<void> _search(String query) async {
    if (query.trim().length < 2) {
      setState(() => _results = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final results = await _searchService.search(query);
      if (!mounted) return;
      setState(() => _results = results);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e)), backgroundColor: AppTheme.errorColor),
      );
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _add(Product product) async {
    setState(() => _isSaving = true);
    try {
      await widget.pantryService.addItems([product.id]);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dodano "${product.name}" do spiżarni.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e)), backgroundColor: AppTheme.errorColor),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dodaj do spiżarni', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              onChanged: _search,
              decoration: InputDecoration(
                hintText: 'Szukaj produktu...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 280,
              child: _isSearching
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty
                      ? Center(
                          child: Text(
                            _controller.text.trim().length < 2
                                ? 'Wpisz nazwę produktu.'
                                : 'Brak wyników.',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _results.length,
                          itemBuilder: (context, index) {
                            final product = _results[index];
                            return ListTile(
                              title: Text(product.name),
                              trailing: _isSaving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.add_circle_outline),
                              onTap: _isSaving ? null : () => _add(product),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
