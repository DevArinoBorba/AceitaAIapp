import 'dart:convert';

import 'package:aceita_ai/app.dart';
import 'package:aceita_ai/core/router/app_router.dart';
import 'package:aceita_ai/data/prefs.dart';
import 'package:aceita_ai/data/cost_repository.dart';
import 'package:aceita_ai/domain/entities/cost_profile.dart';
import 'package:aceita_ai/domain/entities/goals.dart';
import 'package:aceita_ai/domain/entities/offer.dart';
import 'package:aceita_ai/domain/entities/verdict.dart';
import 'package:aceita_ai/domain/services/earnings_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regressão de layout em telas pequenas.
///
/// O motorista usa o celular no suporte do carro, muitas vezes num aparelho
/// antigo de 320-360 dp. Este arquivo monta as telas principais do app real em
/// 320, 360 e 412 dp de largura e falha em qualquer exceção de layout
/// (RenderFlex overflow, etc.).
const List<double> _widths = <double>[320, 360, 412];

/// Altura mínima da faixa pedida: o pior caso vertical.
const double _height = 640;

const Map<String, String> _screens = <String, String>{
  'home': '/',
  'metas': '/metas',
  'custo': '/custo',
  'simulador': '/simulador',
  'historico': '/historico',
  'leitura': '/leitura',
  'ajustes': '/ajustes',
  'planos': '/planos',
};

/// Histórico de exemplo: exercita os cards e as pílulas de nota, não só o
/// estado vazio.
String _historySeed() {
  final now = DateTime.now();
  const engine = EarningsEngine(Goals());
  OfferVerdict verdict({
    required String app,
    required double value,
    required double km,
    required int min,
    bool? accepted,
  }) {
    final base = engine.evaluate(
      Offer.create(
        appId: app,
        value: value,
        distanceKm: km,
        timeMin: min,
        createdAt: now,
      ),
    );
    return accepted == null ? base : base.copyWith(accepted: accepted);
  }

  final entries = <OfferVerdict>[
    verdict(app: 'uber', value: 21.4, km: 8.2, min: 22, accepted: true),
    verdict(app: '99', value: 18.0, km: 6.0, min: 18, accepted: false),
    verdict(app: 'indrive', value: 9.0, km: 7.5, min: 25),
  ].map((v) => v.toJson()).toList();
  return jsonEncode(entries);
}

Map<String, Object> _basePrefs() => <String, Object>{
      // Custo e simulador só abrem a tela real em modo PRO.
      'dev_unlock_v1': true,
      'history_v1': _historySeed(),
    };

Future<void> _pumpAt(
  WidgetTester tester,
  double width, {
  Map<String, Object>? prefs,
  bool captureInitialErrors = false,
}) async {
  tester.view.physicalSize = Size(width, _height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues(prefs ?? _basePrefs());
  final sharedPrefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: <Override>[
      sharedPreferencesProvider.overrideWithValue(sharedPrefs),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const AceitaAiApp(),
    ),
  );
  await tester.pumpAndSettle();

  // Toda navegação parte da home, que é verificada no teste dela. Aqui
  // descartamos os erros dessa primeira tela para não contaminar as demais.
  if (!captureInitialErrors) {
    Object? pending = tester.takeException();
    while (pending != null) {
      pending = tester.takeException();
    }
  }
}

GoRouter _router(WidgetTester tester) {
  final scope = tester.widget<UncontrolledProviderScope>(
    find.byType(UncontrolledProviderScope),
  );
  return scope.container.read(routerProvider);
}

/// Falha com uma mensagem útil se alguma exceção de layout foi registrada.
void _expectNoLayoutError(WidgetTester tester, String where) {
  final Object? error = tester.takeException();
  expect(error, isNull, reason: 'Erro de layout em $where');
}

