# The Brain -- AI Co-Founder Agent Guide

> **Service:** `brain/` (Python 3.11 / FastAPI)
> **Port:** 8081
> **Role:** Transform raw invention ideas into structured, patent-ready briefs through a guided conversation.

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [The Onboarding Script](#the-onboarding-script)
4. [System Prompt and Persona](#system-prompt-and-persona)
5. [Conversation History](#conversation-history)
6. [API Reference](#api-reference)
7. [Integration Points](#integration-points)
8. [Mock Mode (Local Development)](#mock-mode-local-development)
9. [Testing](#testing)

---

## Overview

The Brain is a Python/FastAPI microservice that serves as the AI Co-Founder of IdeaCapital. It uses **Vertex AI (Gemini 1.5 Pro)** via LangChain to take a raw invention idea -- submitted as text, a voice note URL, or a sketch URL -- and structure it into a patent-ready brief with social metadata, technical details, and a risk assessment.

The agent follows a three-phase **Onboarding Script**:

1. **Napkin Sketch** (Ingest) -- Capture the core idea and produce an initial structured draft.
2. **Drill Down** (Flesh Out) -- Conduct a multi-turn conversation to fill gaps in the schema.
3. **Sanity Check** (Validate) -- Run prior art searches and assess feasibility.

The Brain does not serve the Flutter frontend directly. It is reached either through **Cloud Pub/Sub** messages dispatched by the TypeScript Cloud Functions backend, or via **direct HTTP** calls proxied through Cloud Functions.

---

## Architecture

### Module Map

```
brain/
  Dockerfile                      # Multi-stage build, runs uvicorn on port 8081
  requirements.txt                # Python dependencies
  src/
    main.py                       # FastAPI app with lifespan (starts Pub/Sub listener)
    agents/
      invention_agent.py          # HTTP endpoints: /analyze, /chat
    services/
      llm_service.py              # Vertex AI (Gemini 1.5 Pro) wrapper + mock fallback
      patent_search.py            # Prior art search (mock now, Google Patents API planned)
      pubsub_listener.py          # Subscribes to ai.processing, publishes to ai.processing.complete
    models/
      invention.py                # Pydantic models mirroring InventionSchema.json
    prompts/
      invention_prompts.py        # All LLM prompt templates (system prompt, per-phase prompts)
  tests/
    test_invention_agent.py       # Endpoint-level integration tests
    test_llm_service.py           # LLM service unit tests (mock mode)
    test_patent_search.py         # Patent search unit tests
```

### Startup Sequence

1. FastAPI creates the application with a **lifespan context manager** (`main.py`).
2. On startup, `start_pubsub_listener()` is called, which creates a background `asyncio.Task` that subscribes to the `ai-processing-brain-sub` Pub/Sub subscription.
3. The Pub/Sub listener runs in the background, routing incoming messages to the `/analyze` or `/chat` endpoints via internal HTTP calls.
4. On shutdown, the listener task is cancelled.

### Key Dependencies

| Dependency | Purpose |
|---|---|
| `fastapi` + `uvicorn` | HTTP framework and ASGI server |
| `langchain-google-vertexai` | LangChain integration for Gemini 1.5 Pro |
| `langchain-core` | Message types (`SystemMessage`, `HumanMessage`) |
| `google-cloud-pubsub` | Pub/Sub subscriber and publisher clients |
| `google-cloud-firestore` | Async Firestore client for conversation state |
| `httpx` | Async HTTP client for internal calls and patent search |
| `pydantic` | Request/response validation and data models |

---

## The Onboarding Script

The Onboarding Script defines how the Brain interviews an inventor across three phases. Each phase maps to specific API endpoints and prompt templates.

### Phase 1: "Napkin Sketch" (Ingest)

**Endpoint:** `POST /api/brain/analyze`

**Trigger:** User submits a raw idea via the Flutter "Agent Composer" screen. The TypeScript backend publishes an `ai.processing` message with action `INITIAL_ANALYSIS`, or calls the Brain directly.

**Input:** One or more of:
- `raw_text` -- Free-form text description of the idea
- `voice_url` -- URL to a voice note in Cloud Storage (transcription pending implementation)
- `sketch_url` -- URL to a sketch/image in Cloud Storage (vision analysis pending implementation)

**Processing:**
1. All inputs are combined into a single context string.
2. The context is sent to Vertex AI with the `INVENTION_STRUCTURING_PROMPT` system prompt.
3. The LLM returns structured JSON which is parsed into the following output fields.
4. A parallel prior art search is executed against the extracted `technical_field` and `solution_summary`.

**Output:** Structured JSON with three sections:

```json
{
  "invention_id": "uuid",
  "status": "REVIEW_READY",
  "social_metadata": {
    "display_title": "Catchy name (max 60 chars)",
    "short_pitch": "One-sentence pitch (max 280 chars)",
    "virality_tags": ["Tag1", "Tag2", "Tag3"]
  },
  "technical_brief": {
    "technical_field": "Category of technology",
    "background_problem": "What problem does this solve?",
    "solution_summary": "How does it solve it?",
    "core_mechanics": [{"step": 1, "description": "..."}],
    "novelty_claims": ["What makes this unique"],
    "hardware_requirements": ["Required components"],
    "software_logic": "Algorithm description if applicable"
  },
  "risk_assessment": {
    "potential_prior_art": [
      {
        "source": "Google Patents API",
        "patent_id": "US-XXXX-XXX",
        "similarity_score": 0.45,
        "notes": "Related to ..."
      }
    ],
    "feasibility_score": 7,
    "missing_info": ["Specific technical mechanism", "Target market"]
  },
  "agent_message": "Conversational response with follow-up questions"
}
```

### Phase 2: "Drill Down" (Flesh Out)

**Endpoint:** `POST /api/brain/chat`

**Trigger:** User responds to the agent's follow-up questions in the Flutter chat interface. The TypeScript backend publishes an `ai.processing` message with action `CONTINUE_CHAT`.

**Processing:**
1. The current invention draft is loaded from Firestore (`inventions/{id}`).
2. The last 20 conversation turns are loaded from Firestore (`inventions/{id}/conversation_history/`).
3. The draft, history, and new user message are assembled into the `CONVERSATION_PROMPT` template.
4. The LLM is asked to update specific schema fields and assess overall completeness.
5. The new conversation turn (user message + agent reply) is saved back to Firestore.

**Output:**

```json
{
  "invention_id": "uuid",
  "agent_message": "Follow-up response with targeted question",
  "updated_fields": {
    "solution_summary": "Updated solution text",
    "core_mechanics": [{"step": 1, "description": "Refined step"}]
  },
  "schema_completeness": 65
}
```

The `completeness_percentage` (exposed as `schema_completeness` in the response) tracks how filled-in the patent brief is on a 0-100 scale. The LLM prioritizes filling: `novelty_claims`, `core_mechanics`, `background_problem`, and `solution_summary`.

### Phase 3: "Sanity Check" (Validate)

The Sanity Check is integrated into both phases rather than being a standalone step:

- **During Phase 1:** Prior art search results are automatically included in the `risk_assessment.potential_prior_art` field of the initial analysis response.
- **During Phase 2:** As the brief reaches higher completeness, the `DRILL_DOWN_PROMPT` instructs the agent to identify the strongest patentable element via the `identified_novelty` field and flag feasibility concerns.
- **Prior Art Analysis:** The `PRIOR_ART_ANALYSIS_PROMPT` template (in `invention_prompts.py`) is designed to assess each search result for similarity, key differences, and whether it blocks patentability.

The `PatentSearchService` currently returns mock results. When the Google Patents API integration is complete, real patent data will flow into the risk assessment automatically.

---

## System Prompt and Persona

The Brain operates under a carefully defined persona. There are two prompt layers.

### Layer 1: Structuring Prompt (`llm_service.py`)

Used for the `/analyze` endpoint and as the system message for all LLM calls:

> You are the IdeaCapital AI Co-Founder. Your job is to take a rough invention idea and structure it into a patent-ready brief.
>
> You are NOT a chatbot. You are a patent analyst. Your tone is:
> - Encouraging but precise
> - You ask targeted engineering questions
> - You hunt for the "novelty claim" -- the specific unique element that makes this patentable
>
> Output is always structured JSON.

### Layer 2: Interview Persona (`invention_prompts.py`)

A more detailed persona used to guide behavior across all phases:

> You are the IdeaCapital AI Co-Founder -- a brilliant patent analyst with the warmth of a startup mentor.

**Six rules the agent follows:**

1. Never be vague. Ask specific engineering questions.
2. Hunt for the "novelty claim" -- the ONE thing that makes this patentable.
3. Be encouraging but honest about feasibility.
4. Structure everything into the canonical schema format.
5. When a potential novelty claim is identified, call it out explicitly.
6. Always end with a specific question to drill deeper.

### Key Behavioral Characteristics

- **Not a chatbot.** The agent does not engage in small talk. Every response is oriented toward filling the patent brief schema.
- **Novelty-obsessed.** The agent actively searches for what differentiates this invention from existing solutions.
- **Structured output.** Every response is JSON. The agent never returns unstructured prose as its primary output.
- **Encouraging but precise.** The agent acknowledges what the inventor has shared, then immediately follows with the next most important question.
- **Gap-aware.** The agent tracks which schema fields are empty or weak and directs conversation toward filling them.

---

## Conversation History

### Storage Schema

Conversation history is stored in Firestore under a subcollection of each invention:

```
inventions/{inventionId}/conversation_history/{turnId}
```

Each document in the subcollection represents one message and contains:

| Field | Type | Description |
|---|---|---|
| `role` | `string` | Either `"user"` or `"assistant"` |
| `content` | `string` | The text content of the message |
| `created_at` | `timestamp` | Firestore server timestamp, set automatically |

### Context Window Management

When the agent continues a conversation via `/chat`:

1. The current invention draft document is loaded from `inventions/{inventionId}`.
2. Conversation history is queried with `.order_by("created_at").limit(20)`, retrieving the **last 20 messages** as context.
3. History is formatted as `ROLE: content` lines and injected into the `CONVERSATION_PROMPT`.
4. After the LLM responds, both the user message and agent reply are saved as two new documents in the subcollection, each with `SERVER_TIMESTAMP`.

This design ensures the agent has sufficient conversational context without exceeding the LLM's token limits.

---

## API Reference

### `GET /health`

Health check endpoint.

**Response:**
```json
{
  "status": "ok",
  "service": "ideacapital-brain",
  "version": "0.1.0"
}
```

### `POST /api/brain/analyze`

Phase 1: Initial idea analysis.

**Request Body:**
```json
{
  "invention_id": "string (required)",
  "creator_id": "string (required)",
  "raw_text": "string (optional)",
  "voice_url": "string (optional)",
  "sketch_url": "string (optional)"
}
```

At least one of `raw_text`, `voice_url`, or `sketch_url` must be provided. Returns HTTP 400 if none are provided.

**Response:** See [Phase 1 Output](#phase-1-napkin-sketch-ingest) above.

### `POST /api/brain/chat`

Phase 2/3: Continue the invention refinement conversation.

**Request Body:**
```json
{
  "invention_id": "string (required)",
  "creator_id": "string (required)",
  "message": "string (required)"
}
```

**Response:**
```json
{
  "invention_id": "string",
  "agent_message": "string",
  "updated_fields": {},
  "schema_completeness": 0
}
```

---

## Integration Points

### Pub/Sub Message Flow

The Brain participates in two Pub/Sub topics:

```
TypeScript Backend                      The Brain                      TypeScript Backend
       |                                    |                                  |
       |--- ai.processing (action:         |                                  |
       |    INITIAL_ANALYSIS) ------------>|                                  |
       |                                    |--- calls /api/brain/analyze     |
       |                                    |--- processes with LLM           |
       |                                    |--- ai.processing.complete ----->|
       |                                    |    (action: INITIAL_ANALYSIS)   |
       |                                    |                                  |
       |--- ai.processing (action:         |                                  |
       |    CONTINUE_CHAT) --------------->|                                  |
       |                                    |--- calls /api/brain/chat        |
       |                                    |--- processes with LLM           |
       |                                    |--- ai.processing.complete ----->|
       |                                    |    (action: CHAT_RESPONSE)      |
```

### Pub/Sub Subscription

- **Subscription name:** `ai-processing-brain-sub`
- **Subscribed topic:** `ai.processing`
- **Message format (inbound):**

```json
{
  "action": "INITIAL_ANALYSIS | CONTINUE_CHAT",
  "invention_id": "string",
  "creator_id": "string",
  "raw_text": "string (for INITIAL_ANALYSIS)",
  "voice_url": "string (for INITIAL_ANALYSIS)",
  "sketch_url": "string (for INITIAL_ANALYSIS)",
  "message": "string (for CONTINUE_CHAT)"
}
```

- **Published topic:** `ai.processing.complete`
- **Message format (outbound):**

```json
{
  "invention_id": "string",
  "action": "INITIAL_ANALYSIS | CHAT_RESPONSE",
  "structured_data": {
    "social_metadata": {},
    "technical_brief": {},
    "risk_assessment": {}
  }
}
```

### Downstream Consumer

The TypeScript Cloud Functions backend subscribes to `ai.processing.complete` and uses the `structured_data` payload to update the invention document in Firestore. The Flutter client reads the updated Firestore document in real time.

### Direct HTTP Access

The Brain can also be called directly via HTTP from Cloud Functions acting as a proxy. The internal URL within the Docker network is `http://brain:8081`. In production on Cloud Run, the service URL is assigned at deploy time.

### Firestore Access

The Brain reads and writes the following Firestore paths:

| Path | Operation | Purpose |
|---|---|---|
| `inventions/{id}` | Read | Load current invention draft for conversation context |
| `inventions/{id}/conversation_history/{turnId}` | Read/Write | Load last 20 messages; save new user + assistant turns |

---

## Mock Mode (Local Development)

When Vertex AI is unavailable (either `VERTEX_AI_PROJECT` is not set, or the `langchain-google-vertexai` import fails), the Brain automatically falls back to **mock mode**. This enables full local development and testing without GCP credentials.

### Mock Structured Output (`structure_invention`)

Returns a complete schema-compliant response with placeholder data:

- `display_title` is derived from the first 50 characters of input
- `virality_tags` default to `["Innovation", "Technology", "Prototype"]`
- `feasibility_score` defaults to 5
- `missing_info` always contains three follow-up questions:
  - "Specific technical mechanism"
  - "Target market/use case"
  - "Prototype materials"
- `agent_reply` asks three specific questions to move to Phase 2

### Mock Conversation Response (`continue_conversation`)

Mock responses vary based on keywords detected in the user's message:

| Keywords Detected | Updated Field | Completeness |
|---|---|---|
| `material`, `component`, `hardware` | `hardware_requirements` | 70% |
| `problem`, `solve`, `issue` | `background_problem` | 60% |
| Any other input | (none) | 55% |

Each mock response includes a conversational `agent_reply` that asks a relevant follow-up question, simulating the real agent's behavior.

### Mock Patent Search

When `GOOGLE_PATENTS_API_KEY` is not set, the `PatentSearchService` returns a single mock result:

```json
{
  "source": "Google Patents API (Mock)",
  "patent_id": "US-MOCK-001",
  "similarity_score": 0.45,
  "notes": "Related to: <query>. Mock result for development."
}
```

### Verifying Mock Mode

When the Brain starts in mock mode, you will see this log line:

```
WARNING - Vertex AI not available, using mock: <error details>
```

All endpoints remain fully functional. The only difference is that responses contain deterministic mock data instead of LLM-generated content.

---

## Testing

The Brain includes three test modules that run in mock mode (no GCP credentials required).

### Running Tests

```bash
cd brain
pip install -r requirements.txt
pip install pytest pytest-asyncio
python -m pytest tests/ -v --tb=short
```

### Test Modules

**`test_invention_agent.py`** -- Endpoint integration tests using FastAPI's `TestClient`:
- Health check returns expected service metadata
- `/analyze` with text input returns `REVIEW_READY` status with populated social metadata, technical brief, and risk assessment
- `/analyze` without any input returns HTTP 400
- `/analyze` accepts `voice_url` and `sketch_url` inputs
- `/chat` returns an agent message with schema completeness tracking
- Social metadata field constraints (title length, tag list format) are validated
- Risk assessment structure (prior art list, feasibility score range 1-10, missing info list) is validated

**`test_llm_service.py`** -- Unit tests for the LLM service mock outputs:
- Mock structured output contains all 13 required fields
- Output types are correct (strings, lists, integers as expected)
- Output contains meaningful non-empty content
- `structure_invention()` falls back to mock when Vertex AI is unavailable
- `continue_conversation()` returns mock with completeness percentage

**`test_patent_search.py`** -- Unit tests for the patent search service:
- Search returns a non-empty list for valid queries
- Each result has required fields (`source`, `patent_id`, `similarity_score`, `notes`)
- `similarity_score` is within the 0.0-1.0 range
- Empty queries return empty results
- Mock results conform to the expected schema
