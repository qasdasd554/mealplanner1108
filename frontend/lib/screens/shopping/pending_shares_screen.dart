import 'package:flutter/material.dart';
import '../../services/shopping_list_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_utils.dart';
import '../../l10n/market_locale.dart';

/// Zaproszenia do współdzielonych list zakupów, oczekujące na akceptację
/// — dwuetapowe udostępnianie (patrz backend, ShoppingListShare): druga
/// strona MUSI świadomie zaakceptować, zanim dostanie dostęp do listy.
class PendingSharesScreen extends StatefulWidget {
  final ShoppingListService? service;
  const PendingSharesScreen({super.key, this.service});

  @override
  State<PendingSharesScreen> createState() => _PendingSharesScreenState();
}

class _PendingSharesScreenState extends State<PendingSharesScreen> {
  late final ShoppingListService _service;
  List<ShoppingListShare> _pending = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? ShoppingListService();
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
        _error = friendlyError(e, strings: context.strings);
        _isLoading = false;
      });
    }
  }

  Future<void> _accept(ShoppingListShare share) async {
    try {
      await _service.acceptShare(share.id);
      if (!mounted) return;
      setState(() => _pending.remove(share));
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text(context.strings.socialShareAccepted),
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
    }
  }

  Future<void> _decline(ShoppingListShare share) async {
    try {
      await _service.deleteShare(share.id);
      if (!mounted) return;
      setState(() => _pending.remove(share));
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.strings.socialSharesTitle)),
      body: RefreshIndicator(
        onRefresh: _load,
        child:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? ListView(
                  children: [
                    const SizedBox(height: 80),
                    Center(child: Text(_error!, textAlign: TextAlign.center)),
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: _load,
                        child: Text(context.strings.socialRetry),
                      ),
                    ),
                  ],
                )
                : _pending.isEmpty
                ? ListView(
                  children: [
                    const SizedBox(height: 100),
                    Icon(
                      Icons.mail_outline,
                      size: 56,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        context.strings.socialNoPendingShares,
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
                        title: Text(
                          context.strings.socialSharedListInvitation(
                            share.sharedByName ?? context.strings.socialSomeone,
                          ),
                        ),
                        subtitle: Text(context.strings.socialShareRespond),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.check_circle,
                                color: AppTheme.primaryColor,
                              ),
                              tooltip: context.strings.socialShareAccept,
                              onPressed: () => _accept(share),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.cancel_outlined,
                                color: AppTheme.errorColor,
                              ),
                              tooltip: context.strings.socialDecline,
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
