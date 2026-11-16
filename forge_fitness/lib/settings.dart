import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'models.dart';
import 'profile_screen.dart';
import 'body_status.dart';
import 'main.dart'
    show lime, orange, muted, gap, small, tag, box, heading, toast;

class SettingsView extends StatefulWidget {
  final AppStore store;
  const SettingsView({super.key, required this.store});
  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final url = TextEditingController(), token = TextEditingController();
  String status = '';
  bool testing = false, visible = false;
  @override
  void initState() {
    super.initState();
    url.text = widget.store.server;
    token.text = widget.store.token;
    if (token.text.isNotEmpty && !widget.store.guestMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) connect();
      });
    }
  }

  @override
  void dispose() {
    url.dispose();
    token.dispose();
    super.dispose();
  }

  bool validConnection() {
    if (url.text.trim().isEmpty && kIsWeb) return true;
    final uri = Uri.tryParse(url.text.trim());
    return uri != null &&
        ['http', 'https'].contains(uri.scheme) &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        (uri.path.isEmpty || uri.path == '/') &&
        uri.query.isEmpty &&
        uri.fragment.isEmpty;
  }

  Future<void> connect() async {
    if (!widget.store.cloudEnabled &&
        (!validConnection() || token.text.trim().length < 16)) {
      setState(
        () => status =
            'Enter a valid server address and the pairing token from its console.',
      );
      return;
    }
    setState(() {
      testing = true;
      status = widget.store.cloudEnabled
          ? 'Checking your online account…'
          : 'Checking your computer…';
    });
    try {
      if (!widget.store.cloudEnabled) {
        await widget.store.saveConnection(url.text, token.text);
      }
      final base = widget.store.cloudEnabled || url.text.trim().isEmpty
          ? Uri.base.origin
          : widget.store.server;
      final r = await http
          .get(
            Uri.parse('$base/api/status'),
            headers: {'Authorization': 'Bearer ${token.text.trim()}'},
          )
          .timeout(const Duration(seconds: 8));
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      if (!mounted) return;
      setState(
        () => status = r.statusCode == 200
            ? (j['configured'] == true || j['aiProviders']?['groq'] == true
                  ? 'Connected. Food references and your selected photo AI are ready.'
                  : 'Food references are ready. Gemini and Groq are optional.')
            : (j['error'] as String? ?? 'Connection failed.'),
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => status = widget.store.cloudEnabled
              ? 'Could not reach your account. Check your internet connection and try Sync now.'
              : 'Could not connect. Keep the server running, check the address and use the same Wi-Fi on both devices.',
        );
      }
    } finally {
      if (mounted) setState(() => testing = false);
    }
  }

  Future<void> exportBackup() async {
    final raw = widget.store.storageError
        ? (widget.store.preferences.getString(widget.store.stateStorageKey) ??
              widget.store.backup())
        : widget.store.backup();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your data, to keep.'),
        content: SizedBox(
          width: 550,
          height: 320,
          child: SingleChildScrollView(
            child: SelectableText(
              raw,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: raw));
              if (context.mounted) {
                toast(
                  context,
                  'Backup copied. Save it in a .json or text file.',
                );
              }
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy backup'),
          ),
        ],
      ),
    );
  }

  Future<void> importBackup() async {
    final c = TextEditingController();
    String? error;
    final raw = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Restore a backup'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'This replaces this device’s profile, meals and workouts. Export your current data first.',
                style: TextStyle(color: orange),
              ),
              gap(),
              TextField(
                controller: c,
                maxLines: 7,
                decoration: InputDecoration(
                  labelText: 'Paste FORGE backup JSON',
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
                try {
                  final parsed = jsonDecode(c.text);
                  if (parsed is! Map || parsed['version'] != 1) {
                    throw const FormatException();
                  }
                  Navigator.pop(context, c.text);
                } catch (_) {
                  update(() => error = 'Paste a valid FORGE v1 JSON backup.');
                }
              },
              child: const Text('Replace & restore'),
            ),
          ],
        ),
      ),
    );
    if (raw == null) return;
    try {
      await widget.store.restore(raw);
      if (mounted) toast(context, 'Backup restored.');
    } catch (_) {
      if (mounted) {
        toast(context, 'Invalid backup. Your current data was not replaced.');
      }
    }
  }

  Future<void> link(String address) async {
    if (!await launchUrl(
          Uri.parse(address),
          mode: LaunchMode.externalApplication,
        ) &&
        mounted) {
      toast(context, 'Could not open this source.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.store.profile!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        small('MAKE IT YOURS'),
        gap(6),
        Text(
          'Your foundation.',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        gap(25),
        box(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        small(
                          '${p.weight} kg · ${p.height} cm · ${p.age} years',
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Edit profile',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            ProfileScreen(store: widget.store, editing: true),
                      ),
                    ),
                    icon: const Icon(Icons.edit_outlined, color: lime),
                  ),
                ],
              ),
              gap(18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  tag(p.goal),
                  tag(p.equipment, color: muted),
                  tag('${p.days} days / week', color: muted),
                ],
              ),
              gap(18),
              Text(
                '${p.calories} kcal  /  ${p.protein} g protein daily',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              gap(6),
              small(
                'These are starting targets. You can edit them in your profile.',
              ),
              gap(12),
              if (p.goal != 'Lean & defined')
                OutlinedButton.icon(
                  onPressed: () =>
                      widget.store.setProfile(p.withGoal('Lean & defined')),
                  icon: const Icon(Icons.accessibility_new),
                  label: const Text('Use Lean & defined plan'),
                ),
              if (p.goal == 'Lean & defined')
                small(
                  'Balanced muscle, strength and conditioning. Starts at estimated maintenance calories, without an automatic surplus. Track energy, training and bodyweight trends before changing intake.',
                ),
            ],
          ),
        ),
        gap(18),
        BodyStatusCard(
          profile: p,
          onUseTarget: (n) => widget.store.setProfile(
            Profile.fromJson({...p.toJson(), 'calorieOverride': n}),
          ),
        ),
        if (widget.store.guestMode) ...[
          heading('Guest mode'),
          box(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'No login required. Your profile, meals, training, water, habits and XP are saved only in this browser or installed app.',
                ),
                gap(12),
                small(
                  'Keep using the same browser or Home Screen app. Clearing its storage removes guest progress. Export a backup below before changing devices. Sign-in opens a separate private cloud profile; it does not overwrite or automatically upload your guest records.',
                ),
                gap(14),
                OutlinedButton.icon(
                  onPressed: () => link(
                    Uri.base
                        .resolve(
                          '/signin-with-chatgpt?return_to=%2Ffitness%2F%3Fmode%3Daccount',
                        )
                        .toString(),
                  ),
                  icon: const Icon(Icons.cloud_outlined),
                  label: const Text('Sign in for cloud sync'),
                ),
              ],
            ),
          ),
          gap(18),
        ],
        heading(
          'Meal estimates connection',
          subtitle: widget.store.guestMode
              ? 'Free text references and on-device tools need no account.'
              : 'Your online account keeps nutrition and training private.',
        ),
        box(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Text references, packet lookup and saved labels work without photo AI. Gemini and Groq are optional for mixed-meal estimates.',
                style: TextStyle(color: muted),
              ),
              gap(18),
              if (kIsWeb && !widget.store.guestMode)
                FilledButton.icon(
                  onPressed: () =>
                      link(Uri.base.resolve('/configure').toString()),
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: const Text('Optional Gemini / Groq setup'),
                ),
              if (widget.store.cloudEnabled) ...[
                gap(12),
                Text('Account sync: ${widget.store.syncStatus}'),
                TextButton.icon(
                  onPressed: () async {
                    await widget.store.syncCloud();
                    if (mounted) setState(() {});
                  },
                  icon: const Icon(Icons.sync),
                  label: const Text('Sync now'),
                ),
              ],
              if (status.isNotEmpty) ...[
                gap(14),
                Text(status, style: const TextStyle(color: orange)),
              ],
              gap(14),
              if (!widget.store.guestMode)
                TextButton.icon(
                  onPressed: testing ? null : connect,
                  icon: const Icon(Icons.refresh),
                  label: Text(testing ? 'Checking…' : 'Check connection'),
                ),
              if (!widget.store.hosted)
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text(
                    'Advanced connection',
                    style: TextStyle(fontSize: 14),
                  ),
                  children: [
                    TextField(
                      controller: url,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'Computer server address',
                        hintText: 'Leave blank to use this app’s server',
                      ),
                    ),
                    gap(14),
                    TextField(
                      controller: token,
                      obscureText: !visible,
                      decoration: InputDecoration(
                        labelText: 'Pairing token (not your API key)',
                        suffixIcon: IconButton(
                          tooltip: 'Show or hide pairing token',
                          onPressed: () => setState(() => visible = !visible),
                          icon: Icon(
                            visible
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                    ),
                    gap(14),
                    FilledButton(
                      onPressed: testing ? null : connect,
                      child: const Text('Save connection'),
                    ),
                    gap(12),
                  ],
                ),
              gap(14),
              small(
                'This online app works without your PC. Barcode decoding and the small photo matcher run on your device. A photo goes to your chosen Google or Groq provider only when you request AI estimation. FORGE does not archive it.',
              ),
            ],
          ),
        ),
        heading('Use FORGE on iPhone'),
        box(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Open this site in Safari → Share → Add to Home Screen. Your computer can be off. Open the Home Screen app while connected and wait for Offline ready before testing offline access.',
                style: TextStyle(color: muted),
              ),
              gap(14),
              OutlinedButton.icon(
                onPressed: () => link(
                  kIsWeb
                      ? Uri.base.resolve('/iphone').toString()
                      : 'http://localhost:8787/iphone',
                ),
                icon: const Icon(Icons.phone_iphone),
                label: const Text('iPhone setup guide'),
              ),
            ],
          ),
        ),
        heading('Your data belongs to you.'),
        box(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.store.guestMode
                    ? 'Your guest profile, nutrition, workouts, water and check-ins stay on this device. Export a backup before clearing browser storage. Photos are not retained.'
                    : 'Your profile, nutrition, workouts, attendance and check-ins sync to your private account online. Offline changes are queued on this device. Keep a backup before clearing browser storage. Photos are not retained.',
                style: TextStyle(color: muted),
              ),
              gap(20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton.icon(
                    onPressed: exportBackup,
                    icon: const Icon(Icons.copy_all_outlined),
                    label: const Text('Export backup'),
                  ),
                  OutlinedButton.icon(
                    onPressed: importBackup,
                    icon: const Icon(Icons.restore),
                    label: const Text('Restore backup'),
                  ),
                  if (widget.store.cloudEnabled && kIsWeb)
                    OutlinedButton.icon(
                      onPressed: () async {
                        await widget.store.syncCloud();
                        if (widget.store.syncStatus != 'Synced') {
                          if (context.mounted) {
                            toast(
                              context,
                              'Connect and sync before signing out so your changes are saved.',
                            );
                          }
                          return;
                        }
                        await widget.store.clearAccountCache();
                        await launchUrl(
                          Uri.base.resolve('/signout-with-chatgpt?return_to=/'),
                          webOnlyWindowName: '_self',
                        );
                      },
                      icon: const Icon(Icons.logout),
                      label: const Text('Sign out'),
                    ),
                ],
              ),
            ],
          ),
        ),
        heading('How your plan is built'),
        box(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Calories use Mifflin–St Jeor resting energy × activity, plus 200 kcal for muscle gain or minus 250 kcal for a chosen fat-loss goal. Other goals start at maintenance, within app bounds. Protein starts at 1.6 g/kg. BMI is an adult screening calculation; it does not distinguish muscle and fat. Feet/inches are converted to centimetres.\n\nChoose 2–5 training days. Balanced strength work is useful for men and women, including during fat loss. Fat-loss plans add optional low-impact cardio guidance; waist-focus plans include core stability, without promising spot reduction. Completed sessions advance the rotation; rest and missed days preserve the next session.',
                style: TextStyle(color: muted),
              ),
              gap(12),
              TextButton(
                onPressed: () =>
                    link('https://pubmed.ncbi.nlm.nih.gov/2305711/'),
                child: const Text('Calorie formula · original research ↗'),
              ),
              TextButton(
                onPressed: () =>
                    link('https://pmc.ncbi.nlm.nih.gov/articles/PMC5477153/'),
                child: const Text('Protein & exercise · ISSN position stand ↗'),
              ),
              TextButton(
                onPressed: () => link(
                  'https://acsm.org/resistance-training-guidelines-update-2026/',
                ),
                child: const Text('Resistance training · ACSM guidance ↗'),
              ),
            ],
          ),
        ),
        gap(28),
        Center(child: small('FORGE 1.0 · BUILT FOR YOUR EVERYDAY')),
      ],
    );
  }
}
