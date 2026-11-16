import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'models.dart';
import 'meal_editor.dart';
import 'workout_screen.dart';
import 'settings.dart';
import 'profile_screen.dart';
import 'quick_meal.dart';
import 'habits_screen.dart';
import 'rank_card.dart';
import 'food_guide.dart';
import 'body_status.dart';
import 'check_in.dart';
import 'personal_records.dart';

const lime = Color(0xFFD4FB60),
    ink = Color(0xFF10130F),
    panel = Color(0xFF1B1F1A),
    muted = Color(0xFF9AA294),
    line = Color(0xFF30362C),
    orange = Color(0xFFFFB67A);
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = AppStore(await SharedPreferences.getInstance());
  await store.load();
  if (kIsWeb) {
    final pairing = Uri.splitQueryString(Uri.base.fragment)['pair'];
    if (pairing != null && pairing.length >= 16) {
      await store.saveConnection('', pairing);
    }
    if (!store.guestMode &&
        (store.cloudEnabled ||
            ['localhost', '127.0.0.1', '::1'].contains(Uri.base.host))) {
      try {
        final response = await http
            .post(Uri.base.resolve('/api/local-pair'))
            .timeout(const Duration(seconds: 3));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          await store.saveConnection('', data['token'] as String);
        }
      } catch (_) {
        /* Previously saved pairing still works when offline. */
      }
    }
  }
  runApp(ForgeApp(store: store));
}

class ForgeApp extends StatelessWidget {
  final AppStore store;
  const ForgeApp({super.key, required this.store});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'FORGE · Build your everyday',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: ink,
      colorScheme: const ColorScheme.dark(
        primary: lime,
        secondary: orange,
        surface: panel,
        onPrimary: ink,
      ),
      fontFamily: 'ForgeSans',
      appBarTheme: const AppBarTheme(
        backgroundColor: ink,
        scrolledUnderElevation: 0,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 38,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.7,
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          letterSpacing: -1,
        ),
        titleLarge: TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w700,
          letterSpacing: -.5,
        ),
        bodyMedium: TextStyle(fontSize: 14, height: 1.5),
        bodySmall: TextStyle(color: muted, height: 1.45),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ink,
        contentPadding: const EdgeInsets.all(16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: line),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: lime,
          foregroundColor: ink,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 19),
          textStyle: const TextStyle(
            fontFamily: 'ForgeSans',
            fontWeight: FontWeight.w800,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    ),
    home: AnimatedBuilder(
      animation: store,
      builder: (context, _) => store.cloudEnabled && store.cloudAuthRequired
          ? AccessChoice(store: store)
          : store.profile == null
          ? ProfileScreen(store: store)
          : HomeScreen(store: store),
    ),
  );
}

class AccessChoice extends StatelessWidget {
  final AppStore store;
  const AccessChoice({super.key, required this.store});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.bolt_rounded, color: lime, size: 48),
                gap(24),
                Text(
                  'Start your way.',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                gap(14),
                const Text(
                  'Training, meals, water, habits and ranks. You can start without an account.',
                ),
                gap(24),
                FilledButton.icon(
                  onPressed: store.continueAsGuest,
                  icon: const Icon(Icons.person_outline),
                  label: const Text('Continue without signing in'),
                ),
                gap(12),
                OutlinedButton.icon(
                  onPressed: () => launchUrl(
                    Uri.base.resolve(
                      '/signin-with-chatgpt?return_to=%2Ffitness%2F%3Fmode%3Daccount',
                    ),
                    webOnlyWindowName: '_self',
                  ),
                  icon: const Icon(Icons.cloud_outlined),
                  label: const Text('Sign in for cloud sync'),
                ),
                gap(20),
                small(
                  'Guest progress stays in this browser or installed app. Signed-in accounts use separate private cloud records. Export a backup before clearing browser data. Broader Gemini/Groq estimates require sign-in; free references and the on-device photo matcher remain available.',
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Text small(String text, {Color? color}) => Text(
  text,
  style: TextStyle(color: color ?? muted, fontSize: 12, letterSpacing: .3),
);
Widget gap([double n = 16]) => SizedBox(height: n);
Widget tag(String text, {Color color = lime}) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
  decoration: BoxDecoration(
    color: color.withValues(alpha: .10),
    borderRadius: BorderRadius.circular(30),
  ),
  child: Text(
    text,
    style: TextStyle(
      color: color,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: .5,
    ),
  ),
);
Widget box(
  Widget child, {
  Color color = panel,
  EdgeInsets padding = const EdgeInsets.all(22),
}) => Container(
  padding: padding,
  decoration: BoxDecoration(
    color: color,
    border: Border.all(color: line),
    borderRadius: BorderRadius.circular(23),
  ),
  child: child,
);
Widget heading(String title, {Widget? action, String? subtitle}) => Padding(
  padding: const EdgeInsets.only(top: 28, bottom: 16),
  child: Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w700,
                letterSpacing: -.6,
              ),
            ),
            if (subtitle != null) small(subtitle),
          ],
        ),
      ),
      ?action,
    ],
  ),
);
void toast(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
Future<void> showSheet(BuildContext context, Widget child) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: panel,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .92,
            maxWidth: 620,
          ),
          child: child,
        ),
      ),
    );

