// Nỏ thủ (archer_p.svg) · "Nỏ thần liên châu": aim -> 3-bolt volley -> recoil -> reload hint. range 2.

// shared impact: same for all units (game-wide hit feel)
const HIT = { stop: 90, amp: 9, kx: 420, debris: 'spark', n: 8, sparkColor: '#ffe08a', cut: true, cutAng: -24 };
const HIT_SMALL = { small: true, stop: 45, amp: 4, kx: 0, debris: 'spark', n: 3, sparkColor: '#ffe08a', cut: false };

const SHOTS = [300, 400, 500];                 // volley release times (ms)
// string cocked + bolt seated (1) vs string snapped forward, no bolt (0); nỏ thần re-seats between shots
const COCK = [[0, 1], [300, 1], [301, 0, 'lin'], [350, 0], [351, 1, 'lin'], [400, 1], [401, 0, 'lin'], [450, 0], [451, 1, 'lin'],
              [500, 1], [501, 0, 'lin'], [1040, 0], [1041, 1, 'lin']];

// bowstring "twang": short white speed lines flaring off the muzzle
const twang = api => {
  const fx = { age: 0, life: 110,
    upd(s, ms) { this.age += ms; return this.age < this.life; },
    draw(ctx, cam, layer) {
      if (layer !== 'front') return;
      const m = api.point('muzzle'), u = this.age / this.life, r0 = 10 + 26 * E.out(u), r1 = r0 + 22 * (1 - u);
      ctx.setTransform(cam.translate(m.x, m.y)); ctx.lineCap = 'round'; ctx.globalAlpha = 1 - u * u;
      for (const a of [-.75, 0, .75]) {
        ctx.beginPath(); ctx.moveTo(Math.cos(a) * r0, Math.sin(a) * r0); ctx.lineTo(Math.cos(a) * r1, Math.sin(a) * r1);
        ctx.strokeStyle = INK; ctx.lineWidth = 9; ctx.stroke(); ctx.strokeStyle = '#fff6d6'; ctx.lineWidth = 4; ctx.stroke();
      }
      ctx.globalAlpha = 1;
    } };
  api.add(fx);
};
const bolt = (api, i) => {
  const tg = api.target(), last = i === SHOTS.length - 1;
  api.projectile({ point: 'muzzle', to: { x: tg.x - 8, y: tg.y + [-16, 6, -4][i] }, kind: 'arrow', size: .95, arc: 14, speed: 2500,
    color: '#c9503f', trail: '#fff6d6',
    hit: last ? Object.assign({}, HIT, { dmg: 36 }) : Object.assign({}, HIT_SMALL, { dmg: 8 }) });
  twang(api);
};

