import 'package:copiloto/app.dart';
import 'package:copiloto/data/prefs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2200);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const CopilotoApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('home abre com metas padrão', (tester) async {
    await pumpApp(tester);

    expect(find.text('Copiloto'), findsOneWidget);
    expect(find.text('Avaliar uma oferta'), findsOneWidget);
    expect(find.textContaining('Meta diária'), findsOneWidget);
  });

  testWidgets('avalia uma oferta e mostra o veredito', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Avaliar uma oferta'));
    await tester.pumpAndSettle();

    expect(find.text('Avaliar uma oferta'), findsWidgets);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '21,40');
    await tester.enterText(fields.at(1), '8,2');
    await tester.enterText(fields.at(2), '22');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Calcular veredito'));
    await tester.pumpAndSettle();

    expect(find.text('Veredito'), findsOneWidget);
    expect(find.text('Boa oferta'), findsOneWidget);
    expect(find.text('Salvar no histórico'), findsOneWidget);
  });

  testWidgets('simulador exige Turbo e libera no modo dev', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Simulador'));
    await tester.pumpAndSettle();

    expect(find.text('Simulador é Turbo'), findsOneWidget);

    await tester.tap(find.text('Modo PRO (dev)'));
    await tester.pumpAndSettle();

    expect(find.text('ACEITAR SOMENTE ACIMA DE'), findsOneWidget);
  });
}
