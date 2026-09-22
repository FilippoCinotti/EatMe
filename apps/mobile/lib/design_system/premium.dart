import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/localization.dart';
import 'brand.dart';
import 'food_image.dart';
import 'icons.dart';

/// Editorial hierarchy shared by the four decision-oriented destinations.
class EditorialHeader extends StatelessWidget {
  const EditorialHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.actions = const [],
    this.art,
  });
  final String eyebrow, title, subtitle;
  final List<Widget> actions;
  final Widget? art;
  @override
  Widget build(BuildContext context) {
    final showArt =
        art != null &&
        MediaQuery.textScalerOf(context).scale(16) <= 22 &&
        MediaQuery.sizeOf(context).width >= 350;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            // Keep the complete public wordmark readable at large text sizes.
            // On compact phones, action buttons move below it instead of
            // competing for horizontal space.
            if (constraints.maxWidth < 300 && actions.isNotEmpty) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: EatMeWordmark(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: actions,
                  ),
                ],
              );
            }
            return Row(
              children: [const EatMeWordmark(), const Spacer(), ...actions],
            );
          },
        ),
        const SizedBox(height: 22),
        Text(
          eyebrow.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            letterSpacing: 2.35,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        if (!showArt)
          Text(title, style: Theme.of(context).textTheme.displaySmall)
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.displaySmall,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(width: 104, height: 112, child: art),
            ],
          ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class EatMeWordmark extends StatelessWidget {
  const EatMeWordmark({super.key, this.large = false});
  final bool large;
  @override
  Widget build(BuildContext context) => Semantics(
    label: context.t('eatme'),
    child: ExcludeSemantics(
      child: Flex(
        direction: large ? Axis.vertical : Axis.horizontal,
        mainAxisSize: MainAxisSize.min,
        children: [
          EatMeBrandMark(size: large ? 52 : 22),
          SizedBox(width: large ? 0 : 6, height: large ? 8 : 0),
          Text(
            context.t('eatme'),
            style: TextStyle(
              fontFamily: 'EatMeSans',
              fontWeight: FontWeight.w700,
              fontSize: large ? 52 : 30,
              height: 1,
              letterSpacing: -1,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    ),
  );
}

class RoundAction extends StatelessWidget {
  const RoundAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.primary = false,
  });
  final EatMeGlyph icon;
  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 8),
    child: IconButton.filledTonal(
      tooltip: label,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        backgroundColor: primary
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.surfaceContainer,
        foregroundColor: primary
            ? Theme.of(context).colorScheme.onPrimary
            : Theme.of(context).colorScheme.onSurface,
      ),
      icon: EatMeIcon(icon, size: 23),
    ),
  );
}

class SearchPill extends StatelessWidget {
  const SearchPill({
    super.key,
    required this.hint,
    this.onChanged,
    this.onFilter,
    this.onTap,
  });
  final String hint;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onFilter, onTap;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(30),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(
            alpha: Theme.of(context).brightness == Brightness.dark ? .12 : .035,
          ),
          blurRadius: 20,
          offset: const Offset(0, 7),
        ),
      ],
    ),
    child: TextField(
      readOnly: onTap != null,
      onTap: onTap,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        fillColor: Colors.transparent,
        hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        prefixIcon: const Center(
          widthFactor: 1,
          child: EatMeIcon(EatMeGlyph.search, size: 21),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 50),
        suffixIcon: onFilter == null
            ? null
            : EatMeIconButton(
                glyph: EatMeGlyph.slidersHorizontal,
                label: context.t('filters'),
                onPressed: onFilter,
                size: 44,
                iconSize: 21,
                backgroundColor: Colors.transparent,
              ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
      ),
    ),
  );
}

class InformationPanel extends StatelessWidget {
  const InformationPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.tinted = true,
  });
  final Widget child;
  final EdgeInsets padding;
  final bool tinted;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: Material(
      color: tinted
          ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .6)
          : Theme.of(context).colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(26),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    ),
  );
}

