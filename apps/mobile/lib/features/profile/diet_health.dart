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
class DietHealthPage extends ConsumerWidget {
  const DietHealthPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appProvider);
    final settings = Map<String, dynamic>.from(
      state.profile['settings'] as Map? ?? {},
    );
    final assignments = List<Map<String, dynamic>>.from(
      (settings['diets'] as List? ?? const []).map(
        (value) => Map<String, dynamic>.from(value as Map),
      ),
    );
    String summary(List<String> values, String Function(String) label) {
      if (values.isEmpty) return context.t('not_configured');
      final visible = values.take(3).map(label).join(' · ');
      return values.length > 3 ? '$visible · +${values.length - 3}' : visible;
    }

    String dietSummary({required bool medical}) => summary(
      assignments
          .map((value) => value['diet_id'] as String)
          .where(
            (id) => state.diets.any(
              (diet) => diet.id == id && diet.medical == medical,
            ),
          )
          .toList(),
      (id) => localized(
        state.diets.firstWhere((diet) => diet.id == id).name,
        context.language,
      ),
    );

    final timing = Map<String, dynamic>.from(
      settings['meal_timing'] as Map? ?? const {'mode': 'standard'},
    );
    void edit(String section) => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RepaintBoundary(
          key: const ValueKey('diet-health-editor-boundary'),
          child: _DietHealthEditorPage(section: section),
        ),
      ),
    );

    final sections = <(String, String, String, EatMeGlyph)>[
      (
        'eating',
        context.t('eating_style'),
        dietSummary(medical: false),
        EatMeGlyph.leaf,
      ),
      (
        'allergies',
        context.t('allergies'),
        summary(
          List<String>.from(settings['allergies'] as List? ?? const []),
          (value) => context.t('allergen_$value'),
        ),
        EatMeGlyph.shield,
      ),
      (
        'sensitivities',
        context.t('intolerances_sensitivities'),
        summary(
          [
            ...List<String>.from(settings['intolerances'] as List? ?? const []),
            ...List<String>.from(
              settings['sensitivities'] as List? ?? const [],
            ),
          ],
          (value) => state.intolerances.contains(value)
              ? context.t('intolerance_$value')
              : context.t('sensitivity_$value'),
        ),
        EatMeGlyph.slidersHorizontal,
      ),
      (
        'medical',
        context.t('medical_restrictions'),
        summary([
          if (dietSummary(medical: true) != context.t('not_configured'))
            dietSummary(medical: true),
          ...List<String>.from(
            settings['medical_awareness'] as List? ?? const [],
          ).map((value) => context.t('medical_$value')),
        ], (value) => value),
        EatMeGlyph.shieldCheck,
      ),
      (
        'therapeutic',
        context.t('therapeutic_protocols'),
        context.t('reviewed_rules_only'),
        EatMeGlyph.badgeCheck,
      ),
      (
        'ethics',
        context.t('ethical_religious'),
        summary(
          List<String>.from(
            settings['ethical_preferences'] as List? ?? const [],
          ),
          (value) => context.t('ethical_$value'),
        ),
        EatMeGlyph.heart,
      ),
      (
        'timing',
        context.t('meal_timing'),
        timing['mode'] == 'standard'
            ? context.t('meal_timing_standard')
            : '${timing['start'] ?? '—'}–${timing['end'] ?? '—'}',
        EatMeGlyph.clock,
      ),
      (
        'exclusions',
        context.t('excluded_foods'),
        context.t('selected_count', {
          'count': (settings['never_suggest'] as List? ?? const []).length,
        }),
        EatMeGlyph.triangleAlert,
      ),
      (
        'unknown',
        context.t('unknown_ingredients'),
        context.t(
          'unknown_policy_${settings['unknown_ingredient_policy'] ?? 'strict'}',
        ),
        EatMeGlyph.search,
      ),
    ];

    return Scaffold(
      appBar: EatMeAppBar(title: Text(context.t('diet_health'))),
      body: PageBody(
        children: [
          InformationPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const EatMeIcon(EatMeGlyph.shieldCheck, size: 30),
                const SizedBox(height: 14),
                Text(
                  context.t('diet_health_hub_title'),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(context.t('diet_health_hub_body')),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (dietSummary(medical: false) != context.t('not_configured'))
                      StatusBadge(
                        label: dietSummary(medical: false),
                        icon: EatMeGlyph.leaf,
                        emphasis: true,
                      ),
                    if (dietSummary(medical: true) != context.t('not_configured'))
                      StatusBadge(
                        label: dietSummary(medical: true),
                        icon: EatMeGlyph.shield,
                      ),
                    if ((settings['never_suggest'] as List? ?? const []).isNotEmpty)
                      StatusBadge(
                        label: context.t('selected_count', {
                          'count': (settings['never_suggest'] as List).length,
                        }),
                        icon: EatMeGlyph.triangleAlert,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          SettingsGroup(
            children: [
              for (final section in sections)
                SettingRow(
                  key: ValueKey('diet-section-${section.$1}'),
                  title: section.$2,
                  subtitle: section.$3,
                  icon: section.$4,
                  onTap: () => edit(section.$1),
                ),
            ],
          ),
          const SizedBox(height: 14),
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

class _DietHealthEditorPage extends ConsumerStatefulWidget {
  const _DietHealthEditorPage({required this.section});
  final String section;

  @override
  ConsumerState<_DietHealthEditorPage> createState() => _DietHealthPageState();
}

class _DietHealthPageState extends ConsumerState<_DietHealthEditorPage> {
  final mutation = Mutation();
  final Map<String, String> strictness = {};
  final Set<String> allergies = {};
  final Set<String> intolerances = {};
  final Set<String> sensitivities = {};
  final Set<String> medicalAwareness = {};
  final Set<String> ethicalPreferences = {};
  final Set<String> exclusions = {};
  final Set<String> initiallyMedical = {};
  String? primaryDiet;
  String unknownPolicy = 'strict';
  String tracePolicy = 'review';
  String mealTimingMode = 'standard';
  String mealStart = '12:00';
  String mealEnd = '20:00';
  String mealPreset = 'custom';
  final Map<String, bool> mealSlots = {
    'breakfast': true,
    'lunch': true,
    'dinner': true,
    'snack': true,
  };
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
    sensitivities.addAll(
      List<String>.from(settings['sensitivities'] as List? ?? const []),
    );
    medicalAwareness.addAll(
      List<String>.from(settings['medical_awareness'] as List? ?? const []),
    );
    ethicalPreferences.addAll(
      List<String>.from(settings['ethical_preferences'] as List? ?? const []),
    );
    exclusions.addAll(
      List<String>.from(settings['never_suggest'] as List? ?? const []),
    );
    primaryDiet = settings['primary_diet'] as String?;
    unknownPolicy =
        settings['unknown_ingredient_policy'] as String? ?? 'strict';
    tracePolicy = settings['trace_policy'] as String? ?? 'block';
    final mealTiming = Map<String, dynamic>.from(
      settings['meal_timing'] as Map? ?? const {'mode': 'standard'},
    );
    mealTimingMode = mealTiming['mode'] as String? ?? 'standard';
    mealStart = mealTiming['start'] as String? ?? '12:00';
    mealEnd = mealTiming['end'] as String? ?? '20:00';
    mealPreset = mealTiming['preset'] as String? ?? 'custom';
    final storedSlots = Map<String, dynamic>.from(
      mealTiming['slots'] as Map? ?? const {},
    );
    for (final slot in mealSlots.keys) {
      mealSlots[slot] = storedSlots[slot] as bool? ?? true;
    }
    healthAcknowledged =
        allergies.isNotEmpty ||
        intolerances.isNotEmpty ||
        sensitivities.isNotEmpty;
    initiallyMedical.addAll(
      state.diets
          .where((diet) => diet.medical && strictness.containsKey(diet.id))
          .map((diet) => diet.id),
    );
    medicalAcknowledged =
        initiallyMedical.isNotEmpty || medicalAwareness.isNotEmpty;
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
      useRootNavigator: true,
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

  Future<void> chooseMealTime({required bool start}) async {
    final source = start ? mealStart : mealEnd;
    final parts = source.split(':');
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts.first) ?? 12,
        minute: int.tryParse(parts.last) ?? 0,
      ),
    );
    if (selected == null || !mounted) return;
    final value =
        '${selected.hour.toString().padLeft(2, '0')}:${selected.minute.toString().padLeft(2, '0')}';
    setState(() => start ? mealStart = value : mealEnd = value);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appProvider);
    initialize(state);
    final selectable = state.diets.where((diet) => diet.selectable).toList();
    final selectedMedical =
        medicalAwareness.isNotEmpty ||
        selectable.any(
          (diet) => diet.medical && strictness.containsKey(diet.id),
        );
    final restrictionsRecorded =
        allergies.isNotEmpty ||
        intolerances.isNotEmpty ||
        sensitivities.isNotEmpty;

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
          if ({
            'eating',
            'medical',
            'therapeutic',
          }.contains(widget.section)) ...[
            const SizedBox(height: 26),
            SectionHeading(
              title: context.t(
                widget.section == 'eating'
                    ? 'eating_style'
                    : widget.section == 'medical'
                    ? 'medical_restrictions'
                    : 'therapeutic_protocols',
              ),
            ),
            Text(
              context.t('diet_profiles_help'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            for (final diet in selectable.where((diet) {
              if (widget.section == 'medical') return diet.medical;
              if (widget.section == 'therapeutic') {
                return {'gluten-free', 'rad'}.contains(diet.slug);
              }
              return !diet.medical &&
                  !{'gluten-free', 'rad'}.contains(diet.slug);
            })) ...[
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
          ],
          if ({'allergies', 'sensitivities'}.contains(widget.section)) ...[
            const SizedBox(height: 14),
            SectionHeading(title: context.t('allergies_intolerances')),
            Text(
              context.t('hard_safety_help'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            if (widget.section == 'allergies')
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
                  const SizedBox(height: 6),
                  Text(
                    context.t('trace_policy_help'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  _ChoiceWrap(
                    values: const ['ignore', 'review', 'block'],
                    selected: {tracePolicy},
                    label: (value) => context.t('trace_policy_$value'),
                    keyPrefix: 'trace-policy',
                    onChanged: (value, selected) {
                      if (selected) setState(() => tracePolicy = value);
                    },
                  ),
                ],
              ),
            if (widget.section == 'sensitivities')
              SettingsGroup(
                title: context.t('intolerances'),
                children: [
                  _ChoiceWrap(
                    values: state.intolerances,
                    selected: intolerances,
                    label: (value) => context.t('intolerance_$value'),
                    keyPrefix: 'intolerance',
                    onChanged: (value, selected) => setState(() {
                      selected
                          ? intolerances.add(value)
                          : intolerances.remove(value);
                      if (selected) healthAcknowledged = false;
                    }),
                  ),
                ],
              ),
            if (widget.section == 'sensitivities')
              SettingsGroup(
                title: context.t('sensitivities'),
                children: [
                  Text(
                    context.t('sensitivities_help'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  _ChoiceWrap(
                    values: state.sensitivities,
                    selected: sensitivities,
                    label: (value) => context.t('sensitivity_$value'),
                    keyPrefix: 'sensitivity',
                    onChanged: (value, selected) => setState(() {
                      selected
                          ? sensitivities.add(value)
                          : sensitivities.remove(value);
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
          ],
          if (widget.section == 'medical') ...[
            const SizedBox(height: 22),
            SectionHeading(title: context.t('medical_awareness')),
            Text(
              context.t('medical_awareness_help'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            InformationPanel(
              tinted: false,
              child: _ChoiceWrap(
                values: state.medicalAwareness,
                selected: medicalAwareness,
                label: (value) => context.t('medical_$value'),
                keyPrefix: 'medical-awareness',
                onChanged: (value, selected) => setState(() {
                  selected
                      ? medicalAwareness.add(value)
                      : medicalAwareness.remove(value);
                  if (selected) medicalAcknowledged = false;
                }),
              ),
            ),
            if (selectedMedical) ...[
              const SizedBox(height: 10),
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
          ],
          if (widget.section == 'ethics') ...[
            const SizedBox(height: 22),
            SectionHeading(title: context.t('ethical_religious')),
            Text(
              context.t('ethical_religious_help'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            InformationPanel(
              tinted: false,
              child: _ChoiceWrap(
                values: state.ethicalPreferences,
                selected: ethicalPreferences,
                label: (value) => context.t('ethical_$value'),
                keyPrefix: 'ethical',
                onChanged: (value, selected) => setState(
                  () => selected
                      ? ethicalPreferences.add(value)
                      : ethicalPreferences.remove(value),
                ),
              ),
            ),
          ],
          if (widget.section == 'timing') ...[
            const SizedBox(height: 22),
            SectionHeading(title: context.t('meal_timing')),
            Text(
              context.t('meal_timing_help'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            EatMeSelectionRow(
              key: const ValueKey('meal-timing-standard'),
              icon: EatMeGlyph.clock,
              title: context.t('meal_timing_standard'),
              subtitle: context.t('meal_timing_standard_body'),
              selected: mealTimingMode == 'standard',
              onTap: () => setState(() => mealTimingMode = 'standard'),
            ),
            const SizedBox(height: 10),
            EatMeSelectionRow(
              key: const ValueKey('meal-timing-window'),
              icon: EatMeGlyph.timer,
              title: context.t('meal_timing_window'),
              subtitle: context.t('meal_timing_window_body'),
              selected: mealTimingMode == 'time_restricted',
              onTap: () => setState(() => mealTimingMode = 'time_restricted'),
            ),
            if (mealTimingMode != 'standard') ...[
              const SizedBox(height: 10),
              _ChoiceWrap(
                values: const ['12:12', '14:10', '16:8', '18:6', 'custom'],
                selected: {mealPreset},
                label: (value) =>
                    value == 'custom' ? context.t('custom_schedule') : value,
                keyPrefix: 'meal-preset',
                onChanged: (value, selected) {
                  if (!selected) return;
                  setState(() {
                    mealPreset = value;
                    final window = {
                      '12:12': ('08:00', '20:00'),
                      '14:10': ('10:00', '20:00'),
                      '16:8': ('12:00', '20:00'),
                      '18:6': ('14:00', '20:00'),
                    }[value];
                    if (window != null) {
                      mealStart = window.$1;
                      mealEnd = window.$2;
                    }
                  });
                },
              ),
              const SizedBox(height: 10),
              InformationPanel(
                tinted: false,
                child: Row(
                  children: [
                    Expanded(
                      child: _ActionPill(
                        label: context.t('window_start', {'time': mealStart}),
                        icon: EatMeGlyph.clock,
                        onTap: () => chooseMealTime(start: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ActionPill(
                        label: context.t('window_end', {'time': mealEnd}),
                        icon: EatMeGlyph.clock,
                        onTap: () => chooseMealTime(start: false),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            InformationPanel(
              tinted: false,
              child: Column(
                children: [
                  for (final slot in mealSlots.keys)
                    EatMeToggleRow(
                      title: context.t(slot),
                      icon: EatMeGlyph.utensils,
                      value: mealSlots[slot]!,
                      onChanged: (value) =>
                          setState(() => mealSlots[slot] = value),
                    ),
                ],
              ),
            ),
          ],
          if (widget.section == 'exclusions') ...[
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
                  () => selected
                      ? exclusions.add(value)
                      : exclusions.remove(value),
                ),
              ),
            ),
          ],
          if (widget.section == 'unknown') ...[
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
          ],
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
                'sensitivities': sensitivities.toList(),
                'medical_awareness': medicalAwareness.toList(),
                'ethical_preferences': ethicalPreferences.toList(),
                'trace_policy': tracePolicy,
                'meal_timing': {
                  'mode': mealTimingMode,
                  if (mealTimingMode != 'standard') 'start': mealStart,
                  if (mealTimingMode != 'standard') 'end': mealEnd,
                  if (mealTimingMode != 'standard') 'preset': mealPreset,
                  'slots': mealSlots,
                },
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
              Navigator.of(context).pop();
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
