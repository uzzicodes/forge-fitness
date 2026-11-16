import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'models.dart';
import 'meal_editor.dart';
import 'food_vision.dart';
import 'packaged_food.dart';
import 'main.dart'
    show lime, orange, muted, ink, gap, small, tag, box, toast, showSheet;

class QuickMealEntry extends StatefulWidget {
  final AppStore store;
  final DateTime date;
  final http.Client? client;
  /// Pre-selected photo; used by tests (the picker cannot run in widget tests).
  final Uint8List? initialPhoto;
  const QuickMealEntry({
    super.key,
    required this.store,
    required this.date,
    this.client,
    this.initialPhoto,
  });
  @override
  State<QuickMealEntry> createState() => _QuickMealEntryState();
}

class _QuickMealEntryState extends State<QuickMealEntry> {
  final message = TextEditingController();
  Uint8List? photo;
  String mime = 'image/jpeg', error = '';
  bool busy = false, saving = false, useGemini = false, aiReady = false;
  String aiProvider = 'gemini';
  List<String> providers = [];
  Map<String, dynamic>? estimate;
  List<String> suggestions = [];
  /// True when the current estimate came from photo AI. A photo cannot
  /// measure weight, so the user must confirm the portion before logging.
  bool photoEstimate = false;
  double? portionFactor;
  late final http.Client client;
  @override
  void initState() {
    super.initState();
    client = widget.client ?? widget.store.foodClient();
    photo = widget.initialPhoto;
    checkAi();
  }

