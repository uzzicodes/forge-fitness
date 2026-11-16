import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:forge_fitness/food_calculator.dart';
import 'package:forge_fitness/models.dart';

const p = Profile(
  name: 'Cloud Test',
  sex: 'Male',
  goal: 'Build muscle',
  equipment: 'Full gym',
  experience: 'Beginner',
  weight: 75,
  height: 175,
  activity: 1.55,
  age: 25,
  days: 5,
  preferredDays: [1, 2, 3, 4, 5],
);
final banana = {
  'id': 173944,
  'name': 'Bananas, raw',
  'calories': 89,
  'protein': 1.09,
  'carbs': 22.84,
  'fat': .33,
  'portions': [
    {'label': '1 medium', 'grams': 118},
    {'label': '1 equivalent serving', 'grams': 118},
  ],
};
final milk = {
  'id': 171265,
  'name': 'Milk, whole, 3.25% milkfat, with added vitamin D',
  'calories': 61,
  'protein': 3.15,
  'carbs': 4.8,
  'fat': 3.25,
  'portions': [
    {'label': '1 cup', 'grams': 244},
  ],
};
void main() {
  testWidgets(
    'Banana shake calculates automatically and can split into servings',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Map<String, dynamic>? received;
      int saves = 0;
      final client = MockClient((request) async {
        if (request.url.path == '/api/recipes' && request.method == 'GET') {
          return http.Response('{"recipes":[]}', 200);
        }
        if (request.url.path.contains('/api/foods/')) {
          return http.Response(
            jsonEncode({
              'food': request.url.path.endsWith('173944') ? banana : milk,
            }),
            200,
          );
        }
        if (request.method == 'POST') {
          final body = jsonDecode(request.body) as Map;
          expect(body['items'].length, 2);
          expect(body['servings'], 2);
          saves++;
          return http.Response(
            jsonEncode({
              'name': 'Banana shake',
              'calories': 131.2,
              'protein': 4.7,
              'carbs': 19.7,
              'fat': 4.4,
              'portion': '1 of 2 servings',
              'assumptions': 'USDA values',
              'source': 'USDA reference',
              'ingredients': body['items'],
            }),
            200,
          );
        }
        return http.Response('{}', 404);
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: FoodCalculator(
              initialName: 'banana shake',
              client: client,
              onConfirm: (j) => received = j,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('262 kcal'), findsOneWidget);
      final fields = find.byType(TextField);
      await tester.ensureVisible(fields.last);
      await tester.enterText(fields.last, '2');
      await tester.pump();
      expect(find.textContaining('131 kcal'), findsOneWidget);
      await tester.ensureVisible(find.text('Use these nutrition values'));
      await tester.tap(find.text('Use these nutrition values'));
      await tester.pumpAndSettle();
      expect(received!['calories'], 131.2);
      expect(saves, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      client.close();
    },
  );
  test('Offline cloud edits survive and sync on reconnect', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    bool online = true;
    String owner = 'alice';
    final remote = <String, Map<String, dynamic>>{};
    final client = MockClient((request) async {
      if (!online) throw http.ClientException('offline');
      if (request.url.path == '/api/status') {
        return http.Response(
          jsonEncode({
            'userId': owner,
            'configured': false,
            'catalogReady': true,
          }),
          200,
        );
      }
      if (request.url.path == '/api/state') {
        return http.Response(
          jsonEncode({'userId': owner, 'records': remote.values.toList()}),
          200,
        );
      }
      if (request.url.path == '/api/sync') {
        final changes = jsonDecode(request.body)['changes'] as List;
        for (final op in changes) {
          final key = op['key'] as String;
          final previous = remote[key];
          if (previous == null ||
              (op['clock'] as String).compareTo(previous['clock'] as String) >
                  0) {
            remote[key] = Map<String, dynamic>.from(op as Map);
          }
        }
        return http.Response('{"ok":true}', 200);
      }
      return http.Response('{}', 404);
    });
    final store = AppStore(prefs, enableCloud: true, syncClient: client);
    await store.load();
    await store.setProfile(p);
    await store.syncCloud();
    expect(remote['profile']!['value']['name'], 'Cloud Test');
    final planKey = 'weekplan:${dayKey(store.weeklyXpStart!)}';
    expect(remote[planKey]!['value']['trainingDays'], 5);
    await store.setRecoveryWeek(true);
    await store.syncCloud();
    expect(remote[planKey]!['value']['recovery'], true);
    online = false;
    await store.addWater(DateTime(2026, 10, 27), 1);
    await store.syncCloud();
    expect(store.syncStatus, 'Offline · queued');
    expect(
      jsonDecode(prefs.getString('forge.cloud.pending')!)['water:2026-10-27'],
      isNotNull,
    );
    online = true;
    await store.syncCloud();
    expect(remote['water:2026-10-27']!['value'], 1);
    expect(store.syncStatus, 'Synced');
    store.dispose();
    final reload = AppStore(prefs, enableCloud: true, syncClient: client);
    await reload.load();
    expect(reload.profile!.name, 'Cloud Test');
    expect(reload.water['2026-10-27'], 1);
    expect(reload.weekPlans[dayKey(reload.weeklyXpStart!)]!['recovery'], true);
    expect(
      reload.accountPreferences['weeklyXpStart'],
      store.accountPreferences['weeklyXpStart'],
    );
    reload.dispose();
    client.close();
  });
  test('Changing accounts clears prior local records before syncing', () async {
    SharedPreferences.setMockInitialValues({'forge.cloud.owner': 'alice'});
    final prefs = await SharedPreferences.getInstance();
    final local = AppStore(prefs);
    await local.setProfile(p);
    final client = MockClient(
      (request) async => http.Response(
        jsonEncode(
          request.url.path == '/api/status'
              ? {'userId': 'bob', 'configured': false, 'catalogReady': true}
              : {'userId': 'bob', 'records': []},
        ),
        200,
      ),
    );
    final bob = AppStore(prefs, enableCloud: true, syncClient: client);
    await bob.load();
    expect(bob.profile, isNull);
    expect(bob.meals, isEmpty);
    expect(bob.weekPlans, isEmpty);
    expect(bob.weeklyXpStart, isNull);
    expect(prefs.getString('forge.cloud.owner'), 'bob');
    bob.dispose();
    local.dispose();
    client.close();
  });
}
