import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import 'package:chatme/core/theme/chatme_theme.dart';
import 'package:chatme/services/status_service.dart';

class StatusViewerScreen extends StatefulWidget {
  final String name;
  final String initials;
  final int colorValue;
  final List<StatusItem> items;
  final bool isMine;
  final String? ownerId;

  const StatusViewerScreen({
    super.key,
    required this.name,
    required this.initials,
    required this.colorValue,
    required this.items,
    this.isMine = false,
    this.ownerId,
  });

  @override
  State<StatusViewerScreen> createState() => _StatusViewerScreenState();
}

class _StatusViewerScreenState extends State<StatusViewerScreen> {
  late int _index;
  late List<StatusItem> _items;
  double _progress = 0;
  bool _done = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.items);
    _index = 0;
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    if (_items.isEmpty) {
      _close();
      return;
    }
    _progress = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 50), (t) {
      if (!mounted || _done) {
        t.cancel();
        return;
      }
      _progress += 0.02;
      if (_progress >= 1) {
        _progress = 1;
        t.cancel();
        _next();
      } else {
        setState(() {});
      }
    });
  }

  void _next() {
    if (_index < _items.length - 1) {
      setState(() => _index++);
      _startTimer();
    } else {
      _close();
    }
  }

  void _prev() {
    if (_progress > 0.1 || _index == 0) {
      setState(() => _progress = 0);
      return;
    }
    setState(() => _index--);
    _startTimer();
  }

  void _close() {
    _done = true;
    _timer?.cancel();
    Get.back();
  }

  void _deleteCurrent() {
    // Sécurité : seul le propriétaire peut supprimer son statut
    if (!widget.isMine) {
      Get.snackbar('Action non autorisée', 'Vous pouvez uniquement consulter le statut des autres — suppression interdite.',
          snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.white, colorText: Colors.black);
      return;
    }
    final item = _items[_index];
    Get.dialog(
      AlertDialog(
        title: const Text('Supprimer le statut'),
        content: const Text('Voulez-vous supprimer ce statut ?'),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Annuler')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              Get.back();
              StatusService.to.deleteMyStatus(item.id);
              setState(() => _items.removeAt(_index));
              if (_items.isEmpty) {
                _close();
              } else {
                if (_index >= _items.length) _index = _items.length - 1;
                _startTimer();
              }
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  void _editCurrent() {
    if (!widget.isMine) {
      Get.snackbar('Action non autorisée', 'Vous pouvez uniquement consulter le statut des autres — modification interdite.',
          snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.white, colorText: Colors.black);
      return;
    }
    final item = _items[_index];
    _pendingDuration = item.durationMinutes;
    final isPreset = [1, 5, 60, 1440].contains(item.durationMinutes);
    bool customEdit = !isPreset;
    final ctrl = TextEditingController(text: item.text ?? '');
    final customCtrl = TextEditingController(text: customEdit ? item.durationMinutes.toString() : '');
    Get.dialog(
      StatefulBuilder(builder: (ctx, setD) {
        return AlertDialog(
          title: const Text('Modifier le statut'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Contenu', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: isPreset ? item.durationMinutes : -1,
                decoration: const InputDecoration(labelText: 'Visibilité'),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('1 min')),
                  DropdownMenuItem(value: 5, child: Text('5 min')),
                  DropdownMenuItem(value: 60, child: Text('1 h')),
                  DropdownMenuItem(value: 1440, child: Text('24 h (défaut WhatsApp)')),
                  DropdownMenuItem(value: -1, child: Text('Personnalisé...')),
                ],
                onChanged: (v) {
                  setD(() {
                    if (v == -1) {
                      customEdit = true;
                    } else if (v != null) {
                      customEdit = false;
                      _pendingDuration = v;
                    }
                  });
                },
              ),
              if (customEdit) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: customCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Durée personnalisée (min)',
                    hintText: '1 → 10080 (7 jours max)',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) {
                    final p = int.tryParse(v.trim());
                    if (p != null && p >= 1 && p <= 10080) _pendingDuration = p;
                  },
                ),
                const SizedBox(height: 4),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('1 min à 10080 min (7 jours) — WeChat style', style: TextStyle(fontSize: 11, color: Colors.grey)),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Get.back(), child: const Text('Annuler')),
            TextButton(
              onPressed: () {
                if (customEdit) {
                  final p = int.tryParse(customCtrl.text.trim());
                  if (p == null || p < 1 || p > 10080) {
                    Get.snackbar('Durée invalide', 'Entrez entre 1 et 10080 minutes', snackPosition: SnackPosition.BOTTOM);
                    return;
                  }
                  _pendingDuration = p;
                }
                final text = ctrl.text.trim();
                if (text.isNotEmpty || item.type != 'text') {
                  StatusService.to.editMyStatus(item.id, text: text.isEmpty ? null : text, durationMinutes: _pendingDuration);
                  // Maj locale immédiate pour reflet personnalisé sans attendre realtime
                  final idx = _items.indexWhere((e) => e.id == item.id);
                  if (idx != -1) {
                    final old = _items[idx];
                    _items[idx] = StatusItem(
                      id: old.id,
                      type: old.type,
                      text: text.isEmpty ? old.text : text,
                      mediaPath: old.mediaPath,
                      durationMinutes: _pendingDuration,
                      createdAt: old.createdAt,
                      expiresAt: old.createdAt.add(Duration(minutes: _pendingDuration)),
                    );
                  }
                  setState(() {});
                }
                Get.back();
                Get.snackbar('Statut modifié', 'Visible pendant ${_formatDuration(_pendingDuration)}',
                    snackPosition: SnackPosition.BOTTOM, backgroundColor: ChatMeColors.violet, colorText: Colors.white);
              },
              child: const Text('Enregistrer'),
            ),
          ],
        );
      }),
    );
  }

  String _formatDuration(int min) {
    if (min < 60) return '$min min';
    if (min < 1440) return '${min ~/ 60} h${min % 60 == 0 ? '' : ' ${min % 60} min'}';
    if (min % 1440 == 0) return '${min ~/ 1440} j';
    final d = min ~/ 1440;
    final h = (min % 1440) ~/ 60;
    if (d > 0 && h > 0) return '${d}j ${h}h';
    return '${d}j';
  }

  String _remainingLabel(StatusItem it) {
    final rem = it.expiresAt.difference(DateTime.now());
    if (rem.isNegative) return 'expiré';
    if (rem.inMinutes < 60) return 'expire dans ${rem.inMinutes} min';
    if (rem.inHours < 24) return 'expire dans ${rem.inHours} h';
    return 'expire dans ${rem.inDays} j';
  }

  int _pendingDuration = 0;

  @override
  Widget build(BuildContext context) {
    final item = _items[_index];
    final canEdit = widget.isMine && StatusService.to.canEditMyStatus(item);
    return Scaffold(
      backgroundColor: const Color(0xFF12101F),
      body: GestureDetector(
        onTapUp: (d) {
          final w = MediaQuery.of(context).size.width;
          if (d.localPosition.dx > w / 2) {
            _next();
          } else {
            _prev();
          }
        },
        child: Stack(
          children: [
            // Contenu du statut (image/vidéo local ou réseau)
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: (item.mediaPath != null && (item.type == 'image' || item.type == 'video'))
                  ? null
                  : const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [ChatMeColors.violet, Color(0xFF5B52B8)],
                      ),
                    ),
              child: _buildStatusMedia(item),
            ),
            // Barres de progression
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: List.generate(_items.length, (i) {
                        final active = i == _index;
                        return Expanded(
                          child: Container(
                            height: 3,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: Colors.white30,
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: i < _index ? 1 : (active ? _progress : 0),
                              child: Container(color: Colors.white),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Color(widget.colorValue),
                          child: Text(widget.initials,
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                              Text('${_remainingLabel(item)} • ${_formatDuration(item.durationMinutes)}',
                                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
                            ],
                          ),
                        ),
                        if (canEdit)
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: Colors.white),
                            onPressed: _editCurrent,
                          ),
                        if (widget.isMine)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.white),
                            onPressed: _deleteCurrent,
                          ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: _close,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusMedia(StatusItem item) {
    final path = item.mediaPath;
    final isVideo = item.type == 'video' || (path != null && (path.endsWith('.mp4') || path.endsWith('.mov') || path.contains('video')));
    if (path == null || path.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(item.text ?? '', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
        ),
      );
    }
    if (isVideo) {
      return _VideoStatusPlayer(path: path, text: item.text);
    }
    final isNetwork = path.startsWith('http');
    return Stack(
      fit: StackFit.expand,
      children: [
        isNetwork
            ? Image.network(path, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: Colors.white54, size: 60)))
            : Image.file(File(path), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: Colors.white54, size: 60))),
        if (item.text != null && item.text!.isNotEmpty)
          Positioned(
            bottom: 80,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
              child: Text(item.text!, style: const TextStyle(color: Colors.white, fontSize: 16), textAlign: TextAlign.center),
            ),
          ),
      ],
    );
  }
}

