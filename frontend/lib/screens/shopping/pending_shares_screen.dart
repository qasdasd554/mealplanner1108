import 'package:flutter/material.dart';
import '../../services/shopping_list_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_utils.dart';

/// Zaproszenia do współdzielonych list zakupów, oczekujące na akceptację
/// — dwuetapowe udostępnianie (patrz backend, ShoppingListShare): druga
/// strona MUSI świadomie zaakceptować, zanim dostanie dostęp do listy.
class PendingSharesScreen extends StatefulWidget {
  const PendingSharesScreen({super.key});

  @override
  State<PendingSharesScreen> createState() => _PendingSharesScreenState();
}

class _PendingSharesScreenState extends State<PendingSharesScreen> {
  final ShoppingListService _service = ShoppingListService();
  List<ShoppingListShare> _pending = [];
  bool _isLoading = true;
  String? _error;

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
      final shares = await _service.getPendingShares();
      if (!mounted) return;
      setState(() {
        _pending = shares;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _accept(ShoppingListShare share) async {
    try {
      await _service.acceptShare(share.id);
      if (!mounted) return;
      setState(() => _pending.remove(share));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zaakceptowano — lista pojawi się jako udostępniona.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e)), backgroundColor: AppTheme.errorColor),
      );
    }
  }

  Future<void> _decline(ShoppingListShare share) async {
    try {
      await _service.deleteShare(share.id);
      if (!mounted) return;
      setState(() => _pending.remove(share));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e)), backgroundColor: AppTheme.errorColor),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Zaproszenia do list zakupów')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(
                    children: [
                      const SizedBox(height: 80),
                      Center(child: Text(_error!, textAlign: TextAlign.center)),
                      const SizedBox(height: 12),
                      Center(child: TextButton(onPressed: _load, child: const Text('Spróbuj ponownie'))),
                    ],
                  )
                : _pending.isEmpty
                    ? ListView(
                        children: [
                          const SizedBox(height: 100),
                          Icon(Icons.mail_outline, size: 56, color: AppTheme.textSecondary),
                          const SizedBox(height: 12),
                          Center(
                            child: Text(
                              'Brak oczekujących zaproszeń.',
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _pending.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final share = _pending[index];
                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.shopping_cart_outlined),
                              title: Text('${share.sharedByName ?? "Ktoś"} udostępnił Ci listę zakupów'),
                              subtitle: const Text('Dotknij, aby odpowiedzieć'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.check_circle, color: AppTheme.primaryColor),
                                    tooltip: 'Zaakceptuj',
                                    onPressed: () => _accept(share),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.cancel_outlined, color: AppTheme.errorColor),
                                    tooltip: 'Odrzuć',
                                    onPressed: () => _decline(share),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
