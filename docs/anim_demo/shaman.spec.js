// Pháp Sư Gọi Hồn (necromancer; 256 viewBox, outline group stroke #2b2220 w7): hood, skull staff, green wisp.
// Melee 1 -> "Gọi hồn": short incantation (staff raised, spirit glyph ring at feet) -> staff thrust -> 3 green soul-flames spiral into target.
// Parts = the art (token SVG is generated from them); `face` sits outside the outline <g> (raw).

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
function glyph(ctx, k, s) {                                 // rune marks: concentric circle, S-spiral, chevron
  ctx.beginPath();
  if (k === 0) { ctx.arc(0, 0, s, 0, Math.PI * 2); ctx.fillStyle = SPIRIT_PALE; ctx.fill(); ctx.stroke(); ctx.beginPath(); ctx.arc(0, 0, s * .4, 0, Math.PI * 2); ctx.fillStyle = INK; ctx.fill(); return; }
  if (k === 1) { ctx.arc(-s * .5, 0, s * .5, Math.PI, 0); ctx.arc(s * .5, 0, s * .5, Math.PI, 0, true); }
  else { ctx.moveTo(-s, s * .6); ctx.lineTo(0, -s * .6); ctx.lineTo(s, s * .6); }
  ctx.lineWidth = 7; ctx.strokeStyle = INK; ctx.stroke(); ctx.lineWidth = 3.5; ctx.strokeStyle = SPIRIT_PALE; ctx.stroke(); ctx.lineWidth = 3;
}

