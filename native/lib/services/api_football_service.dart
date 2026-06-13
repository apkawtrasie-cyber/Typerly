import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config/env_config.dart';

class ApiFootballService {
  static const String _baseUrl = 'https://v3.football.api-sports.io';

  static Future<Map<String, dynamic>> _get(String endpoint) async {
    final key = EnvConfig.apiFootballKey;
    final response = await http.get(
      Uri.parse('$_baseUrl$endpoint'),
      headers: {'x-apisports-key': key},
    );
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('API error ${response.statusCode}');
  }

  // Konwertuje jeden fixture z api-football na Map kompatybilny z Match.fromJson
  static Map<String, dynamic>? fixtureToMatchMap(Map<String, dynamic> fixture) {
    try {
      final f = fixture['fixture'] as Map<String, dynamic>?;
      if (f == null) return null;

      final date = f['date'] as String?;
      if (date == null || date.isEmpty) return null;

      final teams = fixture['teams'] as Map<String, dynamic>?;
      final goals = fixture['goals'] as Map<String, dynamic>?;
      final league = fixture['league'] as Map<String, dynamic>?;
      final home = teams?['home'] as Map<String, dynamic>?;
      final away = teams?['away'] as Map<String, dynamic>?;

      if (home == null || away == null) return null;

      final statusShort =
          ((f['status'] as Map<String, dynamic>?))?['short'] as String? ?? 'NS';

      final String mappedStatus;
      switch (statusShort) {
        case '1H':
        case 'HT':
        case '2H':
        case 'ET':
        case 'BT':
        case 'P':
        case 'LIVE':
          mappedStatus = 'LIVE';
        case 'FT':
        case 'AET':
        case 'PEN':
          mappedStatus = 'FT';
        default:
          mappedStatus = 'NS';
      }

      return {
        'id': 'api_${f['id']}',
        'api_fixture_id': f['id'] as int?,
        'sport_type': (league?['name'] as String?) ?? 'football',
        'home_team_name': (home['name'] as String?) ?? 'Unknown',
        'away_team_name': (away['name'] as String?) ?? 'Unknown',
        'home_team_logo_url': home['logo'] as String?,
        'away_team_logo_url': away['logo'] as String?,
        'match_time': date,
        'status': mappedStatus,
        'home_score': goals?['home'] as int?,
        'away_score': goals?['away'] as int?,
        'is_custom': false,
        'creator_id': null,
        'league_id': null,
        'created_at': DateTime.now().toIso8601String(),
      };
    } catch (_) {
      return null;
    }
  }

  static List<Map<String, dynamic>> _mapFixtures(List list) => list
      .map((e) => fixtureToMatchMap(e as Map<String, dynamic>))
      .where((e) => e != null)
      .cast<Map<String, dynamic>>()
      .toList();

  // Aktualnie trwające mecze na całym świecie
  static Future<List<Map<String, dynamic>>> getLiveFixtures() async {
    final data = await _get('/fixtures?live=all');
    return _mapFixtures(data['response'] as List);
  }

  // Mecze dla konkretnej daty (format YYYY-MM-DD)
  static Future<List<Map<String, dynamic>>> getFixturesByDate(DateTime date) async {
    final d = date.toUtc();
    final dateStr =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final data = await _get('/fixtures?date=$dateStr');
    return _mapFixtures(data['response'] as List);
  }

  // Statystyki meczu (posiadanie, strzały, faule…)
  static Future<List<Map<String, dynamic>>> getMatchStatistics(int fixtureId) async {
    final data = await _get('/fixtures/statistics?fixture=$fixtureId');
    final list = data['response'] as List;
    return list.cast<Map<String, dynamic>>();
  }

  // Składy (Starting XI + formacja)
  static Future<List<Map<String, dynamic>>> getMatchLineups(int fixtureId) async {
    final data = await _get('/fixtures/lineups?fixture=$fixtureId');
    final list = data['response'] as List;
    return list.cast<Map<String, dynamic>>();
  }

  static Future<List<String>> getRounds(int leagueId, int season) async {
    final data = await _get('/fixtures/rounds?league=$leagueId&season=$season');
    final list = data['response'] as List;
    return list.map((e) => e.toString()).toList();
  }

  static Future<List<Map<String, dynamic>>> getFixtures({
    required int leagueId,
    required int season,
    String? round,
  }) async {
    var url = '/fixtures?league=$leagueId&season=$season';
    if (round != null) url += '&round=${Uri.encodeComponent(round)}';
    final data = await _get(url);
    final list = data['response'] as List;
    return list.map((e) => e as Map<String, dynamic>).toList();
  }

  static Future<List<Map<String, dynamic>>> getTeams(int leagueId, int season) async {
    final data = await _get('/teams?league=$leagueId&season=$season');
    final list = data['response'] as List;
    return list.map((e) => e as Map<String, dynamic>).toList();
  }

  static Future<Map<String, dynamic>?> getLeagueInfo(int leagueId, int season) async {
    final data = await _get('/leagues?id=$leagueId&season=$season');
    final list = data['response'] as List;
    if (list.isEmpty) return null;
    return list.first as Map<String, dynamic>;
  }
}