  Future<void> checkAi() async {
    try {
      final r = await client
          .get(Uri.base.resolve('/api/status'))
          .timeout(const Duration(seconds: 8));
      if (r.statusCode == 200 && mounted) {
        setState(() {
          final data = jsonDecode(r.body) as Map<String, dynamic>;
          providers = [
            if (data['configured'] == true ||
                data['aiProviders']?['gemini'] == true)
              'gemini',
            if (data['aiProviders']?['groq'] == true) 'groq',
          ];
          aiReady = providers.isNotEmpty;
          if (aiReady) aiProvider = providers.first;
          useGemini = aiReady;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    message.dispose();
    if (widget.client == null) client.close();
    super.dispose();
  }

  Future<void> pick() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1400,
        maxHeight: 1400,
        imageQuality: 80,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 8 * 1024 * 1024) {
        throw Exception('Choose a photo under 8 MB.');
      }
      final jpg = bytes.length > 3 && bytes[0] == 255 && bytes[1] == 216,
          png = bytes.length > 8 && bytes[0] == 137 && bytes[1] == 80,
          webp =
              bytes.length > 12 &&
              String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP';
      if (!jpg && !png && !webp) {
        throw Exception(
          'Choose a JPEG, PNG or WebP photo. Your iPhone may export a compatible copy from Photos.',
        );
      }
      if (mounted) {
        setState(() {
          photo = bytes;
          mime = png
              ? 'image/png'
              : webp
              ? 'image/webp'
              : 'image/jpeg';
          useGemini = aiReady;
          estimate = null;
          suggestions = [];
          error = '';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> understand() async {
    if (message.text.trim().isEmpty && photo == null) {
      setState(() => error = 'Write what you ate, or add a photo.');
      return;
    }
    setState(() {
      busy = true;
      error = '';
      estimate = null;
      suggestions = [];
    });
    try {
      final image = photo == null
          ? null
          : 'data:$mime;base64,${base64Encode(photo!)}';
      if (message.text.trim().isEmpty && image != null && !useGemini) {
        final found = await suggestFood(
          image,
        ).timeout(const Duration(seconds: 75));
        if (!mounted) return;
        setState(() {
          suggestions = found.map((f) => f['name'] as String).toList();
          estimate = {
            'needsClarification': true,
            'question': suggestions.isEmpty
                ? 'Tell me the food and amount, for example “3 boiled eggs”. This small matcher cannot identify every food.'
                : 'Choose the closest food, then add how much you ate. Photo suggestions cannot measure portions.',
            'items': [],
          };
        });
        return;
      }
      final uri = Uri.base.resolve('/api/interpret'),
          body = jsonEncode({
            'description': message.text.trim(),
            'useGemini': useGemini,
            'provider': aiProvider,
            if (useGemini && image != null) 'image': image,
          });
      final r = await client
          .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 70));
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      if (r.statusCode != 200) {
        throw Exception(data['error'] ?? 'Could not read that meal.');
      }
      if (mounted) {
        setState(() {
          estimate = data;
          photoEstimate = useGemini && image != null;
          portionFactor = photoEstimate ? null : 1;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is http.ClientException
              ? 'Connect to estimate this message, or use a label below. Saved meals and training still work offline.'
              : e.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> advanced() async {
    final before = widget.store.meals.length;
    await showSheet(
      context,
      MealEditor(store: widget.store, date: widget.date),
    );
    if (mounted && widget.store.meals.length > before) Navigator.pop(context);
  }

  Future<void> packaged() async {
    await showSheet(
      context,
      Builder(
        builder: (sheetContext) => PackagedFoodEntry(
          client: client,
          deviceOnly: widget.store.guestMode,
          onReview: (data) {
            Navigator.pop(sheetContext);
            if (mounted) {
              setState(() {
                estimate = data;
                photoEstimate = false;
                portionFactor = 1;
                message.text = data['name'] as String;
                photo = null;
                useGemini = false;
                error = '';
              });
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final raw = estimate;
    final ready = raw != null && raw['needsClarification'] != true;
    final Map<String, dynamic> base = raw ?? const {};
    final factor = portionFactor;
    // What the review card shows and what gets logged: the estimate scaled
    // by the portion the user chose (unchanged when no scaling applies).
    final Map<String, dynamic> shown = ready && factor != null && factor != 1
        ? scaleEstimate(base, factor)
        : base;
    final j = raw == null ? null : shown;
    final needsPortion = ready && photoEstimate && factor == null;
    final items = (j?['items'] as List? ?? []);
    return PopScope(
      canPop: !busy && !saving,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Just tell me what you ate.',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Close meal entry',
                  onPressed: busy || saving
                      ? null
                      : () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            gap(8),
            small('${prettyDay(widget.date)} · text first, photo optional'),
            gap(20),
            TextField(
              controller: message,
              enabled: !busy && !saving,
              minLines: 2,
              maxLines: 4,
              maxLength: 1000,
              onChanged: (_) => setState(() => estimate = null),
              decoration: const InputDecoration(
                labelText: 'What did you eat or drink?',
                hintText: 'I ate 3 boiled eggs and drank a glass of milk',
              ),
            ),
            gap(8),
            if (photo == null)
              Wrap(
                spacing: 8,
                runSpacing: 5,
                children:
                    [
                          '3 boiled eggs',
                          '2 roti and chicken karahi',
                          '500 ml water',
                        ]
                        .map(
                          (s) => ActionChip(
                            label: Text(
                              s,
                              style: const TextStyle(fontSize: 12),
                            ),
                            onPressed: busy
                                ? null
                                : () {
                                    setState(() {
                                      message.text = s;
                                      estimate = null;
                                    });
                                  },
                          ),
                        )
                        .toList(),
              ),
            gap(12),
            OutlinedButton.icon(
              onPressed: busy || saving ? null : packaged,
              icon: const Icon(Icons.inventory_2_outlined),
              label: const Text('Packet barcode / saved label'),
            ),
            gap(12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: busy || saving ? null : pick,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: Text(photo == null ? 'Add photo' : 'Change photo'),
                ),
                if (photo != null) ...[
                  const SizedBox(width: 10),
                  IconButton(
                    tooltip: 'Remove meal photo',
                    onPressed: busy
                        ? null
                        : () => setState(() {
                            photo = null;
                            estimate = null;
                            useGemini = false;
                          }),
                    icon: const Icon(Icons.delete_outline, color: muted),
                  ),
                ],
              ],
            ),
            if (photo != null) ...[
              gap(12),
              ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.memory(
                  photo!,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              gap(8),
              small(
                'Photo stays on this device unless you choose photo AI below. FORGE does not archive it.',
              ),
            ],
            gap(14),
            if (useGemini) ...[
              small(
                aiProvider == 'groq'
                    ? 'Groq enabled: this message and optional photo go to Groq when you tap Estimate. FORGE does not archive photos.'
                    : 'Gemini enabled: unclear meals and photos go to Google when you tap Estimate. Free-tier inputs may improve Google products. FORGE does not archive photos.',
              ),
              gap(10),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: busy || saving ? null : understand,
                icon: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: ink,
                        ),
                      )
                    : const Icon(Icons.auto_awesome_outlined),
                label: Text(
                  busy
                      ? 'Understanding your meal…'
                      : useGemini
                      ? 'Estimate with AI'
                      : 'Estimate my meal',
                ),
              ),
            ),
            if (error.isNotEmpty) ...[
              gap(14),
              Text(error, style: const TextStyle(color: orange)),
            ],
            if (j != null && j['needsClarification'] == true) ...[
              gap(20),
              box(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    tag('ONE QUICK CHECK', color: orange),
                    gap(10),
                    Text(j['question'] as String? ?? 'Tell me a little more.'),
                    if (suggestions.isNotEmpty) ...[
                      gap(12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: suggestions
                            .map(
                              (s) => ActionChip(
                                label: Text(s),
                                onPressed: () {
                                  setState(() {
                                    message.text = s;
                                    estimate = null;
                                  });
                                },
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    gap(10),
                    small(
                      'Edit the message above and estimate again. Generic estimates state their assumed food and portion; packet lookup can use your exact label.',
                    ),
                  ],
                ),
              ),
            ],
            if (ready) ...[
              gap(22),
              box(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    tag('READY TO REVIEW'),
                    gap(14),
                    ...items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.check_circle_outline,
                              color: lime,
                              size: 19,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['name'] as String,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  small(item['portion'] as String? ?? ''),
                                ],
                              ),
                            ),
                            Text(
                              '${(item['calories'] as num).round()} kcal',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (items.isNotEmpty) ...[
                      const Divider(),
                      gap(8),
                      Wrap(
                        spacing: 22,
                        runSpacing: 10,
                        children: [
                          Text(
                            '${(shown['calories'] as num).round()} kcal',
                            style: const TextStyle(
                              fontSize: 27,
                              fontWeight: FontWeight.w800,
                              color: lime,
                            ),
                          ),
                          Text(
                            '${(shown['protein'] as num).toStringAsFixed(1)} g protein',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: orange,
                            ),
                          ),
                        ],
                      ),
                      gap(8),
                      small(
                        '${(shown['carbs'] as num).toStringAsFixed(1)} g carbs · ${(shown['fat'] as num).toStringAsFixed(1)} g fat',
                      ),
                    ],
                    if ((shown['waterMl'] as num? ?? 0) > 0) ...[
                      gap(10),
                      Text(
                        '${shown['waterMl']} ml water',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF97C8F2),
                        ),
                      ),
                    ],
                    gap(12),
                    if ((shown['assumptions'] as String? ?? '').isNotEmpty)
                      Text(
                        shown['assumptions'] as String,
                        style: const TextStyle(
                          color: muted,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    gap(8),
                    small(
                      'An estimate from the food and portions shown. Change the message if a size or recipe is different.',
                    ),
                  ],
                ),
              ),
              if (photoEstimate) ...[
                gap(14),
                PortionCheck(
                  assumed: base['portion'] as String? ?? '',
                  selected: portionFactor,
                  onChanged: (f) => setState(() => portionFactor = f),
                ),
              ],
              gap(14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: saving || busy || needsPortion
                      ? null
                      : () async {
                          setState(() => saving = true);
                          await widget.store.confirmMealEstimate(
                            widget.date,
                            shown,
                          );
                          if (context.mounted) {
                            Navigator.pop(context);
                            toast(
                              context,
                              'Confirmed. Your daily totals are updated.',
                            );
                          }
                        },
                  icon: const Icon(Icons.check),
                  label: Text(
                    saving
                        ? 'Saving…'
                        : needsPortion
                        ? 'Choose your portion first'
                        : 'Yes, confirm & log',
                  ),
                ),
              ),
            ],
            gap(18),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('More options', style: TextStyle(fontSize: 14)),
              children: [
                const Text(
                  'Everyday text uses free references. Connected photo AI can estimate unfamiliar meals using stated portions and recipes. Packet lookup and saved labels use no AI requests.',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
                if (aiReady) ...[
                  DropdownButtonFormField<String>(
                    initialValue: aiProvider,
                    decoration: const InputDecoration(
                      labelText: 'Photo & unfamiliar-meal AI',
                    ),
                    items: [
                      for (final p in providers)
                        DropdownMenuItem(
                          value: p,
                          child: Text(
                            p == 'groq' ? 'Groq · free-tier vision' : 'Gemini',
                          ),
                        ),
                    ],
                    onChanged: busy
                        ? null
                        : (p) => setState(() {
                            aiProvider = p!;
                            estimate = null;
                          }),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(
                      'Use ${aiProvider == 'groq' ? 'Groq' : 'Gemini'} for this estimate',
                      style: TextStyle(fontSize: 13),
                    ),
                    subtitle: Text(
                      aiProvider == 'groq'
                          ? 'Sends this message and optional photo to Groq. Provider token and request limits apply.'
                          : 'Sends this message and optional photo to Google. Free-tier inputs may improve Google products.',
                      style: TextStyle(fontSize: 11),
                    ),
                    value: useGemini,
                    onChanged: busy
                        ? null
                        : (v) => setState(() {
                            useGemini = v == true;
                            estimate = null;
                          }),
                  ),
                ] else
                  TextButton(
                    onPressed: () => launchUrl(Uri.base.resolve('/configure')),
                    child: Text(
                      widget.store.guestMode
                          ? 'Sign in to connect optional photo AI ↗'
                          : 'Connect free-tier Gemini or Groq ↗',
                    ),
                  ),
                TextButton.icon(
                  onPressed: busy ? null : advanced,
                  icon: const Icon(Icons.edit_note),
                  label: const Text('Use a nutrition label or recipe builder'),
                ),
              ],
            ),
            gap(8),
          ],
        ),
      ),
    );
  }
}

/// Portion multipliers offered after a photo estimate.
const portionChoices = <(String, double)>[
  ('Half', .5),
  ('¾', .75),
  ('As shown', 1),
  ('1¼', 1.25),
  ('1½', 1.5),
  ('Double', 2),
];

String _factor(double f) => f == f.roundToDouble()
    ? f.toInt().toString()
    : f.toString().replaceFirst(RegExp(r'0+$'), '');

/// Scales a reviewed estimate by the portion the user actually ate.
/// Only nutrition and the portion text change; the AI's assumptions stay
/// visible so the record remains transparent about where numbers came from.
Map<String, dynamic> scaleEstimate(Map<String, dynamic> j, double factor) {
  double r(Object? v) => ((v as num? ?? 0) * factor * 10).round() / 10;
  final note = 'you set ×${_factor(factor)} of the assumed portion';
  return {
    ...j,
    for (final k in ['calories', 'protein', 'carbs', 'fat']) k: r(j[k]),
    'portion': '${j['portion'] ?? ''} · $note',
    'items': [
      for (final item in (j['items'] as List? ?? []))
        if (item is Map)
          {
            ...item,
            for (final k in ['calories', 'protein', 'carbs', 'fat'])
              k: r(item[k]),
            'portion': '${item['portion'] ?? ''} · $note',
          },
    ],
  };
}

class PortionCheck extends StatelessWidget {
  final String assumed;
  final double? selected;
  final ValueChanged<double> onChanged;
  const PortionCheck({
    super.key,
    required this.assumed,
    required this.selected,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => box(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        tag('CHECK YOUR PORTION', color: orange),
        gap(10),
        Text(
          assumed.isEmpty
              ? 'A photo cannot measure weight. How much did you eat?'
              : 'A photo cannot measure weight. The estimate assumed: $assumed',
        ),
        gap(12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (label, f) in portionChoices)
              ChoiceChip(
                label: Text(label),
                selected: selected == f,
                onSelected: (_) => onChanged(f),
              ),
          ],
        ),
        gap(10),
        small(
          'Choose “As shown” if that matches what you ate. Calories and macros scale with your choice; it is still an estimate, not a measurement.',
        ),
      ],
    ),
  );
}
