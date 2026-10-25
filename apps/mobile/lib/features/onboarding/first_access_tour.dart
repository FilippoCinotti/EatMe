import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/localization.dart';
import '../../core/state.dart';

abstract final class FirstAccessTour {
  static String _key(String userId) => 'eatme.$userId.first_access_tour';

  static Future<void> markPending(String userId) => _write(userId, 'pending');

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

abstract final class FirstAccessTourTargets {
  static final navigation = GlobalKey(debugLabel: 'tour-navigation');
  static final chefHeader = GlobalKey(debugLabel: 'tour-chef-header');
  static final chefSearch = GlobalKey(debugLabel: 'tour-chef-search');
  static final chefModes = GlobalKey(debugLabel: 'tour-chef-modes');
  static final chefTools = GlobalKey(debugLabel: 'tour-chef-tools');
  static final fridgeHeader = GlobalKey(debugLabel: 'tour-fridge-header');
  static final fridgeSearch = GlobalKey(debugLabel: 'tour-fridge-search');
  static final fridgeFilters = GlobalKey(debugLabel: 'tour-fridge-filters');
  static final fridgeTools = GlobalKey(debugLabel: 'tour-fridge-tools');
  static final planTabs = GlobalKey(debugLabel: 'tour-plan-tabs');
  static final planWeek = GlobalKey(debugLabel: 'tour-plan-week');
  static final planActions = GlobalKey(debugLabel: 'tour-plan-actions');
  static final planMeals = GlobalKey(debugLabel: 'tour-plan-meals');
  static final profileSummary = GlobalKey(debugLabel: 'tour-profile-summary');
  static final profileSettings = GlobalKey(debugLabel: 'tour-profile-settings');
  static final profileTools = GlobalKey(debugLabel: 'tour-profile-tools');
  static final profileMore = GlobalKey(debugLabel: 'tour-profile-more');
}

class FirstAccessTourStep {
  const FirstAccessTourStep({
    required this.route,
    required this.target,
    required this.titleKey,
    required this.bodyKey,
  });

  final String route;
  final GlobalKey target;
  final String titleKey;
  final String bodyKey;
}

final firstAccessTourControllerProvider =
    NotifierProvider<FirstAccessTourController, int?>(
      FirstAccessTourController.new,
    );

class FirstAccessTourController extends Notifier<int?> {
  @override
  int? build() => null;

  int? get index => state;

  void start() {
    state = 0;
  }

  void next(int total) {
    if (state == null || state! >= total - 1) return;
    state = state! + 1;
  }

  void back() {
    if (state == null || state == 0) return;
    state = state! - 1;
  }

  void stop() {
    state = null;
  }
}

class FirstAccessTourOverlay extends ConsumerStatefulWidget {
  const FirstAccessTourOverlay({
    super.key,
    required this.router,
    required this.child,
  });

  final GoRouter router;
  final Widget child;

