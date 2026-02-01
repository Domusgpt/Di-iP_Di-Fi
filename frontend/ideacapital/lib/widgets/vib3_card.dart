import 'package:flutter/material.dart';
import 'vib3_background.dart';

/// An invention card with an optional Vib3 shader background.
/// Each invention gets a unique geometry based on its ID hash.
class Vib3Card extends StatelessWidget {
  final String inventionId;
  final Widget child;
  final double height;
  final EdgeInsets padding;

  const Vib3Card({
    super.key,
    required this.inventionId,
    required this.child,
    this.height = 200,
    this.padding = const EdgeInsets.all(16),
  });

  int _geometryFromId(String id) {
    // Derive a consistent geometry index (0-23) from the invention ID
    int hash = 0;
    for (int i = 0; i < id.length; i++) {
      hash = (hash * 31 + id.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    return hash % 24;
  }

  String _systemFromId(String id) {
    final systems = ['quantum', 'faceted', 'holographic'];
    int hash = 0;
    for (int i = 0; i < id.length; i++) {
      hash = (hash * 37 + id.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    return systems[hash % 3];
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 4,
      child: SizedBox(
        height: height,
        child: Vib3Background(
          system: _systemFromId(inventionId),
          geometry: _geometryFromId(inventionId),
          opacity: 0.15,
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}
