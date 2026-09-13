import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api.dart';
import '../../core/localization.dart';
import '../../core/state.dart';
import '../../design_system/widgets.dart';
import '../organize/shared.dart';

class CustomFoodPage extends ConsumerStatefulWidget {
  const CustomFoodPage({super.key});
  @override
  ConsumerState<CustomFoodPage> createState() => _CustomFoodState();
}

class _CustomFoodState extends ConsumerState<CustomFoodPage> {
  final name = TextEditingController(),
      amount = TextEditingController(text: '1'),
      notes = TextEditingController();
  final form = GlobalKey<FormState>();
  final mutation = Mutation();
  String group = 'other',
      unit = 'pcs',
      location = 'fridge',
      kind = 'best_before';
  DateTime? date;
  Uint8List? photo;
  String? mediaId;
  bool saved = false;
  @override
  void dispose() {
    name.dispose();
    amount.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> choosePhoto(ImageSource source) async {
    final image = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (mounted)
      {
      setState(() {
        photo = bytes;
        mediaId = null;
      });
      }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.t('custom_food'))),
    body: Form(
      key: form,
      child: PageBody(
        children: [
          StatusNote(text: context.t('custom_food_notice')),
          if (photo != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.memory(photo!, height: 180, fit: BoxFit.cover),
            ),
          Wrap(
            spacing: 8,
            children: [
              AsyncAction(
                label: context.t('take_photo'),
                secondary: true,
                action: () => choosePhoto(ImageSource.camera),
              ),
              AsyncAction(
                label: context.t('choose_photo'),
                secondary: true,
                action: () => choosePhoto(ImageSource.gallery),
              ),
              if (photo != null)
                TextButton(
                  onPressed: () => setState(() {
                    photo = null;
                    mediaId = null;
                  }),
                  child: Text(context.t('remove_photo')),
                ),
            ],
          ),
          TextFormField(
            controller: name,
            maxLength: 100,
            decoration: InputDecoration(labelText: context.t('food_name')),
            validator: (v) => v == null || v.trim().isEmpty
                ? context.t('required_field')
                : null,
          ),
          DropdownButtonFormField<String>(
            initialValue: group,
            decoration: InputDecoration(labelText: context.t('category')),
            items:
                [
                      'vegetable',
                      'fruit',
                      'legume',
                      'grain',
                      'oil',
                      'dairy',
                      'meat',
                      'egg',
                      'fish',
                      'nuts',
                      'seed',
                      'herb',
                      'packaged',
                      'other',
                    ]
                    .map(
                      (g) => DropdownMenuItem(
                        value: g,
                        child: Text(context.t('food_group_$g')),
                      ),
                    )
                    .toList(),
            onChanged: (v) => setState(() => group = v!),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: context.t('quantity')),
            validator: (v) {
              final n = double.tryParse((v ?? '').replaceAll(',', '.'));
              return n == null ||
                      !n.isFinite ||
                      n <= 0 ||
                      (unit == 'pcs' && n != n.roundToDouble())
                  ? context.t('invalid_quantity')
                  : null;
            },
          ),
          DropdownButtonFormField<String>(
            initialValue: unit,
            decoration: InputDecoration(labelText: context.t('unit')),
            items: [
              'pcs',
              'g',
              'ml',
            ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (v) => setState(() => unit = v!),
          ),
          StorageDateFields(
            location: location,
            date: date,
            kind: kind,
            onChanged: (l, d, k) => setState(() {
              location = l;
              date = d;
              kind = k;
            }),
          ),
          TextField(
            controller: notes,
            maxLength: 500,
            maxLines: 3,
            decoration: InputDecoration(labelText: context.t('notes')),
          ),
          AsyncAction(
            label: context.t('add_to_fridge'),
            action: () async {
              if (saved) {
                await ref.read(appProvider.notifier).hydrate();
                if (context.mounted) Navigator.pop(context);
                return;
              }
              if (!form.currentState!.validate()) return;
              final api = ref.read(apiProvider);
              if (photo != null && mediaId == null) {
                final media = await api.request(
                  'POST',
                  '/media',
                  body: {'kind': 'food', 'base64': base64Encode(photo!)},
                );
                mediaId = media['id'] as String;
              }
              await mutation.send(api, 'POST', '/foods', {
                'action': 'create',
                'name': name.text.trim(),
                'group': group,
                'unit': unit,
                'quantity': amount.text.trim().replaceAll(',', '.'),
                'location': location,
                'expiry_date': date == null ? null : isoDay(date!),
                'expiry_kind': date == null ? 'unknown' : kind,
                'notes': notes.text.trim(),
                if (mediaId != null) 'media_id': mediaId,
              });
              saved = true;
              await ref.read(appProvider.notifier).hydrate();
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
    ),
  );
}

/// Reused by manual entry and scan review; dates retain their declared meaning.
class StorageDateFields extends StatelessWidget {
  const StorageDateFields({
    super.key,
    required this.location,
    required this.date,
    required this.kind,
    required this.onChanged,
  });
  final String location, kind;
  final DateTime? date;
  final void Function(String, DateTime?, String) onChanged;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(
        initialValue: location,
        decoration: InputDecoration(labelText: context.t('storage')),
        items: ['fridge', 'freezer', 'pantry']
            .map((v) => DropdownMenuItem(value: v, child: Text(context.t(v))))
            .toList(),
        onChanged: (v) => onChanged(v!, date, kind),
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(context.t('package_date')),
        subtitle: Text(
          date == null
              ? context.t('optional')
              : MaterialLocalizations.of(context).formatCompactDate(date!),
        ),
        trailing: const Icon(Icons.calendar_today_outlined),
        onTap: () async {
          final chosen = await showDatePicker(
            context: context,
            initialDate: date ?? DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (chosen != null) onChanged(location, chosen, kind);
        },
      ),
      if (date != null) ...[
        DropdownButtonFormField<String>(
          initialValue: kind,
          decoration: InputDecoration(labelText: context.t('date_type')),
          items: ['use_by', 'best_before', 'estimated']
              .map(
                (v) => DropdownMenuItem(
                  value: v,
                  child: Text(context.t('${v}_label')),
                ),
              )
              .toList(),
          onChanged: (v) => onChanged(location, date, v!),
        ),
        TextButton(
          onPressed: () => onChanged(location, null, kind),
          child: Text(context.t('remove_date')),
        ),
      ],
    ],
  );
}
