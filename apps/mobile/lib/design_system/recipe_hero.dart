import 'package:flutter/material.dart';
import 'food_image.dart';
import 'icons.dart';

/// A recipe photograph is the primary visual anchor; metadata wraps for large text.
class HeroRecipeCard extends StatelessWidget {
  const HeroRecipeCard({
    super.key,
    required this.imageId,
    required this.title,
    required this.onTap,
    required this.metadata,
    this.badge,
    this.action,
    this.footer,
    this.imageUrl,
    this.ingredientIds = const [],
  });
  final String imageId, title;
  final String? imageUrl;
  final List<String> ingredientIds;
  final VoidCallback onTap;
  final List<Widget> metadata;
  final Widget? badge, action, footer;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainer,
    borderRadius: BorderRadius.circular(28),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              FoodImage(
                id: imageId,
                imageUrl: imageUrl,
                ingredientIds: ingredientIds,
                height: 242,
                radius: 0,
              ),
              if (badge != null)
                Positioned(
                  left: 16,
                  top: 16,
                  right: action == null ? 16 : 76,
                  child: Align(alignment: Alignment.centerLeft, child: badge),
                ),
              if (action != null)
                Positioned(right: 12, top: 12, child: action!),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    const SizedBox(width: 8),
                    EatMeIcon(
                      EatMeGlyph.chevronRight,
                      size: 22,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: metadata),
                ?footer,
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
