import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/api.dart';
import '../../core/entitlements.dart';
import '../../core/localization.dart';
import '../../core/models.dart';
import '../../core/share_text.dart';
import '../../core/state.dart';
import '../../design_system/widgets.dart';
import 'shared.dart';

class DinnersPage extends ConsumerStatefulWidget {
  const DinnersPage({super.key});
  @override
  ConsumerState<DinnersPage> createState() => _DinnersPageState();
}

class _DinnersPageState extends ResourceState<DinnersPage> {
  @override
  String get path => '/dinners';

  Future<void> createDinner() async {
    final title = await askText(context, context.t('dinner_title'));
    if (title == null || title.isEmpty || !mounted) return;
    final day = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 19, minute: 30),
    );
    if (time == null || !mounted) return;
    final location = await askText(context, context.t('dinner_location'));
    if (!mounted) return;
    final start = DateTime(
      day.year,
      day.month,
      day.day,
      time.hour,
      time.minute,
    ).toUtc();
    final settings = Map<String, dynamic>.from(
      ref.read(appProvider).profile['settings'] as Map? ?? const {},
    );
    final result = await command({
      'action': 'create',
      'title': title,
      'starts_at': start.toIso8601String(),
      'timezone': settings['timezone'] as String? ?? 'UTC',
      if (location != null && location.isNotEmpty) 'location': location,
    });
    if (mounted && result['id'] != null) {
      context.push('/plan/dinners/${result['id']}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final events = records(data?['items']);
    return Scaffold(
      appBar: EatMeAppBar(title: Text(context.t('with_friends'))),
      body: content([
        EatMeTabStrip(
          values: [
            ('plan', context.t('my_plan')),
            ('dinners', context.t('with_friends')),
            ('shopping', context.t('shopping_list')),
          ],
          selected: 'dinners',
          onSelected: (value) {
            if (value == 'plan') context.go('/plan');
            if (value == 'shopping') context.go('/plan/shopping');
          },
        ),
        const SizedBox(height: 24),
        Text(
          context.t('with_friends').toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            letterSpacing: 2.35,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.t('dinner_planning_title'),
          style: Theme.of(context).textTheme.displaySmall,
        ),
        const SizedBox(height: 8),
        Text(
          context.t('dinner_planning_body'),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        AsyncAction(label: context.t('create_dinner'), action: createDinner),
        if (events.isEmpty)
          EmptyMessage(
            title: context.t('no_dinners'),
            body: context.t('no_dinners_body'),
          )
        else ...[
          const SizedBox(height: 28),
          _Heading(title: context.t('your_dinners')),
          for (final (index, event) in events.indexed) ...[
            if (index > 0) const SizedBox(height: 10),
            _DinnerCard(
              event: event,
              featured: index == 0 && event['status'] == 'planned',
              onTap: () => context.push('/plan/dinners/${event['id']}'),
            ),
          ],
        ],
      ]),
    );
  }
}

class DinnerDetailPage extends ConsumerStatefulWidget {
  const DinnerDetailPage({super.key, required this.dinnerId});
  final String dinnerId;
  @override
  ConsumerState<DinnerDetailPage> createState() => _DinnerDetailPageState();
}

class _DinnerDetailPageState extends ConsumerState<DinnerDetailPage> {
  final mutation = Mutation();
  Json? event;
  List<Json> recipes = [];
  String? error;
  bool updating = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(load);
  }

  Future<void> load() async {
    try {
      final api = ref.read(apiProvider);
      final responses = await Future.wait([
        api.request('GET', '/dinners/${widget.dinnerId}'),
        api.request('GET', '/recipes'),
      ]);
      if (mounted) {
        setState(() {
          event = responses[0];
          recipes = records(responses[1]['items']);
          error = null;
        });
      }
    } on ApiFailure catch (failure) {
      if (mounted) setState(() => error = failure.code);
    }
  }

  Future<Json> send(Json body) async {
    if (updating) throw const ApiFailure('operation_in_progress');
    updating = true;
    try {
      final result = await mutation.send(
        ref.read(apiProvider),
        'POST',
        '/dinners',
        {...body, 'id': widget.dinnerId, 'expected_version': event!['version']},
      );
      if (mounted) setState(() => event = result);
      return result;
    } finally {
      updating = false;
    }
  }

  Future<void> addTemporaryGuest() async {
    final name = await askText(context, context.t('guest_name'));
    if (name == null || name.isEmpty) return;
    await send({
      'action': 'add_participant',
      'kind': 'temporary_guest',
      'display_name': name,
    });
  }

  Future<void> addHouseholdMember() async {
    final home = await ref.read(apiProvider).request('GET', '/households');
    if (!mounted) return;
    final existing = records(
      event?['participants'],
    ).map((item) => item['user_id']).toSet();
    final candidates = records(
      home['members'],
    ).where((item) => !existing.contains(item['user_id'])).toList();
    final selected = await showModalBottomSheet<Json>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      builder: (context) => ListView(
        children: [
          for (final member in candidates)
            ListTile(
              title: Text(member['name'] as String),
              subtitle: Text(context.t('dinner_household_member')),
              onTap: () => Navigator.pop(context, member),
            ),
        ],
      ),
    );
    if (selected != null) {
      await send({
        'action': 'add_participant',
        'kind': 'household_member',
        'user_id': selected['user_id'],
      });
    }
  }

  Future<void> addSavedGuest() async {
    final response = await ref
        .read(apiProvider)
        .request('GET', '/dinner-guests');
    if (!mounted) return;
    final selected = await showModalBottomSheet<Json>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      builder: (context) => ListView(
        children: [
          for (final guest in records(response['items']))
            ListTile(
              title: Text(guest['display_name'] as String),
              subtitle: Text(context.t('saved_guest')),
              onTap: () => Navigator.pop(context, guest),
            ),
        ],
      ),
    );
    if (selected != null) {
      await send({
        'action': 'add_participant',
        'kind': 'saved_guest',
        'saved_guest_id': selected['id'],
      });
    }
  }

  Future<void> showAddParticipant() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            leading: const EatMeIcon(EatMeGlyph.userRound),
            title: Text(context.t('new_guest')),
            onTap: () => Navigator.pop(context, 'temporary'),
          ),
          ListTile(
            leading: const EatMeIcon(EatMeGlyph.usersRound),
            title: Text(context.t('dinner_household_member')),
            onTap: () => Navigator.pop(context, 'household'),
          ),
          ListTile(
            leading: const EatMeIcon(EatMeGlyph.history),
            title: Text(context.t('saved_guest')),
            onTap: () => Navigator.pop(context, 'saved'),
          ),
        ],
      ),
    );
    if (action == 'temporary') await addTemporaryGuest();
    if (action == 'household') await addHouseholdMember();
    if (action == 'saved') await addSavedGuest();
  }

  Future<void> invite(Json participant, {String action = 'create'}) async {
    final result = await Mutation().send(
      ref.read(apiProvider),
      'POST',
      '/dinners/${widget.dinnerId}/invitations',
      {'action': action, 'participant_id': participant['id']},
    );
    if (!mounted) return;
    final url = result['url'] as String;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.t('guest_invitation')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                label: context.t('invitation_qr'),
                child: SizedBox.square(
                  dimension: 234,
                  child: ColoredBox(
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: QrImageView(data: url, size: 210),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SelectableText(url),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: url));
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(context.t('copy_link')),
          ),
          TextButton(
            onPressed: () async {
              await shareText(
                context,
                event!['title'] as String,
                context.t('dinner_invite_share', {'url': url}),
              );
            },
            child: Text(context.t('share')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.t('close')),
          ),
        ],
      ),
    );
    await load();
  }

  Future<void> revokeInvite(Json participant) async {
    await Mutation().send(
      ref.read(apiProvider),
      'POST',
      '/dinners/${widget.dinnerId}/invitations',
      {'action': 'revoke', 'participant_id': participant['id']},
    );
    await load();
  }

  Future<void> renameGuest(Json participant) async {
    final name = await askText(
      context,
      context.t('guest_name'),
      initial: participant['display_name'] as String,
    );
    if (name == null || name.isEmpty) return;
    await send({
      'action': 'update_participant',
      'participant_id': participant['id'],
      'display_name': name,
    });
  }

  Future<void> showGuestResponse(Json participant) async {
    final response = participant['response'];
    if (response is! Map || !mounted) return;
    final value = Map<String, dynamic>.from(response);
    String list(String key) =>
        List<String>.from(value[key] as List? ?? const []).join(', ');
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(participant['display_name'] as String),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${context.t('allergies')}: ${list('allergies')}'),
              Text('${context.t('intolerances')}: ${list('intolerances')}'),
              Text('${context.t('sensitivities')}: ${list('sensitivities')}'),
              if ((value['note'] as String? ?? '').isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(value['note'] as String),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.t('close')),
          ),
        ],
      ),
    );
  }

  Future<void> chooseMenu() async {
    final selected = List<String>.from(event?['menu'] as List? ?? const []);
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => SizedBox(
          height: MediaQuery.sizeOf(context).height * .78,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  context.t('choose_menu'),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              Expanded(
                child: ListView(
                  children: [
                    for (final recipe in recipes)
                      CheckboxListTile(
                        title: Text(labelOf(recipe['title'], context)),
                        subtitle: Text('${recipe['minutes']} min'),
                        value: selected.contains(recipe['id']),
                        onChanged: (value) => update(() {
                          if (value == true) {
                            selected.add(recipe['id'] as String);
                          } else {
                            selected.remove(recipe['id']);
                          }
                        }),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, selected),
                  child: Text(context.t('save_menu')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (result != null) {
      await send({
        'action': 'set_menu',
        'recipe_ids': result,
        'extra_portions': event?['extra_portions'] ?? 0,
      });
    }
  }

  Future<void> setExtraPortions(int value) async {
    await send({
      'action': 'set_menu',
      'recipe_ids': List<String>.from(event?['menu'] as List? ?? const []),
      'extra_portions': value.clamp(0, 20).toInt(),
    });
  }

  Future<void> completeDinner() async {
    var remember = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(context.t('complete_dinner')),
          content: CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.t('save_meal_memory')),
            subtitle: Text(context.t('meal_memory_detail')),
            value: remember,
            onChanged: (value) => update(() => remember = value == true),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.t('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.t('complete')),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true) {
      await send({'action': 'complete', 'meal_memory': remember});
    }
  }

  /// Runs a tile action with the same error feedback as AsyncAction.
  Future<void> guarded(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      final code = error is ApiFailure ? error.code : 'unknown_error';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.t(code))));
    }
  }

  Future<void> buildDinnerShopping() async {
    final entitlement = await ref.read(entitlementsProvider.future);
    if (!entitlement.can(EntitlementCapability.generatedShopping)) {
      if (mounted) {
        await showContextualPlusPrompt(
          context,
          benefit: 'dinner_shopping_plus_body',
        );
      }
      return;
    }
    await send({'action': 'generate_shopping'});
    if (mounted) context.go('/plan/shopping');
  }

  Future<void> cancelDinner() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.t('cancel_dinner')),
        content: Text(context.t('cancel_dinner_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.t('back')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.t('cancel_dinner')),
          ),
        ],
      ),
    );
    if (confirmed == true) await send({'action': 'cancel'});
  }

  Json? recipeById(String id) =>
      recipes.where((recipe) => recipe['id'] == id).firstOrNull;

  @override
  Widget build(BuildContext context) {
    if (event == null) {
      return Scaffold(
        appBar: EatMeAppBar(title: Text(context.t('dinners'))),
        body: Center(
          child: error == null
              ? const CircularProgressIndicator()
              : AsyncAction(label: context.t('retry'), action: load),
        ),
      );
    }
    final participants = records(event!['participants']);
    final invitations = records(event!['invitations']);
    final menu = List<String>.from(event!['menu'] as List? ?? const []);
    final fit = {
      for (final item in records(event!['diet_fit']))
        item['recipe_id'] as String: item,
    };
    final timeline = records(event!['timeline']);
    final active = event!['status'] == 'planned';
    final extra = event!['extra_portions'] as int? ?? 0;
    final guests = participants
        .where(
          (item) => ['temporary_guest', 'saved_guest'].contains(item['kind']),
        )
        .toList();
    final answered = guests.where((item) => item['status'] != 'invited').length;
    final canShop =
        ref
            .watch(entitlementsProvider)
            .asData
            ?.value
            .can(EntitlementCapability.generatedShopping) ??
        true;
    final starts = DateTime.parse(event!['starts_at'] as String).toLocal();
    final kicker =
        '${MaterialLocalizations.of(context).formatMediumDate(starts)} · '
        '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(starts))}';
    return Scaffold(
      appBar: EatMeAppBar(title: Text(context.t('with_friends'))),
      body: PageBody(
        onRefresh: load,
        children: [
          if (error != null) StatusNote(text: context.t(error!), warning: true),
          const SizedBox(height: 8),
          Text(
            kicker.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 2.35,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            event!['title'] as String,
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusBadge(
                label: context.t('dinner_status_${event!['status']}'),
                warning: !active,
                emphasis: active,
              ),
              if (event!['location'] != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    EatMeIcon(
                      EatMeGlyph.house,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      event!['location'] as String,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 20),
          _GuestSummary(
            servings: event!['servings'] as int? ?? 1,
            guests: guests.length,
            answered: answered,
            onAdd: active ? showAddParticipant : null,
          ),
          if (active) ...[
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: EatMeActionTile(
                    key: const ValueKey('dinner-menu-action'),
                    icon: EatMeGlyph.utensils,
                    label: context.t('choose_menu'),
                    onTap: () => guarded(chooseMenu),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: EatMeActionTile(
                    key: const ValueKey('dinner-shopping-action'),
                    icon: canShop
                        ? EatMeGlyph.shoppingBasket
                        : EatMeGlyph.badgeCheck,
                    label: context.t(
                      canShop ? 'dinner_shopping_short' : 'eatme_plus',
                    ),
                    emphasized: true,
                    onTap: menu.isEmpty
                        ? null
                        : () => guarded(buildDinnerShopping),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: EatMeActionTile(
                    key: const ValueKey('dinner-timeline-action'),
                    icon: EatMeGlyph.clock,
                    label: context.t('cooking_timeline'),
                    onTap: menu.isEmpty
                        ? null
                        : () => guarded(
                            () async => send({'action': 'generate_timeline'}),
                          ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 28),
          _Heading(title: context.t('dinner_guests')),
          _DinnerGroup(
            children: [
              for (final participant in participants)
                SettingRow(
                  icon: EatMeGlyph.userRound,
                  title: participant['display_name'] as String,
                  subtitle: context.t('guest_status_${participant['status']}'),
                  onTap: participant['response'] is Map
                      ? () => showGuestResponse(participant)
                      : null,
                  trailing:
                      active &&
                          [
                            'temporary_guest',
                            'saved_guest',
                          ].contains(participant['kind'])
                      ? PopupMenuButton<String>(
                          tooltip: context.t('more'),
                          icon: const EatMeIcon(EatMeGlyph.ellipsis),
                          onSelected: (action) async {
                            if (action == 'invite') await invite(participant);
                            if (action == 'rotate') {
                              await invite(participant, action: 'rotate');
                            }
                            if (action == 'revoke') {
                              await revokeInvite(participant);
                            }
                            if (action == 'rename') {
                              await renameGuest(participant);
                            }
                            if (action == 'remove') {
                              await send({
                                'action': 'remove_participant',
                                'participant_id': participant['id'],
                              });
                            }
                          },
                          itemBuilder: (context) {
                            final hasInvite = invitations.any(
                              (item) =>
                                  item['participant_id'] == participant['id'] &&
                                  item['revoked_at'] == null,
                            );
                            return [
                              PopupMenuItem(
                                value: hasInvite ? 'rotate' : 'invite',
                                child: Text(
                                  context.t(
                                    hasInvite ? 'replace_link' : 'invite_guest',
                                  ),
                                ),
                              ),
                              if (hasInvite)
                                PopupMenuItem(
                                  value: 'revoke',
                                  child: Text(context.t('revoke_invite')),
                                ),
                              PopupMenuItem(
                                value: 'rename',
                                child: Text(context.t('rename_guest')),
                              ),
                              PopupMenuItem(
                                value: 'remove',
                                child: Text(context.t('remove')),
                              ),
                            ];
                          },
                        )
                      : null,
                ),
            ],
          ),
          const SizedBox(height: 28),
          _Heading(
            title: context.t('dinner_menu'),
            actionLabel: active ? context.t('choose_menu') : null,
            onAction: active ? () => guarded(chooseMenu) : null,
          ),
          if (menu.isEmpty)
            StatusNote(text: context.t('menu_empty'))
          else
            for (final (index, recipeId) in menu.indexed) ...[
              if (index > 0) const SizedBox(height: 10),
              _MenuCard(
                recipeId: recipeId,
                recipe: recipeById(recipeId),
                status:
                    fit[recipeId]?['status'] as String? ?? 'review_required',
                servings: event!['servings'] as int? ?? 1,
                featured: index == 0,
                onTap: () => context.push('/recipes/$recipeId'),
              ),
            ],
          const SizedBox(height: 12),
          _DinnerGroup(
            children: [
              SettingRow(
                icon: EatMeGlyph.usersRound,
                title: context.t('extra_portions_title'),
                subtitle: context.t('extra_portions_hint'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    EatMeIconButton(
                      glyph: EatMeGlyph.minus,
                      label: context.t('fewer'),
                      size: 40,
                      iconSize: 18,
                      onPressed: active && extra > 0
                          ? () => setExtraPortions(extra - 1)
                          : null,
                    ),
                    SizedBox(
                      width: 32,
                      child: Text(
                        '$extra',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    EatMeIconButton(
                      glyph: EatMeGlyph.plus,
                      label: context.t('more'),
                      size: 40,
                      iconSize: 18,
                      onPressed: active && extra < 20
                          ? () => setExtraPortions(extra + 1)
                          : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (timeline.isNotEmpty) ...[
            const SizedBox(height: 28),
            _Heading(title: context.t('cooking_timeline')),
            _DinnerGroup(
              children: [
                for (final item in timeline)
                  SettingRow(
                    icon: EatMeGlyph.timer,
                    title: MaterialLocalizations.of(context).formatTimeOfDay(
                      TimeOfDay.fromDateTime(
                        DateTime.parse(item['start_at'] as String).toLocal(),
                      ),
                    ),
                    subtitle: labelOf(
                      recipeById(item['recipe_id'] as String)?['title'] ?? '',
                      context,
                    ),
                  ),
              ],
            ),
          ],
          if (active) ...[
            const SizedBox(height: 28),
            AsyncAction(
              label: context.t('complete_dinner'),
              action: completeDinner,
            ),
            const SizedBox(height: 10),
            AsyncAction(
              label: context.t('cancel_dinner'),
              secondary: true,
              destructive: true,
              action: cancelDinner,
            ),
          ],
        ],
      ),
    );
  }
}

/// Rows grouped on one borderless panel, as in the Profile settings groups.
class _DinnerGroup extends StatelessWidget {
  const _DinnerGroup({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => InformationPanel(
    tinted: false,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Column(children: children),
  );
}

/// Section title in the editorial Plan style, with an optional text action.
class _Heading extends StatelessWidget {
  const _Heading({required this.title, this.actionLabel, this.onAction});
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.headlineMedium),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    ),
  );
}

/// Who is coming, mirroring the Plan's week summary.
class _GuestSummary extends StatelessWidget {
  const _GuestSummary({
    required this.servings,
    required this.guests,
    required this.answered,
    required this.onAdd,
  });
  final int servings, guests, answered;
  final VoidCallback? onAdd;
  @override
  Widget build(BuildContext context) => InformationPanel(
    child: Column(
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: const EatMeIcon(EatMeGlyph.usersRound, size: 23),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t('cooking_for', {'count': servings}),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    guests == 0
                        ? context.t('dinner_no_guests')
                        : context.t('dinner_answered', {
                            'answered': answered,
                            'total': guests,
                          }),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            if (onAdd != null)
              EatMeIconButton(
                key: const ValueKey('dinner-add-person'),
                glyph: EatMeGlyph.plus,
                label: context.t('add_person'),
                onPressed: onAdd,
              ),
          ],
        ),
        if (guests > 0) ...[
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: answered / guests,
              minHeight: 5,
            ),
          ),
        ],
      ],
    ),
  );
}

/// A menu course, styled like the Plan's meal cards. The first course is
/// featured with a larger photo.
class _MenuCard extends StatelessWidget {
  const _MenuCard({
    required this.recipeId,
    required this.recipe,
    required this.status,
    required this.servings,
    required this.featured,
    required this.onTap,
  });
  final String recipeId, status;
  final Json? recipe;
  final int servings;
  final bool featured;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fitColor = switch (status) {
      'works_for_everyone' => scheme.primary,
      'not_compatible' => scheme.error,
      _ =>
        Theme.of(context).brightness == Brightness.dark
            ? const Color(0xffffcf70)
            : const Color(0xff855400),
    };
    return InformationPanel(
      tinted: featured,
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(featured ? 14 : 10),
          child: Row(
            children: [
              FoodImage(
                id: recipeId,
                imageUrl: '${recipe?['image_url'] ?? ''}',
                width: featured ? 104 : 52,
                height: featured ? 92 : 52,
                radius: featured ? 18 : 14,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      labelOf(recipe?['title'] ?? '', context),
                      maxLines: featured ? 3 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: featured
                          ? Theme.of(context).textTheme.titleLarge
                          : Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${recipe?['minutes'] ?? '—'} min · $servings ${context.t('servings').toLowerCase()}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    // Diet-Fit is safety information: kept as a readable
                    // sentence, colored by outcome.
                    Text(
                      context.t('diet_fit_$status'),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: fitColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              EatMeIcon(
                EatMeGlyph.chevronRight,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A dinner in the list, styled like the Plan's meal cards: the date is the
/// kicker and the next planned dinner is featured.
class _DinnerCard extends StatelessWidget {
  const _DinnerCard({
    required this.event,
    required this.featured,
    required this.onTap,
  });
  final Json event;
  final bool featured;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final starts = DateTime.parse(event['starts_at'] as String).toLocal();
    final status = event['status'] as String;
    return InformationPanel(
      tinted: featured,
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(featured ? 16 : 12),
          child: Row(
            children: [
              Container(
                width: featured ? 56 : 48,
                height: featured ? 56 : 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: featured
                      ? scheme.surface.withValues(alpha: .7)
                      : scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: EatMeIcon(
                  EatMeGlyph.utensils,
                  size: featured ? 26 : 22,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${MaterialLocalizations.of(context).formatMediumDate(starts)} · ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(starts))}'
                          .toUpperCase(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        letterSpacing: 1.6,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      event['title'] as String,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: featured
                          ? Theme.of(context).textTheme.titleLarge
                          : Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    StatusBadge(
                      label: context.t('dinner_status_$status'),
                      warning: status == 'cancelled',
                      emphasis: status == 'planned',
                    ),
                  ],
                ),
              ),
              EatMeIcon(
                EatMeGlyph.chevronRight,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
