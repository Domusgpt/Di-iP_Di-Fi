import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../providers/auth_provider.dart';

/// Streams comments for an invention.
final commentsProvider = StreamProvider.family<List<Map<String, dynamic>>, String>(
  (ref, inventionId) {
    return FirebaseFirestore.instance
        .collection('inventions')
        .doc(inventionId)
        .collection('comments')
        .orderBy('created_at', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  },
);

class CommentSection extends ConsumerStatefulWidget {
  final String inventionId;

  const CommentSection({super.key, required this.inventionId});

  @override
  ConsumerState<CommentSection> createState() => _CommentSectionState();
}

class _CommentSectionState extends ConsumerState<CommentSection> {
  final _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _isSubmitting = true);

    try {
      await FirebaseFirestore.instance
          .collection('inventions')
          .doc(widget.inventionId)
          .collection('comments')
          .add({
        'user_id': user.uid,
        'display_name': user.displayName ?? user.email?.split('@')[0] ?? 'Anonymous',
        'avatar_url': user.photoURL,
        'text': text,
        'created_at': FieldValue.serverTimestamp(),
        'like_count': 0,
      });
      _commentController.clear();
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(commentsProvider(widget.inventionId));
    final user = ref.watch(currentUserProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Comments',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        // Comment input
        if (user != null)
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundImage: user.photoURL != null
                    ? NetworkImage(user.photoURL!)
                    : null,
                child: user.photoURL == null
                    ? const Icon(Icons.person, size: 18)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _commentController,
                  decoration: InputDecoration(
                    hintText: 'Add a comment...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    suffixIcon: _isSubmitting
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.send),
                            onPressed: _submitComment,
                          ),
                  ),
                  maxLines: 3,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _submitComment(),
                ),
              ),
            ],
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('Sign in to comment'),
          ),

        const SizedBox(height: 16),

        // Comments list
        commentsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Text('Error loading comments: $err'),
          data: (comments) {
            if (comments.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No comments yet. Be the first!',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: comments.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final comment = comments[index];
                return _CommentTile(comment: comment);
              },
            );
          },
        ),
      ],
    );
  }
}

class _CommentTile extends StatelessWidget {
  final Map<String, dynamic> comment;

  const _CommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final createdAt = comment['created_at'] as Timestamp?;
    final timeAgo = createdAt != null
        ? timeago.format(createdAt.toDate())
        : 'just now';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundImage: comment['avatar_url'] != null
                ? NetworkImage(comment['avatar_url'])
                : null,
            child: comment['avatar_url'] == null
                ? const Icon(Icons.person, size: 16)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment['display_name'] ?? 'Anonymous',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeAgo,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(comment['text'] ?? ''),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
