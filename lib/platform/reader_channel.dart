import 'package:flutter/services.dart';

import '../domain/entities/card_layout.dart';

/// Um nó de texto encontrado na tela.
///
/// O `id` é o `viewIdResourceName` (ex.: `com.ubercab.driver:id/...`). É o que
/// torna o parser estável: texto muda de idioma, id não.
class ReaderNode {
  const ReaderNode({required this.text, required this.id, required this.cls});

  final String text;
  final String id;
  final String cls;

  factory ReaderNode.fromMap(Object? raw) {
    if (raw is! Map) return const ReaderNode(text: '', id: '', cls: '');
    return ReaderNode(
      text: (raw['text'] ?? '').toString(),
      id: (raw['id'] ?? '').toString(),
      cls: (raw['cls'] ?? '').toString(),
    );
  }
}

/// Uma leitura completa da tela de um app.
class ScreenDump {
  const ScreenDump({
    required this.package,
    required this.appLabel,
    required this.reason,
    required this.at,
    required this.hash,
    required this.nodes,
  });

  final String package;
  final String appLabel;
  final String reason;
  final DateTime at;
  final String hash;
  final List<ReaderNode> nodes;

  static ScreenDump? fromMap(Object? raw) {
    if (raw is! Map) return null;

    final nodes = <ReaderNode>[];
    final rawNodes = raw['nodes'];
    if (rawNodes is List) {
      for (final node in rawNodes) {
        nodes.add(ReaderNode.fromMap(node));
      }
    }

    final millis = raw['at'];
    return ScreenDump(
      package: (raw['package'] ?? 'desconhecido').toString(),
      appLabel: (raw['appLabel'] ?? 'Aplicativo').toString(),
      reason: (raw['reason'] ?? '').toString(),
      at: millis is int
          ? DateTime.fromMillisecondsSinceEpoch(millis)
          : DateTime.now(),
      hash: (raw['hash'] ?? '').toString(),
      nodes: nodes,
    );
  }

  /// Texto plano de todos os nós — usado pelo parser e pelo botão "copiar".
  String get plainText => nodes.map((node) => node.text).join('\n');

  /// Relatório completo, no formato que o desenvolvedor (eu) precisa ver.
  String toReport() {
    final buffer = StringBuffer()
      ..writeln('package: $package')
      ..writeln('app: $appLabel')
      ..writeln('capturado em: ${at.toIso8601String()}')
      ..writeln('nos: ${nodes.length}')
      ..writeln('hash: $hash')
      ..writeln('---');

    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      final id = node.id.isEmpty ? '-' : node.id;
      buffer.writeln('${i.toString().padLeft(3, '0')}  [$id]  ${node.text}');
    }
    return buffer.toString();
  }
}

/// Estado do serviço de acessibilidade.
class ReaderStatus {
  const ReaderStatus({
    required this.available,
    required this.serviceEnabled,
    required this.serviceConnected,
    required this.captureAll,
    required this.readingEnabled,
    required this.bubbleEnabled,
    this.canDrawOverlays = true,
    this.batteryUnrestricted = true,
    this.notificationsEnabled = true,
    required this.targets,
    required this.dumpCount,
    this.cardFields = const <CardField>{},
    this.lastPackage,
    this.lastAt,
  });

  /// Usado quando não existe camada nativa (testes, web, desktop).
  const ReaderStatus.unsupported()
      : available = false,
        serviceEnabled = false,
        serviceConnected = false,
        captureAll = false,
        readingEnabled = false,
        bubbleEnabled = false,
        canDrawOverlays = false,
        batteryUnrestricted = true,
        notificationsEnabled = true,
        targets = const <String>[],
        dumpCount = 0,
        cardFields = const <CardField>{},
        lastPackage = null,
        lastAt = null;

  final bool available;
  final bool serviceEnabled;
  final bool serviceConnected;
  final bool captureAll;

  /// O balão está ligado? (pausar a leitura não desliga o serviço)
  final bool readingEnabled;

  /// O balão flutuante está visível?
  final bool bubbleEnabled;

  /// O Android permite desenhar sobre outros apps? No MIUI é isso que faz o
  /// balão receber toque, não só aparecer.
  final bool canDrawOverlays;

  /// O Android está livre para manter a leitura viva? Com "economia de
  /// bateria" ligada o MIUI corta o processo no meio do turno — a
  /// acessibilidade continua marcada como ligada, mas o card para de aparecer.
  final bool batteryUnrestricted;

  /// O motorista autorizou as notificações? É o canal do aviso "leitura parou".
  final bool notificationsEnabled;

  final List<String> targets;
  final int dumpCount;

  /// Quais números o card flutuante mostra (ajuste do motorista).
  final Set<CardField> cardFields;

  final String? lastPackage;
  final DateTime? lastAt;

  /// Serviço ligado e conectado.
  bool get isLive => available && serviceEnabled && serviceConnected;

