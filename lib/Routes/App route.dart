import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../Firebase/Auth provider.dart';
import '../Screens/Splash screen.dart';
import '../Screens/Login screen.dart';
import '../Screens/Register screen.dart';
import '../Screens/Home screen.dart';
import '../Screens/Chat screen.dart';
import '../Screens/User search screen.dart';

class AppRouter {
  static GoRouter createRouter(BuildContext context) {
    return GoRouter(
      initialLocation: '/splash',
      redirect: (context, state) {
        final authProvider = context.read<AuthProvider>();
        final status = authProvider.status;
        final location = state.matchedLocation;

        if (status == AuthStatus.unknown) return '/splash';

        if (status == AuthStatus.unauthenticated) {
          if (location == '/login' || location == '/register') return null;
          return '/login';
        }

        if (status == AuthStatus.authenticated) {
          if (location == '/login' ||
              location == '/register' ||
              location == '/splash') {
            return '/home';
          }
        }
        return null;
      },
      refreshListenable: context.read<AuthProvider>(),
      routes: [
        GoRoute(
          path: '/splash',
          builder: (_, __) => const SplashScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (_, __) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (_, __) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/home',
          builder: (_, __) => const HomeScreen(),
        ),
        GoRoute(
          path: '/chat/:roomId/:otherUserId/:otherUserName',
          builder: (_, state) => ChatScreen(
            roomId: state.pathParameters['roomId']!,
            otherUserId: state.pathParameters['otherUserId']!,
            otherUserName: Uri.decodeComponent(
                state.pathParameters['otherUserName']!),
          ),
        ),
        GoRoute(
          path: '/search',
          builder: (_, __) => const UserSearchScreen(),
        ),
      ],
    );
  }
}