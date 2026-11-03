# MyFit Tracker

A personal gym, nutrition and progress tracker for Android, built with Flutter. It works fully offline: no account, no ads, no analytics, no cloud backend. Everything is stored in a local SQLite database on the phone.

The visual design follows `Neon Fitness App UI Collage.png` (dark, charcoal surfaces, neon-green accent). The full product brief is in [`prompt`](prompt).

## Features

**Workouts**
- Weekly planner (Mon–Sun) with any number of training days; each day is a named workout or a rest day.
- Multiple plans: create, rename, duplicate, delete, choose the active one. Sample 3-, 4-, 5- and 6-day plans, clearly labelled as samples.
- Per exercise: sets, rep range (or target seconds), rest time; drag to reorder; copy a day to another weekday.
- Exercise library of 53 exercises with instructions, search (by exercise or muscle name), muscle-group filters and custom exercises (weight × reps, bodyweight, timed, or distance).
- For every exercise: the body part and the specific muscles it builds, split into **main muscles** (grow the most) and **also works** (supporting muscles). Each muscle shows its anatomical name (e.g. *Anterior deltoid*) and what it does. A front/back body diagram highlights them in the library, on the exercise page and in the live session. The exercise page also suggests other exercises for the same main muscle. Custom exercises use a muscle picker.
- Live session: editable weight/reps per set, tick sets off (tap again to undo), add/remove sets, skip/replace/remove exercises, “last time” values, and new sets pre-filled from the last session (never auto-ticked).
- Rest timer: start, pause, resume, skip, reset, ±15 s. It runs off the wall clock, so it stays correct when the app is backgrounded, and a notification fires when rest ends.
- Unfinished sessions are saved continuously and survive closing the app; discarding asks for confirmation.
- Summary after finishing: completed sets and exercises, duration, external-load volume (bodyweight and timed sets are listed separately), and personal records. A first session never counts as a record.
- Workout history with per-session detail; edit duration or notes, delete a session.

**Nutrition**
- Daily food diary with date navigation, meal categories (Breakfast, Lunch, Evening Snack, Dinner, Other Snacks, plus your own).
- 54 Indian vegetarian foods (roti, rice, dal, rajma, chole, paneer, tofu, soy chunks, milk, curd, oats, poha, upma, idli, dosa, khichdi, fruit, nuts and more), stored per 100 g / 100 ml with defined household servings. Raw, dry and cooked versions are kept separate.
- Add Food: search, category filters, recent foods, saved meals; choose a serving or enter grams; live calorie and macro preview.
- Calories, protein, carbs and fat against your targets, with “remaining” or “over by” (never negative remaining). Missing fibre data is shown as missing, not as zero.
- Saved meals/recipes with dynamic totals; log one with a number of servings.
- Every diary entry stores a snapshot of its values, so correcting a food or editing a saved meal never changes past days.
- Custom foods and corrections to any food, with a source field and an “estimate” flag.
- Water tracking: quick glass, custom amount, undo, optional daily target.

**Progress**
- Body weight: one entry per day, edit/delete, trend chart (7/30/90 days/all), change over the period, 7-day average shown separately from the latest value. Missing days are never filled in.
- Strength: per-exercise charts of heaviest set, estimated 1RM, volume, reps or time; personal bests; sessions list.
- Calories over the last 7 days against target; workout consistency counts.
- Body measurements (chest, waist, hips, arms, thighs, calves, shoulders, neck, or custom) with history charts.

**Personalisation and data**
- First-launch setup (only the name is required).
- Profile & goals: calorie and macro targets estimated with Mifflin–St Jeor, with the working shown; editable by hand. Targets only change when you change them.
- Dark (default), light or system theme; kg/lb, cm/ft-in, ml/fl oz. Values are always stored in kg, cm and ml.
- Optional local reminders: workout (training days of the active plan only), meal logging, water (every N hours in a window), weigh-in.
- JSON backup export and restore (validated first, applied in one transaction).
- Reset all data, with two confirmations.

## Technology

| Area | Choice |
|---|---|
| Framework | Flutter (stable 3.47), Dart 3.13 |
| State | Riverpod 3 (`Notifier`, `AsyncNotifier`, `FutureProvider`) |
| Database | SQLite via `sqflite` with versioned migrations |
| Navigation | `go_router` with `StatefulShellRoute` (each tab keeps its own back stack) |
| Charts | `fl_chart` |
| Notifications | `flutter_local_notifications`, `timezone`, `flutter_timezone` |
| Backup files | `file_picker` (Android system file dialogs) |
| Tests | `flutter_test`, `sqflite_common_ffi` (real SQLite in tests) |

