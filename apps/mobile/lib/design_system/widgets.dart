import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/api.dart';
import '../core/localization.dart';
import '../core/models.dart';
import 'food_image.dart';
export 'food_image.dart';

class AsyncAction extends StatefulWidget {
  const AsyncAction({
    super.key,
    required this.label,
    required this.action,
    this.enabled = true,
    this.secondary = false,
  });
  final String label;
  final Future<void> Function() action;
  final bool enabled, secondary;
  @override
  State<AsyncAction> createState() => _AsyncActionState();
}

class _AsyncActionState extends State<AsyncAction> {
  bool busy = false;
  Future<void> run() async {
    setState(() => busy = true);
    try {
      await widget.action();
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
  const PageBody({super.key, required this.children, this.onRefresh});
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  @override
  Widget build(BuildContext context) {
    final content = ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      physics: const AlwaysScrollableScrollPhysics(),
      children: children,
    );
    return SafeArea(
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
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
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
      isScrollControlled: true,
      useSafeArea: true,
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
