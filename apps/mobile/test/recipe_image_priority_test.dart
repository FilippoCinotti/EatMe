import 'package:eatme/core/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('recipe image URL priority', () {
    test('approved FLUX image replaces legacy hero and thumbnail URLs', () {
      final recipe = <String, dynamic>{
        'image_url': 'https://storage.example/recipe-images/id/hero-002.webp',
        'hero_image_url': 'https://storage.example/old-hero.jpg',
        'thumbnail_url': 'https://storage.example/old-thumb.jpg',
      };

      expect(
        recipeImageUrl(recipe),
        'https://storage.example/recipe-images/id/hero-002.webp',
      );
      expect(
        Recipe.fromJson({
          ...recipe,
          'id': 'recipe-1',
          'title': {'en': 'Example'},
          'minutes': 15,
          'servings': 2,
          'ingredients': <dynamic>[],
          'steps': {'en': <dynamic>[]},
        }).imageUrl,
        recipe['image_url'],
      );
    });

    test('legacy hero is used when catalog image is missing or blank', () {
      expect(
        recipeImageUrl({
          'image_url': '  ',
          'hero_image_url': 'https://storage.example/old-hero.jpg',
          'thumbnail_url': 'https://storage.example/old-thumb.jpg',
        }),
        'https://storage.example/old-hero.jpg',
      );
      expect(
        recipeImageUrl({'hero_image_url': 'https://storage.example/hero.jpg'}),
        'https://storage.example/hero.jpg',
      );
    });

    test('thumbnail is the final fallback', () {
      expect(
        recipeImageUrl({'thumbnail_url': 'https://storage.example/thumb.jpg'}),
        'https://storage.example/thumb.jpg',
      );
      expect(recipeImageUrl({}), isNull);
    });
  });
}
