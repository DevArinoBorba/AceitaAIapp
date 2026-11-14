import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show pumpApp;

void main() {
  for (final width in [320.0, 360.0, 412.0]) {
    testWidgets('quatro botões navegam em ${width.toInt()}dp', (tester) async {
      await pumpApp(tester);
      tester.view.physicalSize = Size(width, 640);
      tester.view.devicePixelRatio = 1;
      await tester.pumpAndSettle();
      for (final label in ['Início', 'Meu custo', 'Metas', 'Histórico']) {
        expect(find.text(label), findsOneWidget);
        expect(find.byTooltip(label), findsOneWidget);
      }
      await tester.tap(find.byTooltip('Meu custo'));
      await tester.pumpAndSettle();
      expect(find.text('SEU CUSTO REAL'), findsOneWidget);
      await tester.tap(find.byTooltip('Metas'));
      await tester.pumpAndSettle();
      expect(find.text('Metas e métricas'), findsOneWidget);
      await tester.tap(find.byTooltip('Histórico'));
      await tester.pumpAndSettle();
      expect(find.text('Histórico e insights'), findsOneWidget);
      await tester.tap(find.byTooltip('Início'));
      await tester.pumpAndSettle();
      expect(find.text('Aceita AI'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
