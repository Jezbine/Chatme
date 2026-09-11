import 'package:flutter/material.dart';

class FeatureTag extends StatelessWidget {
  final String label;

  const FeatureTag({required this.label, super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 16, color: cs.tertiary),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, color: cs.onSurface)),
        ],
      ),
    );
  }
}
