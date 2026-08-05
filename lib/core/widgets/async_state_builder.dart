import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../utils/error_messages.dart';
import 'empty_state_widget.dart';
import 'loading_widget.dart';

/// One place to render the four states every async surface actually has.
///
/// The pattern this replaces was `if (!snapshot.hasData) return LoadingWidget()`
/// — which turns any stream error into a permanent spinner with no message and
/// no way out. [AsyncStateBuilder] always handles the error branch, and gives
/// the user a retry when one is possible.
///
/// Use [AsyncStateBuilder.stream] or [AsyncStateBuilder.future] rather than
/// wiring a raw [StreamBuilder]/[FutureBuilder] by hand.
class AsyncStateBuilder<T> extends StatelessWidget {
  final AsyncSnapshot<T> snapshot;

  /// Rendered once data has arrived and [isEmpty] is false.
  final Widget Function(BuildContext context, T data) data;

  /// Optional override for the loading state.
  final Widget? loading;

  /// Treats a successful-but-empty result (an empty list, a null) as its own
  /// state so callers stop hand-rolling `list.isEmpty ? ... : ...`.
  final bool Function(T data)? isEmpty;

  /// Shown when [isEmpty] returns true. Defaults to nothing being special —
  /// [data] is called instead when this is omitted.
  final Widget? empty;

  /// Re-runs the work behind this builder. When provided, the error state
  /// gets a "Try again" button.
  final VoidCallback? onRetry;

  /// Overrides the generic error copy derived from the thrown object.
  final String? errorMessage;

  const AsyncStateBuilder({
    super.key,
    required this.snapshot,
    required this.data,
    this.loading,
    this.isEmpty,
    this.empty,
    this.onRetry,
    this.errorMessage,
  });

  /// Convenience wrapper around [StreamBuilder] that cannot forget the error
  /// branch.
  static Widget stream<T>({
    Key? key,
    required Stream<T>? stream,
    T? initialData,
    required Widget Function(BuildContext context, T data) data,
    Widget? loading,
    bool Function(T data)? isEmpty,
    Widget? empty,
    VoidCallback? onRetry,
    String? errorMessage,
  }) {
    return StreamBuilder<T>(
      key: key,
      stream: stream,
      initialData: initialData,
      builder: (context, snapshot) => AsyncStateBuilder<T>(
        snapshot: snapshot,
        data: data,
        loading: loading,
        isEmpty: isEmpty,
        empty: empty,
        onRetry: onRetry,
        errorMessage: errorMessage,
      ),
    );
  }

  /// Convenience wrapper around [FutureBuilder].
  ///
  /// Note the future must be created in `initState` or otherwise cached — a
  /// future constructed inline in `build()` restarts on every rebuild.
  static Widget future<T>({
    Key? key,
    required Future<T>? future,
    T? initialData,
    required Widget Function(BuildContext context, T data) data,
    Widget? loading,
    bool Function(T data)? isEmpty,
    Widget? empty,
    VoidCallback? onRetry,
    String? errorMessage,
  }) {
    return FutureBuilder<T>(
      key: key,
      future: future,
      initialData: initialData,
      builder: (context, snapshot) => AsyncStateBuilder<T>(
        snapshot: snapshot,
        data: data,
        loading: loading,
        isEmpty: isEmpty,
        empty: empty,
        onRetry: onRetry,
        errorMessage: errorMessage,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (snapshot.hasError) {
      return AsyncErrorView(
        message: errorMessage ?? ErrorMessages.friendly(snapshot.error),
        onRetry: onRetry,
      );
    }

    if (!snapshot.hasData) {
      // A stream that has completed without ever emitting is not loading —
      // it is done and empty. Showing a spinner forever would be a lie.
      if (snapshot.connectionState == ConnectionState.done) {
        return empty ?? const SizedBox.shrink();
      }
      return loading ?? const LoadingWidget();
    }

    final value = snapshot.data as T;
    if (empty != null && (isEmpty?.call(value) ?? false)) return empty!;
    return data(context, value);
  }
}

/// The error branch of [AsyncStateBuilder], also usable on its own for
/// imperative failures (a failed submit, a rejected action).
class AsyncErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final bool compact;

  const AsyncErrorView({
    super.key,
    required this.message,
    this.onRetry,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 20,
              color: AppColors.error,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.error,
                ),
              ),
            ),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
    }

    return EmptyStateWidget(
      icon: Icons.error_outline_rounded,
      title: 'Something went wrong',
      subtitle: message,
      actionLabel: onRetry == null ? null : 'Try again',
      onAction: onRetry,
    );
  }
}
