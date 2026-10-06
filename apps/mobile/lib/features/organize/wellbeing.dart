import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization.dart';
import '../../design_system/widgets.dart';
import 'shared.dart';

const habitGoals = [
  'eat_better',
  'waste_less',
  'follow_diet',
  'more_vegetables',
  'less_processed',
  'maintain_weight',
];

class WellbeingPage extends ConsumerStatefulWidget {
  const WellbeingPage({super.key});
  @override
  ConsumerState<WellbeingPage> createState() => _WellbeingState();
}

class _WellbeingState extends ResourceState<WellbeingPage> {
  @override
  String get path => '/wellbeing';
  Future<void> editTarget(String goal, int target) async {
    final result = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(context.t('weekly_target')),
        children: [
          for (var i = 1; i <= 7; i++)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, i),
              child: Text(context.t('days_per_week', {'count': i})),
            ),
        ],
      ),
    );
    if (result != null) {
      await command({
        'action': 'target',
        'goal': goal,
        'target': result,
        'expected_version': data!['version'],
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final goals = records(data?['goals']);
    return Scaffold(
      appBar: EatMeAppBar(title: Text(context.t('wellbeing'))),
      body: content([
        Text(
          context.t('your_goals'),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        StatusNote(text: context.t('self_reported_habits')),
        if (data != null)
          Text(
            context.t('week_starting', {
              'date': context.displayDate(data!['week_start']),
            }),
          ),
        if (goals.isEmpty)
          EmptyMessage(
            title: context.t('no_habits'),
            body: context.t('choose_habit'),
          ),
        for (final goal in goals)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t('goal_${goal['id']}'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value:
                        ((goal['completed_days'] as int) /
                                (goal['target'] as int))
                            .clamp(0.0, 1.0),
                  ),
                  Text(
                    context.t('habit_progress', {
                      'done': goal['completed_days'] as int,
                      'target': goal['target'] as int,
                    }),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: AsyncAction(
                          label: context.t(
                            goal['done_today'] == true
                                ? 'undo_today'
                                : 'done_today',
                          ),
                          icon: goal['done_today'] == true
                              ? Icons.check_circle
                              : Icons.check_circle_outline,
                          secondary: goal['done_today'] != true,
                          action: () => command({
                            'action': 'check_in',
                            'goal': goal['id'],
                            'completed': goal['done_today'] != true,
                            'expected_version': data!['version'],
                          }),
                        ),
                      ),
                      AsyncAction(
                        label: context.t('edit'),
                        icon: Icons.edit_outlined,
                        iconOnly: true,
                        action: () => editTarget(
                          goal['id'] as String,
                          goal['target'] as int,
                        ),
                      ),
                      AsyncAction(
                        label: context.t('delete'),
                        icon: Icons.delete_outline,
                        iconOnly: true,
                        action: () => command({
                          'action': 'remove',
                          'goal': goal['id'],
                          'expected_version': data!['version'],
                        }),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) => Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final goal in habitGoals.where(
                (id) => !goals.any((g) => g['id'] == id),
              ))
                SizedBox(
                  width: constraints.maxWidth < 300
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 12) / 2,
                  child: Builder(
                    builder: (context) {
                      final scheme = ColorScheme.fromSeed(
                        seedColor: [
                          Colors.teal,
                          Colors.amber,
                          Colors.indigo,
                          Colors.green,
                          Colors.deepOrange,
                          Colors.purple,
                        ][habitGoals.indexOf(goal)],
                        brightness: Theme.of(context).brightness,
                      );
                      return Card(
                        color: scheme.primaryContainer,
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: data == null
                              ? null
                              : () => editTarget(goal, 5),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  [
                                    Icons.restaurant_outlined,
                                    Icons.recycling,
                                    Icons.favorite_outline,
                                    Icons.eco_outlined,
                                    Icons.shopping_basket_outlined,
                                    Icons.balance,
                                  ][habitGoals.indexOf(goal)],
                                  size: 30,
                                  color: scheme.onPrimaryContainer,
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  context.t('goal_$goal'),
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: scheme.onPrimaryContainer,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ]),
    );
  }
}

class HouseholdActivityPage extends ConsumerStatefulWidget {
  const HouseholdActivityPage({super.key});
  @override
  ConsumerState<HouseholdActivityPage> createState() => _ActivityState();
}

class _ActivityState extends ResourceState<HouseholdActivityPage> {
  @override
  String get path => '/households/activity';
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: EatMeAppBar(title: Text(context.t('recent_activity'))),
    body: content([
      if (records(data?['items']).isEmpty)
        StatusNote(text: context.t('activity_empty')),
      for (final item in records(data?['items']))
        Card(
          child: ListTile(
            leading: const IconBadge(Icons.history),
            title: Text(
              '${item['actor_name'] ?? context.t('former_member')} · ${context.t('event_${item['kind']}')}',
            ),
            subtitle: Text(
              '${labelOf(item['food_name'], context)}\n${item['quantity']} ${item['unit'] ?? ''} · ${item['created_at']}',
            ),
            isThreeLine: true,
          ),
        ),
    ]),
  );
}
