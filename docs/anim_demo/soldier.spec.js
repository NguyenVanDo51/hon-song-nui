// shared impact: same for all units (game-wide hit feel)
const HIT = { stop: 90, amp: 9, kx: 420, debris: 'spark', n: 8, sparkColor: '#ffe08a', cut: true, cutAng: -24 };
const HIT_SMALL = { small: true, stop: 45, amp: 4, kx: 0, debris: 'spark', n: 3, sparkColor: '#ffe08a', cut: false };
// main hit:   api.hit(Object.assign({}, HIT, { dmg: 42 }))     or  wave/projectile/tornado { hit: Object.assign({}, HIT, { dmg: 42 }) }
// multi-tick: Object.assign({}, HIT_SMALL, { dmg: 6 }) for the small ticks before the final HIT

// Bộ binh (soldier_p.svg): spear + round shield. Attack = step-in -> coil -> lunging thrust + piercing lance streak.
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
  title: 'Bộ binh · Đâm thương xuyên giáp',
  subtitle: 'Bước lên → thu thương → đâm thẳng, luồng sáng xuyên qua địch.',
  feet: 244, cx: 128, range: 1,
  parts: {
    shield: `<circle cx="84" cy="166" r="40" fill="#c9503f"/>
<circle cx="84" cy="166" r="27" fill="none" stroke="#93362b" stroke-width="5"/>
<path d="M84 145 L84 187 M63 166 L105 166" stroke="#93362b" stroke-width="4"/>
<circle cx="84" cy="166" r="10" fill="#e2c36e" stroke-width="5"/>`,
    legB: `<rect x="104" y="196" width="20" height="40" rx="4" fill="#5a4a3c"/>
<rect x="98" y="228" width="30" height="18" rx="8" fill="#3a2e28"/>`,
    legF: `<rect x="134" y="196" width="20" height="40" rx="4" fill="#5a4a3c"/>
<rect x="130" y="228" width="32" height="18" rx="8" fill="#3a2e28"/>`,
    torso: `<path d="M100 128 Q128 118 156 128 L166 204 Q128 214 90 204 Z" fill="#c9503f"/>
<path d="M93 191 Q128 200 163 191" fill="none" stroke="#93362b" stroke-width="6"/>
<path d="M95 172 L161 172" stroke="#5a4a3c" stroke-width="10"/>
<circle cx="128" cy="172" r="6" fill="#e2c36e" stroke-width="4"/>`,
    spear: `<line x1="198" y1="50" x2="198" y2="240" stroke="#2b2220" stroke-width="15"/>
<line x1="198" y1="50" x2="198" y2="240" stroke="#a87a4c" stroke-width="7"/>`,
    tassel: `<path d="M198 58 Q186 70 188 90 Q194 84 198 92 Q202 84 208 90 Q210 70 198 58 Z" fill="#c9503f" stroke-width="5"/>`,
    spearHead: `<path d="M198 6 Q213 28 205 48 L191 48 Q183 28 198 6 Z" fill="#cdd4da" stroke-width="5"/>
<path d="M198 16 L198 42" stroke="#aab3bd" stroke-width="4"/>
<rect x="190" y="46" width="16" height="12" rx="3" fill="#e2c36e" stroke-width="5"/>`,
    crest: `<path d="M138 38 C144 16 128 2 102 6 C114 12 116 24 116 38 Z" fill="#c9503f" stroke-width="5"/>
<path d="M131 30 C131 18 122 11 110 10" fill="none" stroke="#93362b" stroke-width="4"/>`,
    head: `<circle cx="130" cy="84" r="54" fill="#f3cfa6"/>
<path d="M76 86 A54 54 0 0 1 184 86 L192 96 L68 96 Z" fill="#aab3bd"/>
<path d="M88 70 Q94 52 110 42" fill="none" stroke="#cdd4da" stroke-width="5"/>
<path d="M72 90 L188 90" stroke="#7e8790" stroke-width="5"/>
<rect x="119" y="28" width="20" height="10" rx="4" fill="#e2c36e" stroke-width="5"/>`,
    arm: `<path d="M152 140 Q176 150 198 158" fill="none" stroke="#2b2220" stroke-width="24"/>
<path d="M152 140 Q176 150 198 158" fill="none" stroke="#c9503f" stroke-width="12"/>
<circle cx="198" cy="160" r="12" fill="#f3cfa6" stroke-width="5"/>`,
    face: `<path d="M141 104 L154 107 M164 107 L177 104" stroke="#2b2220" stroke-width="4" stroke-linecap="round"/>
<circle cx="148" cy="115" r="6" fill="#2b2220"/>
<circle cx="170" cy="115" r="6" fill="#2b2220"/>
<circle cx="150" cy="113" r="2" fill="#fff"/>
<circle cx="172" cy="113" r="2" fill="#fff"/>
<ellipse cx="179" cy="127" rx="6" ry="4" fill="#f09a88" opacity="0.6"/>
<path d="M151 132 Q158 137 165 132" fill="none" stroke="#2b2220" stroke-width="3" stroke-linecap="round"/>`,
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
  // source order; face last (arm's shoulder cap sits under the mouth)
  draw: [['shield', 'shield'], ['legB', 'legB'], ['legF', 'legF'], ['torso', 'body'],
         ['spear', 'spear'], ['tassel', 'tassel'], ['spearHead', 'spear'],
         ['crest', 'crest'], ['head', 'head'], ['arm', 'arm'], ['face', 'head']],
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
      id: 'thrust', label: '🗡 Đâm thương', dur: 1100,
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
