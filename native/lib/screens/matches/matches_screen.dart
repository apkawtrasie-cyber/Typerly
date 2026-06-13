import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import '../../features/auth/auth.dart';
import '../../models/match.dart';

/// Ekran "Mecze" — lista typów z segmentowanym menu u góry:
/// Nadchodzące / ● Live / Zakończone.
class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  int _segment = 0; // 0 = Nadchodzące, 1 = Live, 2 = Zakończone

  List<Map<String, dynamic>> _upcoming = [];
  List<Map<String, dynamic>> _live = [];
  List<Map<String, dynamic>> _finished = [];
  Map<String, Map<String, dynamic>> _myPredictions = {};

  bool _loading = true;
  String? _error;
  Timer? _liveTimer;

  // Paleta spójna z ekranem Home
  static const Color gold = Color(0xFFFFC83D);
  static const Color bg = Color(0xFF0A0A0A);
  static const Color card = Color(0xFF161616);
  static const Color cardLight = Color(0xFF222222);
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
    // Odświeżaj LIVE co 2 minuty (sync aktualizuje bazę osobno)
    _liveTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      if (_segment == 1) _fetchAll(silent: true);
    });
  }

  @override
  void dispose() {
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
      final from = now.subtract(const Duration(days: 90)).toIso8601String();
      final to = now.add(const Duration(days: 60)).toIso8601String();

      final results = await Future.wait([
        db.from('matches').select()
            .gte('match_time', from).lte('match_time', to)
            .order('match_time'),
        if (userId != null)
          db.from('predictions')
              .select('match_id, predicted_home_score, predicted_away_score')
              .eq('user_id', userId)
        else
          Future.value(<dynamic>[]),
      ]);

      final all = results[0].cast<Map<String, dynamic>>();
      final predictions = results[1].cast<Map<String, dynamic>>();

      final liveList = <Map<String, dynamic>>[];
      final upcomingList = <Map<String, dynamic>>[];
      final finishedList = <Map<String, dynamic>>[];

      for (final m in all) {
        final status = (m['status'] as String?) ?? 'NS';
        final matchTime = DateTime.tryParse(m['match_time'] as String? ?? '');
        if (status == 'LIVE') {
          liveList.add(m);
        } else if (status == 'FT') {
          finishedList.add(m);
        } else if (status == 'PST' || status == 'CANC') {
          // pomijamy
        } else if (matchTime != null && matchTime.isBefore(now)) {
          // NS w przeszłości → traktuj jako zakończony (brak wyniku w API)
          finishedList.add(m);
        } else {
          upcomingList.add(m);
        }
      }
      upcomingList.sort((a, b) =>
          (a['match_time'] as String).compareTo(b['match_time'] as String));
      finishedList.sort((a, b) =>
          (b['match_time'] as String).compareTo(a['match_time'] as String));

      final predMap = <String, Map<String, dynamic>>{};
      for (final p in predictions) {
        predMap[p['match_id'] as String] = p;
      }

      if (!mounted) return;
      setState(() {
        _live = liveList;
        _upcoming = upcomingList;
        _finished = finishedList;
        _myPredictions = predMap;
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

  List<Map<String, dynamic>> get _currentList => switch (_segment) {
        1 => _live,
        2 => _finished,
        _ => _upcoming,
      };

  String get _emptyMessage => switch (_segment) {
        1 => 'Brak meczów na żywo',
        2 => 'Brak zakończonych meczów',
        _ => 'Brak nadchodzących meczów',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Text('Mecze',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildSegmentedControl(),
            ),
            const SizedBox(height: 16),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentedControl() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _buildSegment(0, 'Nadchodzące'),
          _buildSegment(1, 'Live', liveDot: true, badge: _live.length),
          _buildSegment(2, 'Zakończone'),
        ],
      ),
    );
  }

  Widget _buildSegment(int index, String label,
      {bool liveDot = false, int badge = 0}) {
    final selected = _segment == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _segment = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? cardLight : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (liveDot) ...[
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                      color: live, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : textDim,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
              if (badge > 0) ...[
                const SizedBox(width: 5),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: live,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('$badge',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _upcoming.isEmpty && _live.isEmpty && _finished.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: gold));
    }
    if (_error != null && _currentList.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, color: textDim, size: 48),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(_error!,
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

    final matches = _currentList;
    return RefreshIndicator(
      color: gold,
      backgroundColor: card,
      onRefresh: _fetchAll,
      child: matches.isEmpty
          ? ListView(
              children: [
                const SizedBox(height: 180),
                Center(
                  child: Column(
                    children: [
                      Icon(
                        _segment == 1
                            ? Icons.live_tv_outlined
                            : Icons.sports_soccer_outlined,
                        color: textDim,
                        size: 40,
                      ),
                      const SizedBox(height: 12),
                      Text(_emptyMessage,
                          style: const TextStyle(color: textDim)),
                    ],
                  ),
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              itemCount: matches.length,
              itemBuilder: (context, i) => _buildMatchCard(matches[i]),
            ),
    );
  }

  // ── Karta meczu ───────────────────────────────────────────────────────────

  String _myTip(Map<String, dynamic> match) {
    final p = _myPredictions[match['id']];
    if (p == null) return '';
    final h = (p['predicted_home_score'] as int?) ?? 0;
    final a = (p['predicted_away_score'] as int?) ?? 0;
    if (h > a) return '1';
    if (h < a) return '2';
    return 'X';
  }

  Widget _buildMatchCard(Map<String, dynamic> match) {
    final status = (match['status'] as String?) ?? 'NS';
    final isLive = status == 'LIVE';
    final matchTime =
        DateTime.parse(match['match_time'] as String).toLocal();
    final hasScore = isLive || status == 'FT';
    final isCustom = (match['is_custom'] as bool?) ?? false;
    final league = isCustom
        ? 'Towarzyski'
        : _competitionLabel(
            match['competition'] as String?, match['sport_type'] as String?);
    final tip = _myTip(match);

    return GestureDetector(
      onTap: () {
        final safeMatch = Map<String, dynamic>.from(match);
        safeMatch['status'] = safeMatch['status'] ?? 'NS';
        safeMatch['is_custom'] = (safeMatch['is_custom'] as bool?) ?? false;
        safeMatch['created_at'] ??= DateTime.now().toIso8601String();
        safeMatch['id'] ??=
            'local_${match['api_fixture_id'] ?? DateTime.now().millisecondsSinceEpoch}';
        safeMatch['sport_type'] ??= 'football';
        Navigator.pushNamed(context, '/match-detail',
            arguments: Match.fromJson(safeMatch));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: card,
          gradient: isLive
              ? const LinearGradient(
                  colors: [Color(0xFF1C1C1C), Color(0xFF141414)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isLive
                ? live.withValues(alpha: 0.25)
                : const Color(0xFF242424),
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(league,
                    style: const TextStyle(color: textDim, fontSize: 12)),
                if (isLive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
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
                  )
                else
                  Text(
                    status == 'FT'
                        ? 'Zakończony · ${matchTime.day} ${_months[matchTime.month - 1]}'
                        : '${_formatTimeUntil(matchTime)} · ${DateFormat('HH:mm').format(matchTime)}',
                    style: TextStyle(
                        color: status == 'FT' ? textDim : gold,
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
                    hasScore
                        ? Text(
                            '${match['home_score'] ?? 0} : ${match['away_score'] ?? 0}',
                            style: TextStyle(
                                color: isLive ? Colors.white : gold,
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1),
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
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
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

  // ── Pomocnicze ────────────────────────────────────────────────────────────

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
