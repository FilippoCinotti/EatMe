import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'api.dart';
import 'localization.dart';
import 'models.dart';

abstract final class EntitlementCapability {
  static const unlimitedImports = 'canUseUnlimitedImports';
  static const advancedDietFit = 'canUseAdvancedDietFit';
  static const advancedSubstitutions = 'canUseAdvancedSubstitutions';
  static const receiptRecognition = 'canUseReceiptRecognition';
  static const advancedPhotoRecognition = 'canUseAdvancedPhotoRecognition';
  static const generatedShopping = 'canUseGeneratedShopping';
  static const smartPlanning = 'canUseSmartPlanning';
  static const householdProfiles = 'canUseHouseholdProfiles';
  static const advancedMealTiming = 'canUseAdvancedMealTiming';
  static const premiumInsights = 'canUsePremiumInsights';
}

/// Product access is resolved once from the server-verified entitlement
/// snapshot. UI code consumes named capabilities instead of inspecting store
/// products or subscription identifiers directly.
class EntitlementSnapshot {
  const EntitlementSnapshot({
    required this.tier,
    required this.capabilities,
    required this.limits,
    required this.usage,
    required this.remaining,
    required this.storeConfigured,
  });

  final String tier;
  final Map<String, bool> capabilities;
  final Json limits;
  final Json usage;
  final Json remaining;
  final bool storeConfigured;

  bool can(String capability) => capabilities[capability] == true;
  int? remainingFor(String capability) => remaining[capability] as int?;
  bool get isPlus => tier == 'eatme_plus';

  factory EntitlementSnapshot.fromJson(Json value) => EntitlementSnapshot(
    tier: value['tier'] as String? ?? 'free',
    capabilities: Map<String, bool>.from(
      value['capabilities'] as Map? ?? const {},
    ),
    limits: Map<String, dynamic>.from(value['limits'] as Map? ?? const {}),
    usage: Map<String, dynamic>.from(value['usage'] as Map? ?? const {}),
    remaining: Map<String, dynamic>.from(
      value['remaining'] as Map? ?? const {},
    ),
    storeConfigured: value['configured'] == true,
  );
}

final entitlementsProvider = FutureProvider<EntitlementSnapshot>((ref) async {
  final value = await ref.read(apiProvider).request('GET', '/entitlements');
  return EntitlementSnapshot.fromJson(value);
});

Future<void> refreshEntitlements(WidgetRef ref) async {
  await ref.read(apiProvider).request('POST', '/entitlements/refresh');
  ref.invalidate(entitlementsProvider);
}

Future<void> showContextualPlusPrompt(
  BuildContext context, {
  required String benefit,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t('eatme_plus'),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.t('contextual_plus_title'),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(context.t(benefit)),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () {
              Navigator.pop(sheetContext);
              context.push('/subscriptions');
            },
            child: Text(context.t('try_eatme_plus')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(sheetContext),
            child: Text(context.t('not_now')),
          ),
        ],
      ),
    ),
  );
}
