"""
Pub/Sub Listener - Subscribes to `ai.processing` topic.

When the TypeScript backend dispatches an AI processing request,
this listener picks it up and routes it to the appropriate agent.
"""

import asyncio
import json
import logging
import os
from typing import Optional

logger = logging.getLogger(__name__)


def start_pubsub_listener() -> Optional[asyncio.Task]:
    """
    Start a background task that listens for Pub/Sub messages.

    Integration Point:
    - Subscribes to: `ai.processing` (dispatched by TypeScript backend)
    - Publishes to: `ai.processing.complete` (consumed by TypeScript backend)
    """
    project_id = os.getenv("GOOGLE_CLOUD_PROJECT", "")

    if not project_id:
        logger.warning("GOOGLE_CLOUD_PROJECT not set, Pub/Sub listener disabled")
        return None

    return asyncio.create_task(_listen_loop(project_id))


async def _listen_loop(project_id: str):
    """Main listener loop."""
    try:
        from google.cloud import pubsub_v1

        subscriber = pubsub_v1.SubscriberClient()
        subscription_path = subscriber.subscription_path(
            project_id, "ai-processing-brain-sub"
        )

        def callback(message):
            """Process incoming Pub/Sub message."""
            try:
                data = json.loads(message.data.decode("utf-8"))
                action = data.get("action", "")
                invention_id = data.get("invention_id", "")

                logger.info(f"Received message: action={action}, invention={invention_id}")

                if action == "INITIAL_ANALYSIS":
                    # TODO: Call invention_agent.analyze_idea()
                    # TODO: Publish result to ai.processing.complete
                    pass
                elif action == "CONTINUE_CHAT":
                    # TODO: Call invention_agent.continue_chat()
                    # TODO: Publish result to ai.processing.complete
                    pass
                else:
                    logger.warning(f"Unknown action: {action}")

                message.ack()

            except Exception as e:
                logger.error(f"Error processing message: {e}")
                message.nack()

        streaming_pull = subscriber.subscribe(subscription_path, callback=callback)
        logger.info(f"Listening on {subscription_path}")

        # Block the task
        await asyncio.get_event_loop().run_in_executor(
            None, streaming_pull.result
        )

    except ImportError:
        logger.warning("google-cloud-pubsub not available, running in local mode")
    except Exception as e:
        logger.error(f"Pub/Sub listener error: {e}")


async def publish_completion(
    project_id: str,
    invention_id: str,
    action: str,
    structured_data: dict,
):
    """Publish AI processing completion to Pub/Sub."""
    try:
        from google.cloud import pubsub_v1

        publisher = pubsub_v1.PublisherClient()
        topic_path = publisher.topic_path(project_id, "ai.processing.complete")

        message = json.dumps({
            "invention_id": invention_id,
            "action": action,
            "structured_data": structured_data,
        }).encode("utf-8")

        future = publisher.publish(topic_path, message)
        result = future.result()
        logger.info(f"Published completion for {invention_id}: {result}")

    except Exception as e:
        logger.error(f"Failed to publish completion: {e}")
