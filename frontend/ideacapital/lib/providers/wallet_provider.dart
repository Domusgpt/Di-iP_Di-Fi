import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:walletconnect_flutter_v2/walletconnect_flutter_v2.dart';
import 'package:web3dart/web3dart.dart' as web3;
import 'package:shared_preferences/shared_preferences.dart';

/// Wallet connection state.
class WalletState {
  final bool isConnected;
  final bool isConnecting;
  final String? address;
  final int? chainId;
  final String? error;
  final String? pairingUri;

  const WalletState({
    this.isConnected = false,
    this.isConnecting = false,
    this.address,
    this.chainId,
    this.error,
    this.pairingUri,
  });

  WalletState copyWith({
    bool? isConnected,
    bool? isConnecting,
    String? address,
    int? chainId,
    String? error,
    String? pairingUri,
  }) {
    return WalletState(
      isConnected: isConnected ?? this.isConnected,
      isConnecting: isConnecting ?? this.isConnecting,
      address: address ?? this.address,
      chainId: chainId ?? this.chainId,
      error: error,
      pairingUri: pairingUri,
    );
  }
}

/// Manages wallet connection via WalletConnect v2.
class WalletNotifier extends StateNotifier<WalletState> {
  WalletNotifier() : super(const WalletState());

  Web3App? _web3App;
  SessionData? _session;

  // IdeaCapital WalletConnect project ID (register at cloud.walletconnect.com)
  static const _projectId = String.fromEnvironment(
    'WALLETCONNECT_PROJECT_ID',
    defaultValue: 'ideacapital-dev',
  );

  // Target chain: Polygon Mainnet (USDC investments)
  static const _polygonChainId = 'eip155:137';
  // Testnet fallback: Polygon Amoy
  static const _amoyChainId = 'eip155:80002';

  /// Initialize the WalletConnect Web3App instance.
  Future<void> _ensureInitialized() async {
    if (_web3App != null) return;

    _web3App = await Web3App.createInstance(
      projectId: _projectId,
      metadata: const PairingMetadata(
        name: 'IdeaCapital',
        description: 'Decentralized Invention Capital Platform',
        url: 'https://ideacapital.app',
        icons: ['https://ideacapital.app/icon.png'],
      ),
    );

    // Listen for session deletions (wallet-side disconnect)
    _web3App!.onSessionDelete.subscribe((event) {
      _session = null;
      state = const WalletState();
    });
  }

  /// Connect to a wallet via WalletConnect v2.
  /// Returns a pairing URI for QR code display.
  Future<void> connect() async {
    if (state.isConnecting) return;

    // MOCK MODE: If project ID is not set or we are in mock mode
    if (_projectId == 'ideacapital-dev') {
      await Future.delayed(const Duration(seconds: 1));
      state = const WalletState(
        isConnected: true,
        isConnecting: false,
        address: '0x71C7656EC7ab88b098defB751B7401B5f6d8976F', // Mock Test User
        chainId: 137,
      );
      return;
    }

    state = state.copyWith(isConnecting: true, error: null);

    try {
      await _ensureInitialized();

      // Request a session with EIP155 namespace (Polygon)
      final connectResponse = await _web3App!.connect(
        requiredNamespaces: {
          'eip155': const RequiredNamespace(
            chains: [_polygonChainId, _amoyChainId],
            methods: ['eth_sendTransaction', 'personal_sign', 'eth_signTypedData_v4'],
            events: ['chainChanged', 'accountsChanged'],
          ),
        },
      );

      // Expose pairing URI for QR code display
      final uri = connectResponse.uri;
      if (uri != null) {
        state = state.copyWith(pairingUri: uri.toString());
      }

      // Wait for user to approve in their wallet
      _session = await connectResponse.session.future;

      // Extract account address and chain
      final accounts = _session!.namespaces['eip155']?.accounts ?? [];
      if (accounts.isEmpty) {
        throw Exception('No accounts returned from wallet');
      }

      // Account format: "eip155:137:0xABC..."
      final parts = accounts.first.split(':');
      final chainId = int.tryParse(parts.length > 1 ? parts[1] : '137') ?? 137;
      final address = parts.length > 2 ? parts[2] : accounts.first;

      // Persist session for reconnection
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('wallet_address', address.toLowerCase());
      await prefs.setInt('wallet_chain_id', chainId);

      state = WalletState(
        isConnected: true,
        isConnecting: false,
        address: address.toLowerCase(),
        chainId: chainId,
      );
    } catch (e) {
      state = WalletState(error: 'Connection failed: $e');
      debugPrint('WalletConnect error: $e');
    }
  }

