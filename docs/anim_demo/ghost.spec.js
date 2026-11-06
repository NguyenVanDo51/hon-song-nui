// Âm binh (ghost, range 1) -> "Âm kiếm": broken sword grows a spectral blade, drift-forward purple slash, fade-drift back.
// Parts = verbatim blocks of assets/units/styles/chibi/ghost_p.svg; `ghostBlade` = effect-only part (not in the static art).

// shared impact: same for all units (game-wide hit feel)
const HIT = { stop: 90, amp: 9, kx: 420, debris: 'spark', n: 8, sparkColor: '#ffe08a', cut: true, cutAng: -24 };
const HIT_SMALL = { small: true, stop: 45, amp: 4, kx: 0, debris: 'spark', n: 3, sparkColor: '#ffe08a', cut: false };

const SPIRIT = '#b48cff', SPIRIT_CORE = '#f1eaff', GHOST = '#d9d4f0';
const TIP = bake(14, 198, 168, 198, 12);    // sword group has rotate(14 198 168); spectral tip
const MID = bake(14, 198, 168, 198, 104);
const SWORD_G = s => `<g transform="rotate(14 198 168)">\n${s}\n</g>`;

// drift track shared by tr.x and the afterimage hook
const X = track([[0, 0], [190, -10, 'out'], [245, -10], [315, 36, 'outExpo'], [600, 40, 'out'], [700, 40], [1000, 0, 'io']]);
const GHOST_IMG = new Image();
GHOST_IMG.src = 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(__SVG.full.replace(/width="256" height="256"/, 'width="768" height="768"'));

// rising ghost wisp: flame-like teardrop, flat fill + INK, sways up and fades (one-shot fx, owns its state)
function wisps(api, x, y, n, o = {}) {
  for (let i = 0; i < n; i++) {
    const q = { x: x + rnd(-(o.sx ?? 18), o.sx ?? 18), y: y + rnd(-(o.sy ?? 14), o.sy ?? 14), vx: (o.vx ?? 0) + rnd(-40, 40), vy: -rnd(60, 130),
      r: rnd(9, 15) * (o.size ?? 1), life: rnd(520, 820), age: 0, ph: rnd(0, 6) };
    api.add({
      upd(s, ms) { q.age += ms; q.vx *= 1 - 2 * s; q.x += (q.vx + 40 * Math.sin(q.age / 120 + q.ph)) * s; q.y += q.vy * s; return q.age < q.life; },
      draw(ctx, cam, layer) {
        if (layer !== 'front') return;
        const u = q.age / q.life, r = q.r * (1 - .45 * u), sway = 10 * Math.sin(q.age / 90 + q.ph);
        ctx.setTransform(cam.translate(q.x, q.y)); ctx.globalAlpha = u < .1 ? u / .1 : 1 - (u - .1) / .9;
        ctx.beginPath(); ctx.arc(0, 0, r, Math.PI, 0, true);
        ctx.quadraticCurveTo(r, -1.7 * r, sway, -3.3 * r); ctx.quadraticCurveTo(-r * .3, -1.4 * r, -r, 0); ctx.closePath();
        ctx.fillStyle = GHOST; ctx.fill(); ctx.strokeStyle = INK; ctx.lineWidth = 3; ctx.lineJoin = 'round'; ctx.stroke();
        ctx.beginPath(); ctx.arc(0, -r * .1, r * .42, 0, Math.PI * 2); ctx.fillStyle = SPIRIT; ctx.fill();
        ctx.globalAlpha = 1;
      },
    });
  }
}

