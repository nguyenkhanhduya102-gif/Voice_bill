import 'package:flutter/material.dart';

class WavePulse extends StatefulWidget {
  final double size;
  final Color color;

  const WavePulse({super.key, this.size = 90, this.color = const Color(0xFF4CAF50)});

  @override
  State<WavePulse> createState() => _WavePulseState();
}

class _WavePulseState extends State<WavePulse> {
  bool _scaleUp = true;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(
        begin: _scaleUp ? 0.95 : 1.05,
        end: _scaleUp ? 1.05 : 0.95,
      ),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      onEnd: () => setState(() => _scaleUp = !_scaleUp),
      child: Icon(Icons.mic, size: widget.size, color: widget.color),
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
    );
  }
}
