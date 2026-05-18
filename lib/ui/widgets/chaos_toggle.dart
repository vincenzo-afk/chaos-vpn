import 'package:flutter/material.dart';

/// Large animated ON/OFF toggle button with a pulse animation when active.
class ChaosToggle extends StatefulWidget {
  final bool isActive;
  final VoidCallback onToggle;

  const ChaosToggle({
    super.key,
    required this.isActive,
    required this.onToggle,
  });

  @override
  State<ChaosToggle> createState() => _ChaosToggleState();
}

class _ChaosToggleState extends State<ChaosToggle>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(ChaosToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.value = 0.0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.isActive ? _pulseAnimation.value : 1.0,
          child: child,
        );
      },
      child: GestureDetector(
        onTap: widget.onToggle,
        child: Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: widget.isActive
                ? const LinearGradient(
                    colors: [Color(0xFF8B0000), Color(0xFFFF4500)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : const LinearGradient(
                    colors: [Color(0xFF2F2F2F), Color(0xFF1A1A1A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            boxShadow: widget.isActive
                ? [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.6),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.3),
                      blurRadius: 60,
                      spreadRadius: 10,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.isActive ? Icons.mic : Icons.mic_off,
                size: 56,
                color: widget.isActive ? Colors.white : Colors.grey,
              ),
              const SizedBox(height: 8),
              Text(
                widget.isActive ? 'ACTIVE' : 'STOPPED',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: widget.isActive ? Colors.white : Colors.grey,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
