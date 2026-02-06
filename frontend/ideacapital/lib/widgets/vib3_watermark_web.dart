// vib3_watermark_web.dart
// Web implementation using 'dart:ui_web'

import 'package:flutter/material.dart';
import 'dart:ui_web' as ui_web;
import 'package:web/web.dart' as web;

void registerVib3ViewFactory(String viewType, String configJson) {
  ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
    final element = web.document.createElement('div') as web.HTMLDivElement;
    element.style.width = '100%';
    element.style.height = '100%';
    element.setAttribute('data-system', 'quantum');
    element.setAttribute('data-config', configJson);
    return element;
  });
}

Widget buildVib3WebView(String viewType) {
  return HtmlElementView(viewType: viewType);
}
