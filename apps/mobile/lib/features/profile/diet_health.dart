import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api.dart';
import '../../core/localization.dart';
import '../../core/models.dart';
import '../../core/state.dart';
import '../../design_system/widgets.dart';

/// Direct, self-service control centre for every rule consumed by EatMe's
/// compatibility and recommendation engine.
class DietHealthPage extends ConsumerStatefulWidget {
  const DietHealthPage({super.key});

  @override
  ConsumerState<DietHealthPage> createState() => _DietHealthPageState();
}

class _DietHealthPageState extends ConsumerState<DietHealthPage> {
  final mutation = Mutation();
  final Map<String, String> strictness = {};
  final Set<String> allergies = {};
  final Set<String> intolerances = {};
  final Set<String> exclusions = {};
  final Set<String> initiallyMedical = {};
  String? primaryDiet;
  String unknownPolicy = 'strict';
  bool healthAcknowledged = false;
  bool medicalAcknowledged = false;
  bool initialized = false;

  void initialize(AppState state) {
    if (initialized) return;
    final settings = Map<String, dynamic>.from(
      state.profile['settings'] as Map? ?? {},
    );
    for (final value in (settings['diets'] as List? ?? const [])) {
      final assignment = Map<String, dynamic>.from(value as Map);
      strictness[assignment['diet_id'] as String] =
          assignment['strictness'] as String? ?? 'standard';
    }
    allergies.addAll(
      List<String>.from(settings['allergies'] as List? ?? const []),
    );
    intolerances.addAll(
      List<String>.from(settings['intolerances'] as List? ?? const []),
    );
    exclusions.addAll(
      List<String>.from(settings['never_suggest'] as List? ?? const []),
    );
    primaryDiet = settings['primary_diet'] as String?;
    unknownPolicy =
        settings['unknown_ingredient_policy'] as String? ?? 'strict';
    healthAcknowledged = allergies.isNotEmpty || intolerances.isNotEmpty;
    initiallyMedical.addAll(
      state.diets
          .where((diet) => diet.medical && strictness.containsKey(diet.id))
          .map((diet) => diet.id),
    );
    medicalAcknowledged = initiallyMedical.isNotEmpty;
    initialized = true;
  }

  void toggleDiet(Diet diet) {
    setState(() {
      if (strictness.containsKey(diet.id)) {
        strictness.remove(diet.id);
        if (primaryDiet == diet.id) {
          primaryDiet = strictness.keys.firstOrNull;
        }
      } else {
        strictness[diet.id] = diet.medical ? 'strict' : 'standard';
        primaryDiet ??= diet.id;
        if (diet.medical && !initiallyMedical.contains(diet.id)) {
          medicalAcknowledged = false;
        }
      }
    });
  }

