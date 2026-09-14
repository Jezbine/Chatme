import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MomentComment {
  final String author;
  final String text;
  MomentComment({required this.author, required this.text});

  Map<String, dynamic> toJson() => {'author': author, 'text': text};
  factory MomentComment.fromJson(Map<String, dynamic> j) =>
      MomentComment(author: j['author'] as String, text: j['text'] as String);
}

class Moment {
  final String id;
  final String name;
  final String initials;
  final int colorValue;
  final String time;
  final String text;
  final String? photoPath; // chemin local (image_picker)
  final int likes;
  final bool liked;
  final List<MomentComment> comments;

  Moment({
    required this.id,
    required this.name,
    required this.initials,
    required this.colorValue,
    required this.time,
    required this.text,
    this.photoPath,
    required this.likes,
    required this.liked,
    required this.comments,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'initials': initials,
        'colorValue': colorValue,
        'time': time,
        'text': text,
        'photoPath': photoPath,
        'likes': likes,
        'liked': liked,
        'comments': comments.map((c) => c.toJson()).toList(),
      };

  factory Moment.fromJson(Map<String, dynamic> j) => Moment(
        id: j['id'] as String,
        name: j['name'] as String,
        initials: j['initials'] as String,
        colorValue: j['colorValue'] as int,
        time: j['time'] as String,
        text: j['text'] as String,
        photoPath: j['photoPath'] as String?,
        likes: j['likes'] as int? ?? 0,
        liked: j['liked'] as bool? ?? false,
        comments: (j['comments'] as List? ?? [])
            .map((c) => MomentComment.fromJson(c as Map<String, dynamic>))
            .toList(),
      );
}

class MomentsService extends GetxService {
  static MomentsService get to => Get.find<MomentsService>();

  final RxList<Moment> moments = <Moment>[].obs;
  bool _supabaseAvailable = false;

  Future<MomentsService> init() async {
    // Audit 2.4 — tenter Supabase d'abord, fallback local si tables non déployées
    try {
      final client = Supabase.instance.client;
      if (client.auth.currentUser != null) {
        // Test si table moments existe en tentant une requête légère
        await client.from('moments').select('id').limit(1);
        _supabaseAvailable = true;
        await _fetchFromSupabase();
        // Realtime
        client.channel('moments').onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'moments', callback: (_) => _fetchFromSupabase()).subscribe();
        return this;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Moments] Supabase non disponible, fallback local: $e');
      _supabaseAvailable = false;
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('moments');
    if (raw == null) {
      // Aucune donnée en dur : liste vide au premier lancement
      moments.value = [];
      await _persist();
    } else {
      moments.value = raw
          .map((e) => Moment.fromJson(jsonDecode(e) as Map<String, dynamic>))
          .toList();
    }
    // Nettoyage : supprimer les anciens seeds hardcodés s'ils existent encore
    final hasSeed = moments.any((m) => m.id == 'm_seed_1' || m.id == 'm_seed_2');
    if (hasSeed) {
      moments.removeWhere((m) => m.id == 'm_seed_1' || m.id == 'm_seed_2');
      await _persist();
    }
    return this;
  }

  Future<String?> _uploadMomentMedia(String localPath) async {
    try {
      final client = Supabase.instance.client;
      final uid = client.auth.currentUser?.id;
      if (uid == null) return null;
      final file = File(localPath);
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      final ext = localPath.split('.').last.toLowerCase();
      final mime = ext == 'png' ? 'image/png' : ext == 'mp4' ? 'video/mp4' : ext == 'webp' ? 'image/webp' : 'image/jpeg';
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
      final storagePath = '$uid/moment_$fileName';
      final bucket = 'chat-media';
      await client.storage.from(bucket).uploadBinary(storagePath, bytes, fileOptions: FileOptions(contentType: mime, upsert: true));
      // Robustesse public/privé : privilégie signed 365j (marche dans les 2 cas)
      try {
        return await client.storage.from(bucket).createSignedUrl(storagePath, 60 * 60 * 24 * 365);
      } catch (_) {
        return client.storage.from(bucket).getPublicUrl(storagePath);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Moments] _uploadMomentMedia error: $e');
      return null;
    }
  }

