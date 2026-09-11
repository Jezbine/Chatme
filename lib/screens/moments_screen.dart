import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../widgets/chat_header.dart';
import '../../widgets/chat_sheets.dart';
import '../../services/moments_service.dart';

class MomentsScreen extends StatelessWidget {
  const MomentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final moments = MomentsService.to;

    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            ChatHeader(
              title: 'Moments',
              actions: [
                HeaderIconButton(
                  icon: Icons.edit,
                  onPressed: () => showTextPostSheet(context),
                ),
                HeaderIconButton(
                  icon: Icons.camera_alt,
                  onPressed: () => showCameraSheet(context),
                ),
              ],
            ),
            Expanded(
              child: Obx(() {
                if (moments.moments.isEmpty) {
                  return Center(
                    child: Text('Aucun moment pour l\'instant',
                        style: TextStyle(color: cs.onSurfaceVariant)),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: moments.moments.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: cs.outline),
                  itemBuilder: (context, index) =>
                      _MomentCard(moment: moments.moments[index]),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _MomentCard extends StatefulWidget {
  final Moment moment;
  const _MomentCard({required this.moment});

  @override
  State<_MomentCard> createState() => _MomentCardState();
}

class _MomentCardState extends State<_MomentCard> {
  final TextEditingController _commentCtrl = TextEditingController();
  final FocusNode _focus = FocusNode();

  @override
  void dispose() {
    _commentCtrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final m = widget.moment;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Color(m.colorValue),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: Text(m.initials,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.name,
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: cs.onSurface)),
                  Text(m.time, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                ],
              ),
              const Spacer(),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'delete') {
                    Get.dialog(AlertDialog(
                      title: Text('Supprimer ?', style: TextStyle(color: cs.onSurface)),
                      content: Text('Voulez-vous supprimer ce moment ?', style: TextStyle(color: cs.onSurface)),
                      actions: [
                        TextButton(onPressed: () => Get.back(), child: const Text('Annuler')),
                        TextButton(
                            onPressed: () {
                              Get.back();
                              MomentsService.to.deleteMoment(m.id);
                              Get.snackbar('Moments', 'Moment supprimé', snackPosition: SnackPosition.BOTTOM);
                            },
                            child: const Text('Supprimer', style: TextStyle(color: Colors.red))),
                      ],
                    ));
                  } else if (v == 'edit') {
                    final ctrl = TextEditingController(text: m.text);
                    Get.dialog(AlertDialog(
                      title: Text('Modifier', style: TextStyle(color: cs.onSurface)),
                      content: TextField(
                          controller: ctrl,
                          maxLines: 4,
                          decoration: const InputDecoration(hintText: 'Texte', border: OutlineInputBorder())),
                      actions: [
                        TextButton(onPressed: () => Get.back(), child: const Text('Annuler')),
                        ElevatedButton(
                            onPressed: () {
                              final t = ctrl.text.trim();
                              if (t.isNotEmpty) MomentsService.to.updateMoment(m.id, t);
                              Get.back();
                            },
                            child: const Text('Enregistrer')),
                      ],
                    ));
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'edit', child: Text('Modifier', style: TextStyle(color: cs.onSurface))),
                  const PopupMenuItem(value: 'delete', child: Text('Supprimer', style: TextStyle(color: Colors.red))),
                ],
                icon: Icon(Icons.more_horiz, color: cs.onSurfaceVariant, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(m.text, style: TextStyle(fontSize: 13.5, color: cs.onSurface, height: 1.4)),
          if (m.photoPath != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: _buildMomentImage(m.photoPath!),
            )
          else
            Container(
              height: 150,
              margin: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  colors: [Color(0xFFDCEFE5), Color(0xFFEFEDFB)],
                ),
              ),
            ),
          Row(
            children: [
              _Action(
                text: m.liked ? '❤️ ${m.likes}' : '🤍 ${m.likes}',
                onTap: () => MomentsService.to.toggleLike(m.id),
              ),
              const SizedBox(width: 18),
              _Action(
                text: '💬 ${m.comments.length}',
                onTap: () => FocusScope.of(context).requestFocus(_focus),
              ),
              const SizedBox(width: 18),
              _Action(
                text: '🔁 Repartager',
                onTap: () async {
                  await MomentsService.to.repostMoment(m.id);
                  Get.snackbar('Repartagé', 'Moment repartagé à vos contacts', snackPosition: SnackPosition.BOTTOM);
                },
              ),
            ],
          ),
          if (m.comments.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: m.comments
                    .map((c) => Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(fontSize: 12.5, color: cs.onSurface),
                              children: [
                                TextSpan(
                                    text: '${c.author} ',
                                    style: const TextStyle(fontWeight: FontWeight.w600)),
                                TextSpan(text: c.text),
                              ],
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentCtrl,
                  focusNode: _focus,
                  decoration: InputDecoration(
                    hintText: 'Commenter…',
                    hintStyle: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
                    isCollapsed: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: InputBorder.none,
                  ),
                  style: TextStyle(fontSize: 12.5, color: cs.onSurface),
                  onSubmitted: (v) => _submit(),
                ),
              ),
              TextButton(
                onPressed: _submit,
                child: const Text('OK', style: TextStyle(fontSize: 12.5)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _submit() {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    MomentsService.to.addComment(widget.moment.id, text);
    _commentCtrl.clear();
  }

  Widget _buildMomentImage(String path) {
    // Supporte URL réseau (contacts) et fichier local
    if (path.startsWith('http')) {
      return Image.network(
        path,
        height: 200,
        width: double.infinity,
        fit: BoxFit.cover,
        loadingBuilder: (ctx, child, progress) => progress == null
            ? child
            : Container(height: 200, color: Theme.of(ctx).colorScheme.surfaceContainerHighest, child: const Center(child: CircularProgressIndicator())),
        errorBuilder: (_, __, ___) => Container(
          height: 200,
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFDCEFE5), Color(0xFFEFEDFB)])),
          child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
        ),
      );
    }
    return Image.file(
      File(path),
      height: 200,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        height: 200,
        decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFDCEFE5), Color(0xFFEFEDFB)])),
        child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _Action({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(text, style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
      ),
    );
  }
}
