// shared impact: same for all units (game-wide hit feel)
const HIT = { stop: 90, amp: 9, kx: 420, debris: 'spark', n: 8, sparkColor: '#ffe08a', cut: true, cutAng: -24 };
const HIT_SMALL = { small: true, stop: 45, amp: 4, kx: 0, debris: 'spark', n: 3, sparkColor: '#ffe08a', cut: false };
// main hit:   api.hit(Object.assign({}, HIT, { dmg: 42 }))     or  wave/projectile/tornado { hit: Object.assign({}, HIT, { dmg: 42 }) }
// multi-tick: Object.assign({}, HIT_SMALL, { dmg: 6 }) for the small ticks before the final HIT

// Tu Sĩ Ánh Sáng: raise the lantern high -> holy light ring bursts out -> step in + mace bonk (THE hit).
const GOLD = '#e2c36e', PALE = '#fff6d6';
const BURST = 300, BONK = 545;      // light burst / mace contact (ms)

// holy light burst: one warm ring + short rays expanding from the lantern (no damage)
function holyBurst(api) {
  const c = api.point('lamp'), st = { age: 0 }, LIFE = 440;
  return api.add({
    upd(s, ms) { st.age += ms; return st.age < LIFE; },
    draw(ctx, cam, layer) {
      if (layer !== 'front') return;
      const u = st.age / LIFE, r = 24 + 150 * E.out(u), r0 = r + 8, r1 = r0 + 8 + 26 * (1 - u);
      ctx.setTransform(cam); ctx.lineCap = 'round'; ctx.globalAlpha = 1 - u * u;
      ctx.beginPath(); ctx.arc(c.x, c.y, r, 0, Math.PI * 2);
      ctx.strokeStyle = INK; ctx.lineWidth = 11; ctx.stroke();
      ctx.strokeStyle = PALE; ctx.lineWidth = 6; ctx.stroke();
      ctx.strokeStyle = GOLD; ctx.lineWidth = 2.5; ctx.stroke();
      for (let k = 0; k < 10; k++) {
        const a = k * Math.PI / 5 + .3, cs = Math.cos(a), sn = Math.sin(a);
        ctx.beginPath(); ctx.moveTo(c.x + cs * r0, c.y + sn * r0); ctx.lineTo(c.x + cs * r1, c.y + sn * r1);
        ctx.strokeStyle = INK; ctx.lineWidth = 8; ctx.stroke(); ctx.strokeStyle = PALE; ctx.lineWidth = 4; ctx.stroke();
      }
      ctx.globalAlpha = 1;
    },
  });
}