  /// Ligado, conectado e sem pausa: é o estado em que a oferta é lida.
  bool get isReading => isLive && readingEnabled;

  /// O turno está protegido: lendo agora, sem o Android cortar por bateria e
  /// com as notificações liberadas para avisar se parar.
  bool get isShiftReady =>
      isReading && batteryUnrestricted && notificationsEnabled;

  String get headline {
    if (!available) return 'Indisponível nesta plataforma';
    if (!serviceEnabled) return 'Acessibilidade desligada';
    if (!serviceConnected) return 'Ligada, conectando…';
    if (!readingEnabled) return 'Leitura pausada';
    return 'Lendo a tela';
  }

  static ReaderStatus fromMap(Object? raw) {
    if (raw is! Map) return const ReaderStatus.unsupported();

    final rawTargets = raw['targets'];
    final rawFields = raw['cardFields'];
    final lastMillis = raw['lastAt'];

    return ReaderStatus(
      available: true,
      serviceEnabled: raw['serviceEnabled'] == true,
      serviceConnected: raw['serviceConnected'] == true,
      captureAll: raw['captureAll'] == true,
      readingEnabled: raw['readingEnabled'] != false,
      bubbleEnabled: raw['bubbleEnabled'] != false,
      canDrawOverlays: raw['canDrawOverlays'] == true,
      batteryUnrestricted: raw['batteryUnrestricted'] != false,
      notificationsEnabled: raw['notificationsEnabled'] != false,
      targets: rawTargets is List
          ? rawTargets.map((item) => item.toString()).toList()
          : const <String>[],
      dumpCount: raw['dumpCount'] is int ? raw['dumpCount'] as int : 0,
      cardFields: cardFieldsFrom(
        rawFields is List
            ? rawFields.map((item) => item.toString()).toList()
            : const <String>[],
      ),
      lastPackage: raw['lastPackage']?.toString(),
      lastAt: lastMillis is int
          ? DateTime.fromMillisecondsSinceEpoch(lastMillis)
          : null,
    );
  }
}

class ReaderEvent {
  const ReaderEvent({this.status, this.dump});

  final ReaderStatus? status;
  final ScreenDump? dump;

  factory ReaderEvent.fromMap(Object? raw) {
    if (raw is! Map) return const ReaderEvent();
    switch (raw['kind']) {
      case 'status':
        return ReaderEvent(status: ReaderStatus.fromMap(raw['status']));
      case 'dump':
        return ReaderEvent(dump: ScreenDump.fromMap(raw['dump']));
      default:
        return const ReaderEvent();
    }
  }
}

/// Fachada tipada do canal nativo.
///
/// Toda chamada é tolerante a falha: em teste/widget sem Android a leitura
/// simplesmente aparece como indisponível em vez de quebrar a tela.
class ReaderChannel {
  const ReaderChannel();

  static const MethodChannel _methods =
      MethodChannel('br.com.aceitaai.app/reader');
  static const EventChannel _events =
      EventChannel('br.com.aceitaai.app/reader_events');

  Future<ReaderStatus> status() async {
    try {
      final result = await _methods.invokeMapMethod<String, Object?>('status');
      return ReaderStatus.fromMap(result);
    } catch (_) {
      return const ReaderStatus.unsupported();
    }
  }

  Future<ScreenDump?> lastDump() async {
    try {
      final result = await _methods.invokeMapMethod<String, Object?>('lastDump');
      return ScreenDump.fromMap(result);
    } catch (_) {
      return null;
    }
  }

  Future<ReaderStatus> setCaptureAll({required bool enabled}) async {
    try {
      final result = await _methods.invokeMapMethod<String, Object?>(
        'setCaptureAll',
        <String, Object?>{'enabled': enabled},
      );
      return ReaderStatus.fromMap(result);
    } catch (_) {
      return const ReaderStatus.unsupported();
    }
  }

  Future<ReaderStatus> setReadingEnabled({required bool enabled}) async {
    try {
      final result = await _methods.invokeMapMethod<String, Object?>(
        'setReadingEnabled',
        <String, Object?>{'enabled': enabled},
      );
      return ReaderStatus.fromMap(result);
    } catch (_) {
      return const ReaderStatus.unsupported();
    }
  }

  Future<ReaderStatus> setBubbleEnabled({required bool enabled}) async {
    try {
      final result = await _methods.invokeMapMethod<String, Object?>(
        'setBubbleEnabled',
        <String, Object?>{'enabled': enabled},
      );
      return ReaderStatus.fromMap(result);
    } catch (_) {
      return const ReaderStatus.unsupported();
    }
  }

  /// Grava quais números o card mostra. O nativo desenha o card, então quem
  /// aplica o ajuste é ele; o Flutter só manda a lista de chaves.
  Future<ReaderStatus> setCardFields(Set<CardField> fields) async {
    try {
      final result = await _methods.invokeMapMethod<String, Object?>(
        'setCardFields',
        <String, Object?>{
          'fields': fields.map((field) => field.key).toList(),
        },
      );
      return ReaderStatus.fromMap(result);
    } catch (_) {
      return const ReaderStatus.unsupported();
    }
  }

