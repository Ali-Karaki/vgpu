export const meta = {
  slug: 'holographic-card',
  title: 'Holographic Card',
  description: 'A collectible foil card with pointer-driven perspective, spectral reflections, and finely etched security patterns. Entirely procedural in one fragment shader.',
  tags: ['holographic', 'iridescence', 'card', 'shader'],
  capabilities: ['webgpu', 'fragment-shader', 'pointer-input', 'continuous-rendering', 'responsive-canvas'],
  files: ['index.tsx', 'renderer.ts', 'scene.ts', 'shader.wgsl'],
} as const;
