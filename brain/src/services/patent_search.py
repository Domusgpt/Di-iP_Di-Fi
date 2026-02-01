"""
Patent Search Service - Searches for prior art via SerpAPI Google Patents.

Used during the "Sanity Check" phase to flag potential conflicts
before the inventor publishes their idea.

Integration: Uses SerpAPI's Google Patents engine when SERPAPI_KEY is set.
Falls back to mock results for local development.
"""

import logging
import os
from typing import Optional

import httpx

logger = logging.getLogger(__name__)


class PatentSearchService:
    """Searches Google Patents for prior art related to an invention."""

    def __init__(self):
        self.serpapi_key = os.getenv("SERPAPI_KEY", "")
        self.serpapi_url = "https://serpapi.com/search"

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
        Query Google Patents via SerpAPI.

        SerpAPI provides structured access to Google Patents results.
        Requires a SERPAPI_KEY environment variable.
        """
        if not self.serpapi_key:
            logger.info("No SERPAPI_KEY configured, using mock results")
            return self._mock_results(query)

        # Truncate query to first 200 chars for API efficiency
        search_query = query[:200].strip()

        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.get(
                self.serpapi_url,
                params={
                    "engine": "google_patents",
                    "q": search_query,
                    "api_key": self.serpapi_key,
                    "num": 10,
                },
            )
            response.raise_for_status()
            data = response.json()

        organic_results = data.get("organic_results", [])

        if not organic_results:
            logger.info(f"No patent results found for query: {search_query[:50]}")
            return []

        # Process and score results
        prior_art = []
        query_words = set(search_query.lower().split())

        for result in organic_results[:5]:
            title = result.get("title", "")
            snippet = result.get("snippet", "")
            patent_id = result.get("patent_id", result.get("publication_number", ""))
            link = result.get("link", "")

            # Calculate a simple keyword overlap similarity score
            result_words = set(f"{title} {snippet}".lower().split())
            common = query_words & result_words
            similarity = len(common) / max(len(query_words), 1)

            prior_art.append({
                "source": "Google Patents (SerpAPI)",
                "patent_id": patent_id,
                "title": title,
                "snippet": snippet[:300],
                "link": link,
                "similarity_score": round(min(similarity, 0.99), 2),
                "notes": f"Keyword overlap: {len(common)} terms",
            })

        # Sort by similarity (highest first)
        prior_art.sort(key=lambda x: x["similarity_score"], reverse=True)

        logger.info(f"Found {len(prior_art)} prior art results")
        return prior_art

    def _mock_results(self, query: str) -> list[dict]:
        """Mock results for development."""
        return [
            {
                "source": "Google Patents (Mock)",
                "patent_id": "US-MOCK-001",
                "title": "Related Technology Patent",
                "snippet": f"Related to: {query[:100]}",
                "link": "",
                "similarity_score": 0.45,
                "notes": "Mock result for local development. Set SERPAPI_KEY for real patent search.",
            }
        ]
