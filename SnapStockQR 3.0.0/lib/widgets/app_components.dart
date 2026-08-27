import 'package:flutter/material.dart';

import '../ui/app_theme.dart';

class ContentConstraint extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  const ContentConstraint({
    super.key,
    required this.child,
    this.maxWidth = 960,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceRaised,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 34, color: AppColors.textMuted),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMuted,
                    ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 22),
                OutlinedButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class AppStatusBanner extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color color;
  final VoidCallback? onTap;

  const AppStatusBanner({
    super.key,
    required this.icon,
    required this.message,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(color: color, fontWeight: FontWeight.w600),
                ),
              ),
              if (onTap != null) Icon(Icons.refresh, color: color, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class AppSectionTitle extends StatelessWidget {
  final String title;
  final String? trailing;

  const AppSectionTitle(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.textMuted,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.textMuted,
                ),
          ),
      ],
    );
  }
}

void showAppMessage(
  BuildContext context,
  String message, {
  bool error = false,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline : Icons.check_circle_outline,
              color: error
                  ? Theme.of(context).colorScheme.error
                  : AppColors.success,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}

Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirmar',
  bool destructive = false,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: destructive
                  ? FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                    )
                  : null,
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(confirmLabel),
            ),
          ],
        ),
      ) ??
      false;
}
