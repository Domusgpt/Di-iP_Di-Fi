"""Tests for the Patent Search Service."""

import pytest
from src.services.patent_search import PatentSearchService


@pytest.fixture
def patent_svc():
    return PatentSearchService()


@pytest.mark.asyncio
async def test_search_returns_list(patent_svc):
    """Search should return a list of prior art results."""
    results = await patent_svc.search_prior_art(
        "Consumer Electronics",
        "Automatic gutter cleaning drone",
    )

    assert isinstance(results, list)
    assert len(results) > 0


@pytest.mark.asyncio
async def test_search_result_structure(patent_svc):
    """Each result should have required fields."""
    results = await patent_svc.search_prior_art(
        "Robotics",
        "Autonomous lawn mower with GPS",
    )

    for result in results:
        assert "source" in result
        assert "patent_id" in result
        assert "similarity_score" in result
        assert "notes" in result
        assert 0 <= result["similarity_score"] <= 1


@pytest.mark.asyncio
async def test_empty_query_returns_empty(patent_svc):
    """Empty query should return empty results."""
    results = await patent_svc.search_prior_art("", "")
    assert results == []


def test_mock_results_format(patent_svc):
    """Mock results should match the expected schema."""
    results = patent_svc._mock_results("test drone query")

    assert len(results) > 0
    result = results[0]
    assert "source" in result
    assert "patent_id" in result
    assert isinstance(result["similarity_score"], float)
