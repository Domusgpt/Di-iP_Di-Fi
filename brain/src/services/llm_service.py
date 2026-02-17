"""
LLM Service - Wraps Vertex AI / Gemini for structured invention analysis.

Uses LangChain for prompt management and output parsing.
"""

import json
import logging
import os

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

CONVERSATION_PROMPT = """You are continuing to refine an invention brief as the IdeaCapital AI Co-Founder.

The current draft state of the invention is:
{draft_json}

The conversation history so far:
{history}

The user just said: {user_message}

Based on this, respond with a JSON object containing:
{{
  "agent_reply": "Your conversational response — ask follow-up questions if needed",
  "updated_fields": {{
    // Only include fields that should be updated based on the user's response
    // e.g. "solution_summary": "Updated solution text",
    // "core_mechanics": [{{"step": 1, "description": "..."}}]
  }},
  "completeness_percentage": 65
}}

Focus on filling gaps in the schema. The completeness_percentage should reflect how
complete the patent brief is (0-100). Prioritize: novelty_claims, core_mechanics,
background_problem, and solution_summary.
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
            # Check for credentials before attempting to load
            if not os.getenv("GOOGLE_APPLICATION_CREDENTIALS") and not os.getenv("GOOGLE_CLOUD_PROJECT"):
                logger.info("No Google credentials found, defaulting to mock mode.")
                return None

            try:
                from langchain_google_vertexai import ChatVertexAI

                self._model = ChatVertexAI(
                    model_name="gemini-1.5-pro",
                    project=self.project_id,
                    location=self.location,
                    temperature=0.3,
                    max_output_tokens=4096,
                )
                logger.info("Vertex AI model initialized successfully.")
            except ImportError:
                logger.warning("langchain_google_vertexai not installed, using mock.")
                self._model = None
            except Exception as e:
                logger.warning(f"Vertex AI initialization failed, using mock: {e}")
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
        Loads draft state and conversation history from Firestore.
        """
        model = self._get_model()

        if model is None:
            return self._mock_conversation_response(user_message)

        try:
            # Load conversation history and draft from Firestore
            draft, history = await self._load_invention_context(invention_id)

            from langchain_core.messages import SystemMessage, HumanMessage

            prompt = CONVERSATION_PROMPT.format(
                draft_json=json.dumps(draft, indent=2) if draft else "{}",
                history=self._format_history(history),
                user_message=user_message,
            )

            messages = [
                SystemMessage(content=INVENTION_STRUCTURING_PROMPT),
                HumanMessage(content=prompt),
            ]

            response = await model.ainvoke(messages)
            content = response.content

            if "```json" in content:
                content = content.split("```json")[1].split("```")[0]
            elif "```" in content:
                content = content.split("```")[1].split("```")[0]

            result = json.loads(content.strip())

            # Store this exchange in conversation history
            await self._save_conversation_turn(
                invention_id, user_message, result.get("agent_reply", "")
            )

            return result

        except Exception as e:
            logger.error(f"Conversation continuation failed: {e}")
            return self._mock_conversation_response(user_message)

    async def _load_invention_context(self, invention_id: str) -> tuple[dict, list]:
        """Load the current invention draft and conversation history from Firestore."""
        try:
            from google.cloud import firestore as gc_firestore

            db = gc_firestore.AsyncClient()

            # Load invention draft
            doc = await db.collection("inventions").document(invention_id).get()
            draft = doc.to_dict() if doc.exists else {}

            # Load conversation history (last 20 messages)
            history_ref = (
                db.collection("inventions")
                .document(invention_id)
                .collection("conversation_history")
                .order_by("created_at")
                .limit(20)
            )
            history_docs = await history_ref.get()
            history = [h.to_dict() for h in history_docs]

            return draft, history

        except Exception as e:
            logger.warning(f"Failed to load invention context: {e}")
            return {}, []

    async def _save_conversation_turn(
        self, invention_id: str, user_message: str, agent_reply: str
    ):
        """Save a conversation turn to Firestore."""
        try:
            from google.cloud import firestore as gc_firestore

            db = gc_firestore.AsyncClient()
            history_ref = (
                db.collection("inventions")
                .document(invention_id)
                .collection("conversation_history")
            )

            await history_ref.add({
                "role": "user",
                "content": user_message,
                "created_at": gc_firestore.SERVER_TIMESTAMP,
            })
            await history_ref.add({
                "role": "assistant",
                "content": agent_reply,
                "created_at": gc_firestore.SERVER_TIMESTAMP,
            })

        except Exception as e:
            logger.warning(f"Failed to save conversation turn: {e}")

    def _format_history(self, history: list) -> str:
        """Format conversation history for the prompt."""
        if not history:
            return "(No prior conversation)"
        lines = []
        for turn in history:
            role = turn.get("role", "unknown")
            content = turn.get("content", "")
            lines.append(f"{role.upper()}: {content}")
        return "\n".join(lines)

    def _mock_conversation_response(self, user_message: str) -> dict:
        """Mock conversation response for local development."""
        lower = user_message.lower()
        # Simulate intelligent follow-up based on keywords
        if any(w in lower for w in ["material", "component", "hardware"]):
            return {
                "agent_reply": (
                    "Great details on the materials. I've updated the hardware requirements. "
                    "Now, can you walk me through the step-by-step process of how a user "
                    "would interact with this invention?"
                ),
                "updated_fields": {
                    "hardware_requirements": [f"Based on user input: {user_message[:100]}"],
                },
                "completeness_percentage": 70,
            }
        elif any(w in lower for w in ["problem", "solve", "issue"]):
            return {
                "agent_reply": (
                    "I've captured the problem statement. This helps strengthen the patent claim. "
                    "What existing solutions have you seen, and what specifically makes your "
                    "approach different?"
                ),
                "updated_fields": {
                    "background_problem": user_message[:300],
                },
                "completeness_percentage": 60,
            }
        else:
            return {
                "agent_reply": (
                    "Thanks for that detail. I've updated your brief. "
                    "Can you tell me more about the specific materials or "
                    "components you envision for the prototype?"
                ),
                "updated_fields": {},
                "completeness_percentage": 55,
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
                "Interesting idea! I've created an initial draft based on your description. "
                "To make this stronger, can you tell me: "
                "1) What specific problem does this solve? "
                "2) How does the core mechanism work step by step? "
                "3) What makes this different from existing solutions?"
            ),
        }
