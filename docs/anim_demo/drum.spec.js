// shared impact: same for all units (game-wide hit feel)
const HIT = { stop: 90, amp: 9, kx: 420, debris: 'spark', n: 8, sparkColor: '#ffe08a', cut: true, cutAng: -24 };
const HIT_SMALL = { small: true, stop: 45, amp: 4, kx: 0, debris: 'spark', n: 3, sparkColor: '#ffe08a', cut: false };
// main hit:   api.hit(Object.assign({}, HIT, { dmg: 42 }))     or  wave/projectile/tornado { hit: Object.assign({}, HIT, { dmg: 42 }) }
// multi-tick: Object.assign({}, HIT_SMALL, { dmg: 6 }) for the small ticks before the final HIT

// Trống đồng: L stick BOOM -> R stick BOOM; each boom rolls a bronze sound ring to the target.
const BRONZE = '#e2c36e', PALE = '#fff6d6';

// sound ring: upright concentric ellipses rolling right, hit on reaching the target front
function soundRing(api, o) {
  const p0 = api.point('rim'), st = { x: p0.x, y0: p0.y, age: 0, hit: false, gone: 0 };
  const R0 = o.R0 ?? 34, R1 = o.R1 ?? 84, sp = o.speed ?? 1300, FADE = 200;
  return api.add({
    upd(s, ms) {
      st.age += ms; st.x += sp * s * (st.hit ? .35 : 1);
      const t = api.target();
      if (!st.hit && st.x >= t.front) { st.hit = true; api.hit(o.hit); }
      if (st.hit) st.gone += ms;
      return st.gone < FADE;
    },
    draw(ctx, cam, layer) {
      if (layer !== 'front') return;
      const T = api.target();
      const ry = (lerp(R0, R1, E.out(clamp(st.age / 120, 0, 1))) + st.gone * .12) * (o.scale ?? 1);
      const y = lerp(st.y0, T.y, E.out(clamp(st.age / 110, 0, 1)));
      const a = 1 - st.gone / FADE;
      ctx.setTransform(cam); ctx.lineCap = 'round';
      // 3 concentric rings, outer = leading edge at st.x
      for (let k = 0; k < 3; k++) {
        const f = 1 - k * .3, r = ry * f, rx = r * .32, cx = st.x - rx - k * 10;
        ctx.globalAlpha = a * (1 - k * .22);
        ctx.beginPath(); ctx.ellipse(cx, y, rx, r, 0, 0, Math.PI * 2);
        ctx.strokeStyle = INK; ctx.lineWidth = (k ? 9 : 12); ctx.stroke();
        ctx.strokeStyle = k ? BRONZE : PALE; ctx.lineWidth = (k ? 4.5 : 6); ctx.stroke();
        if (!k) { ctx.strokeStyle = BRONZE; ctx.lineWidth = 2.5; ctx.stroke(); }
      }
      ctx.globalAlpha = 1;
    },
  });
}

// per-boom fx at the drum face (shockwave around the face, sparks at the striking tip, small shake)
function boom(api, tip, big) {
  const f = api.point('face');
  api.shockwave(f.x, f.y, { r: big ? 110 : 80, ms: big ? 320 : 260, color: BRONZE });
  api.sparks(api.point(tip).x, f.y - 4, big ? 7 : 5, BRONZE);
  api.shake(big ? 6 : 4, big ? 160 : 120);
  if (big) api.dust(128, 244, 6, 0);
}

