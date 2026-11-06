// Anh hùng (Lạc Việt general: bronze Đông Sơn plates, feather crest, bronze kiếm)
// Attack = "Kiếm gió lốc": identical for both commanders (hero_p.spec.js / hero_e.spec.js differ only in CHAR).
// Parts = verbatim markup from assets/units/styles/chibi/hero_p.svg; same skeleton (pivots, sword hand, blade length) in both.

const CHAR = {
 title: 'Anh hùng · Kiếm gió lốc',
 plumePivot: [122, 48],
 parts: {
  cape: `<path d="M108 128 Q64 150 30 236 Q48 226 58 242 Q72 228 88 244 Q100 232 114 240 L138 134 Z" fill="#c9503f"/>
<path d="M104 140 Q76 166 56 228 Q70 220 84 234 Q96 222 108 230" fill="none" stroke="#93362b" stroke-width="5"/>`,
  legB: `<rect x="104" y="196" width="20" height="40" rx="4" fill="#5a4a3c"/>
<path d="M106 214 L122 214" stroke="#e2c36e" stroke-width="5"/>
<rect x="98" y="226" width="30" height="20" rx="8" fill="#3a2e28"/>`,
  legF: `<rect x="134" y="196" width="20" height="40" rx="4" fill="#5a4a3c"/>
<path d="M136 214 L152 214" stroke="#e2c36e" stroke-width="5"/>
<rect x="130" y="226" width="32" height="20" rx="8" fill="#3a2e28"/>`,
  skirt: `<path d="M94 176 L162 176 L168 208 Q128 218 88 208 Z" fill="#c9503f"/>
<path d="M110 184 L108 210 M128 186 L128 212 M146 184 L148 210" fill="none" stroke="#93362b" stroke-width="4"/>`,
  torso: `<path d="M100 128 Q128 118 156 128 L162 180 Q128 190 94 180 Z" fill="#5a4a3c"/>
<path d="M106 134 Q130 126 154 134 L156 166 Q130 174 104 166 Z" fill="#e2c36e" stroke-width="5"/>
<circle cx="128" cy="150" r="10" fill="none" stroke="#a87a4c" stroke-width="4"/>
<circle cx="128" cy="150" r="3" fill="#a87a4c" stroke="none"/>
<path d="M110 138 L116 134 M140 134 L146 138 M110 162 L116 166 M140 166 L146 162" stroke="#a87a4c" stroke-width="3"/>
<path d="M96 178 Q128 188 160 178" fill="none" stroke="#2b2220" stroke-width="15"/>
<path d="M96 178 Q128 188 160 178" fill="none" stroke="#c9503f" stroke-width="7"/>`,
  pad: `<ellipse cx="152" cy="146" rx="17" ry="13" fill="#e2c36e" stroke-width="5"/>
<path d="M138 150 Q152 158 167 149" fill="none" stroke="#a87a4c" stroke-width="4"/>`,
  plume: `<path d="M118 50 C100 32 72 16 34 8 C56 24 82 42 108 60 Z" fill="#efe3c8" stroke-width="5"/>
<path d="M34 8 C44 14 52 20 58 24 L66 16 C56 12 46 9 34 8 Z" fill="#3a2e28" stroke-width="4"/>
<path d="M124 46 C114 26 94 10 66 2 C82 18 98 36 112 56 Z" fill="#c9503f" stroke-width="5"/>
<path d="M118 44 C108 30 92 16 76 8" fill="none" stroke="#93362b" stroke-width="3"/>
<path d="M128 46 C128 26 120 12 104 2 C108 18 112 34 116 54 Z" fill="#efe3c8" stroke-width="5"/>
<path d="M104 2 C109 7 113 12 116 18 L122 14 C118 8 112 4 104 2 Z" fill="#3a2e28" stroke-width="4"/>`,
  head: `<circle cx="130" cy="92" r="52" fill="#f3cfa6"/>
<path d="M80 98 Q74 128 92 142 Q100 132 104 112 L104 98 Z" fill="#3a2e28" stroke-width="5"/>
<path d="M78 94 Q80 44 130 40 Q180 44 182 94 Z" fill="#e2c36e"/>
<path d="M92 70 Q130 50 168 70" fill="none" stroke="#a87a4c" stroke-width="4"/>
<path d="M98 60 L104 54 L110 60 L116 54 L122 60 L128 54 L134 60 L140 54 L146 60 L152 54 L158 60" fill="none" stroke="#a87a4c" stroke-width="3"/>
<path d="M72 84 L188 84 L190 100 L70 100 Z" fill="#e2c36e" stroke-width="5"/>
<circle cx="96" cy="92" r="4" fill="none" stroke="#a87a4c" stroke-width="3"/>
<circle cx="120" cy="92" r="4" fill="none" stroke="#a87a4c" stroke-width="3"/>
<circle cx="144" cy="92" r="4" fill="none" stroke="#a87a4c" stroke-width="3"/>
<circle cx="168" cy="92" r="4" fill="none" stroke="#a87a4c" stroke-width="3"/>
<rect x="114" y="36" width="20" height="12" rx="4" fill="#e2c36e" stroke-width="5"/>`,
  sword: `<g transform="rotate(6 212 128)">
<path d="M205 112 L204 36 L212 10 L220 36 L219 112 Z" fill="#e2c36e" stroke-width="5"/>
<path d="M212 30 L212 108" stroke="#a87a4c" stroke-width="4"/>
<rect x="192" y="108" width="40" height="11" rx="5" fill="#a87a4c" stroke-width="5"/>
<rect x="207" y="118" width="10" height="22" rx="3" fill="#3a2e28" stroke-width="5"/>
<circle cx="212" cy="144" r="7" fill="#e2c36e" stroke-width="5"/>
</g>`,
  arm: `<path d="M152 152 Q182 150 210 130" fill="none" stroke="#2b2220" stroke-width="24"/>
<path d="M152 152 Q182 150 210 130" fill="none" stroke="#c9503f" stroke-width="12"/>
<path d="M188 145 L202 137" fill="none" stroke="#2b2220" stroke-width="26"/>
<path d="M188 145 L202 137" fill="none" stroke="#e2c36e" stroke-width="13"/>
<circle cx="212" cy="128" r="12" fill="#f3cfa6" stroke-width="5"/>`,
  face: `<path d="M140 110 L156 115 M164 115 L180 110" stroke="#2b2220" stroke-width="6" stroke-linecap="round"/>
<circle cx="148" cy="123" r="6" fill="#2b2220"/>
<circle cx="170" cy="123" r="6" fill="#2b2220"/>
<circle cx="150" cy="121" r="2" fill="#fff"/>
<circle cx="172" cy="121" r="2" fill="#fff"/>
<ellipse cx="181" cy="134" rx="6" ry="4" fill="#f09a88" opacity="0.6"/>
<path d="M151 134 Q159 142 167 134" fill="none" stroke="#2b2220" stroke-width="3" stroke-linecap="round"/>`,
 },
};

