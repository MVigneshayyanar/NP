import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'providers/auth_provider.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/onboarding/profile_setup_screen.dart';
import 'screens/onboarding/sensory_assessment_screen.dart';
import 'screens/onboarding/goals_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/scan/scan_room_screen.dart';
import 'screens/coach/coach_screen.dart';
import 'screens/progress/progress_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/shell/main_shell.dart';

/// Listenable adapter for Riverpod authProvider updates without re-instantiating GoRouter.
class AuthListenable extends ChangeNotifier {
  AuthListenable(Ref ref) {
    ref.listen<AuthState>(authProvider, (_, __) {
      notifyListeners();
    });
  }
}

/// App router with auth guard and bottom nav shell.
final routerProvider = Provider<GoRouter>((ref) {
  final listenable = AuthListenable(ref);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: listenable,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final isLoading = authState.status == AuthStatus.loading ||
          authState.status == AuthStatus.initial;
      final isAuthenticated = authState.status == AuthStatus.authenticated;
      final isOnSplash = state.matchedLocation == '/splash';
      final isOnAuth = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      // Stay on splash while loading initial auth check
      if (isLoading) return null;

      // If finished loading and still on splash, redirect appropriately
      if (isOnSplash) {
        if (!isAuthenticated) return '/login';
        if (authState.user?.onboardingCompleted == false) {
          return '/onboarding/profile';
        }
        return '/home';
      }

      // If not authenticated and trying to access protected screens, go to login
      if (!isAuthenticated && !isOnAuth) return '/login';

      // If authenticated and on auth screens, redirect to home or onboarding
      if (isAuthenticated && isOnAuth) {
        if (authState.user?.onboardingCompleted == false) {
          return '/onboarding/profile';
        }
        return '/home';
      }

      return null;
    },


    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),

      // Onboarding routes
      GoRoute(
        path: '/onboarding/profile',
        builder: (context, state) => const ProfileSetupScreen(),
      ),
      GoRoute(
        path: '/onboarding/sensory',
        builder: (context, state) => const SensoryAssessmentScreen(),
      ),
      GoRoute(
        path: '/onboarding/goals',
        builder: (context, state) => const GoalsScreen(),
      ),

      // Main app with bottom navigation shell
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/coach',
            builder: (context, state) => const CoachScreen(),
          ),
          GoRoute(
            path: '/progress',
            builder: (context, state) => const ProgressScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),

      // Standalone routes (no bottom nav)
      GoRoute(
        path: '/scan',
        builder: (context, state) => const ScanRoomScreen(),
      ),
    ],
  );
});
