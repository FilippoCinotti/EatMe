import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api.dart';
import '../../core/localization.dart';
import '../../core/models.dart';
import '../../core/state.dart';
import '../../design_system/widgets.dart';
import '../organize/shared.dart';

class BatchDetailsPage extends ConsumerStatefulWidget {
  const BatchDetailsPage({super.key, required this.batch});
  final Batch batch;
  @override
  ConsumerState<BatchDetailsPage> createState() => _BatchDetailsState();
}

class _BatchDetailsState extends ConsumerState<BatchDetailsPage> {
  final mutation = Mutation();
  late final lot = TextEditingController(
    text: '${widget.batch.metadata['lot'] ?? ''}',
  );
  late final code = TextEditingController(
    text: '${widget.batch.metadata['barcode'] ?? ''}',
  );
  late final cost = TextEditingController(
    text: '${widget.batch.metadata['cost'] ?? ''}',
  );
  late final notes = TextEditingController(
    text: '${widget.batch.metadata['notes'] ?? ''}',
  );
  late String currency = widget.batch.metadata['currency'] as String? ?? 'EUR';
  late String kind = widget.batch.expiryKind;
  late DateTime? expiry = widget.batch.expiryDate;
  late DateTime? purchased = DateTime.tryParse(
    '${widget.batch.metadata['purchase_date'] ?? ''}',
  );
  @override
  void dispose() {
    for (final controller in [lot, code, cost, notes]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<DateTime?> date(DateTime? initial) => showDatePicker(
    context: context,
    initialDate: initial ?? DateTime.now(),
    firstDate: DateTime(2000),
    lastDate: DateTime(2100),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.t('edit_batch_details'))),
    body: PageBody(
      children: [
        Text(
          localized(widget.batch.food.name, context.language),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 20),
        DropdownButtonFormField<String>(
          initialValue: kind,
          decoration: InputDecoration(labelText: context.t('expiry_kind')),
          items: ['unknown', 'use_by', 'best_before', 'estimated']
              .map(
                (value) => DropdownMenuItem(
                  value: value,
                  child: Text(context.t('expiry_$value')),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() {
            kind = value!;
            if (kind == 'unknown') expiry = null;
          }),
        ),
        const SizedBox(height: 12),
        AsyncAction(
          label: expiry == null ? context.t('expiry_date') : isoDay(expiry!),
          secondary: true,
          enabled: kind != 'unknown',
          action: () async {
            final value = await date(expiry);
            if (value != null && mounted) setState(() => expiry = value);
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: lot,
          maxLength: 100,
          decoration: InputDecoration(labelText: context.t('lot_number')),
        ),
        TextField(
          controller: code,
          maxLength: 14,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: context.t('barcode')),
        ),
        AsyncAction(
          label:
              '${context.t('purchase_date')}: ${purchased == null ? '—' : isoDay(purchased!)}',
          secondary: true,
          action: () async {
            final value = await date(purchased);
            if (value != null && mounted) setState(() => purchased = value);
          },
        ),
        if (purchased != null)
          TextButton(
            onPressed: () => setState(() => purchased = null),
            child: Text(context.t('clear_date')),
          ),
        const SizedBox(height: 12),
        TextField(
          controller: cost,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: context.t('purchase_cost')),
        ),
        DropdownButtonFormField<String>(
          initialValue: currency,
          items: ['EUR', 'USD', 'GBP', 'CHF']
              .map(
                (value) => DropdownMenuItem(value: value, child: Text(value)),
              )
              .toList(),
          onChanged: (value) => setState(() => currency = value!),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: notes,
          maxLength: 500,
          maxLines: 3,
          decoration: InputDecoration(labelText: context.t('notes')),
        ),
        const SizedBox(height: 24),
        AsyncAction(
          label: context.t('save'),
          action: () async {
            await mutation.send(
              ref.read(apiProvider),
              'POST',
              '/inventory/metadata',
              {
                'id': widget.batch.id,
                'expected_version': widget.batch.version,
                'expiry_kind': kind,
                'expiry_date': expiry == null ? null : isoDay(expiry!),
                'metadata': {
                  'lot': lot.text.trim(),
                  'barcode': code.text.trim(),
                  'notes': notes.text.trim(),
                  if (purchased != null) 'purchase_date': isoDay(purchased!),
                  if (cost.text.trim().isNotEmpty) ...{
                    'cost': cost.text.trim().replaceAll(',', '.'),
                    'currency': currency,
                  },
                  if (widget.batch.metadata['product_id'] != null)
                    'product_id': widget.batch.metadata['product_id'],
                },
              },
            );
            await ref.read(appProvider.notifier).refresh();
            if (context.mounted) Navigator.pop(context);
          },
        ),
      ],
    ),
  );
}
