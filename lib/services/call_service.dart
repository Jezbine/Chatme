import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:chatme/config/supabase_config.dart';

class CallService extends GetxService {
  static CallService get to => Get.find<CallService>();

  Room? _room;
  LocalAudioTrack? _localAudio;
  LocalVideoTrack? _localVideo;

  final RxBool isInCall = false.obs;
  final RxBool isVideoCall = false.obs;
  final RxBool isMuted = false.obs;
  final RxBool isVideoEnabled = true.obs;
  final RxBool isSpeakerOn = true.obs;
  final RxString callStatus = ''.obs;
  final RxString currentRoomName = ''.obs;
  final Rx<RemoteVideoTrack?> remoteVideoTrack = Rx<RemoteVideoTrack?>(null);
  final Rx<RemoteAudioTrack?> remoteAudioTrack = Rx<RemoteAudioTrack?>(null);
  final RxString remoteParticipantIdentity = ''.obs;

  CancelListenFunc? _roomEventsSub;
  StreamSubscription? _participantSub;
  StreamSubscription? _trackSub;

  final SupabaseClient _client = SupabaseConfig.client;

  @override
  Future<void> onInit() async {
    super.onInit();
  }

  @override
  void onClose() {
    leaveCall();
    super.onClose();
  }

  Future<void> joinCall({
    required String conversationId,
    required String otherUserId,
    required String otherUserName,
    required bool isVideo,
  }) async {
    if (isInCall.value) return;

    isInCall.value = true;
    isVideoCall.value = isVideo;
    isMuted.value = false;
    isVideoEnabled.value = isVideo;
    currentRoomName.value = 'call_$conversationId';
    callStatus.value = 'Connexion...';

    _room = Room();

    try {
      // Fix: demander permissions avant création tracks (évite PlatformException)
      try {
        // permission_handler gère micro/caméra; on tente gracieusement
        final hasAudio = await _requestMicPermission();
        if (!hasAudio) throw Exception('Permission micro refusée');
        if (isVideo) {
          final hasCam = await _requestCameraPermission();
          if (!hasCam) throw Exception('Permission caméra refusée');
        }
      } catch (e) {
        if (e.toString().contains('Permission')) rethrow;
      }

      _localAudio = await LocalAudioTrack.create();
      
      if (isVideo) {
        _localVideo = await LocalVideoTrack.createCameraTrack();
      }

      _setupRoomListeners();

      final liveKitUrl = _getLiveKitUrl();
      if (liveKitUrl == null) {
        // Mode dégradé : pas de LiveKit configuré → garder l'appel local pour tester micro/caméra
        callStatus.value = 'Mode local — serveur LiveKit non configuré';
        isInCall.value = true;
        await Future.delayed(const Duration(milliseconds: 100));
        try {
          Get.snackbar('Appel (local)', 'Mode test local : micro/caméra OK, serveur LiveKit à configurer pour appels distants (--dart-define=LIVEKIT_URL)',
              snackPosition: SnackPosition.BOTTOM, backgroundColor: const Color(0xFF3C3489), colorText: Colors.white, duration: const Duration(seconds: 4));
        } catch (_) {}
        // Ne pas leaveCall() : garder LocalAudio/Video actifs pour preview
        return;
      }
      final token = await _fetchCallToken(conversationId, otherUserId);
      if (token == null) {
        // Token indisponible → fallback local au lieu de crash
        callStatus.value = 'Mode local — token indisponible';
        isInCall.value = true;
        try {
          Get.snackbar('Appel (local)', 'Token LiveKit indisponible (Edge Function create-call-token non déployée). Mode local activé.',
              snackPosition: SnackPosition.BOTTOM, backgroundColor: const Color(0xFF3C3489), colorText: Colors.white, duration: const Duration(seconds: 4));
        } catch (_) {}
        return;
      }

      await _room!.connect(
        liveKitUrl,
        token,
      );

      await _room!.localParticipant?.setMicrophoneEnabled(true);
      if (_localVideo != null) {
        await _room!.localParticipant?.setCameraEnabled(true);
      }

      callStatus.value = 'En appel';
    } catch (e) {
      if (kDebugMode) print('CallService joinCall error: $e');
      await leaveCall();
      callStatus.value = 'Erreur: $e';
      // Fix: ne pas rethrow (crash non catch côté UI) — afficher snackbar et laisser l'appelant gérer via callStatus
      try {
        Get.snackbar('Appel impossible', e.toString(),
            snackPosition: SnackPosition.BOTTOM, backgroundColor: const Color(0xFFFFFFFF), colorText: const Color(0xFF1A1A1A), duration: const Duration(seconds: 4));
      } catch (_) {}
      return;
    }
  }

