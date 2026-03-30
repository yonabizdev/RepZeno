import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile.dart';
import '../models/weight_log.dart';
import '../repositories/profile_repository.dart';

final profileRepositoryProvider = Provider((ref) => ProfileRepository());

class UserProfileNotifier extends AsyncNotifier<UserProfile?> {
  @override
  Future<UserProfile?> build() async {
    return ref.watch(profileRepositoryProvider).getUserProfile();
  }

  Future<void> saveProfile(UserProfile profile) async {
    await ref.read(profileRepositoryProvider).saveUserProfile(profile);
    state = AsyncData(profile);
  }
}

final userProfileProvider = AsyncNotifierProvider<UserProfileNotifier, UserProfile?>(
  () => UserProfileNotifier(),
);

class WeightLogsNotifier extends AsyncNotifier<List<WeightLog>> {
  @override
  Future<List<WeightLog>> build() async {
    return ref.watch(profileRepositoryProvider).getWeightLogs();
  }

  Future<void> addLog(WeightLog log) async {
    await ref.read(profileRepositoryProvider).addWeightLog(log);
    ref.invalidateSelf();
  }

  Future<void> updateLog(WeightLog log) async {
    await ref.read(profileRepositoryProvider).updateWeightLog(log);
    ref.invalidateSelf();
  }

  Future<void> deleteLog(int id) async {
    await ref.read(profileRepositoryProvider).deleteWeightLog(id);
    ref.invalidateSelf();
  }
}

final weightLogsProvider = AsyncNotifierProvider<WeightLogsNotifier, List<WeightLog>>(
  () => WeightLogsNotifier(),
);
