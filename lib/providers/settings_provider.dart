import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences not initialized');
});

class SortSetsNotifier extends Notifier<bool> {
  static const _key = 'sort_sets_ascending';

  @override
  bool build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return prefs.getBool(_key) ?? true;
  }

  void toggle() {
    state = !state;
    ref.read(sharedPreferencesProvider).setBool(_key, state);
  }
}

final sortSetsAscendingProvider = NotifierProvider<SortSetsNotifier, bool>(() {
  return SortSetsNotifier();
});