/// Rola o conteúdo até o fim para que listas preguiçosas também construam e
/// pintem os itens de baixo — é lá que o overflow costuma aparecer.
Future<void> _scrollToEnd(WidgetTester tester, String where) async {
  for (int i = 0; i < 8; i++) {
    final Finder scrollables = find.byType(Scrollable);
    if (scrollables.evaluate().isEmpty) return;
    await tester.drag(
      scrollables.first,
      const Offset(0, -420),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    _expectNoLayoutError(tester, '$where (scroll $i)');
  }
}

void main() {
  testWidgets('escolha próprio/alugado é salva', (tester) async {
    await _pumpAt(tester, 360);
    _router(tester).go('/custo');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Carro alugado'), 100,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Carro alugado'));
    await tester.pumpAndSettle();
    final scope = tester.widget<UncontrolledProviderScope>(
        find.byType(UncontrolledProviderScope));
    expect(scope.container.read(costProfileProvider).isRented, isTrue);
    expect(
        scope.container.read(costRepositoryProvider).load().isRented, isTrue);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 220));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Carro próprio'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Carro próprio'));
    await tester.pumpAndSettle();
    expect(scope.container.read(costProfileProvider).isRented, isFalse);
    expect(
        scope.container.read(costRepositoryProvider).load().isRented, isFalse);
    _expectNoLayoutError(tester, 'troca próprio/alugado');
  });

  for (final double width in _widths) {
    final String w = width.toInt().toString();
    group('largura ${w}dp', () {
      for (final MapEntry<String, String> screen in _screens.entries) {
        testWidgets(
          '${screen.key} não estoura em ${w}dp',
          (tester) async {
            await _pumpAt(
              tester,
              width,
              captureInitialErrors: screen.key == 'home',
            );
            _router(tester).go(screen.value);
            await tester.pumpAndSettle();
            _expectNoLayoutError(tester, '${screen.key} ${w}dp');
            await _scrollToEnd(tester, '${screen.key} ${w}dp');
          },
        );
      }

      testWidgets(
        'custo alugado não estoura em ${w}dp',
        (tester) async {
          await _pumpAt(tester, width, prefs: {
            ..._basePrefs(),
            'cost_profile_v1': jsonEncode(const CostProfile(
              ownership: VehicleOwnership.rented,
              rentWeekly: 600,
              rentalKmWeekly: 1000,
              foodWeekly: 150,
              washWeekly: 30,
              otherWeekly: 20,
            ).toJson()),
          });
          _router(tester).go('/custo');
          await tester.pumpAndSettle();
          _expectNoLayoutError(tester, 'alugado ${w}dp');
          await _scrollToEnd(tester, 'alugado ${w}dp');
          expect(find.text('Aluguel semanal'), findsWidgets);
          expect(find.text('Franquia semanal'), findsWidgets);
          expect(find.text('Alimentação'), findsOneWidget);
          expect(find.text('Lavagem'), findsOneWidget);
          expect(find.text('Outros'), findsOneWidget);
          expect(find.text('Desgaste por km'), findsNothing);
          expect(find.text('Sua operação'), findsNothing);
          expect(find.text('Seguro (por ano)'), findsNothing);
        },
      );

      testWidgets(
        'formulário de avaliar não estoura em ${w}dp',
        (tester) async {
          await _pumpAt(tester, width);
          await tester.tap(find.text('Avaliar uma oferta'));
          await tester.pumpAndSettle();
          _expectNoLayoutError(tester, 'formulário de avaliar ${w}dp');
        },
      );

      testWidgets(
        'veredito não estoura em ${w}dp',
        (tester) async {
          await _pumpAt(tester, width);
          final verdict = const EarningsEngine(Goals()).evaluate(
            Offer.create(
              appId: 'uber',
              value: 21.4,
              distanceKm: 8.2,
              timeMin: 22,
              passengerRating: 4.9,
              label: 'Shopping Center Norte',
            ),
          );
          _router(tester).go('/avaliar', extra: verdict);
          await tester.pumpAndSettle();
          _expectNoLayoutError(tester, 'veredito ${w}dp');
          await _scrollToEnd(tester, 'veredito ${w}dp');
        },
      );
    });
  }
}
