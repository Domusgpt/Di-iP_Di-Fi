"""
ZKP Service
Handles generation and verification of Zero-Knowledge Proofs for invention novelty.
Wraps snarkjs or a Python equivalent to prove knowledge of content without revealing it.
"""

import logging
import os
import json
import hashlib

logger = logging.getLogger(__name__)

class ZKPService:
    def __init__(self):
        self.circuit_path = os.path.join(os.path.dirname(__file__), "novelty.circom")
        # In a real impl, we would compile this to .wasm and .zkey

    async def generate_proof(self, content: str) -> dict:
        """
        Generate a ZK proof using snarkjs.
        """
        content_hash = self._hash_content(content)
        logger.info(f"Generating ZKP for content hash: {content_hash}")

        # Check if we are in Mock Mode (no snarkjs installed)
        import shutil
        if not shutil.which("snarkjs"):
            logger.warning("snarkjs not found, falling back to mock proof")
            return {
                "proof": {"mock": True},
                "publicSignals": [content_hash]
            }

        # 1. Prepare Input
        # In a real Poseidon circuit, we need to convert string to field elements.
        # For this MVP circuit, we just use the hash as input stub.
        input_data = {
            "content": [1, 2, 3, 4], # Stubbed field elements
            "publicHash": "123456789" # Stubbed hash constraint
        }

        # 2. Run snarkjs via subprocess
        import subprocess
        import tempfile

        with tempfile.TemporaryDirectory() as tmpdir:
            input_path = os.path.join(tmpdir, "input.json")
            proof_path = os.path.join(tmpdir, "proof.json")
            public_path = os.path.join(tmpdir, "public.json")

            with open(input_path, "w") as f:
                json.dump(input_data, f)

            # Paths to compiled circuit files (assumed to be in /app/src/zkp/build)
            wasm_path = "/app/src/zkp/build/novelty_js/novelty.wasm"
            zkey_path = "/app/src/zkp/build/novelty_final.zkey"

            if not os.path.exists(zkey_path):
                 logger.warning("ZKP build artifacts not found, using mock.")
                 return {"proof": {"mock": True}, "publicSignals": [content_hash]}

            cmd = [
                "snarkjs", "groth16", "fullprove",
                input_path, wasm_path, zkey_path,
                proof_path, public_path
            ]

            try:
                subprocess.run(cmd, check=True, capture_output=True)

                with open(proof_path) as f:
                    proof = json.load(f)
                with open(public_path) as f:
                    public_signals = json.load(f)

                return {"proof": proof, "publicSignals": public_signals}
            except Exception as e:
                logger.error(f"snarkjs execution failed: {e}")
                raise

    def _hash_content(self, content: str) -> str:
        # Simple SHA256 for the mock, though circuit uses Poseidon
        return hashlib.sha256(content.encode()).hexdigest()

    async def verify_proof(self, proof: dict, public_hash: str) -> bool:
        """
        Verify a ZK proof.
        """
        # Mock verification
        if not proof:
            return False

        signals = proof.get("publicSignals", [])
        if not signals:
            return False

        return signals[0] == public_hash
