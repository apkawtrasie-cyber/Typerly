import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/config/supabase_config.dart';
import '../../core/theme/app_theme.dart';
import '../../features/auth/auth.dart';
import '../../models/league.dart';
import '../../services/league_service.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<League> _leagues = [];
  League? _selectedLeague;
  List<Map<String, dynamic>> _ranking = [];
  bool _isLoadingLeagues = true;
  bool _isLoadingRanking = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      _currentUserId = authState.profile.id;
    }
    _loadLeagues();
  }

  Future<void> _loadLeagues() async {
    if (_currentUserId == null) return;
    setState(() => _isLoadingLeagues = true);
    try {
      final leagues = await LeagueService.getUserLeagues(_currentUserId!);
      if (mounted) {
        setState(() {
          _leagues = leagues;
          _isLoadingLeagues = false;
          if (leagues.isNotEmpty) {
            _selectedLeague = leagues.first;
            _loadRanking(leagues.first);
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingLeagues = false);
    }
  }

  Future<void> _loadRanking(League league) async {
    setState(() => _isLoadingRanking = true);
    try {
      // Get all members with their total points from predictions
      final membersResp = await SupabaseConfig.client
          .from('league_members')
          .select('user_id, profiles(username, avatar_url)')
          .eq('league_id', league.id);

      final members = List<Map<String, dynamic>>.from(membersResp as List);

      // Pobierz punkty wszystkich członków w tej lidze jednym zapytaniem
      final memberIds = members.map((m) => m['user_id'] as String).toList();
      final predictionsResp = memberIds.isEmpty
          ? <dynamic>[]
          : await SupabaseConfig.client
              .from('predictions')
              .select('user_id, points_earned')
              .eq('league_id', league.id)
              .eq('is_calculated', true)
              .inFilter('user_id', memberIds);

      final pointsMap = <String, int>{};
      final countMap = <String, int>{};
      for (final p in (predictionsResp as List)) {
        final uid = p['user_id'] as String;
        pointsMap[uid] = (pointsMap[uid] ?? 0) + ((p['points_earned'] as int?) ?? 0);
        countMap[uid] = (countMap[uid] ?? 0) + 1;
      }

      final rankingData = members.map((member) {
        final userId = member['user_id'] as String;
        final profile = member['profiles'] as Map<String, dynamic>?;
        return {
          'user_id': userId,
          'username': profile?['username'] ?? 'Użytkownik',
          'avatar_url': profile?['avatar_url'],
          'total_points': pointsMap[userId] ?? 0,
          'typed_count': countMap[userId] ?? 0,
        };
      }).toList();

      rankingData.sort((a, b) => (b['total_points'] as int).compareTo(a['total_points'] as int));

      if (mounted) {
        setState(() {
          _ranking = rankingData;
          _isLoadingRanking = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingRanking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        title: const Text('Ranking', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
      ),
      body: _isLoadingLeagues
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : _leagues.isEmpty
              ? _buildNoLeagues()
              : Column(
                  children: [
                    if (_leagues.length > 1) _buildLeaguePicker(),
                    Expanded(child: _buildRanking()),
                  ],
                ),
    );
  }

  Widget _buildNoLeagues() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.emoji_events_outlined, color: AppTheme.textTertiary, size: 64),
          const SizedBox(height: 16),
          const Text('Brak lig', style: TextStyle(color: AppTheme.textSecondary, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Utwórz lub dołącz do ligi\nżeby zobaczyć ranking', style: TextStyle(color: AppTheme.textTertiary, fontSize: 13), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pushReplacementNamed(context, '/main'),
            child: const Text('Idź do Leagues'),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaguePicker() {
    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _leagues.length,
        itemBuilder: (context, i) {
          final league = _leagues[i];
          final isSelected = _selectedLeague?.id == league.id;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedLeague = league);
              _loadRanking(league);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryColor : AppTheme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isSelected ? AppTheme.primaryColor : AppTheme.dividerColor),
              ),
              child: Text(
                league.name,
                style: TextStyle(
                  color: isSelected ? AppTheme.backgroundColor : AppTheme.textSecondary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRanking() {
    if (_isLoadingRanking) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
    }
    if (_ranking.isEmpty) {
      return const Center(
        child: Text('Brak danych rankingu', style: TextStyle(color: AppTheme.textSecondary)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: _ranking.length,
      itemBuilder: (context, i) {
        final entry = _ranking[i];
        final isMe = entry['user_id'] == _currentUserId;
        final rank = i + 1;
        final points = entry['total_points'] as int;
        final username = entry['username'] as String;
        final typedCount = entry['typed_count'] as int;

        Color rankColor = AppTheme.textTertiary;
        if (rank == 1) rankColor = const Color(0xFFFFD700); // złoty
        if (rank == 2) rankColor = const Color(0xFFC0C0C0); // srebrny
        if (rank == 3) rankColor = const Color(0xFFCD7F32); // brązowy

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isMe ? AppTheme.primaryColor.withOpacity(0.08) : AppTheme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isMe ? AppTheme.primaryColor.withOpacity(0.5) : AppTheme.dividerColor,
              width: isMe ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              // Rank
              SizedBox(
                width: 36,
                child: rank <= 3
                    ? Icon(Icons.emoji_events, color: rankColor, size: 28)
                    : Text('#$rank', style: TextStyle(color: rankColor, fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 12),
              // Avatar
              CircleAvatar(
                radius: 22,
                backgroundColor: AppTheme.surfaceColor,
                child: Text(username[0].toUpperCase(), style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w700, fontSize: 16)),
              ),
              const SizedBox(width: 12),
              // Name + stats
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(username, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                        if (isMe) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                            child: const Text('Ty', style: TextStyle(color: AppTheme.primaryColor, fontSize: 10, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('$typedCount ${_typedLabel(typedCount)}', style: const TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
                  ],
                ),
              ),
              // Points
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('$points', style: TextStyle(color: rank == 1 ? AppTheme.primaryColor : AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w800)),
                  const Text('pkt', style: TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _typedLabel(int count) {
    if (count == 1) return 'typ';
    if (count >= 2 && count <= 4) return 'typy';
    return 'typów';
  }
}
