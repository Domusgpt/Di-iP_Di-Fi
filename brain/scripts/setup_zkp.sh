#!/bin/bash
set -e

# Setup ZKP directories
CIRCUIT_DIR="src/zkp"
BUILD_DIR="src/zkp/build"
mkdir -p $BUILD_DIR

echo "🔧 Compiling Circom Circuit..."
circom $CIRCUIT_DIR/novelty.circom --r1cs --wasm --sym --output $BUILD_DIR

echo "🔧 Generating Trusted Setup (Powers of Tau)..."
# In a real ceremony, this takes much longer. We use a pre-prepared or small one for dev.
# For this script, we'll generate a quick one.
snarkjs powersoftau new bn128 12 $BUILD_DIR/pot12_0000.ptau -v
snarkjs powersoftau contribute $BUILD_DIR/pot12_0000.ptau $BUILD_DIR/pot12_final.ptau --name="First contribution" -v -e="random text"

echo "🔧 Generating Verification Key..."
snarkjs groth16 setup $BUILD_DIR/novelty.r1cs $BUILD_DIR/pot12_final.ptau $BUILD_DIR/novelty_0000.zkey
snarkjs zkey contribute $BUILD_DIR/novelty_0000.zkey $BUILD_DIR/novelty_final.zkey --name="Second contribution" -v -e="another random text"
snarkjs zkey export verificationkey $BUILD_DIR/novelty_final.zkey $BUILD_DIR/verification_key.json

echo "✅ ZKP Setup Complete"
