import 'package:eatme/core/api.dart';
import 'package:eatme/core/models.dart';
import 'package:eatme/core/state.dart';
import 'package:eatme/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('real API: purchase, plan, cook and export a meal', (tester) async {
    final api = EatMeApi();
    await EatMeApi.secure.write(key: 'eatme.locale', value: 'en');
    await api.login('mobile-${DateTime.now().microsecondsSinceEpoch}@example.test', 'Integration-only-12345!', register: true);
    await api.request('PUT', '/profile', operationKey: api.newOperation(), body: {'name': 'Kitchen test', 'adult_confirmed': true});
    final catalog = await api.request('GET', '/catalog');
    final foods = (catalog['foods'] as List).cast<Map>();
    for (final food in foods.where((food) => food['ingredient_status'] == 'known')) {
      await api.request('POST', '/inventory', operationKey: api.newOperation(), body: {'food_id': food['id'], 'quantity': food['unit'] == 'pcs' ? '20' : '1000'});
    }
    final tomato = foods.firstWhere((food) => '${food['name']['en']}'.toLowerCase().contains('tomato'));
    await api.request('POST', '/shopping', operationKey: api.newOperation(), body: {'action': 'add', 'food_id': tomato['id'], 'quantity': '100'});
    final container = ProviderContainer(overrides: [apiProvider.overrideWithValue(api)]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const EatMeApp()));
    await tester.pumpAndSettle(const Duration(milliseconds: 250));
    expect(container.read(appProvider).stage, Stage.ready);
    expect(find.byType(NavigationDestination), findsNWidgets(4));
    container.read(routerProvider).go('/shopping');
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Purchased · add to fridge'));
    await tester.tap(find.text('Purchased · add to fridge'));
    await tester.pumpAndSettle();
    expect((await api.request('GET', '/shopping'))['items'], isEmpty);
    container.read(routerProvider).go('/planner');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Suggest seven dinners'));
    await tester.tap(find.text('Suggest seven dinners'));
    await tester.pumpAndSettle();
    final plans = await api.request('GET', '/plans');
    expect(plans['items'][0]['data']['meals'].length, 7);
    final recipes = await api.request('GET', '/recipes');
    final recipe = Map<String, dynamic>.from((recipes['items'] as List).first as Map);
    container.read(routerProvider).go('/cook/${recipe['id']}?servings=1');
    await tester.pumpAndSettle();
    for (var step = 0; step < 30 && find.text('Next step').evaluate().isNotEmpty; step++) {
      await tester.ensureVisible(find.text('Next step'));
      await tester.tap(find.text('Next step'));
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(find.text('I’m done'));
    await tester.tap(find.text('I’m done'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Confirm & update Fridge'));
    await tester.tap(find.text('Confirm & update Fridge'));
    await tester.pumpAndSettle();
    final Json exported = await api.request('GET', '/privacy/export');
    expect((exported['cooking_sessions'] as List).length, 1);
    expect(tester.takeException(), isNull);
    await api.request('DELETE', '/profile', body: {'confirm': true});
    await api.clearSession();
  });
}
