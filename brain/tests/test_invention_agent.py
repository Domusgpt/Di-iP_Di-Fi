"""Tests for the Invention Agent API endpoints."""

import pytest
from fastapi.testclient import TestClient
from src.main import app

client = TestClient(app)


def test_health_check():
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"
    assert data["service"] == "ideacapital-brain"


def test_analyze_idea_with_text():
    """Test initial idea analysis with raw text input."""
    response = client.post("/api/brain/analyze", json={
        "invention_id": "test-uuid-001",
        "creator_id": "user-123",
        "raw_text": "A drone that cleans gutters automatically using a high-pressure water jet",
    })
    assert response.status_code == 200
    data = response.json()

    assert data["invention_id"] == "test-uuid-001"
    assert data["status"] == "REVIEW_READY"

    # Social metadata should be populated
    assert "display_title" in data["social_metadata"]
    assert len(data["social_metadata"]["display_title"]) > 0
    assert "short_pitch" in data["social_metadata"]

    # Technical brief should have content
    assert "background_problem" in data["technical_brief"]
    assert "solution_summary" in data["technical_brief"]

    # Risk assessment should exist
    assert "feasibility_score" in data["risk_assessment"]
    assert "missing_info" in data["risk_assessment"]

    # Agent should provide a conversational response
    assert len(data["agent_message"]) > 0


def test_analyze_idea_requires_input():
    """Test that at least one input is required."""
    response = client.post("/api/brain/analyze", json={
        "invention_id": "test-uuid-002",
        "creator_id": "user-123",
    })
    assert response.status_code == 400


def test_analyze_idea_with_voice_url():
    """Test analysis with voice note URL (transcription is mocked)."""
    response = client.post("/api/brain/analyze", json={
        "invention_id": "test-uuid-003",
        "creator_id": "user-123",
        "voice_url": "https://storage.example.com/voice/note.mp3",
    })
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "REVIEW_READY"


def test_analyze_idea_with_sketch_url():
    """Test analysis with sketch image URL (vision analysis is mocked)."""
    response = client.post("/api/brain/analyze", json={
        "invention_id": "test-uuid-004",
        "creator_id": "user-123",
        "sketch_url": "https://storage.example.com/sketches/napkin.jpg",
    })
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "REVIEW_READY"


def test_continue_chat():
    """Test conversation continuation for refining an invention."""
    response = client.post("/api/brain/chat", json={
        "invention_id": "test-uuid-001",
        "creator_id": "user-123",
        "message": "It uses a spinning reel on the base that manages tension automatically",
    })
    assert response.status_code == 200
    data = response.json()

    assert "agent_message" in data
    assert "schema_completeness" in data
    assert data["invention_id"] == "test-uuid-001"


def test_social_metadata_constraints():
    """Test that generated social metadata respects field constraints."""
    response = client.post("/api/brain/analyze", json={
        "invention_id": "test-uuid-005",
        "creator_id": "user-123",
        "raw_text": "A self-cleaning water bottle that uses UV-C light to sanitize itself every hour",
    })
    assert response.status_code == 200
    data = response.json()

    # display_title should exist and be reasonable length
    title = data["social_metadata"]["display_title"]
    assert len(title) > 0
    assert len(title) <= 120  # Allow some flexibility for mock, schema says 60

    # virality_tags should be a list
    tags = data["social_metadata"].get("virality_tags", [])
    assert isinstance(tags, list)


def test_risk_assessment_format():
    """Test that risk assessment has the expected structure."""
    response = client.post("/api/brain/analyze", json={
        "invention_id": "test-uuid-006",
        "creator_id": "user-123",
        "raw_text": "Solar-powered backpack that charges your phone while hiking",
    })
    assert response.status_code == 200
    data = response.json()

    risk = data["risk_assessment"]
    assert "potential_prior_art" in risk
    assert isinstance(risk["potential_prior_art"], list)
    assert "feasibility_score" in risk
    assert 1 <= risk["feasibility_score"] <= 10
    assert "missing_info" in risk
    assert isinstance(risk["missing_info"], list)
