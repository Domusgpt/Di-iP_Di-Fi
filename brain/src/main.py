"""
IdeaCapital Brain - AI Agent Service

The Brain is the AI layer of IdeaCapital. It handles:
- Invention idea ingestion (text, voice, images)
- Structured patent brief generation via LLM
- Prior art search via Google Patents API
- Concept art generation via Imagen
- Conversation-based invention refinement

Integration Points:
- Subscribes to: `ai.processing` Pub/Sub topic (from TypeScript backend)
- Publishes to: `ai.processing.complete` Pub/Sub topic
- Reads/Writes: Firestore (conversation state)
"""

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from src.agents.invention_agent import router as invention_router
from src.services.pubsub_listener import start_pubsub_listener

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Start background Pub/Sub listener on startup."""
    logger.info("Starting IdeaCapital Brain service")

    # Start listening for Pub/Sub messages in the background
    listener_task = start_pubsub_listener()
    logger.info("Pub/Sub listener started")

    yield

    # Cleanup
    if listener_task:
        listener_task.cancel()
    logger.info("Brain service shutting down")


app = FastAPI(
    title="IdeaCapital Brain",
    description="AI Agent for invention analysis and patent structuring",
    version="0.1.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Routes
app.include_router(invention_router, prefix="/api/brain", tags=["invention"])


@app.get("/health")
async def health_check():
    return {
        "status": "ok",
        "service": "ideacapital-brain",
        "version": "0.1.0",
    }
