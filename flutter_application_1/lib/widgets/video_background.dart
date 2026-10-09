import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Video nền phủ kín, lặp lại, không tiếng. Lỗi thì chỉ hiện nền đen.
class VideoBackground extends StatefulWidget {
  final String asset;
  const VideoBackground({super.key, required this.asset});

  @override
  State<VideoBackground> createState() => _VideoBackgroundState();
}

class _VideoBackgroundState extends State<VideoBackground> {
  late final VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    // mixWithOthers: không làm tắt nhạc khách đang nghe
    _controller = VideoPlayerController.asset(
      widget.asset,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _start();
  }

  Future<void> _start() async {
    try {
      await _controller.initialize();
      await _controller.setLooping(true);
      await _controller.setVolume(0);
      await _controller.play();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  @override
  void dispose() {
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
        duration: const Duration(milliseconds: 300),
        child: ready
            ? SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  clipBehavior: Clip.hardEdge,
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
