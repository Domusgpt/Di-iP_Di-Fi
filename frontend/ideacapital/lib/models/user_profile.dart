import 'package:json_annotation/json_annotation.dart';

part 'user_profile.g.dart';

@JsonSerializable()
class UserProfile {
  final String uid;
  @JsonKey(name: 'display_name')
  final String displayName;
  final String? email;
  @JsonKey(name: 'avatar_url')
  final String? avatarUrl;
  final String? bio;
  final String role; // 'inventor', 'investor', 'both'
  @JsonKey(name: 'reputation_score')
  final int reputationScore;
  final List<String> badges;
  @JsonKey(name: 'wallet_address')
  final String? walletAddress;
  @JsonKey(name: 'inventions_count')
  final int inventionsCount;
  @JsonKey(name: 'investments_count')
  final int investmentsCount;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  UserProfile({
    required this.uid,
    required this.displayName,
    this.email,
    this.avatarUrl,
    this.bio,
    this.role = 'both',
    this.reputationScore = 0,
    this.badges = const [],
    this.walletAddress,
    this.inventionsCount = 0,
    this.investmentsCount = 0,
    required this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) =>
      _$UserProfileFromJson(json);
  Map<String, dynamic> toJson() => _$UserProfileToJson(this);
}
