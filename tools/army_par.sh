#!/usr/bin/env bash
# parallel sim/probes/army_probe.gd: nproc processes, salts salt0 .. salt0+nproc-1, then merged metrics.
# usage: tools/army_par.sh <a-spec> <b-spec> [games=2] [salt0=600] [nproc=8]
cd "$(dirname "$0")/.."
a=$1; b=$2; games=${3:-2}; salt0=${4:-600}; np=${5:-8}
dir=${MATCH_DIR:-${TMPDIR:-/tmp}/hsn_match}; mkdir -p "$dir"
h=$(printf '%s|%s' "$a" "$b" | shasum | cut -c1-10)
tag=army-$(echo "$salt0-g$games-$h-$a-vs-$b" | tr -c 'A-Za-z0-9_.-' '_' | cut -c1-120)
files=""
for i in $(seq 0 $((np - 1))); do
	MAX_MB=1500 MAX_SEC=${MAX_SEC:-7200} tools/run_guarded.sh "$dir/$tag.$i.log" -- --headless --path . -s sim/probes/army_probe.gd -- \
		a="$a" b="$b" games="$games" salt=$((salt0 + i)) > /dev/null &
	files="$files,$dir/$tag.$i.log"
done
wait
echo "A $a vs B $b (salt $salt0..$((salt0 + np - 1)), games $games)"
godot --headless --path . -s sim/probes/army_probe.gd -- sum="${files#,}" 2>/dev/null | grep -v '^Godot' | grep -v '^  raw'
