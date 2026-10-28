import 'package:aceita_ai/domain/entities/card_layout.dart';
import 'package:aceita_ai/platform/reader_channel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScreenDump', () {
    test('lê nós e metadados do mapa nativo', () {
      final dump = ScreenDump.fromMap(<String, Object?>{
        'package': 'com.ubercab.driver',
        'appLabel': 'Uber Driver',
        'reason': 'content_changed',
        'at': 1700000000000,
        'hash': 'abc123',
        'nodes': <Object?>[
          <String, Object?>{
            'text': 'R\$ 21,40',
            'id': 'com.ubercab.driver:id/fare',
            'cls': 'android.widget.TextView',
          },
          <String, Object?>{
            'text': '8,2 km',
            'id': '',
            'cls': 'android.widget.TextView',
          },
        ],
      });

      expect(dump, isNotNull);
      expect(dump!.package, 'com.ubercab.driver');
      expect(dump.nodes, hasLength(2));
      expect(dump.nodes.first.id, 'com.ubercab.driver:id/fare');
      expect(dump.plainText, contains('R\$ 21,40'));
      expect(dump.toReport(), contains('package: com.ubercab.driver'));
      expect(dump.toReport(), contains('com.ubercab.driver:id/fare'));
    });

    test('entrada inválida não lança', () {
      expect(ScreenDump.fromMap(null), isNull);
      expect(ScreenDump.fromMap('texto'), isNull);
      expect(ScreenDump.fromMap(const <String, Object?>{}), isNotNull);
    });

    test('dump vazio tem lista de nós vazia', () {
      final dump = ScreenDump.fromMap(const <String, Object?>{})!;
      expect(dump.nodes, isEmpty);
      expect(dump.plainText, isEmpty);
    });
  });

  group('ReaderStatus', () {
    test('sem camada nativa fica indisponível', () {
      const status = ReaderStatus.unsupported();

      expect(status.available, isFalse);
      expect(status.isLive, isFalse);
      expect(status.headline, 'Indisponível nesta plataforma');
    });

    test('serviço ativo e conectado está lendo', () {
      final status = ReaderStatus.fromMap(<String, Object?>{
        'serviceEnabled': true,
        'serviceConnected': true,
        'captureAll': false,
        'targets': <Object?>['com.ubercab.driver', 'br.com.brainweb.ifood'],
        'dumpCount': 2,
        'lastPackage': 'com.ubercab.driver',
        'lastAt': 1700000000000,
      });

      expect(status.available, isTrue);
      expect(status.isLive, isTrue);
      expect(status.targets, hasLength(2));
      expect(status.dumpCount, 2);
      expect(status.headline, 'Lendo a tela');
      expect(status.lastAt, isNotNull);
    });

    test('ligado mas ainda não conectado não é live', () {
      final status = ReaderStatus.fromMap(<String, Object?>{
        'serviceEnabled': true,
        'serviceConnected': false,
      });

      expect(status.isLive, isFalse);
      expect(status.headline, 'Ligada, conectando…');
    });

    test('desligado nas configurações', () {
      final status = ReaderStatus.fromMap(<String, Object?>{
        'serviceEnabled': false,
        'serviceConnected': false,
      });

      expect(status.headline, 'Acessibilidade desligada');
      expect(status.targets, isEmpty);
    });

    test('sem ajuste de card, mostra tudo', () {
      final status = ReaderStatus.fromMap(<String, Object?>{
        'serviceEnabled': true,
        'serviceConnected': true,
      });

      expect(status.cardFields, cardDetailedPreset);
    });

    test('lê o card escolhido pelo motorista', () {
      final status = ReaderStatus.fromMap(<String, Object?>{
        'cardFields': <Object?>['valor', 'rkm', 'veredito'],
      });

      expect(
        status.cardFields,
        <CardField>{CardField.value, CardField.perKm, CardField.verdict},
      );
      expect(cardModeOf(status.cardFields), CardMode.simple);
    });
  });

  group('ReaderEvent', () {
    test('distingue status de dump', () {
      final statusEvent = ReaderEvent.fromMap(<String, Object?>{
        'kind': 'status',
        'status': <String, Object?>{'serviceEnabled': true},
      });
      expect(statusEvent.status, isNotNull);
      expect(statusEvent.dump, isNull);

      final dumpEvent = ReaderEvent.fromMap(<String, Object?>{
        'kind': 'dump',
        'dump': <String, Object?>{
          'package': 'com.ubercab.driver',
          'nodes': <Object?>[],
        },
      });
      expect(dumpEvent.dump, isNotNull);
      expect(dumpEvent.dump!.package, 'com.ubercab.driver');
    });

    test('tipo desconhecido vira evento vazio', () {
      final event = ReaderEvent.fromMap(const <String, Object?>{'kind': 'x'});
      expect(event.status, isNull);
      expect(event.dump, isNull);
    });
  });
}
