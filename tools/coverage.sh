#!/usr/bin/env bash
# line coverage of GDScript (instrumented copy, repo untouched). Hits from every runner add up.
# usage: tools/coverage.sh [core|ui|all|'<glob>'] [-m FILE_SUBSTR] [-- runner [-- runner ...]]
#   default scope core (scripts/core), default runner sim/tests.gd; -m lists uncovered lines of matching files
#   e.g. tools/coverage.sh ui -- sim/tests.gd -- sim/click_driver.gd -- mission=m02 fresh nointro
#   runner = script path + its args; a runner's own "--" args go after the script (the next "--" starts a new runner
#   only when followed by a .gd path). KEEP=1 keeps the copy (path printed). MAX_SEC per runner (default 400).
cd "$(dirname "$0")/.."
root=$(pwd)
scope=core
missed=
runners=()
case "${1:-}" in core | ui | all) scope=$1; shift ;; -m | --) ;; "") ;; *) scope=$1; shift ;; esac
if [ "${1:-}" = -m ]; then missed=$2; shift 2; fi
case $scope in
	core) globs=("scripts/core/*.gd") ;;
	ui) globs=("scripts/ui/**/*.gd") ;;
	all) globs=("scripts/**/*.gd") ;;
	*) globs=("$scope") ;;
esac
cur=
while [ $# -gt 0 ]; do
	if [ "$1" = -- ] && [[ "${2:-}" == *.gd ]]; then
		[ -n "$cur" ] && runners+=("$cur")
		cur=$2
		shift 2
		continue
	fi
	cur="$cur $1"
	shift
done
[ -n "$cur" ] && runners+=("$cur")
[ ${#runners[@]} -eq 0 ] && runners=("sim/tests.gd")

tmp=$(mktemp -d "${TMPDIR:-/tmp}/cov.XXXXXX")
dst=$tmp/proj
hits=$tmp/hits.bin
python3 tools/coverage/instrument.py "$root" "$dst" "$hits" "${globs[@]}" || exit 1
if [ ! -d "$dst/.godot" ]; then
	echo "coverage: no .godot cache, importing once"
	${GODOT:-godot} --headless --path "$dst" --import > "$tmp/import.log" 2>&1
fi
fail=0
i=0
for r in "${runners[@]}"; do
	i=$((i + 1))
	read -r -a parts <<< "$r"
	script=${parts[0]}
	args=("${parts[@]:1}")
	[ "${args[0]:-}" = -- ] && args=("${args[@]:1}")
	extra=()
	[ ${#args[@]} -gt 0 ] && extra=(-- "${args[@]}")
	echo "coverage: run $script ${args[*]}"
	MAX_SEC=${MAX_SEC:-400} tools/run_guarded.sh "$tmp/run$i.log" -- --headless --path "$dst" -s "$script" "${extra[@]}" || fail=1
	tail -1 "$tmp/run$i.log"
done
python3 tools/coverage/report.py "$dst/cov_map.json" "$hits" $missed
[ $fail -ne 0 ] && echo "coverage: a runner failed (logs in $tmp)"
if [ "${KEEP:-0}" = 1 ] || [ $fail -ne 0 ]; then echo "coverage: kept $tmp"; else rm -rf "$tmp"; fi
exit $fail
