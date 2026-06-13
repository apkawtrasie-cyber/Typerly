import 'dart:io';
import 'dart:ui' show lerpDouble;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import '../../core/config/supabase_config.dart';
import '../../core/theme/app_theme.dart';
import '../../features/auth/auth.dart';
import '../../services/scoring_service.dart';
import '../../services/tournament_service.dart';
import 'setup_group_phase_screen.dart';
import '../../widgets/match_winner_overlay.dart';
import 'package:uuid/uuid.dart';
import '../../widgets/qr_invite_dialog.dart';

class TournamentDetailScreen extends StatefulWidget {
  const TournamentDetailScreen({super.key});

  @override
  State<TournamentDetailScreen> createState() => _TournamentDetailScreenState();
}

class _TournamentDetailScreenState extends State<TournamentDetailScreen>
    with SingleTickerProviderStateMixin {
  late Map<String, dynamic> _tournament;
  List<Map<String, dynamic>> _teams = [];
  List<Map<String, dynamic>> _matches = [];
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _groupsWithTeams = [];
  Map<String, int> _memberPoints = {};
  bool _isLoading = true;
  bool _initialized = false;
  late TabController _tabController;
  String? _currentUserId;
  bool get _isAdmin => _tournament['admin_id'] == _currentUserId;

  bool get _hasGroupPhase => _groupsWithTeams.isNotEmpty;
  bool get _hasKnockout => _matches.any((m) => m['match_phase'] == 'knockout');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _tournament = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final auth = context.read<AuthBloc>().state;
    if (auth is AuthAuthenticated) _currentUserId = auth.profile.id;
    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _isLoading = true);
    final tid = _tournament['id'] as String;

    // Każde zapytanie osobno — błąd jednego nie blokuje pozostałych
    List<Map<String, dynamic>> teams = [];
    List<Map<String, dynamic>> matches = [];
    List<Map<String, dynamic>> members = [];
    List<Map<String, dynamic>> groups = [];
    Map<String, int> pts = {};

    try { teams = await TournamentService.getTeams(tid); } catch (_) {}
    try { matches = await TournamentService.getMatches(tid); } catch (_) {}
    try { members = await TournamentService.getMembers(tid); } catch (_) {}
    try { groups = await TournamentService.getGroupsWithTeams(tid); } catch (_) {}

    try {
      final predsResp = await SupabaseConfig.client
          .from('tournament_predictions')
          .select('user_id, points_earned')
          .eq('tournament_id', tid)
          .eq('is_calculated', true);
      for (final p in predsResp as List) {
        final uid = p['user_id'] as String;
        pts[uid] = (pts[uid] ?? 0) + ((p['points_earned'] as int?) ?? 0);
      }
    } catch (_) {}

    members.sort((a, b) {
      final ap = pts[a['user_id'] as String] ?? 0;
      final bp = pts[b['user_id'] as String] ?? 0;
      return bp.compareTo(ap);
    });

    final hasGroups = groups.isNotEmpty;
    final hasKnockout = matches.any((m) => m['match_phase'] == 'knockout');
    final newTabCount = 3 + (hasGroups ? 1 : 0) + (hasKnockout ? 1 : 0);

    if (mounted) {
      setState(() {
        _teams = teams;
        _matches = matches;
        _members = members;
        _groupsWithTeams = groups;
        _memberPoints = pts;
        _isLoading = false;
      });
      if (_tabController.length != newTabCount) {
        final current = _tabController.index.clamp(0, newTabCount - 1);
        _tabController.dispose();
        _tabController = TabController(length: newTabCount, vsync: this, initialIndex: current);
        setState(() {});
      }
    }
  }

  void _snack(String msg, {Color? color, Duration duration = const Duration(seconds: 2)}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color ?? AppTheme.successColor,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      duration: duration,
    ));
  }

  void _copyInviteCode() {
    Clipboard.setData(ClipboardData(text: _tournament['invite_code'] as String));
    _snack('Kod skopiowany: ${_tournament['invite_code']}');
  }

  Future<void> _showQrCode() async {
    // Jeśli turniej nie ma kodu — wygeneruj i zapisz
    String? code = _tournament['invite_code'] as String?;
    if (code == null || code.isEmpty) {
      code = const Uuid().v4().replaceAll('-', '').substring(0, 8).toUpperCase();
      try {
        await SupabaseConfig.client
            .from('custom_tournaments')
            .update({'invite_code': code})
            .eq('id', _tournament['id'] as String);
        setState(() => _tournament['invite_code'] = code);
      } catch (e) {
        _snack('Błąd generowania kodu: $e', color: AppTheme.errorColor);
        return;
      }
    }
    if (!mounted) return;
    showQrInviteDialog(
      context: context,
      code: code,
      name: _tournament['name'] as String? ?? 'Turniej',
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Tab> get _tabs {
    return [
      const Tab(text: 'MECZE'),
      if (_hasGroupPhase) const Tab(text: 'GRUPY'),
      if (_hasKnockout) const Tab(text: 'DRABINKA'),
      const Tab(text: 'DRUŻYNY'),
      const Tab(text: 'RANKING'),
    ];
  }

  List<Widget> get _tabViews {
    return [
      _buildMatchesTab(),
      if (_hasGroupPhase) _buildGroupsTab(),
      if (_hasKnockout) _buildBracketTab(),
      _buildTeamsTab(),
      _buildRankingTab(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        title: Text(_tournament['name'] as String,
            style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
        actions: [
          if (_isAdmin)
            PopupMenuButton<String>(
              color: AppTheme.cardColor,
              onSelected: (v) async {
                if (v == 'show_qr') await _showQrCode();
                if (v == 'add_team') await _showAddTeamDialog();
                if (v == 'add_match') await _showAddMatchDialog();
                if (v == 'setup_groups') await _openGroupPhaseSetup();
                if (v == 'gen_knockout') await _generateKnockout();
                if (v == 'gen_direct_knockout') await _generateDirectKnockout();
                if (v == 'delete_tournament') await _deleteTournament();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'show_qr', child: Row(children: [Icon(Icons.qr_code, color: AppTheme.primaryColor, size: 18), SizedBox(width: 8), Text('Kod QR zaproszenia', style: TextStyle(color: AppTheme.primaryColor))])),
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'add_team', child: Text('+ Dodaj drużynę', style: TextStyle(color: AppTheme.textPrimary))),
                const PopupMenuItem(value: 'add_match', child: Text('+ Dodaj mecz ręcznie', style: TextStyle(color: AppTheme.textPrimary))),
                const PopupMenuDivider(),
                if (_teams.length >= 2 && !_hasGroupPhase)
                  const PopupMenuItem(value: 'gen_direct_knockout', child: Text('🏆 Generuj puchar', style: TextStyle(color: AppTheme.primaryColor))),
                if (_teams.length >= 4)
                  const PopupMenuItem(value: 'setup_groups', child: Text('⚽ Ustaw fazę grupową', style: TextStyle(color: AppTheme.primaryColor))),
                if (_hasGroupPhase)
                  const PopupMenuItem(value: 'gen_knockout', child: Text('🏆 Generuj drabinkę', style: TextStyle(color: AppTheme.primaryColor))),
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'delete_tournament', child: Text('Usuń turniej', style: TextStyle(color: Colors.redAccent))),
              ],
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textTertiary,
          indicatorColor: AppTheme.primaryColor,
          isScrollable: _tabs.length > 3,
          tabAlignment: _tabs.length > 3 ? TabAlignment.start : TabAlignment.fill,
          tabs: _tabs,
        ),
      ),
      body: SafeArea(
        top: false,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
            : RefreshIndicator(
                onRefresh: _loadData,
                color: AppTheme.primaryColor,
                child: Column(
                  children: [
                    _buildInviteStrip(),
                    if (_tournament['prize_description'] != null) _buildPrizeStrip(),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: _tabViews,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Future<void> _openGroupPhaseSetup() async {
    if (_teams.length < 4) {
      _snack('Dodaj co najmniej 4 drużyny przed ustawieniem fazy grupowej', color: Colors.orange);
      return;
    }
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SetupGroupPhaseScreen(
          tournament: _tournament,
          teams: _teams,
        ),
      ),
    );
    if (result == true) _loadData();
  }

  Future<void> _generateKnockout() async {
    if (!_hasGroupPhase) return;

    // Sprawdź czy wszystkie mecze grupowe są zakończone
    final groupMatches = _matches.where((m) => m['match_phase'] == 'group').toList();
    final unfinished = groupMatches.where((m) => m['status'] != 'FT').length;

    if (unfinished > 0) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.cardColor,
          title: const Text('Niezakończone mecze', style: TextStyle(color: AppTheme.textPrimary)),
          content: Text('$unfinished meczów grupowych nie ma jeszcze wyników. Czy wygenerować drabinkę mimo to?',
              style: const TextStyle(color: AppTheme.textSecondary)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Anuluj')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
              child: const Text('Generuj', style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    // Dialog: ile drużyn awansuje z grupy
    int teamsPerGroup = 2;
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppTheme.cardColor,
          title: const Text('Awans z grupy', style: TextStyle(color: AppTheme.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Ile drużyn awansuje z każdej grupy?', style: TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: teamsPerGroup > 1 ? () => setS(() => teamsPerGroup--) : null,
                    icon: const Icon(Icons.remove_circle_outline, color: AppTheme.primaryColor),
                  ),
                  Text('$teamsPerGroup', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 28, fontWeight: FontWeight.w800)),
                  IconButton(
                    onPressed: () => setS(() => teamsPerGroup++),
                    icon: const Icon(Icons.add_circle_outline, color: AppTheme.primaryColor),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Anuluj')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, teamsPerGroup),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
              child: const Text('Generuj drabinkę', style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;

    try {
      await TournamentService.generateKnockout(
        tournamentId: _tournament['id'] as String,
        teamsPerGroup: result,
        groupsWithTeams: _groupsWithTeams,
        allMatches: _matches,
      );
      _loadData();
    } catch (e) {
      _snack('Błąd: $e', color: AppTheme.errorColor);
    }
  }

  Widget _buildInviteStrip() {
    final code = _tournament['invite_code'] as String? ?? '';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.vpn_key_outlined, color: AppTheme.primaryColor, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: _copyInviteCode,
              child: Row(
                children: [
                  Text(
                    'KOD: $code',
                    style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 3),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.copy, color: AppTheme.primaryColor, size: 14),
                ],
              ),
            ),
          ),
          // Przycisk QR
          GestureDetector(
            onTap: () => showQrInviteDialog(
              context: context,
              code: code,
              name: _tournament['name'] as String? ?? 'Turniej',
            ),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.qr_code, color: AppTheme.primaryColor, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrizeStrip() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD700).withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.emoji_events, color: Color(0xFFFFD700), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _tournament['prize_description'] as String,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // Indeks zakładki DRUŻYNY (zawsze przedostatnia)
  int get _teamsTabIndex => _tabController.length - 2;

  void _goToTeamsTab() {
    _tabController.animateTo(_teamsTabIndex);
  }

  // ── KREATOR FORMATU ROZGRYWEK ────────────────────────────────────────────

  Widget _buildFormatPicker() {
    final canGroups = _teams.length >= 4;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      children: [
        const Text('Wybierz format rozgrywek', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text('Masz ${_teams.length} drużyn. Wybierz jak chcesz rozegrać turniej.', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        const SizedBox(height: 20),

        // Mecze towarzyskie
        _formatCard(
          icon: '🤝',
          title: 'Mecze towarzyskie',
          subtitle: 'Dodawaj mecze ręcznie jeden po jednym. Dowolna liczba drużyn. Ty ustalasz kto z kim gra.',
          badge: null,
          onTap: _showAddMatchDialog,
        ),
        const SizedBox(height: 12),

        // Puchar / drabinka
        _formatCard(
          icon: '🏆',
          title: 'Puchar / Play-offy',
          subtitle: 'Drabinka eliminacyjna — przegrany odpada. Jak FA Cup, Puchar Polski. Zwycięzca meczu przechodzi dalej.',
          badge: '${_teams.length} drużyn → ${_bracketRounds(_teams.length)} rund',
          onTap: _generateDirectKnockout,
        ),
        const SizedBox(height: 12),

        // Faza grupowa + drabinka
        _formatCard(
          icon: '⚽',
          title: 'Faza grupowa + Play-offy',
          subtitle: 'Jak UEFA, MŚ — najpierw grupy (każdy z każdym), potem najlepsi awansują do drabinki. Minimum 4 drużyny.',
          badge: canGroups ? 'Dostępne (${_teams.length} drużyn)' : 'Wymaga min. 4 drużyn',
          badgeColor: canGroups ? AppTheme.primaryColor : Colors.orange,
          onTap: canGroups ? _openGroupPhaseSetup : () {
            _snack('Dodaj co najmniej 4 drużyny dla fazy grupowej', color: Colors.orange);
          },
        ),
        const SizedBox(height: 24),

        // Dodaj drużynę jeśli mało
        if (_teams.length < 4)
          OutlinedButton.icon(
            onPressed: () async {
              _goToTeamsTab();
              await Future.delayed(const Duration(milliseconds: 300));
              _showAddTeamDialog();
            },
            icon: const Icon(Icons.add, size: 18),
            label: Text('Dodaj więcej drużyn (masz ${_teams.length})'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
              side: const BorderSide(color: AppTheme.primaryColor),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
      ],
    );
  }

  int _bracketRounds(int n) {
    var slots = 1;
    while (slots < n) slots *= 2;
    var rounds = 0;
    var r = slots ~/ 2;
    while (r >= 1) { rounds++; r ~/= 2; }
    return rounds;
  }

  Widget _formatCard({
    required String icon,
    required String title,
    required String subtitle,
    String? badge,
    Color? badgeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.dividerColor),
        ),
        child: Row(
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(child: Text(icon, style: const TextStyle(fontSize: 26))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: (badgeColor ?? AppTheme.primaryColor).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(badge, style: TextStyle(color: badgeColor ?? AppTheme.primaryColor, fontSize: 10, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12), maxLines: 3),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: AppTheme.textTertiary, size: 20),
          ],
        ),
      ),
    );
  }

  // ── ZAKŁADKA MECZE ───────────────────────────────────────────────────────

  Widget _buildMatchesTab() {
    if (_matches.isEmpty) {
      // Brak drużyn — pokieruj admina żeby najpierw dodał drużyny
      if (_isAdmin && _teams.length < 2) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.group_add_outlined, color: AppTheme.textTertiary, size: 56),
                const SizedBox(height: 16),
                const Text('Najpierw dodaj drużyny', style: TextStyle(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  _teams.isEmpty
                      ? 'Dodaj co najmniej 2 drużyny zanim dodasz mecze lub wygenerujesz turniej.'
                      : 'Masz tylko 1 drużynę. Dodaj jeszcze co najmniej jedną.',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () async {
                    _goToTeamsTab();
                    await Future.delayed(const Duration(milliseconds: 300));
                    _showAddTeamDialog();
                  },
                  icon: const Icon(Icons.add, color: Colors.black),
                  label: const Text('Dodaj drużynę', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
                ),
              ],
            ),
          ),
        );
      }

      // Admin z 2+ drużynami — pokaż kreator formatu rozgrywek
      if (_isAdmin) {
        return _buildFormatPicker();
      }

      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sports_soccer_outlined, color: AppTheme.textTertiary, size: 48),
            SizedBox(height: 12),
            Text('Brak meczów', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
          ],
        ),
      );
    }

    // Knockout: Final (round=1) first; group matches by time
    final sorted = [..._matches];
    sorted.sort((a, b) {
      final aKO = a['match_phase'] == 'knockout';
      final bKO = b['match_phase'] == 'knockout';
      if (aKO && bKO) {
        return (a['knockout_round'] as int? ?? 0)
            .compareTo(b['knockout_round'] as int? ?? 0);
      }
      if (aKO != bKO) return aKO ? -1 : 1; // knockout first
      return (a['match_time'] as String? ?? '')
          .compareTo(b['match_time'] as String? ?? '');
    });

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: sorted.length,
      itemBuilder: (context, i) => _buildMatchCard(sorted[i]),
    );
  }

  Widget _buildMatchCard(Map<String, dynamic> m) {
    final status = m['status'] as String? ?? 'NS';
    final isFinished = status == 'FT';
    final roundName = m['round_name'] as String?;
    final matchTime = DateTime.tryParse(m['match_time'] as String? ?? '')?.toLocal();
    final homeLogo = m['home_team_logo'] as String?;
    final awayLogo = m['away_team_logo'] as String?;

    return GestureDetector(
      onTap: () => _showMatchPredictDialog(m),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: status == 'LIVE' ? AppTheme.primaryColor : AppTheme.dividerColor),
        ),
        child: Column(
          children: [
            if (roundName != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                ),
                child: Text(roundName, style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _teamLogoSmall(homeLogo),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(m['home_team_name'] as String, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13), textAlign: TextAlign.center),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isFinished ? AppTheme.surfaceColor : AppTheme.backgroundColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: status == 'LIVE' ? AppTheme.primaryColor : AppTheme.dividerColor),
                    ),
                    child: isFinished
                        ? Text('${m['home_score']}:${m['away_score']}',
                            style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 16))
                        : status == 'LIVE'
                            ? Text('LIVE', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w800, fontSize: 12))
                            : Text(
                                matchTime != null ? DateFormat('dd.MM HH:mm').format(matchTime) : 'VS',
                                style: const TextStyle(color: AppTheme.textTertiary, fontWeight: FontWeight.w600, fontSize: 11),
                              ),
                  ),
                  Expanded(
                    child: Text(m['away_team_name'] as String, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13), textAlign: TextAlign.center),
                  ),
                  const SizedBox(width: 8),
                  _teamLogoSmall(awayLogo),
                ],
              ),
            ),
            if (_isAdmin && !isFinished)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: GestureDetector(
                  onTap: () => _showEnterResultDialog(m),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.primaryColor.withOpacity(0.4)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_outlined, color: AppTheme.primaryColor, size: 14),
                        SizedBox(width: 4),
                        Text('Wpisz wynik', style: TextStyle(color: AppTheme.primaryColor, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── ZAKŁADKA DRUŻYNY ─────────────────────────────────────────────────────

  Widget _buildTeamsTab() {
    if (_teams.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.group_outlined, color: AppTheme.textTertiary, size: 48),
            const SizedBox(height: 12),
            const Text('Brak drużyn', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
            if (_isAdmin) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _showAddTeamDialog,
                icon: const Icon(Icons.add, color: Colors.black),
                label: const Text('Dodaj drużynę', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _teams.length + (_isAdmin ? 1 : 0),
      itemBuilder: (context, i) {
        if (_isAdmin && i == _teams.length) {
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton.icon(
              onPressed: _showAddTeamDialog,
              icon: const Icon(Icons.add),
              label: const Text('Dodaj drużynę'),
              style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primaryColor, side: const BorderSide(color: AppTheme.primaryColor)),
            ),
          );
        }
        final t = _teams[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.dividerColor),
          ),
          child: Row(
            children: [
              _teamLogoMedium(t['logo_url'] as String?),
              const SizedBox(width: 14),
              Expanded(
                child: Text(t['name'] as String, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
              ),
              if (_isAdmin)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppTheme.errorColor, size: 20),
                  onPressed: () => _deleteTeam(t['id'] as String, t['name'] as String),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Usuń drużynę',
                ),
            ],
          ),
        );
      },
    );
  }

  // ── ZAKŁADKA RANKING ─────────────────────────────────────────────────────

  Widget _buildRankingTab() {
    if (_members.isEmpty) {
      return const Center(child: Text('Brak członków', style: TextStyle(color: AppTheme.textSecondary)));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _members.length,
      itemBuilder: (context, i) {
        final m = _members[i];
        final profile = m['profiles'] as Map<String, dynamic>?;
        final username = profile?['username'] as String? ?? 'Użytkownik';
        final pts = _memberPoints[m['user_id'] as String] ?? 0;
        final isMe = m['user_id'] == _currentUserId;
        final isAdmin = m['user_id'] == _tournament['admin_id'];
        final rank = i + 1;

        Color rankColor = AppTheme.textTertiary;
        if (rank == 1) rankColor = const Color(0xFFFFD700);
        if (rank == 2) rankColor = const Color(0xFFC0C0C0);
        if (rank == 3) rankColor = const Color(0xFFCD7F32);

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isMe ? AppTheme.primaryColor.withOpacity(0.08) : AppTheme.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isMe ? AppTheme.primaryColor.withOpacity(0.4) : AppTheme.dividerColor),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                child: rank <= 3
                    ? Icon(Icons.emoji_events, color: rankColor, size: 26)
                    : Text('#$rank', style: TextStyle(color: rankColor, fontWeight: FontWeight.w700)),
              ),
              CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.surfaceColor,
                child: Text(username[0].toUpperCase(), style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Text(username, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                    if (isMe) ...[const SizedBox(width: 6), _badge('Ty', AppTheme.primaryColor)],
                    if (isAdmin) ...[const SizedBox(width: 4), _badge('Admin', AppTheme.secondaryColor)],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('$pts', style: TextStyle(color: rank == 1 ? AppTheme.primaryColor : AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w800)),
                  const Text('pkt', style: TextStyle(color: AppTheme.textTertiary, fontSize: 10)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ── ZAKŁADKA GRUPY ────────────────────────────────────────────────────────

  Widget _buildGroupsTab() {
    if (_groupsWithTeams.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.workspaces_outline, color: AppTheme.textTertiary, size: 48),
            const SizedBox(height: 12),
            const Text('Brak fazy grupowej', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
            if (_isAdmin) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _openGroupPhaseSetup,
                icon: const Icon(Icons.add, color: Colors.black),
                label: const Text('Ustaw fazę grupową', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
              ),
            ],
          ],
        ),
      );
    }

    final groupMatches = _matches.where((m) => m['match_phase'] == 'group').toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: _groupsWithTeams.map((g) {
        final gId = g['id'] as String;
        final gMatches = groupMatches.where((m) => m['group_id'] == gId).toList();
        final teams = List<Map<String, dynamic>>.from(g['teams'] as List);
        final standings = TournamentService.calculateGroupStandings(teams, gMatches);
        return _buildGroupStandingsCard(g['name'] as String, standings, gMatches);
      }).toList(),
    );
  }

  Widget _buildGroupStandingsCard(String groupName, List<Map<String, dynamic>> standings, List<Map<String, dynamic>> gMatches) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                  child: Center(child: Text(groupName, style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w800, fontSize: 13))),
                ),
                const SizedBox(width: 8),
                Text('Grupa $groupName', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
              ],
            ),
          ),
          // Nagłówek tabeli
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Expanded(child: Text('Drużyna', style: TextStyle(color: AppTheme.textTertiary, fontSize: 11, fontWeight: FontWeight.w600))),
                for (final h in ['M', 'W', 'R', 'P', 'G', 'Pkt'])
                  SizedBox(width: h == 'Pkt' ? 36 : 22, child: Text(h, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11, fontWeight: FontWeight.w600))),
              ],
            ),
          ),
          const Divider(color: AppTheme.dividerColor, height: 8),
          // Wiersze
          ...standings.asMap().entries.map((entry) {
            final idx = entry.key;
            final s = entry.value;
            final team = s['team'] as Map<String, dynamic>;
            return Container(
              color: idx == 0 ? AppTheme.primaryColor.withOpacity(0.04) : null,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 20, height: 20,
                    decoration: BoxDecoration(
                      color: idx < 2 ? AppTheme.primaryColor.withOpacity(0.15) : AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(child: Text('${idx + 1}', style: TextStyle(color: idx < 2 ? AppTheme.primaryColor : AppTheme.textTertiary, fontSize: 11, fontWeight: FontWeight.w700))),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(team['name'] as String, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                  for (final val in [s['played'], s['wins'], s['draws'], s['losses'], '${s['gf']}:${s['ga']}'])
                    SizedBox(width: 22, child: Text('$val', textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12))),
                  SizedBox(
                    width: 36,
                    child: Text('${s['points']}', textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            );
          }),
          // Mecze grupy
          if (gMatches.isNotEmpty) ...[
            const Divider(color: AppTheme.dividerColor, height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text('MECZE', style: const TextStyle(color: AppTheme.textTertiary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
            ),
            ...gMatches.map((m) => _buildMiniMatchRow(m)),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildMiniMatchRow(Map<String, dynamic> m) {
    final isFinished = m['status'] == 'FT';
    final matchTime = DateTime.tryParse(m['match_time'] as String? ?? '')?.toLocal();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(m['home_team_name'] as String, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12), textAlign: TextAlign.right, overflow: TextOverflow.ellipsis)),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isFinished ? AppTheme.surfaceColor : AppTheme.backgroundColor,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.dividerColor),
            ),
            child: Text(
              isFinished ? '${m['home_score']}:${m['away_score']}' : (matchTime != null ? DateFormat('dd.MM').format(matchTime) : 'VS'),
              style: TextStyle(color: isFinished ? AppTheme.textPrimary : AppTheme.textTertiary, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: Text(m['away_team_name'] as String, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  // ── ZAKŁADKA DRABINKA ─────────────────────────────────────────────────────

  Widget _buildBracketTab() {
    final knockoutMatches = _matches
        .where((m) => m['match_phase'] == 'knockout')
        .toList();

    if (knockoutMatches.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.emoji_events_outlined, color: AppTheme.textTertiary, size: 48),
            const SizedBox(height: 12),
            const Text('Brak drabinki pucharowej', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
            if (_isAdmin && _hasGroupPhase) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _generateKnockout,
                icon: const Icon(Icons.auto_awesome, color: Colors.black),
                label: const Text('Generuj drabinkę', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
              ),
            ],
          ],
        ),
      );
    }

    // Grupuj po rundach
    final Map<int, List<Map<String, dynamic>>> byRound = {};
    for (final m in knockoutMatches) {
      final r = m['knockout_round'] as int? ?? 1;
      byRound.putIfAbsent(r, () => []).add(m);
    }
    // Ascending: Final (1) at top, then SF (2), then QF (4)
    final rounds = byRound.keys.toList()..sort((a, b) => a.compareTo(b));

    final roundNames = {1: 'FINAŁ', 2: 'PÓŁFINAŁ', 4: 'ĆWIERĆFINAŁ', 8: '1/8 FINAŁU'};

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: rounds.map((r) {
        final matches = byRound[r]!..sort((a, b) => (a['knockout_slot'] as int? ?? 0).compareTo(b['knockout_slot'] as int? ?? 0));
        final roundLabel = roundNames[r] ?? 'RUNDA';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.emoji_events, color: AppTheme.primaryColor, size: 14),
                  const SizedBox(width: 6),
                  Text(roundLabel, style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                ],
              ),
            ),
            ...matches.map((m) => _buildBracketMatchCard(m)),
            const SizedBox(height: 8),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildBracketMatchCard(Map<String, dynamic> m) {
    final isFinished = m['status'] == 'FT';
    final isFinal = (m['knockout_round'] as int? ?? 0) == 1;
    final matchTime = DateTime.tryParse(m['match_time'] as String? ?? '')?.toLocal();
    final homeLogo = m['home_team_logo'] as String?;
    final awayLogo = m['away_team_logo'] as String?;
    final homeSource = m['home_source'] as String?;
    final awaySource = m['away_source'] as String?;

    final card = GestureDetector(
      onTap: isFinished ? null : (_isAdmin ? () => _showEnterResultDialog(m) : null),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isFinal ? AppTheme.cardColor.withOpacity(0.97) : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(isFinal ? 18 : 14),
        ),
        child: Padding(
          padding: EdgeInsets.all(isFinal ? 18.0 : 12.0),
          child: Row(
            children: [
              isFinal ? _teamLogoMedium(homeLogo) : _teamLogoSmall(homeLogo),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(m['home_team_name'] as String,
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: isFinal ? 16 : 13,
                        ),
                        textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
                    if (homeSource != null && !isFinished)
                      Text(homeSource, style: const TextStyle(color: AppTheme.textTertiary, fontSize: 10), textAlign: TextAlign.center),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isFinal ? 14 : 10,
                  vertical: isFinal ? 10 : 6,
                ),
                decoration: BoxDecoration(
                  color: isFinished ? AppTheme.surfaceColor : AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isFinished ? AppTheme.primaryColor.withOpacity(0.4) : AppTheme.dividerColor),
                ),
                child: isFinished
                    ? Text('${m['home_score']}:${m['away_score']}',
                        style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: isFinal ? 22 : 16))
                    : Text(
                        matchTime != null ? DateFormat('dd.MM').format(matchTime) : 'VS',
                        style: const TextStyle(color: AppTheme.textTertiary, fontWeight: FontWeight.w600, fontSize: 12),
                      ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(m['away_team_name'] as String,
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: isFinal ? 16 : 13,
                        ),
                        textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
                    if (awaySource != null && !isFinished)
                      Text(awaySource, style: const TextStyle(color: AppTheme.textTertiary, fontSize: 10), textAlign: TextAlign.center),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              isFinal ? _teamLogoMedium(awayLogo) : _teamLogoSmall(awayLogo),
            ],
          ),
        ),
      ),
    );

    if (!isFinal) return card;
    return _PulsingBorderCard(child: card);
  }

  Widget _teamLogoMedium(String? url) {
    if (url != null && url.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(imageUrl: url, width: 40, height: 40, fit: BoxFit.cover,
            errorWidget: (_, __, ___) => _teamLogoPlaceholder(40)),
      );
    }
    return _teamLogoPlaceholder(40);
  }

  Widget _teamLogoPlaceholder(double size) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Icon(Icons.shield_outlined, color: AppTheme.textTertiary, size: size * 0.55),
    );
  }

  // ── DIALOGI ──────────────────────────────────────────────────────────────

  Future<void> _deleteTeam(String teamId, String teamName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Usuń drużynę', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('Czy na pewno chcesz usunąć "$teamName"?', style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Nie')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Tak, usuń', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await TournamentService.deleteTeam(teamId);
      _loadData();
    } catch (e) {
      _snack('Błąd: $e', color: AppTheme.errorColor);
    }
  }

  Future<void> _deleteTournament() async {
    final name = _tournament['name'] as String;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Usuń turniej', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          'Czy na pewno chcesz usunąć "$name"?\n\nUsunięte zostaną wszystkie mecze, drużyny i dane turnieju. Tej operacji nie można cofnąć.',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Nie')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Tak, usuń', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await TournamentService.deleteTournament(_tournament['id'] as String);
      if (mounted) Navigator.of(context).pop(); // wróć do listy
    } catch (e) {
      _snack('Błąd: $e', color: AppTheme.errorColor);
    }
  }

  Future<void> _generateDirectKnockout() async {
    if (_teams.length < 2) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Generuj puchar', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          'Wygenerować drabinkę pucharową dla ${_teams.length} drużyn?\n\nIstniejące mecze knockout zostaną usunięte.',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Nie')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            child: const Text('Generuj', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await TournamentService.generateDirectKnockout(
        tournamentId: _tournament['id'] as String,
        teams: _teams,
      );
      _loadData();
    } catch (e) {
      _snack('Błąd: $e', color: AppTheme.errorColor);
    }
  }

  Future<void> _showAddTeamDialog() async {
    final nameCtrl = TextEditingController();
    File? logoFile;
    String? logoPreviewPath;
    String? libraryLogoUrl;
    bool saving = false;

    // Załaduj bibliotekę drużyn admina
    final userTeams = await TournamentService.getUserTeams();

    // Filtruj te które już są w tym turnieju
    final existingNames = _teams.map((t) => (t['name'] as String).toLowerCase()).toSet();
    final availableLibraryTeams = userTeams
        .where((t) => !existingNames.contains((t['name'] as String).toLowerCase()))
        .toList();

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.viewInsetsOf(ctx).bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Dodaj drużynę', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),

              // Sekcja "Twoje drużyny" z biblioteki
              if (availableLibraryTeams.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text('TWOJE DRUŻYNY', style: TextStyle(color: AppTheme.textTertiary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: availableLibraryTeams.map((t) {
                    final tName = t['name'] as String;
                    final tLogo = t['logo_url'] as String?;
                    return GestureDetector(
                      onTap: () async {
                        if (saving) return;
                        setInner(() => saving = true);
                        try {
                          await TournamentService.addTeam(
                            tournamentId: _tournament['id'] as String,
                            name: tName,
                            existingLogoUrl: tLogo,
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                          _loadData();
                        } catch (e) {
                          setInner(() => saving = false);
                          _snack('Błąd: $e', color: AppTheme.errorColor);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.dividerColor),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (tLogo != null)
                              ClipOval(
                                child: CachedNetworkImage(imageUrl: tLogo, width: 20, height: 20, fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => const SizedBox(width: 20, height: 20)),
                              )
                            else
                              Container(
                                width: 20, height: 20,
                                decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.2), shape: BoxShape.circle),
                                child: Center(child: Text(tName.substring(0, 1).toUpperCase(), style: const TextStyle(color: AppTheme.primaryColor, fontSize: 10, fontWeight: FontWeight.w700))),
                              ),
                            const SizedBox(width: 6),
                            Text(tName, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Row(children: [
                    Expanded(child: Divider(color: AppTheme.dividerColor)),
                    Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('lub nowa', style: TextStyle(color: AppTheme.textTertiary, fontSize: 12))),
                    Expanded(child: Divider(color: AppTheme.dividerColor)),
                  ]),
                ),
              ] else
                const SizedBox(height: 16),

              // Logo picker
              GestureDetector(
                onTap: () async {
                  final file = await TournamentService.pickLogoFromGallery();
                  if (file != null) setInner(() { logoFile = file; logoPreviewPath = file.path; libraryLogoUrl = null; });
                },
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.primaryColor.withOpacity(0.5)),
                  ),
                  child: logoPreviewPath != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(13),
                          child: Image.file(File(logoPreviewPath!), fit: BoxFit.cover),
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo_outlined, color: AppTheme.primaryColor, size: 24),
                            SizedBox(height: 4),
                            Text('Logo', style: TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Nazwa drużyny',
                  hintStyle: const TextStyle(color: AppTheme.textTertiary),
                  filled: true,
                  fillColor: AppTheme.surfaceColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: saving ? null : () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    setInner(() => saving = true);
                    try {
                      await TournamentService.addTeam(
                        tournamentId: _tournament['id'] as String,
                        name: name,
                        logoFile: logoFile,
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      _loadData();
                    } catch (e) {
                      setInner(() => saving = false);
                      _snack('Błąd dodawania drużyny: $e', color: AppTheme.errorColor);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                      : const Text('Dodaj', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAddMatchDialog() async {
    if (_teams.length < 2) {
      // Przejdź do zakładki drużyn i otwórz dialog dodawania
      _goToTeamsTab();
      await Future.delayed(const Duration(milliseconds: 300));
      _showAddTeamDialog();
      return;
    }

    Map<String, dynamic>? homeTeam;
    Map<String, dynamic>? awayTeam;
    DateTime? matchDate;
    final roundCtrl = TextEditingController();
    bool saving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.viewInsetsOf(ctx).bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Dodaj mecz', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _teamDropdown('Gospodarz', homeTeam, (t) => setInner(() => homeTeam = t))),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('VS', style: TextStyle(color: AppTheme.textTertiary, fontWeight: FontWeight.w700))),
                  Expanded(child: _teamDropdown('Gość', awayTeam, (t) => setInner(() => awayTeam = t))),
                ],
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.now().add(const Duration(days: 1)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    builder: (c, child) => Theme(data: Theme.of(c).copyWith(colorScheme: const ColorScheme.dark(primary: AppTheme.primaryColor)), child: child!),
                  );
                  if (picked != null && ctx.mounted) {
                    final time = await showTimePicker(
                      context: ctx,
                      initialTime: const TimeOfDay(hour: 18, minute: 0),
                      builder: (c, child) => Theme(data: Theme.of(c).copyWith(colorScheme: const ColorScheme.dark(primary: AppTheme.primaryColor)), child: child!),
                    );
                    if (time != null) {
                      setInner(() => matchDate = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute));
                    }
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, color: AppTheme.primaryColor, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        matchDate != null ? DateFormat('dd.MM.yyyy HH:mm').format(matchDate!) : 'Wybierz datę i godzinę',
                        style: TextStyle(color: matchDate != null ? AppTheme.textPrimary : AppTheme.textTertiary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: roundCtrl,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Etap (np. Faza grupowa, Finał)',
                  hintStyle: const TextStyle(color: AppTheme.textTertiary),
                  filled: true,
                  fillColor: AppTheme.surfaceColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: (saving || homeTeam == null || awayTeam == null || matchDate == null) ? null : () async {
                    setInner(() => saving = true);
                    try {
                      await TournamentService.createMatch(
                        tournamentId: _tournament['id'] as String,
                        homeTeam: homeTeam!,
                        awayTeam: awayTeam!,
                        matchTime: matchDate!,
                        roundName: roundCtrl.text.trim().isEmpty ? null : roundCtrl.text.trim(),
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      _loadData();
                    } catch (e) {
                      setInner(() => saving = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                      : const Text('Dodaj mecz', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _teamDropdown(String label, Map<String, dynamic>? selected, void Function(Map<String, dynamic>) onChanged) {
    return DropdownButtonFormField<String>(
      value: selected?['id'] as String?,
      dropdownColor: AppTheme.cardColor,
      style: const TextStyle(color: AppTheme.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppTheme.textTertiary, fontSize: 12),
        filled: true,
        fillColor: AppTheme.surfaceColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
      items: _teams.map((t) => DropdownMenuItem(
        value: t['id'] as String,
        child: Text(t['name'] as String, overflow: TextOverflow.ellipsis),
      )).toList(),
      onChanged: (id) {
        final t = _teams.firstWhere((t) => t['id'] == id);
        onChanged(t);
      },
    );
  }

  Future<void> _showEnterResultDialog(Map<String, dynamic> match) async {
    final homeCtrl = TextEditingController();
    final awayCtrl = TextEditingController();
    bool saving = false;

    await showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.viewInsetsOf(ctx).bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Wynik: ${match['home_team_name']} vs ${match['away_team_name']}',
                  style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: TextField(
                    controller: homeCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w800),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: '0',
                      hintStyle: const TextStyle(color: AppTheme.textTertiary, fontSize: 24),
                      filled: true,
                      fillColor: AppTheme.surfaceColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  )),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text(':', style: TextStyle(color: AppTheme.textPrimary, fontSize: 28, fontWeight: FontWeight.w900))),
                  Expanded(child: TextField(
                    controller: awayCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w800),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: '0',
                      hintStyle: const TextStyle(color: AppTheme.textTertiary, fontSize: 24),
                      filled: true,
                      fillColor: AppTheme.surfaceColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  )),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: saving ? null : () async {
                    final h = int.tryParse(homeCtrl.text);
                    final a = int.tryParse(awayCtrl.text);
                    if (h == null || a == null) return;
                    setInner(() => saving = true);
                    try {
                      await TournamentService.setResult(matchId: match['id'] as String, homeScore: h, awayScore: a);
                      // Awans do następnej rundy jeśli mecz knockout
                      if (match['match_phase'] == 'knockout') {
                        await TournamentService.advanceKnockoutWinner(
                          tournamentId: _tournament['id'] as String,
                          completedMatch: {...match, 'home_score': h, 'away_score': a},
                        );
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                      _loadData();

                      // Pokaż nakładkę celebracji zwycięzcy
                      final winnerName = h > a
                          ? (match['home_team_name'] as String? ?? '')
                          : (h < a ? (match['away_team_name'] as String? ?? '') : '');
                      final isFinal = (match['round_name'] as String? ?? '').toLowerCase().contains('finał')
                          || (match['knockout_round'] as int?) == 1;
                      if (mounted && winnerName.isNotEmpty) {
                        showMatchWinnerOverlay(
                          context: context,
                          winnerName: winnerName,
                          homeScore: h,
                          awayScore: a,
                          homeTeamName: match['home_team_name'] as String? ?? '',
                          awayTeamName: match['away_team_name'] as String? ?? '',
                          isFinal: isFinal,
                        );
                      }
                    } catch (e) {
                      setInner(() => saving = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                      : const Text('Zatwierdź wynik', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showMatchPredictDialog(Map<String, dynamic> match) async {
    if (match['status'] == 'FT') {
      // Pokaż typy innych
      _showMatchPredictionsView(match);
      return;
    }
    if (_currentUserId == null) return;

    final homeCtrl = TextEditingController();
    final awayCtrl = TextEditingController();
    bool saving = false;

    // Załaduj istniejący typ
    final existing = await SupabaseConfig.client
        .from('tournament_predictions')
        .select()
        .eq('custom_match_id', match['id'] as String)
        .eq('user_id', _currentUserId!)
        .maybeSingle();

    if (existing != null) {
      homeCtrl.text = existing['predicted_home_score'].toString();
      awayCtrl.text = existing['predicted_away_score'].toString();
    }

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.viewInsetsOf(ctx).bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Twój typ: ${match['home_team_name']} vs ${match['away_team_name']}',
                  style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 15), textAlign: TextAlign.center),
              const SizedBox(height: 4),
              const Text('Punktacja: 3 / 2 / 1 / 0 pkt', style: TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: TextField(
                    controller: homeCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 28, fontWeight: FontWeight.w800),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: '0',
                      hintStyle: const TextStyle(color: AppTheme.textTertiary, fontSize: 28),
                      filled: true,
                      fillColor: AppTheme.surfaceColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  )),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text(':', style: TextStyle(color: AppTheme.textPrimary, fontSize: 32, fontWeight: FontWeight.w900))),
                  Expanded(child: TextField(
                    controller: awayCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 28, fontWeight: FontWeight.w800),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: '0',
                      hintStyle: const TextStyle(color: AppTheme.textTertiary, fontSize: 28),
                      filled: true,
                      fillColor: AppTheme.surfaceColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  )),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: saving ? null : () async {
                    final h = int.tryParse(homeCtrl.text);
                    final a = int.tryParse(awayCtrl.text);
                    if (h == null || a == null) return;
                    setInner(() => saving = true);
                    try {
                      await TournamentService.savePrediction(
                        tournamentId: _tournament['id'] as String,
                        matchId: match['id'] as String,
                        userId: _currentUserId!,
                        homeScore: h,
                        awayScore: a,
                      );
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        _snack('Typ zapisany!');
                      }
                    } catch (e) {
                      setInner(() => saving = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                      : Text(existing != null ? 'Zmień typ' : 'Zapisz typ', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showMatchPredictionsView(Map<String, dynamic> match) async {
    final preds = await TournamentService.getMatchPredictions(match['id'] as String);
    final homeScore = match['home_score'] as int?;
    final awayScore = match['away_score'] as int?;

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Wynik: ${match['home_team_name']} $homeScore:$awayScore ${match['away_team_name']}',
                style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 16),
            if (preds.isEmpty)
              const Text('Brak typów', style: TextStyle(color: AppTheme.textSecondary))
            else
              ...preds.map((p) {
                final profile = p['profiles'] as Map<String, dynamic>?;
                final username = profile?['username'] as String? ?? 'Użytkownik';
                final ph = p['predicted_home_score'] as int;
                final pa = p['predicted_away_score'] as int;
                int? pts;
                if (homeScore != null && awayScore != null) {
                  pts = ScoringService.calculatePoints(predictHome: ph, predictAway: pa, realHome: homeScore, realAway: awayScore);
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      CircleAvatar(radius: 16, backgroundColor: AppTheme.surfaceColor, child: Text(username[0].toUpperCase(), style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w700, fontSize: 12))),
                      const SizedBox(width: 10),
                      Expanded(child: Text(username, style: const TextStyle(color: AppTheme.textPrimary))),
                      Text('$ph:$pa', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
                      if (pts != null) ...[
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                          child: Text('+$pts pkt', style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w700, fontSize: 12)),
                        ),
                      ],
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
    child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
  );

  Widget _teamLogoSmall(String? url) => _teamLogoWidget(url, 28);

  Widget _teamLogoWidget(String? url, double size) {
    if (url == null || url.isEmpty) {
      return SizedBox(
        width: size, height: size,
        child: Center(child: Icon(Icons.shield_outlined, color: AppTheme.textTertiary, size: size * 0.7)),
      );
    }
    if (url.toLowerCase().endsWith('.svg')) {
      return SvgPicture.network(url, width: size, height: size, fit: BoxFit.contain,
          placeholderBuilder: (_) => SizedBox(width: size, height: size));
    }
    return CachedNetworkImage(
      imageUrl: url, width: size, height: size, fit: BoxFit.contain,
      errorWidget: (_, __, ___) => SizedBox(
        width: size, height: size,
        child: Icon(Icons.shield_outlined, color: AppTheme.textTertiary, size: size * 0.7),
      ),
    );
  }
}

// Pulsująca neonowa ramka dla karty Finału
class _PulsingBorderCard extends StatefulWidget {
  final Widget child;
  const _PulsingBorderCard({required this.child});

  @override
  State<_PulsingBorderCard> createState() => _PulsingBorderCardState();
}

class _PulsingBorderCardState extends State<_PulsingBorderCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    // Stop pulsing after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _ctrl.stop();
        _ctrl.value = 1.0;
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, child) {
        final glow = lerpDouble(0.3, 1.0, _anim.value)!;
        final width = lerpDouble(1.5, 3.0, _anim.value)!;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppTheme.primaryColor.withOpacity(glow),
              width: width,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(glow * 0.35),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
