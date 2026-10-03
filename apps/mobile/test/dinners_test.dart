import 'package:eatme/core/models.dart';
import 'package:eatme/design_system/widgets.dart';
import 'package:eatme/features/organize/dinners.dart';
import 'package:eatme/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'application_test.dart' as support;

class DinnerApi extends support.TestApi {
  Json get event => {
    'id': 'dinner-1',
    'title': 'Dinner with friends',
    'starts_at': '2030-09-20T17:00:00+00:00',
    'timezone': 'Europe/Rome',
    'location': 'Home',
    'status': 'planned',
    'version': 2,
    'host_user_id': support.uid,
    'menu': ['recipe-1'],
    'extra_portions': 1,
    'timeline': <Json>[],
    'meal_memory': false,
    'servings': 2,
    'participants': [
      {
        'id': 'host-person',
        'kind': 'host',
        'display_name': 'Alex',
        'status': 'host',
        'user_id': support.uid,
      },
      {
        'id': 'guest-person',
        'kind': 'temporary_guest',
        'display_name': 'Ada',
        'status': 'invited',
      },
    ],
    'invitations': <Json>[],
    'diet_fit': [
      {
        'recipe_id': 'recipe-1',
        'status': 'review_required',
        'blocked': <Json>[],
        'unanswered_participant_ids': ['guest-person'],
      },
    ],
  };

  @override
  Future<Json> request(
    String method,
    String path, {
    Json? body,
    String? operationKey,
    bool allowCache = true,
  }) async {
    calls.add({
      'method': method,
      'path': path,
      'body': body,
      'key': operationKey,
    });
    if (method == 'GET' && path == '/dinners') {
      return {
        'items': [
          {
            'id': 'dinner-1',
            'title': 'Dinner with friends',
            'starts_at': '2030-09-20T17:00:00+00:00',
            'status': 'planned',
          },
        ],
      };
    }
    if (method == 'GET' && path == '/dinners/dinner-1') return event;
    if (method == 'GET' && path == '/entitlements') {
      return {
        'tier': 'free',
        'capabilities': {'canUseGeneratedShopping': false},
        'limits': <String, dynamic>{},
        'usage': <String, dynamic>{},
        'remaining': <String, dynamic>{},
        'configured': true,
      };
    }
    if (method == 'GET' && path == '/recipes') {
      return {
        'items': [
          {
            'id': 'recipe-1',
            'title': {'en': 'Garden bowl', 'it': 'Bowl dell’orto'},
            'minutes': 20,
          },
        ],
      };
    }
    if (method == 'POST' && path.endsWith('/invitations')) {
      return {
        'id': 'invite-1',
        'token': 'test-capability-token',
        'url': 'https://guest.eatme.test/en/invite/test-capability-token',
        'expires_at': '2030-09-21T17:00:00+00:00',
      };
    }
    return super.request(
      method,
      path,
      body: body,
      operationKey: operationKey,
      allowCache: allowCache,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Dinner remains inside Plan and renders at accessible text size',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        support.harness(
          const AppShell(path: '/plan/dinners', child: DinnersPage()),
          DinnerApi(),
          scale: 1.6,
        ),
      );
      await tester.pumpAndSettle();
      final navigation = tester.widget<EatMeNavigationBar>(
        find.byType(EatMeNavigationBar),
      );
      expect(navigation.selectedIndex, 2);
      expect(navigation.destinations, hasLength(4));
      expect(find.text('Dinner with friends'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('unanswered guest is visible and never presented as safe', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      support.harness(
        const DinnerDetailPage(dinnerId: 'dinner-1'),
        DinnerApi(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('Waiting for a guest’s food needs'), findsOneWidget);
    expect(
      find.text('Works for everyone in the answered profiles'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('guest invite offers an on-device QR capability link', (
    tester,
  ) async {
    await tester.pumpWidget(
      support.harness(
        const DinnerDetailPage(dinnerId: 'dinner-1'),
        DinnerApi(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Invite guest'));
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsOneWidget);
    expect(
      find.text('https://guest.eatme.test/en/invite/test-capability-token'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('free plan sees the EatMe+ prompt instead of a failing request', (
    tester,
  ) async {
    final api = DinnerApi();
    await tester.pumpWidget(
      support.harness(const DinnerDetailPage(dinnerId: 'dinner-1'), api),
    );
    await tester.pumpAndSettle();
    final action = find.text('Build dinner shopping list');
    await tester.scrollUntilVisible(action, 200);
    await tester.tap(action);
    // The row keeps its progress indicator while the sheet is open.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(
      find.textContaining('the shopping list for this dinner is built for you'),
      findsOneWidget,
    );
    expect(
      api.calls.where((call) => call['body']?['action'] == 'generate_shopping'),
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });
}
