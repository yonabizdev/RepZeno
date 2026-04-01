import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/progress_photo.dart';
import '../repositories/progress_photo_repository.dart';

final progressPhotoRepositoryProvider = Provider((ref) => ProgressPhotoRepository());

final progressPhotosProvider = AsyncNotifierProvider<ProgressPhotosNotifier, List<ProgressPhoto>>(() {
  return ProgressPhotosNotifier();
});

class ProgressPhotosNotifier extends AsyncNotifier<List<ProgressPhoto>> {
  @override
  FutureOr<List<ProgressPhoto>> build() async {
    final repository = ref.watch(progressPhotoRepositoryProvider);
    return repository.getPhotos();
  }

  Future<void> addPhoto(ProgressPhoto photo) async {
    final repository = ref.read(progressPhotoRepositoryProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await repository.addPhoto(photo);
      return repository.getPhotos();
    });
  }

  Future<void> deletePhoto(ProgressPhoto photo) async {
    if (photo.id == null) return;
    final repository = ref.read(progressPhotoRepositoryProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await repository.deletePhoto(photo.id!, photo.path);
      return repository.getPhotos();
    });
  }

  Future<void> updatePhotoDate(ProgressPhoto photo, String newDate) async {
    if (photo.id == null) return;
    final repository = ref.read(progressPhotoRepositoryProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await repository.updatePhotoDate(photo.id!, newDate);
      return repository.getPhotos();
    });
  }
}
