import 'dart:convert';

import 'package:aceita_ai/domain/entities/goals.dart';
import 'package:aceita_ai/domain/entities/offer.dart';
import 'package:aceita_ai/domain/services/earnings_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'app_test.dart' show pumpApp;

String history() => jsonEncode([
      const EarningsEngine(Goals())
          .evaluate(Offer.create(
            appId: 'uber',
            value: 25,
            distanceKm: 10,
            timeMin: 30,
          ))
          .copyWith(accepted: true)
          .toJson(),
      const EarningsEngine(Goals())
          .evaluate(Offer.create(
            appId: 'uber',
            value: 100,
            distanceKm: 10,
            timeMin: 30,
          ))
          .copyWith(accepted: false)
          .toJson(),
    ]);

void main() {
  testWidgets('dashboard soma só aceitas; não confunde oferta com recebimento',
      (tester) async {
    await pumpApp(tester, initialPrefs: {'history_v1': history()});
    await tester.tap(find.byTooltip('Metas'));
    await tester.pumpAndSettle();
    expect(find.text('R\$ 17,50'), findsOneWidget);
    expect(find.text('Lucro estimado das corridas aceitas'), findsOneWidget);
    expect(find.text('R\$ 110,00'), findsNothing);
    await tester.tap(find.text('Mês'));
    await tester.pumpAndSettle();
    expect(find.text('Resultado do mês'), findsOneWidget);
    expect(find.text('R\$ 17,50'), findsOneWidget);
  });

  testWidgets('histórico filtra recusadas e mantém acesso ao resumo',
      (tester) async {
    await pumpApp(tester, initialPrefs: {'history_v1': history()});
    GoRouter.of(tester.element(find.text('Aceita AI'))).push('/historico');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Todas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Recusadas').last);
    await tester.pumpAndSettle();
    expect(find.text('R\$ 100,00'), findsOneWidget);
    expect(find.text('R\$ 25,00'), findsNothing);
    await tester.tap(find.text('Insights'));
    await tester.pumpAndSettle();
    expect(find.text('Lucro estimado das aceitas'), findsOneWidget);
    expect(find.text('R\$ 0,00'), findsOneWidget);
  });
}
