// New enemy bodies drawn natively in pxl (presentation only), for enemies whose Dota courier
// model has a body type none of the refined-v3 sprites has (docs/enemy-silhouettes.md).
// Style follows refined-v3: 3/4 view facing right, near-black 1px outline, light from the
// upper left, rounded volumes with 4-6 tones per material and dark seams between parts.
// Parts ("_name") are animated in walk.px.js.

// ---------------------------------------------------------------- shading helpers
// Light from the upper left, slightly in front. Tones are ramps dark -> light. Between two tones
// the threshold follows smooth value noise (cells of ~3 px), so a gradient breaks into irregular
// brush-like clusters as in the refined sprites instead of a regular checkerboard.
const LIGHT = (() => { const v = [-0.55, -0.7, 0.6], n = Math.hypot(...v); return v.map((a) => a / n) })()

function hash2(x, y) {
  let h = (x * 374761393 + y * 668265263) | 0
  h = Math.imul(h ^ (h >>> 13), 1274126177)
  return ((h ^ (h >>> 16)) >>> 0) / 4294967296
}

function brush(x, y, cell = 2.6) {
  const fx = x / cell, fy = y / cell, x0 = Math.floor(fx), y0 = Math.floor(fy)
  const tx = fx - x0, ty = fy - y0, sx = tx * tx * (3 - 2 * tx), sy = ty * ty * (3 - 2 * ty)
  const top = hash2(x0, y0) * (1 - sx) + hash2(x0 + 1, y0) * sx
  const bottom = hash2(x0, y0 + 1) * (1 - sx) + hash2(x0 + 1, y0 + 1) * sx
  return top * (1 - sy) + bottom * sy
}

function tone(ramp, i, x, y, dither = true) {
  const v = Math.max(0, Math.min(1, i)) * (ramp.length - 1)
  if (!dither) return ramp[Math.round(v)]
  const base = Math.floor(v), frac = v - base
  // Stretch the noise so most pixels sit clearly on one tone and only the band edges wander.
  const n = Math.min(1, Math.max(0, (brush(x, y) - 0.5) * 1.6 + 0.5))
  return ramp[Math.min(ramp.length - 1, base + (frac > n ? 1 : 0))]
}

// Refined-v3 keeps most of a body in its mid/dark tones and saves the top tone for a small
// highlight, so the diffuse term is curved down.
function lit(nx, ny, nz, ambient = 0.1) {
  const d = Math.max(0, nx * LIGHT[0] + ny * LIGHT[1] + nz * LIGHT[2])
  return ambient + (1 - ambient) * 0.95 * d ** 1.5
}

// Refined-v3 sprites darken one tone just inside the outline; call last, before outline.
function rim(c, steps = 1) {
  const edge = new Set()
  for (let y = 0; y < c.h; y++)
    for (let x = 0; x < c.w; x++)
      if (c.is(x, y, "*") && (c.is(x + 1, y, ".") || c.is(x - 1, y, ".") || c.is(x, y + 1, ".") || c.is(x, y - 1, ".")))
        edge.add(x + "," + y)
  c.shade((x, y) => edge.has(x + "," + y), steps)
}

// Dark seam where a new part overlaps what is already drawn, so parts read as separate volumes,
// plus a soft contact shadow one step darker on the part underneath, just outside the seam.
function seam(c, test, key) {
  const line = new Set()
  for (let y = 0; y < c.h; y++)
    for (let x = 0; x < c.w; x++)
      if (!test(x, y) && c.is(x, y, "*") && (test(x + 1, y) || test(x - 1, y) || test(x, y + 1) || test(x, y - 1)))
        line.add(x + "," + y)
  const shadow = new Set()
  for (const p of line) {
    const [x, y] = p.split(",").map(Number)
    for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [-1, 1]]) {
      const q = (x + dx) + "," + (y + dy)
      if (!line.has(q) && !test(x + dx, y + dy) && c.is(x + dx, y + dy, "*")) shadow.add(q)
    }
  }
  c.shade((x, y) => shadow.has(x + "," + y), 1)
  for (const p of line) { const [x, y] = p.split(",").map(Number); c.px(x, y, key) }
}

// Drawing space. creature(..., scale) draws every body in its own unscaled coordinates on a
// canvas `scale` times larger: shapes are rasterised again at the larger size (more pixels, more
// detail) instead of being enlarged, so all bodies can match the refined-v3 pixel size in game.
// Helpers accept either the raw canvas or this proxy; C()/S() unwrap it.
const R = Math.round
function space(c, s) {
  const sc = (v) => R(v * s), len = (v) => Math.max(1, R(v * s))
  return {
    raw: c, s, w: c.w / s, h: c.h / s, frame: c.frame, rng: (seed) => c.rng(seed),
    px: (x, y, k) => c.px(sc(x), sc(y), k),
    line: (x0, y0, x1, y1, k, width) => c.line(sc(x0), sc(y0), sc(x1), sc(y1), k, width),
    poly: (pts, k) => c.poly(pts.map(sc), k),
    rect: (x, y, w, h, k) => c.rect(sc(x), sc(y), len(w), len(h), k),
    hline: (x, y, n, k) => c.hline(sc(x), sc(y), len(n), k),
    vline: (x, y, n, k) => c.vline(sc(x), sc(y), len(n), k),
    circ: (x, y, r, k) => c.circ(sc(x), sc(y), sc(r), k),
    ring: (x, y, r, k) => c.ring(sc(x), sc(y), sc(r), k),
    ellipse: (x, y, rx, ry, k, ring) => c.ellipse(sc(x), sc(y), sc(rx), sc(ry), k, ring),
    noise: (x, y, w, h, keys, d, seed, on) => c.noise(sc(x), sc(y), len(w), len(h), keys, d, seed, on),
    stamp: (name, x, y, o) => c.stamp(name, sc(x), sc(y), o),
    clip: (pred, fn) => c.clip((x, y) => pred(x / s, y / s), fn),
    is: (x, y, k) => c.is(sc(x), sc(y), k),
    get: (x, y) => c.get(sc(x), sc(y)),
  }
}
const C = (c) => c.raw ?? c
const S = (c) => c.s ?? 1
const scaledClip = (clip, s) => clip && ((x, y) => clip(x / s, y / s))

