import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/wallet_provider.dart';

/// Full-screen investment flow for backing a project with USDC.
class InvestScreen extends ConsumerStatefulWidget {
  final String inventionId;

  const InvestScreen({super.key, required this.inventionId});

  @override
  ConsumerState<InvestScreen> createState() => _InvestScreenState();
}

class _InvestScreenState extends ConsumerState<InvestScreen> {
  double _amount = 50.0;
  bool _isSubmitting = false;
  String? _txHash;

  final List<double> _presetAmounts = [25, 50, 100, 250, 500, 1000];

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Back This Project')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Choose Investment Amount',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You will receive royalty tokens proportional to your investment.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),

            // Amount selector
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _presetAmounts.map((amount) {
                final isSelected = _amount == amount;
                return ChoiceChip(
                  selected: isSelected,
                  label: Text('\$${amount.toStringAsFixed(0)} USDC'),
                  onSelected: (_) => setState(() => _amount = amount),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Summary card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SummaryRow('Investment', '\$${_amount.toStringAsFixed(0)} USDC'),
                    const _SummaryRow('Network', 'Polygon'),
                    const _SummaryRow('Gas (est.)', '~\$0.01'),
                    const Divider(),
                    _SummaryRow(
                      'Wallet',
                      wallet.isConnected
                          ? '${wallet.address?.substring(0, 6)}...${wallet.address?.substring((wallet.address?.length ?? 4) - 4)}'
                          : 'Not connected',
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(),

            if (_txHash != null) ...[
              Card(
                color: theme.colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Icon(Icons.check_circle, size: 48),
                      const SizedBox(height: 8),
                      const Text('Transaction Submitted!'),
                      const SizedBox(height: 4),
                      Text(
                        'TX: ${_txHash!.substring(0, 10)}...',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            FilledButton.icon(
              onPressed: _isSubmitting ? null : _invest,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.rocket_launch),
              label: Text(
                _isSubmitting
                    ? 'Processing...'
                    : 'Invest \$${_amount.toStringAsFixed(0)} USDC',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _invest() async {
    final wallet = ref.read(walletProvider.notifier);
    setState(() => _isSubmitting = true);

    try {
      // TODO: Build the Crowdsale contract call data
      // TODO: Send via wallet.sendTransaction()
      // The optimistic UI update happens via Pub/Sub -> Firestore
      await Future.delayed(const Duration(seconds: 2)); // Placeholder
      setState(() => _txHash = '0xabc123...placeholder');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Transaction failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          )),
        ],
      ),
    );
  }
}
