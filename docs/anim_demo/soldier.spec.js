// shared impact: same for all units (game-wide hit feel)
const HIT = { stop: 90, amp: 9, kx: 420, debris: 'spark', n: 8, sparkColor: '#ffe08a', cut: true, cutAng: -24 };
const HIT_SMALL = { small: true, stop: 45, amp: 4, kx: 0, debris: 'spark', n: 3, sparkColor: '#ffe08a', cut: false };
// main hit:   api.hit(Object.assign({}, HIT, { dmg: 42 }))     or  wave/projectile/tornado { hit: Object.assign({}, HIT, { dmg: 42 }) }
// multi-tick: Object.assign({}, HIT_SMALL, { dmg: 6 }) for the small ticks before the final HIT

// Vệ Binh (footman): kettle helm, mail + team tabard, pennant spear, heater shield. Attack = step-in -> coil -> lunging thrust + piercing lance streak.
const DMG = 50;   // rules.gd soldier atk 50

// armed at thrust start; fires HIT the frame the spear tip crosses the target front, then draws the lance through it
function pierceFx(a) {
  const st = { age: 0, hit: -1, x0: 0, y0: 0 };
  return {
    upd(s, ms) {
      st.age += ms;
      if (st.hit < 0) {
        const tp = a.point('tip');
        if (tp.x >= a.target().front) { st.hit = 0; st.x0 = tp.x; st.y0 = tp.y; a.hit(Object.assign({}, HIT, { dmg: DMG })); }
      } else st.hit += ms;
      return st.age < 900 && st.hit < 300;
    },
    draw(ctx, cam, layer) {
      ctx.setTransform(cam); ctx.lineCap = 'round'; ctx.lineJoin = 'round';
      // speed lines above/below the shaft, behind the hero (mid layer) so they never cross the face
      const pre = st.hit < 0 ? Math.min(1, st.age / 30) : Math.max(0, 1 - st.hit / 140);
      if (layer === 'mid' && pre > 0) {
        const tp = a.point('tip'), hd = a.point('hand');
        ctx.globalAlpha = pre;
        for (const [dy, f0, f1] of [[-26, .05, .7], [24, .15, .8], [-48, .3, .62]]) {
          ctx.beginPath(); ctx.moveTo(lerp(hd.x, tp.x, f0) - 40, lerp(hd.y, tp.y, f0) + dy); ctx.lineTo(lerp(hd.x, tp.x, f1) - 40, lerp(hd.y, tp.y, f1) + dy);
          ctx.strokeStyle = INK; ctx.lineWidth = 9; ctx.stroke(); ctx.strokeStyle = '#fffdf4'; ctx.lineWidth = 4; ctx.stroke();
        }
        ctx.globalAlpha = 1;
      }
      if (layer !== 'front' || st.hit < 0) return;
      // lance: shoots through the target and out the back
      const u = st.hit, grow = E.outExpo(Math.min(1, u / 60)), k = u < 110 ? 1 : Math.max(0, 1 - (u - 110) / 190);
      const xs = st.x0 - 90, xm = st.x0 + 10, xe = st.x0 + 30 + 230 * grow, y = st.y0, w = 24 * k + 2;
      ctx.globalAlpha = Math.min(1, .35 + k);
      ctx.beginPath(); ctx.moveTo(xs, y); ctx.lineTo(xm, y - w / 2); ctx.lineTo(xe, y); ctx.lineTo(xm, y + w / 2); ctx.closePath();
      ctx.fillStyle = '#fffdf4'; ctx.fill(); ctx.strokeStyle = INK; ctx.lineWidth = 5; ctx.stroke();
      ctx.beginPath(); ctx.moveTo(xs + 40, y); ctx.lineTo(xm, y - w * .2); ctx.lineTo(xe - 40, y); ctx.lineTo(xm, y + w * .2); ctx.closePath();
      ctx.fillStyle = '#ffe08a'; ctx.fill();
      // exit ring on the far side of the target
      const T = a.target(), g = E.out(Math.min(1, u / 160)), xr = T.x + 46 + 30 * g;
      ctx.globalAlpha = Math.max(0, 1 - u / 260);
      ctx.beginPath(); ctx.ellipse(xr, y, 8 + 12 * g, 22 + 38 * g, 0, 0, Math.PI * 2);
      ctx.strokeStyle = INK; ctx.lineWidth = 11 * (1 - g) + 4; ctx.stroke(); ctx.strokeStyle = '#fffdf4'; ctx.lineWidth = 6 * (1 - g) + 1.5; ctx.stroke();
      ctx.globalAlpha = 1;
    },
  };
}

