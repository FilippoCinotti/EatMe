import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/localization.dart';
import '../../core/state.dart';
import '../../design_system/widgets.dart';

abstract final class FirstAccessTour {
  static String _key(String userId) => 'eatme.$userId.first_access_tour';

  static Future<void> markPending(String userId) =>
      _write(userId, 'pending');

  static Future<bool> isPending(String userId) async {
    try {
      return await EatMeApi.secure.read(key: _key(userId)) == 'pending';
    } on MissingPluginException {
      return false;
    }
  }

  static Future<void> complete(String userId) => _write(userId, 'complete');

  static Future<void> _write(String userId, String value) async {
    try {
      await EatMeApi.secure.write(key: _key(userId), value: value);
    } on MissingPluginException {
      // Secure storage is unavailable in widget tests and non-native previews.
    }
  }
}

class FirstAccessTourPage extends ConsumerStatefulWidget {
  const FirstAccessTourPage({super.key});

  @override
  ConsumerState<FirstAccessTourPage> createState() =>
      _FirstAccessTourPageState();
}

class _FirstAccessTourPageState extends ConsumerState<FirstAccessTourPage> {
  final controller = PageController();
  int step = 0;

  static const steps = <(String, String, EatMeGlyph)>[
    ('first_tour_chef_title', 'first_tour_chef_body', EatMeGlyph.chefHat),
    (
      'first_tour_fridge_title',
      'first_tour_fridge_body',
      EatMeGlyph.refrigerator,
    ),
    ('first_tour_plan_title', 'first_tour_plan_body', EatMeGlyph.calendarDays),
    (
      'first_tour_profile_title',
      'first_tour_profile_body',
      EatMeGlyph.shieldCheck,
    ),
  ];

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> finish() async {
    final userId = ref.read(apiProvider).userId;
    if (userId != null) await FirstAccessTour.complete(userId);
    if (mounted) context.go('/chef');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final last = step == steps.length - 1;
    return Scaffold(
      appBar: EatMeAppBar(
        leading: const SizedBox(width: 48),
        title: const EatMeWordmark(),
        actions: [
          TextButton(
            key: const ValueKey('first-tour-skip'),
            onPressed: finish,
            child: Text(context.t('first_tour_skip')),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  context.t('first_tour_progress', {
                    'current': step + 1,
                    'total': steps.length,
                  }),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (var index = 0; index < steps.length; index++) ...[
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        height: 4,
                        decoration: BoxDecoration(
                          color: index <= step
                              ? scheme.primary
                              : scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    if (index < steps.length - 1) const SizedBox(width: 7),
                  ],
                ],
              ),
              const SizedBox(height: 22),
              Expanded(
                child: PageView.builder(
                  key: const ValueKey('first-access-tour'),
                  controller: controller,
                  itemCount: steps.length,
                  onPageChanged: (value) => setState(() => step = value),
                  itemBuilder: (context, index) => _TourStep(
                    icon: steps[index].$3,
                    title: context.t(steps[index].$1),
                    body: context.t(steps[index].$2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  if (step > 0) ...[
                    Expanded(
                      child: OutlinedButton(
                        key: const ValueKey('first-tour-back'),
                        onPressed: () => controller.previousPage(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                        ),
                        child: Text(context.t('first_tour_back')),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: step > 0 ? 2 : 1,
                    child: FilledButton(
                      key: ValueKey(
                        last ? 'first-tour-finish' : 'first-tour-next',
                      ),
                      onPressed: last
                          ? finish
                          : () => controller.nextPage(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOut,
                            ),
                      child: Text(
                        context.t(
                          last ? 'first_tour_start' : 'first_tour_next',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TourStep extends StatelessWidget {
  const _TourStep({
    required this.icon,
    required this.title,
    required this.body,
  });

  final EatMeGlyph icon;
  final String title, body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      namesRoute: true,
      label: '$title. $body',
      child: SingleChildScrollView(
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 360),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: scheme.surfaceContainer,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: EatMeIcon(icon, size: 30, color: scheme.primary),
                ),
              ),
              const SizedBox(height: 38),
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              Text(
                body,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
