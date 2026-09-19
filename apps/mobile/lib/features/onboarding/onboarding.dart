import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api.dart';
import '../../core/localization.dart';
import '../../core/models.dart';
import '../../core/state.dart';
import '../../design_system/widgets.dart';

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
    name.dispose();
    timezone.dispose();
    super.dispose();
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
    final state = ref.watch(appProvider);
    return Scaffold(
      appBar: EatMeAppBar(
        title: Text(context.t(widget.edit ? 'edit_profile' : 'make_it_yours')),
        leading: step > 0
            ? IconButton(
                tooltip: context.t('back'),
                icon: const EatMeIcon(EatMeGlyph.chevronLeft),
                onPressed: () => setState(() => step--),
              )
            : null,
      ),
      body: PageBody(
        children: [
          Text(
            context.t('step_count', {'current': step + 1, 'total': 6}),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 24),
          if (step == 0) ...[
            Text(
              context.t('welcome_title'),
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 28),
            Text(
              context.t('primary_goal'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final goal in ['eat_better', 'waste_less', 'follow_diet'])
                  ChoiceChip(
                    label: Text(context.t('goal_$goal')),
                    selected: primaryGoal == goal,
                    onSelected: (_) => setState(() => primaryGoal = goal),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: name,
              decoration: InputDecoration(labelText: context.t('name')),
            ),
            const SizedBox(height: 24),
            Text(
              context.t('household_question'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Row(
              children: [
                IconButton(
                  tooltip: context.t('fewer'),
                  onPressed: size > 1 ? () => setState(() => size--) : null,
                  icon: const Icon(Icons.remove),
                ),
                Text(
                  '$size',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                IconButton(
                  tooltip: context.t('more'),
                  onPressed: size < 20 ? () => setState(() => size++) : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
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
            for (final diet in state.diets.where(
              (d) => d.selectable && !d.medical,
            ))
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(localized(diet.name, context.language)),
                value: selected.contains(diet.id),
                onChanged: (v) => setState(() {
                  if (v == true) {
                    selected.add(diet.id);
                  } else {
                    selected.remove(diet.id);
                    if (primaryDiet == diet.id) {
                      primaryDiet = selected.firstOrNull;
                    }
                  }
                }),
              ),
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
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: state.allergens
                  .map(
                    (a) => FilterChip(
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
            SectionHeading(title: context.t('intolerances')),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: state.intolerances
                  .map(
                    (value) => FilterChip(
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
            const SizedBox(height: 18),
            SectionHeading(title: context.t('sensitivities')),
            Text(context.t('sensitivities_help')),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: state.sensitivities
                  .map(
                    (value) => FilterChip(
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
            for (final diet in state.diets.where(
              (d) => d.selectable && d.medical,
            ))
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(localized(diet.name, context.language)),
                subtitle: Text(context.t('self_declared_health_profile')),
                value: selected.contains(diet.id),
                onChanged: (enabled) => setState(() {
                  enabled == true
                      ? selected.add(diet.id)
                      : selected.remove(diet.id);
                  if (enabled == true) medicalConsent = false;
                }),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: state.medicalAwareness
                  .map(
                    (value) => FilterChip(
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
            EatMeSelectionRow(
              icon: EatMeGlyph.clock,
              title: context.t('meal_timing_standard'),
              subtitle: context.t('meal_timing_standard_body'),
              selected: mealTimingMode == 'standard',
              onTap: () => setState(() => mealTimingMode = 'standard'),
            ),
            const SizedBox(height: 10),
            EatMeSelectionRow(
              icon: EatMeGlyph.timer,
              title: context.t('meal_timing_window'),
              subtitle: context.t('meal_timing_window_body'),
              selected: mealTimingMode != 'standard',
              onTap: () => setState(() => mealTimingMode = 'time_restricted'),
            ),
            if (mealTimingMode != 'standard') ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final value in ['12:12', '14:10', '16:8', '18:6'])
                    ChoiceChip(
                      label: Text(value),
                      selected: mealPreset == value,
                      onSelected: (_) => setState(() {
                        mealPreset = value;
                        final window = {
                          '12:12': ('08:00', '20:00'),
                          '14:10': ('10:00', '20:00'),
                          '16:8': ('12:00', '20:00'),
                          '18:6': ('14:00', '20:00'),
                        }[value]!;
                        mealStart = window.$1;
                        mealEnd = window.$2;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => chooseMealTime(start: true),
                      child: Text(
                        context.t('window_start', {'time': mealStart}),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => chooseMealTime(start: false),
                      child: Text(context.t('window_end', {'time': mealEnd})),
                    ),
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
              onPressed: () => setState(() => step++),
              child: Text(context.t('continue')),
            ),
            if (step > 0)
              TextButton(
                onPressed: () => setState(() => step++),
                child: Text(context.t('skip_for_now')),
              ),
          ] else
            AsyncAction(
              label: context.t(widget.edit ? 'save' : 'start_eatme'),
              action: () async {
                if (!adult || name.text.trim().isEmpty) {
                  setState(() => step = 0);
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
