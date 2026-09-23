import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/api.dart';
import '../../core/localization.dart';
import '../../core/models.dart';
import '../../core/state.dart';
import '../../design_system/widgets.dart';
import 'shared.dart';
import 'photo_acquisition.dart';
import '../fridge/custom_food.dart';

class ScanningPage extends ConsumerStatefulWidget {
  const ScanningPage({super.key});
  @override
  ConsumerState<ScanningPage> createState() => _ScanningState();
}

class _ScanningState extends ResourceState<ScanningPage> {
  @override
  String get path => '/jobs';
  Timer? timer;
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (records(
        data?['items'],
      ).any((j) => ['queued', 'processing'].contains(j['status']))) {
        load();
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<bool> consent() async {
    final api = ref.read(apiProvider);
    final prefs = await api.request('GET', '/preferences');
    if (prefs['data']['ai_consent'] == true) return true;
    if (!mounted) return false;
    final agreed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.t('ai_consent_title')),
        content: Text(context.t('ai_consent_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.t('agree')),
          ),
        ],
      ),
    );
    if (agreed != true) return false;
    await Mutation().send(api, 'POST', '/preferences', {
      'expected_version': prefs['version'],
      'data': {
        ...Map<String, dynamic>.from(prefs['data'] as Map),
        'ai_consent': true,
      },
    });
    return true;
  }

  Future<void> chooseSource(String kind) async {
    if (!await consent() || !mounted || !context.mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => PhotoAcquisitionPage(
          kind: kind,
          onConfirm: (file) => scanFile(kind, file),
        ),
      ),
    );
    await load();
  }

  Future<void> scanFile(String kind, XFile picked) async {
    final image = await ref
        .read(apiProvider)
        .request(
          'POST',
          '/media',
          body: {
            'kind': kind == 'recipe' ? 'photo' : kind,
            'base64': base64Encode(await picked.readAsBytes()),
          },
        );
    await command({'action': 'create', 'kind': kind, 'media_id': image['id']});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: EatMeAppBar(title: Text(context.t('scan_and_import'))),
    body: content([
      Text(
        context.t('less_typing'),
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      StatusNote(text: context.t('scan_review_notice')),
      AsyncAction(
        label: context.t('scan_barcode'),
        action: () async {
          await context.push('/barcode');
        },
      ),
      const SizedBox(height: 8),
      AsyncAction(
        label: context.t('food_photo'),
        secondary: true,
        action: () => chooseSource('photo'),
      ),
      const SizedBox(height: 8),
      AsyncAction(
        label: context.t('receipt_photo'),
        secondary: true,
        action: () => chooseSource('receipt'),
      ),
      const SizedBox(height: 8),
      AsyncAction(
        label: context.t('generate_recipe'),
        secondary: true,
        action: () async {
          if (!await consent() || !mounted || !context.mounted) return;
          final prompt = await askText(context, context.t('recipe_idea'));
          if (prompt != null) {
            await command({
              'action': 'create',
              'kind': 'recipe',
              'text': prompt,
            });
          }
        },
      ),
      const SizedBox(height: 8),
      AsyncAction(
        label: context.t('recipe_photo'),
        secondary: true,
        action: () => chooseSource('recipe'),
      ),
      const SizedBox(height: 28),
      for (final job in records(data?['items']))
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t('job_${job['kind']}'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(context.t('job_${job['status']}')),
                if (['queued', 'processing'].contains(job['status'])) ...[
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: (job['progress'] as num).toDouble() / 100,
                  ),
                  AsyncAction(
                    label: context.t('cancel'),
                    secondary: true,
                    action: () async {
                      await command({'action': 'cancel', 'id': job['id']});
                    },
                  ),
                ],
                if (job['error_code'] != null)
                  StatusNote(
                    text: context.t(job['error_code'] as String),
                    warning: true,
                  ),
                if (job['result']?['development_fixture'] == true)
                  StatusNote(
                    text: context.t('development_fixture'),
                    warning: true,
                  ),
                if (job['status'] == 'completed' && job['confirmed_at'] == null)
                  AsyncAction(
                    label: context.t('review_results'),
                    action: () async {
                      if (job['kind'] == 'recipe') {
                        await context.push(
                          '/recipe-editor',
                          extra: Map<String, dynamic>.from(
                            job['result'] as Map,
                          ),
                        );
                      } else {
                        await Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DetectionReviewPage(job: job),
                          ),
                        );
                      }
                      await load();
                    },
                  ),
              ],
            ),
          ),
        ),
    ]),
  );
}

