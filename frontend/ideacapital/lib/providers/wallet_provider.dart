import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Wallet connection state.
class WalletState {
  final bool isConnected;
  final String? address;
  final int? chainId;
  final String? error;

  const WalletState({
    this.isConnected = false,
    this.address,
    this.chainId,
    this.error,
  });

  WalletState copyWith({
    bool? isConnected,
    String? address,
    int? chainId,
    String? error,
  }) {
    return WalletState(
      isConnected: isConnected ?? this.isConnected,
      address: address ?? this.address,
      chainId: chainId ?? this.chainId,
      error: error ?? this.error,
    );
  }
}

/// Manages wallet connection via WalletConnect / Reown.
class WalletNotifier extends StateNotifier<WalletState> {
  WalletNotifier() : super(const WalletState());

  Future<void> connect() async {
    try {
      // TODO: Initialize WalletConnect session via Reown SDK
      // 1. Create pairing URI
      // 2. Present QR code or deep link
      // 3. Wait for session approval
      // 4. Extract account address and chain ID
      state = state.copyWith(
        isConnected: true,
        // address will come from WalletConnect session
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> disconnect() async {
    // TODO: Disconnect WalletConnect session
    state = const WalletState();
  }

  /// Sign and send a transaction (e.g., invest in a project).
  Future<String?> sendTransaction({
    required String to,
    required BigInt value,
    required String data,
  }) async {
    if (!state.isConnected) {
      throw Exception('Wallet not connected');
    }
    // TODO: Use WalletConnect to request transaction signing
    // Returns transaction hash
    return null;
  }
}

final walletProvider = StateNotifierProvider<WalletNotifier, WalletState>(
  (ref) => WalletNotifier(),
);
