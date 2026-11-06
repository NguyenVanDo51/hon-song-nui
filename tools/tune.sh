#!/usr/bin/env bash
# AI self-play tuning (sim/tune.gd): parallel islands = independent evolve lines, each under the memory / time guard;
# then every island's best vs DEFAULT on held-out seeds; the best island -> sim/tuned_params.txt (only if it beats DEFAULT).
# usage: tools/tune.sh [islands=4] [minutes=20] [games=8] [held_games=16]
#   TUNE_DIR (default $TEMP/hsn_tune): island_<k>.txt state (rerun with the same dir resumes) + logs
cd "$(dirname "$0")/.."
islands=${1:-4}; minutes=${2:-20}; games=${3:-8}; held=${4:-16}
dir=${TUNE_DIR:-${TEMP:-/tmp}/hsn_tune}; mkdir -p "$dir"
g() { MAX_MB=1500 MAX_SEC=$1 tools/run_guarded.sh "$2" -- --headless --path . -s sim/tune.gd -- "${@:3}" > /dev/null; }
# evolve stops itself after `minutes`, finishing the generation in flight (<= ~4 min at games=8)
for k in $(seq 0 $((islands - 1))); do
	g $((minutes * 60 + 900)) "$dir/island_$k.log" evolve out="$dir/island_$k.txt" games="$games" minutes="$minutes" island="$k" &
done
wait
grep -h ACCEPT "$dir"/island_*.log
for k in $(seq 0 $((islands - 1))); do
	g 3600 "$dir/held_$k.log" match a=file:"$dir/island_$k.txt" b=default games="$held" salt=9000000 &
done
wait
best=-1; bs=0.5
for k in $(seq 0 $((islands - 1))); do
	sc=$(grep -o "A score [0-9.]*" "$dir/held_$k.log" | awk '{print $3}')
	echo "island $k vs DEFAULT (held-out, $((held * 6)) games): ${sc:-?}"
	if [ -n "$sc" ] && awk "BEGIN{exit !($sc > $bs)}"; then best=$k; bs=$sc; fi
done
if [ "$best" -ge 0 ]; then
	cp "$dir/island_$best.txt" sim/tuned_params.txt
	echo "best: island $best ($bs) -> sim/tuned_params.txt"
else
	echo "no island beat DEFAULT on held-out seeds; sim/tuned_params.txt unchanged"
fi
