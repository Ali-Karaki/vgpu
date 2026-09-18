import { frame, type Gpu, type Target } from 'vgpu';
import { createScene } from './scene';

export async function renderThumbnail(gpu: Gpu, target: Target): Promise<void> {
  try {
    const shader = createScene(gpu, target);
    await shader.compile(target);
    frame(gpu, (currentFrame) => currentFrame.pass(target, shader));
  } finally {
    await Promise.allSettled([
      Promise.resolve().then(() => gpu.gpu.queue.onSubmittedWorkDone()),
      Promise.resolve().then(() => gpu.settled()),
    ]);
  }
}