  Future<void> _fetchFromSupabase() async {
    try {
      final client = Supabase.instance.client;
      final uid = client.auth.currentUser?.id;
      // Récupère moments avec profil, likes et commentaires
      // Schéma compatible : tente d'abord nouveau schéma (BLOQUANTS: content,image_url), fallback ancien (text,photo_path)
      dynamic rows;
      try {
        rows = await client
            .from('moments')
            .select('id, user_id, text, photo_path, likes_count, created_at, updated_at, profiles!moments_user_id_fkey(display_name)')
            .order('created_at', ascending: false)
            .limit(50);
      } catch (_) {
        rows = await client
            .from('moments')
            .select('id, user_id, content, image_url, created_at, profiles!moments_user_id_fkey(display_name)')
            .order('created_at', ascending: false)
            .limit(50);
      }
      final List<Moment> fetched = [];
      for (final r in rows as List) {
        final m = r as Map<String, dynamic>;
        final display = (m['profiles']?['display_name'] as String?) ?? 'Contact';
        final initials = display.isNotEmpty ? display.substring(0, display.length >= 2 ? 2 : 1).toUpperCase() : '?';
        final createdAt = DateTime.tryParse(m['created_at'].toString()) ?? DateTime.now();
        final timeAgo = _formatTimeAgo(createdAt);
        // Likes : compter via likes_count + vérifier si current user a liké
        int likes = (m['likes_count'] as int?) ?? 0;
        bool liked = false;
        List<MomentComment> comments = [];
        try {
          if (uid != null) {
            final likeRow = await client.from('moment_likes').select('user_id').eq('moment_id', m['id']).eq('user_id', uid).maybeSingle();
            liked = likeRow != null;
          }
          final commentRows = await client.from('moment_comments').select('text, user_id, profiles!moment_comments_user_id_fkey(display_name)').eq('moment_id', m['id']).order('created_at').limit(20);
          comments = (commentRows as List).map((c) {
            final cm = c as Map<String, dynamic>;
            final author = (cm['profiles']?['display_name'] as String?) ?? 'Contact';
            return MomentComment(author: author, text: cm['text'] as String? ?? '');
          }).toList();
          // Si likes_count est 0 mais il y a des likes, compter
          if (likes == 0) {
            final countRes = await client.from('moment_likes').select('user_id').eq('moment_id', m['id']);
            likes = (countRes as List).length;
          }
        } catch (_) {}
        fetched.add(Moment(
          id: m['id'] as String,
          name: display,
          initials: initials,
          colorValue: 0xFF3C3489,
          time: timeAgo,
          text: (m['text'] as String?) ?? (m['content'] as String?) ?? '',
          photoPath: (m['photo_path'] as String?) ?? (m['image_url'] as String?),
          likes: likes,
          liked: liked,
          comments: comments,
        ));
      }
      moments.value = fetched;
      await _persist();
      if (kDebugMode) debugPrint('[Moments] fetched ${fetched.length} from Supabase (visibles par contacts)');
    } catch (e) {
      if (kDebugMode) debugPrint('[Moments] _fetchFromSupabase error: $e');
    }
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return "à l'instant";
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes}min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
    if (diff.inDays == 1) return 'Hier';
    return 'Il y a ${diff.inDays}j';
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'moments',
      moments.map((m) => jsonEncode(m.toJson())).toList(),
    );
  }

  Future<void> toggleLike(String id) async {
    final i = moments.indexWhere((m) => m.id == id);
    if (i == -1) return;
    final m = moments[i];
    final liked = !m.liked;
    moments[i] = m.copyWith(
      liked: liked,
      likes: m.likes + (liked ? 1 : -1),
    );
    await _persist();
    if (_supabaseAvailable) {
      try {
        final client = Supabase.instance.client;
        final uid = client.auth.currentUser?.id;
        if (uid == null) return;
        if (liked) {
          await client.from('moment_likes').insert({'moment_id': id, 'user_id': uid});
        } else {
          await client.from('moment_likes').delete().eq('moment_id', id).eq('user_id', uid);
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[Moments] toggleLike Supabase error: $e');
      }
    }
  }

  Future<void> addComment(String id, String text) async {
    final i = moments.indexWhere((m) => m.id == id);
    if (i == -1) return;
    final m = moments[i];
    String author = 'Vous';
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user != null) {
        final profile = await client.from('profiles').select('display_name').eq('id', user.id).maybeSingle();
        author = (profile?['display_name'] as String?) ?? user.userMetadata?['display_name'] as String? ?? 'Vous';
      }
    } catch (_) {}
    final comments = [...m.comments, MomentComment(author: author, text: text)];
    moments[i] = m.copyWith(comments: comments);
    await _persist();
    if (_supabaseAvailable) {
      try {
        final client = Supabase.instance.client;
        final uid = client.auth.currentUser?.id;
        if (uid != null) await client.from('moment_comments').insert({'moment_id': id, 'user_id': uid, 'text': text});
      } catch (e) {
        if (kDebugMode) debugPrint('[Moments] addComment Supabase error: $e');
      }
    }
  }

  Future<void> addMoment({
    required String text,
    String? photoPath,
    String? name,
    String? initials,
    int? colorValue,
  }) async {
    // Nom / initiales dynamiques depuis l'utilisateur courant, plus de valeurs en dur
    String resolvedName = name ?? '';
    String resolvedInitials = initials ?? '';
    int resolvedColor = colorValue ?? 0xFF3C3489;
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user != null && (resolvedName.isEmpty || resolvedInitials.isEmpty)) {
        // Essayer de récupérer le profil courant
        final profile = await client.from('profiles').select('display_name').eq('id', user.id).maybeSingle();
        final displayName = (profile?['display_name'] as String?) ?? user.userMetadata?['display_name'] as String? ?? 'Vous';
        resolvedName = resolvedName.isEmpty ? displayName : resolvedName;
        if (resolvedInitials.isEmpty) {
          final parts = displayName.trim().split(RegExp(r'\s+'));
          resolvedInitials = parts.length >= 2
              ? (parts[0][0] + parts[1][0]).toUpperCase()
              : displayName.substring(0, displayName.length >= 2 ? 2 : 1).toUpperCase();
        }
      }
    } catch (_) {}
    if (resolvedName.isEmpty) resolvedName = 'Vous';
    if (resolvedInitials.isEmpty) resolvedInitials = resolvedName.substring(0, 1).toUpperCase();

    String? remotePhoto = photoPath;
    if (photoPath != null && photoPath.isNotEmpty && !photoPath.startsWith('http')) {
      final uploaded = await _uploadMomentMedia(photoPath);
      if (uploaded != null) remotePhoto = uploaded;
    }
    if (_supabaseAvailable) {
      try {
        final client = Supabase.instance.client;
        final uid = client.auth.currentUser?.id;
        if (uid != null) {
          // Essayer schéma récent (text/photo_path), fallback ancien (content/image_url)
          Map<String, dynamic> row;
          try {
            row = await client.from('moments').insert({'user_id': uid, 'text': text, 'photo_path': remotePhoto}).select().single();
          } catch (_) {
            row = await client.from('moments').insert({'user_id': uid, 'content': text, 'image_url': remotePhoto}).select().single();
          }
          moments.insert(0, Moment(id: row['id'] as String, name: resolvedName, initials: resolvedInitials, colorValue: resolvedColor, time: "à l'instant", text: text, photoPath: remotePhoto, likes: 0, liked: false, comments: const []));
          await _persist();
          return;
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[Moments] addMoment Supabase error: $e');
      }
    }
    moments.insert(
      0,
      Moment(
        id: 'm_${DateTime.now().millisecondsSinceEpoch}',
        name: resolvedName,
        initials: resolvedInitials,
        colorValue: resolvedColor,
        time: "à l'instant",
        text: text,
        photoPath: remotePhoto,
        likes: 0,
        liked: false,
        comments: const [],
      ),
    );
    await _persist();
  }

  /// Repartage un moment (repost) — crée un nouveau moment chez l'utilisateur courant
  Future<void> repostMoment(String originalId) async {
    final idx = moments.indexWhere((m) => m.id == originalId);
    if (idx == -1) return;
    final original = moments[idx];
    // Créer un nouveau moment avec référence à l'original
    final repostText = original.text.isNotEmpty ? '↻ ${original.text}' : '↻ Repartage';
    await addMoment(text: repostText, photoPath: original.photoPath);
    if (kDebugMode) debugPrint('[Moments] repost $originalId');
  }

  // WeChat Moments : suppression propriétaire, RLS user_id = auth.uid()
  Future<void> deleteMoment(String id) async {
    moments.removeWhere((m) => m.id == id);
    await _persist();
    if (_supabaseAvailable) {
      try {
        final uid = Supabase.instance.client.auth.currentUser?.id;
        if (uid != null) {
          await Supabase.instance.client.from('moments').delete().eq('id', id).eq('user_id', uid);
        } else {
          await Supabase.instance.client.from('moments').delete().eq('id', id);
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[Moments] deleteMoment supabase error: $e');
      }
    }
  }

  Future<void> updateMoment(String id, String newText) async {
    final i = moments.indexWhere((m) => m.id == id);
    if (i == -1) return;
    moments[i] = moments[i].copyWith(text: newText);
    await _persist();
    if (_supabaseAvailable) {
      try {
        // Gère les 2 schémas (text/photo_path vs content/image_url)
        try {
          await Supabase.instance.client.from('moments').update({'text': newText}).eq('id', id);
        } catch (_) {
          await Supabase.instance.client.from('moments').update({'content': newText}).eq('id', id);
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[Moments] updateMoment error: $e');
      }
    }
  }
}

extension _MomentCopy on Moment {
  Moment copyWith({
    String? name,
    String? time,
    String? text,
    String? photoPath,
    int? likes,
    bool? liked,
    List<MomentComment>? comments,
  }) =>
      Moment(
        id: id,
        name: name ?? this.name,
        initials: initials,
        colorValue: colorValue,
        time: time ?? this.time,
        text: text ?? this.text,
        photoPath: photoPath ?? this.photoPath,
        likes: likes ?? this.likes,
        liked: liked ?? this.liked,
        comments: comments ?? this.comments,
      );
}
