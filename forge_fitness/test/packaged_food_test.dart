import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:forge_fitness/packaged_food.dart';

void main() {
  testWidgets(
    'free packet lookup scales slices and returns a review without logging',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Map<String, dynamic>? review;
      int saves = 0, searches = 0;
      final client = MockClient((r) async {
        if (r.url.path == '/api/my-foods') {
          if (r.method == 'POST') saves++;
          return http.Response('{"foods":[]}', 200);
        }
        searches++;
        expect(r.url.queryParameters['q'], 'Bunnys');
        return http.Response(
          jsonEncode({
            'products': [
              {
                'id': 'off-5060061730952',
                'name': 'Fixture white bread',
                'brand': 'Bunnys',
                'barcode': '5060061730952',
                'calories': 266,
                'protein': 8.85,
                'carbs': 49.42,
                'fat': 3.33,
                'servingGrams': 29,
                'servingLabel': '1 slice (29 g)',
                'source': 'Open Food Facts',
              },
            ],
          }),
          200,
        );
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: PackagedFoodEntry(
              client: client,
              onReview: (j) => review = j,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Bunnys');
      await tester.tap(find.text('Find product'));
      await tester.pumpAndSettle();
      expect(searches, 1);
      expect(review, isNull);
      await tester.ensureVisible(find.text('Fixture white bread'));
      await tester.tap(find.text('Fixture white bread'));
      await tester.pumpAndSettle();
      final qty = find.widgetWithText(TextField, 'Number of slices eaten');
      await tester.ensureVisible(qty);
      await tester.enterText(qty, '3');
      await tester.pumpAndSettle();
      final check = find.text('The product and label values match my packet');
      await tester.ensureVisible(check);
      await tester.tap(check);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Review this portion'));
      await tester.tap(find.text('Review this portion'));
      await tester.pumpAndSettle();
      expect(review?['calories'], 231.4);
      expect(review?['protein'], 7.7);
      expect(review?['needsClarification'], false);
      expect(saves, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      client.close();
    },
  );
}
