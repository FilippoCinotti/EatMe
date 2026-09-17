import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api.dart';
import '../../core/entitlements.dart';
import '../../core/localization.dart';
import '../../core/state.dart';
import '../../design_system/widgets.dart';
import 'shared.dart';

class SubscriptionsPage extends ConsumerStatefulWidget {
  const SubscriptionsPage({super.key, this.illustrativePrices = const []});

  /// Explicit screenshot/demo fixtures. Production pricing always comes from
  /// the configured store offering and leaves this list empty.
  @visibleForTesting
  final List<IllustrativeStorePrice> illustrativePrices;

  @override
  ConsumerState<SubscriptionsPage> createState() => _SubscriptionsState();
}

@visibleForTesting
class IllustrativeStorePrice {
  const IllustrativeStorePrice({
    required this.title,
    required this.price,
    required this.period,
    this.savingsPercent,
  });

  final String title;
  final String price;
  final String period;
  final int? savingsPercent;
}

class _SubscriptionsState extends ResourceState<SubscriptionsPage> {
  @override
  String get path => '/entitlements';
  List<Package> packages = [];
  String? managementUrl;
  bool storeReady = false;
  static bool configured = false;
  @override
  Future<void> load() async {
    if (mounted) {
      setState(() {
        storeReady = false;
        packages = [];
        managementUrl = null;
      });
    }
    await super.load();
    final key = defaultTargetPlatform == TargetPlatform.iOS
        ? const String.fromEnvironment('REVENUECAT_IOS_KEY')
        : const String.fromEnvironment('REVENUECAT_ANDROID_KEY');
    if (data?['configured'] != true || key.isEmpty || EatMeApi.development) {
      return;
    }
    try {
      final user = ref.read(apiProvider).userId!;
      if (!configured) {
        await Purchases.configure(
          PurchasesConfiguration(key)..appUserID = user,
        );
        configured = true;
      } else {
        await Purchases.logIn(user);
      }
      final offerings = await Purchases.getOfferings();
      final customer = await Purchases.getCustomerInfo();
      if (mounted && ref.read(apiProvider).userId == user) {
        setState(() {
          storeReady = true;
          packages = offerings.current?.availablePackages ?? [];
          managementUrl = customer.managementURL;
        });
      }
    } catch (_) {
      if (mounted && context.mounted) {
        setState(() => error = 'store_unavailable');
      }
    }
  }

  Future<void> verify() async {
    await refreshEntitlements(ref);
    await load();
  }

  int? annualSavings(Package annual) {
    final monthly = packages
        .where((package) => package.packageType == PackageType.monthly)
        .firstOrNull;
    if (monthly == null ||
        monthly.storeProduct.price <= 0 ||
        annual.storeProduct.price <= 0) {
      return null;
    }
    final fullYear = monthly.storeProduct.price * 12;
    final percent = ((fullYear - annual.storeProduct.price) / fullYear * 100)
        .round();
    return percent > 0 ? percent : null;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: EatMeAppBar(title: Text(context.t('subscriptions'))),
    body: content([
      Text(
        context.t('eatme_plus').toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w800,
          letterSpacing: 2.2,
        ),
      ),
      const SizedBox(height: 10),
      Text(
        context.t('eatme_plus_title'),
        style: Theme.of(context).textTheme.displaySmall,
      ),
      const SizedBox(height: 10),
      Text(
        context.t('eatme_plus_body'),
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 24),
      InformationPanel(
        child: Row(
          children: [
            const EatMeIcon(EatMeGlyph.badgeCheck, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t(
                      data?['tier'] == 'eatme_plus'
                          ? 'eatme_plus_active'
                          : 'free_plan_active',
                    ),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    context.t(
                      data?['tier'] == 'eatme_plus'
                          ? 'eatme_plus_active_body'
                          : 'free_plan_active_body',
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 22),
      Text(
        context.t('eatme_plus_benefits'),
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 10),
      for (final benefit in [
        ('benefit_import_anywhere', EatMeGlyph.sparkles),
        ('benefit_adapt_to_you', EatMeGlyph.shieldCheck),
        ('benefit_plan_week', EatMeGlyph.calendarDays),
        ('benefit_less_admin', EatMeGlyph.refrigerator),
      ])
        _BenefitRow(label: context.t(benefit.$1), icon: benefit.$2),
      const SizedBox(height: 20),
      if (packages.isEmpty && widget.illustrativePrices.isEmpty)
        StatusNote(text: context.t('no_offerings')),
      for (final price in widget.illustrativePrices)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InformationPanel(
            tinted: price.savingsPercent != null,
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  price.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (price.savingsPercent != null) ...[
                  const SizedBox(height: 8),
                  StatusBadge(
                    label: context.t('save_percent', {
                      'percent': price.savingsPercent!,
                    }),
                    icon: EatMeGlyph.sparkles,
                    emphasis: true,
                  ),
                ],
                const SizedBox(height: 12),
                Text('${price.price} · ${price.period}'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {},
                  child: Text(context.t('try_eatme_plus')),
                ),
              ],
            ),
          ),
        ),
      for (final package in packages)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InformationPanel(
            tinted: package.packageType == PackageType.annual,
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  package.storeProduct.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (package.packageType == PackageType.annual) ...[
                  const SizedBox(height: 8),
                  StatusBadge(
                    label: annualSavings(package) == null
                        ? context.t('recommended_value')
                        : context.t('save_percent', {
                            'percent': annualSavings(package) ?? 0,
                          }),
                    icon: EatMeGlyph.sparkles,
                    emphasis: true,
                  ),
                ],
                const SizedBox(height: 10),
                Text(package.storeProduct.description),
                const SizedBox(height: 16),
                Text(
                  '${package.storeProduct.priceString} · '
                  '${context.t(package.packageType == PackageType.annual ? 'billing_annual' : 'billing_monthly')}',
                ),
                const SizedBox(height: 16),
                AsyncAction(
                  label: context.t('try_eatme_plus'),
                  action: () async {
                    await Purchases.purchase(PurchaseParams.package(package));
                    await verify();
                  },
                ),
              ],
            ),
          ),
        ),
      if (storeReady)
        AsyncAction(
          label: context.t('restore_purchases'),
          secondary: true,
          action: () async {
            await Purchases.restorePurchases();
            await verify();
          },
        ),
      if (managementUrl != null)
        TextButton(
          onPressed: () => launchUrl(
            Uri.parse(managementUrl!),
            mode: LaunchMode.externalApplication,
          ),
          child: Text(context.t('manage_subscription')),
        ),
      for (final link in [
        ('privacy', const String.fromEnvironment('PRIVACY_URL')),
        ('terms', const String.fromEnvironment('TERMS_URL')),
      ])
        if (link.$2.startsWith('https://'))
          TextButton(
            onPressed: () => launchUrl(
              Uri.parse(link.$2),
              mode: LaunchMode.externalApplication,
            ),
            child: Text(context.t(link.$1)),
          ),
    ]),
  );
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.label, required this.icon});
  final String label;
  final EatMeGlyph icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: EatMeIcon(
            icon,
            size: 21,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.titleMedium),
        ),
      ],
    ),
  );
}
