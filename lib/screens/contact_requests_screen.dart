import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:chatme/services/contacts_service.dart';
import 'package:chatme/core/utils/string_extension.dart';
import 'package:chatme/core/theme/chatme_theme.dart';

class ContactRequestsScreen extends StatelessWidget {
  const ContactRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = ContactsService.to;
    return Scaffold(
      appBar: AppBar(title: const Text('Demandes de contact'), backgroundColor: ChatMeColors.violet, foregroundColor: Colors.white),
      body: Obx(() {
        final incoming = cs.incomingRequests;
        final outgoing = cs.outgoingRequests;
        if (incoming.isEmpty && outgoing.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.person_add_outlined, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text('Aucune demande', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text('Scannez le QR d\'un ami pour lui envoyer une demande', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7))),
          ]));
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (incoming.isNotEmpty) ...[
              Text('Reçues (${incoming.length})', style: const TextStyle(fontWeight: FontWeight.w700, color: ChatMeColors.violet)),
              const SizedBox(height: 8),
              ...incoming.map((r) => Card(child: ListTile(
                    leading: CircleAvatar(backgroundColor: ChatMeColors.violet, child: Text((r.fromName ?? '?').initials, style: const TextStyle(color: Colors.white))),
                    title: Text(r.fromName ?? r.fromUserId.substring(0,8)),
                    subtitle: Text('Il y a ${_timeAgo(r.createdAt)}'),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () async {
                        final ok = await cs.rejectRequest(r.id);
                        Get.snackbar(ok ? 'Refusée' : 'Erreur', ok ? 'Demande refusée' : 'Échec', snackPosition: SnackPosition.BOTTOM);
                      }),
                      IconButton(icon: const Icon(Icons.check, color: Colors.green), onPressed: () async {
                        final ok = await cs.acceptRequest(r.id, r.fromUserId, r.fromName ?? 'Ami');
                        Get.snackbar(ok ? 'Acceptée' : 'Erreur', ok ? 'Contact ajouté !' : 'Échec', snackPosition: SnackPosition.BOTTOM, backgroundColor: ok ? ChatMeColors.cProfil : null, colorText: Colors.white);
                      }),
                    ]),
                  ))),
              const SizedBox(height: 16),
            ],
            if (outgoing.isNotEmpty) ...[
              Text('Envoyées (${outgoing.length})', style: const TextStyle(fontWeight: FontWeight.w700, color: ChatMeColors.inkSoft)),
              const SizedBox(height: 8),
              ...outgoing.map((r) => Card(child: ListTile(
                    leading: const Icon(Icons.hourglass_top, color: ChatMeColors.inkSoft),
                    title: Text(r.toUserId.substring(0,8)),
                    subtitle: const Text('En attente de validation'),
                    trailing: IconButton(icon: const Icon(Icons.cancel_outlined), onPressed: () async {
                      await cs.rejectRequest(r.id);
                    }),
                  ))),
            ],
          ],
        );
      }),
    );
  }

  String _timeAgo(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return "à l'instant";
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24) return '${diff.inHours} h';
    return '${diff.inDays} j';
  }
}
