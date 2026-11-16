import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'exercise_player.dart';
import 'main.dart' show muted, orange, gap, small, tag, box;

Map<String, dynamic>? _demos;
Future<Map<String, dynamic>> _loadDemos() async {
  if (_demos != null) return _demos!;
  final r = await http
      .get(Uri.base.resolve('/demos/manifest.json'))
      .timeout(const Duration(seconds: 12));
  if (r.statusCode != 200) throw Exception('Demo library unavailable');
  return _demos = Map<String, dynamic>.from(jsonDecode(r.body) as Map);
}

class ExerciseMedia extends StatefulWidget {
  final String exerciseId;
  const ExerciseMedia({super.key, required this.exerciseId});
  @override
  State<ExerciseMedia> createState() => _ExerciseMediaState();
}

class _ExerciseMediaState extends State<ExerciseMedia> {
  late Future<Map<String, dynamic>> loading = _loadDemos();
  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: loading,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return box(
          Column(
            children: [
              const Icon(Icons.videocam_off_outlined, color: muted, size: 40),
              gap(10),
              const Text(
                'Connect to load the exercise demo. Your sets and technique cues still work offline.',
              ),
              TextButton(
                onPressed: () => setState(() => loading = _loadDemos()),
                child: const Text('Retry demo'),
              ),
            ],
          ),
        );
      }
      if (!snapshot.hasData) {
        return const SizedBox(
          height: 210,
          child: Center(child: CircularProgressIndicator()),
        );
      }
      final d = Map<String, dynamic>.from(
        snapshot.data![widget.exerciseId] as Map,
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          tag(
            d['kind'] == 'youtube'
                ? 'COACH VIDEO · TAP PLAY'
                : 'REAL MOVEMENT · TAP PLAY',
            color: orange,
          ),
          gap(12),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: AspectRatio(aspectRatio: 16 / 9, child: exercisePlayer(d)),
          ),
          gap(10),
          small('${d['author']} · ${d['license']}'),
          if (d['kind'] == 'youtube')
            small(
              'Hosted by the original video provider. If playback is blocked, open the source below.',
            ),
          Wrap(
            spacing: 6,
            children: [
              TextButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse((d['watchUrl'] ?? d['sourceUrl']) as String),
                ),
                icon: const Icon(Icons.open_in_new, size: 15),
                label: const Text('Open original demo'),
              ),
              if (d['kind'] == 'video')
                TextButton(
                  onPressed: () =>
                      launchUrl(Uri.parse(d['licenseUrl'] as String)),
                  child: const Text('CC BY-SA 4.0'),
                ),
            ],
          ),
          if (d['kind'] == 'video') small(d['changes'] as String? ?? ''),
        ],
      );
    },
  );
}
