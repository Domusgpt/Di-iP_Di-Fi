"""
Invention Agent - The AI Co-Founder

This agent interviews the inventor to turn a raw idea into a structured
patent brief. It follows the "Onboarding Script" from the spec:

Phase 1: "Napkin Sketch" (Ingest) - Extract the core idea
Phase 2: "Drill Down" (Flesh Out) - Ask targeted questions to fill the schema
Phase 3: "Sanity Check" (Validate) - Prior art search + feasibility assessment

Integration Point: This is called by the Pub/Sub listener or directly via HTTP.
Output is published to `ai.processing.complete` topic.
"""

import logging
import uuid
from typing import Optional

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from src.services.llm_service import LLMService
from src.services.patent_search import PatentSearchService
from src.models.invention import (
    InventionDraft,
    SocialMetadata,
    TechnicalBrief,
    RiskAssessment,
    PriorArt,
)

logger = logging.getLogger(__name__)
router = APIRouter()

llm_service = LLMService()
patent_service = PatentSearchService()


class AnalyzeRequest(BaseModel):
    """Request to analyze a raw invention idea."""
    invention_id: str
    creator_id: str
    raw_text: Optional[str] = None
    voice_url: Optional[str] = None
    sketch_url: Optional[str] = None


class ChatRequest(BaseModel):
    """Request to continue the agent conversation."""
    invention_id: str
    creator_id: str
    message: str


class AnalyzeResponse(BaseModel):
    """Response with the structured invention data."""
    invention_id: str
    status: str
    social_metadata: dict
    technical_brief: dict
    risk_assessment: dict
    agent_message: str


@router.post("/analyze", response_model=AnalyzeResponse)
async def analyze_idea(request: AnalyzeRequest):
    """
    Phase 1: The "Napkin Sketch" - Initial idea ingestion.

    Takes raw input (text, voice URL, sketch URL) and generates
    an initial structured invention draft.
    """
    logger.info(f"Analyzing invention {request.invention_id}")

    if not request.raw_text and not request.voice_url and not request.sketch_url:
        raise HTTPException(status_code=400, detail="At least one input required")

    # Combine all inputs into a single context
    input_context = ""
    if request.raw_text:
        input_context += f"Text description: {request.raw_text}\n"
    if request.voice_url:
        # TODO: Transcribe voice note via Vertex AI Speech-to-Text
        input_context += f"[Voice note uploaded - transcription pending]\n"
    if request.sketch_url:
        # TODO: Analyze sketch via Gemini Vision
        input_context += f"[Sketch uploaded - visual analysis pending]\n"

    # Generate structured output using LLM
    structured = await llm_service.structure_invention(input_context)

    # Run prior art search
    prior_art = await patent_service.search_prior_art(
        structured.get("technical_field", ""),
        structured.get("solution_summary", ""),
    )

    # Build the response
    social_metadata = {
        "display_title": structured.get("display_title", "Untitled Invention"),
        "short_pitch": structured.get("short_pitch", ""),
        "virality_tags": structured.get("virality_tags", []),
    }

    technical_brief = {
        "technical_field": structured.get("technical_field", ""),
        "background_problem": structured.get("background_problem", ""),
        "solution_summary": structured.get("solution_summary", ""),
        "core_mechanics": structured.get("core_mechanics", []),
        "novelty_claims": structured.get("novelty_claims", []),
        "hardware_requirements": structured.get("hardware_requirements", []),
        "software_logic": structured.get("software_logic", ""),
    }

    risk_assessment = {
        "potential_prior_art": prior_art,
        "feasibility_score": structured.get("feasibility_score", 5),
        "missing_info": structured.get("missing_info", []),
    }

    agent_message = structured.get(
        "agent_reply",
        "I've drafted your invention summary. Please review and let me know if anything needs adjustment."
    )

    return AnalyzeResponse(
        invention_id=request.invention_id,
        status="REVIEW_READY",
        social_metadata=social_metadata,
        technical_brief=technical_brief,
        risk_assessment=risk_assessment,
        agent_message=agent_message,
    )


@router.post("/chat")
async def continue_chat(request: ChatRequest):
    """
    Phase 2/3: "Drill Down" and "Sanity Check"

    Continue the conversation to refine the invention.
    The agent asks targeted questions to fill gaps in the schema.
    """
    logger.info(f"Continuing chat for invention {request.invention_id}")

    # TODO: Load existing invention draft from Firestore
    # TODO: Pass conversation history to LLM
    # TODO: Identify which schema fields are still empty
    # TODO: Generate targeted follow-up questions

    response = await llm_service.continue_conversation(
        invention_id=request.invention_id,
        user_message=request.message,
    )

    return {
        "invention_id": request.invention_id,
        "agent_message": response.get("agent_reply", ""),
        "updated_fields": response.get("updated_fields", {}),
        "schema_completeness": response.get("completeness_percentage", 0),
    }
