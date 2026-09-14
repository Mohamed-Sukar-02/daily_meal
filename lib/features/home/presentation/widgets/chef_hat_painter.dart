import 'package:flutter/material.dart';

class ChefHatPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final hatPaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // A simple chef hat path
    final path = Path();
    path.moveTo(size.width * 0.2, size.height * 0.8);
    path.lineTo(size.width * 0.8, size.height * 0.8);
    path.lineTo(size.width * 0.8, size.height * 0.6);
    
    // Puffs
    path.quadraticBezierTo(size.width * 0.9, size.height * 0.5, size.width * 0.75, size.height * 0.4);
    path.quadraticBezierTo(size.width * 0.8, size.height * 0.1, size.width * 0.5, size.height * 0.2);
    path.quadraticBezierTo(size.width * 0.2, size.height * 0.1, size.width * 0.25, size.height * 0.4);
    path.quadraticBezierTo(size.width * 0.1, size.height * 0.5, size.width * 0.2, size.height * 0.6);
    
    path.close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, hatPaint);

    // Heart
    final heartPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;
      
    final heartPath = Path();
    double hX = size.width * 0.5;
    double hY = size.height * 0.45;
    double hSize = size.width * 0.15;
    
    heartPath.moveTo(hX, hY + hSize * 0.5);
    heartPath.cubicTo(
      hX + hSize, hY - hSize * 0.25, 
      hX + hSize * 1.5, hY + hSize * 0.5, 
      hX, hY + hSize * 1.5
    );
    heartPath.cubicTo(
      hX - hSize * 1.5, hY + hSize * 0.5, 
      hX - hSize, hY - hSize * 0.25, 
      hX, hY + hSize * 0.5
    );
    
    canvas.drawPath(heartPath, heartPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
