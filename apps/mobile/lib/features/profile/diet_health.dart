import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/localization.dart';
import '../../core/models.dart';
import '../../core/state.dart';
import '../../design_system/widgets.dart';

/// Read-only summary of saved restrictions; editing retains the consent workflow.
class DietHealthPage extends ConsumerWidget {
  const DietHealthPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appProvider);
    final settings = state.profile['settings'] as Map? ?? {};
    final assignments = (settings['diets'] as List? ?? []).cast<Map>();
    final allergies = List<String>.from(settings['allergies'] as List? ?? []);
    final intolerances = List<String>.from(settings['intolerances'] as List? ?? []);
    return Scaffold(appBar: EatMeAppBar(title: Text(context.t('diet_health'))), body: PageBody(children: [
      InformationPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.shield_outlined, size: 30),
        const SizedBox(height: 16),
        Text(context.t('allergies_intolerances'), style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        Text(context.t('saved_restrictions_notice')),
        const SizedBox(height: 16),
        for (final section in [('allergies', allergies), ('intolerances', intolerances)]) ...[
          Text(context.t(section.$1), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (section.$2.isEmpty) Text(context.t('none_recorded')) else Wrap(spacing: 8, runSpacing: 8, children: [for (final value in section.$2) StatusBadge(label: context.t(section.$1 == 'allergies' ? 'allergen_$value' : value), icon: Icons.warning_amber, urgent: true)]),
          const SizedBox(height: 16),
        ],
      ])),
      const SizedBox(height: 24),
      SettingsGroup(title: context.t('diet'), children: [
        if (assignments.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text(context.t('no_diet'))),
        for (final assignment in assignments) Builder(builder: (context) {
          final diet = state.diets.where((d) => d.id == assignment['diet_id']).firstOrNull;
          return SettingRow(title: diet == null ? context.t('food_unavailable') : localized(diet.name, context.language), subtitle: context.t(assignment['strictness'] as String? ?? 'standard'), icon: diet?.medical == true ? Icons.medical_services_outlined : Icons.eco_outlined, trailing: assignment['diet_id'] == settings['primary_diet'] ? StatusBadge(label: context.t('primary_diet')) : null);
        }),
      ]),
      if (settings['primary_goal'] is String) SettingsGroup(title: context.t('primary_goal'), children: [SettingRow(title: context.t('goal_${settings['primary_goal']}'), icon: Icons.favorite_outline)]),
      FilledButton(onPressed: () => context.push('/profile/edit'), child: Text(context.t('edit_profile'))),
      const SizedBox(height: 16),
      SettingRow(title: context.t('wellbeing'), icon: Icons.track_changes, onTap: () => context.push('/wellbeing')),
    ]));
  }
}
