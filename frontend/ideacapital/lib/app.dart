import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'screens/feed/feed_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/invention/invention_detail_screen.dart';
import 'screens/invention/create_invention_screen.dart';
import 'screens/profile/profile_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const FeedScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/invention/:id',
        builder: (context, state) => InventionDetailScreen(
          inventionId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/create',
        builder: (context, state) => const CreateInventionScreen(),
      ),
      GoRoute(
        path: '/profile/:uid',
        builder: (context, state) => ProfileScreen(
          userId: state.pathParameters['uid']!,
        ),
      ),
    ],
  );
});

class IdeaCapitalApp extends ConsumerWidget {
  const IdeaCapitalApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'IdeaCapital',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C5CE7),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Inter',
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C5CE7),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'Inter',
      ),
      routerConfig: router,
    );
  }
}
