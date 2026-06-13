// Uruchamianie: dart run scripts/sync_fixtures.dart
// Opcje:
//   --update    aktualizuje też istniejące mecze (wyniki, status)
//   --league=1  synchronizuje tylko jedną ligę (po ID api-football)

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

// ─── Konfiguracja ────────────────────────────────────────────────────────────

// Sekrety czytane ze zmiennych środowiskowych — NIE hardkodujemy ich w repo.
// Uruchamianie: dart run scripts/sync_fixtures.dart \
//   --define=API_KEY=... --define=SUPABASE_URL=... --define=SUPABASE_KEY=...
const String kApiKey = String.fromEnvironment('API_KEY');
const String kApiBase = 'https://v3.football.api-sports.io';
const String kSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
const String kSupabaseKey = String.fromEnvironment('SUPABASE_KEY');

// Zawody do synchronizacji – odpowiadają competitions_screen.dart
const List<Map<String, dynamic>> kCompetitions = [
  {'id': 1,   'season': 2026, 'name': 'World Cup 2026'},
  {'id': 2,   'season': 2025, 'name': 'Champions League 2025/26'},
  {'id': 3,   'season': 2025, 'name': 'Europa League 2025/26'},
  {'id': 15,  'season': 2025, 'name': 'Club World Cup 2025'},
  {'id': 6,   'season': 2025, 'name': 'AFCON 2025'},
  {'id': 30,  'season': 2025, 'name': 'Gold Cup 2025'},
  {'id': 35,  'season': 2025, 'name': 'Euro Kobiet 2025'},
  {'id': 39,  'season': 2025, 'name': 'Premier League 2025/26'},
  {'id': 140, 'season': 2025, 'name': 'La Liga 2025/26'},
  {'id': 78,  'season': 2025, 'name': 'Bundesliga 2025/26'},
  {'id': 135, 'season': 2025, 'name': 'Serie A 2025/26'},
  {'id': 106, 'season': 2025, 'name': 'Ekstraklasa 2025/26'},
];

// ─── Mapowanie statusów api-football → app ───────────────────────────────────

String _mapStatus(String s) {
  switch (s) {
    case '1H':
    case 'HT':
    case '2H':
    case 'ET':
    case 'BT':
    case 'P':
    case 'LIVE':
      return 'LIVE';
    case 'FT':
    case 'AET':
    case 'PEN':
      return 'FT';
    default:
      return 'NS';
  }
}

// ─── API-Football ─────────────────────────────────────────────────────────────

Future<List<Map<String, dynamic>>> _fetchFixtures(int leagueId, int season) async {
  final uri = Uri.parse('$kApiBase/fixtures?league=$leagueId&season=$season');
  final res = await http.get(uri, headers: {'x-apisports-key': kApiKey});

  if (res.statusCode != 200) {
    throw Exception('API ${res.statusCode}: ${res.body}');
  }

  final body = json.decode(res.body) as Map<String, dynamic>;
  final errors = body['errors'];
  if (errors is Map && errors.isNotEmpty) {
    throw Exception('API errors: $errors');
  }

  final list = body['response'] as List;
  return list.cast<Map<String, dynamic>>();
}

// ─── Supabase ────────────────────────────────────────────────────────────────

Map<String, String> get _headers => {
      'apikey': kSupabaseKey,
      'Authorization': 'Bearer $kSupabaseKey',
      'Content-Type': 'application/json',
    };

Future<Set<int>> _getExistingFixtureIds() async {
  final uri = Uri.parse(
    '$kSupabaseUrl/rest/v1/matches?select=api_fixture_id&api_fixture_id=not.is.null&limit=50000',
  );
  final res = await http.get(uri, headers: _headers);

  if (res.statusCode != 200) throw Exception('Supabase GET: ${res.body}');

  final list = json.decode(res.body) as List;
  return list
      .map((e) => e['api_fixture_id'] as int?)
      .whereType<int>()
      .toSet();
}

Future<void> _upsertBatch(List<Map<String, dynamic>> rows) async {
  final uri = Uri.parse('$kSupabaseUrl/rest/v1/matches');
  final res = await http.post(
    uri,
    headers: {
      ..._headers,
      'Prefer': 'resolution=merge-duplicates,return=minimal',
    },
    body: json.encode(rows),
  );

  if (res.statusCode != 200 && res.statusCode != 201) {
    throw Exception('Supabase POST ${res.statusCode}: ${res.body}');
  }
}

// ─── Mapowanie fixture → wiersz bazy ─────────────────────────────────────────

