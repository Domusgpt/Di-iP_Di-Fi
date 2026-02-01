import 'package:json_annotation/json_annotation.dart';

part 'invention.g.dart';

/// Mirrors the canonical InventionSchema.json.
/// This is the Dart representation of the shared schema.
@JsonSerializable(explicitToJson: true)
class Invention {
  @JsonKey(name: 'invention_id')
  final String inventionId;
  final String status;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;
  @JsonKey(name: 'creator_id')
  final String creatorId;
  @JsonKey(name: 'social_metadata')
  final SocialMetadata socialMetadata;
  @JsonKey(name: 'technical_brief')
  final TechnicalBrief? technicalBrief;
  @JsonKey(name: 'risk_assessment')
  final RiskAssessment? riskAssessment;
  final Funding? funding;
  @JsonKey(name: 'blockchain_ref')
  final BlockchainRef? blockchainRef;

  Invention({
    required this.inventionId,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    required this.creatorId,
    required this.socialMetadata,
    this.technicalBrief,
    this.riskAssessment,
    this.funding,
    this.blockchainRef,
  });

  factory Invention.fromJson(Map<String, dynamic> json) =>
      _$InventionFromJson(json);
  Map<String, dynamic> toJson() => _$InventionToJson(this);
}

@JsonSerializable(explicitToJson: true)
class SocialMetadata {
  @JsonKey(name: 'display_title')
  final String displayTitle;
  @JsonKey(name: 'short_pitch')
  final String shortPitch;
  @JsonKey(name: 'virality_tags')
  final List<String>? viralityTags;
  @JsonKey(name: 'media_assets')
  final MediaAssets? mediaAssets;

  SocialMetadata({
    required this.displayTitle,
    required this.shortPitch,
    this.viralityTags,
    this.mediaAssets,
  });

  factory SocialMetadata.fromJson(Map<String, dynamic> json) =>
      _$SocialMetadataFromJson(json);
  Map<String, dynamic> toJson() => _$SocialMetadataToJson(this);
}

@JsonSerializable()
class MediaAssets {
  @JsonKey(name: 'hero_image_url')
  final String? heroImageUrl;
  @JsonKey(name: 'explainer_video_url')
  final String? explainerVideoUrl;
  @JsonKey(name: 'thumbnail_url')
  final String? thumbnailUrl;
  final List<String>? gallery;

  MediaAssets({
    this.heroImageUrl,
    this.explainerVideoUrl,
    this.thumbnailUrl,
    this.gallery,
  });

  factory MediaAssets.fromJson(Map<String, dynamic> json) =>
      _$MediaAssetsFromJson(json);
  Map<String, dynamic> toJson() => _$MediaAssetsToJson(this);
}

@JsonSerializable(explicitToJson: true)
class TechnicalBrief {
  @JsonKey(name: 'technical_field')
  final String? technicalField;
  @JsonKey(name: 'background_problem')
  final String? backgroundProblem;
  @JsonKey(name: 'solution_summary')
  final String? solutionSummary;
  @JsonKey(name: 'core_mechanics')
  final List<CoreMechanic>? coreMechanics;
  @JsonKey(name: 'novelty_claims')
  final List<String>? noveltyClaims;
  @JsonKey(name: 'hardware_requirements')
  final List<String>? hardwareRequirements;
  @JsonKey(name: 'software_logic')
  final String? softwareLogic;

  TechnicalBrief({
    this.technicalField,
    this.backgroundProblem,
    this.solutionSummary,
    this.coreMechanics,
    this.noveltyClaims,
    this.hardwareRequirements,
    this.softwareLogic,
  });

  factory TechnicalBrief.fromJson(Map<String, dynamic> json) =>
      _$TechnicalBriefFromJson(json);
  Map<String, dynamic> toJson() => _$TechnicalBriefToJson(this);
}

@JsonSerializable()
class CoreMechanic {
  final int step;
  final String description;

  CoreMechanic({required this.step, required this.description});

  factory CoreMechanic.fromJson(Map<String, dynamic> json) =>
      _$CoreMechanicFromJson(json);
  Map<String, dynamic> toJson() => _$CoreMechanicToJson(this);
}

@JsonSerializable(explicitToJson: true)
class RiskAssessment {
  @JsonKey(name: 'potential_prior_art')
  final List<PriorArt>? potentialPriorArt;
  @JsonKey(name: 'feasibility_score')
  final int? feasibilityScore;
  @JsonKey(name: 'missing_info')
  final List<String>? missingInfo;

  RiskAssessment({
    this.potentialPriorArt,
    this.feasibilityScore,
    this.missingInfo,
  });

  factory RiskAssessment.fromJson(Map<String, dynamic> json) =>
      _$RiskAssessmentFromJson(json);
  Map<String, dynamic> toJson() => _$RiskAssessmentToJson(this);
}

@JsonSerializable()
class PriorArt {
  final String? source;
  @JsonKey(name: 'patent_id')
  final String? patentId;
  @JsonKey(name: 'similarity_score')
  final double? similarityScore;
  final String? notes;

  PriorArt({this.source, this.patentId, this.similarityScore, this.notes});

  factory PriorArt.fromJson(Map<String, dynamic> json) =>
      _$PriorArtFromJson(json);
  Map<String, dynamic> toJson() => _$PriorArtToJson(this);
}

@JsonSerializable()
class Funding {
  @JsonKey(name: 'goal_usdc')
  final double? goalUsdc;
  @JsonKey(name: 'raised_usdc')
  final double? raisedUsdc;
  @JsonKey(name: 'backer_count')
  final int? backerCount;
  @JsonKey(name: 'min_investment_usdc')
  final double? minInvestmentUsdc;
  @JsonKey(name: 'royalty_percentage')
  final double? royaltyPercentage;
  final DateTime? deadline;
  @JsonKey(name: 'token_supply')
  final int? tokenSupply;

  Funding({
    this.goalUsdc,
    this.raisedUsdc,
    this.backerCount,
    this.minInvestmentUsdc,
    this.royaltyPercentage,
    this.deadline,
    this.tokenSupply,
  });

  factory Funding.fromJson(Map<String, dynamic> json) =>
      _$FundingFromJson(json);
  Map<String, dynamic> toJson() => _$FundingToJson(this);
}

@JsonSerializable()
class BlockchainRef {
  @JsonKey(name: 'nft_contract_address')
  final String? nftContractAddress;
  @JsonKey(name: 'nft_token_id')
  final String? nftTokenId;
  @JsonKey(name: 'royalty_token_address')
  final String? royaltyTokenAddress;
  @JsonKey(name: 'crowdsale_address')
  final String? crowdsaleAddress;
  @JsonKey(name: 'chain_id')
  final int? chainId;
  @JsonKey(name: 'ipfs_metadata_cid')
  final String? ipfsMetadataCid;

  BlockchainRef({
    this.nftContractAddress,
    this.nftTokenId,
    this.royaltyTokenAddress,
    this.crowdsaleAddress,
    this.chainId,
    this.ipfsMetadataCid,
  });

  factory BlockchainRef.fromJson(Map<String, dynamic> json) =>
      _$BlockchainRefFromJson(json);
  Map<String, dynamic> toJson() => _$BlockchainRefToJson(this);
}
