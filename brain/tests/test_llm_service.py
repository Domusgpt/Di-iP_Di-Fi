"""Tests for the LLM Service (mock mode without Vertex AI credentials)."""

import pytest
from src.services.llm_service import LLMService


@pytest.fixture
def llm():
    return LLMService()


def test_mock_structured_output(llm):
    """Test that mock output has all required fields."""
    result = llm._mock_structured_output("A drone for cleaning gutters")

    required_fields = [
        "display_title", "short_pitch", "virality_tags",
        "technical_field", "background_problem", "solution_summary",
        "core_mechanics", "novelty_claims", "hardware_requirements",
        "software_logic", "feasibility_score", "missing_info", "agent_reply",
    ]

    for field in required_fields:
        assert field in result, f"Missing field: {field}"


def test_mock_output_types(llm):
    """Test that mock output has correct types."""
    result = llm._mock_structured_output("Automatic plant watering system")

    assert isinstance(result["display_title"], str)
    assert isinstance(result["short_pitch"], str)
    assert isinstance(result["virality_tags"], list)
    assert isinstance(result["core_mechanics"], list)
    assert isinstance(result["novelty_claims"], list)
    assert isinstance(result["hardware_requirements"], list)
    assert isinstance(result["feasibility_score"], int)
    assert isinstance(result["missing_info"], list)
    assert isinstance(result["agent_reply"], str)


def test_mock_output_has_content(llm):
    """Test that mock output contains meaningful content."""
    result = llm._mock_structured_output("Smart mirror with health tracking")

    assert len(result["display_title"]) > 0
    assert len(result["short_pitch"]) > 0
    assert len(result["agent_reply"]) > 0
    assert len(result["missing_info"]) > 0  # Should always ask follow-up questions
    assert 1 <= result["feasibility_score"] <= 10


@pytest.mark.asyncio
async def test_structure_invention_falls_back_to_mock(llm):
    """Without Vertex AI creds, should fall back to mock output."""
    result = await llm.structure_invention("A self-driving shopping cart")

    assert "display_title" in result
    assert "agent_reply" in result
    assert len(result["display_title"]) > 0


@pytest.mark.asyncio
async def test_continue_conversation_mock(llm):
    """Test conversation continuation in mock mode."""
    result = await llm.continue_conversation(
        invention_id="test-123",
        user_message="It uses LiDAR sensors to navigate aisles",
    )

    assert "agent_reply" in result
    assert "completeness_percentage" in result
    assert isinstance(result["completeness_percentage"], int)
