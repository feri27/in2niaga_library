import 'package:flutter/material.dart';

//Add camera overlay UI to the plugin
class FaceboxPainter extends CustomPainter {
  final Color borderColor;

  FaceboxPainter(this.borderColor);

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint();
    Paint borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;

    paint.strokeWidth = 2.0;
    paint.color = Colors.black.withOpacity(0.7);

    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(size.width * 0.5, size.height * 0.5 - 10),
            width: size.width - 60,
            height: size.width - 20),
        borderPaint);

    canvas.drawPath(
      Path.combine(
        PathOperation.difference, //simple difference of following operations
        //bellow draws a rectangle of full screen (parent) size
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        //bellow clips out the circular rectangle with center as offset and dimensions you need to set
        Path()
          ..addOval(
            Rect.fromCenter(
              center: Offset(size.width * 0.5, size.height * 0.5 - 10),
              width: size.width - 60,
              height: size.width - 20,
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
