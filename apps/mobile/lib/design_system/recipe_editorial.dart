import 'package:flutter/material.dart';

import '../core/localization.dart';
import 'icons.dart';

/// The compact editorial hierarchy shared by discovery, recipes and cooking.
/// Kept local to these journeys so the approved wordmark and other pages retain
/// their own typography. EatMeDisplay is the bundled STIX Two Text family.
class RecipeEditorial extends StatelessWidget {
  const RecipeEditorial({super.key, required this.builder});
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final scheme = base.colorScheme;
    TextStyle display(double size) => TextStyle(
      fontFamily: 'EatMeDisplay',
      fontSize: size,
      fontWeight: FontWeight.w700,
      height: 1.15,
      letterSpacing: -.25,
      color: scheme.onSurface,
    );
    final action = display(15).copyWith(letterSpacing: 0, height: 1.2);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
    );
    return Theme(
      data: base.copyWith(
        textTheme: base.textTheme.copyWith(
          displaySmall: display(24),
          headlineMedium: display(24),
          headlineSmall: display(22),
          titleLarge: display(22),
          titleMedium: display(17),
          titleSmall: display(15),
          labelLarge: action,
          bodyLarge: base.textTheme.bodyLarge?.copyWith(
            fontSize: 15,
            height: 1.4,
          ),
          bodyMedium: base.textTheme.bodyMedium?.copyWith(
            fontSize: 14,
            height: 1.4,
            letterSpacing: 0,
          ),
          bodySmall: base.textTheme.bodySmall?.copyWith(
            fontSize: 13,
            height: 1.35,
            letterSpacing: 0,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            textStyle: action,
            iconSize: 20,
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
            shape: shape,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            textStyle: action,
            iconSize: 20,
            side: BorderSide.none,
            backgroundColor: scheme.surfaceContainer,
            foregroundColor: scheme.primary,
            shape: shape,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            minimumSize: const Size(44, 44),
            textStyle: action,
            iconSize: 20,
            foregroundColor: scheme.primary,
          ),
        ),
      ),
      child: Builder(builder: builder),
    );
  }
}

class RecipeActionRow extends StatelessWidget {
  const RecipeActionRow({
    super.key,
    required this.primary,
    required this.secondary,
  });
  final Widget primary, secondary;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 300 ||
          MediaQuery.textScalerOf(context).scale(15) > 20) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [primary, const SizedBox(height: 8), secondary],
        );
      }
      return Row(
        children: [
          Expanded(flex: 6, child: primary),
          const SizedBox(width: 10),
          Expanded(flex: 4, child: secondary),
        ],
      );
    },
  );
}

/// Scaffold reserves this bar's measured height, including large text/safe area.
class RecipeActionBar extends StatelessWidget {
  const RecipeActionBar({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
    child: Align(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: child,
        ),
      ),
    ),
  );
}

class RecipeMeta extends StatelessWidget {
  const RecipeMeta({super.key, required this.icon, required this.text});
  final EatMeGlyph icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      EatMeIcon(
        icon,
        size: 17,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ),
    ],
  );
}

class RecipeDisclosure extends StatelessWidget {
  const RecipeDisclosure({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
    this.onTap,
    this.warning = false,
    this.trailing,
    this.plain = false,
  });
  final String title;
  final String? subtitle;
  final EatMeGlyph icon;
  final VoidCallback? onTap;
  final bool warning, plain;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: plain ? Colors.transparent : scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: plain ? 0 : 14,
            vertical: 12,
          ),
          child: Row(
            children: [
              EatMeIcon(
                icon,
                size: 22,
                color: warning ? scheme.error : scheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: warning ? scheme.error : scheme.onSurface,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ] else if (onTap != null) ...[
                const SizedBox(width: 8),
                const EatMeIcon(EatMeGlyph.chevronRight, size: 18),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class RecipeAvailability extends StatelessWidget {
  const RecipeAvailability({
    super.key,
    required this.available,
    required this.total,
    this.onTap,
  });
  final int available, total;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => RecipeDisclosure(
    icon: EatMeGlyph.refrigerator,
    title: context.t('ingredients_at_home', {
      'available': available,
      'total': total,
    }),
    subtitle: onTap == null ? null : context.t('view_ingredients'),
    onTap: onTap,
    trailing: total == 0
        ? null
        : SizedBox(
            width: 48,
            child: Semantics(
              label: context.t('ingredient_coverage', {
                'available': available,
                'total': total,
              }),
              child: LinearProgressIndicator(
                value: (available / total).clamp(0, 1).toDouble(),
                minHeight: 5,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
  );
}

class RecipeDescription extends StatefulWidget {
  const RecipeDescription({super.key, required this.text});
  final String text;
  @override
  State<RecipeDescription> createState() => _RecipeDescriptionState();
}

class _RecipeDescriptionState extends State<RecipeDescription> {
  bool expanded = false;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final style = Theme.of(context).textTheme.bodyMedium!;
      final painter = TextPainter(
        text: TextSpan(text: widget.text, style: style),
        maxLines: 2,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: constraints.maxWidth);
      final overflows = painter.didExceedMaxLines;
      painter.dispose();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.text,
            style: style,
            maxLines: expanded ? null : 2,
            overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          ),
          if (overflows)
            TextButton(
              onPressed: () => setState(() => expanded = !expanded),
              child: Text(context.t(expanded ? 'show_less' : 'read_more')),
            ),
        ],
      );
    },
  );
}
