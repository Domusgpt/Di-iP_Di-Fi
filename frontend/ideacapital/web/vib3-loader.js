/**
 * Vib3+ Shader SDK Loader for IdeaCapital
 *
 * Loads the Vib3+ engine and registers a Flutter platform view factory
 * that creates shader-powered canvas elements.
 *
 * Integration: The SDK is loaded from a CDN or local build of
 * https://github.com/Domusgpt/Vib3-CORE-Documented01-
 * Branch: claude/phase-5-hardening-a4Wzn
 */

(function() {
  'use strict';

  // Configuration
  const VIB3_SDK_URL = '/assets/vib3/VIB3Engine.js';
  const DEFAULT_SYSTEM = 'quantum';
  const DEFAULT_GEOMETRY = 10;

  let engineInstance = null;
  let isInitialized = false;

  /**
   * Initialize the Vib3 engine and register Flutter platform views.
   */
  async function initVib3() {
    if (isInitialized) return;

    try {
      // Register the platform view factory for Flutter web
      if (window._flutter && window._flutter.loader) {
        // Wait for Flutter engine to be ready
        await window._flutter.loader.load();
      }

      // Register platform view
      const registerFactory = window.platformViewRegistry ||
        (window._platformViewRegistry);

      if (registerFactory && registerFactory.registerViewFactory) {
        registerFactory.registerViewFactory('vib3-shader-view', function(viewId) {
          const container = document.createElement('div');
          container.id = 'vib3-container-' + viewId;
          container.style.width = '100%';
          container.style.height = '100%';
          container.style.position = 'relative';
          container.style.overflow = 'hidden';

          // Create canvas for shader rendering
          const canvas = document.createElement('canvas');
          canvas.style.width = '100%';
          canvas.style.height = '100%';
          canvas.style.position = 'absolute';
          canvas.style.top = '0';
          canvas.style.left = '0';
          container.appendChild(canvas);

          // Initialize minimal shader on this canvas
          requestAnimationFrame(() => initShaderOnCanvas(canvas));

          return container;
        });
      }

      isInitialized = true;
      console.log('[Vib3] Platform view factory registered');

    } catch (error) {
      console.warn('[Vib3] SDK initialization deferred:', error.message);
      // Fallback: containers will show as transparent (CSS gradient fallback in Flutter)
    }
  }

  /**
   * Initialize a minimal procedural shader on a canvas element.
   * This is a lightweight inline shader — the full SDK provides more systems.
   */
  function initShaderOnCanvas(canvas) {
    const gl = canvas.getContext('webgl2') || canvas.getContext('webgl');
    if (!gl) {
      console.warn('[Vib3] WebGL not available');
      return;
    }

    // Resize canvas to container
    const resize = () => {
      const rect = canvas.parentElement.getBoundingClientRect();
      canvas.width = rect.width * window.devicePixelRatio;
      canvas.height = rect.height * window.devicePixelRatio;
      gl.viewport(0, 0, canvas.width, canvas.height);
    };
    resize();
    new ResizeObserver(resize).observe(canvas.parentElement);

    // Vertex shader — fullscreen triangle
    const vsSource = `#version 300 es
      out vec2 vUv;
      void main() {
        float x = float((gl_VertexID & 1) << 2);
        float y = float((gl_VertexID & 2) << 1);
        vUv = vec2(x * 0.5, y * 0.5);
        gl_Position = vec4(x - 1.0, y - 1.0, 0.0, 1.0);
      }
    `;

    // Fragment shader — procedural 4D-inspired visualization
    const fsSource = `#version 300 es
      precision highp float;
      in vec2 vUv;
      out vec4 fragColor;
      uniform float uTime;
      uniform vec2 uResolution;

      // 4D rotation helpers
      vec2 rot2D(vec2 p, float a) {
        float c = cos(a), s = sin(a);
        return vec2(p.x * c - p.y * s, p.x * s + p.y * c);
      }

      // Quantum lattice field
      float quantumField(vec3 p, float t) {
        vec3 q = p;
        q.xy = rot2D(q.xy, t * 0.3);
        q.xz = rot2D(q.xz, t * 0.2);
        float d = length(q) - 1.0;
        d += sin(q.x * 4.0 + t) * sin(q.y * 4.0 + t * 1.3) * sin(q.z * 4.0 + t * 0.7) * 0.15;
        return d;
      }

      void main() {
        vec2 uv = (vUv * 2.0 - 1.0) * vec2(uResolution.x / uResolution.y, 1.0);
        float t = uTime;

        // Ray march
        vec3 ro = vec3(0.0, 0.0, -3.0);
        vec3 rd = normalize(vec3(uv, 1.5));
        rd.xy = rot2D(rd.xy, t * 0.1);

        float totalDist = 0.0;
        float glow = 0.0;

        for (int i = 0; i < 64; i++) {
          vec3 p = ro + rd * totalDist;
          float d = quantumField(p, t);
          glow += 0.02 / (0.1 + abs(d));
          if (abs(d) < 0.001 || totalDist > 10.0) break;
          totalDist += d * 0.5;
        }

        // Color palette — deep space with quantum accents
        vec3 col = vec3(0.0);
        col += vec3(0.1, 0.3, 0.8) * glow * 0.3;
        col += vec3(0.6, 0.1, 0.9) * glow * 0.2;
        col += vec3(0.0, 0.8, 0.6) * pow(glow * 0.1, 2.0);

        // Vignette
        float vig = 1.0 - dot(vUv - 0.5, vUv - 0.5) * 2.0;
        col *= vig;

        fragColor = vec4(col, 1.0);
      }
    `;

    // Compile shaders
    function compile(type, source) {
      const shader = gl.createShader(type);
      gl.shaderSource(shader, source);
      gl.compileShader(shader);
      if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
        console.error('[Vib3] Shader compile error:', gl.getShaderInfoLog(shader));
        gl.deleteShader(shader);
        return null;
      }
      return shader;
    }

    const vs = compile(gl.VERTEX_SHADER, vsSource);
    const fs = compile(gl.FRAGMENT_SHADER, fsSource);
    if (!vs || !fs) return;

    const program = gl.createProgram();
    gl.attachShader(program, vs);
    gl.attachShader(program, fs);
    gl.linkProgram(program);

    if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
      console.error('[Vib3] Program link error:', gl.getProgramInfoLog(program));
      return;
    }

    const uTime = gl.getUniformLocation(program, 'uTime');
    const uResolution = gl.getUniformLocation(program, 'uResolution');

    // Animation loop
    let startTime = performance.now();
    let animId = null;

    function render() {
      const time = (performance.now() - startTime) * 0.001;
      gl.useProgram(program);
      gl.uniform1f(uTime, time);
      gl.uniform2f(uResolution, canvas.width, canvas.height);
      gl.drawArrays(gl.TRIANGLES, 0, 3);
      animId = requestAnimationFrame(render);
    }

    render();

    // Cleanup on removal
    const observer = new MutationObserver((mutations) => {
      for (const m of mutations) {
        for (const node of m.removedNodes) {
          if (node === canvas.parentElement || node.contains(canvas)) {
            cancelAnimationFrame(animId);
            observer.disconnect();
            return;
          }
        }
      }
    });
    if (canvas.parentElement && canvas.parentElement.parentElement) {
      observer.observe(canvas.parentElement.parentElement, { childList: true, subtree: true });
    }
  }

  // Auto-initialize when DOM is ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initVib3);
  } else {
    initVib3();
  }

  // Export for manual control
  window.Vib3Loader = { init: initVib3, initShaderOnCanvas };
})();
