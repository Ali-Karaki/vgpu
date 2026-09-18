import { clock, frameLoop, init, surface, type Gpu } from 'vgpu';
import { createScene } from './scene';

export function createRenderer(canvas: HTMLCanvasElement) {
  let disposed = false;
  let gpu: Gpu | undefined;
  let removeInput = () => {};

  const dispose = () => {
    if (disposed) return;
    disposed = true;
    removeInput();
    gpu?.dispose();
  };

  const ready = (async () => {
    const context = await init();
    if (disposed) { context.dispose(); return; }
    gpu = context;
    const output = surface(context, canvas, { dpr: [1, 2] });
    const shader = createScene(context, output);
    await shader.compile({ colors: [output.format] });
    if (disposed) return;

    const motion = window.matchMedia('(prefers-reduced-motion: reduce)');
    let active = false;
    let pointerX = 0;
    let pointerY = 0;
    let tiltX = 0.12;
    let tiltY = -0.08;
    const move = (event: PointerEvent) => {
      if (!event.isPrimary) return;
      const rect = canvas.getBoundingClientRect();
      pointerX = Math.max(-1, Math.min(1, (event.clientX - rect.left) / Math.max(1, rect.width) * 2 - 1));
      pointerY = Math.max(-1, Math.min(1, (event.clientY - rect.top) / Math.max(1, rect.height) * 2 - 1));
      active = true;
    };
    const leave = () => { active = false; };
    const up = (event: PointerEvent) => { if (event.pointerType !== 'mouse') leave(); };
    canvas.addEventListener('pointermove', move, { passive: true });
    canvas.addEventListener('pointerdown', move, { passive: true });
    canvas.addEventListener('pointerleave', leave);
    canvas.addEventListener('pointercancel', leave);
    canvas.addEventListener('pointerup', up);
    const unsubscribeResize = output.onResize(() => {
      shader.set({ params: { resolution: output.size } });
    });
    removeInput = () => {
      canvas.removeEventListener('pointermove', move);
      canvas.removeEventListener('pointerdown', move);
      canvas.removeEventListener('pointerleave', leave);
      canvas.removeEventListener('pointercancel', leave);
      canvas.removeEventListener('pointerup', up);
      unsubscribeResize();
    };

    const time = clock(context);
    frameLoop(context, (currentFrame) => {
      const idleX = 0.12 + Math.sin(time.time * 0.55) * 0.12;
      const idleY = -0.08 + Math.sin(time.time * 0.4) * 0.08;
      const targetX = motion.matches ? 0.12 : active ? pointerX * 0.42 : idleX;
      const targetY = motion.matches ? -0.08 : active ? -pointerY * 0.32 : idleY;
      const blend = 1 - Math.exp(-8 * Math.min(time.deltaTime, 0.1));
      tiltX += (targetX - tiltX) * blend;
      tiltY += (targetY - tiltY) * blend;
      shader.set({ params: { tilt: [tiltX, tiltY] } });
      currentFrame.pass(output, shader);
    }, { fps: 60 });
  })().catch((error: unknown) => {
    if (disposed) return;
    dispose();
    throw error;
  });

  return { ready, dispose };
}
