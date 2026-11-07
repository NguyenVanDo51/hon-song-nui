// Hiệp Sĩ Chỉ Huy (player commander): plate + gold trim, crown helm w/ red gem, white feather wings, greatsword planted.
// Attack "Kiếm Giáng": shared by hero_p.spec.js / hero_e.spec.js (they differ only in CHAR).
// Art source = SVG.hero2('p', 2) in docs/review/ui_direction_fantasy.html (pose B, planted sword); same skeleton both sides.

const CHAR = {
 title: 'Hiệp Sĩ Chỉ Huy · Kiếm Giáng',
 parts: {
  cape: `<path d="M100 122 Q44 150 24 244 Q60 232 92 244 Q128 236 162 246 Q198 232 230 244 Q212 166 156 122 Z" fill="#c9503f"/>
<path d="M98 142 Q64 180 54 232 Q76 226 96 232 Z" fill="#93362b" stroke="none"/>
<path d="M158 142 Q192 180 202 232 Q180 226 160 232 Z" fill="#93362b" stroke="none"/>
<path d="M28 239 Q60 228 92 239 Q128 231 162 241 Q198 228 226 239" fill="none" stroke="#e2c36e" stroke-width="5"/>`,
  legB: `<rect x="96" y="194" width="24" height="40" rx="5" fill="#aab3bd"/>
<rect x="86" y="226" width="38" height="20" rx="8" fill="#7e8790"/>
<circle cx="108" cy="206" r="8" fill="#e2c36e" stroke-width="5"/>`,
  legF: `<rect x="138" y="194" width="24" height="40" rx="5" fill="#aab3bd"/>
<rect x="134" y="226" width="40" height="20" rx="8" fill="#7e8790"/>
<circle cx="150" cy="206" r="8" fill="#e2c36e" stroke-width="5"/>`,
  torso: `<path d="M98 126 Q128 114 158 126 L168 202 Q128 214 88 202 Z" fill="#cdd4da"/>
<path d="M110 136 Q107 162 112 190" fill="none" stroke="#f6f8fa" stroke-width="5"/>
<path d="M104 130 Q128 143 152 130" fill="none" stroke="#e2c36e" stroke-width="6"/>
<path d="M90 192 Q128 204 166 192 L172 214 Q128 228 84 214 Z" fill="#c9503f"/>
<path d="M87 210 Q128 224 169 210" fill="none" stroke="#e2c36e" stroke-width="5"/>
<path d="M92 190 Q128 200 164 190" fill="none" stroke="#5a4a3c" stroke-width="9"/>
<circle cx="128" cy="196" r="7" fill="#e2c36e" stroke-width="4"/>`,
  sword: `<path d="M119 170 L119 236 L128 252 L137 236 L137 170 Z" fill="#eef2f5"/>
<path d="M128 174 L128 236" stroke="#aab3bd" stroke-width="3"/>
<rect x="122" y="128" width="12" height="34" rx="3" fill="#5a4a3c"/>
<circle cx="128" cy="124" r="9" fill="#e2c36e" stroke-width="5"/>
<path d="M96 162 Q128 150 160 162 L158 174 Q128 164 98 174 Z" fill="#e2c36e"/>
<circle cx="128" cy="166" r="5" fill="#d23a3a" stroke-width="3"/>`,
  arms: `<path d="M104 140 Q98 158 118 150" fill="none" stroke="#2b2220" stroke-width="26"/>
<path d="M104 140 Q98 158 118 150" fill="none" stroke="#cdd4da" stroke-width="14"/>
<path d="M152 140 Q158 158 138 150" fill="none" stroke="#2b2220" stroke-width="26"/>
<path d="M152 140 Q158 158 138 150" fill="none" stroke="#cdd4da" stroke-width="14"/>
<circle cx="121" cy="148" r="12" fill="#aab3bd" stroke-width="5"/>
<circle cx="135" cy="148" r="12" fill="#aab3bd" stroke-width="5"/>`,
  pauld: `<path d="M112 132 Q82 124 70 150 Q90 144 106 158 Z" fill="#aab3bd"/>
<path d="M118 124 Q84 110 68 138 Q88 133 104 148 Z" fill="#cdd4da"/>
<path d="M110 125 Q84 118 74 135" fill="none" stroke="#e2c36e" stroke-width="5"/>
<path d="M144 132 Q174 124 186 150 Q166 144 150 158 Z" fill="#aab3bd"/>
<path d="M138 124 Q172 110 188 138 Q168 133 152 148 Z" fill="#cdd4da"/>
<path d="M146 125 Q172 118 182 135" fill="none" stroke="#e2c36e" stroke-width="5"/>
<path d="M68 138 L70 120 L77 129 L84 114 L91 129 L98 120 L100 138 Z" fill="#e2c36e" stroke-width="4"/>`,
  crest: `<path d="M92 86 Q62 84 34 60 Q46 60 52 56 Q32 44 26 20 Q44 32 58 34 Q48 20 50 4 Q70 26 76 40 Q84 54 100 64 Z" fill="#f7f4ec"/>
<path d="M86 74 Q64 66 46 52 M80 58 Q64 46 50 30 M86 50 Q74 36 62 20" fill="none" stroke="#cfc6b0" stroke-width="3"/>
<path d="M168 86 Q198 84 226 60 Q214 60 208 56 Q228 44 234 20 Q216 32 202 34 Q212 20 210 4 Q190 26 184 40 Q176 54 160 64 Z" fill="#f7f4ec"/>
<path d="M174 74 Q196 66 214 52 M180 58 Q196 46 210 30 M174 50 Q186 36 198 20" fill="none" stroke="#cfc6b0" stroke-width="3"/>`,
  head: `<circle cx="130" cy="84" r="54" fill="#f3cfa6"/>
<path d="M74 88 A56 56 0 0 1 186 88 L192 98 L68 98 Z" fill="#cdd4da"/>
<path d="M90 68 Q98 50 114 42" fill="none" stroke="#f6f8fa" stroke-width="5"/>
<path d="M104 80 L106 56 L118 70 L130 48 L142 70 L154 56 L156 80 Q130 72 104 80 Z" fill="#e2c36e" stroke-width="5"/>
<circle cx="130" cy="70" r="5" fill="#d23a3a" stroke-width="3"/>
<path d="M70 86 Q130 72 190 86 L192 98 Q130 84 68 98 Z" fill="#e2c36e" stroke-width="5"/>`,
  face: `<circle cx="149" cy="117" r="6.5" fill="#2b2220"/>
<circle cx="170" cy="117" r="6.5" fill="#2b2220"/>
<circle cx="151" cy="115" r="2" fill="#fff"/>
<circle cx="172" cy="115" r="2" fill="#fff"/>
<path d="M137 104 L157 111 M161 111 L181 104" stroke="#2b2220" stroke-width="7.5" stroke-linecap="round"/>
<path d="M152 133 Q160 130 168 132" fill="none" stroke="#2b2220" stroke-width="4" stroke-linecap="round"/>`,
 },
 // feather wings sway; hero_e horns stay rigid (no crest spring there)
 springs: {
  crest: { k: 230, c: 9, drive: (p, vx, c) => clamp(vx * .02, -8, 14) + p.lean * .3 + p.head * .4 + (c.idle ? 1.2 * Math.sin(c.clock / 700) : 0) },
 },
};

