import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../models/invention.dart';
import '../../widgets/invention_card.dart';

/// Search provider — queries Firestore by tags and title keywords.
final searchQueryProvider = StateProvider<String>((ref) => '');

final searchResultsProvider = FutureProvider.family<List<Invention>, String>(
  (ref, query) async {
    if (query.trim().isEmpty) return [];

    final firestore = FirebaseFirestore.instance;
    final lowerQuery = query.toLowerCase();

    // Search by virality tags (exact match on tags)
    final tagResults = await firestore
        .collection('inventions')
        .where('social_metadata.virality_tags', arrayContains: query)
        .where('status', whereIn: ['LIVE', 'FUNDING'])
        .limit(20)
        .get();

    // Also search by display_title prefix (Firestore range query)
    final titleResults = await firestore
        .collection('inventions')
        .where('social_metadata.display_title', isGreaterThanOrEqualTo: query)
        .where('social_metadata.display_title', isLessThanOrEqualTo: '$query\uf8ff')
        .where('status', whereIn: ['LIVE', 'FUNDING'])
        .limit(20)
        .get();

    // Merge and deduplicate results
    final Map<String, Invention> merged = {};
    for (final doc in [...tagResults.docs, ...titleResults.docs]) {
      final invention = Invention.fromJson(doc.data());
      merged[invention.inventionId] = invention;
    }

    return merged.values.toList();
  },
);

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  String _activeQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch() {
    setState(() {
      _activeQuery = _searchController.text.trim();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search inventions, tags...',
            border: InputBorder.none,
          ),
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _onSearch(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _onSearch,
          ),
        ],
      ),
      body: _activeQuery.isEmpty
          ? _buildSuggestions(theme)
          : _buildResults(),
    );
  }

  Widget _buildSuggestions(ThemeData theme) {
    final popularTags = [
      'GreenTech', 'Robotics', 'HealthTech', 'AI', 'IoT',
      'FinTech', 'BioTech', 'CleanEnergy', 'SpaceTech', 'EdTech',
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Popular Tags',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: popularTags.map((tag) {
              return ActionChip(
                label: Text(tag),
                onPressed: () {
                  _searchController.text = tag;
                  _onSearch();
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    final resultsAsync = ref.watch(searchResultsProvider(_activeQuery));

    return resultsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
      data: (inventions) {
        if (inventions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.search_off, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text('No results for "$_activeQuery"'),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: inventions.length,
          itemBuilder: (context, index) {
            return InventionCard(
              invention: inventions[index],
              onTap: () => context.push('/invention/${inventions[index].inventionId}'),
            );
          },
        );
      },
    );
  }
}
