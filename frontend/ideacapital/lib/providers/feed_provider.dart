import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/invention.dart';

/// The feed filter state.
enum FeedFilter { trending, nearGoal, newest, following }

final feedFilterProvider = StateProvider<FeedFilter>((ref) => FeedFilter.trending);

/// Streams a paginated list of inventions from Firestore based on the active filter.
final inventionFeedProvider = StreamProvider.family<List<Invention>, FeedFilter>(
  (ref, filter) {
    final firestore = FirebaseFirestore.instance;
    Query<Map<String, dynamic>> query = firestore.collection('inventions');

    switch (filter) {
      case FeedFilter.trending:
        query = query
            .where('status', isEqualTo: 'LIVE')
            .orderBy('funding.backer_count', descending: true)
            .limit(20);
        break;
      case FeedFilter.nearGoal:
        query = query
            .where('status', isEqualTo: 'FUNDING')
            .orderBy('funding.raised_usdc', descending: true)
            .limit(20);
        break;
      case FeedFilter.newest:
        query = query
            .where('status', whereIn: ['LIVE', 'FUNDING'])
            .orderBy('created_at', descending: true)
            .limit(20);
        break;
      case FeedFilter.following:
        // TODO: Filter by user's following list
        query = query
            .orderBy('created_at', descending: true)
            .limit(20);
        break;
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Invention.fromJson(doc.data())).toList();
    });
  },
);

/// Streams a single invention by ID.
final inventionDetailProvider = StreamProvider.family<Invention?, String>(
  (ref, inventionId) {
    return FirebaseFirestore.instance
        .collection('inventions')
        .doc(inventionId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return Invention.fromJson(doc.data()!);
    });
  },
);
