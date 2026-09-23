import 'package:go_router/go_router.dart';

import '../datos/local_data_service.dart';
import '../presentacion/pantallas/app/app_shell.dart';
import '../presentacion/pantallas/auth/inicio_sesion.dart';
import '../presentacion/pantallas/shared/menu.dart';

final GoRouter router = GoRouter(
  initialLocation: '/menu',
  refreshListenable: SessionController.instance,
  redirect: (context, state) {
    final loggedIn = SessionController.instance.isLoggedIn;
    final location = state.matchedLocation;
    final authRoute = location == '/menu' || location.startsWith('/login');

    if (!loggedIn && location == '/app') return '/menu';
    if (loggedIn && authRoute) return '/app';
    return null;
  },
  routes: [
    GoRoute(path: '/menu', builder: (context, state) => const Menu()),
    GoRoute(
      path: '/login/:rol',
      builder: (context, state) {
        final role = userRoleFromRoute(state.pathParameters['rol'] ?? '');
        return InicioSesion(role: role);
      },
    ),
    GoRoute(path: '/app', builder: (context, state) => const AppShell()),
    GoRoute(path: '/menu_supervisor', redirect: (context, state) => '/app'),
    GoRoute(path: '/practicas', redirect: (context, state) => '/app'),
    GoRoute(path: '/evaluacion', redirect: (context, state) => '/app'),
  ],
);
