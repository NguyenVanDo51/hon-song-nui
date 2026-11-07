// Cung Thủ (archer_p.svg) · "Phát tên cung dài": brace -> draw longbow to the chin -> hold -> loose -> recoil. range 1-2.

// shared impact: same for all units (game-wide hit feel)
const HIT = { stop: 90, amp: 9, kx: 420, debris: 'spark', n: 8, sparkColor: '#ffe08a', cut: true, cutAng: -24 };
const HIT_SMALL = { small: true, stop: 45, amp: 4, kx: 0, debris: 'spark', n: 3, sparkColor: '#ffe08a', cut: false };

const LOOSE = 580;                 // release time (ms)
const STR_L = 111;                 // half string length: tip (196,18|240) -> nock (196,129)
// nock offset along the bow frame x (string pulled back = negative); string snaps forward + quivers after the loose
const STR = track([[0, 0], [140, 0], [420, -40, 'io'], [LOOSE, -42, 'lin'], [LOOSE + 12, 5, 'outExpo'], [LOOSE + 45, -3, 'out'],
                   [LOOSE + 85, 1.5, 'io'], [LOOSE + 140, 0, 'io']]);
// string half = bone at its bow tip, rotated + stretched so its end sits on the nock
const strAng = p => Math.atan(-p / STR_L) * 180 / Math.PI;
const strSc = p => Math.hypot(p, STR_L) / STR_L - 1;

// bowstring "twang": short white speed lines flaring off the bow grip
const twang = api => {
  const fx = { age: 0, life: 110,
    upd(s, ms) { this.age += ms; return this.age < this.life; },
    draw(ctx, cam, layer) {
      if (layer !== 'front') return;
      const m = api.point('grip'), u = this.age / this.life, r0 = 10 + 26 * E.out(u), r1 = r0 + 22 * (1 - u);
      ctx.setTransform(cam.translate(m.x, m.y)); ctx.lineCap = 'round'; ctx.globalAlpha = 1 - u * u;
      for (const a of [-.75, 0, .75]) {
        ctx.beginPath(); ctx.moveTo(Math.cos(a) * r0, Math.sin(a) * r0); ctx.lineTo(Math.cos(a) * r1, Math.sin(a) * r1);
        ctx.strokeStyle = INK; ctx.lineWidth = 9; ctx.stroke(); ctx.strokeStyle = '#fff6d6'; ctx.lineWidth = 4; ctx.stroke();
      }
      ctx.globalAlpha = 1;
    } };
  api.add(fx);
};
const loose = api => {
  const tg = api.target();
  api.projectile({ point: 'atip', to: { x: tg.x - 8, y: tg.y - 6 }, kind: 'arrow', size: 1, arc: 18, speed: 2300,
    color: '#c9503f', trail: '#fff6d6', hit: Object.assign({}, HIT, { dmg: 40 }) });
  twang(api);
};

