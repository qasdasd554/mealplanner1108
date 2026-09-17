import 'package:flutter/material.dart';

import '../../models/friend.dart';
import '../../services/friend_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_utils.dart';
import '../../widgets/user_avatar.dart';
import 'friend_detail_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _service = FriendService();
  List<FriendEntry>? _friends;
  List<FriendEntry>? _invitations;
  String? _error;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final values = await Future.wait([_service.getFriends(), _service.getInvitations()]);
      if (!mounted) return;
      setState(() {
        _friends = values[0];
        _invitations = values[1];
      });
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    }
  }

  Future<void> _invite() async {
    final controller = TextEditingController();
    final identifier = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Zaproś znajomego'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Nazwa użytkownika lub e-mail',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Anuluj')),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.length >= 2) Navigator.pop(dialogContext, value);
            },
            child: const Text('Wyślij'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (identifier == null || !mounted) return;
    setState(() => _working = true);
    try {
      await _service.invite(identifier);
      await _load();
      if (mounted) _message('Zaproszenie zostało wysłane.');
    } catch (error) {
      if (mounted) _message(friendlyError(error));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _act(Future<void> Function() action, String success) async {
    setState(() => _working = true);
    try {
      await action();
      await _load();
      if (mounted) _message(success);
    } catch (error) {
      if (mounted) _message(friendlyError(error));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final incoming = _invitations?.where((item) => item.direction == 'incoming').toList() ?? [];
    final outgoing = _invitations?.where((item) => item.direction == 'outgoing').toList() ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Znajomi')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _working ? null : _invite,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Zaproś'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _error != null
            ? ListView(
                children: [
                  const SizedBox(height: 140),
                  Center(child: Text(_error!, textAlign: TextAlign.center)),
                  Center(child: TextButton(onPressed: _load, child: const Text('Spróbuj ponownie'))),
                ],
              )
            : (_friends == null || _invitations == null)
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    children: [
                      if (incoming.isNotEmpty) ...[
                        const _Heading('Zaproszenia do Ciebie'),
                        ...incoming.map((entry) => _InvitationCard(
                              entry: entry,
                              working: _working,
                              onAccept: () => _act(
                                () => _service.accept(entry.connectionId),
                                'Zaproszenie zostało przyjęte.',
                              ),
                              onDecline: () => _act(
                                () => _service.declineOrCancel(entry.connectionId),
                                'Zaproszenie zostało odrzucone.',
                              ),
                            )),
                        const SizedBox(height: 18),
                      ],
                      const _Heading('Twoi znajomi'),
                      if (_friends!.isEmpty)
                        const _InfoCard(
                          icon: Icons.people_outline,
                          text: 'Nie masz jeszcze znajomych. Wyślij pierwsze zaproszenie.',
                        )
                      else
                        ..._friends!.map((entry) => Card(
                              child: ListTile(
                                leading: UserAvatar(
                                  avatar: entry.avatar,
                                  avatarPhotoBase64: entry.avatarPhotoBase64,
                                  size: 44,
                                ),
                                title: Text(entry.displayName,
                                    style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: const Text('Przepisy i lista zakupów'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => FriendDetailScreen(friend: entry)),
                                ),
                              ),
                            )),
                      if (outgoing.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        const _Heading('Wysłane zaproszenia'),
                        ...outgoing.map((entry) => Card(
                              child: ListTile(
                                leading: UserAvatar(
                                  avatar: entry.avatar,
                                  avatarPhotoBase64: entry.avatarPhotoBase64,
                                  size: 40,
                                ),
                                title: Text(entry.displayName),
                                subtitle: const Text('Oczekuje na odpowiedź'),
                                trailing: TextButton(
                                  onPressed: _working
                                      ? null
                                      : () => _act(
                                            () => _service.declineOrCancel(entry.connectionId),
                                            'Zaproszenie zostało anulowane.',
                                          ),
                                  child: const Text('Anuluj'),
                                ),
                              ),
                            )),
                      ],
                    ],
                  ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  final String text;
  const _Heading(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      );
}

class _InvitationCard extends StatelessWidget {
  final FriendEntry entry;
  final bool working;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _InvitationCard({
    required this.entry,
    required this.working,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              UserAvatar(
                avatar: entry.avatar,
                avatarPhotoBase64: entry.avatarPhotoBase64,
                size: 44,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(entry.displayName, style: const TextStyle(fontWeight: FontWeight.w600))),
              IconButton(
                tooltip: 'Odrzuć',
                onPressed: working ? null : onDecline,
                icon: const Icon(Icons.close),
              ),
              IconButton.filled(
                tooltip: 'Przyjmij',
                onPressed: working ? null : onAccept,
                icon: const Icon(Icons.check),
              ),
            ],
          ),
        ),
      );
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoCard({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primaryColor),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
          ],
        ),
      );
}
