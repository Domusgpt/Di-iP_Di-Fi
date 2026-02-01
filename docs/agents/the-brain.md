# The Brain -- Python AI Agent Specification

> **Service:** `brain/`
> **Role:** The AI Co-Founder
> **Runtime:** Python 3.11, FastAPI, LangChain, Vertex AI (Gemini 1.5 Pro)
> **Port:** 8081

---

## Purpose

The Brain is IdeaCapital's AI layer. It acts as an AI Co-Founder that interviews inventors, transforms raw ideas into structured patent-ready briefs, and performs prior art analysis. It is the only service that communicates with the LLM and is responsible for all natural-language understanding in the platform.

The Brain does **not** serve the Flutter frontend directly. All user-facing traffic routes through the TypeScript Cloud Functions backend, which dispatches work to The Brain via Google Cloud Pub/Sub.

---

## Technology Stack

| Component | Technology |
|-----------|------------|
| Language | Python 3.11 |
| Web Framework | FastAPI (async, with lifespan hooks) |
| LLM Orchestration | LangChain (`langchain-google-vertexai`) |
| LLM Model | Vertex AI Gemini 1.5 Pro (temperature 0.3, max 4096 tokens) |
| Messaging | Google Cloud Pub/Sub (`google-cloud-pubsub`) |
| Persistence | Google Cloud Firestore (conversation history) |
| HTTP Client | httpx (async, 120s timeout) |
| Data Validation | Pydantic v2 |
| Testing | pytest, pytest-asyncio, httpx AsyncClient |
| Formatting / Linting | black, ruff |

---

## Architecture

### Source Layout

```
brain/
  Dockerfile
  pyproject.toml
  requirements.txt
  src/
    __init__.py
    main.py                          # FastAPI app with lifespan
    agents/
      __init__.py
      invention_agent.py             # Router: /analyze and /chat endpoints
    models/
      __init__.py
      invention.py                   # Pydantic models mirroring InventionSchema.json
    prompts/
      __init__.py
      invention_prompts.py           # Prompt templates for each interview phase
    services/
      __init__.py
      llm_service.py                 # LLMService class (Vertex AI + mock fallback)
      patent_search.py               # PatentSearchService (mock, Google Patents planned)
      pubsub_listener.py             # Background Pub/Sub subscriber
  tests/
    __init__.py
    test_invention_agent.py          # 8 endpoint tests
    test_llm_service.py              # 6 LLM service tests (mock mode)
    test_patent_search.py            # 4 patent search tests
```

### Module Responsibilities

| Module | Responsibility |
|--------|---------------|
| `main.py` | Creates the FastAPI application, registers CORS middleware, mounts the invention router at `/api/brain`, exposes `/health`. Uses the `lifespan` context manager to start the Pub/Sub listener on startup and cancel it on shutdown. |
| `invention_agent.py` | FastAPI `APIRouter` with two endpoints: `POST /analyze` (Phase 1 ingestion) and `POST /chat` (Phase 2/3 refinement). Orchestrates calls to `LLMService` and `PatentSearchService`. |
| `llm_service.py` | `LLMService` class that wraps Vertex AI Gemini 1.5 Pro via LangChain. Lazy-loads the model on first use. Falls back to deterministic mock responses when credentials are unavailable. Manages Firestore reads/writes for conversation history. |
| `patent_search.py` | `PatentSearchService` that will integrate with the Google Patents API. Currently returns mock results. Falls back gracefully when no API key is configured. |
| `pubsub_listener.py` | Starts a background `asyncio.Task` that subscribes to the `ai.processing` Pub/Sub topic. Routes incoming messages to agent endpoints via internal HTTP calls using httpx. Publishes results to `ai.processing.complete`. |

---

## The Onboarding Script

The Brain follows a three-phase "interview" protocol to convert a raw idea into a structured patent brief.

### Phase 1: Napkin Sketch (Initial Ingestion)

**Endpoint:** `POST /api/brain/analyze`

**Request (`AnalyzeRequest`):**
```json
{
  "invention_id": "uuid-v4",
  "creator_id": "firebase-uid",
  "raw_text": "A drone that cleans gutters...",
  "voice_url": "https://storage.example.com/voice/note.mp3",
  "sketch_url": "https://storage.example.com/sketches/napkin.jpg"
}
```

At least one of `raw_text`, `voice_url`, or `sketch_url` must be provided. If none are given, the endpoint returns HTTP 400.

**Processing Flow:**
1. Combine all inputs into a single context string.
2. Send context to Gemini via `LLMService.structure_invention()` with the structuring system prompt.
3. In parallel, run `PatentSearchService.search_prior_art()` using the `technical_field` and `solution_summary` extracted by the LLM.
4. Assemble the response from LLM output and prior art results.