const SPEC = {
  title: 'Nỏ thủ · Nỏ thần liên châu',
  subtitle: 'aim → 3-bolt volley → recoil → reload (range 2)',
  feet: 244, cx: 128, range: 2,
  parts: {
    quiver: `<path d="M52 120 L40 84" stroke-width="5"/>
<path d="M64 116 L58 78" stroke-width="5"/>
<path d="M76 112 L76 76" stroke-width="5"/>
<path d="M40 84 L30 72 L46 76 Z" fill="#c9503f" stroke-width="4"/>
<path d="M58 78 L52 64 L66 70 Z" fill="#c9503f" stroke-width="4"/>
<path d="M76 76 L72 62 L84 68 Z" fill="#c9503f" stroke-width="4"/>
<path d="M40 128 L80 112 L108 182 L80 198 Z" fill="#5a4a3c"/>
<path d="M46 142 L84 126" stroke="#e2c36e" stroke-width="5"/>
<circle cx="80" cy="162" r="8" fill="#e2c36e" stroke-width="4"/>`,
    legB: `<rect x="104" y="196" width="20" height="40" rx="4" fill="#5a4a3c"/>
<rect x="98" y="228" width="30" height="18" rx="8" fill="#3a2e28"/>`,
    legF: `<rect x="134" y="196" width="20" height="40" rx="4" fill="#5a4a3c"/>
<rect x="130" y="228" width="32" height="18" rx="8" fill="#3a2e28"/>`,
    torso: `<path d="M100 128 Q128 118 156 128 L166 204 Q128 214 90 204 Z" fill="#c9503f"/>
<path d="M94 196 Q128 206 163 196" fill="none" stroke="#93362b" stroke-width="5"/>
<path d="M150 130 L100 194" stroke="#3a2e28" stroke-width="8"/>
<path d="M95 182 L161 182" stroke="#5a4a3c" stroke-width="10"/>
<circle cx="140" cy="182" r="6" fill="#e2c36e" stroke-width="4"/>`,
    tails: `<path d="M84 96 Q60 104 50 128 L62 132 Q68 114 88 104 Z" fill="#c9503f" stroke-width="5"/>
<path d="M84 102 Q70 118 70 140 L80 140 Q80 120 90 108 Z" fill="#93362b" stroke-width="5"/>`,
    head: `<circle cx="130" cy="84" r="54" fill="#f3cfa6"/>
<path d="M76 92 A54 54 0 0 1 184 84 Q132 70 80 104 Z" fill="#c9503f"/>
<path d="M88 84 Q132 60 176 72" fill="none" stroke="#93362b" stroke-width="5"/>
<circle cx="84" cy="98" r="9" fill="#c9503f" stroke-width="5"/>`,
    arm: `<path d="M152 144 Q174 158 194 166" fill="none" stroke="#2b2220" stroke-width="24"/>
<path d="M152 144 Q174 158 194 166" fill="none" stroke="#c9503f" stroke-width="12"/>`,
    bow: `<path d="M206 116 Q230 152 206 190" fill="none" stroke="#2b2220" stroke-width="16"/>
<path d="M206 116 Q230 152 206 190" fill="none" stroke="#a87a4c" stroke-width="8"/>
<circle cx="206" cy="116" r="5" fill="#e2c36e" stroke-width="4"/>
<circle cx="206" cy="190" r="5" fill="#e2c36e" stroke-width="4"/>`,
    stock: `<path d="M112 148 L228 148 L228 162 L152 164 Q138 180 114 170 Z" fill="#a87a4c"/>
<path d="M122 156 L222 156" stroke="#5a4a3c" stroke-width="3"/>
<rect x="150" y="160" width="22" height="14" rx="3" fill="#e2c36e" stroke-width="5"/>
<path d="M162 174 L158 188" stroke-width="5"/>`,
    stringC: `<path d="M206 116 L164 148 L206 190" fill="none" stroke-width="4"/>`,
    stringR: `<path d="M206 116 Q209 153 206 190" fill="none" stroke-width="4"/>`,
    bolt: `<path d="M168 140 L230 140" stroke-width="9"/>
<path d="M168 140 L230 140" stroke="#e2c36e" stroke-width="3"/>
<path d="M230 133 L246 140 L230 147 Z" fill="#cdd4da" stroke-width="4"/>
<path d="M176 140 L163 131 L167 140 L163 149 Z" fill="#c9503f" stroke-width="4"/>`,
    handF: `<circle cx="198" cy="168" r="12" fill="#f3cfa6" stroke-width="5"/>`,
    handB: `<circle cx="138" cy="172" r="11" fill="#f3cfa6" stroke-width="5"/>`,
    face: `<path d="M141 100 L154 104 M164 104 L177 100" stroke="#2b2220" stroke-width="4" stroke-linecap="round"/>
<circle cx="148" cy="112" r="6" fill="#2b2220"/>
<circle cx="170" cy="112" r="6" fill="#2b2220"/>
<circle cx="150" cy="110" r="2" fill="#fff"/>
<circle cx="172" cy="110" r="2" fill="#fff"/>
<ellipse cx="179" cy="124" rx="6" ry="4" fill="#f09a88" opacity="0.6"/>
<path d="M150 130 Q156 134 162 131" fill="none" stroke="#2b2220" stroke-width="3" stroke-linecap="round"/>`,
  },
  raw: ['face'],
  bones: [
    { name: 'body', pivot: [128, 200], ch: 'lean' },
    { name: 'head', parent: 'body', pivot: [130, 140], ch: 'head' },
    { name: 'tails', parent: 'head', pivot: [86, 100], ch: 'tails' },
    { name: 'quiver', parent: 'body', pivot: [84, 122], ch: 'quiv' },
    // crossbow: own bone at the shoulder/cheek; arm + hands ride on it. kick = recoil slide, raise = lift to the eye
    { name: 'xbow', parent: 'body', pivot: [150, 146], ch: 'aim', tx: 'kick', ty: 'raise' },
    { name: 'handB', parent: 'xbow', pivot: [138, 172], tx: 'pull' },
    { name: 'legB', pivot: [114, 198], ch: 'legB' },
    { name: 'legF', pivot: [144, 198], ch: 'legF' },
  ],
  // source order; face drawn last as in the SVG
  draw: [['quiver', 'quiver'], ['legB', 'legB'], ['legF', 'legF'], ['torso', 'body'], ['tails', 'tails'], ['head', 'head'],
         ['arm', 'xbow'], ['bow', 'xbow'], ['stock', 'xbow'], ['stringC', 'xbow', 'cock'], ['stringR', 'xbow', 'rel'],
         ['bolt', 'xbow', 'cock'], ['handF', 'xbow'], ['handB', 'handB'], ['face', 'head']],
  // stock raised to the cheek -> crossbow + arm in front of the face
  order(p, list) {
    if (p.raise >= -1) return list;
    const f = list.find(([n]) => n === 'face'), rest = list.filter(([n]) => n !== 'face'), i = rest.findIndex(([n]) => n === 'head');
    return [...rest.slice(0, i + 1), f, ...rest.slice(i + 1)];
  },
  points: { muzzle: ['xbow', 246, 140], nut: ['xbow', 166, 146], mid: ['xbow', 206, 140] },
  springs: {
    tails: { k: 190, c: 9, drive: (p, vx, c) => clamp(vx * .03, -14, 30) + p.lean * .6 + p.head * .5 + (p.kick || 0) * -1.2 + (c.idle ? 3 * Math.sin(c.clock / 650) : 0) },
    quiv: { k: 260, c: 10, drive: (p, vx, c) => clamp(vx * .02, -8, 12) + p.lean * .4 + (p.kick || 0) * -.5 + (c.idle ? .8 * Math.sin(c.clock / 800) : 0) },
  },
  idle(p, b) { p.sy = 1 + .014 * b; p.head = 1.5 * b; p.aim = -1.2 * b; p.raise = -.8 * b; },
  attacks: [
    {
      id: 'volley', label: '🏹 Nỏ thần liên châu', dur: 1450,
      tr: {
        // 0-170 brace + raise · 170-300 aim hold (gleam) · 300/400/500 bolts · 500-760 recoil hold · 860-1060 reload · -1400 recover
        x: track([[0, 0], [170, -4, 'out'], [300, -4], [310, -8, 'outExpo'], [400, -8], [410, -12, 'outExpo'], [500, -12],
                  [516, -22, 'outExpo'], [760, -18, 'out'], [1400, 0, 'io']]),
        sy: track([[0, 1], [160, .9, 'out'], [260, .94], [300, .94], [310, 1.03, 'outExpo'], [370, .96], [410, 1.03, 'outExpo'], [470, .96],
                   [516, 1.07, 'outExpo'], [620, .95, 'out'], [760, 1, 'out'], [960, .97, 'io'], [1060, 1, 'io']]),
        lean: track([[0, 0], [170, -7, 'out'], [300, -5], [516, -12, 'outExpo'], [760, -9, 'out'], [920, 4, 'io'], [1100, 4], [1400, 0, 'io']]),
        head: track([[0, 0], [170, 6, 'out'], [300, 6], [516, -5, 'outExpo'], [760, -2], [920, 10, 'io'], [1100, 10], [1400, 0, 'io']]),
        aim: track([[0, 0], [170, -14, 'outBack'], [260, -6, 'io'], [300, -6], [312, -12, 'outExpo'], [385, -6, 'out'], [400, -6],
                    [412, -12, 'outExpo'], [485, -6, 'out'], [500, -6], [516, -16, 'outExpo'], [700, -11, 'out'],
                    [900, 18, 'io'], [1100, 18], [1180, 12, 'outBack'], [1400, 0, 'io']]),
        raise: track([[0, 0], [170, -10, 'outBack'], [260, -7], [500, -7], [516, -3, 'outExpo'], [700, -5], [900, 4, 'io'], [1100, 4], [1400, 0, 'io']]),
        kick: track([[0, 0], [300, 0], [312, -9, 'outExpo'], [385, 0, 'out'], [400, 0], [412, -9, 'outExpo'], [485, 0, 'out'], [500, 0],
                     [516, -16, 'outExpo'], [700, -7, 'out'], [1000, 0, 'io']]),
        pull: track([[0, 0], [880, 0], [980, -18, 'io'], [1040, -18], [1060, 0, 'outExpo']]),
        cock: track(COCK),
        rel: track(COCK.map(([t, v, e]) => (e ? [t, 1 - v, e] : [t, 1 - v]))),
        legF: track([[0, 0], [170, -9, 'out'], [760, -9], [1400, 0, 'io']]),
        legB: track([[0, 0], [170, 6, 'out'], [760, 6], [1400, 0, 'io']]),
      },
      ev: [
        [150, a => a.dust(96, 244, 4, -1)],
        [210, a => a.gleam('muzzle', 160)],
        [SHOTS[0], a => bolt(a, 0)],
        [SHOTS[1], a => bolt(a, 1)],
        [SHOTS[2], a => { bolt(a, 2); a.dust(100, 244, 6, -1); a.shake(3, 120); }],
        [1042, a => a.gleam('nut', 120)],
      ],
    },
  ],
};
