import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'models.dart';
import 'main.dart'
    show lime, orange, muted, box, gap, small, tag, heading, toast;

class GuideFood {
  final Map<String, dynamic> data;
  const GuideFood(this.data);
  String get id => data['id'] as String;
  String get name => data['name'] as String;
  String get portion => data['portion'] as String;
  double number(String key) => (data[key] as num).toDouble();
  double? get low => (data['priceLow'] as num?)?.toDouble();
  double? get high => (data['priceHigh'] as num?)?.toDouble();
  bool get meal => data.containsKey('parts');
  String price([double scale = 1]) {
    if (low == null || high == null) return 'Check local price';
    final a = (low! * scale).round(), b = (high! * scale).round();
    return a == b ? '≈ Rs $a' : '≈ Rs $a–$b';
  }

  String get proteinCost {
    if (number('protein') <= 0) return 'No protein · calorie add-on';
    if (low == null || high == null) return 'Protein value needs a local price';
    final a = (low! * 10 / number('protein')).round(),
        b = (high! * 10 / number('protein')).round();
    return a == b ? '≈ Rs $a per 10 g protein' : '≈ Rs $a–$b per 10 g protein';
  }

  Map<String, dynamic> estimate(double scale) => {
    'is_food': true,
    'needsClarification': false,
    'name': scale == 1 ? name : '$scale × $name',
    'items': [
      {'name': name},
    ],
    for (final macro in ['calories', 'protein', 'carbs', 'fat'])
      macro: (number(macro) * scale * 10).round() / 10,
    'portion': '$scale × $portion',
    'assumptions': data['notes'],
    'source': 'USDA food-guide serving estimate',
  };
}

class FoodGuideData {
  final Map<String, dynamic> data;
  final List<GuideFood> items;
  FoodGuideData(this.data)
    : items = [
        for (final f in [...data['foods'] as List, ...data['recipes'] as List])
          GuideFood(Map<String, dynamic>.from(f as Map)),
      ];
  static Future<FoodGuideData> load() async => FoodGuideData(
    jsonDecode(await rootBundle.loadString('assets/food-guide.json'))
        as Map<String, dynamic>,
  );
  List<GuideFood> select({
    String category = 'Protein picks',
    String group = 'All sources',
    String query = '',
    String sort = 'Protein value',
    double? budget,
  }) {
    final result = items
        .where(
          (f) =>
              (category == 'All foods' ||
                  (category == 'Meal ideas'
                      ? f.meal
                      : !f.meal &&
                            f.data[category == 'Protein picks'
                                    ? 'proteinPick'
                                    : 'caloriePick'] ==
                                true)) &&
              (group == 'All sources' || f.data['group'] == group) &&
              (budget == null || (f.high != null && f.high! <= budget)) &&
              '${f.name} ${f.portion} ${f.data['notes']}'
                  .toLowerCase()
                  .contains(query.trim().toLowerCase()),
        )
        .toList();
    double score(GuideFood f) => switch (sort) {
      'Lowest cost' => f.high ?? double.infinity,
      'Most protein' => -f.number('protein'),
      'Most calories' => -f.number('calories'),
      'Protein per calorie' =>
        f.number('calories') > 0
            ? -f.number('protein') / f.number('calories')
            : 0,
      _ =>
        f.number('protein') > 0 && f.high != null
            ? f.high! / f.number('protein')
            : double.infinity,
    };
    result.sort((a, b) {
      final c = score(a).compareTo(score(b));
      return c == 0 ? a.name.compareTo(b.name) : c;
    });
    return result;
  }
}

class FoodGuideScreen extends StatefulWidget {
  final AppStore store;
  final DateTime date;
  final FoodGuideData? guide;
  const FoodGuideScreen({
    super.key,
    required this.store,
    required this.date,
    this.guide,
  });
  @override
  State<FoodGuideScreen> createState() => _FoodGuideScreenState();
}

class _FoodGuideScreenState extends State<FoodGuideScreen> {
  late Future<FoodGuideData> future;
  String category = 'Protein picks',
      group = 'All sources',
      sort = 'Protein value',
      query = '';
  double? budget;
  @override
  void initState() {
    super.initState();
    future = widget.guide != null
        ? Future.value(widget.guide)
        : FoodGuideData.load();
  }

