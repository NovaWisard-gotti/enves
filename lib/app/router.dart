import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/experience/experience_screen.dart';
import '../features/home/home_screen.dart';
import '../features/map/map_screen.dart';
import '../features/notebook/notebook_screens.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/privacy/privacy_screen.dart';
import '../features/questions/questions_screen.dart';
import '../features/references/references_screen.dart';
import '../features/settings/settings_screen.dart';
import 'error_screens.dart';
import 'providers.dart';

class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen(userStateProvider, (_, __) => notifyListeners());
    ref.listen(contentProvider, (_, __) => notifyListeners());
  }
}

String? _redirect(Ref ref, String location) {
  final content = ref.read(contentProvider);
  final user = ref.read(userStateProvider);
  if (content.hasError || user.hasError) {
    return location == '/error' ? null : '/error';
  }
  if (!content.hasValue || !user.hasValue) {
    return location == '/cargando' ? null : '/cargando';
  }
  final onboarded = user.value!.onboarding != null;
  if (!onboarded) return location == '/onboarding' ? null : '/onboarding';
  if (location == '/cargando' || location == '/error' || location == '/onboarding') return '/';
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);
  return GoRouter(
    initialLocation: '/cargando',
    refreshListenable: refresh,
    redirect: (context, state) => _redirect(ref, state.matchedLocation),
    routes: [
      GoRoute(path: '/cargando', builder: (context, state) => const LoadingScreen()),
      GoRoute(path: '/error', builder: (context, state) => const StateErrorScreen()),
      GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(path: '/preguntas', builder: (context, state) => const QuestionsScreen()),
      GoRoute(
        path: '/experiencia/:id',
        builder: (context, state) => ExperienceScreen(id: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: '/mapa',
        builder: (context, state) => MapScreen(demo: state.uri.queryParameters['demo'] == '1'),
      ),
      GoRoute(
        path: '/cuaderno',
        builder: (context, state) => NotebookScreen(demo: state.uri.queryParameters['demo'] == '1'),
      ),
      GoRoute(
        path: '/cuaderno/:entryId',
        builder: (context, state) => NotebookEntryScreen(
          entryId: state.pathParameters['entryId'] ?? '',
          demo: state.uri.queryParameters['demo'] == '1',
        ),
      ),
      GoRoute(path: '/fuentes', builder: (context, state) => const ReferencesScreen()),
      GoRoute(path: '/ajustes', builder: (context, state) => const SettingsScreen()),
      GoRoute(path: '/ajustes/privacidad', builder: (context, state) => const PrivacyScreen()),
    ],
  );
});
