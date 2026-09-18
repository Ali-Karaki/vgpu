'use client';

import { useEffect, useRef, useState } from 'react';
import { createRenderer } from './renderer';

export function Example() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [error, setError] = useState(false);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    let mounted = true;
    const renderer = createRenderer(canvas);
    void renderer.ready.catch((cause: unknown) => {
      if (!mounted) return;
      console.error('Holographic card initialization failed:', cause);
      setError(true);
    });
    return () => { mounted = false; renderer.dispose(); };
  }, []);

  return (
    <div className="relative h-full w-full overflow-hidden bg-[#090b10]">
      <canvas ref={canvasRef} className="block h-full w-full touch-none" aria-label="Holographic foil card. Move your pointer or drag to tilt the card and shift its rainbow reflections." />
      <p className="pointer-events-none absolute inset-x-0 bottom-5 text-center font-mono text-[10px] tracking-[0.2em] text-white/45">
        {error ? 'This example requires a WebGPU-capable browser.' : 'HOLOGRAPHIC CARD · MOVE TO EXPLORE'}
      </p>
    </div>
  );
}

export default Example;
