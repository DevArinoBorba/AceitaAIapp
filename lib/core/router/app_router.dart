import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/verdict.dart';
import '../../features/calculator/goals_screen.dart';
import '../../features/costs/costs_screen.dart';
import '../../features/history/history_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/paywall/paywall_screen.dart';
import '../../features/reader/reader_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/simulator/simulator_screen.dart';
import '../../features/verdict/verdict_screen.dart';
import '../../features/verdict/evaluate_screen.dart';

/// Mapa de navegação do MVP.
///
/// No GigU são 51 rotas (`HomeRoute`, `ToolsCdgRoute`, `CdgHistoryRoute`...).
/// Aqui estão as que sustentam o fluxo de Cálculo de Ganhos. Quando o serviço
/// nativo entrar, as rotas de CDG/câmera/radar se somam a este arquivo.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/metas',
        builder: (context, state) => const GoalsScreen(),
      ),
      GoRoute(
        path: '/custo',
        builder: (context, state) => const CostsScreen(),
      ),
      GoRoute(
        path: '/avaliar',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is OfferVerdict) return VerdictScreen(verdict: extra);
          return const EvaluateScreen();
        },
      ),
      GoRoute(
        path: '/simulador',
        builder: (context, state) => const SimulatorScreen(),
      ),
      GoRoute(
        path: '/historico',
        builder: (context, state) => const HistoryScreen(),
      ),
      GoRoute(
        path: '/ajustes',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/leitura',
        builder: (context, state) => const ReaderScreen(),
      ),
      GoRoute(
        path: '/planos',
        builder: (context, state) => const PaywallScreen(),
      ),
    ],
  );
});
