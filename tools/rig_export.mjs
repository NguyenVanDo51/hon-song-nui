#!/usr/bin/env node
// Export an svg-attack-anim spec (docs/anim_demo/<name>.spec.js) to pure data for the Godot rig runtime.
//   node tools/rig_export.mjs hero_p [hero_e ...]        -> assets/units/rig/<name>.json
//   node tools/rig_export.mjs --all                      -> every docs/anim_demo/*.spec.js except hero_slash
//   node tools/rig_export.mjs --sample hero_p gale 0,160,290   -> print every track channel at those ms (parity check)
// Functions (ev callbacks, springs.drive, idle, order, attack.draw) are NOT exported: they are hand-ported per unit
// in scripts/ui/rig/specs/<unit>.gd. Their presence is flagged in the JSON so the port can be cross-checked.
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const SRC = path.join(ROOT, 'docs/anim_demo');
const OUT = path.join(ROOT, 'assets/units/rig');

// ---------- engine globals (same semantics as ~/.claude/skills/svg-attack-anim/assets/engine.js) ----------
const E = {
  lin: u => u, out: u => 1 - (1 - u) ** 3, in: u => u * u * u,
  io: u => u < .5 ? 4 * u * u * u : 1 - (-2 * u + 2) ** 3 / 2,
  outExpo: u => u >= 1 ? 1 : 1 - 2 ** (-10 * u),
  outBack: u => { const c = 1.9; return 1 + (c + 1) * (u - 1) ** 3 + c * (u - 1) ** 2; },
  hold: u => 0,
};
const track = keys => {
  const f = t => {
    if (t <= keys[0][0]) return keys[0][1];
    for (let i = 1; i < keys.length; i++) if (t <= keys[i][0]) {
      const [t0, v0] = keys[i - 1], [t1, v1, e] = keys[i];
      return v0 + (v1 - v0) * E[e || 'io']((t - t0) / (t1 - t0));
    }
    return keys[keys.length - 1][1];
  };
  f.keys = keys;
  return f;
};
// minimal DOMMatrix stand-in: enough for bake / rotAbout / scaleAbout in spec top-level code
class Mat {
  constructor(a = 1, b = 0, c = 0, d = 1, e = 0, f = 0) { Object.assign(this, { a, b, c, d, e, f }); }
  multiply(m) {
    const { a, b, c, d, e, f } = this;
    return new Mat(a * m.a + c * m.b, b * m.a + d * m.b, a * m.c + c * m.d, b * m.c + d * m.d, a * m.e + c * m.f + e, b * m.e + d * m.f + f);
  }
  translate(x = 0, y = 0) { return this.multiply(new Mat(1, 0, 0, 1, x, y)); }
  rotate(deg = 0) { const r = deg * Math.PI / 180, cs = Math.cos(r), sn = Math.sin(r); return this.multiply(new Mat(cs, sn, -sn, cs, 0, 0)); }
  scale(sx = 1, sy = sx) { return this.multiply(new Mat(sx, 0, 0, sy, 0, 0)); }
  transformPoint(p) { return { x: this.a * p.x + this.c * p.y + this.e, y: this.b * p.x + this.d * p.y + this.f }; }
}
const M = () => new Mat();
const rotAbout = (m, x, y, d) => m.translate(x, y).rotate(d).translate(-x, -y);
const scaleAbout = (m, x, y, sx, sy) => m.translate(x, y).scale(sx, sy).translate(-x, -y);
const bake = (deg, px, py, x, y) => { const q = rotAbout(M(), px, py, deg).transformPoint({ x, y }); return [q.x, q.y]; };
let seed = 1;
const rnd = (a, b) => { seed = (seed * 16807) % 2147483647; return a + (seed / 2147483647) * (b - a); };
// browser-only names some specs touch at top level (ghost afterimage): inert stand-ins
class Image { constructor() { this.src = ''; } }
const __SVG = { full: '<svg width="256" height="256"></svg>', target: '', tile: '' };
const GLOBALS = { Image, __SVG, E, track, M, rotAbout, scaleAbout, bake, clamp: (v, a, b) => Math.max(a, Math.min(b, v)), lerp: (a, b, u) => a + (b - a) * u, rnd, INK: '#2b2220', Math, console };

