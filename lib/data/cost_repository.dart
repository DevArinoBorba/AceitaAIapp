import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/entities/cost_profile.dart';
import 'goals_repository.dart';
import 'prefs.dart';

/// Guarda o perfil de custos do veículo (tela "Meu custo").
///
/// O perfil não é só uma planilha: quando está preenchido, o custo por km
/// calculado vira o número que o card usa para dizer o lucro de cada oferta.
class CostRepository {
  CostRepository(this._prefs);

  static const _key = 'cost_profile_v1';

  final SharedPreferences _prefs;

  /// O motorista já salvou um perfil? Sem isso, os valores de referência
  /// aparecem na tela mas não valem no card.
  bool get hasSaved => _prefs.containsKey(_key);

  CostProfile load() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const CostProfile();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return CostProfile.fromJson(Map<String, dynamic>.from(decoded));
      }
    } on FormatException {
      // dado corrompido: cai no default
    }
    return const CostProfile();
  }

  Future<void> save(CostProfile profile) =>
      _prefs.setString(_key, jsonEncode(profile.toJson()));
}

final costRepositoryProvider = Provider<CostRepository>((ref) {
  return CostRepository(ref.watch(sharedPreferencesProvider));
});

final costProfileProvider =
    NotifierProvider<CostProfileNotifier, CostProfile>(CostProfileNotifier.new);

class CostProfileNotifier extends Notifier<CostProfile> {
  @override
  CostProfile build() => ref.watch(costRepositoryProvider).load();

  /// Atualiza a tela sem gravar (enquanto o motorista digita).
  void preview(CostProfile profile) => state = profile;

  /// Grava e leva o custo por km para as metas — é esse número que o card usa.
  Future<void> commit() async {
    final profile = state;
    await ref.read(costRepositoryProvider).save(profile);
    // O perfil passou a existir: o selo "no card" e a tela de Metas mudam.
    ref.read(costSavedProvider.notifier).markSaved();
    if (!profile.isComplete) return;

    final goals = ref.read(goalsProvider);
    if ((goals.costPerKm - profile.totalPerKm).abs() < 0.0001) return;
    await ref
        .read(goalsProvider.notifier)
        .update(goals.copyWith(costPerKm: profile.totalPerKm));
  }

  Future<void> update(CostProfile profile) async {
    state = profile;
    await commit();
  }

  /// No start do app: se existe um perfil salvo, garante que as metas (e o
  /// card) estejam com o custo calculado a partir dele.
  Future<void> applyToGoals() async {
    if (!ref.read(costRepositoryProvider).hasSaved) return;
    await commit();
  }

  /// Volta para os valores de referência.
  Future<void> reset() => update(const CostProfile());
}

/// Já existe um perfil salvo? Começa lendo o disco e vira `true` no primeiro
/// save — evita invalidar provider de dentro do notifier.
final costSavedProvider =
    NotifierProvider<CostSavedNotifier, bool>(CostSavedNotifier.new);

class CostSavedNotifier extends Notifier<bool> {
  @override
  bool build() => ref.watch(costRepositoryProvider).hasSaved;

  void markSaved() => state = true;
}

/// Aviso de que o perfil está preenchido e salvo (para a tela de Metas e o
/// selo "no card").
final hasCostProfileProvider = Provider<bool>((ref) {
  final saved = ref.watch(costSavedProvider);
  return saved && ref.watch(costProfileProvider).isComplete;
});
