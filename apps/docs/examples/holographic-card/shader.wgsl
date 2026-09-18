struct Params {
  resolution: vec2f,
  tilt: vec2f,
  pointer: vec2f,
  hover: f32,
}
@group(0) @binding(0) var<uniform> params: Params;
@group(0) @binding(1) var lettering: texture_2d<f32>;
@group(0) @binding(2) var linear: sampler;

fn roundedBox(p: vec2f, halfSize: vec2f, radius: f32) -> f32 {
  let q = abs(p) - halfSize + radius;
  return length(max(q, vec2f(0))) + min(max(q.x, q.y), 0.0) - radius;
}

fn segment(p: vec2f, a: vec2f, b: vec2f) -> f32 {
  let v = b - a;
  return length(p - a - v * clamp(dot(p - a, v) / dot(v, v), 0.0, 1.0));
}

fn stroke(distance: f32, width: f32, aa: f32) -> f32 {
  return 1.0 - smoothstep(width, width + aa, abs(distance));
}

fn spectrum(phase: f32) -> vec3f {
  return 0.55 + 0.45 * cos(6.2831853 * (phase + vec3f(0.0, 0.33, 0.67)));
}

fn grain(point: vec2f) -> f32 {
  let p = vec2u(abs(point) * 2400.0);
  var n = (p.x * 1597334677u) ^ (p.y * 3812015801u);
  n = (n ^ (n >> 16u)) * 2246822519u;
  return f32(n & 1023u) / 1023.0 - 0.5;
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
  let resolution = max(params.resolution, vec2f(1));
  let scale = min(resolution.y, resolution.x * 1.35);
  let screen = (uv - 0.5) * resolution / scale * 2.5;
  let sx = sin(params.tilt.y);
  let cx = cos(params.tilt.y);
  let sy = sin(params.tilt.x);
  let cy = cos(params.tilt.x);
  let right = vec3f(cy, 0, -sy);
  let down = vec3f(sy * sx, cx, cy * sx);
  let normal = cross(right, down);
  let eye = vec3f(0, 0, 4.5);
  let ray = normalize(vec3f(screen, -4.5));
  let hit = eye - ray * (dot(eye, normal) / dot(ray, normal));
  let p = vec2f(dot(hit, right), dot(hit, down));
  let aa = max(length(fwidth(p)), 0.0006);
  let edge = roundedBox(p, vec2f(0.64, 0.91), 0.055);
  let silhouette = 1.0 - smoothstep(-aa, aa, edge);

  let halo = exp(-dot(screen, screen) * 0.8);
  var background = vec3f(0.027, 0.031, 0.038) + 0.009 * halo;
  let shadow = exp(-max(roundedBox(screen - vec2f(0.025, 0.06), vec2f(0.63, 0.9), 0.055), 0.0) * 22.0);
  background *= 1.0 - 0.7 * shadow;

  // Matte graphite remains dark; only the cursor's grazing light reveals the foil.
  let hover = clamp(params.hover, 0.0, 1.0);
  let lightCenter = params.pointer * vec2f(0.64, 0.91);
  let delta = p - lightCenter;
  let lightBand = exp(-pow((delta.x * 0.72 + delta.y * 0.52) / 0.25, 2.0));
  let spotlight = exp(-dot(delta * vec2f(1.05, 0.72), delta * vec2f(1.05, 0.72)) * 2.6);
  let light = lightBand * spotlight * hover;
  let phase = p.x * 0.55 + p.y * 0.32 + dot(params.tilt, vec2f(1.1, 0.8));
  let tint = mix(vec3f(0.72, 0.76, 0.8), spectrum(phase), 0.28);
  let noise = grain(p + vec2f(2));
  var color = vec3f(0.062, 0.068, 0.078) + 0.008 * (0.9 - p.y) + noise * 0.013;
  color += light * (vec3f(0.07) + tint * 0.09);

  let top = vec2f(0, -0.48);
  let left = vec2f(-0.45, 0.25);
  let rightCorner = vec2f(0.45, 0.25);
  let triangleDistance = min(segment(p, top, left), min(segment(p, left, rightCorner), segment(p, rightCorner, top)));
  let inside = step(abs(p.x) * (0.73 / 0.45), p.y + 0.48) * step(p.y, 0.25);

  // Fine, warped contour lines appear in the light. Outside the triangle they fade quickly.
  let q = p - vec2f(0.13, 0.08);
  let radius = length(q * vec2f(1.0, 0.76));
  let angle = atan2(q.y, q.x);
  let contour = radius * 142.0 + sin(angle * 3.0 + radius * 8.0) * 1.7;
  let contours = stroke(sin(contour), 0.06, min(fwidth(contour), 1.0));
  let reveal = hover * (0.12 * spotlight + light * 0.88);
  let engraving = contours * reveal * mix(0.08 * exp(-triangleDistance * 9.0), 1.0, inside);
  color += engraving * mix(vec3f(0.28, 0.32, 0.36), spectrum(phase + radius * 0.55), 0.25) * 0.75;

  // Always-visible outline: its baseline contrast does not depend on hover or light.
  let outline = stroke(triangleDistance, 0.0012, aa * 0.65);
  color = mix(color, vec3f(0.29, 0.32, 0.36) + tint * light * 0.16, outline);

  // Real Geist lettering baked into a small mask shared by browser and Node.
  let artworkUv = p / vec2f(1.28, 1.82) + 0.5;
  let text = textureSampleLevel(lettering, linear, clamp(artworkUv, vec2f(0), vec2f(1)), 0.0).r;
  color = mix(color, vec3f(0.77, 0.79, 0.82), text);
  let mark = p - vec2f(0.505, -0.765);
  let crossMark = min(segment(mark, vec2f(-0.024, 0), vec2f(0.024, 0)), segment(mark, vec2f(0, -0.024), vec2f(0, 0.024)));
  color = mix(color, vec3f(0.48, 0.51, 0.55), stroke(crossMark, 0.0007, aa * 0.65));

  let rim = stroke(edge + 0.002, 0.0008, aa * 0.7);
  let rimLight = pow(max(0.0, 1.0 - length(delta) * 0.65), 3.0) * hover;
  color = mix(color, vec3f(0.25, 0.28, 0.32) + tint * rimLight * 0.42, rim);
  return vec4f(mix(background, color, silhouette), 1);
}
