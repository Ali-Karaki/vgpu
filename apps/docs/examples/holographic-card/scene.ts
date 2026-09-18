import { effect, type Gpu, type Target } from 'vgpu';
import fragment from './shader.wgsl';

/** Shared by the live canvas and deterministic gallery thumbnails. */
export function createScene(gpu: Gpu, output: Target) {
  const shader = effect(gpu, fragment, {
    label: 'holographic-card',
    set: { params: { resolution: output.size, tilt: [0.12, -0.08] } },
  });
  return shader;
}