const SPEC = {
  title: 'Tu Sĩ Ánh Sáng · Đèn thánh, chùy phán xét',
  subtitle: 'Giơ cao đèn lồng — vòng thánh quang bừng sáng — bước tới nện chùy vào địch.',
  feet: 244, cx: 128, range: 1,
  parts: {
    tails: `<path d="M104 134 Q80 160 70 198 L84 202 Q94 168 114 142 Z" fill="#c9503f" stroke-width="5"/>
<path d="M98 150 Q86 170 80 194" fill="none" stroke="#93362b" stroke-width="4"/>`,
    legs: `<rect x="98" y="226" width="30" height="20" rx="8" fill="#5a4a3c"/>
<rect x="132" y="226" width="32" height="20" rx="8" fill="#5a4a3c"/>`,
    torso: `<path d="M100 128 Q128 118 156 128 L174 230 Q128 242 82 230 Z" fill="#f1ece0"/>
<path d="M104 134 Q96 180 88 226 Q100 230 112 232 L114 130 Z" fill="#d8d2c6" stroke="none"/>
<path d="M86 222 Q128 233 170 222" fill="none" stroke="#c9503f" stroke-width="6"/>
<path d="M112 128 L106 212 L120 214 L124 132 Z" fill="#c9503f"/>
<path d="M144 128 L150 212 L136 214 L132 132 Z" fill="#c9503f"/>
<path d="M108 202 L120 204 M148 202 L136 204" stroke="#93362b" stroke-width="4"/>
<path d="M92 188 Q128 198 164 188" fill="none" stroke-width="13"/>
<path d="M92 188 Q128 198 164 188" fill="none" stroke="#a87a4c" stroke-width="6"/>
<circle cx="128" cy="160" r="13" fill="#e2c36e" stroke-width="5"/>`,
    armB: `<path d="M106 146 Q80 140 70 112" fill="none" stroke="#2b2220" stroke-width="26"/>
<path d="M106 146 Q80 140 70 112" fill="none" stroke="#f1ece0" stroke-width="14"/>`,
    head: `<path d="M70 112 Q58 40 120 26 Q170 20 186 60 Q192 84 186 104 Z" fill="#d8d2c6"/>
<circle cx="130" cy="84" r="54" fill="#f3cfa6"/>
<path d="M74 104 Q70 36 130 28 Q190 34 188 100 Q172 70 132 66 Q96 68 74 104 Z" fill="#f1ece0"/>
<path d="M80 96 Q100 72 132 70 Q166 70 184 92" fill="none" stroke="#c9503f" stroke-width="5"/>`,
    lantern: `<path d="M60 124 Q68 102 76 124" fill="none" stroke-width="5"/>
<rect x="56" y="124" width="24" height="32" rx="4" fill="#fff1c4"/>
<path d="M68 132 Q75 142 68 151 Q61 142 68 132 Z" fill="#f5b33a" stroke-width="3"/>
<path d="M54 126 L82 126 L76 116 L60 116 Z" fill="#e2c36e" stroke-width="5"/>
<rect x="53" y="154" width="30" height="8" rx="3" fill="#e2c36e" stroke-width="5"/>`,
    handB: `<circle cx="68" cy="108" r="12" fill="#f3cfa6" stroke-width="5"/>`,
    armF: `<path d="M152 142 Q178 154 200 162" fill="none" stroke="#2b2220" stroke-width="26"/>
<path d="M152 142 Q178 154 200 162" fill="none" stroke="#f1ece0" stroke-width="14"/>`,
    mace: `<line x1="206" y1="186" x2="206" y2="120" stroke="#2b2220" stroke-width="13"/>
<line x1="206" y1="186" x2="206" y2="120" stroke="#a87a4c" stroke-width="6"/>
<circle cx="206" cy="87" r="5" fill="#aab3bd" stroke-width="4"/>
<circle cx="189" cy="104" r="5" fill="#aab3bd" stroke-width="4"/>
<circle cx="223" cy="104" r="5" fill="#aab3bd" stroke-width="4"/>
<circle cx="206" cy="104" r="15" fill="#cdd4da"/>
<path d="M199 97 Q203 93 208 94" fill="none" stroke="#f4f6f8" stroke-width="3.5"/>
<rect x="198" y="120" width="16" height="7" rx="2" fill="#e2c36e" stroke-width="4"/>`,
    handF: `<circle cx="204" cy="164" r="12" fill="#f3cfa6" stroke-width="5"/>`,
    face: `<path d="M143 104 Q150 100 156 104 M164 104 Q171 100 177 104" fill="none" stroke="#2b2220" stroke-width="3.5" stroke-linecap="round"/>
<circle cx="148" cy="114" r="6" fill="#2b2220"/>
<circle cx="170" cy="114" r="6" fill="#2b2220"/>
<circle cx="150" cy="112" r="2" fill="#fff"/>
<circle cx="172" cy="112" r="2" fill="#fff"/>
<ellipse cx="179" cy="126" rx="6" ry="4" fill="#f09a88" opacity="0.6"/>
<path d="M151 131 Q158 136 165 131" fill="none" stroke="#2b2220" stroke-width="3" stroke-linecap="round"/>`,
  },
  raw: ['face'],
  bones: [
    { name: 'body', pivot: [128, 236], ch: 'lean' },
    { name: 'head', parent: 'body', pivot: [130, 138], ch: 'head' },
    { name: 'tails', parent: 'body', pivot: [108, 138], ch: 'tails' },
    // lantern arm: lift slides it up behind the head, lantern hangs from the hand (pendulum spring)
    { name: 'armB', parent: 'body', pivot: [106, 146], ch: 'armB', ty: 'liftB' },
    { name: 'lamp', parent: 'armB', pivot: [68, 108], ch: 'lamp' },
    { name: 'armF', parent: 'body', pivot: [152, 142], ch: 'armF' },
    { name: 'mace', parent: 'armF', pivot: [204, 164], ch: 'wristF' },
  ],
  draw: [['tails', 'tails'], ['legs', 'root'], ['torso', 'body'], ['armB', 'armB'], ['head', 'head'],
         ['lantern', 'lamp'], ['handB', 'armB'], ['armF', 'armF'], ['mace', 'mace'], ['handF', 'armF'], ['face', 'head']],
  // mace cocked over the head: draw the face under the arm
  order(p, list) {
    if (p.armF < -40) {
      const f = list.find(([n]) => n === 'face'), rest = list.filter(([n]) => n !== 'face');
      const i = rest.findIndex(([n]) => n === 'head'); rest.splice(i + 1, 0, f); return rest;
    }
    return list;
  },
  points: {
    lamp: ['lamp', 68, 140], maceHead: ['mace', 206, 104], maceMid: ['mace', 206, 146],
  },
  springs: {
    tails: { k: 190, c: 9, drive: (p, vx, c) => clamp(vx * .03, -14, 30) - p.lean * .8 + (c.idle ? 2 * Math.sin(c.clock / 650) : 0) },
    // hangs plumb (cancels arm + body tilt) and trails the motion
    lamp: { k: 140, c: 6, drive: (p, vx, c) => -(p.armB + p.lean) + clamp(vx * .04, -20, 20) + (c.idle ? 2.5 * Math.sin(c.clock / 700) : 0) },
  },
  idle(p, b) { p.sy = 1 + .014 * b; p.head = 1.5 * b; p.armB = 2 * b; p.armF = -2 * b; p.wristF = 1.5 * b; },
  attacks: [{
    id: 'bonk', label: '🏮 Đèn thánh, chùy phán xét', dur: 1250,
    tr: {
      // 0-140 crouch · 140-300 lantern up · 300 light burst · 380-520 mace cocked · 520-580 step in + bonk · -1250 recover
      x: track([[0, 0], [140, -6, 'out'], [380, -6], [520, -10, 'io'], [580, 70, 'outExpo'], [820, 60, 'out'], [1250, 0, 'io']]),
      y: track([[0, 0], [520, 0], [550, -10, 'out'], [580, 0, 'in']]),
      sy: track([[0, 1], [140, .9, 'out'], [300, 1.06, 'outBack'], [420, 1], [500, .92, 'out'], [580, 1.06, 'outExpo'], [700, .97, 'out'], [860, 1, 'io']]),
      lean: track([[0, 0], [140, 4, 'out'], [300, -6, 'outBack'], [500, -8, 'io'], [580, 10, 'outExpo'], [820, 7, 'out'], [1250, 0, 'io']]),
      head: track([[0, 0], [140, 3, 'out'], [300, -6, 'outBack'], [500, -4], [580, 6, 'outExpo'], [820, 4, 'out'], [1250, 0, 'io']]),
      armB: track([[0, 0], [140, -6, 'out'], [300, 35, 'outBack'], [460, 32], [700, 10, 'io'], [1150, 0, 'io']]),
      liftB: track([[0, 0], [140, 4, 'out'], [300, -75, 'outBack'], [460, -72], [700, -30, 'io'], [1150, 0, 'io']]),
      armF: track([[0, 0], [140, 6, 'out'], [380, 6], [500, -80, 'outBack'], [520, -82], [580, 10, 'outExpo'], [820, 4, 'out'], [1250, 0, 'io']]),
      wristF: track([[0, 0], [140, -6, 'out'], [380, -6], [500, 33, 'outBack'], [520, 35], [580, 70, 'outExpo'], [820, 60, 'out'], [1250, 0, 'io']]),
      glow: track([[0, 0], [200, .4, 'in'], [BURST, 1, 'outExpo'], [520, .6, 'out'], [800, 0, 'io']]),
    },
    ev: [
      [120, a => a.dust(110, 244, 4, -1)],
      [BURST, a => { holyBurst(a); const l = a.point('lamp'); a.sparks(l.x, l.y, 8, GOLD); a.flash(PALE, 60); a.shake(3, 120); }],
      [BONK, a => { a.hit(Object.assign({}, HIT, { dmg: 30 })); const m = a.point('maceHead'); a.sparks(m.x, m.y, 6, GOLD); a.dust(150, 244, 6, 1); }],
    ],
    // lantern halo: soft warm discs + 4 short glints around the lantern while glow > 0 (hero-attached)
    draw(ctx, cam, api, layer) {
      const g = api.pose.glow || 0;
      if (layer !== 'front' || g <= .02) return;
      const l = api.point('lamp');
      ctx.setTransform(cam);
      ctx.globalAlpha = .28 * g; ctx.beginPath(); ctx.arc(l.x, l.y, 22 + 14 * g, 0, Math.PI * 2); ctx.fillStyle = PALE; ctx.fill();
      ctx.globalAlpha = .5 * g; ctx.beginPath(); ctx.arc(l.x, l.y, 12 + 8 * g, 0, Math.PI * 2); ctx.fillStyle = PALE; ctx.fill();
      ctx.globalAlpha = Math.min(1, g * 1.4); ctx.lineCap = 'round';
      const r0 = 28 + 6 * g, r1 = r0 + 14 * g;
      for (const a of [-90, 0, 90, 180]) {
        const c = Math.cos(a / 57.3), s2 = Math.sin(a / 57.3);
        ctx.beginPath(); ctx.moveTo(l.x + c * r0, l.y + s2 * r0); ctx.lineTo(l.x + c * r1, l.y + s2 * r1);
        ctx.strokeStyle = INK; ctx.lineWidth = 9; ctx.stroke(); ctx.strokeStyle = GOLD; ctx.lineWidth = 4.5; ctx.stroke();
      }
      ctx.globalAlpha = 1;
    },
    smear: { tip: 'maceHead', base: 'maceMid', from: 515, to: 600, window: 40, fill: PALE, inner: GOLD },
  }],
};