const SPEC = {
  title: 'Trống đồng · Song hồi trống trận',
  subtitle: 'Hai dùi giáng xuống mặt trống Đông Sơn — vòng âm đồng lăn tới đập vào địch.',
  feet: 244, cx: 128, range: 1,
  parts: {
    tails: `<path d="M84 70 Q66 56 50 58 Q58 68 58 76 Q70 74 84 78 Z" fill="#c9503f" stroke-width="5"/>
<path d="M84 78 Q70 84 56 94 Q66 98 70 106 Q78 94 88 86 Z" fill="#93362b" stroke-width="5"/>`,
    legs: `<rect x="104" y="196" width="20" height="40" rx="4" fill="#5a4a3c"/>
<rect x="134" y="196" width="20" height="40" rx="4" fill="#5a4a3c"/>
<rect x="98" y="228" width="30" height="18" rx="8" fill="#3a2e28"/>
<rect x="130" y="228" width="32" height="18" rx="8" fill="#3a2e28"/>`,
    torso: `<path d="M100 128 Q128 118 156 128 L164 200 Q128 210 92 200 Z" fill="#c9503f"/>
<path d="M104 134 Q101 168 97 198 Q106 201 113 202 L114 129 Z" fill="#93362b" stroke="none"/>`,
    strap: `<path d="M108 128 L176 172" stroke="#2b2220" stroke-width="16"/>
<path d="M108 128 L176 172" stroke="#5a4a3c" stroke-width="8"/>`,
    drumBody: `<path d="M92 170 C90 186 94 196 102 204 L98 222 Q146 236 194 222 L190 204 C198 196 202 186 200 170 Z" fill="#b58a3e"/>
<path d="M92 170 C91 182 93 190 97 196 Q146 210 195 196 C199 190 201 182 200 170 Z" fill="#e2c36e" stroke-width="5"/>
<path d="M101 204 Q146 216 191 204" fill="none" stroke-width="5"/>
<path d="M100 214 Q146 226 192 214" fill="none" stroke="#e2c36e" stroke-width="4"/>
<path d="M108 190 q4 -6 9 -2 q5 -5 9 1 M117 188 l9 2 M138 194 q4 -6 9 -2 q5 -5 9 1 M147 192 l9 2 M168 190 q4 -6 9 -2 q5 -5 9 1 M177 188 l9 2" fill="none" stroke="#8a6634" stroke-width="3"/>`,
    drumFace: `<ellipse cx="146" cy="170" rx="54" ry="15" fill="#e2c36e"/>
<ellipse cx="146" cy="170" rx="42" ry="11" fill="none" stroke="#b58a3e" stroke-width="3"/>
<ellipse cx="146" cy="170" rx="28" ry="7.5" fill="none" stroke="#b58a3e" stroke-width="3"/>
<path d="M175 170 q3 -3 6 0 q3 -3 6 0 M105 170 q3 -3 6 0 q3 -3 6 0 M140 180.5 q3 -2 6 0 q3 -2 6 0 M140 160 q3 -2 6 0 q3 -2 6 0" fill="none" stroke="#8a6634" stroke-width="2"/>
<polygon points="170.0,170.0 154.7,170.7 166.8,173.4 152.4,171.8 158.0,175.8 148.3,172.4 146.0,176.7 143.7,172.4 134.0,175.8 139.6,171.8 125.2,173.4 137.3,170.7 122.0,170.0 137.3,169.3 125.2,166.6 139.6,168.2 134.0,164.2 143.7,167.6 146.0,163.3 148.3,167.6 158.0,164.2 152.4,168.2 166.8,166.6 154.7,169.3" fill="#b58a3e" stroke="none"/>`,
    // flash overlay for the drum face (not in the source art; alpha 0 at rest)
    glow: `<ellipse cx="146" cy="170" rx="54" ry="15" fill="#fff6d6"/>
<polygon points="170.0,170.0 154.7,170.7 166.8,173.4 152.4,171.8 158.0,175.8 148.3,172.4 146.0,176.7 143.7,172.4 134.0,175.8 139.6,171.8 125.2,173.4 137.3,170.7 122.0,170.0 137.3,169.3 125.2,166.6 139.6,168.2 134.0,164.2 143.7,167.6 146.0,163.3 148.3,167.6 158.0,164.2 152.4,168.2 166.8,166.6 154.7,169.3" fill="#e2c36e" stroke="none"/>`,
    head: `<circle cx="130" cy="84" r="54" fill="#f3cfa6"/>
<path d="M76.5 76 A54 54 0 0 1 183.5 76 Z" fill="#3a2e28"/>
<circle cx="112" cy="30" r="13" fill="#3a2e28" stroke-width="6"/>
<path d="M77 68 Q130 50 183 68 L184 82 Q130 64 76 82 Z" fill="#c9503f"/>
<circle cx="82" cy="76" r="7" fill="#93362b" stroke-width="5"/>`,
    armB: `<path d="M106 146 Q80 144 64 124" fill="none" stroke="#2b2220" stroke-width="24"/>
<path d="M106 146 Q80 144 64 124" fill="none" stroke="#93362b" stroke-width="12"/>`,
    stickB: `<line x1="66" y1="128" x2="36" y2="60" stroke="#2b2220" stroke-width="13"/>
<line x1="66" y1="128" x2="36" y2="60" stroke="#a87a4c" stroke-width="6"/>
<circle cx="34" cy="55" r="10" fill="#c9503f" stroke-width="5"/>`,
    handB: `<circle cx="62" cy="122" r="12" fill="#f3cfa6" stroke-width="5"/>`,
    armF: `<path d="M150 144 Q184 142 202 114" fill="none" stroke="#2b2220" stroke-width="24"/>
<path d="M150 144 Q184 142 202 114" fill="none" stroke="#c9503f" stroke-width="12"/>`,
    stickF: `<line x1="200" y1="120" x2="226" y2="50" stroke="#2b2220" stroke-width="13"/>
<line x1="200" y1="120" x2="226" y2="50" stroke="#a87a4c" stroke-width="6"/>
<circle cx="228" cy="45" r="10" fill="#c9503f" stroke-width="5"/>`,
    handF: `<circle cx="204" cy="108" r="12" fill="#f3cfa6" stroke-width="5"/>`,
    face: `<circle cx="148" cy="112" r="6" fill="#2b2220"/>
<circle cx="170" cy="112" r="6" fill="#2b2220"/>
<circle cx="150" cy="110" r="2" fill="#fff"/>
<circle cx="172" cy="110" r="2" fill="#fff"/>
<ellipse cx="179" cy="124" rx="6" ry="4" fill="#f09a88" opacity="0.6"/>
<path d="M150 128 Q157 138 164 128 Z" fill="#2b2220" stroke="#2b2220" stroke-width="3" stroke-linejoin="round"/>`,
  },
  raw: ['face'],
  bones: [
    { name: 'body', pivot: [128, 236], ch: 'lean' },
    { name: 'drum', parent: 'body', pivot: [146, 196], ty: 'drumY' },
    { name: 'head', parent: 'body', pivot: [130, 138], ch: 'head' },
    { name: 'tails', parent: 'head', pivot: [84, 76], ch: 'tails' },
    { name: 'armB', parent: 'body', pivot: [106, 146], ch: 'armB' },
    { name: 'stickB', parent: 'armB', pivot: [62, 122], ch: 'wristB' },
    { name: 'armF', parent: 'body', pivot: [150, 144], ch: 'armF' },
    { name: 'stickF', parent: 'armF', pivot: [204, 108], ch: 'wristF' },
  ],
  // source order; glow sits on the face; hands over their sticks
  draw: [['tails', 'tails'], ['legs', 'root'], ['torso', 'body'], ['strap', 'body'],
         ['drumBody', 'drum'], ['drumFace', 'drum'], ['glow', 'drum', 'glow'], ['head', 'head'],
         ['armB', 'armB'], ['stickB', 'stickB'], ['handB', 'armB'],
         ['armF', 'armF'], ['stickF', 'stickF'], ['handF', 'armF'], ['face', 'head']],
  // sticks whipping across the head: draw the face under the arms
  order(p, list) {
    if (Math.abs(p.wristB) > 60 || Math.abs(p.wristF) > 60) {
      const f = list.find(([n]) => n === 'face'), rest = list.filter(([n]) => n !== 'face');
      const i = rest.findIndex(([n]) => n === 'head'); rest.splice(i + 1, 0, f); return rest;
    }
    return list;
  },
  points: {
    tipB: ['stickB', 34, 55], tipF: ['stickF', 228, 45], midF: ['stickF', 215, 80],
    face: ['drum', 146, 170], rim: ['drum', 200, 170],
  },
  springs: {
    tails: { k: 190, c: 9, drive: (p, vx, c) => clamp(vx * .03, -14, 30) - p.lean * .8 - p.head * .6 + (p.kick || 0) + (c.idle ? 2 * Math.sin(c.clock / 650) : 0) },
  },
  idle(p, b) { p.sy = 1 + .014 * b; p.head = 1.5 * b; p.armB = 2 * b; p.armF = -2 * b; p.wristB = -1.5 * b; p.wristF = 1.5 * b; },
  attacks: [{
    id: 'boom', label: '🥁 Song hồi trống', dur: 1250,
    tr: {
      y: track([[0, 0], [170, 5, 'out'], [220, 5], [272, 0, 'outExpo'], [398, 2, 'outExpo'], [470, 0, 'out']]),
      sy: track([[0, 1], [170, .9, 'out'], [220, .89], [272, 1.04, 'outExpo'], [340, .98, 'io'], [398, .86, 'outExpo'], [470, 1.05, 'out'], [560, 1, 'io']]),
      lean: track([[0, 0], [170, -6, 'outBack'], [220, -7], [272, -2, 'outExpo'], [340, -5, 'io'], [398, 8, 'outExpo'], [720, 6, 'out'], [1150, 0, 'io']]),
      head: track([[0, 0], [170, -7, 'out'], [220, -7], [272, 2, 'outExpo'], [340, -3], [398, 7, 'outExpo'], [720, 4, 'out'], [1150, 0, 'io']]),
      // back (left) stick: cock up -> whip down onto the face (BOOM 1) -> rebound, rest on it
      armB: track([[0, 0], [170, 26, 'outBack'], [220, 28], [272, -25, 'outExpo'], [340, -20, 'out'], [398, -24, 'outExpo'], [720, -20, 'out'], [1150, 0, 'io']]),
      wristB: track([[0, 0], [170, -14, 'outBack'], [220, -18], [272, 160, 'outExpo'], [340, 142, 'out'], [398, 156, 'outExpo'], [720, 146, 'out'], [1150, 0, 'io']]),
      // front (right) stick: stays cocked through BOOM 1, cocks deeper, whips down (BOOM 2)
      armF: track([[0, 0], [170, -18, 'outBack'], [220, -18], [280, -16, 'out'], [340, -22, 'out'], [398, 32, 'outExpo'], [720, 28, 'out'], [1150, 0, 'io']]),
      wristF: track([[0, 0], [170, 28, 'outBack'], [220, 30], [280, 26, 'out'], [340, 38, 'out'], [398, -167, 'outExpo'], [720, -155, 'out'], [1150, 0, 'io']]),
      drumY: track([[0, 0], [268, 0], [282, 4, 'lin'], [380, 0, 'out'], [394, 0], [408, 6, 'lin'], [520, 0, 'out']]),
      glow: track([[0, 0], [266, 0], [274, .95, 'lin'], [360, 0, 'out'], [392, 0], [400, 1, 'lin'], [520, 0, 'out']]),
      kick: track([[0, 0], [266, 0], [280, 22, 'out'], [380, 0, 'io'], [396, 0], [410, 30, 'out'], [560, 0, 'io']]),
    },
    ev: [
      [160, a => { a.gleam('tipB'); a.gleam('tipF'); }],
      [268, a => { boom(a, 'tipB', false); soundRing(a, { R0: 30, R1: 70, hit: Object.assign({}, HIT_SMALL, { dmg: 12 }) }); }],
      [396, a => { boom(a, 'tipF', true); soundRing(a, { R0: 38, R1: 92, scale: 1, hit: Object.assign({}, HIT, { dmg: 26 }) }); }],
    ],
    // drum face flash: short bronze impact lines either side of the face while glow > 0
    draw(ctx, cam, api, layer) {
      const g = api.pose.glow || 0;
      if (layer !== 'front' || g <= .02) return;
      const f = api.point('face'), r0 = 64 + (1 - g) * 22, r1 = r0 + 26 * g;
      ctx.setTransform(cam); ctx.lineCap = 'round'; ctx.globalAlpha = Math.min(1, g * 1.4);
      for (const a of [-172, -150, -30, -8]) {
        const c = Math.cos(a / 57.3), s2 = Math.sin(a / 57.3) * .55;
        ctx.beginPath(); ctx.moveTo(f.x + c * r0, f.y - 6 + s2 * r0); ctx.lineTo(f.x + c * r1, f.y - 6 + s2 * r1);
        ctx.strokeStyle = INK; ctx.lineWidth = 10; ctx.stroke(); ctx.strokeStyle = BRONZE; ctx.lineWidth = 5; ctx.stroke();
      }
      ctx.globalAlpha = 1;
    },
    smear: { tip: 'tipF', base: 'midF', from: 352, to: 440, window: 36, fill: PALE, inner: BRONZE },
  }],
};
