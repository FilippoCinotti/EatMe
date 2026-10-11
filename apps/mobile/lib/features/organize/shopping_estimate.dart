/// Versioned planning assumptions in EUR, not observed shop prices. Amounts
/// represent the quantity on the list, not the cost of a whole retail pack.
/// Keep unknown categories/units unavailable rather than silently pricing them.
class ShoppingEstimate {
  const ShoppingEstimate(this.cents, this.referenceCents, this.referenceUnit);
  final int cents, referenceCents;
  final String referenceUnit;

  static const version = 'category-eur-v1';
  static const perKg = <String, int>{
    'vegetable': 300,
    'fruit': 350,
    'grain': 250,
    'legume': 350,
    'meat': 1200,
    'fish': 1800,
    'dairy': 900,
    'oil': 800,
    'nuts': 1800,
    'seed': 1200,
    'herb': 2000,
    'egg': 500,
    'honey': 1200,
    'packaged': 600,
    'condiment': 800,
    'spice': 2500,
    'sweetener': 400,
  };
  static const perLitre = <String, int>{
    'dairy': 170,
    'oil': 800,
    'condiment': 800,
    'honey': 1600,
    'packaged': 250,
    'beverage': 250,
  };
  static const perPiece = <String, int>{'egg': 40};

  static ShoppingEstimate? forQuantity(String group, String unit, Object? raw) {
    final quantity = double.tryParse('$raw');
    if (quantity == null || !quantity.isFinite || quantity <= 0) return null;
    final (prices, divisor, referenceUnit) = switch (unit) {
      'g' => (perKg, 1000, 'kg'),
      'kg' => (perKg, 1, 'kg'),
      'ml' => (perLitre, 1000, 'l'),
      'l' => (perLitre, 1, 'l'),
      'pcs' => (perPiece, 1, 'pcs'),
      _ => (const <String, int>{}, 1, unit),
    };
    final reference = prices[group];
    if (reference == null) return null;
    final amount = quantity * reference / divisor;
    if (!amount.isFinite || amount > 1000000000) return null;
    return ShoppingEstimate(amount.round(), reference, referenceUnit);
  }
}
