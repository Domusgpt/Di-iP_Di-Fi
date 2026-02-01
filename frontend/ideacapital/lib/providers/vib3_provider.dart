import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Vib3+ shader engine configuration state.
class Vib3Config {
  final String activeSystem; // quantum, faceted, holographic
  final int geometry; // 0-23
  final double speed;
  final bool audioReactive;
  final Map<String, double> parameters;

  const Vib3Config({
    this.activeSystem = 'quantum',
    this.geometry = 10,
    this.speed = 1.0,
    this.audioReactive = false,
    this.parameters = const {},
  });

  Vib3Config copyWith({
    String? activeSystem,
    int? geometry,
    double? speed,
    bool? audioReactive,
    Map<String, double>? parameters,
  }) {
    return Vib3Config(
      activeSystem: activeSystem ?? this.activeSystem,
      geometry: geometry ?? this.geometry,
      speed: speed ?? this.speed,
      audioReactive: audioReactive ?? this.audioReactive,
      parameters: parameters ?? this.parameters,
    );
  }
}

/// Notifier for Vib3 engine configuration.
class Vib3Notifier extends StateNotifier<Vib3Config> {
  Vib3Notifier() : super(const Vib3Config());

  void switchSystem(String system) {
    state = state.copyWith(activeSystem: system);
  }

  void setGeometry(int geometry) {
    if (geometry >= 0 && geometry <= 23) {
      state = state.copyWith(geometry: geometry);
    }
  }

  void setSpeed(double speed) {
    state = state.copyWith(speed: speed.clamp(0.0, 5.0));
  }

  void toggleAudioReactive() {
    state = state.copyWith(audioReactive: !state.audioReactive);
  }

  void setParameter(String name, double value) {
    final updated = Map<String, double>.from(state.parameters);
    updated[name] = value;
    state = state.copyWith(parameters: updated);
  }

  void randomize() {
    final random = DateTime.now().millisecondsSinceEpoch;
    state = state.copyWith(
      geometry: random % 24,
      speed: (random % 30) / 10.0,
    );
  }
}

/// Global Vib3 configuration provider.
final vib3Provider = StateNotifierProvider<Vib3Notifier, Vib3Config>(
  (ref) => Vib3Notifier(),
);

/// Derived provider: whether shader backgrounds are enabled.
/// Users can disable for performance on low-end devices.
final vib3EnabledProvider = StateProvider<bool>((ref) => true);
