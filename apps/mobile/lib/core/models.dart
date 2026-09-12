typedef Json = Map<String, dynamic>;

String localized(Json text, String language) =>
    (text[language] ?? text['en'] ?? '') as String;

class Food {
  const Food({
    required this.id,
    required this.name,
    required this.unit,
    required this.group,
  });
  final String id, unit, group;
  final Json name;
  factory Food.fromJson(Json j) => Food(
    id: j['id'] as String,
    name: Map<String, dynamic>.from(j['name'] as Map),
    unit: j['unit'] as String,
    group: j['group'] as String,
  );
}

class Diet {
  const Diet(
    this.id,
    this.slug,
    this.name,
    this.selectable,
    this.status,
    this.medical,
  );
  final String id, slug, status;
  final Json name;
  final bool selectable, medical;
  factory Diet.fromJson(Json j) => Diet(
    j['id'] as String,
    j['slug'] as String,
    Map<String, dynamic>.from(j['name'] as Map),
    j['selectable'] as bool,
    j['status'] as String,
    j['medical'] as bool,
  );
}

class Batch {
  const Batch(
    this.id,
    this.food,
    this.quantity,
    this.location,
    this.expiryDate,
    this.expiryKind,
    this.version,
    this.usable, {
    this.metadata = const {},
    this.recalls = const [],
  });
  final String id, quantity, location, expiryKind;
  final Food food;
  final DateTime? expiryDate;
  final int version;
  final bool usable;
  final Json metadata;
  final List<Json> recalls;
  factory Batch.fromJson(Json j) => Batch(
    j['id'] as String,
    Food.fromJson(Map<String, dynamic>.from(j['food'] as Map)),
    j['quantity'] as String,
    j['location'] as String,
    DateTime.tryParse(j['expiry_date'] as String? ?? ''),
    j['expiry_kind'] as String,
    j['version'] as int,
    j['usable'] as bool,
    metadata: Map<String, dynamic>.from(j['metadata'] as Map? ?? {}),
    recalls: (j['recalls'] as List? ?? [])
        .map((v) => Map<String, dynamic>.from(v as Map))
        .toList(),
  );
}

class Recipe {
  const Recipe(
    this.id,
    this.title,
    this.minutes,
    this.servings,
    this.ingredients,
    this.steps,
  );
  final String id;
  final Json title, steps;
  final int minutes, servings;
  final List<Json> ingredients;
  factory Recipe.fromJson(Json j) => Recipe(
    j['id'] as String,
    Map<String, dynamic>.from(j['title'] as Map),
    j['minutes'] as int,
    j['servings'] as int,
    (j['ingredients'] as List)
        .map((i) => Map<String, dynamic>.from(i as Map))
        .toList(),
    Map<String, dynamic>.from(j['steps'] as Map),
  );
  List<String> instructions(String language) =>
      List<String>.from(steps[language] ?? steps['en']);
}

class Recommendation {
  const Recommendation(
    this.recipe,
    this.available,
    this.total,
    this.useSoon,
    this.warnings,
  );
  final Recipe recipe;
  final int available, total;
  final List<String> useSoon;
  final List<Json> warnings;
  factory Recommendation.fromJson(Json j) => Recommendation(
    Recipe.fromJson(Map<String, dynamic>.from(j['recipe'] as Map)),
    j['available_count'] as int,
    j['ingredient_count'] as int,
    List<String>.from(j['use_soon_food_ids'] as List),
    (j['warnings'] as List)
        .map((x) => Map<String, dynamic>.from(x as Map))
        .toList(),
  );
}
