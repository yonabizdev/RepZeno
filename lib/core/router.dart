import 'package:go_router/go_router.dart';
import '../screens/home_screen.dart';
import '../screens/workout_log_screen.dart';
import '../screens/add_exercise_screen.dart';
import '../screens/muscle_history_screen.dart';
import '../screens/exercise_management_screen.dart';
import '../screens/privacy_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/bodyweight_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/progress_gallery_screen.dart';
import '../screens/comparison_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: '/workout/:date',
      builder: (context, state) {
        final date = state.pathParameters['date']!;
        return WorkoutLogScreen(date: date);
      },
    ),
    GoRoute(
      path: '/add-exercise/:workoutId',
      builder: (context, state) {
        final workoutId = int.parse(state.pathParameters['workoutId']!);
        return AddExerciseScreen(workoutId: workoutId);
      },
    ),
    GoRoute(
      path: '/add-exercise/date/:date',
      builder: (context, state) {
        final date = state.pathParameters['date']!;
        return AddExerciseScreen(date: date);
      },
    ),
    GoRoute(
      path: '/history/:muscleGroupId',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['muscleGroupId']!);
        return MuscleHistoryScreen(muscleGroupId: id);
      },
    ),
    GoRoute(
      path: '/manage-exercises',
      builder: (context, state) => const ExerciseManagementScreen(),
    ),
    GoRoute(
      path: '/privacy',
      builder: (context, state) => const PrivacyScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: '/bodyweight',
      builder: (context, state) => const BodyweightScreen(),
    ),
    GoRoute(
      path: '/reports',
      builder: (context, state) => const ReportsScreen(),
    ),
    GoRoute(
      path: '/progress',
      builder: (context, state) => const ProgressGalleryScreen(),
    ),
    GoRoute(
      path: '/progress/compare',
      builder: (context, state) {
        final pathA = state.uri.queryParameters['pathA']!;
        final dateA = state.uri.queryParameters['dateA']!;
        final pathB = state.uri.queryParameters['pathB']!;
        final dateB = state.uri.queryParameters['dateB']!;
        return ComparisonScreen(
          pathA: pathA,
          dateA: dateA,
          pathB: pathB,
          dateB: dateB,
        );
      },
    ),
  ],
);
