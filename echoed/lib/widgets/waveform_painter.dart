import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/constants.dart';

/// ---------------------------------------------------------------------------
/// WaveformPainter — renders two overlaid sine waves:
///   • "target" wave: thin, primary accent color
///   • "guess" wave: thicker, secondary accent color (only when both provided)
///
/// Frequency drives the visual wave density (higher Hz = more cycles shown).
/// This is entirely procedural — no image assets.
/// ---------------------------------------------------------------------------
class WaveformPainter extends CustomPainter {
  WaveformPainter({
    required this.targetHz,
    this.guessHz,
    this.animationValue = 1.0,
    this.targetColor = AppColors.accent,
    this.guessColor = AppColors.primary,
    this.showGuess = true,
  });

  final double targetHz;
  final double? guessHz;

  /// 0–1 animation progress (use with AnimationController).
  final double animationValue;

  final Color targetColor;
  final Color guessColor;
  final bool showGuess;

  @override
  void paint(Canvas canvas, Size size) {
    _drawWave(
      canvas: canvas,
      size: size,
      hz: targetHz,
      color: targetColor,
      strokeWidth: 1.5,
      phase: 0,
      amplitude: size.height * 0.35,
    );

    if (showGuess && guessHz != null) {
      _drawWave(
        canvas: canvas,
        size: size,
        hz: guessHz!,
        color: guessColor,
        strokeWidth: 2.5,
        phase: math.pi / 6, // slight phase offset for visual separation
        amplitude: size.height * 0.30,
      );
    }
  }

  void _drawWave({
    required Canvas canvas,
    required Size size,
    required double hz,
    required Color color,
    required double strokeWidth,
    required double phase,
    required double amplitude,
  }) {
    // Normalize Hz to a visual cycle count in [1.5, 6] — perceptually readable
    final logMin = math.log(AppConstants.minFrequencyHz);
    final logMax = math.log(AppConstants.maxFrequencyHz);
    final normalized = (math.log(hz) - logMin) / (logMax - logMin);
    final cycles = 1.5 + normalized * 4.5;

    final paint = Paint()
      ..color = color.withOpacity(0.85 * animationValue)
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    final centerY = size.height / 2;
    const steps = 200;

    for (int i = 0; i <= steps; i++) {
      final x = size.width * i / steps;
      // Wave draws progressively using animationValue
      final drawProgress = animationValue;
      final t = i / steps;
      if (t > drawProgress) break;

      final y = centerY +
          amplitude *
              math.sin(2 * math.pi * cycles * t + phase) *
              _envelope(t);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  /// Soft envelope: fade in at start, fade out at end.
  double _envelope(double t) {
    const fadeWidth = 0.05;
    if (t < fadeWidth) return t / fadeWidth;
    if (t > 1 - fadeWidth) return (1 - t) / fadeWidth;
    return 1.0;
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) {
    return oldDelegate.targetHz != targetHz ||
        oldDelegate.guessHz != guessHz ||
        oldDelegate.animationValue != animationValue;
  }
}

/// Animated waveform widget that draws and optionally animates in.
class AnimatedWaveform extends StatefulWidget {
  const AnimatedWaveform({
    super.key,
    required this.targetHz,
    this.guessHz,
    this.animate = true,
    this.height = 80,
    this.width = double.infinity,
  });

  final double targetHz;
  final double? guessHz;
  final bool animate;
  final double height;
  final double width;

  @override
  State<AnimatedWaveform> createState() => _AnimatedWaveformState();
}

class _AnimatedWaveformState extends State<AnimatedWaveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    if (widget.animate) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return CustomPaint(
          size: Size(widget.width, widget.height),
          painter: WaveformPainter(
            targetHz: widget.targetHz,
            guessHz: widget.guessHz,
            animationValue: _animation.value,
          ),
        );
      },
    );
  }
}

// ── Pulsing tone indicator ────────────────────────────────────────────────────

/// A compact pulsing waveform strip shown in the memorization phase for each tone.
class ToneIndicatorPainter extends CustomPainter {
  ToneIndicatorPainter({
    required this.hz,
    required this.pulseValue,
    required this.isActive,
    required this.hasBeenPlayed,
    required this.accentColor,
  });

  final double hz;
  final double pulseValue; // 0–1 from AnimationController
  final bool isActive;
  final bool hasBeenPlayed;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final logMin = math.log(AppConstants.minFrequencyHz);
    final logMax = math.log(AppConstants.maxFrequencyHz);
    final normalized = (math.log(hz) - logMin) / (logMax - logMin);
    final cycles = 1.0 + normalized * 3.0;

    final baseOpacity = hasBeenPlayed ? 0.9 : 0.4;
    final opacity = isActive
        ? baseOpacity * (0.7 + 0.3 * pulseValue)
        : baseOpacity;

    final paint = Paint()
      ..color = accentColor.withOpacity(opacity)
      ..strokeWidth = isActive ? 2.0 : 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    final centerY = size.height / 2;
    final amplitude = size.height * 0.3 * (isActive ? (0.8 + 0.2 * pulseValue) : 1.0);
    const steps = 60;

    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      final x = size.width * t;
      final y = centerY + amplitude * math.sin(2 * math.pi * cycles * t) * _env(t);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  double _env(double t) {
    const fw = 0.08;
    if (t < fw) return t / fw;
    if (t > 1 - fw) return (1 - t) / fw;
    return 1.0;
  }

  @override
  bool shouldRepaint(ToneIndicatorPainter old) =>
      old.pulseValue != pulseValue || old.isActive != isActive || old.hasBeenPlayed != hasBeenPlayed;
}
