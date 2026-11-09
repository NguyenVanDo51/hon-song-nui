// Sfx synth v2, style C "nhạc cụ gõ" (user pick 2026-11-09): every action is a pitched mallet (bell / marimba)
// in D (music BASE D3 = 146.83 Hz) + soft noise layers, through one shared bus (warmth + room + loudness target),
// so the whole set sounds like one family. Frequent action sounds get 3 variants (game picks one at random).
// run: node tools/sfx/synth.mjs [out dir = assets/sfx] [--manifest]   then once: godot --headless --path . --import
//   -> s_<key>.wav (1 variant) / s_<key>_<n>.wav (variants) + PCM .import files; stale files of these keys are removed;
//   --manifest also writes synth.json (review page). Prints a check table. s_select.wav is not made here (user kept the old one).
import fs from "node:fs";
import path from "node:path";
import { SR, buf, hz, modal, thud, noise, bus, wav, db, loudness, centroid } from "./dsp.mjs";

const BUS = { lp: 9000, drive: 1.1, room: { size: 0.7, damp: 0.35, wet: 0.3, tail: 1.2 } };

// bell mallet (celesta-like) and wooden marimba bar
const bell = (b, at, s, vol = 1, len = 1.0) =>
	modal(b, at, { f: hz(s), vol, ratios: [1, 2.0, 3.0, 4.16], decays: [len, len * 0.4, len * 0.25, len * 0.12], amps: [1, 0.25, 0.12, 0.06], atk: 0.002 });
const wood = (b, at, s, vol = 1, len = 0.3) =>
	modal(b, at, { f: hz(s), vol, ratios: [1, 3.93, 9.2], decays: [len, len * 0.3, len * 0.1], amps: [1, 0.3, 0.08], atk: 0.001 });

