import 'package:json_annotation/json_annotation.dart';

part 'match.g.dart';

@JsonSerializable()
class Match {
  final String id;
  @JsonKey(name: 'api_fixture_id')
  final int? apiFixtureId;
  @JsonKey(name: 'sport_type')
  final String sportType;
  @JsonKey(name: 'home_team_name')
  final String homeTeamName;
  @JsonKey(name: 'away_team_name')
  final String awayTeamName;
  @JsonKey(name: 'home_team_logo_url')
  final String? homeTeamLogoUrl;
  @JsonKey(name: 'away_team_logo_url')
  final String? awayTeamLogoUrl;
  @JsonKey(name: 'match_time')
  final DateTime matchTime;
  final String status;
  @JsonKey(name: 'home_score')
  final int? homeScore;
  @JsonKey(name: 'away_score')
  final int? awayScore;
  @JsonKey(name: 'is_custom')
  final bool isCustom;
  @JsonKey(name: 'creator_id')
  final String? creatorId;
  @JsonKey(name: 'league_id')
  final String? leagueId;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  Match({
    required this.id,
    this.apiFixtureId,
    required this.sportType,
    required this.homeTeamName,
    required this.awayTeamName,
    this.homeTeamLogoUrl,
    this.awayTeamLogoUrl,
    required this.matchTime,
    required this.status,
    this.homeScore,
    this.awayScore,
    required this.isCustom,
    this.creatorId,
    this.leagueId,
    required this.createdAt,
  });

  factory Match.fromJson(Map<String, dynamic> json) => _$MatchFromJson(json);

  Map<String, dynamic> toJson() => _$MatchToJson(this);

  Match copyWith({
    String? id,
    int? apiFixtureId,
    String? sportType,
    String? homeTeamName,
    String? awayTeamName,
    String? homeTeamLogoUrl,
    String? awayTeamLogoUrl,
    DateTime? matchTime,
    String? status,
    int? homeScore,
    int? awayScore,
    bool? isCustom,
    String? creatorId,
    String? leagueId,
    DateTime? createdAt,
  }) {
    return Match(
      id: id ?? this.id,
      apiFixtureId: apiFixtureId ?? this.apiFixtureId,
      sportType: sportType ?? this.sportType,
      homeTeamName: homeTeamName ?? this.homeTeamName,
      awayTeamName: awayTeamName ?? this.awayTeamName,
      homeTeamLogoUrl: homeTeamLogoUrl ?? this.homeTeamLogoUrl,
      awayTeamLogoUrl: awayTeamLogoUrl ?? this.awayTeamLogoUrl,
      matchTime: matchTime ?? this.matchTime,
      status: status ?? this.status,
      homeScore: homeScore ?? this.homeScore,
      awayScore: awayScore ?? this.awayScore,
      isCustom: isCustom ?? this.isCustom,
      creatorId: creatorId ?? this.creatorId,
      leagueId: leagueId ?? this.leagueId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isLive => status == 'LIVE';
  bool get isFinished => status == 'FT';
  bool get isNotStarted => status == 'NS';
}
