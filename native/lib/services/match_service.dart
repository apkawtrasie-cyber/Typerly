import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';
import '../models/match.dart';

class MatchService {
  static final SupabaseClient _client = SupabaseConfig.client;

  static Future<List<Match>> getUpcomingMatches({String? sportType}) async {
    var query = _client
        .from('matches')
        .select()
        .eq('is_custom', false)
        .gte('match_time', DateTime.now().toIso8601String())
        .order('match_time', ascending: true)
        .limit(30);

    final response = await query;
    return (response as List).map((e) => Match.fromJson(e)).toList();
  }

  static Future<List<Match>> getLeagueMatches(String leagueId) async {
    final response = await _client
        .from('matches')
        .select()
        .eq('league_id', leagueId)
        .order('match_time', ascending: true);
    return (response as List).map((e) => Match.fromJson(e)).toList();
  }

  static Future<Match> createCustomMatch({
    required String homeTeam,
    required String awayTeam,
    required DateTime matchTime,
    required String creatorId,
    required String leagueId,
  }) async {
    final response = await _client.from('matches').insert({
      'home_team_name': homeTeam,
      'away_team_name': awayTeam,
      'match_time': matchTime.toIso8601String(),
      'creator_id': creatorId,
      'league_id': leagueId,
      'is_custom': true,
      'sport_type': 'football',
      'status': 'NS',
    }).select().single();

    return Match.fromJson(response);
  }
}
