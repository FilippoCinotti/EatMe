import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/localization.dart';
import '../../core/models.dart';
import '../../core/state.dart';
import '../../design_system/widgets.dart';
import 'onboarding_tag.dart';

const _treeNuts = {
  'almond',
  'hazelnut',
  'walnut',
  'cashew',
  'pecan',
  'brazil_nut',
  'pistachio',
  'macadamia',
};

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key, this.edit = false});
  final bool edit;
  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final name = TextEditingController(),
      timezone = TextEditingController(text: 'Europe/Rome');
  final mutation = Mutation();
  final scroll = ScrollController();
  int step = 0, size = 1;
  bool adult = false, consent = false, medicalConsent = false;
  String strictness = 'standard', primaryGoal = 'eat_better';
  String unknownPolicy = 'strict';
  String mealTimingMode = 'standard', mealStart = '10:00', mealEnd = '20:00';
  String mealPreset = '14:10';
  final Map<String, bool> mealSlots = {
    'breakfast': true,
    'lunch': true,
    'dinner': true,
    'snack': true,
  };
  String? primaryDiet;
  Json preservedSettings = {};
  final Set<String> selected = {}, allergies = {}, intolerances = {};
  final Set<String> sensitivities = {}, medicalAwareness = {};
  final Set<String> neverSuggest = {};
  @override
  void initState() {
    super.initState();
    final state = ref.read(appProvider);
    final profile = state.profile;
    if (widget.edit) {
      name.text = profile['name'] as String? ?? '';
      size = profile['household_size'] as int? ?? 1;
      final settings = Map<String, dynamic>.from(profile['settings'] as Map);
      preservedSettings = settings;
      timezone.text = settings['timezone'] as String;
      primaryGoal = settings['primary_goal'] as String? ?? 'eat_better';
      primaryDiet = settings['primary_diet'] as String?;
      selected.addAll(
        (settings['diets'] as List).map((d) => d['diet_id'] as String),
      );
      allergies.addAll(List<String>.from(settings['allergies'] as List));
      intolerances.addAll(List<String>.from(settings['intolerances'] as List));
      sensitivities.addAll(
        List<String>.from(settings['sensitivities'] as List? ?? const []),
      );
      medicalAwareness.addAll(
        List<String>.from(settings['medical_awareness'] as List? ?? const []),
      );
      final mealTiming = Map<String, dynamic>.from(
        settings['meal_timing'] as Map? ?? const {'mode': 'standard'},
      );
      mealTimingMode = mealTiming['mode'] as String? ?? 'standard';
      mealStart = mealTiming['start'] as String? ?? '10:00';
      mealEnd = mealTiming['end'] as String? ?? '20:00';
      mealPreset = mealTiming['preset'] as String? ?? 'custom';
      final storedSlots = Map<String, dynamic>.from(
        mealTiming['slots'] as Map? ?? const {},
      );
      for (final slot in mealSlots.keys) {
        mealSlots[slot] = storedSlots[slot] as bool? ?? true;
      }
      neverSuggest.addAll(
        List<String>.from(settings['never_suggest'] as List? ?? const []),
      );
      unknownPolicy =
          settings['unknown_ingredient_policy'] as String? ?? 'strict';
      if ((settings['diets'] as List).isNotEmpty) {
        strictness = settings['diets'][0]['strictness'] as String;
      }
      adult = true;
      consent =
          allergies.isNotEmpty ||
          intolerances.isNotEmpty ||
          sensitivities.isNotEmpty;
      medicalConsent =
          medicalAwareness.isNotEmpty ||
          state.diets.any((diet) => diet.medical && selected.contains(diet.id));
    } else {
      for (final diet in state.diets) {
        if (diet.slug == 'mediterranean' && diet.selectable) {
          selected.add(diet.id);
        }
      }
    }
  }

  @override
  void dispose() {
    scroll.dispose();
    name.dispose();
    timezone.dispose();
    super.dispose();
  }

  void moveStep(int value) {
    FocusScope.of(context).unfocus();
    if (scroll.hasClients) scroll.jumpTo(0);
    setState(() => step = value);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && scroll.hasClients) scroll.jumpTo(0);
    });
  }

  Future<void> chooseMealTime({required bool start}) async {
    final source = start ? mealStart : mealEnd;
    final parts = source.split(':');
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts.first) ?? 10,
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
    final theme = Theme.of(context);
    final text = theme.textTheme;
    return Theme(
      data: theme.copyWith(
        textTheme: text.copyWith(
          displaySmall: text.displaySmall?.copyWith(fontSize: 22, height: 1.15),
          headlineMedium: text.headlineMedium?.copyWith(fontSize: 22),
          titleLarge: text.titleLarge?.copyWith(fontSize: 14),
          titleMedium: text.titleMedium?.copyWith(fontSize: 14),
          bodyLarge: text.bodyLarge?.copyWith(fontSize: 13),
          bodyMedium: text.bodyMedium?.copyWith(fontSize: 13),
          bodySmall: text.bodySmall?.copyWith(fontSize: 13),
          labelLarge: text.labelLarge?.copyWith(fontSize: 14),
          labelMedium: text.labelMedium?.copyWith(fontSize: 12),
          labelSmall: text.labelSmall?.copyWith(fontSize: 11),
        ),
        appBarTheme: theme.appBarTheme.copyWith(
          titleTextStyle: text.titleMedium?.copyWith(fontSize: 14),
        ),
        inputDecorationTheme: theme.inputDecorationTheme.copyWith(
          labelStyle: text.bodyMedium?.copyWith(fontSize: 13),
          hintStyle: text.bodyMedium?.copyWith(fontSize: 13),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: theme.filledButtonTheme.style?.copyWith(
            textStyle: WidgetStatePropertyAll(
              text.labelLarge?.copyWith(fontSize: 14),
            ),
            minimumSize: const WidgetStatePropertyAll(Size(44, 48)),
          ),
        ),
      ),
      child: Builder(builder: _buildContent),
    );
  }

  Widget panel({String? title, required List<Widget> children}) =>
      InformationPanel(
        tinted: false,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontSize: 14),
              ),
              const SizedBox(height: 12),
            ],
            ...children,
          ],
        ),
      );

  Widget _buildContent(BuildContext context) {
    final state = ref.watch(appProvider);
    return Scaffold(
      appBar: EatMeAppBar(
        title: Text(
          context.t(widget.edit ? 'edit_profile' : 'make_it_yours'),
          maxLines: 2,
          overflow: TextOverflow.visible,
        ),
        leading: step > 0
            ? IconButton(
                tooltip: context.t('back'),
                icon: const EatMeIcon(EatMeGlyph.chevronLeft),
                onPressed: () => moveStep(step - 1),
              )
            : null,
      ),
      body: PageBody(
        key: ValueKey('onboarding-step-$step'),
        controller: scroll,
        children: [
          Text(
            context.t('step_count', {'current': step + 1, 'total': 6}),
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 8),
          Semantics(
            label: context.t('step_count', {'current': step + 1, 'total': 6}),
            child: Row(
              children: [
                for (var segment = 0; segment < 6; segment++) ...[
                  if (segment > 0) const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: segment <= step
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (step == 0) ...[
            Text(
              context.t('welcome_title'),
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 24),
            panel(
              title: context.t('primary_goal'),
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final goal in [
                      'eat_better',
                      'waste_less',
                      'follow_diet',
                    ])
                      OnboardingTag(
                        key: ValueKey('onboarding-goal-$goal'),
                        label: Text(context.t('goal_$goal')),
                        selected: primaryGoal == goal,
                        onSelected: (_) => setState(() => primaryGoal = goal),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            panel(
              title: context.t('name'),
              children: [
                TextField(
                  controller: name,
                  style: Theme.of(context).textTheme.bodyMedium,
                  decoration: InputDecoration(labelText: context.t('name')),
                ),
              ],
            ),
            const SizedBox(height: 24),
            panel(
              title: context.t('household_question'),
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: context.t('fewer'),
                      onPressed: size > 1 ? () => setState(() => size--) : null,
                      icon: const Icon(Icons.remove),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          '$size',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: context.t('more'),
                      onPressed: size < 20
                          ? () => setState(() => size++)
                          : null,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.t('adult_confirmation')),
              value: adult,
              onChanged: (v) => setState(() => adult = v ?? false),
            ),
          ],
          if (step == 1) ...[
            Text(
              context.t('diet_question'),
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 12),
            Text(context.t('diet_hint')),
            const SizedBox(height: 24),
            panel(
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final diet in state.diets.where(
                      (d) => d.selectable && !d.medical,
                    ))
                      OnboardingTag(
                        key: ValueKey('onboarding-diet-${diet.slug}'),
                        label: Text(localized(diet.name, context.language)),
                        selected: selected.contains(diet.id),
                        onSelected: (enabled) => setState(() {
                          if (enabled) {
                            selected.add(diet.id);
                          } else {
                            selected.remove(diet.id);
                            if (primaryDiet == diet.id) {
                              primaryDiet = selected.firstOrNull;
                            }
                          }
                        }),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (selected.isNotEmpty)
              DropdownButtonFormField<String>(
                isExpanded: true,
                key: ValueKey(selected.join(',')),
                initialValue: selected.contains(primaryDiet)
                    ? primaryDiet
                    : selected.first,
                decoration: InputDecoration(
                  labelText: context.t('primary_diet'),
                ),
                items: state.diets
                    .where((d) => selected.contains(d.id))
                    .map(
                      (d) => DropdownMenuItem(
                        value: d.id,
                        child: Text(localized(d.name, context.language)),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => primaryDiet = v),
              ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: strictness,
              decoration: InputDecoration(labelText: context.t('strictness')),
              items: ['flexible', 'standard', 'strict']
                  .map(
                    (s) =>
                        DropdownMenuItem(value: s, child: Text(context.t(s))),
                  )
                  .toList(),
              onChanged: (s) => setState(() => strictness = s!),
            ),
          ],
          if (step == 2) ...[
            Text(
              context.t('onboarding_allergies_title'),
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 12),
            Text(context.t('onboarding_allergies_body')),
            const SizedBox(height: 16),
            for (final values in [
              state.allergens.where((a) => !_treeNuts.contains(a)).toList(),
              state.allergens.where(_treeNuts.contains).toList(),
            ])
              if (values.isNotEmpty) ...[
                panel(
                  title: context.t(
                    _treeNuts.contains(values.first)
                        ? 'allergen_nuts'
                        : 'allergies',
                  ),
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: values
                          .map(
                            (a) => OnboardingTag(
                              key: ValueKey('onboarding-allergen-$a'),
                              label: Text(context.t('allergen_$a')),
                              selected: allergies.contains(a),
                              onSelected: (v) => setState(() {
                                v ? allergies.add(a) : allergies.remove(a);
                                if (v) consent = false;
                              }),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            if (allergies.isNotEmpty) ...[
              const SizedBox(height: 18),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.t('health_consent')),
                value: consent,
                onChanged: (v) => setState(() => consent = v ?? false),
              ),
            ],
          ],
          if (step == 3) ...[
            Text(
              context.t('onboarding_sensitivities_title'),
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 12),
            Text(context.t('onboarding_sensitivities_body')),
            const SizedBox(height: 18),
            panel(
              title: context.t('intolerances'),
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: state.intolerances
                      .map(
                        (value) => OnboardingTag(
                          key: ValueKey('onboarding-intolerance-$value'),
                          label: Text(context.t('intolerance_$value')),
                          selected: intolerances.contains(value),
                          onSelected: (enabled) => setState(() {
                            enabled
                                ? intolerances.add(value)
                                : intolerances.remove(value);
                            if (enabled) consent = false;
                          }),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
            const SizedBox(height: 24),
            panel(
              title: context.t('sensitivities'),
              children: [
                Text(context.t('sensitivities_help')),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: state.sensitivities
                      .map(
                        (value) => OnboardingTag(
                          key: ValueKey('onboarding-sensitivity-$value'),
                          label: Text(context.t('sensitivity_$value')),
                          selected: sensitivities.contains(value),
                          onSelected: (enabled) => setState(() {
                            enabled
                                ? sensitivities.add(value)
                                : sensitivities.remove(value);
                            if (enabled) consent = false;
                          }),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
            if (intolerances.isNotEmpty || sensitivities.isNotEmpty) ...[
              const SizedBox(height: 18),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.t('health_consent')),
                value: consent,
                onChanged: (v) => setState(() => consent = v ?? false),
              ),
            ],
          ],
          if (step == 4) ...[
            Text(
              context.t('onboarding_medical_title'),
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 12),
            Text(context.t('onboarding_medical_body')),
            const SizedBox(height: 18),
            panel(
              children: [
                Text(context.t('self_declared_health_profile')),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final diet in state.diets.where(
                      (d) => d.selectable && d.medical,
                    ))
                      OnboardingTag(
                        key: ValueKey('onboarding-diet-${diet.slug}'),
                        label: Text(localized(diet.name, context.language)),
                        selected: selected.contains(diet.id),
                        onSelected: (enabled) => setState(() {
                          enabled
                              ? selected.add(diet.id)
                              : selected.remove(diet.id);
                          if (enabled) medicalConsent = false;
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: state.medicalAwareness
                      .map(
                        (value) => OnboardingTag(
                          key: ValueKey('onboarding-medical-$value'),
                          label: Text(context.t('medical_$value')),
                          selected: medicalAwareness.contains(value),
                          onSelected: (enabled) => setState(() {
                            enabled
                                ? medicalAwareness.add(value)
                                : medicalAwareness.remove(value);
                            if (enabled) medicalConsent = false;
                          }),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
            if (medicalAwareness.isNotEmpty ||
                state.diets.any(
                  (d) => d.medical && selected.contains(d.id),
                )) ...[
              const SizedBox(height: 18),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.t('medical_consent')),
                value: medicalConsent,
                onChanged: (v) => setState(() => medicalConsent = v ?? false),
              ),
            ],
          ],
          if (step == 5) ...[
            Text(
              context.t('onboarding_timing_title'),
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 12),
            Text(context.t('meal_timing_help')),
            const SizedBox(height: 18),
            panel(
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OnboardingTag(
                      label: Text(context.t('meal_timing_standard')),
                      selected: mealTimingMode == 'standard',
                      onSelected: (_) =>
                          setState(() => mealTimingMode = 'standard'),
                    ),
                    OnboardingTag(
                      key: const ValueKey('onboarding-timing-window'),
                      label: Text(context.t('meal_timing_window')),
                      selected: mealTimingMode != 'standard',
                      onSelected: (_) =>
                          setState(() => mealTimingMode = 'time_restricted'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(context.t('meal_timing_standard_body')),
                const SizedBox(height: 8),
                Text(context.t('meal_timing_window_body')),
              ],
            ),
            if (mealTimingMode != 'standard') ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final value in [
                    '12:12',
                    '14:10',
                    '16:8',
                    '18:6',
                    '23:23',
                  ])
                    OnboardingTag(
                      label: Text(value),
                      selected: mealPreset == value,
                      onSelected: (_) => setState(() {
                        mealPreset = value;
                        // The 23:23 dedication keeps the user's current window.
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
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton(
                    onPressed: () => chooseMealTime(start: true),
                    child: Text(context.t('window_start', {'time': mealStart})),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () => chooseMealTime(start: false),
                    child: Text(context.t('window_end', {'time': mealEnd})),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
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
            const SizedBox(height: 18),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(context.t('date_settings')),
              children: [
                TextField(
                  controller: timezone,
                  decoration: InputDecoration(labelText: context.t('timezone')),
                ),
              ],
            ),
          ],
          const SizedBox(height: 32),
          if (step < 5) ...[
            FilledButton(
              key: const ValueKey('onboarding-continue'),
              onPressed: () => moveStep(step + 1),
              child: Text(context.t('continue')),
            ),
            if (step > 0)
              TextButton(
                onPressed: () => moveStep(step + 1),
                child: Text(context.t('skip_for_now')),
              ),
          ] else
            AsyncAction(
              label: context.t(widget.edit ? 'save' : 'start_eatme'),
              action: () async {
                if (!adult || name.text.trim().isEmpty) {
                  moveStep(0);
                  throw const ApiFailure('invalid_profile');
                }
                if ((allergies.isNotEmpty ||
                        intolerances.isNotEmpty ||
                        sensitivities.isNotEmpty) &&
                    !consent) {
                  throw const ApiFailure('health_consent_required');
                }
                final data = <String, dynamic>{
                  'name': name.text.trim(),
                  'adult_confirmed': adult,
                  'primary_goal': primaryGoal,
                  'primary_diet': selected.contains(primaryDiet)
                      ? primaryDiet
                      : selected.firstOrNull,
                  'household_size': size,
                  'timezone': timezone.text.trim(),
                  'diets': selected
                      .map((id) => {'diet_id': id, 'strictness': strictness})
                      .toList(),
                  'allergies': allergies.toList(),
                  'intolerances': intolerances.toList(),
                  'sensitivities': sensitivities.toList(),
                  'medical_awareness': medicalAwareness.toList(),
                  'ethical_preferences': List<String>.from(
                    preservedSettings['ethical_preferences'] as List? ??
                        const [],
                  ),
                  'trace_policy':
                      preservedSettings['trace_policy'] as String? ?? 'block',
                  'meal_timing': {
                    'mode': mealTimingMode,
                    if (mealTimingMode != 'standard') 'start': mealStart,
                    if (mealTimingMode != 'standard') 'end': mealEnd,
                    if (mealTimingMode != 'standard') 'preset': mealPreset,
                    'slots': mealSlots,
                  },
                  'never_suggest': neverSuggest.toList(),
                  'unknown_ingredient_policy': unknownPolicy,
                  if (consent) 'health_consent_version': 'nutrition-profile-1',
                  if (medicalConsent)
                    'medical_consent_version': 'medical-nutrition-1',
                  if (widget.edit) 'expected_version': state.profile['version'],
                };
                await mutation.send(
                  ref.read(apiProvider),
                  'PUT',
                  '/profile',
                  data,
                );
                await ref.read(appProvider.notifier).hydrate();
                if (widget.edit && context.mounted) Navigator.of(context).pop();
              },
            ),
        ],
      ),
    );
  }
}