  @override
  ConsumerState<FirstAccessTourOverlay> createState() =>
      _FirstAccessTourOverlayState();
}

class _FirstAccessTourOverlayState
    extends ConsumerState<FirstAccessTourOverlay> {
  static final steps = <FirstAccessTourStep>[
    FirstAccessTourStep(
      route: '/chef',
      target: FirstAccessTourTargets.chefHeader,
      titleKey: 'chef_table',
      bodyKey: 'tour_chef_header_body',
    ),
    FirstAccessTourStep(
      route: '/chef',
      target: FirstAccessTourTargets.chefSearch,
      titleKey: 'recipe_search_hint',
      bodyKey: 'tour_chef_search_body',
    ),
    FirstAccessTourStep(
      route: '/chef',
      target: FirstAccessTourTargets.chefModes,
      titleKey: 'for_you',
      bodyKey: 'tour_chef_modes_body',
    ),
    FirstAccessTourStep(
      route: '/chef',
      target: FirstAccessTourTargets.chefTools,
      titleKey: 'your_kitchen',
      bodyKey: 'tour_chef_tools_body',
    ),
    FirstAccessTourStep(
      route: '/chef',
      target: FirstAccessTourTargets.navigation,
      titleKey: 'eatme',
      bodyKey: 'tour_navigation_body',
    ),
    FirstAccessTourStep(
      route: '/fridge',
      target: FirstAccessTourTargets.fridgeHeader,
      titleKey: 'add_food',
      bodyKey: 'tour_fridge_add_body',
    ),
    FirstAccessTourStep(
      route: '/fridge',
      target: FirstAccessTourTargets.fridgeSearch,
      titleKey: 'inventory_search_hint',
      bodyKey: 'tour_fridge_search_body',
    ),
    FirstAccessTourStep(
      route: '/fridge',
      target: FirstAccessTourTargets.fridgeFilters,
      titleKey: 'fridge',
      bodyKey: 'tour_fridge_filters_body',
    ),
    FirstAccessTourStep(
      route: '/fridge',
      target: FirstAccessTourTargets.fridgeTools,
      titleKey: 'scan_and_import',
      bodyKey: 'tour_fridge_tools_body',
    ),
    FirstAccessTourStep(
      route: '/plan',
      target: FirstAccessTourTargets.planTabs,
      titleKey: 'plan',
      bodyKey: 'tour_plan_tabs_body',
    ),
    FirstAccessTourStep(
      route: '/plan',
      target: FirstAccessTourTargets.planWeek,
      titleKey: 'change_week',
      bodyKey: 'tour_plan_week_body',
    ),
    FirstAccessTourStep(
      route: '/plan',
      target: FirstAccessTourTargets.planActions,
      titleKey: 'generate_week',
      bodyKey: 'tour_plan_actions_body',
    ),
    FirstAccessTourStep(
      route: '/plan',
      target: FirstAccessTourTargets.planMeals,
      titleKey: 'day_plan',
      bodyKey: 'tour_plan_meals_body',
    ),
    FirstAccessTourStep(
      route: '/profile',
      target: FirstAccessTourTargets.profileSummary,
      titleKey: 'profile',
      bodyKey: 'tour_profile_summary_body',
    ),
    FirstAccessTourStep(
      route: '/profile',
      target: FirstAccessTourTargets.profileSettings,
      titleKey: 'preferences',
      bodyKey: 'tour_profile_settings_body',
    ),
    FirstAccessTourStep(
      route: '/profile',
      target: FirstAccessTourTargets.profileTools,
      titleKey: 'your_kitchen',
      bodyKey: 'tour_profile_tools_body',
    ),
    FirstAccessTourStep(
      route: '/profile',
      target: FirstAccessTourTargets.profileMore,
      titleKey: 'more',
      bodyKey: 'tour_profile_more_body',
    ),
  ];

  Rect? targetRect;
  int? preparedIndex;

  Future<void> prepare(FirstAccessTourStep step, int index) async {
    if (preparedIndex == index) return;
    preparedIndex = index;
    targetRect = null;
    final currentPath =
        widget.router.routerDelegate.currentConfiguration.uri.path;
    if (currentPath != step.route) {
      widget.router.go(step.route);
      await Future<void>.delayed(const Duration(milliseconds: 240));
    }
    if (!mounted ||
        ref.read(firstAccessTourControllerProvider.notifier).index != index) {
      return;
    }
    var targetContext = step.target.currentContext;
    for (var attempt = 0; targetContext == null && attempt < 8; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      targetContext = step.target.currentContext;
    }
    if (targetContext == null || !targetContext.mounted || !mounted) return;
    await Scrollable.ensureVisible(
      targetContext,
      alignment: .42,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
    await Future<void>.delayed(const Duration(milliseconds: 40));
    final box = step.target.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !mounted) return;
    final origin = box.localToGlobal(Offset.zero);
    setState(() => targetRect = (origin & box.size).inflate(8));
  }

  Future<void> finish() async {
    final userId = ref.read(apiProvider).userId;
    if (userId != null) await FirstAccessTour.complete(userId);
    ref.read(firstAccessTourControllerProvider.notifier).stop();
    widget.router.go('/chef');
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(firstAccessTourControllerProvider);
    final controller = ref.read(firstAccessTourControllerProvider.notifier);
    if (index == null) {
      preparedIndex = null;
      targetRect = null;
      return widget.child;
    }
    final step = steps[index];
    WidgetsBinding.instance.addPostFrameCallback((_) => prepare(step, index));
    final size = MediaQuery.sizeOf(context);
    final safeTop = MediaQuery.paddingOf(context).top + 12;
    final safeBottom = MediaQuery.paddingOf(context).bottom + 12;
    final rect = targetRect;
    const cardHeight = 230.0;
    final placeBelow = rect == null || rect.center.dy < size.height * .46;
    final cardTop = placeBelow
        ? math.min(
            (rect?.bottom ?? safeTop) + 24,
            size.height - cardHeight - safeBottom,
          )
        : math.max(safeTop, rect.top - cardHeight - 24);
    final cardRect = Rect.fromLTWH(20, cardTop, size.width - 40, cardHeight);
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        Semantics(
          scopesRoute: true,
          namesRoute: true,
          label:
              '${context.t('first_tour_progress', {'current': index + 1, 'total': steps.length})}. ${context.t(step.titleKey)}. ${context.t(step.bodyKey)}',
          child: Material(
            color: Colors.transparent,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _TourScrimPainter(
                      target: rect,
                      card: cardRect,
                      color: Colors.black.withValues(alpha: .68),
                      accent: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                Positioned.fromRect(
                  rect: cardRect,
                  child: _TourCard(
                    title: context.t(step.titleKey),
                    body: context.t(step.bodyKey),
                    progress: context.t('first_tour_progress', {
                      'current': index + 1,
                      'total': steps.length,
                    }),
                    canGoBack: index > 0,
                    isLast: index == steps.length - 1,
                    onBack: () {
                      targetRect = null;
                      preparedIndex = null;
                      controller.back();
                    },
                    onNext: index == steps.length - 1
                        ? finish
                        : () {
                            targetRect = null;
                            preparedIndex = null;
                            controller.next(steps.length);
                          },
                    onSkip: finish,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TourCard extends StatelessWidget {
  const _TourCard({
    required this.title,
    required this.body,
    required this.progress,
    required this.canGoBack,
    required this.isLast,
    required this.onBack,
    required this.onNext,
    required this.onSkip,
  });

  final String title;
  final String body;
  final String progress;
  final bool canGoBack;
  final bool isLast;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 12,
      color: scheme.surface,
      borderRadius: BorderRadius.circular(26),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    progress,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  key: const ValueKey('first-tour-skip'),
                  onPressed: onSkip,
                  child: Text(context.t('first_tour_skip')),
                ),
              ],
            ),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  body,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ),
            ),
            Row(
              children: [
                if (canGoBack)
                  TextButton(
                    key: const ValueKey('first-tour-back'),
                    onPressed: onBack,
                    child: Text(context.t('first_tour_back')),
                  ),
                const Spacer(),
                FilledButton(
                  key: ValueKey(
                    isLast ? 'first-tour-finish' : 'first-tour-next',
                  ),
                  onPressed: onNext,
                  child: Text(
                    context.t(isLast ? 'first_tour_start' : 'first_tour_next'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TourScrimPainter extends CustomPainter {
  const _TourScrimPainter({
    required this.target,
    required this.card,
    required this.color,
    required this.accent,
  });

  final Rect? target;
  final Rect card;
  final Color color;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final hole = target;
    final scrim = Path()..addRect(Offset.zero & size);
    if (hole != null) {
      scrim.addRRect(RRect.fromRectAndRadius(hole, const Radius.circular(20)));
      scrim.fillType = PathFillType.evenOdd;
    }
    canvas.drawPath(scrim, Paint()..color = color);
    if (hole == null) return;
    canvas.drawRRect(
      RRect.fromRectAndRadius(hole, const Radius.circular(20)),
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    final from = card.center.dy > hole.center.dy
        ? Offset(hole.center.dx, hole.bottom + 4)
        : Offset(hole.center.dx, hole.top - 4);
    final to = card.center.dy > hole.center.dy
        ? Offset(card.center.dx, card.top - 8)
        : Offset(card.center.dx, card.bottom + 8);
    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..quadraticBezierTo(from.dx, (from.dy + to.dy) / 2, to.dx, to.dy);
    canvas.drawPath(
      path,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    final angle = math.atan2(to.dy - from.dy, to.dx - from.dx);
    const arrow = 10.0;
    final arrowPath = Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo(
        to.dx - arrow * math.cos(angle - math.pi / 6),
        to.dy - arrow * math.sin(angle - math.pi / 6),
      )
      ..moveTo(to.dx, to.dy)
      ..lineTo(
        to.dx - arrow * math.cos(angle + math.pi / 6),
        to.dy - arrow * math.sin(angle + math.pi / 6),
      );
    canvas.drawPath(
      arrowPath,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _TourScrimPainter oldDelegate) =>
      oldDelegate.target != target ||
      oldDelegate.card != card ||
      oldDelegate.color != color ||
      oldDelegate.accent != accent;
}

class FirstAccessTourPage extends ConsumerStatefulWidget {
  const FirstAccessTourPage({super.key});

  @override
  ConsumerState<FirstAccessTourPage> createState() =>
      _FirstAccessTourPageState();
}

class _FirstAccessTourPageState extends ConsumerState<FirstAccessTourPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(firstAccessTourControllerProvider.notifier).start();
      if (mounted) GoRouter.maybeOf(context)?.go('/chef');
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          context.t('first_tour_chef_body'),
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
}
