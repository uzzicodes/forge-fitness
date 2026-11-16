import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'models.dart';
import 'food_calculator.dart';
import 'food_vision.dart';
import 'main.dart' show orange, muted, gap, tag, small, toast, showSheet;

Future<void> recoverPhoto(
  BuildContext context,
  AppStore store,
  DateTime date,
) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  try {
    final response = await ImagePicker().retrieveLostData();
    if (!context.mounted || response.isEmpty) return;
    if (response.files?.isNotEmpty ?? false) {
      await showSheet(
        context,
        MealEditor(store: store, date: date, recovered: response.files!.first),
      );
    }
  } catch (_) {
    if (context.mounted) {
      toast(
        context,
        'Could not recover the previous photo. Please choose it again.',
      );
    }
  }
}

class MealEditor extends StatefulWidget {
  final AppStore store;
  final DateTime date;
  final Meal? existing;
  final XFile? recovered;
  const MealEditor({
    super.key,
    required this.store,
    required this.date,
    this.existing,
    this.recovered,
  });
  @override
  State<MealEditor> createState() => _MealEditorState();
}

class _MealEditorState extends State<MealEditor> {
  final form = GlobalKey<FormState>();
  final description = TextEditingController();
  final name = TextEditingController(),
      cal = TextEditingController(),
      pro = TextEditingController(),
      carb = TextEditingController(text: '0'),
      fat = TextEditingController(text: '0'),
      notes = TextEditingController(),
      contextNotes = TextEditingController();
  String type = 'Lunch', error = '', assumptions = '', mime = 'image/jpeg';
  bool busy = false, estimated = false, consent = false, saving = false;
  Uint8List? photo;
  String nutritionSource = 'manual';
  @override
  void initState() {
    super.initState();
    final m = widget.existing;
    if (m != null) {
      name.text = m.name;
      cal.text = '${m.calories}';
      pro.text = '${m.protein}';
      carb.text = '${m.carbs}';
      fat.text = '${m.fat}';
      notes.text = m.notes;
      type = m.type;
      estimated = m.estimated;
      nutritionSource = m.source;
    }
    if (widget.recovered != null) {
      readPhoto(widget.recovered!);
    }
  }

