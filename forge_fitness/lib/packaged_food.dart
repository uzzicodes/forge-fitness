import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'food_vision.dart';
import 'main.dart' show lime, orange, gap, small, box;

class PackagedFoodEntry extends StatefulWidget {
  final http.Client? client;
  final bool deviceOnly;
  final void Function(Map<String, dynamic>) onReview;
  const PackagedFoodEntry({
    super.key,
    this.client,
    this.deviceOnly = false,
    required this.onReview,
  });
  @override
  State<PackagedFoodEntry> createState() => _PackagedFoodEntryState();
}

class _PackagedFoodEntryState extends State<PackagedFoodEntry> {
  late final http.Client client;
  final query = TextEditingController(),
      name = TextEditingController(),
      barcode = TextEditingController(),
      basis = TextEditingController(text: '100'),
      cal = TextEditingController(),
      pro = TextEditingController(),
      carb = TextEditingController(),
      fat = TextEditingController(),
      portion = TextEditingController(text: '29'),
      quantity = TextEditingController(text: '1');
  List<Map<String, dynamic>> results = [], saved = [];
  Map<String, dynamic>? chosen;
  DateTime? selectedAt;
  String error = '', unit = 'slice';
  bool busy = false,
      editing = false,
      checked = false,
      remember = false,
      labelEdited = false;
  @override
  void initState() {
    super.initState();
    client = widget.client ?? http.Client();
    loadSaved();
  }

  @override
  void dispose() {
    for (final c in [
      query,
      name,
      barcode,
      basis,
      cal,
      pro,
      carb,
      fat,
      portion,
      quantity,
    ]) {
      c.dispose();
    }
    if (widget.client == null) client.close();
    super.dispose();
  }

