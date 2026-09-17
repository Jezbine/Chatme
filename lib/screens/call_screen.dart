import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:chatme/core/theme/chatme_theme.dart';
import 'package:chatme/services/call_service.dart';

class CallScreen extends StatefulWidget {
  final String conversationId;
  final String otherUserId;
  final String name;
  final String initials;
  final bool isVideo;
  final String? photoUrl;

  const CallScreen({
    required this.conversationId,
    required this.otherUserId,
    required this.name,
    required this.initials,
    this.isVideo = false,
    this.photoUrl,
    super.key,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> with WidgetsBindingObserver {
  final CallService _callService = CallService.to;
  
  bool _connected = false;
  int _seconds = 0;
  Timer? _timer;
  Timer? _connectTimeout;
  
  late final StreamSubscription<bool> _inCallSub;
  late final StreamSubscription<bool> _mutedSub;
  late final StreamSubscription<bool> _videoEnabledSub;
  late final StreamSubscription<bool> _speakerSub;
  late final StreamSubscription<String> _statusSub;
  late final StreamSubscription<RemoteVideoTrack?> _remoteVideoSub;
  late final StreamSubscription<RemoteAudioTrack?> _remoteAudioSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _requestPermissions();
    _listenToCallService();
    _startCall();
  }

  Future<void> _requestPermissions() async {
    await Permission.microphone.request();
    if (widget.isVideo) {
      await Permission.camera.request();
    }
  }

  void _listenToCallService() {
    _inCallSub = _callService.isInCall.listen((inCall) {
      if (mounted) {
        setState(() => _connected = inCall);
        if (inCall) {
          _startTimer();
          _connectTimeout?.cancel();
        } else if (!_connected) {
          _cleanupAndExit();
        }
      }
    });

    _mutedSub = _callService.isMuted.listen((_) => mounted ? setState(() {}) : null);
    _videoEnabledSub = _callService.isVideoEnabled.listen((_) => mounted ? setState(() {}) : null);
    _speakerSub = _callService.isSpeakerOn.listen((_) => mounted ? setState(() {}) : null);
    _statusSub = _callService.callStatus.listen((_) => mounted ? setState(() {}) : null);
    _remoteVideoSub = _callService.remoteVideoTrack.listen((_) => mounted ? setState(() {}) : null);
    _remoteAudioSub = _callService.remoteAudioTrack.listen((_) => mounted ? setState(() {}) : null);
  }

  Future<void> _startCall() async {
    _connectTimeout = Timer(const Duration(seconds: 30), () {
      if (mounted && !_connected) {
        _callService.leaveCall();
        Get.snackbar('Appel', 'Délai de connexion dépassé', snackPosition: SnackPosition.BOTTOM);
        Get.back();
      }
    });

    try {
      await _callService.joinCall(
        conversationId: widget.conversationId,
        otherUserId: widget.otherUserId,
        otherUserName: widget.name,
        isVideo: widget.isVideo,
      );
    } catch (e) {
      if (mounted) {
        _connectTimeout?.cancel();
        Get.snackbar('Erreur', 'Impossible de démarrer l\'appel: $e', snackPosition: SnackPosition.BOTTOM);
        Get.back();
      }
    }
  }

  void _startTimer() {
    _seconds = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  String get _duration {
    final m = _seconds ~/ 60;
    final s = _seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _connectTimeout?.cancel();
    _inCallSub.cancel();
    _mutedSub.cancel();
    _videoEnabledSub.cancel();
    _speakerSub.cancel();
    _statusSub.cancel();
    _remoteVideoSub.cancel();
    _remoteAudioSub.cancel();
    if (_connected) {
      _callService.leaveCall();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Keep call active in background
    } else if (state == AppLifecycleState.resumed) {
      // Resume video if needed
    }
  }

  void _cleanupAndExit() {
    _timer?.cancel();
    _connectTimeout?.cancel();
    if (mounted) Get.back();
  }

  void _toggleMute() {
    _callService.toggleMute();
  }

  void _toggleVideo() {
    _callService.toggleVideo();
  }

  void _switchCamera() {
    _callService.switchCamera();
  }

  void _toggleSpeaker() {
    _callService.toggleSpeaker();
  }

  void _endCall() {
    _callService.leaveCall();
    Get.back();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF12101F),
      body: SafeArea(
        child: Stack(
          children: [
            // Remote video (fullscreen)
            if (widget.isVideo && _connected && _callService.remoteVideoTrack.value != null)
              Positioned.fill(
                child: VideoTrackRenderer(
                  _callService.remoteVideoTrack.value!,
                  fit: VideoViewFit.cover,
                ),
              ),

            // Local video preview (picture-in-picture)
            if (widget.isVideo && _connected && _callService.localVideo != null)
              Positioned(
                top: 60,
                right: 16,
                width: 120,
                height: 160,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: VideoTrackRenderer(
                    _callService.localVideo!,
                    fit: VideoViewFit.cover,
                    mirrorMode: VideoViewMirrorMode.mirror,
                  ),
                ),
              ),

            // Call info overlay
            Positioned(
              top: 40,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFF1B8A5A),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'LiveKit Cloud HD',
                          style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _callService.callStatus.value.isNotEmpty 
                        ? _callService.callStatus.value 
                        : (_connected ? 'En appel' : 'Connexion…'),
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.name,
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _connected ? _duration : 'Sonnerie…',
                    style: const TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                ],
              ),
            ),

            // Audio-only avatar
            if (!widget.isVideo || !_connected || _callService.remoteVideoTrack.value == null)
              Center(
                child: CircleAvatar(
                  radius: 80,
                  backgroundColor: widget.isVideo ? ChatMeColors.violet : _callService.isVideoCall.value ? ChatMeColors.violet : Theme.of(context).colorScheme.primary,
                  backgroundImage: widget.photoUrl != null ? NetworkImage(widget.photoUrl!) : null,
                  child: widget.photoUrl == null
                      ? Text(
                          widget.initials,
                          style: const TextStyle(fontSize: 48, color: Colors.white, fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
              ),

            // Local video preview for audio calls (when camera enabled)
            if (!widget.isVideo && _connected && _callService.isVideoEnabled.value && _callService.localVideo != null)
              Positioned(
                top: 200,
                right: 16,
                width: 100,
                height: 140,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: VideoTrackRenderer(
                    _callService.localVideo!,
                    fit: VideoViewFit.cover,
                    mirrorMode: VideoViewMirrorMode.mirror,
                  ),
                ),
              ),

            // Bottom controls
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 30),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _RoundButton(
                      icon: _callService.isMuted.value ? Icons.mic_off : Icons.mic,
                      label: 'Muet',
                      active: _callService.isMuted.value,
                      onTap: _toggleMute,
                    ),
                    if (widget.isVideo || _callService.isVideoCall.value)
                      _RoundButton(
                        icon: Icons.flip_camera_android,
                        label: _callService.isVideoEnabled.value ? 'Caméra' : 'Caméra off',
                        active: _callService.isVideoEnabled.value,
                        onTap: _callService.isVideoEnabled.value ? _switchCamera : _toggleVideo,
                      ),
                    _RoundButton(
                      icon: _callService.isSpeakerOn.value ? Icons.volume_up : Icons.volume_down,
                      label: 'Haut-parleur',
                      active: _callService.isSpeakerOn.value,
                      onTap: _toggleSpeaker,
                    ),
                    Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      child: IconButton(
                        icon: const Icon(Icons.call_end, color: Colors.white, size: 30),
                        onPressed: _endCall,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Connecting overlay
            if (!_connected)
              Positioned.fill(
                child: Container(
                  color: const Color(0xFF12101F),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(ChatMeColors.violetLight),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _callService.callStatus.value.isNotEmpty 
                              ? _callService.callStatus.value 
                              : 'Connexion en cours…',
                          style: const TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _RoundButton({required this.icon, required this.label, this.active = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: active ? ChatMeColors.violetLight : Colors.white12,
            shape: BoxShape.circle,
          ),
          child: IconButton(icon: Icon(icon, color: Colors.white), onPressed: onTap),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }
}