// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'league_member.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LeagueMember _$LeagueMemberFromJson(Map<String, dynamic> json) => LeagueMember(
      id: json['id'] as String,
      leagueId: json['league_id'] as String,
      userId: json['user_id'] as String,
      gemingsBalance: (json['gemings_balance'] as num).toInt(),
      isApprovedByAdmin: json['is_approved_by_admin'] as bool,
      joinedAt: DateTime.parse(json['joined_at'] as String),
    );

Map<String, dynamic> _$LeagueMemberToJson(LeagueMember instance) =>
    <String, dynamic>{
      'id': instance.id,
      'league_id': instance.leagueId,
      'user_id': instance.userId,
      'gemings_balance': instance.gemingsBalance,
      'is_approved_by_admin': instance.isApprovedByAdmin,
      'joined_at': instance.joinedAt.toIso8601String(),
    };
