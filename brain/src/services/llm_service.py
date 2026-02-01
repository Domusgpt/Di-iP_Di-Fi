"""
LLM Service - Wraps Vertex AI / Gemini for structured invention analysis.

Uses LangChain for prompt management and output parsing.
"""

import json
import logging
import os
from typing import Optional

logger = logging.getLogger(__name__)

# System prompt that defines the AI's persona and output structure
INVENTION_STRUCTURING_PROMPT = """You are the IdeaCapital AI Co-Founder. Your job is to take a rough
invention idea and structure it into a patent-ready brief.

You are NOT a chatbot. You are a patent analyst. Your tone is:
- Encouraging but precise
- You ask targeted engineering questions
- You hunt for the "novelty claim" — the specific unique element that makes this patentable

Given the user's raw input, generate a structured JSON output with these fields:
{
  "display_title": "Catchy name (max 60 chars)",
  "short_pitch": "One-sentence pitch (max 280 chars)",
  "virality_tags": ["Tag1", "Tag2", "Tag3"],
  "technical_field": "Category of technology",
  "background_problem": "What problem does this solve?",
  "solution_summary": "How does it solve it?",
  "core_mechanics": [{"step": 1, "description": "..."}],
  "novelty_claims": ["What makes this unique"],
  "hardware_requirements": ["Required components"],
  "software_logic": "Algorithm description if applicable",
  "feasibility_score": 7,
  "missing_info": ["Questions that need answers"],
  "agent_reply": "Your conversational response to the user"
}

Be thorough. If information is missing, list it in missing_info and ask about it in agent_reply.
"""


class LLMService:
    """Handles all LLM interactions for invention structuring."""

    def __init__(self):
        self.project_id = os.getenv("VERTEX_AI_PROJECT", "ideacapital-dev")
        self.location = os.getenv("VERTEX_AI_LOCATION", "us-central1")
        self._model = None

    def _get_model(self):
        """Lazy-load the Vertex AI model."""
        if self._model is None:
            try:
                from langchain_google_vertexai import ChatVertexAI

                self._model = ChatVertexAI(
                    model_name="gemini-1.5-pro",
                    project=self.project_id,
                    location=self.location,
                    temperature=0.3,
                    max_output_tokens=4096,
                )
            except Exception as e:
                logger.warning(f"Vertex AI not available, using mock: {e}")
                self._model = None
        return self._model

    async def structure_invention(self, raw_input: str) -> dict:
        """
        Take raw user input and generate a structured invention brief.
        """
        model = self._get_model()

        if model is None:
            # Return mock data for local development
            return self._mock_structured_output(raw_input)

        try:
            from langchain_core.messages import SystemMessage, HumanMessage

            messages = [
                SystemMessage(content=INVENTION_STRUCTURING_PROMPT),
                HumanMessage(content=f"Here is the invention idea:\n\n{raw_input}"),
            ]

            response = await model.ainvoke(messages)
            content = response.content

            # Parse JSON from response
            # Try to extract JSON block if wrapped in markdown
            if "```json" in content:
                content = content.split("```json")[1].split("```")[0]
            elif "```" in content:
                content = content.split("```")[1].split("```")[0]

            return json.loads(content.strip())

        except Exception as e:
            logger.error(f"LLM structuring failed: {e}")
            return self._mock_structured_output(raw_input)

    async def continue_conversation(
        self, invention_id: str, user_message: str
    ) -> dict:
        """
        Continue refining an invention through conversation.
        """
        model = self._get_model()

        if model is None:
            return {
                "agent_reply": (
                    "Thanks for that detail. I've updated your brief. "
                    "Can you tell me more about the specific materials or "
                    "components you envision for the prototype?"
                ),
                "updated_fields": {},
                "completeness_percentage": 65,
            }

        # TODO: Load conversation history from Firestore
        # TODO: Load current draft state
        # TODO: Build context-aware prompt
        # TODO: Parse response and identify updated fields

        return {
            "agent_reply": "Processing your response...",
            "updated_fields": {},
            "completeness_percentage": 50,
        }

    def _mock_structured_output(self, raw_input: str) -> dict:
        """Mock output for local development without Vertex AI."""
        first_words = raw_input[:50].strip()
        return {
            "display_title": f"Innovation: {first_words}...",
            "short_pitch": f"A novel approach: {raw_input[:200]}",
            "virality_tags": ["Innovation", "Technology", "Prototype"],
            "technical_field": "General Technology",
            "background_problem": "Extracted from user input - needs refinement",
            "solution_summary": raw_input[:500],
            "core_mechanics": [
                {"step": 1, "description": "Core mechanism to be defined"},
            ],
            "novelty_claims": ["Unique approach - needs AI analysis"],
            "hardware_requirements": [],
            "software_logic": "",
            "feasibility_score": 5,
            "missing_info": [
                "Specific technical mechanism",
                "Target market/use case",
                "Prototype materials",
            ],
            "agent_reply": (
                f"Interesting idea! I've created an initial draft based on your description. "
                f"To make this stronger, can you tell me: "
                f"1) What specific problem does this solve? "
                f"2) How does the core mechanism work step by step? "
                f"3) What makes this different from existing solutions?"
            ),
        }
