import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:forge_fitness/models.dart';
import 'package:forge_fitness/main.dart';
import 'package:forge_fitness/guest_food_client.dart';

const athlete = Profile(
  name: 'Guest Athlete',
  sex: 'Male',
  goal: 'Lean & defined',
  equipment: 'Full gym',
  experience: 'Beginner',
  weight: 75,
  height: 175,
  activity: 1.375,
  age: 25,
  days: 5,
  preferredDays: [1, 2, 3, 4, 5],
);
void main() {
  test(
    'guest records persist separately and never sync or alter account queues',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final account = AppStore(prefs);
      await account.setProfile(athlete);
      final original = prefs.getString('forge.v1');
      await prefs.setString(
        'forge.cloud.pending',
        '{"account-operation":"keep"}',
      );
      await prefs.setString('forge.cloud.owner', 'alice');
      await prefs.setString('forge.mode', 'guest');
      var calls = 0;
      final httpClient = MockClient((r) async {
        calls++;
        throw StateError('Guest must not use account API');
      });
      final guest = AppStore(prefs, enableCloud: true, syncClient: httpClient);
      await guest.load();
      expect(guest.profile, isNull);
      expect(guest.guestMode, true);
      expect(guest.cloudEnabled, false);
      await guest.setProfile(athlete);
      await guest.addWater(DateTime(2026, 10, 31), 1);
      await guest.syncCloud();
      expect(calls, 0);
      expect(prefs.getString('forge.v1'), original);
      expect(
        prefs.getString('forge.cloud.pending'),
        '{"account-operation":"keep"}',
      );
      expect(prefs.getString('forge.cloud.owner'), 'alice');
      final reloaded = AppStore(
        prefs,
        enableCloud: true,
        syncClient: httpClient,
      );
      await reloaded.load();
      expect(reloaded.profile!.name, 'Guest Athlete');
      expect(reloaded.water['2026-10-31'], 1);
      expect(calls, 0);
      guest.dispose();
      reloaded.dispose();
      account.dispose();
      httpClient.close();
    },
  );
  test(
    'access choice preserves expired account cache and restores previous guest profile',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final account = AppStore(prefs);
      await account.setProfile(athlete);
      final raw = prefs.getString('forge.v1');
      await prefs.setString('forge.guest.v1', raw!);
      final expired = AppStore(
        prefs,
        enableCloud: true,
        syncClient: MockClient((r) async => http.Response('{}', 401)),
      );
      await expired.load();
      expect(expired.cloudAuthRequired, true);
      await expired.continueAsGuest();
      expect(expired.guestMode, true);
      expect(expired.profile!.name, 'Guest Athlete');
      expect(prefs.getString('forge.v1'), raw);
      expect(expired.cloudAuthRequired, false);
      expired.dispose();
      account.dispose();
    },
  );
  test(
    'guest client redirects only public references and keeps libraries local',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final requests = <http.Request>[];
      final transport = MockClient((r) async {
        requests.add(r);
        if (r.url.path.endsWith('/recipes/calculate')) {
          return http.Response(
            jsonEncode({
              'name': 'Guest shake',
              'calories': 200,
              'protein': 10,
              'carbs': 25,
              'fat': 6,
              'ingredients': [],
              'servings': 1,
            }),
            200,
          );
        }
        return http.Response('{"items":[],"foods":[]}', 200);
      });
      final client = GuestFoodClient(prefs, client: transport);
      Uri api(String p) => Uri.parse('https://forge.test/api/$p');
      final status = jsonDecode((await client.get(api('status'))).body);
      expect(status['configured'], false);
      expect(requests, isEmpty);
      await client.get(api('foods?q=eggs'));
      expect(requests.last.url.path, '/api/guest/foods');
      expect(requests.last.url.queryParameters['q'], 'eggs');
      final label = {
        'name': 'Device white bread',
        'barcode': '',
        'basisGrams': 100,
        'servingGrams': 35,
        'servingUnit': 'slice',
        'calories': 300,
        'protein': 8,
        'carbs': 60,
        'fat': 2,
      };
      expect(
        (await client.post(
          api('my-foods'),
          body: jsonEncode(label),
        )).statusCode,
        200,
      );
      expect(requests.length, 1);
      expect(
        jsonDecode((await client.get(api('my-foods'))).body)['foods'].length,
        1,
      );
      await client.post(
        api('interpret'),
        body: jsonEncode({
          'description': '3 slices of Device white bread',
          'useGemini': true,
          'image': 'private-photo',
        }),
      );
      final body = jsonDecode(requests.last.body);
      expect(requests.last.url.path, '/api/guest/interpret');
      expect(body['useGemini'], false);
      expect(body.containsKey('image'), false);
      expect(body['labels'][0]['basisGrams'], 100);
      expect((await client.post(api('analyze'), body: '{}')).statusCode, 401);
      expect(requests.length, 2);
      expect(
        (await client.post(
          api('my-foods'),
          body: jsonEncode({...label, 'barcode': '123'}),
        )).statusCode,
        400,
      );
      await client.post(
        api('recipes'),
        body: jsonEncode({
          'name': 'Guest shake',
          'items': [
            {'fdcId': 173944, 'grams': 118},
          ],
        }),
      );
      expect(requests.last.url.path, '/api/guest/recipes/calculate');
      expect(
        jsonDecode((await client.get(api('recipes'))).body)['recipes'].length,
        1,
      );
      final count = requests.length;
      expect((await client.post(api('sync'), body: '{}')).statusCode, 401);
      expect(requests.length, count);
      client.close();
    },
  );
  test(
    'guest backup restores device labels and recipes without changing account storage',
    () async {
      SharedPreferences.setMockInitialValues({
        'forge.mode': 'guest',
        'forge.v1': 'untouched-account',
        'forge.guest.labels': '[{"name":"My label"}]',
        'forge.guest.recipes': '[{"name":"My recipe"}]',
      });
      final prefs = await SharedPreferences.getInstance(),
          s = AppStore(
            await SharedPreferences.getInstance(),
            enableCloud: true,
          );
      await s.load();
      await s.setProfile(athlete);
      final backup = s.backup();
      await prefs.remove('forge.guest.labels');
      await prefs.remove('forge.guest.recipes');
      await s.restore(backup);
      expect(
        jsonDecode(prefs.getString('forge.guest.labels')!)[0]['name'],
        'My label',
      );
      expect(prefs.getString('forge.v1'), 'untouched-account');
      final bad = jsonDecode(backup) as Map<String, dynamic>;
      bad['deviceLabels'] = [42];
      await expectLater(s.restore(jsonEncode(bad)), throwsFormatException);
      expect(s.profile!.name, 'Guest Athlete');
      s.dispose();
    },
  );
  testWidgets(
    'small phone access screen has a working no-login choice without showing cached account data',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final store = AppStore(
        await SharedPreferences.getInstance(),
        enableCloud: true,
      );
      store.cloudAuthRequired = true;
      store.profile = athlete;
      await tester.pumpWidget(ForgeApp(store: store));
      expect(find.text('Hey, Guest Athlete.'), findsNothing);
      await tester.tap(find.text('Continue without signing in'));
      await tester.pumpAndSettle();
      expect(store.guestMode, true);
      expect(find.text('Build my plan'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    },
  );
}
