import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/prefs.dart';

/// Estado de assinatura e teste grátis de 14 dias.
///
/// Modelo de negócio:
/// - Assim que o motorista abre o app pela primeira vez, inicia automaticamente
///   o período de teste grátis de **14 dias** (`trialDaysTotal = 14`) com todas
///   as funções Turbo liberadas (incluindo leitura de tela, card flutuante,
///   Meu custo, Simulador e Insights).
/// - Após os 14 dias, se não houver assinatura `turbo` ativa (ou `devUnlock`
///   para testes), o app bloqueia os recursos (incluindo a leitura automática
///   de tela e o card flutuante nativo) até que a assinatura seja ativada.
class SubscriptionState {
  const SubscriptionState({
    required this.turbo,
    required this.devUnlock,
    required this.trialStartMs,
  });

  static const int trialDaysTotal = 14;
  static const int _msPerDay = 24 * 60 * 60 * 1000;
  static const int trialDurationMs = trialDaysTotal * _msPerDay;

  final bool turbo;
  final bool devUnlock;
  final int trialStartMs;

  /// Verdadeiro enquanto os 14 dias de teste grátis ainda não expiraram.
  bool get isTrialActive {
    if (trialStartMs <= 0) return false;
    final elapsedMs = DateTime.now().millisecondsSinceEpoch - trialStartMs;
    return elapsedMs < trialDurationMs;
  }

  /// Verdadeiro quando os 14 dias acabaram e o usuário não tem assinatura nem devUnlock.
  bool get isTrialExpired => !turbo && !devUnlock && !isTrialActive;

  /// Quantos dias inteiros restam no teste grátis (de 0 a 14).
  int get trialDaysLeft {
    if (trialStartMs <= 0) return 0;
    final remainingMs =
        trialDurationMs - (DateTime.now().millisecondsSinceEpoch - trialStartMs);
    if (remainingMs <= 0) return 0;
    final days = (remainingMs / _msPerDay).ceil();
    return days.clamp(1, trialDaysTotal);
  }

  /// Libera todos os recursos do app (leitura de tela, card, Meu custo, Simulador, etc.).
  bool get isPro => turbo || devUnlock || isTrialActive;

  /// Rótulo curto para o cabeçalho da Home e tela de Ajustes.
  String get statusBadgeLabel {
    if (turbo) return 'Turbo ativo';
    if (devUnlock) return 'Modo PRO (dev)';
    if (isTrialActive) {
      final d = trialDaysLeft;
      return 'Teste grátis · $d ${d == 1 ? 'dia restante' : 'dias restantes'}';
    }
    return 'Teste encerrado · Assinar Turbo';
  }

  SubscriptionState copyWith({
    bool? turbo,
    bool? devUnlock,
    int? trialStartMs,
  }) {
    return SubscriptionState(
      turbo: turbo ?? this.turbo,
      devUnlock: devUnlock ?? this.devUnlock,
      trialStartMs: trialStartMs ?? this.trialStartMs,
    );
  }
}

final subscriptionProvider =
    NotifierProvider<SubscriptionNotifier, SubscriptionState>(
  SubscriptionNotifier.new,
);

class SubscriptionNotifier extends Notifier<SubscriptionState> {
  static const _devUnlockKey = 'dev_unlock_v1';
  static const trialStartKey = 'trial_start_ms_v1';

  @override
  SubscriptionState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    var trialStart = prefs.getInt(trialStartKey);
    if (trialStart == null || trialStart <= 0) {
      trialStart = DateTime.now().millisecondsSinceEpoch;
      prefs.setInt(trialStartKey, trialStart);
    }
    return SubscriptionState(
      turbo: false,
      devUnlock: prefs.getBool(_devUnlockKey) ?? false,
      trialStartMs: trialStart,
    );
  }

  Future<void> setDevUnlock(bool value) async {
    state = state.copyWith(devUnlock: value);
    await ref.read(sharedPreferencesProvider).setBool(_devUnlockKey, value);
  }

  /// Reinicia os 14 dias de teste grátis a partir de agora (útil para testes).
  Future<void> resetTrial() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    state = state.copyWith(trialStartMs: now);
    await ref.read(sharedPreferencesProvider).setInt(trialStartKey, now);
  }

  /// Simula o fim imediato dos 14 dias de teste (útil para testar o bloqueio).
  Future<void> expireTrialForTest() async {
    final expiredStart = DateTime.now()
        .subtract(const Duration(days: SubscriptionState.trialDaysTotal + 1))
        .millisecondsSinceEpoch;
    state = state.copyWith(trialStartMs: expiredStart, devUnlock: false);
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt(trialStartKey, expiredStart);
    await prefs.setBool(_devUnlockKey, false);
  }

  /// Ponto de entrada do RevenueCat: chamar quando o entitlement mudar.
  void setTurbo(bool value) {
    state = state.copyWith(turbo: value);
  }
}
