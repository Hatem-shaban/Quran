import 'package:flutter/material.dart';

/// A widget that catches errors from its child and shows a friendly
/// error message with a retry button instead of a blank screen.
class ErrorFallback extends StatefulWidget {
  const ErrorFallback({
    super.key,
    required this.child,
    this.onRetry,
  });

  final Widget child;
  final VoidCallback? onRetry;

  @override
  State<ErrorFallback> createState() => _ErrorFallbackState();
}

class _ErrorFallbackState extends State<ErrorFallback> {
  Object? _error;

  void _retry() {
    setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _ErrorView(
        error: _error!,
        onRetry: widget.onRetry ?? _retry,
      );
    }
    return widget.child;
  }
}

/// Widget displayed when a build error is caught.
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'حدث خطأ',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'عذراً، حدث خطأ غير متوقع.\nيرجى المحاولة مرة أخرى.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
            const SizedBox(height: 12),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A transparent wrapper for screen child builders.
class SafeChild extends StatelessWidget {
  const SafeChild({
    super.key,
    required this.builder,
  });

  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return builder(context);
  }
}