  /// Disconnect the current wallet session.
  Future<void> disconnect() async {
    if (_session != null && _web3App != null) {
      try {
        await _web3App!.disconnectSession(
          topic: _session!.topic,
          reason: const WalletConnectError(
            code: 6000,
            message: 'User disconnected',
          ),
        );
      } catch (e) {
        debugPrint('Disconnect error: $e');
      }
    }

    _session = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('wallet_address');
    await prefs.remove('wallet_chain_id');

    state = const WalletState();
  }

  /// Restore a previous session on app startup.
  Future<void> restoreSession() async {
    try {
      await _ensureInitialized();

      final sessions = _web3App!.getActiveSessions();
      if (sessions.isNotEmpty) {
        _session = sessions.values.first;
        final accounts = _session!.namespaces['eip155']?.accounts ?? [];
        if (accounts.isNotEmpty) {
          final parts = accounts.first.split(':');
          final chainId = int.tryParse(parts.length > 1 ? parts[1] : '137') ?? 137;
          final address = parts.length > 2 ? parts[2] : accounts.first;
          state = WalletState(
            isConnected: true,
            address: address.toLowerCase(),
            chainId: chainId,
          );
          return;
        }
      }

      // Fall back to stored address (read-only mode)
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('wallet_address');
      if (stored != null) {
        state = WalletState(
          isConnected: false,
          address: stored,
          chainId: prefs.getInt('wallet_chain_id'),
        );
      }
    } catch (e) {
      debugPrint('Session restore failed: $e');
    }
  }

  /// Sign and send a transaction via WalletConnect.
  /// Returns the transaction hash on success.
  Future<String?> sendTransaction({
    required String to,
    required BigInt value,
    required String data,
  }) async {
    if (!state.isConnected) {
      throw Exception('Wallet not connected');
    }

    // MOCK MODE
    if (_session == null || _projectId == 'ideacapital-dev') {
      await Future.delayed(const Duration(seconds: 2));
      // Return a fake TX hash
      // Format: 0x... (64 chars)
      return '0x${DateTime.now().millisecondsSinceEpoch.toRadixString(16).padLeft(64, '0')}';
    }

    if (_session == null || _web3App == null) {
        throw Exception('Wallet session invalid');
    }

    final chainId = 'eip155:${state.chainId ?? 137}';

    final txHash = await _web3App!.request(
      topic: _session!.topic,
      chainId: chainId,
      request: SessionRequestParams(
        method: 'eth_sendTransaction',
        params: [
          {
            'from': state.address,
            'to': to,
            'value': '0x${value.toRadixString(16)}',
            'data': data,
          },
        ],
      ),
    );

    return txHash as String?;
  }

  /// Approve USDC spending for the Crowdsale contract.
  /// Returns the approval tx hash.
  Future<String?> approveUsdc({
    required String usdcContract,
    required String spender,
    required BigInt amount,
  }) async {
    // ERC-20 approve(address,uint256) function selector: 0x095ea7b3
    final amountHex = amount.toRadixString(16).padLeft(64, '0');
    final spenderPadded = spender.replaceFirst('0x', '').padLeft(64, '0');
    final callData = '0x095ea7b3$spenderPadded$amountHex';

    return sendTransaction(
      to: usdcContract,
      value: BigInt.zero,
      data: callData,
    );
  }
}

final walletProvider = StateNotifierProvider<WalletNotifier, WalletState>(
  (ref) => WalletNotifier(),
);
