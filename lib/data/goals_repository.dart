import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/entities/goals.dart';
import 'prefs.dart';

class GoalsRepository {
  GoalsRepository(this._prefs);

  static const _key = 'goals_v1';

  final SharedPreferences _prefs;

  Goals load() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const Goals();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Goals.fromJson(Map<String, dynamic>.from(decoded));
      }
    } on FormatException {
      // dado corrompido: cai no default
    }
    return const Goals();
  }

  Future<void> save(Goals goals) =>
      _prefs.setString(_key, jsonEncode(goals.toJson()));
}

final goalsRepositoryProvider = Provider<GoalsRepository>((ref) {
  return GoalsRepository(ref.watch(sharedPreferencesProvider));
});

final goalsProvider = NotifierProvider<GoalsNotifier, Goals>(GoalsNotifier.new);

class GoalsNotifier extends Notifier<Goals> {
  @override
  Goals build() => ref.watch(goalsRepositoryProvider).load();

  /// Atualiza o estado sem gravar (usado enquanto o slider arrasta).
  void preview(Goals goals) => state = goals;

  /// Grava o estado atual.
  Future<void> commit() => ref.read(goalsRepositoryProvider).save(state);

  /// Atualiza e grava.
  Future<void> update(Goals goals) async {
    state = goals;
    await commit();
  }
}
