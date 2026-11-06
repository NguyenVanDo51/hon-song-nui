// Chó săn (wolf_p.svg): crouch -> pounce leap -> jaw-snap bite (3 red claw slashes) -> "weakened" puff on target -> hop back.
// Parts = verbatim blocks of wolf_p.svg; face sits outside the outline <g> -> raw.

// shared impact: same for all units (game-wide hit feel)
const HIT = { stop: 90, amp: 9, kx: 420, debris: 'spark', n: 8, sparkColor: '#ffe08a', cut: true, cutAng: -24 };
const HIT_SMALL = { small: true, stop: 45, amp: 4, kx: 0, debris: 'spark', n: 3, sparkColor: '#ffe08a', cut: false };

const CLAW = '#e0503f';
const WEAK = { dark: '#6e1e2a', mid: '#9c2f3c', light: '#d9707a' };

// 3 red bite/claw slashes on the target, staggered; read target pos each frame (knockback moves it)
function clawFx(api) {
  const life = 360;
  return {
    age: 0,
    upd(s, ms) { this.age += ms; return this.age < life; },
    draw(ctx, cam, layer) {
      if (layer !== 'front') return;
      const c = api.target();
      for (let i = 0; i < 3; i++) {
        const a = this.age - i * 28; if (a <= 0) continue;
        const u = Math.min(1, a / (life - 60)), len = 170 * Math.min(1, a / 45), w = 15 * (1 - u * u);
        if (w <= .5) continue;
        ctx.setTransform(cam.translate(c.x - 6 + (i - 1) * 30, c.y - 10 + (i - 1) * 6).rotate(62));
        ctx.beginPath(); ctx.moveTo(-len / 2, 0); ctx.quadraticCurveTo(0, -w, len / 2, 0); ctx.quadraticCurveTo(0, w, -len / 2, 0);
        ctx.fillStyle = CLAW; ctx.fill(); ctx.strokeStyle = INK; ctx.lineWidth = 4; ctx.lineJoin = 'round'; ctx.stroke();
      }
    },
  };
}

// debuff (-10 atk / -10 def): dark-red puff + swirl on the bitten torso + 2 sinking down-arrows; kept below the shared dmg number
function weakFx(api) {
  const life = 950;
  const arrow = (ctx, x, y, s) => {
    ctx.beginPath();
    ctx.moveTo(x - 7 * s, y - 22 * s); ctx.lineTo(x + 7 * s, y - 22 * s); ctx.lineTo(x + 7 * s, y - 4 * s); ctx.lineTo(x + 16 * s, y - 4 * s);
    ctx.lineTo(x, y + 16 * s); ctx.lineTo(x - 16 * s, y - 4 * s); ctx.lineTo(x - 7 * s, y - 4 * s); ctx.closePath();
    ctx.fillStyle = WEAK.mid; ctx.fill(); ctx.strokeStyle = INK; ctx.lineWidth = 4; ctx.stroke();
  };
  return {
    age: 0,
    upd(s, ms) { this.age += ms; return this.age < life; },
    draw(ctx, cam, layer) {
      if (layer !== 'front') return;
      const c = api.target(), t = this.age, pop = E.outBack(Math.min(1, t / 170)), fade = t > life - 260 ? (life - t) / 260 : 1;
      const x = c.x + 2, y = c.y + 4 + 10 * E.out(t / life);
      ctx.globalAlpha = Math.max(0, fade); ctx.lineJoin = 'round'; ctx.lineCap = 'round';
      ctx.setTransform(cam.translate(x, y).scale(pop, pop));
      ctx.beginPath();
      for (const [dx, dy, r] of [[-30, 6, 20], [-8, -8, 26], [20, -2, 22], [34, 10, 15], [0, 12, 20]]) { ctx.moveTo(dx + r, dy); ctx.arc(dx, dy, r, 0, Math.PI * 2); }
      ctx.fillStyle = WEAK.dark; ctx.strokeStyle = INK; ctx.lineWidth = 9; ctx.stroke(); ctx.fill();
      ctx.beginPath();
      for (let k = 0; k <= 40; k++) { const a = k / 40 * Math.PI * 3.2 + t / 120, r = 3 + k * .45; ctx.lineTo(Math.cos(a) * r * 1.3, 2 + Math.sin(a) * r); }
      ctx.strokeStyle = WEAK.light; ctx.lineWidth = 4; ctx.stroke();
      const sink = 34 * E.out(Math.min(1, t / 600));
      ctx.setTransform(cam);
      arrow(ctx, x - 74, c.y - 44 + sink, 1.2);
      arrow(ctx, x + 76, c.y - 34 + sink * .8, 1.05);
      ctx.globalAlpha = 1;
    },
  };
}

