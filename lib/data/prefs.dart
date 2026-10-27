import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sobrescrito no `main()` com a instância já carregada.
/// Isso evita estados de "carregando" espalhados pela UI.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider precisa ser sobrescrito no ProviderScope',
  );
});
