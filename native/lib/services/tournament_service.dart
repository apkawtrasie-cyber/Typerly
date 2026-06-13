import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';

class TournamentService {
  static final SupabaseClient _client = SupabaseConfig.client;
  static final _picker = ImagePicker();

  // ── Turnieje ──────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> createTournament({
    required String name,
    required String adminId,
    required String inviteCode,
    String? prizeDescription,
  }) async {
    final resp = await _client.from('custom_tournaments').insert({
      'name': name,
      'admin_id': adminId,
      'invite_code': inviteCode.toUpperCase(),
      'prize_description': prizeDescription,
    }).select().single();

    // Auto-dodaj twórcę jako członka
    await _client.from('tournament_members').insert({
      'tournament_id': resp['id'],
      'user_id': adminId,
    });

    return resp as Map<String, dynamic>;
  }

  static Future<List<Map<String, dynamic>>> getUserTournaments(String userId) async {
    try {
      final adminResp = await _client
          .from('custom_tournaments')
          .select()
          .eq('admin_id', userId);

      final memberResp = await _client
          .from('tournament_members')
          .select('tournament_id')
          .eq('user_id', userId);

      final memberIds = (memberResp as List)
          .map((r) => r['tournament_id'] as String)
          .toList();

      final all = <String, Map<String, dynamic>>{};
      for (final t in (adminResp as List)) {
        all[t['id'] as String] = t as Map<String, dynamic>;
      }

      if (memberIds.isNotEmpty) {
        final memberTResp = await _client
            .from('custom_tournaments')
            .select()
            .inFilter('id', memberIds);
        for (final t in (memberTResp as List)) {
          all[t['id'] as String] = t as Map<String, dynamic>;
        }
      }

      return all.values.toList()
        ..sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));
    } catch (_) {
      return [];
    }
  }

  static Future<Map<String, dynamic>?> joinTournament(
      String inviteCode, String userId) async {
    final t = await _client
        .from('custom_tournaments')
        .select()
        .eq('invite_code', inviteCode.toUpperCase())
        .maybeSingle();
    if (t == null) return null;

    await _client.from('tournament_members').upsert({
      'tournament_id': t['id'],
      'user_id': userId,
    });
    return t as Map<String, dynamic>;
  }

  // ── Drużyny ───────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> addTeam({
    required String tournamentId,
    required String name,
    File? logoFile,
    String? existingLogoUrl,
  }) async {
    String? logoUrl = existingLogoUrl;
    if (logoFile != null) {
      logoUrl = await _uploadLogo(tournamentId, logoFile);
    }

    final resp = await _client.from('custom_teams').insert({
      'tournament_id': tournamentId,
      'name': name,
      'logo_url': logoUrl,
    }).select().single();

    // Zapisz do biblioteki drużyn użytkownika (ignoruj konflikt jeśli już istnieje)
    try {
      await _client.from('user_teams').upsert({
        'user_id': _client.auth.currentUser!.id,
        'name': name,
        'logo_url': logoUrl,
      }, onConflict: 'user_id,name');
    } catch (_) {}

    return resp as Map<String, dynamic>;
  }

  static Future<void> deleteTeam(String teamId) async {
    await _client.from('custom_teams').delete().eq('id', teamId);
  }

  static Future<List<Map<String, dynamic>>> getUserTeams() async {
    try {
      final resp = await _client
          .from('user_teams')
          .select()
          .order('name');
      return List<Map<String, dynamic>>.from(resp as List);
    } catch (_) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getTeams(String tournamentId) async {
    final resp = await _client
        .from('custom_teams')
        .select()
        .eq('tournament_id', tournamentId)
        .order('created_at');
    return List<Map<String, dynamic>>.from(resp as List);
  }

  static Future<String> _uploadLogo(String tournamentId, File file) async {
    final ext = file.path.split('.').last.toLowerCase();
    final path = 'tournament-logos/$tournamentId/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _client.storage.from('team-logos').upload(path, file);
    return _client.storage.from('team-logos').getPublicUrl(path);
  }

  // ── Mecze ────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> createMatch({
    required String tournamentId,
    required Map<String, dynamic> homeTeam,
    required Map<String, dynamic> awayTeam,
    required DateTime matchTime,
    String? roundName,
  }) async {
    final resp = await _client.from('custom_matches').insert({
      'tournament_id': tournamentId,
      'home_team_id': homeTeam['id'],
      'away_team_id': awayTeam['id'],
      'home_team_name': homeTeam['name'],
      'away_team_name': awayTeam['name'],
      'home_team_logo': homeTeam['logo_url'],
      'away_team_logo': awayTeam['logo_url'],
      'match_time': matchTime.toIso8601String(),
      'round_name': roundName,
    }).select().single();
    return resp as Map<String, dynamic>;
  }

  static Future<List<Map<String, dynamic>>> getMatches(String tournamentId) async {
    final resp = await _client
        .from('custom_matches')
        .select()
        .eq('tournament_id', tournamentId)
        .order('match_time');
    return List<Map<String, dynamic>>.from(resp as List);
  }

  static Future<void> setResult({
    required String matchId,
    required int homeScore,
    required int awayScore,
  }) async {
    await _client.from('custom_matches').update({
      'home_score': homeScore,
      'away_score': awayScore,
      'status': 'FT',
    }).eq('id', matchId);
  }

  // ── Członkowie ────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getMembers(String tournamentId) async {
    final resp = await _client
        .from('tournament_members')
        .select('*, profiles(username, avatar_url)')
        .eq('tournament_id', tournamentId);
    return List<Map<String, dynamic>>.from(resp as List);
  }

  // ── Typy ──────────────────────────────────────────────────────────────────

  static Future<void> savePrediction({
    required String tournamentId,
    required String matchId,
    required String userId,
    required int homeScore,
    required int awayScore,
  }) async {
    await _client.from('tournament_predictions').upsert({
      'tournament_id': tournamentId,
      'custom_match_id': matchId,
      'user_id': userId,
      'predicted_home_score': homeScore,
      'predicted_away_score': awayScore,
      'is_calculated': false,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'custom_match_id,user_id');
  }

  static Future<List<Map<String, dynamic>>> getMatchPredictions(
      String matchId) async {
    final resp = await _client
        .from('tournament_predictions')
        .select('*, profiles(username, avatar_url)')
        .eq('custom_match_id', matchId)
        .order('updated_at', ascending: false);
    return List<Map<String, dynamic>>.from(resp as List);
  }

  // ── Faza grupowa ─────────────────────────────────────────────────────────

  /// Tworzy grupy, przypisuje drużyny i generuje mecze round-robin.
  /// [groupTeams] = { 'A': [teamId1, teamId2, ...], 'B': [...], ... }
  static Future<void> setupGroupPhase({
    required String tournamentId,
    required Map<String, List<String>> groupTeams,
    required List<Map<String, dynamic>> allTeams,
  }) async {
    // Usuń poprzednie grupy (cascade usuwa przypisania i mecze grupowe)
    await _client
        .from('custom_matches')
        .delete()
        .eq('tournament_id', tournamentId)
        .eq('match_phase', 'group');

    await _client
        .from('tournament_groups')
        .delete()
        .eq('tournament_id', tournamentId);

    final teamMap = {for (final t in allTeams) t['id'] as String: t};

    for (final entry in groupTeams.entries) {
      if (entry.value.length < 2) continue;

      // Utwórz grupę
      final groupResp = await _client.from('tournament_groups').insert({
        'tournament_id': tournamentId,
        'name': entry.key,
      }).select().single();
      final groupId = groupResp['id'] as String;

      // Przypisz drużyny do grupy
      await _client.from('group_team_assignments').insert(
        entry.value.map((tid) => {'group_id': groupId, 'team_id': tid}).toList(),
      );

      // Generuj mecze round-robin
      final teamIds = entry.value;
      final baseTime = DateTime.now().add(const Duration(days: 1));
      var matchIndex = 0;

      for (var i = 0; i < teamIds.length; i++) {
        for (var j = i + 1; j < teamIds.length; j++) {
          final home = teamMap[teamIds[i]]!;
          final away = teamMap[teamIds[j]]!;
          final matchTime = baseTime.add(Duration(days: matchIndex ~/ 2, hours: matchIndex % 2 == 0 ? 0 : 3));

          await _client.from('custom_matches').insert({
            'tournament_id': tournamentId,
            'home_team_id': home['id'],
            'away_team_id': away['id'],
            'home_team_name': home['name'],
            'away_team_name': away['name'],
            'home_team_logo': home['logo_url'],
            'away_team_logo': away['logo_url'],
            'match_time': matchTime.toIso8601String(),
            'round_name': 'Grupa ${entry.key}',
            'group_id': groupId,
            'match_phase': 'group',
          });
          matchIndex++;
        }
      }
    }
  }

  static Future<List<Map<String, dynamic>>> getGroupsWithTeams(String tournamentId) async {
    final groups = await _client
        .from('tournament_groups')
        .select()
        .eq('tournament_id', tournamentId)
        .order('name');

    final result = <Map<String, dynamic>>[];
    for (final g in (groups as List)) {
      final assignments = await _client
          .from('group_team_assignments')
          .select('team_id')
          .eq('group_id', g['id'] as String);

      final teamIds = (assignments as List).map((a) => a['team_id'] as String).toList();
      final teams = <Map<String, dynamic>>[];
      if (teamIds.isNotEmpty) {
        final tr = await _client
            .from('custom_teams')
            .select()
            .inFilter('id', teamIds);
        teams.addAll((tr as List).cast<Map<String, dynamic>>());
      }

      result.add({...g as Map<String, dynamic>, 'teams': teams});
    }
    return result;
  }

  /// Oblicza tabelę grupy na podstawie meczów.
  /// Zwraca listę drużyn z: played/wins/draws/losses/gf/ga/gd/points
  static List<Map<String, dynamic>> calculateGroupStandings(
      List<Map<String, dynamic>> groupTeams,
      List<Map<String, dynamic>> groupMatches) {
    final stats = <String, Map<String, dynamic>>{};

    for (final t in groupTeams) {
      stats[t['id'] as String] = {
        'team': t,
        'played': 0, 'wins': 0, 'draws': 0, 'losses': 0,
        'gf': 0, 'ga': 0, 'gd': 0, 'points': 0,
      };
    }

    for (final m in groupMatches) {
      if (m['status'] != 'FT') continue;
      final hId = m['home_team_id'] as String?;
      final aId = m['away_team_id'] as String?;
      final hScore = m['home_score'] as int? ?? 0;
      final aScore = m['away_score'] as int? ?? 0;

      if (hId == null || aId == null) continue;
      if (!stats.containsKey(hId) || !stats.containsKey(aId)) continue;

      stats[hId]!['played'] = (stats[hId]!['played'] as int) + 1;
      stats[aId]!['played'] = (stats[aId]!['played'] as int) + 1;
      stats[hId]!['gf'] = (stats[hId]!['gf'] as int) + hScore;
      stats[hId]!['ga'] = (stats[hId]!['ga'] as int) + aScore;
      stats[aId]!['gf'] = (stats[aId]!['gf'] as int) + aScore;
      stats[aId]!['ga'] = (stats[aId]!['ga'] as int) + hScore;

      if (hScore > aScore) {
        stats[hId]!['wins'] = (stats[hId]!['wins'] as int) + 1;
        stats[hId]!['points'] = (stats[hId]!['points'] as int) + 3;
        stats[aId]!['losses'] = (stats[aId]!['losses'] as int) + 1;
      } else if (hScore == aScore) {
        stats[hId]!['draws'] = (stats[hId]!['draws'] as int) + 1;
        stats[hId]!['points'] = (stats[hId]!['points'] as int) + 1;
        stats[aId]!['draws'] = (stats[aId]!['draws'] as int) + 1;
        stats[aId]!['points'] = (stats[aId]!['points'] as int) + 1;
      } else {
        stats[aId]!['wins'] = (stats[aId]!['wins'] as int) + 1;
        stats[aId]!['points'] = (stats[aId]!['points'] as int) + 3;
        stats[hId]!['losses'] = (stats[hId]!['losses'] as int) + 1;
      }
    }

    for (final s in stats.values) {
      s['gd'] = (s['gf'] as int) - (s['ga'] as int);
    }

    final list = stats.values.toList();
    list.sort((a, b) {
      final pts = (b['points'] as int).compareTo(a['points'] as int);
      if (pts != 0) return pts;
      final gd = (b['gd'] as int).compareTo(a['gd'] as int);
      if (gd != 0) return gd;
      return (b['gf'] as int).compareTo(a['gf'] as int);
    });
    return list;
  }

  // ── Drabinka pucharowa ────────────────────────────────────────────────────

  /// Generuje drabinkę knockout na podstawie końcowej tabeli grup.
  /// [teamsPerGroup] = ile drużyn awansuje z każdej grupy
  static Future<void> generateKnockout({
    required String tournamentId,
    required int teamsPerGroup,
    required List<Map<String, dynamic>> groupsWithTeams,
    required List<Map<String, dynamic>> allMatches,
  }) async {
    // Usuń poprzednie mecze knockout
    await _client
        .from('custom_matches')
        .delete()
        .eq('tournament_id', tournamentId)
        .eq('match_phase', 'knockout');

    // Zbierz awansujące drużyny z każdej grupy
    final advancing = <Map<String, dynamic>>[];
    for (final g in groupsWithTeams) {
      final gMatches = allMatches
          .where((m) => m['group_id'] == g['id'] && m['match_phase'] == 'group')
          .toList();
      final standings = calculateGroupStandings(
          List<Map<String, dynamic>>.from(g['teams'] as List),
          gMatches);
      final take = standings.take(teamsPerGroup).toList();
      for (var i = 0; i < take.length; i++) {
        advancing.add({
          ...take[i],
          'source_label': '${i + 1}. Gr. ${g['name']}',
        });
      }
    }

    if (advancing.length < 2) return;

    // Oblicz liczbę rund (potęga 2)
    var slots = 1;
    while (slots < advancing.length) slots *= 2;

    // Utwórz bracket: seeding 1 vs ostatni, 2 vs przedostatni, itd.
    final seeded = <Map<String, dynamic>?>[];
    for (var i = 0; i < slots; i++) {
      seeded.add(i < advancing.length ? advancing[i] : null);
    }

    final baseTime = DateTime.now().add(const Duration(days: 14));
    final roundNames = {1: 'Finał', 2: 'Półfinał', 4: 'Ćwierćfinał', 8: '1/8 finału'};

    // Generuj pierwszą rundę knockout
    final matchIds = <int, String>{}; // slot index → match id
    final firstRoundMatches = slots ~/ 2;

    for (var i = 0; i < firstRoundMatches; i++) {
      final home = seeded[i];
      final away = seeded[slots - 1 - i];
      final roundSize = firstRoundMatches;
      final roundName = roundNames[roundSize] ?? 'Faza pucharowa';

      final resp = await _client.from('custom_matches').insert({
        'tournament_id': tournamentId,
        'home_team_id': home?['team']?['id'],
        'away_team_id': away?['team']?['id'],
        'home_team_name': home?['team']?['name'] ?? home?['source_label'] ?? 'TBD',
        'away_team_name': away?['team']?['name'] ?? away?['source_label'] ?? 'TBD',
        'home_team_logo': home?['team']?['logo_url'],
        'away_team_logo': away?['team']?['logo_url'],
        'home_source': home?['source_label'],
        'away_source': away?['source_label'],
        'match_time': baseTime.add(Duration(hours: i * 2)).toIso8601String(),
        'round_name': roundName,
        'match_phase': 'knockout',
        'knockout_round': roundSize,
        'knockout_slot': i,
      }).select().single();
      matchIds[i] = resp['id'] as String;
    }

    // Generuj kolejne rundy (puste mecze czekające na wyniki)
    var currentRound = firstRoundMatches ~/ 2;
    var dayOffset = 7;
    while (currentRound >= 1) {
      final roundName = roundNames[currentRound] ?? 'Faza pucharowa';
      for (var i = 0; i < currentRound; i++) {
        await _client.from('custom_matches').insert({
          'tournament_id': tournamentId,
          'home_team_name': 'Mecz ${i * 2 + 1}',
          'away_team_name': 'Mecz ${i * 2 + 2}',
          'home_team_id': null,
          'away_team_id': null,
          'match_time': baseTime.add(Duration(days: dayOffset, hours: i * 2)).toIso8601String(),
          'round_name': roundName,
          'match_phase': 'knockout',
          'knockout_round': currentRound,
          'knockout_slot': i,
        });
      }
      currentRound ~/= 2;
      dayOffset += 7;
    }
  }

  /// Generuje bezpośredni puchar (bez fazy grupowej) z listy drużyn.
  static Future<void> generateDirectKnockout({
    required String tournamentId,
    required List<Map<String, dynamic>> teams,
  }) async {
    await _client
        .from('custom_matches')
        .delete()
        .eq('tournament_id', tournamentId)
        .eq('match_phase', 'knockout');

    if (teams.length < 2) return;

    var slots = 1;
    while (slots < teams.length) slots *= 2;

    final seeded = <Map<String, dynamic>?>[];
    for (var i = 0; i < slots; i++) {
      seeded.add(i < teams.length ? teams[i] : null);
    }

    final baseTime = DateTime.now().add(const Duration(days: 1));
    final roundNames = {1: 'Finał', 2: 'Półfinał', 4: 'Ćwierćfinał', 8: '1/8 finału'};
    final firstRoundMatches = slots ~/ 2;

    // Teams that get automatic byes (opponent slot is null) — keyed by first-round slot index
    final Map<int, Map<String, dynamic>> byeTeams = {};

    for (var i = 0; i < firstRoundMatches; i++) {
      final home = seeded[i];
      final away = seeded[slots - 1 - i];

      if (home == null && away == null) continue;

      if (home == null || away == null) {
        // One team has no opponent — auto-advance without creating a match
        byeTeams[i] = (home ?? away)!;
        continue;
      }

      final roundName = roundNames[firstRoundMatches] ?? 'Faza pucharowa';
      await _client.from('custom_matches').insert({
        'tournament_id': tournamentId,
        'home_team_id': home['id'],
        'away_team_id': away['id'],
        'home_team_name': home['name'],
        'away_team_name': away['name'],
        'home_team_logo': home['logo_url'],
        'away_team_logo': away['logo_url'],
        'match_time': baseTime.add(Duration(hours: i * 2)).toIso8601String(),
        'round_name': roundName,
        'match_phase': 'knockout',
        'knockout_round': firstRoundMatches,
        'knockout_slot': i,
      });
    }

    // Build subsequent rounds; pre-fill any slots whose first-round opponent was a bye
    var currentRound = firstRoundMatches ~/ 2;
    var dayOffset = 7;
    var prevByeTeams = Map<int, Map<String, dynamic>>.from(byeTeams);

    while (currentRound >= 1) {
      final roundName = roundNames[currentRound] ?? 'Faza pucharowa';

      for (var i = 0; i < currentRound; i++) {
        final preHome = prevByeTeams[i * 2];
        final preAway = prevByeTeams[i * 2 + 1];

        await _client.from('custom_matches').insert({
          'tournament_id': tournamentId,
          'home_team_id': preHome?['id'],
          'away_team_id': preAway?['id'],
          'home_team_name': preHome?['name'] ?? 'TBD',
          'away_team_name': preAway?['name'] ?? 'TBD',
          'home_team_logo': preHome?['logo_url'],
          'away_team_logo': preAway?['logo_url'],
          'match_time': baseTime.add(Duration(days: dayOffset, hours: i * 2)).toIso8601String(),
          'round_name': roundName,
          'match_phase': 'knockout',
          'knockout_round': currentRound,
          'knockout_slot': i,
        });
      }

      currentRound ~/= 2;
      dayOffset += 7;
      prevByeTeams = {}; // byes only apply to the first round
    }
  }

  static Future<void> deleteTournament(String tournamentId) async {
    // group_team_assignments has no tournament_id — delete via group_id
    final groups = await _client
        .from('tournament_groups')
        .select('id')
        .eq('tournament_id', tournamentId);
    for (final g in groups as List) {
      await _client
          .from('group_team_assignments')
          .delete()
          .eq('group_id', g['id'] as String);
    }
    await _client.from('custom_matches').delete().eq('tournament_id', tournamentId);
    await _client.from('tournament_groups').delete().eq('tournament_id', tournamentId);
    await _client.from('custom_teams').delete().eq('tournament_id', tournamentId);
    await _client.from('tournament_members').delete().eq('tournament_id', tournamentId);
    await _client.from('custom_tournaments').delete().eq('id', tournamentId);
  }

  static Future<List<Map<String, dynamic>>> getKnockoutMatches(String tournamentId) async {
    final resp = await _client
        .from('custom_matches')
        .select()
        .eq('tournament_id', tournamentId)
        .eq('match_phase', 'knockout')
        .order('knockout_round', ascending: false)
        .order('knockout_slot');
    return List<Map<String, dynamic>>.from(resp as List);
  }

  /// Awansuje zwycięzcę meczu knockout do następnej rundy.
  static Future<void> advanceKnockoutWinner({
    required String tournamentId,
    required Map<String, dynamic> completedMatch,
  }) async {
    final slot = completedMatch['knockout_slot'] as int?;
    final round = completedMatch['knockout_round'] as int?;
    if (slot == null || round == null || round <= 1) return;

    final nextRound = round ~/ 2;
    final nextSlot = slot ~/ 2;
    final isHome = slot % 2 == 0;

    final hScore = completedMatch['home_score'] as int? ?? 0;
    final aScore = completedMatch['away_score'] as int? ?? 0;
    final winnerIsHome = hScore >= aScore;

    final winnerName = winnerIsHome
        ? completedMatch['home_team_name'] as String
        : completedMatch['away_team_name'] as String;
    final winnerLogo = winnerIsHome
        ? completedMatch['home_team_logo'] as String?
        : completedMatch['away_team_logo'] as String?;
    final winnerId = winnerIsHome
        ? completedMatch['home_team_id'] as String?
        : completedMatch['away_team_id'] as String?;

    final nextMatchResp = await _client
        .from('custom_matches')
        .select()
        .eq('tournament_id', tournamentId)
        .eq('match_phase', 'knockout')
        .eq('knockout_round', nextRound)
        .eq('knockout_slot', nextSlot)
        .maybeSingle();

    if (nextMatchResp == null) return;

    await _client.from('custom_matches').update({
      if (isHome) 'home_team_name': winnerName else 'away_team_name': winnerName,
      if (isHome) 'home_team_logo': winnerLogo else 'away_team_logo': winnerLogo,
      if (isHome) 'home_team_id': winnerId else 'away_team_id': winnerId,
    }).eq('id', nextMatchResp['id'] as String);
  }

  // ── Image picker ──────────────────────────────────────────────────────────

  static Future<File?> pickLogoFromGallery() async {
    final xfile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (xfile == null) return null;
    return File(xfile.path);
  }
}
