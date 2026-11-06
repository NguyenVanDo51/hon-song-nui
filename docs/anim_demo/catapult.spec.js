// Máy bắn đá (catapult_p.svg) · range 3 (rules.gd rmin 2 / rmax 4).
// Operator hauls the winch lever -> arm ratchets back (creak, frame squash) -> trigger -> arm whips into the
// crossbar, rear of the cart kicks up -> boulder flies a high arc over 3 tiles -> smash: shared HIT + rock debris + dust ring.

// shared impact: same for all units (game-wide hit feel)
const HIT = { stop: 90, amp: 9, kx: 420, debris: 'spark', n: 8, sparkColor: '#ffe08a', cut: true, cutAng: -24 };
const HIT_SMALL = { small: true, stop: 45, amp: 4, kx: 0, debris: 'spark', n: 3, sparkColor: '#ffe08a', cut: false };
// main hit:   api.hit(Object.assign({}, HIT, { dmg: 42 }))     or  wave/projectile/tornado { hit: Object.assign({}, HIT, { dmg: 42 }) }
// multi-tick: Object.assign({}, HIT_SMALL, { dmg: 6 }) for the small ticks before the final HIT

const REL = 665, FLY = 640, LAND = REL + FLY;     // boulder release / flight ms / impact
const STONE = '#9b958c', STONE_D = '#7a746c', SAND = '#efe3c8';

// stone chunks: one-shot fx, own state
function rockDebris(api, x, y) {
  const bits = [];
  for (let i = 0; i < 9; i++) {
    const a = -Math.PI * (.12 + .76 * i / 8) + rnd(-.12, .12), v = rnd(380, 720);
    bits.push({ x: x + rnd(-14, 14), y: y - rnd(0, 20), vx: Math.cos(a) * v, vy: Math.sin(a) * v, r: rnd(7, 14), rot: rnd(0, 6), vr: rnd(-12, 12), bounced: false, k: (i % 3) / 2 });
  }
  let age = 0; const FEET = api.target().feet, LIFE = 820;
  api.add({
    upd(s, ms) {
      age += ms;
      for (const b of bits) {
        b.vy += 1900 * s; b.x += b.vx * s; b.y += b.vy * s; b.rot += b.vr * s;
        if (b.y > FEET - b.r * .6 && b.vy > 0) { b.y = FEET - b.r * .6; b.vy *= b.bounced ? 0 : -.32; b.vx *= .45; b.vr *= .5; b.bounced = true; }
      }
      return age < LIFE;
    },
    draw(ctx, cam, layer) {
      if (layer !== 'front') return;
      const fade = age > LIFE - 220 ? (LIFE - age) / 220 : 1;
      for (const b of bits) {
        ctx.setTransform(cam.translate(b.x, b.y).rotate(b.rot * 57.3)); ctx.globalAlpha = fade;
        ctx.beginPath(); ctx.moveTo(-b.r, -b.r * .3); ctx.lineTo(-b.r * .2, -b.r); ctx.lineTo(b.r, -b.r * .4); ctx.lineTo(b.r * .6, b.r * .8); ctx.lineTo(-b.r * .7, b.r * .6); ctx.closePath();
        ctx.fillStyle = b.k > .6 ? STONE_D : STONE; ctx.fill(); ctx.strokeStyle = INK; ctx.lineWidth = 4; ctx.lineJoin = 'round'; ctx.stroke();
      }
      ctx.globalAlpha = 1;
    },
  });
}

