#!/usr/bin/env bash
# GDScript lint: gdlint (style, gdlintrc) + Godot parse / warnings-as-errors (project.godot [debug]).
# usage: tools/lint.sh            -> all tracked .gd
#        tools/lint.sh --staged   -> staged .gd only (pre-commit hook)
# needs: pipx install "gdtoolkit==4.*" + gdscript-formatter 0.27 (README Lint); GODOT=path overrides the Godot binary.
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
# layout = gdscript-formatter (GDQuest); same flags as the one-off repo format
fmt=(--max-line-length 150 --blank-lines-around-definitions 1)
command -v gdscript-formatter >/dev/null || { echo "lint: gdscript-formatter missing -> README Lint"; exit 1; }
if ! echo "$files" | tr '\n' '\0' | xargs -0 gdscript-formatter --check "${fmt[@]}" >/dev/null 2>&1; then
	echo "lint: not formatted -> gdscript-formatter ${fmt[*]} <files>"; exit 1
fi
# i18n: every Vietnamese literal in scripts/ goes through Lang.t, every catalog entry has a translation (docs/i18n.md)
python3 tools/i18n_extract.py --check >/dev/null || { python3 tools/i18n_extract.py --check; echo "lint: i18n -> python3 tools/i18n_extract.py, then translate locale/*.po"; exit 1; }
# Godot type-checks a script with its dependencies, so check the given files only (fast) but via the real parser
res=$(echo "$files" | sed 's#^#res://#' | tr '\n' ' ')
[ -z "$res" ] && exit 0
out=$("$bin" --headless --path . -s sim/check_scripts.gd -- $res 2>&1)
if echo "$out" | grep -q "SCRIPT ERROR"; then
	echo "$out" | grep -A1 "SCRIPT ERROR" | grep -v "^--"
	echo "lint: Godot parse / warning errors above"; exit 1
fi
echo "lint: ok"
