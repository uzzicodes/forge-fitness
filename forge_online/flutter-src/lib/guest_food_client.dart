import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Guest reference requests never enter account APIs or use a provider key.
/// Personal labels and recipes live only in the guest browser namespace.
class GuestFoodClient extends http.BaseClient {
  final SharedPreferences preferences;
  final http.Client inner;
  GuestFoodClient(this.preferences, {http.Client? client})
    : inner = client ?? http.Client();
  List<Map<String, dynamic>> saved(String kind) =>
      (jsonDecode(preferences.getString('forge.guest.$kind') ?? '[]') as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
  String id() =>
      'guest-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 30)}';
  http.StreamedResponse json(Object value, [int status = 200]) =>
      http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(value))),
        status,
        headers: {
          'content-type': 'application/json',
          'cache-control': 'private, no-store',
        },
      );
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path, method = request.method;
    if (path == '/api/status') {
      return json({
        'ok': true,
        'guest': true,
        'configured': false,
        'aiProviders': {'gemini': false, 'groq': false},
      });
    }
    if (path == '/api/my-foods' && method == 'GET') {
      return json({'foods': saved('labels')});
    }
    if (path == '/api/recipes' && method == 'GET') {
      return json({'recipes': saved('recipes')});
    }
    final bytes = await request.finalize().toBytes();
    final Map<String, dynamic> body = bytes.isEmpty
        ? {}
        : Map<String, dynamic>.from(jsonDecode(utf8.decode(bytes)) as Map);
    if (path == '/api/my-foods' && method == 'POST') {
      final code = body['barcode'] ?? '';
      if (code is! String || (code.isNotEmpty && !_validBarcode(code))) {
        return json({
          'error': 'Check the barcode digits and check digit.',
        }, 400);
      }
      final basis = body['basisGrams'], grams = body['servingGrams'];
      final macros = ['calories', 'protein', 'carbs', 'fat'];
      bool positive(Object? n, double max) =>
          n is num && n.isFinite && n > 0 && n <= max;
      if (body['name'] is! String ||
          (body['name'] as String).trim().length < 2 ||
          (body['name'] as String).length > 100 ||
          !positive(basis, 1000) ||
          !positive(grams, 1000) ||
          !['slice', 'serving', 'piece'].contains(body['servingUnit']) ||
          macros.any(
            (k) =>
                body[k] is! num ||
                !(body[k] as num).isFinite ||
                (body[k] as num) < 0,
          )) {
        return json({
          'error':
              'Check the name, serving weight and all nutrition label values.',
        }, 400);
      }
      final scaled = {
        for (final k in macros) k: (body[k] as num) * 100 / (basis as num),
      };
      if (scaled['calories']! > 950 ||
          scaled['protein']! + scaled['carbs']! + scaled['fat']! > 105) {
        return json({
          'error': 'Check per-serving versus per-100 g label values.',
        }, 400);
      }
      final foods = saved('labels'),
          key =
              body['id'] is String &&
                  RegExp(r'^[a-zA-Z0-9-]{1,80}$').hasMatch(body['id'])
              ? body['id']
              : id();
      if (foods.length >= 100 && !foods.any((f) => f['id'] == key)) {
        return json({
          'error': 'You can save up to 100 labels on this device.',
        }, 400);
      }
      final food = {
        'id': key,
        'name': (body['name'] as String).trim(),
        'barcode': body['barcode'] ?? '',
        ...scaled,
        'servingGrams': grams,
        'servingUnit': body['servingUnit'],
        'source': 'Your verified nutrition label',
        'assumptions':
            'Your saved label on this device; check the current packet.',
      };
      foods.removeWhere((f) => f['id'] == key);
      foods.insert(0, food);
      if (!await preferences.setString('forge.guest.labels', jsonEncode(foods))) {
        return json({'error': 'Could not save this label on the device.'}, 507);
      }
      return json({'food': food});
    }
    if (path.startsWith('/api/my-foods/') && method == 'DELETE') {
      final foods = saved('labels')
        ..removeWhere((f) => f['id'] == path.split('/').last);
      await preferences.setString('forge.guest.labels', jsonEncode(foods));
      return json({'ok': true});
    }
    final saveRecipe = path == '/api/recipes' && method == 'POST';
    final allowed =
        (method == 'GET' &&
            (path == '/api/foods' ||
                RegExp(r'^/api/foods/(\d+|pk-[a-z0-9-]+)$').hasMatch(path) ||
                path == '/api/products')) ||
        (method == 'POST' &&
            (path == '/api/interpret' ||
                path == '/api/recipes/calculate' ||
                saveRecipe));
    if (!allowed) {
      return json({
        'error':
            'Sign in for cloud sync and optional Gemini/Groq estimates. Guest records remain on this device.',
      }, 401);
    }
    if (path == '/api/interpret') {
      body.remove('image');
      body['useGemini'] = false;
      body['labels'] = saved(
        'labels',
      ).map((f) => {...f, 'basisGrams': 100}).toList();
    }
    final next = http.Request(
      method,
      request.url.replace(
        path: saveRecipe
            ? '/api/guest/recipes/calculate'
            : path.replaceFirst('/api/', '/api/guest/'),
      ),
    );
    next.headers.addAll({'content-type': 'application/json'});
    if (method == 'POST') next.body = jsonEncode(body);
    final response = await inner.send(next);
    if (!saveRecipe || response.statusCode != 200) return response;
    final result = Map<String, dynamic>.from(
      jsonDecode(await response.stream.bytesToString()) as Map,
    );
    final recipes = saved('recipes');
    final key = body['id'] is String ? body['id'] : id();
    recipes.removeWhere((r) => r['id'] == key);
    recipes.insert(0, {'id': key, ...result});
    if (!await preferences.setString(
      'forge.guest.recipes',
      jsonEncode(recipes.take(100).toList()),
    )) {
      return json({'error': 'Could not save the recipe on this device.'}, 507);
    }
    return json({'id': key, ...result});
  }

  @override
  void close() {
    inner.close();
    super.close();
  }
}

bool _validBarcode(String code) {
  if (!RegExp(r'^(?:\d{8}|\d{12}|\d{13}|\d{14})$').hasMatch(code)) return false;
  final digits = code.split('').map(int.parse).toList(),
      check = digits.removeLast();
  var sum = 0, i = 0;
  for (final digit in digits.reversed) {
    sum += digit * (i.isEven ? 3 : 1);
    i++;
  }
  return (10 - sum % 10) % 10 == check;
}
