import 'package:flutter/material.dart';
import '../utils/vib3_identity.dart';

/// A unique visual watermark for an invention, generated procedurally via Vib3.
/// This widget replaces the "loud" full-screen background with a subtle, identity-based seal.
class Vib3Watermark extends StatelessWidget {
  final String seed;
  final double size;
  final double opacity;

  const Vib3Watermark({
    super.key,
    required this.seed,
    this.size = 100.0,
    this.opacity = 0.8,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Generate the unique configuration for this seed
    final config = Vib3Identity.generate(seed);

    // 2. Render the "Seal"
    // Since we don't have the actual WebGL engine running in this Dart environment,
    // we simulate the visual result using a CustomPainter that approximates the
    // Vib3 aesthetic (geometric shapes + gradients) based on the config.
    // In a full web build, this would wrap the HtmlElementView for the shader.

    return Opacity(
      opacity: opacity,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              Color.fromARGB(
                255,
                (config.colorPrimary[0] * 255).toInt(),
                (config.colorPrimary[1] * 255).toInt(),
                (config.colorPrimary[2] * 255).toInt(),
              ),
              Color.fromARGB(
                255,
                (config.colorSecondary[0] * 255).toInt(),
                (config.colorSecondary[1] * 255).toInt(),
                (config.colorSecondary[2] * 255).toInt(),
              ),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(2, 2),
            ),
          ],
        ),
        child: CustomPaint(
          painter: _Vib3GeometricPainter(config),
        ),
      ),
    );
  }
}

class _Vib3GeometricPainter extends CustomPainter {
  final Vib3Config config;

  _Vib3GeometricPainter(this.config);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final paint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Simulate 23 geometry types with basic shape variations
    // This is a placeholder for the actual 4D shader render

    canvas.save();
    // Apply "rotation" from config
    canvas.translate(center.dx, center.dy);
    canvas.rotate(config.rotationZ * 3.14);
    canvas.translate(-center.dx, -center.dy);

    if (config.geometryType % 3 == 0) {
      // Circle-based
      canvas.drawCircle(center, radius * 0.6 * config.zoom, paint);
      canvas.drawCircle(center, radius * 0.4 * config.zoom, paint);
    } else if (config.geometryType % 3 == 1) {
      // Rect-based
      final rectSize = radius * 1.2 * config.zoom;
      canvas.drawRect(
        Rect.fromCenter(center: center, width: rectSize, height: rectSize),
        paint,
      );
    } else {
      // Line-based (Polygon approximation)
      final path = Path();
      path.moveTo(center.dx, center.dy - (radius * 0.8));
      path.lineTo(center.dx + (radius * 0.7), center.dy + (radius * 0.5));
      path.lineTo(center.dx - (radius * 0.7), center.dy + (radius * 0.5));
      path.close();
      canvas.drawPath(path, paint);
    }

    // "Distortion" effect lines
    if (config.distortion > 0.5) {
      final p2 = Paint()
        ..color = Colors.white.withOpacity(0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      canvas.drawLine(
        Offset(0, size.height * 0.5),
        Offset(size.width, size.height * 0.5),
        p2
      );
      canvas.drawLine(
        Offset(size.width * 0.5, 0),
        Offset(size.width * 0.5, size.height),
        p2
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
