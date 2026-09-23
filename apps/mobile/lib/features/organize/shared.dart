import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api.dart';
import '../../core/localization.dart';
import '../../core/models.dart';
import '../../core/state.dart';
import '../../design_system/widgets.dart';

List<Json> records(dynamic value) => (value as List? ?? [])
    .map((v) => Map<String, dynamic>.from(v as Map))
    .toList();
String labelOf(dynamic value, BuildContext context) => value is Map
    ? localized(Map<String, dynamic>.from(value), context.language)
    : '$value';
String isoDay(DateTime date) => date.toIso8601String().substring(0, 10);

abstract class ResourceState<T extends ConsumerStatefulWidget>
    extends ConsumerState<T> {
  String get path;
  Json? data;
  String? error;
  final mutation = Mutation();
  bool updating = false;
  Future<void> guard(Future<void> Function() action) async {
    try {
      await action();
    } on ApiFailure catch (e) {
      if (mounted) setState(() => error = e.code);
    }
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(load);
  }

  Future<void> load() async {
    try {
      final value = await ref.read(apiProvider).request('GET', path);
      if (mounted && context.mounted) {
        setState(() {
          data = value;
          error = null;
        });
      }
    } on ApiFailure catch (e) {
      if (mounted && context.mounted) setState(() => error = e.code);
    }
  }

  Future<Json> command(Json body) async {
    if (updating) throw const ApiFailure('operation_in_progress');
    updating = true;
    try {
      final value = await mutation.send(
        ref.read(apiProvider),
        'POST',
        path,
        body,
      );
      await load();
      if (mounted && value['queued'] == true) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.t('queued_offline'))));
      }
      return value;
    } finally {
      updating = false;
    }
  }

  Widget content(List<Widget> children) => data == null && error == null
      ? const Center(child: CircularProgressIndicator())
      : PageBody(
          onRefresh: load,
          children: [
            if (error != null) ...[
              StatusNote(text: context.t(error!), warning: true),
              AsyncAction(label: context.t('retry'), action: load),
            ],
            if (data?['_offline'] == true)
              StatusNote(text: context.t('cached_view'), warning: true),
            ...children,
          ],
        );
}

Future<String?> askText(
  BuildContext context,
  String label, {
  String initial = '',
  bool numeric = false,
}) async {
  var value = initial;
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(label),
      content: TextFormField(
        initialValue: initial,
        autofocus: true,
        maxLength: 240,
        keyboardType: numeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        onChanged: (next) => value = next,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.t('cancel')),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, value.trim()),
          child: Text(context.t('save')),
        ),
      ],
    ),
  );
  return result;
}

Future<Food?> chooseFood(BuildContext context, List<Food> foods) =>
    showModalBottomSheet<Food>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * .75,
        child: FoodPicker(foods: foods),
      ),
    );

class FoodPicker extends StatefulWidget {
  const FoodPicker({super.key, required this.foods});
  final List<Food> foods;
  @override
  State<FoodPicker> createState() => _FoodPickerState();
}

class _FoodPickerState extends State<FoodPicker> {
  String query = '';
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(20),
        child: TextField(
          autofocus: true,
          decoration: InputDecoration(labelText: context.t('search_food')),
          onChanged: (v) => setState(() => query = v.toLowerCase()),
        ),
      ),
      Expanded(
        child: ListView(
          children: [
            for (final food in widget.foods.where(
              (f) => localized(
                f.name,
                context.language,
              ).toLowerCase().contains(query),
            ))
              ListTile(
                leading: FoodMark(food: food),
                title: Text(localized(food.name, context.language)),
                subtitle: Text(
                  '${context.t('food_group_${food.group}')} · ${food.unit}',
                ),
                onTap: () => Navigator.pop(context, food),
              ),
          ],
        ),
      ),
    ],
  );
}

Future<List<String>?> chooseDiners(
  BuildContext context,
  EatMeApi api,
  List<String>? initial,
) async {
  final home = await api.request('GET', '/households');
  if (!context.mounted) return null;
  final members = records(home['members']);
  final selected = (initial ?? [api.userId!]).toSet();
  return showDialog<List<String>>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, update) => AlertDialog(
        title: Text(context.t('who_is_eating')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.t('diner_consent_notice')),
              const SizedBox(height: 16),
              for (final member in members) ...[
                Builder(
                  builder: (context) {
                    final id = member['user_id'] as String;
                    final name = (member['name'] as String? ?? '').trim();
                    final blocked =
                        id != api.userId && member['share_constraints'] != 1;
                    final active = selected.contains(id);
                    final initials = name
                        .split(RegExp(r'\s+'))
                        .where((part) => part.isNotEmpty)
                        .take(2)
                        .map((part) => part.substring(0, 1).toUpperCase())
                        .join();
                    return Material(
                      color: active
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(22),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: blocked
                            ? null
                            : () => update(() {
                                if (active) {
                                  selected.remove(id);
                                } else {
                                  selected.add(id);
                                }
                              }),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              _MemberAvatar(
                                api: api,
                                mediaId: member['avatar_media_id'] as String?,
                                initials: initials,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    if (blocked)
                                      Text(
                                        context.t('sharing_not_enabled'),
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                  ],
                                ),
                              ),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: active
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: active
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(
                                            context,
                                          ).colorScheme.outlineVariant,
                                  ),
                                ),
                                child: active
                                    ? Icon(
                                        Icons.check,
                                        size: 18,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onPrimary,
                                      )
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.t('cancel')),
          ),
          TextButton(
            onPressed: selected.isEmpty
                ? null
                : () => Navigator.pop(context, selected.toList()..sort()),
            child: Text(context.t('save')),
          ),
        ],
      ),
    ),
  );
}


class _MemberAvatar extends StatelessWidget {
  const _MemberAvatar({
    required this.api,
    required this.mediaId,
    required this.initials,
  });
  final EatMeApi api;
  final String? mediaId, initials;

  @override
  Widget build(BuildContext context) {
    Widget fallback() => CircleAvatar(
      radius: 22,
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: Text(
        (initials == null || initials!.isEmpty) ? '•' : initials!,
        style: Theme.of(context).textTheme.labelLarge,
      ),
    );
    if (mediaId == null) return fallback();
    return FutureBuilder<Json>(
      future: api.request('GET', '/media/$mediaId'),
      builder: (context, snapshot) {
        final encoded = snapshot.data?['base64'] as String?;
        if (encoded == null) return fallback();
        return ClipOval(
          child: Image.memory(
            base64Decode(encoded),
            width: 44,
            height: 44,
            fit: BoxFit.cover,
          ),
        );
      },
    );
  }
}
