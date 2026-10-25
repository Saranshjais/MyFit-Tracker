import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

const green = Color(0xff24e88a);
const background = Color(0xff0e1113);
const surface = Color(0xff1a2024);
const muted = Color(0xffa0aaa7);
const panel = surface;

final appProvider = ChangeNotifierProvider<AppModel>(
  (ref) => AppModel()..load(),
);

class Exercise {
  Exercise(this.id, this.name, this.muscle, this.equipment);
  final int id;
  final String name;
  final String muscle;
  final String equipment;
}

class AppModel extends ChangeNotifier {
  final Store store = Store();
  bool ready = false;
  int tab = 0;
  List<Exercise> exercises = <Exercise>[];
  Set<int> completed = <int>{};

  Future<void> load() async {
    exercises = await store.exercises();
    completed = await store.completed();
    ready = true;
    notifyListeners();
  }

  void setTab(int value) {
    tab = value;
    notifyListeners();
  }

  Future<void> choose(Exercise exercise) async {
    await store.mark(exercise.id);
    completed = <int>{...completed, exercise.id};
    notifyListeners();
  }

  Future<void> addCustom(String name, String muscle) async {
    await store.add(name, muscle);
    exercises = await store.exercises();
    notifyListeners();
  }
}

class Store {
  Database? _database;
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await openDatabase(
      join(await getDatabasesPath(), 'myfit_tracker.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE exercises(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, muscle TEXT, equipment TEXT)',
        );
        await db.execute(
          'CREATE TABLE completed(exerciseId INTEGER, date TEXT, UNIQUE(exerciseId,date))',
        );
        for (final item in initialExercises) {
          await db.insert('exercises', item);
        }
      },
    );
    return _database!;
  }

  Future<List<Exercise>> exercises() async {
    final rows = await (await database).query('exercises', orderBy: 'name');
    return rows
        .map(
          (row) => Exercise(
            row['id'] as int,
            row['name'] as String,
            row['muscle'] as String,
            row['equipment'] as String,
          ),
        )
        .toList();
  }

  Future<Set<int>> completed() async {
    final date = DateTime.now().toIso8601String().substring(0, 10);
    final rows = await (await database).query(
      'completed',
      where: 'date=?',
      whereArgs: <Object>[date],
    );
    return rows.map((row) => row['exerciseId'] as int).toSet();
  }

  Future<void> mark(int id) async {
    final date = DateTime.now().toIso8601String().substring(0, 10);
    await (await database).insert('completed', <String, Object>{
      'exerciseId': id,
      'date': date,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> add(String name, String muscle) async {
    await (await database).insert('exercises', <String, Object>{
      'name': name,
      'muscle': muscle,
      'equipment': 'Custom',
    });
  }
}

const initialExercises = <Map<String, Object>>[
  <String, Object>{
    'name': 'Bench Press',
    'muscle': 'Chest',
    'equipment': 'Barbell',
  },
  <String, Object>{
    'name': 'Incline Dumbbell Press',
    'muscle': 'Chest',
    'equipment': 'Dumbbell',
  },
  <String, Object>{
    'name': 'Chest Fly',
    'muscle': 'Chest',
    'equipment': 'Cable',
  },
  <String, Object>{
    'name': 'Push-up',
    'muscle': 'Chest',
    'equipment': 'Bodyweight',
  },
  <String, Object>{
    'name': 'Lat Pulldown',
    'muscle': 'Back',
    'equipment': 'Cable',
  },
  <String, Object>{'name': 'Squat', 'muscle': 'Legs', 'equipment': 'Barbell'},
  <String, Object>{
    'name': 'Shoulder Press',
    'muscle': 'Shoulders',
    'equipment': 'Dumbbell',
  },
  <String, Object>{
    'name': 'Biceps Curl',
    'muscle': 'Arms',
    'equipment': 'Dumbbell',
  },
  <String, Object>{
    'name': 'Plank',
    'muscle': 'Core',
    'equipment': 'Bodyweight',
  },
];

void main() {
  runApp(const ProviderScope(child: MyFitApp()));
}

class MyFitApp extends StatelessWidget {
  const MyFitApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(primary: green, surface: surface),
    ),
    home: const Shell(),
  );
}

class MyApp extends MyFitApp {
  const MyApp({super.key});
}