  Future<void> chooseStrictness(Diet diet) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t('strictness_for', {
                'profile': localized(diet.name, context.language),
              }),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 14),
            for (final value in ['flexible', 'standard', 'strict']) ...[
              EatMeSelectionRow(
                icon: value == 'strict'
                    ? EatMeGlyph.shield
                    : EatMeGlyph.slidersHorizontal,
                title: context.t(value),
                subtitle: context.t('strictness_${value}_description'),
                selected: strictness[diet.id] == value,
                onTap: () => Navigator.pop(context, value),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() => strictness[diet.id] = selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appProvider);
    initialize(state);
    final selectable = state.diets.where((diet) => diet.selectable).toList();
    final selectedMedical = selectable.any(
      (diet) => diet.medical && strictness.containsKey(diet.id),
    );
    final restrictionsRecorded =
        allergies.isNotEmpty || intolerances.isNotEmpty;

    return Scaffold(
      appBar: EatMeAppBar(title: Text(context.t('diet_health'))),
      body: PageBody(
        children: [
          InformationPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EatMeIcon(
                  EatMeGlyph.shieldCheck,
                  size: 30,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 14),
                Text(
                  context.t('diet_health_control_title'),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  context.t('diet_health_control_body'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          SectionHeading(title: context.t('diet_profiles')),
          Text(
            context.t('diet_profiles_help'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          for (final diet in selectable) ...[
            EatMeSelectionRow(
              key: ValueKey('diet-${diet.slug}'),
              icon: diet.medical ? EatMeGlyph.shield : EatMeGlyph.leaf,
              title: localized(diet.name, context.language),
              subtitle: diet.medical
                  ? context.t('self_declared_health_profile')
                  : context.t('lifestyle_profile'),
              selected: strictness.containsKey(diet.id),
              onTap: () => toggleDiet(diet),
            ),
            if (strictness.containsKey(diet.id))
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 8, 14),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _ActionPill(
                      label: context.t('strictness_value', {
                        'value': context.t(strictness[diet.id]!),
                      }),
                      icon: EatMeGlyph.slidersHorizontal,
                      onTap: () => chooseStrictness(diet),
                    ),
                    _ActionPill(
                      label: primaryDiet == diet.id
                          ? context.t('primary_profile')
                          : context.t('make_primary'),
                      icon: primaryDiet == diet.id
                          ? EatMeGlyph.circleCheck
                          : EatMeGlyph.badgeCheck,
                      selected: primaryDiet == diet.id,
                      onTap: () => setState(() => primaryDiet = diet.id),
                    ),
                  ],
                ),
              )
            else
              const SizedBox(height: 10),
          ],
          if (selectedMedical) ...[
            const SizedBox(height: 2),
            InformationPanel(
              tinted: false,
              child: EatMeToggleRow(
                key: const ValueKey('medical-acknowledgement'),
                title: context.t('medical_profile_acknowledgement'),
                subtitle: context.t('medical_profile_acknowledgement_body'),
                icon: EatMeGlyph.shield,
                value: medicalAcknowledged,
                onChanged: (value) =>
                    setState(() => medicalAcknowledged = value),
              ),
            ),
          ],
          const SizedBox(height: 14),
          SectionHeading(title: context.t('allergies_intolerances')),
          Text(
            context.t('hard_safety_help'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          SettingsGroup(
            title: context.t('allergies'),
            children: [
              _ChoiceWrap(
                values: state.allergens,
                selected: allergies,
                label: (value) => context.t('allergen_$value'),
                keyPrefix: 'allergen',
                onChanged: (value, selected) => setState(() {
                  selected ? allergies.add(value) : allergies.remove(value);
                  if (selected) healthAcknowledged = false;
                }),
              ),
            ],
          ),
          SettingsGroup(
            title: context.t('intolerances'),
            children: [
              EatMeToggleRow(
                key: const ValueKey('intolerance-lactose'),
                title: context.t('lactose'),
                subtitle: context.t('intolerance_hard_rule'),
                icon: EatMeGlyph.triangleAlert,
                value: intolerances.contains('lactose'),
                onChanged: (selected) => setState(() {
                  selected
                      ? intolerances.add('lactose')
                      : intolerances.remove('lactose');
                  if (selected) healthAcknowledged = false;
                }),
              ),
            ],
          ),
          if (restrictionsRecorded)
            InformationPanel(
              tinted: false,
              child: EatMeToggleRow(
                key: const ValueKey('health-acknowledgement'),
                title: context.t('health_consent'),
                subtitle: context.t('health_consent_direct_body'),
                icon: EatMeGlyph.lock,
                value: healthAcknowledged,
                onChanged: (value) =>
                    setState(() => healthAcknowledged = value),
              ),
            ),
          const SizedBox(height: 14),
          SectionHeading(title: context.t('excluded_foods')),
          Text(
            context.t('excluded_foods_help'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          InformationPanel(
            tinted: false,
            child: _ChoiceWrap(
              values: state.foods.map((food) => food.id).toList(),
              selected: exclusions,
              label: (value) => localized(
                state.foods.firstWhere((food) => food.id == value).name,
                context.language,
              ),
              keyPrefix: 'exclude',
              onChanged: (value, selected) => setState(
                () =>
                    selected ? exclusions.add(value) : exclusions.remove(value),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SectionHeading(title: context.t('unknown_ingredients')),
          Text(
            context.t('unknown_ingredients_help'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          EatMeSelectionRow(
            key: const ValueKey('unknown-strict'),
            icon: EatMeGlyph.shield,
            title: context.t('unknown_policy_strict'),
            subtitle: context.t('unknown_policy_strict_body'),
            selected: unknownPolicy == 'strict',
            onTap: () => setState(() => unknownPolicy = 'strict'),
          ),
          const SizedBox(height: 10),
          EatMeSelectionRow(
            key: const ValueKey('unknown-review'),
            icon: EatMeGlyph.search,
            title: context.t('unknown_policy_review'),
            subtitle: context.t('unknown_policy_review_body'),
            selected: unknownPolicy == 'review',
            onTap: () => setState(() => unknownPolicy = 'review'),
          ),
          const SizedBox(height: 28),
          AsyncAction(
            key: const ValueKey('save-diet-health'),
            label: context.t('save_diet_health'),
            enabled:
                (!restrictionsRecorded || healthAcknowledged) &&
                (!selectedMedical || medicalAcknowledged),
            action: () async {
              final profile = state.profile;
              final settings = Map<String, dynamic>.from(
                profile['settings'] as Map? ?? {},
              );
              final body = <String, dynamic>{
                'name': profile['name'] as String? ?? '',
                'adult_confirmed': true,
                'household_size': profile['household_size'] as int? ?? 1,
                'timezone': settings['timezone'] as String? ?? 'Europe/Rome',
                'primary_goal': settings['primary_goal'],
                'primary_diet': strictness.containsKey(primaryDiet)
                    ? primaryDiet
                    : strictness.keys.firstOrNull,
                'diets': strictness.entries
                    .map(
                      (entry) => {
                        'diet_id': entry.key,
                        'strictness': entry.value,
                      },
                    )
                    .toList(),
                'allergies': allergies.toList(),
                'intolerances': intolerances.toList(),
                'never_suggest': exclusions.toList(),
                'unknown_ingredient_policy': unknownPolicy,
                if (healthAcknowledged)
                  'health_consent_version': 'nutrition-profile-1',
                if (medicalAcknowledged)
                  'medical_consent_version': 'medical-nutrition-1',
                'expected_version': profile['version'],
              };
              await mutation.send(
                ref.read(apiProvider),
                'PUT',
                '/profile',
                body,
              );
              await ref.read(appProvider.notifier).hydrate();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.t('diet_health_saved'))),
              );
            },
          ),
          const SizedBox(height: 16),
          SettingRow(
            title: context.t('wellbeing'),
            icon: EatMeGlyph.chartSpline,
            onTap: () => context.push('/wellbeing'),
          ),
        ],
      ),
    );
  }
}

class _ChoiceWrap extends StatelessWidget {
  const _ChoiceWrap({
    required this.values,
    required this.selected,
    required this.label,
    required this.keyPrefix,
    required this.onChanged,
  });

  final List<String> values;
  final Set<String> selected;
  final String Function(String value) label;
  final String keyPrefix;
  final void Function(String value, bool selected) onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final value in values)
          _ActionPill(
            key: ValueKey('$keyPrefix-$value'),
            label: label(value),
            icon: selected.contains(value)
                ? EatMeGlyph.circleCheck
                : EatMeGlyph.plus,
            selected: selected.contains(value),
            onTap: () => onChanged(value, !selected.contains(value)),
          ),
      ],
    ),
  );
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.selected = false,
  });

  final String label;
  final EatMeGlyph icon;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  EatMeIcon(icon, size: 17, color: scheme.primary),
                  const SizedBox(width: 7),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 230),
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
