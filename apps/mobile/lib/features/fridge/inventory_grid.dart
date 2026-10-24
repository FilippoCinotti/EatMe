import 'package:flutter/material.dart';

import '../../core/localization.dart';
import '../../core/models.dart';
import '../../design_system/widgets.dart';

/// The existing catalog's food.group remains the source of truth.
/// Similar catalog groups share one visual section, without duplicate items.
const inventoryCategoryOrder = <String>[
  'vegetable',
  'fruit',
  'dairy',
  'meat',
  'fish',
  'grain',
  'legume',
  'bakery',
  'condiment',
  'beverage',
  'snack',
  'other',
];

String inventoryCategory(Food food) => switch (food.group) {
  'vegetable' || 'mushroom' => 'vegetable',
  'fruit' => 'fruit',
  'dairy' || 'egg' => 'dairy',
  'meat' => 'meat',
  'fish' || 'seafood' => 'fish',
  'grain' || 'pasta' || 'rice' => 'grain',
  'legume' => 'legume',
  'bread' || 'bakery' || 'baked' => 'bakery',
  'oil' || 'herb' || 'spice' || 'condiment' ||
  'honey' || 'sweetener' || 'sauce' => 'condiment',
  'beverage' || 'drink' => 'beverage',
  'nuts' || 'seed' || 'snack' || 'dessert' || 'sweet' => 'snack',
  _ => 'other',
};

String inventoryCategoryTitle(BuildContext context, String id) =>
    context.t('inventory_category_$id');

IconData inventoryCategoryIcon(String id) => switch (id) {
  'vegetable' => Icons.eco_outlined,
  'fruit' => Icons.apple_outlined,
  'dairy' => Icons.egg_outlined,
  'meat' => Icons.set_meal_outlined,
  'fish' => Icons.phishing_outlined,
  'grain' => Icons.grain_outlined,
  'legume' => Icons.spa_outlined,
  'bakery' => Icons.bakery_dining_outlined,
  'condiment' => Icons.water_drop_outlined,
  'beverage' => Icons.local_drink_outlined,
  'snack' => Icons.cookie_outlined,
  _ => Icons.inventory_2_outlined,
};

bool inventorySearchMatches(Batch batch, String query, BuildContext context) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return true;
  final category = inventoryCategory(batch.food);
  final searchText = <String>[
    ...batch.food.name.values.whereType<String>(),
    batch.food.group,
    inventoryCategoryTitle(context, category),
    context.t('food_group_${batch.food.group}'),
    batch.location,
    context.t(batch.location),
    ...['barcode', 'lot', 'notes'].map(
      (key) => '${batch.metadata[key] ?? ''}',
    ),
  ].join(' ').toLowerCase();
  return searchText.contains(needle);
}

int inventoryColumns(double availableWidth, double textScale) {
  if (textScale >= 1.55) return 1;
  final minWidth = availableWidth >= 600 ? 184.0 : 140.0;
  return ((availableWidth + 10) / (minWidth + 10))
      .floor()
      .clamp(1, 5);
}

double inventoryCardHeight(double textScale) =>
    textScale > 1.25 ? 214 : 187;

class InventoryCategoryGroup {
  const InventoryCategoryGroup(this.id, this.items);
  final String id;
  final List<Batch> items;
}

List<InventoryCategoryGroup> groupInventory(
  List<Batch> visible,
  String sort,
  String language,
) {
  final groups = <String, List<Batch>>{};
  for (final batch in visible) {
    groups.putIfAbsent(inventoryCategory(batch.food), () => []).add(batch);
  }
  final result = <InventoryCategoryGroup>[];
  for (final category in inventoryCategoryOrder) {
    final items = groups[category];
    if (items == null || items.isEmpty) continue;
    items.sort((a, b) {
      final nameA = localized(a.food.name, language).toLowerCase();
      final nameB = localized(b.food.name, language).toLowerCase();
      if (sort == 'name' || sort == 'name_desc') {
        final comparison = nameA.compareTo(nameB);
        return sort == 'name_desc' ? -comparison : comparison;
      }
      if (sort == 'recent') {
        final comparison = (b.createdAt ?? DateTime(1970)).compareTo(
          a.createdAt ?? DateTime(1970),
        );
        if (comparison != 0) return comparison;
      }
      final comparison = (a.expiryDate ?? DateTime(9999)).compareTo(
        b.expiryDate ?? DateTime(9999),
      );
      return comparison != 0 ? comparison : nameA.compareTo(nameB);
    });
    result.add(InventoryCategoryGroup(category, items));
  }
  return result;
}

/// Visual only: state and interactions live in the parent Fridge controller.
class InventoryPhotoCard extends StatelessWidget {
  const InventoryPhotoCard({
    super.key,
    required this.batch,
    required this.showLocation,
    required this.selecting,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });
  final Batch batch;
  final bool showLocation, selecting, selected;
  final VoidCallback onTap, onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final expiry = batchExpiryStatus(batch);
    final status = !batch.usable ? BatchExpiryStatus.expired : expiry;
    final statusColor = switch (status) {
      BatchExpiryStatus.expired => scheme.error,
      BatchExpiryStatus.soon => scheme.tertiary,
      BatchExpiryStatus.normal => scheme.primary,
      BatchExpiryStatus.unknown => scheme.onSurfaceVariant,
    };
    final days = expiryDays(batch);
    final compactExpiry = days == null
        ? context.t('date_unknown')
        : days < 0
        ? context.t('inventory_expired_days', {'count': days.abs()})
        : days == 0
        ? context.t('expiry_today')
        : context.t('inventory_remaining_days', {'count': days});
    final description = [
      localized(batch.food.name, context.language),
      '${batch.quantity} ${batch.food.unit}',
      compactExpiry,
      if (batch.expiryKind == 'estimated') context.t('estimated_label'),
      if (selected) context.t('inventory_select_item'),
    ].join(', ');
    return Semantics(
      button: true,
      selected: selected,
      label: description,
      onLongPress: onLongPress,
      child: Material(
        color: selected ? scheme.primaryContainer : scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('inventory-card-${batch.id}'),
          onTap: onTap,
          onLongPress: onLongPress,
          onSecondaryTap: onLongPress,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? scheme.primary : scheme.outlineVariant,
                width: selected ? 1.5 : 0.5,
              ),
            ),
            padding: const EdgeInsets.all(9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      FoodImage(
                        id: batch.food.id,
                        photoId: batch.food.photoId,
                        imageUrl: batch.food.imageUrl,
                        width: double.infinity,
                        height: 88,
                        radius: 12,
                      ),
                      if (selecting)
                        Positioned(
                          top: 2,
                          right: 2,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              selected
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: selected ? scheme.primary : scheme.onSurface,
                              size: 25,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  localized(batch.food.name, context.language),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                Text(
                  '${batch.quantity} ${batch.food.unit}${showLocation ? ' · ${context.t(batch.location)}' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(Icons.schedule, color: statusColor, size: 14),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        compactExpiry,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: statusColor,
                        ),
                      ),
                    ),
                    if (batch.expiryKind == 'estimated')
                      Tooltip(
                        message: context.t('estimated_label'),
                        child: Icon(
                          Icons.auto_awesome_outlined,
                          size: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
