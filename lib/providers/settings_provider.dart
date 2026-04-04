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
    final prefs = ref.read(sharedPreferencesProvider);
    state = !state;
    prefs.setBool(_key, state);
  }
}

final sortSetsAscendingProvider = NotifierProvider<SortSetsNotifier, bool>(() {
  return SortSetsNotifier();
});

class TransformationTipNotifier extends Notifier<bool> {
  static const _key = 'transformation_tip_dismissed';

  @override
  bool build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return prefs.getBool(_key) ?? false;
  }

  void dismiss() {
    final prefs = ref.read(sharedPreferencesProvider);
    state = true;
    prefs.setBool(_key, true);
  }
}

final transformationTipDismissedProvider = NotifierProvider<TransformationTipNotifier, bool>(() {
  return TransformationTipNotifier();
});

class CameraTipNotifier extends Notifier<bool> {
  static const _key = 'camera_tip_dismissed';

  @override
  bool build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return prefs.getBool(_key) ?? false;
  }

  void dismiss() {
    final prefs = ref.read(sharedPreferencesProvider);
    state = true;
    prefs.setBool(_key, true);
  }
}

final cameraTipDismissedProvider = NotifierProvider<CameraTipNotifier, bool>(() {
  return CameraTipNotifier();
});
