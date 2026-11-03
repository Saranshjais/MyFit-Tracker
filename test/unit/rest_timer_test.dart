import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfit_tracker/features/settings/app_settings.dart';
import 'package:myfit_tracker/features/workout/rest_timer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late RestTimerNotifier timer;
  late DateTime now;

  setUp(() {
    container = ProviderContainer(
      overrides: [initialSettingsProvider.overrideWithValue(const AppSettings(defaultRestSeconds: 90))],
    );
    timer = container.read(restTimerProvider.notifier);
    now = DateTime(2026, 11, 3, 18);
    timer.clock = () => now;
  });

  tearDown(() => container.dispose());

  RestTimerState state() => container.read(restTimerProvider);

  test('starts idle with the default duration', () {
    expect(state().status, RestStatus.idle);
    expect(state().remainingSeconds, 90);
  });

  test('pause keeps the remaining time based on the clock', () {
    timer.start(60);
    now = now.add(const Duration(seconds: 25));
    timer.pause();
    expect(state().status, RestStatus.paused);
    expect(state().remainingSeconds, 35);

    // Time passing while paused does not count.
    now = now.add(const Duration(minutes: 5));
    timer.resume();
    now = now.add(const Duration(seconds: 10));
    timer.pause();
    expect(state().remainingSeconds, 25);
  });

  test('finishes when the end time has passed', () {
    timer.start(30);
    now = now.add(const Duration(seconds: 31));
    timer.onAppResumed(); // recomputes from the clock
    expect(state().status, RestStatus.finished);
    expect(state().remainingSeconds, 0);
  });

  test('adjust adds time to a running timer', () {
    timer.start(60);
    timer.adjust(15);
    now = now.add(const Duration(seconds: 10));
    timer.pause();
    expect(state().remainingSeconds, 65);
    expect(state().totalSeconds, 75);
  });

  test('skip and reset return to idle', () {
    timer.start(45);
    timer.skip();
    expect(state().status, RestStatus.idle);
    expect(state().remainingSeconds, 45);
    timer.start();
    timer.reset();
    expect(state().status, RestStatus.idle);
  });

  test('duration is clamped to a sensible range', () {
    timer.configure(1);
    expect(state().totalSeconds, RestTimerNotifier.minSeconds);
    timer.configure(99999);
    expect(state().totalSeconds, RestTimerNotifier.maxSeconds);
  });
}
