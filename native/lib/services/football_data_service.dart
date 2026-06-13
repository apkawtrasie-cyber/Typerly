import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config/env_config.dart';

/// Klient football-data.org v4 (darmowy plan: 10 req/min, top ligi + MŚ).
class FootballDataService {
  static const String _base = 'https://api.football-data.org/v4';

  static Future<Map<String, dynamic>> _get(String path) async {
    final res = await http.get(
      Uri.parse('$_base$path'),
      headers: {'X-Auth-Token': EnvConfig.footballDataToken},
    );
    if (res.statusCode == 200) {
      return json.decode(res.body) as Map<String, dynamic>;
    }
    throw Exception('football-data ${res.statusCode}');
  }

  /// Tabele grup turnieju (np. MŚ A–L). Zwraca listę grup z drużynami.
  static Future<List<Map<String, dynamic>>> getGroupStandings(
      String competitionCode) async {
    final data = await _get('/competitions/$competitionCode/standings');
    final blocks = (data['standings'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .where((b) => b['type'] == 'TOTAL')
        .toList();

    return blocks.map((b) {
      final table = (b['table'] as List? ?? []).cast<Map<String, dynamic>>();
      return {
        'group': b['group'] as String? ?? '',
        'table': table.map((row) {
          final team = row['team'] as Map<String, dynamic>? ?? {};
          return {
            'position': row['position'],
            'team_name': team['shortName'] ?? team['name'] ?? '?',
            'team_crest': team['crest'],
            'played': row['playedGames'],
            'won': row['won'],
            'draw': row['draw'],
            'lost': row['lost'],
            'points': row['points'],
            'goals_for': row['goalsFor'],
            'goals_against': row['goalsAgainst'],
            'goal_difference': row['goalDifference'],
          };
        }).toList(),
      };
    }).toList();
  }
}