// shared impact: same for all units (game-wide hit feel)
const HIT = { stop: 90, amp: 9, kx: 420, debris: 'spark', n: 8, sparkColor: '#ffe08a', cut: true, cutAng: -24 };
const HIT_SMALL = { small: true, stop: 45, amp: 4, kx: 0, debris: 'spark', n: 3, sparkColor: '#ffe08a', cut: false };
// main hit:   api.hit(Object.assign({}, HIT, { dmg: 42 }))     or  wave/projectile/tornado { hit: Object.assign({}, HIT, { dmg: 42 }) }
// multi-tick: Object.assign({}, HIT_SMALL, { dmg: 6 }) for the small ticks before the final HIT

// ---------- shared below: same rig + attack for both commanders ----------
const TIP = bake(6, 212, 128, 212, 14);   // sword group has rotate(6 212 128) in the source
const MID = bake(6, 212, 128, 212, 70);
// damage split ~ hero atk 55–65: blade 5 + 3 ticks × 5 + drop 40 = 60
const DMG = { blade: 5, tick: 5, drop: 40 };
// timeline (ms): wind-up 0–160, hold –220, slash –290, blade lands ~342 -> tornado; lift ~432, 3 ticks, release ~1152 (hero cuts down), drop hit ~1547
const T_WAVE = 262, WAVE_X = 236, WAVE_VX = 1300;
const T_TWISTER = T_WAVE + Math.round((256 + 84 - WAVE_X) / WAVE_VX * 1000);   // wave reaches target front (~342)
const TW_TRAVEL = 90, TW_HOLD = 720, T_DROP = T_TWISTER + TW_TRAVEL + TW_HOLD;   // twister releases target (~1152); lands ~T_DROP+395

