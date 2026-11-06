// Thầy mo (shaman_p.svg, 256 viewBox, outline group stroke #2b2220 w7).
// Melee 1 -> "Gọi hồn": short incantation (staff raised, spirit glyph ring at feet) -> staff thrust -> 3 green soul-flames spiral into target.
// Parts = inner markup copied verbatim from the source SVG; `face` sits outside the outline <g> (raw).

// shared impact: same for all units (game-wide hit feel)
const HIT = { stop: 90, amp: 9, kx: 420, debris: 'spark', n: 8, sparkColor: '#ffe08a', cut: true, cutAng: -24 };
const HIT_SMALL = { small: true, stop: 45, amp: 4, kx: 0, debris: 'spark', n: 3, sparkColor: '#ffe08a', cut: false };
// main hit:   api.hit(Object.assign({}, HIT, { dmg: 42 }))     or  wave/projectile/tornado { hit: Object.assign({}, HIT, { dmg: 42 }) }
// multi-tick: Object.assign({}, HIT_SMALL, { dmg: 6 }) for the small ticks before the final HIT

const SPIRIT = '#8fe39a', SPIRIT_PALE = '#e6ffe9';
const RING = { x: 128, y: 244, t0: 60, t1: 1300 };         // glyph ring stays where the shaman stands
const T_THRUST = 560;
const FLAMES = [                                            // launch ms, fan control offset, spiral phase, hit
  { t: 560, cx: 20, cy: -120, ph: 0, hit: Object.assign({}, HIT_SMALL, { dmg: 6 }) },
  { t: 625, cx: 60, cy: -80, ph: 2.1, hit: Object.assign({}, HIT_SMALL, { dmg: 6 }) },
  { t: 690, cx: 95, cy: -40, ph: 4.2, hit: Object.assign({}, HIT, { dmg: 30 }) },
];
const wob = (t, a, b, amp, per) => (t > a && t < b ? amp * Math.sin((t - a) / per) : 0);