const SPEC = {
  title: 'Âm binh · Âm kiếm',
  subtitle: 'Hồn lính tử trận được thầy mo gọi về · lưỡi kiếm gãy mọc lưỡi ma tím',
  feet: 244, cx: 128, range: 1, shadowR: 50,
  parts: {
    bandT: `<path d="M80 86 Q58 76 36 84 L46 90 L38 98 Q60 90 80 96 Z" fill="#c9503f" stroke-width="5"/>
<path d="M78 94 Q56 100 42 120 L54 115 L52 126 Q64 110 82 104 Z" fill="#c9503f" stroke-width="5"/>
<path d="M52 92 L64 91" stroke="#93362b" stroke-width="3"/>`,
    tail: `<path d="M102 184 L160 184 Q166 220 138 236 Q110 248 80 240 Q58 234 44 212 Q66 228 86 224 Q106 218 102 184 Z" fill="#d9d4f0"/>
<path d="M44 212 Q34 200 42 190" fill="none" stroke-width="5"/>
<path d="M148 202 Q146 222 122 232 M92 234 Q76 232 64 222" fill="none" stroke="#b8aedb" stroke-width="5"/>`,
    torso: `<path d="M100 128 Q128 118 156 128 L164 200 L152 194 L142 204 L132 194 L120 204 L110 194 L98 202 L92 196 Z" fill="#d9d4f0"/>
<path d="M112 142 L106 160 M118 170 L112 186" stroke="#b8aedb" stroke-width="5"/>
<path d="M106 134 L156 182" stroke="#2b2220" stroke-width="22"/>
<path d="M106 134 L156 182" stroke="#c9503f" stroke-width="10"/>
<path d="M150 180 L164 214 L154 207 L148 218 L140 188 Z" fill="#c9503f" stroke-width="5"/>
<path d="M120 148 L128 156" stroke="#93362b" stroke-width="4"/>`,
    head: `<circle cx="130" cy="84" r="54" fill="#d9d4f0"/>
<path d="M77 82 Q72 46 98 32 L100 14 L118 26 L134 8 L144 26 L166 20 L164 38 Q186 54 184 80 Q162 60 132 62 Q102 62 77 82 Z" fill="#8f84bd" stroke-width="5"/>
<path d="M77 72 Q130 52 183 72 L184 90 Q130 70 78 92 Z" fill="#c9503f"/>
<path d="M82 82 Q130 64 181 81" fill="none" stroke="#93362b" stroke-width="4"/>
<path d="M126 64 L122 74 L130 72" fill="none" stroke="#93362b" stroke-width="3"/>
<circle cx="80" cy="90" r="8" fill="#c9503f" stroke-width="5"/>`,
    face: `<path d="M132 95 L146 90 M160 90 L174 95" stroke="#2b2220" stroke-width="3" stroke-linecap="round"/>
<ellipse cx="142" cy="107" rx="8.5" ry="10.5" fill="#2b2220"/>
<ellipse cx="166" cy="107" rx="8.5" ry="10.5" fill="#2b2220"/>
<circle cx="142" cy="108" r="5" fill="#b48cff"/>
<circle cx="166" cy="108" r="5" fill="#b48cff"/>
<circle cx="143.5" cy="106" r="2" fill="#f4efff"/>
<circle cx="167.5" cy="106" r="2" fill="#f4efff"/>
<ellipse cx="168" cy="121" rx="5" ry="3.5" fill="#b8aedb"/>
<ellipse cx="153" cy="125" rx="4" ry="5.5" fill="#2b2220"/>`,
    arm: `<path d="M150 146 Q174 156 196 166" fill="none" stroke="#2b2220" stroke-width="24"/>
<path d="M150 146 Q174 156 196 166" fill="none" stroke="#d9d4f0" stroke-width="12"/>
<path d="M178 152 L174 164 M186 156 L184 168" stroke="#b8aedb" stroke-width="4"/>`,
    // spectral blade continuing from the jagged break (effect part, alpha `gb`)
    ghostBlade: SWORD_G(`<path d="M191 94 L188 40 L198 12 L208 40 L205 90 L203 80 L199 94 L196 86 Z" fill="${SPIRIT}" stroke-width="5"/>
<path d="M198 84 L198 34" stroke="${SPIRIT_CORE}" stroke-width="6"/>`),
    sword: `<g transform="rotate(14 198 168)">
<rect x="193" y="156" width="10" height="36" rx="3" fill="#3a2e28" stroke-width="5"/>
<circle cx="198" cy="196" r="6" fill="#e2c36e" stroke-width="5"/>
<path d="M191 150 L191 94 L196 86 L199 94 L203 80 L205 90 L205 150 Z" fill="#cdd4da" stroke-width="5"/>
<path d="M198 146 L198 100" stroke="#aab3bd" stroke-width="4"/>
<rect x="182" y="146" width="32" height="10" rx="4" fill="#e2c36e" stroke-width="5"/>
</g>`,
    hand: `<circle cx="198" cy="168" r="12" fill="#d9d4f0" stroke-width="5"/>`,
  },
  raw: ['face'],
  bones: [
    { name: 'body', pivot: [128, 196], ch: 'lean' },
    { name: 'tail', parent: 'body', pivot: [130, 186], ch: 'tail', stretch: true },
    { name: 'head', parent: 'body', pivot: [130, 138], ch: 'head' },
    { name: 'band', parent: 'head', pivot: [80, 90], ch: 'band' },
    { name: 'arm', parent: 'body', pivot: [150, 146], ch: 'arm' },
    { name: 'sword', parent: 'arm', pivot: [198, 168], ch: 'wrist' },
  ],
  // source order; every entry fades with `ga` (fade-drift back), the spectral blade with `gb`
  draw: [['bandT', 'band', 'ga'], ['tail', 'tail', 'ga'], ['torso', 'body', 'ga'], ['head', 'head', 'ga'], ['face', 'head', 'ga'],
         ['arm', 'arm', 'ga'], ['ghostBlade', 'sword', 'gb'], ['sword', 'sword', 'ga'], ['hand', 'arm', 'ga']],
  points: { tip: ['sword', TIP[0], TIP[1]], mid: ['sword', MID[0], MID[1]] },
  springs: {
    tail: { k: 110, c: 8, drive: (p, vx, c) => clamp(vx * .035, -18, 34) + p.lean * .5 + (c.idle ? 5 * Math.sin(c.clock / 520) : 0) },
    band: { k: 200, c: 9, drive: (p, vx, c) => clamp(vx * .04, -14, 30) + p.lean * .6 + p.head * .6 + (c.idle ? 3 * Math.sin(c.clock / 600) : 0) },
  },
  // hover bob (b = 0 at load -> rest check stays aligned)
  idle(p, b) { p.y = -5 * b; p.sy = 1 + .012 * b; p.head = 1.5 * b; p.arm = 2 * b; p.wrist = -1.5 * b; },
  attacks: [
    {
      id: 'slash', label: '👻 Âm kiếm', dur: 1250,
      tr: {
        x: X,
        y: track([[0, 0], [190, -16, 'out'], [245, -18], [315, -4, 'outExpo'], [600, -6], [820, -14, 'io'], [1180, 0, 'io']]),
        sy: track([[0, 1], [190, .9, 'out'], [245, .89], [300, 1.16, 'outExpo'], [420, .97, 'out'], [560, 1, 'out']]),
        lean: track([[0, 0], [190, -10, 'out'], [245, -11], [315, 16, 'outExpo'], [600, 12, 'out'], [1050, 0, 'io']]),
        head: track([[0, 0], [190, -7, 'out'], [245, -7], [315, 7, 'outExpo'], [600, 4], [1050, 0, 'io']]),
        arm: track([[0, 0], [190, -60, 'outBack'], [245, -62], [310, 54, 'outExpo'], [600, 46, 'out'], [1050, 0, 'io']]),
        wrist: track([[0, 0], [190, 30, 'outBack'], [245, 32], [310, 40, 'outExpo'], [600, 30, 'out'], [1050, 0, 'io']]),
        gb: track([[0, 0], [70, 0], [190, 1, 'out'], [460, 1], [600, 0, 'out']]),
        ga: track([[0, 1], [620, 1], [740, .45, 'out'], [960, .45], [1180, 1, 'io']]),
      },
      ev: [
        [110, a => wisps(a, a.point('tip').x, a.point('tip').y, 2, { size: .8 })],
        [200, a => a.gleam('tip')],
        [250, a => wisps(a, 120, 214, 3, { vx: -120 })],
        [262, a => a.flash('#d9c6ff', 50)],
        [265, a => a.wave({ x: 226, y: 150, vx: 1500, R: 116, fill: SPIRIT, inner: SPIRIT_CORE, hit: Object.assign({}, HIT, { dmg: 45 }) })],
        [285, a => { const q = a.point('tip'); wisps(a, q.x, q.y, 3, { vx: 160 }); }],
        [345, a => { const c = a.target(); wisps(a, c.x, c.y, 5, { sx: 34, sy: 34, vx: 120 }); }],
        [650, a => { const h = a.hero(); wisps(a, h.x, h.y + 20, 5, { sx: 40, sy: 50, vx: -90 }); }],
        [780, a => { const h = a.hero(); wisps(a, h.x - 40, h.y + 70, 2, { sx: 24, sy: 10, vx: -80, size: .8 }); }],
      ],
      smear: { tip: 'tip', base: 'mid', from: 248, to: 365, window: 50, fill: SPIRIT, inner: SPIRIT_CORE },
      // afterimage echoes trailing the drift (stateless: from the X track)
      draw(ctx, cam, api, layer, t) {
        if (layer !== 'mid' || !GHOST_IMG.complete) return;
        if (t < 250 || t > 420) return;   // forward drift only (rest-pose echoes clash with the faded body on the way back)
        const fade = 1 - Math.max(0, t - 330) / 90;
        for (const [lag, a] of [[45, .32], [95, .16]]) {
          const dx = X(Math.max(0, t - lag));
          if (Math.abs(dx - api.pose.x) < 4) continue;
          ctx.setTransform(cam.translate(dx, api.pose.y)); ctx.globalAlpha = a * fade;
          ctx.drawImage(GHOST_IMG, 0, 0, 256, 256);
        }
        ctx.globalAlpha = 1;
      },
    },
  ],
};