**Response (`AnalyzeResponse`):**
```json
{
  "invention_id": "uuid-v4",
  "status": "REVIEW_READY",
  "social_metadata": {
    "display_title": "GutterDrone Pro",
    "short_pitch": "An autonomous drone that pressure-washes residential gutters",
    "virality_tags": ["Robotics", "HomeTech", "Drones"]
  },
  "technical_brief": {
    "technical_field": "Consumer Robotics - Home Maintenance",
    "background_problem": "Gutter cleaning is dangerous and expensive...",
    "solution_summary": "A lightweight drone with a high-pressure nozzle...",
    "core_mechanics": [{"step": 1, "description": "..."}],
    "novelty_claims": ["Autonomous gutter-edge detection via LiDAR"],
    "hardware_requirements": ["Drone frame", "High-pressure pump"],
    "software_logic": "Path-planning algorithm..."
  },
  "risk_assessment": {
    "potential_prior_art": [
      {
        "source": "Google Patents API",
        "patent_id": "US-12345678",
        "similarity_score": 0.45,
        "notes": "Related cleaning drone patent..."
      }
    ],
    "feasibility_score": 7,
    "missing_info": ["Nozzle pressure specification", "Battery capacity"]
  },
  "agent_message": "Interesting concept! I've drafted your brief. Can you clarify the nozzle mechanism?"
}
```

### Phase 2: Drill Down (Conversational Refinement)

**Endpoint:** `POST /api/brain/chat`

**Request (`ChatRequest`):**
```json
{
  "invention_id": "uuid-v4",
  "creator_id": "firebase-uid",
  "message": "The nozzle uses a rotating head at 2000 PSI..."
}
```

**Processing Flow:**
1. Load the current invention draft from Firestore (`inventions/{id}`).
2. Load the last 20 conversation turns from Firestore (`inventions/{id}/conversation_history/{turnId}`).
3. Build a context-aware prompt containing the draft state, formatted history, and the user's new message.
4. Send to Gemini, which identifies fields to update and generates a follow-up question.
5. Save the user message and agent reply as new conversation turns in Firestore.

**Response:**
```json
{
  "invention_id": "uuid-v4",
  "agent_message": "Great detail on the nozzle. I've updated core_mechanics. What material is the frame?",
  "updated_fields": {
    "core_mechanics": [{"step": 1, "description": "Rotating nozzle at 2000 PSI..."}]
  },
  "schema_completeness": 65
}
```

### Phase 3: Sanity Check (Prior Art Validation)

The sanity check is integrated into Phase 1 rather than being a separate endpoint. The `patent_search` results populate the `risk_assessment.potential_prior_art` array in the `AnalyzeResponse`. As the conversation continues in Phase 2, the agent can re-evaluate novelty claims against known prior art.

---

## System Prompt Design

The Brain's persona is defined in two locations:
- `llm_service.py`: Contains the inline `INVENTION_STRUCTURING_PROMPT` and `CONVERSATION_PROMPT` used for runtime calls.
- `prompts/invention_prompts.py`: Contains the more detailed `SYSTEM_PROMPT`, `INITIAL_ANALYSIS_PROMPT`, `DRILL_DOWN_PROMPT`, and `PRIOR_ART_ANALYSIS_PROMPT` templates for future use.

### Persona Rules

| Rule | Description |
|------|-------------|
| Identity | Patent analyst, not a chatbot |
| Tone | Encouraging but precise -- startup mentor warmth with engineering rigor |
| Primary Goal | Hunt for the "novelty claim" -- the one specific element that makes the invention patentable |
| Output Format | Always structured JSON matching the defined field schema |
| Missing Information | Listed explicitly in the `missing_info` array and asked about conversationally in `agent_reply` |
| Conversation Style | Always ends with a specific follow-up question to drill deeper |

### Interview Phases in Prompts

| Phase | Prompt Goal |
|-------|-------------|
| Phase 1 (Ingest) | Understand the core idea; generate title, problem statement, and initial structure |
| Phase 2 (Drill Down) | Ask about mechanism, materials, and logic flow; identify the novelty claim |
| Phase 3 (Validate) | Check feasibility, flag prior art concerns, confirm novelty claims |

---

## Conversation History Management

### Storage

Conversation history is stored in Firestore as a subcollection:

```
inventions/{inventionId}/conversation_history/{turnId}
```

Each document represents one turn:
```json
{
  "role": "user" | "assistant",
  "content": "The message text",
  "created_at": "<Firestore SERVER_TIMESTAMP>"
}
```

### Loading and Formatting

