// vib3_watermark_stub.dart
// Stub implementation for mobile platforms where 'dart:ui_web' is unavailable.

import 'package:flutter/material.dart';

void registerVib3ViewFactory(String viewType, String configJson) {
  // No-op on mobile
}

Widget buildVib3WebView(String viewType) {
  // Fallback to error or empty container if logic ever reaches here on mobile
  return const SizedBox.shrink();
}
