import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_theme.dart';
import 'rounds_screen.dart';
import 'standings_screen.dart';
import 'group_standings_screen.dart';

enum CompetitionStatus { live, upcoming, finished }

class Competition {
  final int id;
  final int season;
  final String name;
  final String country;
  final String logoUrl;
  final String emoji;
  final String description;
  final CompetitionStatus status;
  final String? dateRange;

  const Competition({
    required this.id,
    required this.season,
    required this.name,
    required this.country,
    required this.logoUrl,
    required this.emoji,
    required this.description,
    required this.status,
    this.dateRange,
  });
}

const List<Competition> _competitions = [
  // --- NADCHODZĄCE ---
  Competition(
    id: 1,
    season: 2026,
    name: 'World Cup 2026',
    country: 'Świat',
    logoUrl: 'https://media.api-sports.io/football/leagues/1.png',
    emoji: '🏆',
    description: 'FIFA Mistrzostwa Świata — USA/Kanada/Meksyk',
    status: CompetitionStatus.upcoming,
    dateRange: '11 cze – 19 lip 2026',
  ),

  // --- ARCHIWUM (SEZON 2025/26) ---
  Competition(
    id: 2,
    season: 2025,
    name: 'Champions League',
    country: 'Europa',
    logoUrl: 'https://media.api-sports.io/football/leagues/2.png',
    emoji: '⭐',
    description: 'UEFA Liga Mistrzów 2025/26',
    status: CompetitionStatus.finished,
    dateRange: 'Sezon 2025/26',
  ),
  Competition(
    id: 3,
    season: 2025,
    name: 'Europa League',
    country: 'Europa',
    logoUrl: 'https://media.api-sports.io/football/leagues/3.png',
    emoji: '🔶',
    description: 'UEFA Liga Europy 2025/26',
    status: CompetitionStatus.finished,
    dateRange: 'Sezon 2025/26',
  ),
  Competition(
    id: 39,
    season: 2025,
    name: 'Premier League',
    country: 'Anglia',
    logoUrl: 'https://media.api-sports.io/football/leagues/39.png',
    emoji: '🦁',
    description: 'Angielska Premier League 2025/26',
    status: CompetitionStatus.finished,
    dateRange: 'Sezon 2025/26',
  ),
  Competition(
    id: 140,
    season: 2025,
    name: 'La Liga',
    country: 'Hiszpania',
    logoUrl: 'https://media.api-sports.io/football/leagues/140.png',
    emoji: '🇪🇸',
    description: 'Hiszpańska Primera División 2025/26',
    status: CompetitionStatus.finished,
    dateRange: 'Sezon 2025/26',
  ),
  Competition(
    id: 78,
    season: 2025,
    name: 'Bundesliga',
    country: 'Niemcy',
    logoUrl: 'https://media.api-sports.io/football/leagues/78.png',
    emoji: '🦅',
    description: 'Niemiecka Bundesliga 2025/26',
    status: CompetitionStatus.finished,
    dateRange: 'Sezon 2025/26',
  ),
  Competition(
    id: 135,
    season: 2025,
    name: 'Serie A',
    country: 'Włochy',
    logoUrl: 'https://media.api-sports.io/football/leagues/135.png',
    emoji: '🇮🇹',
    description: 'Włoska Serie A 2025/26',
    status: CompetitionStatus.finished,
    dateRange: 'Sezon 2025/26',
  ),
  Competition(
    id: 106,
    season: 2025,
    name: 'Ekstraklasa',
    country: 'Polska',
    logoUrl: 'https://media.api-sports.io/football/leagues/106.png',
    emoji: '🇵🇱',
    description: 'Polska Ekstraklasa 2025/26',
    status: CompetitionStatus.finished,
    dateRange: 'Sezon 2025/26',
  ),
  Competition(
    id: 6,
    season: 2025,
    name: 'AFCON 2025',
    country: 'Afryka',
    logoUrl: 'https://media.api-sports.io/football/leagues/6.png',
    emoji: '🌍',
    description: 'Puchar Narodów Afryki — Maroko',
    status: CompetitionStatus.finished,
    dateRange: '21 gru 2025 – 18 sty 2026',
  ),

  // --- ARCHIWUM (2025) ---
  Competition(
    id: 15,
    season: 2025,
    name: 'Club World Cup 2025',
    country: 'Świat',
    logoUrl: 'https://media.api-sports.io/football/leagues/15.png',
    emoji: '🌍',
    description: 'FIFA Klubowe MŚ — 32 drużyny',
    status: CompetitionStatus.finished,
    dateRange: '14 cze – 13 lip 2025',
  ),
  Competition(
    id: 30,
    season: 2025,
    name: 'Gold Cup 2025',
    country: 'Ameryka Pn.',
    logoUrl: 'https://media.api-sports.io/football/leagues/30.png',
    emoji: '🏅',
    description: 'CONCACAF Gold Cup — USA/Kanada',
    status: CompetitionStatus.finished,
    dateRange: '14 cze – 6 lip 2025',
  ),
  Competition(
    id: 35,
    season: 2025,
    name: 'Euro Kobiet 2025',
    country: 'Europa',
    logoUrl: 'https://media.api-sports.io/football/leagues/35.png',
    emoji: '👩',
    description: 'UEFA Women\'s Euro — Szwajcaria',
    status: CompetitionStatus.finished,
    dateRange: '2 – 27 lip 2025',
  ),

  // --- ARCHIWUM (2024) ---
  Competition(
    id: 4,
    season: 2024,
    name: 'Euro 2024',
    country: 'Europa',
    logoUrl: 'https://media.api-sports.io/football/leagues/4.png',
    emoji: '🏆',
    description: 'Mistrzostwa Europy w Niemczech',
    status: CompetitionStatus.finished,
    dateRange: 'Czerwiec–Lipiec 2024',
  ),
  Competition(
    id: 9,
    season: 2024,
    name: 'Copa America 2024',
    country: 'Ameryka Pd.',
    logoUrl: 'https://media.api-sports.io/football/leagues/9.png',
    emoji: '🌎',
    description: 'Mistrzostwa Ameryki Południowej 2024',
    status: CompetitionStatus.finished,
    dateRange: 'Czerwiec–Lipiec 2024',
  ),
];

