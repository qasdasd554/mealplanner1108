import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/user_avatar.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  List<Map<String, dynamic>>? _blocked;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final blocked = await authProvider.getBlockedUsers();
    if (!mounted) return;
    setState(() {
      _blocked = blocked;
      _isLoading = false;
    });
  }

  Future<void> _unblock(String userId, String name) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.unblockUser(userId);
    if (!mounted) return;
    if (success) {
      setState(() {
        _blocked?.removeWhere((b) => b['blocked_user_id'] == userId);
      });
      ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('Odblokowano "$name". Znów zobaczysz jej/jego treści.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Zablokowani użytkownicy')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (_blocked == null || _blocked!.isEmpty)
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.block, size: 48, color: AppTheme.textSecondary),
                        const SizedBox(height: 12),
                        Text(
                          'Nie zablokowałeś jeszcze nikogo.',
                          style: TextStyle(color: AppTheme.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _blocked!.length,
                  itemBuilder: (context, index) {
                    final entry = _blocked![index];
                    final name = entry['blocked_display_name'] as String? ?? 'Użytkownik';
                    final userId = entry['blocked_user_id'] as String;
                    final avatar = entry['blocked_avatar'] as String?;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: UserAvatar(avatar: avatar, size: 40),
                        title: Text(name),
                        trailing: TextButton(
                          onPressed: () => _unblock(userId, name),
                          child: const Text('Odblokuj'),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