  /// Grava as metas no nativo. O card é desenhado pelo serviço, com o app
  /// fechado, então quem calcula o lucro de cada oferta é o Kotlin — ele
  /// precisa dos mesmos números que a tela mostra.
  Future<ReaderStatus> setGoals({
    required double minPerKm,
    required double goodPerKm,
    required double minPerHour,
    required double goodPerHour,
    required double minProfitPct,
    required double goodProfitPct,
    required double costPerKm,
    required double minRating,
    required double goodRating,
  }) async {
    try {
      final result = await _methods.invokeMapMethod<String, Object?>(
        'setGoals',
        <String, Object?>{
          'minPerKm': minPerKm,
          'goodPerKm': goodPerKm,
          'minPerHour': minPerHour,
          'goodPerHour': goodPerHour,
          'minProfitPct': minProfitPct,
          'goodProfitPct': goodProfitPct,
          'costPerKm': costPerKm,
          'minRating': minRating,
          'goodRating': goodRating,
        },
      );
      return ReaderStatus.fromMap(result);
    } catch (_) {
      return const ReaderStatus.unsupported();
    }
  }

  Future<ReaderStatus> setTargets(List<String> packages) async {
    try {
      final result = await _methods.invokeMapMethod<String, Object?>(
        'setTargets',
        <String, Object?>{'packages': packages},
      );
      return ReaderStatus.fromMap(result);
    } catch (_) {
      return const ReaderStatus.unsupported();
    }
  }

  /// Avisa o serviço se o Aceita AI está na frente, para o balão sair de cena.
  Future<void> setAppVisible(bool visible) async {
    try {
      await _methods.invokeMethod<void>(
        'setAppVisible',
        <String, Object?>{'visible': visible},
      );
    } catch (_) {
      // Sem Android não existe balão.
    }
  }

  Future<void> openAccessibilitySettings() async {
    try {
      await _methods.invokeMethod<void>('openAccessibilitySettings');
    } catch (_) {
      // Sem Android não existe ajuste para abrir.
    }
  }

  /// Abre a tela "exibir sobre outros apps" do Android.
  Future<void> openOverlaySettings() async {
    try {
      await _methods.invokeMethod<void>('openOverlaySettings');
    } catch (_) {
      // idem
    }
  }

  /// Abre a lista de apps com bateria sem restrição.
  Future<void> openBatterySettings() async {
    try {
      await _methods.invokeMethod<void>('openBatterySettings');
    } catch (_) {
      // idem
    }
  }

  /// Abre o autostart do MIUI (cai nos detalhes do app quando não existe).
  Future<void> openAutoStart() async {
    try {
      await _methods.invokeMethod<void>('openAutoStart');
    } catch (_) {
      // idem
    }
  }

  /// Abre as notificações deste app nas configurações do Android.
  Future<void> openNotificationSettings() async {
    try {
      await _methods.invokeMethod<void>('openNotificationSettings');
    } catch (_) {
      // idem
    }
  }

  /// Desenha o card com números de exemplo, para conferir o layout.
  Future<void> devShowOffer({
    required double value,
    required double km,
    required int minutes,
  }) async {
    try {
      await _methods.invokeMethod<void>('devOffer', <String, Object?>{
        'value': value,
        'km': km,
        'minutes': minutes,
      });
    } catch (_) {
      // sem Android não há card
    }
  }

  /// Registra uma oferta de exemplo no histórico, pelo mesmo caminho que a
  /// oferta real usa (serviço nativo -> arquivo do histórico).
  Future<bool> devRecordOffer({
    double value = 7.15,
    double km = 2.1,
    int minutes = 9,
  }) async {
    try {
      final saved = await _methods.invokeMethod<bool>(
        'devRecordOffer',
        <String, Object?>{'value': value, 'km': km, 'minutes': minutes},
      );
      return saved ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Lê a tela por imagem agora (OCR) e devolve as linhas reconhecidas.
  Future<List<String>> ocrNow() async {
    try {
      final raw = await _methods
          .invokeMethod<Map<Object?, Object?>>('ocrNow');
      final lines = raw?['lines'];
      if (lines is List) {
        return lines.map((line) => line.toString()).toList();
      }
    } catch (_) {
      // Serviço desligado ou OCR indisponível.
    }
    return const <String>[];
  }

  Future<void> clear() async {
    try {
      await _methods.invokeMethod<void>('clear');
    } catch (_) {
      // idem
    }
  }

  Stream<ReaderEvent> watch() {
    return _events
        .receiveBroadcastStream()
        .map(ReaderEvent.fromMap)
        .handleError((Object _) {});
  }
}
