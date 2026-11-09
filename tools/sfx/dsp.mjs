// Offline DSP building blocks for the sfx synth: generators write into a shared Float32Array,
// bus() applies the shared warmth + room + loudness stage that keeps every sound in one family.
export const SR = 44100;

export function rng(seed) {
	let a = seed >>> 0;
	return () => {
		a = (a + 0x6d2b79f5) >>> 0;
		let t = a;
		t = Math.imul(t ^ (t >>> 15), t | 1);
		t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
		return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
	};
}

export const buf = (sec) => new Float32Array(Math.ceil(sec * SR));
const at0 = (at) => Math.round(at * SR);
export const db = (x) => 20 * Math.log10(Math.max(x, 1e-9));
export const hz = (semi, base = 146.83) => base * 2 ** (semi / 12); // D3 = music BASE in audio.gd

// RBJ biquad, coefficients fixed
export function biquad(type, f, q) {
	const w = (2 * Math.PI * Math.min(f, SR * 0.45)) / SR;
	const c = Math.cos(w), al = Math.sin(w) / (2 * q);
	let b0, b1, b2;
	if (type === "lp") [b0, b1, b2] = [(1 - c) / 2, 1 - c, (1 - c) / 2];
	else if (type === "hp") [b0, b1, b2] = [(1 + c) / 2, -(1 + c), (1 + c) / 2];
	else [b0, b1, b2] = [al, 0, -al]; // bp, 0 dB peak
	const a0 = 1 + al;
	const k = [b0 / a0, b1 / a0, b2 / a0, (-2 * c) / a0, (1 - al) / a0];
	let x1 = 0, x2 = 0, y1 = 0, y2 = 0;
	return (x) => {
		const y = k[0] * x + k[1] * x1 + k[2] * x2 - k[3] * y1 - k[4] * y2;
		x2 = x1; x1 = x; y2 = y1; y1 = y;
		return y;
	};
}

// envelope: linear attack, then exponential decay to -60 dB at `dec` seconds after the attack
const env = (t, atk, dec) => (t < atk ? t / atk : Math.exp((-6.9 * (t - atk)) / dec));

// modal: damped partials (wood / metal / bell / marimba); ratios, decays (s), amps per partial
export function modal(b, at, { f, ratios = [1], decays = [0.3], amps = [1], vol = 1, atk = 0.001 }) {
	const s0 = at0(at);
	ratios.forEach((r, i) => {
		const fr = f * r;
		if (fr > SR * 0.45) return;
		const d = decays[i] ?? decays[decays.length - 1];
		const a = (amps[i] ?? 0.3) * vol;
		const n = Math.min(Math.ceil(d * 1.2 * SR), b.length - s0);
		for (let j = 0; j < n; j++) {
			const t = j / SR;
			b[s0 + j] += a * env(t, atk, d) * Math.sin(2 * Math.PI * fr * t);
		}
	});
}

// tone with exponential pitch glide f -> f2 (thuds / body drops)
export function thud(b, at, { f, f2 = f, dur = 0.2, vol = 1, atk = 0.002 }) {
	const s0 = at0(at), n = Math.min(Math.ceil(dur * 1.2 * SR), b.length - s0);
	let ph = 0;
	for (let j = 0; j < n; j++) {
		const t = j / SR;
		const fr = f * (f2 / f) ** Math.min(1, t / dur);
		ph += (2 * Math.PI * fr) / SR;
		b[s0 + j] += vol * env(t, atk, dur) * Math.sin(ph);
	}
}

// filtered noise; cutoff glides f -> f2 (exp), env: attack atk, decay dec (or swell: peak at `peak` of dur)
export function noise(b, at, { dur = 0.1, f = 1000, f2 = f, q = 0.8, type = "bp", vol = 1, atk = 0.002, dec, seed = 1 }) {
	const r = rng(seed);
	const s0 = at0(at), n = Math.min(Math.ceil(dur * SR), b.length - s0);
	const d = dec ?? dur;
	// Chamberlin SVF, time-varying cutoff (stable below ~SR/6)
	let lo = 0, bp = 0;
	const qq = 1 / q;
	for (let j = 0; j < n; j++) {
		const t = j / SR;
		const fc = Math.min(f * (f2 / f) ** (t / dur), SR / 6.5);
		const k = 2 * Math.sin((Math.PI * fc) / SR);
		const x = r() * 2 - 1;
		const hi = x - lo - qq * bp;
		bp += k * hi;
		lo += k * bp;
		const y = type === "lp" ? lo : type === "hp" ? hi : bp;
		const fade = Math.min(1, (n - j) / (0.01 * SR));
		b[s0 + j] += vol * y * env(t, atk, d) * fade;
	}
}

