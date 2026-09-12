import 'package:flutter/material.dart';

class ChatHeader extends StatelessWidget {
  final String title;
  final List<Widget>? actions;

  const ChatHeader({super.key, required this.title, this.actions});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
          ),
          if (actions != null) ...actions!,
        ],
      ),
    );
  }
}

class HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const HeaderIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 34,
        height: 34,
        margin: const EdgeInsets.only(left: 12),
        decoration: BoxDecoration(
          color: cs.primary.withOpacity(0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: cs.primary, size: 18),
      ),
    );
  }
}
