import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';
import '../models/prediction.dart';

class PredictionService {
  static final SupabaseClient _client = SupabaseConfig.client;

  static Future<List<Prediction>> getMatchPredictions(String matchId) async {
    final response = await _client
        .from('predictions')
        .select('*, profiles(username, avatar_url)')
        .eq('match_id', matchId)
        .order('created_at', ascending: false);
    return (response as List).map((e) => Prediction.fromJson(e)).toList();
  }

  static Future<Prediction?> getUserPrediction(
      String matchId, String userId) async {
    final response = await _client
        .from('predictions')
        .select()
        .eq('match_id', matchId)
        .eq('user_id', userId)
        .maybeSingle();
    if (response == null) return null;
    return Prediction.fromJson(response);
  }

  static Future<Prediction> savePrediction({
    required String matchId,
    required String userId,
    required String leagueId,
    required int predictedHome,
    required int predictedAway,
  }) async {
    final existing = await getUserPrediction(matchId, userId);

    if (existing != null) {
      final response = await _client
          .from('predictions')
          .update({
            'predicted_home_score': predictedHome,
            'predicted_away_score': predictedAway,
          })
          .eq('id', existing.id)
          .select()
          .single();
      return Prediction.fromJson(response);
    } else {
      final response = await _client.from('predictions').insert({
        'match_id': matchId,
        'user_id': userId,
        'league_id': leagueId,
        'predicted_home_score': predictedHome,
        'predicted_away_score': predictedAway,
      }).select().single();
      return Prediction.fromJson(response);
    }
  }
}
