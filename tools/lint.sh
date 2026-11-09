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
	# shown-text language check only when what the screens show can change (project settings, catalogs, code, content)
	lang_need=$(git diff --cached --name-only -- project.godot 'locale/*' 'scripts/*' 'content/*' sim/lang_check.gd)
else
	files=$(git ls-files '*.gd')
	lang_need=1
fi
# i18n shown text (docs/i18n.md "Kiểm"): after a language switch every screen shows that language (sim/lang_check.gd).
# Before the .gd early exit: the 2026-11-09 bug was a project.godot-only change (locale/fallback)
if [ -n "$lang_need" ]; then
	lout=$("${GODOT:-$(command -v godot || echo /Applications/Godot.app/Contents/MacOS/Godot)}" --headless --path . -s sim/lang_check.gd 2>&1)
	if ! echo "$lout" | grep -q "LANG CHECK fails=0"; then
		echo "$lout" | grep -E "^FAIL|^       |SCRIPT ERROR|LANG CHECK"
		echo "lint: shown text in the wrong language -> sim/lang_check.gd (docs/i18n.md)"; exit 1
	fi
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
