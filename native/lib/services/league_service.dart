import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';
import '../models/league.dart';

class LeagueService {
  static final SupabaseClient _client = SupabaseConfig.client;

  static Future<List<League>> getUserLeagues(String userId) async {
    final response = await _client
        .from('leagues')
        .select('*, league_members!inner(user_id)')
        .eq('league_members.user_id', userId)
        .order('created_at', ascending: false);
    return (response as List).map((e) => League.fromJson(e)).toList();
  }

  static Future<int> getUserLeagueCount(String userId) async {
    final response = await _client
        .from('leagues')
        .select('id')
        .eq('admin_id', userId);
    return (response as List).length;
  }

  static Future<League> createLeague({
    required String name,
    required String adminId,
    required int entryFeeGemings,
    required String inviteCode,
  }) async {
    final response = await _client.from('leagues').insert({
      'name': name,
      'admin_id': adminId,
      'entry_fee_gemings': entryFeeGemings,
      'invite_code': inviteCode,
    }).select().single();

    final league = League.fromJson(response);

    // Auto-add creator as member
    await _client.from('league_members').insert({
      'league_id': league.id,
      'user_id': adminId,
    });

    return league;
  }

  static Future<League?> joinLeague(String inviteCode, String userId) async {
    final leagueResponse = await _client
        .from('leagues')
        .select()
        .eq('invite_code', inviteCode.toUpperCase())
        .maybeSingle();

    if (leagueResponse == null) return null;

    final league = League.fromJson(leagueResponse);

    await _client.from('league_members').insert({
      'league_id': league.id,
      'user_id': userId,
    });

    return league;
  }

  static Future<int> getMemberCount(String leagueId) async {
    final response = await _client
        .from('league_members')
        .select('id')
        .eq('league_id', leagueId);
    return (response as List).length;
  }
}