// Shaded ellipsoid. opts: seam key (default "k"), bright (tone shift), clip(x, y) to cut it.
function ball(c, cx, cy, rx, ry, ramp, opts = {}) {
  const s = S(c); c = C(c); cx *= s; cy *= s; rx *= s; ry *= s
  const clip = scaledClip(opts.clip, s)
  const inside = (x, y) => (((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1) && (!clip || clip(x, y))
  if (opts.seam !== null) seam(c, inside, opts.seam ?? "k")
  for (let y = Math.floor(cy - ry); y <= cy + ry; y++)
    for (let x = Math.floor(cx - rx); x <= cx + rx; x++) {
      if (!inside(x, y)) continue
      const nx = (x + 0.5 - cx) / rx, ny = (y + 0.5 - cy) / ry
      const nz = Math.sqrt(Math.max(0, 1 - nx * nx - ny * ny))
      c.px(x, y, tone(ramp, lit(nx, ny, nz) + (opts.bright ?? 0), x, y))
    }
}

// Shaded capsule from (x0, y0, r0) to (x1, y1, r1): legs, necks, tails, roots.
function tube(c, x0, y0, r0, x1, y1, r1, ramp, opts = {}) {
  const s = S(c); c = C(c); x0 *= s; y0 *= s; r0 *= s; x1 *= s; y1 *= s; r1 *= s
  const dx = x1 - x0, dy = y1 - y0, len2 = dx * dx + dy * dy || 1
  const at = (x, y) => {
    const t = Math.max(0, Math.min(1, ((x + 0.5 - x0) * dx + (y + 0.5 - y0) * dy) / len2))
    const px = x0 + dx * t, py = y0 + dy * t, r = r0 + (r1 - r0) * t
    return [(x + 0.5 - px) / r, (y + 0.5 - py) / r]
  }
  const inside = (x, y) => { const [u, v] = at(x, y); return u * u + v * v <= 1 }
  if (opts.seam !== null) seam(c, inside, opts.seam ?? "k")
  const r = Math.max(r0, r1)
  for (let y = Math.floor(Math.min(y0, y1) - r); y <= Math.max(y0, y1) + r; y++)
    for (let x = Math.floor(Math.min(x0, x1) - r); x <= Math.max(x0, x1) + r; x++) {
      if (!inside(x, y)) continue
      const [u, v] = at(x, y)
      // Thin limbs: no dither, or the tone bands turn into a ladder pattern.
      c.px(x, y, tone(ramp, lit(u, v, Math.sqrt(Math.max(0, 1 - u * u - v * v))) + (opts.bright ?? 0), x, y, r > 3))
    }
}

// Upright cylinder with an elliptical bottom edge (trunks, stalks); the top is drawn separately.
function cyl(c, cx, y0, y1, rx, ry, ramp, opts = {}) {
  const s = S(c); c = C(c); cx *= s; y0 = R(y0 * s); y1 = R(y1 * s); rx *= s; ry *= s
  const inside = (x, y) => { const nx = (x + 0.5 - cx) / rx; return Math.abs(nx) <= 1 && y >= y0 && y <= y1 + ry * Math.sqrt(1 - nx * nx) }
  if (opts.seam !== null) seam(c, inside, opts.seam ?? "k")
  for (let y = y0; y <= y1 + ry; y++)
    for (let x = Math.floor(cx - rx); x <= cx + rx; x++) {
      if (!inside(x, y)) continue
      const nx = (x + 0.5 - cx) / rx
      c.px(x, y, tone(ramp, lit(nx, -0.15, Math.sqrt(1 - nx * nx)) + (opts.bright ?? 0), x, y))
    }
}

// Glossy creature eye like the refined frog/boar: dark rim, iris lit from the upper left,
// vertical pupil, white glint.
function eye(c, x, y, r, iris, irisLight, pupil = "k", glint = "w") {
  const s = S(c); c = C(c); x = R(x * s); y = R(y * s); r = R(r * s)
  c.circ(x, y, r, "k")
  for (let yy = y - r + 1; yy <= y + r - 1; yy++)
    for (let xx = x - r + 1; xx <= x + r - 1; xx++)
      if ((xx - x) ** 2 + (yy - y) ** 2 <= (r - 1) ** 2 + 0.5)
        c.px(xx, yy, (xx - x) + (yy - y) < 0 ? irisLight : iris)
  c.vline(x + (r > 2 ? 1 : 0), y - Math.max(0, r - 3), Math.max(1, 2 * r - 4), pupil)
  c.px(x - 1, y - 1, glint)
}

// Fin, veil tail or feathered wing: a fan from (x, y) between two angles (degrees, 0 = right,
// 90 = down) with radius r, filled light-to-dark from the root with darker rays.
function fan(c, x, y, a0, a1, r, ramp, rays = 4) {
  const s = S(c); c = C(c); x *= s; y *= s; r *= s
  const pts = [R(x), R(y)], steps = 10
  for (let i = 0; i <= steps; i++) {
    const a = (a0 + (a1 - a0) * i / steps) * Math.PI / 180, rr = r * (0.82 + 0.18 * Math.sin(i / steps * Math.PI))
    pts.push(R(x + Math.cos(a) * rr), R(y + Math.sin(a) * rr))
  }
  // Mark the fan with a temporary key so it can be shaded and edged against what is behind it.
  const under = new Map()
  for (let yy = Math.floor(y - r - 1); yy <= y + r + 1; yy++)
    for (let xx = Math.floor(x - r - 1); xx <= x + r + 1; xx++) under.set(xx + "," + yy, c.get(xx, yy))
  c.poly(pts, "#ff00ff")
  const mine = new Set()
  for (const key of under.keys()) { const [xx, yy] = key.split(",").map(Number); if (c.get(xx, yy) === 0xff00ffff) mine.add(key) }
  for (const key of mine) {
    const [xx, yy] = key.split(",").map(Number)
    const edge = [[1, 0], [-1, 0], [0, 1], [0, -1]].some(([dx, dy]) => !mine.has((xx + dx) + "," + (yy + dy)) && under.get((xx + dx) + "," + (yy + dy)))
    const d = Math.hypot(xx + 0.5 - x, yy + 0.5 - y) / r
    c.px(xx, yy, edge ? "k" : tone(ramp, 0.85 - d * 0.6, xx, yy))
  }
  for (let i = 1; i < rays; i++) {
    const a = (a0 + (a1 - a0) * i / rays) * Math.PI / 180
    c.line(R(x), R(y), R(x + Math.cos(a) * r * 0.85), R(y + Math.sin(a) * r * 0.85), ramp[0])
  }
}

// Surface detail drawn at the final resolution, like the hand-placed strokes in refined-v3:
// every helper only touches pixels whose key is in `ramp`, and steps one tone along it.
function stepKey(ramp, k, d) {
  const i = ramp.indexOf(k)
  return i < 0 ? null : ramp[Math.max(0, Math.min(ramp.length - 1, i + d))]
}

// Fur/hair: short strokes combed along (dx, dy); lit tones get lighter strands, shaded ones darker.
function fur(c, ramp, density = 0.12, seed = 1, dx = -1, dy = 1, len = 2) {
  const rnd = C(c).rng(seed); c = C(c)
  const strokes = []
  for (let y = 0; y < c.h; y++)
    for (let x = 0; x < c.w; x++) {
      const k = c.key(x, y)
      if (ramp.includes(k) && rnd() < density) strokes.push([x, y, stepKey(ramp, k, ramp.indexOf(k) >= ramp.length / 2 ? 1 : -1)])
    }
  for (const [x, y, k] of strokes)
    for (let i = 0; i <= len; i++)
      if (ramp.includes(c.key(x + dx * i, y + dy * i))) c.px(x + dx * i, y + dy * i, k)
}

// Feathers or fish scales: rows of small darker arcs, offset every other row.
function scallops(c, ramp, w = 4, h = 3, seed = 1) {
  const rnd = C(c).rng(seed); c = C(c)
  const marks = []
  for (let y = 1; y < c.h; y += h)
    for (let x = ((y / h) & 1) * (w >> 1); x < c.w; x += w) {
      if (rnd() < 0.15) continue
      for (const [ax, ay] of [[0, 0], [1, 1], [2, 1], [3, 0]].slice(0, w))
        if (ramp.includes(c.key(x + ax, y + ay))) marks.push([x + ax, y + ay, stepKey(ramp, c.key(x + ax, y + ay), -1)])
    }
  for (const [x, y, k] of marks) c.px(x, y, k)
}

// Wool: little curls (a darker hook and a lighter top).
function curls(c, ramp, density = 0.05, seed = 1) {
  const rnd = C(c).rng(seed); c = C(c)
  const at = []
  for (let y = 1; y < c.h - 1; y++)
    for (let x = 1; x < c.w - 1; x++)
      if (ramp.includes(c.key(x, y)) && rnd() < density) at.push([x, y])
  for (const [x, y] of at) {
    const k = c.key(x, y)
    for (const [ax, ay, d] of [[0, 0, -1], [1, 0, -1], [1, -1, -1], [0, -1, 1], [-1, 0, 1]])
      if (ramp.includes(c.key(x + ax, y + ay))) c.px(x + ax, y + ay, stepKey(ramp, k, d))
  }
}

// ---------------------------------------------------------------- animation helpers
// Every body is an anim of 4 frames. Ground gait matches walk.px.js: frames 0 and 2 are the
// contacts that land with the hop in GemArt.enemy_motion; the near-front leg and its diagonal
// partner reach forward on frame 0, the other pair on frame 2, and a leg lifts while it swings
// forward (frame 3 for the near-front pair, frame 1 for the other). Flyers: frame 0 is the top of
// the wing beat, frame 2 the bottom.
function gait(frame) {
  const p = frame / 4 * Math.PI * 2
  return {
    a: { dx: Math.round(Math.cos(p) * 100) / 100, lift: Math.max(0, -Math.round(Math.sin(p))) },
    b: { dx: Math.round(Math.cos(p + Math.PI) * 100) / 100, lift: Math.max(0, Math.round(Math.sin(p))) },
    wing: [0, 0.55, 1, 0.45][frame],
  }
}

// scale: see space(); chosen per body so its pixel size in game matches refined-v3.
function creature(name, w, h, draw, scale = 1) {
  anim(name, { w: Math.ceil(w * scale), h: Math.ceil(h * scale), frames: 4, fps: 8, outline: "k" }, (c) => {
    draw(scale === 1 ? c : space(c, scale), gait(c.frame), c.frame)
    rim(c)
  })
}

// ---------------------------------------------------------------- plant: stump, shroomy, shagbark
use(["#050304"]) // fresh palette: ramps accumulate, so each family starts clean
pal({
  k: "#050304", K: "#1a0f0a",
  "1": "#1c0e07", "2": "#3a1f10", "3": "#58321a", "4": "#7a4826", "5": "#9d6236", "6": "#c0814d",
  r: "#5a3a1e", s: "#87603a", t: "#b28a58", u: "#d4b07a", v: "#ecd3a0",
  a: "#16300f", b: "#2f571b", c: "#548a2a", d: "#8fbf43", e: "#c8e57a",
  o: "#d9822b", O: "#f2b84b", w: "#fff6dc", m: "#2a1208",
  f: "#2e0a0a", g: "#5e1712", h: "#92261a", i: "#c43f25", j: "#e8683a", y: "#f5ead0",
  l: "#3f3226", n: "#6f5b46", q: "#a38d70", x: "#cfbb98", z: "#efe2c6", G: "#7a5a3a",
  Y: "#f4f59a", L: "#a6e04a",
})
const BARK = "123456", WOOD = "rstuv", MOSS = "abcde"
const CAP = "fghij", STALK = "lnqxz"
ramps("k123456", "2rstuv", "kabcde", "moO", "kfghij", "klnqxz", "LY")

// Wandering vertical grooves; skip(x, y) keeps them off the face.
function bark(c, x0, x1, y0, y1, seed, skip = () => false) {
  const s = S(c), rnd = C(c).rng(seed); c = C(c)
  for (let x = R((x0 + 1) * s); x < x1 * s; x += 3 + Math.floor(rnd() * 2)) {
    let gx = x
    for (let y = R(y0 * s) + Math.floor(rnd() * 3); y < y1 * s; y++) {
      if (c.is(gx, y, BARK) && !skip(gx / s, y / s)) c.px(gx, y, c.is(gx, y, "56") ? "3" : "1")
      if (rnd() < 0.18) gx += rnd() < 0.5 ? -1 : 1
    }
  }
}

sprite("_plant_eye", `
  .kkkk.
  kwOook
  kOOkok
  kookok
  kooook
  .kkkk.`)

creature("stump_walk", 48, 46, (c, g) => {
  // far roots, trunk, near roots (3/4 view: face and front roots on the right)
  tube(c, 13, 33, 3, 5 + 2 * g.b.dx, 40 - g.b.lift, 2, BARK)
  tube(c, 33, 32, 3, 42 + 2 * g.a.dx, 38 - g.a.lift, 2, BARK)
  cyl(c, 23, 12, 33, 14, 4, BARK, { bright: 0.12 })
  bark(c, 9, 37, 15, 36, 7, (x, y) => x >= 19 && y >= 16 && y <= 33)
  tube(c, 17, 34, 3.5, 13 + 2 * g.a.dx, 43 - g.a.lift, 2.5, BARK)
  tube(c, 29, 35, 3.5, 32 + 2 * g.b.dx, 44 - g.b.lift, 2.5, BARK)
  // cut top: rings and a mossy rim
  ball(c, 23, 12, 14, 5.5, WOOD, { bright: 0.05 })
  c.ellipse(23, 12, 14, 5, "r", true)
  c.ellipse(23, 12, 9, 3, "s", true)
  c.ellipse(23, 12, 4, 1, "s", true)
  for (const [x, y, rx, ry] of [[11, 14, 4, 3], [17, 17, 4, 2.5], [33, 15, 4, 3], [37, 12, 2.5, 2], [10, 10, 2.5, 2]])
    ball(c, x, y, rx, ry, MOSS, { seam: null })
  c.vline(12, 16, 3, "b"); c.vline(18, 19, 2, "b"); c.vline(34, 17, 3, "b")
  // sprout
  c.line(26, 10, 27, 3, "b")
  c.poly([27, 4, 20, 0, 22, 3, 26, 6], "c")
  c.poly([27, 3, 34, 0, 33, 3, 28, 6], "d")
  c.px(23, 1, "e"); c.px(31, 1, "e")
  fur(c, BARK, 0.06, 3, 0, 1, 2)
  // face on the lit front of the trunk: glossy eyes like the refined frog, heavy brow, teeth
  c.stamp("_plant_eye", 21, 19); c.stamp("_plant_eye", 30, 19)
  c.line(20, 17, 27, 19, "k"); c.line(20, 16, 27, 18, "1")
  c.line(30, 19, 37, 17, "k"); c.line(30, 18, 37, 16, "1")
  c.poly([24, 28, 34, 28, 32, 32, 26, 32], "k")
  c.hline(25, 29, 2, "v"); c.hline(31, 29, 2, "v"); c.hline(27, 31, 4, "m")
  c.line(21, 26, 23, 27, "3"); c.line(36, 26, 34, 27, "2")
}, 1.27)

creature("shroomy_walk", 46, 44, (c, g) => {
  // stubby feet under a short stalk, big spotted cap leaning forward
  ball(c, 16 + 2 * g.b.dx, 40 - g.b.lift, 4.5, 3, STALK)
  cyl(c, 23, 20, 35, 10, 3, STALK, { bright: 0.1 })
  ball(c, 28 + 2 * g.a.dx, 41 - g.a.lift, 5, 3, STALK)
  // gills under the rim, then the dome
  ball(c, 23, 20, 20, 5, "lGG", { seam: null })
  ball(c, 23, 18, 21, 15, CAP, { clip: (x, y) => y < 19, bright: 0.05 })
  for (const [x, y, r] of [[13, 11, 2.5], [22, 7, 3], [31, 10, 2], [36, 15, 2], [18, 15, 1.5], [28, 15, 1.5]])
    ball(c, x, y, r, r * 0.8, "qxzy", { seam: null, bright: 0.2 })
  fur(c, STALK, 0.08, 4, 0, 1, 2)
  // face on the stalk
  c.stamp("_plant_eye", 21, 23); c.stamp("_plant_eye", 29, 23)
  c.poly([26, 31, 31, 31, 30, 33, 27, 33], "k"); c.px(28, 32, "j")
  c.px(20, 30, "j")
}, 1.35)

// Boss: a hunched, shaggy tree beast (Dota "shagbark"), drawn at boss resolution like boss_hound.
creature("shagbark_walk", 72, 66, (c, g) => {
  // far limbs
  tube(c, 20, 44, 6, 13 + 3 * g.b.dx, 62 - g.b.lift, 4, BARK)
  tube(c, 52, 40, 5, 61 + 3 * g.b.dx, 61 - g.b.lift, 4, BARK)
  ball(c, 61 + 3 * g.b.dx, 62 - g.b.lift, 5, 3, BARK)
  // torso, mossy canopy on the back, twigs
  ball(c, 34, 38, 24, 15, BARK, { bright: 0.1 })
  bark(c, 12, 56, 26, 52, 11, (x, y) => x >= 48)
  tube(c, 30, 16, 2, 25, 3, 1, BARK); tube(c, 44, 15, 2, 50, 4, 1, BARK); tube(c, 26, 7, 1, 21, 5, 1, BARK)
  for (const [x, y, rx, ry] of [[14, 30, 8, 7], [24, 22, 14, 10], [39, 19, 13, 10], [51, 25, 9, 7]])
    ball(c, x, y, rx, ry, MOSS, { seam: null })
  c.noise(14, 12, 44, 12, "e", 0.08, 4, "d")
  for (const [x, y, n] of [[18, 51, 5], [24, 52, 6], [31, 53, 4], [38, 52, 5], [44, 51, 4]]) c.vline(x, y, n, "b")
  fur(c, BARK, 0.08, 9, 0, 1, 3); curls(c, MOSS, 0.04, 2)
  // head at the front with a mossy beard
  ball(c, 57, 40, 11, 10, BARK, { bright: 0.18 })
  ball(c, 58, 50, 7, 4.5, MOSS)
  c.vline(54, 53, 4, "b"); c.vline(58, 54, 5, "b"); c.vline(62, 53, 3, "b")
  ball(c, 59, 37, 8, 4, "k12", { seam: null })
  ball(c, 55, 37, 2.5, 2, "LY", { seam: null }); ball(c, 63, 37, 2.5, 2, "LY", { seam: null })
  c.px(55, 36, "w"); c.px(63, 36, "w")
  c.line(49, 32, 57, 34, "k"); c.line(61, 34, 68, 31, "k")
  c.poly([54, 44, 64, 44, 62, 47, 56, 47], "k"); c.px(56, 44, "v"); c.px(62, 44, "v")
  // near limbs
  tube(c, 26, 46, 7, 22 + 3 * g.a.dx, 63 - g.a.lift, 5, BARK)
  ball(c, 22 + 3 * g.a.dx, 63 - g.a.lift, 6, 3, BARK)
  tube(c, 46, 44, 6, 47 + 3 * g.a.dx, 63 - g.a.lift, 5, BARK)
  ball(c, 48 + 3 * g.a.dx, 63 - g.a.lift, 6, 3, BARK)
  // knuckle twigs
  c.line(51 + 3 * g.a.dx, 62 - g.a.lift, 54 + 3 * g.a.dx, 63 - g.a.lift, "2")
}, 1.15)

// ---------------------------------------------------------------- fish: shark, furry_fish, goldfish
use(["#050304"]) // fresh palette: ramps accumulate, so each family starts clean
pal({
  k: "#050304", w: "#fffaf0", m: "#3a0d10", p: "#c84a5a", T: "#f4efe2", o: "#d9822b", O: "#f2b84b",
  "1": "#101820", "2": "#22364a", "3": "#375676", "4": "#5279a0", "5": "#7ea3c4", "6": "#b4d0e6",
  r: "#6d7884", s: "#9aa6b2", t: "#c3ccd4", u: "#e3e8ec", v: "#f8fafb",
  a: "#3a0f1e", b: "#742542", c: "#b04466", d: "#e0708a", e: "#f6a6b4", f: "#ffd2d6",
  g: "#3a1e05", h: "#7a4508", i: "#c17a12", j: "#eeb02a", l: "#ffe07a",
  q: "#a04a10", x: "#e07a20", y: "#f7a640", z: "#ffd38a",
})
const SHARK = "123456", BELLY = "rstuv", CORAL = "abcdef", GOLD = "ghijl", FIN = "qxyz"
ramps("k123456", "2rstuv", "kabcdef", "kghijl", "hqxyz", "moO")

sprite("_fish_eye", `
  .kkk.
  kwOok
  kOkok
  kooOk
  .kkk.`)

creature("shark_walk", 56, 44, (c, g) => {
  // far fin-feet, tail, body, belly, dorsal fin, near fin-feet
  ball(c, 22 + 2 * g.b.dx, 38 - g.b.lift, 4, 2.5, SHARK)
  ball(c, 40 + 2 * g.a.dx, 38 - g.a.lift, 4, 2.5, SHARK)
  c.poly([10, 21, 0, 3, 7, 4, 15, 20], "4"); c.line(2, 5, 10, 19, "5")
  c.poly([10, 26, 0, 38, 7, 36, 15, 27], "2"); c.line(2, 37, 10, 27, "3")
  tube(c, 20, 24, 9, 9, 24, 3.5, SHARK)
  ball(c, 30, 24, 18, 11, SHARK, { bright: 0.1 })
  ball(c, 32, 31, 15, 7, BELLY, { seam: null, bright: 0.15, clip: (x, y) => y >= 27 && ((x + 0.5 - 30) / 18) ** 2 + ((y + 0.5 - 24) / 11) ** 2 <= 1 })
  c.poly([22, 15, 30, 2, 33, 4, 34, 15], "3"); c.line(30, 3, 32, 14, "5")
  fur(c, SHARK, 0.05, 2, -1, 0, 3)
  // gills, eye, toothy grin
  c.line(36, 21, 35, 27, "2"); c.line(38, 20, 37, 27, "2")
  c.stamp("_fish_eye", 40, 17)
  c.poly([38, 28, 50, 25, 47, 31, 40, 31], "m")
  for (let x = 40; x <= 48; x += 2) { c.px(x, 28 - (x - 40) / 3, "T"); c.px(x + 1, 30, "T") }
  ball(c, 26 + 2 * g.a.dx, 39 - g.a.lift, 4.5, 3, SHARK)
  ball(c, 44 + 2 * g.b.dx, 39 - g.b.lift, 4.5, 3, SHARK)
}, 1.14)

creature("furry_fish_walk", 50, 44, (c, g) => {
  ball(c, 17 + 2 * g.b.dx, 39 - g.b.lift, 4, 3, CORAL)
  ball(c, 32 + 2 * g.a.dx, 39 - g.a.lift, 4, 3, CORAL)
  // tail fin, fluffy round body with tufts, small top fin
  c.poly([10, 22, 1, 12, 3, 22, 1, 32], "c"); c.line(2, 14, 8, 21, "e"); c.line(2, 30, 8, 23, "b")
  for (const [x, y, r] of [[14, 14, 5], [22, 9, 6], [32, 10, 6], [38, 17, 5], [12, 26, 5], [36, 29, 5]]) ball(c, x, y, r, r, CORAL)
  ball(c, 25, 22, 16, 14, CORAL, { bright: 0.08 })
  // fur: short strands combed back, lighter on the lit side
  const rnd = c.rng(5)
  for (let i = 0; i < 70; i++) {
    const x = 11 + Math.floor(rnd() * 30), y = 9 + Math.floor(rnd() * 26)
    if (!c.is(x, y, CORAL) || !c.is(x - 2, y + 1, CORAL)) continue
    const k = x + y < 42 ? "f" : x + y < 54 ? "e" : "b"
    c.line(x, y, x - 2, y + 1, k)
  }
  // face
  c.stamp("_fish_eye", 28, 15); c.stamp("_fish_eye", 35, 16)
  c.poly([32, 26, 38, 26, 36, 29, 33, 29], "m"); c.px(34, 27, "p")
  ball(c, 22 + 2 * g.a.dx, 40 - g.a.lift, 4.5, 3, CORAL)
  ball(c, 36 + 2 * g.b.dx, 40 - g.b.lift, 4.5, 3, CORAL)
}, 1.35)

// Flyer: veil fins beat like wings (frame 0 up, frame 2 down).
creature("goldfish_flap", 54, 48, (c, g) => {
  const dn = Math.round(g.wing * 9)
  // far fin, veil tail
  fan(c, 30, 20, -150 - dn * 9, -95 - dn * 9, 15, "qxyz")
  fan(c, 13, 27, 145, 215, 14, "qxyz", 5)
  ball(c, 26, 27, 15, 11, GOLD, { bright: 0.1 })
  c.noise(14, 20, 24, 14, "j", 0.12, 5, "i")
  scallops(c, GOLD, 4, 3, 2)
  // bulging eyes, small mouth
  ball(c, 38, 22, 5, 5, GOLD, { bright: 0.2 })
  c.stamp("_fish_eye", 37, 20)
  c.poly([41, 31, 44, 30, 43, 32], "m"); c.px(43, 31, "p")
  // near fin and small bottom fins
  fan(c, 24, 23, -160 - dn * 9, -110 - dn * 9, 15, "qxyz", 5)
  fan(c, 24, 36, 95, 140, 7, "qxyz", 2); fan(c, 33, 36, 70, 110, 6, "qxyz", 2)
}, 1.3)

// ---------------------------------------------------------------- birds: flamingo, drodo, chicken
use(["#050304"]) // fresh palette: ramps accumulate, so each family starts clean
pal({
  k: "#050304", w: "#fffaf0", m: "#3a0d10", o: "#d9822b", O: "#f2b84b", n: "#1d1210",
  a: "#3d0f22", b: "#7a2445", c: "#b8466e", d: "#e4789a", e: "#f7a9c0", f: "#ffd6e2",
  r: "#5d5a63", s: "#8f8b95", t: "#bcb8c0", u: "#e2dee4", v: "#fbf9fb",
  g: "#3a1a05", h: "#9a4a10", i: "#e08a20", j: "#f7c45a",
  l: "#5a0d10", M: "#a3201c", q: "#e04a3a",
  x: "#6a4a08", y: "#c49518", z: "#f4dc6a",
  "1": "#2a1d18", "2": "#5a3d2e", "3": "#8a6248", "4": "#e8e0d0", "5": "#9c8f80",
  A: "#10302e", B: "#1f5753", C: "#2f8079", D: "#4fb0a2", E: "#8fd8c8",
})
const PINK = "abcdef", WHITE = "rstuv", BEAK = "ghij", COMB = "lMq", BELT = "xyz", DODO = "ABCDE"
ramps("kabcdef", "krstuv", "nghij", "klMq", "gxyz", "k12345", "kABCDE", "moO")

sprite("_bird_eye", `
  .kk.
  kwok
  kook
  .kk.`)

// Rides a skateboard: legs pump on the board, wheels turn, board stays on the ground.
creature("flamingo_walk", 44, 54, (c, g, f) => {
  const pump = [0, 1, 0, 1][f]
  // board and wheels
  c.rect(6, 47, 30, 3, "2"); c.hline(7, 47, 28, "3"); c.px(5, 48, "2"); c.px(36, 48, "2")
  for (const x of [11, 30]) { c.circ(x, 51, 2, "1"); c.px(x + [0, 1, 0, -1][f], 51 + [-1, 0, 1, 0][f], "5") }
  // long legs with a bent knee
  tube(c, 18, 31, 1.6, 15 - pump, 39 + pump, 1.3, PINK); tube(c, 15 - pump, 39 + pump, 1.3, 17, 46, 1.2, PINK)
  tube(c, 23, 31, 1.6, 26 + pump, 39 + pump, 1.3, PINK); tube(c, 26 + pump, 39 + pump, 1.3, 24, 46, 1.2, PINK)
  // body, tail feathers, folded wing
  fan(c, 10, 25, 150, 210, 8, "bcde", 3)
  ball(c, 20, 25, 12, 8, PINK, { bright: 0.25 })
  fan(c, 25, 22, 160, 215, 13, "bcde", 4)
  scallops(c, PINK, 4, 3, 5)
  // S-shaped neck and head with a bent beak
  tube(c, 28, 22, 3, 31, 12, 2.2, PINK, { bright: 0.25 }); tube(c, 31, 12, 2.2, 29, 5, 2.4, PINK, { bright: 0.25 })
  ball(c, 31, 5, 4.5, 4, PINK, { bright: 0.2 })
  c.poly([34, 4, 41, 7, 41, 11, 38, 9, 34, 7], "w"); c.poly([38, 8, 41, 8, 41, 12, 39, 10], "n")
  c.stamp("_bird_eye", 30, 3)
}, 1.12)

// Drodo: a chubby flightless sea-dragon bird with a heavy beak.
creature("drodo_walk", 50, 46, (c, g) => {
  tube(c, 21, 33, 2.5, 19 + 3 * g.b.dx, 42 - g.b.lift, 2, BEAK); ball(c, 19 + 3 * g.b.dx, 43 - g.b.lift, 3.5, 1.8, BEAK)
  fan(c, 9, 22, 160, 230, 9, "BCDE", 3)
  ball(c, 23, 25, 15, 12, DODO, { bright: 0.1 })
  ball(c, 24, 30, 10, 6, "BDE" + "E", { seam: null, clip: (x, y) => y > 27, bright: 0.2 })
  fan(c, 23, 21, 170, 230, 11, "ABCD", 3)
  scallops(c, DODO, 4, 3, 6)
  // head, crest, beak
  ball(c, 36, 15, 8, 7.5, DODO, { bright: 0.2 })
  c.poly([33, 8, 30, 2, 35, 6, 37, 1, 39, 8], "C")
  c.poly([41, 13, 49, 15, 49, 20, 46, 22, 41, 20], "i"); c.line(42, 18, 49, 18, "h"); c.px(48, 15, "j"); c.px(47, 21, "h")
  c.stamp("_bird_eye", 36, 12)
  tube(c, 28, 34, 2.5, 30 + 3 * g.a.dx, 43 - g.a.lift, 2, BEAK); ball(c, 31 + 3 * g.a.dx, 44 - g.a.lift, 3.5, 1.8, BEAK)
}, 1.14)

// Belted chicken: white hen with a red comb and a gold champion belt.
creature("chicken_walk", 44, 46, (c, g) => {
  tube(c, 18, 32, 1.6, 17 + 3 * g.b.dx, 42 - g.b.lift, 1.3, BEAK); c.hline(15 + 3 * g.b.dx, 43 - g.b.lift, 5, "h")
  fan(c, 10, 20, 170, 245, 11, "stuv", 4)
  ball(c, 21, 25, 13, 11, WHITE, { bright: 0.12 })
  fan(c, 22, 22, 165, 220, 11, "rstu", 3)
  scallops(c, WHITE, 4, 3, 7)
  // belt
  c.clip((x, y) => (((x + 0.5 - 21) / 13) ** 2 + ((y + 0.5 - 25) / 11) ** 2) <= 1, () => { c.rect(7, 27, 30, 4, "y"); c.hline(7, 27, 30, "z"); c.hline(7, 30, 30, "x") })
  ball(c, 25, 29, 3.5, 3, BELT, { bright: 0.2 }); c.px(25, 29, "q")
  // head, comb, wattle, beak
  ball(c, 32, 12, 7, 7, WHITE, { bright: 0.2 })
  for (const [x, y] of [[29, 5], [32, 4], [35, 5]]) ball(c, x, y, 2.2, 2.6, COMB, { bright: 0.2 })
  c.poly([38, 11, 43, 13, 38, 15], "i"); c.line(38, 13, 42, 13, "h")
  ball(c, 37, 18, 1.8, 2.5, COMB, { bright: 0.1 })
  c.stamp("_bird_eye", 32, 9)
  tube(c, 25, 33, 1.6, 26 + 3 * g.a.dx, 43 - g.a.lift, 1.3, BEAK); c.hline(25 + 3 * g.a.dx, 44 - g.a.lift, 5, "h")
}, 1.32)

// ---------------------------------------------------------------- craft: corsair, carpet_rider
use(["#050304"]) // fresh palette: ramps accumulate, so each family starts clean
pal({
  k: "#050304", w: "#fffaf0", m: "#3a0d10", o: "#d9822b", O: "#f2b84b", n: "#1d1210",
  "1": "#1f120a", "2": "#3e2414", "3": "#63391d", "4": "#8a5429", "5": "#b37440", "6": "#d89a5c",
  r: "#6e5f48", s: "#a8967a", t: "#d6c6a6", u: "#efe4cb", v: "#fffaf0",
  a: "#3a0a0e", b: "#741620", c: "#b0283a", d: "#de4a52",
  e: "#2a0d3a", f: "#4c1a63", g: "#74308f", h: "#a04fb8", i: "#cc84dc",
  x: "#6a4a08", y: "#c49518", z: "#f4dc6a",
  A: "#132a10", B: "#2b5420", C: "#4c8a32", D: "#7fbd4c", E: "#b8e27c",
  p: "#c84a5a",
})
const HULL = "123456", SAIL = "rstuv", RED = "abcd", RUG = "efghi", GOLDT = "xyz", GOBLIN = "ABCDE"
ramps("k123456", "krstuv", "kabcd", "kefghi", "2xyz", "kABCDE", "moO")

// Flying pirate ship (Dota "corsair ship"): feathered wings beat on both sides of the hull.
creature("corsair_flap", 58, 50, (c, g) => {
  const dn = g.wing
  fan(c, 40, 27, -125 - dn * 70, -60 - dn * 70, 19, "rstu", 5)
  // mast and billowing sail with a red stripe
  c.rect(27, 2, 2, 30, "3"); c.vline(27, 2, 30, "4")
  c.poly([29, 2, 37, 4, 29, 6], "c")
  ball(c, 30, 15, 13, 14, SAIL, { clip: (x, y) => y >= 5 && y <= 24 && x >= 19 && x <= 41, bright: 0.15 })
  c.clip((x, y) => c.is(x, y, SAIL), () => { c.rect(14, 9, 30, 3, "c"); c.rect(14, 18, 30, 2, "c") })
  c.hline(19, 5, 23, "3"); c.hline(19, 24, 23, "3")
  // hull: rounded bottom half, planks, rail, bow
  ball(c, 28, 30, 23, 12, HULL, { clip: (x, y) => y >= 28, bright: 0.1 })
  c.poly([48, 28, 56, 22, 54, 28], "4")
  c.rect(5, 27, 46, 2, "5"); c.hline(5, 27, 46, "6")
  for (const y of [32, 36]) c.clip((x, yy) => c.is(x, yy, HULL), () => c.hline(4, y, 50, "2"))
  for (const x of [16, 24, 32, 40]) c.circ(x, 31, 1, "1")
  ball(c, 9, 30, 3, 3, GOLDT, { bright: 0.2 })
  fan(c, 18, 28, -170 - dn * 70, -105 - dn * 70, 21, "rstuv", 6)
}, 1.03)

// Boss: a smeevil riding a flying carpet; the carpet ripples, gold tassels swing.
creature("carpet_rider_flap", 74, 62, (c, g, f) => {
  const wave = (x) => Math.round(Math.sin(x / 9 + f * Math.PI / 2) * 2.5)
  const s = S(c), raw = C(c), top = (x) => 44 + wave(x) - Math.round((x - 4) * 0.06)
  for (let px = R(4 * s); px <= R(70 * s); px++) {
    const x = px / s, y = R(top(x) * s), band = R(8 * s)
    for (let yy = 0; yy < band; yy++) {
      const v = yy / s
      raw.px(px, y + yy, v < 1 ? "i" : v < 2 ? "h" : v > 6 ? "e" : (x + v) % 8 < 4 ? "g" : "f")
    }
    if (R(x) % 6 === 0 && Math.abs(x - R(x)) < 0.5 / s) { raw.px(px, y + R(2 * s), "y"); raw.px(px, y + R(5 * s), "y") }
  }
  for (let x = 4; x <= 70; x += 4) c.vline(x, top(x) + 8, 3 + (x % 8 === 0 ? 1 : 0), "y")
  c.vline(3, 44 + wave(3), 8, "x"); c.vline(71, 40 + wave(71), 8, "x")
  // smeevil: green body, big ears, grin, waving arm
  const bob = [0, 1, 0, -1][f]
  ball(c, 34, 33 + bob, 11, 10, GOBLIN, { bright: 0.12 })
  ball(c, 40, 20 + bob, 10, 9, GOBLIN, { bright: 0.2 })
  c.poly([32, 16 + bob, 18, 8 + bob, 31, 22 + bob], "C"); c.poly([47, 15 + bob, 60, 6 + bob, 49, 21 + bob], "D")
  c.line(22, 10 + bob, 31, 18 + bob, "B"); c.line(57, 8 + bob, 49, 17 + bob, "B")
  for (const x of [38, 45]) { c.circ(x, 18 + bob, 2, "k"); c.px(x, 18 + bob, "O"); c.px(x - 1, 17 + bob, "w") }
  c.poly([37, 25 + bob, 48, 24 + bob, 46, 28 + bob, 39, 28 + bob], "m"); c.hline(39, 25 + bob, 7, "w")
  // vest and a waving arm holding a gold coin
  ball(c, 34, 36 + bob, 8, 6, RED, { clip: (x, y) => y >= 32 + bob, seam: null })
  tube(c, 44, 31 + bob, 2.5, 54, 24 + bob - 2 * [0, 1, 2, 1][f], 2, GOBLIN)
  ball(c, 55, 22 + bob - 2 * [0, 1, 2, 1][f], 3, 3, GOLDT, { bright: 0.2 })
}, 1.06)

// ---------------------------------------------------------------- spirits: young_demon, ghost, ripper
use(["#050304"]) // fresh palette: ramps accumulate, so each family starts clean
pal({
  k: "#050304", w: "#fffaf0", m: "#2a0608", o: "#d9822b", O: "#f2b84b", Y: "#fff27a",
  "1": "#2a0606", "2": "#5a0f0e", "3": "#8e1c16", "4": "#c2321f", "5": "#e8603a", "6": "#f79a64",
  r: "#3a2a24", s: "#6a5246", t: "#a08676", u: "#d4c2b0", v: "#f2e8da",
  a: "#0a1e26", b: "#123a48", c: "#1f6472", d: "#3a9ea4", e: "#7fd8cc", f: "#c8fff0",
  g: "#141418", h: "#2c2c34", i: "#4a4a56", j: "#74747f", l: "#a6a6ae",
  x: "#1a3a0e", y: "#4ea82a", z: "#b6ff6a",
})
const IMP = "123456", HORN = "rstuv", WRAITH = "abcdef", IRON = "ghijl", BONE = "rstuv", GLOW = "xyz"
ramps("k123456", "krstuv", "kabcdef", "kghijl", "xyz", "oOY")

// Imp: small red demon on two legs, bat wings, spade tail.
creature("young_demon_walk", 46, 46, (c, g) => {
  // wings and tail behind
  fan(c, 20, 20, -185, -115, 17, "2345", 4)
  tube(c, 14, 30, 2, 5, 34, 1.2, IMP); c.poly([2, 31, 6, 31, 4, 37], "3")
  tube(c, 18, 33, 2.5, 16 + 3 * g.b.dx, 42 - g.b.lift, 2, IMP)
  ball(c, 22, 28, 9, 9, IMP, { bright: 0.1 })
  fan(c, 25, 19, -125, -55, 15, "2345", 4)
  tube(c, 25, 34, 2.5, 27 + 3 * g.a.dx, 43 - g.a.lift, 2, IMP)
  fur(c, IMP, 0.05, 4, -1, 1, 2)
  // big head, horns, glowing eyes, fangs
  ball(c, 28, 15, 10, 9, IMP, { bright: 0.2 })
  tube(c, 22, 9, 2, 17, 2, 0.6, HORN); tube(c, 32, 8, 2, 37, 1, 0.6, HORN)
  for (const x of [27, 34]) { ball(c, x, 14, 2.5, 2, "oOY", { seam: null }); c.px(x, 14, "k") }
  c.line(24, 11, 29, 12, "k"); c.line(32, 12, 37, 10, "k")
  c.poly([29, 19, 37, 18, 35, 22, 31, 22], "m"); c.px(31, 19, "w"); c.px(35, 19, "w")
  // arm with claws
  tube(c, 27, 25, 2.2, 32, 31, 1.8, IMP); tube(c, 32, 31, 1.8, 37, 28, 1.5, IMP); c.line(37, 28, 40, 26, "v"); c.line(37, 29, 40, 30, "v")
}, 1.35)

// Boss: a hooded wraith; the tattered robe streams down and back, its claws reach forward.
creature("ghost_flap", 70, 66, (c, g, f) => {
  const sway = [0, 1, 2, 1][f]
  // tattered robe strands streaming down-left behind the body
  for (let s = 0; s < 5; s++) {
    const x0 = 26 + s * 5, y0 = 38, ph = f * Math.PI / 2 + s
    tube(c, x0, y0, 4, x0 - 10 - s * 2 + Math.round(Math.sin(ph) * 2), 58 + (s % 2) * 4, 1, WRAITH, { bright: -0.1 })
  }
  // robe body widening downward
  ball(c, 38, 36, 14, 18, WRAITH, { clip: (x, y) => y >= 24 && y <= 50, bright: 0.05 })
  c.noise(24, 26, 28, 24, "e", 0.05, 6, "cd")
  fur(c, WRAITH, 0.1, 5, -1, 2, 3)
  // hood with a dark face hollow and glowing eyes
  ball(c, 42, 17, 12, 12, WRAITH, { bright: 0.15 })
  c.line(31, 12, 40, 6, "e"); c.line(30, 16, 33, 10, "d")
  ball(c, 46, 20, 7, 7.5, "gh", { seam: null })
  for (const x of [44, 49]) { ball(c, x, 19, 1.8, 1.6, GLOW, { seam: null }); c.px(x, 19, "z") }
  // bony claws reaching forward, one low
  tube(c, 44, 32, 3, 56, 31 - sway, 2.2, WRAITH); tube(c, 56, 31 - sway, 1.4, 62, 28 - sway, 1, BONE)
  c.line(62, 28 - sway, 66, 26 - sway, "u"); c.line(62, 29 - sway, 66, 30 - sway, "u"); c.line(61, 30 - sway, 63, 33 - sway, "u")
  tube(c, 46, 38, 3, 54, 44 + sway, 2, WRAITH); c.line(54, 44 + sway, 58, 46 + sway, "u"); c.line(54, 45 + sway, 56, 48 + sway, "u")
}, 1.28)

// Deathripper: a skeletal iron raptor on two legs with a huge jaw and green soul glow.
creature("ripper_walk", 56, 48, (c, g, f) => {
  // tail, far leg, ribcage body, spine spikes
  tube(c, 18, 22, 4, 2, 13, 1.5, IRON)
  tube(c, 22, 28, 4, 17 + 3 * g.b.dx, 38 - g.b.lift, 3, IRON); tube(c, 17 + 3 * g.b.dx, 38 - g.b.lift, 2.5, 20 + 3 * g.b.dx, 45 - g.b.lift, 2, BONE)
  ball(c, 26, 24, 13, 10, IRON, { bright: 0.12 })
  for (let x = 18; x <= 34; x += 4) c.line(x, 18, x - 1, 31, "g")
  ball(c, 27, 25, 5, 4.5, GLOW, { seam: null })
  for (const x of [16, 22, 28, 34]) c.poly([x - 3, 16, x, 7, x + 3, 16], "j")
  // neck and skull with a big open jaw
  tube(c, 35, 21, 4, 41, 15, 3.5, IRON)
  ball(c, 45, 13, 8, 7, BONE, { bright: 0.15 })
  c.poly([40, 17, 55, 16, 52, 21, 41, 20], "t")
  c.poly([41, 19 + f % 2, 54, 23 + f % 2, 50, 27 + f % 2, 41, 23], "s")
  for (let x = 43; x <= 53; x += 2) { c.px(x, 17, "v"); c.px(x, 23 + f % 2, "v") }
  ball(c, 46, 11, 2, 1.8, GLOW, { seam: null }); c.px(46, 11, "z")
  // near leg, digitigrade with claws
  tube(c, 30, 30, 4.5, 32 + 3 * g.a.dx, 39 - g.a.lift, 3, IRON); tube(c, 32 + 3 * g.a.dx, 39 - g.a.lift, 2.5, 30 + 3 * g.a.dx, 46 - g.a.lift, 2, BONE)
  c.line(30 + 3 * g.a.dx, 46 - g.a.lift, 35 + 3 * g.a.dx, 47 - g.a.lift, "u")
}, 1.06)

// ---------------------------------------------------------------- beasts: alpaca, sheep, baby_roshan
use(["#050304"]) // fresh palette: ramps accumulate, so each family starts clean
pal({
  k: "#050304", w: "#fffaf0", m: "#2a0608", o: "#d9822b", O: "#f2b84b", n: "#1d1210",
  "1": "#3a2a18", "2": "#6e5432", "3": "#a68558", "4": "#d2b585", "5": "#eedbb4", "6": "#fff3dc",
  r: "#4a4a52", s: "#8a8a94", t: "#c4c4cc", u: "#e8e8ee", v: "#ffffff",
  a: "#1a1416", b: "#3a2c2e", c: "#5c4748",
  d: "#3a0a0e", e: "#7a1622", f: "#c02c36", F: "#2a3a8a", G: "#4a68c8", x: "#c49518", y: "#f4dc6a",
  g: "#1e1a1c", h: "#3c3438", i: "#5e5258", j: "#857680", l: "#b0a0a8",
  q: "#6a5a40", z: "#c8b48c", Z: "#f0e2c0",
})
const WOOL = "123456", FLEECE = "rstuv", FACE = "abc", ROSH = "ghijl", TUSK = "qzZ", RUG2 = "def"
ramps("k123456", "krstuv", "kabc", "kghijl", "kqzZ", "kdef", "oO")

// Llama in a livery blanket: long neck, banana ears, four legs.
creature("alpaca_walk", 46, 56, (c, g) => {
  const leg = (x, y, s, near) => { tube(c, x, y, 2.5, x + 2 * s.dx, y + 13 - s.lift, 2, WOOL, { bright: near ? 0.1 : -0.1 }); c.hline(x - 1 + 2 * s.dx, y + 14 - s.lift, 4, "a") }
  leg(13, 38, g.b, false); leg(30, 38, g.a, false)
  ball(c, 6, 30, 3.5, 4, WOOL)
  ball(c, 21, 33, 15, 9, WOOL, { bright: 0.1 })
  // livery blanket with gold trim and tassels
  ball(c, 21, 30, 10, 7, RUG2, { clip: (x, y) => y >= 25 && y <= 37, seam: null, bright: 0.2 })
  c.hline(11, 37, 21, "x"); for (let x = 12; x <= 30; x += 3) c.px(x, 38, "y")
  c.rect(14, 29, 14, 2, "G"); c.hline(14, 29, 14, "F")
  fur(c, WOOL, 0.16, 8, -1, 1, 2)
  // neck and head
  tube(c, 31, 30, 5, 35, 12, 4, WOOL, { bright: 0.15 })
  ball(c, 37, 10, 6, 5, WOOL, { bright: 0.2 })
  c.poly([33, 6, 31, 0, 35, 4], "3"); c.poly([37, 5, 37, -1, 39, 4], "4")
  ball(c, 42, 12, 3, 2.5, "345", { seam: null }); c.px(44, 12, "n")
  c.circ(38, 9, 1, "k"); c.px(38, 8, "w")
  leg(17, 39, g.a, true); leg(33, 39, g.b, true)
}, 1.1)

// Boss: baby Roshan with stubby wings; tusks, horns, round belly.
creature("baby_roshan_flap", 70, 64, (c, g) => {
  const dn = g.wing
  fan(c, 30, 22, -150 - dn * 70, -90 - dn * 70, 20, "hijl", 5)
  // legs dangling, round body and belly
  ball(c, 26, 52, 6, 5, ROSH); ball(c, 44, 53, 6, 5, ROSH)
  ball(c, 34, 38, 19, 17, ROSH, { bright: 0.1 })
  ball(c, 37, 43, 12, 10, TUSK, { seam: null, bright: 0.05, clip: (x, y) => y >= 36 })
  fur(c, ROSH, 0.07, 4, -1, 1, 2)
  // head: brow ridge, horns, eyes, tusks
  ball(c, 48, 22, 13, 11, ROSH, { bright: 0.2 })
  tube(c, 40, 13, 3, 33, 2, 1, TUSK); tube(c, 54, 12, 3, 61, 2, 1, TUSK)
  c.line(41, 18, 48, 20, "g"); c.line(52, 20, 58, 17, "g")
  for (const x of [45, 54]) { c.circ(x, 22, 2, "k"); c.px(x, 22, "O"); c.px(x - 1, 21, "w") }
  c.poly([44, 28, 59, 27, 56, 32, 47, 32], "m")
  c.poly([45, 30, 44, 24, 47, 29], "Z"); c.poly([57, 29, 59, 23, 55, 28], "Z")
  // stubby arm and near wing
  tube(c, 46, 38, 4, 54, 44, 3, ROSH); ball(c, 55, 45, 3.5, 3, ROSH)
  fan(c, 26, 26, -170 - dn * 70, -105 - dn * 70, 22, "ijl" + "l", 6)
}, 1.25)

// ---------------------------------------------------------------- small mammals: rabbit, fox,
// jinyin_fox, wabbit, panda_flyer; amphibian rider: mermaid
use(["#050304"]) // fresh palette: ramps accumulate, so each family starts clean
pal({
  k: "#050304", w: "#fffaf0", m: "#2a0608", o: "#d9822b", O: "#f2b84b", n: "#1d1210", p: "#e07a8a",
  "1": "#3a2618", "2": "#6a4a30", "3": "#9a7450", "4": "#c49e74", "5": "#e2c49c", "6": "#f6e4c6",
  a: "#3a1006", b: "#74240c", c: "#b0461a", d: "#d9702c", e: "#f09a4e", f: "#ffc890",
  r: "#5d5a63", s: "#8f8b95", t: "#bcb8c0", u: "#e2dee4", v: "#fbf9fb",
  g: "#0e0c10", h: "#24202a", i: "#3c3644", j: "#5a5266",
  l: "#4a0a10", M: "#8e1622", N: "#d0303a",
  A: "#1c3a12", B: "#3a6e22", C: "#64a33a", D: "#9cd263",
  E: "#0a2a30", F: "#145058", G: "#1f7f86", H: "#3fb3ae", I: "#8fe0d0",
  x: "#6a4a08", y: "#c49518", z: "#f4dc6a",
})
const TAN = "123456", FOX = "abcdef", SNOW = "rstuv", INK = "ghij", CAPE = "lMN", BAMBOO = "ABCD", SEA = "EFGHI", BRASS = "xyz"
ramps("k123456", "kabcdef", "krstuv", "kghij", "klMN", "kABCD", "kEFGHI", "kxyz", "oO")

// One small four-legged body; o picks fur, ears, tail, wings and extras.
function mammal(c, g, o) {
  const fly = !!o.wings, dn = g.wing, hy = o.longEars ? 22 : 18
  const leg = (x, y, s, near, ramp) => fly
    ? tube(c, x, y, 2.2, x - 3, y + 5, 1.8, ramp, { bright: near ? 0.15 : -0.05 })
    : tube(c, x, y, 2.4, x + 3 * s.dx, y + (o.legLen ?? 9) - s.lift, 2, ramp, { bright: near ? 0.15 : -0.05 })
  if (fly) fan(c, 23, 23, -140 - dn * 75, -75 - dn * 75, 19, o.wings, 5)
  if (o.cape) c.poly([28, 18, 8, 22 + Math.round(dn * 4), 4, 34 + Math.round(dn * 3), 14, 30, 24, 26], o.cape[1])
  leg(15, 33, g.b, false, o.legs ?? o.fur); leg(28, 34, g.a, false, o.legs ?? o.fur)
  // tail: puff or brush with a pale tip
  if (o.tail === "brush") { tube(c, 12, 27, 3.5, 4, 14, 4.5, o.fur, { bright: 0.15 }); ball(c, 3, 11, 3.5, 3.5, o.tip ?? SNOW, { bright: 0.2 }) }
  else ball(c, 9, 27, 4, 4, o.tip ?? SNOW, { bright: 0.2 })
  ball(c, 21, 29, 12, 8.5, o.body ?? o.fur, { bright: 0.12 })
  if (o.belly) ball(c, 25, 33, 7, 4, o.belly, { seam: null, bright: 0.2, clip: (x, y) => y >= 31 })
  for (const ramp of new Set([o.fur, o.body ?? o.fur])) fur(c, ramp, 0.14, 11, -1, 1, 2)
  if (o.pack) o.pack(c)
  // head, muzzle, ears
  if (o.longEars) { tube(c, 31, hy - 5, 2.8, 26, hy - 17, 2.4, o.head ?? o.fur); tube(c, 35, hy - 5, 2.8, 38, hy - 18, 2.4, o.head ?? o.fur); c.line(37, hy - 15, 36, hy - 8, "p") }
  else { c.poly([28, hy - 4, 28, hy - 13, 33, hy - 6], o.ear ?? (o.head ?? o.fur)[3]); c.poly([34, hy - 6, 39, hy - 13, 39, hy - 4], o.ear ?? (o.head ?? o.fur)[4]) }
  ball(c, 34, hy, 8, 7, o.head ?? o.fur, { bright: 0.2 })
  ball(c, 40, hy + 3, 3, 2.5, o.muzzle ?? SNOW, { bright: 0.25, seam: null })
  c.px(43, hy + 2, "n")
  fur(c, o.head ?? o.fur, 0.1, 12, 1, 1, 1)
  if (o.mask) { c.rect(29, hy - 3, 11, 3, o.mask); c.hline(29, hy - 3, 11, "k") }
  c.stamp("_mammal_eye", 34, hy - 3)
  if (o.extra) o.extra(c, hy)
  leg(19, 35, g.a, true, o.legs ?? o.fur); leg(31, 35, g.b, true, o.legs ?? o.fur)
}

sprite("_mammal_eye", `
  .kk.
  kwok
  kook
  .kk.`)

creature("rabbit_walk", 48, 46, (c, g) => mammal(c, g, { fur: TAN, longEars: true, belly: "456", tip: SNOW, muzzle: "456", legLen: 6 }), 1.44)

creature("fox_flap", 50, 46, (c, g) => mammal(c, g, { fur: FOX, tail: "brush", wings: "rstuv", belly: SNOW, mask: "h", cape: CAPE, legs: INK }), 1.3)

creature("jinyin_fox_flap", 50, 46, (c, g) => mammal(c, g, { fur: SNOW, head: SNOW, tail: "brush", tip: INK, wings: "ghij", legs: INK, ear: "h", muzzle: SNOW,
  extra: (c, hy) => { c.line(30, hy + 4, 37, hy + 6, "i"); c.px(31, hy - 5, "z") } }), 1.3)

creature("wabbit_flap", 50, 50, (c, g) => mammal(c, g, { fur: SNOW, longEars: true, wings: "rstuv", cape: CAPE, belly: "uv",
  extra: (c, hy) => { ball(c, 34, hy - 6, 6, 2, BRASS, { seam: null, clip: (x, y) => y <= hy - 6 }); c.px(34, hy - 8, "N") } }), 1.42)

// Captain Bamboo: a panda with a bamboo rotor on its head and a bamboo pack.
creature("panda_flyer_flap", 50, 50, (c, g, f) => {
  const blades = [[-10, 0, 10, 0], [-7, -2, 7, 2], [0, -3, 0, 3], [-7, 2, 7, -2]][f]
  mammal(c, g, { fur: INK, body: SNOW, head: SNOW, tip: INK, legs: INK, ear: "g", muzzle: SNOW,
    pack: (c) => { c.rect(10, 18, 4, 14, "B"); c.vline(10, 18, 14, "C"); c.hline(10, 22, 4, "A"); c.hline(10, 27, 4, "A") },
    extra: (c, hy) => {
      ball(c, 32, hy - 1, 2.5, 2, INK, { seam: null }); c.px(32, hy - 1, "w")
      c.vline(34, hy - 12, 5, "B"); c.line(34 + blades[0], hy - 12 + blades[1], 34 + blades[2], hy - 12 + blades[3], "C")
      c.px(34, hy - 12, "A")
    } })
}, 1.38)

// Amphibian kid riding a little flying fish; the fish's fins beat.
creature("mermaid_flap", 52, 50, (c, g) => {
  const dn = g.wing
  fan(c, 26, 30, -150 - dn * 75, -95 - dn * 75, 14, "FGHI", 4)
  fan(c, 9, 34, 145, 215, 10, "FGHI", 4)
  ball(c, 25, 35, 14, 8, SEA, { bright: 0.12 })
  ball(c, 36, 33, 4, 4, SEA, { bright: 0.25 }); c.stamp("_mammal_eye", 35, 31)
  scallops(c, SEA, 3, 2, 3)
  // the kid: green skin, fin ears, big eyes, riding on top
  ball(c, 22, 24, 6, 6, BAMBOO, { bright: 0.15 })
  ball(c, 25, 14, 8, 7, BAMBOO, { bright: 0.25 })
  c.poly([17, 12, 12, 7, 18, 16], "B"); c.poly([32, 11, 37, 5, 32, 16], "C")
  c.stamp("_mammal_eye", 23, 11); c.stamp("_mammal_eye", 28, 11)
  c.line(24, 18, 28, 18, "A")
  tube(c, 26, 23, 2, 33, 27, 1.6, BAMBOO)
  fan(c, 22, 33, -165 - dn * 75, -110 - dn * 75, 15, "FGHI", 5)
}, 1.42)

// Flat shaded face (box sides, lids, boards): polygon filled along a tone gradient from light0 at
// one end to light1 at the other (dir "x" or "y"), with the same brush clusters as tone().
function facet(c, pts, ramp, light0, light1, dir = "x", opts = {}) {
  const s = S(c); c = C(c)
  const sp = pts.map((v) => R(v * s))
  const xs = sp.filter((_, i) => i % 2 === 0), ys = sp.filter((_, i) => i % 2 === 1)
  const x0 = Math.min(...xs), x1 = Math.max(...xs), y0 = Math.min(...ys), y1 = Math.max(...ys)
  const under = new Map()
  for (let y = y0 - 1; y <= y1 + 1; y++) for (let x = x0 - 1; x <= x1 + 1; x++) under.set(x + "," + y, c.get(x, y))
  c.poly(sp, "#ff00ff")
  const mine = []
  for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) if (c.get(x, y) === 0xff00ffff) mine.push([x, y])
  const set = new Set(mine.map(([x, y]) => x + "," + y))
  for (const [x, y] of mine) {
    const t = dir === "x" ? (x - x0) / Math.max(1, x1 - x0) : (y - y0) / Math.max(1, y1 - y0)
    const edge = opts.edge !== false && [[1, 0], [-1, 0], [0, 1], [0, -1]].some(([dx, dy]) => !set.has((x + dx) + "," + (y + dy)) && under.get((x + dx) + "," + (y + dy)))
    c.px(x, y, edge ? "k" : tone(ramp, light0 + (light1 - light0) * t, x, y))
  }
}

// ---------------------------------------------------------------- boxhounds: lockjaw, trapjaw, machjaw
// Dota "Boxhound" couriers are treasure chests on legs: the lid is a biting jaw, the loot shows in
// the mouth, an eye (or periscope head) sits on top.
use(["#050304"]) // fresh palette: ramps accumulate, so each family starts clean
pal({
  k: "#050304", w: "#fffaf0",
  a: "#3a2606", b: "#7a5210", c: "#c08a1a", d: "#eec03a", e: "#fff08a",
  f: "#1e0a2a", g: "#3e1656", h: "#64288a", i: "#8e44b8", j: "#b876e0",
  l: "#14181c", m: "#2e363e", n: "#56626e", o: "#8a98a6", q: "#c6d2dc",
  r: "#0c0a0e", s: "#24202a", t: "#423c4a",
  u: "#0e4a14", v: "#2aa830", x: "#9cf27a",
  R: "#c82a2a", O: "#f08a2a", B: "#3a8ae8", P: "#ff9a8a",
  "1": "#8a8478", "2": "#c8c0b0", "3": "#f2ece0", "4": "#f6f0de", "5": "#2a0a10",
  "7": "#3a1c0a", "8": "#6e3a18", "9": "#a8642c",
})
const GOLDBOX = "abcde", PURPLE = "fghij", METAL = "lmnoq", BLACK = "rst", GEM = "uvx", IVORY = "123", HAIR = "789"
ramps("kabcde", "kfghij", "klmnoq", "krst", "kuvx", "k123", "k789")

// One chest body; o: body/trim ramps, legs (ramp, width), loot(c), top(c, lidTip), angle per frame.
function chest(c, g, f, o) {
  const open = (o.open ?? [16, 26, 16, 8])[f] * Math.PI / 180
  const lw = o.legWidth ?? 1.6
  // far leg, then the box: long side, narrow front face (3/4 view), rim and straps
  tube(c, 18, 34, lw, 16 + 3 * g.b.dx, 44 - g.b.lift, lw * 0.8, o.legs)
  facet(c, [8, 21, 36, 21, 36, 37, 8, 37], o.body, 0.85, 0.45, "x")
  facet(c, [36, 21, 43, 18, 43, 33, 36, 37], o.body, 0.35, 0.2, "y")
  for (const x of [13, 29]) facet(c, [x, 21, x + 3, 21, x + 3, 37, x, 37], o.trim, 0.7, 0.4, "x")
  facet(c, [8, 34, 36, 34, 36, 37, 8, 37], o.trim, 0.6, 0.3, "x")
  facet(c, [36, 31, 43, 29, 43, 33, 36, 37], o.trim, 0.3, 0.2, "y")
  // mouth: dark inside, loot heaped on the rim, teeth on the rim
  const hx = 8, hy = 21, len = 30
  const tipX = hx + Math.cos(open) * len, tipY = hy - Math.sin(open) * len
  c.poly([hx, hy, tipX + 6, tipY + 1, 43, 18, 36, 21], "5")
  o.loot(c)
  for (let x = 12; x <= 34; x += 4) c.poly([x, 21, x + 2, 21, x + 1, 18], "4")
  // lid: a slab hinged at the back edge, teeth along its front edge
  const nx = Math.sin(open), ny = Math.cos(open), th = 6
  const lid = [hx, hy, tipX, tipY, tipX - nx * th, tipY - ny * th, hx - nx * th, hy - ny * th]
  for (let i = 1; i <= 4; i++) {
    const t = i / 5, bx = hx + (tipX - hx) * t, by = hy + (tipY - hy) * t
    c.poly([bx - 1, by, bx + 1, by, bx + nx * 3, by + ny * 3], "4")
  }
  facet(c, lid, o.body, 0.95, 0.6, "y")
  facet(c, [tipX, tipY, tipX + 6, tipY + 1, tipX + 6 - nx * th, tipY + 1 - ny * th, tipX - nx * th, tipY - ny * th], o.body, 0.4, 0.25, "y")
  facet(c, [hx + (tipX - hx) * 0.55, hy + (tipY - hy) * 0.55, hx + (tipX - hx) * 0.68, hy + (tipY - hy) * 0.68,
    hx + (tipX - hx) * 0.68 - nx * th, hy + (tipY - hy) * 0.68 - ny * th, hx + (tipX - hx) * 0.55 - nx * th, hy + (tipY - hy) * 0.55 - ny * th], o.trim, 0.8, 0.5, "y")
  o.top(c, hx + (tipX - hx) * 0.45 - nx * th, hy + (tipY - hy) * 0.45 - ny * th, open)
  // near leg
  tube(c, 30, 35, lw, 32 + 3 * g.a.dx, 45 - g.a.lift, lw * 0.8, o.legs)
  c.line(29 + 3 * g.a.dx, 45 - g.a.lift, 35 + 3 * g.a.dx, 45 - g.a.lift, o.legs[0])
}

function bigEye(c, x, y, r, iris) {
  ball(c, x, y, r, r, "q3w" + "w", { bright: 0.3 })
  ball(c, x + r * 0.25, y + 0.3, r * 0.55, r * 0.55, "k" + iris + iris, { seam: null, bright: 0.2 })
  c.px(x + r * 0.25, y + 0.3, "k"); c.px(x - r * 0.2, y - r * 0.35, "w")
}

// Lockjaw: golden chest with white viking horns and a blue eye; gold coins inside.
creature("lockjaw_walk", 50, 48, (c, g, f) => chest(c, g, f, {
  body: GOLDBOX, trim: METAL, legs: METAL, legWidth: 2.2,
  loot: (c) => { for (const [x, y] of [[14, 20], [19, 19], [24, 20], [29, 19], [33, 20], [22, 18]]) ball(c, x, y, 2.4, 1.6, GOLDBOX, { bright: 0.3 }) },
  top: (c, x, y) => {
    tube(c, x - 4, y + 1, 2.2, x - 9, y - 7, 0.8, IVORY, { bright: 0.2 }); tube(c, x + 5, y + 1, 2.2, x + 10, y - 7, 0.8, IVORY, { bright: 0.2 })
    bigEye(c, x + 1, y - 2, 4, "B")
  },
}), 1.33)

// Trapjaw: purple chest with black trim, green gems, curved black horns, one orange eye, thin legs.
creature("trapjaw_walk", 50, 48, (c, g, f) => chest(c, g, f, {
  body: PURPLE, trim: BLACK, legs: BLACK, legWidth: 1.3, open: [20, 30, 20, 12],
  loot: (c) => { for (const [x, y] of [[14, 20], [19, 18], [25, 19], [30, 18], [34, 20]]) ball(c, x, y, 2.6, 2.2, GEM, { bright: 0.3 }) },
  top: (c, x, y) => {
    tube(c, x - 7, y - 3, 2, x - 1, y - 9, 1.2, HAIR)
    tube(c, x - 3, y, 1.8, x - 12, y - 6, 1, BLACK); tube(c, x - 12, y - 6, 1, x - 13, y - 10, 0.7, BLACK)
    tube(c, x + 5, y, 1.8, x + 13, y - 6, 1, BLACK); tube(c, x + 13, y - 6, 1, x + 13, y - 10, 0.7, BLACK)
    bigEye(c, x + 1, y - 3, 4.5, "O")
  },
}), 1.29)

// Mechjaw: riveted steel chest with a periscope head (one red eye) and gold coins inside.
creature("machjaw_walk", 50, 52, (c, g, f) => chest(c, g, f, {
  body: METAL, trim: GOLDBOX, legs: METAL, legWidth: 2,
  loot: (c) => { for (const [x, y] of [[14, 20], [19, 19], [24, 20], [29, 19], [33, 20]]) ball(c, x, y, 2.4, 1.6, GOLDBOX, { bright: 0.3 }) },
  top: (c, x, y) => {
    tube(c, x, y, 1.6, x, y - 6, 1.6, METAL)
    tube(c, x - 1, y - 4, 1, x - 7, y - 6, 1, METAL); tube(c, x + 1, y - 4, 1, x + 6, y - 8, 1, METAL)
    facet(c, [x - 6, y - 15, x + 7, y - 15, x + 7, y - 6, x - 6, y - 6], METAL, 0.9, 0.5, "x")
    for (const px of [x - 5, x + 6]) { c.px(px, y - 14, "q"); c.px(px, y - 7, "q") }
    bigEye(c, x + 1, y - 10.5, 3.5, "R")
  },
}), 1.29)

// ---------------------------------------------------------------- lilnova, zombie, boooofus
use(["#050304"]) // fresh palette: ramps accumulate, so each family starts clean
pal({
  k: "#050304", w: "#fffaf0", m: "#2a0608", p: "#e0607a",
  a: "#160c12", b: "#2c1a24", c: "#463040", d: "#62485a", e: "#84687a",
  f: "#1c2836", g: "#38506a", h: "#6684a4", i: "#a4bed8", j: "#e2eef8",
  l: "#2affff", L: "#c8ffff",
  n: "#0a1430", o: "#18285a", q: "#2c4690", r: "#4a6cc4",
  s: "#2a5450", t: "#3f807a", u: "#62aea4", v: "#9adccf",
  x: "#6a4a08", y: "#c49518", z: "#f4dc6a",
  "1": "#5a4e40", "2": "#9a8c76", "3": "#d2c6ae", "4": "#f4ecd8",
  "5": "#3a0a0e", "6": "#8e1622", "7": "#d0303a",
  "8": "#4a2e18", "9": "#8a5a30",
})
const NOVA = "abcde", HELM = "fghij", ROBE = "noqr", SKIN = "stuv", TRIM = "xyz", SKULL = "1234", ROPE = "567", HAFT = "89"
ramps("kabcde", "kfghij", "knoqr", "kstuv", "kxyz", "k1234", "k567", "k89")

// Lil' Nova: a shaggy dark lion cub (Luna's mount) in a silver-blue helm with glowing eyes.
creature("lilnova_walk", 50, 46, (c, g) => {
  const leg = (x, y, s, near) => {
    tube(c, x, y, 3.2, x + 3 * s.dx, y + 8 - s.lift, 2.6, NOVA, { bright: near ? 0.15 : -0.05 })
    ball(c, x + 3 * s.dx, y + 8 - s.lift, 2.6, 1.6, HELM, { bright: 0.2, seam: null })
    c.px(x + 3 * s.dx + 2, y + 10 - s.lift, "i")
  }
  leg(14, 33, g.b, false); leg(28, 34, g.a, false)
  tube(c, 11, 28, 2, 4, 20, 1.3, NOVA); ball(c, 4, 19, 3, 3, NOVA, { bright: -0.1 })
  ball(c, 20, 30, 12, 8.5, NOVA, { bright: 0.12 })
  fur(c, NOVA, 0.2, 7, -1, 1, 2)
  // round shaggy mane behind a big cub head
  ball(c, 33, 21, 11, 11, NOVA, { bright: -0.1 })
  fur(c, NOVA, 0.3, 9, 1, 1, 2)
  ball(c, 36, 23, 8, 7.5, NOVA, { bright: 0.25 })
  ball(c, 41, 27, 4, 3, "cde", { seam: null, bright: 0.25 }); c.px(44, 25, "k"); c.px(42, 29, "w")
  // helm over brow and snout ridge, glowing eye slots, a crest fin
  ball(c, 36, 19, 8.5, 5.5, HELM, { clip: (x, y) => y <= 21, bright: 0.2 })
  c.poly([31, 15, 27, 8, 35, 13], "h"); c.line(29, 10, 33, 14, "i")
  for (const x of [35, 40]) { c.px(x, 21, "l"); c.px(x + 1, 21, "L"); c.px(x, 22, "l") }
  leg(18, 35, g.a, true); leg(32, 36, g.b, true)
}, 1.3)

// Zombie Hopper: a jiangshi child in a Qing official's robe and hat, talisman over the face,
// arms out; it hops with both feet together.
creature("zombie_walk", 44, 52, (c, g, f) => {
  const hop = [0, 2, 0, 2][f]
  // boots together, yellow hem, robe, rope sash
  ball(c, 18, 49 - hop, 3.5, 2, "kn" + "o", { bright: 0.2 }); ball(c, 25, 49 - hop, 3.5, 2, "kno", { bright: 0.3 })
  facet(c, [12, 40 - hop, 30, 40 - hop, 31, 47 - hop, 11, 47 - hop], TRIM, 0.9, 0.5, "x")
  ball(c, 21, 33 - hop, 11, 10, ROBE, { bright: 0.15, clip: (x, y) => y <= 42 - hop })
  c.line(13, 27 - hop, 29, 37 - hop, "y"); c.line(13, 28 - hop, 29, 38 - hop, "x")
  facet(c, [17, 32 - hop, 24, 32 - hop, 24, 39 - hop, 17, 39 - hop], "3z4", 0.9, 0.5, "y")
  c.line(19, 34 - hop, 22, 34 - hop, "6"); c.line(20, 36 - hop, 21, 37 - hop, "q")
  // stiff arms straight forward
  tube(c, 24, 27 - hop, 3, 37, 27 - hop, 2.6, ROBE, { bright: 0.1 })
  ball(c, 39, 27 - hop, 2.5, 2.2, SKIN, { bright: 0.2 }); c.line(40, 26 - hop, 42, 26 - hop, "s"); c.line(40, 28 - hop, 42, 28 - hop, "s")
  // head: blue-green skin, rosy cheeks, tongue, sleepy eyes
  ball(c, 24, 16 - hop, 9, 8.5, SKIN, { bright: 0.25 })
  c.px(21, 20 - hop, "p"); c.px(30, 20 - hop, "p")
  c.hline(24, 16 - hop, 2, "k"); c.hline(28, 16 - hop, 2, "k"); c.hline(24, 15 - hop, 2, "s"); c.hline(28, 15 - hop, 2, "s")
  c.rect(26, 20 - hop, 2, 3, "p"); c.px(26, 20 - hop, "m")
  // Qing hat: round crown, flat brim, blue bead on top; yellow talisman hanging over the brow
  ball(c, 23, 8 - hop, 9, 5, ROBE, { bright: 0.1, clip: (x, y) => y <= 9 - hop })
  facet(c, [12, 9 - hop, 34, 9 - hop, 33, 12 - hop, 13, 12 - hop], ROBE, 0.5, 0.3, "x")
  ball(c, 23, 2 - hop, 2, 2, "nqr" + "r", { bright: 0.3 })
  facet(c, [25, 10 - hop, 29, 10 - hop, 29, 19 - hop, 25, 19 - hop], TRIM, 0.95, 0.75, "y")
  c.vline(27, 12 - hop, 5, "7"); c.px(26, 14 - hop, "7")
}, 1.18)

// Boooofus: a tiny grim reaper in a blue hooded robe, skull face, red rope belt, scythe and sack.
creature("boooofus_walk", 50, 52, (c, g) => {
  // sack on the back, far foot
  ball(c, 11, 30, 6, 7, "1234", { bright: -0.1 }); c.line(9, 23, 13, 24, "6")
  ball(c, 18 + 2 * g.b.dx, 47 - g.b.lift, 3, 2, SKULL, { bright: 0.1 })
  // robe: bell shape with a ragged hem
  ball(c, 23, 34, 11, 13, ROBE, { bright: 0.15, clip: (x, y) => y <= 46 })
  for (let x = 14; x <= 32; x += 4) c.poly([x, 45, x + 2, 48, x + 4, 45], "o")
  c.line(13, 36, 33, 34, "6"); c.line(13, 37, 33, 35, "7"); c.line(22, 36, 20, 42, "6"); c.line(23, 36, 25, 42, "7")
  // scythe: long handle, curved grey blade above the hood
  c.line(36, 46, 30, 6, "8", 2); c.line(35, 46, 29, 6, "9")
  for (let i = 0; i <= 10; i++) {
    const a = (200 + i * 14) * Math.PI / 180
    tube(c, 30 + Math.cos(a) * 12 + 12, 9 + Math.sin(a) * 9, 2.6 - i * 0.2, 30 + Math.cos(a + 0.24) * 12 + 12, 9 + Math.sin(a + 0.24) * 9, 2.4 - i * 0.2, "fghij", { seam: null, bright: 0.2 })
  }
  // hood and skull face
  ball(c, 25, 18, 10, 10, ROBE, { bright: 0.2 })
  ball(c, 28, 20, 6, 6.5, SKULL, { bright: 0.3 })
  ball(c, 26, 19, 1.8, 2, "k", { seam: null }); ball(c, 31, 19, 1.6, 2, "k", { seam: null })
  c.px(29, 22, "k"); c.hline(26, 25, 5, "1"); for (let x = 26; x <= 30; x += 2) c.px(x, 24, "4")
  // bony hand gripping the handle, near foot
  ball(c, 33, 31, 2, 2, SKULL, { bright: 0.3 })
  ball(c, 27 + 2 * g.a.dx, 48 - g.a.lift, 3, 2, SKULL, { bright: 0.2 })
}, 1.2)

// ---------------------------------------------------------------- jumo, kupu, faun (sheep)
use(["#050304"]) // fresh palette: ramps accumulate, so each family starts clean
pal({
  k: "#050304", w: "#fffaf0", m: "#3a0d10", p: "#e0707a", O: "#f2b84b",
  a: "#5a3428", b: "#9a6248", c: "#d4987a", d: "#f2c8a8", e: "#fff0dc",
  f: "#1c1028", g: "#3a2250", h: "#5e3a7c", i: "#8a5aa8",
  j: "#4a0c10", l: "#8a1a1c", n: "#c8302a", q: "#ec6a40",
  r: "#183a14", s: "#2e6a22", t: "#5aa436", u: "#a6dc5c",
  v: "#5a1e06", x: "#a84408", y: "#ec8418", z: "#ffc458",
  A: "#2a1a10", B: "#5a3a22", C: "#8c6036", D: "#b88a52",
  E: "#3c4a2a", F: "#647a44", G: "#98ae6a", H: "#d6dcae",
  "1": "#2a1a2a", "2": "#58304e", "3": "#8c4a70", "4": "#c87298",
  "5": "#0e3a40", "6": "#1e7480", "7": "#3ab4b8",
})
const ELF = "abcde", PLUM = "fghi", DRESS = "jlnq", LEAF = "rstu", WING = "vxyz", GOATFUR = "ABCD", CLOTH = "EFGH", GRUB = "1234"
ramps("kabcde", "kfghi", "kjlnq", "krstu", "kvxyz", "kABCD", "kEFGH", "k1234", "BCDd")

sprite("_kid_eye", `
  .kk.
  k76k
  kk7k
  .kk.`)

// Jumo: an elf girl with leaf sprouts, plum hair bun, red dress, carrying a little lantern.
creature("jumo_walk", 40, 54, (c, g) => {
  tube(c, 17, 40, 1.8, 16 + 2 * g.b.dx, 50 - g.b.lift, 1.6, ELF)
  ball(c, 16 + 2 * g.b.dx, 51 - g.b.lift, 2.5, 1.5, DRESS)
  // skirt and top
  ball(c, 20, 39, 10, 8, DRESS, { bright: 0.15, clip: (x, y) => y >= 33 })
  ball(c, 20, 31, 6, 6, "xyz" + "z", { bright: 0.1 })
  c.hline(14, 35, 13, "z")
  // arm with lantern
  tube(c, 23, 30, 1.8, 29, 34, 1.5, ELF)
  c.line(30, 34, 30, 36, "A")
  facet(c, [27, 36, 33, 36, 33, 43, 27, 43], DRESS, 0.6, 0.3, "x")
  facet(c, [28, 37, 32, 37, 32, 42, 28, 42], "yz" + "w", 0.9, 0.6, "y")
  // big head, plum hair with a bun, elf ears, leaf sprouts
  tube(c, 12, 9, 2.6, 4, 2, 1, LEAF, { bright: 0.2 }); tube(c, 27, 8, 2.6, 34, 0, 1, LEAF, { bright: 0.2 })
  ball(c, 20, 18, 10, 9, PLUM, { bright: 0.15 })
  ball(c, 13, 12, 4, 4, PLUM, { bright: 0.2 })
  ball(c, 22, 21, 8, 7, ELF, { bright: 0.3, clip: (x, y) => y >= 15 })
  c.poly([29, 19, 35, 16, 30, 22], "c"); c.line(30, 19, 33, 17, "d")
  c.stamp("_kid_eye", 20, 19); c.stamp("_kid_eye", 25, 19)
  c.px(19, 24, "p"); c.px(28, 24, "p"); c.hline(23, 25, 2, "m")
  tube(c, 23, 41, 1.8, 24 + 2 * g.a.dx, 51 - g.a.lift, 1.6, ELF)
  ball(c, 24 + 2 * g.a.dx, 52 - g.a.lift, 2.5, 1.5, DRESS)
}, 1.12)

// Kupu the Metamorpher (flying form): an orange butterfly; both wing pairs beat together.
creature("kupu_flap", 54, 46, (c, g) => {
  const dn = g.wing
  // far wings, segmented body, near wings with eye spots
  fan(c, 26, 22, -120 - dn * 60, -50 - dn * 60, 20, "vxyz", 5)
  for (let i = 0; i < 5; i++) ball(c, 17 + i * 4, 26 - i * 0.6, 3.2, 3, GRUB, { bright: 0.15 })
  ball(c, 38, 22, 4.5, 4.5, GRUB, { bright: 0.25 })
  c.line(39, 18, 42, 10, "1"); c.line(41, 18, 47, 12, "1"); c.px(42, 9, "4"); c.px(47, 11, "4")
  c.stamp("_kid_eye", 38, 20)
  fan(c, 24, 23, -165 - dn * 60, -95 - dn * 60, 22, "vxyz", 6)
  fan(c, 22, 27, 160 - dn * 40, 215 - dn * 40, 13, "vxyz", 4)
}, 1.27)

// Forest Faun (the "sheep" wave): a satyr kid on goat legs with curly hair, small horns, a
// backpack and bagpipes.
creature("sheep_walk", 44, 54, (c, g) => {
  const goatLeg = (x, y, s, near) => {
    const kx = x - 3 + 3 * s.dx, ky = y + 6 - s.lift
    tube(c, x, y, 3, kx, ky, 2.2, GOATFUR, { bright: near ? 0.15 : -0.05 })
    tube(c, kx, ky, 2, kx + 2, ky + 7, 1.4, GOATFUR, { bright: near ? 0.1 : -0.1 })
    ball(c, kx + 2, ky + 8, 2.2, 1.5, "kAB", { seam: null })
  }
  goatLeg(18, 36, g.b, false)
  // backpack and bedroll
  facet(c, [5, 20, 13, 19, 13, 33, 5, 33], CLOTH, 0.6, 0.3, "x"); ball(c, 9, 18, 5, 2.5, "BCD", { bright: 0.2 })
  // furry hips and green vest
  ball(c, 20, 35, 8, 5, GOATFUR, { bright: 0.1 })
  fur(c, GOATFUR, 0.25, 4, 0, 1, 2)
  ball(c, 21, 27, 7.5, 8, CLOTH, { bright: 0.15 })
  // bagpipes: bag under the arm, pipes forward
  ball(c, 27, 30, 5, 4, "ABCD", { bright: 0.2 })
  c.line(30, 27, 39, 21, "y", 2); c.line(30, 28, 40, 25, "x", 2); c.line(28, 32, 36, 37, "x", 2)
  c.px(40, 20, "z"); c.px(41, 24, "z"); c.px(37, 38, "z")
  tube(c, 24, 24, 2, 31, 25, 1.6, ELF)
  // head: big ears, curly pale hair, little horns
  ball(c, 25, 13, 8, 8, ELF, { bright: 0.25 })
  c.poly([18, 12, 9, 9, 17, 16], "c"); c.poly([31, 11, 39, 7, 32, 15], "d")
  for (const [x, y] of [[20, 6], [24, 5], [28, 6], [19, 9], [30, 9]]) ball(c, x, y, 2.6, 2.4, "BCDd", { bright: 0.3 })
  curls(c, "BCDd", 0.3, 5)
  tube(c, 22, 5, 1.4, 20, 1, 0.8, "ABCD"); tube(c, 28, 5, 1.4, 30, 1, 0.8, "ABCD")
  c.stamp("_kid_eye", 24, 12); c.stamp("_kid_eye", 28, 12)
  c.px(31, 17, "m"); c.px(23, 17, "p")
  goatLeg(24, 37, g.a, true)
}, 1.15)

// ---------------------------------------------------------------- balloon badger (wave 5)
use(["#050304"]) // fresh palette: ramps accumulate, so each family starts clean
pal({
  k: "#050304", w: "#fffaf0", m: "#3a0d10",
  a: "#173a12", b: "#2f6a1e", c: "#58a030", d: "#94d052",
  e: "#6a2a06", f: "#b05410", g: "#e8862a", h: "#ffbc62",
  i: "#141216", j: "#34303a", l: "#5c5664", n: "#b8b2c0", o: "#f4f0f6",
  q: "#3a2414", r: "#6a4426", s: "#9a6a3e", t: "#c69a64",
  u: "#5a4a30", v: "#8e7a52", x: "#c4ae7c", y: "#ecdcb0",
})
const BALLOON = "abcd", PATCH = "efgh", BADGER = "ijlno", BROWNFUR = "qrst", SACK = "uvxy"
ramps("kabcd", "kefgh", "kijlno", "kqrst", "kuvxy")

// Fearless Badger, flying: hangs under two patchwork balloons with a big sack and a tail rotor.
creature("blue_courier_flap", 54, 64, (c, g, f) => {
  const bob = [0, 1, 2, 1][f]
  // balloons with diagonal patch seams, then ropes
  for (const [x, y, r, s] of [[18, 11 + bob, 10, 3], [37, 14 - bob, 9, 8]]) {
    ball(c, x, y, r, r * 1.1, BALLOON, { bright: 0.15 })
    c.clip((xx, yy) => ((xx - x) / r) ** 2 + ((yy - y) / (r * 1.1)) ** 2 <= 0.92, () => {
      for (let i = -2; i <= 2; i++) c.line(x - r + i * 6, y - r, x + i * 6 + r, y + r, "f")
      for (let i = -2; i <= 2; i++) c.line(x + r + i * 6, y - r, x + i * 6 - r, y + r, "e")
    })
    c.px(x - r * 0.4, y - r * 0.5, "d"); c.px(x - r * 0.4 + 1, y - r * 0.5, "d")
    c.poly([x - 2, y + r * 1.1 - 1, x + 2, y + r * 1.1 - 1, x, y + r * 1.1 + 2], "b")
  }
  c.line(19, 22 + bob, 24, 38, "r"); c.line(36, 24 - bob, 30, 38, "r")
  // sack, badger body with a green saddle cloth, dangling paws, tail rotor
  ball(c, 27, 38, 8, 6, SACK, { bright: 0.2 }); c.line(21, 36, 33, 41, "u"); c.line(27, 32, 27, 44, "u")
  ball(c, 26, 49, 13, 7, BROWNFUR, { bright: 0.1 })
  fur(c, BROWNFUR, 0.18, 3, -1, 1, 2)
  ball(c, 27, 45, 8, 4, BALLOON, { clip: (x, y) => y <= 47, seam: null, bright: 0.1 })
  for (const x of [17, 31]) tube(c, x, 53, 2, x - 1, 58 + (f % 2), 1.6, "ijl")
  const rot = [[0, -5, 0, 5], [-4, -3, 4, 3], [-5, 0, 5, 0], [-4, 3, 4, -3]][f]
  c.line(12, 47, 9, 47, "r"); c.line(8 + rot[0], 47 + rot[1], 8 + rot[2], 47 + rot[3], "t")
  // striped badger head looking forward-down
  ball(c, 41, 52, 7.5, 6.5, BADGER, { bright: 0.1 })
  c.clip((x, y) => ((x - 41) / 7.5) ** 2 + ((y - 52) / 6.5) ** 2 <= 1, () => { c.line(36, 46, 48, 55, "o"); c.line(36, 47, 48, 56, "n") })
  ball(c, 48, 56, 2.5, 2, BADGER, { bright: 0.3 }); c.px(50, 56, "k")
  c.circ(43, 50, 1, "k"); c.px(43, 49, "w")
}, 1)
