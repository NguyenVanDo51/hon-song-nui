#!/usr/bin/env bash
# GDScript lint: gdlint (style, gdlintrc) + Godot parse / warnings-as-errors (project.godot [debug]).
# usage: tools/lint.sh            -> all tracked .gd
#        tools/lint.sh --staged   -> staged .gd only (pre-commit hook)
# needs: pipx install "gdtoolkit==4.*" ; GODOT=path overrides the Godot binary.
cd "$(dirname "$0")/.."
export PATH="$HOME/.local/bin:$PATH"
bin=${GODOT:-$(command -v godot || echo /Applications/Godot.app/Contents/MacOS/Godot)}
if [ "$1" = "--staged" ]; then
	files=$(git diff --cached --name-only --diff-filter=ACMR -- '*.gd')
else
	files=$(git ls-files '*.gd')
fi
files=$(echo "$files" | grep -v '^assets/') # generated (emoji manifest); gdlintrc excludes it too
[ -z "$files" ] && exit 0
command -v gdlint >/dev/null || { echo "lint: gdlint missing -> pipx install \"gdtoolkit==4.*\""; exit 1; }
echo "$files" | tr '\n' '\0' | xargs -0 gdlint || exit 1
# Godot type-checks a script with its dependencies, so check the given files only (fast) but via the real parser
res=$(echo "$files" | sed 's#^#res://#' | tr '\n' ' ')
[ -z "$res" ] && exit 0
out=$("$bin" --headless --path . -s sim/check_scripts.gd -- $res 2>&1)
if echo "$out" | grep -q "SCRIPT ERROR"; then
	echo "$out" | grep -A1 "SCRIPT ERROR" | grep -v "^--"
	echo "lint: Godot parse / warning errors above"; exit 1
fi
echo "lint: ok"
