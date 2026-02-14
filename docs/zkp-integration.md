# Zero-Knowledge Proof Integration (DeSci)

IdeaCapital uses Zero-Knowledge Proofs (ZKPs) to solve the **Inventor's Dilemma**:
> "How can I prove I invented this *before* you, without showing you the invention and risking theft?"

## Architecture

We use **Circom** for circuit definition and **SnarkJS** (or a Python wrapper) for proof generation.

### 1. The Circuit (`brain/src/zkp/novelty.circom`)

The circuit `ProvenanceProof` takes two inputs:
1.  **Private Input (`content`):** The raw text/data of the invention (split into field elements).
2.  **Public Input (`publicHash`):** The published hash of the invention (e.g., on IPFS or Blockchain).

The circuit calculates the hash of the `content` (using Poseidon) and asserts that it equals `publicHash`.

```circom
template ProvenanceProof() {
    signal input content[4];
    signal input publicHash;
    // ... hash logic ...
    publicHash === hasher.out;
}
```

### 2. The Flow

1.  **Inventor** drafts an idea in the app.
2.  **The Brain** (local or server-side) computes the `contentHash`.
3.  **The Brain** generates a ZK Proof: `proof = Prove(content, contentHash)`.
4.  **The Brain** discards the `content` (if privacy mode is on) but stores `proof` and `contentHash` in Firestore.
5.  **Investors** see a "Verifiable Novelty" badge. They can verify `Verify(proof, contentHash)` to know that *some* valid content exists behind that hash, without seeing it yet.

### 3. API Reference

#### `POST /api/inventions/:id/prove_novelty`

Generates and attaches a ZKP to an existing invention draft.

**Request:**
```json
{
  "invention_id": "uuid-1234",
  "content": "My secret invention text..."
}
```

**Response:**
```json
{
  "status": "PROOF_GENERATED",
  "proof": { ...snarkjs_proof... }
}
```

## Future Work

- **Timestamping:** Combine ZKP with a blockchain timestamp to prove *existence at time T*.
- **Client-Side Proving:** Move proof generation to the Flutter app (using a WASM build of the circuit) so the raw content never leaves the user's device.
