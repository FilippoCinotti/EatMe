import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/api.dart';
import '../core/localization.dart';
import '../core/models.dart';
import 'food_image.dart';
export 'food_image.dart';
export 'brand.dart';
export 'icons.dart';
export 'premium.dart';
export 'recipe_hero.dart';
export 'recipe_editorial.dart';

class AsyncAction extends StatefulWidget {
  const AsyncAction({
    super.key,
    required this.label,
    required this.action,
    this.enabled = true,
    this.secondary = false,
    this.destructive = false,
  });
  final String label;
  final Future<void> Function() action;
  final bool enabled, secondary, destructive;
  @override
  State<AsyncAction> createState() => _AsyncActionState();
}

class _AsyncActionState extends State<AsyncAction> {
  bool busy = false;
  Future<void> run() async {
    setState(() => busy = true);
    try {
      await widget.action();
      unawaited(HapticFeedback.lightImpact());
    } catch (error) {
      if (mounted) {
        final code = error is ApiFailure
            ? error.code
            : error is AuthException
            ? 'authentication_failed'
            : 'unknown_error';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.t(code))));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = busy
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          )
        : Text(widget.label);
    return widget.secondary
        ? OutlinedButton(
            style: widget.destructive
                ? OutlinedButton.styleFrom(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.errorContainer,
                    // The container/on-container pair keeps the label legible
                    // in both themes.
                    foregroundColor: Theme.of(
                      context,
                    ).colorScheme.onErrorContainer,
                  )
                : null,
            onPressed: busy || !widget.enabled ? null : run,
            child: label,
          )
        : FilledButton(
            onPressed: busy || !widget.enabled ? null : run,
            child: label,
          );
  }
}

class PageBody extends StatelessWidget {
  const PageBody({
    super.key,
    required this.children,
    this.onRefresh,
    this.controller,
  });
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  final ScrollController? controller;
  @override
  Widget build(BuildContext context) {
    final content = ListView(
      controller: controller,
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        28 + MediaQuery.paddingOf(context).bottom,
      ),
      physics: const AlwaysScrollableScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: children,
    );
    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: onRefresh == null
              ? content
              : RefreshIndicator(onRefresh: onRefresh!, child: content),
        ),
      ),
    );
  }
}

/// Keeps navigation and dialogs within an unobstructed foldable display region.
class AdaptiveAppFrame extends StatelessWidget {
  const AdaptiveAppFrame({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surface,
    child: DisplayFeatureSubScreen(anchorPoint: Offset.zero, child: child),
  );
}

class FoodMark extends StatelessWidget {
  const FoodMark({super.key, required this.food, this.size = 48});
  final Food food;
  final double size;
  @override
  Widget build(BuildContext context) {
    final icon = switch (food.group) {
      'grain' => Icons.grain_outlined,
      'oil' => Icons.water_drop_outlined,
      'dairy' => Icons.breakfast_dining_outlined,
      'egg' => Icons.egg_outlined,
      _ => Icons.eco_outlined,
    };
    return FoodImage(
      id: food.id,
      photoId: food.photoId,
      width: size,
      height: size,
      radius: 13,
      fallback: icon,
    );
  }
}

class SectionHeading extends StatelessWidget {
  const SectionHeading({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 10),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final heading = Text(
          title,
          style: Theme.of(context).textTheme.titleLarge,
        );
        final action = actionLabel != null && onAction != null
            ? TextButton(onPressed: onAction, child: Text(actionLabel!))
            : null;
        if (action == null) return heading;
        if (constraints.maxWidth < 360 &&
            MediaQuery.textScalerOf(context).scale(15) > 20) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading,
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  alignment: AlignmentDirectional.centerStart,
                ),
                child: Text(actionLabel!),
              ),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: heading),
            action,
          ],
        );
      },
    ),
  );
}

class IconBadge extends StatelessWidget {
  const IconBadge(this.icon, {super.key, this.size = 44});
  final IconData icon;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      shape: BoxShape.circle,
    ),
    child: Icon(
      icon,
      color: Theme.of(context).colorScheme.primary,
      size: size * .5,
    ),
  );
}

class HighlightPanel extends StatelessWidget {
  const HighlightPanel({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.onTap,
  });
  final IconData icon;
  final String title, body;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.primaryContainer,
    child: ListTile(
      leading: IconBadge(icon),
      title: Text(title),
      subtitle: Text(body),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}

class EmptyMessage extends StatelessWidget {
  const EmptyMessage({
    super.key,
    required this.title,
    required this.body,
    this.action,
  });
  final String title, body;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        Text(body, style: Theme.of(context).textTheme.bodyLarge),
        if (action != null) ...[const SizedBox(height: 24), action!],
      ],
    ),
  );
}

class StatusNote extends StatelessWidget {
  const StatusNote({super.key, required this.text, this.warning = false});
  final String text;
  final bool warning;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: warning
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

Future<void> sheet(BuildContext context, Widget child) =>
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.88,
          ),
          child: child,
        ),
      ),
    );

String expiryLabel(BuildContext context, Batch batch) {
  if (batch.expiryDate == null) return context.t('date_unknown');
  final date = MaterialLocalizations.of(
    context,
  ).formatCompactDate(batch.expiryDate!);
  return context.t(batch.expiryKind, {'date': date});
}

/// Calendar-day arithmetic also works across daylight-saving transitions.
int? expiryDays(Batch batch, {DateTime? now}) {
  final date = batch.expiryDate;
  if (date == null) return null;
  final today = now ?? DateTime.now();
  return DateTime.utc(
    date.year,
    date.month,
    date.day,
  ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
}

String relativeExpiryLabel(BuildContext context, Batch batch) {
  final days = expiryDays(batch);
  if (days == null) return context.t('date_unknown');
  if (batch.expiryKind == 'use_by') {
    return context.t(
      days < 0
          ? 'use_by_days_ago'
          : days == 0
          ? 'use_by_today'
          : days == 1
          ? 'use_by_tomorrow'
          : 'use_by_in_days',
      {'count': days.abs()},
    );
  }
  final relative = context.t(
    days < 0
        ? 'expiry_days_ago'
        : days == 0
        ? 'expiry_today'
        : days == 1
        ? 'expiry_tomorrow'
        : 'expiry_in_days',
    {'count': days.abs()},
  );
  if (batch.expiryKind == 'estimated') {
    return '${context.t('estimated_label')} · $relative';
  }
  if (batch.expiryKind == 'best_before') {
    return '${context.t('best_before_label')} · $relative';
  }
  return relative;
}

class CompactBatchRow extends StatelessWidget {
  const CompactBatchRow({super.key, required this.batch, required this.onTap});
  final Batch batch;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final days = expiryDays(batch);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                FoodImage(
                  id: batch.food.id,
                  photoId: batch.food.photoId,
                  imageUrl: batch.food.imageUrl,
                  width: 56,
                  height: 56,
                  radius: 12,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localized(batch.food.name, context.language),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        '${batch.quantity} ${batch.food.unit} · ${context.t(batch.location)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        relativeExpiryLabel(context, batch),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              !batch.usable ||
                                  (days != null &&
                                      days < 0 &&
                                      batch.expiryKind == 'use_by')
                              ? scheme.error
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
