#!/usr/bin/env bash
# macOS/Linux twin of run_guarded.ps1: run Godot, kill it when RSS > MAX_MB or run > MAX_SEC.
# usage: MAX_MB=1500 MAX_SEC=120 tools/run_guarded.sh LOG -- <godot args>     (GODOT=path overrides binary)
cd "$(dirname "$0")/.."
log=$1; shift; [ "$1" = "--" ] && shift
max_mb=${MAX_MB:-1500}; max_sec=${MAX_SEC:-120}; bin=${GODOT:-godot}
"$bin" "$@" > "$log" 2> "$log.err" &
pid=$!; t0=$SECONDS; peak=0; why=exit
while kill -0 "$pid" 2>/dev/null; do
	sleep 0.4
	kb=$(ps -o rss= -p "$pid" 2>/dev/null | tr -d ' '); mb=$(( ${kb:-0} / 1024 ))
	[ "$mb" -gt "$peak" ] && peak=$mb
	if [ "$mb" -gt "$max_mb" ]; then why="KILLED: memory $mb MB > $max_mb"
	elif [ $((SECONDS - t0)) -gt "$max_sec" ]; then why="KILLED: time > $max_sec s"; fi
	if [ "$why" != exit ]; then kill -9 "$pid" 2>/dev/null; break; fi
done
wait "$pid" 2>/dev/null; code=$?
line="[guard] $why, peak $peak MB, $((SECONDS - t0)) s, exit $code"
echo "$line" > "$log.guard"; echo "$line"
[ "$why" = exit ] && exit $code || exit 137
