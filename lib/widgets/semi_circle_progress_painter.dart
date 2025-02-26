import 'dart:math';
import 'package:flutter/material.dart';

class SemiCircleProgressPainter extends CustomPainter {
  final Color backgroundColor;
  final Color progressColor;
  final double strokeWidth;
  final double value;
  final StrokeCap strokeCap;
  final double strokeAlign;

  SemiCircleProgressPainter({
    required this.backgroundColor,
    required this.progressColor,
    required this.strokeWidth,
    required this.value,
    this.strokeCap = StrokeCap.round,
    this.strokeAlign = BorderSide.strokeAlignCenter,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // 绘制背景半圆
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = strokeCap;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi,
      pi,
      false,
      backgroundPaint,
    );

    // 绘制进度半圆
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = strokeCap;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi,
      pi * value,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(SemiCircleProgressPainter oldDelegate) {
    return oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.value != value ||
        oldDelegate.strokeCap != strokeCap ||
        oldDelegate.strokeAlign != strokeAlign;
  }
}