// key: { label, target dBFS (max 50 ms RMS), len s, variants, fn(b, v, seed) }
const SOUNDS = {
	ui: { label: "Bấm nút", target: -26, len: 0.5, fn: (b) => bell(b, 0, 19, 1, 0.35) },
	page: {
		label: "Mở bảng / lật giấy", target: -25, len: 0.6,
		fn: (b) => {
			noise(b, 0, { dur: 0.14, f: 1200, f2: 4000, q: 1.2, atk: 0.04, dec: 0.08, vol: 0.6, seed: 11 });
			bell(b, 0.05, 24, 0.35, 0.3);
		},
	},
	move: {
		label: "Quân đi", target: -27, len: 0.5, variants: 3,
		fn: (b, v, seed) => {
			const [a, c] = [[5, 0], [7, 2], [3, 0]][v];
			wood(b, 0, a, 0.8, 0.12);
			wood(b, 0.09, c, 0.6, 0.12);
			noise(b, 0, { dur: 0.04, f: 900, type: "lp", vol: 0.25, seed });
			noise(b, 0.09, { dur: 0.04, f: 900, type: "lp", vol: 0.2, seed: seed + 1 });
		},
	},
	slash: {
		// user 2026-11-09: softer + lower than the first C draft (600->2200 Hz sweep, A3 bell, -18)
		label: "Vung kiếm", target: -20, len: 0.9, variants: 3,
		fn: (b, v, seed) => {
			noise(b, 0, { dur: 0.28, f: [380, 420, 350][v], f2: [1300, 1450, 1200][v], q: 1.2, type: "lp", atk: 0.12, dec: 0.12, seed });
			bell(b, 0.12, [0, 2, -2][v], 0.3, 0.45);
		},
	},
	hit: {
		label: "Trúng đòn", target: -15, len: 0.8, variants: 3,
		fn: (b, v, seed) => {
			thud(b, 0, { f: [140, 150, 130][v], f2: 60, dur: 0.2, vol: 0.8 });
			bell(b, 0, [0, 3, -2][v], 0.6, 0.5);
			noise(b, 0, { dur: 0.05, f: 1500, type: "lp", vol: 0.6, seed });
		},
	},
	heavy: {
		label: "Đòn nặng / đá rơi", target: -14, len: 1.2, variants: 3,
		fn: (b, v, seed) => {
			thud(b, 0, { f: [110, 120, 100][v], f2: 40, dur: 0.35 });
			bell(b, 0, [-12, -10, -14][v], 0.8, 0.8);
			wood(b, 0.005, [-5, -3, -7][v], 0.5, 0.25);
			noise(b, 0, { dur: 0.14, f: 900, f2: 300, type: "lp", vol: 0.8, seed });
		},
	},
	arrow: {
		label: "Bắn tên", target: -19, len: 0.6, variants: 3,
		fn: (b, v, seed) => {
			bell(b, 0, [26, 24, 29][v], 0.3, 0.2); // bowstring
			noise(b, 0.01, { dur: 0.17, f: 2500, f2: 5200, q: 3, atk: 0.02, dec: 0.12, vol: 0.9, seed });
		},
	},
	orb: {
		label: "Pháp sư bắn cầu phép", target: -19, len: 1.0, variants: 3,
		fn: (b, v, seed) => {
			[[26, 31, 36], [24, 28, 33], [29, 33, 38]][v].forEach((s, i) => bell(b, i * 0.045, s, 0.7 - i * 0.12, 0.45));
			noise(b, 0, { dur: 0.3, f: 6000, type: "hp", atk: 0.05, dec: 0.25, vol: 0.12, seed });
		},
	},
	rock: {
		label: "Máy bắn đá phóng", target: -18, len: 0.9, variants: 3,
		fn: (b, v, seed) => {
			thud(b, 0, { f: 90, f2: 60, dur: 0.15, vol: 0.8 });
			wood(b, 0, [-5, -7, -3][v], 0.9, 0.25);
			noise(b, 0.04, { dur: 0.32, f: 300, f2: 900, q: 1.2, atk: 0.14, dec: 0.15, vol: 0.9, seed });
		},
	},
	die: {
		label: "Quân chết", target: -20, len: 1.4, variants: 3,
		fn: (b, v, seed) => {
			const [a, c] = [[3, 0], [5, 2], [7, 3]][v];
			bell(b, 0, a, 0.7, 0.5);
			bell(b, 0.16, c, 0.6, 0.9);
			noise(b, 0, { dur: 0.45, f: 800, f2: 250, type: "lp", atk: 0.02, dec: 0.4, vol: 0.5, seed });
		},
	},
	capture: {
		label: "Chiếm làng / thành", target: -18, len: 2.0,
		fn: (b) => {
			[12, 19].forEach((s, i) => bell(b, i * 0.13, s, 0.8, 0.8));
			[0, 24].forEach((s) => bell(b, 0.26, s, 0.7, 1.4));
		},
	},
	coin: {
		label: "Vàng vào", target: -21, len: 1.2, variants: 3,
		fn: (b, v) => {
			const [a, c] = [[31, 36], [33, 38], [29, 36]][v];
			bell(b, 0, a, 0.7, 0.6);
			bell(b, 0.08, c, 0.8, 0.9);
		},
	},
	rank: {
		label: "Lên cấp / quân mới của ta", target: -19, len: 1.6,
		fn: (b, v, seed) => {
			[24, 31, 36].forEach((s, i) => bell(b, i * 0.06, s, 0.8 - i * 0.1, 0.9));
			noise(b, 0.12, { dur: 0.5, f: 7000, type: "hp", atk: 0.05, dec: 0.4, vol: 0.08, seed });
		},
	},
	raise: {
		label: "Phù thủy hồi sinh xác", target: -19, len: 1.8,
		fn: (b, v, seed) => {
			noise(b, 0, { dur: 0.7, f: 200, f2: 1200, q: 1.5, atk: 0.55, dec: 0.15, vol: 0.6, seed });
			bell(b, 0.5, 0, 0.7, 1.0);
			bell(b, 0.5, 6, 0.55, 1.0); // tritone D-G#: uncanny
			bell(b, 0.62, 12, 0.35, 0.8);
		},
	},
	heal: {
		label: "Hồi máu", target: -21, len: 1.8,
		fn: (b, v, seed) => {
			bell(b, 0, 24, 0.6, 1.2);
			bell(b, 0.03, 31, 0.5, 1.2);
			bell(b, 0.2, 38, 0.45, 1.0);
			noise(b, 0, { dur: 0.6, f: 8000, type: "hp", atk: 0.2, dec: 0.4, vol: 0.06, seed });
		},
	},
	drum: {
		label: "Báo lượt (băng rôn Lượt N)", target: -21, len: 1.8,
		fn: (b) => {
			bell(b, 0, 31, 0.8, 1.5);
			bell(b, 0.09, 38, 0.5, 1.3);
			bell(b, 0.18, 43, 0.2, 1.0);
		},
	},
	spawn: {
		label: "Quân địch mới xuất hiện", target: -19, len: 1.8,
		fn: (b, v, seed) => {
			noise(b, 0, { dur: 0.6, f: 150, f2: 500, q: 1.2, atk: 0.4, dec: 0.2, vol: 0.5, seed });
			bell(b, 0.35, -12, 0.8, 1.3);
			bell(b, 0.35, -5, 0.5, 1.1);
			bell(b, 0.5, 3, 0.3, 0.9);
		},
	},
	win: {
		label: "Thắng (1–2 s)", target: -18, len: 2.4,
		fn: (b) => {
			[24, 31].forEach((s, i) => bell(b, i * 0.12, s, 0.8, 0.9));
			[12, 36].forEach((s) => bell(b, 0.26, s, 0.7, 1.6));
		},
	},
	lose: {
		label: "Thua (1–2 s)", target: -19, len: 2.4,
		fn: (b) => {
			[19, 15, 12].forEach((s, i) => bell(b, i * 0.18, s, 0.8, 1.2));
			bell(b, 0.36, 0, 0.5, 1.4);
		},
	},
};

