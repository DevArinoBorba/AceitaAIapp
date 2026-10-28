import 'dart:convert';

import 'package:aceita_ai/app.dart';
import 'package:aceita_ai/data/prefs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpApp(
  WidgetTester tester, {
  Map<String, Object> initialPrefs = const <String, Object>{},
}) async {
  tester.view.physicalSize = const Size(1080, 2200);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues(initialPrefs);
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const AceitaAiApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('home abre com metas padrão', (tester) async {
    await pumpApp(tester);

    expect(find.text('Aceita AI'), findsOneWidget);
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

  testWidgets('tela de leitura abre e explica o estado', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Leitura de tela'));
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma tela capturada ainda'), findsOneWidget);
    expect(find.text('Capturar qualquer app'), findsOneWidget);
    expect(find.text('APPS LIDOS'), findsOneWidget);
  });

  testWidgets('oferta gravada pelo serviço aparece na home', (tester) async {
    // Exatamente o formato que o serviço grava no aparelho: chave history_v1,
    // offer + goals, sem os campos que o card não conhece.
    final now = DateTime.now();
    await pumpApp(
      tester,
      initialPrefs: <String, Object>{
        'history_v1': jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{
            'offer': <String, dynamic>{
              'appId': 'uber',
              'value': 17.04,
              'distanceKm': 13.2,
              'timeMin': 24,
              'passengerRating': null,
              'label': null,
              'createdAt': now.toIso8601String(),
            },
            'goals': <String, dynamic>{'minPerKm': 1.45},
          },
        ]),
      },
    );

    // A oferta foi lida, mas ninguém viu se ele aceitou: não é ganho.
    expect(find.text('0 aceitas'), findsOneWidget);
    expect(find.text('R\$ 0,00'), findsOneWidget);
    // lucro = 17,04 - (13,2 x 0,75) = 7,14
    expect(find.text('Analisado: R\$ 7,14 em 1 ofertas'), findsOneWidget);
  });

  testWidgets('home soma só a corrida aceita no ganho confirmado', (tester) async {
    final now = DateTime.now();
    Map<String, dynamic> entry({
      required double value,
      required double km,
      required int min,
      bool? accepted,
    }) {
      return <String, dynamic>{
        'offer': <String, dynamic>{
          'appId': 'uber',
          'value': value,
          'distanceKm': km,
          'timeMin': min,
          'passengerRating': null,
          'label': null,
          'createdAt': now.toIso8601String(),
        },
        'goals': <String, dynamic>{'minPerKm': 1.45},
        if (accepted != null) 'accepted': accepted,
      };
    }

    await pumpApp(
      tester,
      initialPrefs: <String, Object>{
        'history_v1': jsonEncode(<Map<String, dynamic>>[
          // aceita: 17,04 - (13,2 x 0,75) = 7,14
          entry(value: 17.04, km: 13.2, min: 24, accepted: true),
          // recusada: não entra no ganho
          entry(value: 30.0, km: 20.0, min: 40, accepted: false),
          // indefinida: também não
          entry(value: 12.0, km: 11.0, min: 30),
        ]),
      },
    );

    expect(find.text('1 aceitas'), findsOneWidget);
    expect(find.text('R\$ 7,14'), findsOneWidget);
    // analisado = 7,14 + (30 - 15) + (12 - 8,25) = 25,89
    expect(find.text('Analisado: R\$ 25,89 em 3 ofertas'), findsOneWidget);
  });
}
