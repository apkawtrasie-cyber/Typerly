import 'package:json_annotation/json_annotation.dart';

part 'profile.g.dart';

@JsonSerializable()
class Profile {
  final String id;
  final String username;
  final String? avatarUrl;
  @JsonKey(name: 'is_premium')
  final bool isPremium;
  @JsonKey(name: 'premium_until')
  final DateTime? premiumUntil;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  Profile({
    required this.id,
    required this.username,
    this.avatarUrl,
    required this.isPremium,
    this.premiumUntil,
    required this.createdAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => _$ProfileFromJson(json);

  Map<String, dynamic> toJson() => _$ProfileToJson(this);

  Profile copyWith({
    String? id,
    String? username,
    String? avatarUrl,
    bool? isPremium,
    DateTime? premiumUntil,
    DateTime? createdAt,
  }) {
    return Profile(
      id: id ?? this.id,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isPremium: isPremium ?? this.isPremium,
      premiumUntil: premiumUntil ?? this.premiumUntil,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isPremiumActive {
    if (!isPremium) return false;
    if (premiumUntil == null) return true;
    return DateTime.now().isBefore(premiumUntil!);
  }
}
