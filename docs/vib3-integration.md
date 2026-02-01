# Vib3+ Shader SDK Integration

IdeaCapital integrates the [Vib3+ SDK](https://github.com/Domusgpt/Vib3-CORE-Documented01-) to provide procedural 4D shader visualizations throughout the platform UI. This document covers the integration architecture, available widgets, and customization options.

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Flutter Widgets](#flutter-widgets)
4. [Web Loader](#web-loader)
5. [Riverpod Provider](#riverpod-provider)
6. [Customization](#customization)
7. [Performance Considerations](#performance-considerations)

---

## Overview

The Vib3+ SDK is a general-purpose 4D rotation visualization engine that renders real-time procedural shaders via WebGL/WebGPU. IdeaCapital uses it for:

- **Animated backgrounds** on key screens (feed, invention detail, invest flow)
- **Per-invention shader cards** where each invention gets a unique procedural visual derived from its ID
- **Brand identity** — the quantum lattice aesthetic reinforces the platform's technology-forward positioning

The SDK supports three visualization systems:

| System | Description |
|---|---|
| **Quantum** | 3D lattice field with ray marching, interference patterns |
| **Faceted** | 2D geometric tessellation with rotation-driven morphing |
| **Holographic** | Multi-layer composited depth effects with glow |

Each system supports 24 geometry variants (8 base shapes x 3 warp cores).

**SDK Source:** `https://github.com/Domusgpt/Vib3-CORE-Documented01-`
**Branch:** `claude/phase-5-hardening-a4Wzn`

---

## Architecture

```
┌─────────────────────────────────────────────────┐
│                Flutter App                       │
│                                                  │
│  ┌─────────────┐  ┌──────────────┐              │
│  │ Vib3Provider │  │ vib3Enabled  │  Riverpod    │
│  │   (config)   │  │  Provider    │  state mgmt  │
│  └──────┬──────┘  └──────┬───────┘              │
│         │                │                       │
│  ┌──────▼────────────────▼───────┐              │
│  │      Vib3Background Widget     │              │
│  │                                │              │
│  │   kIsWeb?                      │              │
│  │   ├── Yes → HtmlElementView    │              │
│  │   │         ↓                  │              │
│  │   │   vib3-loader.js           │              │
│  │   │   ↓                        │              │
│  │   │   WebGL2 Canvas            │              │
│  │   │   ↓                        │              │
│  │   │   Procedural Fragment      │              │
│  │   │   Shader (GLSL)            │              │
│  │   │                            │              │
│  │   └── No → Gradient Fallback   │              │
│  └────────────────────────────────┘              │
│                                                  │
│  ┌────────────────────────────────┐              │
│  │       Vib3Card Widget          │              │
│  │  (wraps Vib3Background +       │              │
│  │   derives geometry from ID)    │              │
│  └────────────────────────────────┘              │
└─────────────────────────────────────────────────┘
```

### Platform Strategy

- **Flutter Web**: Uses `HtmlElementView` to embed a WebGL canvas managed by `vib3-loader.js`. The loader registers a platform view factory that creates canvas elements and runs fragment shaders.
- **Flutter Native (iOS/Android)**: Falls back to an animated gradient. The full Vib3+ Flutter plugin (native FFI to C++ math core) can be integrated later for native shader rendering.

---

## Flutter Widgets

### `Vib3Background`

**File:** `frontend/ideacapital/lib/widgets/vib3_background.dart`

A full-area shader background that renders behind child content.

```dart
Vib3Background(
  system: 'quantum',   // 'quantum', 'faceted', 'holographic'
  geometry: 10,         // 0-23 (geometry variant index)
  opacity: 0.3,         // Background transparency
  child: YourContent(),
)
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `system` | `String` | `'quantum'` | Visualization system to render |
| `geometry` | `int` | `10` | Geometry variant (0-23) |
| `opacity` | `double` | `0.3` | Overlay transparency |
| `child` | `Widget?` | `null` | Content rendered on top |

### `Vib3Card`

**File:** `frontend/ideacapital/lib/widgets/vib3_card.dart`

A `Card` widget with a shader background derived from the invention ID.

```dart
Vib3Card(
  inventionId: 'abc-123-def',
  height: 200,
  child: Column(
    children: [
      Text('My Invention'),
      Text('Funding: 45%'),
    ],
  ),
)
```

The geometry and system are deterministically derived from the invention ID hash, so each invention always gets the same visual.

| Parameter | Type | Default | Description |
|---|---|---|---|
| `inventionId` | `String` | required | Used to derive geometry index |
| `child` | `Widget` | required | Card content |
| `height` | `double` | `200` | Card height |
| `padding` | `EdgeInsets` | `EdgeInsets.all(16)` | Content padding |

---

## Web Loader

**File:** `frontend/ideacapital/web/vib3-loader.js`

The JavaScript loader handles WebGL initialization for Flutter web builds. It:

1. Registers a Flutter platform view factory (`vib3-shader-view`)
2. Creates canvas elements with WebGL2 context
3. Compiles and runs a procedural fragment shader (ray-marched quantum lattice)
4. Manages the animation loop and cleanup on element removal

### Shader Details

The inline shader implements:

- **4D-inspired rotation**: 2D rotation functions applied to 3D coordinates, simulating 4D projections
- **Quantum lattice field**: Sinusoidal interference patterns creating a volumetric lattice
- **Ray marching**: 64-step sphere tracing with glow accumulation
- **Color palette**: Deep space blues with quantum violet and teal accents
- **Vignette**: Edge darkening for natural framing

To load the full Vib3+ SDK instead of the inline shader, update `VIB3_SDK_URL` in `vib3-loader.js` to point to a built version of the SDK.

### Including in index.html

Add this script tag to `frontend/ideacapital/web/index.html`:

```html
<script src="vib3-loader.js" defer></script>
```

---

## Riverpod Provider

**File:** `frontend/ideacapital/lib/providers/vib3_provider.dart`

### `vib3Provider`

A `StateNotifierProvider<Vib3Notifier, Vib3Config>` that manages the global shader configuration.

```dart
final config = ref.watch(vib3Provider);

// Switch system
ref.read(vib3Provider.notifier).switchSystem('holographic');

// Set geometry
ref.read(vib3Provider.notifier).setGeometry(15);

// Randomize
ref.read(vib3Provider.notifier).randomize();
```

### `vib3EnabledProvider`

A `StateProvider<bool>` that lets users disable shader backgrounds for performance.

```dart
final enabled = ref.watch(vib3EnabledProvider);

// Toggle off for low-end devices
ref.read(vib3EnabledProvider.notifier).state = false;
```

### Vib3Config Fields

| Field | Type | Default | Description |
|---|---|---|---|
| `activeSystem` | `String` | `'quantum'` | Current visualization system |
| `geometry` | `int` | `10` | Geometry variant (0-23) |
| `speed` | `double` | `1.0` | Animation speed multiplier (0-5) |
| `audioReactive` | `bool` | `false` | Whether to modulate from audio input |
| `parameters` | `Map<String, double>` | `{}` | Custom shader parameters |

---

## Customization

### Changing the Default System

Edit `vib3_provider.dart`:

```dart
Vib3Notifier() : super(const Vib3Config(activeSystem: 'holographic'));
```

### Using a Custom Color Palette

Modify the fragment shader in `vib3-loader.js`:

```glsl
// Replace the color lines in the main() function
col += vec3(0.1, 0.3, 0.8) * glow * 0.3;  // Primary color
col += vec3(0.6, 0.1, 0.9) * glow * 0.2;  // Secondary color
col += vec3(0.0, 0.8, 0.6) * pow(glow * 0.1, 2.0);  // Accent
```

### Integrating the Full SDK

For access to all 3 systems, 24 geometries, audio reactivity, and spatial input:

1. Build the Vib3+ SDK: `cd vib3-sdk && npm run build`
2. Copy the build output to `frontend/ideacapital/web/assets/vib3/`
3. Update `VIB3_SDK_URL` in `vib3-loader.js` to `'/assets/vib3/VIB3Engine.js'`
4. The loader will auto-detect the full SDK and use its visualization systems

---

## Performance Considerations

- **GPU usage**: The procedural shader runs a 64-step ray march per pixel per frame. On low-end devices, this can cause frame drops.
- **Resolution scaling**: The canvas auto-scales to `devicePixelRatio`. For performance, you can cap this at `1.0` in `vib3-loader.js`.
- **Disable option**: Use `vib3EnabledProvider` to let users turn off shader backgrounds.
- **Cleanup**: The `MutationObserver` in `vib3-loader.js` automatically cancels animation frames when canvases are removed from the DOM.
- **Native fallback**: On iOS/Android, the gradient fallback uses zero GPU compute.
