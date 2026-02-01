import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../models/invention.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/invention_card.dart';

final userProfileProvider = StreamProvider.family<UserProfile?, String>(
  (ref, userId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return UserProfile.fromJson(doc.data()!);
    });
  },
);

/// User's inventions stream.
final userInventionsProvider = StreamProvider.family<List<Invention>, String>(
  (ref, userId) {
    return FirebaseFirestore.instance
        .collection('inventions')
        .where('creator_id', isEqualTo: userId)
        .orderBy('created_at', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Invention.fromJson(doc.data())).toList());
  },
);

/// User's investments stream.
final userInvestmentsProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>(
  (ref, userId) {
    return FirebaseFirestore.instance
        .collection('investments')
        .where('user_id', isEqualTo: userId)
        .orderBy('created_at', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  },
);

/// Whether the current user follows a given user.
final isFollowingProvider = StreamProvider.family<bool, String>(
  (ref, targetUserId) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return Stream.value(false);
    return FirebaseFirestore.instance
        .collection('following')
        .doc(user.uid)
        .collection('user_following')
        .doc(targetUserId)
        .snapshots()
        .map((doc) => doc.exists);
  },
);

class ProfileScreen extends ConsumerWidget {
  final String userId;

  const ProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider(userId));
    final currentUser = ref.watch(currentUserProvider);
    final theme = Theme.of(context);
    final isOwnProfile = currentUser?.uid == userId;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('User not found'));
          }

          return DefaultTabController(
            length: 2,
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Avatar + Name
                        CircleAvatar(
                          radius: 48,
                          backgroundImage: profile.avatarUrl != null
                              ? NetworkImage(profile.avatarUrl!)
                              : null,
                          child: profile.avatarUrl == null
                              ? const Icon(Icons.person, size: 48)
                              : null,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          profile.displayName,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (profile.bio != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            profile.bio!,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge,
                          ),
                        ],
                        const SizedBox(height: 16),

                        // Follow button (if viewing another user's profile)
                        if (!isOwnProfile && currentUser != null)
                          _FollowButton(targetUserId: userId),

                        const SizedBox(height: 16),

                        // Stats row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _StatColumn(
                              label: 'Inventions',
                              value: '${profile.inventionsCount}',
                            ),
                            _StatColumn(
                              label: 'Investments',
                              value: '${profile.investmentsCount}',
                            ),
                            _StatColumn(
                              label: 'Reputation',
                              value: '${profile.reputationScore}',
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Badges
                        if (profile.badges.isNotEmpty) ...[
                          const Divider(),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: profile.badges.map((badge) {
                              return Chip(
                                avatar:
                                    const Icon(Icons.military_tech, size: 18),
                                label: Text(badge),
                              );
                            }).toList(),
                          ),
                        ],

                        // Wallet
                        if (profile.walletAddress != null) ...[
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 8),
                          ListTile(
                            leading:
                                const Icon(Icons.account_balance_wallet),
                            title: const Text('Wallet'),
                            subtitle: Text(
                              '${profile.walletAddress!.substring(0, 6)}...${profile.walletAddress!.substring(profile.walletAddress!.length - 4)}',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _TabBarDelegate(
                    TabBar(
                      tabs: const [
                        Tab(text: 'Inventions'),
                        Tab(text: 'Investments'),
                      ],
                    ),
                  ),
                ),
              ],
              body: TabBarView(
                children: [
                  _InventionsTab(userId: userId),
                  _InvestmentsTab(userId: userId),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FollowButton extends ConsumerWidget {
  final String targetUserId;
  const _FollowButton({required this.targetUserId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFollowing =
        ref.watch(isFollowingProvider(targetUserId)).valueOrNull ?? false;
    final currentUser = ref.watch(currentUserProvider);

    return isFollowing
        ? OutlinedButton(
            onPressed: () => _toggleFollow(currentUser!.uid, false),
            child: const Text('Following'),
          )
        : FilledButton(
            onPressed: () => _toggleFollow(currentUser!.uid, true),
            child: const Text('Follow'),
          );
  }

  Future<void> _toggleFollow(String myUid, bool follow) async {
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    final followingRef = firestore
        .collection('following')
        .doc(myUid)
        .collection('user_following')
        .doc(targetUserId);

    final followerRef = firestore
        .collection('followers')
        .doc(targetUserId)
        .collection('user_followers')
        .doc(myUid);

    if (follow) {
      batch.set(followingRef, {'created_at': FieldValue.serverTimestamp()});
      batch.set(followerRef, {'created_at': FieldValue.serverTimestamp()});
    } else {
      batch.delete(followingRef);
      batch.delete(followerRef);
    }

    await batch.commit();
  }
}

class _InventionsTab extends ConsumerWidget {
  final String userId;
  const _InventionsTab({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventionsAsync = ref.watch(userInventionsProvider(userId));

    return inventionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
      data: (inventions) {
        if (inventions.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'No inventions yet',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: inventions.length,
          itemBuilder: (context, index) {
            return InventionCard(
              invention: inventions[index],
              onTap: () =>
                  context.push('/invention/${inventions[index].inventionId}'),
            );
          },
        );
      },
    );
  }
}

class _InvestmentsTab extends ConsumerWidget {
  final String userId;
  const _InvestmentsTab({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final investmentsAsync = ref.watch(userInvestmentsProvider(userId));
    final theme = Theme.of(context);

    return investmentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
      data: (investments) {
        if (investments.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'No investments yet',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: investments.length,
          itemBuilder: (context, index) {
            final inv = investments[index];
            final status = inv['status'] ?? 'PENDING';
            final amount = inv['amount_usdc'] ?? 0;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: status == 'CONFIRMED'
                      ? Colors.green.shade100
                      : Colors.orange.shade100,
                  child: Icon(
                    status == 'CONFIRMED'
                        ? Icons.check_circle
                        : Icons.hourglass_bottom,
                    color: status == 'CONFIRMED' ? Colors.green : Colors.orange,
                  ),
                ),
                title: Text('\$${amount.toStringAsFixed(2)} USDC'),
                subtitle: Text(
                  'Status: $status',
                  style: TextStyle(
                    color: status == 'CONFIRMED' ? Colors.green : Colors.orange,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  final inventionId = inv['invention_id'];
                  if (inventionId != null) {
                    context.push('/invention/$inventionId');
                  }
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;

  const _StatColumn({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _TabBarDelegate(this.tabBar);

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: tabBar,
    );
  }

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => false;
}
