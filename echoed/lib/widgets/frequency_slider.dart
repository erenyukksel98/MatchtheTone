import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants.dart';

/// ---------------------------------------------------------------------------
/// FrequencySlider — a vertical logarithmic slider for frequency recreation.
///
/// • Drag range maps linearly to log frequency space (perceptually even).
/// • Displays live Hz readout above the thumb.
/// • Haptic feedback on movement threshold.
/// • Speaker button triggers a preview callback.
/// ---------------------------------------------------------------------------
class FrequencySlider extends StatefulWidget {
  const FrequencySlider({
    super.key,
    required this.index,
    required this.initialHz,
    required this.onChanged,
    required this.onPreviewTap,
    this.minHz = AppConstants.minFrequencyHz,
    this.maxHz = AppConstants.maxFrequencyHz,
    this.height = 280,
  });

  final int index;
  final double initialHz;
  final ValueChanged<double> onChanged;
  final VoidCallback onPreviewTap;
  final double minHz;
  final double maxHz;
  final double height;

  @override
  State<FrequencySlider> createState() => _FrequencySliderState();
}

class _FrequencySliderState extends State<FrequencySlider>
    with SingleTickerProviderStateMixin {
  late double _currentHz;

  // Maps hz to normalized position [0, 1] on log scale
  double _hzToPosition(double hz) {
    final logMin = math.log(widget.minHz);
    final logMax = math.log(widget.maxHz);
    return (math.log(hz) - logMin) / (logMax - logMin);
  }

  // Maps normalized position [0, 1] to hz
  double _positionToHz(double pos) {
    final logMin = math.log(widget.minHz);
    final logMax = math.log(widget.maxHz);
    return math.exp(logMin + pos.clamp(0.0, 1.0) * (logMax - logMin));
  }

  double _lastHapticHz = 0;
  static const double _hapticThresholdCents = 25;

  late final AnimationController _glowController;
  late final Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _currentHz = widget.initialHz;

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _glowAnim = CurvedAnimation(parent: _glowController, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  void _onVerticalDrag(double dy, double totalHeight) {
    final sliderHeight = totalHeight - 60; // reserve space for label + button
    final delta = -dy / sliderHeight;
    final currentPos = _hzToPosition(_currentHz);
    final newPos = (currentPos + delta).clamp(0.0, 1.0);
    final newHz = _positionToHz(newPos);
    final rounded = (newHz * 10).round() / 10.0;

    if (rounded == _currentHz) return;

    // Haptic feedback every ~25 cents
    final cents = (1200 * math.log(rounded / _lastHapticHz.max(1)) / math.ln2).abs();
    if (cents >= _hapticThresholdCents) {
      HapticFeedback.selectionClick();
      _lastHapticHz = rounded;
    }

    setState(() => _currentHz = rounded);
    widget.onChanged(rounded);

    _glowController
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    final position = _hzToPosition(_currentHz);

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalHeight = widget.height;
        final trackHeight = totalHeight - 80; // top label + bottom button

        return SizedBox(
          width: 56,
          height: totalHeight,
          child: Column(
            children: [
              // Hz readout
              Container(
                height: 28,
                alignment: Alignment.center,
                child: Text(
                  '${_currentHz.toStringAsFixed(0)} Hz',
                  style: AppTextStyles.freqReadout.copyWith(fontSize: 12),
                ),
              ),
              const SizedBox(height: 4),

              // Track + thumb
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragUpdate: (d) {
                    _onVerticalDrag(d.delta.dy, trackHeight);
                  },
                  child: AnimatedBuilder(
                    animation: _glowAnim,
                    builder: (context, _) {
                      return CustomPaint(
                        size: Size(56, trackHeight),
                        painter: _SliderTrackPainter(
                          position: position,
                          glowIntensity: _glowAnim.value,
                          toneIndex: widget.index,
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 4),

              // Preview speaker button
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  widget.onPreviewTap();
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(
                    Icons.volume_up_rounded,
                    color: AppColors.textSecondary,
                    size: 18,
                  ),
                ),
              ),

              const SizedBox(height: 4),

              // Tone number label
              Text(
                '${widget.index + 1}',
                style: AppTextStyles.labelLarge,
              ),
            ],
          ),
        );
      },
    );
  }
}

extension _DoubleExt on double {
  double max(double other) => math.max(this, other);
}

/// Custom painter for the vertical slider track and thumb.
class _SliderTrackPainter extends CustomPainter {
  _SliderTrackPainter({
    required this.position, // 0 = bottom, 1 = top
    required this.glowIntensity, // 0–1
    required this.toneIndex,
  });

  final double position;
  final double glowIntensity;
  final int toneIndex;

  // Each tone gets a distinct hue within the primary palette
  static const List<Color> _toneColors = [
    Color(0xFF7B6EF6), // indigo
    Color(0xFF6EA8F6), // blue
    Color(0xFF6EF6D4), // teal
    Color(0xFFD46EF6), // violet
    Color(0xFFF6A06E), // orange
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final color = _toneColors[toneIndex % _toneColors.length];
    const trackWidth = 6.0;
    const thumbRadius = 10.0;
    final centerX = size.width / 2;

    // Thumb Y position (inverted: 1 = top, 0 = bottom)
    final thumbY = size.height * (1 - position);

    // ── Inactive track (below thumb) ───────────────────────────────
    final inactiveRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(centerX - trackWidth / 2, thumbY, trackWidth, size.height - thumbY),
      const Radius.circular(3),
    );
    canvas.drawRRect(
      inactiveRect,
      Paint()..color = AppColors.border,
    );

    // ── Active track (above thumb) — gradient ──────────────────────
    final activeRect = Rect.fromLTWH(centerX - trackWidth / 2, 0, trackWidth, thumbY);
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        color.withOpacity(0.9),
        color.withOpacity(0.3),
      ],
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(activeRect, const Radius.circular(3)),
      Paint()..shader = gradient.createShader(activeRect),
    );

    // ── Glow behind thumb ──────────────────────────────────────────
    if (glowIntensity > 0) {
      canvas.drawCircle(
        Offset(centerX, thumbY),
        thumbRadius * 2.5,
        Paint()
          ..color = color.withOpacity(0.25 * glowIntensity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }

    // ── Thumb circle ────────────────────────────────────────────────
    canvas.drawCircle(
      Offset(centerX, thumbY),
      thumbRadius,
      Paint()..color = AppColors.sliderThumb,
    );
    canvas.drawCircle(
      Offset(centerX, thumbY),
      thumbRadius,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Inner dot
    canvas.drawCircle(
      Offset(centerX, thumbY),
      3,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_SliderTrackPainter old) =>
      old.position != position || old.glowIntensity != glowIntensity;
}
