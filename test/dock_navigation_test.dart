import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show pumpApp;

void main() {
  for (final width in [320.0, 360.0, 412.0]) {
    testWidgets('quatro botões navegam e avaliam em ${width.toInt()}dp',
        (tester) async {
      await pumpApp(tester);
      tester.view.physicalSize = Size(width, 640);
      tester.view.devicePixelRatio = 1;
      await tester.pumpAndSettle();
      for (final label in ['Início', 'Avaliar', 'Metas', 'Histórico']) {
        expect(find.text(label), findsOneWidget);
        expect(find.byTooltip(label), findsOneWidget);
      }
      await tester.tap(find.byTooltip('Metas'));
      await tester.pumpAndSettle();
      expect(find.text('Metas e métricas'), findsOneWidget);
      await tester.tap(find.byTooltip('Histórico'));
      await tester.pumpAndSettle();
      expect(find.text('Histórico e insights'), findsOneWidget);
      await tester.tap(find.byTooltip('Avaliar'));
      await tester.pumpAndSettle();
      expect(find.text('Calcular veredito'), findsOneWidget);
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '21,40');
      await tester.enterText(fields.at(1), '8,2');
      await tester.enterText(fields.at(2), '22');
      await tester.ensureVisible(find.text('Calcular veredito'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Calcular veredito'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Salvar no histórico'), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Salvar no histórico'), findsOneWidget);
      await tester.tap(find.byTooltip('Início'));
      await tester.pumpAndSettle();
      expect(find.text('Aceita AI'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
