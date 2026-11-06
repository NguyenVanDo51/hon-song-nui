// Thủy binh (boat_p.svg, 256 viewBox, outline group #2b2220 w7). Range 1 melee.
// Attack "Sóng cuộn": overhead paddle-spear sweep -> blade slaps the water in front -> curling wave rolls forward and crashes on the target.
// Parts = inner markup copied verbatim from boat_p.svg (face sits inside the outline group with explicit strokes).

// shared impact: same for all units (game-wide hit feel)
const HIT = { stop: 90, amp: 9, kx: 420, debris: 'spark', n: 8, sparkColor: '#ffe08a', cut: true, cutAng: -24 };
const HIT_SMALL = { small: true, stop: 45, amp: 4, kx: 0, debris: 'spark', n: 3, sparkColor: '#ffe08a', cut: false };

const GROUND = 244;
const WATER = '#6fb6e0', WSHADE = '#3f8cc4', FOAM = '#f4fcff';
const BLADE = bake(10, 196, 160, 196, 12);    // paddle group has rotate(10 196 160) baked in
const BLADE_B = bake(10, 196, 160, 196, 90);

// water droplets: outlined teardrops along velocity, gravity, die on the ground
function drops(api, x, y, n, o = {}) {
  for (let i = 0; i < n; i++) {
    const q = { x: x + rnd(-(o.sx ?? 20), o.sx ?? 20), y: y + rnd(-10, 10), vx: rnd(o.vx0 ?? -150, o.vx1 ?? 350), vy: rnd(o.vy0 ?? -620, o.vy1 ?? -260),
      r: rnd(o.r0 ?? 5, o.r1 ?? 10), life: rnd(650, 1000), age: 0 };
    api.add({
      upd(s, ms) { q.age += ms; q.vy += 1500 * s; q.x += q.vx * s; q.y += q.vy * s; return q.age < q.life && q.y < GROUND + 6; },
      draw(ctx, cam, layer) {
        if (layer !== 'front') return;
        const r = q.r;
        ctx.setTransform(cam.translate(q.x, q.y).rotate(Math.atan2(q.vy, q.vx) * 57.3));
        ctx.globalAlpha = q.age > q.life * .7 ? 1 - (q.age - q.life * .7) / (q.life * .3) : 1;
        ctx.beginPath(); ctx.moveTo(-r * 2.3, 0); ctx.quadraticCurveTo(-r * .6, -r, 0, -r); ctx.arc(0, 0, r, -Math.PI / 2, Math.PI / 2); ctx.quadraticCurveTo(-r * .6, r, -r * 2.3, 0);
        ctx.fillStyle = WATER; ctx.fill(); ctx.strokeStyle = INK; ctx.lineWidth = 3; ctx.lineJoin = 'round'; ctx.stroke();
        ctx.beginPath(); ctx.arc(r * .2, -r * .35, r * .3, 0, Math.PI * 2); ctx.fillStyle = FOAM; ctx.fill();
        ctx.globalAlpha = 1;
      },
    });
  }
}

