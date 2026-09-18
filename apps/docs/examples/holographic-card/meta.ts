export const meta = {
  slug: 'holographic-card',
  title: 'Holographic Card',
  description: 'A minimal graphite card with Geist typography and a persistent triangle outline. Hover to reveal fine optical engravings and a subtle holographic reflection.',
  tags: ['holographic', 'iridescence', 'card', 'shader'],
  capabilities: ['webgpu', 'fragment-shader', 'pointer-input', 'continuous-rendering', 'responsive-canvas'],
  files: ['index.tsx', 'renderer.ts', 'scene.ts', 'lettering.ts', 'shader.wgsl'],
} as const;
