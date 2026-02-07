/// Vib3 Identity Protocol
///
/// Deterministically maps an Invention ID (or any string) to the visual parameters
/// of the Vib3 shader engine. This creates a unique "visual fingerprint" for each
/// piece of intellectual property on the platform.
///
/// Input: Hash (String) -> Output: Vib3Config
library vib3_identity;

import 'dart:convert';
import 'package:crypto/crypto.dart';

class Vib3Config {
  final int geometryType; // 0-22 (23 types)
  final double rotationX;
  final double rotationY;
  final double rotationZ;
  final double speed;
  final double zoom;
  final double distortion;
  final List<double> colorPrimary;   // [r, g, b]
  final List<double> colorSecondary; // [r, g, b]

  Vib3Config({
    required this.geometryType,
    required this.rotationX,
    required this.rotationY,
    required this.rotationZ,
    required this.speed,
    required this.zoom,
    required this.distortion,
    required this.colorPrimary,
    required this.colorSecondary,
  });

  // Convert to map for passing to JS/Shader
  Map<String, dynamic> toJson() => {
        'geometryType': geometryType,
        'rotation': {'x': rotationX, 'y': rotationY, 'z': rotationZ},
        'speed': speed,
        'zoom': zoom,
        'distortion': distortion,
        'colors': [colorPrimary, colorSecondary],
      };
}

class Vib3Identity {
  /// Generate the configuration from a seed string (e.g. invention_id).
  static Vib3Config generate(String seed) {
    // 1. Create a deterministic hash (SHA-256)
    final bytes = utf8.encode(seed);
    final hash = sha256.convert(bytes).bytes;

    // Helper to get a normalized float (0.0 - 1.0) from a byte byte index
    double getNorm(int index) => hash[index % hash.length] / 255.0;

    // Helper to get an integer range
    int getInt(int index, int max) => hash[index % hash.length] % max;

    // 2. Map hash bytes to parameters

    // Geometry: 23 types
    final geometryType = getInt(0, 23);

    // Rotations: -1.0 to 1.0 range
    final rotX = (getNorm(1) * 2.0) - 1.0;
    final rotY = (getNorm(2) * 2.0) - 1.0;
    final rotZ = (getNorm(3) * 2.0) - 1.0;

    // Speed: 0.1 to 2.0 (avoid 0/static)
    final speed = 0.1 + (getNorm(4) * 1.9);

    // Zoom: 0.5 to 3.0
    final zoom = 0.5 + (getNorm(5) * 2.5);

    // Distortion: 0.0 to 1.0
    final distortion = getNorm(6);

    // Colors: Use bytes 7-9 and 10-12
    final color1 = [getNorm(7), getNorm(8), getNorm(9)];
    final color2 = [getNorm(10), getNorm(11), getNorm(12)];

    return Vib3Config(
      geometryType: geometryType,
      rotationX: rotX,
      rotationY: rotY,
      rotationZ: rotZ,
      speed: speed,
      zoom: zoom,
      distortion: distortion,
      colorPrimary: color1,
      colorSecondary: color2,
    );
  }
}
