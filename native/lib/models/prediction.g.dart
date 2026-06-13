// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'prediction.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Prediction _$PredictionFromJson(Map<String, dynamic> json) => Prediction(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      matchId: json['match_id'] as String,
      leagueId: json['league_id'] as String,
      predictedHomeScore: (json['predicted_home_score'] as num).toInt(),
      predictedAwayScore: (json['predicted_away_score'] as num).toInt(),
      pointsEarned: (json['points_earned'] as num).toInt(),
      isCalculated: json['is_calculated'] as bool,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$PredictionToJson(Prediction instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'match_id': instance.matchId,
      'league_id': instance.leagueId,
      'predicted_home_score': instance.predictedHomeScore,
      'predicted_away_score': instance.predictedAwayScore,
      'points_earned': instance.pointsEarned,
      'is_calculated': instance.isCalculated,
      'updated_at': instance.updatedAt.toIso8601String(),
    };
