// JS side of the parity trace: node sim/trace_js.cjs <path to the JS hon-song-nui repo> > js.txt; diff against sim/trace.gd output
const path = require('path');
const G = require(path.join(process.argv[2], 'scripts/load.cjs'));
let seed = 1;
const rng = () => ((seed = (seed * 1103515245 + 12345) % 2147483648) / 2147483648);
G.aiRng = rng;
const fnv = (h, str) => { for (let i = 0; i < str.length; i++) { h ^= str.charCodeAt(i); h = Math.imul(h, 16777619) >>> 0; } return h; };
function stepStr(st) {
  if (!st) return 'E';
  if (st.kind === 'buy') return `b${st.x},${st.y}:${st.type}`;
  const a = st.act, t = a.target == null ? '' : Array.isArray(a.target) ? a.target.join(',') : a.target;
  return `a${a.id}>${a.to[0]},${a.to[1]}:${a.kind}:${t}`;
}
function play(def, naive) {
  const s = G.newGame(def);
  let mem = {}, steps = 0, h = 2166136261;
  while (!s.winner && s.turn <= 60) {
    const step = naive && s.side === 'p' ? G.aiRandomStep(s, rng) : G.aiNextStep(s, mem);
    h = fnv(h, stepStr(step) + ';');
    if (!step) { G.endTurn(s); mem = {}; continue; }
    G.applyStep(s, step);
    steps++;
  }
  for (const u of s.units) h = fnv(h, `${u.id}:${u.x},${u.y}:${u.hp}:${u.xp}:${u.rank};`);
  h = fnv(h, `g${s.gold.p},${s.gold.e}`);
  return `${s.winner || 'draw'} ${s.reason || 'timeout'} t${s.turn} n${steps} ${h.toString(16)}`;
}
const runs = [];
for (const m of G.CAMPAIGN) runs.push([m.id, 20, () => m, false]);
const heroes = G.look.heroesOf('p');
runs.push(['skirmish', 12, (g) => G.skirmishDef('dong_bang', heroes[g % 3], false), false]);
runs.push(['skirmish-easy', 12, (g) => G.skirmishDef('dong_bang', heroes[g % 3], true), false]);
runs.push(['naive', 10, () => G.skirmishDef('dong_bang', heroes[0], false), true]);
for (const [label, n, mk, naive] of runs)
  for (let g = 0; g < n; g++) { seed = 1000 + g * 7919; console.log(`${label} ${g} ${play(mk(g), naive)}`); }
