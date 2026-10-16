import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_animations.dart';

class CaptainOnlineToggle extends StatefulWidget {
  final bool isOnline;
  final ValueChanged<bool> onToggle;

  const CaptainOnlineToggle({
    super.key,
    required this.isOnline,
    required this.onToggle,
  });

  @override
  State<CaptainOnlineToggle> createState() => _CaptainOnlineToggleState();
}

class _CaptainOnlineToggleState extends State<CaptainOnlineToggle> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = widget.isOnline;

    return GestureDetector(
      onTap: () {
        HapticFeedback.heavyImpact();
        widget.onToggle(!isOnline);
      },
      child: AnimatedContainer(
        duration: AppAnimations.medium,
        curve: AppAnimations.spring,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          gradient: isOnline
              ? const LinearGradient(
                  colors: [Color(0xFF00C853), Color(0xFF00E676)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : LinearGradient(
                  colors: [Colors.grey.shade400, Colors.grey.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          borderRadius: BorderRadius.circular(36),
          boxShadow: [
            BoxShadow(
              color: (isOnline ? const Color(0xFF00C853) : Colors.grey).withValues(alpha: 0.4),
              blurRadius: isOnline ? 16 : 8,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isOnline)
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) => Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: _pulseController.value * 0.8),
                        blurRadius: 10,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                ),
              )
            else
              Container(
                width: 14,
                height: 14,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white70,
                ),
              ),
            const SizedBox(width: 12),
            Text(
              isOnline ? 'ONLINE • READY TO DRIVE' : 'OFFLINE • TAP TO GO ONLINE',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 14,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isOnline ? Icons.check_circle_rounded : Icons.power_settings_new_rounded,
              color: Colors.white,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
