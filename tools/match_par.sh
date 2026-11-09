#!/usr/bin/env bash
# parallel sim/tune.gd match: nproc processes, salts salt0 .. salt0+nproc-1, each games x 3 maps x 2 seats -> summed A score.
# usage: tools/match_par.sh <a-spec> <b-spec> [games=4] [salt0=100] [nproc=8]   (MATCH_DIR: logs, default $TMPDIR/hsn_match)
#   MATCH_EXTRA="prices=soldier:200,archer:300 spam=elephant,archer" -> extra tune.gd args (economy test)
# SE = binomial sqrt(p(1-p)/n) (draws rare)
cd "$(dirname "$0")/.."
a=$1; b=$2; games=${3:-4}; salt0=${4:-100}; np=${5:-8}
dir=${MATCH_DIR:-${TMPDIR:-/tmp}/hsn_match}; mkdir -p "$dir"
# salt + games + spec hash first: long specs cut at 120 chars must not share a log across runs
extra=${MATCH_EXTRA:-}
h=$(printf '%s|%s|%s' "$a" "$b" "$extra" | shasum | cut -c1-10)
tag=$(echo "$salt0-g$games-$h-$a-vs-$b" | tr -c 'A-Za-z0-9_.-' '_' | cut -c1-120)
for i in $(seq 0 $((np - 1))); do
	MAX_MB=1500 MAX_SEC=${MAX_SEC:-7200} tools/run_guarded.sh "$dir/$tag.$i.log" -- --headless --path . -s sim/tune.gd -- \
		match a="$a" b="$b" games="$games" salt=$((salt0 + i)) $extra > /dev/null &
done
wait
grep -hv "guard\] exit" "$dir/$tag".*.log.guard
cat "$dir/$tag".*.log | awk -v a="$a" -v b="$b" '
	/ A as / { k = $1 " " substr($4, 1, 1); sc[k] += $5; n[k] += $7; S += $5; N += $7 }
	/WARNING/ { print "  " $0 }
	END {
		for (k in sc) printf "  %-14s A as %s: %.1f / %d\n", substr(k, 1, index(k, " ") - 1), substr(k, index(k, " ") + 1), sc[k], n[k]
		p = N ? S / N : 0
		printf "A %s vs B %s: %.3f +- %.3f (%d games)\n", a, b, p, sqrt(p * (1 - p) / (N ? N : 1)), N
	}'