class GlassSurface extends StatelessWidget {
  const GlassSurface({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final contrast = MediaQuery.highContrastOf(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? .28 : .08),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: contrast ? 0 : 20,
            sigmaY: contrast ? 0 : 20,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer.withValues(
                alpha: contrast
                    ? 1
                    : dark
                    ? .88
                    : .82,
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: Colors.white.withValues(
                  alpha: contrast
                      ? .8
                      : dark
                      ? .12
                      : .8,
                ),
                width: 1,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class EatMeNavigationItem {
  const EatMeNavigationItem({required this.label, required this.icon});

  final String label;
  final EatMeGlyph icon;
}

/// EatMe's bespoke four-destination navigation inside the shared glass shell.
class EatMeNavigationBar extends StatelessWidget {
  const EatMeNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  }) : assert(destinations.length == 4);

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<EatMeNavigationItem> destinations;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reducedMotion
        ? Duration.zero
        : const Duration(milliseconds: 210);
    final largeText = MediaQuery.textScalerOf(context).scale(16) > 22;
    return SizedBox(
      height: largeText ? 84 : 72,
      child: Row(
        children: [
          for (var index = 0; index < destinations.length; index++)
            Expanded(
              child: Semantics(
                button: true,
                selected: selectedIndex == index,
                label: destinations[index].label,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => onDestinationSelected(index),
                    child: Center(
                      child: AnimatedContainer(
                        duration: duration,
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: EdgeInsets.symmetric(
                          horizontal: largeText ? 3 : 4,
                          vertical: largeText ? 7 : 6,
                        ),
                        decoration: BoxDecoration(
                          color: selectedIndex == index
                              ? scheme.primary.withValues(alpha: .13)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: ExcludeSemantics(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedScale(
                                duration: duration,
                                curve: Curves.easeOutBack,
                                scale: selectedIndex == index ? 1.08 : 1,
                                child: EatMeIcon(
                                  destinations[index].icon,
                                  size: 22,
                                  strokeWidth: selectedIndex == index
                                      ? 2.2
                                      : 1.75,
                                  color: selectedIndex == index
                                      ? scheme.primary
                                      : scheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 4),
                              AnimatedDefaultTextStyle(
                                duration: duration,
                                style: Theme.of(context).textTheme.labelSmall!
                                    .copyWith(
                                      height: 1,
                                      fontSize: 10.5,
                                      fontWeight: selectedIndex == index
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                      color: selectedIndex == index
                                          ? scheme.primary
                                          : scheme.onSurfaceVariant,
                                    ),
                                child: Text(
                                  destinations[index].label,
                                  maxLines: largeText ? 2 : 1,
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.icon,
    this.urgent = false,
    this.warning = false,
    this.emphasis = false,
  });
  final String label;
  final EatMeGlyph? icon;
  final bool urgent, warning, emphasis;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = urgent
        ? scheme.error
        : warning
        ? Theme.of(context).brightness == Brightness.dark
              ? const Color(0xffffcf70)
              : const Color(0xff855400)
        : emphasis
        ? scheme.onPrimary
        : scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: urgent
            ? scheme.errorContainer
            : warning
            ? Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xff4b3817)
                  : const Color(0xfffff0c9)
            : emphasis
            ? scheme.primary
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            EatMeIcon(icon!, size: 15, color: color, strokeWidth: 2),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: color, height: 1.25),
            ),
          ),
        ],
      ),
    );
  }
}

class FoodPhotoCard extends StatelessWidget {
  const FoodPhotoCard({
    super.key,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.photoId,
    this.imageUrl,
    this.badge,
    this.onAction,
    this.actionIcon = EatMeGlyph.ellipsis,
    this.actionLabel,
    this.actionEmphasis = false,
    this.imageHeight = 144,
  });
  final String id, title, subtitle;
  final String? photoId, imageUrl, actionLabel;
  final VoidCallback? onTap;
  final VoidCallback? onAction;
  final EatMeGlyph actionIcon;
  final bool actionEmphasis;
  final Widget? badge;
  final double imageHeight;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainer,
    borderRadius: BorderRadius.circular(23),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              FoodImage(
                id: id,
                photoId: photoId,
                imageUrl: imageUrl,
                height: imageHeight,
                radius: 0,
                fallback: Icons.eco_outlined,
              ),
              if (badge != null)
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 8,
                  child: Align(alignment: Alignment.centerLeft, child: badge),
                ),
              if (onAction != null)
                Positioned(
                  right: 8,
                  top: 8,
                  child: EatMeIconButton(
                    glyph: actionIcon,
                    label: actionLabel ?? '',
                    onPressed: onAction,
                    size: 44,
                    iconSize: 20,
                    foregroundColor: actionEmphasis
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainer.withValues(alpha: .9),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class AdaptivePhotoGrid extends StatelessWidget {
  const AdaptivePhotoGrid({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns =
          constraints.maxWidth >= 330 &&
              MediaQuery.textScalerOf(context).scale(16) <= 23
          ? 2
          : 1;
      final width = (constraints.maxWidth - (columns - 1) * 14) / columns;
      return Wrap(
        spacing: 14,
        runSpacing: 16,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}

class HorizontalFoodRail extends StatelessWidget {
  const HorizontalFoodRail({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final child in children)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: SizedBox(
              width: MediaQuery.textScalerOf(context).scale(16) > 23
                  ? 210
                  : 146,
              child: child,
            ),
          ),
      ],
    ),
  );
}

class CategoryTile extends StatelessWidget {
  const CategoryTile({
    super.key,
    required this.label,
    required this.foodId,
    required this.selected,
    required this.onTap,
    this.icon,
  });
  final String label, foodId;
  final EatMeGlyph? icon;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: Material(
      color: selected
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: SizedBox(
          width: MediaQuery.textScalerOf(context).scale(16) > 23 ? 130 : 96,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                if (icon == null)
                  FoodImage(
                    id: foodId,
                    height: 62,
                    radius: 14,
                    fallback: Icons.eco_outlined,
                  )
                else
                  SizedBox(
                    height: 62,
                    child: Center(
                      child: EatMeIcon(
                        icon!,
                        size: 30,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children, this.title});
  final List<Widget> children;
  final String? title;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(title!, style: Theme.of(context).textTheme.titleLarge),
          ),
        InformationPanel(
          tinted: false,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(children: children),
        ),
      ],
    ),
  );
}

class SettingRow extends StatelessWidget {
  const SettingRow({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
    this.onTap,
    this.trailing,
  });
  final String title;
  final String? subtitle;
  final EatMeGlyph icon;
  final VoidCallback? onTap;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: onTap != null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: EatMeIcon(icon, size: 21, color: scheme.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
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
                const SizedBox(width: 10),
                trailing ??
                    (onTap == null
                        ? const SizedBox.shrink()
                        : EatMeIcon(
                            EatMeGlyph.chevronRight,
                            size: 18,
                            color: scheme.onSurfaceVariant,
                          )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ShortcutTile extends StatelessWidget {
  const ShortcutTile({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
  });
  final String title;
  final EatMeGlyph icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainer,
    borderRadius: BorderRadius.circular(24),
    child: InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EatMeIcon(
              icon,
              size: 28,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 18),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    ),
  );
}

class CompactShortcut extends StatelessWidget {
  const CompactShortcut({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final EatMeGlyph icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: title,
    child: Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          width: 132,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EatMeIcon(
                  icon,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class EatMeSelectionRow extends StatelessWidget {
  const EatMeSelectionRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final EatMeGlyph icon;
  final String title, subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? scheme.primaryContainer : scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EatMeIcon(icon, size: 23, color: scheme.primary),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (selected)
                  EatMeIcon(
                    EatMeGlyph.circleCheck,
                    size: 21,
                    color: scheme.primary,
                  )
                else
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: scheme.outline, width: 1.6),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EatMeToggleRow extends StatelessWidget {
  const EatMeToggleRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final EatMeGlyph? icon;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (icon != null) ...[
          EatMeIcon(
            icon!,
            size: 21,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        Switch.adaptive(value: value, onChanged: onChanged),
      ],
    ),
  );
}

class EatMeTabStrip extends StatelessWidget {
  const EatMeTabStrip({
    super.key,
    required this.values,
    required this.selected,
    required this.onSelected,
  });

  final List<(String, String)> values;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    borderRadius: BorderRadius.circular(20),
    child: Padding(
      padding: const EdgeInsets.all(4),
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          children: [
            for (final value in values)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: selected == value.$1,
                  child: InkWell(
                    onTap: () => onSelected(value.$1),
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 180),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: selected == value.$1
                            ? Theme.of(context).colorScheme.surfaceContainer
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        value.$2,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: selected == value.$1
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                              fontWeight: selected == value.$1
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// Secondary navigation keeps actions and titles readable at larger text sizes.
class EatMeAppBar extends StatelessWidget implements PreferredSizeWidget {
  const EatMeAppBar({super.key, this.title, this.leading, this.actions});
  final Widget? title, leading;
  final List<Widget>? actions;
  @override
  Size get preferredSize => const Size.fromHeight(72);
  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: SizedBox(
      height: 72,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            if (leading != null)
              leading!
            else if (Navigator.canPop(context))
              IconButton(
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: () => Navigator.maybePop(context),
                icon: const EatMeIcon(EatMeGlyph.chevronLeft),
              ),
            Expanded(
              child: title == null
                  ? const EatMeWordmark()
                  : Semantics(
                      header: true,
                      child: DefaultTextStyle(
                        style: Theme.of(context).textTheme.titleLarge!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        child: title!,
                      ),
                    ),
            ),
            ...?actions,
          ],
        ),
      ),
    ),
  );
}
