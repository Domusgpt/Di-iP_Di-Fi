/**
 * Shared TypeScript types for the backend.
 * These mirror the canonical InventionSchema.json.
 */

export type InventionStatus =
  | "DRAFT"
  | "AI_PROCESSING"
  | "REVIEW_READY"
  | "LIVE"
  | "FUNDING"
  | "FUNDED"
  | "MINTED"
  | "LICENSING"
  | "REVENUE";

export interface Invention {
  invention_id: string;
  status: InventionStatus;
  created_at: FirebaseFirestore.Timestamp;
  updated_at?: FirebaseFirestore.Timestamp;
  creator_id: string;
  social_metadata: SocialMetadata;
  technical_brief?: TechnicalBrief;
  risk_assessment?: RiskAssessment;
  funding?: Funding;
  blockchain_ref?: BlockchainRef;
}

export interface SocialMetadata {
  display_title: string;
  short_pitch: string;
  virality_tags?: string[];
  media_assets?: {
    hero_image_url?: string;
    explainer_video_url?: string;
    thumbnail_url?: string;
    gallery?: string[];
  };
}

export interface TechnicalBrief {
  technical_field?: string;
  background_problem?: string;
  solution_summary?: string;
  core_mechanics?: { step: number; description: string }[];
  novelty_claims?: string[];
  hardware_requirements?: string[];
  software_logic?: string;
}

export interface RiskAssessment {
  potential_prior_art?: {
    source: string;
    patent_id: string;
    similarity_score: number;
    notes: string;
  }[];
  feasibility_score?: number;
  missing_info?: string[];
}

export interface Funding {
  goal_usdc?: number;
  raised_usdc?: number;
  backer_count?: number;
  min_investment_usdc?: number;
  royalty_percentage?: number;
  deadline?: FirebaseFirestore.Timestamp;
  token_supply?: number;
  pending_investments?: number;
}

export interface BlockchainRef {
  nft_contract_address?: string;
  nft_token_id?: string;
  royalty_token_address?: string;
  crowdsale_address?: string;
  chain_id?: number;
  ipfs_metadata_cid?: string;
}

export interface Investment {
  investment_id: string;
  invention_id: string;
  user_id: string;
  wallet_address: string;
  amount_usdc: number;
  tx_hash: string;
  status: "PENDING" | "CONFIRMED" | "FAILED";
  block_number?: number;
  token_amount?: number;
  created_at: FirebaseFirestore.Timestamp;
  confirmed_at?: FirebaseFirestore.Timestamp;
}

// ---- Pub/Sub Message Types ----

export interface AiProcessingMessage {
  invention_id: string;
  creator_id: string;
  raw_text?: string;
  voice_url?: string;
  sketch_url?: string;
  message?: string;
  action: "INITIAL_ANALYSIS" | "CONTINUE_CHAT";
}

export interface InvestmentPendingMessage {
  investment_id: string;
  invention_id: string;
  tx_hash: string;
  wallet_address: string;
  amount_usdc: number;
}

export interface InvestmentConfirmedMessage {
  investment_id: string;
  invention_id: string;
  wallet_address: string;
  amount_usdc: number;
  token_amount: number;
  block_number: number;
}
