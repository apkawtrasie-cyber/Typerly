import 'package:json_annotation/json_annotation.dart';

part 'league_member.g.dart';

@JsonSerializable()
class LeagueMember {
  final String id;
  @JsonKey(name: 'league_id')
  final String leagueId;
  @JsonKey(name: 'user_id')
  final String userId;
  @JsonKey(name: 'gemings_balance')
  final int gemingsBalance;
  @JsonKey(name: 'is_approved_by_admin')
  final bool isApprovedByAdmin;
  @JsonKey(name: 'joined_at')
  final DateTime joinedAt;

  LeagueMember({
    required this.id,
    required this.leagueId,
    required this.userId,
    required this.gemingsBalance,
    required this.isApprovedByAdmin,
    required this.joinedAt,
  });

  factory LeagueMember.fromJson(Map<String, dynamic> json) =>
      _$LeagueMemberFromJson(json);

  Map<String, dynamic> toJson() => _$LeagueMemberToJson(this);

  LeagueMember copyWith({
    String? id,
    String? leagueId,
    String? userId,
    int? gemingsBalance,
    bool? isApprovedByAdmin,
    DateTime? joinedAt,
  }) {
    return LeagueMember(
      id: id ?? this.id,
      leagueId: leagueId ?? this.leagueId,
      userId: userId ?? this.userId,
      gemingsBalance: gemingsBalance ?? this.gemingsBalance,
      isApprovedByAdmin: isApprovedByAdmin ?? this.isApprovedByAdmin,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }
}