// curling wave, base on the ground at X, height H; c = curl 0..2 (1 = full barrel, 2 = lip slammed down), k = forward lean
function drawWave(ctx, cam, X, H, c, k, alpha) {
  const P = (x, y) => [X + (x * .85 - k * y) * H, GROUND + y * H];
  const tip = [.18 + .42 * c, -1 + .5 * c], I = [.16 + .1 * c, -.6 + .1 * c];
  const lip = (move) => {
    if (move) ctx.moveTo(...P(-.05, -1));
    ctx.bezierCurveTo(...P(.25, -1.02), ...P(tip[0] + .06, -1 + .2 * c), ...P(tip[0], tip[1]));
  };
  ctx.setTransform(cam); ctx.globalAlpha = alpha; ctx.lineJoin = 'round'; ctx.lineCap = 'round';
  // body
  ctx.beginPath(); ctx.moveTo(...P(-.85, 0));
  ctx.bezierCurveTo(...P(-.45, 0), ...P(-.45, -1), ...P(-.05, -1));
  lip(false);
  ctx.bezierCurveTo(...P(tip[0] - .04, tip[1] - .22 * Math.min(c, 1)), ...P(I[0] + .14, I[1] - .14), ...P(I[0], I[1]));
  ctx.bezierCurveTo(...P(I[0] - .1, I[1] + .25), ...P(.16, -.06), ...P(.42, 0));
  ctx.closePath(); ctx.fillStyle = WATER; ctx.fill(); ctx.strokeStyle = INK; ctx.lineWidth = 6; ctx.stroke();
  // shade on the inner face (no outline)
  ctx.beginPath(); ctx.moveTo(...P(I[0], I[1]));
  ctx.bezierCurveTo(...P(I[0] - .1, I[1] + .25), ...P(.16, -.06), ...P(.36, -.01));
  ctx.lineTo(...P(.02, -.01)); ctx.bezierCurveTo(...P(-.06, -.3), ...P(-.04, -.62), ...P(I[0], I[1]));
  ctx.fillStyle = WSHADE; ctx.fill();
  // motion streaks on the back slope
  ctx.strokeStyle = FOAM; ctx.lineWidth = 5; ctx.globalAlpha = alpha * .9;
  for (const [a, b, y] of [[-.55, -.3, -.45], [-.42, -.2, -.72], [-.66, -.5, -.2]]) { ctx.beginPath(); ctx.moveTo(...P(a, y)); ctx.lineTo(...P(b, y - .04)); ctx.stroke(); }
  ctx.globalAlpha = alpha;
  // foam cap along the crest -> lip
  const w = Math.max(9, H * .1);
  ctx.beginPath(); ctx.moveTo(...P(-.32, -.94)); ctx.quadraticCurveTo(...P(-.2, -1.01), ...P(-.05, -1)); lip(false);
  ctx.strokeStyle = INK; ctx.lineWidth = w + 7; ctx.stroke(); ctx.strokeStyle = FOAM; ctx.lineWidth = w; ctx.stroke();
  // foam bubbles off the lip
  ctx.fillStyle = FOAM; ctx.strokeStyle = INK; ctx.lineWidth = 3;
  for (const [dx, dy, r] of [[.08, -.1, .05], [-.02, .02, .035], [.12, .06, .03]]) {
    ctx.beginPath(); ctx.arc(...P(tip[0] + dx, tip[1] + dy), Math.max(4, r * H), 0, Math.PI * 2); ctx.fill(); ctx.stroke();
  }
  ctx.globalAlpha = 1;
}

// wave fx: rises + curls toward the target, crashes (shared HIT), then collapses into foam
function waveFx(api, x0) {
  const RISE = 150, FALL = 340, HMAX = 200, st = { age: 0, hit: false };
  return {
    upd(s, ms) {
      st.age += ms;
      if (!st.hit && st.age >= RISE) {
        st.hit = true;
        const c = api.target();
        api.hit(Object.assign({}, HIT, { dmg: 52 }));
        drops(api, c.x, c.y - 30, 16, { sx: 34, vx0: -180, vx1: 420, vy0: -700, vy1: -280, r0: 6, r1: 11 });
        api.shockwave(c.x, GROUND, { color: WATER, r: 150, ms: 460 });
      }
      return st.age < RISE + FALL;
    },
    draw(ctx, cam, layer) {
      if (layer !== 'mid') return;
      const a = st.age;
      if (a < RISE) {
        const u = a / RISE, e = E.out(u);
        drawWave(ctx, cam, lerp(x0, x0 + 44, e), lerp(40, HMAX, e), E.out(clamp((u - .15) / .85, 0, 1)), lerp(.05, .25, u), 1);
      } else {
        const v = (a - RISE) / FALL, e = E.out(v);
        drawWave(ctx, cam, x0 + 44 + 30 * e, HMAX * (1 - .7 * e), 1 + .9 * e, .25 + .25 * e, v < .45 ? 1 : 1 - (v - .45) / .55);
      }
    },
  };
}

