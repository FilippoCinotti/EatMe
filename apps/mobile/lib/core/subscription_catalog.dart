/// Load purchasable products independently from optional management metadata.
/// Only products provided by the native store may be displayed for purchase.
Future<void> loadSubscriptionCatalog<T>({
  required Future<List<T>> Function() fetchProducts,
  required Future<String?> Function() fetchManagementUrl,
  required void Function(List<T>) onProducts,
  required void Function(String?) onManagementUrl,
  required bool Function() isCurrent,
}) async {
  await Future.wait<void>([
    () async {
      final products = await fetchProducts();
      if (isCurrent()) onProducts(products);
    }(),
    () async {
      try {
        final url = await fetchManagementUrl();
        if (isCurrent()) onManagementUrl(url);
      } catch (_) {
        // A failed management-link request must not hide available products.
      }
    }(),
  ], eagerError: true);
}
