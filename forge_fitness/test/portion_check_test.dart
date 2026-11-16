import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:forge_fitness/models.dart';
import 'package:forge_fitness/quick_meal.dart';

// 1×1 transparent PNG.
final pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);
final aiEstimate = <String, dynamic>{
  'is_food': true,
  'needsClarification': false,
  'name': 'Chicken biryani',
  'portion': '1 plate, about 350 g',
  'calories': 600,
  'protein': 30,
  'carbs': 70,
  'fat': 20,
  'assumptions': 'Typical home recipe with oil; approximate, not measured.',
  'source': 'Gemini estimate',
  'items': [
    {
      'name': 'Chicken biryani',
      'portion': '1 plate, about 350 g',
      'calories': 600,
      'protein': 30,
      'carbs': 70,
      'fat': 20,
    },
  ],
  'original': '',
  'waterMl': 0,
};

Finder button(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
);
VoidCallback? onPressed(WidgetTester t, Finder f) =>
    t.widget<ButtonStyleButton>(f).onPressed;

void main() {
  test('scaleEstimate scales nutrition and records the chosen portion', () {
    final s = scaleEstimate(aiEstimate, .75);
    expect(s['calories'], 450);
    expect(s['protein'], 22.5);
    expect(s['carbs'], 52.5);
    expect(s['fat'], 15);
    expect(s['portion'], contains('×0.75'));
    expect(s['assumptions'], aiEstimate['assumptions']);
    final item = (s['items'] as List).single as Map;
    expect(item['calories'], 450);
    expect(item['portion'], contains('×0.75'));
    expect(aiEstimate['calories'], 600, reason: 'original is not mutated');
    expect(scaleEstimate(aiEstimate, 2)['portion'], contains('×2 '));
  });

  testWidgets(
    'photo AI estimate cannot be logged until the portion is chosen',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final store = AppStore(await SharedPreferences.getInstance());
      Map? sent;
      final client = MockClient((r) async {
        if (r.url.path == '/api/status') {
          return http.Response(
            jsonEncode({
              'configured': true,
              'aiProviders': {'gemini': true, 'groq': false},
            }),
            200,
          );
        }
        if (r.url.path == '/api/interpret') {
          sent = jsonDecode(r.body) as Map;
          return http.Response(jsonEncode(aiEstimate), 200);
        }
        return http.Response('{}', 404);
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => Scaffold(
                        body: QuickMealEntry(
                          store: store,
                          date: DateTime(2026, 11, 16),
                          client: client,
                          initialPhoto: pixel,
                        ),
                      ),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Estimate with AI'));
      await tester.pumpAndSettle();
      expect(sent!['image'], startsWith('data:image/jpeg;base64,'));
      expect(find.text('CHECK YOUR PORTION'), findsOneWidget);
      final confirm = button('Choose your portion first');
      await tester.ensureVisible(confirm);
      expect(onPressed(tester, confirm), isNull);

      await tester.ensureVisible(find.text('¾'));
      await tester.tap(find.text('¾'));
      await tester.pumpAndSettle();
      expect(find.text('450 kcal'), findsWidgets);
      final ready = button('Yes, confirm & log');
      await tester.ensureVisible(ready);
      await tester.tap(ready);
      await tester.pumpAndSettle();
      final meal = store.meals.single;
      expect(meal.calories, 450);
      expect(meal.protein, 22.5);
      expect(meal.notes, contains('×0.75'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      client.close();
    },
  );

  testWidgets('text estimates keep the one-step confirm', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(await SharedPreferences.getInstance());
    final client = MockClient((r) async {
      if (r.url.path == '/api/interpret') {
        return http.Response(
          jsonEncode({...aiEstimate, 'source': 'USDA reference'}),
          200,
        );
      }
      return http.Response('{}', 404);
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: QuickMealEntry(
            store: store,
            date: DateTime(2026, 11, 16),
            client: client,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'chicken biryani');
    await tester.tap(find.text('Estimate my meal'));
    await tester.pumpAndSettle();
    expect(find.text('CHECK YOUR PORTION'), findsNothing);
    final ready = button('Yes, confirm & log');
    await tester.ensureVisible(ready);
    expect(onPressed(tester, ready), isNotNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    client.close();
  });
}
