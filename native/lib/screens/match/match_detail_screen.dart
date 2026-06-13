import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/config/supabase_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/prediction_scorer.dart';
import '../../features/auth/auth.dart';
import '../../models/match.dart';
import '../../widgets/widgets.dart';

class MatchDetailScreen extends StatefulWidget {
  const MatchDetailScreen({super.key});

  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen> {
  final _homeScoreController = TextEditingController();
  final _awayScoreController = TextEditingController();

  List<Map<String, dynamic>> _predictions = [];
  bool _isLoadingPredictions = true;
  String? _existingPredictionId;
  bool _isSaving = false;

  // Statystyki z Supabase: forma drużyn + bezpośrednie mecze (H2H).
  // Konto api-football jest zawieszone, więc liczymy z tabeli `matches`
  // (zasilanej z football-data.org przez sync-matches/sync-live).
  List<Map<String, dynamic>> _homeForm = [];
  List<Map<String, dynamic>> _awayForm = [];
  List<Map<String, dynamic>> _h2h = [];
  List<Map<String, dynamic>> _homeSquad = [];
  List<Map<String, dynamic>> _awaySquad = [];
  bool _isLoadingStats = false;
  bool _isLoadingLineups = false;
  String? _statsError;
  String? _lineupsError;

  // Guard — didChangeDependencies może być wołany wielokrotnie
  bool _initialized = false;
  // Overlay wyników pokazujemy tylko raz per sesja
  bool _overlayShown = false;

  late Match _match;
  String? _currentUserId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    _match = ModalRoute.of(context)!.settings.arguments as Match;
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      _currentUserId = authState.profile.id;
    }
    _loadPredictions();
    _loadLineups();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    if (!mounted) return;
    setState(() { _isLoadingStats = true; _statsError = null; });
    try {
      final db = SupabaseConfig.client;
      final home = _match.homeTeamName;
      final away = _match.awayTeamName;

      final results = await Future.wait([
        // Forma: ostatnie 5 zakończonych meczów każdej z drużyn
        db.from('matches').select()
            .eq('status', 'FT')
            .or('home_team_name.eq."$home",away_team_name.eq."$home"')
            .order('match_time', ascending: false)
            .limit(5),
        db.from('matches').select()
            .eq('status', 'FT')
            .or('home_team_name.eq."$away",away_team_name.eq."$away"')
            .order('match_time', ascending: false)
            .limit(5),
        // H2H: bezpośrednie mecze obu drużyn
        db.from('matches').select()
            .eq('status', 'FT')
            .or('and(home_team_name.eq."$home",away_team_name.eq."$away"),'
                'and(home_team_name.eq."$away",away_team_name.eq."$home")')
            .order('match_time', ascending: false)
            .limit(10),
      ]);

      if (mounted) {
        setState(() {
          _homeForm = List<Map<String, dynamic>>.from(results[0] as List);
          _awayForm = List<Map<String, dynamic>>.from(results[1] as List);
          _h2h = List<Map<String, dynamic>>.from(results[2] as List);
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _isLoadingStats = false; _statsError = e.toString(); });
    }
  }