const SPEC = {
  title: 'Máy bắn đá · Nện đá tảng',
  subtitle: 'Kéo cần tời → cần ném ghì ra sau (kẽo kẹt) → bật mạnh vào xà chặn → đá tảng bay vòng cung 3 ô → nện vỡ.',
  feet: 244, cx: 128, range: 3, shadowR: 118,
  parts: {
    pole: `<line x1="218" y1="104" x2="218" y2="20" stroke-width="13"/>
<line x1="218" y1="104" x2="218" y2="20" stroke="#6b4a2e" stroke-width="5"/>`,
    flag: `<path d="M221 22 Q238 28 253 40 Q238 52 221 66 Z" fill="#c9503f" stroke-width="5"/>
<path d="M226 42 L242 41" stroke="#93362b" stroke-width="4"/>`,
    aframe: `<line x1="180" y1="178" x2="206" y2="122" stroke-width="22"/>
<line x1="180" y1="178" x2="206" y2="122" stroke="#a87a4c" stroke-width="10"/>
<line x1="238" y1="178" x2="226" y2="122" stroke-width="22"/>
<line x1="238" y1="178" x2="226" y2="122" stroke="#a87a4c" stroke-width="10"/>
<rect x="194" y="100" width="44" height="26" rx="11" fill="#c9503f"/>
<path d="M207 103 L207 123 M224 103 L224 123" stroke="#93362b" stroke-width="5"/>`,
    arm: `<line x1="154" y1="188" x2="112" y2="100" stroke-width="26"/>
<line x1="154" y1="188" x2="112" y2="100" stroke="#a87a4c" stroke-width="13"/>
<path d="M131 126 L139 142" stroke="#aab3bd" stroke-width="6"/>`,
    bucket: `<path d="M78 76 Q80 106 108 106 Q136 106 138 76 Z" fill="#6b4a2e"/>
<path d="M88 90 Q96 98 108 98" fill="none" stroke="#5a4a3c" stroke-width="4"/>
<path d="M74 76 L142 76" stroke-width="10"/>
<path d="M74 76 L142 76" stroke="#a87a4c" stroke-width="3"/>`,
    rock: `<circle cx="108" cy="54" r="23" fill="#9b958c"/>
<path d="M95 49 Q99 39 109 37" fill="none" stroke="#c9c3b9" stroke-width="5"/>`,
    base: `<rect x="70" y="174" width="174" height="26" rx="9" fill="#a87a4c"/>
<path d="M80 192 L234 192" stroke="#6b4a2e" stroke-width="5"/>
<rect x="70" y="174" width="11" height="26" fill="#aab3bd" stroke-width="5"/>
<rect x="233" y="174" width="11" height="26" fill="#aab3bd" stroke-width="5"/>
<circle cx="150" cy="178" r="12" fill="#aab3bd" stroke-width="5"/>
<circle cx="150" cy="178" r="4" fill="#5a4a3c" stroke-width="3"/>
<path d="M136 198 L176 198 L176 230 L166 223 L156 232 L146 223 L136 230 Z" fill="#c9503f"/>
<path d="M136 207 L176 207" stroke="#93362b" stroke-width="5"/>
<circle cx="156" cy="217" r="6" fill="#e2c36e" stroke-width="4"/>`,
    wheels: `<circle cx="104" cy="214" r="28" fill="#6b4a2e"/>
<circle cx="104" cy="214" r="18" fill="#a87a4c" stroke-width="5"/>
<path d="M86 214 L122 214 M104 196 L104 232" stroke="#6b4a2e" stroke-width="5"/>
<circle cx="208" cy="214" r="28" fill="#6b4a2e"/>
<circle cx="208" cy="214" r="18" fill="#a87a4c" stroke-width="5"/>
<path d="M190 214 L226 214 M208 196 L208 232" stroke="#6b4a2e" stroke-width="5"/>
<circle cx="208" cy="214" r="7" fill="#aab3bd" stroke-width="5"/>`,
    lever: `<line x1="104" y1="214" x2="68" y2="184" stroke-width="15"/>
<line x1="104" y1="214" x2="68" y2="184" stroke="#a87a4c" stroke-width="7"/>
<circle cx="104" cy="214" r="8" fill="#aab3bd" stroke-width="5"/>`,
    opBody: `<rect x="21" y="218" width="12" height="20" rx="3" fill="#5a4a3c"/>
<rect x="38" y="218" width="12" height="20" rx="3" fill="#5a4a3c"/>
<rect x="15" y="232" width="21" height="12" rx="5" fill="#3a2e28"/>
<rect x="35" y="232" width="21" height="12" rx="5" fill="#3a2e28"/>
<path d="M20 184 Q36 176 52 184 L57 222 Q36 228 15 222 Z" fill="#c9503f"/>
<path d="M28 188 L28 204" stroke="#93362b" stroke-width="4"/>
<path d="M17 207 L55 207" stroke="#5a4a3c" stroke-width="6"/>`,
    opHead: `<circle cx="36" cy="156" r="26" fill="#f3cfa6"/>
<path d="M10 154 A26 26 0 0 1 62 154 Q48 148 36 148 Q22 148 10 154 Z" fill="#3a2e28" stroke-width="5"/>
<path d="M14 150 L4 142 L6 156 Z" fill="#c9503f" stroke-width="4"/>
<path d="M11 146 Q36 134 61 146 L62 154 Q36 142 10 154 Z" fill="#c9503f" stroke-width="5"/>`,
    opArm: `<path d="M44 197 Q56 196 66 189" fill="none" stroke-width="17"/>
<path d="M44 197 Q56 196 66 189" fill="none" stroke="#c9503f" stroke-width="8"/>
<circle cx="68" cy="187" r="8" fill="#f3cfa6" stroke-width="5"/>`,
    face: `<circle cx="44" cy="165" r="4" fill="#2b2220"/>
<circle cx="56" cy="165" r="4" fill="#2b2220"/>
<circle cx="45.4" cy="163.6" r="1.4" fill="#fff"/>
<circle cx="57.4" cy="163.6" r="1.4" fill="#fff"/>
<ellipse cx="58" cy="174" rx="4" ry="3" fill="#f09a88" opacity="0.6"/>
<path d="M45 175 Q49 178 53 175" fill="none" stroke="#2b2220" stroke-width="2.5" stroke-linecap="round"/>`,
  },
  raw: ['face'],
  bones: [
    { name: 'frame', pivot: [208, 242], ch: 'tilt' },                 // whole cart rocks on the front wheel
    { name: 'flag', parent: 'frame', pivot: [220, 40], ch: 'flag' },
    { name: 'arm', parent: 'frame', pivot: [150, 178], ch: 'arm' },   // pivot = axle hub
    { name: 'bucket', parent: 'arm', pivot: [110, 102], ch: 'bucket' }, // pivot = arm tip
    { name: 'lever', parent: 'frame', pivot: [104, 214], ch: 'lever' }, // winch lever on rear axle
    { name: 'opBody', pivot: [36, 244], ch: 'opLean' },
    { name: 'opHead', parent: 'opBody', pivot: [36, 182], ch: 'opHead' },
    { name: 'opArm', parent: 'opBody', pivot: [44, 197], ch: 'opArm' },
  ],
  draw: [['pole', 'frame'], ['flag', 'flag'], ['aframe', 'frame'], ['arm', 'arm'], ['bucket', 'bucket'], ['rock', 'bucket', 'rockA'],
         ['base', 'frame'], ['wheels', 'frame'], ['lever', 'lever'], ['opBody', 'opBody'], ['opHead', 'opHead'], ['face', 'opHead'], ['opArm', 'opArm']],
  points: { rock: ['bucket', 108, 54], cup: ['bucket', 108, 100], mid: ['arm', 133, 144], hub: ['frame', 150, 178] },
  springs: {
    bucket: { k: 320, c: 13, drive: p => p.arm * .4 },               // sling-like lag + flick after the arm stops
    flag: { k: 140, c: 6, drive: (p, vx, c) => -p.tilt * 3 + (p.flagX || 0) + (c.idle ? 7 * Math.sin(c.clock / 420) : 0) },
  },
  // machine never breathes (no sy); only the crew + flag move at idle
  idle(p, b) { p.opHead = 2 * b; p.opLean = .8 * b; p.opArm = 1.5 * b; },
  attacks: [
    {
      id: 'boulder', label: '🪨 Nện đá tảng', dur: 2050,
      tr: {
        // root squash only while the frame is under tension
        sy: track([[0, 1], [150, 1.01], [520, .95, 'io'], [600, .945], [650, 1.05, 'outExpo'], [760, .98, 'out'], [880, 1, 'io']]),
        tilt: track([[0, 0], [660, 0], [715, 5, 'out'], [790, 0, 'in'], [835, -1, 'out'], [900, 0, 'io']]),
        // ratchet wind-back: steps + creak wobble, hold trembling, whip into the crossbar, bounce, slow re-cock
        arm: track([[0, 0], [150, 3, 'out'], [250, -7, 'out'], [290, -6], [360, -13, 'out'], [400, -12], [470, -20, 'out'],
                    [520, -22, 'out'], [545, -21], [570, -23], [595, -21.5], [610, -22],
                    [680, 55, 'outExpo'], [735, 44, 'out'], [790, 52, 'io'], [1080, 49, 'out'], [1650, 0, 'io']]),
        // lever: lean in, haul back in pumps (matches the ratchet), yank = trigger, let go -> springs forward
        lever: track([[0, 0], [150, 6, 'out'], [250, -10, 'out'], [290, -8], [360, -19, 'out'], [400, -17], [470, -28, 'out'], [520, -30, 'out'],
                      [600, -30], [630, -40, 'out'], [700, 12, 'outBack'], [900, 0, 'io']]),
        opLean: track([[0, 0], [150, 5, 'out'], [520, -11, 'io'], [600, -11], [630, -15, 'out'], [700, -19, 'out'], [900, -8, 'io'], [1250, 0, 'io']]),
        opArm: track([[0, 0], [150, -4, 'out'], [250, 22, 'out'], [290, 20], [360, 38, 'out'], [400, 36], [470, 52, 'out'], [520, 55, 'out'],
                      [600, 55], [630, 68, 'out'], [700, -30, 'outBack'], [950, -24], [1250, 0, 'io']]),
        opHead: track([[0, 0], [150, 4], [520, -6, 'io'], [630, -8], [700, -16, 'out'], [950, -10], [1250, 0, 'io']]),
        rockA: track([[0, 1], [REL - 1, 1], [REL, 0, 'lin'], [1780, 0], [1960, 1, 'out']]),
        flagX: track([[0, 0], [660, 0], [700, -30, 'out'], [860, 0, 'io']]),
      },
      ev: [
        [630, a => a.sparks(68, 190, 4, '#e2c36e')],               // trigger yank
        [672, a => { a.shake(5, 160); a.dust(220, 244, 4, 1); }], // arm slams the crossbar
        [REL, a => a.projectile({
          point: 'rock', kind: 'rock', size: 24, color: STONE, arc: 205, ms: FLY, trail: SAND,
          hit: Object.assign({}, HIT, { dmg: 60 }),                  // rock arrival auto-adds dust + shake(14)
          onArrive: to => {
            const f = a.target().feet;
            a.shockwave(to.x, f, { r: 210, ms: 520, color: SAND });
            a.shockwave(to.x, f, { r: 120, ms: 360, color: '#d9c49a' });
            rockDebris(a, to.x, f - 20);
            a.dust(to.x, f, 10, 0);
          },
        })],
        [800, a => a.dust(104, 244, 6, -1)],                      // rear wheels thud back down
      ],
      smear: { tip: 'rock', base: 'cup', from: 612, to: 715, window: 40, fade: 675 },
      // stateless hooks: creak marks while winding, landing shadow during flight, crater after impact
      draw(ctx, cam, api, layer, t) {
        ctx.lineCap = 'round'; ctx.lineJoin = 'round';
        if (layer === 'front' && t > 200 && t < 610) {
          const h = api.point('hub'), m = api.point('mid'), k = Math.floor(t / 55) % 2;
          for (const [q, r0] of [[h, 26], [m, 30]]) {
            ctx.setTransform(cam.translate(q.x, q.y));
            for (const s of [-1, 1]) {
              ctx.beginPath(); ctx.arc(0, 0, r0 + 7 * k, s < 0 ? Math.PI * .95 : -.25, s < 0 ? Math.PI * 1.25 : .05);
              ctx.strokeStyle = INK; ctx.lineWidth = 7; ctx.stroke(); ctx.strokeStyle = '#fff6d6'; ctx.lineWidth = 3; ctx.stroke();
            }
          }
        }
        const tx = api.target().tileX + 128, f = api.target().feet;
        if (layer === 'back' && t > REL && t < LAND) {
          const u = (t - REL) / FLY;
          ctx.setTransform(cam); ctx.globalAlpha = .12 + .3 * u;
          ctx.beginPath(); ctx.ellipse(tx, f + 2, 24 + 56 * u, 7 + 12 * u, 0, 0, Math.PI * 2); ctx.fillStyle = INK; ctx.fill();
        }
        if (layer === 'back' && t >= LAND) {
          const u = clamp((t - LAND) / 700, 0, 1);
          ctx.setTransform(cam); ctx.globalAlpha = .5 * (1 - u * u);
          ctx.beginPath(); ctx.ellipse(tx, f + 4, 92, 20, 0, 0, Math.PI * 2); ctx.fillStyle = '#6b4a2e'; ctx.fill();
          ctx.strokeStyle = INK; ctx.lineWidth = 4; ctx.stroke();
        }
        ctx.globalAlpha = 1;
      },
    },
  ],
};
