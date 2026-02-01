"""
Patent Search Service - Searches Google Patents API for prior art.

Used during the "Sanity Check" phase to flag potential conflicts
before the inventor publishes their idea.
"""

import logging
import os
from typing import Optional

import httpx

logger = logging.getLogger(__name__)


class PatentSearchService:
    """Searches Google Patents for prior art related to an invention."""

    def __init__(self):
        self.api_key = os.getenv("GOOGLE_PATENTS_API_KEY", "")
        self.base_url = "https://patents.google.com"

    async def search_prior_art(
        self, technical_field: str, solution_summary: str
    ) -> list[dict]:
        """
        Search for patents similar to the described invention.

        Returns a list of potential prior art with similarity scores.
        """
        if not technical_field and not solution_summary:
            return []

        query = f"{technical_field} {solution_summary}"

        try:
            results = await self._search_google_patents(query)
            return results
        except Exception as e:
            logger.error(f"Patent search failed: {e}")
            return self._mock_results(query)

    async def _search_google_patents(self, query: str) -> list[dict]:
        """
        Query the Google Patents API.

        Note: The actual Google Patents API requires specific access.
        This is the integration point for the real API.
        """
        if not self.api_key:
            logger.info("No Google Patents API key configured, using mock results")
            return self._mock_results(query)

        async with httpx.AsyncClient() as client:
            # TODO: Implement actual Google Patents API call
            # The API endpoint and format depends on the specific API access granted
            pass

        return []

    def _mock_results(self, query: str) -> list[dict]:
        """Mock results for development."""
        return [
            {
                "source": "Google Patents API (Mock)",
                "patent_id": "US-MOCK-001",
                "similarity_score": 0.45,
                "notes": f"Related to: {query[:100]}. Mock result for development.",
            }
        ]
