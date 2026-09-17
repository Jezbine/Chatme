import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';

/// Visionneuse interactive pour images et photos en plein écran (style WhatsApp/Telegram)
class ImageViewerScreen extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String? subtitle;

  const ImageViewerScreen({
    required this.imageUrl,
    this.title = 'Photo',
    this.subtitle,
    super.key,
  });

  static void show(BuildContext context, {required String imageUrl, String title = 'Photo', String? subtitle}) {
    Get.to(
      () => ImageViewerScreen(imageUrl: imageUrl, title: title, subtitle: subtitle),
      transition: Transition.fadeIn,
      fullscreenDialog: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNetwork = imageUrl.startsWith('http');

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.7),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            if (subtitle != null)
              Text(subtitle!, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
        actions: [
          if (isNetwork)
            IconButton(
              icon: const Icon(Icons.open_in_browser, color: Colors.white),
              tooltip: 'Ouvrir dans le navigateur',
              onPressed: () async {
                final uri = Uri.tryParse(imageUrl);
                if (uri != null && await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 4.0,
          child: isNetwork
              ? Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(child: CircularProgressIndicator(color: Colors.white));
                  },
                  errorBuilder: (_, __, ___) => const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image, color: Colors.white54, size: 64),
                        SizedBox(height: 12),
                        Text('Impossible de charger l\'image', style: TextStyle(color: Colors.white54)),
                      ],
                    ),
                  ),
                )
              : Image.file(
                  File(imageUrl),
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
                  ),
                ),
        ),
      ),
    );
  }
}

/// Lecteur vidéo plein écran pour les messages vidéos reçus ou envoyés
class VideoViewerScreen extends StatefulWidget {
  final String videoUrl;
  final String title;

  const VideoViewerScreen({
    required this.videoUrl,
    this.title = 'Vidéo',
    super.key,
  });

  static void show(BuildContext context, {required String videoUrl, String title = 'Vidéo'}) {
    Get.to(
      () => VideoViewerScreen(videoUrl: videoUrl, title: title),
      transition: Transition.fadeIn,
      fullscreenDialog: true,
    );
  }

  @override
  State<VideoViewerScreen> createState() => _VideoViewerScreenState();
}

class _VideoViewerScreenState extends State<VideoViewerScreen> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _hasError = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      final isNetwork = widget.videoUrl.startsWith('http');
      _controller = isNetwork
          ? VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
          : VideoPlayerController.file(File(widget.videoUrl));

      await _controller!.initialize();
      _controller!.addListener(() {
        if (mounted) setState(() {});
      });
      _controller!.play();
      if (mounted) {
        setState(() {
          _initialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.7),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: _hasError
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, color: Colors.redAccent, size: 54),
                        SizedBox(height: 12),
                        Text('Erreur de lecture de la vidéo', style: TextStyle(color: Colors.white70)),
                      ],
                    )
                  : (_initialized && _controller != null
                      ? AspectRatio(
                          aspectRatio: _controller!.value.aspectRatio,
                          child: VideoPlayer(_controller!),
                        )
                      : const CircularProgressIndicator(color: Colors.white)),
            ),

            // Bouton central Play/Pause
            if (_showControls && _initialized && _controller != null)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _controller!.value.isPlaying ? _controller!.pause() : _controller!.play();
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Icon(
                    _controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
              ),

            // Barre de progression en bas
            if (_showControls && _initialized && _controller != null)
              Positioned(
                bottom: 24,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Text(
                        _formatDuration(_controller!.value.position),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      Expanded(
                        child: Slider(
                          value: _controller!.value.position.inMilliseconds.toDouble(),
                          min: 0,
                          max: _controller!.value.duration.inMilliseconds.toDouble(),
                          activeColor: Theme.of(context).colorScheme.primary,
                          inactiveColor: Colors.white30,
                          onChanged: (val) {
                            _controller!.seekTo(Duration(milliseconds: val.toInt()));
                          },
                        ),
                      ),
                      Text(
                        _formatDuration(_controller!.value.duration),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

