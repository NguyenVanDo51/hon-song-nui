// Rồng (bird_p.svg) -> "Phun lửa": inhale (neck rears, body coils, mouth glow) -> fire-breath cone -> 3 burn ticks + HIT -> embers, body wave.
// Parts = inner markup copied verbatim from bird_p.svg; face/shine are outside the outline group -> raw.

// shared impact: same for all units (game-wide hit feel)
const HIT = { stop: 90, amp: 9, kx: 420, debris: 'spark', n: 8, sparkColor: '#ffe08a', cut: true, cutAng: -24 };
const HIT_SMALL = { small: true, stop: 45, amp: 4, kx: 0, debris: 'spark', n: 3, sparkColor: '#ffe08a', cut: false };

const FIRE = { out: '#ff6a3d', mid: '#ffb347', core: '#fff1c4' };
// centre of the mouth gap (between upper and lower jaw), follows jaw opening
const gap = (api, a, b) => { const p = api.point(a), q = api.point(b); return { x: (p.x + q.x) / 2, y: (p.y + q.y) / 2 }; };
const T_FIRE = 340, T_FULL = 420, T_END = 720, T_GONE = 830;   // fire cone timeline (attack ms)

// flat fire tongue along +x from s0..s1 (local space), half-width w(s), scalloped edge scrolling outward
function fireShape(ctx, s0, s1, w, t, k) {
  const n = 22, top = [], bot = [];
  for (let i = 0; i <= n; i++) {
    const s = lerp(s0, s1, i / n), ww = w(s) * k;
    const sc = Math.abs(Math.sin((s - t * .32) / 15)) * 7 * k * Math.min(1, (s - s0) / 30);
    top.push([s, -ww - sc]); bot.push([s, ww + Math.abs(Math.sin((s - t * .27) / 13 + 1)) * 6 * k * Math.min(1, (s - s0) / 30)]);
  }
  ctx.beginPath(); ctx.moveTo(s0, 0);
  for (const [x, y] of top) ctx.lineTo(x, y);
  const R = w(s1) * k;                                     // rounded, lobed front
  for (let j = 1; j < 9; j++) {
    const a = -Math.PI / 2 + Math.PI * j / 9, r = R * (j % 2 ? 1.25 : .85) + 4 * Math.sin(t * .05 + j);
    ctx.lineTo(s1 + Math.cos(a) * r * .9, Math.sin(a) * r);
  }
  for (let i = n; i >= 0; i--) ctx.lineTo(bot[i][0], bot[i][1]);
  ctx.closePath();
}
// cone from the mouth to just past the target; geometry = pure function of attack time t
function drawFire(ctx, cam, api, t) {
  if (t < T_FIRE || t > T_GONE) return;
  const m = gap(api, 'lipU', 'lipD'), tg = api.target();
  const dx = tg.x + 40 - m.x, dy = tg.y + 6 - m.y, L = Math.hypot(dx, dy);
  const grow = E.outExpo(clamp((t - T_FIRE) / (T_FULL - T_FIRE), 0, 1));
  const gone = E.in(clamp((t - T_END) / (T_GONE - T_END), 0, 1));
  const s1 = L * grow + 30 * gone, s0 = 8 + (L - 20) * gone;
  if (s1 - s0 < 6) return;
  const pulse = 1 + .22 * Math.max(0, 1 - Math.abs(t - 700) / 40) + .05 * Math.sin(t * .07);
  const w = s => Math.min(70, 9 + .4 * s) * pulse * (1 - .5 * gone);
  ctx.setTransform(cam.translate(m.x, m.y).rotate(Math.atan2(dy, dx) * 57.3));
  ctx.lineJoin = 'round'; ctx.lineCap = 'round';
  ctx.globalAlpha = .3; fireShape(ctx, s0, s1, w, t, 1.35); ctx.fillStyle = FIRE.mid; ctx.fill();   // faint halo
  ctx.globalAlpha = 1;
  fireShape(ctx, s0, s1, w, t, 1); ctx.fillStyle = FIRE.out; ctx.fill(); ctx.strokeStyle = INK; ctx.lineWidth = 6; ctx.stroke();
  fireShape(ctx, s0 + 4, s0 + (s1 - s0) * .92, w, t + 90, .64); ctx.fillStyle = FIRE.mid; ctx.fill();
  fireShape(ctx, s0 + 8, s0 + (s1 - s0) * .74, w, t + 200, .3); ctx.fillStyle = FIRE.core; ctx.fill();
}
// flat flame ball with ink outline (mouth glow)
function orb(ctx, cam, x, y, r) {
  ctx.setTransform(cam.translate(x, y));
  ctx.globalAlpha = .35; ctx.beginPath(); ctx.arc(0, 0, r * 1.7, 0, Math.PI * 2); ctx.fillStyle = FIRE.mid; ctx.fill(); ctx.globalAlpha = 1;
  ctx.beginPath(); ctx.arc(0, 0, r, 0, Math.PI * 2); ctx.fillStyle = FIRE.out; ctx.fill(); ctx.strokeStyle = INK; ctx.lineWidth = 4; ctx.stroke();
  ctx.beginPath(); ctx.arc(0, 0, r * .62, 0, Math.PI * 2); ctx.fillStyle = FIRE.mid; ctx.fill();
  ctx.beginPath(); ctx.arc(-r * .15, -r * .15, r * .3, 0, Math.PI * 2); ctx.fillStyle = FIRE.core; ctx.fill();
}
// rising embers at the target after the final hit (own state, so api.add)
function embers(api, n) {
  const c = api.target(), ps = [];
  for (let i = 0; i < n; i++) ps.push({ x: c.x + rnd(-55, 55), y: c.y + rnd(-50, 20), vx: rnd(-60, 60), vy: rnd(-360, -160), r: rnd(6, 10), rot: rnd(0, 6), vr: rnd(-6, 6), age: 0, life: rnd(650, 1050), col: i % 2 ? FIRE.out : FIRE.mid });
  api.add({
    upd(s, ms) { for (const p of ps) { p.age += ms; p.x += (p.vx + 30 * Math.sin(p.age / 120)) * s; p.y += p.vy * s; p.vy *= 1 - .8 * s; p.rot += p.vr * s; } return ps.some(p => p.age < p.life); },
    draw(ctx, cam, layer) {
      if (layer !== 'front') return;
      for (const p of ps) {
        if (p.age >= p.life) continue;
        const u = p.age / p.life, r = p.r * (1 - u * .6);
        ctx.setTransform(cam.translate(p.x, p.y).rotate(p.rot * 57.3)); ctx.globalAlpha = 1 - u * u;
        ctx.beginPath(); ctx.moveTo(0, -r * 1.5); ctx.lineTo(r, 0); ctx.lineTo(0, r); ctx.lineTo(-r, 0); ctx.closePath();
        ctx.fillStyle = p.col; ctx.fill(); ctx.strokeStyle = INK; ctx.lineWidth = 3; ctx.stroke();
      }
      ctx.globalAlpha = 1;
    },
  });
}
// fire cone as an fx added at T_FIRE: drawn before later hit fx (burst/number stay on top of the flame)
function fireFx(api) {
  let alive = true;
  api.add({
    upd() { alive = api.t <= T_GONE && api.t > 0; return alive; },
    draw(ctx, cam, layer) { if (layer === 'front' && alive) drawFire(ctx, cam, api, api.t); },
  });
}

