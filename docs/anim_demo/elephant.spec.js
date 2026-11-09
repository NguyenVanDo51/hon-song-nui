// Golem Đá (unit key `elephant`; token elephant_p/e.svg generated from these parts, 256 viewBox, outline group stroke #2b2220 w7).
// Attack "Đập đất": lumbering step-in -> both fists raised overhead -> double-fist slam -> ground cracks race to the target + shockwave + stone shards -> HIT.
// `raw` = drawn outside the outline group (eyes).

// shared impact: same for all units (game-wide hit feel)
const HIT = { stop: 90, amp: 9, kx: 420, debris: 'spark', n: 8, sparkColor: '#ffe08a', cut: true, cutAng: -24 };
const HIT_SMALL = { small: true, stop: 45, amp: 4, kx: 0, debris: 'spark', n: 3, sparkColor: '#ffe08a', cut: false };
// main hit:   api.hit(Object.assign({}, HIT, { dmg: 42 }))     or  wave/projectile/tornado { hit: Object.assign({}, HIT, { dmg: 42 }) }
// multi-tick: Object.assign({}, HIT_SMALL, { dmg: 6 }) for the small ticks before the final HIT

const GROUND = 246;
const T_STEP = 240;          // step-in foot lands
const T_SLAM = 660;          // fists hit the ground
const T_HIT = 680;           // crack reaches target -> shared HIT
const STONE = '#9a9488', STONE2 = '#7a7468', STONE3 = '#5d584f';

// ground cracks (fixed geometry -> stateless draw): main crack fists -> under target, plus branches
const CRACK_MAIN = [[282, 250], [298, 245], [314, 254], [332, 248], [350, 255], [368, 249], [386, 256], [404, 250], [422, 255], [442, 251]];
const CRACK_BR = [
  { at: .0, pts: [[282, 250], [264, 260], [244, 258]] },
  { at: .0, pts: [[282, 250], [292, 239], [308, 235]] },
  { at: .2, pts: [[314, 254], [328, 265], [348, 267]] },
  { at: .45, pts: [[350, 255], [364, 241], [382, 237]] },
  { at: .7, pts: [[404, 250], [418, 263], [438, 265]] },
];
const plen = pts => pts.slice(1).reduce((s, q, i) => s + Math.hypot(q[0] - pts[i][0], q[1] - pts[i][1]), 0);
// draw the first u (0..1) of a polyline, tapering width w0 -> w1
function crackLine(ctx, pts, u, w0, w1) {
  const L = plen(pts) * u; let acc = 0;
  for (let i = 1; i < pts.length && acc < L; i++) {
    const [x0, y0] = pts[i - 1], [x1, y1] = pts[i], d = Math.hypot(x1 - x0, y1 - y0), k = Math.min(1, (L - acc) / d);
    const w = lerp(w0, w1, (acc + d * k / 2) / plen(pts));
    ctx.beginPath(); ctx.moveTo(x0, y0); ctx.lineTo(x0 + (x1 - x0) * k, y0 + (y1 - y0) * k);
    ctx.strokeStyle = STONE2; ctx.lineWidth = w + 9; ctx.stroke();
    ctx.strokeStyle = INK; ctx.lineWidth = w; ctx.stroke();
    acc += d;
  }
}

// stone shards thrown toward the target (one-shot fx with own state)
function shards(api, x, n) {
  for (let i = 0; i < n; i++) {
    const q = { x: x + rnd(-14, 24), y: GROUND - 4, vx: rnd(120, 460), vy: rnd(-560, -260), r: rnd(6, 11), rot: rnd(0, 6), age: 0, life: rnd(520, 720) };
    api.add({
      upd(s, ms) { q.age += ms; q.vy += 1700 * s; q.x += q.vx * s; q.y += q.vy * s; q.rot += 9 * s; if (q.y > GROUND) { q.y = GROUND; q.vy *= -.3; q.vx *= .5; } return q.age < q.life; },
      draw(ctx, cam, layer) {
        if (layer !== 'front') return;
        const u = q.age / q.life;
        ctx.setTransform(cam.translate(q.x, q.y).rotate(q.rot * 57.3)); ctx.globalAlpha = u > .7 ? (1 - u) / .3 : 1;
        ctx.beginPath(); for (let k = 0; k < 4; k++) { const a = k / 4 * Math.PI * 2 + .4, r = q.r * (k % 2 ? .7 : 1); k ? ctx.lineTo(Math.cos(a) * r, Math.sin(a) * r) : ctx.moveTo(Math.cos(a) * r, Math.sin(a) * r); }
        ctx.closePath(); ctx.fillStyle = STONE; ctx.fill(); ctx.strokeStyle = INK; ctx.lineWidth = 3; ctx.lineJoin = 'round'; ctx.stroke(); ctx.globalAlpha = 1;
      },
    });
  }
}

