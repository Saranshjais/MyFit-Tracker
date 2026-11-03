import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/backup/backup_screen.dart';
import '../../features/dashboard/home_screen.dart';
import '../../features/exercises/exercise_detail_screen.dart';
import '../../features/exercises/exercise_form_screen.dart';
import '../../features/exercises/exercise_picker_screen.dart';
import '../../features/nutrition/screens/add_food_screen.dart';
import '../../features/nutrition/screens/diet_screen.dart';
import '../../features/nutrition/screens/food_database_screen.dart';
import '../../features/nutrition/screens/food_form_screen.dart';
import '../../features/nutrition/screens/meal_editor_screen.dart';
import '../../features/nutrition/screens/saved_meals_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/progress/measurements_screen.dart';
import '../../features/progress/progress_screen.dart';
import '../../features/progress/weight_history_screen.dart';
import '../../features/reminders/reminders_screen.dart';
import '../../features/settings/about_screen.dart';
import '../../features/settings/app_settings.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/settings/units_screen.dart';
import '../../features/workout/screens/history_screen.dart';
import '../../features/workout/screens/plan_day_editor_screen.dart';
import '../../features/workout/screens/plans_screen.dart';
import '../../features/workout/screens/session_screen.dart';
import '../../features/workout/screens/session_summary_screen.dart';
import '../../features/workout/screens/workout_screen.dart';
import 'app_shell.dart';

int? _intParam(GoRouterState s, String name) => int.tryParse(s.pathParameters[name] ?? '');

final routerProvider = Provider<GoRouter>((ref) {
  final onboarded = ValueNotifier<bool>(ref.read(settingsProvider).onboardingCompleted);
  ref.listen(settingsProvider.select((s) => s.onboardingCompleted), (_, done) => onboarded.value = done);
  ref.onDispose(onboarded.dispose);

  final router = GoRouter(
    initialLocation: '/home',
    refreshListenable: onboarded,
    redirect: (context, state) {
      final atOnboarding = state.matchedLocation == '/onboarding';
      if (!onboarded.value && !atOnboarding) return '/onboarding';
      if (onboarded.value && atOnboarding) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/home', builder: (_, _) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/workout',
                builder: (_, s) => WorkoutScreen(initialTab: s.uri.queryParameters['tab'] == 'library' ? 1 : 0),
                routes: [
                  GoRoute(
                    path: 'day/:dayId',
                    builder: (_, s) => PlanDayEditorScreen(dayId: _intParam(s, 'dayId')!),
                  ),
                  GoRoute(path: 'plans', builder: (_, _) => const PlansScreen()),
                  GoRoute(path: 'exercise/new', builder: (_, _) => const ExerciseFormScreen()),
                  GoRoute(
                    path: 'exercise/:id',
                    builder: (_, s) => ExerciseDetailScreen(exerciseId: _intParam(s, 'id')!),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        builder: (_, s) => ExerciseFormScreen(exerciseId: _intParam(s, 'id')),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'pick-exercise',
                    builder: (_, s) => ExercisePickerScreen(title: s.uri.queryParameters['title'] ?? 'Choose exercise'),
                  ),
                  GoRoute(path: 'session', builder: (_, _) => const SessionScreen()),
                  GoRoute(
                    path: 'history',
                    builder: (_, _) => const HistoryScreen(),
                    routes: [
                      GoRoute(
                        path: ':id',
                        builder: (_, s) => SessionSummaryScreen(
                          sessionId: _intParam(s, 'id')!,
                          justFinished: s.uri.queryParameters['finished'] == '1',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/diet',
                builder: (_, _) => const DietScreen(),
                routes: [
                  GoRoute(
                    path: 'add',
                    builder: (_, s) =>
                        AddFoodScreen(date: s.uri.queryParameters['date'], category: s.uri.queryParameters['meal']),
                  ),
                  GoRoute(path: 'pick-food', builder: (_, _) => const AddFoodScreen(pickOnly: true)),
                  GoRoute(path: 'meals', builder: (_, _) => const SavedMealsScreen()),
                  GoRoute(
                    path: 'meal/new',
                    builder: (_, s) =>
                        MealEditorScreen(date: s.uri.queryParameters['date'], category: s.uri.queryParameters['meal']),
                  ),
                  GoRoute(
                    path: 'meal/:id',
                    builder: (_, s) =>
                        MealEditorScreen(mealId: _intParam(s, 'id'), date: s.uri.queryParameters['date']),
                  ),
                  GoRoute(path: 'foods', builder: (_, _) => const FoodDatabaseScreen()),
                  GoRoute(path: 'foods/new', builder: (_, _) => const FoodFormScreen()),
                  GoRoute(
                    path: 'foods/:id',
                    builder: (_, s) => FoodFormScreen(foodId: _intParam(s, 'id')),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/progress',
                builder: (_, s) => ProgressScreen(
                  initialTab: switch (s.uri.queryParameters['tab']) {
                    'weight' => 1,
                    'strength' => 2,
                    _ => 0,
                  },
                ),
                routes: [
                  GoRoute(path: 'weight', builder: (_, _) => const WeightHistoryScreen()),
                  GoRoute(path: 'measurements', builder: (_, _) => const MeasurementsScreen()),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/more',
                builder: (_, _) => const SettingsScreen(),
                routes: [
                  GoRoute(path: 'profile', builder: (_, _) => const ProfileScreen()),
                  GoRoute(path: 'reminders', builder: (_, _) => const RemindersScreen()),
                  GoRoute(path: 'units', builder: (_, _) => const UnitsScreen()),
                  GoRoute(path: 'backup', builder: (_, _) => const BackupScreen()),
                  GoRoute(path: 'about', builder: (_, _) => const AboutScreen()),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
