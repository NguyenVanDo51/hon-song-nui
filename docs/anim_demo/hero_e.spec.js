// Tướng giặc (Eastern Han general: lamellar, spiked helmet + tassel, ring-pommel dao)
// Attack = "Kiếm gió lốc": identical for both commanders (hero_p.spec.js / hero_e.spec.js differ only in CHAR).
// Parts = verbatim markup from assets/units/styles/chibi/hero_e.svg; same skeleton (pivots, sword hand, blade length) in both.

const CHAR = {
 title: 'Tướng giặc · Kiếm gió lốc',
 plumePivot: [128, 30],
 parts: {
  cape: `<path d="M106 128 Q56 148 40 238 L60 228 L76 244 L92 230 L108 242 L120 232 Q116 182 134 132 Z" fill="#4f74c9"/>
<path d="M100 142 Q76 168 66 222 M112 150 Q98 190 96 228" fill="none" stroke="#32508f" stroke-width="5"/>`,
  legB: `<rect x="104" y="196" width="20" height="40" rx="4" fill="#3a2e28"/>
<rect x="96" y="226" width="32" height="20" rx="8" fill="#3a2e28"/>
<path d="M100 230 L124 230" stroke="#aab3bd" stroke-width="4"/>`,
  legF: `<rect x="134" y="196" width="20" height="40" rx="4" fill="#3a2e28"/>
<rect x="130" y="226" width="34" height="20" rx="8" fill="#3a2e28"/>
<path d="M134 230 L160 230" stroke="#aab3bd" stroke-width="4"/>`,
  skirt: `<path d="M92 178 L164 178 L172 222 Q128 232 84 222 Z" fill="#4f74c9"/>
<path d="M104 190 L98 220 M128 192 L128 226 M152 190 L158 220" fill="none" stroke="#32508f" stroke-width="4"/>
<path d="M94 176 L162 176 L166 198 Q128 206 90 198 Z" fill="#aab3bd" stroke-width="5"/>
<path d="M108 178 L106 200 M122 180 L121 203 M136 180 L136 203 M150 178 L151 201" fill="none" stroke="#7e8790" stroke-width="3"/>`,
  torso: `<path d="M98 128 Q128 116 158 128 L164 182 Q128 192 92 182 Z" fill="#aab3bd"/>
<path d="M98 142 L160 142 M97 156 L161 156 M96 170 L162 170" fill="none" stroke="#7e8790" stroke-width="4"/>
<path d="M110 130 L108 180 M122 128 L121 184 M136 128 L136 184 M150 130 L151 182" fill="none" stroke="#7e8790" stroke-width="3"/>
<path d="M106 126 L128 152 L150 124 L142 120 L128 138 L114 120 Z" fill="#4f74c9" stroke-width="5"/>
<path d="M94 180 Q128 190 162 180" fill="none" stroke="#2b2220" stroke-width="15"/>
<path d="M94 180 Q128 190 162 180" fill="none" stroke="#5a4a3c" stroke-width="7"/>
<rect x="120" y="178" width="16" height="12" rx="3" fill="#e2c36e" stroke-width="4"/>`,
  pad: `<path d="M136 136 Q154 126 174 138 L170 162 Q152 168 138 158 Z" fill="#aab3bd" stroke-width="5"/>
<path d="M140 146 Q154 140 171 148 M139 154 Q153 150 170 156" fill="none" stroke="#7e8790" stroke-width="3"/>`,
  plume: `<path d="M130 26 C108 16 80 24 58 46 C74 42 86 44 94 50 C80 56 70 68 64 84 C84 68 104 58 126 44 Z" fill="#4f74c9" stroke-width="6"/>
<path d="M120 30 C104 26 88 32 76 42 M118 40 C102 44 90 52 80 64" fill="none" stroke="#32508f" stroke-width="4"/>`,
  head: `<path d="M78 92 L68 138 Q84 146 104 138 L106 96 Z" fill="#aab3bd" stroke-width="5"/>
<path d="M74 110 L104 112 M72 124 L104 126" fill="none" stroke="#7e8790" stroke-width="3"/>
<circle cx="130" cy="92" r="52" fill="#f3cfa6"/>
<path d="M76 96 Q76 42 130 36 Q184 42 184 96 Z" fill="#aab3bd"/>
<path d="M104 44 L100 94 M130 36 L130 94 M156 44 L160 94" fill="none" stroke="#7e8790" stroke-width="4"/>
<path d="M120 40 L130 12 L140 40 Z" fill="#cdd4da" stroke-width="5"/>
<circle cx="130" cy="14" r="6" fill="#e2c36e" stroke-width="4"/>
<path d="M70 88 L190 88 L192 102 L68 102 Z" fill="#4f74c9" stroke-width="5"/>
<path d="M162 126 Q148 126 138 146 Q150 136 162 134 Q174 136 186 146 Q178 126 162 126 Z" fill="#3a2e28" stroke-width="4"/>`,
  face: `<path d="M138 106 L158 116 M166 116 L184 106" stroke="#2b2220" stroke-width="8" stroke-linecap="round"/>
<path d="M142 120 Q150 115 158 120 Q150 124 142 120 Z" fill="#2b2220" stroke="#2b2220" stroke-width="3" stroke-linejoin="round"/>
<path d="M166 120 Q174 115 182 120 Q174 124 166 120 Z" fill="#2b2220" stroke="#2b2220" stroke-width="3" stroke-linejoin="round"/>
<circle cx="153" cy="119" r="1.6" fill="#fff"/>
<circle cx="177" cy="119" r="1.6" fill="#fff"/>
<path d="M118 104 L128 124 M120 112 L126 110 M123 118 L129 116" stroke="#c0605a" stroke-width="3" stroke-linecap="round"/>`,
  sword: `<g transform="rotate(6 212 128)">
<path d="M205 112 L205 30 L220 12 L220 112 Z" fill="#cdd4da" stroke-width="5"/>
<path d="M209 34 L209 108" stroke="#aab3bd" stroke-width="4"/>
<rect x="198" y="108" width="28" height="11" rx="5" fill="#5a4a3c" stroke-width="5"/>
<rect x="207" y="118" width="10" height="20" rx="3" fill="#3a2e28" stroke-width="5"/>
<circle cx="212" cy="146" r="9" fill="none" stroke="#2b2220" stroke-width="11"/>
<circle cx="212" cy="146" r="9" fill="none" stroke="#e2c36e" stroke-width="4"/>
</g>`,
  arm: `<path d="M152 152 Q182 150 210 130" fill="none" stroke="#2b2220" stroke-width="26"/>
<path d="M152 152 Q182 150 210 130" fill="none" stroke="#4f74c9" stroke-width="14"/>
<path d="M190 144 L203 136" fill="none" stroke="#2b2220" stroke-width="26"/>
<path d="M190 144 L203 136" fill="none" stroke="#aab3bd" stroke-width="13"/>
<circle cx="212" cy="128" r="12" fill="#f3cfa6" stroke-width="5"/>`,
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