function load(name) {
  const file = path.join(SRC, name + '.spec.js');
  const code = fs.readFileSync(file, 'utf8');
  const ctx = vm.createContext({ ...GLOBALS });
  // top-level const/let live in the script scope: return them from the same script
  const consts = [...new Set([...code.matchAll(/(?:^|[\s,;(])(?:const|let|var)\s+([A-Za-z_$][\w$]*)\s*=/gm)].map(m => m[1])
    .concat([...code.matchAll(/,\s*([A-Z_][A-Z0-9_]*)\s*=/g)].map(m => m[1])))];
  const grab = consts.map(n => `${JSON.stringify(n)}: typeof ${n} === 'undefined' ? undefined : ${n}`).join(', ');
  const res = vm.runInContext(code + `\n;({ SPEC, __consts: { ${grab} } })`, ctx, { filename: file });
  return { S: res.SPEC, consts: res.__consts };
}

const num = v => Math.round(v * 1e4) / 1e4;
// plain JSON-able values only (numbers, strings, bools, arrays/objects of those); functions / tracks dropped
function plain(v) {
  if (typeof v === 'number') return num(v);
  if (typeof v === 'string' || typeof v === 'boolean' || v === null) return v;
  if (typeof v === 'function' && v.keys) return { track: v.keys.map((q, i) => [num(q[0]), num(q[1]), i ? (q[2] || 'io') : 'io']) };
  if (Array.isArray(v)) { const a = v.map(plain); return a.includes(undefined) ? undefined : a; }
  if (typeof v === 'object' && Object.prototype.toString.call(v) === '[object Object]' && v.constructor?.name === 'Object') {  // cross-realm (vm) safe
    const o = {};
    for (const k in v) { const p = plain(v[k]); if (p !== undefined) o[k] = p; }
    return o;
  }
  return undefined;
}

function exportSpec(name) {
  const { S, consts } = load(name);
  const out = {
    name, title: S.title ?? name, feet: S.feet ?? 244, cx: S.cx ?? 128, outline: S.outline ?? 7, range: S.range ?? 1,
    targetFront: S.targetFront ?? 84, targetCY: S.targetCY ?? 150, shadowR: S.shadowR ?? 62,
    parts: S.parts, raw: S.raw || [],
    bones: S.bones.map(b => {
      const o = { name: b.name, parent: b.parent || 'root', pivot: (b.pivot || [0, 0]).map(num) };
      for (const k of ['ch', 'tx', 'ty', 'sc']) if (b[k]) o[k] = b[k];
      if (b.stretch) o.stretch = true;
      return o;
    }),
    draw: S.draw.map(d => d.slice()),
    points: Object.fromEntries(Object.entries(S.points || {}).map(([k, q]) => [k, [q[0], num(q[1]), num(q[2])]])),
    springs: Object.fromEntries(Object.entries(S.springs || {}).map(([k, sp]) => [k, { k: sp.k ?? 180, c: sp.c ?? 11 }])),
    hooks: { idle: !!S.idle, order: !!S.order },
    attacks: S.attacks.map(a => ({
      id: a.id, label: a.label ?? a.id, dur: num(a.dur),
      tr: Object.fromEntries(Object.entries(a.tr).map(([k, f]) => {
        // composite channel (e.g. track + wobble): sampled every 5 ms as linear keys (listed in `sampled`)
        if (!f.keys) { const ks = []; for (let t = 0; t <= a.dur; t += 5) ks.push([t, num(f(t)), 'lin']); return [k, ks]; }
        return [k, f.keys.map((q, i) => [num(q[0]), num(q[1]), i ? (q[2] || 'io') : 'io'])];
      })),
      sampled: Object.entries(a.tr).filter(([, f]) => !f.keys).map(([k]) => k),
      smear: a.smear ? plain(a.smear) : null,
      ev_times: (a.ev || []).map(e => num(e[0])),
      draw: !!a.draw,
    })),
    consts: {},
  };
  for (const [k, v] of Object.entries(consts)) {
    if (k === 'SPEC' || k === 'CHAR') continue;
    const p = plain(v);
    if (p !== undefined) out.consts[k] = p;
  }
  fs.mkdirSync(OUT, { recursive: true });
  const file = path.join(OUT, name + '.json');
  fs.writeFileSync(file, JSON.stringify(out, null, 1) + '\n');
  console.log(path.relative(ROOT, file), `${Object.keys(out.parts).length} parts, ${out.bones.length} bones, ${out.attacks.map(a => a.id + ' ' + a.dur + 'ms').join(', ')}`);
}

const args = process.argv.slice(2);
if (args[0] === '--sample') {
  const [, name, id, times] = args;
  const { S } = load(name);
  const A = S.attacks.find(a => a.id === id) || S.attacks[0];
  for (const t of times.split(',').map(Number)) {
    const row = Object.entries(A.tr).map(([k, f]) => `${k}=${num(f(t))}`).join(' ');
    console.log(`${t}: ${row}`);
  }
} else {
  const names = args[0] === '--all' || !args.length
    ? fs.readdirSync(SRC).filter(f => f.endsWith('.spec.js')).map(f => f.replace('.spec.js', '')).filter(n => n !== 'hero_slash')
    : args;
  for (const n of names) exportSpec(n);
}