const SPEC = {
  title: 'Pháp Sư Gọi Hồn · Gọi hồn',
  subtitle: 'Niệm chú (gậy đầu lâu giơ cao, vòng phù dưới chân) → chỉ gậy → 3 đốm hồn xanh xoáy vào địch',
  feet: 244, cx: 128, range: 1,
  parts: {
    armB: `<path d="M108 140 Q102 164 100 188" fill="none" stroke="#2b2220" stroke-width="26"/>
<path d="M108 140 Q102 164 100 188" fill="none" stroke="#32508f" stroke-width="14"/>
<circle cx="100" cy="192" r="11" fill="#f3cfa6" stroke-width="5"/>`,
    // small green wisp spirit floating beside the necromancer
    wisp: `<path d="M60 152 Q42 138 52 118 Q58 132 66 130 Q60 116 74 104 Q74 126 84 136 Q82 154 60 152 Z" fill="#8be37a" stroke-width="5"/>
<circle cx="64" cy="138" r="2.6" fill="#2b2220" stroke="none"/>
<circle cx="73" cy="137" r="2.6" fill="#2b2220" stroke="none"/>`,
    feet: `<rect x="98" y="226" width="30" height="20" rx="8" fill="#3a2e28"/>
<rect x="132" y="226" width="32" height="20" rx="8" fill="#3a2e28"/>`,
    // dark team robe + team trim, rope belt, skull pendant
    body: `<path d="M100 128 Q128 118 156 128 L176 230 Q128 242 80 230 Z" fill="#32508f"/>
<path d="M84 222 Q128 233 172 222" fill="none" stroke="#4f74c9" stroke-width="8"/>
<path d="M128 132 L131 226" stroke="#4f74c9" stroke-width="6"/>
<path d="M92 176 Q128 186 164 176" fill="none" stroke="#2b2220" stroke-width="15"/>
<path d="M92 176 Q128 186 164 176" fill="none" stroke="#a87a4c" stroke-width="7"/>
<path d="M120 146 Q120 136 128 136 Q136 136 136 146 Q136 151 132 152 L132 156 L124 156 L124 152 Q120 151 120 146 Z" fill="#ece6da" stroke-width="4"/>`,
    // skull-topped staff with green ghost fire
    staff: `<line x1="200" y1="60" x2="200" y2="244" stroke="#2b2220" stroke-width="15"/>
<line x1="200" y1="60" x2="200" y2="244" stroke="#5a4a3c" stroke-width="7"/>
<path d="M200 4 Q214 16 210 28 Q206 34 200 30 Q193 34 190 26 Q190 14 200 4 Z" fill="#8be37a" stroke-width="4"/>
<path d="M182 48 Q182 24 200 24 Q218 24 218 48 Q218 58 210 60 L210 68 L190 68 L190 60 Q182 58 182 48 Z" fill="#ece6da" stroke-width="5"/>
<circle cx="193" cy="46" r="4.5" fill="#2b2220" stroke="none"/>
<circle cx="207" cy="46" r="4.5" fill="#2b2220" stroke="none"/>
<path d="M196 62 L196 68 M200 62 L200 68 M204 62 L204 68" stroke="#2b2220" stroke-width="2.5"/>`,
    armF: `<path d="M152 140 Q176 150 196 160" fill="none" stroke="#2b2220" stroke-width="28"/>
<path d="M152 140 Q176 150 196 160" fill="none" stroke="#32508f" stroke-width="16"/>
<circle cx="200" cy="162" r="12" fill="#f3cfa6" stroke-width="5"/>`,
    // hood tail (flops back)
    plume: `<path d="M86 46 Q54 30 36 48 Q60 54 76 68 Z" fill="#32508f"/>`,
    head: `<path d="M72 112 Q56 42 112 24 Q152 14 178 36 Q198 56 192 104 Z" fill="#32508f"/>
<circle cx="130" cy="84" r="54" fill="#f3cfa6"/>
<path d="M76 98 Q72 40 130 30 Q188 36 188 96 Q168 66 132 64 Q98 66 76 98 Z" fill="#32508f"/>
<path d="M82 92 Q102 70 132 68 Q164 68 182 88" fill="none" stroke="#4f74c9" stroke-width="5"/>`,
    // brows, glowing green eye glints, tired eye bags
    face: `<path d="M140 103 L155 109 M163 109 L178 103" stroke="#2b2220" stroke-width="5" stroke-linecap="round"/>
<circle cx="148" cy="116" r="6" fill="#2b2220"/>
<circle cx="170" cy="116" r="6" fill="#2b2220"/>
<circle cx="150" cy="114" r="2" fill="#8be37a"/>
<circle cx="172" cy="114" r="2" fill="#8be37a"/>
<path d="M141 124 Q148 128 155 124 M163 124 Q170 128 177 124" fill="none" stroke="#9b86b8" stroke-width="2.5" stroke-linecap="round"/>
<path d="M151 134 Q160 136 168 129" fill="none" stroke="#2b2220" stroke-width="3.5" stroke-linecap="round"/>`,
  },
  raw: ['face'],
  bones: [
    { name: 'body', pivot: [128, 236], ch: 'lean' },
    { name: 'armB', parent: 'body', pivot: [108, 140], ch: 'armB' },
    { name: 'head', parent: 'body', pivot: [130, 136], ch: 'head' },
    { name: 'plume', parent: 'head', pivot: [82, 56], ch: 'plume' },   // hood tail root
    { name: 'armF', parent: 'body', pivot: [152, 140], ch: 'arm' },
    { name: 'staff', parent: 'armF', pivot: [200, 160], ch: 'wrist' },   // pivot = hand centre
  ],
  // sample order (head + hood over the shoulder); wisp after armB so a raised back hand sits behind the spirit
  draw: [['armB', 'armB'], ['wisp', 'body'], ['feet', 'root'], ['body', 'body'], ['staff', 'staff'], ['armF', 'armF'],
         ['plume', 'plume'], ['head', 'head'], ['face', 'head']],
  points: { tip: ['staff', 200, 8], top: ['staff', 200, 36], bell: ['staff', 200, 66], mid: ['staff', 200, 104] },
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
        // spirit gathering on the skull flame while chanting (becomes the burst)
        if (front && t > 240 && t < T_THRUST) {
          const q = api.point('top'), u = clamp((t - 240) / 260, 0, 1);
          drawFlame(ctx, cam, q.x + 2, q.y - 20 - 6 * u, -90, 5 + 8 * E.out(u) + 1.2 * Math.sin(t / 35), .3 * Math.sin(t / 40), fade, false);
        }
        ctx.globalAlpha = 1;
      },
    },
  ],
};
