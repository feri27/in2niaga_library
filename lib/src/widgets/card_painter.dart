import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class CardPainter extends CustomPainter {
  CardPainter(
      this.cardRect, this.passedCard, this.absoluteImageSize, this.rotation);

  final Rect cardRect;
  final bool passedCard;
  final Size absoluteImageSize;
  final InputImageRotation rotation;

  @override
  void paint(Canvas canvas, Size size) {
    double left = translateX(cardRect.left, rotation, size, absoluteImageSize);
    double top = translateY(cardRect.top, rotation, size, absoluteImageSize);
    double right =
        translateX(cardRect.right, rotation, size, absoluteImageSize);
    double bottom =
        translateY(cardRect.bottom, rotation, size, absoluteImageSize);

    final Paint paintLeft = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = passedCard ? Colors.green.withOpacity(0.8) : Colors.white;
    canvas.drawLine(Offset(left, top), Offset(left, bottom), paintLeft);

    final Paint paintTop = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = passedCard ? Colors.green.withOpacity(0.8) : Colors.white;
    canvas.drawLine(Offset(left, top), Offset(right, top), paintTop);

    final Paint paintRight = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = passedCard ? Colors.green.withOpacity(0.8) : Colors.white;
    canvas.drawLine(Offset(right, top), Offset(right, bottom), paintRight);

    final Paint paintBottom = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = passedCard ? Colors.green.withOpacity(0.8) : Colors.white;
    canvas.drawLine(Offset(left, bottom), Offset(right, bottom), paintBottom);
  }

  @override
  bool shouldRepaint(CardPainter oldDelegate) {
    return oldDelegate.absoluteImageSize != absoluteImageSize ||
        oldDelegate.passedCard != passedCard;
  }

  double translateX(double x, InputImageRotation rotation, Size size,
      Size absoluteImageSize) {
    switch (rotation) {
      case InputImageRotation.rotation90deg:
        return x *
            size.width /
            (Platform.isIOS
                ? absoluteImageSize.width
                : absoluteImageSize.height);
      case InputImageRotation.rotation270deg:
        return size.width -
            x *
                size.width /
                (Platform.isIOS
                    ? absoluteImageSize.width
                    : absoluteImageSize.height);
      default:
        return x * size.width / absoluteImageSize.width;
    }
  }

  double translateY(double y, InputImageRotation rotation, Size size,
      Size absoluteImageSize) {
    switch (rotation) {
      case InputImageRotation.rotation90deg:
      case InputImageRotation.rotation270deg:
        return y *
            size.height /
            (Platform.isIOS
                ? absoluteImageSize.height
                : absoluteImageSize.width);
      default:
        return y * size.height / absoluteImageSize.height;
    }
  }
}