// soul flame: teardrop pointing along +x, wavy tail
function flameShape(ctx, s, w) {
  ctx.beginPath();
  ctx.arc(0, 0, s, -Math.PI / 2, Math.PI / 2);
  ctx.quadraticCurveTo(-1.5 * s, 1.1 * s, -3.1 * s, w * s);
  ctx.quadraticCurveTo(-2.2 * s, .1 * s, -1.9 * s, -.35 * s);
  ctx.quadraticCurveTo(-2.4 * s, -.9 * s, -2.7 * s, -1.15 * s);
  ctx.quadraticCurveTo(-1.2 * s, -1.25 * s, 0, -s);
  ctx.closePath();
}
function drawFlame(ctx, cam, x, y, ang, s, w, alpha, eyes) {
  ctx.setTransform(cam.translate(x, y).rotate(ang)); ctx.globalAlpha = alpha; ctx.lineJoin = 'round';
  ctx.beginPath(); ctx.arc(0, 0, s * 1.7, 0, Math.PI * 2); ctx.fillStyle = 'rgba(143,227,154,.22)'; ctx.fill();
  flameShape(ctx, s, w); ctx.fillStyle = SPIRIT; ctx.fill(); ctx.strokeStyle = INK; ctx.lineWidth = 5; ctx.stroke();
  ctx.translate(s * .2, 0); flameShape(ctx, s * .55, w); ctx.fillStyle = SPIRIT_PALE; ctx.fill();
  if (eyes) {
    ctx.setTransform(cam.translate(x, y));
    for (const ex of [-s * .28, s * .3]) { ctx.beginPath(); ctx.ellipse(ex, -s * .05, s * .13, s * .2, 0, 0, Math.PI * 2); ctx.fillStyle = INK; ctx.fill(); }
  }
  ctx.globalAlpha = 1;
}
// one soul flame: bursts up/forward from the staff tip along a bezier, spiralling, then dives into the target
function soulFlame(api, f) {
  const P0 = api.point('tip'), tg = api.target(), P2 = { x: tg.x - 8, y: tg.y - 6 };
  const P1 = { x: P0.x + f.cx, y: P0.y + f.cy }, ms = 330, R = 30;
  const bez = u => ({ x: (1 - u) ** 2 * P0.x + 2 * u * (1 - u) * P1.x + u * u * P2.x, y: (1 - u) ** 2 * P0.y + 2 * u * (1 - u) * P1.y + u * u * P2.y });
  const st = { age: 0, done: false, pop: 0, x: P0.x, y: P0.y, ang: 0, z: 1, trail: [] };
  return api.add({
    upd(s, dt) {
      st.age += dt;
      if (st.done) return false; // impact = shared HIT only (same for every unit)
      const u = Math.min(1, st.age / ms), uu = E.io(u) * .35 + u * .65, b = bez(uu), b2 = bez(Math.min(1, uu + .02));
      const tx = b2.x - b.x, ty = b2.y - b.y, L = Math.hypot(tx, ty) || 1, ph = f.ph + uu * Math.PI * 3.2;
      const off = R * Math.sin(Math.PI * uu) ** .7 * Math.sin(ph);
      const nx = b.x - ty / L * off, ny = b.y + tx / L * off;
      if (st.age > 8) st.ang = Math.atan2(ny - st.y, nx - st.x) * 57.3;
      st.x = nx; st.y = ny; st.z = Math.cos(ph);
      st.trail.unshift({ x: nx, y: ny }); st.trail.length = Math.min(st.trail.length, 9);
      if (u >= 1) { st.done = true; api.hit(f.hit); }
      return true;
    },
    draw(ctx, cam, layer) {
      if (layer !== 'front') return;
      if (st.done) return;
      ctx.setTransform(cam); ctx.lineCap = 'round'; ctx.lineJoin = 'round';
      if (st.trail.length > 1) {
        ctx.beginPath(); st.trail.forEach((p, i) => i ? ctx.lineTo(p.x, p.y) : ctx.moveTo(p.x, p.y));
        ctx.globalAlpha = .75; ctx.strokeStyle = INK; ctx.lineWidth = 13; ctx.stroke();
        ctx.strokeStyle = SPIRIT; ctx.lineWidth = 7; ctx.stroke(); ctx.globalAlpha = 1;
      }
      const grow = Math.min(1, st.age / 60), s = 20 * (.88 + .16 * st.z) * (.5 + .5 * grow);
      drawFlame(ctx, cam, st.x, st.y, st.ang, s, .25 * Math.sin(st.age / 30), 1, true);
    },
  });
}
// elliptic arc pieces on the near (front) or far half
function arcHalf(ctx, cx, cy, rx, ry, front) {
  ctx.beginPath();
  if (front) ctx.ellipse(cx, cy, rx, ry, 0, 0, Math.PI); else ctx.ellipse(cx, cy, rx, ry, 0, Math.PI, Math.PI * 2);
}
function glyph(ctx, k, s) {                                 // Đông Sơn-ish marks: concentric circle, S-spiral, chevron
  ctx.beginPath();
  if (k === 0) { ctx.arc(0, 0, s, 0, Math.PI * 2); ctx.fillStyle = SPIRIT_PALE; ctx.fill(); ctx.stroke(); ctx.beginPath(); ctx.arc(0, 0, s * .4, 0, Math.PI * 2); ctx.fillStyle = INK; ctx.fill(); return; }
  if (k === 1) { ctx.arc(-s * .5, 0, s * .5, Math.PI, 0); ctx.arc(s * .5, 0, s * .5, Math.PI, 0, true); }
  else { ctx.moveTo(-s, s * .6); ctx.lineTo(0, -s * .6); ctx.lineTo(s, s * .6); }
  ctx.lineWidth = 7; ctx.strokeStyle = INK; ctx.stroke(); ctx.lineWidth = 3.5; ctx.strokeStyle = SPIRIT_PALE; ctx.stroke(); ctx.lineWidth = 3;
}