Decisions:
- **sqflite instead of Drift.** The project already used sqflite, and plain SQL keeps migrations explicit without a code-generation step.
- **Settings live in the database, not shared_preferences,** so backup and restore include them.
- **No exercise photos.** The body diagram is drawn in code, so a missing image can never break a screen.

## Project structure

```
lib/
  main.dart                 Opens the database, loads settings, starts the app
  app.dart                  MaterialApp, theme, app lifecycle (date rollover, rest-timer alert)
  core/
    database/               Schema, migrations, first-launch seeding
    routing/                Routes and the bottom-navigation shell
    services/               Local notifications
    theme/                  Colour palette and Material theme (dark + light)
    utils/                  Dates, unit conversion, number formatting/validation
    widgets/                Cards, rings, dialogs, empty/error/loading states, inputs
  features/
    onboarding/  dashboard/  profile/  exercises/  workout/  nutrition/
    water/  progress/  reminders/  settings/  backup/
assets/data/
  exercises.json            Exercise library: instructions, main and supporting muscles
  foods.json                Food database with sources and servings
test/
  unit/                     Calculations: nutrition, units, targets, workout, activity, rest timer
  database/                 Repositories, migrations, persistence, backup
  widget/                   App flows on a 360 × 780 phone screen
android/                    Android project (app id com.saranshjais.myfittracker)
```

Business logic lives outside widgets: nutrition maths in `features/nutrition/nutrition_models.dart`, workout maths in `features/workout/workout_calculations.dart`, targets in `features/profile/target_calculator.dart`, and database access in the `*_repository.dart` files.

## Prerequisites

- Flutter SDK (stable channel, 3.47 or newer) with Dart 3.13+
- Android SDK (API 36) and a JDK 17 (the one bundled with Android Studio works)
- An Android phone with USB debugging, or an emulator

Check with `flutter doctor`.

## Install and run

```bash
flutter pub get
flutter run            # with a phone or emulator connected
```

## Tests and checks

```bash
dart format lib test   # line width 120 is set in analysis_options.yaml
flutter analyze
flutter test           # 100 tests: unit, database and widget
```

The database tests run real SQLite through `sqflite_common_ffi`, so no device is needed.

## Building the APK

```bash
flutter build apk --debug
# → build/app/outputs/flutter-apk/app-debug.apk

flutter build apk --release
# → build/app/outputs/flutter-apk/app-release.apk  (~57 MB, all CPU types)

flutter build apk --release --split-per-abi
# → smaller per-CPU APKs; most phones need app-arm64-v8a-release.apk
```

### Release signing

Without signing set up, release builds are signed with the debug key. That's fine for installing on your own phone, but **not valid for the Play Store**. To sign properly:

1. Create a keystore (keep it and its passwords safe and private):
   ```bash
   keytool -genkey -v -keystore ~/myfit-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias myfit
   ```
2. Create `android/key.properties` (already git-ignored):
   ```properties
   storePassword=...
   keyPassword=...
   keyAlias=myfit
   storeFile=C:/Users/you/myfit-release.jks
   ```
3. Run `flutter build apk --release` (or `flutter build appbundle` for the Play Store).

Never commit the keystore or `key.properties`.

### Troubleshooting

- **`Could not close incremental caches` during a Kotlin compile on Windows.** This happens when the project and the pub cache are on different drives. `android/gradle.properties` sets `kotlin.incremental=false` to avoid it.

## Database

SQLite file `myfit_tracker.db`, schema version 3, foreign keys on. Tables:

| Table | Purpose |
|---|---|
| `app_settings` | Theme, units, default rest, glass size, onboarding flag (single row) |
| `user_profile` | Name, age, sex, height, goal, activity, targets (single row) |
| `exercises` | Library; `target_muscles` / `assist_muscles` (muscle ids), `is_custom`, `is_archived` (referenced exercises are archived, never deleted) |
| `workout_plans`, `workout_plan_days`, `planned_exercises` | Plans → 7 weekdays → ordered exercises with sets/reps/rest |
| `workout_sessions`, `session_exercises`, `set_logs` | Logged workouts; the session name is a snapshot, so renaming a plan doesn't rewrite history |
| `food_items`, `food_servings` | Foods per 100 g/ml with source and estimate flag; household servings |
| `saved_meals`, `saved_meal_items` | Reusable meals (recipes) |
| `food_logs` | Diary entries with a nutrient snapshot (and an ingredient snapshot for meals) |
| `meal_categories` | Default and custom meal names |
| `water_logs`, `body_weight_logs` (one per date), `body_measurements` (cm) | Tracking |
| `reminder_settings` | Reminder on/off, time, water interval |

Dates are stored as local `YYYY-MM-DD` keys, so entries stay on the day they were logged; timestamps are UTC ISO-8601.

