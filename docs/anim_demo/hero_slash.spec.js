// Worked example: chibi general (hero_p.svg, 256 viewBox, outline group stroke #2b2220 w7).
// Melee sword -> "Chém gió" (wind-blade slash). Second attack shows tornado/ring/lift fx usage.
// Parts = inner markup copied from the source SVG; listed in `raw` = no outline wrapper (face sits outside the <g>).

const TIP = bake(6, 212, 128, 212, 14);   // sword group has transform="rotate(6 212 128)" baked in
const MID = bake(6, 212, 128, 212, 70);

const SPEC = {
  title: 'Trưng Trắc · Chém gió',
  feet: 244, cx: 128,
  parts: {
    cape: `<path d="M108 126 Q64 148 28 236 Q46 226 56 242 Q70 228 86 244 Q98 232 114 240 L138 132 Z" fill="#c9503f"/>
<path d="M104 138 Q76 164 54 228 Q68 220 82 234 Q94 222 108 230" fill="none" stroke="#93362b" stroke-width="5"/>`,
    legB: `<rect x="104" y="196" width="20" height="40" rx="4" fill="#5a4a3c"/>
<rect x="98" y="226" width="30" height="20" rx="8" fill="#3a2e28"/>
<path d="M102 228 L124 228" stroke="#e2c36e" stroke-width="5"/>`,
    legF: `<rect x="134" y="196" width="20" height="40" rx="4" fill="#5a4a3c"/>
<rect x="130" y="226" width="32" height="20" rx="8" fill="#3a2e28"/>
<path d="M134 228 L158 228" stroke="#e2c36e" stroke-width="5"/>`,
    skirt: `<path d="M94 176 L162 176 L168 206 Q128 216 88 206 Z" fill="#c9503f"/>`,
    torso: `<path d="M100 128 Q128 118 156 128 L162 180 Q128 190 94 180 Z" fill="#aab3bd"/>
<path d="M120 140 L120 174" stroke="#7e8790" stroke-width="5"/>
<path d="M96 178 Q128 188 160 178" fill="none" stroke="#e2c36e" stroke-width="8"/>
<circle cx="132" cy="160" r="8" fill="#e2c36e" stroke-width="5"/>`,
    pad: `<ellipse cx="152" cy="146" rx="17" ry="13" fill="#aab3bd" stroke-width="5"/>
<path d="M137 152 Q152 160 168 150" fill="none" stroke="#e2c36e" stroke-width="4"/>`,
    sword: `<g transform="rotate(6 212 128)">
<path d="M204 112 L204 30 L212 12 L220 30 L220 112 Z" fill="#cdd4da" stroke-width="5"/>
<path d="M212 30 L212 108" stroke="#aab3bd" stroke-width="4"/>
<rect x="190" y="108" width="44" height="11" rx="5" fill="#e2c36e" stroke-width="5"/>
<rect x="207" y="118" width="10" height="22" rx="3" fill="#3a2e28" stroke-width="5"/>
<circle cx="212" cy="144" r="7" fill="#e2c36e" stroke-width="5"/>
</g>`,
    plume: `<path d="M138 40 C144 16 130 4 108 4 C86 4 64 16 46 38 C64 32 78 32 88 36 C74 42 64 52 58 66 C78 56 98 52 116 50 Z" fill="#c9503f" stroke-width="6"/>
<path d="M128 32 C126 18 116 12 102 12 M116 40 C102 34 86 34 72 38 M110 48 C96 48 84 52 74 58" fill="none" stroke="#93362b" stroke-width="4"/>`,
    head: `<circle cx="130" cy="88" r="54" fill="#f3cfa6"/>
<path d="M78 98 L72 130 Q86 138 102 130 L102 98 Z" fill="#aab3bd" stroke-width="5"/>
<path d="M76 128 Q87 134 99 128" fill="none" stroke="#e2c36e" stroke-width="4"/>
<path d="M76 90 A54 54 0 0 1 184 90 L192 100 L68 100 Z" fill="#aab3bd"/>
<path d="M84 74 Q90 52 108 42" fill="none" stroke="#cdd4da" stroke-width="5"/>
<path d="M70 92 L190 92 L194 102 L66 102 Z" fill="#e2c36e" stroke-width="5"/>
<rect x="116" y="30" width="22" height="12" rx="4" fill="#e2c36e" stroke-width="5"/>
<path d="M164 64 L174 76 L164 88 L154 76 Z" fill="#e2c36e" stroke-width="4"/>`,
    face: `<path d="M141 108 L154 112 M164 112 L177 108" stroke="#2b2220" stroke-width="4" stroke-linecap="round"/>
<circle cx="148" cy="120" r="6" fill="#2b2220"/><circle cx="170" cy="120" r="6" fill="#2b2220"/>
<circle cx="150" cy="118" r="2" fill="#fff"/><circle cx="172" cy="118" r="2" fill="#fff"/>
<ellipse cx="180" cy="132" rx="6" ry="4" fill="#f09a88" opacity="0.6"/>
<path d="M149 132 Q158 143 167 132" fill="none" stroke="#2b2220" stroke-width="3" stroke-linecap="round"/>`,
    arm: `<path d="M152 152 Q182 150 210 130" fill="none" stroke="#2b2220" stroke-width="24"/>
<path d="M152 152 Q182 150 210 130" fill="none" stroke="#c9503f" stroke-width="12"/>
<circle cx="212" cy="128" r="12" fill="#f3cfa6" stroke-width="5"/>`,
  },
  raw: ['face'],
  // parent before child; pivot in 256 space; ch = rotation channel (deg)
  bones: [
    { name: 'body', pivot: [128, 200], ch: 'lean' },
    { name: 'head', parent: 'body', pivot: [130, 140], ch: 'head' },
    { name: 'arm', parent: 'body', pivot: [152, 152], ch: 'arm' },
    { name: 'sword', parent: 'arm', pivot: [212, 128], ch: 'wrist' },   // pivot = hand centre
    { name: 'cape', parent: 'body', pivot: [122, 130], ch: 'cape', stretch: true },
    { name: 'plume', parent: 'head', pivot: [127, 38], ch: 'plume' },
    { name: 'legB', pivot: [114, 198], ch: 'legB' },
    { name: 'legF', pivot: [144, 198], ch: 'legF' },
  ],
  // [part, bone]; same order as the source SVG (sword moved next to arm — no overlap at rest)
  draw: [['cape', 'cape'], ['legB', 'legB'], ['legF', 'legF'], ['skirt', 'body'], ['torso', 'body'], ['pad', 'body'],
         ['plume', 'plume'], ['head', 'head'], ['face', 'head'], ['sword', 'sword'], ['arm', 'arm']],
  // z-swaps: mirrored during a spin -> weapon arm goes behind the body
  order(p, list) {
    if (p.face < 0) { const w = list.filter(([n]) => n === 'sword' || n === 'arm'); return [...w, ...list.filter(([n]) => n !== 'sword' && n !== 'arm')]; }
    return list;
  },
  points: { tip: ['sword', TIP[0], TIP[1]], mid: ['sword', MID[0], MID[1]] },
  springs: {
    cape: { k: 170, c: 11, drive: (p, vx, c) => clamp(vx * .03, -12, 34) + p.lean * .5 + (p.capeX || 0) + (c.idle ? 3 * Math.sin(c.clock / 700) : 0) },
    plume: { k: 230, c: 9, drive: (p, vx, c) => clamp(vx * .035, -14, 30) + p.lean * .7 + p.head * .6 + (c.idle ? 1.8 * Math.sin(c.clock / 700) : 0) },
  },
  idle(p, b) { p.sy = 1 + .014 * b; p.head = 1.5 * b; p.arm = 2 * b; p.wrist = -1.5 * b; },
  attacks: [
    {
      id: 'slash', label: '⚔ Chém gió', dur: 1080,
      tr: {
        x: track([[0, 0], [150, -12, 'out'], [210, -14], [280, 26, 'outExpo'], [560, 30, 'out'], [1000, 0, 'io']]),
        y: track([[0, 0], [150, 6, 'out'], [210, 6], [260, -10, 'out'], [340, 0, 'in']]),
        sy: track([[0, 1], [150, .9, 'out'], [210, .88], [255, 1.1, 'outExpo'], [340, .95, 'out'], [440, 1, 'out']]),
        lean: track([[0, 0], [150, -12, 'out'], [210, -13], [280, 16, 'outExpo'], [600, 12, 'out'], [1000, 0, 'io']]),
        head: track([[0, 0], [150, -8, 'out'], [210, -8], [280, 8, 'outExpo'], [600, 4], [1000, 0, 'io']]),
        arm: track([[0, 0], [150, -35, 'outBack'], [210, -38], [275, 75, 'outExpo'], [620, 68, 'out'], [1000, 0, 'io']]),
        wrist: track([[0, 0], [150, 12, 'outBack'], [210, 14], [275, 40, 'outExpo'], [620, 35, 'out'], [1000, 0, 'io']]),
        legF: track([[0, 0], [150, 8], [210, 8], [280, -28, 'outExpo'], [600, -24], [1000, 0, 'io']]),
        legB: track([[0, 0], [150, -4], [210, -4], [280, 22, 'outExpo'], [600, 18], [1000, 0, 'io']]),
      },
      ev: [
        [150, a => a.gleam('tip')],
        [215, a => a.dust(100, 244, 6, -1)],
        [252, a => a.wave({ x: 205, y: 150, vx: 1500, hit: { dmg: 42 } })],
      ],
      smear: { tip: 'tip', base: 'mid', from: 212, to: 330, window: 48 },
    },
    {
      id: 'whirl', label: '🌪 Lốc xoáy', dur: 2500,
      tr: {
        x: track([[0, 0], [160, -8, 'out'], [760, 14, 'io'], [1150, 0, 'io']]),
        y: track([[0, 0], [160, 6, 'out'], [260, -26, 'out'], [660, -22], [760, 0, 'in']]),
        sy: track([[0, 1], [160, .88, 'out'], [240, 1.1, 'outExpo'], [680, 1.04], [760, .88, 'in'], [900, 1, 'outBack']]),
        lean: track([[0, 0], [160, -10, 'out'], [260, 6, 'out'], [760, 6], [1150, 0, 'io']]),
        head: track([[0, 0], [160, -6], [1150, 0]]),
        arm: track([[0, 0], [160, 30, 'outBack'], [240, 22, 'outExpo'], [760, 22], [1150, 0, 'io']]),
        wrist: track([[0, 0], [160, 95, 'outBack'], [240, 80, 'outExpo'], [760, 80], [1150, 0, 'io']]),
        spin: track([[0, 0], [200, 0], [760, Math.PI * 4, 'io']]),       // face = cos(spin): paper-flip spin
        capeX: track([[0, 0], [220, 0], [320, 28, 'out'], [700, 28], [900, 0, 'io']]),
        legF: track([[0, 0], [160, 8], [260, -10, 'out'], [700, -10], [800, 0]]),
        legB: track([[0, 0], [160, -4], [260, 10, 'out'], [700, 10], [800, 0]]),
      },
      ev: [
        [200, a => a.dust(128, 244, 8, 0)],
        [220, a => a.ring({ ms: 600, turns: 2 })],
        [600, a => a.tornado({ x0: 200, ticks: 3, tick: { dmg: 9 }, final: { dmg: 21 } })],
        [770, a => a.dust(128, 244, 6, 0)],
      ],
    },
  ],
};
