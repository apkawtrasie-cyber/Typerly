import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/config/supabase_config.dart';
import '../../core/theme/app_theme.dart';
import '../../features/auth/auth.dart';
import '../../models/league.dart';
import '../../models/match.dart';

class LeagueDetailScreen extends StatefulWidget {
  const LeagueDetailScreen({super.key});

  @override
  State<LeagueDetailScreen> createState() => _LeagueDetailScreenState();
}

class _LeagueDetailScreenState extends State<LeagueDetailScreen> {
  late League _league;
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _matches = [];
  // userId → punkty zdobyte w tej lidze
  Map<String, int> _memberPoints = {};
  bool _isLoading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _league = ModalRoute.of(context)!.settings.arguments as League;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final membersResp = await SupabaseConfig.client
          .from('league_members')
          .select('*, profiles(username, avatar_url)')
          .eq('league_id', _league.id);

      final matchesResp = await SupabaseConfig.client
          .from('matches')
          .select()
          .gte('match_time', DateTime.now().subtract(const Duration(hours: 2)).toIso8601String())
          .order('match_time', ascending: true)
          .limit(30);

      // Punkty per użytkownik w tej lidze
      final pointsResp = await SupabaseConfig.client
          .from('predictions')
          .select('user_id, points_earned')
          .eq('league_id', _league.id)
          .eq('is_calculated', true);

      final pointsMap = <String, int>{};
      for (final row in (pointsResp as List)) {
        final uid = row['user_id'] as String;
        pointsMap[uid] = (pointsMap[uid] ?? 0) + ((row['points_earned'] as int?) ?? 0);
      }

      final membersList = List<Map<String, dynamic>>.from(membersResp as List);
      // Sortuj członków wg punktów malejąco
      membersList.sort((a, b) {
        final ap = pointsMap[a['user_id'] as String] ?? 0;
        final bp = pointsMap[b['user_id'] as String] ?? 0;
        return bp.compareTo(ap);
      });

      if (mounted) {
        setState(() {
          _members = membersList;
          _matches = List<Map<String, dynamic>>.from(matchesResp as List);
          _memberPoints = pointsMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _copyInviteCode() {
    Clipboard.setData(ClipboardData(text: _league.inviteCode));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Kod skopiowany: ${_league.inviteCode}'),
        backgroundColor: AppTheme.successColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        title: Text(_league.name, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppTheme.primaryColor,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildInviteCard(),
                  const SizedBox(height: 20),
                  _buildMembersSection(),
                  const SizedBox(height: 20),
                  _buildMatchesSection(),
                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }

  Widget _buildInviteCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryColor, width: 1.5),
      ),
      child: Column(
        children: [
          const Text(
            'KOD ZAPROSZENIA',
            style: TextStyle(color: AppTheme.primaryColor, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.5),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _league.inviteCode,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 6),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _copyInviteCode,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.copy, color: AppTheme.primaryColor, size: 22),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Wyślij ten kod znajomym — wpisują go w aplikacji w zakładce Leagues → "Dołącz z kodem"',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMembersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('CZŁONKOWIE', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('${_members.length}', style: const TextStyle(color: AppTheme.primaryColor, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_members.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.dividerColor)),
            child: const Center(child: Text('Brak członków — wyślij kod zaproszenia', style: TextStyle(color: AppTheme.textSecondary))),
          )
        else
          ..._members.asMap().entries.map((entry) {
            final i = entry.key;
            final m = entry.value;
            final profile = m['profiles'] as Map<String, dynamic>?;
            final username = profile?['username'] as String? ?? 'Użytkownik';
            final currentUserId = (context.read<AuthBloc>().state is AuthAuthenticated)
                ? (context.read<AuthBloc>().state as AuthAuthenticated).profile.id
                : null;
            final isMe = m['user_id'] == currentUserId;
            final isAdmin = m['user_id'] == _league.adminId;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isMe ? AppTheme.primaryColor.withOpacity(0.08) : AppTheme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isMe ? AppTheme.primaryColor.withOpacity(0.4) : AppTheme.dividerColor),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        '#${i + 1}',
                        style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppTheme.surfaceColor,
                    child: Text(username[0].toUpperCase(), style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      children: [
                        Text(username, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                        if (isMe) ...[
                          const SizedBox(width: 6),
                          _badge('Ty', AppTheme.primaryColor),
                        ],
                        if (isAdmin) ...[
                          const SizedBox(width: 6),
                          _badge('Admin', AppTheme.secondaryColor),
                        ],
                      ],
                    ),
                  ),
                  Text(
                    '${_memberPoints[m['user_id']] ?? 0} pkt',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }

  Widget _buildMatchesSection() {
    final upcomingMatches = _matches.where((m) {
      final status = m['status'] ?? 'NS';
      return status == 'NS' || status == 'LIVE';
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('MECZE DO TYPOWANIA', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        if (upcomingMatches.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.dividerColor)),
            child: const Center(child: Text('Brak nadchodzących meczów', style: TextStyle(color: AppTheme.textSecondary))),
          )
        else
          ...upcomingMatches.map((m) {
            final safeMatch = Map<String, dynamic>.from(m);
            safeMatch['status'] = safeMatch['status'] ?? 'NS';
            safeMatch['is_custom'] = (safeMatch['is_custom'] as bool?) ?? false;
            final match = Match.fromJson(safeMatch);
            // Przekaż leagueId żeby typ zapisał się w kontekście tej ligi
            final matchWithLeague = match.copyWith(leagueId: _league.id);

            return GestureDetector(
              onTap: () => Navigator.pushNamed(
                context,
                '/match-detail',
                arguments: matchWithLeague,
              ),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.dividerColor),
                ),
                child: Row(
                  children: [
                    // Logo gospodarzy
                    _teamLogo(match.homeTeamLogoUrl),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(match.homeTeamName, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13), textAlign: TextAlign.center),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: BorderRadius.circular(8)),
                      child: const Text('VS', style: TextStyle(color: AppTheme.textTertiary, fontWeight: FontWeight.w700, fontSize: 12)),
                    ),
                    Expanded(
                      child: Text(match.awayTeamName, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13), textAlign: TextAlign.center),
                    ),
                    const SizedBox(width: 8),
                    // Logo gości
                    _teamLogo(match.awayTeamLogoUrl),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right, color: AppTheme.textTertiary, size: 18),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _teamLogo(String? url) {
    if (url == null || url.isEmpty) {
      return const SizedBox(width: 28, height: 28);
    }
    if (url.toLowerCase().endsWith('.svg')) {
      return SvgPicture.network(
        url,
        width: 28,
        height: 28,
        fit: BoxFit.contain,
        placeholderBuilder: (_) => const SizedBox(width: 28, height: 28),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      width: 28,
      height: 28,
      fit: BoxFit.contain,
      errorWidget: (_, __, ___) => const SizedBox(width: 28, height: 28),
    );
  }
}
