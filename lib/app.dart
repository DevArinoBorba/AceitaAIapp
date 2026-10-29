import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/cost_repository.dart';
import 'data/goals_repository.dart';
import 'data/history_repository.dart';
import 'domain/entities/goals.dart';
import 'features/reader/reader_provider.dart';

class AceitaAiApp extends ConsumerStatefulWidget {
  const AceitaAiApp({super.key});

  @override
  ConsumerState<AceitaAiApp> createState() => _AceitaAiAppState();
}

class _AceitaAiAppState extends ConsumerState<AceitaAiApp>
    with WidgetsBindingObserver {
  Timer? _goalSync;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // O balão flutuante só aparece fora do app. Quem sabe disso com certeza é
    // o ciclo de vida do Flutter — tentar deduzir pelos eventos de
    // acessibilidade fazia o balão piscar, porque ele mesmo gera eventos.
    _reportVisibility(AppLifecycleState.resumed);
    // O card é desenhado pelo nativo; ele precisa das metas já no primeiro
    // card, não só depois que o motorista mexe em alguma tela.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(costProfileProvider.notifier).applyToGoals();
      _scheduleGoalSync();
    });
  }

  @override
  void dispose() {
    _goalSync?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _reportVisibility(state);
  }

  void _reportVisibility(AppLifecycleState state) {
    final visible = state == AppLifecycleState.resumed;
    ref.read(readerProvider.notifier).setAppVisible(visible);
    // O serviço de acessibilidade grava as ofertas lidas no histórico com o
    // app fora de cena; ao voltar, é hora de reler o arquivo.
    if (visible) {
      ref.read(historyProvider.notifier).reload();
    }
  }

  /// Manda as metas para o nativo com um respiro: o slider dispara a cada
  /// pixel e o canal não precisa receber 60 gravações por segundo.
  void _scheduleGoalSync() {
    _goalSync?.cancel();
    _goalSync = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      ref.read(readerProvider.notifier).pushGoals(ref.read(goalsProvider));
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    // Metas e custo mudam em telas diferentes; um único ponto garante que o
    // card nativo esteja sempre com o mesmo número que o app mostra.
    ref.listen<Goals>(goalsProvider, (previous, next) => _scheduleGoalSync());

    return MaterialApp.router(
      title: 'Aceita AI',
      debugShowCheckedModeBanner: false,
      theme: buildDarkTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: ThemeMode.dark,
      routerConfig: router,
    );
  }
}
