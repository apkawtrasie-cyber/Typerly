import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_theme.dart';
import '../../models/match.dart';
import '../../services/api_football_service.dart';
import 'competitions_screen.dart';

class RoundsScreen extends StatefulWidget {
  final Competition competition;
  const RoundsScreen({super.key, required this.competition});

  @override
  State<RoundsScreen> createState() => _RoundsScreenState();
}

class _RoundsScreenState extends State<RoundsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Mecze tab state
  List<String> _rounds = [];
  String? _selectedRound;
  List<Map<String, dynamic>> _fixtures = [];
  bool _isLoadingRounds = true;
  bool _isLoadingFixtures = false;

  // Uczestnicy tab state
  List<Map<String, dynamic>> _teams = [];
  bool _isLoadingTeams = true;

  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRounds();
    _loadTeams();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRounds() async {
    setState(() { _isLoadingRounds = true; _error = null; });
    try {
      final rounds = await ApiFootballService.getRounds(
        widget.competition.id,
        widget.competition.season,
      );
      if (mounted) {
        setState(() { _rounds = rounds; _isLoadingRounds = false; });
        if (rounds.isNotEmpty) _selectRound(rounds.first);
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoadingRounds = false; });
    }
  }

  Future<void> _loadTeams() async {
    try {
      final teams = await ApiFootballService.getTeams(
        widget.competition.id,
        widget.competition.season,
      );
      if (mounted) setState(() { _teams = teams; _isLoadingTeams = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoadingTeams = false);
    }
  }

  Future<void> _selectRound(String round) async {
    setState(() { _selectedRound = round; _isLoadingFixtures = true; _fixtures = []; });
    try {
      final fixtures = await ApiFootballService.getFixtures(
        leagueId: widget.competition.id,
        season: widget.competition.season,
        round: round,
      );
      if (mounted) setState(() { _fixtures = fixtures; _isLoadingFixtures = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoadingFixtures = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            backgroundColor: AppTheme.backgroundColor,
            expandedHeight: 130,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(widget.competition.name,
                style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppTheme.surfaceColor, AppTheme.backgroundColor],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    CachedNetworkImage(
                      imageUrl: widget.competition.logoUrl,
                      width: 56,
                      height: 56,
                      fit: BoxFit.contain,
                      errorWidget: (_, __, ___) => Text(widget.competition.emoji, style: const TextStyle(fontSize: 44)),
                    ),
                    if (widget.competition.dateRange != null) ...[
                      const SizedBox(height: 4),
                      Text(widget.competition.dateRange!,
                        style: const TextStyle(color: AppTheme.primaryColor, fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ],
                ),
              ),
            ),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.primaryColor,
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: AppTheme.textTertiary,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              tabs: const [
                Tab(text: 'MECZE'),
                Tab(text: 'UCZESTNICY'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildMatchesTab(),
            _buildTeamsTab(),
          ],
        ),
      ),
    );
  }

  // ── MECZE TAB ──────────────────────────────────────────────────
  Widget _buildMatchesTab() {
    if (_isLoadingRounds) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
    }
    if (_error != null) return _buildError();
    if (_rounds.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.calendar_today_outlined, color: AppTheme.textTertiary, size: 48),
            const SizedBox(height: 12),
            const Text('Brak danych dla tego sezonu', style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
            const SizedBox(height: 6),
            Text('Sezon ${widget.competition.season} może jeszcze nie być dostępny w API',
              style: const TextStyle(color: AppTheme.textTertiary, fontSize: 12),
              textAlign: TextAlign.center),
          ],
        ),
      );
    }
    return Column(
      children: [
        _buildRoundPicker(),
        Expanded(child: _buildFixtures()),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off, color: AppTheme.textTertiary, size: 48),
          const SizedBox(height: 12),
          const Text('Błąd połączenia z API', style: TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _loadRounds, child: const Text('Spróbuj ponownie')),
        ],
      ),
    );
  }

  Widget _buildRoundPicker() {
    final groups = _rounds.where((r) => r.toLowerCase().contains('group')).toList();
    final knockouts = _rounds.where((r) => !r.toLowerCase().contains('group')).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (groups.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Text('FAZA GRUPOWA', style: TextStyle(color: AppTheme.textTertiary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
          ),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: groups.length,
              itemBuilder: (_, i) => _roundChip(groups[i]),
            ),
          ),
        ],
        if (knockouts.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.fromLTRB(16, groups.isEmpty ? 12 : 8, 16, 6),
            child: const Text('FAZA PUCHAROWA', style: TextStyle(color: AppTheme.textTertiary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
          ),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: knockouts.length,
              itemBuilder: (_, i) => _roundChip(knockouts[i]),
            ),
          ),
        ],
        const SizedBox(height: 8),
        const Divider(height: 1, color: AppTheme.dividerColor),
      ],
    );
  }

  Widget _roundChip(String round) {
    final isSelected = _selectedRound == round;
    return GestureDetector(
      onTap: () => _selectRound(round),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppTheme.primaryColor : AppTheme.dividerColor),
        ),
        child: Text(
          _formatRound(round),
          style: TextStyle(
            color: isSelected ? AppTheme.backgroundColor : AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildFixtures() {
    if (_isLoadingFixtures) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
    }
    if (_fixtures.isEmpty) {
      return const Center(child: Text('Brak meczów w tej rundzie', style: TextStyle(color: AppTheme.textSecondary)));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: _fixtures.length,
      itemBuilder: (context, i) => _buildFixtureCard(_fixtures[i]),
    );
  }

  Widget _buildFixtureCard(Map<String, dynamic> fixture) {
    final fix = fixture['fixture'] as Map<String, dynamic>;
    final teams = fixture['teams'] as Map<String, dynamic>;
    final goals = fixture['goals'] as Map<String, dynamic>;

    final home = teams['home'] as Map<String, dynamic>;
    final away = teams['away'] as Map<String, dynamic>;
    final status = fix['status'] as Map<String, dynamic>;
    final statusShort = status['short'] as String;
    final matchDate = DateTime.tryParse(fix['date'] as String? ?? '')?.toLocal();

    final homeGoals = goals['home'] as int?;
    final awayGoals = goals['away'] as int?;
    final isLive = ['1H', '2H', 'HT', 'ET', 'BT', 'P', 'LIVE'].contains(statusShort);
    final isFinished = ['FT', 'AET', 'PEN'].contains(statusShort);

    return GestureDetector(
      onTap: () => _navigateToMatch(fixture),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isLive ? Colors.red : AppTheme.primaryColor.withOpacity(0.15),
            width: isLive ? 1.5 : 0.5,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (isLive)
                  Row(children: [
                    Container(width: 7, height: 7, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Text("${status['elapsed'] ?? ''}\'", style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w700)),
                  ])
                else if (matchDate != null)
                  Text(_formatDate(matchDate), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12))
                else
                  const SizedBox(),
                if (isFinished)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: BorderRadius.circular(6)),
                    child: const Text('FT', style: TextStyle(color: AppTheme.textTertiary, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                if (!isLive && !isFinished)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                    child: const Text('TYPUJ', style: TextStyle(color: AppTheme.primaryColor, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _buildTeamSide(home, TextAlign.left)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: isFinished || isLive
                      ? Text(
                          '${homeGoals ?? 0} : ${awayGoals ?? 0}',
                          style: TextStyle(
                            color: isLive ? Colors.red : AppTheme.primaryColor,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        )
                      : const Text('VS', style: TextStyle(color: AppTheme.textTertiary, fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                Expanded(child: _buildTeamSide(away, TextAlign.right)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamSide(Map<String, dynamic> team, TextAlign align) {
    final logoUrl = team['logo'] as String?;
    final name = team['name'] as String? ?? '';
    return Column(
      children: [
        if (logoUrl != null)
          CachedNetworkImage(
            imageUrl: logoUrl,
            width: 44,
            height: 44,
            fit: BoxFit.contain,
            errorWidget: (_, __, ___) => const Icon(Icons.sports_soccer, color: AppTheme.primaryColor, size: 32),
          ),
        const SizedBox(height: 8),
        Text(name,
          style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
          textAlign: align,
          maxLines: 2,
          overflow: TextOverflow.ellipsis),
      ],
    );
  }

  // ── UCZESTNICY TAB ────────────────────────────────────────────
  Widget _buildTeamsTab() {
    if (_isLoadingTeams) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
    }
    if (_teams.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.group_outlined, color: AppTheme.textTertiary, size: 48),
            const SizedBox(height: 12),
            const Text('Brak danych o uczestnikach', style: TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 6),
            Text('Sezon ${widget.competition.season} może jeszcze nie być dostępny',
              style: const TextStyle(color: AppTheme.textTertiary, fontSize: 12),
              textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(
            children: [
              Text('${_teams.length} uczestników', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              const Spacer(),
              Text(widget.competition.country, style: const TextStyle(color: AppTheme.primaryColor, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const Divider(height: 1, color: AppTheme.dividerColor),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.85,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _teams.length,
            itemBuilder: (_, i) => _buildTeamCard(_teams[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildTeamCard(Map<String, dynamic> entry) {
    final team = entry['team'] as Map<String, dynamic>;
    final name = team['name'] as String? ?? '';
    final logo = team['logo'] as String?;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (logo != null)
            CachedNetworkImage(
              imageUrl: logo,
              width: 50,
              height: 50,
              fit: BoxFit.contain,
              errorWidget: (_, __, ___) => const Icon(Icons.sports_soccer, color: AppTheme.primaryColor, size: 36),
            )
          else
            const Icon(Icons.sports_soccer, color: AppTheme.primaryColor, size: 36),
          const SizedBox(height: 8),
          Text(
            name,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ── NAVIGATION ─────────────────────────────────────────────────
  void _navigateToMatch(Map<String, dynamic> fixture) {
    final fix = fixture['fixture'] as Map<String, dynamic>;
    final teams = fixture['teams'] as Map<String, dynamic>;
    final goals = fixture['goals'] as Map<String, dynamic>;
    final status = fix['status'] as Map<String, dynamic>;
    final statusShort = status['short'] as String;

    final isFinished = ['FT', 'AET', 'PEN'].contains(statusShort);
    final isLive = ['1H', '2H', 'HT', 'ET', 'BT', 'P', 'LIVE'].contains(statusShort);

    final matchData = <String, dynamic>{
      'id': fix['id'].toString(),
      'api_fixture_id': fix['id'] as int,
      'home_team_name': teams['home']['name'] as String,
      'away_team_name': teams['away']['name'] as String,
      'home_team_logo_url': teams['home']['logo'] as String?,
      'away_team_logo_url': teams['away']['logo'] as String?,
      'match_time': fix['date'] as String,
      'status': isLive ? 'LIVE' : isFinished ? 'FT' : 'NS',
      'home_score': goals['home'] as int?,
      'away_score': goals['away'] as int?,
      'is_custom': false,
      'creator_id': null,
      'league_id': null,
      'created_at': fix['date'] as String,
      'sport_type': 'football',
    };

    final match = Match.fromJson(matchData);
    Navigator.pushNamed(context, '/match-detail', arguments: match);
  }

  // ── HELPERS ────────────────────────────────────────────────────
  String _formatRound(String round) {
    return round
        .replaceAll('Group Stage', 'Faza grupowa')
        .replaceAll('Group', 'Gr.')
        .replaceAll('Round of 16', '1/8 finału')
        .replaceAll('Quarter-finals', 'Ćwierćfinał')
        .replaceAll('Semi-finals', 'Półfinał')
        .replaceAll('3rd Place Final', 'Mecz o 3. miejsce')
        .replaceAll('Final', 'Finał');
  }

  String _formatDate(DateTime date) {
    final days = ['Pon', 'Wt', 'Śr', 'Czw', 'Pt', 'Sob', 'Nd'];
    final months = ['sty', 'lut', 'mar', 'kwi', 'maj', 'cze', 'lip', 'sie', 'wrz', 'paź', 'lis', 'gru'];
    return '${days[date.weekday - 1]} ${date.day} ${months[date.month - 1]}, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
