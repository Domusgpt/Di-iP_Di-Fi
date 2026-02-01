import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../providers/feed_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/like_button.dart';
import '../../widgets/comment_section.dart';

class InventionDetailScreen extends ConsumerWidget {
  final String inventionId;

  const InventionDetailScreen({super.key, required this.inventionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventionAsync = ref.watch(inventionDetailProvider(inventionId));
    final wallet = ref.watch(walletProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: inventionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (invention) {
          if (invention == null) {
            return const Center(child: Text('Invention not found'));
          }

          final social = invention.socialMetadata;
          final brief = invention.technicalBrief;
          final funding = invention.funding;

          return CustomScrollView(
            slivers: [
              // Hero image
              SliverAppBar(
                expandedHeight: 250,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    social.displayTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(blurRadius: 8)],
                    ),
                  ),
                  background: social.mediaAssets?.heroImageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: social.mediaAssets!.heroImageUrl!,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: theme.colorScheme.primaryContainer,
                          child: const Icon(Icons.lightbulb, size: 80),
                        ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tags + Like button row
                      Row(
                        children: [
                          if (social.viralityTags != null)
                            Expanded(
                              child: Wrap(
                                spacing: 8,
                                children: social.viralityTags!
                                    .map((t) => Chip(label: Text(t)))
                                    .toList(),
                              ),
                            ),
                          LikeButton(inventionId: inventionId),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Short pitch
                      Text(
                        social.shortPitch,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 24),

                      // Funding section
                      if (funding != null) ...[
                        _SectionTitle('Funding Progress'),
                        const SizedBox(height: 8),
                        _FundingDetail(funding: funding),
                        const SizedBox(height: 24),
                      ],

                      // Technical brief
                      if (brief != null) ...[
                        if (brief.backgroundProblem != null) ...[
                          _SectionTitle('The Problem'),
                          const SizedBox(height: 8),
                          Text(brief.backgroundProblem!),
                          const SizedBox(height: 16),
                        ],
                        if (brief.solutionSummary != null) ...[
                          _SectionTitle('The Solution'),
                          const SizedBox(height: 8),
                          Text(brief.solutionSummary!),
                          const SizedBox(height: 16),
                        ],
                        if (brief.coreMechanics != null &&
                            brief.coreMechanics!.isNotEmpty) ...[
                          _SectionTitle('How It Works'),
                          const SizedBox(height: 8),
                          ...brief.coreMechanics!.map(
                            (m) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    child: Text('${m.step}',
                                        style: const TextStyle(fontSize: 12)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(child: Text(m.description)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (brief.noveltyClaims != null &&
                            brief.noveltyClaims!.isNotEmpty) ...[
                          _SectionTitle('Novelty Claims'),
                          const SizedBox(height: 8),
                          ...brief.noveltyClaims!.map(
                            (c) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.verified, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(c)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],

                      const SizedBox(height: 32),

                      // Comments section
                      CommentSection(inventionId: inventionId),

                      const SizedBox(height: 80), // Space for FAB
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: inventionAsync.valueOrNull != null
          ? FloatingActionButton.extended(
              onPressed: () {
                if (!wallet.isConnected) {
                  ref.read(walletProvider.notifier).connect();
                } else {
                  context.push('/invest/$inventionId');
                }
              },
              icon: Icon(wallet.isConnected
                  ? Icons.rocket_launch
                  : Icons.account_balance_wallet),
              label: Text(
                wallet.isConnected ? 'Back This Project' : 'Connect Wallet',
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }
}

class _FundingDetail extends StatelessWidget {
  final dynamic funding;
  const _FundingDetail({required this.funding});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress =
        ((funding.raisedUsdc ?? 0) / (funding.goalUsdc ?? 1)).clamp(0.0, 1.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 12,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '\$${(funding.raisedUsdc ?? 0).toStringAsFixed(0)}',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    Text('raised of \$${(funding.goalUsdc ?? 0).toStringAsFixed(0)}'),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${funding.backerCount ?? 0}',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text('backers'),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
