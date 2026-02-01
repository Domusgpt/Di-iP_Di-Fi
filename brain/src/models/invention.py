"""
Invention Pydantic models - Python representation of InventionSchema.json.

These models are the Python-side contract for the shared schema.
They mirror the canonical JSON Schema in /schemas/InventionSchema.json.
"""

from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field


class MediaAssets(BaseModel):
    hero_image_url: Optional[str] = None
    explainer_video_url: Optional[str] = None
    thumbnail_url: Optional[str] = None
    gallery: list[str] = Field(default_factory=list)


class SocialMetadata(BaseModel):
    display_title: str = Field(max_length=60)
    short_pitch: str = Field(max_length=280)
    virality_tags: list[str] = Field(default_factory=list)
    media_assets: Optional[MediaAssets] = None


class CoreMechanic(BaseModel):
    step: int
    description: str


class TechnicalBrief(BaseModel):
    technical_field: Optional[str] = None
    background_problem: Optional[str] = None
    solution_summary: Optional[str] = None
    core_mechanics: list[CoreMechanic] = Field(default_factory=list)
    novelty_claims: list[str] = Field(default_factory=list)
    hardware_requirements: list[str] = Field(default_factory=list)
    software_logic: Optional[str] = None


class PriorArt(BaseModel):
    source: str
    patent_id: str
    similarity_score: float = Field(ge=0, le=1)
    notes: str


class RiskAssessment(BaseModel):
    potential_prior_art: list[PriorArt] = Field(default_factory=list)
    feasibility_score: int = Field(ge=1, le=10, default=5)
    missing_info: list[str] = Field(default_factory=list)


class Funding(BaseModel):
    goal_usdc: Optional[float] = None
    raised_usdc: float = 0
    backer_count: int = 0
    min_investment_usdc: Optional[float] = None
    royalty_percentage: Optional[float] = None
    deadline: Optional[datetime] = None
    token_supply: Optional[int] = None


class BlockchainRef(BaseModel):
    nft_contract_address: Optional[str] = None
    nft_token_id: Optional[str] = None
    royalty_token_address: Optional[str] = None
    crowdsale_address: Optional[str] = None
    chain_id: Optional[int] = None
    ipfs_metadata_cid: Optional[str] = None


class InventionDraft(BaseModel):
    """Full invention model matching the canonical InventionSchema.json."""

    invention_id: str
    status: str = "DRAFT"
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: Optional[datetime] = None
    creator_id: str
    social_metadata: SocialMetadata
    technical_brief: Optional[TechnicalBrief] = None
    risk_assessment: Optional[RiskAssessment] = None
    funding: Optional[Funding] = None
    blockchain_ref: Optional[BlockchainRef] = None
