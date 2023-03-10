import 'package:flutter/material.dart';

class CirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint();

    paint.strokeWidth = 2.0;
    paint.color = Colors.black.withOpacity(0.7);

    canvas.drawPath(
      Path.combine(
        PathOperation.difference, //simple difference of following operations
        //bellow draws a rectangle of full screen (parent) size
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        //bellow clips out the circular rectangle with center as offset and dimensions you need to set
        Path()
          ..addOval(
            Rect.fromCenter(
              center: Offset(size.width * 0.5, size.width * 0.5 + 40),
              width: size.width - 40,
              height: size.width - 40,
            ),
          )
          ..close(),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
