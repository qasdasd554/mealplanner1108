import 'package:flutter/material.dart';

import '../../models/friend.dart';
import '../../services/friend_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_utils.dart';
import '../../utils/retained_dialog.dart';
import '../../l10n/market_locale.dart';
import '../../widgets/user_avatar.dart';
import 'friend_detail_screen.dart';

class FriendsScreen extends StatefulWidget {
  final FriendService? service;
  const FriendsScreen({super.key, this.service});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  late final FriendService _service;
  List<FriendEntry>? _friends;
  List<FriendEntry>? _invitations;
  String? _error;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? FriendService();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final values = await Future.wait([
        _service.getFriends(),
        _service.getInvitations(),
      ]);
      if (!mounted) return;
      setState(() {
        _friends = values[0];
        _invitations = values[1];
      });
    } catch (error) {
      if (mounted)
        setState(() => _error = friendlyError(error, strings: context.strings));
    }
  }

  Future<void> _invite() async {
    final controller = TextEditingController();
    final identifier = await showRetainedDialog<String>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(context.strings.socialInviteTitle),
            content: TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: context.strings.socialIdentifier,
                border: const OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(context.strings.commentsCancel),
              ),
              FilledButton(
                onPressed: () {
                  final value = controller.text.trim();
                  if (value.length >= 2) Navigator.pop(dialogContext, value);
                },
                child: Text(context.strings.socialSend),
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
      if (mounted) _message(context.strings.socialInvitationSent);
    } catch (error) {
      if (mounted) _message(friendlyError(error, strings: context.strings));
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
      if (mounted) _message(friendlyError(error, strings: context.strings));
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
    final incoming =
        _invitations?.where((item) => item.direction == 'incoming').toList() ??
        [];
    final outgoing =
        _invitations?.where((item) => item.direction == 'outgoing').toList() ??
        [];

    return Scaffold(
      appBar: AppBar(title: Text(context.strings.socialFriends)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _working ? null : _invite,
        icon: const Icon(Icons.person_add_alt_1),
        label: Text(context.strings.socialInvite),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child:
            _error != null
                ? ListView(
                  children: [
                    const SizedBox(height: 140),
                    Center(child: Text(_error!, textAlign: TextAlign.center)),
                    Center(
                      child: TextButton(
                        onPressed: _load,
                        child: Text(context.strings.socialRetry),
                      ),
                    ),
                  ],
                )
                : (_friends == null || _invitations == null)
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  children: [
                    if (incoming.isNotEmpty) ...[
                      _Heading(context.strings.socialIncoming),
                      ...incoming.map(
                        (entry) => _InvitationCard(
                          entry: entry,
                          working: _working,
                          onAccept:
                              () => _act(
                                () => _service.accept(entry.connectionId),
                                context.strings.socialInvitationAccepted,
                              ),
                          onDecline:
                              () => _act(
                                () => _service.declineOrCancel(
                                  entry.connectionId,
                                ),
                                context.strings.socialInvitationDeclined,
                              ),
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],
                    _Heading(context.strings.socialYourFriends),
                    if (_friends!.isEmpty)
                      _InfoCard(
                        icon: Icons.people_outline,
                        text: context.strings.socialNoFriends,
                      )
                    else
                      ..._friends!.map(
                        (entry) => Card(
                          child: ListTile(
                            leading: UserAvatar(
                              avatar: entry.avatar,
                              avatarPhotoBase64: entry.avatarPhotoBase64,
                              size: 44,
                            ),
                            title: Text(
                              entry.displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              context.strings.socialFriendSubtitle,
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap:
                                () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder:
                                        (_) => FriendDetailScreen(
                                          friend: entry,
                                          service: widget.service,
                                        ),
                                  ),
                                ),
                          ),
                        ),
                      ),
                    if (outgoing.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      _Heading(context.strings.socialOutgoing),
                      ...outgoing.map(
                        (entry) => Card(
                          child: ListTile(
                            leading: UserAvatar(
                              avatar: entry.avatar,
                              avatarPhotoBase64: entry.avatarPhotoBase64,
                              size: 40,
                            ),
                            title: Text(entry.displayName),
                            subtitle: Text(
                              context.strings.socialAwaitingResponse,
                            ),
                            trailing: TextButton(
                              onPressed:
                                  _working
                                      ? null
                                      : () => _act(
                                        () => _service.declineOrCancel(
                                          entry.connectionId,
                                        ),
                                        context
                                            .strings
                                            .socialInvitationCancelled,
                                      ),
                              child: Text(context.strings.commentsCancel),
                            ),
                          ),
                        ),
                      ),
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
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
    ),
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
          Expanded(
            child: Text(
              entry.displayName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            tooltip: context.strings.socialDecline,
            onPressed: working ? null : onDecline,
            icon: const Icon(Icons.close),
          ),
          IconButton.filled(
            tooltip: context.strings.socialAccept,
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
