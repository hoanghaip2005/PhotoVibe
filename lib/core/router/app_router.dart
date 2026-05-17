import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/analysis/loading_screen.dart';
import '../../features/capture/capture_screen.dart';
import '../../features/capture/preview_screen.dart';
import '../../features/diary/vibe_diary_screen.dart';
import '../../features/filter_editor/filter_editor_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/onboarding/splash_screen.dart';
import '../../features/playlist/playlist_detail_screen.dart';
import '../../features/playlist/playlist_library_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/profile/music_preference_setup_screen.dart';
import '../../features/result/result_screen.dart';
import '../../state/app_state.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final appState = ref.read(appStateProvider);
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: appState,
    redirect: (context, state) {
      final path = state.uri.path;
      if (path == '/splash') return null;
      if (!appState.onboardingCompleted) {
        return path == '/onboarding' ? null : '/onboarding';
      }
      if (!appState.authPromptCompleted && path != '/login') {
        return '/login';
      }
      if (!appState.musicProfileCompleted) {
        return path == '/music-setup' || path == '/login'
            ? null
            : '/music-setup';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) =>
            LoginScreen(nextPath: state.uri.queryParameters['next']),
      ),
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/capture',
        builder: (context, state) {
          return CaptureScreen(
            initialTab: state.uri.queryParameters['tab'] ?? 'camera',
          );
        },
      ),
      GoRoute(
        path: '/preview',
        builder: (context, state) => const PreviewScreen(),
      ),
      GoRoute(
        path: '/loading',
        builder: (context, state) => const LoadingScreen(),
      ),
      GoRoute(
        path: '/result/:id',
        builder: (context, state) =>
            ResultScreen(resultId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/playlists',
        builder: (context, state) => const PlaylistLibraryScreen(),
      ),
      GoRoute(
        path: '/playlists/:id',
        builder: (context, state) =>
            PlaylistDetailScreen(playlistId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/filter-editor/:resultId',
        builder: (context, state) =>
            FilterEditorScreen(resultId: state.pathParameters['resultId']!),
      ),
      GoRoute(
        path: '/diary',
        builder: (context, state) => const VibeDiaryScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/music-setup',
        builder: (context, state) => const MusicPreferenceSetupScreen(),
      ),
    ],
  );
});
