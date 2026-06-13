import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/theme/app_theme.dart';
import '../../services/football_data_service.dart';

/// Tabele grupowe turnieju (np. MŚ 2026 — grupy A–L).
class GroupStandingsScreen extends StatefulWidget {
  final String competitionCode;
  final String title;
  const GroupStandingsScreen({
    super.key,
    required this.competitionCode,
    required this.title,
  });

  @override
  State<GroupStandingsScreen> createState() => _GroupStandingsScreenState();
}

class _GroupStandingsScreenState extends State<GroupStandingsScreen> {
  static const Color neonLime = Color(0xFFFFC83D);
  static const Color cardColor = Color(0xFF1A1A1A);

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _groups = [];

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
      final groups =
          await FootballDataService.getGroupStandings(widget.competitionCode);
      if (!mounted) return;
      setState(() {
        _groups = groups;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Nie udało się pobrać grup: $e';
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
        title: Text(widget.title.toUpperCase(),
            style: const TextStyle(
                color: neonLime, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: neonLime))
          : _error != null
              ? Center(
                  child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!,
                          style: const TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        style:
                            ElevatedButton.styleFrom(backgroundColor: neonLime),
                        onPressed: _load,
                        child: const Text('Ponów',
                            style: TextStyle(color: Colors.black)),
                      ),
                    ],
                  ),
                ))
              : RefreshIndicator(
                  color: neonLime,
                  backgroundColor: cardColor,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _groups.length,
                    itemBuilder: (context, i) => _groupCard(_groups[i]),
                  ),
                ),
    );
  }

  Widget _groupCard(Map<String, dynamic> g) {
    final group = (g['group'] as String? ?? '').replaceAll('Group ', 'Grupa ');
    final table = (g['table'] as List? ?? []).cast<Map<String, dynamic>>();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: neonLime.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: neonLime,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(group,
                      style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w800,
                          fontSize: 13)),
                ),
                const Spacer(),
                const Text('M  Z  R  P  Pkt',
                    style: TextStyle(
                        color: Colors.grey,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF2A2A2A)),
          ...table.map((row) => _teamRow(row, table.length)),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _teamRow(Map<String, dynamic> r, int total) {
    final pos = r['position'] as int? ?? 0;
    // Top 2 awansują (zielony), 3. baraż (żółty)
    Color posColor = Colors.grey;
    if (pos <= 2) {
      posColor = neonLime;
    } else if (pos == 3) {
      posColor = Colors.amber;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: Text('$pos',
                style: TextStyle(
                    color: posColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ),
          _crest(r['team_crest'] as String?),
          const SizedBox(width: 8),
          Expanded(
            child: Text(r['team_name'] as String? ?? '',
                style: const TextStyle(color: Colors.white, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          _c('${r['played'] ?? 0}'),
          _c('${r['won'] ?? 0}'),
          _c('${r['draw'] ?? 0}'),
          _c('${r['lost'] ?? 0}'),
          _c('${r['points'] ?? 0}', bold: true, color: neonLime),
        ],
      ),
    );
  }

  Widget _crest(String? url) {
    if (url == null || url.isEmpty) {
      return const Icon(Icons.flag, color: Colors.grey, size: 22);
    }
    if (url.toLowerCase().endsWith('.svg')) {
      return SvgPicture.network(url,
          width: 24,
          height: 24,
          placeholderBuilder: (_) =>
              const Icon(Icons.flag, color: Colors.grey, size: 22));
    }
    return CachedNetworkImage(
      imageUrl: url,
      width: 24,
      height: 24,
      fit: BoxFit.contain,
      errorWidget: (_, __, ___) =>
          const Icon(Icons.flag, color: Colors.grey, size: 22),
    );
  }

  Widget _c(String t, {bool bold = false, Color color = Colors.white}) =>
      SizedBox(
        width: 22,
        child: Text(t,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      );
}
