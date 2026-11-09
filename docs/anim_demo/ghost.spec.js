// Bộ Xương (skeleton raised by the necromancer; type `ghost`, range 1) -> "Kiếm ma": broken rusty sword grows a spectral blade,
// drift-forward purple slash, fade-drift back.
// Parts = the art (token SVG generated from them); `ghostBlade` = effect-only part (gb = 0 at rest: not in the token).

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
  title: 'Bộ Xương · Kiếm ma',
  subtitle: 'Bộ xương do Pháp Sư Gọi Hồn dựng dậy · kiếm gỉ gãy mọc lưỡi ma tím',
  feet: 244, cx: 128, range: 1, shadowR: 50,
  parts: {
    // torn team rag tied round the skull: fluttering tails
    bandT: `<path d="M80 86 Q58 76 36 84 L44 88 L38 94 L48 93 Q62 88 80 96 Z" fill="#4f74c9" stroke-width="5"/>
<path d="M78 94 Q56 100 42 120 L52 116 L48 126 L58 118 Q66 108 82 104 Z" fill="#4f74c9" stroke-width="5"/>
<path d="M52 89 L64 88 M60 108 L68 104" stroke="#32508f" stroke-width="3"/>`,
    // dangling leg bones + pelvis + torn dark loincloth (floats: no ground contact)
    tail: `<path d="M116 196 L110 226 M142 196 L148 224" fill="none" stroke="#2b2220" stroke-width="17"/>
<path d="M116 196 L110 226 M142 196 L148 224" fill="none" stroke="#ece6da" stroke-width="7"/>
<circle cx="113" cy="212" r="6" fill="#ece6da" stroke-width="4"/>
<circle cx="145" cy="210" r="6" fill="#ece6da" stroke-width="4"/>
<path d="M98 232 Q100 222 112 224 Q124 226 126 234 Q112 240 98 232 Z" fill="#ece6da" stroke-width="5"/>
<path d="M136 230 Q138 220 150 222 Q162 224 164 232 Q150 238 136 230 Z" fill="#ece6da" stroke-width="5"/>
<path d="M106 184 Q128 176 152 184 L148 198 Q128 204 110 198 Z" fill="#d8d2c6"/>
<path d="M104 188 L154 188 L152 206 L144 200 L138 214 L130 202 L122 216 L116 202 L108 208 Z" fill="#32508f"/>`,
    // spine + ribcage + torn team sash
    torso: `<path d="M126 128 L126 192" stroke="#2b2220" stroke-width="16"/>
<path d="M126 128 L126 192" stroke="#d8d2c6" stroke-width="7"/>
<path d="M102 132 Q128 122 154 132 Q164 154 154 176 Q128 184 102 176 Q92 154 102 132 Z" fill="#ece6da"/>
<path d="M104 150 Q128 158 152 150 M104 164 Q128 172 154 164" fill="none" stroke="#2b2220" stroke-width="5"/>
<path d="M128 134 L128 176" stroke="#d8d2c6" stroke-width="4"/>
<path d="M106 134 L156 182" stroke="#2b2220" stroke-width="22"/>
<path d="M106 134 L156 182" stroke="#4f74c9" stroke-width="10"/>
<path d="M150 180 L164 214 L156 206 L152 220 L146 204 L140 188 Z" fill="#4f74c9" stroke-width="5"/>
<path d="M120 148 L128 156 M138 164 L142 170" stroke="#32508f" stroke-width="4"/>`,
    // small round shield, cracked, a wedge broken out
    shield: `<path d="M98 148 A28 28 0 1 0 110 162 L100 160 L104 154 Z" fill="#a87a4c"/>
<path d="M72 152 L72 192 M96 168 L96 192" fill="none" stroke="#5a4a3c" stroke-width="3"/>
<circle cx="84" cy="172" r="8" fill="#9a7b5a" stroke-width="5"/>
<path d="M78 180 L70 188 L73 194 L66 198" fill="none" stroke="#2b2220" stroke-width="3"/>`,
    // bone-white skull (jaw under the cranium) + torn team rag headband, cracked crown
    head: `<path d="M126 126 Q150 118 182 108 Q188 132 172 148 Q150 156 130 146 Z" fill="#ece6da"/>
<circle cx="130" cy="84" r="54" fill="#ece6da"/>
<path d="M84 112 Q100 134 132 138 Q100 140 84 112 Z" fill="#d8d2c6" stroke="none"/>
<path d="M112 36 L120 46 L112 54 L118 60" fill="none" stroke="#2b2220" stroke-width="3"/>
<path d="M77 66 Q130 46 183 66 L184 84 L172 80 L166 86 L156 78 Q130 70 106 78 L98 84 L92 78 L78 86 Z" fill="#4f74c9"/>
<path d="M82 76 Q130 58 181 75" fill="none" stroke="#32508f" stroke-width="4"/>
<circle cx="80" cy="90" r="8" fill="#4f74c9" stroke-width="5"/>`,
    // dark sockets with green eye flames, nose hole, teeth
    face: `<ellipse cx="142" cy="108" rx="9.5" ry="11" fill="#2b2220"/>
<ellipse cx="168" cy="108" rx="9.5" ry="11" fill="#2b2220"/>
<path d="M142 115 Q135 110 138 103 Q140 106 142 104 Q142 98 146 96 Q149 104 147 110 Q146 115 142 115 Z" fill="#8be37a"/>
<path d="M168 115 Q161 110 164 103 Q166 106 168 104 Q168 98 172 96 Q175 104 173 110 Q172 115 168 115 Z" fill="#8be37a"/>
<circle cx="143" cy="110" r="2" fill="#f4ffef"/>
<circle cx="169" cy="110" r="2" fill="#f4ffef"/>
<path d="M155 120 L151 128 L159 128 Z" fill="#2b2220" stroke="#2b2220" stroke-width="2" stroke-linejoin="round"/>
<rect x="140" y="131" width="36" height="9" rx="3" fill="#ece6da" stroke="#2b2220" stroke-width="3"/>
<path d="M149 131 L149 140 M158 131 L158 140 M167 131 L167 140" stroke="#2b2220" stroke-width="2.5"/>`,
    arm: `<path d="M150 146 Q174 156 196 166" fill="none" stroke="#2b2220" stroke-width="18"/>
<path d="M150 146 Q174 156 196 166" fill="none" stroke="#ece6da" stroke-width="7"/>
<circle cx="174" cy="156" r="6" fill="#ece6da" stroke-width="4"/>`,
    // spectral blade continuing from the jagged break (effect part, alpha `gb`)
    ghostBlade: SWORD_G(`<path d="M191 94 L188 40 L198 12 L208 40 L205 90 L203 80 L199 94 L196 86 Z" fill="${SPIRIT}" stroke-width="5"/>
<path d="M198 84 L198 34" stroke="${SPIRIT_CORE}" stroke-width="6"/>`),
    // rusty broken sword
    sword: `<g transform="rotate(14 198 168)">
<rect x="193" y="156" width="10" height="36" rx="3" fill="#3a2e28" stroke-width="5"/>
<circle cx="198" cy="196" r="6" fill="#9a7b5a" stroke-width="5"/>
<path d="M191 150 L191 94 L196 86 L199 94 L203 80 L205 90 L205 150 Z" fill="#9a7b5a" stroke-width="5"/>
<path d="M198 146 L198 100" stroke="#6f5640" stroke-width="4"/>
<path d="M191 128 L195 124 L191 120 M205 112 L201 108 L205 104" fill="none" stroke="#2b2220" stroke-width="3"/>
<rect x="182" y="146" width="32" height="10" rx="4" fill="#6f5640" stroke-width="5"/>
</g>`,
    hand: `<circle cx="198" cy="168" r="11" fill="#ece6da" stroke-width="5"/>
<path d="M191 164 L205 164 M191 171 L205 171" stroke="#d8d2c6" stroke-width="2.5"/>`,
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
  draw: [['bandT', 'band', 'ga'], ['tail', 'tail', 'ga'], ['torso', 'body', 'ga'], ['shield', 'body', 'ga'], ['head', 'head', 'ga'], ['face', 'head', 'ga'],
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
      id: 'slash', label: '💀 Kiếm ma', dur: 1250,
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
