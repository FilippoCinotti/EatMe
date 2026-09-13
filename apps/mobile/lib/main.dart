import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/api.dart';
import 'core/localization.dart';
import 'core/state.dart';
import 'design_system/theme.dart';
import 'design_system/widgets.dart';
import 'features/organize/shopping.dart';
import 'features/organize/planner.dart';
import 'features/organize/household.dart';
import 'features/organize/leftovers.dart';
import 'features/organize/recipe_library.dart';
import 'features/organize/scanning.dart';
import 'features/organize/settings.dart';
import 'features/organize/subscriptions.dart';
import 'core/models.dart';
import 'features/auth/login.dart';
import 'features/auth/reauthenticate.dart';
import 'features/onboarding/onboarding.dart';
import 'features/chef_table/chef_table.dart';
import 'features/fridge/fridge.dart';
import 'features/fridge/custom_food.dart';
import 'features/fridge/expiry.dart';
import 'features/organize/wellbeing.dart';
import 'features/healthy_food/healthy_food.dart';
import 'features/profile/profile.dart';
import 'features/recipe/recipe.dart';
import 'features/cooking/cooking.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!EatMeApi.development) {
    await Supabase.initialize(
      url: const String.fromEnvironment('SUPABASE_URL'),
      publishableKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
      authOptions: const FlutterAuthClientOptions(
        localStorage: SecureAuthStorage(),
      ),
    );
  }
  runApp(const ProviderScope(child: EatMeApp()));
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(appProvider, (previous, next) {
    if (previous?.stage != next.stage) refresh.value++;
  });
  final router = GoRouter(
    initialLocation: '/launch',
    refreshListenable: refresh,
    redirect: (context, state) {
      final stage = ref.read(appProvider).stage, path = state.uri.path;
      if (stage == Stage.loading || stage == Stage.failed) {
        return path == '/launch' ? null : '/launch';
      }
      if (stage == Stage.login) return path == '/login' ? null : '/login';
      if (stage == Stage.onboarding) {
        return path == '/onboarding' ? null : '/onboarding';
      }
      if ([
        '/launch',
        '/login',
        '/onboarding',
        '/login-callback',
      ].contains(path)) {
        return '/chef';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/launch', builder: (_, _) => const LaunchPage()),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/login-callback', builder: (_, _) => const LaunchPage()),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingPage()),
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(path: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/chef', builder: (_, _) => const ChefTablePage()),
          GoRoute(path: '/fridge', builder: (_, _) => const FridgePage()),
          GoRoute(
            path: '/healthy-food',
            builder: (_, _) => const HealthyFoodPage(),
          ),
          GoRoute(path: '/profile', builder: (_, _) => const ProfilePage()),
        ],
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (_, _) => const OnboardingPage(edit: true),
      ),
      GoRoute(
        path: '/reauthenticate',
        builder: (_, _) => const ReauthenticatePage(),
      ),
      GoRoute(path: '/privacy', builder: (_, _) => const PrivacyPage()),
      GoRoute(path: '/cooking-complete', builder: (_, state) => CookingCompletePage(recipeId: state.uri.queryParameters['recipe'] ?? '', leftovers: int.tryParse(state.uri.queryParameters['leftovers'] ?? '0') ?? 0)),
      GoRoute(path: '/custom-food', builder: (_, _) => const CustomFoodPage()),
      GoRoute(path: '/expiry', builder: (_, _) => const ExpiryPage()),
      GoRoute(path: '/wellbeing', builder: (_, _) => const WellbeingPage()),
      GoRoute(path: '/household-activity', builder: (_, _) => const HouseholdActivityPage()),
      GoRoute(path: '/shopping', builder: (_, _) => const ShoppingPage()),
      GoRoute(path: '/planner', builder: (_, _) => const PlannerPage()),
      GoRoute(path: '/household', builder: (_, _) => const HouseholdPage()),
      GoRoute(path: '/leftovers', builder: (_, _) => const LeftoversPage()),
      GoRoute(
        path: '/recipe-library',
        builder: (_, state) => RecipeLibraryPage(initialFavorites: state.uri.queryParameters['favorites'] == 'true'),
      ),
      GoRoute(
        path: '/recipe-editor',
        builder: (_, state) => RecipeEditorPage(initial: state.extra as Json?),
      ),
      GoRoute(path: '/scanning', builder: (_, _) => const ScanningPage()),
      GoRoute(path: '/barcode', builder: (_, _) => const BarcodePage()),
      GoRoute(path: '/preferences', builder: (_, _) => const PreferencesPage()),
      GoRoute(
        path: '/notifications',
        builder: (_, _) => const NotificationsPage(),
      ),
      GoRoute(path: '/evidence', builder: (_, _) => const EvidencePage()),
      GoRoute(path: '/insights', builder: (_, _) => const InsightsPage()),
      GoRoute(path: '/sync', builder: (_, _) => const SyncPage()),
      GoRoute(
        path: '/subscriptions',
        builder: (_, _) => const SubscriptionsPage(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (_, _) => const ResetPasswordPage(),
      ),
      GoRoute(
        path: '/recipes/:id',
        builder: (_, state) =>
            RecipePage(recipeId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/cook/:id',
        builder: (_, state) => CookingPage(
          recipeId: state.pathParameters['id']!,
          participants: state.extra as List<String>?,
          servings:
              (int.tryParse(state.uri.queryParameters['servings'] ?? '1') ?? 1)
                  .clamp(1, 20)
                  .toInt(),
        ),
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

class EatMeApp extends ConsumerStatefulWidget {
  const EatMeApp({super.key});
  @override
  ConsumerState<EatMeApp> createState() => _EatMeAppState();
}

class _EatMeAppState extends ConsumerState<EatMeApp> {
  StreamSubscription<AuthState>? subscription;
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(appProvider.notifier).restore());
    if (!EatMeApi.development) {
      subscription = Supabase.instance.client.auth.onAuthStateChange.listen((
        event,
      ) async {
        if (!mounted) return;
        if (event.event == AuthChangeEvent.signedIn ||
            event.event == AuthChangeEvent.signedOut) {
          await ref.read(appProvider.notifier).restore();
        }
        if (event.event == AuthChangeEvent.passwordRecovery) {
          await ref.read(appProvider.notifier).restore();
          if (mounted) ref.read(routerProvider).push('/reset-password');
        }
      });
    }
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appProvider);
    return MaterialApp.router(
      title: 'EatMe',
      debugShowCheckedModeBanner: false,
      builder: (context, child) => AdaptiveAppFrame(child: child!),
      theme: Tokens.theme(Brightness.light),
      darkTheme: Tokens.theme(Brightness.dark),
      themeMode: state.theme,
      locale: state.locale,
      supportedLocales: const [Locale('it'), Locale('en')],
      localizationsDelegates: const [
        EatMeStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: ref.watch(routerProvider),
    );
  }
}

class LaunchPage extends ConsumerWidget {
  const LaunchPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appProvider);
    return Scaffold(
      body: state.stage == Stage.failed
          ? PageBody(
              children: [
                const SizedBox(height: 64),
                StatusNote(
                  text: context.t(state.error ?? 'unknown_error'),
                  warning: true,
                ),
                AsyncAction(
                  label: context.t('retry'),
                  action: () => ref.read(appProvider.notifier).restore(),
                ),
                AsyncAction(
                  label: context.t('return_login'),
                  secondary: true,
                  action: () async {
                    await ref.read(apiProvider).clearSession();
                    await ref.read(appProvider.notifier).restore();
                  },
                ),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.path, required this.child});
  final String path;
  final Widget child;
  static const paths = ['/chef', '/fridge', '/healthy-food', '/profile'];
  @override
  Widget build(BuildContext context) => Scaffold(
    body: child,
    bottomNavigationBar: SafeArea(
      minimum: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      child: Align(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: MediaQuery.highContrastOf(context) ? 0 : 12,
                sigmaY: MediaQuery.highContrastOf(context) ? 0 : 12,
              ),
              child: NavigationBar(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainer.withValues(alpha: .92),
                elevation: 0,
                selectedIndex: paths.indexOf(path).clamp(0, 3).toInt(),
                onDestinationSelected: (index) => context.go(paths[index]),
                destinations: [
                  NavigationDestination(
                    icon: const Icon(Icons.restaurant_menu_outlined),
                    selectedIcon: const Icon(Icons.restaurant_menu),
                    label: context.t('chef_table'),
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.kitchen_outlined),
                    selectedIcon: const Icon(Icons.kitchen),
                    label: context.t('fridge'),
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.eco_outlined),
                    selectedIcon: const Icon(Icons.eco),
                    label: context.t('healthy_food'),
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.person_outline),
                    selectedIcon: const Icon(Icons.person),
                    label: context.t('profile'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