const SPEC = {
  title: 'Cung Thủ · Phát tên cung dài',
  subtitle: 'trụ chân → kéo cung dài tới cằm → giữ → buông tên → giật lùi (tầm 1–2)',
  feet: 244, cx: 128, range: 2,
  parts: {
    cape: `<path d="M106 124 Q72 158 62 224 Q88 216 112 222 Q114 172 130 128 Z" fill="#93362b"/>`,
    quiver: `<path d="M52 120 L40 84" stroke-width="5"/>
<path d="M64 116 L58 78" stroke-width="5"/>
<path d="M76 112 L76 76" stroke-width="5"/>
<path d="M40 84 L30 72 L46 76 Z" fill="#c9503f" stroke-width="4"/>
<path d="M58 78 L52 64 L66 70 Z" fill="#c9503f" stroke-width="4"/>
<path d="M76 76 L72 62 L84 68 Z" fill="#c9503f" stroke-width="4"/>
<path d="M40 128 L80 112 L108 182 L80 198 Z" fill="#a87a4c"/>
<path d="M46 142 L84 126" stroke="#5a4a3c" stroke-width="6"/>
<path d="M66 186 L100 172" stroke="#5a4a3c" stroke-width="6"/>`,
    legB: `<rect x="104" y="196" width="20" height="40" rx="4" fill="#5a4a3c"/>
<rect x="98" y="228" width="30" height="18" rx="8" fill="#3a2e28"/>`,
    legF: `<rect x="134" y="196" width="20" height="40" rx="4" fill="#5a4a3c"/>
<rect x="130" y="228" width="32" height="18" rx="8" fill="#3a2e28"/>`,
    torso: `<path d="M100 128 Q128 118 156 128 L166 204 Q128 214 90 204 Z" fill="#5a4a3c"/>
<path d="M128 150 L128 182" stroke="#3a2e28" stroke-width="4"/>
<path d="M152 132 L104 196" stroke-width="13"/>
<path d="M152 132 L104 196" stroke="#a87a4c" stroke-width="6"/>
<path d="M95 186 L161 186" stroke="#3a2e28" stroke-width="10"/>
<circle cx="142" cy="187" r="6" fill="#e2c36e" stroke-width="4"/>`,
    mantle: `<path d="M94 132 Q128 112 162 132 L168 152 Q148 160 128 156 Q108 160 88 152 Z" fill="#c9503f"/>
<path d="M92 149 Q110 156 128 153 Q146 156 165 149" fill="none" stroke="#e2c36e" stroke-width="3.5"/>`,
    tails: `<path d="M92 50 Q60 36 34 54 Q62 58 82 76 Z" fill="#c9503f" stroke-width="5"/>
<path d="M86 54 Q66 48 50 54" fill="none" stroke="#93362b" stroke-width="4"/>`,
    head: `<path d="M72 114 Q56 44 112 24 Q150 14 172 32 Q190 52 186 94 Z" fill="#93362b"/>
<circle cx="130" cy="84" r="54" fill="#f3cfa6"/>
<path d="M76 100 Q70 38 130 28 Q186 34 186 96 Q168 66 132 64 Q98 66 76 100 Z" fill="#c9503f"/>
<path d="M82 92 Q102 70 132 68 Q162 68 180 88" fill="none" stroke="#e2c36e" stroke-width="3.5"/>`,
    arm: `<path d="M152 142 Q184 146 214 134" fill="none" stroke="#2b2220" stroke-width="24"/>
<path d="M152 142 Q184 146 214 134" fill="none" stroke="#c9503f" stroke-width="12"/>`,
    bow: `<path d="M196 18 C228 58 228 200 196 240" fill="none" stroke="#2b2220" stroke-width="15"/>
<path d="M196 18 C228 58 228 200 196 240" fill="none" stroke="#a87a4c" stroke-width="7"/>
<circle cx="196" cy="18" r="5" fill="#e2c36e" stroke-width="4"/>
<circle cx="196" cy="240" r="5" fill="#e2c36e" stroke-width="4"/>`,
    strT: `<path d="M196 18 L196 129" fill="none" stroke-width="3.5"/>`,
    strB: `<path d="M196 240 L196 129" fill="none" stroke-width="3.5"/>`,
    handF: `<circle cx="220" cy="132" r="12" fill="#f3cfa6" stroke-width="5"/>`,
    arrow: `<path d="M194 129 L240 129" stroke-width="8"/>
<path d="M194 129 L240 129" stroke="#a87a4c" stroke-width="3"/>
<path d="M238 122 L253 129 L238 136 Z" fill="#cdd4da" stroke-width="4"/>
<path d="M214 129 L203 121 L206 129 L203 137 Z" fill="#c9503f" stroke-width="4"/>`,
    handB: `<circle cx="192" cy="133" r="11" fill="#f3cfa6" stroke-width="5"/>`,
    face: `<path d="M140 101 L155 106 M163 106 L178 101" stroke="#2b2220" stroke-width="4.5" stroke-linecap="round"/>
<circle cx="148" cy="114" r="6" fill="#2b2220"/>
<circle cx="170" cy="114" r="6" fill="#2b2220"/>
<circle cx="150" cy="112" r="2" fill="#fff"/>
<circle cx="172" cy="112" r="2" fill="#fff"/>
<ellipse cx="179" cy="126" rx="6" ry="4" fill="#f09a88" opacity="0.6"/>
<path d="M151 132 Q157 135 163 132" fill="none" stroke="#2b2220" stroke-width="3" stroke-linecap="round"/>`,
  },
  raw: ['face'],
  bones: [
    { name: 'body', pivot: [128, 200], ch: 'lean' },
    { name: 'cape', parent: 'body', pivot: [112, 128], ch: 'cape' },
    { name: 'head', parent: 'body', pivot: [130, 140], ch: 'head' },
    { name: 'tails', parent: 'head', pivot: [86, 62], ch: 'tails' },
    { name: 'quiver', parent: 'body', pivot: [84, 122], ch: 'quiv' },
    // longbow arm: bow + string + both hands ride on it (aim = tilt up at the shoulder)
    { name: 'bow', parent: 'body', pivot: [152, 142], ch: 'aim' },
    { name: 'strT', parent: 'bow', pivot: [196, 18], ch: 'sT', sc: 'sS' },
    { name: 'strB', parent: 'bow', pivot: [196, 240], ch: 'sB', sc: 'sS' },
    // string hand + nocked arrow slide back along the bow frame; after the loose the hand keeps flying back
    { name: 'handB', parent: 'bow', pivot: [196, 129], tx: 'hand' },
    { name: 'legB', pivot: [114, 198], ch: 'legB' },
    { name: 'legF', pivot: [144, 198], ch: 'legF' },
  ],
  draw: [['cape', 'cape'], ['quiver', 'quiver'], ['legB', 'legB'], ['legF', 'legF'], ['torso', 'body'], ['mantle', 'body'],
         ['tails', 'tails'], ['head', 'head'], ['arm', 'bow'], ['bow', 'bow'], ['strT', 'strT'], ['strB', 'strB'],
         ['handF', 'bow'], ['arrow', 'handB', 'nock'], ['handB', 'handB'], ['face', 'head']],
  // string hand at the chin: string, hand + arrow over the face
  order(p, list) {
    if (p.hand >= -18) return list;
    const f = list.find(([n]) => n === 'face'), rest = list.filter(([n]) => n !== 'face'), i = rest.findIndex(([n]) => n === 'head');
    return [...rest.slice(0, i + 1), f, ...rest.slice(i + 1)];
  },
  points: { atip: ['handB', 253, 129], nock: ['handB', 196, 129], grip: ['bow', 230, 129] },
  springs: {
    tails: { k: 190, c: 9, drive: (p, vx, c) => clamp(vx * .03, -14, 30) + p.lean * .6 + p.head * .5 + (c.idle ? 3 * Math.sin(c.clock / 650) : 0) },
    cape: { k: 160, c: 9, drive: (p, vx, c) => clamp(vx * .04, -10, 24) + p.lean * .5 + (c.idle ? 1.5 * Math.sin(c.clock / 720) : 0) },
    quiv: { k: 260, c: 10, drive: (p, vx, c) => clamp(vx * .02, -8, 12) + p.lean * .4 + (c.idle ? .8 * Math.sin(c.clock / 800) : 0) },
  },
  idle(p, b) { p.sy = 1 + .014 * b; p.head = 1.5 * b; p.aim = -1.2 * b; },
  attacks: [
    {
      id: 'loose', label: '🏹 Phát tên cung dài', dur: 1400,
      tr: {
        // 0-140 brace · 140-420 draw to the chin · 420-580 hold (gleam) · 580 loose · 580-820 recoil · 820-1300 recover + re-nock
        x: track([[0, 0], [140, 2, 'out'], [420, -4, 'io'], [LOOSE, -4], [LOOSE + 20, -14, 'outExpo'], [850, -10, 'out'], [1300, 0, 'io']]),
        sy: track([[0, 1], [140, .93, 'out'], [420, .97, 'io'], [LOOSE, .97], [LOOSE + 20, 1.05, 'outExpo'], [720, .97, 'out'], [880, 1, 'io']]),
        lean: track([[0, 0], [140, 3, 'out'], [420, -4, 'io'], [LOOSE, -4], [LOOSE + 20, -10, 'outExpo'], [840, -6, 'out'], [1300, 0, 'io']]),
        head: track([[0, 0], [140, 2, 'out'], [420, -4, 'io'], [LOOSE, -4], [LOOSE + 20, -8, 'outExpo'], [900, -3, 'out'], [1300, 0, 'io']]),
        aim: track([[0, 0], [140, -3, 'out'], [420, -8, 'io'], [LOOSE, -8], [LOOSE + 20, -16, 'outExpo'], [800, -11, 'out'], [1300, 0, 'io']]),
        str: STR,
        sT: t => strAng(STR(t)),
        sB: t => -strAng(STR(t)),
        sS: t => strSc(STR(t)),
        hand: track([[0, 0], [140, 0], [420, -40, 'io'], [LOOSE, -42, 'lin'], [LOOSE + 20, -60, 'outExpo'], [840, -54, 'out'], [1180, 0, 'io']]),
        nock: track([[0, 1], [LOOSE, 1], [LOOSE + 1, 0, 'lin'], [1120, 0], [1121, 1, 'lin']]),
        legF: track([[0, 0], [140, -9, 'out'], [840, -9], [1300, 0, 'io']]),
        legB: track([[0, 0], [140, 6, 'out'], [840, 6], [1300, 0, 'io']]),
      },
      ev: [
        [120, a => a.dust(96, 244, 4, -1)],
        [470, a => a.gleam('atip', 150)],
        [LOOSE, a => { loose(a); a.dust(100, 244, 6, -1); a.shake(3, 120); }],
      ],
    },
  ],
};