const SPEC = {
  title: 'Chó săn · Vồ cắn',
  subtitle: 'Thu mình → vồ → đớp (3 vết cào đỏ) → địch suy yếu −10 công/−10 thủ → nhảy lùi',
  feet: 244, cx: 128, range: 1, shadowR: 78,
  parts: {
    tail: `<path d="M60 162 Q20 158 22 122 Q26 92 54 100 Q70 112 54 130" fill="none" stroke="#2b2220" stroke-width="28"/>
<path d="M60 162 Q20 158 22 122 Q26 92 54 100 Q70 112 54 130" fill="none" stroke="#c48a4f" stroke-width="14"/>`,
    legHB: `<rect x="90" y="190" width="24" height="54" rx="10" fill="#8f5f34"/>`,
    legFB: `<rect x="178" y="186" width="24" height="58" rx="10" fill="#8f5f34"/>`,
    body: `<ellipse cx="120" cy="174" rx="72" ry="40" fill="#c48a4f"/>
<path d="M76 140 Q116 126 158 138" fill="none" stroke="#8f5f34" stroke-width="9"/>
<path d="M66 204 Q120 220 178 200" fill="none" stroke="#8f5f34" stroke-width="5"/>`,
    legHF: `<ellipse cx="76" cy="186" rx="28" ry="30" fill="#c48a4f"/>
<rect x="56" y="198" width="30" height="46" rx="12" fill="#c48a4f"/>
<path d="M66 234 L66 243 M76 234 L76 243" stroke="#8f5f34" stroke-width="4"/>`,
    legFF: `<rect x="150" y="188" width="30" height="56" rx="12" fill="#c48a4f"/>
<path d="M160 234 L160 243 M170 234 L170 243" stroke="#8f5f34" stroke-width="4"/>`,
    cloth: `<path d="M68 148 Q118 134 168 148 L172 198 Q118 212 62 198 Z" fill="#c9503f"/>
<path d="M74 155 Q118 143 162 155" fill="none" stroke="#93362b" stroke-width="5"/>
<path d="M86 176 L94 167 L102 176 M134 176 L142 167 L150 176" fill="none" stroke="#93362b" stroke-width="4"/>
<path d="M64 194 Q118 208 170 194" fill="none" stroke="#e2c36e" stroke-width="10"/>
<circle cx="118" cy="174" r="12" fill="#e2c36e" stroke-width="5"/>
<circle cx="118" cy="174" r="5" fill="none" stroke="#93362b" stroke-width="3"/>`,
    earB: `<path d="M150 102 L142 54 L182 82 Z" fill="#c48a4f"/>
<path d="M154 92 L150 68 L170 82 Z" fill="#8f5f34" stroke="none"/>`,
    earF: `<path d="M184 86 L204 42 L222 90 Z" fill="#c48a4f"/>
<path d="M193 82 L204 58 L212 84 Z" fill="#8f5f34" stroke="none"/>`,
    mouth: `<path d="M196 144 L240 140 Q238 174 214 178 Q198 170 196 144 Z" fill="#5a2420"/>`,
    jaw: `<path d="M200 164 Q220 174 240 156 L238 168 Q226 188 200 176 Z" fill="#ecd9b4" stroke-width="5"/>
<path d="M210 172 Q220 166 230 164" fill="none" stroke="#d9706a" stroke-width="4"/>
<path d="M219 171 L223 158 L228 169 Z" fill="#f5ecd8" stroke-width="4"/>`,
    head: `<circle cx="178" cy="124" r="44" fill="#c48a4f"/>
<ellipse cx="214" cy="130" rx="27" ry="15" fill="#ecd9b4"/>
<ellipse cx="238" cy="124" rx="8" ry="6" fill="#2b2220" stroke-width="4"/>
<path d="M205 143 L210 160 L216 143 Z M226 142 L230 157 L235 141 Z" fill="#f5ecd8" stroke-width="4"/>`,
    collar: `<path d="M144 108 Q138 148 166 176" fill="none" stroke="#2b2220" stroke-width="24"/>
<path d="M144 108 Q138 148 166 176" fill="none" stroke="#5a4a3c" stroke-width="11"/>
<path d="M140 118 L124 112 L138 130 Z M137 142 L121 144 L139 154 Z M148 164 L138 178 L156 174 Z" fill="#aab3bd" stroke-width="5"/>
<circle cx="141" cy="136" r="5" fill="#e2c36e" stroke-width="4"/>`,
    face: `<path d="M174 104 L198 112" stroke="#2b2220" stroke-width="6" stroke-linecap="round"/>
<circle cx="188" cy="118" r="6" fill="#2b2220"/>
<circle cx="190" cy="116" r="2" fill="#fff"/>
<ellipse cx="180" cy="142" rx="6" ry="4" fill="#f09a88" opacity="0.6"/>`,
  },
  raw: ['face'],
  bones: [
    { name: 'all', pivot: [124, 214], ch: 'pitch' },            // whole-body pitch: nose up on take-off, down into the bite
    { name: 'tail', parent: 'all', pivot: [58, 160], ch: 'tail' },
    { name: 'legHB', parent: 'all', pivot: [102, 194], ch: 'legHb' },
    { name: 'legFB', parent: 'all', pivot: [190, 190], ch: 'legFb' },
    { name: 'legHF', parent: 'all', pivot: [76, 180], ch: 'legH' },
    { name: 'legFF', parent: 'all', pivot: [165, 192], ch: 'legF' },
    { name: 'head', parent: 'all', pivot: [160, 162], ch: 'head' },
    { name: 'jaw', parent: 'head', pivot: [200, 162], ch: 'jaw' },
    { name: 'earB', parent: 'head', pivot: [162, 92], ch: 'earB' },
    { name: 'earF', parent: 'head', pivot: [202, 86], ch: 'earF' },
  ],
  draw: [['tail', 'tail'], ['legHB', 'legHB'], ['legFB', 'legFB'], ['body', 'all'], ['legHF', 'legHF'], ['legFF', 'legFF'],
         ['cloth', 'all'], ['earB', 'earB'], ['earF', 'earF'], ['mouth', 'head'], ['jaw', 'jaw'], ['head', 'head'],
         ['collar', 'head'], ['face', 'head']],
  points: { eye: ['head', 190, 116], bite: ['head', 228, 158], nose: ['head', 240, 124] },
  // tail/ears = springs; tracks push them through additive channels (spring would overwrite a same-named track)
  springs: {
    tail: { k: 150, c: 8, drive: (p, vx, c) => clamp(-vx * .035, -34, 16) + (p.tailX || 0) - p.pitch * .6 + (c.idle ? 9 * Math.sin(c.clock / 170) : 0) },
    earB: { k: 260, c: 10, drive: (p, vx, c) => clamp(-vx * .03, -30, 10) + (p.earsX || 0) - p.head * .4 + (c.idle ? 2 * Math.sin(c.clock / 600) : 0) },
    earF: { k: 240, c: 9, drive: (p, vx, c) => clamp(-vx * .035, -34, 10) + (p.earsX || 0) * 1.1 - p.head * .5 + (c.idle ? 2.5 * Math.sin(c.clock / 600 + 1) : 0) },
  },
  idle(p, b) { p.sy = 1 + .016 * b; p.head = 2 * b; p.jaw = 3 * Math.max(0, b); p.pitch = .6 * b; },
  attacks: [
    {
      id: 'pounce', label: '🐕 Vồ cắn', dur: 1160,
      tr: {
        x: track([[0, 0], [170, -16, 'out'], [230, -18], [420, 102, 'out'], [470, 98], [600, 88, 'out'], [880, 4, 'io'], [960, 0, 'out']]),
        y: track([[0, 0], [230, 0], [330, -62, 'out'], [430, -12, 'in'], [600, -6], [650, 0, 'in'], [760, -36, 'out'], [880, 0, 'in']]),
        sy: track([[0, 1], [170, .8, 'out'], [230, .78], [280, 1.14, 'outExpo'], [400, 1.04], [445, .94, 'outExpo'], [530, 1, 'out'],
                   [660, .9, 'out'], [720, 1.06, 'out'], [880, 1], [905, .88, 'out'], [1040, 1, 'outBack']]),
        pitch: track([[0, 0], [170, 6, 'out'], [230, 7], [300, -16, 'outExpo'], [420, 8, 'io'], [450, 10, 'out'], [600, 8],
                      [660, 2], [740, -8, 'out'], [880, 0, 'io']]),
        head: track([[0, 0], [170, 6, 'out'], [230, 6], [320, -12, 'out'], [415, -14], [445, 8, 'outExpo'], [490, 2], [520, 9], [560, 3],
                     [600, 6], [900, 0, 'io']]),
        jaw: track([[0, 0], [170, -6, 'out'], [230, -6], [300, 8], [415, 32, 'outBack'], [440, -10, 'outExpo'], [640, -10], [760, 4, 'out'], [960, 0, 'io']]),
        legF: track([[0, 0], [170, 10], [230, 12], [300, -62, 'outExpo'], [420, -48, 'out'], [600, -36], [680, 14, 'io'], [800, -20, 'io'], [890, 0, 'out']]),
        legFb: track([[0, 0], [170, 6], [230, 8], [305, -50, 'outExpo'], [420, -40, 'out'], [600, -28], [680, 8, 'io'], [800, -14, 'io'], [890, 0, 'out']]),
        legH: track([[0, 0], [170, -10], [230, -14], [290, 58, 'outExpo'], [420, 34, 'out'], [600, 24], [680, -10, 'io'], [800, 26, 'io'], [890, 0, 'out']]),
        legHb: track([[0, 0], [170, -6], [230, -10], [295, 46, 'outExpo'], [420, 28, 'out'], [600, 18], [680, -6, 'io'], [800, 20, 'io'], [890, 0, 'out']]),
        tailX: track([[0, 0], [170, 24, 'out'], [230, 26], [300, -6, 'out'], [600, 0], [900, 0]]),
        earsX: track([[0, 0], [170, -26, 'out'], [230, -28], [420, -34], [460, -10, 'out'], [700, -18], [960, 0, 'io']]),
      },
      ev: [
        [120, a => a.gleam('eye', 200)],
        [236, a => a.dust(70, 244, 7, -1)],
        [442, a => {
          a.hit(Object.assign({}, HIT, { dmg: 62 }));   // wolf atk 60-65 (rules.gd)
          a.add(clawFx(a));
        }],
        [620, a => a.add(weakFx(a))],
        [652, a => a.dust(200, 244, 4, 1)],
        [890, a => a.dust(128, 244, 6, 0)],
      ],
      // speed streaks behind the leaping body
      draw(ctx, cam, api, layer, t) {
        if (layer !== 'mid' || t < 250 || t > 470) return;
        const h = api.hero(), u = (t - 250) / 220, a = u < .2 ? u / .2 : 1 - (u - .2) / .8;
        ctx.setTransform(cam); ctx.lineCap = 'round'; ctx.globalAlpha = a;
        for (const [dy, len] of [[-40, 110], [0, 150], [36, 90]]) {
          ctx.beginPath(); ctx.moveTo(h.x - 70, h.y + dy); ctx.lineTo(h.x - 70 - len, h.y + dy);
          ctx.strokeStyle = INK; ctx.lineWidth = 10; ctx.stroke(); ctx.strokeStyle = '#f4fcff'; ctx.lineWidth = 5; ctx.stroke();
        }
        ctx.globalAlpha = 1;
      },
    },
  ],
};