const SPEC = {
  title: 'Thủy binh · Sóng cuộn',
  subtitle: 'paddle-spear sweep -> curling wave crashes on the target',
  feet: GROUND, cx: 128, range: 1,
  parts: {
    shield: `<circle cx="78" cy="178" r="32" fill="#e2c36e"/>
<circle cx="78" cy="178" r="22" fill="none" stroke="#a87a4c" stroke-width="4"/>
<path d="M78 146 L78 156 M78 200 L78 210 M46 178 L56 178 M100 178 L110 178" stroke="#a87a4c" stroke-width="4"/>
<circle cx="78" cy="178" r="12" fill="#c9503f" stroke-width="5"/>
<path d="M78 167 L80.5 175.5 L89 178 L80.5 180.5 L78 189 L75.5 180.5 L67 178 L75.5 175.5 Z" fill="#e2c36e" stroke-width="3"/>`,
    legB: `<rect x="106" y="196" width="18" height="40" rx="4" fill="#f3cfa6"/>
<path d="M107 222 L123 222" stroke="#5a4a3c" stroke-width="5"/>
<rect x="100" y="230" width="28" height="15" rx="7" fill="#f3cfa6"/>`,
    legF: `<rect x="136" y="196" width="18" height="40" rx="4" fill="#f3cfa6"/>
<path d="M137 222 L153 222" stroke="#5a4a3c" stroke-width="5"/>
<rect x="132" y="230" width="30" height="15" rx="7" fill="#f3cfa6"/>`,
    torso: `<path d="M100 128 Q128 118 156 128 L164 200 Q128 210 92 200 Z" fill="#c9503f"/>
<polyline points="96,194 106,184 116,194 126,184 136,194 146,184 156,194 162,186" fill="none" stroke="#93362b" stroke-width="5"/>
<path d="M116 174 L142 174 L138 222 Q130 228 120 222 Z" fill="#93362b"/>
<path d="M95 174 L161 174" stroke="#5a4a3c" stroke-width="10"/>
<circle cx="128" cy="174" r="6" fill="#e2c36e" stroke-width="4"/>`,
    plume: `<path d="M104 50 Q76 22 44 26 Q62 44 92 62 Z" fill="#c9503f" stroke-width="5"/>
<path d="M118 40 Q108 8 78 2 Q90 22 102 52 Z" fill="#efe3c8" stroke-width="5"/>
<path d="M91 15 Q86 9 80 6" fill="none" stroke="#c9503f" stroke-width="5"/>`,
    head: `<circle cx="130" cy="84" r="54" fill="#f3cfa6"/>
<path d="M76.5 76 A54 54 0 0 1 183.5 76 Z" fill="#3a2e28"/>
<path d="M77 68 Q130 50 183 68 L184 82 Q130 64 76 82 Z" fill="#c9503f"/>
<path d="M96 66 L104 60 L112 64 L120 58 L128 62" fill="none" stroke="#93362b" stroke-width="3"/>
<circle cx="84" cy="74" r="7" fill="#e2c36e" stroke-width="5"/>`,
    face: `<path d="M141 100 L154 104 M164 104 L177 100" stroke="#2b2220" stroke-width="4"/>
<circle cx="148" cy="112" r="6" fill="#2b2220" stroke="none"/>
<circle cx="170" cy="112" r="6" fill="#2b2220" stroke="none"/>
<circle cx="150" cy="110" r="2" fill="#fff" stroke="none"/>
<circle cx="172" cy="110" r="2" fill="#fff" stroke="none"/>
<ellipse cx="179" cy="124" rx="6" ry="4" fill="#f09a88" opacity="0.6" stroke="none"/>
<path d="M150 130 Q156 135 162 131" fill="none" stroke="#2b2220" stroke-width="3"/>`,
    paddle: `<g transform="rotate(10 196 160)">
<line x1="196" y1="60" x2="196" y2="228" stroke="#2b2220" stroke-width="15"/>
<line x1="196" y1="60" x2="196" y2="228" stroke="#a87a4c" stroke-width="7"/>
<path d="M196 6 Q224 30 216 70 Q208 88 196 94 Q184 88 176 70 Q168 30 196 6 Z" fill="#a87a4c"/>
<path d="M196 22 L196 84" stroke="#6b4a2e" stroke-width="5"/>
<path d="M184 62 L196 70 L208 62" fill="none" stroke="#c9503f" stroke-width="4"/>
<path d="M196 248 L207 222 L185 222 Z" fill="#cdd4da" stroke-width="5"/>
<path d="M188 222 L204 222" stroke="#c9503f" stroke-width="6"/>
</g>`,
    arm: `<path d="M152 140 Q176 150 196 158" fill="none" stroke="#2b2220" stroke-width="24"/>
<path d="M152 140 Q176 150 196 158" fill="none" stroke="#f3cfa6" stroke-width="12"/>
<path d="M162 140 L158 152" stroke="#2b2220" stroke-width="16" stroke-linecap="butt"/>
<path d="M162 140 L158 152" stroke="#c9503f" stroke-width="7" stroke-linecap="butt"/>
<circle cx="196" cy="160" r="12" fill="#f3cfa6" stroke-width="5"/>`,
  },
  bones: [
    { name: 'body', pivot: [128, 200], ch: 'lean' },
    { name: 'shield', parent: 'body', pivot: [100, 160], ch: 'shld' },
    { name: 'head', parent: 'body', pivot: [130, 138], ch: 'head' },
    { name: 'plume', parent: 'head', pivot: [104, 58], ch: 'plume' },
    { name: 'arm', parent: 'body', pivot: [152, 140], ch: 'arm' },
    { name: 'paddle', parent: 'arm', pivot: [196, 160], ch: 'wrist' },   // pivot = hand centre
    { name: 'legB', pivot: [115, 198], ch: 'legB' },
    { name: 'legF', pivot: [145, 198], ch: 'legF' },
  ],
  // same order as the source SVG
  draw: [['shield', 'shield'], ['legB', 'legB'], ['legF', 'legF'], ['torso', 'body'], ['plume', 'plume'], ['head', 'head'], ['face', 'head'],
         ['paddle', 'paddle'], ['arm', 'arm']],
  points: { blade: ['paddle', BLADE[0], BLADE[1]], bladeB: ['paddle', BLADE_B[0], BLADE_B[1]] },
  springs: {
    plume: { k: 210, c: 9, drive: (p, vx, c) => clamp(vx * .035, -14, 30) + p.lean * .8 + p.head * .6 + (c.idle ? 2 * Math.sin(c.clock / 700) : 0) },
  },
  idle(p, b) { p.sy = 1 + .014 * b; p.head = 1.5 * b; p.arm = 2 * b; p.wrist = -1.5 * b; p.shld = b; },
  attacks: [
    {
      id: 'wave', label: '🌊 Sóng cuộn', dur: 1300,
      tr: {
        x: track([[0, 0], [180, -12, 'out'], [235, -14], [310, 22, 'outExpo'], [660, 26, 'out'], [1200, 0, 'io']]),
        y: track([[0, 0], [180, 5, 'out'], [235, 6], [290, -8, 'out'], [360, 0, 'in']]),
        sy: track([[0, 1], [180, .88, 'out'], [235, .87], [285, 1.1, 'outExpo'], [330, .93, 'out'], [440, 1, 'out']]),
        lean: track([[0, 0], [180, -12, 'out'], [235, -13], [310, 14, 'outExpo'], [660, 10, 'out'], [1200, 0, 'io']]),
        head: track([[0, 0], [180, -8, 'out'], [235, -8], [310, 8, 'outExpo'], [660, 4], [1200, 0, 'io']]),
        arm: track([[0, 0], [180, -44, 'outBack'], [235, -47], [305, 52, 'outExpo'], [420, 46, 'out'], [660, 42, 'out'], [1200, 0, 'io']]),
        wrist: track([[0, 0], [180, 4, 'outBack'], [235, 4], [305, 44, 'outExpo'], [420, 36, 'out'], [660, 32, 'out'], [1200, 0, 'io']]),
        legF: track([[0, 0], [180, 8], [235, 8], [310, -24, 'outExpo'], [660, -20], [1200, 0, 'io']]),
        legB: track([[0, 0], [180, -4], [235, -4], [310, 18, 'outExpo'], [660, 15], [1200, 0, 'io']]),
        shld: track([[0, 0], [180, 8], [235, 8], [310, -12, 'outExpo'], [660, -9], [1200, 0, 'io']]),
      },
      ev: [
        [170, a => a.gleam('blade')],
        [240, a => a.dust(100, GROUND, 5, -1)],
        [300, a => {
          const b = a.point('blade'), x = Math.max(200, Math.min(b.x, 300));
          drops(a, x, GROUND - 14, 9, { sx: 26, vx0: 60, vx1: 380, vy0: -560, vy1: -220, r0: 4, r1: 8 });
          a.shockwave(x, GROUND, { color: WATER, r: 80, ms: 320 });
          a.add(waveFx(a, 250));
        }],
      ],
      smear: { tip: 'blade', base: 'bladeB', from: 240, to: 360, window: 48, fill: FOAM, inner: WATER },
    },
  ],
};