const SPEC = {
  title: CHAR.title,
  subtitle: 'Chém kiếm phóng lưỡi gió -> hoá lốc xoáy cuốn địch, quật xuống',
  feet: 244, cx: 128, range: 1,
  parts: CHAR.parts,
  raw: ['face'],
  bones: [
    { name: 'body', pivot: [128, 200], ch: 'lean' },
    { name: 'head', parent: 'body', pivot: [130, 140], ch: 'head' },
    { name: 'arm', parent: 'body', pivot: [152, 152], ch: 'arm' },
    { name: 'sword', parent: 'arm', pivot: [212, 128], ch: 'wrist' },
    { name: 'cape', parent: 'body', pivot: [122, 130], ch: 'cape', stretch: true },
    { name: 'plume', parent: 'head', pivot: CHAR.plumePivot, ch: 'plume' },
    { name: 'legB', pivot: [114, 198], ch: 'legB' },
    { name: 'legF', pivot: [144, 198], ch: 'legF' },
  ],
  draw: [['cape', 'cape'], ['legB', 'legB'], ['legF', 'legF'], ['skirt', 'body'], ['torso', 'body'], ['pad', 'body'],
         ['plume', 'plume'], ['head', 'head'], ['face', 'head'], ['sword', 'sword'], ['arm', 'arm']],
  points: { tip: ['sword', TIP[0], TIP[1]], mid: ['sword', MID[0], MID[1]] },
  springs: {
    cape: { k: 170, c: 11, drive: (p, vx, c) => clamp(vx * .03, -12, 34) + p.lean * .5 + (c.idle ? 3 * Math.sin(c.clock / 700) : 0) },
    plume: { k: 230, c: 9, drive: (p, vx, c) => clamp(vx * .035, -14, 30) + p.lean * .7 + p.head * .6 + (c.idle ? 1.8 * Math.sin(c.clock / 700) : 0) },
  },
  idle(p, b) { p.sy = 1 + .014 * b; p.head = 1.5 * b; p.arm = 2 * b; p.wrist = -1.5 * b; },
  attacks: [
    {
      id: 'gale', label: '🌪 Kiếm gió lốc', dur: 1820,
      tr: {
        // wind-up -> slash -> follow-through -> recover -> raise sword (lifting the twister) -> cut down = drop
        x: track([[0, 0], [160, -12, 'out'], [220, -14], [290, 26, 'outExpo'], [620, 28, 'out'], [1000, 0, 'io']]),
        y: track([[0, 0], [160, 6, 'out'], [220, 6], [270, -10, 'out'], [350, 0, 'in']]),
        sy: track([[0, 1], [160, .88, 'out'], [220, .87], [265, 1.1, 'outExpo'], [350, .95, 'out'], [450, 1, 'out'],
                   [T_DROP - 80, 1.04, 'io'], [T_DROP, .92, 'outExpo'], [T_DROP + 150, 1, 'out']]),
        lean: track([[0, 0], [160, -12, 'out'], [220, -13], [290, 16, 'outExpo'], [620, 12, 'out'], [1000, 0, 'io'],
                     [T_DROP - 80, -6, 'io'], [T_DROP, 8, 'outExpo'], [T_DROP + 90, 6], [T_DROP + 390, 0, 'io']]),
        head: track([[0, 0], [160, -8, 'out'], [220, -8], [290, 8, 'outExpo'], [620, 4], [1000, 0, 'io'],
                     [T_DROP - 80, -6, 'io'], [T_DROP, 4, 'outExpo'], [T_DROP + 390, 0, 'io']]),
        arm: track([[0, 0], [160, -38, 'outBack'], [220, -40], [285, 78, 'outExpo'], [620, 70, 'out'], [1000, 0, 'io'],
                    [T_DROP - 80, -48, 'io'], [T_DROP, 56, 'outExpo'], [T_DROP + 110, 50], [T_DROP + 430, 0, 'io']]),
        wrist: track([[0, 0], [160, 14, 'outBack'], [220, 16], [285, 42, 'outExpo'], [620, 36, 'out'], [1000, 0, 'io'],
                      [T_DROP - 80, 12, 'io'], [T_DROP, 30, 'outExpo'], [T_DROP + 110, 26], [T_DROP + 430, 0, 'io']]),
        legF: track([[0, 0], [160, 8], [220, 8], [290, -28, 'outExpo'], [620, -24], [1000, 0, 'io']]),
        legB: track([[0, 0], [160, -4], [220, -4], [290, 22, 'outExpo'], [620, 18], [1000, 0, 'io']]),
      },
      ev: [
        [160, a => a.gleam('tip')],
        [225, a => a.dust(100, 244, 6, -1)],
        [T_WAVE, a => { a.flash('#f4fcff', 50); a.wave({ x: WAVE_X, y: 150, vx: WAVE_VX, R: 118, angle: -16, hit: Object.assign({}, HIT_SMALL, { dmg: DMG.blade }) }); }],
        [T_TWISTER, a => {
          const tg = a.target();
          a.shockwave(tg.x, 244, { r: 130, ms: 360, color: '#f4fcff' });
          a.dust(tg.x, 244, 8, 0);
          a.tornado({ x0: tg.x, travel: TW_TRAVEL, hold: TW_HOLD, lift: 100, ticks: 3,
                      tick: Object.assign({}, HIT_SMALL, { dmg: DMG.tick }), final: Object.assign({}, HIT, { dmg: DMG.drop }) });
        }],
        [T_DROP - 70, a => a.gleam('tip', 150)],
      ],
      smear: { tip: 'tip', base: 'mid', from: 222, to: 340, window: 48 },
    },
  ],
};