const args = process.argv.slice(2);
const out = args.find((a) => !a.startsWith("--")) ?? "assets/sfx";
fs.mkdirSync(out, { recursive: true });
// import as plain PCM (Godot's default QOA is lossy); same params tools used before
const IMPORT = '[remap]\n\nimporter="wav"\ntype="AudioStreamWAV"\n\n[params]\n\ncompress/mode=0\n';
const manifest = [];
const rows = [];
const made = new Set();
for (const [key, s] of Object.entries(SOUNDS)) {
	const n = s.variants || 1;
	for (let v = 0; v < n; v++) {
		const b = buf(s.len);
		s.fn(b, v, 101 + v * 17);
		const y = bus(b, { ...BUS, target: s.target });
		const file = n > 1 ? `s_${key}_${v + 1}.wav` : `s_${key}.wav`;
		fs.writeFileSync(path.join(out, file), wav(y));
		if (!fs.existsSync(path.join(out, file + ".import"))) fs.writeFileSync(path.join(out, file + ".import"), IMPORT);
		made.add(file);
		manifest.push({ key, label: s.label, variant: v + 1, file });
		let pk = 0, dc = 0;
		for (const x of y) { pk = Math.max(pk, Math.abs(x)); dc += x; }
		rows.push([file, (y.length / SR).toFixed(2), db(pk).toFixed(1), db(loudness(y)).toFixed(1), s.target,
			Math.round(centroid(y)), (dc / y.length).toExponential(0), y[0].toFixed(3), y[y.length - 1].toFixed(3)]);
	}
}
// drop stale files of the keys made here (e.g. s_hit.wav once hit has variants)
for (const f of fs.readdirSync(out)) {
	const m = f.match(/^s_([a-z]+)(?:_\d+)?\.wav(\.import)?$/);
	if (m && SOUNDS[m[1]] && !made.has(f.replace(/\.import$/, ""))) fs.rmSync(path.join(out, f));
}
if (args.includes("--manifest")) fs.writeFileSync(path.join(out, "synth.json"), JSON.stringify(manifest, null, 1));
console.log(["file", "sec", "peak", "loud", "target", "centroid", "dc", "first", "last"].join("\t"));
for (const r of rows) console.log(r.join("\t"));