class Shell extends ConsumerWidget {
  const Shell({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final model = ref.watch(appProvider);
    if (!model.ready)
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: green)),
      );
    final pages = <Widget>[
      const HomePage(),
      const WorkoutPage(),
      const DietPage(),
      const ProgressPage(),
      const MorePage(),
    ];
    return Scaffold(
      body: SafeArea(child: pages[model.tab]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: model.tab,
        onDestinationSelected: ref.read(appProvider).setTab,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.fitness_center),
            label: 'Workout',
          ),
          NavigationDestination(icon: Icon(Icons.restaurant), label: 'Diet'),
          NavigationDestination(
            icon: Icon(Icons.show_chart),
            label: 'Progress',
          ),
          NavigationDestination(icon: Icon(Icons.more_horiz), label: 'More'),
        ],
      ),
    );
  }
}

class HomePage extends ConsumerWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final model = ref.watch(appProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        const Text(
          'SUNDAY, 25 OCTOBER',
          style: TextStyle(color: muted, fontSize: 10, letterSpacing: 1),
        ),
        const SizedBox(height: 7),
        const Text(
          'Hi Saransh 👋',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const Text(
          'Stay consistent, stronger everyday!',
          style: TextStyle(color: muted, fontSize: 11),
        ),
        const SizedBox(height: 18),
        CardBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Small('TODAY’S FOCUS'),
              const SizedBox(height: 8),
              const Text(
                'Chest & Triceps',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Text(
                'Strength · 5 exercises · 45 min',
                style: TextStyle(color: muted, fontSize: 12),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SessionPage()),
                ),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Workout'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: Metric(
                title: 'CALORIES',
                value: '1,850',
                sub: '/ 2,500 kcal',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Metric(
                title: 'WORKOUTS',
                value: '${model.completed.length}',
                sub: 'completed today',
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const Text(
          'Quick actions',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Row(
          children: const <Widget>[
            Expanded(
              child: ActionBox(icon: Icons.restaurant, label: 'Log Food'),
            ),
            SizedBox(width: 8),
            Expanded(
              child: ActionBox(icon: Icons.water_drop, label: 'Log Water'),
            ),
            SizedBox(width: 8),
            Expanded(
              child: ActionBox(icon: Icons.monitor_weight, label: 'Weight'),
            ),
          ],
        ),
      ],
    );
  }
}

class WorkoutPage extends ConsumerStatefulWidget {
  const WorkoutPage({super.key});
  @override
  ConsumerState<WorkoutPage> createState() => WorkoutState();
}