  String? _getLiveKitUrl() {
    const envUrl = String.fromEnvironment('LIVEKIT_URL', defaultValue: '');
    if (envUrl.isNotEmpty) return envUrl;
    return null; // non bloquant : l'UI affichera "Bientôt disponible"
  }

  Future<String?> _fetchCallToken(String conversationId, String otherUserId) async {
    try {
      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId == null) return null;

      final response = await _client.functions.invoke(
        'create-call-token',
        body: {
          'room_name': 'call_$conversationId',
          'user_id': currentUserId,
          'user_name': _client.auth.currentUser?.userMetadata?['display_name'] ?? 'Utilisateur',
        },
      );

      if (response.data != null && response.data['token'] != null) {
        return response.data['token'] as String;
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('CallService _fetchCallToken error: $e');
      return null;
    }
  }

  void _setupRoomListeners() {
    _roomEventsSub = _room!.events.listen((event) {
      if (event is RoomConnectedEvent) {
        callStatus.value = 'En appel';
        isInCall.value = true;
      } else if (event is RoomDisconnectedEvent) {
        callStatus.value = 'Déconnecté';
        isInCall.value = false;
      } else if (event is RoomReconnectingEvent) {
        callStatus.value = 'Reconnexion...';
      } else if (event is RoomReconnectedEvent) {
        callStatus.value = 'En appel';
      } else if (event is ParticipantConnectedEvent) {
        remoteParticipantIdentity.value = event.participant.identity;
        callStatus.value = 'Connecté';
      } else if (event is ParticipantDisconnectedEvent) {
        callStatus.value = 'L\'autre participant a quitté';
        remoteVideoTrack.value = null;
        remoteAudioTrack.value = null;
      } else if (event is TrackSubscribedEvent) {
        if (event.track is RemoteVideoTrack) {
          remoteVideoTrack.value = event.track as RemoteVideoTrack;
        } else if (event.track is RemoteAudioTrack) {
          remoteAudioTrack.value = event.track as RemoteAudioTrack;
        }
      } else if (event is TrackUnsubscribedEvent) {
        if (event.track is RemoteVideoTrack) {
          remoteVideoTrack.value = null;
        } else if (event.track is RemoteAudioTrack) {
          remoteAudioTrack.value = null;
        }
      }
    });
  }

  Future<void> leaveCall() async {
    if (!isInCall.value && _room == null) return;

    try {
      _roomEventsSub?.call();
      await _participantSub?.cancel();
      await _trackSub?.cancel();
      await _room?.disconnect();
    } catch (e) {
      if (kDebugMode) print('CallService leaveCall error: $e');
    } finally {
      await _localAudio?.dispose();
      await _localVideo?.dispose();
      _localAudio = null;
      _localVideo = null;
      _room = null;
      isInCall.value = false;
      isVideoCall.value = false;
      isMuted.value = false;
      isVideoEnabled.value = false;
      isSpeakerOn.value = true;
      callStatus.value = '';
      currentRoomName.value = '';
      remoteVideoTrack.value = null;
      remoteAudioTrack.value = null;
      remoteParticipantIdentity.value = '';
    }
  }

  void toggleMute() {
    final newValue = !isMuted.value;
    isMuted.value = newValue;
    _room?.localParticipant?.setMicrophoneEnabled(!newValue);
  }

  void toggleVideo() {
    final newValue = !isVideoEnabled.value;
    isVideoEnabled.value = newValue;
    _room?.localParticipant?.setCameraEnabled(newValue);
  }

  void switchCamera() {
    _localVideo?.switchCamera('front');
  }

  void toggleSpeaker() {
    isSpeakerOn.value = !isSpeakerOn.value;
  }

  Future<bool> _requestMicPermission() async {
    try {
      final s = await Permission.microphone.request();
      return s.isGranted;
    } catch (_) {
      return true; // si permission_handler non dispo, laisser LiveKit gérer
    }
  }

  Future<bool> _requestCameraPermission() async {
    try {
      final s = await Permission.camera.request();
      return s.isGranted;
    } catch (_) {
      return true;
    }
  }

  LocalVideoTrack? get localVideo => _localVideo;
  LocalAudioTrack? get localAudio => _localAudio;
  Room? get room => _room;
}