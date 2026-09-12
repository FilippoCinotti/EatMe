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
  final controller = TextEditingController(text: initial);
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(label),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 240,
        keyboardType: numeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.t('cancel')),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: Text(context.t('save')),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}

Future<Food?> chooseFood(BuildContext context, List<Food> foods) =>
    showModalBottomSheet<Food>(
      context: context,
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
                subtitle: Text(food.unit),
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
            children: [
              Text(context.t('diner_consent_notice')),
              for (final member in members)
                CheckboxListTile(
                  title: Text(member['name'] as String),
                  value: selected.contains(member['user_id']),
                  subtitle:
                      member['user_id'] != api.userId &&
                          member['share_constraints'] != 1
                      ? Text(context.t('sharing_not_enabled'))
                      : null,
                  onChanged:
                      member['user_id'] != api.userId &&
                          member['share_constraints'] != 1
                      ? null
                      : (value) => update(() {
                          if (value == true) {
                            selected.add(member['user_id'] as String);
                          } else {
                            selected.remove(member['user_id']);
                          }
                        }),
                ),
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