class HomeScreen extends StatefulWidget {
  final AppStore store;
  const HomeScreen({super.key, required this.store});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int tab = 0;
  DateTime date = calendarDay(DateTime.now()),
      lastToday = calendarDay(DateTime.now());
  late Timer clock;
  AppStore get s => widget.store;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    clock = Timer.periodic(const Duration(seconds: 30), (_) => refreshDay());
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => recoverPhoto(context, s, date),
    );
  }

  void refreshDay() {
    if (s.cloudEnabled) s.syncCloud();
    final next = calendarDay(DateTime.now());
    if (dayKey(next) != dayKey(lastToday)) {
      if (dayKey(date) == dayKey(lastToday)) date = next;
      lastToday = next;
      setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refreshDay();
  }

  @override
  void dispose() {
    clock.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void addMeal() => showSheet(context, QuickMealEntry(store: s, date: date));
  void openFoodGuide() => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => FoodGuideScreen(store: s, date: date),
    ),
  );
  void openWorkout() => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => WorkoutScreen(store: s, date: date),
    ),
  );
  Widget nav(bool wide) => wide
      ? NavigationRail(
          backgroundColor: ink,
          extended: true,
          minExtendedWidth: 216,
          selectedIndex: tab,
          onDestinationSelected: (i) => setState(() => tab = i),
          leading: Padding(
            padding: const EdgeInsets.fromLTRB(12, 22, 12, 35),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt_rounded, color: lime, size: 32),
                const SizedBox(width: 6),
                const Text(
                  'FORGE',
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                  ),
                ),
              ],
            ),
          ),
          selectedIconTheme: const IconThemeData(color: ink),
          indicatorColor: lime,
          destinations: const [
            NavigationRailDestination(
              icon: Icon(Icons.grid_view_rounded),
              label: Text('Overview'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.restaurant_rounded),
              label: Text('Nutrition'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.fitness_center_rounded),
              label: Text('Training'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.auto_awesome_rounded),
              label: Text('Habits'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.insights_rounded),
              label: Text('Progress'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.tune_rounded),
              label: Text('Settings'),
            ),
          ],
        )
      : NavigationBar(
          backgroundColor: panel,
          indicatorColor: lime,
          selectedIndex: tab,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (i) => setState(() => tab = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.grid_view_rounded),
              label: 'Today',
            ),
            NavigationDestination(
              icon: Icon(Icons.restaurant_rounded),
              label: 'Food',
            ),
            NavigationDestination(
              icon: Icon(Icons.fitness_center_rounded),
              label: 'Train',
            ),
            NavigationDestination(
              icon: Icon(Icons.auto_awesome_rounded),
              label: 'Habits',
            ),
            NavigationDestination(
              icon: Icon(Icons.insights_rounded),
              label: 'Progress',
            ),
            NavigationDestination(
              icon: Icon(Icons.tune_rounded),
              label: 'Settings',
            ),
          ],
        );
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 1000;
      return Scaffold(
        floatingActionButton: !wide && tab < 2
            ? FloatingActionButton.extended(
                onPressed: addMeal,
                backgroundColor: lime,
                foregroundColor: ink,
                icon: const Icon(Icons.add_a_photo_outlined),
                label: const Text('Log meal'),
              )
            : null,
        bottomNavigationBar: wide ? null : nav(false),
        body: SafeArea(
          child: Row(
            children: [
              if (wide) nav(true),
              if (wide) const VerticalDivider(width: 1, color: line),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: wide ? 38 : 22,
                    vertical: 24,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1180),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (!wide) ...[
                                const Icon(Icons.bolt_rounded, color: lime),
                                const Text(
                                  'FORGE',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2,
                                  ),
                                ),
                                const Spacer(),
                              ],
                              if (wide) small('YOUR EVERYDAY. UPGRADED.'),
                              if (wide) const Spacer(),
                              tag(
                                s.cloudEnabled
                                    ? s.syncStatus.toUpperCase()
                                    : s.guestMode
                                    ? 'GUEST · THIS DEVICE'
                                    : 'LOCAL FIRST',
                                color: muted,
                              ),
                              const SizedBox(width: 12),
                              CircleAvatar(
                                backgroundColor: lime,
                                foregroundColor: ink,
                                child: Text(
                                  s.profile!.name.substring(0, 1).toUpperCase(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          gap(18),
                          RankHeader(store: s),
                          if (s.guestMode) ...[
                            gap(10),
                            small(
                              'Guest progress is saved on this device. Export a backup in Settings; sign in to use a separate cloud profile.',
                            ),
                          ],
                          gap(28),
                          if (s.storageError)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: box(
                                const Text(
                                  'Storage needs attention. Export a backup from Settings; changes may not survive a restart.',
                                  style: TextStyle(color: orange),
                                ),
                              ),
                            ),
                          if (tab != 5) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      small(
                                        tab == 0
                                            ? 'LET’S GET AFTER IT'
                                            : tab == 1
                                            ? 'FUEL YOUR POTENTIAL'
                                            : tab == 2
                                            ? 'SHOW UP. GET STRONGER.'
                                            : tab == 3
                                            ? 'SMALL WINS. EVERY DAY.'
                                            : 'EVERY REP ADDS UP',
                                      ),
                                      gap(5),
                                      Text(
                                        tab == 0
                                            ? 'Hey, ${s.profile!.name}.'
                                            : tab == 1
                                            ? 'Your daily fuel.'
                                            : tab == 2
                                            ? 'Built by consistency.'
                                            : tab == 3
                                            ? 'Your everyday, upgraded.'
                                            : 'The bigger picture.',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.headlineLarge,
                                      ),
                                    ],
                                  ),
                                ),
                                if (wide && tab < 2)
                                  FilledButton.icon(
                                    onPressed: addMeal,
                                    icon: const Icon(
                                      Icons.add_a_photo_outlined,
                                      size: 20,
                                    ),
                                    label: const Text('Log a meal'),
                                  ),
                              ],
                            ),
                            gap(20),
                            dateSelector(),
                            gap(20),
                          ],
                          switch (tab) {
                            0 => overview(),
                            1 => nutrition(),
                            2 => training(),
                            3 => HabitsView(store: s, date: date),
                            4 => progress(),
                            _ => SettingsView(store: s),
                          },
                          gap(32),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  Widget dateSelector() => Row(
    children: [
      IconButton(
        tooltip: 'Previous day',
        onPressed: () =>
            setState(() => date = date.subtract(const Duration(days: 1))),
        icon: const Icon(Icons.chevron_left),
      ),
      Expanded(
        child: TextButton.icon(
          onPressed: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: date,
              firstDate: DateTime(2020),
              lastDate: calendarDay(DateTime.now()),
            );
            if (d != null) setState(() => date = d);
          },
          icon: const Icon(
            Icons.calendar_today_outlined,
            size: 15,
            color: muted,
          ),
          label: Text(
            dayKey(date) == dayKey(DateTime.now())
                ? 'Today · ${date.day} ${months[date.month - 1]}'
                : prettyDay(date),
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
      IconButton(
        tooltip: 'Next day',
        onPressed: date.isBefore(calendarDay(DateTime.now()))
            ? () => setState(() => date = date.add(const Duration(days: 1)))
            : null,
        icon: const Icon(Icons.chevron_right),
      ),
      if (dayKey(date) != dayKey(DateTime.now()))
        TextButton(
          onPressed: () => setState(() => date = calendarDay(DateTime.now())),
          child: const Text('Today'),
        ),
    ],
  );
  Widget overview() {
    final w = s.workoutOn(date);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, c) {
            final hero = Container(
              width: double.infinity,
              height: 280,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: lime,
                borderRadius: BorderRadius.circular(26),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -30,
                    bottom: -55,
                    child: Transform.rotate(
                      angle: -.15,
                      child: const Icon(
                        Icons.fitness_center_rounded,
                        size: 290,
                        color: Color(0xFFB2D547),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(27),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        tag('THE WORK IS WORTH IT', color: ink),
                        gap(18),
                        const FittedBox(
                          alignment: Alignment.centerLeft,
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Build strength.\nFuel the change.',
                            style: TextStyle(
                              color: ink,
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              height: 1.04,
                              letterSpacing: -1.3,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${s.profile!.days} days a week. One stronger you.',
                          style: const TextStyle(
                            color: ink,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        gap(12),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: ink,
                            foregroundColor: lime,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                          ),
                          onPressed: () => setState(() => tab = 2),
                          icon: const Icon(Icons.arrow_forward, size: 17),
                          label: const Text('Your training plan'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
            final fuel = nutritionSummary();
            if (c.maxWidth > 800) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: hero),
                  const SizedBox(width: 18),
                  Expanded(flex: 6, child: fuel),
                ],
              );
            }
            return Column(children: [fuel, gap(), hero]);
          },
        ),
        gap(18),
        BodyStatusCard(
          profile: s.profile!,
          compact: true,
          onOpen: () => setState(() => tab = 5),
        ),
        gap(18),
        DailyCheckInCard(store: s, date: date),
        heading(
          'On the menu today',
          action: TextButton(
            onPressed: () => setState(() => tab = 1),
            child: const Text('View nutrition →'),
          ),
        ),
        box(
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: lime.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.add_a_photo_outlined, color: lime),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Say it. Check it. Log it.',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '“I ate 3 boiled eggs.” We’ll do the calculation.',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Log a meal',
                onPressed: addMeal,
                icon: const Icon(Icons.arrow_forward, color: lime),
              ),
            ],
          ),
        ),
        if (s.mealsFor(date).isNotEmpty) ...[
          gap(12),
          ...s.mealsFor(date).take(2).map(mealTile),
        ],
        heading(
          'Your next move',
          subtitle: w.rest
              ? 'Recovery is part of the plan.'
              : '${w.exercises.length} exercises · ${s.profile!.equipment}',
        ),
        attendanceCard(),
        gap(),
        box(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  tag(w.rest ? 'RECOVER' : 'TRAIN', color: orange),
                  const Spacer(),
                  small(weekdays[date.weekday - 1].toUpperCase()),
                ],
              ),
              gap(15),
              Text(w.name, style: Theme.of(context).textTheme.headlineMedium),
              gap(4),
              Text(w.focus, style: const TextStyle(color: muted)),
              gap(22),
              Wrap(
                spacing: 20,
                runSpacing: 15,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  small(
                    w.rest
                        ? '20–30 min easy walk'
                        : '35–55 min · ${w.sets} sets / exercise',
                  ),
                  FilledButton(
                    onPressed: openWorkout,
                    child: Text(w.rest ? 'Recovery guide' : 'Open workout'),
                  ),
                ],
              ),
            ],
          ),
        ),
        heading('Small habits. Big returns.'),
        box(
          Row(
            children: [
              const Icon(Icons.local_fire_department_outlined, color: orange),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${s.streak(DateTime.now())} day streak · ${s.totalXp} XP',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => tab = 3),
                child: const Text('Your quests →'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget nutritionSummary() {
    final p = s.profile!;
    final cal = s.total(date, 'calories'), pro = s.total(date, 'protein');
    return box(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'DAILY FUEL',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
              tag('YOUR TARGETS'),
            ],
          ),
          gap(22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              MacroRing(
                value: cal,
                target: p.calories.toDouble(),
                label: 'CALORIES',
                unit: 'kcal',
                color: lime,
              ),
              MacroRing(
                value: pro,
                target: p.protein.toDouble(),
                label: 'PROTEIN',
                unit: 'g',
                color: orange,
              ),
            ],
          ),
          gap(19),
          Center(
            child: small(
              cal >= p.calories && pro >= p.protein
                  ? 'Both targets reached. Nice work.'
                  : '${math.max(0, p.calories - cal).round()} kcal  ·  ${math.max(0, p.protein - pro).round()} g protein remaining',
            ),
          ),
          gap(10),
          Center(
            child: TextButton.icon(
              onPressed: openFoodGuide,
              icon: const Icon(Icons.menu_book_outlined, size: 18),
              label: const Text('Food ideas & prices'),
            ),
          ),
          gap(10),
          waterCard(),
        ],
      ),
    );
  }

  Widget nutrition() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      nutritionSummary(),
      gap(14),
      DailyCheckInCard(store: s, date: date),
      gap(14),
      box(
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            macroStat('Carbs', s.total(date, 'carbs'), 'g', lime),
            macroStat('Fat', s.total(date, 'fat'), 'g', orange),
            macroStat(
              'Meals',
              s.mealsFor(date).length.toDouble(),
              'logged',
              Colors.white,
            ),
          ],
        ),
      ),
      heading(
        'Meal journal',
        action: TextButton.icon(
          onPressed: addMeal,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add meal'),
        ),
      ),
      if (s.mealsFor(date).isEmpty)
        box(
          Column(
            children: [
              const Icon(Icons.restaurant_outlined, color: muted, size: 42),
              gap(),
              const Text(
                'Your day starts with a bite.',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              gap(6),
              const Text(
                'Write what you ate, or add a photo.\nReview the estimate and confirm.',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted),
              ),
              gap(20),
              FilledButton.icon(
                onPressed: addMeal,
                icon: const Icon(Icons.add_a_photo_outlined),
                label: const Text('Log your first meal'),
              ),
            ],
          ),
        )
      else
        ...s.mealsFor(date).map(mealTile),
      gap(),
      small(
        'Photo values are estimates, not measurements. Portion size, oil, sauces and ingredients can change the result. For accuracy, weigh food and check nutrition labels.',
      ),
    ],
  );
  Widget macroStat(String label, double value, String unit, Color color) =>
      Flexible(
        child: Column(
          children: [
            Text(
              '${value.round()} $unit',
              style: TextStyle(
                color: color,
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
            small(label),
          ],
        ),
      );
  Widget mealTile(Meal m) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: panel,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () =>
            showSheet(context, MealEditor(store: s, date: date, existing: m)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: orange.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  m.estimated
                      ? Icons.photo_camera_outlined
                      : Icons.restaurant_rounded,
                  color: orange,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    small(
                      '${m.type} · ${m.source == 'manual' ? 'Manual entry' : m.source}',
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${m.calories.round()} kcal',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '${m.protein.toStringAsFixed(1)} g protein',
                    style: const TextStyle(color: lime, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: muted, size: 18),
            ],
          ),
        ),
      ),
    ),
  );
  Future<void> editWaterTarget() async {
    final value = TextEditingController(text: s.waterTargetMl.toString());
    final target = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Your daily drink target'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'A starting guide is around 1.5–2 L daily. Adjust for your needs or a target advised to you.',
            ),
            gap(14),
            TextField(
              controller: value,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Daily target · ml',
                helperText: '500–6000 ml · 2000 ml = 2 litres',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final n = int.tryParse(value.text);
              if (n != null && n >= 500 && n <= 6000) Navigator.pop(ctx, n);
            },
            child: const Text('Save goal'),
          ),
        ],
      ),
    );
    value.dispose();
    if (target != null) await s.setWaterTarget(target);
  }

  Widget waterCard() {
    final n = (s.water[dayKey(date)] as num? ?? 0).toDouble();
    return box(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.water_drop_outlined, color: Color(0xFF97C8F2)),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Water',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
                ),
              ),
              Text(
                '${(n * .25).toStringAsFixed(2)} / ${(s.waterTargetMl / 1000).toStringAsFixed(1)} L',
                style: const TextStyle(
                  color: Color(0xFF97C8F2),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          gap(8),
          LinearProgressIndicator(
            value: (s.waterMl(date) / s.waterTargetMl).clamp(0, 1),
            minHeight: 7,
            color: const Color(0xFF97C8F2),
            backgroundColor: ink,
            borderRadius: BorderRadius.circular(7),
          ),
          gap(8),
          Row(
            children: [
              Expanded(child: small('Hydration · your daily drink target')),
              TextButton(
                onPressed: editWaterTarget,
                child: const Text('Edit goal'),
              ),
            ],
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              IconButton(
                tooltip: 'Remove 250 ml',
                onPressed: n > 0 ? () => s.addWater(date, -1) : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              IconButton(
                tooltip: 'Add 250 ml',
                onPressed: n < 40 ? () => s.addWater(date, 1) : null,
                icon: const Icon(Icons.add_circle_outline, color: lime),
              ),
              OutlinedButton.icon(
                onPressed: n < 39 ? () => s.addWater(date, 2) : null,
                icon: const Icon(Icons.water_drop_outlined, size: 17),
                label: const Text('+500 ml bottle'),
              ),
            ],
          ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text(
              'How much should I drink?',
              style: TextStyle(fontSize: 12),
            ),
            children: [
              small(
                'Start around 1.5–2 litres of drinks per day (6–8 cups), then adjust for heat, activity and thirst. Other drinks and food provide fluid too. Use your clinician’s target if you have a fluid restriction. This is a general guide, not a personal fluid prescription.',
              ),
              TextButton(
                onPressed: () => launchUrl(
                  Uri.parse(
                    'https://www.nhs.uk/live-well/eat-well/food-guidelines-and-food-labels/water-drinks-nutrition/',
                  ),
                ),
                child: const Text('Hydration guidance · NHS ↗'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget training() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      box(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            tag('${s.profile!.days}-DAY SPLIT'),
            gap(),
            Text(
              'Your days. Your rhythm.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            gap(8),
            Text(
              '${s.profile!.experience} · ${s.profile!.equipment} · ${s.profile!.goal}',
              style: const TextStyle(color: muted),
            ),
            gap(),
            if (s.profile!.equipment == 'Full gym') ...[
              small(
                'Your full-gym plan combines machines, cables and free weights. Use Swap / move inside a workout when equipment is busy. Saved workouts keep the exercises you actually logged.',
              ),
              gap(10),
            ],
            const Text(
              'Why exercises repeat',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            gap(6),
            small(
              'Your workout rotation repeats across weeks so you can practise the same movements and compare reps and load. It does not replace every exercise on Monday. Different days already use different movements; use Swap / move for a suitable alternative. Each exercise keeps its own PR.',
            ),
            gap(10),
            const Text(
              'Keep 2–3 repetitions in reserve. When every set reaches the top of the rep range with steady form, add the smallest available weight next time. For bodyweight moves, add repetitions or slow the lowering phase.',
              style: TextStyle(fontSize: 13, color: muted),
            ),
          ],
        ),
      ),
      gap(18),
      attendanceCard(),
      heading(
        'Your week',
        subtitle:
            'A forecast, not a deadline. Missed days never skip a session.',
      ),
      ...List.generate(7, (i) {
        final monday = date.subtract(Duration(days: date.weekday - 1));
        final d = monday.add(Duration(days: i));
        final w = s.workoutOn(d);
        final missed =
            d.isBefore(calendarDay(DateTime.now())) &&
            s.sessions[dayKey(d)] == null;
        final done = (s.sessions[dayKey(d)] as Map?)?['done'] == true;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: dayKey(d) == dayKey(date) ? const Color(0xFF283020) : panel,
            borderRadius: BorderRadius.circular(18),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 10,
              ),
              leading: SizedBox(
                width: 42,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    small(weekdays[i].substring(0, 3).toUpperCase()),
                    Text(
                      '${d.day}',
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                        fontSize: 20,
                        height: 1.0,
                        fontWeight: FontWeight.w800,
                        color: dayKey(d) == dayKey(date) ? lime : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              title: Text(
                missed ? 'No workout logged' : w.name,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: small(
                missed
                    ? 'Sequence held · nothing skipped'
                    : w.rest
                    ? 'Easy movement + mobility'
                    : '${w.exercises.length} exercises · ${w.sets} sets each',
              ),
              trailing: Icon(
                done
                    ? Icons.check_circle
                    : w.rest
                    ? Icons.spa_outlined
                    : Icons.arrow_forward_rounded,
                color: done ? lime : muted,
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => WorkoutScreen(store: s, date: d),
                ),
              ),
            ),
          ),
        );
      }),
      heading('Move well, then move more.'),
      box(
        const Text(
          'Start with 5–10 minutes of easy movement and light practice sets. Use a controlled range of motion, breathe steadily and stop an exercise if you feel sharp pain. Watch the exercise videos, follow the written cues and use coaching to refine your form.',
          style: TextStyle(color: muted),
        ),
      ),
    ],
  );
  Widget attendanceCard() {
    final done = (s.sessions[dayKey(date)] as Map?)?['done'] == true;
    final last = s.lastCompletedBefore(date);
    final choice = s.attendance[dayKey(date)];
    final next = s.workoutOn(date, forceTraining: true);
    return box(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          tag(
            done
                ? 'WORKOUT COMPLETE'
                : choice == 'rest'
                ? 'REST DAY'
                : choice == 'train'
                ? 'TRAINING DAY'
                : 'DAILY CHECK-IN',
            color: done ? lime : orange,
          ),
          gap(14),
          Text(
            done
                ? 'You showed up.'
                : dayKey(date) == dayKey(DateTime.now())
                ? 'Are you training today?'
                : 'Training on this day?',
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
          ),
          gap(8),
          if (last != null)
            small(
              'Last completed: ${(last.value as Map)['name']} · ${prettyDay(DateTime.parse(last.key))}',
            ),
          if (done)
            small(
              'Session saved. Your next workout will follow this completed session.',
            ),
          if (!done && last == null)
            small('Your first session is ready when you are.'),
          gap(12),
          if (!done)
            Text(
              'Next in your sequence: ${next.name}',
              style: const TextStyle(color: lime, fontWeight: FontWeight.w700),
            ),
          gap(14),
          small(
            'Resting or missing a day keeps the next session in place. Finish a workout to move forward.',
          ),
          if (!done) ...[
            gap(18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: () async {
                    await s.setAttendance(date, 'train');
                    if (mounted) openWorkout();
                  },
                  icon: const Icon(Icons.fitness_center, size: 18),
                  label: const Text('I’m training'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    await s.setAttendance(date, 'rest');
                    if (mounted) {
                      toast(
                        context,
                        'Rest day saved. Your next workout stays in the queue.',
                      );
                    }
                  },
                  icon: const Icon(Icons.spa_outlined, size: 18),
                  label: const Text('Rest today'),
                ),
              ],
            ),
          ] else
            TextButton(
              onPressed: openWorkout,
              child: const Text('View completed workout →'),
            ),
        ],
      ),
    );
  }

  Widget progress() {
    final days = List.generate(7, (i) => date.subtract(Duration(days: 6 - i)));
    final total = s.sessions.values
        .where((v) => (v as Map)['done'] == true)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        box(
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              macroStat('Workouts completed', total.toDouble(), 'total', lime),
              macroStat(
                'Meals logged',
                s.meals.length.toDouble(),
                'total',
                orange,
              ),
            ],
          ),
        ),
        gap(16),
        FilledButton.tonalIcon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => PersonalRecordsScreen(store: s),
            ),
          ),
          icon: const Icon(Icons.emoji_events_outlined),
          label: const Text('Personal records'),
        ),
        heading(
          'Your last seven days',
          subtitle: 'Daily calories · bars use your current target',
        ),
        box(
          Column(
            children: days.map((d) {
              final cal = s.total(d, 'calories');
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 34,
                      child: small(weekdays[d.weekday - 1].substring(0, 3)),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: (cal / s.profile!.calories).clamp(0, 1),
                          minHeight: 14,
                          color: dayKey(d) == dayKey(date)
                              ? lime
                              : const Color(0xFF728453),
                          backgroundColor: ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 65,
                      child: Text(
                        '${cal.round()}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        heading(
          'Protein consistency',
          subtitle: 'Daily protein · current target ${s.profile!.protein} g',
        ),
        box(
          Column(
            children: days
                .map(
                  (d) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 40,
                          child: small(weekdays[d.weekday - 1].substring(0, 3)),
                        ),
                        Expanded(
                          child: LinearProgressIndicator(
                            value: (s.total(d, 'protein') / s.profile!.protein)
                                .clamp(0, 1),
                            color: orange,
                            backgroundColor: ink,
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 65,
                          child: Text(
                            '${s.total(d, 'protein').round()} g',
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        heading(
          'Bodyweight check-in',
          action: TextButton.icon(
            onPressed: logWeight,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Log weight'),
          ),
        ),
        if (s.weights.isEmpty)
          box(
            const Text(
              'Your weight is one signal, not your whole story.\nLog at a similar time of day to see a useful trend.',
              style: TextStyle(color: muted),
            ),
          )
        else
          box(
            Column(
              children: s.weights.reversed
                  .take(10)
                  .map(
                    (w) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              prettyDay(DateTime.parse(w['date'] as String)),
                              style: const TextStyle(color: muted),
                            ),
                          ),
                          Text(
                            '${w['kg']} kg',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: lime,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        gap(),
        small(
          'Weight check-ins track your trend. Update your profile weight to recalculate nutrition targets. Historical charts compare intake with your current targets.',
        ),
      ],
    );
  }

  Future<void> logWeight() async {
    final c = TextEditingController(text: s.profile!.weight.toString());
    String? error;
    final value = await showDialog<double>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Bodyweight check-in'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              small(prettyDay(date)),
              gap(),
              TextField(
                controller: c,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Weight · kg',
                  errorText: error,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final n = double.tryParse(c.text);
                if (n == null || !n.isFinite || n < 30 || n > 300) {
                  update(() => error = 'Enter 30–300 kg');
                  return;
                }
                Navigator.pop(context, n);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (value != null) await s.addWeight(date, value);
  }
}

class MacroRing extends StatelessWidget {
  final double value, target;
  final String label, unit;
  final Color color;
  const MacroRing({
    super.key,
    required this.value,
    required this.target,
    required this.label,
    required this.unit,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        width: 110,
        height: 110,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.expand(
              child: CircularProgressIndicator(
                value: (value / target).clamp(0, 1),
                strokeWidth: 7,
                backgroundColor: line,
                color: color,
                strokeCap: StrokeCap.round,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${value.round()}',
                  style: const TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
                Text(
                  '/ ${target.round()} $unit',
                  style: const TextStyle(color: muted, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      ),
      gap(12),
      Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
        ),
      ),
    ],
  );
}
