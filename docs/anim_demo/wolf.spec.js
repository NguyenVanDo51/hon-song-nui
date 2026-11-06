// Chó săn (wolf_p.svg, grey wolf look): crouch -> pounce leap -> jaw-snap bite (3 red claw slashes) -> "weakened" puff on target -> hop back.
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
    tail: `<path d="M72 156 Q52 132 24 136 L30 145 L12 146 L22 156 L4 162 L20 168 L8 180 L30 178 L24 190 L44 180 Q60 176 72 168 Z" fill="#8d94a0"/>
<path d="M24 136 L30 145 L12 146 L22 156 L4 162 L20 168 L8 180 L30 178 L24 190 L34 184 Q26 160 36 140 Z" fill="#4a4f5a" stroke="none"/>
<path d="M50 150 L44 144 M56 166 L48 170" fill="none" stroke="#5d6370" stroke-width="4"/>`,
    legHB: `<path d="M92 190 L114 190 L110 226 Q114 240 106 244 L88 244 Q84 238 92 232 Z" fill="#5d6370"/>`,
    legFB: `<path d="M180 186 L200 186 L198 236 Q200 244 190 244 L176 244 Q172 238 180 234 Z" fill="#5d6370"/>`,
    body: `<path d="M58 176 Q58 142 102 138 Q148 132 176 148 Q198 166 186 196 Q164 214 120 210 Q80 212 64 198 Q56 188 58 176 Z" fill="#8d94a0"/>
<path d="M88 202 Q122 212 170 198 Q166 190 154 194 Q124 204 94 196 Z" fill="#dfe2e6" stroke="none"/>
<path d="M76 146 Q118 132 164 144 Q124 150 84 160 Z" fill="#5d6370" stroke="none"/>`,
    legHF: `<ellipse cx="78" cy="184" rx="27" ry="30" fill="#8d94a0"/>
<path d="M64 196 L90 200 L82 226 Q90 238 84 244 L62 244 Q58 238 66 232 Z" fill="#8d94a0"/>
<path d="M68 238 L68 244 M76 238 L76 244" stroke="#5d6370" stroke-width="4"/>`,
    legFF: `<path d="M152 186 L178 186 L174 236 Q178 244 168 244 L152 244 Q146 240 152 234 Z" fill="#8d94a0"/>
<path d="M158 238 L158 244 M166 238 L166 244" stroke="#5d6370" stroke-width="4"/>`,
    cloth: `<path d="M70 148 Q118 136 166 148 L170 194 Q118 208 64 196 Z" fill="#c9503f"/>
<path d="M76 155 Q118 145 160 155" fill="none" stroke="#93362b" stroke-width="5"/>
<path d="M88 176 L96 167 L104 176 M132 176 L140 167 L148 176" fill="none" stroke="#93362b" stroke-width="4"/>
<path d="M66 192 Q118 206 168 192" fill="none" stroke="#e2c36e" stroke-width="9"/>
<circle cx="118" cy="172" r="12" fill="#e2c36e" stroke-width="5"/>
<circle cx="118" cy="172" r="5" fill="none" stroke="#93362b" stroke-width="3"/>`,
    earB: `<path d="M150 100 L144 44 L180 80 Z" fill="#5d6370"/>`,
    earF: `<path d="M180 84 L200 28 L220 86 Z" fill="#8d94a0"/>
<path d="M190 80 L200 46 L210 82 Z" fill="#e4c6bd" stroke="none"/>`,
    mouth: `<path d="M196 142 L244 136 Q242 172 216 178 Q198 170 196 142 Z" fill="#5a2420"/>`,
    jaw: `<path d="M198 162 Q222 170 244 154 L242 166 Q228 186 198 176 Z" fill="#dfe2e6" stroke-width="5"/>
<path d="M210 171 Q222 166 234 162" fill="none" stroke="#d9706a" stroke-width="4"/>
<path d="M214 170 L218 156 L223 168 Z M230 165 L235 152 L239 162 Z" fill="#f5ecd8" stroke-width="4"/>`,
    head: `<path d="M140 118 Q140 82 176 78 Q204 76 214 100 L244 112 Q254 120 246 132 L216 146 Q196 160 170 158 Q142 152 140 118 Z" fill="#8d94a0"/>
<path d="M194 128 Q214 118 246 116 Q252 124 246 130 L216 144 Q198 146 194 128 Z" fill="#dfe2e6" stroke="none"/>
<path d="M160 92 Q182 82 206 98 L200 106 Q184 94 166 100 Z" fill="#5d6370" stroke="none"/>
<path d="M150 136 Q164 150 186 150 Q172 140 166 128 Z" fill="#dfe2e6" stroke="none"/>
<ellipse cx="246" cy="117" rx="8" ry="6" fill="#2b2220" stroke-width="4"/>
<path d="M206 142 L210 156 L215 142 Z M228 138 L232 152 L237 137 Z" fill="#f5ecd8" stroke-width="4"/>`,
    collar: `<path d="M150 92 L132 100 L144 110 L124 118 L142 128 L122 140 L144 146 L130 160 L152 160 L146 176 L166 168 L172 182 Q148 158 150 92 Z" fill="#b6bcc6"/>
<path d="M140 120 L150 122 M138 144 L150 144 M150 160 L158 158" fill="none" stroke="#5d6370" stroke-width="4"/>`,
    face: `<path d="M172 100 L202 108" stroke="#2b2220" stroke-width="7" stroke-linecap="round"/>
<path d="M180 116 Q192 106 204 114 Q192 124 180 116 Z" fill="#ffc83d" stroke="#2b2220" stroke-width="3.5" stroke-linejoin="round"/>
<ellipse cx="193" cy="115" rx="2.6" ry="5" fill="#2b2220"/>
<circle cx="190" cy="112" r="1.6" fill="#fff"/>`,
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
  points: { eye: ['head', 192, 114], bite: ['head', 228, 158], nose: ['head', 246, 117] },
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
