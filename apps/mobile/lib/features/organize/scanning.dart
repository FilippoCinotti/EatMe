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
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      useSafeArea: true,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: Text(context.t('take_photo')),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(context.t('choose_photo')),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ],
      ),
    );
    if (source != null) await scan(kind, source);
  }

  Future<void> scan(String kind, ImageSource source) async {
    if (!await consent()) return;
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 2048,
      maxHeight: 2048,
    );
    if (picked == null) return;
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
    appBar: AppBar(title: Text(context.t('scan_and_import'))),
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
  final mutation = Mutation();
  @override
  void initState() {
    super.initState();
    items = records(
      widget.job['result']['items'],
    ).map((i) => {...i, 'confirmed': false}).toList();
  }

  @override
  Widget build(BuildContext context) {
    final foods = ref.watch(appProvider).foods;
    return Scaffold(
      appBar: AppBar(title: Text(context.t('review_results'))),
      body: PageBody(
        children: [
          StatusNote(text: context.t('scan_review_notice')),
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
                        final food = await chooseFood(context, foods);
                        if (food != null && mounted) {
                          setState(() {
                            item['food_id'] = food.id;
                            item['unit'] = food.unit;
                            item['confirmed'] = false;
                          });
                        }
                      },
                      child: Text(
                        foods
                                .where((f) => f.id == item['food_id'])
                                .map((f) => localized(f.name, context.language))
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
                        item['quantity'] = v;
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
                        if (mounted)
                          setState(() {
                            item['location'] = l;
                            item['expiry_date'] = d == null ? null : isoDay(d);
                            item['expiry_kind'] = d == null
                                ? 'unknown'
                                : k == 'unknown'
                                ? 'estimated'
                                : k;
                          });
                      },
                    ),
                    CheckboxListTile(
                      title: Text(context.t('confirm_identification')),
                      value: item['confirmed'] == true,
                      onChanged: item['food_id'] == null
                          ? null
                          : (v) => setState(() => item['confirmed'] = v),
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
      if (mounted && context.mounted) setState(() => product = result);
    } on ApiFailure catch (e) {
      if (mounted && context.mounted) setState(() => error = e.code);
    } finally {
      if (mounted && context.mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.t('scan_barcode'))),
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
          AsyncAction(
            label: context.t('map_product_to_food'),
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
