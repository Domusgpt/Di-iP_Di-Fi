import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/feed_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/invention_card.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(feedFilterProvider);
    final feedAsync = ref.watch(inventionFeedProvider(filter));
    final user = ref.watch(currentUserProvider);
    final unreadCount = ref.watch(unreadCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'IdeaCapital',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/search'),
          ),
          IconButton(
            icon: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text('$unreadCount'),
              child: const Icon(Icons.notifications_outlined),
            ),
            onPressed: () => context.push('/notifications'),
          ),
          if (user != null)
            GestureDetector(
              onTap: () => context.push('/profile/${user.uid}'),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: CircleAvatar(
                  radius: 16,
                  backgroundImage: user.photoURL != null
                      ? NetworkImage(user.photoURL!)
                      : null,
                  child: user.photoURL == null
                      ? const Icon(Icons.person, size: 18)
                      : null,
                ),
              ),
            )
          else
            TextButton(
              onPressed: () => context.push('/login'),
              child: const Text('Sign In'),
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: FeedFilter.values.map((f) {
                final isSelected = f == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: isSelected,
                    label: Text(_filterLabel(f)),
                    onSelected: (_) {
                      ref.read(feedFilterProvider.notifier).state = f;
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          // Feed list
          Expanded(
            child: feedAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
              data: (inventions) {
                if (inventions.isEmpty) {
                  return const Center(
                    child: Text('No inventions yet. Be the first!'),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(inventionFeedProvider(filter));
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: inventions.length,
                    itemBuilder: (context, index) {
                      return InventionCard(
                        invention: inventions[index],
                        onTap: () {
                          context.push(
                            '/invention/${inventions[index].inventionId}',
                          );
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: user != null
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/create'),
              icon: const Icon(Icons.lightbulb_outline),
              label: const Text('Post Idea'),
            )
          : null,
    );
  }

  String _filterLabel(FeedFilter filter) {
    switch (filter) {
      case FeedFilter.trending:
        return 'Trending';
      case FeedFilter.nearGoal:
        return 'Near Goal';
      case FeedFilter.newest:
        return 'Newest';
      case FeedFilter.following:
        return 'Following';
    }
  }
}
