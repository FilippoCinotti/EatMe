import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/state.dart';
import '../core/api.dart';

final _privatePhoto = FutureProvider.autoDispose.family<String?, String>((ref, key) async {
  final value = await ref.read(apiProvider).request('GET', '/foods/${key.split('|').last}/photo', allowCache: false);
  return value['base64'] as String?;
});

/// Illustrative photography is mapped only to the bundled demo catalog IDs.
/// Unknown or private content keeps an honest icon fallback, never a wrong dish.
class FoodImage extends ConsumerWidget {
  const FoodImage({
    super.key,
    required this.id,
    this.photoId,
    this.height = 160,
    this.width,
    this.radius = 16,
    this.fallback = Icons.restaurant_outlined,
  });
  final String id;
  final String? photoId;
  final double height, radius;
  final double? width;
  final IconData fallback;
  static const asset = 'assets/images/food-atlas.webp';
  static const cells = <String, int>{
    '913a438b-0805-543d-8719-c0253f8f103a': 0,
    '50773917-c954-51f2-a53b-1cf4b3c00690': 1,
    'ee9f625f-f38b-5849-9fde-f5bdfb8f6ada': 2,
    'fa51c4ef-498a-5587-8aa3-2a92ecd30242': 3,
    '1536dc24-7d91-5bb7-bb5b-8c2ba6a0620e': 4,
    'd72ab6c9-e21e-57c5-9674-2c0bc0fdca2e': 5,
    'b488bbff-0384-5e44-9973-7a23778efcc2': 6,
    '32b74528-bf3a-52df-82b6-31f2444520d7': 7,
    '1f866511-1940-57a4-a277-999cf3cf931e': 8,
    '55dd2126-df80-549e-8f07-2f2199d89679': 9,
    '342e40a1-9306-5d6d-a963-be68cb5d95b8': 10,
    '533cdc59-9b73-5059-9bd2-60e268df96d6': 11,
    '3baf7b73-2db5-5adb-8fe0-1a5a28d648b0': 12,
    '604b56d0-d20e-5010-a03b-80cc43bd9f20': 13,
    '9eac5c99-859e-58f6-89c8-e136e9b6ff52': 14,
    '9291d3ed-aae8-5924-92cd-7109f68cddb6': 15,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (photoId != null) {
      final state = ref.watch(appProvider);
      final key = '${ref.read(apiProvider).userId}|${state.profile['household_id']}|$photoId|$id';
      final photo = ref.watch(_privatePhoto(key)).asData?.value;
      if (photo != null) return ExcludeSemantics(child: ClipRRect(borderRadius: BorderRadius.circular(radius), child: Image.memory(base64Decode(photo), width: width, height: height, fit: BoxFit.cover, errorBuilder: (_, _, _) => SizedBox(width: width, height: height, child: Icon(fallback)))));
    }
    final cell = cells[id];
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox(
          width: width,
          height: height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (cell == null) {
                return ColoredBox(
                  color: scheme.primaryContainer,
                  child: Center(
                    child: Icon(
                      fallback,
                      size: math.min(height * .4, 64),
                      color: scheme.primary,
                    ),
                  ),
                );
              }
              final side = math.max(constraints.maxWidth, height);
              return Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned(
                    left:
                        -(cell % 4) * side + (constraints.maxWidth - side) / 2,
                    top: -(cell ~/ 4) * side + (height - side) / 2,
                    width: side * 4,
                    height: side * 4,
                    child: Image.asset(
                      asset,
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (context, error, stack) =>
                          ColoredBox(color: scheme.primaryContainer),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