Map<String, dynamic>? _toRow(Map<String, dynamic> fixture) {
  try {
    final f = fixture['fixture'] as Map<String, dynamic>;
    final teams = fixture['teams'] as Map<String, dynamic>;
    final goals = fixture['goals'] as Map<String, dynamic>;
    final home = teams['home'] as Map<String, dynamic>;
    final away = teams['away'] as Map<String, dynamic>;
    final dateStr = f['date'] as String?;

    if (dateStr == null) return null;

    final statusShort = (f['status'] as Map<String, dynamic>)['short'] as String? ?? 'NS';

    return {
      'api_fixture_id': f['id'] as int,
      'sport_type': 'football',
      'home_team_name': home['name'] as String,
      'away_team_name': away['name'] as String,
      'home_team_logo_url': home['logo'] as String?,
      'away_team_logo_url': away['logo'] as String?,
      'match_time': dateStr,
      'status': _mapStatus(statusShort),
      'home_score': goals['home'] as int?,
      'away_score': goals['away'] as int?,
      'is_custom': false,
    };
  } catch (_) {
    return null;
  }
}

// ─── Main ─────────────────────────────────────────────────────────────────────

void main(List<String> args) async {
  final doUpdate = args.contains('--update');
  final onlyLeague = args
      .where((a) => a.startsWith('--league='))
      .map((a) => int.tryParse(a.split('=').last))
      .whereType<int>()
      .firstOrNull;

  final competitions = onlyLeague != null
      ? kCompetitions.where((c) => c['id'] == onlyLeague).toList()
      : kCompetitions;

  if (competitions.isEmpty) {
    print('❌ Nie znaleziono ligi o ID $onlyLeague');
    exit(1);
  }

  print('🚀  Typerly — Sync Fixtures');
  print('    Tryb: ${doUpdate ? "insert + update" : "tylko nowe"}');
  print('    Zawody: ${competitions.length}');
  print('=' * 48);

  // Pobierz istniejące ID (potrzebne tylko gdy NIE aktualizujemy)
  Set<int> existingIds = {};
  if (!doUpdate) {
    stdout.write('\n📋 Pobieranie istniejących ID z Supabase...');
    existingIds = await _getExistingFixtureIds();
    print(' ${existingIds.length} rekordów');
  }

  int totalInserted = 0;
  int totalUpdated = 0;
  int totalSkipped = 0;
  int requestCount = 0;

  for (final comp in competitions) {
    final leagueId = comp['id'] as int;
    final season = comp['season'] as int;
    final name = comp['name'] as String;

    print('\n📡  $name  (league=$leagueId, season=$season)');

    List<Map<String, dynamic>> fixtures;
    try {
      fixtures = await _fetchFixtures(leagueId, season);
      requestCount++;
      print('    Pobrano ${fixtures.length} meczów z API');
    } catch (e) {
      print('    ❌ Błąd API: $e');
      // Czekaj dłużej po błędzie (rate limit)
      await Future.delayed(const Duration(seconds: 5));
      continue;
    }

    final toInsert = <Map<String, dynamic>>[];
    final toUpdate = <Map<String, dynamic>>[];

    for (final fixture in fixtures) {
      final row = _toRow(fixture);
      if (row == null) continue;

      final fixtureId = row['api_fixture_id'] as int;

      if (doUpdate) {
        toUpdate.add(row);
      } else if (!existingIds.contains(fixtureId)) {
        toInsert.add(row);
        existingIds.add(fixtureId);
      } else {
        totalSkipped++;
      }
    }

    final rows = doUpdate ? toUpdate : toInsert;
    print('    Nowych: ${toInsert.length}  |  Pominiętych: ${fixtures.length - toInsert.length}');

    if (rows.isNotEmpty) {
      try {
        // Wsadowe wysyłanie po 100
        for (var i = 0; i < rows.length; i += 100) {
          final end = (i + 100).clamp(0, rows.length);
          await _upsertBatch(rows.sublist(i, end));
          stdout.write('.');
        }
        print('\n    ✅ Zapisano ${rows.length} rekordów');

        if (doUpdate) {
          totalUpdated += rows.length;
        } else {
          totalInserted += rows.length;
        }
      } catch (e) {
        print('\n    ❌ Błąd zapisu: $e');
      }
    }

    // Przerwa między żądaniami – api-football free: 10 req/min
    if (requestCount % 10 == 0) {
      print('\n⏸️  Przerwa 60s (limit API)...');
      await Future.delayed(const Duration(seconds: 60));
    } else {
      await Future.delayed(const Duration(seconds: 7));
    }
  }

  print('\n${'=' * 48}');
  print('✅  Sync zakończony!');
  print('    Dodano:      $totalInserted meczów');
  if (doUpdate) print('    Zaktualizowano: $totalUpdated meczów');
  print('    Pominięto:   $totalSkipped (już istniały)');
  print('    Żądań API:   $requestCount / ${competitions.length}');
}
