import 'dart:math';

import 'package:flutter/material.dart';

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

    // 1️⃣ Rule of Thirds
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

    // 2️⃣ Center Cross
    if (showCenterCross) {
      final cx = size.width / 2;
      final cy = size.height / 2;
      final crossLen = min(size.width, size.height) * 0.03; // scaled
      canvas.drawLine(Offset(cx - crossLen, cy), Offset(cx + crossLen, cy), paint);
      canvas.drawLine(Offset(cx, cy - crossLen), Offset(cx, cy + crossLen), paint);
    }

    // 3️⃣ Golden Ratio rectangles & spiral
    if (showGoldenRatio) {
      const phi = 1.618;
      Rect rect = Offset.zero & size;

      // Draw nested golden rectangles
      for (int i = 0; i < 3; i++) {
        canvas.drawRect(rect, paint);

        // Shrink according to longest side
        if (rect.width > rect.height) {
          final newWidth = rect.width / phi;
          rect = Rect.fromLTWH(rect.left, rect.top, newWidth, rect.height);
        } else {
          final newHeight = rect.height / phi;
          rect = Rect.fromLTWH(rect.left, rect.top, rect.width, newHeight);
        }
      }

      // Golden spiral arc (responsive)
      final spiralPaint = Paint()
        ..color = lineColor.withOpacity(0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;

      final arcRect = Rect.fromLTWH(
        size.width * 0.05,   // left
        size.height * 0.05,  // top
        size.width * 0.9,    // width
        size.height * 0.9,   // height
      );

      canvas.drawArc(arcRect, -pi / 2, pi * 0.8, false, spiralPaint);
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
