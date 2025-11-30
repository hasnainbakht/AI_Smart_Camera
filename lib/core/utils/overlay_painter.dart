import 'package:flutter/material.dart';

/// Simple overlay painter that can draw:
/// - Rule of Thirds grid
/// - Golden ratio spiral guide (approx using rectangles)
/// - Center cross
///
/// Configure booleans to show/hide each element and set line color/opacity.
class GridOverlayPainter extends CustomPainter {
  final bool showRuleOfThirds;
  final bool showGoldenRatio;
  final bool showCenterCross;
  final double strokeWidth;
  final Color lineColor;

  GridOverlayPainter({
    this.showRuleOfThirds = true,
    this.showGoldenRatio = false,
    this.showCenterCross = false,
    this.strokeWidth = 1.0,
    this.lineColor = Colors.white70,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    // Rule of Thirds (2 vertical, 2 horizontal)
    if (showRuleOfThirds) {
      final v1 = size.width / 3;
      final v2 = 2 * size.width / 3;
      final h1 = size.height / 3;
      final h2 = 2 * size.height / 3;

      canvas.drawLine(Offset(v1, 0), Offset(v1, size.height), paint);
      canvas.drawLine(Offset(v2, 0), Offset(v2, size.height), paint);
      canvas.drawLine(Offset(0, h1), Offset(size.width, h1), paint);
      canvas.drawLine(Offset(0, h2), Offset(size.width, h2), paint);
    }

    // Center Cross
    if (showCenterCross) {
      final cx = size.width / 2;
      final cy = size.height / 2;
      final crossLen = 20.0;
      canvas.drawLine(Offset(cx - crossLen, cy), Offset(cx + crossLen, cy), paint);
      canvas.drawLine(Offset(cx, cy - crossLen), Offset(cx, cy + crossLen), paint);
    }

    // Golden Ratio rectangles (approximate)
    if (showGoldenRatio) {
      // We'll draw nested rectangles using phi ~ 1.618
      const phi = 1.618;
      // Start with full rect, then shrink by phi progressively to suggest golden rectangles
      Rect rect = Offset.zero & size;
      for (int i = 0; i < 3; i++) {
        canvas.drawRect(rect, paint);
        // shrink horizontally or vertically alternating
        final w = rect.width / phi;
        final h = rect.height / phi;
        if (rect.width > rect.height) {
          rect = Rect.fromLTWH(rect.left, rect.top, w, rect.height);
        } else {
          rect = Rect.fromLTWH(rect.left, rect.top, rect.width, h);
        }
      }
      // Optionally draw a subtle spiral guide (approx using arc)
      final spiralPaint = Paint()
        ..color = lineColor.withOpacity(0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      final arcRect = Rect.fromCenter(
        center: Offset(size.width * 0.62, size.height * 0.38),
        width: size.width * 0.8,
        height: size.height * 0.8,
      );
      canvas.drawArc(arcRect, -1.2, 1.6, false, spiralPaint);
    }
  }

  @override
  bool shouldRepaint(covariant GridOverlayPainter oldDelegate) {
    return oldDelegate.showRuleOfThirds != showRuleOfThirds ||
        oldDelegate.showGoldenRatio != showGoldenRatio ||
        oldDelegate.showCenterCross != showCenterCross ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
