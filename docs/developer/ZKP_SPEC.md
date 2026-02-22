# Zero-Knowledge Proof Specification

IdeaCapital utilizes Zero-Knowledge Proofs (ZKPs) to verify that an invention is novel and matches a public commitment (hash) without revealing the underlying content on-chain.

## 1. The Circuit (`novelty.circom`)

The circuit is written in **Circom 2.0**. It proves knowledge of a preimage that hashes to a public output.

### Inputs

*   **Private Input:** `content[4]` - Array of 4 field elements representing the invention text (chunked).
*   **Public Input:** `publicHash` - The Poseidon hash of the content.

### Constraints

The circuit enforces the following constraint:

$$
\text{Poseidon}(content[0], content[1], content[2], content[3]) == publicHash
$$

### Implementation
```circom
template ProvenanceProof() {
    signal input content[4];
    signal input publicHash;

    component hasher = Poseidon(4);
    hasher.inputs[0] <== content[0];
    hasher.inputs[1] <== content[1];
    hasher.inputs[2] <== content[2];
    hasher.inputs[3] <== content[3];

    publicHash === hasher.out;
}
```

## 2. Proving Scheme

We use **Groth16** for its small proof size and fast verification time on Ethereum.

### Trusted Setup
1.  **Phase 1:** Powers of Tau (generic ceremony).
2.  **Phase 2:** Circuit-specific setup (`novelty.zkey`).

### Proof Generation
The Python Brain service (`zkp_service.py`) executes `snarkjs`:
```bash
snarkjs groth16 prove novelty_0001.zkey witness.wtns proof.json public.json
```

## 3. Verification

The generated `proof.json` and `public.json` are submitted to the `Verifier.sol` smart contract on-chain. If `verifyProof(a, b, c, input)` returns `true`, the invention is verified as authentic to the commitment without exposing the IP.