  @override
  void dispose() {
    description.dispose();
    for (final c in [name, cal, pro, carb, fat, notes, contextNotes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> readPhoto(XFile file) async {
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    if (bytes.length > 8 * 1024 * 1024) {
      setState(() => error = 'Please use a photo smaller than 8 MB.');
      return;
    }
    final jpeg = bytes.length > 3 && bytes[0] == 255 && bytes[1] == 216;
    final png =
        bytes.length > 8 &&
        bytes[0] == 137 &&
        bytes[1] == 80 &&
        bytes[2] == 78 &&
        bytes[3] == 71;
    final webp =
        bytes.length > 12 &&
        String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP';
    if (!jpeg && !png && !webp) {
      setState(() => error = 'Choose a JPEG, PNG or WebP photo.');
      return;
    }
    setState(() {
      photo = bytes;
      mime = png
          ? 'image/png'
          : webp
          ? 'image/webp'
          : 'image/jpeg';
      error = '';
      consent = false;
    });
  }

  Future<void> pick(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1400,
        maxHeight: 1400,
        imageQuality: 80,
      );
      if (file != null) await readPhoto(file);
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Could not open the camera or photo library. Check permissions, or enter the meal manually.',
        );
      }
    }
  }

  Future<void> analyze() async {
    if (photo == null && description.text.trim().length < 2) {
      setState(
        () => error =
            'Type a food name, such as banana shake, or choose a meal photo.',
      );
      return;
    }
    final s = widget.store;
    if (s.guestMode) {
      setState(
        () => error =
            'Broader photo AI requires sign-in. Use the free food calculator or on-device matcher below, or enter the label values.',
      );
      return;
    }
    final base = s.server.isNotEmpty
        ? s.server
        : (kIsWeb ? Uri.base.origin : '');
    if (base.isEmpty) {
      setState(
        () => error =
            'Connect your computer in Settings → Meal estimates connection, then try again. Manual logging works offline.',
      );
      return;
    }
    if (s.token.isEmpty) {
      setState(
        () => error =
            'Add the pairing token from your computer’s server in Settings.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = '';
    });
    try {
      final response = await http
          .post(
            Uri.parse('$base/api/analyze'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${s.token}',
            },
            body: jsonEncode({
              if (photo != null)
                'image': 'data:$mime;base64,${base64Encode(photo!)}',
              'description': description.text.trim(),
              'context': contextNotes.text.trim(),
            }),
          )
          .timeout(const Duration(seconds: 100));
      final j = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200) {
        throw Exception(j['error'] ?? 'Photo analysis failed.');
      }
      if (!mounted) return;
      setState(() {
        name.text = j['name'] as String;
        cal.text = '${j['calories']}';
        pro.text = '${j['protein']}';
        carb.text = '${j['carbs']}';
        fat.text = '${j['fat']}';
        assumptions = j['assumptions'] as String;
        notes.text = '${j['portion']}\n$assumptions';
        estimated = true;
        nutritionSource = 'Gemini estimate';
      });
    } on TimeoutException {
      if (mounted) {
        setState(
          () => error =
              'Analysis timed out. Please retry, or enter your meal manually.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void applyNutrition(Map<String, dynamic> j) {
    if (!mounted) return;
    setState(() {
      name.text = j['name'] as String;
      cal.text = j['calories'].toString();
      pro.text = j['protein'].toString();
      carb.text = j['carbs'].toString();
      fat.text = j['fat'].toString();
      assumptions = j['assumptions'] as String;
      notes.text = '${j['portion'] as String}\n$assumptions';
      estimated = true;
      nutritionSource = j['source'] as String? ?? 'USDA reference';
    });
  }

  Future<void> freeLookup() async {
    if (!widget.store.hosted) {
      setState(
        () => error =
            'The free food database is available in the hosted online app.',
      );
      return;
    }
    var suggestions = <String>[];
    if (photo != null) {
      setState(() {
        busy = true;
        error = '';
      });
      try {
        final found = await suggestFood(
          'data:$mime;base64,${base64Encode(photo!)}',
        ).timeout(const Duration(seconds: 60));
        suggestions = found.map((r) => r['name'] as String).toList();
      } catch (_) {
        if (mounted) {
          setState(
            () => error =
                'The small photo matcher could not identify this meal. Type its name in the food database.',
          );
        }
      } finally {
        if (mounted) setState(() => busy = false);
      }
    }
    if (!mounted) return;
    await showSheet(
      context,
      FoodCalculator(
        store: widget.store,
        initialName: description.text.trim(),
        notes: contextNotes.text,
        suggestions: suggestions,
        onConfirm: applyNutrition,
      ),
    );
  }

  Widget macroField(String label, TextEditingController c, double max) =>
      TextFormField(
        controller: c,
        enabled: !busy,
        onChanged: (_) => nutritionSource = 'Manual correction',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label),
        validator: (s) {
          final n = double.tryParse(s ?? '');
          return n == null || !n.isFinite || n < 0 || n > max
              ? 'Enter 0–${max.round()}'
              : null;
        },
      );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy && !saving,
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.existing == null
                        ? 'Fuel your progress.'
                        : 'Edit your meal.',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: busy || saving
                      ? null
                      : () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            small(prettyDay(widget.date)),
            gap(20),
            if (widget.existing == null) ...[
              TextField(
                controller: description,
                enabled: !busy,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'What did you eat?',
                  hintText: 'e.g. banana shake, chicken biryani, 2 eggs',
                ),
              ),
              small('Enter a food name, choose a photo, or use both.'),
              gap(12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : () => pick(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Choose photo'),
                    ),
                  ),
                  if (!kIsWeb ||
                      defaultTargetPlatform == TargetPlatform.iOS ||
                      defaultTargetPlatform == TargetPlatform.android) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: busy ? null : () => pick(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Camera'),
                      ),
                    ),
                  ],
                ],
              ),
              gap(12),
              if (photo != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.memory(
                    photo!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, error, stack) => const SizedBox(
                      height: 80,
                      child: Center(child: Text('Photo preview unavailable')),
                    ),
                  ),
                ),
                gap(12),
              ],
              TextField(
                controller: contextNotes,
                enabled: !busy,
                maxLength: 700,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Serving & ingredients (optional)',
                  hintText: 'e.g. 1 banana, 250 ml milk, no added sugar',
                ),
              ),
              small(
                'Leave blank for an estimated typical serving. The assumed recipe and portion will be shown for review.',
              ),
              if (widget.store.hosted) ...[
                gap(16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: busy ? null : freeLookup,
                    icon: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                    label: Text(
                      busy
                          ? 'Matching your meal…'
                          : 'Free food & portion calculator',
                    ),
                  ),
                ),
                gap(10),
                small(
                  'No API key needed. The small photo matcher suggests 101 supported dishes; choose the food and serving you actually ate. For other foods, type the name. Photos are not archived.',
                ),
              ],
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: consent,
                onChanged: busy ? null : (v) => setState(() => consent = v!),
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(
                  'Optional Gemini estimate: send this food name, notes and photo to Google. Free-tier input may be used to improve Google products.',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: busy || !consent ? null : analyze,
                  icon: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome_outlined, size: 18),
                  label: Text(
                    busy
                        ? 'Estimating your meal…'
                        : 'Gemini estimate (optional)',
                  ),
                ),
              ),
              gap(20),
              small('REVIEW THE ESTIMATE BELOW · OR ENTER VALUES FROM A LABEL'),
              gap(12),
            ],
            if (error.isNotEmpty) ...[
              Text(error, style: const TextStyle(color: orange)),
              gap(16),
            ],
            if (estimated) ...[
              tag('ESTIMATE · REVIEW BEFORE SAVING', color: orange),
              gap(10),
              Text(
                assumptions.isEmpty
                    ? 'Estimates depend on portion size and ingredients. Review the assumed recipe and correct the values below if needed.'
                    : assumptions,
                style: const TextStyle(color: muted, fontSize: 12),
              ),
              gap(16),
            ],
            TextFormField(
              controller: name,
              enabled: !busy,
              decoration: const InputDecoration(
                labelText: 'Meal name',
                hintText: 'e.g. Chicken, rice & vegetables',
              ),
              maxLength: 100,
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Give your meal a name'
                  : null,
            ),
            gap(12),
            DropdownButtonFormField<String>(
              initialValue: type,
              decoration: const InputDecoration(labelText: 'Meal'),
              items: [
                'Breakfast',
                'Lunch',
                'Dinner',
                'Snack',
              ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: busy ? null : (v) => setState(() => type = v!),
            ),
            gap(16),
            Row(
              children: [
                Expanded(child: macroField('Calories · kcal', cal, 10000)),
                const SizedBox(width: 12),
                Expanded(child: macroField('Protein · g', pro, 1500)),
              ],
            ),
            gap(16),
            Row(
              children: [
                Expanded(child: macroField('Carbs · g', carb, 1500)),
                const SizedBox(width: 12),
                Expanded(child: macroField('Fat · g', fat, 1500)),
              ],
            ),
            gap(16),
            TextField(
              controller: notes,
              enabled: !busy,
              maxLength: 2000,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Portion & notes (optional)',
              ),
            ),
            gap(16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: busy || saving
                    ? null
                    : () async {
                        if (!form.currentState!.validate()) return;
                        setState(() => saving = true);
                        final m = Meal(
                          id:
                              widget.existing?.id ??
                              DateTime.now().microsecondsSinceEpoch.toString(),
                          date: dayKey(widget.date),
                          name: name.text.trim(),
                          type: type,
                          calories: double.parse(cal.text),
                          protein: double.parse(pro.text),
                          carbs: double.parse(carb.text),
                          fat: double.parse(fat.text),
                          notes: notes.text.trim(),
                          estimated: estimated,
                          source: nutritionSource,
                        );
                        await widget.store.upsertMeal(m);
                        if (context.mounted) {
                          Navigator.pop(context);
                          toast(context, 'Meal saved. Daily totals updated.');
                        }
                      },
                icon: const Icon(Icons.check),
                label: Text(
                  widget.existing == null
                      ? 'Confirm & add to my day'
                      : 'Save changes',
                ),
              ),
            ),
            if (widget.existing != null)
              Center(
                child: TextButton.icon(
                  onPressed: saving || busy
                      ? null
                      : () async {
                          final remove = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Delete this meal?'),
                              content: const Text(
                                'This also removes its nutrition from your daily totals.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Keep meal'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                          if (remove == true) {
                            await widget.store.removeMeal(widget.existing!.id);
                            if (context.mounted) Navigator.pop(context);
                          }
                        },
                  icon: const Icon(Icons.delete_outline, color: orange),
                  label: const Text(
                    'Delete meal',
                    style: TextStyle(color: orange),
                  ),
                ),
              ),
            gap(12),
          ],
        ),
      ),
    ),
  );
}
