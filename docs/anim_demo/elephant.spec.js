// Voi chiến (elephant_p.svg, 256 viewBox, outline group stroke #2b2220 w7).
// Attack "Giẫm đất": rear up on hind legs, trunk raised + trumpet -> slam front feet -> ground cracks + shockwave + dust -> HIT.
// Parts = inner markup copied verbatim from elephant_p.svg; `raw` = drawn outside the outline group (faces).

// shared impact: same for all units (game-wide hit feel)
const HIT = { stop: 90, amp: 9, kx: 420, debris: 'spark', n: 8, sparkColor: '#ffe08a', cut: true, cutAng: -24 };
const HIT_SMALL = { small: true, stop: 45, amp: 4, kx: 0, debris: 'spark', n: 3, sparkColor: '#ffe08a', cut: false };
// main hit:   api.hit(Object.assign({}, HIT, { dmg: 42 }))     or  wave/projectile/tornado { hit: Object.assign({}, HIT, { dmg: 42 }) }
// multi-tick: Object.assign({}, HIT_SMALL, { dmg: 6 }) for the small ticks before the final HIT

const GROUND = 246;
const T_SLAM = 722;          // front feet touch ground
const T_HIT = 740;           // crack reaches target -> shared HIT
const T_TRUMP = [400, 650];  // sound lines window

// ground cracks (fixed geometry -> stateless draw): main crack foot -> under target, plus branches
const CRACK_MAIN = [[194, 252], [214, 247], [232, 255], [252, 249], [274, 256], [296, 250], [318, 257], [340, 251], [362, 256], [384, 250], [406, 255], [430, 251]];
const CRACK_BR = [
  { at: .0, pts: [[194, 252], [176, 262], [156, 260]] },
  { at: .0, pts: [[194, 252], [206, 240], [222, 236]] },
  { at: .16, pts: [[232, 255], [246, 266], [266, 268]] },
  { at: .34, pts: [[274, 256], [288, 242], [306, 238]] },
  { at: .62, pts: [[340, 251], [354, 264], [376, 267]] },
  { at: .8, pts: [[384, 250], [400, 239], [418, 236]] },
];
const plen = pts => pts.slice(1).reduce((s, q, i) => s + Math.hypot(q[0] - pts[i][0], q[1] - pts[i][1]), 0);
// draw the first u (0..1) of a polyline, tapering width w0 -> w1
function crackLine(ctx, pts, u, w0, w1) {
  const L = plen(pts) * u; let acc = 0;
  for (let i = 1; i < pts.length && acc < L; i++) {
    const [x0, y0] = pts[i - 1], [x1, y1] = pts[i], d = Math.hypot(x1 - x0, y1 - y0), k = Math.min(1, (L - acc) / d);
    const w = lerp(w0, w1, (acc + d * k / 2) / plen(pts));
    ctx.beginPath(); ctx.moveTo(x0, y0); ctx.lineTo(x0 + (x1 - x0) * k, y0 + (y1 - y0) * k);
    ctx.strokeStyle = '#a87a4c'; ctx.lineWidth = w + 9; ctx.stroke();
    ctx.strokeStyle = INK; ctx.lineWidth = w; ctx.stroke();
    acc += d;
  }
}

// dirt clods kicked toward the target (one-shot fx with own state)
function clods(api, x, n) {
  for (let i = 0; i < n; i++) {
    const q = { x: x + rnd(-14, 24), y: GROUND - 4, vx: rnd(120, 460), vy: rnd(-560, -260), r: rnd(6, 10), rot: rnd(0, 6), age: 0, life: rnd(520, 720) };
    api.add({
      upd(s, ms) { q.age += ms; q.vy += 1700 * s; q.x += q.vx * s; q.y += q.vy * s; q.rot += 9 * s; if (q.y > GROUND) { q.y = GROUND; q.vy *= -.3; q.vx *= .5; } return q.age < q.life; },
      draw(ctx, cam, layer) {
        if (layer !== 'front') return;
        const u = q.age / q.life;
        ctx.setTransform(cam.translate(q.x, q.y).rotate(q.rot * 57.3)); ctx.globalAlpha = u > .7 ? (1 - u) / .3 : 1;
        ctx.beginPath(); for (let k = 0; k < 5; k++) { const a = k / 5 * Math.PI * 2, r = q.r * (k % 2 ? .75 : 1); k ? ctx.lineTo(Math.cos(a) * r, Math.sin(a) * r) : ctx.moveTo(r, 0); }
        ctx.closePath(); ctx.fillStyle = '#a87a4c'; ctx.fill(); ctx.strokeStyle = INK; ctx.lineWidth = 3; ctx.lineJoin = 'round'; ctx.stroke(); ctx.globalAlpha = 1;
      },
    });
  }
}

