#!/usr/bin/env bash
# review recorded matches (README "Ghi trận / phân tích"): replay + analyze user://replays/<profile>/*.replay headless.
# usage: tools/review_match.sh [latest|all-new|<file.replay>|<folder>] [PROFILE=test] [LESSONS=off|<path>] [noscen] [lessons_bot]
#   lessons_bot = also add `bot`-flag runs (our side played by the AI) to the lessons file (skipped by default)
#   latest (default) = newest replay; all-new = every replay without a .review.json yet; <file> = that replay
#   PROFILE (arg or env) = the game's profile= flag (default: default); LESSONS = lessons file (default docs/review/match_lessons.md)
# out: <id>.review.md / .review.json beside the replay, docs/review/match_lessons.md, sim/scenarios/<id>_t<turn>.scenario
cd "$(dirname "$0")/.."
bin=${GODOT:-$(command -v godot || echo /Applications/Godot.app/Contents/MacOS/Godot)}
what=latest; profile=${PROFILE:-}; lessons=${LESSONS:-}; extra=()
for a in "$@"; do
	case "$a" in
		PROFILE=*) profile=${a#PROFILE=} ;;
		LESSONS=*) lessons=${a#LESSONS=} ;;
		noscen|lessons_bot) extra+=("$a") ;;
		*) what=$a ;;
	esac
done
dir=""
case "$what" in
	latest|all-new) ;;
	*) if [ -d "$what" ]; then dir=$(cd "$what" && pwd); what=all-new # a folder AirDropped off the phone
	else what=$(cd "$(dirname "$what")" && pwd)/$(basename "$what"); fi ;;
esac
args=("what=$what" "profile=$profile")
[ -n "$dir" ] && args+=("dir=$dir")
[ -n "$lessons" ] && args+=("lessons=$lessons")
"$bin" --headless --path . -s sim/review.gd -- "${args[@]}" "${extra[@]}" 2>&1 | grep -v '^Godot Engine'
exit "${PIPESTATUS[0]}"
