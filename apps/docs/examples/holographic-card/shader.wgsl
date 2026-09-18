struct Params { resolution: vec2f, tilt: vec2f }
@group(0) @binding(0) var<uniform> params: Params;

const PI = 3.14159265;

fn box(p: vec2f, halfSize: vec2f, radius: f32) -> f32 {
  let q = abs(p) - halfSize + radius;
  return length(max(q, vec2f(0))) + min(max(q.x, q.y), 0.0) - radius;
}

fn spectrum(phase: f32) -> vec3f {
  return 0.55 + 0.45 * cos(6.2831853 * (phase + vec3f(0.0, 0.33, 0.67)));
}

fn line(distance: f32, width: f32, aa: f32) -> f32 {
  return 1.0 - smoothstep(width, width + aa, abs(distance));
}

// A small vector wordmark: no fonts, textures, or external assets.
fn segment(p: vec2f, a: vec2f, b: vec2f) -> f32 {
  let v = b - a;
  return length(p - a - v * clamp(dot(p - a, v) / dot(v, v), 0.0, 1.0));
}

fn wordmark(p: vec2f, aa: f32) -> f32 {
  var d = min(segment(p, vec2f(0, 0), vec2f(0.035, 0.085)), segment(p, vec2f(0.035, 0.085), vec2f(0.07, 0)));
  let g = p - vec2f(0.13, 0.043);
  let ring = abs(length(g) - 0.039);
  d = min(d, max(ring, min(g.x, -g.y)));
  d = min(d, segment(g, vec2f(0.005, 0), vec2f(0.039, 0)));
  d = min(d, segment(g, vec2f(0.039, 0), vec2f(0.039, 0.026)));
  let b = p - vec2f(0.20, 0);
  d = min(d, segment(b, vec2f(0), vec2f(0, 0.085)));
  d = min(d, segment(b, vec2f(0), vec2f(0.032, 0)));
  d = min(d, segment(b, vec2f(0, 0.046), vec2f(0.032, 0.046)));
  d = min(d, max(abs(length(b - vec2f(0.032, 0.023)) - 0.023), 0.032 - b.x));
  let u = p - vec2f(0.30, 0);
  d = min(d, segment(u, vec2f(0), vec2f(0, 0.052)));
  d = min(d, segment(u, vec2f(0.066, 0), vec2f(0.066, 0.052)));
  d = min(d, max(abs(length(u - vec2f(0.033, 0.052)) - 0.033), 0.052 - u.y));
  return line(d, 0.0045, aa);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
  let resolution = max(params.resolution, vec2f(1));
  // Keep the full card in view in both portrait and landscape embeds.
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
  let aa = max(length(fwidth(p)), 0.001);
  let edge = box(p, vec2f(0.64, 0.91), 0.055);
  let silhouette = 1.0 - smoothstep(-aa, aa, edge);

  // Dark studio backdrop and a soft, offset contact shadow.
  let halo = exp(-dot(screen * vec2f(0.75, 0.65), screen * vec2f(0.75, 0.65)) * 2.0);
  var background = vec3f(0.026, 0.032, 0.046) + vec3f(0.05, 0.06, 0.075) * halo;
  let shadow = exp(-max(box(screen - vec2f(0.035, 0.075), vec2f(0.62, 0.89), 0.06), 0.0) * 18.0);
  background *= 1.0 - 0.72 * shadow;

  let view = normalize(eye - hit);
  let angle = dot(view, right) * 1.7 + dot(view, down) * 1.25;
  let radial = length(p - vec2f(-0.23, -0.2));
  let phase = p.x * 0.58 + p.y * 0.32 + radial * 0.45 + angle;
  let foil = spectrum(phase);
  let sweep = pow(0.5 + 0.5 * sin((p.x * 0.9 - p.y * 0.55 + angle * 1.4) * 5.0), 10.0);
  var color = mix(vec3f(0.20, 0.23, 0.28), foil, 0.60) * (0.65 + sweep * 0.8);

  // Fine diffraction grooves and guilloche waves etched into the foil.
  let groovePhase = (p.x + p.y * 0.38) * 380.0;
  let grooves = sin(groovePhase) * (1.0 - smoothstep(0.5, 3.0, fwidth(groovePhase)));
  color += grooves * 0.018;
  let wavePhase = p.y * 135.0 + sin(p.x * 15.0) * 4.0 + sin(p.x * 6.0) * 8.0;
  let waves = line(sin(wavePhase), 0.09, min(fwidth(wavePhase), 1.0));
  color += waves * spectrum(phase + 0.25) * 0.13;

  // The central medallion combines a spectral disc with concentric engraving.
  let medallion = p - vec2f(0, -0.09);
  let radius = length(medallion);
  let polar = atan2(medallion.y, medallion.x);
  let disc = 1.0 - smoothstep(0.415 - aa, 0.415 + aa, radius);
  let discFoil = spectrum(radius * 1.9 - angle * 0.8 + polar / (2.0 * PI));
  let etchPhase = radius * 290.0 + sin(polar * 24.0) * 0.65;
  let etch = line(sin(etchPhase), 0.12, min(fwidth(etchPhase), 1.0));
  let discColor = discFoil * (0.48 + sweep * 0.75) + etch * 0.14;
  color = mix(color, discColor, disc * 0.85);
  color += line(radius - 0.425, 0.002, aa) * (0.3 + foil * 0.5);
  color += line(radius - 0.45, 0.001, aa) * 0.25;

  // Vercel's triangular silhouette, embossed above the medallion.
  let triangle = max(abs(medallion.x) * 0.8660254 - (medallion.y + 0.235) * 0.5, medallion.y - 0.19);
  let triangleMask = 1.0 - smoothstep(-aa, aa, triangle);
  let metal = mix(vec3f(0.84, 0.88, 0.91), spectrum(phase + 0.15), 0.24) * (0.7 + sweep * 0.4);
  color = mix(color, metal, triangleMask);
  color += line(triangle, 0.0015, aa) * 0.28;

  // Inset border, header, separator and a machine-readable decorative strip.
  let border = box(p, vec2f(0.587, 0.857), 0.022);
  color = mix(color, vec3f(0.75, 0.83, 0.88), line(border, 0.001, aa) * 0.5);
  let logo = wordmark(p - vec2f(-0.49, -0.74), aa);
  color = mix(color, vec3f(0.90, 0.94, 0.96), logo);
  let emblem = abs(p - vec2f(0.455, -0.695));
  let star = line(min(emblem.x, emblem.y), 0.002, aa) * (1.0 - smoothstep(0.027, 0.032, max(emblem.x, emblem.y)));
  color += star * 0.7;
  let rule = line(p.y - 0.53, 0.001, aa) * (1.0 - smoothstep(0.48, 0.49, abs(p.x)));
  color += rule * 0.35;
  let cell = u32(max(0.0, floor((p.x + 0.65) * 180.0)));
  let hash = (cell ^ (cell >> 3u)) * 2654435761u;
  let bars = f32((hash >> 29u) & 1u);
  let barcode = bars * (1.0 - smoothstep(0.036, 0.036 + aa, abs(p.y - 0.69))) * (1.0 - smoothstep(0.48, 0.48 + aa, abs(p.x)));
  color = mix(color, vec3f(0.055, 0.065, 0.085), barcode * 0.8);
  // Small foil serial markers below the strip.
  let ticks = line(fract((p.x + 0.48) * 40.0) - 0.5, 0.12, aa * 40.0);
  color += ticks * line(p.y - 0.77, 0.006, aa) * step(abs(p.x), 0.48) * 0.4;

  // Polished perimeter catches the same moving light as the face.
  color += line(edge + 0.008, 0.003, aa) * (0.25 + spectrum(phase + 0.2) * 0.65);
  color += pow(sweep, 3.0) * 0.20;
  return vec4f(mix(background, clamp(color, vec3f(0), vec3f(1)), silhouette), 1);
}