  Future<void> _loadLineups() async {
    if (!mounted) return;
    setState(() { _isLoadingLineups = true; _lineupsError = null; });
    try {
      // Kadry z Supabase (tabela squads, zasilana z football-data przez sync-squads)
      final homeSquad = await SupabaseConfig.client
          .from('squads')
          .select()
          .eq('team_name', _match.homeTeamName);

      final awaySquad = await SupabaseConfig.client
          .from('squads')
          .select()
          .eq('team_name', _match.awayTeamName);

      var homeList = List<Map<String, dynamic>>.from(homeSquad as List);
      var awayList = List<Map<String, dynamic>>.from(awaySquad as List);

      // Sortowanie wg linii formacji: bramkarze → obrona → pomoc → atak
      int posOrder(Map<String, dynamic> p) =>
          _posGroup(p['player_position'] as String?);
      homeList.sort((a, b) => posOrder(a).compareTo(posOrder(b)));
      awayList.sort((a, b) => posOrder(a).compareTo(posOrder(b)));

      if (mounted) {
        setState(() {
          _homeSquad = homeList;
          _awaySquad = awayList;
          _isLoadingLineups = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _isLoadingLineups = false; _lineupsError = e.toString(); });
    }
  }

  Future<void> _loadPredictions() async {
    if (!mounted) return;
    setState(() => _isLoadingPredictions = true);
    try {
      // Ładuj typy w tym samym kontekście ligowym co mecz
      // Kontekst ligi: null = globalny, 'id' = prywatna grupa
      var query = SupabaseConfig.client
          .from('predictions')
          .select('*, profiles(username, avatar_url)')
          .eq('match_id', _match.id);

      if (_match.leagueId != null) {
        query = query.eq('league_id', _match.leagueId!);
      } else {
        query = query.isFilter('league_id', null);
      }

      final response = await query.order('updated_at', ascending: false);

      final predictions = List<Map<String, dynamic>>.from(response as List);

      String? existingId;
      for (final p in predictions) {
        if (p['user_id'] == _currentUserId) {
          existingId = p['id'] as String;
          if (_homeScoreController.text.isEmpty) {
            _homeScoreController.text = p['predicted_home_score'].toString();
            _awayScoreController.text = p['predicted_away_score'].toString();
          }
          break;
        }
      }

      if (mounted) {
        setState(() {
          _predictions = predictions;
          _existingPredictionId = existingId;
          _isLoadingPredictions = false;
        });

        // Overlay wyniku — tylko dla zakończonego meczu z typem użytkownika
        _maybeShowResultOverlay(predictions);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingPredictions = false);
    }
  }

  void _maybeShowResultOverlay(List<Map<String, dynamic>> predictions) {
    if (_overlayShown) return;
    if (!_match.isFinished) return;
    if (_currentUserId == null) return;
    if (_match.homeScore == null || _match.awayScore == null) return;

    // Szukamy własnego typu
    Map<String, dynamic>? own;
    for (final p in predictions) {
      if (p['user_id'] == _currentUserId) { own = p; break; }
    }
    if (own == null) return;

    final predHome = own['predicted_home_score'] as int? ?? 0;
    final predAway = own['predicted_away_score'] as int? ?? 0;
    final actualHome = _match.homeScore!;
    final actualAway = _match.awayScore!;

    final points = PredictionScorer.calculate(
      predictedHome: predHome,
      predictedAway: predAway,
      actualHome: actualHome,
      actualAway: actualAway,
    );

    final profiles = own['profiles'] as Map<String, dynamic>?;
    final username = profiles?['username'] as String? ?? 'Ty';

    _overlayShown = true;

    // Mapowanie punktów → odznaka
    final badgeMap = {
      3: ('Snajper 🎯', 'rare'),
      2: ('Strateg ⚡', 'common'),
      1: ('Analityk 📊', 'common'),
      0: ('Tarcza 🛡️', 'common'),
    };
    final badge = badgeMap[points];

    // Małe opóźnienie żeby ekran się wyrenderował
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      showPredictionResultOverlay(
        context: context,
        username: username,
        points: points,
        predictedHome: predHome,
        predictedAway: predAway,
        actualHome: actualHome,
        actualAway: actualAway,
        badgeName: badge?.$1,
        badgeRarity: badge?.$2,
      );
    });
  }

  Future<void> _handleSubmitTip() async {
    if (_homeScoreController.text.isEmpty || _awayScoreController.text.isEmpty) return;
    final home = int.tryParse(_homeScoreController.text);
    final away = int.tryParse(_awayScoreController.text);
    if (home == null || away == null || _currentUserId == null) return;

    setState(() => _isSaving = true);
    try {
      final client = SupabaseConfig.client;
      if (_existingPredictionId != null) {
        await client.from('predictions').update({
          'predicted_home_score': home,
          'predicted_away_score': away,
        }).eq('id', _existingPredictionId!);
      } else {
        final insert = <String, dynamic>{
          'match_id': _match.id,
          'user_id': _currentUserId,
          'predicted_home_score': home,
          'predicted_away_score': away,
        };
        if (_match.leagueId != null) insert['league_id'] = _match.leagueId;
        await client.from('predictions').insert(insert);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Typ zapisany!'), backgroundColor: AppTheme.successColor),
        );
        await _loadPredictions();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _homeScoreController.dispose();
    _awayScoreController.dispose();
    _pageScrollController.dispose();
    super.dispose();
  }

  final _pageScrollController = ScrollController();

  // Czat działa tylko dla meczów zapisanych w bazie (FK do matches.id)
  bool get _hasDbMatch =>
      !_match.id.startsWith('local_') && _match.id.contains('-');

  void _scrollToChat() {
    _pageScrollController.animateTo(
      _pageScrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Stack(
        children: [
          CustomScrollView(
            controller: _pageScrollController,
            slivers: [
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                backgroundColor: AppTheme.backgroundColor,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    '${_match.homeTeamName} vs ${_match.awayTeamName}',
                    style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppTheme.surfaceColor, AppTheme.backgroundColor],
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_match.isLive)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.liveColor,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text('LIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                            ),
                          const SizedBox(height: 16),
                          if (_match.homeScore != null && _match.awayScore != null)
                            Text(
                              '${_match.homeScore} : ${_match.awayScore}',
                              style: const TextStyle(color: AppTheme.primaryColor, fontSize: 48, fontWeight: FontWeight.w800),
                            )
                          else
                            const Text('VS', style: TextStyle(color: AppTheme.textTertiary, fontSize: 32, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildPredictionForm(),
                      // Statystyki z Supabase: forma + H2H
                      const SizedBox(height: 24),
                      _buildStatistics(),
                      // Składy z Supabase (squads) — zawsze, własna obsługa pustego
                      const SizedBox(height: 24),
                      _buildLineups(),
                      const SizedBox(height: 24),
                      _buildPointsIndicator(),
                      const SizedBox(height: 24),
                      _buildOtherPredictions(),
                      // Czat meczu — wspólny dla wszystkich typujących
                      if (_hasDbMatch) ...[
                        const SizedBox(height: 24),
                        BlocBuilder<AuthBloc, AuthState>(
                          builder: (context, state) => MatchChatWidget(
                            matchId: _match.id,
                            matchName:
                                '${_match.homeTeamName} vs ${_match.awayTeamName}',
                            userId: _currentUserId,
                            username: state is AuthAuthenticated
                                ? state.profile.username
                                : null,
                            // Mecz otwarty z prywatnej ligi → osobny czat ligi
                            leagueId: _match.leagueId,
                          ),
                        ),
                      ],
                      const SizedBox(height: 96),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPredictionForm() {
    if (_match.isFinished) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.dividerColor),
        ),
        child: Column(
          children: [
            const Icon(Icons.check_circle, color: AppTheme.successColor, size: 48),
            const SizedBox(height: 12),
            const Text('Mecz zakończony', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Wynik: ${_match.homeScore ?? 0} : ${_match.awayScore ?? 0}',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryColor, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text('TWÓJ TYP', style: TextStyle(color: AppTheme.primaryColor, fontSize: 16, fontWeight: FontWeight.w700)),
              const Spacer(),
              if (_existingPredictionId != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Zapisany', style: TextStyle(color: AppTheme.successColor, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _homeScoreController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 32, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle: const TextStyle(color: AppTheme.textTertiary),
                    filled: true,
                    fillColor: AppTheme.surfaceColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.dividerColor)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              const Text(':', style: TextStyle(color: AppTheme.textPrimary, fontSize: 32, fontWeight: FontWeight.w700)),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _awayScoreController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 32, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle: const TextStyle(color: AppTheme.textTertiary),
                    filled: true,
                    fillColor: AppTheme.surfaceColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.dividerColor)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            text: _existingPredictionId != null ? 'Zaktualizuj typ' : 'Zapisz typ',
            onPressed: _handleSubmitTip,
            isLoading: _isSaving,
          ),
        ],
      ),
    );
  }

  Widget _buildPointsIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('PUNKTACJA', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildPointBadge('Dokładny wynik', '+3', AppTheme.primaryColor),
              _buildPointBadge('Różnica bramek', '+2', AppTheme.secondaryColor),
              _buildPointBadge('Tendencja', '+1', AppTheme.textTertiary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPointBadge(String label, String points, Color color) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color),
          ),
          child: Center(child: Text(points, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w700))),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10), textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildOtherPredictions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('INNE TYPY', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            if (!_isLoadingPredictions)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('${_predictions.length}', style: const TextStyle(color: AppTheme.primaryColor, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoadingPredictions)
          const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
        else if (_predictions.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.dividerColor),
            ),
            child: const Center(
              child: Text('Brak typów dla tego meczu', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
            ),
          )
        else
          ..._predictions.map((p) {
            final profiles = p['profiles'] as Map<String, dynamic>?;
            final username = profiles?['username'] as String? ?? 'Użytkownik';
            final homeScore = p['predicted_home_score'] as int? ?? 0;
            final awayScore = p['predicted_away_score'] as int? ?? 0;
            final points = p['points_earned'] as int? ?? 0;
            final isOwn = p['user_id'] == _currentUserId;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isOwn ? AppTheme.primaryColor.withOpacity(0.08) : AppTheme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isOwn ? AppTheme.primaryColor.withOpacity(0.4) : AppTheme.dividerColor),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppTheme.surfaceColor,
                    child: Text(
                      username[0].toUpperCase(),
                      style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(username, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                            if (isOwn) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('Ty', style: TextStyle(color: AppTheme.primaryColor, fontSize: 10, fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ],
                        ),
                        Text('$homeScore : $awayScore', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getPointsColor(points).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      points > 0 ? '+$points' : '-',
                      style: TextStyle(color: _getPointsColor(points), fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Color _getPointsColor(int points) {
    switch (points) {
      case 3: return AppTheme.primaryColor;
      case 2: return AppTheme.secondaryColor;
      case 1: return AppTheme.textTertiary;
      default: return AppTheme.textTertiary;
    }
  }


  // ── STATYSTYKI MECZU ───────────────────────────────────────────
  Widget _buildStatistics() {
    if (_isLoadingStats) {
      return _sectionShell('STATYSTYKI MECZU', const Center(
        child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: AppTheme.primaryColor)),
      ));
    }
    if (_statsError != null) {
      return _sectionShell('STATYSTYKI', _retryWidget('Błąd: $_statsError', _loadStatistics));
    }
    if (_homeForm.isEmpty && _awayForm.isEmpty) {
      return _sectionShell('STATYSTYKI', const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: Text('Brak rozegranych meczów w bazie', style: TextStyle(color: AppTheme.textTertiary, fontSize: 12), textAlign: TextAlign.center)),
      ));
    }

    final home = _match.homeTeamName;
    final away = _match.awayTeamName;

    int wins(List<Map<String, dynamic>> form, String team) =>
        form.where((m) => _outcomeFor(m, team) > 0).length;
    int draws(List<Map<String, dynamic>> form, String team) =>
        form.where((m) => _outcomeFor(m, team) == 0).length;
    int losses(List<Map<String, dynamic>> form, String team) =>
        form.where((m) => _outcomeFor(m, team) < 0).length;
    double goalsAvg(List<Map<String, dynamic>> form, String team) {
      if (form.isEmpty) return 0;
      var sum = 0;
      for (final m in form) {
        final isHome = m['home_team_name'] == team;
        sum += ((isHome ? m['home_score'] : m['away_score']) as int?) ?? 0;
      }
      return sum / form.length;
    }

    // Bilans H2H z perspektywy gospodarza
    final h2hHomeWins = _h2h.where((m) => _outcomeFor(m, home) > 0).length;
    final h2hDraws = _h2h.where((m) => _outcomeFor(m, home) == 0).length;
    final h2hAwayWins = _h2h.length - h2hHomeWins - h2hDraws;

    return _sectionShell(
      'STATYSTYKI',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nagłówki drużyn
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(child: Text(home, style: const TextStyle(color: AppTheme.primaryColor, fontSize: 12, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                Expanded(child: Text(away, style: const TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.w700), textAlign: TextAlign.right, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
          // Forma — ostatnie 5 meczów
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _formChips(_homeForm, home),
                const Text('Forma (ost. 5)', style: TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
                _formChips(_awayForm, away),
              ],
            ),
          ),
          _statRow('Wygrane', wins(_homeForm, home), wins(_awayForm, away)),
          _statRow('Remisy', draws(_homeForm, home), draws(_awayForm, away)),
          _statRow('Porażki', losses(_homeForm, home), losses(_awayForm, away)),
          _statRow('Śr. goli na mecz',
              goalsAvg(_homeForm, home).toStringAsFixed(1),
              goalsAvg(_awayForm, away).toStringAsFixed(1)),
          if (_h2h.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('BEZPOŚREDNIE MECZE (${_h2h.length})',
                style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
            const SizedBox(height: 8),
            _statRow('Wygrane H2H', h2hHomeWins, h2hAwayWins),
            _statRow('Remisy H2H', h2hDraws, h2hDraws),
          ],
        ],
      ),
    );
  }

  // Wynik meczu z perspektywy drużyny: >0 wygrana, 0 remis, <0 porażka
  int _outcomeFor(Map<String, dynamic> m, String team) {
    final hs = (m['home_score'] as int?) ?? 0;
    final as_ = (m['away_score'] as int?) ?? 0;
    final isHome = m['home_team_name'] == team;
    return isHome ? hs - as_ : as_ - hs;
  }

  // Kolorowe znaczniki W/R/P (od najnowszego)
  Widget _formChips(List<Map<String, dynamic>> form, String team) {
    if (form.isEmpty) {
      return const Text('—', style: TextStyle(color: AppTheme.textTertiary));
    }
    return Row(
      children: form.map((m) {
        final o = _outcomeFor(m, team);
        final (label, color) = o > 0
            ? ('W', AppTheme.successColor)
            : o < 0
                ? ('P', AppTheme.errorColor)
                : ('R', AppTheme.textTertiary);
        return Container(
          width: 20,
          height: 20,
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800)),
          ),
        );
      }).toList(),
    );
  }

  Widget _statRow(String label, dynamic homeVal, dynamic awayVal) {
    final hStr = homeVal?.toString() ?? '—';
    final aStr = awayVal?.toString() ?? '—';

    double parse(dynamic v) {
      if (v == null) return 0;
      final s = v.toString().replaceAll('%', '');
      return double.tryParse(s) ?? 0;
    }

    final h = parse(homeVal);
    final a = parse(awayVal);
    final total = h + a;
    final ratio = total > 0 ? h / total : 0.5;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(hStr, style: const TextStyle(color: AppTheme.primaryColor, fontSize: 13, fontWeight: FontWeight.w700)),
              Text(label, style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
              Text(aStr, style: const TextStyle(color: Colors.blue, fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 5,
              backgroundColor: Colors.blue.withValues(alpha: 0.35),
              valueColor: const AlwaysStoppedAnimation(AppTheme.primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  // ── SKŁADY ─────────────────────────────────────────────────────

  // Grupa pozycji: 0 bramkarz, 1 obrona, 2 pomoc, 3 atak, 4 inne.
  // Obsługuje nazwy z football-data ('Goalkeeper', 'Centre-Back', 'Defensive
  // Midfield'...) i skróty z api-football ('G','D','M','F').
  int _posGroup(String? pos) {
    final p = (pos ?? '').toLowerCase().trim();
    if (p == 'g' || p.contains('keeper')) return 0;
    if (p == 'm' || p.contains('midfield')) return 2;
    if (p == 'd' || p.contains('back') || p.contains('defen')) return 1;
    if (p == 'f' ||
        p.contains('wing') ||
        p.contains('forward') ||
        p.contains('offen') ||
        p.contains('striker') ||
        p.contains('attack')) {
      return 3;
    }
    return 4;
  }

  static const _posGroupNames = ['BRAMKARZE', 'OBRONA', 'POMOC', 'ATAK', 'POZOSTALI'];

  Widget _buildLineups() {
    if (_isLoadingLineups) {
      return _sectionShell('SKŁADY', const Center(
        child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: AppTheme.primaryColor)),
      ));
    }
    if (_lineupsError != null) {
      return _sectionShell('SKŁADY', _retryWidget('Błąd: $_lineupsError', _loadLineups));
    }
    if (_homeSquad.isEmpty && _awaySquad.isEmpty) {
      return _sectionShell('SKŁADY', const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: Text('Składy drużyn niedostępne dla tego meczu', style: TextStyle(color: AppTheme.textTertiary, fontSize: 12), textAlign: TextAlign.center)),
      ));
    }

    // Gospodarze w lewej kolumnie, goście w prawej
    return _sectionShell('SKŁADY', Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _match.homeTeamName,
                style: const TextStyle(color: AppTheme.primaryColor, fontSize: 13, fontWeight: FontWeight.w700),
                maxLines: 2,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _match.awayTeamName,
                style: const TextStyle(color: Colors.blue, fontSize: 13, fontWeight: FontWeight.w700),
                textAlign: TextAlign.right,
                maxLines: 2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _squadColumn(_homeSquad, isHome: true)),
              Container(
                width: 1,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                color: AppTheme.dividerColor,
              ),
              Expanded(child: _squadColumn(_awaySquad, isHome: false)),
            ],
          ),
        ),
      ],
    ));
  }

  Widget _squadColumn(List<Map<String, dynamic>> squad, {required bool isHome}) {
    if (squad.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('Brak danych o kadrze',
            style: TextStyle(color: AppTheme.textTertiary, fontSize: 11),
            textAlign: TextAlign.center),
      );
    }

    final accent = isHome ? AppTheme.primaryColor : Colors.blue;
    final children = <Widget>[];
    int? lastGroup;

    for (final p in squad) {
      final group = _posGroup(p['player_position'] as String?);
      if (group != lastGroup) {
        lastGroup = group;
        children.add(Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: Text(_posGroupNames[group],
              style: TextStyle(color: accent, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1)),
        ));
      }
      children.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(color: accent.withValues(alpha: 0.6), shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                p['player_name'] as String? ?? '?',
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }

  Widget _retryWidget(String message, VoidCallback onRetry) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Text(message,
              style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 16, color: AppTheme.primaryColor),
            label: const Text('Spróbuj ponownie',
                style: TextStyle(color: AppTheme.primaryColor, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _sectionShell(String title, Widget child) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

}

