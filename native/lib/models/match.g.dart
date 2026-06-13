// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'match.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Match _$MatchFromJson(Map<String, dynamic> json) => Match(
      id: json['id'] as String,
      apiFixtureId: (json['api_fixture_id'] as num?)?.toInt(),
      sportType: json['sport_type'] as String,
      homeTeamName: json['home_team_name'] as String,
      awayTeamName: json['away_team_name'] as String,
      homeTeamLogoUrl: json['home_team_logo_url'] as String?,
      awayTeamLogoUrl: json['away_team_logo_url'] as String?,
      matchTime: DateTime.parse(json['match_time'] as String),
      status: json['status'] as String,
      homeScore: (json['home_score'] as num?)?.toInt(),
      awayScore: (json['away_score'] as num?)?.toInt(),
      isCustom: json['is_custom'] as bool,
      creatorId: json['creator_id'] as String?,
      leagueId: json['league_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$MatchToJson(Match instance) => <String, dynamic>{
      'id': instance.id,
      'api_fixture_id': instance.apiFixtureId,
      'sport_type': instance.sportType,
      'home_team_name': instance.homeTeamName,
      'away_team_name': instance.awayTeamName,
      'home_team_logo_url': instance.homeTeamLogoUrl,
      'away_team_logo_url': instance.awayTeamLogoUrl,
      'match_time': instance.matchTime.toIso8601String(),
      'status': instance.status,
      'home_score': instance.homeScore,
      'away_score': instance.awayScore,
      'is_custom': instance.isCustom,
      'creator_id': instance.creatorId,
      'league_id': instance.leagueId,
      'created_at': instance.createdAt.toIso8601String(),
    };