class CompetitionsScreen extends StatefulWidget {
  const CompetitionsScreen({super.key});

  @override
  State<CompetitionsScreen> createState() => _CompetitionsScreenState();
}

class _CompetitionsScreenState extends State<CompetitionsScreen>
    with SingleTickerProviderStateMixin {
  String _searchQuery = '';
  final _searchController = TextEditingController();
  late TabController _tabController;

  final _tabs = const ['WSZYSTKIE', 'TRWAJĄCE', 'NADCHODZĄCE', 'ARCHIWUM'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  List<Competition> get _filtered {
    final tab = _tabController.index;
    var list = _competitions.where((c) {
      final query = _searchQuery;
      return c.name.toLowerCase().contains(query) || c.country.toLowerCase().contains(query);
    }).toList();

    if (tab == 1) list = list.where((c) => c.status == CompetitionStatus.live).toList();
    if (tab == 2) list = list.where((c) => c.status == CompetitionStatus.upcoming).toList();
    if (tab == 3) list = list.where((c) => c.status == CompetitionStatus.finished).toList();
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        title: const Text('ZAWODY', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
        bottom: TabBar(
          controller: _tabController,
          onTap: (_) => setState(() {}),
          isScrollable: true,
          indicatorColor: AppTheme.primaryColor,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textTertiary,
          labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8),
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Szukaj zawodów...',
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: AppTheme.primaryColor),
                fillColor: AppTheme.cardColor,
                filled: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Colors.grey, width: 1),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                if (_searchQuery.isEmpty) _buildFifaCard(),
                if (_searchQuery.isEmpty) _buildLeagueCarousel(),
                if (_tabController.index == 0 && _searchQuery.isEmpty)
                  _buildFeaturedSection(),
                const SizedBox(height: 8),
                if (_filtered.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                        child: Text('Brak zawodów',
                            style: TextStyle(color: AppTheme.textSecondary))),
                  )
                else
                  ..._filtered.map((c) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildCompetitionRow(c),
                      )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Karta FIFA — Mistrzostwa Świata → grupy A–L
  Widget _buildFifaCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const GroupStandingsScreen(
                competitionCode: 'WC', title: 'MŚ 2026 — Grupy'),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xFF1A2A6C), Color(0xFF2A0845)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              CachedNetworkImage(
                imageUrl: 'https://crests.football-data.org/wm26.png',
                width: 48,
                height: 48,
                fit: BoxFit.contain,
                errorWidget: (_, __, ___) =>
                    const Text('🏆', style: TextStyle(fontSize: 40)),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('FIFA',
                            style: TextStyle(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                letterSpacing: 1.5)),
                        SizedBox(width: 6),
                        Text('Mistrzostwa Świata 2026',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14)),
                      ],
                    ),
                    SizedBox(height: 2),
                    Text('Grupy A–L · tabele · awans',
                        style: TextStyle(color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.primaryColor),
            ],
          ),
        ),
      ),
    );
  }

  // Ligi z prawdziwymi tabelami (standings) — kod, nazwa, kolor, emblemat
  static const _leagueCarousel = [
    ('PL', 'Premier League', 'Anglia', Color(0xFF3D195B)),
    ('PD', 'La Liga', 'Hiszpania', Color(0xFFEE8707)),
    ('BL1', 'Bundesliga', 'Niemcy', Color(0xFFD20515)),
    ('SA', 'Serie A', 'Włochy', Color(0xFF008FD7)),
    ('FL1', 'Ligue 1', 'Francja', Color(0xFF091C3E)),
  ];

  Widget _buildLeagueCarousel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            children: [
              Icon(Icons.leaderboard, color: AppTheme.primaryColor, size: 18),
              SizedBox(width: 8),
              Text('TABELE LIG — NA ŻYWO',
                  style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      letterSpacing: 1)),
            ],
          ),
        ),
        SizedBox(
          height: 150,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _leagueCarousel.length,
            itemBuilder: (context, i) {
              final (code, name, country, color) = _leagueCarousel[i];
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          StandingsScreen(initialCompetition: code)),
                ),
                child: Container(
                  width: 140,
                  margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [color.withValues(alpha: 0.85), AppTheme.cardColor],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppTheme.primaryColor.withValues(alpha: 0.25)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        CachedNetworkImage(
                          imageUrl:
                              'https://crests.football-data.org/$code.png',
                          width: 44,
                          height: 44,
                          fit: BoxFit.contain,
                          errorWidget: (_, __, ___) => const Icon(
                              Icons.emoji_events,
                              color: Colors.white,
                              size: 40),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            Text(country,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 11)),
                            const SizedBox(height: 4),
                            const Row(
                              children: [
                                Text('Tabela',
                                    style: TextStyle(
                                        color: AppTheme.primaryColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700)),
                                Icon(Icons.arrow_forward,
                                    color: AppTheme.primaryColor, size: 13),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturedSection() {
    final featured = _competitions.where((c) =>
      c.status == CompetitionStatus.live || c.status == CompetitionStatus.upcoming
    ).take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text('POLECANE', style: TextStyle(color: AppTheme.textTertiary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
        ),
        SizedBox(
          height: 150,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: featured.length,
            itemBuilder: (context, i) => _buildFeaturedCard(featured[i]),
          ),
        ),
        const SizedBox(height: 12),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: Text('WSZYSTKIE', style: TextStyle(color: AppTheme.textTertiary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
        ),
      ],
    );
  }

  Widget _buildFeaturedCard(Competition c) {
    return GestureDetector(
      onTap: () => _openCompetition(c),
      child: Container(
        width: 155,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: c.status == CompetitionStatus.live
                ? AppTheme.primaryColor.withOpacity(0.5)
                : AppTheme.dividerColor,
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.cardColor, AppTheme.surfaceColor],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CachedNetworkImage(
                    imageUrl: c.logoUrl,
                    width: 38,
                    height: 38,
                    fit: BoxFit.contain,
                    errorWidget: (_, __, ___) => Text(c.emoji, style: const TextStyle(fontSize: 30)),
                  ),
                  const Spacer(),
                  _statusBadge(c.status),
                ],
              ),
              const Spacer(),
              Text(c.name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700), maxLines: 2),
              const SizedBox(height: 3),
              if (c.dateRange != null)
                Text(c.dateRange!, style: const TextStyle(color: AppTheme.primaryColor, fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(CompetitionStatus status) {
    switch (status) {
      case CompetitionStatus.live:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
          child: const Text('NA ŻYWO', style: TextStyle(color: Colors.green, fontSize: 8, fontWeight: FontWeight.w800)),
        );
      case CompetitionStatus.upcoming:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: Colors.blue.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
          child: const Text('WKRÓTCE', style: TextStyle(color: Colors.blue, fontSize: 8, fontWeight: FontWeight.w800)),
        );
      case CompetitionStatus.finished:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: BorderRadius.circular(6)),
          child: const Text('KONIEC', style: TextStyle(color: AppTheme.textTertiary, fontSize: 8, fontWeight: FontWeight.w700)),
        );
    }
  }

  Widget _buildList() {
    final list = _filtered;
    if (list.isEmpty) {
      return const Center(child: Text('Brak zawodów', style: TextStyle(color: AppTheme.textSecondary)));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      itemCount: list.length,
      itemBuilder: (context, i) => _buildCompetitionRow(list[i]),
    );
  }

  Widget _buildCompetitionRow(Competition c) {
    return GestureDetector(
      onTap: () => _openCompetition(c),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: c.status == CompetitionStatus.live
                ? AppTheme.primaryColor.withOpacity(0.3)
                : AppTheme.dividerColor,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.all(6),
              child: CachedNetworkImage(
                imageUrl: c.logoUrl,
                fit: BoxFit.contain,
                errorWidget: (_, __, ___) => Center(child: Text(c.emoji, style: const TextStyle(fontSize: 26))),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(c.description, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  if (c.dateRange != null) ...[
                    const SizedBox(height: 3),
                    Text(c.dateRange!, style: const TextStyle(color: AppTheme.primaryColor, fontSize: 11)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _statusBadge(c.status),
                const SizedBox(height: 6),
                const Icon(Icons.chevron_right, color: AppTheme.textTertiary, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openCompetition(Competition c) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RoundsScreen(competition: c)),
    );
  }
}
