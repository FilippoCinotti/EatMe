import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:eatme/core/subscription_catalog.dart';

void main() {
  test('customer-info failure does not hide purchasable plans', () async {
    var products = <String>[];
    await loadSubscriptionCatalog<String>(
      fetchProducts: () async => ['monthly', 'annual'],
      fetchManagementUrl: () async => throw StateError('customer info failed'),
      onProducts: (value) => products = value,
      onManagementUrl: (_) => throw StateError('unexpected metadata'),
      isCurrent: () => true,
    );
    expect(products.length, 2);
  });

  test('plans appear before a slow management-link request finishes', () async {
    final metadata = Completer<String?>(), visible = Completer<void>();
    String? url;
    final load = loadSubscriptionCatalog<String>(
      fetchProducts: () async => ['monthly'],
      fetchManagementUrl: () => metadata.future,
      onProducts: (_) => visible.complete(),
      onManagementUrl: (value) => url = value,
      isCurrent: () => true,
    );
    await visible.future;
    expect(metadata.isCompleted, isFalse);
    metadata.complete('https://apps.apple.com/account/subscriptions');
    await load;
    expect(url, 'https://apps.apple.com/account/subscriptions');
  });

  test('offering failure still allows the management link to load', () async {
    final metadata = Completer<String?>(), visible = Completer<void>();
    String? url;
    final load = loadSubscriptionCatalog<String>(
      fetchProducts: () async => throw StateError('store unavailable'),
      fetchManagementUrl: () => metadata.future,
      onProducts: (_) => throw StateError('no purchasable products'),
      onManagementUrl: (value) {
        url = value;
        visible.complete();
      },
      isCurrent: () => true,
    );
    var failed = false;
    try {
      await load;
    } on StateError {
      failed = true;
    }
    expect(failed, isTrue);
    metadata.complete('https://apps.apple.com/account/subscriptions');
    await visible.future;
    expect(url, 'https://apps.apple.com/account/subscriptions');
  });

  test(
    'empty store results remain empty without illustrative fallback',
    () async {
      var count = -1;
      await loadSubscriptionCatalog<String>(
        fetchProducts: () async => [],
        fetchManagementUrl: () async => null,
        onProducts: (value) => count = value.length,
        onManagementUrl: (_) {},
        isCurrent: () => true,
      );
      expect(count, 0);
    },
  );

  test(
    'late results cannot update a disposed page or another account',
    () async {
      final products = Completer<List<String>>(),
          metadata = Completer<String?>();
      var current = true, updated = false;
      final load = loadSubscriptionCatalog<String>(
        fetchProducts: () => products.future,
        fetchManagementUrl: () => metadata.future,
        onProducts: (_) => updated = true,
        onManagementUrl: (_) => updated = true,
        isCurrent: () => current,
      );
      current = false;
      products.complete(['monthly']);
      metadata.complete('https://apps.apple.com/account/subscriptions');
      await load;
      expect(updated, isFalse);
    },
  );
}
