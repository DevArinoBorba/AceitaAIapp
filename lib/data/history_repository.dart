import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/entities/goals.dart';
import '../domain/entities/offer.dart';
import '../domain/entities/verdict.dart';
import '../domain/services/earnings_engine.dart';
import 'goals_repository.dart';
import 'prefs.dart';

/// Persistência simples (JSON em SharedPreferences).
///
/// No GigU isso é Realm com sync incremental (`CdgSyncableResultModel` + 
/// `CdgSyncWorker`). Aqui o objetivo é o mesmo contrato de dados, com o
/// mínimo de infraestrutura: quando entrar o backend, troca-se só o
/// repositório por um que também envia para a API.
class HistoryRepository {
  HistoryRepository(this._prefs);

  static const _key = 'history_v1';
  static const maxEntries = 300;

  final SharedPreferences _prefs;

  List<OfferVerdict> load() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const <OfferVerdict>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <OfferVerdict>[];
      final result = <OfferVerdict>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final offerRaw = map['offer'];
        final goalsRaw = map['goals'];
        if (offerRaw is! Map || goalsRaw is! Map) continue;
        final engine = EarningsEngine(
          Goals.fromJson(Map<String, dynamic>.from(goalsRaw)),
        );
        final verdict =
            engine.evaluate(Offer.fromJson(Map<String, dynamic>.from(offerRaw)));
        // A aceitação é gravada depois, pelo serviço de acessibilidade (a
        // tela seguinte do app de corrida é quem responde).
        final accepted = map['accepted'];
        result.add(
          accepted is bool ? verdict.copyWith(accepted: accepted) : verdict,
        );
      }
      return result;
    } on FormatException {
      return const <OfferVerdict>[];
    }
  }

  Future<void> save(List<OfferVerdict> verdicts) {
    final data = verdicts.take(maxEntries).map((v) => v.toJson()).toList();
    return _prefs.setString(_key, jsonEncode(data));
  }

  /// Relê o arquivo do zero.
  ///
  /// O serviço de acessibilidade grava ofertas no mesmo arquivo, com o app
  /// fechado. O `SharedPreferences` guarda tudo em memória: sem este reload o
  /// app continuaria vendo o histórico de quando abriu.
  Future<void> reload() => _prefs.reload();
}

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  return HistoryRepository(ref.watch(sharedPreferencesProvider));
});

final historyProvider =
    NotifierProvider<HistoryNotifier, List<OfferVerdict>>(HistoryNotifier.new);

class HistoryNotifier extends Notifier<List<OfferVerdict>> {
  @override
  List<OfferVerdict> build() => ref.watch(historyRepositoryProvider).load();

  HistoryRepository get _repository => ref.read(historyRepositoryProvider);

  /// Traz o que o serviço de acessibilidade gravou enquanto o app estava fora.
  Future<void> reload() async {
    await _repository.reload();
    state = _repository.load();
  }

  Future<void> add(OfferVerdict verdict) async {
    // Relê antes de gravar: o serviço pode ter registrado ofertas enquanto o
    // app estava em segundo plano, e gravar por cima as apagaria.
    final disk = _repository
        .load()
        .where((existing) => !_sameOffer(existing, verdict))
        .toList();
    final next = <OfferVerdict>[verdict, ...disk]
        .take(HistoryRepository.maxEntries)
        .toList();
    state = next;
    await _repository.save(next);
  }

  Future<void> removeAt(int index) async {
    if (index < 0 || index >= state.length) return;
    final target = state[index];
    final next = _repository
        .load()
        .where((existing) => !_sameOffer(existing, target))
        .toList();
    state = next;
    await _repository.save(next);
  }

  Future<void> clear() async {
    state = const <OfferVerdict>[];
    await _repository.save(const <OfferVerdict>[]);
  }

  /// Corrige à mão a aceitação de uma oferta.
  ///
  /// A detecção automática olha a tela seguinte do app de corrida, mas pode
  /// ficar "indefinida" (ele fechou o app, trocou de tela, a oferta expirou).
  /// Aqui o motorista conserta — e o conserto vale para o ganho do dia.
  Future<void> setAccepted(OfferVerdict verdict, bool accepted) async {
    final next = _repository.load().map((existing) {
      if (!_sameOffer(existing, verdict)) return existing;
      return existing.copyWith(accepted: accepted);
    }).toList();
    state = next;
    await _repository.save(next);
  }

