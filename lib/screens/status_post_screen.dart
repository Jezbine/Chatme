import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:chatme/core/theme/chatme_theme.dart';
import 'package:chatme/services/status_service.dart';

class StatusPostScreen extends StatefulWidget {
  const StatusPostScreen({super.key});

  @override
  State<StatusPostScreen> createState() => _StatusPostScreenState();
}

class _StatusPostScreenState extends State<StatusPostScreen> {
  final _textCtrl = TextEditingController();
  final _customCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  String _type = 'text';
  File? _photo;
  int _duration = 1440; // 24 h par défaut
  bool _custom = false;

  final List<Map<String, dynamic>> _presets = const [
    {'label': '1 minute', 'min': 1},
    {'label': '5 minutes', 'min': 5},
    {'label': '1 heure', 'min': 60},
    {'label': '24 heures', 'min': 1440},
  ];

  @override
  void dispose() {
    _textCtrl.dispose();
    _customCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final file = await _picker.pickImage(source: ImageSource.gallery);
      if (file != null) {
        setState(() {
          _photo = File(file.path);
          _type = 'image';
        });
      }
    } catch (e) {
      if (kDebugMode) print('[StatusPost] Error picking photo: $e');
    }
  }

  Future<void> _pickVideo() async {
    try {
      final file = await _picker.pickVideo(source: ImageSource.gallery);
      if (file != null) {
        setState(() {
          _photo = File(file.path);
          _type = 'video';
        });
      }
    } catch (e) {
      if (kDebugMode) print('[StatusPost] Error picking video: $e');
    }
  }

  void _publish() {
    final duration = _custom
        ? (int.tryParse(_customCtrl.text) ?? _duration)
        : _duration;
    final text = _textCtrl.text.trim();

    if ((_type == 'image' || _type == 'video') && _photo == null) {
      Get.snackbar(_type == 'video' ? 'Vidéo requise' : 'Photo requise', 'Choisissez un média ou passez en mode texte',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (_type == 'text' && text.isEmpty) {
      Get.snackbar('Texte requis', 'Écrivez quelque chose pour votre statut',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    StatusService.to.addMyStatus(
      type: _type,
      text: text.isEmpty ? null : text,
      mediaPath: _photo?.path,
      durationMinutes: duration,
    );
    Get.back();
    Get.snackbar('Statut publié', 'Visible pendant ${_formatDuration(duration)}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: ChatMeColors.violet,
        colorText: Colors.white);
  }

  String _formatDuration(int min) {
    if (min < 60) return '$min min';
    if (min < 1440) return '${min ~/ 60} h';
    return '${min ~/ 1440} j';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ChatMeColors.surface,
      appBar: AppBar(
        backgroundColor: ChatMeColors.surface,
        foregroundColor: ChatMeColors.ink,
        title: const Text('Nouveau statut'),
        centerTitle: false,
        actions: [
          TextButton(onPressed: _publish, child: const Text('Publier')),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                _TypeChip(label: 'Texte', active: _type == 'text', onTap: () => setState(() => _type = 'text')),
                const SizedBox(width: 10),
                _TypeChip(label: 'Photo', active: _type == 'image', onTap: () => _pickPhoto()),
                const SizedBox(width: 10),
                _TypeChip(label: 'Vidéo', active: _type == 'video', onTap: () => _pickVideo()),
              ],
            ),
            const SizedBox(height: 16),
            if (_type == 'text')
              TextField(
                controller: _textCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Exprimez-vous…',
                  filled: true,
                  fillColor: ChatMeColors.violetPale,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              )
            else
              GestureDetector(
                onTap: () => _type == 'video' ? _pickVideo() : _pickPhoto(),
                child: Container(
                  height: 180,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: ChatMeColors.violetPale,
                  ),
                  child: _photo != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: _type == 'video'
                              ? Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Container(color: Colors.black12, child: const Center(child: Icon(Icons.videocam, size: 40, color: ChatMeColors.violet))),
                                    Center(child: Text(_photo!.path.split('/').last, style: const TextStyle(color: ChatMeColors.violet, fontSize: 12), textAlign: TextAlign.center)),
                                  ],
                                )
                              : Image.file(_photo!, fit: BoxFit.cover),
                        )
                      : const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate, size: 40, color: ChatMeColors.violet),
                              SizedBox(height: 8),
                              Text('Choisir une photo', style: TextStyle(color: ChatMeColors.violet)),
                            ],
                          ),
                        ),
                ),
              ),
            const SizedBox(height: 20),
            const Text('DURÉE DE VISIBILITÉ',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: ChatMeColors.inkSoft)),
            const SizedBox(height: 10),
            RadioGroup<int>(
              groupValue: _custom ? -1 : _duration,
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    if (v == -1) {
                      _custom = true;
                    } else {
                      _duration = v;
                      _custom = false;
                    }
                  });
                }
              },
              child: Column(
                children: [
                  ..._presets.map((p) => Row(
                        children: [
                          Radio<int>(
                            value: p['min'] as int,
                            activeColor: ChatMeColors.violet,
                          ),
                          Text(p['label'] as String),
                        ],
                      )),
                  Row(
                    children: [
                      const Radio<int>(
                        value: -1,
                        activeColor: ChatMeColors.violet,
                      ),
                      const Text('Personnalisé : '),
                      SizedBox(
                        width: 70,
                        child: TextField(
                          controller: _customCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            isCollapsed: true,
                            hintText: 'min',
                            contentPadding: EdgeInsets.symmetric(vertical: 6),
                          ),
                          onChanged: (_) => setState(() => _custom = true),
                        ),
                      ),
                      const Text(' min'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ChatMeColors.violetPale,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Vos contacts pourront voir ce statut pendant ${_formatDuration(_custom ? (int.tryParse(_customCtrl.text) ?? _duration) : _duration)}.',
                style: const TextStyle(fontSize: 12.5, color: ChatMeColors.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TypeChip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: active ? ChatMeColors.violet : ChatMeColors.violetPale,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(color: active ? Colors.white : ChatMeColors.violet, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
