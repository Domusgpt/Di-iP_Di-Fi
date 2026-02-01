import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/auth_provider.dart';

/// Checks if the current user has liked an invention.
final isLikedProvider = StreamProvider.family<bool, String>(
  (ref, inventionId) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return Stream.value(false);

    return FirebaseFirestore.instance
        .collection('inventions')
        .doc(inventionId)
        .collection('likes')
        .doc(user.uid)
        .snapshots()
        .map((doc) => doc.exists);
  },
);

/// Streams the like count for an invention.
final likeCountProvider = StreamProvider.family<int, String>(
  (ref, inventionId) {
    return FirebaseFirestore.instance
        .collection('inventions')
        .doc(inventionId)
        .snapshots()
        .map((doc) => (doc.data()?['like_count'] as int?) ?? 0);
  },
);

class LikeButton extends ConsumerWidget {
  final String inventionId;
  final bool showCount;

  const LikeButton({
    super.key,
    required this.inventionId,
    this.showCount = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLikedAsync = ref.watch(isLikedProvider(inventionId));
    final likeCountAsync = ref.watch(likeCountProvider(inventionId));
    final user = ref.watch(currentUserProvider);

    final isLiked = isLikedAsync.valueOrNull ?? false;
    final count = likeCountAsync.valueOrNull ?? 0;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: user != null ? () => _toggleLike(ref, user.uid) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isLiked ? Icons.favorite : Icons.favorite_border,
              color: isLiked ? Colors.red : null,
              size: 22,
            ),
            if (showCount && count > 0) ...[
              const SizedBox(width: 4),
              Text(
                _formatCount(count),
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _toggleLike(WidgetRef ref, String userId) async {
    final firestore = FirebaseFirestore.instance;
    final likeRef = firestore
        .collection('inventions')
        .doc(inventionId)
        .collection('likes')
        .doc(userId);

    final likeDoc = await likeRef.get();

    if (likeDoc.exists) {
      await likeRef.delete();
      await firestore.collection('inventions').doc(inventionId).update({
        'like_count': FieldValue.increment(-1),
      });
    } else {
      await likeRef.set({
        'user_id': userId,
        'created_at': FieldValue.serverTimestamp(),
      });
      await firestore.collection('inventions').doc(inventionId).update({
        'like_count': FieldValue.increment(1),
      });
    }
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}
