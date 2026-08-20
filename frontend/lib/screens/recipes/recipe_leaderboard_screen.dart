import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_utils.dart';

/// Ranking użytkowników wg liczby dodanych, ZAAKCEPTOWANYCH przez
/// administratora przepisów do wspólnego katalogu. Backend istniał od
/// dawna (GET /users/leaderboard/recipes) — ten ekran to brakujący
/// interfejs, który go wreszcie wykorzystuje.
class RecipeLeaderboardScreen extends StatefulWidget {
  const RecipeLeaderboardScreen({super.key});

  @override
  State<RecipeLeaderboardScreen> createState() => _RecipeLeaderboardScreenState();
}

class _RecipeLeaderboardScreenState extends State<RecipeLeaderboardScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _entries = [];

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
      final entries = await _authService.getRecipeLeaderboard();
      if (!mounted) return;
      setState(() {
        _entries = entries;
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

  static const List<String> _medals = ['🥇', '🥈', '🥉'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ranking autorów przepisów')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
          const SizedBox(height: 12),
          Center(child: Text(_error!, textAlign: TextAlign.center)),
          const SizedBox(height: 12),
          Center(child: TextButton(onPressed: _load, child: const Text('Spróbuj ponownie'))),
        ],
      );
    }
    if (_entries.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 100),
          Icon(Icons.emoji_events_outlined, size: 56, color: AppTheme.textSecondary),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Jeszcze nikt nie dodał zaakceptowanego przepisu\ndo wspólnego katalogu.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final entry = _entries[index];
        final name = entry['display_name'] as String;
        final count = entry['recipe_count'] as int;
        final medal = index < 3 ? _medals[index] : null;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(14),
            border: index == 0 ? Border.all(color: const Color(0xFFE0A62E), width: 1.5) : null,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                child: Text(
                  medal ?? '${index + 1}.',
                  style: TextStyle(fontSize: medal != null ? 22 : 16, color: AppTheme.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              ),
              Text(
                '$count ${count == 1 ? "przepis" : (count < 5 ? "przepisy" : "przepisów")}',
                style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ).animate().fadeIn(delay: (index * 40).ms).slideX(begin: 0.03, end: 0);
      },
    );
  }
}
