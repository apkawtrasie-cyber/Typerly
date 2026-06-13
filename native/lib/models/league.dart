import 'package:json_annotation/json_annotation.dart';

part 'league.g.dart';

@JsonSerializable()
class League {
  final String id;
  final String name;
  @JsonKey(name: 'invite_code')
  final String inviteCode;
  @JsonKey(name: 'admin_id')
  final String adminId;
  @JsonKey(name: 'entry_fee_gemings')
  final int entryFeeGemings;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  League({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.adminId,
    required this.entryFeeGemings,
    required this.createdAt,
  });

  factory League.fromJson(Map<String, dynamic> json) => _$LeagueFromJson(json);

  Map<String, dynamic> toJson() => _$LeagueToJson(this);

  League copyWith({
    String? id,
    String? name,
    String? inviteCode,
    String? adminId,
    int? entryFeeGemings,
    DateTime? createdAt,
  }) {
    return League(
      id: id ?? this.id,
      name: name ?? this.name,
      inviteCode: inviteCode ?? this.inviteCode,
      adminId: adminId ?? this.adminId,
      entryFeeGemings: entryFeeGemings ?? this.entryFeeGemings,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