class WorkoutState extends ConsumerState<WorkoutPage> {
  String filter = 'All';
  String search = '';
  @override
  Widget build(BuildContext context) {
    final model = ref.watch(appProvider);
    final items = model.exercises
        .where(
          (e) =>
              (filter == 'All' || e.muscle == filter) &&
              e.name.toLowerCase().contains(search.toLowerCase()),
        )
        .toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        const Small('TRAINING PLAN'),
        const SizedBox(height: 7),
        const Text(
          'Make it count.',
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
        ),
        const Text(
          'Choose what you trained today.',
          style: TextStyle(color: muted, fontSize: 12),
        ),
        const SizedBox(height: 15),
        Row(
          children: <Widget>[
            Expanded(
              child: FilledButton(
                onPressed: () {},
                child: const Text('Week Plan'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () {},
                child: const Text('Exercise Library'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        const Text(
          'Exercises completed today',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        model.completed.isEmpty
            ? const CardBox(
                child: Text(
                  'Select the exercises you completed below.',
                  style: TextStyle(color: muted, fontSize: 11),
                ),
              )
            : CardBox(
                child: Wrap(
                  spacing: 6,
                  children: model.exercises
                      .where((e) => model.completed.contains(e.id))
                      .map(
                        (e) => Chip(
                          label: Text(e.name),
                          backgroundColor: const Color(0xff153b2c),
                        ),
                      )
                      .toList(),
                ),
              ),
        const SizedBox(height: 14),
        TextField(
          onChanged: (v) => setState(() => search = v),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Search exercises',
          ),
        ),
        const SizedBox(height: 9),
        Wrap(
          spacing: 5,
          children:
              <String>[
                    'All',
                    'Chest',
                    'Back',
                    'Shoulders',
                    'Arms',
                    'Legs',
                    'Core',
                  ]
                  .map(
                    (item) => ChoiceChip(
                      label: Text(item),
                      selected: filter == item,
                      selectedColor: green,
                      onSelected: (_) => setState(() => filter = item),
                    ),
                  )
                  .toList(),
        ),
        const SizedBox(height: 10),
        for (final item in items)
          ExerciseTile(
            item: item,
            selected: model.completed.contains(item.id),
            onAdd: () => ref.read(appProvider).choose(item),
          ),
        OutlinedButton.icon(
          onPressed: () => addCustom(context),
          icon: const Icon(Icons.add),
          label: const Text('Add custom exercise'),
        ),
      ],
    );
  }

  Future<void> addCustom(BuildContext context) async {
    final name = TextEditingController();
    String muscle = 'Chest';
    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, set) => AlertDialog(
          title: const Text('Add custom exercise'),
          content: TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Exercise name'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (name.text.trim().isNotEmpty)
                  ref.read(appProvider).addCustom(name.text.trim(), muscle);
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}

class SessionPage extends StatelessWidget {
  const SessionPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Workout Session')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: const <Widget>[
        Small('CHEST & TRICEPS'),
        SizedBox(height: 8),
        Text(
          'Bench Press',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        Text('Exercise 1 of 5', style: TextStyle(color: muted, fontSize: 12)),
        SizedBox(height: 16),
        CardBox(
          child: Column(
            children: <Widget>[
              Text('Set     Weight       Reps'),
              SizedBox(height: 15),
              TextField(
                decoration: InputDecoration(
                  hintText: '1      20 kg        12 reps',
                ),
              ),
              SizedBox(height: 10),
              TextField(
                decoration: InputDecoration(
                  hintText: '2      25 kg        10 reps',
                ),
              ),
              SizedBox(height: 10),
              TextField(
                decoration: InputDecoration(
                  hintText: '3      25 kg        8 reps',
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12),
        Text('REST TIMER', style: TextStyle(color: muted, fontSize: 10)),
        Text(
          '01:30',
          style: TextStyle(
            color: green,
            fontSize: 25,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

class DietPage extends StatelessWidget {
  const DietPage({super.key});
  @override
  Widget build(BuildContext context) => const SimplePage(
    title: 'Diet / Nutrition',
    kicker: 'SUNDAY, 25 OCTOBER',
    body: <Widget>[
      Text('1,850 / 2,500 kcal', style: TextStyle(color: green, fontSize: 24)),
      SizedBox(height: 18),
      Text('Breakfast   450 kcal'),
      Text('Lunch        620 kcal'),
      Text('Dinner       520 kcal'),
    ],
  );
}

class ProgressPage extends StatelessWidget {
  const ProgressPage({super.key});
  @override
  Widget build(BuildContext context) => const SimplePage(
    title: 'Progress',
    kicker: 'YOUR JOURNEY',
    body: <Widget>[
      Text(
        'Body weight  64.2 kg',
        style: TextStyle(color: green, fontSize: 22),
      ),
      SizedBox(height: 18),
      Text('Strength and weight history'),
    ],
  );
}

class MorePage extends StatelessWidget {
  const MorePage({super.key});
  @override
  Widget build(BuildContext context) => const SimplePage(
    title: 'Settings & More',
    kicker: 'PERSONALIZE',
    body: <Widget>[
      Text('Workout Plan'),
      Text('My Meals'),
      Text('Food Database'),
      Text('Reminders'),
      Text('Backup & Restore'),
    ],
  );
}

class SimplePage extends StatelessWidget {
  const SimplePage({
    super.key,
    required this.title,
    required this.kicker,
    required this.body,
  });
  final String title;
  final String kicker;
  final List<Widget> body;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: <Widget>[
      Small(kicker),
      const SizedBox(height: 7),
      Text(
        title,
        style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 18),
      CardBox(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: body
              .map(
                (w) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: w,
                ),
              )
              .toList(),
        ),
      ),
    ],
  );
}

class CardBox extends StatelessWidget {
  const CardBox({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: panel,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xff2a3236)),
    ),
    child: child,
  );
}

class Small extends StatelessWidget {
  const Small(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(color: muted, fontSize: 10, letterSpacing: 1.1),
  );
}

class Metric extends StatelessWidget {
  const Metric({
    super.key,
    required this.title,
    required this.value,
    required this.sub,
  });
  final String title;
  final String value;
  final String sub;
  @override
  Widget build(BuildContext context) => CardBox(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Small(title),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: green,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(sub, style: const TextStyle(color: muted, fontSize: 10)),
      ],
    ),
  );
}

class ActionBox extends StatelessWidget {
  const ActionBox({super.key, required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => CardBox(
    child: Column(
      children: <Widget>[
        Icon(icon, color: green),
        const SizedBox(height: 5),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    ),
  );
}

class ExerciseTile extends StatelessWidget {
  const ExerciseTile({
    super.key,
    required this.item,
    required this.selected,
    required this.onAdd,
  });
  final Exercise item;
  final bool selected;
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: CardBox(
      child: Row(
        children: <Widget>[
          const Icon(Icons.fitness_center, color: green),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '${item.equipment} · ${item.muscle}',
                  style: const TextStyle(color: muted, fontSize: 10),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: selected ? null : onAdd,
            icon: Icon(
              selected ? Icons.check_circle : Icons.add_circle,
              color: selected ? green : muted,
            ),
          ),
        ],
      ),
    ),
  );
}
