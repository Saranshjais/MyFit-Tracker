import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/notification_service.dart';
import '../settings/app_settings.dart';

enum RestStatus { idle, running, paused, finished }

@immutable
class RestTimerState {
  const RestTimerState({required this.status, required this.totalSeconds, required this.remainingSeconds, this.endsAt});

  final RestStatus status;
  final int totalSeconds;
  final int remainingSeconds;

  /// Wall-clock end time while running. Remaining time is always derived from
  /// it, so the timer stays correct if the app is paused or backgrounded.
  final DateTime? endsAt;

  double get progress => totalSeconds == 0 ? 0 : 1 - remainingSeconds / totalSeconds;

  RestTimerState copyWith({
    RestStatus? status,
    int? totalSeconds,
    int? remainingSeconds,
    DateTime? endsAt,
    bool clearEnd = false,
  }) => RestTimerState(
    status: status ?? this.status,
    totalSeconds: totalSeconds ?? this.totalSeconds,
    remainingSeconds: remainingSeconds ?? this.remainingSeconds,
    endsAt: clearEnd ? null : (endsAt ?? this.endsAt),
  );
}

class RestTimerNotifier extends Notifier<RestTimerState> {
  Timer? _ticker;
  bool _inBackground = false;

  /// Replaceable in tests.
  DateTime Function() clock = DateTime.now;

  static const minSeconds = 5;
  static const maxSeconds = 3600;

  NotificationService get _notifications => ref.read(notificationServiceProvider);

  @override
  RestTimerState build() {
    ref.onDispose(() => _ticker?.cancel());
    final seconds = ref.read(settingsProvider).defaultRestSeconds;
    return RestTimerState(status: RestStatus.idle, totalSeconds: seconds, remainingSeconds: seconds);
  }

  /// Sets the duration for the next rest without starting it.
  void configure(int seconds) {
    if (state.status == RestStatus.running || state.status == RestStatus.paused) return;
    final s = seconds.clamp(minSeconds, maxSeconds);
    state = RestTimerState(status: RestStatus.idle, totalSeconds: s, remainingSeconds: s);
  }

  void start([int? seconds]) {
    final total = (seconds ?? state.totalSeconds).clamp(minSeconds, maxSeconds);
    state = RestTimerState(
      status: RestStatus.running,
      totalSeconds: total,
      remainingSeconds: total,
      endsAt: clock().add(Duration(seconds: total)),
    );
    _startTicker();
    if (_inBackground) _scheduleAlert();
  }

  void pause() {
    if (state.status != RestStatus.running) return;
    _tick();
    if (state.status != RestStatus.running) return;
    _stopTicker();
    _cancelAlert();
    state = state.copyWith(status: RestStatus.paused, clearEnd: true);
  }

  void resume() {
    if (state.status != RestStatus.paused) return;
    state = state.copyWith(
      status: RestStatus.running,
      endsAt: clock().add(Duration(seconds: state.remainingSeconds)),
    );
    _startTicker();
  }

  void skip() => reset();

  void reset() {
    _stopTicker();
    _cancelAlert();
    state = RestTimerState(
      status: RestStatus.idle,
      totalSeconds: state.totalSeconds,
      remainingSeconds: state.totalSeconds,
    );
  }

  /// Adds or removes time (e.g. ±15 s).
  void adjust(int deltaSeconds) {
    final total = (state.totalSeconds + deltaSeconds).clamp(minSeconds, maxSeconds);
    switch (state.status) {
      case RestStatus.running:
        final end = state.endsAt!.add(Duration(seconds: deltaSeconds));
        state = state.copyWith(totalSeconds: total, endsAt: end);
        _tick();
        if (_inBackground) _scheduleAlert();
      case RestStatus.paused:
        state = state.copyWith(
          totalSeconds: total,
          remainingSeconds: (state.remainingSeconds + deltaSeconds).clamp(0, maxSeconds),
        );
      case RestStatus.idle:
      case RestStatus.finished:
        state = RestTimerState(status: RestStatus.idle, totalSeconds: total, remainingSeconds: total);
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _tick() {
    final end = state.endsAt;
    if (state.status != RestStatus.running || end == null) return;
    final remainingMs = end.difference(clock()).inMilliseconds;
    final remaining = math.max(0, (remainingMs / 1000).ceil());
    if (remaining <= 0) {
      _stopTicker();
      state = state.copyWith(status: RestStatus.finished, remainingSeconds: 0, clearEnd: true);
      if (!_inBackground) HapticFeedback.vibrate();
      return;
    }
    if (remaining != state.remainingSeconds) state = state.copyWith(remainingSeconds: remaining);
  }

  /// Called from the app lifecycle observer.
  void onAppPaused() {
    _inBackground = true;
    if (state.status == RestStatus.running) _scheduleAlert();
  }

  void onAppResumed() {
    _inBackground = false;
    _cancelAlert();
    _tick();
  }

  void _scheduleAlert() {
    final end = state.endsAt;
    if (end == null) return;
    _notifications
        .scheduleOnce(id: NotificationIds.restTimer, at: end, title: 'Rest is over', body: 'Time for your next set.')
        .catchError((Object e) => debugPrint('Could not schedule rest alert: $e'));
  }

  void _cancelAlert() {
    _notifications
        .cancel(NotificationIds.restTimer)
        .catchError((Object e) => debugPrint('Could not cancel rest alert: $e'));
  }
}

final restTimerProvider = NotifierProvider<RestTimerNotifier, RestTimerState>(RestTimerNotifier.new);