const SPEC = {
  title: 'Voi chiến · Giẫm đất',
  subtitle: 'Chồm lên, rống vòi → giẫm nứt đất, sóng chấn lan tới địch',
  feet: 244, cx: 128, range: 1, shadowR: 100,
  parts: {
    tail: `<path d="M32 164 Q12 172 14 192" fill="none" stroke-width="6"/>
<path d="M8 188 L14 206 L22 190 Z" fill="#3a2e28" stroke-width="5"/>`,
    legHB: `<rect x="40" y="188" width="34" height="56" rx="13" fill="#85818a"/>
<rect x="38" y="206" width="38" height="11" rx="5" fill="#aab3bd" stroke-width="5"/>`,
    legFB: `<rect x="132" y="188" width="34" height="56" rx="13" fill="#85818a"/>
<rect x="130" y="206" width="38" height="11" rx="5" fill="#aab3bd" stroke-width="5"/>`,
    body: `<ellipse cx="108" cy="170" rx="80" ry="54" fill="#a9a6a8"/>
<path d="M38 134 Q104 106 170 128 L176 184 Q106 202 34 184 Z" fill="#c9503f"/>
<path d="M46 138 Q104 116 160 132" fill="none" stroke="#93362b" stroke-width="5"/>
<circle cx="66" cy="156" r="15" fill="#e2c36e" stroke-width="5"/>
<circle cx="66" cy="156" r="6" fill="#93362b" stroke-width="4"/>
<path d="M88 172 L96 164 L104 172 L112 164 L120 172 L128 164 L136 172" fill="none" stroke="#e2c36e" stroke-width="5"/>
<path d="M34 182 Q106 200 176 182 L178 200 Q106 222 32 200 Z" fill="#aab3bd"/>
<path d="M54 192 L54 206 M74 196 L74 212 M94 198 L94 215 M114 198 L114 215 M134 197 L134 213 M154 193 L154 208" stroke="#7e8790" stroke-width="4"/>
<path d="M36 183 Q106 201 176 183" fill="none" stroke="#e2c36e" stroke-width="9"/>`,
    legHF: `<rect x="62" y="194" width="38" height="50" rx="14" fill="#a9a6a8"/>
<rect x="60" y="208" width="42" height="12" rx="5" fill="#aab3bd" stroke-width="5"/>
<path d="M71 238 L74 238 M80 238 L83 238 M89 238 L92 238" stroke="#f5ecd8" stroke-width="5"/>`,
    legFF: `<rect x="152" y="194" width="38" height="50" rx="14" fill="#a9a6a8"/>
<rect x="150" y="208" width="42" height="12" rx="5" fill="#aab3bd" stroke-width="5"/>
<path d="M161 238 L164 238 M170 238 L173 238 M179 238 L182 238" stroke="#f5ecd8" stroke-width="5"/>`,
    rider: `<rect x="104" y="116" width="16" height="26" rx="5" fill="#5a4a3c"/>
<rect x="100" y="134" width="26" height="13" rx="6" fill="#3a2e28"/>
<path d="M92 84 Q110 78 128 84 L132 122 Q110 128 88 122 Z" fill="#c9503f"/>
<path d="M90 110 L130 110" stroke="#6b4a2e" stroke-width="7"/>
<circle cx="112" cy="58" r="27" fill="#f3cfa6"/>
<path d="M85 58 A27 27 0 0 1 139 58 L144 64 L80 64 Z" fill="#aab3bd"/>
<path d="M87 58 L137 58" stroke="#7e8790" stroke-width="5"/>
<path d="M104 32 Q112 16 124 24 Q118 28 116 33" fill="#c9503f" stroke-width="5"/>`,
    goad: `<path d="M142 118 L162 54" stroke-width="12"/>
<path d="M142 118 L162 54" stroke="#a87a4c" stroke-width="5"/>
<path d="M164 50 Q178 48 176 62" fill="none" stroke-width="10"/>
<path d="M164 50 Q178 48 176 62" fill="none" stroke="#cdd4da" stroke-width="4"/>
<path d="M156 60 L166 32 L170 62 Z" fill="#cdd4da" stroke-width="5"/>`,
    rarm: `<path d="M120 94 Q134 102 146 100" fill="none" stroke-width="18"/>
<path d="M120 94 Q134 102 146 100" fill="none" stroke="#c9503f" stroke-width="8"/>
<circle cx="148" cy="99" r="8" fill="#f3cfa6" stroke-width="5"/>`,
    trunk2: `<path d="M226 200 Q227 216 223 222 Q217 232 228 233 Q238 233 235 223" fill="none" stroke-width="28"/>
<path d="M226 200 Q227 216 223 222 Q217 232 228 233 Q238 233 235 223" fill="none" stroke="#a9a6a8" stroke-width="14"/>`,
    trunk1: `<path d="M208 156 Q224 174 226 200" fill="none" stroke-width="28" stroke-linecap="butt"/>
<path d="M208 156 Q224 174 226 200" fill="none" stroke="#a9a6a8" stroke-width="14" stroke-linecap="butt"/>`,
    head: `<circle cx="186" cy="136" r="50" fill="#a9a6a8"/>
<path d="M144 116 Q176 74 224 96 L228 110 Q188 92 152 126 Z" fill="#aab3bd"/>
<path d="M176 84 L184 62 L194 82" fill="#e2c36e" stroke-width="5"/>
<circle cx="180" cy="97" r="4" fill="#e2c36e" stroke-width="3"/>
<circle cx="204" cy="96" r="4" fill="#e2c36e" stroke-width="3"/>
<path d="M204 170 Q220 192 244 186 Q228 180 214 162 Z" fill="#f5ecd8" stroke-width="5"/>`,
    ear: `<ellipse cx="160" cy="140" rx="28" ry="38" fill="#85818a"/>
<path d="M150 114 Q138 140 150 166" fill="none" stroke="#a9a6a8" stroke-width="5"/>`,
    face: `<path d="M199 108 L217 113" stroke="#2b2220" stroke-width="4" stroke-linecap="round"/>
<circle cx="210" cy="123" r="7" fill="#2b2220"/>
<circle cx="212" cy="121" r="2.5" fill="#fff"/>
<ellipse cx="224" cy="141" rx="7" ry="4.5" fill="#f09a88" opacity="0.6"/>
<path d="M194 158 Q200 163 206 159" fill="none" stroke="#2b2220" stroke-width="3" stroke-linecap="round"/>`,
    rface: `<circle cx="120" cy="73" r="4.5" fill="#2b2220"/>
<circle cx="133" cy="73" r="4.5" fill="#2b2220"/>
<circle cx="121.3" cy="71.7" r="1.5" fill="#fff"/>
<circle cx="134.3" cy="71.7" r="1.5" fill="#fff"/>
<ellipse cx="138" cy="80" rx="4" ry="2.6" fill="#f09a88" opacity="0.6"/>
<path d="M122 82 Q126 85 130 83" fill="none" stroke="#2b2220" stroke-width="2.5" stroke-linecap="round"/>`,
  },
  raw: ['face', 'rface'],
  // parent before child; pivot in 256 space
  bones: [
    { name: 'legHB', pivot: [57, 190], ch: 'hindB' },          // hind legs stay planted (root)
    { name: 'legHF', pivot: [81, 196], ch: 'hind' },
    { name: 'body', pivot: [70, 200], ch: 'lean' },             // pivot = hind hip -> rears up
    { name: 'tail', parent: 'body', pivot: [32, 164], ch: 'tail' },
    { name: 'legFB', parent: 'body', pivot: [149, 192], ch: 'frontB' },
    { name: 'legFF', parent: 'body', pivot: [171, 198], ch: 'front' },
    { name: 'rider', parent: 'body', pivot: [112, 128], ch: 'rider' },
    { name: 'rarm', parent: 'rider', pivot: [120, 94], ch: 'rarm' },
    { name: 'goad', parent: 'rarm', pivot: [148, 99], ch: 'goad' },   // pivot = hand
    { name: 'head', parent: 'body', pivot: [166, 166], ch: 'head' },
    { name: 'trunk1', parent: 'head', pivot: [210, 160], ch: 'tr1' },
    { name: 'trunk2', parent: 'trunk1', pivot: [226, 200], ch: 'tr2' },
    { name: 'ear', parent: 'head', pivot: [180, 120], ch: 'ear' },
  ],
  // same order as the source SVG
  draw: [['tail', 'tail'], ['legHB', 'legHB'], ['legFB', 'legFB'], ['body', 'body'], ['legHF', 'legHF'], ['legFF', 'legFF'],
         ['rider', 'rider'], ['goad', 'goad'], ['rarm', 'rarm'], ['trunk2', 'trunk2'], ['trunk1', 'trunk1'],
         ['head', 'head'], ['ear', 'ear'], ['face', 'head'], ['rface', 'rider']],
  points: { tip: ['trunk2', 235, 223], troot: ['trunk1', 210, 160], foot: ['legFF', 171, 244] },
  springs: {
    ear: { k: 210, c: 10, drive: (p, vx, c) => (p.earX || 0) + clamp(vx * .02, -10, 14) + (c.idle ? 3 * Math.sin(c.clock / 520) : 0) },
    tail: { k: 150, c: 8, drive: (p, vx, c) => -p.lean * .7 + clamp(-vx * .03, -20, 20) + (c.idle ? 5 * Math.sin(c.clock / 800) : 0) },
  },
  idle(p, b, clock) {
    p.sy = 1 + .012 * b; p.head = 1.2 * b; p.rider = 1.5 * b; p.rarm = 2 * b;
    p.tr1 = 3 * b; p.tr2 = 6 * Math.sin(clock / 1300 * Math.PI * 2);
  },
  attacks: [
    {
      id: 'stomp', label: '🐘 Giẫm đất', dur: 1550,
      tr: {
        x: track([[0, 0], [160, -4, 'out'], [420, -12, 'out'], [640, -14], [T_SLAM, 22, 'in'], [900, 18, 'out'], [1450, 0, 'io']]),
        sy: track([[0, 1], [160, .9, 'out'], [420, 1.05, 'out'], [640, 1.04], [T_SLAM, .84, 'in'], [830, 1.05, 'out'], [960, 1, 'io']]),
        lean: track([[0, 0], [160, 5, 'out'], [420, -26, 'out'], [560, -28, 'io'], [640, -27], [T_SLAM, 2, 'in'], [820, 0, 'out'], [1450, 0]]),
        front: track([[0, 0], [160, 6, 'out'], [420, -48, 'out'], [640, -52], [T_SLAM, -2, 'in'], [820, 0, 'out']]),
        frontB: track([[0, 0], [160, 6, 'out'], [420, -40, 'out'], [640, -44], [T_SLAM, -2, 'in'], [820, 0, 'out']]),
        head: track([[0, 0], [160, 6, 'out'], [420, -10, 'out'], [480, -12], [520, -9], [560, -12], [600, -9], [640, -11], [T_SLAM, 10, 'in'], [830, 3, 'out'], [1450, 0, 'io']]),
        tr1: track([[0, 0], [160, 14, 'out'], [420, -62, 'out'], [640, -68], [T_SLAM, 18, 'in'], [850, -10, 'out'], [1030, 3, 'io'], [1450, 0, 'io']]),
        tr2: track([[0, 0], [160, 10, 'out'], [420, -30, 'out'], [640, -36], [T_SLAM, 16, 'in'], [870, -8, 'out'], [1450, 0, 'io']]),
        earX: track([[0, 0], [300, 0], [430, 30, 'out'], [640, 32], [T_SLAM, -10, 'in'], [900, 0, 'io']]),
        rider: track([[0, 0], [160, 4, 'out'], [420, -10, 'out'], [640, -12], [T_SLAM, 10, 'in'], [830, -4, 'out'], [1450, 0, 'io']]),
        rarm: track([[0, 0], [200, 0], [420, -38, 'outBack'], [640, -42], [T_SLAM, -10, 'in'], [1450, 0, 'io']]),
        goad: track([[0, 0], [200, 0], [420, 50, 'out'], [640, 54], [T_SLAM, 12, 'in'], [1450, 0, 'io']]),
      },
      ev: [
        [400, a => a.dust(70, GROUND, 5, -1)],
        [430, a => a.shake(3, 260)],                               // trumpet rumble
        [T_SLAM, a => {
          const f = a.point('foot');
          a.flash('#fff6dc', 40);
          a.shake(16, 440);                                        // heavy unit: stronger shake than the shared HIT (HIT amp 9 won't override)
          a.shockwave(f.x + 6, GROUND, { r: 120, ms: 340 });
          a.dust(f.x + 20, GROUND, 4, 1); a.dust(f.x - 30, GROUND, 3, -1);
          clods(a, f.x + 10, 6);
        }],
        [T_HIT, a => {
          const c = a.target();
          a.hit(Object.assign({}, HIT, { dmg: 65 }));
          a.shockwave(c.x, GROUND, { r: 110, ms: 300 });
          a.dust(c.x - 50, GROUND, 3, 1);
        }],
      ],
      draw(ctx, cam, api, layer, t) {
        // ground cracks: race from the front feet to under the target, then fade
        if (layer === 'back' && t >= T_SLAM) {
          const u = E.outExpo(clamp((t - T_SLAM) / 90, 0, 1)), al = t < 1200 ? 1 : clamp(1 - (t - 1200) / 330, 0, 1);
          ctx.setTransform(cam); ctx.globalAlpha = al; ctx.lineCap = 'round';
          ctx.beginPath(); ctx.ellipse(CRACK_MAIN[0][0], CRACK_MAIN[0][1], 30, 8, 0, 0, Math.PI * 2); ctx.fillStyle = 'rgba(43,34,32,.35)'; ctx.fill();
          crackLine(ctx, CRACK_MAIN, u, 13, 5);
          for (const b of CRACK_BR) crackLine(ctx, b.pts, clamp((u - b.at) / .25, 0, 1), 9, 3);
          ctx.globalAlpha = 1;
        }
        // trumpet: sound dashes pulsing out of the raised trunk tip
        if (layer === 'front' && t > T_TRUMP[0] && t < T_TRUMP[1]) {
          const tip = api.point('tip'), bk = api.point('troot');
          const a0 = Math.atan2(tip.y - bk.y, tip.x - bk.x);
          const env = clamp((t - T_TRUMP[0]) / 40, 0, 1) * clamp((T_TRUMP[1] - t) / 60, 0, 1);
          ctx.setTransform(cam); ctx.lineCap = 'round';
          for (let k = 0; k < 3; k++) {
            const ph = ((t - T_TRUMP[0]) / 200 + k / 3) % 1, d = 16 + 56 * ph, len = 22 - 8 * ph;
            ctx.globalAlpha = env * (1 - ph * ph);
            for (const da of [-.6, 0, .6]) {
              const a = a0 + da, cx = Math.cos(a), cy = Math.sin(a);
              const x0 = tip.x + cx * d, y0 = tip.y + cy * d;
              ctx.beginPath(); ctx.moveTo(x0, y0); ctx.lineTo(x0 + cx * len, y0 + cy * len);
              ctx.strokeStyle = INK; ctx.lineWidth = 10; ctx.stroke(); ctx.strokeStyle = '#fffaf0'; ctx.lineWidth = 4.5; ctx.stroke();
            }
          }
          ctx.globalAlpha = 1;
        }
      },
    },
  ],
};
