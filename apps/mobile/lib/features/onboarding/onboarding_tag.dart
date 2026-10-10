import 'package:flutter/material.dart';

import '../../design_system/widgets.dart';

/// The same selected palette as Diet & Health's action pills, with a wrapping
/// label and a 44px minimum target for onboarding and large text.
class OnboardingTag extends StatelessWidget {
  const OnboardingTag({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final Text label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const seeds = [
      Colors.teal,
      Colors.indigo,
      Colors.amber,
      Colors.purple,
      Colors.deepOrange,
    ];
    final index =
        (label.data ?? '').runes.fold<int>(0, (a, b) => a + b) % seeds.length;
    final scheme = selected
        ? ColorScheme.fromSeed(
            seedColor: seeds[index],
            brightness: theme.brightness,
          )
        : theme.colorScheme;
    final foreground = selected ? scheme.onPrimaryContainer : scheme.onSurface;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onSelected(!selected),
          customBorder: const StadiumBorder(),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selected) ...[
                    EatMeIcon(
                      EatMeGlyph.circleCheck,
                      size: 16,
                      color: foreground,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      label.data ?? '',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontSize: 12,
                        color: foreground,
                        height: 1.3,
                      ),
                      softWrap: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
