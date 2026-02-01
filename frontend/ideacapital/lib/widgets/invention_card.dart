import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/invention.dart';

class InventionCard extends StatelessWidget {
  final Invention invention;
  final VoidCallback? onTap;

  const InventionCard({
    super.key,
    required this.invention,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final social = invention.socialMetadata;
    final funding = invention.funding;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero image
            if (social.mediaAssets?.heroImageUrl != null)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: CachedNetworkImage(
                  imageUrl: social.mediaAssets!.heroImageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.image_not_supported, size: 48),
                  ),
                ),
              )
            else
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  color: theme.colorScheme.primaryContainer,
                  child: Center(
                    child: Icon(
                      Icons.lightbulb,
                      size: 64,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tags
                  if (social.viralityTags != null &&
                      social.viralityTags!.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: social.viralityTags!
                          .take(3)
                          .map(
                            (tag) => Chip(
                              label: Text(tag, style: const TextStyle(fontSize: 11)),
                              padding: EdgeInsets.zero,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                          )
                          .toList(),
                    ),
                  const SizedBox(height: 8),

                  // Title
                  Text(
                    social.displayTitle,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Pitch
                  Text(
                    social.shortPitch,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Funding progress
                  if (funding != null &&
                      funding.goalUsdc != null &&
                      funding.raisedUsdc != null) ...[
                    const SizedBox(height: 12),
                    _FundingProgress(funding: funding),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FundingProgress extends StatelessWidget {
  final Funding funding;

  const _FundingProgress({required this.funding});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = (funding.raisedUsdc ?? 0) / (funding.goalUsdc ?? 1);
    final clampedProgress = progress.clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: clampedProgress,
            minHeight: 8,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '\$${(funding.raisedUsdc ?? 0).toStringAsFixed(0)} raised',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            Text(
              '${(clampedProgress * 100).toStringAsFixed(0)}% of \$${(funding.goalUsdc ?? 0).toStringAsFixed(0)}',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        if (funding.backerCount != null) ...[
          const SizedBox(height: 4),
          Text(
            '${funding.backerCount} backers',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
