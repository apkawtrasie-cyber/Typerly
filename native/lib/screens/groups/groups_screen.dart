import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/config/supabase_config.dart';
import '../../core/theme/app_theme.dart';
import '../../features/auth/auth.dart';
import '../../models/league.dart';
import '../../services/league_service.dart';
import '../../services/tournament_service.dart';
import '../../widgets/widgets.dart';
import 'qr_scanner_screen.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  List<League> _leagues = [];
  List<Map<String, dynamic>> _tournaments = [];
  Map<String, int> _memberCounts = {};
  Map<String, int> _tournamentMemberCounts = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() => _loadLeagues();

  Future<void> _loadLeagues() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    setState(() { _isLoading = true; _error = null; });
    try {
      final uid = authState.profile.id;
      final results = await Future.wait([
        LeagueService.getUserLeagues(uid),
        TournamentService.getUserTournaments(uid),
      ]);
      final leagues = results[0] as List<League>;
      final tournaments = results[1] as List<Map<String, dynamic>>;

      // Liczby członków lig
      Map<String, int> counts = {};
      if (leagues.isNotEmpty) {
        final ids = leagues.map((l) => l.id).toList();
        final resp = await SupabaseConfig.client
            .from('league_members')
            .select('league_id')
            .inFilter('league_id', ids);
        for (final row in (resp as List)) {
          final lid = row['league_id'] as String;
          counts[lid] = (counts[lid] ?? 0) + 1;
        }
      }

      // Liczby członków turniejów
      Map<String, int> tCounts = {};
      if (tournaments.isNotEmpty) {
        final ids = tournaments.map((t) => t['id'] as String).toList();
        final resp = await SupabaseConfig.client
            .from('tournament_members')
            .select('tournament_id')
            .inFilter('tournament_id', ids);
        for (final row in (resp as List)) {
          final tid = row['tournament_id'] as String;
          tCounts[tid] = (tCounts[tid] ?? 0) + 1;
        }
      }

      if (mounted) {
        setState(() {
          _leagues = leagues;
          _tournaments = tournaments;
          _memberCounts = counts;
          _tournamentMemberCounts = tCounts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  void _showJoinDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Dołącz z kodem', style: TextStyle(color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Działa dla lig i turniejów', style: TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Wpisz kod zaproszenia',
                hintStyle: TextStyle(color: AppTheme.textTertiary),
                filled: true,
                fillColor: AppTheme.surfaceColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Anuluj')),
          ElevatedButton(
            onPressed: () async {
              final code = controller.text.trim();
              if (code.isEmpty) return;
              Navigator.pop(ctx);
              final authState = context.read<AuthBloc>().state;
              if (authState is! AuthAuthenticated) return;
              try {
                // Próbuj najpierw jako liga, potem jako turniej
                final league = await LeagueService.joinLeague(code, authState.profile.id);
                if (league != null) {
                  _loadAll();
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Dołączono do ligi: ${league.name}'), backgroundColor: AppTheme.successColor),
                  );
                  return;
                }
                final tournament = await TournamentService.joinTournament(code, authState.profile.id);
                if (tournament != null) {
                  _loadAll();
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Dołączono do turnieju: ${tournament['name']}'), backgroundColor: AppTheme.successColor),
                  );
                } else {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nie znaleziono ligi ani turnieju z tym kodem'), backgroundColor: Colors.red),
                  );
                }
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Błąd: $e'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Dołącz'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Ligi i Turnieje'),
        actions: [
          IconButton(icon: const Icon(Icons.group_add_outlined), tooltip: 'Dołącz z kodem', onPressed: _showJoinDialog),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Skanuj QR
          FloatingActionButton.small(
            heroTag: 'fab_qr',
            backgroundColor: AppTheme.cardColor,
            tooltip: 'Skanuj kod QR',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const QrScannerScreen()),
            ),
            child: const Icon(Icons.qr_code_scanner, color: AppTheme.primaryColor),
          ),
          const SizedBox(height: 10),
          // Utwórz
          FloatingActionButton(
            heroTag: 'fab_create',
            backgroundColor: AppTheme.primaryColor,
            child: const Icon(Icons.add, color: Colors.black),
            onPressed: () => _showCreateMenu(),
          ),
        ],
      ),
    );
  }

  void _showCreateMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Co chcesz utworzyć?', style: TextStyle(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            _createOption(
              icon: Icons.sports_soccer,
              title: 'Liga (mecze piłkarskie)',
              subtitle: 'Typujesz wyniki prawdziwych meczów',
              onTap: () async {
                Navigator.pop(ctx);
                await Navigator.pushNamed(context, '/create-group');
                _loadAll();
              },
            ),
            const SizedBox(height: 12),
            _createOption(
              icon: Icons.emoji_events,
              title: 'Turniej własny',
              subtitle: 'Sam tworzysz drużyny, mecze i nagrodę',
              onTap: () async {
                Navigator.pop(ctx);
                await Navigator.pushNamed(context, '/create-tournament');
                _loadAll();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _createOption({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.dividerColor)),
        child: Row(
          children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: AppTheme.primaryColor)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
              Text(subtitle, style: const TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
            ])),
            const Icon(Icons.chevron_right, color: AppTheme.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off, color: AppTheme.textTertiary, size: 48),
            const SizedBox(height: 16),
            Text('Błąd ładowania lig', style: TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            TextButton(onPressed: _loadLeagues, child: const Text('Spróbuj ponownie')),
          ],
        ),
      );
    }
    if (_leagues.isEmpty && _tournaments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.group_outlined, color: AppTheme.textTertiary, size: 64),
            const SizedBox(height: 16),
            const Text('Brak lig i turniejów', style: TextStyle(color: AppTheme.textSecondary, fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text('Utwórz własną ligę lub turniej\nalbo dołącz z kodem zaproszenia', style: TextStyle(color: AppTheme.textTertiary, fontSize: 13), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _showJoinDialog,
              icon: const Icon(Icons.group_add),
              label: const Text('Dołącz z kodem'),
              style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primaryColor, side: const BorderSide(color: AppTheme.primaryColor)),
            ),
          ],
        ),
      );
    }

    // Łączna lista: najpierw ligi, potem turnieje
    final totalItems = _leagues.length + _tournaments.length + (_tournaments.isNotEmpty ? 1 : 0) + (_leagues.isNotEmpty ? 1 : 0);

    return RefreshIndicator(
      onRefresh: _loadAll,
      color: AppTheme.primaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
        itemCount: totalItems,
        itemBuilder: (context, index) {
          // Sekcja liga
          if (_leagues.isNotEmpty) {
            if (index == 0) return _sectionHeader('LIGI', Icons.sports_soccer);
            if (index <= _leagues.length) {
              final li = index - 1;
              return LeagueCard(
                league: _leagues[li],
                memberCount: _memberCounts[_leagues[li].id] ?? 0,
                userRank: li + 1,
                userPoints: 0,
                onTap: () => Navigator.pushNamed(context, '/league-detail', arguments: _leagues[li]),
              );
            }
            // Shift dla sekcji turnieju
            final shifted = index - _leagues.length - 1;
            if (_tournaments.isNotEmpty) {
              if (shifted == 0) return _sectionHeader('TURNIEJE WŁASNE', Icons.emoji_events);
              final ti = shifted - 1;
              if (ti < _tournaments.length) return _tournamentCard(_tournaments[ti]);
            }
          } else {
            // Tylko turnieje
            if (index == 0) return _sectionHeader('TURNIEJE WŁASNE', Icons.emoji_events);
            final ti = index - 1;
            if (ti < _tournaments.length) return _tournamentCard(_tournaments[ti]);
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 16),
          const SizedBox(width: 6),
          Text(title, style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
        ],
      ),
    );
  }

  Widget _tournamentCard(Map<String, dynamic> t) {
    final memberCount = _tournamentMemberCounts[t['id'] as String] ?? 0;
    final hasPrize = t['prize_description'] != null;
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/tournament-detail', arguments: t),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.dividerColor),
        ),
        child: Row(
          children: [
            Container(width: 48, height: 48,
              decoration: BoxDecoration(color: const Color(0xFFFFD700).withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.emoji_events, color: Color(0xFFFFD700), size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t['name'] as String, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.people, size: 13, color: AppTheme.textTertiary),
                  const SizedBox(width: 4),
                  Text('$memberCount członków', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  if (hasPrize) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.card_giftcard, size: 13, color: Color(0xFFFFD700)),
                    const SizedBox(width: 2),
                    const Text('Nagroda', style: TextStyle(color: Color(0xFFFFD700), fontSize: 12)),
                  ],
                ]),
              ],
            )),
            const Icon(Icons.chevron_right, color: AppTheme.textTertiary),
          ],
        ),
      ),
    );
  }
}
