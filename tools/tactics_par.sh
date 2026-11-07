#!/usr/bin/env bash
# parallel sim/probes/tactics_probe.gd: nproc processes, salts salt0 .. salt0+nproc-1, then merged metrics.
# usage: tools/tactics_par.sh "<probe args, e.g. over=lone_w:1 opp=v1>" [games=4] [salt0=600] [nproc=8]
cd "$(dirname "$0")/.."
pa=$1; games=${2:-4}; salt0=${3:-600}; np=${4:-8}
dir=${MATCH_DIR:-${TMPDIR:-/tmp}/hsn_match}; mkdir -p "$dir"
h=$(printf '%s' "$pa" | shasum | cut -c1-10) # hash first: long args cut at 120 chars must not share a log
tag=tactics-$(echo "$salt0-g$games-$h-$pa" | tr -c 'A-Za-z0-9_.-' '_' | cut -c1-120)
files=""
for i in $(seq 0 $((np - 1))); do
	MAX_MB=1500 MAX_SEC=${MAX_SEC:-7200} tools/run_guarded.sh "$dir/$tag.$i.log" -- --headless --path . -s sim/probes/tactics_probe.gd -- \
		$pa games="$games" salt=$((salt0 + i)) > /dev/null &
	files="$files,$dir/$tag.$i.log"
done
wait
godot --headless --path . -s sim/probes/tactics_probe.gd -- $pa sum="${files#,}" 2>/dev/null | grep -v '^Godot' | grep -v '^  raw'
