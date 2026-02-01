import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Vib3+ shader background widget.
/// On web: renders a live WebGL shader via HtmlElementView.
/// On native: renders a gradient placeholder.
class Vib3Background extends StatelessWidget {
  final String system; // 'quantum', 'faceted', 'holographic'
  final int geometry; // 0-23
  final double opacity;
  final Widget? child;

  const Vib3Background({
    super.key,
    this.system = 'quantum',
    this.geometry = 10,
    this.opacity = 0.3,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: kIsWeb
              ? _WebShaderView(system: system, geometry: geometry, opacity: opacity)
              : _NativeFallback(opacity: opacity),
        ),
        if (child != null) child!,
      ],
    );
  }
}

class _WebShaderView extends StatefulWidget {
  final String system;
  final int geometry;
  final double opacity;

  const _WebShaderView({
    required this.system,
    required this.geometry,
    required this.opacity,
  });

  @override
  State<_WebShaderView> createState() => _WebShaderViewState();
}

class _WebShaderViewState extends State<_WebShaderView> {
  // Use a unique view type for each instance
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = 'vib3-shader-${widget.system}-${widget.geometry}-${identityHashCode(this)}';
    // Platform view registration happens in web entrypoint (index.html)
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: widget.opacity,
      child: const HtmlElementView(viewType: 'vib3-shader-view'),
    );
  }
}

class _NativeFallback extends StatelessWidget {
  final double opacity;
  const _NativeFallback({required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0D0221),
              Color(0xFF0A1628),
              Color(0xFF1A0533),
              Color(0xFF0D0221),
            ],
          ),
        ),
      ),
    );
  }
}
