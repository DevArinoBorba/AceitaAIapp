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

  testWidgets('simulador projeta com ofertas de exemplo', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Simulador'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Modo PRO (dev)'));
    await tester.pumpAndSettle();

    expect(find.text('Histórico curto'), findsOneWidget);

    await tester.tap(find.text('Gerar 12 ofertas de exemplo'));
    await tester.pumpAndSettle();

    expect(find.text('hoje por semana'), findsOneWidget);
    expect(find.text('com o filtro'), findsOneWidget);
    expect(find.textContaining('Aceitaria'), findsOneWidget);
  });

  testWidgets('ajustes abre com todas as seções', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Modo PRO (dev)'), findsOneWidget);
    expect(find.text('Zerar histórico'), findsOneWidget);
    expect(find.text('Como o cálculo funciona'), findsOneWidget);
  });

  testWidgets('oferta salva aparece no histórico', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Avaliar uma oferta'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '12,00');
    await tester.enterText(fields.at(1), '11,0');
    await tester.enterText(fields.at(2), '30');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Calcular veredito'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Salvar no histórico'));
    await tester.pumpAndSettle();

    expect(find.text('Salvo no histórico'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Histórico'));
    await tester.pumpAndSettle();

    expect(find.text('Ofertas'), findsOneWidget);
    expect(find.text('Uber'), findsWidgets);
  });
}
