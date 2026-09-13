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
    if (result != null)
      await command({
        'action': 'target',
        'goal': goal,
        'target': result,
        'expected_version': data!['version'],
      });
  }

  @override
  Widget build(BuildContext context) {
    final goals = records(data?['goals']);
    return Scaffold(
      appBar: AppBar(title: Text(context.t('wellbeing'))),
      body: content([
        Text(
          context.t('your_goals'),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        StatusNote(text: context.t('self_reported_habits')),
        if (data != null)
          Text(context.t('week_starting', {'date': '${data!['week_start']}'})),
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
                  AsyncAction(
                    label: context.t(
                      goal['done_today'] == true ? 'undo_today' : 'done_today',
                    ),
                    action: () async {
                      await command({
                        'action': 'check_in',
                        'goal': goal['id'],
                        'completed': goal['done_today'] != true,
                        'expected_version': data!['version'],
                      });
                    },
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      AsyncAction(
                        label: context.t('edit'),
                        secondary: true,
                        action: () => editTarget(
                          goal['id'] as String,
                          goal['target'] as int,
                        ),
                      ),
                      AsyncAction(
                        label: context.t('delete'),
                        secondary: true,
                        action: () async {
                          await command({
                            'action': 'remove',
                            'goal': goal['id'],
                            'expected_version': data!['version'],
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        for (final goal in habitGoals.where(
          (id) => !goals.any((g) => g['id'] == id),
        ))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AsyncAction(
              label: context.t('goal_$goal'),
              secondary: true,
              enabled: data != null,
              action: () => editTarget(goal, 5),
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
    appBar: AppBar(title: Text(context.t('recent_activity'))),
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
