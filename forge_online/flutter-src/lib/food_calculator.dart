import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'models.dart';
import 'main.dart' show lime, orange, muted, gap, small, tag, box, toast;

class FoodCalculator extends StatefulWidget {
  final String initialName, notes;
  final List<String> suggestions;
  final void Function(Map<String, dynamic>) onConfirm;
  final http.Client? client;
  final AppStore? store;
  const FoodCalculator({
    super.key,
    this.initialName = '',
    this.notes = '',
    this.suggestions = const [],
    required this.onConfirm,
    this.client,
    this.store,
  });
  @override
  State<FoodCalculator> createState() => _FoodCalculatorState();
}

class _Ingredient {
  final Map<String, dynamic> food;
  final TextEditingController grams;
  _Ingredient(this.food, double amount)
    : grams = TextEditingController(
        text: amount.toStringAsFixed(amount % 1 == 0 ? 0 : 1),
      );
}

class _FoodCalculatorState extends State<FoodCalculator> {
  late final http.Client client;
  final search = TextEditingController(),
      name = TextEditingController(),
      servings = TextEditingController(text: '1');
  final List<_Ingredient> ingredients = [];
  List<Map<String, dynamic>> results = [], recipes = [];
  String error = '';
  bool loading = false, busy = false, saveRecipe = true;
  Timer? debounce;
  int queryId = 0;
  @override
  void initState() {
    super.initState();
    client = widget.client ?? widget.store?.foodClient() ?? http.Client();
    name.text = widget.initialName;
    search.text = widget.initialName;
    initialize();
  }

  Future<void> initialize() async {
    await loadRecipes();
    if (RegExp(
      r'banana.*(shake|smoothie)|(shake|smoothie).*banana',
      caseSensitive: false,
    ).hasMatch(widget.initialName)) {
      try {
        final banana = await food(173944), milk = await food(171265);
        if (!mounted) return;
        setState(() {
          ingredients.add(_Ingredient(banana, 118));
          ingredients.add(_Ingredient(milk, 258));
          if (name.text.trim().isEmpty) name.text = 'Banana shake';
        });
      } catch (_) {
        if (mounted) {
          setState(
            () => error =
                'Could not load the banana shake preset. Search its ingredients below.',
          );
        }
      }
    } else if (search.text.trim().isNotEmpty) {
      await findFoods(search.text);
    }
  }

