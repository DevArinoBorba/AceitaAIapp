import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/reader/reader_provider.dart';

class AceitaAiApp extends ConsumerStatefulWidget {
  const AceitaAiApp({super.key});

  @override
  ConsumerState<AceitaAiApp> createState() => _AceitaAiAppState();
}

class _AceitaAiAppState extends ConsumerState<AceitaAiApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // O balão flutuante só aparece fora do app. Quem sabe disso com certeza é
    // o ciclo de vida do Flutter — tentar deduzir pelos eventos de
    // acessibilidade fazia o balão piscar, porque ele mesmo gera eventos.
    _reportVisibility(AppLifecycleState.resumed);
  }

  @override
  void dispose() {
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
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

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
