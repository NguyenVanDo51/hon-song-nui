#!/usr/bin/env bash
# Balance sims for several missions in parallel, each under the memory guard.
# usage: tools/sim_many.sh "m09 m10 m11" [games=12] [jobs=4]     -> one summary line per mission
# logs: $TEMP/hsn_bal/<mission>.log
cd "$(dirname "$0")/.."
missions=$1; games=${2:-12}; jobs=${3:-4}
out="${TEMP:-/tmp}/hsn_bal"; mkdir -p "$out"
outw=$(cygpath -m "$out" 2>/dev/null || echo "$out")
run() {
	powershell -NoProfile -File tools/run_guarded.ps1 -Log "$outw/$1.log" -MaxMB 1200 -MaxSec 2400 \
		-GArgs "--headless --path . -s sim/sim.gd -- mission $1 $games" > /dev/null
}
n=0
for m in $missions; do
	run "$m" &
	n=$((n + 1))
	if [ $((n % jobs)) -eq 0 ]; then wait; fi
done
wait
for m in $missions; do tr -d '\000' < "$out/$m.log" | grep -E "^m[0-9]+ " ; tr -d '\000' < "$out/$m.log.guard" 2>/dev/null | grep KILLED; done
