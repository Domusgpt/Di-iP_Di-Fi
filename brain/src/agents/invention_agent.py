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
import os
from typing import Optional

import httpx
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from src.services.llm_service import LLMService
from src.services.patent_search import PatentSearchService
from src.services.zkp_service import ZKPService

logger = logging.getLogger(__name__)
router = APIRouter()

llm_service = LLMService()
patent_service = PatentSearchService()
zkp_service = ZKPService()


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


class ProveNoveltyRequest(BaseModel):
    """Request to generate a ZK proof for an invention."""
    invention_id: str
    content: str


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
        transcription = await _transcribe_voice(request.voice_url)
        input_context += f"Voice transcription: {transcription}\n"
    if request.sketch_url:
        sketch_analysis = await _analyze_sketch(request.sketch_url)
        input_context += f"Sketch analysis: {sketch_analysis}\n"

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

    # continue_conversation handles all context loading internally:
    # - Loads existing invention draft from Firestore
    # - Loads conversation history (last 20 turns)
    # - Identifies empty schema fields via completeness_percentage
    # - Generates targeted follow-up questions in agent_reply
    response = await llm_service.continue_conversation(
        invention_id=request.invention_id,
        user_message=request.message,
    )

    # Apply updated fields to Firestore if the LLM suggested changes
    updated_fields = response.get("updated_fields", {})
    if updated_fields:
        try:
            from google.cloud import firestore as gc_firestore

            db = gc_firestore.AsyncClient()
            await db.collection("inventions").document(request.invention_id).update(
                updated_fields
            )
            logger.info(
                f"Updated {len(updated_fields)} fields for invention {request.invention_id}"
            )
        except Exception as e:
            logger.warning(f"Failed to apply updated fields to Firestore: {e}")

    return {
        "invention_id": request.invention_id,
        "agent_message": response.get("agent_reply", ""),
        "updated_fields": updated_fields,
        "schema_completeness": response.get("completeness_percentage", 0),
    }


@router.post("/prove_novelty")
async def prove_novelty(request: ProveNoveltyRequest):
    """
    Generate a Zero-Knowledge Proof of novelty for an invention.
    Stores the proof in Firestore.
    """
    logger.info(f"Generating ZKP for invention {request.invention_id}")

    try:
        proof = await zkp_service.generate_proof(request.content)

        # Store proof in Firestore
        try:
            from google.cloud import firestore as gc_firestore
            db = gc_firestore.AsyncClient()
            await db.collection("inventions").document(request.invention_id).update({
                "novelty_proof": proof
            })
            logger.info(f"Stored ZKP for invention {request.invention_id}")
        except Exception as e:
            logger.warning(f"Failed to store ZKP in Firestore: {e}")
            # We return the proof anyway so the caller has it

        return {
            "invention_id": request.invention_id,
            "status": "PROOF_GENERATED",
            "proof": proof
        }
    except Exception as e:
        logger.error(f"ZKP generation failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))


async def _transcribe_voice(voice_url: str) -> str:
    """
    Transcribe a voice note using Google Cloud Speech-to-Text v2.
    Falls back to a placeholder if the API is not available.
    """
    try:
        from google.cloud.speech_v2 import SpeechAsyncClient
        from google.cloud.speech_v2.types import cloud_speech

        client = SpeechAsyncClient()
        project_id = os.getenv("VERTEX_AI_PROJECT", "ideacapital-dev")

        # Download the audio file
        async with httpx.AsyncClient() as http:
            audio_response = await http.get(voice_url, timeout=30.0)
            audio_response.raise_for_status()
            audio_content = audio_response.content

        config = cloud_speech.RecognitionConfig(
            auto_decoding_config=cloud_speech.AutoDetectDecodingConfig(),
            language_codes=["en-US"],
            model="long",
        )

        request = cloud_speech.RecognizeRequest(
            recognizer=f"projects/{project_id}/locations/global/recognizers/_",
            config=config,
            content=audio_content,
        )

        response = await client.recognize(request=request)

        transcription = ""
        for result in response.results:
            transcription += result.alternatives[0].transcript + " "

        logger.info(f"Transcribed voice note: {len(transcription)} chars")
        return transcription.strip() if transcription.strip() else "[Voice note was empty or inaudible]"

    except ImportError:
        logger.warning("google-cloud-speech not installed, using mock transcription")
        return "[Voice note uploaded — transcription requires google-cloud-speech package]"
    except Exception as e:
        logger.error(f"Voice transcription failed: {e}")
        return f"[Voice note uploaded — transcription failed: {str(e)[:100]}]"


async def _analyze_sketch(sketch_url: str) -> str:
    """
    Analyze a sketch image using Gemini 1.5 Flash Vision.
    Falls back to a placeholder if the API is not available.
    """
    try:
        import vertexai
        from vertexai.generative_models import GenerativeModel, Part

        project_id = os.getenv("VERTEX_AI_PROJECT", "ideacapital-dev")
        location = os.getenv("VERTEX_AI_LOCATION", "us-central1")
        vertexai.init(project=project_id, location=location)

        model = GenerativeModel("gemini-1.5-flash")

        prompt = (
            "You are analyzing an inventor's sketch or diagram for a patent application. "
            "Describe in detail:\n"
            "1. What the sketch depicts (components, connections, layout)\n"
            "2. The apparent purpose or function of the invention\n"
            "3. Any text, labels, or annotations visible\n"
            "4. Technical components or mechanisms you can identify\n"
            "Be specific and technical. This description will be used to generate a patent brief."
        )

        image_part = Part.from_uri(sketch_url, mime_type="image/jpeg")
        response = await model.generate_content_async(
            [prompt, image_part],
            generation_config={"temperature": 0.2, "max_output_tokens": 1024},
        )

        analysis = response.text
        logger.info(f"Analyzed sketch: {len(analysis)} chars")
        return analysis

    except ImportError:
        logger.warning("vertexai not installed, using mock sketch analysis")
        return "[Sketch uploaded — visual analysis requires vertexai package]"
    except Exception as e:
        logger.error(f"Sketch analysis failed: {e}")
        return f"[Sketch uploaded — visual analysis failed: {str(e)[:100]}]"