// Karplus-Strong pluck with body resonances; bright 0..1, sustain = T60 seconds
export function pluck(b, at, { f, sustain = 1.2, bright = 0.5, vol = 1, body = [[210, 0.25], [470, 0.15]], seed = 7, pos = 0.18 }) {
	const r = rng(seed);
	const s0 = at0(at), n = Math.min(Math.ceil(sustain * 1.1 * SR), b.length - s0);
	const L = SR / f;
	const damp = 0.5 + 0.45 * bright; // loop lowpass weight: y = damp*x + (1-damp)*x[-1], delay (1-damp)
	// loop delay = N + (1-damp) + d, d in [0.1, 1.1) from a first-order allpass
	const N = Math.floor(L - (1 - damp) - 0.1);
	const d = L - N - (1 - damp);
	const C = (1 - d) / (1 + d);
	const line = new Float32Array(N);
	// excitation: lowpassed noise minus a delayed copy (pluck position comb)
	const lpA = 0.15 + 0.8 * bright;
	let lp = 0;
	const ex = new Float32Array(N);
	for (let i = 0; i < N; i++) { lp += lpA * (r() * 2 - 1 - lp); ex[i] = lp; }
	const P = Math.max(1, Math.round(pos * N));
	let mean = 0;
	for (let i = 0; i < N; i++) { line[i] = ex[i] - (i >= P ? ex[i - P] : 0) * 0.9; mean += line[i] / N; }
	for (let i = 0; i < N; i++) line[i] -= mean;
	const g = 10 ** (-3 / (f * sustain)); // per-period loop gain for T60
	const bodies = body.map(([bf, bg]) => [biquad("bp", bf, 3), bg]);
	let idx = 0, prev = 0, ax1 = 0, ay1 = 0;
	for (let j = 0; j < n; j++) {
		const x = line[idx];
		const filt = g * (damp * x + (1 - damp) * prev);
		prev = x;
		const ap = C * filt + ax1 - C * ay1;
		ax1 = filt; ay1 = ap;
		line[idx] = ap;
		idx = (idx + 1) % N;
		let y = x;
		for (const [bq, bg] of bodies) y += bg * bq(x);
		const fade = Math.min(1, (n - j) / (0.02 * SR));
		b[s0 + j] += vol * y * fade;
	}
}

// Freeverb-style mono room: 8 combs + 4 allpasses
export function reverb(x, { size = 0.5, damp = 0.4, wet = 0.2, tail = 0.8 }) {
	const sc = SR / 44100;
	const combs = [1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617].map((l) => ({ d: new Float32Array(Math.round(l * sc * (0.6 + 0.4 * size))), i: 0, s: 0 }));
	const aps = [556, 441, 341, 225].map((l) => ({ d: new Float32Array(Math.round(l * sc)), i: 0 }));
	const fb = 0.7 + 0.28 * size;
	const out = new Float32Array(x.length + Math.ceil(tail * SR));
	for (let j = 0; j < out.length; j++) {
		const inp = (j < x.length ? x[j] : 0) * 0.015;
		let y = 0;
		for (const c of combs) {
			const o = c.d[c.i];
			c.s = o * (1 - damp) + c.s * damp;
			c.d[c.i] = inp + c.s * fb;
			c.i = (c.i + 1) % c.d.length;
			y += o;
		}
		for (const a of aps) {
			const o = a.d[a.i];
			a.d[a.i] = y + o * 0.5;
			a.i = (a.i + 1) % a.d.length;
			y = o - y;
		}
		out[j] = (j < x.length ? x[j] : 0) + wet * y;
	}
	return out;
}