const SPEC = {
  title: 'Golem Đá · Đập đất',
  subtitle: 'Bước tới, giơ hai nắm đấm qua đầu → đập xuống đất, nứt đất + sóng chấn lan tới địch',
  feet: 244, cx: 128, range: 1, shadowR: 96,
  parts: {
    armB: `<path d="M50 120 L72 118 L64 180 L38 176 Z" fill="#7a7468"/>
<path d="M58 134 L52 160" stroke="#32508f" stroke-width="8"/>
<path d="M58 134 L52 160" stroke="#4f74c9" stroke-width="4"/>
<rect x="18" y="170" width="48" height="46" rx="12" fill="#7a7468"/>
<path d="M22 202 L62 202" stroke="#5d584f" stroke-width="4"/>
<circle cx="60" cy="124" r="22" fill="#7a7468"/>`,
    legB: `<rect x="86" y="188" width="36" height="46" rx="8" fill="#7a7468"/>
<rect x="78" y="226" width="50" height="20" rx="7" fill="#5d584f"/>`,
    legF: `<rect x="136" y="188" width="38" height="46" rx="8" fill="#9a9488"/>
<path d="M146 200 L154 212 L150 222" fill="none" stroke="#5d584f" stroke-width="3.5"/>
<rect x="130" y="226" width="54" height="20" rx="7" fill="#7a7468"/>`,
    body: `<path d="M72 116 Q128 94 186 114 L196 178 Q190 214 128 216 Q66 214 60 178 Z" fill="#9a9488"/>
<path d="M64 186 Q128 204 192 186 Q186 212 128 214 Q70 212 64 186 Z" fill="#7a7468" stroke-width="5"/>
<path d="M82 136 L96 148 L90 168 M176 190 L166 200" fill="none" stroke="#5d584f" stroke-width="4"/>
<path d="M68 122 Q80 102 104 106 Q100 120 88 120 Q80 130 68 122 Z" fill="#6f8f44" stroke-width="5"/>
<path d="M100 196 Q108 186 120 192 Q114 202 100 196 Z" fill="#6f8f44" stroke-width="4"/>
<path d="M142 156 L114 144 L102 160 M142 156 L172 138 M142 156 L150 188 L132 200 M142 156 L180 170" fill="none" stroke="#32508f" stroke-width="9"/>
<path d="M142 156 L114 144 L102 160 M142 156 L172 138 M142 156 L150 188 L132 200 M142 156 L180 170" fill="none" stroke="#4f74c9" stroke-width="5"/>
<path d="M142 156 L114 144 L102 160 M142 156 L172 138 M142 156 L150 188 L132 200 M142 156 L180 170" fill="none" stroke="#e2c36e" stroke-width="1.8"/>
<path d="M142 136 L162 156 L142 176 L122 156 Z" fill="#32508f" stroke-width="6"/>
<path d="M142 144 L154 156 L142 168 L130 156 Z" fill="#4f74c9" stroke="none"/>
<circle cx="142" cy="156" r="5" fill="#e2c36e" stroke="none"/>`,
    head: `<path d="M98 50 Q100 34 116 33 L172 31 Q188 33 190 50 L192 102 Q190 118 172 118 L114 118 Q98 118 96 102 Z" fill="#9a9488"/>
<path d="M100 102 Q144 112 190 100 Q188 116 172 116 L114 116 Q100 116 100 102 Z" fill="#7a7468" stroke="none"/>
<path d="M136 80 Q164 72 194 76 L194 86 Q164 84 136 90 Z" fill="#7a7468" stroke-width="5"/>
<path d="M112 36 Q122 22 140 29 Q154 19 168 31 Q152 40 138 37 Q124 44 112 36 Z" fill="#6f8f44" stroke-width="5"/>
<path d="M114 56 L122 66 L114 76" fill="none" stroke="#32508f" stroke-width="8"/>
<path d="M114 56 L122 66 L114 76" fill="none" stroke="#4f74c9" stroke-width="4"/>
<path d="M180 40 L172 52 L178 60" fill="none" stroke="#5d584f" stroke-width="3.5"/>`,
    armF: `<path d="M186 120 L212 116 L228 176 L198 182 Z" fill="#9a9488"/>
<path d="M206 134 L216 162" stroke="#32508f" stroke-width="8"/>
<path d="M206 134 L216 162" stroke="#4f74c9" stroke-width="4"/>
<path d="M206 134 L216 162" stroke="#e2c36e" stroke-width="1.5"/>
<rect x="190" y="170" width="52" height="48" rx="12" fill="#9a9488"/>
<path d="M194 204 L238 204 Q238 216 226 216 L206 216 Q194 216 194 204 Z" fill="#7a7468" stroke="none"/>
<path d="M226 180 L240 180 M226 194 L240 194" stroke="#5d584f" stroke-width="4"/>
<circle cx="198" cy="122" r="24" fill="#9a9488"/>
<path d="M176 116 Q182 96 204 96 Q220 100 222 114 Q206 106 192 114 Q184 120 176 116 Z" fill="#6f8f44" stroke-width="5"/>`,
    eyes: `<ellipse cx="156" cy="95" rx="7" ry="4.5" fill="#e2c36e" stroke="#32508f" stroke-width="2.5"/>
<ellipse cx="178" cy="95" rx="6" ry="4.5" fill="#e2c36e" stroke="#32508f" stroke-width="2.5"/>
<path d="M158 108 L178 106" stroke="#2b2220" stroke-width="3.5" stroke-linecap="round"/>`,
  },
  raw: ['eyes'],
  // parent before child; pivot in 256 space
  bones: [
    { name: 'legB', pivot: [104, 190], ch: 'legB' },
    { name: 'legF', pivot: [155, 190], ch: 'legF' },
    { name: 'body', pivot: [128, 204], ch: 'lean' },                               // pivot = hips
    { name: 'head', parent: 'body', pivot: [142, 116], ch: 'head' },
    { name: 'armB', parent: 'body', pivot: [60, 124], ch: 'armB', tx: 'armBX', ty: 'armBY' },   // back arm slides forward behind the torso
    { name: 'armF', parent: 'body', pivot: [198, 122], ch: 'armF', ty: 'armFY' },
  ],
  draw: [['armB', 'armB'], ['legB', 'legB'], ['legF', 'legF'], ['body', 'body'], ['head', 'head'], ['armF', 'armF'], ['eyes', 'head']],
  points: { fistF: ['armF', 218, 218], fistTop: ['armF', 228, 176], elbowF: ['armF', 210, 150], fistB: ['armB', 42, 216], core: ['body', 142, 156] },
  idle(p, b) { p.sy = 1 + .01 * b; p.head = 1 * b; p.armF = 1.5 * b; p.armB = -1.5 * b; },
  attacks: [
    {
      // 0-240 step-in · 240-520 fists up overhead · 520-580 hold · 580-660 slam (contact T_SLAM) · 660-860 fists planted · 860-1250 recover
      id: 'slam', label: '👊 Đập đất', dur: 1250,
      tr: {
        x: track([[0, 0], [T_STEP, 16, 'out'], [520, 10, 'out'], [580, 10], [T_SLAM, 28, 'in'], [860, 26, 'out'], [1250, 0, 'io']]),
        y: track([[0, 0], [110, -7, 'out'], [T_STEP, 0, 'in'], [520, -6, 'out'], [580, -6], [T_SLAM, 0, 'in']]),
        sy: track([[0, 1], [110, 1.02, 'out'], [T_STEP, .93, 'in'], [330, 1, 'out'], [520, 1.06, 'out'], [580, 1.06], [T_SLAM, .86, 'in'], [760, 1.02, 'out'], [860, 1, 'io']]),
        lean: track([[0, 0], [110, -3, 'out'], [T_STEP, 4, 'in'], [520, -10, 'out'], [580, -11], [T_SLAM, 22, 'in'], [860, 20, 'out'], [1250, 0, 'io']]),
        head: track([[0, 0], [T_STEP, 3], [520, -8, 'out'], [580, -8], [T_SLAM, 8, 'in'], [860, 6], [1250, 0, 'io']]),
        legF: track([[0, 0], [110, -18, 'out'], [T_STEP, 0, 'in'], [T_SLAM, -6, 'in'], [860, -6], [1250, 0, 'io']]),
        legB: track([[0, 0], [T_STEP, 4], [520, 0], [T_SLAM, 8, 'in'], [860, 8], [1250, 0, 'io']]),
        armF: track([[0, 0], [T_STEP, 8, 'out'], [520, -165, 'io'], [580, -168], [T_SLAM, -48, 'in'], [720, -52, 'out'], [860, -50], [1250, 0, 'io']]),
        armFY: track([[0, 0], [T_STEP, 0], [520, -10, 'out'], [580, -10], [T_SLAM, 0, 'in']]),
        armB: track([[0, 0], [T_STEP, -6, 'out'], [520, -172, 'io'], [580, -175], [T_SLAM, -64, 'in'], [720, -68, 'out'], [860, -66], [1250, 0, 'io']]),
        armBX: track([[0, 0], [T_STEP, 0], [520, 72, 'io'], [580, 74], [T_SLAM, 130, 'in'], [860, 130], [1250, 0, 'io']]),
        armBY: track([[0, 0], [T_STEP, 0], [520, -50, 'io'], [580, -50], [T_SLAM, 0, 'in']]),
      },
      ev: [
        [T_STEP, a => { a.dust(150, GROUND, 4, 1); a.dust(104, GROUND, 3, -1); a.shake(4, 160); }],
        [500, a => a.gleam('core', 200)],
        [T_SLAM, a => {
          const f = a.point('fistF');
          a.flash('#fff6dc', 40);
          a.shake(16, 440);                                        // heavy unit: stronger shake than the shared HIT (HIT amp 9 won't override)
          a.shockwave(f.x, GROUND, { r: 120, ms: 340 });
          a.dust(f.x + 20, GROUND, 4, 1); a.dust(f.x - 40, GROUND, 3, -1);
          shards(a, f.x, 7);
        }],
        [T_HIT, a => {
          const c = a.target();
          a.hit(Object.assign({}, HIT, { dmg: 60 }));
          a.shockwave(c.x, GROUND, { r: 110, ms: 300 });
          a.dust(c.x - 50, GROUND, 3, 1);
        }],
      ],
      smear: { tip: 'fistTop', base: 'elbowF', from: 590, to: 680, window: 32, fill: '#cfc8b8', inner: '#9a9488' },
      draw(ctx, cam, api, layer, t) {
        // ground cracks: race from the fists to under the target, then fade
        if (layer === 'back' && t >= T_SLAM) {
          const u = E.outExpo(clamp((t - T_SLAM) / 90, 0, 1)), al = t < 1000 ? 1 : clamp(1 - (t - 1000) / 250, 0, 1);
          ctx.setTransform(cam); ctx.globalAlpha = al; ctx.lineCap = 'round';
          ctx.beginPath(); ctx.ellipse(CRACK_MAIN[0][0], CRACK_MAIN[0][1], 34, 9, 0, 0, Math.PI * 2); ctx.fillStyle = 'rgba(43,34,32,.35)'; ctx.fill();
          crackLine(ctx, CRACK_MAIN, u, 13, 5);
          for (const b of CRACK_BR) crackLine(ctx, b.pts, clamp((u - b.at) / .25, 0, 1), 9, 3);
          ctx.globalAlpha = 1;
        }
      },
    },
  ],
};
