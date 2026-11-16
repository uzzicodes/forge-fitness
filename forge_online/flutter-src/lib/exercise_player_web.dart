import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

Widget exercisePlayer(Map<String, dynamic> demo) => _Player(demo: demo);

class _Player extends StatefulWidget {
  final Map<String, dynamic> demo;
  const _Player({required this.demo});
  @override
  State<_Player> createState() => _PlayerState();
}

class _PlayerState extends State<_Player> {
  web.HTMLVideoElement? video;
  @override
  void dispose() {
    video?.pause();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.demo;
    return HtmlElementView.fromTagName(
      tagName: d['kind'] == 'youtube' ? 'iframe' : 'video',
      onElementCreated: (element) {
        if (d['kind'] == 'youtube') {
          final frame = element as web.HTMLIFrameElement;
          frame.src = d['video'] as String;
          frame.title = '${d['title']} exercise demonstration';
          frame.allow =
              'accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture; web-share';
          frame.allowFullscreen = true;
          frame.referrerPolicy = 'strict-origin-when-cross-origin';
          frame.style.width = '100%';
          frame.style.height = '100%';
          frame.style.border = '0';
        } else {
          final v = element as web.HTMLVideoElement;
          video = v;
          v.src = d['video'] as String;
          v.poster = d['poster'] as String? ?? '';
          v.controls = true;
          v.loop = true;
          v.muted = true;
          v.preload = 'metadata';
          v.setAttribute('playsinline', '');
          v.setAttribute('aria-label', '${d['title']} exercise demonstration');
          v.style.width = '100%';
          v.style.height = '100%';
          v.style.objectFit = 'contain';
          v.style.background = '#10130f';
        }
      },
    );
  }
}