// shared impact: same for all units (game-wide hit feel)
const HIT = { stop: 90, amp: 9, kx: 420, debris: 'spark', n: 8, sparkColor: '#ffe08a', cut: true, cutAng: -24 };
const HIT_SMALL = { small: true, stop: 45, amp: 4, kx: 0, debris: 'spark', n: 3, sparkColor: '#ffe08a', cut: false };
// main hit:   api.hit(Object.assign({}, HIT, { dmg: 42 }))     or  wave/projectile/tornado { hit: Object.assign({}, HIT, { dmg: 42 }) }
// multi-tick: Object.assign({}, HIT_SMALL, { dmg: 6 }) for the small ticks before the final HIT

// ---------- shared below: same rig + attack for both commanders ----------
const DMG = 60;   // demo only; game shows the real amount
// timeline (ms): wrench 0–110 · raise 110–300 · hold –330 · cleave 330–400 (contact T_HIT) · follow –640 · re-plant –1080
const T_SLASH = 330, T_HIT = 362, T_PLANT = 1080;
// sword in front of head/wings while raised (rest order = behind arms + head)
const FRONT_ON = 280, FRONT_OFF = 640;

const SPEC = {
  title: CHAR.title,
  subtitle: 'Giật kiếm khỏi đất → vung qua đầu → chém chéo xuống địch → cắm kiếm trở lại',
  feet: 244, cx: 128, range: 1,
  parts: CHAR.parts,
  raw: ['face'],
  bones: [
    { name: 'body', pivot: [128, 200], ch: 'lean' },
    { name: 'cape', parent: 'body', pivot: [128, 124], ch: 'cape', stretch: true },
    { name: 'head', parent: 'body', pivot: [130, 138], ch: 'head' },
    { name: 'crest', parent: 'head', pivot: [130, 64], ch: 'crest' },
    { name: 'arms', parent: 'body', pivot: [128, 148], ch: 'arm', tx: 'armX', ty: 'armY' },
    { name: 'sword', parent: 'arms', pivot: [128, 148], ch: 'wrist' },   // pivot = both gauntlets on the grip
    { name: 'legB', pivot: [108, 196], ch: 'legB' },
    { name: 'legF', pivot: [150, 196], ch: 'legF' },
  ],
  draw: [['cape', 'cape'], ['legB', 'legB'], ['legF', 'legF'], ['torso', 'body'], ['sword', 'sword'], ['arms', 'arms'],
         ['pauld', 'body'], ['crest', 'crest'], ['head', 'head'], ['face', 'head']],
  order(p, list) {
    if (p.swordUp > .5) {
      const s = list.find(([n]) => n === 'sword'), rest = list.filter(([n]) => n !== 'sword');
      rest.splice(rest.findIndex(([n]) => n === 'face') + 1, 0, s); return rest;
    }
    return list;
  },
  points: { tip: ['sword', 128, 246], mid: ['sword', 128, 196], plant: ['sword', 128, 244] },
  springs: Object.assign({
    cape: { k: 170, c: 11, drive: (p, vx, c) => clamp(vx * .03, -12, 30) + p.lean * .5 + (c.idle ? 2 * Math.sin(c.clock / 700) : 0) },
  }, CHAR.springs),
  idle(p, b) { p.sy = 1 + .014 * b; p.head = 1.5 * b; },
  attacks: [
    {
      id: 'cleave', label: '⚔ Kiếm Giáng', dur: 1200,
      tr: {
        // wrist: clockwise backswing (+140 = blade up-back over the helm) -> cleave to +300 (down-forward) -> +360 = planted again
        wrist: track([[0, 0], [110, -6, 'out'], [300, 140, 'out'], [T_SLASH, 143], [400, 300, 'outExpo'], [640, 306, 'out'], [T_PLANT, 360, 'io']]),
        // hands: up out of the ground, out to the right, then high; cleave brings them forward-low
        armX: track([[0, 0], [110, 2, 'out'], [230, 50, 'out'], [T_SLASH, 52], [400, 54, 'outExpo'], [640, 50], [T_PLANT - 60, 0, 'io']]),
        armY: track([[0, 0], [110, -16, 'out'], [300, -98, 'in'], [T_SLASH, -100], [400, 0, 'outExpo'], [640, -4], [T_PLANT - 60, -14, 'io'], [T_PLANT, 0, 'in']]),
        arm: track([[0, 0], [T_SLASH, 0], [400, 10, 'outExpo'], [640, 8], [T_PLANT - 60, 0, 'io']]),
        x: track([[0, 0], [110, -4, 'out'], [300, -12, 'out'], [T_SLASH, -12], [400, 34, 'outExpo'], [640, 30, 'out'], [T_PLANT, 0, 'io']]),
        y: track([[0, 0], [300, 0], [350, -8, 'out'], [420, 0, 'in']]),
        sy: track([[0, 1], [110, .92, 'out'], [300, 1.04, 'out'], [T_SLASH, 1.04], [380, 1.1, 'outExpo'], [460, .94, 'out'], [560, 1, 'out'],
                   [T_PLANT - 40, 1.02, 'io'], [T_PLANT, .96, 'in'], [T_PLANT + 90, 1, 'out']]),
        lean: track([[0, 0], [110, -3, 'out'], [300, -10, 'out'], [T_SLASH, -11], [400, 14, 'outExpo'], [640, 12, 'out'], [T_PLANT, 0, 'io']]),
        head: track([[0, 0], [110, 3], [300, -6, 'out'], [T_SLASH, -6], [400, 8, 'outExpo'], [640, 5], [T_PLANT, 0, 'io']]),
        legF: track([[0, 0], [300, 6, 'out'], [T_SLASH, 6], [400, -24, 'outExpo'], [640, -20], [T_PLANT, 0, 'io']]),
        legB: track([[0, 0], [300, -4, 'out'], [T_SLASH, -4], [400, 18, 'outExpo'], [640, 15], [T_PLANT, 0, 'io']]),
        swordUp: track([[0, 0], [FRONT_ON, 0], [FRONT_ON + 1, 1, 'lin'], [FRONT_OFF, 1], [FRONT_OFF + 1, 0, 'lin']]),
      },
      ev: [
        [30, a => a.dust(128, 244, 4, 0)],
        [250, a => a.gleam('tip', 130)],
        [T_SLASH, a => a.dust(100, 244, 6, -1)],
        [T_HIT, a => a.hit(Object.assign({}, HIT, { dmg: DMG }))],
        [T_PLANT, a => { a.dust(128, 244, 5, 0); a.shake(2, 70); }],
      ],
      smear: { tip: 'tip', base: 'mid', from: T_SLASH, to: 430, window: 50, fill: '#fffdf4', inner: '#ffe08a' },
    },
  ],
};
