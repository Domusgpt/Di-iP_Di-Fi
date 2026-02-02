/**
 * Vib3+ SDK Loader for IdeaCapital
 *
 * Loads the @vib3code/sdk engine and registers a Flutter platform view factory
 * that creates 4D visualization canvases. Falls back to inline WebGL shader
 * if the SDK module fails to load.
 *
 * SDK: @vib3code/sdk@2.0.1
 * Source: https://github.com/Domusgpt/vib34d-xr-quaternion-sdk
 */

(function() {
  'use strict';

  const DEFAULT_SYSTEM = 'quantum';
  const DEFAULT_GEOMETRY = 10;
  const DEFAULT_SPEED = 1.0;

  let VIB3Engine = null;
  let engines = new Map(); // viewId -> engine instance
  let isInitialized = false;

  /**
   * Try to load the VIB3Engine from the SDK module.
   * Returns the class or null if unavailable.
   */
  async function loadSDK() {
    try {
      const mod = await import('/node_modules/@vib3code/sdk/src/core/VIB3Engine.js');
      return mod.VIB3Engine || mod.default;
    } catch (e1) {
      try {
        // Try alternative path (bundled)
        const mod = await import('/assets/vib3/VIB3Engine.js');
        return mod.VIB3Engine || mod.default;
      } catch (e2) {
        console.warn('[Vib3] SDK not available, using inline shader fallback');
        return null;
      }
    }
  }

  /**
   * Initialize a VIB3Engine instance in a container.
   */
  async function initSDKEngine(container, viewId) {
    if (!VIB3Engine) return false;

    try {
      const engine = new VIB3Engine({
        preferWebGPU: false, // WebGL for broader compat
        debug: false,
      });

      await engine.initialize(container.id);

      // Read config from data attributes if present
      const system = container.dataset.system || DEFAULT_SYSTEM;
      const geometry = parseInt(container.dataset.geometry || DEFAULT_GEOMETRY, 10);
      const speed = parseFloat(container.dataset.speed || DEFAULT_SPEED);

      await engine.switchSystem(system);
      engine.setParameter('geometry', geometry);
      engine.setParameter('speed', speed);

      // Set IdeaCapital color palette (deep purple/blue)
      engine.setParameter('hue', 260);
      engine.setParameter('intensity', 0.6);

      engines.set(viewId, engine);
      console.log(`[Vib3] SDK engine initialized for view ${viewId} (${system})`);
      return true;
    } catch (err) {
      console.warn(`[Vib3] SDK engine init failed for view ${viewId}:`, err.message);
      return false;
    }
  }

  /**
   * Destroy an engine instance for a given view.
   */
  function destroyEngine(viewId) {
    const engine = engines.get(viewId);
    if (engine) {
      try { engine.destroy(); } catch (e) { /* ignore */ }
      engines.delete(viewId);
    }
  }

  /**
   * Initialize the Vib3 loader and register Flutter platform views.
   */
  async function initVib3() {
    if (isInitialized) return;

    // Load SDK
    VIB3Engine = await loadSDK();

    try {
      // Register the platform view factory for Flutter web
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

          // Try SDK engine first, fall back to inline shader
          requestAnimationFrame(async () => {
            const sdkOk = await initSDKEngine(container, viewId);
            if (!sdkOk) {
              initInlineShader(container, viewId);
            }
          });

          // Cleanup on removal
          const observer = new MutationObserver((mutations) => {
            for (const m of mutations) {
              for (const node of m.removedNodes) {
                if (node === container || node.contains(container)) {
                  destroyEngine(viewId);
                  observer.disconnect();
                  return;
                }
              }
            }
          });
          if (container.parentElement) {
            observer.observe(container.parentElement, { childList: true, subtree: true });
          } else {
            // Defer observer until mounted
            const mountCheck = setInterval(() => {
              if (container.parentElement) {
                observer.observe(container.parentElement, { childList: true, subtree: true });
                clearInterval(mountCheck);
              }
            }, 100);
            setTimeout(() => clearInterval(mountCheck), 5000);
          }

          return container;
        });
      }

      isInitialized = true;
      console.log(`[Vib3] Platform view factory registered (SDK: ${VIB3Engine ? 'loaded' : 'fallback'})`);

    } catch (error) {
      console.warn('[Vib3] Initialization deferred:', error.message);
    }
  }

  /**
   * Inline WebGL shader fallback when SDK is not available.
   * Ray-marched quantum lattice visualization.
   */
  function initInlineShader(container, viewId) {
    const canvas = document.createElement('canvas');
    canvas.style.width = '100%';
    canvas.style.height = '100%';
    canvas.style.position = 'absolute';
    canvas.style.top = '0';
    canvas.style.left = '0';
    container.appendChild(canvas);

    const gl = canvas.getContext('webgl2') || canvas.getContext('webgl');
    if (!gl) {
      console.warn('[Vib3] WebGL not available');
      return;
    }

    const resize = () => {
      const rect = canvas.parentElement.getBoundingClientRect();
      canvas.width = rect.width * window.devicePixelRatio;
      canvas.height = rect.height * window.devicePixelRatio;
      gl.viewport(0, 0, canvas.width, canvas.height);
    };
    resize();
    new ResizeObserver(resize).observe(canvas.parentElement);

    const vsSource = `#version 300 es
      out vec2 vUv;
      void main() {
        float x = float((gl_VertexID & 1) << 2);
        float y = float((gl_VertexID & 2) << 1);
        vUv = vec2(x * 0.5, y * 0.5);
        gl_Position = vec4(x - 1.0, y - 1.0, 0.0, 1.0);
      }
    `;

    const fsSource = `#version 300 es
      precision highp float;
      in vec2 vUv;
      out vec4 fragColor;
      uniform float uTime;
      uniform vec2 uResolution;

      vec2 rot2D(vec2 p, float a) {
        float c = cos(a), s = sin(a);
        return vec2(p.x * c - p.y * s, p.x * s + p.y * c);
      }

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
        vec3 col = vec3(0.0);
        col += vec3(0.1, 0.3, 0.8) * glow * 0.3;
        col += vec3(0.6, 0.1, 0.9) * glow * 0.2;
        col += vec3(0.0, 0.8, 0.6) * pow(glow * 0.1, 2.0);
        float vig = 1.0 - dot(vUv - 0.5, vUv - 0.5) * 2.0;
        col *= vig;
        fragColor = vec4(col, 1.0);
      }
    `;

    function compile(type, source) {
      const shader = gl.createShader(type);
      gl.shaderSource(shader, source);
      gl.compileShader(shader);
      if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
        console.error('[Vib3] Shader error:', gl.getShaderInfoLog(shader));
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
      console.error('[Vib3] Link error:', gl.getProgramInfoLog(program));
      return;
    }

    const uTime = gl.getUniformLocation(program, 'uTime');
    const uResolution = gl.getUniformLocation(program, 'uResolution');

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

    // Store cleanup handle
    engines.set(viewId, {
      destroy: () => {
        cancelAnimationFrame(animId);
        const ext = gl.getExtension('WEBGL_lose_context');
        if (ext) ext.loseContext();
      }
    });
  }

  // ---- Public API ----

  /**
   * Update an engine's parameters from Flutter via JS interop.
   */
  function setViewParameters(viewId, params) {
    const engine = engines.get(viewId);
    if (engine && engine.setParameters) {
      engine.setParameters(params);
    }
  }

  function switchViewSystem(viewId, system) {
    const engine = engines.get(viewId);
    if (engine && engine.switchSystem) {
      return engine.switchSystem(system);
    }
  }

  function setViewGeometry(viewId, geometry) {
    const engine = engines.get(viewId);
    if (engine && engine.setParameter) {
      engine.setParameter('geometry', geometry);
    }
  }

  // Auto-initialize when DOM is ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initVib3);
  } else {
    initVib3();
  }

  // Export for Flutter JS interop and manual control
  window.Vib3Loader = {
    init: initVib3,
    setParameters: setViewParameters,
    switchSystem: switchViewSystem,
    setGeometry: setViewGeometry,
    destroyView: destroyEngine,
    getEngines: () => engines,
  };
})();