const SPEC = {
  title: 'Rồng · Phun lửa',
  subtitle: 'Rồng vàng Lạc Long Quân: ngửa cổ hít hơi → phun lửa hình nón sang ô địch → 3 nhịp cháy + đòn chính.',
  feet: 244, cx: 112, range: 1, shadowR: 78,
  parts: {
    cloud: `<path d="M38 246 Q26 230 44 222 Q46 204 70 208 Q82 192 106 202 Q124 192 140 206 Q164 200 168 220 Q190 222 184 246 Z" fill="#f5ecd8" stroke-width="6"/>
<path d="M62 232 Q76 222 90 232 M134 230 Q148 220 162 232" fill="none" stroke="#d9cdb4" stroke-width="5"/>`,
    fin: `<path d="M70 114 Q28 102 22 54 Q40 68 54 64 Q46 32 74 14 Q82 42 96 44 Q104 18 132 20 Q120 64 114 118 Z" fill="#c9503f"/>
<path d="M62 102 Q46 84 40 66 M82 98 Q72 66 76 38 M102 102 Q104 68 120 40" fill="none" stroke="#93362b" stroke-width="5"/>`,
    leg: `<path d="M124 192 L122 224" stroke-width="24"/>
<path d="M124 192 L122 224" stroke="#e0b04a" stroke-width="11"/>
<path d="M110 230 L114 222 M120 231 L122 222 M130 230 L128 222" stroke-width="8"/>
<path d="M110 230 L114 222 M120 231 L122 222 M130 230 L128 222" stroke="#efe3c8" stroke-width="3"/>`,
    tail: `<path d="M40 130 Q14 206 52 214" fill="none" stroke-width="32"/>
<path d="M40 130 Q14 206 52 214" fill="none" stroke="#e0b04a" stroke-width="18"/>
<path d="M28 160 q5 5 10 0 M26 178 q5 5 10 0 M34 196 q5 5 10 0" fill="none" stroke="#b5832e" stroke-width="3"/>`,
    tailFlame: `<path d="M46 204 Q58 182 78 182 Q70 194 72 200 Q90 188 106 196 Q92 204 90 210 Q104 214 110 230 Q82 224 48 228 Z" fill="#c9503f"/>
<path d="M60 208 Q76 198 92 198 M62 218 Q82 214 98 222" fill="none" stroke="#93362b" stroke-width="5"/>`,
    hump: `<path d="M48 112 L44 88 L62 104 Z M66 102 L70 78 L84 100 Z M86 106 L98 86 L100 114 Z" fill="#c9503f" stroke-width="5"/>
<path d="M98 158 C90 104 50 98 40 132" fill="none" stroke-width="46"/>
<path d="M98 158 C90 104 50 98 40 132" fill="none" stroke="#e0b04a" stroke-width="32"/>
<path d="M52 118 q5 6 10 0 M66 112 q5 6 10 0 M80 118 q5 6 10 0 M58 130 q5 6 10 0 M76 130 q5 6 10 0" fill="none" stroke="#b5832e" stroke-width="3"/>`,
    belly: `<path d="M96 150 C98 200 150 206 162 172" fill="none" stroke-width="46"/>
<path d="M96 150 C98 200 150 206 162 172" fill="none" stroke="#e0b04a" stroke-width="32"/>
<path d="M104 170 Q120 196 146 188" fill="none" stroke="#f5ecd8" stroke-width="10"/>
<path d="M110 182 L116 176 M122 190 L126 184 M134 192 L136 186" fill="none" stroke="#d9cdb4" stroke-width="3"/>
<path d="M98 160 q5 6 10 0 M108 152 q5 6 10 0 M140 170 q5 6 10 0" fill="none" stroke="#b5832e" stroke-width="3"/>`,
    neck: `<path d="M158 156 L142 152 L156 166 Z M162 140 L148 132 L162 150 Z" fill="#c9503f" stroke-width="5"/>
<path d="M160 176 C170 160 174 144 178 124" fill="none" stroke-width="46"/>
<path d="M160 176 C170 160 174 144 178 124" fill="none" stroke="#e0b04a" stroke-width="32"/>
<path d="M164 164 Q172 150 172 136" fill="none" stroke="#f5ecd8" stroke-width="9"/>
<path d="M166 156 L172 158 M168 146 L174 148" fill="none" stroke="#d9cdb4" stroke-width="3"/>`,
    arm: `<path d="M158 182 Q178 188 192 192" fill="none" stroke-width="24"/>
<path d="M158 182 Q178 188 192 192" fill="none" stroke="#e0b04a" stroke-width="11"/>
<circle cx="206" cy="190" r="14" fill="#e2c36e" stroke-width="6"/>
<path d="M190 180 Q200 172 210 176 M188 200 Q198 208 210 204 M218 182 Q224 190 218 198" fill="none" stroke-width="8"/>
<path d="M190 180 Q200 172 210 176 M188 200 Q198 208 210 204 M218 182 Q224 190 218 198" fill="none" stroke="#efe3c8" stroke-width="3"/>`,
    mane: `<path d="M172 46 Q150 8 112 18 Q132 30 128 42 Q96 36 80 62 Q106 64 112 74 Q82 82 76 112 Q100 102 112 106 Q94 124 104 148 Q118 132 130 132 Q126 146 136 156 L170 128 Z" fill="#c9503f"/>
<path d="M150 40 Q128 44 116 58 M132 76 Q112 84 100 100 M128 108 Q116 120 114 136" fill="none" stroke="#93362b" stroke-width="5"/>
<path d="M164 106 L140 114 L158 120 L142 134 L164 128 L160 146 L180 124 Z" fill="#c9503f" stroke-width="5"/>`,
    horns: `<path d="M168 60 Q158 36 136 26" fill="none" stroke-width="15"/>
<path d="M168 60 Q158 36 136 26" fill="none" stroke="#efe3c8" stroke-width="6"/>
<path d="M150 34 L146 16" fill="none" stroke-width="13"/>
<path d="M150 34 L146 16" fill="none" stroke="#efe3c8" stroke-width="5"/>
<path d="M184 54 Q182 26 162 6" fill="none" stroke-width="17"/>
<path d="M184 54 Q182 26 162 6" fill="none" stroke="#efe3c8" stroke-width="8"/>
<path d="M178 30 Q188 18 202 16" fill="none" stroke-width="14"/>
<path d="M178 30 Q188 18 202 16" fill="none" stroke="#efe3c8" stroke-width="6"/>`,
    mouthIn: `<path d="M204 116 L206 98 Q224 90 240 94 L242 116 Z" fill="#3a2e28" stroke="none"/>
<path d="M210 112 Q224 104 236 110" fill="none" stroke="#f09a88" stroke-width="7"/>`,
    head: `<path d="M148 98 Q144 62 178 52 Q206 46 220 64 L236 68 Q250 72 250 90 Q250 104 244 112 L206 114 Q198 126 180 128 Q152 126 148 98 Z" fill="#e0b04a"/>
<path d="M186 72 Q204 58 226 68 L220 78 Q204 70 190 80 Z" fill="#b5832e" stroke-width="4"/>
<path d="M228 72 Q238 63 247 71 Q249 82 241 85 Q230 84 228 72 Z" fill="#e0b04a" stroke-width="5"/>
<path d="M160 82 q5 6 10 0 M156 98 q5 6 10 0 M168 110 q5 6 10 0" fill="none" stroke="#b5832e" stroke-width="3"/>
<path d="M212 112 L215 122 L219 112 M226 112 L229 121 L233 112 M236 112 L239 120 L242 112" fill="#f5ecd8" stroke-width="4"/>`,
    jaw: `<path d="M206 132 Q198 150 208 164 Q212 152 220 150 Q218 162 232 164 Q226 148 230 134 Z" fill="#c9503f" stroke-width="5"/>
<path d="M200 114 L244 114 Q242 132 222 138 Q202 136 200 114 Z" fill="#f5ecd8"/>
<path d="M214 128 Q224 132 234 128" fill="none" stroke="#d9cdb4" stroke-width="4"/>`,
    face: `<path d="M244 88 Q254 102 246 120 Q238 138 250 154" fill="none" stroke="#2b2220" stroke-width="4" stroke-linecap="round"/>
<path d="M232 104 Q218 122 228 140 Q236 154 226 168" fill="none" stroke="#2b2220" stroke-width="4" stroke-linecap="round"/>
<path d="M184 78 Q202 64 224 74" fill="none" stroke="#2b2220" stroke-width="6" stroke-linecap="round"/>
<path d="M192 90 Q204 78 218 86 Q206 98 192 90 Z" fill="#fff3c4" stroke="#2b2220" stroke-width="3.5" stroke-linejoin="round"/>
<circle cx="206" cy="88" r="5" fill="#e0503f"/>
<ellipse cx="206" cy="88" rx="1.8" ry="4.5" fill="#2b2220"/>
<path d="M236 76 Q243 72 243 79" fill="none" stroke="#2b2220" stroke-width="3.5" stroke-linecap="round"/>`,
    shine: `<circle cx="201" cy="185" r="4" fill="#fff" opacity="0.7"/>`,
  },
  raw: ['face', 'shine'],
  // chain: belly (root, leg on cloud) -> hump -> tail -> tailFlame ; belly -> neck -> head -> jaw
  bones: [
    { name: 'cloud', pivot: [112, 230] },
    { name: 'belly', pivot: [124, 192], ch: 'belly', ty: 'hover' },
    { name: 'hump', parent: 'belly', pivot: [97, 154], ch: 'hump' },
    { name: 'fin', parent: 'hump', pivot: [92, 116], ch: 'fin' },
    { name: 'tail', parent: 'hump', pivot: [40, 131], ch: 'tail' },
    { name: 'tailFlame', parent: 'tail', pivot: [52, 212], ch: 'flame' },
    { name: 'neck', parent: 'belly', pivot: [161, 174], ch: 'neck' },
    { name: 'head', parent: 'neck', pivot: [178, 126], ch: 'head' },
    { name: 'jaw', parent: 'head', pivot: [204, 114], ch: 'jaw' },
    { name: 'mane', parent: 'head', pivot: [160, 92], ch: 'mane' },
    { name: 'arm', parent: 'belly', pivot: [158, 182], ch: 'arm' },
  ],
  // source order; mouthIn rides the jaw (drawn before head -> hidden at rest, fills the gap when the jaw drops)
  draw: [['cloud', 'cloud'], ['fin', 'fin'], ['leg', 'belly'], ['tail', 'tail'], ['tailFlame', 'tailFlame'], ['hump', 'hump'],
         ['belly', 'belly'], ['neck', 'neck'], ['arm', 'arm'], ['shine', 'arm'], ['mane', 'mane'], ['horns', 'head'],
         ['mouthIn', 'jaw'], ['head', 'head'], ['jaw', 'jaw'], ['face', 'head']],
  points: { lipU: ['head', 244, 112], lipD: ['jaw', 240, 114], throatU: ['head', 232, 112], throatD: ['jaw', 230, 114] },
  // body wave = springs on hump/tail/fin driven by the neck: they lag the neck snap and swing through
  springs: {
    hump: { k: 120, c: 9, drive: (p, vx, c) => -p.neck * .35 + (p.humpT || 0) + (c.idle ? 1.5 * Math.sin(c.clock / 520) : 0) },
    tail: { k: 70, c: 6, drive: (p, vx, c) => p.neck * .5 - clamp(vx * .02, -10, 10) + (c.idle ? 3 * Math.sin(c.clock / 520 - 1.2) : 0) },
    flame: { k: 140, c: 7, drive: (p, vx, c) => -p.neck * .4 + (c.idle ? 5 * Math.sin(c.clock / 300) : 0) },
    fin: { k: 150, c: 8, drive: (p, vx, c) => -p.neck * .45 - clamp(vx * .03, -14, 14) + (c.idle ? 3 * Math.sin(c.clock / 420) : 0) },
    mane: { k: 200, c: 9, drive: (p, vx, c) => -(p.neck + p.head) * .3 - clamp(vx * .03, -14, 14) + (c.idle ? 2 * Math.sin(c.clock / 600) : 0) },
  },
  idle(p, b) { p.hover = -2.5 * b; p.neck = 2 * b; p.head = -1.5 * b; p.arm = 2 * b; },
  attacks: [
    {
      id: 'breath', label: '🔥 Phun lửa', dur: 1500,
      tr: {
        x: track([[0, 0], [260, -10, 'out'], [320, -12], [380, 16, 'outExpo'], [720, 18, 'out'], [1400, 0, 'io']]),
        y: track([[0, 0], [260, 4, 'out'], [320, 4], [380, -8, 'outExpo'], [720, -6], [1400, 0, 'io']]),
        sy: track([[0, 1], [260, .9, 'out'], [320, .89], [370, 1.08, 'outExpo'], [460, .98, 'out'], [560, 1, 'out']]),
        belly: track([[0, 0], [260, -8, 'out'], [320, -9], [380, 4, 'outExpo'], [720, 3, 'out'], [1400, 0, 'io']]),
        neck: track([[0, 0], [260, -26, 'outBack'], [320, -28], [380, 10, 'outExpo'], [700, 8, 'out'], [840, -6, 'io'], [1400, 0, 'io']]),
        head: track([[0, 0], [260, -16, 'outBack'], [320, -17], [380, 6, 'outExpo'], [720, 4, 'out'], [860, -4, 'io'], [1400, 0, 'io']]),
        jaw: track([[0, 0], [220, 24, 'out'], [320, 22], [380, 38, 'outExpo'], [740, 34], [900, 0, 'io']]),
        arm: track([[0, 0], [260, -14, 'out'], [320, -14], [380, 10, 'outExpo'], [720, 8], [1400, 0, 'io']]),
        humpT: track([[0, 0], [260, 4, 'out'], [380, -6, 'outExpo'], [720, -4], [1400, 0, 'io']]),
      },
      ev: [
        [120, a => a.gleam('lipU', 200)],
        [300, a => a.shake(3, 120)],
        [T_FIRE - 20, a => a.flash(FIRE.mid, 50)],
        [T_FIRE, a => fireFx(a)],
        [450, a => a.hit(Object.assign({}, HIT_SMALL, { dmg: 8 }))],
        [540, a => a.hit(Object.assign({}, HIT_SMALL, { dmg: 8 }))],
        [630, a => a.hit(Object.assign({}, HIT_SMALL, { dmg: 8 }))],
        [705, a => a.hit(Object.assign({}, HIT, { dmg: 50 }))],
        [720, a => { embers(a, 12); a.sparks(a.target().x, a.target().y, 6, FIRE.out); }],
      ],
      // inhale glow in the mouth: stateless (pure of t)
      draw(ctx, cam, api, layer, t) {
        if (layer !== 'front' || t < 90 || t > T_END + 60) return;
        const m = gap(api, 'throatU', 'throatD');
        if (t < T_FIRE) {                                  // air streaks sucked into the mouth
          ctx.setTransform(cam); ctx.lineCap = 'round';
          for (let i = 0; i < 5; i++) {
            const ph = ((t - 90) / 240 + i / 5) % 1, d = 110 * (1 - ph) + 16, a = -.9 + i * .42;
            const x0 = m.x + Math.cos(a) * d, y0 = m.y + Math.sin(a) * d, x1 = m.x + Math.cos(a) * (d + 26), y1 = m.y + Math.sin(a) * (d + 26);
            ctx.globalAlpha = Math.sin(ph * Math.PI);
            ctx.beginPath(); ctx.moveTo(x0, y0); ctx.lineTo(x1, y1); ctx.strokeStyle = INK; ctx.lineWidth = 8; ctx.stroke(); ctx.strokeStyle = FIRE.core; ctx.lineWidth = 4; ctx.stroke();
          }
          ctx.globalAlpha = 1;
        }
        const r = t < T_FIRE ? 3 + 8 * E.out(clamp((t - 120) / 200, 0, 1)) : 11 * (1 - clamp((t - T_END) / 60, 0, 1));
        if (r > 1) orb(ctx, cam, m.x, m.y, r * (1 + .08 * Math.sin(t * .09)));
      },
    },
  ],
};
