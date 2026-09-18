import { afterEach, expect, test, vi } from 'vitest';

const mocks = vi.hoisted(() => ({ init: vi.fn(), surface: vi.fn(), frameLoop: vi.fn(), createScene: vi.fn() }));
vi.mock('vgpu', () => ({ ...mocks, clock: () => ({ time: 1, deltaTime: 1 / 60 }) }));
vi.mock('./scene', () => ({ createScene: mocks.createScene }));
import { createRenderer } from './renderer';

function deferred<T>() {
  let resolve!: (value: T) => void;
  const promise = new Promise<T>((done) => { resolve = done; });
  return { promise, resolve };
}

function setup() {
  const canvas = new EventTarget() as HTMLCanvasElement;
  canvas.getBoundingClientRect = () => ({ left: 10, top: 20, width: 300, height: 500 }) as DOMRect;
  const remove = vi.spyOn(canvas, 'removeEventListener');
  const gpu = { dispose: vi.fn() };
  const unsubscribe = vi.fn();
  const output = { size: [300, 500], format: 'bgra8unorm', onResize: vi.fn((callback) => { callback(); return unsubscribe; }) };
  const shader = { compile: vi.fn().mockResolvedValue(undefined), set: vi.fn() };
  const motion = { matches: false };
  vi.stubGlobal('window', { matchMedia: () => motion });
  mocks.init.mockResolvedValue(gpu);
  mocks.surface.mockReturnValue(output);
  mocks.createScene.mockReturnValue(shader);
  return { canvas, gpu, output, shader, remove, unsubscribe, motion };
}

afterEach(() => { vi.resetAllMocks(); vi.unstubAllGlobals(); });

test('unmount during adapter initialization disposes the late context without creating a surface', async () => {
  const { canvas, gpu } = setup();
  const pending = deferred<typeof gpu>();
  mocks.init.mockReturnValue(pending.promise);
  const renderer = createRenderer(canvas);
  renderer.dispose();
  pending.resolve(gpu);
  await renderer.ready;
  expect(gpu.dispose).toHaveBeenCalledOnce();
  expect(mocks.surface).not.toHaveBeenCalled();
});

test('unmount during prewarm never installs input or starts a late frame loop', async () => {
  const { canvas, gpu, shader, output } = setup();
  const compiling = deferred<void>();
  shader.compile.mockReturnValue(compiling.promise);
  const renderer = createRenderer(canvas);
  await vi.waitFor(() => expect(shader.compile).toHaveBeenCalled());
  renderer.dispose();
  compiling.resolve();
  await renderer.ready;
  expect(gpu.dispose).toHaveBeenCalledOnce();
  expect(output.onResize).not.toHaveBeenCalled();
  expect(mocks.frameLoop).not.toHaveBeenCalled();
});

test('compilation failure rejects ready and releases the context', async () => {
  const { canvas, gpu, shader } = setup();
  shader.compile.mockRejectedValue(new Error('compile failed'));
  const renderer = createRenderer(canvas);
  await expect(renderer.ready).rejects.toThrow('compile failed');
  renderer.dispose();
  expect(gpu.dispose).toHaveBeenCalledOnce();
});

test('input changes the foil angle, reduced motion stays fixed, and disposal removes subscriptions', async () => {
  const { canvas, shader, motion, remove, unsubscribe, gpu } = setup();
  const renderer = createRenderer(canvas);
  await renderer.ready;
  expect(shader.compile).toHaveBeenCalledWith({ colors: ['bgra8unorm'] });
  const tick = mocks.frameLoop.mock.calls[0]![1];
  const pass = vi.fn();
  const pointer = Object.assign(new Event('pointermove'), { isPrimary: true, clientX: 210, clientY: 200 });
  canvas.dispatchEvent(pointer);
  tick({ pass });
  const tilt = shader.set.mock.lastCall![0].params.tilt;
  expect(tilt[0]).toBeGreaterThan(0);
  expect(tilt[1]).toBeGreaterThan(0);
  expect(shader.set.mock.lastCall![0].params.hover).toBeGreaterThan(0);
  expect(pass).toHaveBeenCalledOnce();
  // Leaving the card, even while still over the canvas, must fade the reveal out.
  const beforeLeave = shader.set.mock.lastCall![0].params.hover;
  canvas.dispatchEvent(Object.assign(new Event('pointermove'), { isPrimary: true, clientX: 10, clientY: 20 }));
  tick({ pass });
  expect(shader.set.mock.lastCall![0].params.hover).toBeLessThan(beforeLeave);
  renderer.dispose();
  renderer.dispose();
  expect(remove).toHaveBeenCalledTimes(5);
  expect(unsubscribe).toHaveBeenCalledOnce();
  expect(gpu.dispose).toHaveBeenCalledOnce();

  motion.matches = true;
  const reduced = createRenderer(canvas);
  await reduced.ready;
  canvas.dispatchEvent(pointer);
  mocks.frameLoop.mock.lastCall![1]({ pass });
  expect(shader.set.mock.lastCall![0].params.tilt).toEqual([0, 0]);
  reduced.dispose();
});