- The `_load_invention_context()` method fetches the last **20 messages** ordered by `created_at`.
- History is formatted for the LLM prompt as plain text, one line per turn:
  ```
  USER: The nozzle uses a rotating head...
  ASSISTANT: Great detail. I've updated core_mechanics...
  USER: The frame is carbon fiber...
  ```
- If no history exists, the placeholder `(No prior conversation)` is used.

### Saving

After each successful LLM call in `continue_conversation()`, both the user message and the agent reply are saved as separate documents in the subcollection, each with `SERVER_TIMESTAMP`.

---

## Pub/Sub Integration

### Subscription

| Parameter | Value |
|-----------|-------|
| Topic | `ai.processing` |
| Subscription | `ai-processing-brain-sub` |
| Trigger | TypeScript backend dispatches an AI processing request |

### Publishing

| Parameter | Value |
|-----------|-------|
| Topic | `ai.processing.complete` |
| Trigger | After the agent finishes processing |

### Message Routing

The Pub/Sub callback inspects the `action` field in the incoming message and routes accordingly:

| Action | Handler | Internal Call | Published Data |
|--------|---------|---------------|----------------|
| `INITIAL_ANALYSIS` | `_process_initial_analysis()` | `POST /api/v1/brain/analyze` via httpx | `social_metadata`, `technical_brief`, `risk_assessment` |
| `CONTINUE_CHAT` | `_process_continue_chat()` | `POST /api/v1/brain/chat` via httpx | `updated_fields` from the chat response |

### Threading Model

The Google Cloud Pub/Sub client uses a synchronous callback model, but the agent endpoints are async. The listener bridges this gap using `asyncio.run_coroutine_threadsafe()` to schedule async handlers on the main event loop from within the synchronous Pub/Sub callback thread.

### Startup and Shutdown

- On startup: The FastAPI `lifespan` context manager calls `start_pubsub_listener()`, which creates an `asyncio.Task` running the `_listen_loop`.
- On shutdown: The task is cancelled via `listener_task.cancel()`.
- If `GOOGLE_CLOUD_PROJECT` is not set, the listener is silently disabled (returns `None`).

---

## Mock Mode

Mock mode activates automatically when Vertex AI is unavailable. This happens when:
- Google Cloud credentials are not configured.
- The `langchain-google-vertexai` package fails to import.
- Any exception occurs during model initialization.

### Mock Behaviors

| Method | Mock Behavior |
|--------|---------------|
| `structure_invention()` | Returns a template with a title derived from input, pitch, 3 virality tags (`Innovation`, `Technology`, `Prototype`), `feasibility_score` of 5, 3 `missing_info` items asking about mechanism, market, and materials. |
| `continue_conversation()` | Keyword-aware responses: messages containing "material"/"component"/"hardware" update `hardware_requirements` (70% complete); messages containing "problem"/"solve"/"issue" update `background_problem` (60% complete); all other messages return a generic follow-up (55% complete). |
| `search_prior_art()` | Returns a single mock result with `patent_id: "US-MOCK-001"`, `similarity_score: 0.45`, and a note referencing the query. |

Mock mode enables full local development and testing of the entire platform without a GCP project or Vertex AI access.

---

## Data Models (Pydantic)

All models are defined in `brain/src/models/invention.py` and mirror the canonical `schemas/InventionSchema.json`.

### InventionDraft

The top-level model representing a full invention:

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| `invention_id` | `str` | required | UUID-v4 |
| `status` | `str` | `"DRAFT"` | Lifecycle state |
| `created_at` | `datetime` | `utcnow()` | |
| `updated_at` | `datetime` | `None` | |
| `creator_id` | `str` | required | Firebase UID |
| `social_metadata` | `SocialMetadata` | required | |
| `technical_brief` | `TechnicalBrief` | `None` | |
| `risk_assessment` | `RiskAssessment` | `None` | |
| `funding` | `Funding` | `None` | |
| `blockchain_ref` | `BlockchainRef` | `None` | |

### SocialMetadata

| Field | Type | Constraint |
|-------|------|------------|
| `display_title` | `str` | max_length=60 |
| `short_pitch` | `str` | max_length=280 |
| `virality_tags` | `list[str]` | |
| `media_assets` | `MediaAssets` | optional |

### TechnicalBrief

| Field | Type |
|-------|------|
| `technical_field` | `str` (optional) |
| `background_problem` | `str` (optional) |
| `solution_summary` | `str` (optional) |
| `core_mechanics` | `list[CoreMechanic]` (each has `step: int` and `description: str`) |
| `novelty_claims` | `list[str]` |
| `hardware_requirements` | `list[str]` |
| `software_logic` | `str` (optional) |

### RiskAssessment