  /// Mesma oferta = mesmos números no mesmo horário. `evaluatedAt` não serve:
  /// ele é recalculado toda vez que o histórico é lido.
  bool _sameOffer(OfferVerdict a, OfferVerdict b) =>
      a.offer.appId == b.offer.appId &&
      a.offer.value == b.offer.value &&
      a.offer.distanceKm == b.offer.distanceKm &&
      a.offer.timeMin == b.offer.timeMin &&
      a.offer.createdAt == b.offer.createdAt;

  /// Gera ofertas de exemplo para o simulador funcionar antes de existir
  /// integração com o serviço de leitura de tela.
  Future<void> seedDemo() async {
    final engine = EarningsEngine(ref.read(goalsProvider));
    final now = DateTime.now();

    final samples = <Offer>[
      Offer(
        appId: DriverApp.uber.id,
        value: 21.4,
        distanceKm: 8.2,
        timeMin: 22,
        passengerRating: 4.9,
        label: 'UberX',
        createdAt: now.subtract(const Duration(hours: 30)),
      ),
      Offer(
        appId: DriverApp.app99.id,
        value: 11.0,
        distanceKm: 9.5,
        timeMin: 24,
        passengerRating: 4.7,
        label: '99Pop',
        createdAt: now.subtract(const Duration(hours: 28)),
      ),
      Offer(
        appId: DriverApp.uber.id,
        value: 8.5,
        distanceKm: 3.0,
        timeMin: 11,
        passengerRating: 5.0,
        label: 'UberX',
        createdAt: now.subtract(const Duration(hours: 26)),
      ),
      Offer(
        appId: DriverApp.indrive.id,
        value: 30.0,
        distanceKm: 18.0,
        timeMin: 35,
        passengerRating: 4.6,
        label: 'InDrive',
        createdAt: now.subtract(const Duration(hours: 24)),
      ),
      Offer(
        appId: DriverApp.ifood.id,
        value: 6.4,
        distanceKm: 4.8,
        timeMin: 18,
        passengerRating: 4.8,
        label: 'iFood',
        createdAt: now.subtract(const Duration(hours: 20)),
      ),
      Offer(
        appId: DriverApp.app99.id,
        value: 14.0,
        distanceKm: 12.0,
        timeMin: 30,
        passengerRating: 4.5,
        label: '99Pop',
        createdAt: now.subtract(const Duration(hours: 16)),
      ),
      Offer(
        appId: DriverApp.uber.id,
        value: 25.5,
        distanceKm: 7.0,
        timeMin: 19,
        passengerRating: 4.9,
        label: 'UberX',
        createdAt: now.subtract(const Duration(hours: 12)),
      ),
      Offer(
        appId: DriverApp.keeta.id,
        value: 9.9,
        distanceKm: 8.0,
        timeMin: 26,
        passengerRating: 4.7,
        label: 'Keeta',
        createdAt: now.subtract(const Duration(hours: 9)),
      ),
      Offer(
        appId: DriverApp.uber.id,
        value: 4.5,
        distanceKm: 1.8,
        timeMin: 8,
        passengerRating: 5.0,
        label: 'UberX',
        createdAt: now.subtract(const Duration(hours: 6)),
      ),
      Offer(
        appId: DriverApp.app99.id,
        value: 17.0,
        distanceKm: 14.0,
        timeMin: 40,
        passengerRating: 4.8,
        label: '99Pop',
        createdAt: now.subtract(const Duration(hours: 4)),
      ),
      Offer(
        appId: DriverApp.indrive.id,
        value: 12.0,
        distanceKm: 11.0,
        timeMin: 28,
        passengerRating: 4.6,
        label: 'InDrive',
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      Offer(
        appId: DriverApp.uber.id,
        value: 19.8,
        distanceKm: 6.5,
        timeMin: 17,
        passengerRating: 5.0,
        label: 'UberX',
        createdAt: now.subtract(const Duration(minutes: 40)),
      ),
    ];

    final generated = samples.map(engine.evaluate).toList();
    final merged = <OfferVerdict>[...generated, ...state];
    merged.sort(
      (a, b) => b.offer.createdAt.compareTo(a.offer.createdAt),
    );
    final capped = merged.take(HistoryRepository.maxEntries).toList();
    state = capped;
    await _repository.save(capped);
  }
}
