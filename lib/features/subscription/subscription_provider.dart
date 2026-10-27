import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/prefs.dart';

/// Estado de assinatura.
///
/// No produto final `turbo` vem do RevenueCat (entitlement `Turbo`) e é
/// revalidado no servidor — nunca de uma flag local. Aqui ele é fixo em
/// `false` e existe um "modo PRO (dev)" para você navegar pelas telas
/// bloqueadas enquanto a integração de billing não entra.
class SubscriptionState {
  const SubscriptionState({required this.turbo, required this.devUnlock});

  final bool turbo;
  final bool devUnlock;

  bool get isPro => turbo || devUnlock;

  SubscriptionState copyWith({bool? turbo, bool? devUnlock}) {
    return SubscriptionState(
      turbo: turbo ?? this.turbo,
      devUnlock: devUnlock ?? this.devUnlock,
    );
  }
}

final subscriptionProvider =
    NotifierProvider<SubscriptionNotifier, SubscriptionState>(
  SubscriptionNotifier.new,
);

class SubscriptionNotifier extends Notifier<SubscriptionState> {
  static const _devUnlockKey = 'dev_unlock_v1';

  @override
  SubscriptionState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return SubscriptionState(
      turbo: false,
      devUnlock: prefs.getBool(_devUnlockKey) ?? false,
    );
  }

  Future<void> setDevUnlock(bool value) async {
    state = state.copyWith(devUnlock: value);
    await ref.read(sharedPreferencesProvider).setBool(_devUnlockKey, value);
  }

  /// Ponto de entrada do RevenueCat: chamar quando o entitlement mudar.
  /// O servidor continua sendo a fonte da verdade (ver docs/arquitetura).
  void setTurbo(bool value) {
    state = state.copyWith(turbo: value);
  }
}