| Field | Type | Constraint |
|-------|------|------------|
| `potential_prior_art` | `list[PriorArt]` | Each has `source`, `patent_id`, `similarity_score` (0-1), `notes` |
| `feasibility_score` | `int` | 1-10, default 5 |
| `missing_info` | `list[str]` | |

### Supporting Models

- **MediaAssets:** `hero_image_url`, `explainer_video_url`, `thumbnail_url`, `gallery: list[str]`
- **CoreMechanic:** `step: int`, `description: str`
- **PriorArt:** `source: str`, `patent_id: str`, `similarity_score: float` (0-1), `notes: str`
- **Funding:** `goal_usdc`, `raised_usdc`, `backer_count`, `min_investment_usdc`, `royalty_percentage`, `deadline`, `token_supply`
- **BlockchainRef:** `nft_contract_address`, `nft_token_id`, `royalty_token_address`, `crowdsale_address`, `chain_id`, `ipfs_metadata_cid`

---

## Testing

All tests run with `pytest` and use mock mode (no GCP credentials required).

### Test Suites

#### test_invention_agent.py (8 tests)

| Test | Validates |
|------|-----------|
| `test_health_check` | `/health` returns 200 with service name |
| `test_analyze_idea_with_text` | Full analyze flow with `raw_text` input; checks all response sections |
| `test_analyze_idea_requires_input` | Returns 400 when no input provided |
| `test_analyze_idea_with_voice_url` | Accepts `voice_url` input, returns `REVIEW_READY` |
| `test_analyze_idea_with_sketch_url` | Accepts `sketch_url` input, returns `REVIEW_READY` |
| `test_continue_chat` | Chat continuation returns `agent_message`, `schema_completeness` |
| `test_social_metadata_constraints` | `display_title` length is reasonable, `virality_tags` is a list |
| `test_risk_assessment_format` | `potential_prior_art` is a list, `feasibility_score` is 1-10, `missing_info` is a list |

#### test_llm_service.py (6 tests)

| Test | Validates |
|------|-----------|
| `test_mock_structured_output` | All 13 required fields present in mock output |
| `test_mock_output_types` | Correct Python types for each field |
| `test_mock_output_has_content` | Non-empty title, pitch, reply; feasibility in range |
| `test_structure_invention_falls_back_to_mock` | `structure_invention()` returns valid output without credentials |
| `test_continue_conversation_mock` | `continue_conversation()` returns `agent_reply` and `completeness_percentage` |

Note: The 6th test is the implicit async fallback verification within `test_structure_invention_falls_back_to_mock`.

#### test_patent_search.py (4 tests)

| Test | Validates |
|------|-----------|
| `test_search_returns_list` | Returns non-empty list for valid query |
| `test_search_result_structure` | Each result has `source`, `patent_id`, `similarity_score` (0-1), `notes` |
| `test_empty_query_returns_empty` | Empty query returns empty list |
| `test_mock_results_format` | Mock results have correct field types |

### Running Tests

```bash
cd brain && pytest tests/ -v
```

All tests use `TestClient` (synchronous wrapper) or `pytest-asyncio` for async service methods. No external services or credentials are required.

---

## Configuration

### Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `VERTEX_AI_PROJECT` | `ideacapital-dev` | Google Cloud project ID for Vertex AI |
| `VERTEX_AI_LOCATION` | `us-central1` | Vertex AI region |
| `GOOGLE_CLOUD_PROJECT` | (none) | Required for Pub/Sub; if unset, listener is disabled |
| `GOOGLE_PATENTS_API_KEY` | (none) | Google Patents API key; if unset, mock results are used |
| `AGENT_BASE_URL` | `http://127.0.0.1:8081` | Base URL for internal httpx calls from the Pub/Sub listener |

### Running Locally

```bash
# Start the service (mock mode, no GCP required)
cd brain && uvicorn src.main:app --port 8081 --reload

# Start with Docker
docker compose up brain
```

---

## Integration Boundaries

The Brain communicates exclusively through two interfaces:

1. **Pub/Sub** (primary): Subscribes to `ai.processing`, publishes to `ai.processing.complete`. This is the production path used when the TypeScript backend dispatches work.

2. **HTTP** (internal): The Pub/Sub listener calls its own FastAPI endpoints via httpx at `AGENT_BASE_URL`. The endpoints are also available for direct HTTP calls during development and testing.

The Brain does **not**:
- Serve the Flutter frontend directly.
- Write to the Vault's PostgreSQL database.
- Interact with the blockchain.
- Manage user authentication (that is the TypeScript backend's responsibility).

The Brain **does** read and write Firestore directly for conversation history management under `inventions/{id}/conversation_history/`.
