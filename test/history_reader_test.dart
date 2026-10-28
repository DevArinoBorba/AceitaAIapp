import 'dart:convert';

import 'package:aceita_ai/data/history_repository.dart';
import 'package:aceita_ai/data/prefs.dart';
import 'package:aceita_ai/domain/entities/goals.dart';
import 'package:aceita_ai/domain/entities/offer.dart';
import 'package:aceita_ai/domain/services/earnings_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Uma entrada no formato gravado pelo serviço de acessibilidade
/// (`OfferHistory.entryOf` no Kotlin).
Map<String, dynamic> entry(
  double value,
  double km,
  int min, {
  DateTime? at,
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
      'createdAt': (at ?? DateTime.now()).toIso8601String(),
    },
    'goals': <String, dynamic>{'minPerKm': 1.45},
    if (accepted != null) 'accepted': accepted,
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reload traz a oferta gravada com o app fechado', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: <Override>[
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(historyProvider), isEmpty);

    // O serviço grava direto no arquivo, por fora do app.
    await prefs.setString('history_v1', jsonEncode(<dynamic>[entry(17.04, 13.2, 24)]));
    await container.read(historyProvider.notifier).reload();

    final history = container.read(historyProvider);
    expect(history, hasLength(1));
    expect(history.single.offer.value, 17.04);
    // lucro = 17,04 - (13,2 x 0,75)
    expect(history.single.profit, closeTo(7.14, 0.001));
  });

  test('apagar uma oferta não apaga a que o serviço gravou depois', () async {
    final older = entry(10.0, 5.0, 10);
    SharedPreferences.setMockInitialValues(<String, Object>{
      'history_v1': jsonEncode(<dynamic>[older]),
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: <Override>[
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(historyProvider), hasLength(1));

    // Enquanto o app estava em segundo plano, o serviço registrou outra.
    await prefs.setString(
      'history_v1',
      jsonEncode(<dynamic>[entry(20.0, 8.0, 15), older]),
    );

    // O motorista apaga a que estava vendo na tela.
    await container.read(historyProvider.notifier).removeAt(0);

    final left = container.read(historyProvider);
    expect(left, hasLength(1));
    expect(left.single.offer.value, 20.0);
  });

  test('aceite marcado pelo serviço chega no veredito', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: <Override>[
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    // O serviço grava a oferta; a tela seguinte diz que ele aceitou.
    await prefs.setString(
      'history_v1',
      jsonEncode(<dynamic>[
        entry(17.04, 13.2, 24, accepted: true),
        entry(9.9, 8.0, 18, accepted: false),
        entry(12.0, 6.0, 15),
      ]),
    );
    await container.read(historyProvider.notifier).reload();

    final history = container.read(historyProvider);
    expect(history[0].accepted, isTrue);
    expect(history[1].accepted, isFalse);
    expect(history[2].accepted, isNull);
  });

  test('corrigir a aceitação à mão grava no histórico', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'history_v1': jsonEncode(<dynamic>[entry(17.04, 13.2, 24)]),
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: <Override>[
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    final verdict = container.read(historyProvider).single;
    expect(verdict.accepted, isNull);

    await container.read(historyProvider.notifier).setAccepted(verdict, true);

    expect(container.read(historyProvider).single.accepted, isTrue);
    final saved = jsonDecode(prefs.getString('history_v1')!) as List<dynamic>;
    expect((saved.first as Map<String, dynamic>)['accepted'], isTrue);
  });

  test('aceite sobrevive a uma gravação feita pelo app', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'history_v1': jsonEncode(<dynamic>[entry(17.04, 13.2, 24, accepted: true)]),
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: <Override>[
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    // Qualquer gravação reescreve a lista inteira: o campo não pode se perder.
    final notifier = container.read(historyProvider.notifier);
    await notifier.reload();
    await notifier.add(
      const EarningsEngine(Goals()).evaluate(
        Offer.create(
          appId: 'uber',
          value: 20,
          distanceKm: 8,
          timeMin: 15,
        ),
      ),
    );

    final saved = jsonDecode(prefs.getString('history_v1')!) as List<dynamic>;
    expect(saved, hasLength(2));
    // A nova entrou na frente, sem aceite conhecido.
    expect((saved.first as Map<String, dynamic>).containsKey('accepted'), isFalse);
    // A antiga continua marcada.
    expect((saved.last as Map<String, dynamic>)['accepted'], isTrue);
  });
}
