export const meta = {
  slug: 'holographic-card',
  title: 'Holographic Card',
  description: 'A minimal graphite card with Geist typography and a persistent equilateral triangle outline. Hover to reveal full-card holographic engravings and a triangular fractal within.',
  tags: ['holographic', 'iridescence', 'card', 'fractal', 'shader'],
  capabilities: ['webgpu', 'fragment-shader', 'pointer-input', 'continuous-rendering', 'responsive-canvas'],
  files: ['index.tsx', 'renderer.ts', 'scene.ts', 'lettering.ts', 'shader.wgsl'],
} as const;
