import 'dart:convert';
import 'dart:js_interop';

@JS('forgeFoodSuggest')
external JSPromise<JSString> _suggest(JSString image);
@JS('forgeReadBarcode')
external JSPromise<JSString> _barcode(JSString image);
Future<String> scanFoodBarcode(String image) async =>
    (await _barcode(image.toJS).toDart).toDart;
Future<List<Map<String, dynamic>>> suggestFood(String image) async {
  final raw = await _suggest(image.toJS).toDart;
  return (jsonDecode(raw.toDart) as List)
      .map((r) => Map<String, dynamic>.from(r as Map))
      .toList();
}