  Future<Map<String, dynamic>> food(Object id) async {
    final r = await client
        .get(Uri.base.resolve('/api/foods/$id'))
        .timeout(const Duration(seconds: 15));
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode != 200) throw Exception(j['error']);
    return Map<String, dynamic>.from(j['food'] as Map);
  }

  Future<void> loadRecipes() async {
    try {
      final r = await client
          .get(Uri.base.resolve('/api/recipes'))
          .timeout(const Duration(seconds: 10));
      if (r.statusCode == 200 && mounted) {
        setState(
          () => recipes = (jsonDecode(r.body)['recipes'] as List)
              .map((r) => Map<String, dynamic>.from(r as Map))
              .toList(),
        );
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    debounce?.cancel();
    if (widget.client == null) client.close();
    for (final c in [
      search,
      name,
      servings,
      ...ingredients.map((i) => i.grams),
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> findFoods(String value) async {
    final id = ++queryId;
    if (value.trim().length < 2) {
      setState(() => results = []);
      return;
    }
    setState(() {
      loading = true;
      error = '';
    });
    try {
      final r = await client
          .get(
            Uri.base
                .resolve('/api/foods')
                .replace(queryParameters: {'q': value.trim()}),
          )
          .timeout(const Duration(seconds: 15));
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      if (r.statusCode != 200) {
        throw Exception(j['error'] ?? 'Food search failed.');
      }
      if (!mounted || id != queryId) return;
      setState(
        () => results = (j['foods'] as List)
            .map((f) => Map<String, dynamic>.from(f as Map))
            .toList(),
      );
    } catch (_) {
      if (mounted && id == queryId) {
        setState(
          () => error =
              'Food search could not connect. Reconnect or enter the meal manually.',
        );
      }
    } finally {
      if (mounted && id == queryId) setState(() => loading = false);
    }
  }

  void add(Map<String, dynamic> food) {
    setState(() {
      ingredients.add(_Ingredient(food, 100));
      if (name.text.trim().isEmpty) name.text = food['name'] as String;
      search.clear();
      results = [];
    });
  }

  Map<String, double> totals() {
    final n = double.tryParse(servings.text) ?? 1;
    final sums = {'calories': 0.0, 'protein': 0.0, 'carbs': 0.0, 'fat': 0.0};
    for (final i in ingredients) {
      final grams = double.tryParse(i.grams.text) ?? 0;
      for (final k in sums.keys) {
        sums[k] =
            sums[k]! +
            (i.food[k] as num).toDouble() * grams / 100 / (n > 0 ? n : 1);
      }
    }
    return sums;
  }

  Future<void> complete() async {
    if (ingredients.isEmpty) {
      setState(() => error = 'Add at least one food.');
      return;
    }
    final count = double.tryParse(servings.text);
    if (count == null ||
        !count.isFinite ||
        count < 1 ||
        count > 30 ||
        ingredients.any((i) {
          final g = double.tryParse(i.grams.text);
          return g == null || !g.isFinite || g <= 0 || g > 5000;
        })) {
      setState(
        () => error =
            'Use ingredient weights over 0 and up to 5,000 g, and 1–30 servings.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = '';
    });
    try {
      final body = {
        'name': name.text.trim(),
        'servings': count,
        'items': ingredients
            .map(
              (i) => {
                'fdcId': i.food['id'],
                'grams': double.parse(i.grams.text),
              },
            )
            .toList(),
      };
      final r = await client
          .post(
            Uri.base.resolve(
              saveRecipe ? '/api/recipes' : '/api/recipes/calculate',
            ),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      if (r.statusCode != 200) {
        throw Exception(j['error'] ?? 'Calculation failed.');
      }
      if (!mounted) return;
      widget.onConfirm(j);
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> useRecipe(Map<String, dynamic> recipe) async {
    setState(() => busy = true);
    try {
      final next = <_Ingredient>[];
      for (final i in recipe['ingredients'] as List) {
        next.add(
          _Ingredient(
            await food(i['fdcId'] as Object),
            (i['grams'] as num).toDouble(),
          ),
        );
      }
      if (!mounted) return;
      setState(() {
        for (final i in ingredients) {
          i.grams.dispose();
        }
        ingredients
          ..clear()
          ..addAll(next);
        name.text = recipe['name'] as String;
        servings.text = recipe['servings'].toString();
      });
    } catch (_) {
      if (mounted) setState(() => error = 'Could not load this recipe.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> showNutrients(Map<String, dynamic> selected) async {
    try {
      final r = await client
          .get(Uri.base.resolve('/api/foods/${selected['id']}'))
          .timeout(const Duration(seconds: 12));
      final j = jsonDecode(r.body) as Map<String, dynamic>,
          f = j['food'] as Map,
          labels = j['nutrientLabels'] as Map;
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Nutrients per 100 g'),
          content: SizedBox(
            width: 500,
            height: 430,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    f['name'] as String,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  gap(),
                  if (f['nutrients'] is Map)
                    ...(f['nutrients'] as Map).entries.map((entry) {
                      final label = labels[entry.key] as Map?;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                label?['name'] as String? ??
                                    entry.key.toString(),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '${entry.value} ${label?['unit'] ?? ''}',
                              style: const TextStyle(fontSize: 12, color: lime),
                            ),
                          ],
                        ),
                      );
                    })
                  else
                    const Text(
                      'Full nutrient details are still importing. Macronutrients are available.',
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (mounted) toast(context, 'Nutrient details could not load.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = totals();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Know your portions.',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              IconButton(
                tooltip: 'Close food calculator',
                onPressed: busy ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          tag('FREE · FOOD & RECIPE DATABASE'),
          gap(12),
          const Text(
            'Choose the food and its weight or a reference serving. The app calculates nutrition for you.',
            style: TextStyle(color: muted),
          ),
          if (widget.suggestions.isNotEmpty) ...[
            gap(12),
            small(
              'Photo suggestions are not confirmed identifications. Select or search for what you actually ate.',
            ),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: widget.suggestions
                  .map(
                    (s) => ActionChip(
                      label: Text(s),
                      onPressed: () {
                        search.text = s;
                        findFoods(s);
                      },
                    ),
                  )
                  .toList(),
            ),
          ],
          if (widget.notes.trim().isNotEmpty) ...[
            gap(10),
            Text(
              'Your notes: ${widget.notes}',
              style: const TextStyle(color: orange, fontSize: 12),
            ),
            small('Add the ingredients and quantities from these notes below.'),
          ],
          if (recipes.isNotEmpty) ...[
            gap(16),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('My saved recipes'),
              children: recipes
                  .take(20)
                  .map(
                    (r) => ListTile(
                      title: Text(r['name'] as String),
                      subtitle: Text(
                        '${r['calories']} kcal · ${r['protein']} g protein / serving',
                      ),
                      onTap: busy ? null : () => useRecipe(r),
                    ),
                  )
                  .toList(),
            ),
          ],
          gap(16),
          TextField(
            controller: name,
            enabled: !busy,
            maxLength: 100,
            decoration: const InputDecoration(labelText: 'Meal or recipe name'),
          ),
          gap(10),
          ...ingredients.asMap().entries.map((entry) {
            final i = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: box(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            i.food['name'] as String,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove ingredient',
                          onPressed: busy
                              ? null
                              : () => setState(() {
                                  ingredients.remove(i);
                                  i.grams.dispose();
                                }),
                          icon: const Icon(Icons.close, size: 18),
                        ),
                      ],
                    ),
                    gap(12),
                    TextField(
                      controller: i.grams,
                      enabled: !busy,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Edible portion · grams',
                      ),
                    ),
                    if ((i.food['portions'] as List?)?.isNotEmpty ?? false)
                      DropdownButtonFormField<int>(
                        key: ValueKey(i),
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Or choose a USDA reference serving',
                        ),
                        items: (i.food['portions'] as List)
                            .asMap()
                            .entries
                            .map(
                              (p) => DropdownMenuItem<int>(
                                value: p.key,
                                child: Text(
                                  '${p.value['label']} · ${p.value['grams']} g',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: busy
                            ? null
                            : (v) => setState(
                                () => i.grams.text =
                                    (i.food['portions'] as List)[v!]['grams']
                                        .toString(),
                              ),
                      ),
                    TextButton(
                      onPressed: () => showNutrients(i.food),
                      child: const Text('View full nutrients per 100 g'),
                    ),
                  ],
                ),
              ),
            );
          }),
          gap(10),
          TextField(
            controller: search,
            enabled: !busy,
            onChanged: (value) {
              debounce?.cancel();
              debounce = Timer(
                const Duration(milliseconds: 350),
                () => findFoods(value),
              );
            },
            decoration: InputDecoration(
              labelText: 'Find an ingredient',
              hintText: 'e.g. banana, cooked rice, chicken, milk',
              suffixIcon: IconButton(
                tooltip: 'Search foods',
                onPressed: () => findFoods(search.text),
                icon: const Icon(Icons.search),
              ),
            ),
          ),
          if (loading) ...[gap(12), const LinearProgressIndicator()],
          if (!loading &&
              search.text.trim().length >= 2 &&
              results.isEmpty) ...[
            gap(8),
            small(
              'No matching result yet. Try a simpler food name or use Gemini for a mixed dish.',
            ),
          ],
          ...results
              .take(12)
              .map(
                (f) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    f['name'] as String,
                    style: const TextStyle(fontSize: 13),
                  ),
                  subtitle: Text(
                    '${f['calories']} kcal · ${f['protein']} g protein per 100 g',
                    style: const TextStyle(fontSize: 11, color: muted),
                  ),
                  trailing: const Icon(Icons.add_circle_outline, color: lime),
                  onTap: busy ? null : () => add(f),
                ),
              ),
          gap(18),
          TextField(
            controller: servings,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Servings in this whole recipe',
            ),
          ),
          gap(14),
          box(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                small('PER SERVING'),
                gap(8),
                Text(
                  '${t['calories']!.round()} kcal  ·  ${t['protein']!.toStringAsFixed(1)} g protein',
                  style: const TextStyle(
                    color: lime,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                small(
                  '${t['carbs']!.toStringAsFixed(1)} g carbs · ${t['fat']!.toStringAsFixed(1)} g fat',
                ),
              ],
            ),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: saveRecipe,
            onChanged: busy ? null : (v) => setState(() => saveRecipe = v!),
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              widget.store?.guestMode == true
                  ? 'Save this recipe on this device'
                  : 'Save this recipe to my account',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          if (error.isNotEmpty) ...[
            Text(error, style: const TextStyle(color: orange)),
            gap(12),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: busy ? null : complete,
              icon: const Icon(Icons.check),
              label: Text(busy ? 'Saving…' : 'Use these nutrition values'),
            ),
          ),
          gap(16),
          small(
            'Reference values vary by preparation and brand. Weigh edible food and match raw or cooked foods carefully. This calculates one serving; it does not add a meal until you confirm it in the meal editor.',
          ),
          gap(16),
        ],
      ),
    );
  }
}