  Future<void> loadSaved() async {
    try {
      final r = await client
          .get(Uri.base.resolve('/api/my-foods'))
          .timeout(const Duration(seconds: 12));
      if (r.statusCode == 200 && mounted) {
        setState(
          () => saved = (jsonDecode(r.body)['foods'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList(),
        );
      }
    } catch (_) {}
  }

  Future<void> search() async {
    if (query.text.trim().length < 2) {
      setState(() => error = 'Enter a product name or barcode.');
      return;
    }
    setState(() {
      busy = true;
      error = '';
      results = [];
    });
    try {
      final q = query.text.trim(), isCode = RegExp(r'^\d+$').hasMatch(q);
      final r = await client
          .get(
            Uri.base
                .resolve('/api/products')
                .replace(queryParameters: {isCode ? 'barcode' : 'q': q}),
          )
          .timeout(const Duration(seconds: 22));
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      if (r.statusCode != 200) throw Exception(data['error']);
      if (mounted) {
        setState(() {
          results = (data['products'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          if (results.isEmpty) {
            error =
                'No complete product label found. Try the brand alone, its barcode, or enter the packet label. Generic meal text still works in the main entry.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> scan() async {
    try {
      final f = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1800,
        maxHeight: 1800,
      );
      if (f == null) return;
      final bytes = await f.readAsBytes();
      if (bytes.length > 8 * 1024 * 1024) {
        throw Exception('Use a barcode photo under 8 MB.');
      }
      if (!mounted) return;
      setState(() {
        busy = true;
        error = '';
      });
      final mime = bytes.length > 2 && bytes[0] == 137
          ? 'image/png'
          : bytes.length > 12 &&
                String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP'
          ? 'image/webp'
          : 'image/jpeg';
      final code = await scanFoodBarcode(
        'data:$mime;base64,${base64Encode(bytes)}',
      ).timeout(const Duration(seconds: 18));
      if (!mounted) return;
      query.text = code;
      await search();
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'No readable food barcode found. Use a sharp close-up with the whole barcode visible, or type its digits. The photo stays on this device.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void select(Map<String, dynamic> f) {
    if (selectedAt != null &&
        DateTime.now().difference(selectedAt!).inMilliseconds < 500) {
      return;
    }
    selectedAt = DateTime.now();
    setState(() {
      chosen = f;
      editing = true;
      name.text = f['name'] as String;
      barcode.text = f['barcode'] as String? ?? '';
      basis.text = '100';
      cal.text = '${f['calories']}';
      pro.text = '${f['protein']}';
      carb.text = '${f['carbs']}';
      fat.text = '${f['fat']}';
      portion.text = '${f['servingGrams'] ?? 100}';
      unit =
          f['servingUnit'] as String? ??
          ((f['servingLabel'] as String? ?? '').contains('slice')
              ? 'slice'
              : 'serving');
      quantity.text = '1';
      checked = false;
      remember = false;
      labelEdited = false;
      error = '';
    });
  }

  Widget field(String label, TextEditingController c, {bool number = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          enabled: !busy,
          keyboardType: number
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          decoration: InputDecoration(labelText: label),
          onChanged: (_) => setState(() {
            checked = false;
            if ([name, barcode, basis, cal, pro, carb, fat].contains(c)) {
              labelEdited = true;
            }
          }),
        ),
      );
  Future<void> review() async {
    final base = double.tryParse(basis.text),
        grams = double.tryParse(portion.text),
        count = double.tryParse(quantity.text),
        values = [
          cal,
          pro,
          carb,
          fat,
        ].map((c) => double.tryParse(c.text)).toList();
    if (!checked ||
        name.text.trim().length < 2 ||
        base == null ||
        !base.isFinite ||
        base <= 0 ||
        base > 1000 ||
        grams == null ||
        !grams.isFinite ||
        grams <= 0 ||
        grams > 1000 ||
        count == null ||
        !count.isFinite ||
        count <= 0 ||
        count > 100 ||
        values.any((n) => n == null || !n.isFinite || n < 0)) {
      setState(
        () => error =
            'Check the food name, all label values and positive portion weights, then confirm the packet match.',
      );
      return;
    }
    final totals = values
        .map((n) => ((n! * grams * count / base) * 10).round() / 10)
        .toList();
    if (totals[0] > 10000 ||
        totals.skip(1).any((n) => n > 1500) ||
        values.skip(1).fold<double>(0, (s, n) => s + n!) * 100 / base > 105) {
      setState(
        () => error =
            'Check the label basis and portion size; these totals are unusually large.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = '';
    });
    try {
      if (remember) {
        final r = await client
            .post(
              Uri.base.resolve('/api/my-foods'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                if (chosen?['id'] != null &&
                    !('${chosen!['id']}').startsWith('off-'))
                  'id': chosen!['id'],
                'name': name.text.trim(),
                'barcode': barcode.text.trim(),
                'basisGrams': base,
                'servingGrams': grams,
                'servingUnit': unit,
                'calories': values[0],
                'protein': values[1],
                'carbs': values[2],
                'fat': values[3],
              }),
            )
            .timeout(const Duration(seconds: 15));
        if (r.statusCode != 200) throw Exception(jsonDecode(r.body)['error']);
      }
      if (!mounted) return;
      final description = '$count × $grams g ($unit)';
      final source = labelEdited
          ? 'Your nutrition label'
          : chosen?['source'] as String? ?? 'Your nutrition label';
      widget.onReview({
        'is_food': true,
        'needsClarification': false,
        'name': name.text.trim(),
        'portion': description,
        'calories': totals[0],
        'protein': totals[1],
        'carbs': totals[2],
        'fat': totals[3],
        'source': source,
        'items': [
          {
            'name': name.text.trim(),
            'portion': description,
            'calories': totals[0],
          },
        ],
        'assumptions':
            'Calculated from the label values you checked, per $base g. Total food weight: ${grams * count} g. ${source == 'Open Food Facts' ? 'Open Food Facts community data, ODbL 1.0; verify your exact packet.' : ''}',
        'waterMl': 0,
      });
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Packet & saved labels',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              tooltip: 'Close product lookup',
              onPressed: busy ? null : () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        small(
          'Free lookup · no Gemini request. Barcode photos are decoded on your device; only the digits or search name go to Open Food Facts.',
        ),
        gap(16),
        field('Brand, product name or barcode', query),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: busy ? null : search,
              icon: const Icon(Icons.search),
              label: Text(busy ? 'Looking up…' : 'Find product'),
            ),
            OutlinedButton.icon(
              onPressed: busy ? null : scan,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Read barcode photo'),
            ),
          ],
        ),
        if (saved.isNotEmpty) ...[
          gap(20),
          const Text(
            'Your saved labels',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          for (final f in saved)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(f['name'] as String),
              subtitle: Text(
                '${f['servingGrams']} g / ${f['servingUnit']} · private',
              ),
              onTap: busy ? null : () => select(f),
              trailing: IconButton(
                tooltip: 'Remove saved label',
                icon: const Icon(Icons.delete_outline),
                onPressed: busy
                    ? null
                    : () async {
                        try {
                          final r = await client.delete(
                            Uri.base.resolve('/api/my-foods/${f['id']}'),
                          );
                          if (r.statusCode == 200) {
                            await loadSaved();
                          } else if (mounted) {
                            setState(
                              () => error = 'Could not remove that label.',
                            );
                          }
                        } catch (_) {
                          if (mounted) {
                            setState(
                              () =>
                                  error = 'Reconnect to remove a saved label.',
                            );
                          }
                        }
                      },
              ),
            ),
        ],
        for (final f in results)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(f['name'] as String),
            subtitle: Text(
              '${f['brand']} · ${f['barcode']}\n${(f['calories'] as num).round()} kcal · ${(f['protein'] as num).toStringAsFixed(1)} g protein / 100 g',
            ),
            isThreeLine: true,
            onTap: busy ? null : () => select(f),
          ),
        gap(10),
        TextButton.icon(
          onPressed: busy
              ? null
              : () {
                  if (selectedAt != null &&
                      DateTime.now().difference(selectedAt!).inMilliseconds <
                          500) {
                    return;
                  }
                  setState(() {
                    chosen = null;
                    labelEdited = true;
                    editing = true;
                    checked = false;
                    name.clear();
                    barcode.clear();
                    for (final c in [cal, pro, carb, fat]) {
                      c.clear();
                    }
                    basis.text = '100';
                    portion.text = '29';
                    unit = 'slice';
                  });
                },
          icon: const Icon(Icons.edit_note),
          label: const Text('Enter a missing packet label'),
        ),
        if (editing) ...[
          gap(14),
          box(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Check the label once',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
                ),
                gap(12),
                field('Product name / variant', name),
                field('Barcode (optional)', barcode, number: true),
                field(
                  'Label values below are per how many grams?',
                  basis,
                  number: true,
                ),
                field('Label calories (kcal)', cal, number: true),
                field('Label protein (g)', pro, number: true),
                field('Label carbs (g)', carb, number: true),
                field('Label fat (g)', fat, number: true),
                const Divider(),
                gap(10),
                const Text(
                  'How much did you eat?',
                  style: TextStyle(color: lime, fontWeight: FontWeight.w800),
                ),
                gap(12),
                DropdownButtonFormField<String>(
                  initialValue: unit,
                  decoration: const InputDecoration(labelText: 'Portion type'),
                  items: [
                    for (final u in ['slice', 'piece', 'serving'])
                      DropdownMenuItem(value: u, child: Text(u)),
                  ],
                  onChanged: busy
                      ? null
                      : (v) => setState(() {
                          unit = v!;
                          checked = false;
                        }),
                ),
                gap(12),
                field('Weight of one $unit (g)', portion, number: true),
                field('Number of ${unit}s eaten', quantity, number: true),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: checked,
                  onChanged: busy
                      ? null
                      : (v) => setState(() => checked = v == true),
                  title: const Text(
                    'The product and label values match my packet',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: remember,
                  onChanged: busy
                      ? null
                      : (v) => setState(() => remember = v == true),
                  title: Text(
                    widget.deviceOnly
                        ? 'Remember this label on this device'
                        : 'Remember this label privately',
                    style: const TextStyle(fontSize: 13),
                  ),
                  subtitle: Text(
                    widget.deviceOnly
                        ? 'Saved only in this browser or installed app. Next time, type the same product name and quantity; text estimation needs internet.'
                        : 'Next time, type the same product name and quantity. Internet is needed to retrieve saved labels.',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
                FilledButton(
                  onPressed: busy ? null : review,
                  child: const Text('Review this portion'),
                ),
              ],
            ),
          ),
        ],
        if (error.isNotEmpty) ...[
          gap(14),
          Text(error, style: const TextStyle(color: orange)),
        ],
        gap(16),
        small(
          'Open Food Facts is a community database and may not contain your exact Pakistani product. Never treat a different brand or variant as your packet.',
        ),
        TextButton(
          onPressed: () => launchUrl(
            Uri.parse('https://world.openfoodfacts.org'),
            mode: LaunchMode.externalApplication,
          ),
          child: const Text('Food data: Open Food Facts · ODbL 1.0'),
        ),
        TextButton(
          onPressed: () => launchUrl(
            Uri.parse('https://opendatacommons.org/licenses/odbl/1.0/'),
            mode: LaunchMode.externalApplication,
          ),
          child: const Text('Open database licence'),
        ),
        small('Barcode decoder: ZXing · Apache 2.0'),
        gap(30),
      ],
    ),
  );
}
