import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_palette.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.padding = const EdgeInsets.all(32)});
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: const Center(child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5))),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.onAction,
    this.compact = false,
  });
  final IconData icon;
  final String title;
  final String? message;
  final String? action;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 16 : 40, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 32 : 44, color: p.textMuted),
          const SizedBox(height: 12),
          Text(title, style: t.titleMedium, textAlign: TextAlign.center),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(message!, style: t.bodySmall, textAlign: TextAlign.center),
          ],
          if (action != null) ...[const SizedBox(height: 16), FilledButton(onPressed: onAction, child: Text(action!))],
        ],
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry});
  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: p.error, size: 36),
          const SizedBox(height: 10),
          Text('Something went wrong', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text('$error', style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ],
      ),
    );
  }
}

/// Shows data as soon as any is available, keeping the previous value while
/// a provider reloads so screens do not flash a spinner after every save.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({super.key, required this.value, required this.builder, this.loading, this.onRetry});
  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final Widget? loading;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (value.hasValue) return builder(value.value as T);
    if (value.hasError) return ErrorView(error: value.error!, onRetry: onRetry);
    return loading ?? const LoadingView();
  }
}

void showSnack(BuildContext context, String message, {SnackBarAction? action}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), action: action, duration: const Duration(seconds: 3)));
}

/// Runs [action] and reports a failure as a snack bar instead of crashing.
/// Returns true on success.
Future<bool> runGuarded(BuildContext context, Future<void> Function() action, {String? success}) async {
  try {
    await action();
    if (success != null && context.mounted) showSnack(context, success);
    return true;
  } on ArgumentError catch (e) {
    if (context.mounted) showSnack(context, '${e.message}');
  } catch (e) {
    if (context.mounted) showSnack(context, 'Could not save: $e');
  }
  return false;
}
