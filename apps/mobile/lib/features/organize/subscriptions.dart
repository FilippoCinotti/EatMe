import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api.dart';
import '../../core/localization.dart';
import '../../core/state.dart';
import '../../design_system/widgets.dart';
import 'shared.dart';

class SubscriptionsPage extends ConsumerStatefulWidget {
  const SubscriptionsPage({super.key});
  @override
  ConsumerState<SubscriptionsPage> createState() => _SubscriptionsState();
}

class _SubscriptionsState extends ResourceState<SubscriptionsPage> {
  @override
  String get path => '/entitlements';
  List<Package> packages = [];
  String? managementUrl;
  static bool configured = false;
  @override
  Future<void> load() async {
    await super.load();
    final key = defaultTargetPlatform == TargetPlatform.iOS
        ? const String.fromEnvironment('REVENUECAT_IOS_KEY')
        : const String.fromEnvironment('REVENUECAT_ANDROID_KEY');
    if (data?['configured'] != true || key.isEmpty || EatMeApi.development)
      return;
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
      if (mounted)
        setState(() {
          packages = offerings.current?.availablePackages ?? [];
          managementUrl = customer.managementURL;
        });
    } catch (_) {
      if (mounted) setState(() => error = 'store_unavailable');
    }
  }

  Future<void> verify() async {
    await ref.read(apiProvider).request('POST', '/entitlements/refresh');
    await load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.t('subscriptions'))),
    body: content([
      Text(
        context.t('your_membership'),
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      StatusNote(text: context.t('subscription_notice')),
      if (packages.isEmpty) StatusNote(text: context.t('no_offerings')),
      for (final package in packages)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  package.storeProduct.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(package.storeProduct.description),
                const SizedBox(height: 16),
                Text(
                  '${package.storeProduct.priceString} · ${package.packageType.name}',
                ),
                const SizedBox(height: 16),
                AsyncAction(
                  label: context.t('subscribe'),
                  action: () async {
                    await Purchases.purchase(PurchaseParams.package(package));
                    await verify();
                  },
                ),
              ],
            ),
          ),
        ),
      if (configured)
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
