import 'dart:math';
import 'package:flutter/material.dart';

/// Audio waveform visualizer using CustomPainter
class Visualizer extends StatefulWidget {
  final bool isActive;

  const Visualizer({super.key, required this.isActive});

  @override
  State<Visualizer> createState() => _VisualizerState();
}

class _VisualizerState extends State<Visualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final Random _random = Random();
  late List<double> _bars;

  @override
  void initState() {
    super.initState();
    _bars = List.generate(40, (_) => 0.0);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    )..repeat();

    _controller.addListener(_updateBars);
  }

  void _updateBars() {
    if (widget.isActive) {
      setState(() {
        for (int i = 0; i < _bars.length; i++) {
          // Smooth interpolation toward random targets
          final target = _random.nextDouble();
          _bars[i] = _bars[i] * 0.7 + target * 0.3;
        }
      });
    } else {
      setState(() {
        for (int i = 0; i < _bars.length; i++) {
          _bars[i] = _bars[i] * 0.9; // Decay to zero
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: CustomPaint(
        painter: _WaveformPainter(bars: _bars, isActive: widget.isActive),
        size: Size.infinite,
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> bars;
  final bool isActive;

  _WaveformPainter({required this.bars, required this.isActive});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;

    final barWidth = size.width / bars.length;
    final centerY = size.height / 2;

    for (int i = 0; i < bars.length; i++) {
      final x = i * barWidth + barWidth / 2;
      final height = bars[i] * size.height * 0.8;

      // Gradient from cyan to fuchsia based on position
      final t = i / bars.length;
      final color = Color.lerp(
        const Color(0xFF22D3EE), // cyan-400
        const Color(0xFFD946EF), // fuchsia-500
        t,
      )!.withValues(alpha: isActive ? 0.8 : 0.3);

      paint.color = color;

      // Draw symmetric bars from center
      canvas.drawLine(
        Offset(x, centerY - height / 2),
        Offset(x, centerY + height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return true;
  }
}
