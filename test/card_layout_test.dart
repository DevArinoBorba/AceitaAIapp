import 'package:aceita_ai/domain/entities/card_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CardField', () {
    test('as chaves são as combinadas com o nativo', () {
      // O card é desenhado pelo Kotlin a partir dessas mesmas chaves
      // (reader/CardLayout.kt). Se uma mudar aqui sozinha, a opção some da
      // tela sem aviso — este teste é o alarme.
      expect(
        CardField.values.map((field) => field.key).toList(),
        <String>[
          'valor',
          'veredito',
          'rkm',
          'rh',
          'lucro',
          'km',
          'tempo',
          'uber',
          'nota',
        ],
      );
    });

    test('chave desconhecida é ignorada', () {
      expect(CardField.fromKey('valor'), CardField.value);
      expect(CardField.fromKey('inexistente'), isNull);
      expect(CardField.fromKey(''), isNull);
    });
  });

  group('cardFieldsFrom', () {
    test('lista vazia cai no detalhado', () {
      expect(cardFieldsFrom(const <String>[]), cardDetailedPreset);
    });

    test('lê as chaves que vieram do nativo', () {
      expect(
        cardFieldsFrom(<String>['valor', 'rkm']),
        <CardField>{CardField.value, CardField.perKm},
      );
    });

    test('só chave inválida cai no detalhado, sem quebrar', () {
      expect(cardFieldsFrom(<String>['x', 'y']), cardDetailedPreset);
    });
  });

  group('cardModeOf', () {
    test('reconhece os dois presets', () {
      expect(cardModeOf(cardSimplePreset), CardMode.simple);
      expect(cardModeOf(cardDetailedPreset), CardMode.detailed);
    });

    test('qualquer mexida vira personalizado', () {
      expect(cardModeOf(<CardField>{CardField.value}), CardMode.custom);
      expect(
        cardModeOf(<CardField>{CardField.value, CardField.profit}),
        CardMode.custom,
      );
      // Todos os campos do detalhado menos um.
      expect(
        cardModeOf(
          CardField.values.toSet()..remove(CardField.rating),
        ),
        CardMode.custom,
      );
    });
  });

  group('cardDurationOptions', () {
    test('inclui o tempo padrão de 10s e opções ordenadas', () {
      expect(defaultCardDurationSeconds, 10);
      expect(cardDurationOptions, <int>[5, 8, 10, 14, 20]);
      expect(cardDurationOptions, contains(defaultCardDurationSeconds));
    });
  });
}