  Future<void> review(GuideFood food) async {
    FocusScope.of(context).unfocus();
    var scale = 1.0;
    var confirmed = false;
    final accepted = await showDialog<double>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, change) => AlertDialog(
          title: Text(food.name),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(food.portion),
                gap(12),
                DropdownButtonFormField<double>(
                  initialValue: scale,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Servings'),
                  items: [
                    for (final n in [.5, 1.0, 1.5, 2.0])
                      DropdownMenuItem(
                        value: n,
                        child: Text('$n × listed serving'),
                      ),
                  ],
                  onChanged: (n) => change(() => scale = n!),
                ),
                gap(14),
                Text(
                  '≈ ${(food.number('calories') * scale).round()} kcal · ${(food.number('protein') * scale).toStringAsFixed(1)} g protein',
                  style: const TextStyle(
                    color: lime,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                gap(8),
                small(
                  '${(food.number('carbs') * scale).toStringAsFixed(1)} g carbs · ${(food.number('fat') * scale).toStringAsFixed(1)} g fat',
                ),
                gap(12),
                Text(food.data['notes'] as String),
                gap(12),
                small(
                  'Logging to ${prettyDay(widget.date)}. Choose this only if you ate the stated food and portion.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (confirmed) return;
                confirmed = true;
                Navigator.pop(ctx, scale);
              },
              child: const Text('Yes, log this serving'),
            ),
          ],
        ),
      ),
    );
    if (accepted == null) return;
    await widget.store.confirmMealEstimate(
      widget.date,
      food.estimate(accepted),
    );
    if (mounted) toast(context, 'Added to your meal journal.');
  }

  Widget picker(
    String label,
    String value,
    List<String> values,
    void Function(String) onChange,
  ) => DropdownButtonFormField<String>(
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: [
      for (final v in values)
        DropdownMenuItem(
          value: v,
          child: Text(v, overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: (v) => onChange(v!),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Food guide')),
    body: FutureBuilder<FoodGuideData>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('The food guide could not load.'),
                  TextButton(
                    onPressed: () =>
                        setState(() => future = FoodGuideData.load()),
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final guide = snapshot.data!;
        return AnimatedBuilder(
          animation: widget.store,
          builder: (context, _) => LayoutBuilder(
            builder: (context, bounds) {
              final width = math.min(bounds.maxWidth - 40, 1120.0),
                  cardWidth = width >= 850 ? (width - 16) / 2 : width;
              final foods = guide.select(
                category: category,
                group: group,
                query: query,
                sort: sort,
                budget: budget,
              );
              final p = widget.store.profile,
                  pro = p == null
                      ? null
                      : math.max(
                          0,
                          p.protein -
                              widget.store.total(widget.date, 'protein'),
                        ),
                  cal = p == null
                      ? null
                      : math.max(
                          0,
                          p.calories -
                              widget.store.total(widget.date, 'calories'),
                        );
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
                child: Center(
                  child: SizedBox(
                    width: width,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        tag('EAT WELL. SPEND WISELY.'),
                        gap(14),
                        Text(
                          'Fuel that fits\nyour goals.',
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                        gap(10),
                        const Text(
                          'Compare everyday Pakistani foods by protein, energy and ingredient cost. Photos show examples or meal ingredients; use the stated portion for nutrition.',
                          style: TextStyle(color: muted),
                        ),
                        gap(20),
                        if (p != null)
                          box(
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                small(prettyDay(widget.date)),
                                gap(8),
                                Text(
                                  '${pro!.round()} g protein · ${cal!.round()} kcal remaining',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: lime,
                                  ),
                                ),
                                gap(8),
                                small(
                                  cal <= 0 && pro <= 0
                                      ? 'Both targets are reached. Use these ideas to plan another day; no extra meal is required.'
                                      : cal <= 0
                                      ? 'Your calorie target is reached. Extra calories are not required; consider protein-rich choices within your overall plan.'
                                      : pro <= 0
                                      ? 'Your protein target is reached. Calorie boosters are options if you also need more energy.'
                                      : 'Protein foods help close a protein gap. Add carbohydrate or fat portions when you also need more energy. These are options, not extra targets.',
                                ),
                              ],
                            ),
                          ),
                        gap(18),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final c in [
                              'Protein picks',
                              'Calorie boosters',
                              'Meal ideas',
                              'All foods',
                            ])
                              ChoiceChip(
                                label: Text(c),
                                selected: category == c,
                                onSelected: (_) => setState(() => category = c),
                              ),
                          ],
                        ),
                        gap(18),
                        TextField(
                          decoration: const InputDecoration(
                            labelText: 'Search foods or meals',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (s) => setState(() => query = s),
                        ),
                        gap(18),
                        Wrap(
                          spacing: 14,
                          runSpacing: 18,
                          children: [
                            SizedBox(
                              width: width >= 600 ? (width - 28) / 3 : width,
                              child: picker('Sort by', sort, [
                                'Protein value',
                                'Lowest cost',
                                'Most protein',
                                'Most calories',
                                'Protein per calorie',
                              ], (v) => setState(() => sort = v)),
                            ),
                            SizedBox(
                              width: width >= 600 ? (width - 28) / 3 : width,
                              child: picker(
                                'Food sources',
                                group,
                                [
                                  'All sources',
                                  'Plant sources',
                                  'Meat & eggs',
                                  'Dairy',
                                ],
                                (v) => setState(() => group = v),
                              ),
                            ),
                            SizedBox(
                              width: width >= 600 ? (width - 28) / 3 : width,
                              child: DropdownButtonFormField<int>(
                                initialValue: budget?.toInt() ?? 0,
                                decoration: const InputDecoration(
                                  labelText: 'Budget per listed serving',
                                ),
                                items: [
                                  for (final n in [0, 50, 100, 200])
                                    DropdownMenuItem(
                                      value: n,
                                      child: Text(
                                        n == 0 ? 'Any budget' : 'Up to Rs $n',
                                      ),
                                    ),
                                ],
                                onChanged: (n) => setState(
                                  () => budget = n == 0 ? null : n!.toDouble(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        gap(14),
                        small(
                          'Prices checked 28 Oct 2026 · PKR estimates, not live quotes. PBS snapshot: 22 Oct 2026. Retail prices, city, brand and portion yield vary.',
                        ),
                        gap(6),
                        small(
                          'Budget filters use the upper estimate. Costs are for home ingredients in the listed portion, not a whole pack, restaurant meal or delivery.',
                        ),
                        gap(20),
                        if (foods.isEmpty)
                          box(
                            const Text(
                              'No matches at this budget. Try a different source, budget or search.',
                            ),
                          ),
                        Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            for (final food in foods)
                              SizedBox(
                                width: cardWidth,
                                child: foodCard(food, guide),
                              ),
                          ],
                        ),
                        heading('Choose for the nutrient you need'),
                        box(
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'For protein',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: lime,
                                ),
                              ),
                              Text(
                                'Eggs, skinless chicken, pulses, milk and plain dahi can help. Compare the amount you will actually eat.',
                              ),
                              SizedBox(height: 14),
                              Text(
                                'For more energy',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: orange,
                                ),
                              ),
                              Text(
                                'Rice, roti, oats, milk and measured portions of nuts can help when calories are still needed. Nuts provide protein plus substantial fat and energy.',
                              ),
                              SizedBox(height: 14),
                              Text(
                                'Easy mix-ups',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              Text(
                                'Oil, ghee, sugar and sweet drinks are not useful protein sources. More calories alone do not mean more protein. Dry and cooked weights are different; frying and sauces change the estimate.',
                              ),
                              SizedBox(height: 14),
                              Text(
                                'Keep meals varied',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              Text(
                                'Include vegetables, fruit and fibre too. These examples are meal building blocks, not a complete diet or a list of forbidden foods.',
                              ),
                            ],
                          ),
                        ),
                        gap(16),
                        TextButton.icon(
                          onPressed: () => launchUrl(
                            Uri.parse(
                              'https://www.nhs.uk/Live-well/eat-well/how-to-eat-a-balanced-diet/eating-a-balanced-diet/',
                            ),
                            mode: LaunchMode.externalApplication,
                          ),
                          icon: const Icon(Icons.open_in_new, size: 16),
                          label: const Text('Balanced eating guidance · NHS'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    ),
  );
  Widget pictures(GuideFood food) {
    final photos = (food.data['images'] as List? ?? []).cast<Map>();
    if (photos.isEmpty) return const SizedBox.shrink();
    Widget photo(Map image) => Image.asset(
      image['asset'] as String,
      fit: BoxFit.cover,
      semanticLabel: 'Example photo: ${image['label'] ?? image['title']}',
      errorBuilder: (_, error, stack) => const ColoredBox(
        color: Color(0xFF30362C),
        child: Center(child: Icon(Icons.restaurant_outlined, color: muted)),
      ),
    );
    Widget row(List<Map> images) => Row(
      children: [
        for (final image in images)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(1),
              child: SizedBox.expand(child: photo(image)),
            ),
          ),
      ],
    );
    final tiles = photos.take(4).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: tiles.length == 1
              ? photo(tiles.first)
              : tiles.length == 2
              ? row(tiles)
              : Column(
                  children: [
                    Expanded(child: row(tiles.take(2).toList())),
                    Expanded(child: row(tiles.skip(2).toList())),
                  ],
                ),
        ),
      ),
    );
  }

  Widget foodCard(GuideFood food, FoodGuideData guide) => box(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        pictures(food),
        if ((food.data['images'] as List? ?? []).isNotEmpty) ...[
          small(
            food.meal
                ? 'Ingredient photos · example only'
                : 'Example photo · use the portion below',
          ),
          for (final image in food.data['images'] as List? ?? [])
            if (image['displayNote'] != null)
              small(image['displayNote'] as String),
          gap(12),
        ],
        Row(
          children: [
            Icon(
              food.meal
                  ? Icons.ramen_dining
                  : food.data['group'] == 'Dairy'
                  ? Icons.local_drink_outlined
                  : food.data['group'] == 'Meat & eggs'
                  ? Icons.egg_outlined
                  : Icons.eco_outlined,
              color: lime,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                food.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
            ),
          ],
        ),
        gap(10),
        Text(food.portion, style: const TextStyle(color: muted)),
        gap(16),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            tag('${food.number('protein').toStringAsFixed(1)} g protein'),
            tag('${food.number('calories').round()} kcal', color: orange),
          ],
        ),
        gap(16),
        Text(
          '${food.price()} / listed serving',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        gap(4),
        small(food.proteinCost),
        gap(10),
        Text(
          food.data['notes'] as String,
          style: const TextStyle(fontSize: 13, color: muted),
        ),
        if ((food.data['allergens'] as List).isNotEmpty) ...[
          gap(8),
          small('Contains: ${(food.data['allergens'] as List).join(', ')}'),
        ],
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text(
            'Sources & photo credits',
            style: TextStyle(fontSize: 13),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: small(food.data['priceBasis'] as String),
            ),
            for (final image in food.data['images'] as List? ?? []) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: small(
                  '${image['title']} · ${image['author']} · ${image['license']}',
                ),
              ),
              if (image['changes'] != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: small(image['changes'] as String),
                ),
              Wrap(
                children: [
                  if (image['authorUrl'] != null)
                    TextButton(
                      onPressed: () => launchUrl(
                        Uri.parse(image['authorUrl'] as String),
                        mode: LaunchMode.externalApplication,
                      ),
                      child: Text(image['author'] as String),
                    ),
                  TextButton(
                    onPressed: () => launchUrl(
                      Uri.parse(image['sourceUrl'] as String),
                      mode: LaunchMode.externalApplication,
                    ),
                    child: const Text('Photo source'),
                  ),
                  TextButton(
                    onPressed: () => launchUrl(
                      Uri.parse(image['licenseUrl'] as String),
                      mode: LaunchMode.externalApplication,
                    ),
                    child: Text(image['license'] as String),
                  ),
                ],
              ),
            ],
            for (final source in (guide.data['sources'] as List).where(
              (s) => (food.data['sourceIds'] as List).contains(s['id']),
            ))
              TextButton(
                onPressed: () => launchUrl(
                  Uri.parse(source['url'] as String),
                  mode: LaunchMode.externalApplication,
                ),
                child: Text(source['title'] as String),
              ),
            TextButton(
              onPressed: () => launchUrl(
                Uri.parse('https://fdc.nal.usda.gov/download-datasets/'),
                mode: LaunchMode.externalApplication,
              ),
              child: const Text('Nutrition reference · USDA'),
            ),
          ],
        ),
        FilledButton.icon(
          onPressed: () => review(food),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Review & log'),
        ),
      ],
    ),
  );
}