// max short-term (50 ms) RMS, the loudness measure used for normalising
export function loudness(x) {
	const w = Math.round(0.05 * SR);
	let best = 0, acc = 0;
	for (let j = 0; j < x.length; j++) {
		acc += x[j] * x[j];
		if (j >= w) acc -= x[j - w] * x[j - w];
		if (j >= w - 1) best = Math.max(best, acc / w);
	}
	return Math.sqrt(Math.max(best, acc / Math.max(1, Math.min(w, x.length))));
}

// shared master stage: DC block, warmth lowpass + soft saturation, room, loudness target, limiter, fades, trim
export function bus(x, { lp = 8000, drive = 1.2, room, target = -18 }) {
	let y = new Float32Array(x.length);
	const hpf = biquad("hp", 40, 0.7), lpf = biquad("lp", lp, 0.7);
	const td = Math.tanh(drive);
	for (let j = 0; j < x.length; j++) y[j] = lpf(hpf(x[j]));
	// normalise pre-saturation so drive means the same thing for every sound
	let pk = 0;
	for (const v of y) pk = Math.max(pk, Math.abs(v));
	for (let j = 0; j < y.length; j++) y[j] = Math.tanh((y[j] / (pk || 1)) * drive) / td;
	if (room) y = reverb(y, room);
	const gain = 10 ** (target / 20) / (loudness(y) || 1);
	for (let j = 0; j < y.length; j++) y[j] *= gain;
	// soft limiter at -1 dBFS
	const ceil = 10 ** (-1 / 20);
	for (let j = 0; j < y.length; j++) y[j] = ceil * Math.tanh(y[j] / ceil);
	// trim tail below -60 dB of peak, fades 2 ms in / 15 ms out
	pk = 0;
	for (const v of y) pk = Math.max(pk, Math.abs(v));
	let end = y.length;
	const thr = pk * 1e-3;
	while (end > 1 && Math.abs(y[end - 1]) < thr) end--;
	end = Math.min(y.length, end + Math.round(0.02 * SR));
	y = y.slice(0, end);
	const fi = Math.round(0.002 * SR), fo = Math.min(end, Math.round(0.015 * SR));
	for (let j = 0; j < fi && j < end; j++) y[j] *= j / fi;
	for (let j = 0; j < fo; j++) y[end - 1 - j] *= j / fo;
	return y;
}

export function wav(x) {
	const n = x.length, b = Buffer.alloc(44 + n * 2);
	b.write("RIFF", 0); b.writeUInt32LE(36 + n * 2, 4); b.write("WAVE", 8);
	b.write("fmt ", 12); b.writeUInt32LE(16, 16); b.writeUInt16LE(1, 20); b.writeUInt16LE(1, 22);
	b.writeUInt32LE(SR, 24); b.writeUInt32LE(SR * 2, 28); b.writeUInt16LE(2, 32); b.writeUInt16LE(16, 34);
	b.write("data", 36); b.writeUInt32LE(n * 2, 40);
	for (let i = 0; i < n; i++) b.writeInt16LE(Math.round(Math.max(-1, Math.min(1, x[i])) * 32767), 44 + i * 2);
	return b;
}

// spectral centroid (Hz) of the loudest 2048-sample frame, naive DFT on 256 bins (sanity check only)
export function centroid(x) {
	const N = 2048;
	let best = 0, at = 0;
	for (let s = 0; s + N <= x.length; s += 512) {
		let e = 0;
		for (let j = 0; j < N; j++) e += x[s + j] ** 2;
		if (e > best) { best = e; at = s; }
	}
	let num = 0, den = 0;
	for (let k = 1; k < N / 2; k += 4) {
		let re = 0, im = 0;
		for (let j = 0; j < N && at + j < x.length; j++) {
			const w = 0.5 - 0.5 * Math.cos((2 * Math.PI * j) / N);
			const v = x[at + j] * w;
			re += v * Math.cos((2 * Math.PI * k * j) / N);
			im -= v * Math.sin((2 * Math.PI * k * j) / N);
		}
		const m = Math.hypot(re, im);
		num += m * ((k * SR) / N);
		den += m;
	}
	return den ? num / den : 0;
}
