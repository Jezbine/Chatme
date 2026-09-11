import 'package:flutter/material.dart';

class AvatarViewerScreen extends StatelessWidget {
  final String? imageUrl;
  final String initials;
  final String name;
  const AvatarViewerScreen({super.key, this.imageUrl, required this.initials, required this.name});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(name, style: const TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: Hero(
          tag: 'avatar_${imageUrl ?? initials}',
          child: imageUrl != null && imageUrl!.isNotEmpty
              ? InteractiveViewer(
                  child: Image.network(
                    imageUrl!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => _fallback(),
                  ),
                )
              : _fallback(),
        ),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      width: 200,
      height: 200,
      decoration: const BoxDecoration(color: Color(0xFF3C3489), shape: BoxShape.circle),
      child: Center(child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 64, fontWeight: FontWeight.w700))),
    );
  }
}