**Migrations** run in one transaction, schema steps first and then data backfills:
- **v1 → v2** (from the original prototype: `exercises` and `completed`). Existing exercises keep their ids and get instructions filled in, custom ones are flagged, and each date in `completed` becomes a completed session labelled “Imported from an earlier app version”.
- **v2 → v3.** Adds `target_muscles` and `assist_muscles` to `exercises` and fills them in for the bundled exercises; custom exercises are left untouched. Restoring a backup made before v3 fills them in the same way.

Add future changes as a new `if (from < 4)` step in `AppDatabase.open`. The muscle list lives in `lib/features/exercises/muscles.dart`; its ids are stored in the database, so never rename them.

## Backup and restore

More › Backup & Restore.
- **Export** writes one JSON file (`myfit-backup-YYYY-MM-DD.json`) through the Android save dialog. It contains every table: profile, settings, plans, workouts and sets, food diary, saved meals, foods (including custom ones), weight, measurements, water and reminders, plus a format version and schema version.
- **Restore** validates the file first (format, versions, every table present, value types). It then replaces all data inside a single transaction. If anything fails, including records that don't fit together, the transaction is rolled back and your current data is untouched.

The app does **not** back up to any cloud, and Android auto-backup is disabled for privacy. Uninstalling deletes the data, so export regularly.

## Nutrition data: sources and limits

Each food records its source (shown when you add it, and in the food database):
- **USDA FoodData Central (SR Legacy)**, public domain: single ingredients (rice, oats, milk products, fruit, nuts, pulses, oils). Values are rounded.
- **Typical Indian label values**: paneer, low-fat paneer, toned/full-cream milk, soy chunks. Brands differ, so check your pack.
- **Home-recipe estimates**: roti, dal, rajma, chole, poha, upma, idli, dosa, khichdi, sabzi and other dishes. Real values depend on oil, water and ingredients.

Household servings (a “bowl”, a “medium roti”) are estimates and are labelled as such; weigh food for accuracy. Totals are approximate. You can correct any food, but corrections affect future entries only.

## How numbers are calculated

- **Food:** nutrient per 100 g × grams ÷ 100. A serving is converted to its grams first. A meal is multiplied by its number of servings exactly once.
- **Remaining:** target − consumed; if over, the excess is shown instead.
- **Calorie target (estimate):** Mifflin–St Jeor BMR (men `10w + 6.25h − 5a + 5`, women `… − 161`) × activity multiplier (1.2–1.9), then a conservative goal adjustment: muscle gain +10% (max 350 kcal), lean gain/strength +5% (max 200), fat loss −20% (max 500, never below max(1,200 kcal, BMR)), recomposition/general fitness at maintenance. Protein 1.4–2.0 g/kg by goal, fat ~25% of calories, carbs the rest.
- **Volume:** Σ weight × reps over completed sets with external load.
- **Estimated 1RM:** Epley, weight × (1 + reps ÷ 30), only for 1–12 reps, always labelled as an estimate.

None of this is medical advice.

## Known limitations

- No exercise photos or videos; a simplified body diagram shows the muscles instead.
- The food database is a starter set of 54 items; add your own for anything else.
- Without the “precise alarms” permission (More › Reminders), Android may delay the rest-timer notification by up to a minute. Reminders use inexact scheduling by design.
- Session duration is the time from start to finish; if you leave a session open, fix it from the summary menu.
- Android only. There is no iOS project, and the UI text is English only.
- No cloud sync; backups are manual files.

## Future improvements

- Bundled, properly licensed exercise illustrations.
- Larger food database (for example, licensed IFCT 2017 data) and a quick "add calories only" entry for meals eaten out.
- Weekly report screen and suggested target adjustments based on several weeks of weight trend.
- Plate calculator and warm-up set suggestions.
- Optional encrypted cloud backup.

## Manual testing checklist

1. Fresh install → setup screens → finish → Home shows your name, today's planned workout and your targets.
2. Home › Start workout → enter weight/reps → tick a set → rest timer starts → background the app → notification when rest ends.
3. Add a set, remove a set (swipe left), skip and replace an exercise; close the app mid-session and reopen it, and the session is still there.
4. Finish → summary shows sets, volume, duration; History lists it; Progress › Strength shows the exercise.
5. Diet › + on Breakfast → search “dal” → pick a serving → Add → totals and rings update; edit the entry's amount; delete it.
6. Create a saved meal → Add to Today → edit the saved meal → the day's entry is unchanged.
7. Record weight on two dates → Progress chart and change appear; edit and delete an entry.
8. Switch units to lb/ft-in → values convert for display; switch back → nothing has drifted.
9. Switch the theme to Light and restart the app → still light.
10. Export a backup → reset all data → restore the backup → everything is back.
11. Turn on reminders → allow notifications → reminders arrive at the chosen times.
