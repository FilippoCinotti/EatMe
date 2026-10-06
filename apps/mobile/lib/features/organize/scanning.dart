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

String mediaKindForScan(String jobKind) => jobKind == 'receipt' ? 'receipt' : 'photo';

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
            'kind': mediaKindForScan(kind),
            'base64': base64Encode(await picked.readAsBytes()),
          },
        );
    await command({'action': 'create', 'kind': kind, 'media_id': image['id']});
  }

  Future<void> openSmartCapture() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => SmartCapturePage(
          onPhoto: (file) async {
            if (!await consent()) return false;
            await scanFile('auto', file);
            return true;
          },
        ),
      ),
    );
    await load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: EatMeAppBar(title: Text(context.t('scan_and_import'))),
    body: content([
      Text(
        context.t('less_typing'),
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 6),
      Text(
        context.t('smart_capture_body'),
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 18),
      AsyncAction(
        label: context.t('smart_capture_action'),
        action: openSmartCapture,
      ),
      const SizedBox(height: 10),
      StatusNote(text: context.t('scan_review_notice')),
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

class SmartCapturePage extends StatefulWidget {
  const SmartCapturePage({super.key, required this.onPhoto, this.picker});

  final Future<bool> Function(XFile file) onPhoto;
  final PhotoPicker? picker;

  @override
  State<SmartCapturePage> createState() => _SmartCapturePageState();
}

class _SmartCapturePageState extends State<SmartCapturePage> {
  final controller = MobileScannerController(
    formats: [BarcodeFormat.ean13, BarcodeFormat.ean8, BarcodeFormat.upcA],
  );
  bool busy = false;
  String? error;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> openBarcode(String value) async {
    if (busy || value.isEmpty) return;
    setState(() => busy = true);
    await controller.stop();
    if (mounted) {
      await context.push('/barcode?code=${Uri.encodeQueryComponent(value)}');
    }
    if (mounted) {
      setState(() => busy = false);
      await controller.start();
    }
  }

  Future<void> pick(ImageSource source) async {
    if (busy) return;
    var shouldRestart = true;
    setState(() {
      busy = true;
      error = null;
    });
    await controller.stop();
    try {
      final file =
          await (widget.picker?.call(source) ??
              ImagePicker().pickImage(
                source: source,
                imageQuality: 85,
                maxWidth: 2048,
                maxHeight: 2048,
                requestFullMetadata: false,
              ));
      if (file == null) return;
      if (await file.length() == 0) {
        if (mounted) setState(() => error = 'photo_unavailable');
        return;
      }
      final completed = await widget.onPhoto(file);
      if (completed && mounted) {
        shouldRestart = false;
        Navigator.pop(context);
      }
    } on ApiFailure catch (failure) {
      if (mounted) setState(() => error = failure.code);
    } catch (_) {
      if (mounted) setState(() => error = 'photo_unavailable');
    } finally {
      if (mounted) {
        setState(() => busy = false);
        if (shouldRestart) await controller.start();
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: EatMeAppBar(title: Text(context.t('smart_capture_title'))),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MobileScanner(
                      controller: controller,
                      onDetect: (capture) {
                        final value = capture.barcodes.firstOrNull?.rawValue;
                        if (value != null) openBarcode(value);
                      },
                    ),
                    IgnorePointer(
                      child: Container(
                        margin: const EdgeInsets.all(34),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.white.withValues(alpha: .78),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                    ),
                    if (busy)
                      ColoredBox(
                        color: Colors.black.withValues(alpha: .62),
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.t('smart_capture_hint'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              StatusNote(text: context.t(error!), warning: true),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : () => pick(ImageSource.gallery),
                    icon: const EatMeIcon(EatMeGlyph.image, size: 20),
                    label: Text(context.t('gallery')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: busy ? null : () => pick(ImageSource.camera),
                    icon: const EatMeIcon(EatMeGlyph.camera, size: 20),
                    label: Text(context.t('take_photo')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
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
  bool reviewed = false;
  late DateTime purchased;
  final mutation = Mutation();
  @override
  void initState() {
    super.initState();
    items = records(
      widget.job['result']['items'],
    ).map((i) => {...i, 'confirmed': false}).toList();
    purchased =
        DateTime.tryParse('${widget.job['created_at']}') ?? DateTime.now();
    for (final item in items) {
      estimate(item);
    }
    final mediaId = widget.job['media_id'] as String?;
    if (mediaId != null) {
      preview = ref.read(apiProvider).request('GET', '/media/$mediaId');
    }
  }

  void estimate(Json item) {
    item['purchase_date'] = isoDay(purchased);
    final food = ref
        .read(appProvider)
        .foods
        .where((f) => f.id == item['food_id'])
        .firstOrNull;
    if (item['expiry_date'] == null || item['automatic_expiry'] == true) {
      final date = food?.estimatedExpiry(
        item['location'] as String? ?? 'fridge',
        purchased,
      );
      item['expiry_date'] = date == null ? null : isoDay(date);
      item['expiry_kind'] = date == null ? 'unknown' : 'estimated';
      item['automatic_expiry'] = true;
    }
  }

  bool valid(Json item) {
    final value = double.tryParse('${item['quantity']}');
    return item['food_id'] != null &&
        value != null &&
        value.isFinite &&
        value > 0 &&
        (item['unit'] != 'pcs' || value == value.roundToDouble());
  }

  @override
  Widget build(BuildContext context) {
    final foods = ref.watch(appProvider).foods;
    return Scaffold(
      appBar: EatMeAppBar(title: Text(context.t('review_results'))),
      body: PageBody(
        children: [
          StatusNote(text: context.t('scan_review_notice')),
          if (widget.job['result']['detected_type'] != null)
            StatusBadge(
              label: context.t(
                widget.job['result']['detected_type'] == 'receipt'
                    ? 'recognized_receipt'
                    : 'recognized_food_photo',
              ),
              icon: widget.job['result']['detected_type'] == 'receipt'
                  ? EatMeGlyph.fileText
                  : EatMeGlyph.camera,
            ),
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
          ListTile(
            leading: const Icon(Icons.shopping_bag_outlined),
            title: Text(context.t('purchase_date')),
            subtitle: Text(context.displayDate(purchased)),
            trailing: const Icon(Icons.edit_calendar_outlined),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: purchased,
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
              );
              if (date != null && mounted) {
                setState(() {
                  purchased = date;
                  reviewed = false;
                  for (final item in items) {
                    estimate(item);
                  }
                });
              }
            },
          ),
          for (final item in items)
            Builder(
              builder: (context) {
                final food = foods
                    .where((f) => f.id == item['food_id'])
                    .firstOrNull;
                final attention =
                    !valid(item) || ((item['confidence'] as num?) ?? 0) < .85;
                return Card(
                  key: ObjectKey(item),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: attention
                          ? Theme.of(context).colorScheme.error
                          : Colors.transparent,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            FoodImage(
                              id: food?.id ?? '',
                              imageUrl: food?.imageUrl,
                              photoId: food?.photoId,
                              height: 52,
                              width: 52,
                              radius: 12,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    food == null
                                        ? context.t('choose_food')
                                        : localized(
                                            food.name,
                                            context.language,
                                          ),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  if (attention)
                                    Text(
                                      context.t('review_attention'),
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.error,
                                      ),
                                    ),
                                  if (item['expiry_date'] != null)
                                    Text(
                                      '${context.t(item['expiry_kind'] == 'estimated' ? 'expiry_estimated' : 'expiry_date')}: ${context.displayDate(item['expiry_date'])}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: context.t('delete'),
                              icon: const Icon(Icons.close),
                              onPressed: () => setState(() {
                                items.remove(item);
                                reviewed = false;
                              }),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                key: ValueKey(
                                  '${item['food_id']}:${item['unit']}',
                                ),
                                initialValue: '${item['quantity'] ?? ''}',
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: InputDecoration(
                                  labelText: context.t('quantity'),
                                  suffixText: food?.unit ?? '',
                                  helperText: context.t(
                                    'quantity_estimate_review',
                                  ),
                                  isDense: true,
                                ),
                                onChanged: (v) => setState(() {
                                  item['quantity'] = v.replaceAll(',', '.');
                                  reviewed = false;
                                }),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              tooltip: context.t('choose_food'),
                              icon: const Icon(Icons.swap_horiz),
                              onPressed: () async {
                                final chosen = await chooseFood(
                                  context,
                                  foods
                                      .where((f) => f.group != 'packaged')
                                      .toList(),
                                );
                                if (chosen != null && mounted) {
                                  setState(() {
                                    item['food_id'] = chosen.id;
                                    item['unit'] = chosen.unit;
                                    item['quantity'] = null;
                                    item['confidence'] = 1.0;
                                    item['automatic_expiry'] = true;
                                    reviewed = false;
                                    estimate(item);
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(
                            context.t(item['location'] as String? ?? 'fridge'),
                          ),
                          subtitle: Text(context.t('storage_and_date')),
                          children: [
                            StorageDateFields(
                              location: item['location'] as String? ?? 'fridge',
                              date: DateTime.tryParse(
                                item['expiry_date'] as String? ?? '',
                              ),
                              kind: item['expiry_kind'] as String? ?? 'unknown',
                              onChanged: (l, d, k) => setState(() {
                                final changedLocation = item['location'] != l;
                                item['location'] = l;
                                reviewed = false;
                                if (changedLocation &&
                                    item['automatic_expiry'] == true) {
                                  estimate(item);
                                } else {
                                  item['expiry_date'] = d == null
                                      ? null
                                      : isoDay(d);
                                  item['expiry_kind'] = d == null
                                      ? 'unknown'
                                      : k;
                                  item['automatic_expiry'] = false;
                                }
                              }),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          CheckboxListTile(
            value: reviewed,
            onChanged: items.isNotEmpty && items.every(valid)
                ? (v) => setState(() => reviewed = v == true)
                : null,
            title: Text(context.t('confirm_identification_and_family')),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          AsyncAction(
            label: context.t('add_confirmed_to_fridge'),
            enabled: items.isNotEmpty && reviewed && items.every(valid),
            action: () async {
              await mutation.send(ref.read(apiProvider), 'POST', '/jobs', {
                'action': 'confirm',
                'id': widget.job['id'],
                'items': items
                    .map((item) => {...item, 'confirmed': true})
                    .toList(),
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
  const BarcodePage({super.key, this.initialCode});
  final String? initialCode;
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
  void initState() {
    super.initState();
    final initial = widget.initialCode;
    if (initial != null && initial.isNotEmpty) {
      code.text = initial;
      WidgetsBinding.instance.addPostFrameCallback((_) => lookup(initial));
    }
  }

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
