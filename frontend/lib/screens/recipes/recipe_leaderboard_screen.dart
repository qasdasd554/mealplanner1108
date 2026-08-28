import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_utils.dart';
import '../../widgets/user_avatar.dart';

/// Ranking użytkowników wg liczby dodanych, ZAAKCEPTOWANYCH przez
/// administratora przepisów do wspólnego katalogu — teraz w DWÓCH
/// wariantach na osobnych zakładkach: "Ten tydzień" (cotygodniowy
/// konkurs, liczący tylko przepisy z ostatnich 7 dni — każdy zaczyna
/// "od zera" co tydzień) i "Cały czas" (oryginalny, ranking bez limitu
/// czasowego).
class RecipeLeaderboardScreen extends StatefulWidget {
  const RecipeLeaderboardScreen({super.key});

  @override
  State<RecipeLeaderboardScreen> createState() => _RecipeLeaderboardScreenState();
}

class _RecipeLeaderboardScreenState extends State<RecipeLeaderboardScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  late final TabController _tabController;

  bool _isLoadingWeekly = true;
  bool _isLoadingAllTime = true;
  String? _errorWeekly;
  String? _errorAllTime;
  List<Map<String, dynamic>> _weeklyEntries = [];
  List<Map<String, dynamic>> _allTimeEntries = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadWeekly();
    _loadAllTime();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadWeekly() async {
    setState(() {
      _isLoadingWeekly = true;
      _errorWeekly = null;
    });
    try {
      final entries = await _authService.getWeeklyRecipeLeaderboard();
      if (!mounted) return;
      setState(() {
        _weeklyEntries = entries;
        _isLoadingWeekly = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorWeekly = friendlyError(e);
        _isLoadingWeekly = false;
      });
    }
  }

  Future<void> _loadAllTime() async {
    setState(() {
      _isLoadingAllTime = true;
      _errorAllTime = null;
    });
    try {
      final entries = await _authService.getRecipeLeaderboard();
      if (!mounted) return;
      setState(() {
        _allTimeEntries = entries;
        _isLoadingAllTime = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorAllTime = friendlyError(e);
        _isLoadingAllTime = false;
      });
    }
  }

  static const List<String> _medals = ['🥇', '🥈', '🥉'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ranking autorów przepisów'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Ten tydzień'),
            Tab(text: 'Cały czas'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          RefreshIndicator(
            onRefresh: _loadWeekly,
            child: _buildBody(
              isLoading: _isLoadingWeekly,
              error: _errorWeekly,
              entries: _weeklyEntries,
              onRetry: _loadWeekly,
              emptyMessage:
                  'W tym tygodniu nikt jeszcze nie dodał\nzaakceptowanego przepisu. Bądź pierwszy!',
            ),
          ),
          RefreshIndicator(
            onRefresh: _loadAllTime,
            child: _buildBody(
              isLoading: _isLoadingAllTime,
              error: _errorAllTime,
              entries: _allTimeEntries,
              onRetry: _loadAllTime,
              emptyMessage:
                  'Jeszcze nikt nie dodał zaakceptowanego przepisu\ndo wspólnego katalogu.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody({
    required bool isLoading,
    required String? error,
    required List<Map<String, dynamic>> entries,
    required VoidCallback onRetry,
    required String emptyMessage,
  }) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
          const SizedBox(height: 12),
          Center(child: Text(error, textAlign: TextAlign.center)),
          const SizedBox(height: 12),
          Center(child: TextButton(onPressed: onRetry, child: const Text('Spróbuj ponownie'))),
        ],
      );
    }
    if (entries.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 100),
          Icon(Icons.emoji_events_outlined, size: 56, color: AppTheme.textSecondary),
          const SizedBox(height: 12),
          Center(
            child: Text(
              emptyMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final entry = entries[index];
        final name = entry['display_name'] as String;
        final count = entry['recipe_count'] as int;
        final avatar = entry['avatar'] as String?;
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
              UserAvatar(avatar: avatar, size: 32),
              const SizedBox(width: 10),
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
