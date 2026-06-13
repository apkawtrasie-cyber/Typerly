import 'package:json_annotation/json_annotation.dart';

part 'prediction.g.dart';

@JsonSerializable()
class Prediction {
  final String id;
  @JsonKey(name: 'user_id')
  final String userId;
  @JsonKey(name: 'match_id')
  final String matchId;
  @JsonKey(name: 'league_id')
  final String leagueId;
  @JsonKey(name: 'predicted_home_score')
  final int predictedHomeScore;
  @JsonKey(name: 'predicted_away_score')
  final int predictedAwayScore;
  @JsonKey(name: 'points_earned')
  final int pointsEarned;
  @JsonKey(name: 'is_calculated')
  final bool isCalculated;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  Prediction({
    required this.id,
    required this.userId,
    required this.matchId,
    required this.leagueId,
    required this.predictedHomeScore,
    required this.predictedAwayScore,
    required this.pointsEarned,
    required this.isCalculated,
    required this.updatedAt,
  });

  factory Prediction.fromJson(Map<String, dynamic> json) =>
      _$PredictionFromJson(json);

  Map<String, dynamic> toJson() => _$PredictionToJson(this);

  Prediction copyWith({
    String? id,
    String? userId,
    String? matchId,
    String? leagueId,
    int? predictedHomeScore,
    int? predictedAwayScore,
    int? pointsEarned,
    bool? isCalculated,
    DateTime? updatedAt,
  }) {
    return Prediction(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      matchId: matchId ?? this.matchId,
      leagueId: leagueId ?? this.leagueId,
      predictedHomeScore: predictedHomeScore ?? this.predictedHomeScore,
      predictedAwayScore: predictedAwayScore ?? this.predictedAwayScore,
      pointsEarned: pointsEarned ?? this.pointsEarned,
      isCalculated: isCalculated ?? this.isCalculated,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get predictionDisplay => '$predictedHomeScore:$predictedAwayScore';
}