const SPEC = {
  title: 'Thầy mo · Gọi hồn',
  subtitle: 'Niệm chú (gậy giơ cao, vòng phù dưới chân) → chỉ gậy → 3 đốm hồn xanh xoáy vào địch',
  feet: 244, cx: 128, range: 1,
  parts: {
    armB: `<path d="M108 140 Q102 164 100 188" fill="none" stroke="#2b2220" stroke-width="26"/>
<path d="M108 140 Q102 164 100 188" fill="none" stroke="#93362b" stroke-width="14"/>
<circle cx="100" cy="192" r="11" fill="#f3cfa6" stroke-width="5"/>`,
    feet: `<rect x="98" y="226" width="30" height="20" rx="8" fill="#3a2e28"/>
<rect x="132" y="226" width="32" height="20" rx="8" fill="#3a2e28"/>`,
    body: `<path d="M100 128 Q128 118 156 128 L176 230 Q128 242 80 230 Z" fill="#c9503f"/>
<path d="M84 212 Q128 223 172 212" fill="none" stroke="#93362b" stroke-width="10"/>
<path d="M88 218 L94 228 M108 222 L112 232 M128 224 L130 234 M148 222 L146 232 M166 218 L162 228" fill="none" stroke="#e2c36e" stroke-width="3"/>
<path d="M132 178 L138 226" fill="none" stroke="#93362b" stroke-width="5"/>
<path d="M114 128 L132 176 L148 130" fill="none" stroke="#93362b" stroke-width="6"/>
<path d="M91 176 Q128 186 165 176" fill="none" stroke="#2b2220" stroke-width="17"/>
<path d="M91 176 Q128 186 165 176" fill="none" stroke="#5a4a3c" stroke-width="9"/>
<path d="M96 180 L92 190" fill="none" stroke="#5a4a3c" stroke-width="5"/>
<circle cx="90" cy="194" r="8" fill="#a87a4c" stroke-width="5"/>
<circle cx="88" cy="214" r="15" fill="#a87a4c" stroke-width="5"/>
<path d="M78 218 Q84 226 94 226" fill="none" stroke="#5a4a3c" stroke-width="3"/>
<rect x="86" y="182" width="8" height="7" rx="2" fill="#5a4a3c" stroke-width="3"/>
<path d="M106 134 Q126 162 150 136" fill="none" stroke="#3a2e28" stroke-width="4"/>
<path d="M110 142 L106 152 L116 148 Z M140 148 L146 156 L148 144 Z" fill="#ece6da" stroke-width="3"/>
<circle cx="128" cy="160" r="11" fill="#e2c36e" stroke-width="5"/>
<circle cx="128" cy="160" r="4" fill="#93362b" stroke-width="3"/>`,
    plume: `<path d="M120 54 Q86 42 66 8 Q102 18 124 48 Z" fill="#ece6da" stroke-width="5"/>
<path d="M118 50 Q94 34 74 14" fill="none" stroke="#d8d2c6" stroke-width="3"/>
<path d="M126 50 Q104 30 102 2 Q126 18 134 48 Z" fill="#c9503f" stroke-width="5"/>
<path d="M130 46 Q114 28 106 8" fill="none" stroke="#93362b" stroke-width="3"/>
<path d="M134 50 Q134 24 150 4 Q160 30 146 54 Z" fill="#ece6da" stroke-width="5"/>
<path d="M142 50 Q144 28 152 10" fill="none" stroke="#d8d2c6" stroke-width="3"/>`,
    head: `<circle cx="130" cy="84" r="54" fill="#f3cfa6"/>
<path d="M80 96 Q78 126 102 140 Q96 116 106 96 Z" fill="#ece6da" stroke-width="5"/>
<path d="M78 76 A54 54 0 0 1 183 72 Z" fill="#5a4a3c"/>
<path d="M96 44 Q112 54 112 72" fill="none" stroke="#3a2e28" stroke-width="5"/>
<path d="M76 70 Q130 48 184 68 L184 84 Q130 64 76 86 Z" fill="#e2c36e" stroke-width="5"/>
<circle cx="102" cy="74" r="3.5" fill="#5a4a3c" stroke="none"/>
<circle cx="130" cy="66" r="3.5" fill="#5a4a3c" stroke="none"/>
<circle cx="158" cy="68" r="3.5" fill="#5a4a3c" stroke="none"/>
<path d="M140 124 Q160 134 180 120 Q182 152 160 180 Q148 158 140 124 Z" fill="#ece6da" stroke-width="5"/>
<path d="M156 140 Q160 156 158 168" fill="none" stroke="#d8d2c6" stroke-width="3"/>`,
    staff: `<path d="M195 70 Q178 86 182 108 L190 106 Q188 88 200 76 Z" fill="#c9503f" stroke-width="4"/>
<line x1="200" y1="56" x2="200" y2="244" stroke="#2b2220" stroke-width="15"/>
<line x1="200" y1="56" x2="200" y2="244" stroke="#a87a4c" stroke-width="7"/>
<rect x="193" y="96" width="14" height="8" rx="3" fill="#e2c36e" stroke-width="4"/>
<rect x="193" y="200" width="14" height="8" rx="3" fill="#e2c36e" stroke-width="4"/>
<path d="M189 46 L211 46 L218 70 L182 70 Z" fill="#e2c36e" stroke-width="5"/>
<path d="M186 60 L214 60" fill="none" stroke="#5a4a3c" stroke-width="3"/>
<circle cx="200" cy="76" r="4" fill="#5a4a3c" stroke-width="3"/>
<path d="M190 32 L172 22 L176 38 Z" fill="#e2c36e" stroke-width="4"/>
<ellipse cx="198" cy="35" rx="14" ry="9" fill="#e2c36e" stroke-width="5"/>
<path d="M206 32 Q211 24 214 16" fill="none" stroke="#2b2220" stroke-width="11"/>
<path d="M206 32 Q211 24 214 16" fill="none" stroke="#e2c36e" stroke-width="5"/>
<path d="M212 10 L204 2" fill="none" stroke="#2b2220" stroke-width="4"/>
<circle cx="215" cy="15" r="6" fill="#e2c36e" stroke-width="4"/>
<path d="M219 12 L238 18 L219 19 Z" fill="#e2c36e" stroke-width="4"/>`,
    armF: `<path d="M152 140 Q176 150 196 158" fill="none" stroke="#2b2220" stroke-width="28"/>
<path d="M152 140 Q176 150 196 158" fill="none" stroke="#c9503f" stroke-width="16"/>
<path d="M178 146 L172 174 L192 172 Z" fill="#93362b" stroke-width="5"/>
<path d="M186 148 L182 166" fill="none" stroke="#e2c36e" stroke-width="5"/>
<circle cx="200" cy="160" r="12" fill="#f3cfa6" stroke-width="5"/>`,
    face: `<path d="M140 100 Q148 93 157 99 M163 99 Q172 93 180 100" fill="none" stroke="#2b2220" stroke-width="8" stroke-linecap="round"/>
<path d="M140 100 Q148 93 157 99 M163 99 Q172 93 180 100" fill="none" stroke="#ece6da" stroke-width="4" stroke-linecap="round"/>
<circle cx="149" cy="110" r="5.5" fill="#2b2220"/>
<circle cx="171" cy="110" r="5.5" fill="#2b2220"/>
<circle cx="151" cy="108" r="2" fill="#fff"/>
<circle cx="173" cy="108" r="2" fill="#fff"/>
<path d="M146 121 Q154 112 161 118 Q168 112 176 120 Q168 126 161 122 Q154 126 146 121 Z" fill="#ece6da" stroke="#2b2220" stroke-width="3" stroke-linejoin="round"/>`,
  },
  raw: ['face'],
  bones: [
    { name: 'body', pivot: [128, 236], ch: 'lean' },
    { name: 'armB', parent: 'body', pivot: [108, 140], ch: 'armB' },
    { name: 'head', parent: 'body', pivot: [130, 136], ch: 'head' },
    { name: 'plume', parent: 'head', pivot: [130, 50], ch: 'plume' },
    { name: 'armF', parent: 'body', pivot: [152, 140], ch: 'arm' },
    { name: 'staff', parent: 'armF', pivot: [200, 160], ch: 'wrist' },   // pivot = hand centre
  ],
  // source order; face moved up to right after head (no overlap with staff/arm at rest) so a raised hand covers it, not vice versa
  draw: [['armB', 'armB'], ['feet', 'root'], ['body', 'body'], ['plume', 'plume'], ['head', 'head'], ['face', 'head'],
         ['staff', 'staff'], ['armF', 'armF']],
  points: { tip: ['staff', 236, 17], top: ['staff', 198, 35], bell: ['staff', 200, 58], mid: ['staff', 200, 104] },
  springs: {
    plume: { k: 200, c: 9, drive: (p, vx, c) => clamp(-vx * .035, -26, 14) - p.lean * .5 - p.head * .4 + (c.idle ? 2 * Math.sin(c.clock / 700) : 0) },
  },
  idle(p, b) { p.sy = 1 + .014 * b; p.head = 1.5 * b; p.arm = 1.5 * b; p.wrist = -1.5 * b; p.armB = 2 * b; },
  attacks: [
    {
      id: 'soul', label: '👻 Gọi hồn', dur: 1500,
      tr: {
        x: track([[0, 0], [240, -8, 'out'], [480, -10], [T_THRUST, 8, 'outExpo'], [1060, 6, 'out'], [1480, 0, 'io']]),
        y: (k => t => k(t) + wob(t, 260, 480, 1.5, 22))(track([[0, 0], [240, -8, 'out'], [480, -10], [530, 2, 'in'], [620, 0, 'out']])),
        sy: track([[0, 1], [110, .92, 'out'], [250, 1.05, 'outBack'], [480, 1.03], [520, .93, 'in'], [T_THRUST, 1.08, 'outExpo'], [700, 1, 'out']]),
        lean: track([[0, 0], [240, -7, 'out'], [480, -8], [T_THRUST, 9, 'outExpo'], [1060, 8, 'out'], [1480, 0, 'io']]),
        head: track([[0, 0], [240, -6, 'out'], [480, -7], [T_THRUST, 6, 'outExpo'], [1060, 4], [1480, 0, 'io']]),
        arm: (k => t => k(t) + wob(t, 260, 480, 2.5, 14))(track([[0, 0], [240, -45, 'outBack'], [480, -48], [T_THRUST, 4, 'outExpo'], [1060, 2, 'out'], [1480, 0, 'io']])),
        wrist: track([[0, 0], [240, 50, 'outBack'], [480, 53], [T_THRUST, 22, 'outExpo'], [1060, 20, 'out'], [1480, 0, 'io']]),
        armB: (k => t => k(t) + wob(t, 260, 480, 4, 18))(track([[0, 0], [240, 92, 'outBack'], [480, 96], [T_THRUST, 40, 'outExpo'], [1060, 34], [1480, 0, 'io']])),
      },
      ev: [
        [250, a => a.gleam('top')],
        [T_THRUST - 20, a => a.flash(SPIRIT_PALE, 45)],
        [T_THRUST, a => { const q = a.point('tip'); a.sparks(q.x, q.y, 7, SPIRIT); a.shockwave(RING.x, RING.y, { r: 150, ms: 360, color: SPIRIT }); }],
        ...FLAMES.map(f => [f.t, a => soulFlame(a, f)]),
      ],
      smear: { tip: 'tip', base: 'bell', from: 490, to: 620, window: 48, fill: SPIRIT_PALE, inner: SPIRIT },
      // spirit glyph ring at the feet + rising wisps while chanting (stateless: pure function of t)
      draw(ctx, cam, api, layer, t) {
        if (layer === 'back' || t < RING.t0 || t > RING.t1) return;
        const front = layer === 'front';
        const g = E.outBack(clamp((t - RING.t0) / 200, 0, 1)), fade = t > RING.t1 - 260 ? (RING.t1 - t) / 260 : 1;
        const pulse = t > T_THRUST - 20 ? Math.max(0, 1 - (t - T_THRUST + 20) / 260) : 0;
        const rx = 100 * g * (1 + .18 * pulse), ry = 26 * g * (1 + .18 * pulse), rot = t / 1000 * 2.4;
        ctx.setTransform(cam); ctx.lineCap = 'round'; ctx.lineJoin = 'round';
        if (!front) {
          ctx.globalAlpha = .28 * fade * (1 + pulse); ctx.beginPath(); ctx.ellipse(RING.x, RING.y, rx, ry, 0, 0, Math.PI * 2);
          ctx.fillStyle = SPIRIT; ctx.fill();
        }
        for (const [k, w] of [[1, 6], [.7, 4]]) {
          arcHalf(ctx, RING.x, RING.y, rx * k, ry * k, front);
          ctx.globalAlpha = fade * (front ? 1 : .75); ctx.strokeStyle = INK; ctx.lineWidth = w + 5; ctx.stroke();
          ctx.strokeStyle = front ? SPIRIT : '#b9efc0'; ctx.lineWidth = w; ctx.stroke();
        }
        for (let k = 0; k < 8; k++) {
          const a = rot + k * Math.PI / 4, sy = Math.sin(a);
          if ((sy >= 0) !== front) continue;
          ctx.setTransform(cam.translate(RING.x + Math.cos(a) * rx * .85, RING.y + sy * ry * .85).scale(1, .55));
          ctx.globalAlpha = fade; ctx.strokeStyle = INK; ctx.lineWidth = 3; glyph(ctx, k % 3, 9 * g);
        }
        // wisps rising from the ring while the spell gathers
        for (let k = 0; k < 6; k++) {
          const st = 140 + k * 55, per = 380, n = Math.floor((t - st) / per);
          if (t < st || st + n * per > 470) continue;
          const u = (t - st - n * per) / per, a = k * 1.9 + .4, z = Math.sin(a);
          if ((z >= 0) !== front) continue;
          drawFlame(ctx, cam, RING.x + Math.cos(a) * 82, RING.y + z * 20 - u * 150, -90, 9 * (1 - u * .6), .3 * Math.sin(t / 40 + k), (1 - u) * fade, false);
        }
        // spirit gathering on the bronze bird while chanting (becomes the burst)
        if (front && t > 240 && t < T_THRUST) {
          const q = api.point('top'), u = clamp((t - 240) / 260, 0, 1);
          drawFlame(ctx, cam, q.x + 2, q.y - 20 - 6 * u, -90, 5 + 8 * E.out(u) + 1.2 * Math.sin(t / 35), .3 * Math.sin(t / 40), fade, false);
        }
        ctx.globalAlpha = 1;
      },
    },
  ],
};
