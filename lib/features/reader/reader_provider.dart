import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/card_layout.dart';
import '../../domain/entities/goals.dart';
import '../../platform/reader_channel.dart';
class ReaderState {
  const ReaderState({
    required this.status,
    this.dump,
    this.byPackage = const <String, ScreenDump>{},
    this.starting = true,
  });

  final ReaderStatus status;
  final ScreenDump? dump;
  final Map<String, ScreenDump> byPackage;
  final bool starting;

  /// Quantos apps diferentes já mandaram tela.
  int get appCount => byPackage.length;

  ReaderState copyWith({
    ReaderStatus? status,
    ScreenDump? dump,
    Map<String, ScreenDump>? byPackage,
    bool? starting,
  }) {
    return ReaderState(
      status: status ?? this.status,
      dump: dump ?? this.dump,
      byPackage: byPackage ?? this.byPackage,
      starting: starting ?? this.starting,
    );
  }
}

class ReaderController extends StateNotifier<ReaderState> {
  ReaderController(this._channel)
      : super(const ReaderState(status: ReaderStatus.unsupported())) {
    _boot();
  }

  final ReaderChannel _channel;
  StreamSubscription<ReaderEvent>? _subscription;
  Timer? _poll;

  Future<void> _boot() async {
    final status = await _channel.status();
    if (!mounted) return;

    ScreenDump? dump;
    if (status.available) {
      dump = await _channel.lastDump();
      if (!mounted) return;
    }

    state = ReaderState(
      status: status,
      dump: dump,
      byPackage: dump == null
          ? const <String, ScreenDump>{}
          : <String, ScreenDump>{dump.package: dump},
      starting: false,
    );

    if (status.available) _startStreaming();
  }

  void _startStreaming() {
    _subscription ??= _channel.watch().listen(_onEvent);
    // O serviço continua lendo com o app em segundo plano; este poll só
    // garante que, ao voltar, o status reflita o que mudou nas configurações.
    _poll ??= Timer.periodic(const Duration(seconds: 3), (_) => refresh());
  }

  void _onEvent(ReaderEvent event) {
    if (!mounted) return;

    if (event.status != null) {
      state = state.copyWith(status: event.status, starting: false);
    }

    final dump = event.dump;
    if (dump != null) {
      state = state.copyWith(
        dump: dump,
        byPackage: <String, ScreenDump>{...state.byPackage, dump.package: dump},
        starting: false,
      );
    }
  }

  Future<void> refresh() async {
    final status = await _channel.status();
    if (!mounted || !status.available) {
      if (mounted && !status.available) {
        state = state.copyWith(status: status, starting: false);
      }
      return;
    }

    final dump = await _channel.lastDump();
    if (!mounted) return;

    if (dump != null && (state.dump?.hash != dump.hash || state.dump == null)) {
      state = state.copyWith(
        status: status,
        dump: dump,
        byPackage: <String, ScreenDump>{...state.byPackage, dump.package: dump},
        starting: false,
      );
      return;
    }

    state = state.copyWith(status: status, starting: false);
  }

  Future<void> openSettings() async {
    await _channel.openAccessibilitySettings();
  }

  Future<void> openOverlaySettings() async {
    await _channel.openOverlaySettings();
  }

  /// Lista de apps com bateria sem restrição (o que evita o MIUI cortar o
  /// processo no meio do turno).
  Future<void> openBatterySettings() async {
    await _channel.openBatterySettings();
  }

  /// Autostart do MIUI: sem isso o serviço não volta sozinho depois de reiniciar.
  Future<void> openAutoStart() async {
    await _channel.openAutoStart();
  }

  /// Notificações do app nas configurações do Android.
  Future<void> openNotificationSettings() async {
    await _channel.openNotificationSettings();
  }

  /// Mostra o card com uma oferta de exemplo (valor, km e minutos).
  Future<void> previewOfferCard({
    double value = 7.15,
    double km = 2.1,
    int minutes = 9,
  }) async {
    await _channel.devShowOffer(value: value, km: km, minutes: minutes);
  }

  /// Lê a tela por imagem agora e devolve as linhas (para conferência).
  Future<List<String>> testOcr() => _channel.ocrNow();

  /// Grava uma oferta de exemplo no histórico, pelo caminho nativo — serve
  /// para conferir a integração sem depender de uma oferta real na tela.
  Future<bool> recordSampleOffer() => _channel.devRecordOffer();

  Future<void> setCaptureAll(bool enabled) async {
    final status = await _channel.setCaptureAll(enabled: enabled);
    if (!mounted) return;
    state = state.copyWith(status: status);
  }

  /// Pausa/retoma a leitura (mesmo interruptor do balão).
  Future<void> setReadingEnabled(bool enabled) async {
    final status = await _channel.setReadingEnabled(enabled: enabled);
    if (!mounted) return;
    state = state.copyWith(status: status);
  }

  /// Mostra/esconde o balão flutuante.
  Future<void> setBubbleEnabled(bool enabled) async {
    final status = await _channel.setBubbleEnabled(enabled: enabled);
    if (!mounted) return;
    state = state.copyWith(status: status);
  }

  /// Troca o que aparece no card (valor, R$/km, lucro…).
  Future<void> setCardFields(Set<CardField> fields) async {
    final status = await _channel.setCardFields(fields);
    if (!mounted) return;
    state = state.copyWith(status: status);
  }

  /// Troca o tempo que o card fica visível na tela (em segundos).
  Future<void> setCardDuration(int seconds) async {
    final status = await _channel.setCardDuration(seconds);
    if (!mounted) return;
    state = state.copyWith(status: status);
  }

  /// Leva as metas para o nativo. O card é desenhado pelo serviço, com o app
  /// fechado; sem isso ele continuaria calculando com os valores de fábrica.
  Future<void> pushGoals(Goals goals) async {
    await _channel.setGoals(
      minPerKm: goals.minPerKm,
      goodPerKm: goals.goodPerKm,
      minPerHour: goals.minPerHour,
      goodPerHour: goals.goodPerHour,
      minProfitPct: goals.minProfitPct,
      goodProfitPct: goals.goodProfitPct,
      costPerKm: goals.costPerKm,
      minRating: goals.minRating,
      goodRating: goals.goodRating,
    );
  }

  /// O app está na frente: o balão sai de cena.
  Future<void> setAppVisible(bool visible) async {
    await _channel.setAppVisible(visible);
  }

  /// Sincroniza se a assinatura Turbo ou os 14 dias grátis estão ativos no serviço nativo.
  Future<void> setSubscriptionActive(bool active) async {
    await _channel.setSubscriptionActive(active);
  }

  Future<void> clearDumps() async {
    await _channel.clear();
    if (!mounted) return;
    state = state.copyWith(
      dump: null,
      byPackage: const <String, ScreenDump>{},
    );
    await refresh();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _poll?.cancel();
    super.dispose();
  }
}

final readerChannelProvider = Provider<ReaderChannel>((ref) {
  return const ReaderChannel();
});

final readerProvider =
    StateNotifierProvider<ReaderController, ReaderState>((ref) {
  return ReaderController(ref.watch(readerChannelProvider));
});

/// Atalho: o status puro, que é o que a home usa.
final readerStatusOfProvider = Provider<ReaderStatus>((ref) {
  return ref.watch(readerProvider).status;
});
