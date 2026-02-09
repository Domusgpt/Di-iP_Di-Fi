pragma circom 2.0.0;

include "circomlib/circuits/poseidon.circom";

// ProvenanceProof: Proves that the prover knows the preimage (content)
// that hashes to a specific public hash, without revealing the content.
// This allows verifying novelty or prior art existence privately.

template ProvenanceProof() {
    // Private inputs: The content of the invention document
    signal input content[4]; // 4 field elements (approx 1KB of text/data)

    // Public inputs: The published hash of the invention
    signal input publicHash;

    // Output: 1 if valid, 0 if invalid (implicit constraint)

    // Using Poseidon for ZK-friendly hashing
    component hasher = Poseidon(4);
    hasher.inputs[0] <== content[0];
    hasher.inputs[1] <== content[1];
    hasher.inputs[2] <== content[2];
    hasher.inputs[3] <== content[3];

    // Constraint: The calculated hash must match the public input
    publicHash === hasher.out;
}

component main {public [publicHash]} = ProvenanceProof();
