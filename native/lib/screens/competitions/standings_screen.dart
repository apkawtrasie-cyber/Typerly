import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';

class StandingsScreen extends StatefulWidget {
  final String? initialCompetition;
  const StandingsScreen({super.key, this.initialCompetition});

  @override
  State<StandingsScreen> createState() => _StandingsScreenState();
}

class _StandingsScreenState extends State<StandingsScreen> {
  static const Color neonLime = Color(0xFFFFC83D);
  static const Color cardColor = Color(0xFF1A1A1A);

  // Ligi dostępne w tabeli standings (kod -> nazwa)
  static const _leagues = [
    ('PL', 'Premier League', '🏴'),
    ('PD', 'La Liga', '🇪🇸'),
    ('BL1', 'Bundesliga', '🇩🇪'),
    ('SA', 'Serie A', '🇮🇹'),
    ('FL1', 'Ligue 1', '🇫🇷'),
  ];

  late String _selected = widget.initialCompetition ?? 'PL';
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _standings = [];
  List<Map<String, dynamic>> _scorers = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final db = Supabase.instance.client;
      final results = await Future.wait([
        db
            .from('standings')
            .select()
            .eq('competition', _selected)
            .order('position', ascending: true),
        db
            .from('top_scorers')
            .select()
            .eq('competition', _selected)
            .order('goals', ascending: false)
            .limit(10),
      ]);
      if (!mounted) return;
      setState(() {
        _standings = (results[0] as List).cast<Map<String, dynamic>>();
        _scorers = (results[1] as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Błąd ładowania: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        iconTheme: const IconThemeData(color: neonLime),
        title: const Text('TABELE LIG',
            style: TextStyle(
                color: neonLime, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
      ),
      body: Column(
        children: [
          _leagueSelector(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: neonLime))
                : _error != null
                    ? Center(
                        child: Text(_error!,
                            style: const TextStyle(color: Colors.grey)))
                    : RefreshIndicator(
                        color: neonLime,
                        backgroundColor: cardColor,
                        onRefresh: _load,
                        child: ListView(
                          padding: const EdgeInsets.all(12),
                          children: [
                            _standingsTable(),
                            const SizedBox(height: 24),
                            _topScorers(),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _leagueSelector() {
    return SizedBox(
      height: 56,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: _leagues.length,
        itemBuilder: (context, i) {
          final (code, name, emoji) = _leagues[i];
          final selected = code == _selected;
          return GestureDetector(
            onTap: () {
              if (_selected != code) {
                setState(() => _selected = code);
                _load();
              }
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? neonLime : cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: selected ? neonLime : Colors.grey.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Text(name,
                      style: TextStyle(
                          color: selected ? Colors.black : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _standingsTable() {
    if (_standings.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
            child: Text('Brak danych tabeli',
                style: TextStyle(color: Colors.grey))),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Nagłówek
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                const SizedBox(width: 28, child: Text('#', style: _hStyle)),
                const Expanded(child: Text('Drużyna', style: _hStyle)),
                _headCell('M'),
                _headCell('Z'),
                _headCell('R'),
                _headCell('P'),
                _headCell('+/-'),
                _headCell('Pkt', bold: true),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF2A2A2A)),
          ..._standings.map(_standingRow),
        ],
      ),
    );
  }

  Widget _standingRow(Map<String, dynamic> r) {
    final pos = r['position'] as int? ?? 0;
    // Kolor strefy: 1-4 LM (zielony), 5-6 EL (niebieski), spadki (czerwony)
    Color posColor = Colors.grey;
    if (pos <= 4) {
      posColor = neonLime;
    } else if (pos <= 6) {
      posColor = Colors.blueAccent;
    } else if (pos >= _standings.length - 2) {
      posColor = Colors.redAccent;
    }

    final logo = r['team_logo_url'] as String?;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text('$pos',
                style: TextStyle(
                    color: posColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ),
          _teamLogo(logo),
          const SizedBox(width: 8),
          Expanded(
            child: Text(r['team_name'] as String? ?? '',
                style: const TextStyle(color: Colors.white, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          _cell('${r['played'] ?? 0}'),
          _cell('${r['won'] ?? 0}'),
          _cell('${r['draw'] ?? 0}'),
          _cell('${r['lost'] ?? 0}'),
          _cell('${r['goal_difference'] ?? 0}'),
          _cell('${r['points'] ?? 0}', bold: true, color: neonLime),
        ],
      ),
    );
  }

  Widget _topScorers() {
    if (_scorers.isEmpty) return const SizedBox();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.sports_soccer, color: neonLime, size: 18),
              SizedBox(width: 8),
              Text('KRÓLOWIE STRZELCÓW',
                  style: TextStyle(
                      color: neonLime,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 12),
          ..._scorers.asMap().entries.map((e) {
            final i = e.key;
            final s = e.value;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                      width: 24,
                      child: Text('${i + 1}',
                          style: TextStyle(
                              color: i == 0 ? neonLime : Colors.grey,
                              fontWeight: FontWeight.bold))),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s['player_name'] as String? ?? '',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        Text(s['team_name'] as String? ?? '',
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 11)),
                      ],
                    ),
                  ),
                  Text('${s['goals'] ?? 0}',
                      style: const TextStyle(
                          color: neonLime,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  const Text(' G',
                      style: TextStyle(color: Colors.grey, fontSize: 11)),
                  if (s['assists'] != null) ...[
                    const SizedBox(width: 10),
                    Text('${s['assists']}',
                        style: const TextStyle(
                            color: Colors.blueAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                    const Text(' A',
                        style: TextStyle(color: Colors.grey, fontSize: 11)),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _teamLogo(String? url) {
    if (url == null || url.isEmpty) {
      return const Icon(Icons.shield, color: Colors.grey, size: 22);
    }
    if (url.toLowerCase().endsWith('.svg')) {
      return SvgPicture.network(url,
          width: 22,
          height: 22,
          placeholderBuilder: (_) =>
              const Icon(Icons.shield, color: Colors.grey, size: 22));
    }
    return CachedNetworkImage(
      imageUrl: url,
      width: 22,
      height: 22,
      fit: BoxFit.contain,
      errorWidget: (_, __, ___) =>
          const Icon(Icons.shield, color: Colors.grey, size: 22),
    );
  }

  static const _hStyle = TextStyle(
      color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold);

  Widget _headCell(String t, {bool bold = false}) =>
      SizedBox(width: 30, child: Text(t, textAlign: TextAlign.center, style: _hStyle));

  Widget _cell(String t, {bool bold = false, Color color = Colors.white}) =>
      SizedBox(
        width: 30,
        child: Text(t,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      );
}
