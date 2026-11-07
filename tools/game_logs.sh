#!/usr/bin/env bash
# read the per-session game logs (scripts/ui/game_log.gd): user://logs/game/<profile>/
# usage: tools/game_logs.sh [cmd] [arg]     PROFILE=test -> that profile's dir (default: default)
#   ls            sessions + crash logs, newest last (default)
#   last [N]      the newest session log (N = tail lines; omit = whole file)
#   crash         the newest crash_*.log (session that ended without "== clean exit")
#   errors [N]    E / S / W / H / X lines + crash markers of the newest N sessions + N crash logs (default 5)
#   grep PATTERN  grep -n in every log of the profile
#   dir           print the log dir
# macOS desktop only (iOS: Xcode > Devices > app > Download Container -> Documents/logs/game; web: browser console)
proj=$(sed -n 's/^config\/name="\(.*\)"/\1/p' "$(dirname "$0")/../project.godot")
dir="${GAME_LOG_DIR:-$HOME/Library/Application Support/Godot/app_userdata/$proj/logs/game/${PROFILE:-default}}"
cmd=${1:-ls}
[ "$cmd" = dir ] && { echo "$dir"; exit 0; }
[ -d "$dir" ] || { echo "game_logs: no dir $dir (no windowed session yet?)"; exit 1; }
cd "$dir" || exit 1
sessions() { ls -1 2>/dev/null | grep -E '^[0-9]{4}-.*\.log$' | sort; }
crashes() { ls -1 2>/dev/null | grep -E '^crash_.*\.log$' | sort; }
case "$cmd" in
	ls)
		echo "# $dir"
		for f in $(sessions) $(crashes); do
			n=$(grep -cE '^[^ ]+ \+[0-9.]+ [ESWH] ' "$f")
			printf "%-36s %6s B  %4s err/warn\n" "$f" "$(wc -c < "$f" | tr -d ' ')" "$n"
		done ;;
	last)
		f=$(sessions | tail -1); [ -z "$f" ] && { echo "game_logs: no session"; exit 1; }
		echo "# $f"; if [ -n "$2" ]; then tail -n "$2" "$f"; else cat "$f"; fi ;;
	crash)
		f=$(crashes | tail -1); [ -z "$f" ] && { echo "game_logs: no crash log"; exit 0; }
		echo "# $f"; cat "$f" ;;
	errors)
		for f in $(sessions | tail -n "${2:-5}") $(crashes | tail -n "${2:-5}"); do grep -HE '^[^ ]+ \+[0-9.]+ [ESWH] |CRASHED|^[^ ]+ \+[0-9.]+ X ' "$f"; done ;;
	grep)
		[ -z "$2" ] && { echo "usage: tools/game_logs.sh grep PATTERN"; exit 1; }
		grep -nE "$2" $(sessions) $(crashes) ;;
	*) sed -n '2,10p' "$0"; exit 1 ;;
esac
