import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import '../../features/auth/auth.dart';
import '../../models/match.dart';
import '../../models/league.dart';
import '../../services/league_service.dart';
import '../../services/tournament_service.dart';

class HomeScreen extends StatefulWidget {
  /// Pozwala przełączyć zakładkę dolnej nawigacji (np. "Zobacz wszystkie"
  /// dyscypliny → zakładka Sporty, "Zarządzaj" → zakładka Ligi).
  final void Function(int tabIndex)? onNavigateToTab;

  const HomeScreen({super.key, this.onNavigateToTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Dane
  List<Map<String, dynamic>> _allMatches = [];
  List<Map<String, dynamic>> _live = [];
  List<Map<String, dynamic>> _upcoming = [];
  Map<String, int> _sportCounts = {};
  Map<String, Map<String, dynamic>> _myPredictions = {}; // match_id -> prediction
  int _totalPoints = 0;
  List<League> _leagues = [];
  Map<String, int> _leagueMemberCounts = {};
  List<Map<String, dynamic>> _tournaments = [];
  List<Map<String, dynamic>> _weeklyRanking = [];

  bool _loading = true;
  String? _error;
  Timer? _liveTimer;

  // Paleta zgodna ze screenem (złoty akcent na czarnym tle)
  static const Color gold = Color(0xFFFFC83D);
  static const Color bg = Color(0xFF0A0A0A);
  static const Color card = Color(0xFF161616);
  static const Color cardLight = Color(0xFF1E1E1E);
  static const Color textDim = Color(0xFF8A8A8A);
  static const Color live = Color(0xFFFF4444);

  String? get _userId {
    final state = context.read<AuthBloc>().state;
    return state is AuthAuthenticated ? state.profile.id : null;
  }

  @override
  void initState() {
    super.initState();
    _fetchAll();
    // Odświeżaj dane LIVE co 2 minuty (sync aktualizuje bazę osobno)
    _liveTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      if (_live.isNotEmpty) _fetchAll(silent: true);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _liveTimer?.cancel();
    super.dispose();
  }

  // Aplikacja czyta WYŁĄCZNIE z Supabase. Dane do bazy wprowadza sync
  // (football-data.org → Supabase). Klasyfikacja po kolumnie `status`.
  Future<void> _fetchAll({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) setState(() { _loading = true; _error = null; });

    try {
      final db = Supabase.instance.client;
      final userId = _userId;
      final now = DateTime.now().toUtc();
      final from = now.subtract(const Duration(days: 7)).toIso8601String();
      final to = now.add(const Duration(days: 60)).toIso8601String();

      // Równoległe pobranie wszystkich sekcji
      final results = await Future.wait([
        db.from('matches').select()
            .gte('match_time', from).lte('match_time', to)
            .order('match_time'),
        if (userId != null)
          db.from('predictions')
              .select('match_id, predicted_home_score, predicted_away_score, points_earned, is_calculated')
              .eq('user_id', userId)
        else
          Future.value(<dynamic>[]),
        if (userId != null)
          LeagueService.getUserLeagues(userId)
        else
          Future.value(<League>[]),
        if (userId != null)
          TournamentService.getUserTournaments(userId)
        else
          Future.value(<Map<String, dynamic>>[]),
        _fetchWeeklyRanking(db),
      ]);

      final all = results[0].cast<Map<String, dynamic>>();
      final predictions = results[1].cast<Map<String, dynamic>>();
      final leagues = results[2].cast<League>();
      final tournaments = results[3].cast<Map<String, dynamic>>();
      final ranking = results[4].cast<Map<String, dynamic>>();

      // Klasyfikacja meczów
      final liveList = <Map<String, dynamic>>[];
      final upcomingList = <Map<String, dynamic>>[];
      final counts = <String, int>{};
      for (final m in all) {
        final status = (m['status'] as String?) ?? 'NS';
        if (status == 'PST' || status == 'CANC') continue;
        final sport = (m['sport_type'] as String?) ?? 'football';
        counts[sport] = (counts[sport] ?? 0) + 1;
        final matchTime = DateTime.tryParse(m['match_time'] as String? ?? '');
        if (status == 'LIVE') {
          liveList.add(m);
        } else if (status != 'FT' &&
            matchTime != null &&
            matchTime.isAfter(now)) {
          upcomingList.add(m);
        }
      }
      upcomingList.sort((a, b) =>
          (a['match_time'] as String).compareTo(b['match_time'] as String));

      // Moje typy i suma punktów
      final predMap = <String, Map<String, dynamic>>{};
      var points = 0;
      for (final p in predictions) {
        predMap[p['match_id'] as String] = p;
        if (p['is_calculated'] == true) {
          points += (p['points_earned'] as int?) ?? 0;
        }
      }

      // Liczba członków lig (do kart "Twoje ligi")
      final memberCounts = <String, int>{};
      await Future.wait(leagues.take(10).map((l) async {
        memberCounts[l.id] = await LeagueService.getMemberCount(l.id);
      }));

      if (!mounted) return;
      setState(() {
        _allMatches = all;
        _live = liveList;
        _upcoming = upcomingList;
        _sportCounts = counts;
        _myPredictions = predMap;
        _totalPoints = points;
        _leagues = leagues;
        _leagueMemberCounts = memberCounts;
        _tournaments = tournaments;
        _weeklyRanking = ranking;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (!silent) _error = 'Błąd ładowania danych: $e';
      });
    }
  }

  // Ranking tygodnia: suma punktów z obliczonych typów od poniedziałku
  Future<List<Map<String, dynamic>>> _fetchWeeklyRanking(
      SupabaseClient db) async {
    try {
      final now = DateTime.now().toUtc();
      final weekStart = now
          .subtract(Duration(days: now.weekday - 1))
          .copyWith(hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0);

      final resp = await db
          .from('predictions')
          .select('user_id, points_earned')
          .eq('is_calculated', true)
          .gte('updated_at', weekStart.toIso8601String());

      final pointsMap = <String, int>{};
      for (final p in (resp as List)) {
        final uid = p['user_id'] as String;
        pointsMap[uid] = (pointsMap[uid] ?? 0) + ((p['points_earned'] as int?) ?? 0);
      }
      if (pointsMap.isEmpty) return [];

      final sorted = pointsMap.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topIds = sorted.take(3).map((e) => e.key).toList();

      final profiles = await db
          .from('profiles')
          .select('id, username, avatar_url')
          .inFilter('id', topIds);
      final profileMap = {
        for (final p in (profiles as List)) p['id'] as String: p
      };

      return [
        for (final e in sorted.take(3))
          if (profileMap[e.key] != null)
            {
              'user_id': e.key,
              'username': profileMap[e.key]!['username'],
              'avatar_url': profileMap[e.key]!['avatar_url'],
              'points': e.value,
            }
      ];
    } catch (_) {
      return [];
    }
  }

  // ── Wyszukiwarka ──────────────────────────────────────────────────────────

  List<Map<String, dynamic>> get _searchResults {
    final q = _searchQuery.toLowerCase();
    return _allMatches.where((m) {
      final home = (m['home_team_name'] as String? ?? '').toLowerCase();
      final away = (m['away_team_name'] as String? ?? '').toLowerCase();
      final comp = _competitionLabel(
              m['competition'] as String?, m['sport_type'] as String?)
          .toLowerCase();
      return home.contains(q) || away.contains(q) || comp.contains(q);
    }).toList();
  }

  void _openMatch(Map<String, dynamic> match) {
    final safeMatch = Map<String, dynamic>.from(match);
    safeMatch['status'] = safeMatch['status'] ?? 'NS';
    safeMatch['is_custom'] = (safeMatch['is_custom'] as bool?) ?? false;
    safeMatch['created_at'] ??= DateTime.now().toIso8601String();
    safeMatch['id'] ??=
        'local_${match['api_fixture_id'] ?? DateTime.now().millisecondsSinceEpoch}';
    safeMatch['sport_type'] ??= 'football';
    Navigator.pushNamed(context, '/match-detail',
        arguments: Match.fromJson(safeMatch));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: _loading && _allMatches.isEmpty
            ? const Center(child: CircularProgressIndicator(color: gold))
            : _error != null && _allMatches.isEmpty
                ? _buildError()
                : RefreshIndicator(
                    color: gold,
                    backgroundColor: card,
                    onRefresh: _fetchAll,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 20),
                        _buildSearchBar(),
                        const SizedBox(height: 24),
                        if (_searchQuery.isNotEmpty)
                          ..._buildSearchSection()
                        else ...[
                          if (_live.isNotEmpty) ...[
                            _buildSectionHeader('Na żywo',
                                trailing:
                                    '${_live.length} ${_matchWord(_live.length)}',
                                trailingColor: gold,
                                liveDot: true),
                            const SizedBox(height: 12),
                            ..._live.take(3).map(_buildLiveCard),
                            const SizedBox(height: 24),
                          ] else if (_upcoming.isNotEmpty) ...[
                            _buildSectionHeader('Najbliższe mecze',
                                trailing:
                                    '${_upcoming.length} ${_matchWord(_upcoming.length)}',
                                trailingColor: gold),
                            const SizedBox(height: 12),
                            ..._upcoming.take(3).map(_buildUpcomingCard),
                            const SizedBox(height: 24),
                          ],
                          _buildSectionHeader('Dyscypliny',
                              trailing: 'Zobacz wszystkie',
                              trailingColor: gold,
                              onTrailingTap: () =>
                                  widget.onNavigateToTab?.call(1)),
                          const SizedBox(height: 12),
                          _buildDisciplinesGrid(),
                          const SizedBox(height: 24),
                          _buildSectionHeader('Twoje ligi',
                              trailing: 'Zarządzaj',
                              trailingColor: gold,
                              onTrailingTap: () =>
                                  widget.onNavigateToTab?.call(2)),
                          const SizedBox(height: 12),
                          _buildLeaguesRow(),
                          const SizedBox(height: 24),
                          _buildSectionHeader('Ranking tygodnia',
                              trailing: 'Pełny ranking',
                              trailingColor: gold,
                              onTrailingTap: () =>
                                  Navigator.pushNamed(context, '/leaderboard')),
                          const SizedBox(height: 12),
                          _buildWeeklyRanking(),
                        ],
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off, color: textDim, size: 48),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(_error ?? 'Błąd',
                style: const TextStyle(color: textDim),
                textAlign: TextAlign.center),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: gold),
            onPressed: _fetchAll,
            child: const Text('Spróbuj ponownie',
                style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  // ── Nagłówek: powitanie, punkty, avatar ──────────────────────────────────

  Widget _buildHeader() {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final profile = state is AuthAuthenticated ? state.profile : null;
        final username = profile?.username ?? 'Gościu';
        final initials = username.isNotEmpty
            ? username.trim().split(RegExp(r'\s+'))
                .map((w) => w[0]).take(2).join().toUpperCase()
            : '?';

        return Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/icons/typerly_icon.png',
                width: 40,
                height: 40,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Witaj ponownie,',
                      style: TextStyle(color: textDim, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(
                    username,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Pastylka z punktami
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF2A2A2A)),
              ),
              child: Row(
                children: [
                  Text(
                    NumberFormat('#,###').format(_totalPoints)
                        .replaceAll(',', ' '),
                    style: const TextStyle(
                        color: gold,
                        fontWeight: FontWeight.w800,
                        fontSize: 15),
                  ),
                  const SizedBox(width: 4),
                  const Text('pkt',
                      style: TextStyle(color: textDim, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => widget.onNavigateToTab?.call(4),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: gold,
                  borderRadius: BorderRadius.circular(14),
                ),
                clipBehavior: Clip.antiAlias,
                child: profile?.avatarUrl != null
                    ? CachedNetworkImage(
                        imageUrl: profile!.avatarUrl!, fit: BoxFit.cover)
                    : Center(
                        child: Text(initials,
                            style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w800,
                                fontSize: 14)),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      onChanged: (v) => setState(() => _searchQuery = v.trim()),
      decoration: InputDecoration(
        hintText: 'Szukaj drużyny, ligi lub meczu…',
        hintStyle: const TextStyle(color: textDim, fontSize: 14),
        prefixIcon: const Icon(Icons.search, color: textDim, size: 20),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close, color: textDim, size: 18),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              )
            : null,
        fillColor: card,
        filled: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: gold.withValues(alpha: 0.6)),
        ),
      ),
    );
  }

  List<Widget> _buildSearchSection() {
    final results = _searchResults;
    if (results.isEmpty) {
      return const [
        SizedBox(height: 60),
        Center(
          child: Text('Brak wyników wyszukiwania',
              style: TextStyle(color: textDim)),
        ),
      ];
    }
    return [
      _buildSectionHeader('Wyniki',
          trailing: '${results.length} ${_matchWord(results.length)}',
          trailingColor: gold),
      const SizedBox(height: 12),
      ...results.take(20).map((m) =>
          (m['status'] == 'LIVE') ? _buildLiveCard(m) : _buildUpcomingCard(m)),
    ];
  }

  Widget _buildSectionHeader(String title,
      {String? trailing,
      Color trailingColor = textDim,
      bool liveDot = false,
      VoidCallback? onTrailingTap}) {
    return Row(
      children: [
        if (liveDot) ...[
          Container(
            width: 8,
            height: 8,
            decoration:
                const BoxDecoration(color: live, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
        ],
        Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800)),
        const Spacer(),
        if (trailing != null)
          GestureDetector(
            onTap: onTrailingTap,
            child: Text(trailing,
                style: TextStyle(
                    color: trailingColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ),
      ],
    );
  }

  // ── Karty meczów ──────────────────────────────────────────────────────────

  String _myTip(Map<String, dynamic> match) {
    final p = _myPredictions[match['id']];
    if (p == null) return '';
    final h = (p['predicted_home_score'] as int?) ?? 0;
    final a = (p['predicted_away_score'] as int?) ?? 0;
    if (h > a) return '1';
    if (h < a) return '2';
    return 'X';
  }

  Widget _buildLiveCard(Map<String, dynamic> match) {
    final tip = _myTip(match);
    final league = _competitionLabel(
        match['competition'] as String?, match['sport_type'] as String?);

    return GestureDetector(
      onTap: () => _openMatch(match),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1C1C1C), Color(0xFF141414)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: live.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(league,
                    style: const TextStyle(color: textDim, fontSize: 12)),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: live.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                              color: live, shape: BoxShape.circle)),
                      const SizedBox(width: 5),
                      const Text('LIVE',
                          style: TextStyle(
                              color: live,
                              fontSize: 11,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                    child: _buildTeamColumn(
                        match['home_team_logo_url'] as String?,
                        match['home_team_name'] as String? ?? '?')),
                Column(
                  children: [
                    Text(
                      '${match['home_score'] ?? 0} : ${match['away_score'] ?? 0}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1),
                    ),
                    const SizedBox(height: 4),
                    if (tip.isNotEmpty)
                      Text.rich(
                        TextSpan(
                          text: 'Twój typ: ',
                          style: const TextStyle(color: textDim, fontSize: 11),
                          children: [
                            TextSpan(
                                text: tip,
                                style: const TextStyle(
                                    color: gold,
                                    fontWeight: FontWeight.w800)),
                          ],
                        ),
                      )
                    else
                      const Text('Brak typu',
                          style: TextStyle(color: textDim, fontSize: 11)),
                  ],
                ),
                Expanded(
                    child: _buildTeamColumn(
                        match['away_team_logo_url'] as String?,
                        match['away_team_name'] as String? ?? '?')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingCard(Map<String, dynamic> match) {
    final tip = _myTip(match);
    final league = _competitionLabel(
        match['competition'] as String?, match['sport_type'] as String?);
    final matchTime =
        DateTime.parse(match['match_time'] as String).toLocal();
    final isFinished = match['status'] == 'FT';

    return GestureDetector(
      onTap: () => _openMatch(match),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF242424)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(league,
                    style: const TextStyle(color: textDim, fontSize: 12)),
                Text(
                  isFinished
                      ? 'Zakończony'
                      : '${_formatTimeUntil(matchTime)} · ${DateFormat('HH:mm').format(matchTime)}',
                  style: TextStyle(
                      color: isFinished ? textDim : gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                    child: _buildTeamColumn(
                        match['home_team_logo_url'] as String?,
                        match['home_team_name'] as String? ?? '?')),
                Column(
                  children: [
                    isFinished
                        ? Text(
                            '${match['home_score'] ?? 0} : ${match['away_score'] ?? 0}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900),
                          )
                        : const Text('VS',
                            style: TextStyle(
                                color: textDim,
                                fontSize: 16,
                                fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    if (tip.isNotEmpty)
                      Text.rich(
                        TextSpan(
                          text: 'Twój typ: ',
                          style: const TextStyle(color: textDim, fontSize: 11),
                          children: [
                            TextSpan(
                                text: tip,
                                style: const TextStyle(
                                    color: gold,
                                    fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                  ],
                ),
                Expanded(
                    child: _buildTeamColumn(
                        match['away_team_logo_url'] as String?,
                        match['away_team_name'] as String? ?? '?')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamColumn(String? logoUrl, String name) {
    return Column(
      children: [
        _buildTeamLogo(logoUrl),
        const SizedBox(height: 8),
        Text(
          name,
          style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildTeamLogo(String? url) {
    const double size = 48;
    if (url != null && url.isNotEmpty) {
      // football-data.org herby to SVG; api-football to PNG
      if (url.toLowerCase().endsWith('.svg')) {
        return SvgPicture.network(url,
            width: size,
            height: size,
            fit: BoxFit.contain,
            placeholderBuilder: (_) => _fallbackLogo(size));
      }
      return CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.contain,
        placeholder: (_, __) => _fallbackLogo(size),
        errorWidget: (_, __, ___) => _fallbackLogo(size),
      );
    }
    return _fallbackLogo(size);
  }

  Widget _fallbackLogo(double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: cardLight,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.shield_outlined, color: textDim, size: 24),
      );

  // ── Dyscypliny ────────────────────────────────────────────────────────────

  static const _disciplines = [
    ('football', 'Piłka nożna', '⚽', Color(0xFFFFC83D)),
    ('basketball', 'Koszykówka', '🏀', Color(0xFFFF6B00)),
    ('tennis', 'Tenis', '🎾', Color(0xFF1DB954)),
    ('volleyball', 'Siatkówka', '🏐', Color(0xFF5B8DEF)),
    ('hockey', 'Hokej', '🏒', Color(0xFF00BFFF)),
    ('esports', 'Esport', '🎮', Color(0xFF9B59B6)),
    ('mma', 'MMA / Boks', '🥊', Color(0xFFFF4444)),
    ('speedway', 'Żużel', '🏍', Color(0xFFB0B0B0)),
  ];

  Widget _buildDisciplinesGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.3,
      ),
      itemCount: _disciplines.length,
      itemBuilder: (context, i) {
        final (id, name, emoji, color) = _disciplines[i];
        final count = _sportCounts[id] ?? 0;
        final available = count > 0;

        return GestureDetector(
          onTap: () {
            if (available) {
              widget.onNavigateToTab?.call(1);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$name — wkrótce w Typerly!'),
                  backgroundColor: cardLight,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF242424)),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                      child: Text(emoji,
                          style: const TextStyle(fontSize: 18))),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(
                        available
                            ? '$count ${_matchWord(count)}'
                            : 'Wkrótce',
                        style:
                            const TextStyle(color: textDim, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Twoje ligi ────────────────────────────────────────────────────────────

  Widget _buildLeaguesRow() {
    final hasAny = _leagues.isNotEmpty || _tournaments.isNotEmpty;
    if (!hasAny) {
      return GestureDetector(
        onTap: () => widget.onNavigateToTab?.call(2),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: gold.withValues(alpha: 0.3),
                style: BorderStyle.solid),
          ),
          child: const Row(
            children: [
              Icon(Icons.add_circle_outline, color: gold),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Nie należysz jeszcze do żadnej ligi.\nStwórz własną lub dołącz kodem!',
                  style: TextStyle(color: textDim, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 118,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          ..._leagues.map((l) => _buildLeagueCard(
                name: l.name,
                badge: 'Liga',
                badgeColor: gold,
                subtitle:
                    '${_leagueMemberCounts[l.id] ?? '–'} graczy · kod ${l.inviteCode}',
                onTap: () => Navigator.pushNamed(context, '/league-detail',
                    arguments: l),
              )),
          ..._tournaments.map((t) => _buildLeagueCard(
                name: t['name'] as String? ?? 'Turniej',
                badge: 'Turniej',
                badgeColor: const Color(0xFF5B8DEF),
                subtitle: (t['invite_code'] as String?) != null
                    ? 'kod ${t['invite_code']}'
                    : 'Turniej prywatny',
                onTap: () => Navigator.pushNamed(
                    context, '/tournament-detail', arguments: t),
              )),
        ],
      ),
    );
  }

  Widget _buildLeagueCard({
    required String name,
    required String badge,
    required Color badgeColor,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 220,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF242424)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: badgeColor.withValues(alpha: 0.4)),
              ),
              child: Text(badge,
                  style: TextStyle(
                      color: badgeColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
            const Spacer(),
            Text(name,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                        color: badgeColor, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(subtitle,
                      style: const TextStyle(color: textDim, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Ranking tygodnia ──────────────────────────────────────────────────────

  static const _rankColors = [
    Color(0xFFFF4444), // 1. miejsce
    Color(0xFF9B59B6), // 2. miejsce
    Color(0xFFFFC83D), // 3. miejsce
  ];

  Widget _buildWeeklyRanking() {
    if (_weeklyRanking.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: Text(
            'Brak obliczonych typów w tym tygodniu.\nTypuj mecze i wskakuj do rankingu!',
            style: TextStyle(color: textDim, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          for (var i = 0; i < _weeklyRanking.length; i++) ...[
            if (i > 0)
              const Divider(color: Color(0xFF242424), height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    child: Text('${i + 1}',
                        style: const TextStyle(
                            color: gold,
                            fontWeight: FontWeight.w800,
                            fontSize: 14)),
                  ),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _rankColors[i % _rankColors.length],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _weeklyRanking[i]['avatar_url'] != null
                        ? CachedNetworkImage(
                            imageUrl:
                                _weeklyRanking[i]['avatar_url'] as String,
                            fit: BoxFit.cover)
                        : Center(
                            child: Text(
                              (_weeklyRanking[i]['username'] as String)
                                  .substring(0, 1)
                                  .toUpperCase(),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13),
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _weeklyRanking[i]['username'] as String,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text('${_weeklyRanking[i]['points']}',
                      style: const TextStyle(
                          color: gold,
                          fontWeight: FontWeight.w800,
                          fontSize: 14)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Pomocnicze ────────────────────────────────────────────────────────────

  String _matchWord(int n) {
    if (n == 1) return 'mecz';
    final last = n % 10;
    final lastTwo = n % 100;
    if (last >= 2 && last <= 4 && (lastTwo < 12 || lastTwo > 14)) {
      return 'mecze';
    }
    return 'meczów';
  }

  // Czytelna nazwa rozgrywek z kodu competition (football-data.org)
  static const _compNames = {
    'WC': 'MŚ 2026',
    'CL': 'Liga Mistrzów',
    'EL': 'Liga Europy',
    'PL': 'Premier League',
    'PD': 'La Liga',
    'BL1': 'Bundesliga',
    'SA': 'Serie A',
    'FL1': 'Ligue 1',
    'DED': 'Eredivisie',
    'PPL': 'Primeira Liga',
    'EC': 'Euro',
    'BSA': 'Brasileirão',
    'ELC': 'Championship',
  };

  String _competitionLabel(String? comp, String? sportType) {
    if (comp != null && _compNames.containsKey(comp)) return _compNames[comp]!;
    if (comp != null && comp.isNotEmpty) return comp;
    if (sportType != null && sportType.isNotEmpty && sportType != 'football') {
      return sportType;
    }
    return 'Piłka nożna';
  }

  static const _months = [
    'sty', 'lut', 'mar', 'kwi', 'maj', 'cze',
    'lip', 'sie', 'wrz', 'paź', 'lis', 'gru'
  ];

  String _formatTimeUntil(DateTime matchTime) {
    final now = DateTime.now();
    final diff = matchTime.difference(now);
    if (diff.isNegative) {
      if (diff.inMinutes > -115) return 'Teraz';
      return '${matchTime.day} ${_months[matchTime.month - 1]}';
    }
    if (diff.inDays == 0) {
      if (diff.inHours == 0) return 'Za ${diff.inMinutes} min';
      return 'Za ${diff.inHours} godz';
    }
    if (diff.inDays == 1) return 'Jutro';
    return 'Za ${diff.inDays} dni';
  }
}
