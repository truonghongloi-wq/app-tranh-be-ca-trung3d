import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Video 3 giây khi mở app. Video lỗi/không tải được thì bỏ qua luôn,
/// không để khách kẹt ở màn chờ.
class VideoIntro extends StatefulWidget {
  final VoidCallback onDone;
  const VideoIntro({super.key, required this.onDone});

  @override
  State<VideoIntro> createState() => _VideoIntroState();
}

class _VideoIntroState extends State<VideoIntro> {
  final _controller = VideoPlayerController.asset(
    'assets/videos/splash.mp4',
    videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
  );
  Timer? _safety;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _safety = Timer(const Duration(seconds: 5), _finish);
    _start();
  }

  Future<void> _start() async {
    try {
      await _controller.initialize().timeout(const Duration(seconds: 2));
      if (!mounted || _done) return;
      _controller.addListener(_onTick);
      await _controller.play();
      setState(() {});
    } catch (_) {
      _finish();
    }
  }

  void _onTick() {
    final v = _controller.value;
    if (v.hasError || v.isCompleted) _finish();
  }

  void _finish() {
    if (_done || !mounted) return;
    _done = true;
    _safety?.cancel();
    widget.onDone();
  }

  @override
  void dispose() {
    _safety?.cancel();
    _controller.removeListener(_onTick);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = _controller.value.isInitialized;
    return ColoredBox(
      color: Colors.black,
      child: AnimatedOpacity(
        opacity: ready ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: ready
            ? SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller.value.size.width,
                    height: _controller.value.size.height,
                    child: VideoPlayer(_controller),
                  ),
                ),
              )
            : const SizedBox.expand(),
      ),
    );
  }
}
