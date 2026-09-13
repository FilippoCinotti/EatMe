import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api.dart';
import '../../core/localization.dart';
import '../../core/models.dart';
import '../../core/state.dart';

final _favoriteRecipe = FutureProvider.autoDispose.family<Json, String>((ref, id) {
  ref.watch(appProvider.select((state) => state.profile['user_id']));
  return ref.watch(apiProvider).request('GET', '/recipes/$id');
});

class RecipeFavorite extends ConsumerStatefulWidget {
  const RecipeFavorite({super.key, required this.recipeId});
  final String recipeId;
  @override
  ConsumerState<RecipeFavorite> createState() => _RecipeFavoriteState();
}

class _RecipeFavoriteState extends ConsumerState<RecipeFavorite> {
  bool busy = false;
  final mutation = Mutation();
  @override
  Widget build(BuildContext context) {
    final resource = ref.watch(_favoriteRecipe(widget.recipeId));
    return resource.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => IconButton.filledTonal(tooltip: context.t('retry'), onPressed: () => ref.invalidate(_favoriteRecipe(widget.recipeId)), icon: const Icon(Icons.refresh)),
      data: (value) {
        if (value['favorite'] is! bool) { return const SizedBox.shrink(); }
        final favorite = value['favorite'] == true;
        return IconButton.filledTonal(tooltip: context.t(favorite ? 'remove_favorite' : 'add_favorite'), style: IconButton.styleFrom(minimumSize: const Size(48, 48), backgroundColor: Theme.of(context).colorScheme.surfaceContainer.withValues(alpha: .94)), icon: Icon(favorite ? Icons.favorite : Icons.favorite_outline), onPressed: busy || ref.watch(appProvider).offline ? null : () async {
          setState(() => busy = true);
          try {
            await mutation.send(ref.read(apiProvider), 'POST', '/recipes', {'action': 'favorite', 'recipe_id': widget.recipeId, 'enabled': !favorite});
            ref.invalidate(_favoriteRecipe(widget.recipeId));
          } on ApiFailure catch (error) {
            if (context.mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.t(error.code)))); }
          } finally {
            if (mounted) { setState(() => busy = false); }
          }
        });
      },
    );
  }
}