const SPEC = {
  title: 'Vệ Binh · Đâm giáo xuyên giáp',
  subtitle: 'Bước lên → thu giáo → đâm thẳng, luồng sáng xuyên qua địch.',
  feet: 244, cx: 128, range: 1,
  parts: {
    legB: `<rect x="104" y="196" width="20" height="40" rx="4" fill="#5a4a3c"/>
<rect x="98" y="228" width="30" height="18" rx="8" fill="#3a2e28"/>`,
    legF: `<rect x="134" y="196" width="20" height="40" rx="4" fill="#5a4a3c"/>
<rect x="130" y="228" width="32" height="18" rx="8" fill="#3a2e28"/>`,
    // mail shirt + team tabard + belt
    torso: `<path d="M100 128 Q128 118 156 128 L166 204 Q128 214 90 204 Z" fill="#aab3bd"/>
<path d="M96 150 Q128 158 160 150 M94 170 Q128 178 162 170" fill="none" stroke="#7e8790" stroke-width="3"/>
<path d="M112 127 L146 127 L150 206 Q128 212 106 206 Z" fill="#c9503f"/>
<path d="M95 188 L161 188" stroke="#5a4a3c" stroke-width="10"/>`,
    spear: `<line x1="198" y1="52" x2="198" y2="240" stroke="#2b2220" stroke-width="15"/>
<line x1="198" y1="52" x2="198" y2="240" stroke="#a87a4c" stroke-width="7"/>`,
    // swallowtail pennant (rigid on the spear: the tassel spring hangs, a flag must not)
    tassel: `<path d="M204 56 L240 64 L226 70 L240 78 L204 82 Z" fill="#c9503f" stroke-width="5"/>`,
    spearHead: `<path d="M198 6 Q213 28 205 50 L191 50 Q183 28 198 6 Z" fill="#eef2f5" stroke-width="5"/>
<path d="M198 16 L198 44" stroke="#aab3bd" stroke-width="4"/>
<rect x="189" y="48" width="18" height="10" rx="3" fill="#e2c36e" stroke-width="5"/>`,
    arm: `<path d="M152 140 Q176 150 196 160" fill="none" stroke="#2b2220" stroke-width="24"/>
<path d="M152 140 Q176 150 196 160" fill="none" stroke="#c9503f" stroke-width="12"/>
<circle cx="198" cy="160" r="12" fill="#f3cfa6" stroke-width="5"/>`,
    // heater shield, gold chevron
    shield: `<path d="M48 138 L118 138 L118 166 Q116 200 83 216 Q50 200 48 166 Z" fill="#c9503f"/>
<path d="M52 158 L83 182 L114 158" fill="none" stroke="#e2c36e" stroke-width="10"/>`,
    // kettle helm + nasal bar
    head: `<circle cx="130" cy="84" r="54" fill="#f3cfa6"/>
<path d="M74 92 A56 56 0 0 1 186 92 L190 100 L70 100 Z" fill="#cdd4da"/>
<path d="M88 74 Q96 56 110 46" fill="none" stroke="#f4f6f8" stroke-width="5"/>
<path d="M72 96 L188 96" stroke="#7e8790" stroke-width="5"/>
<rect x="155" y="92" width="9" height="30" rx="3" fill="#cdd4da" stroke-width="4"/>`,
    face: `<circle cx="148" cy="115" r="6" fill="#2b2220"/>
<circle cx="170" cy="115" r="6" fill="#2b2220"/>
<circle cx="150" cy="113" r="2" fill="#fff"/>
<circle cx="172" cy="113" r="2" fill="#fff"/>
<ellipse cx="179" cy="127" rx="6" ry="4" fill="#f09a88" opacity="0.6"/>
<path d="M152 133 Q158 137 165 133" fill="none" stroke="#2b2220" stroke-width="3" stroke-linecap="round"/>`,
  },
  raw: ['face'],
  bones: [
    { name: 'body', pivot: [128, 200], ch: 'lean' },
    { name: 'shield', parent: 'body', pivot: [104, 142], ch: 'shield' },
    { name: 'head', parent: 'body', pivot: [130, 136], ch: 'head' },
    { name: 'crest', parent: 'head', pivot: [127, 38], ch: 'crest' },
    { name: 'arm', parent: 'body', pivot: [152, 140], ch: 'arm', tx: 'armX' },
    { name: 'spear', parent: 'arm', pivot: [198, 160], ch: 'wrist', tx: 'slide' },   // pivot = fist
    { name: 'tassel', parent: 'spear', pivot: [198, 58], ch: 'tassel' },
    { name: 'legB', pivot: [114, 198], ch: 'legB' },
    { name: 'legF', pivot: [144, 198], ch: 'legF' },
  ],
  // sample order (shield in front of the body, head over the shoulder); `crest` bone kept, no art (kettle helm)
  draw: [['legB', 'legB'], ['legF', 'legF'], ['torso', 'body'],
         ['spear', 'spear'], ['tassel', 'spear'], ['spearHead', 'spear'],
         ['arm', 'arm'], ['shield', 'shield'], ['head', 'head'], ['face', 'head']],
  points: { tip: ['spear', 198, 8], mid: ['spear', 198, 110], hand: ['arm', 198, 160] },
  springs: {
    crest: { k: 230, c: 9, drive: (p, vx, c) => clamp(vx * .035, -14, 30) + p.lean * .7 + p.head * .6 + (c.idle ? 1.8 * Math.sin(c.clock / 700) : 0) },
    // hangs with gravity (cancels spear angle) + trails the thrust
    tassel: { k: 200, c: 8, drive: (p, vx, c) => -(p.lean + p.arm + p.wrist) * .9 + clamp(vx * .03, -12, 40) + (c.idle ? 3 * Math.sin(c.clock / 600) : 0) },
  },
  idle(p, b) { p.sy = 1 + .014 * b; p.head = 1.5 * b; p.arm = 1.5 * b; p.wrist = -1.5 * b; p.shield = -1.5 * b; },
  attacks: [
    {
      // 0-130 step-in · 130-300 coil · 300-345 hold · 345-410 thrust (contact = tip crosses target front) · 410-660 follow-through · 660-760 retract · 760-1100 recover
      id: 'thrust', label: '🗡 Đâm giáo', dur: 1100,
      tr: {
        x: track([[0, 0], [130, 8, 'out'], [300, -20, 'out'], [345, -21], [410, 26, 'outExpo'], [660, 22, 'out'], [760, 4, 'io'], [1100, 0, 'io']]),
        y: track([[0, 0], [65, -6, 'out'], [130, 0, 'in'], [300, 4, 'out'], [345, 4], [385, -6, 'outExpo'], [470, 0, 'in']]),
        sy: track([[0, 1], [130, .97], [300, .88, 'out'], [345, .87], [385, 1.1, 'outExpo'], [470, .96, 'out'], [580, 1, 'out']]),
        lean: track([[0, 0], [130, 3, 'out'], [300, -13, 'out'], [345, -14], [410, 15, 'outExpo'], [660, 12, 'out'], [760, 2, 'io'], [1100, 0, 'io']]),
        head: track([[0, 0], [130, 2], [300, -6, 'out'], [345, -6], [410, 6, 'outExpo'], [660, 4], [1100, 0, 'io']]),
        arm: track([[0, 0], [130, -4], [300, 10, 'out'], [345, 10], [410, -10, 'outExpo'], [660, -8], [760, 0, 'io'], [1100, 0, 'io']]),
        armX: track([[0, 0], [130, 2], [300, -26, 'out'], [345, -27], [410, 18, 'outExpo'], [660, 14, 'out'], [760, -22, 'io'], [1100, 0, 'io']]),
        slide: track([[0, 0], [300, -10, 'out'], [345, -10], [410, 18, 'outExpo'], [660, 14, 'out'], [760, -12, 'io'], [1100, 0, 'io']]),
        wrist: track([[0, 0], [130, 25, 'out'], [300, 66, 'out'], [345, 68], [372, 85, 'outExpo'], [660, 86], [760, 40, 'io'], [1100, 0, 'io']]),
        shield: track([[0, 0], [130, -3], [300, -8, 'out'], [345, -8], [410, 14, 'outExpo'], [660, 10], [1100, 0, 'io']]),
        legF: track([[0, 0], [65, -16, 'out'], [130, -4, 'in'], [300, 8, 'out'], [345, 8], [410, -28, 'outExpo'], [660, -24], [1100, 0, 'io']]),
        legB: track([[0, 0], [130, 3], [300, -4, 'out'], [345, -4], [410, 22, 'outExpo'], [660, 18], [1100, 0, 'io']]),
      },
      ev: [
        [130, a => a.dust(160, 244, 3, 1)],
        [230, a => a.gleam('tip', 115)],
        [345, a => { a.dust(98, 244, 6, -1); a.add(pierceFx(a)); }],
      ],
      smear: { tip: 'tip', base: 'mid', from: 350, to: 440, window: 48, fill: '#fffdf4', inner: '#ffe08a' },
    },
  ],
};