class DetectionReviewPage extends ConsumerStatefulWidget {
  const DetectionReviewPage({super.key, required this.job});
  final Json job;
  @override
  ConsumerState<DetectionReviewPage> createState() => _DetectionState();
}

class _DetectionState extends ConsumerState<DetectionReviewPage> {
  late List<Json> items;
  Future<Json>? preview;
  final mutation = Mutation();
  @override
  void initState() {
    super.initState();
    items = records(
      widget.job['result']['items'],
    ).map((i) => {...i, 'confirmed': i['food_id'] != null}).toList();
    final mediaId = widget.job['media_id'] as String?;
    if (mediaId != null) {
      preview = ref.read(apiProvider).request('GET', '/media/$mediaId');
    }
  }

  @override
  Widget build(BuildContext context) {
    final foods = ref.watch(appProvider).foods;
    return Scaffold(
      appBar: EatMeAppBar(title: Text(context.t('review_results'))),
      body: PageBody(
        children: [
          StatusNote(text: context.t('scan_review_notice')),
          if (preview != null) ...[
            FutureBuilder<Json>(
              future: preview,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                final encoded = snapshot.data!['base64'] as String?;
                if (encoded == null || encoded.isEmpty) {
                  return const SizedBox.shrink();
                }
                return ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.memory(
                    base64Decode(encoded),
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
          for (final item in items)
            Card(
              key: ObjectKey(item),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item['name'] as String),
                      subtitle: Text(
                        context.t('estimated_confidence', {
                          'value': ((item['confidence'] as num) * 100).round(),
                        }),
                      ),
                      trailing: IconButton(
                        tooltip: context.t('delete'),
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => items.remove(item)),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () async {
                        final food = await chooseFood(
                          context,
                          foods
                              .where((food) => food.group != 'packaged')
                              .toList(),
                        );
                        if (food != null && mounted) {
                          setState(() {
                            item['food_id'] = food.id;
                            item['unit'] = food.unit;
                            item['confirmed'] = true;
                          });
                        }
                      },
                      child: Text(
                        foods
                                .where((f) => f.id == item['food_id'])
                                .map(
                                  (f) => localized(f.name, context.language),
                                )
                                .firstOrNull ??
                            context.t('choose_food'),
                      ),
                    ),
                    TextFormField(
                      initialValue: '${item['quantity'] ?? ''}',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText:
                            '${context.t('quantity')} (${item['unit'] ?? ''})',
                      ),
                      onChanged: (v) {
                        item['quantity'] = v.replaceAll(',', '.');
                      },
                    ),
                    StorageDateFields(
                      location: item['location'] as String? ?? 'fridge',
                      date: DateTime.tryParse(
                        item['expiry_date'] as String? ?? '',
                      ),
                      kind: item['expiry_kind'] == 'unknown'
                          ? 'estimated'
                          : item['expiry_kind'] as String? ?? 'estimated',
                      onChanged: (l, d, k) {
                        if (mounted) {
                          setState(() {
                            item['location'] = l;
                            item['expiry_date'] = d == null ? null : isoDay(d);
                            item['expiry_kind'] = d == null
                                ? 'unknown'
                                : k == 'unknown'
                                ? 'estimated'
                                : k;
                          });
                        }
                      },
                    ),
                    if (item['food_id'] == null)
                      StatusNote(
                        text: context.t('choose_food_before_confirming'),
                        warning: true,
                      ),
                  ],
                ),
              ),
            ),
          AsyncAction(
            label: context.t('add_confirmed_to_fridge'),
            enabled:
                items.isNotEmpty && items.every((i) => i['confirmed'] == true),
            action: () async {
              await mutation.send(ref.read(apiProvider), 'POST', '/jobs', {
                'action': 'confirm',
                'id': widget.job['id'],
                'items': items,
              });
              await ref.read(appProvider.notifier).refresh();
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

class BarcodePage extends ConsumerStatefulWidget {
  const BarcodePage({super.key});
  @override
  ConsumerState<BarcodePage> createState() => _BarcodeState();
}

class _BarcodeState extends ConsumerState<BarcodePage> {
  final controller = MobileScannerController(
    formats: [BarcodeFormat.ean13, BarcodeFormat.ean8, BarcodeFormat.upcA],
  );
  final code = TextEditingController();
  bool busy = false;
  Json? product;
  Food? classification;
  String? error;
  @override
  void dispose() {
    controller.dispose();
    code.dispose();
    super.dispose();
  }

  Future<void> lookup(String value) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await controller.stop();
      final result = await ref
          .read(apiProvider)
          .request('GET', '/products/${Uri.encodeComponent(value)}');
      final mappedId = result['mapped_food_id'] as String?;
      final mappedFood = ref
          .read(appProvider)
          .foods
          .where((food) => food.id == mappedId && food.group != 'packaged')
          .firstOrNull;
      if (mounted && context.mounted) {
        setState(() {
          product = result;
          classification = mappedFood;
        });
      }
    } on ApiFailure catch (e) {
      if (mounted && context.mounted) setState(() => error = e.code);
    } finally {
      if (mounted && context.mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: EatMeAppBar(title: Text(context.t('scan_barcode'))),
    body: PageBody(
      children: [
        if (product == null)
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: SizedBox(
              height: 240,
              child: MobileScanner(
                controller: controller,
                onDetect: (capture) {
                  final value = capture.barcodes.firstOrNull?.rawValue;
                  if (value != null) lookup(value);
                },
              ),
            ),
          ),
        Wrap(
          spacing: 8,
          children: [
            AsyncAction(
              label: context.t('toggle_torch'),
              secondary: true,
              action: () => controller.toggleTorch(),
            ),
            AsyncAction(
              label: context.t('scan_again'),
              secondary: true,
              enabled: !busy,
              action: () async {
                setState(() {
                  product = null;
                  classification = null;
                  error = null;
                });
                await controller.start();
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: code,
          keyboardType: TextInputType.number,
          maxLength: 14,
          decoration: InputDecoration(labelText: context.t('barcode')),
        ),
        AsyncAction(
          label: context.t('look_up_product'),
          enabled: !busy,
          action: () => lookup(code.text.trim()),
        ),
        if (error != null) StatusNote(text: context.t(error!), warning: true),
        if (product != null) ...[
          Text(
            product!['name'] as String,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          Text(product!['brand'] as String),
          StatusNote(text: context.t('verify_package')),
          Text(product!['ingredients_text'] as String),
          for (final entry in (product!['nutrition']['values'] as Map).entries)
            ListTile(
              title: Text(context.t('nutrient_${entry.key}')),
              trailing: Text('${entry.value['value']} ${entry.value['unit']}'),
            ),
          Text(
            '${product!['nutrition']['basis']} · ${product!['attribution']}',
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () async {
              final food = await chooseFood(
                context,
                ref
                    .read(appProvider)
                    .foods
                    .where((item) => item.group != 'packaged')
                    .toList(),
              );
              if (food != null && mounted) {
                setState(() => classification = food);
              }
            },
            child: Text(
              classification == null
                  ? context.t('classify_product')
                  : localized(classification!.name, context.language),
            ),
          ),
          if (classification == null)
            StatusNote(
              text: context.t('product_family_required'),
              warning: true,
            ),
          AsyncAction(
            label: context.t('map_product_to_food'),
            enabled: classification != null,
            action: () async {
              final amount = await askText(
                context,
                context.t('package_count'),
                initial: '1',
                numeric: true,
              );
              if (amount == null) return;
              await Mutation()
                  .send(ref.read(apiProvider), 'POST', '/products/stock', {
                    'product_id': product!['id'],
                    'food_id': classification!.id,
                    'quantity': amount,
                    'package_checked': true,
                  });
              await ref.read(appProvider.notifier).refresh();
              if (context.mounted) context.pop();
            },
          ),
        ],
      ],
    ),
  );
}
