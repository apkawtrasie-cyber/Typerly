// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Profile _$ProfileFromJson(Map<String, dynamic> json) => Profile(
      id: json['id'] as String,
      username: json['username'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      isPremium: json['is_premium'] as bool,
      premiumUntil: json['premium_until'] == null
          ? null
          : DateTime.parse(json['premium_until'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$ProfileToJson(Profile instance) => <String, dynamic>{
      'id': instance.id,
      'username': instance.username,
      'avatarUrl': instance.avatarUrl,
      'is_premium': instance.isPremium,
      'premium_until': instance.premiumUntil?.toIso8601String(),
      'created_at': instance.createdAt.toIso8601String(),
    };