class _VideoStatusPlayer extends StatefulWidget {
  final String path;
  final String? text;
  const _VideoStatusPlayer({required this.path, this.text});

  @override
  State<_VideoStatusPlayer> createState() => _VideoStatusPlayerState();
}

class _VideoStatusPlayerState extends State<_VideoStatusPlayer> {
  VideoPlayerController? _controller;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    final isNetwork = widget.path.startsWith('http');
    _controller = isNetwork ? VideoPlayerController.networkUrl(Uri.parse(widget.path)) : VideoPlayerController.file(File(widget.path));
    _controller!.initialize().then((_) {
      if (mounted) setState(() {});
      _controller!.setLooping(false);
      _controller!.play();
    }).catchError((_) {
      if (mounted) setState(() => _error = true);
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error) return const Center(child: Icon(Icons.videocam_off, color: Colors.white54, size: 60));
    if (_controller == null || !_controller!.value.isInitialized) return const Center(child: CircularProgressIndicator(color: Colors.white));
    return Stack(
      fit: StackFit.expand,
      children: [
        FittedBox(fit: BoxFit.cover, child: SizedBox(width: _controller!.value.size.width, height: _controller!.value.size.height, child: VideoPlayer(_controller!))),
        if (widget.text != null && widget.text!.isNotEmpty)
          Positioned(bottom: 80, left: 16, right: 16, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)), child: Text(widget.text!, style: const TextStyle(color: Colors.white, fontSize: 16), textAlign: TextAlign.center))),
      ],
    );
  }
}
