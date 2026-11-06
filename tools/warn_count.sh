#!/usr/bin/env bash
# Count Godot warnings not yet enforced (temp override.cfg turns them into errors, then loads scripts).
# usage: tools/warn_count.sh [-v] [path-prefix ...]   e.g. tools/warn_count.sh -v scripts/core
#   -v -> list file:line + message;  WARNS="a b" overrides the warning set
cd "$(dirname "$0")/.."
verbose=0; [ "$1" = "-v" ] && { verbose=1; shift; }
warns=${WARNS:-"untyped_declaration unsafe_property_access unsafe_method_access unsafe_cast unsafe_call_argument integer_division incompatible_ternary shadowed_variable shadowed_variable_base_class shadowed_global_identifier"}
bin=${GODOT:-$(command -v godot || echo /Applications/Godot.app/Contents/MacOS/Godot)}
[ -e override.cfg ] && { echo "warn_count: override.cfg exists, refusing"; exit 1; }
trap 'rm -f override.cfg' EXIT
{ echo "[debug]"; for w in $warns; do echo "gdscript/warnings/$w=2"; done; } > override.cfg
files=$(git ls-files '*.gd' | grep -v '^assets/')
if [ $# -gt 0 ]; then pat=$(printf '^%s|' "$@"); files=$(echo "$files" | grep -E "${pat%|}"); fi
res=$(echo "$files" | sed 's#^#res://#' | tr '\n' ' ')
out=$("$bin" --headless --path . -s sim/check_scripts.gd -- $res 2>&1)
echo "$out" | python3 -c '
import re,sys,collections
want=set(sys.argv[2:]); v=sys.argv[1]=="1"
L=sys.stdin.read().splitlines(); seen=set(); rows=[]
for i,l in enumerate(L):
    if not l.startswith("SCRIPT ERROR") or i+1>=len(L): continue
    m=re.search(r"\(res://([^:]+):(\d+)\)",L[i+1])
    if not m or (m.group(1) not in want): continue
    k=(m.group(1),int(m.group(2)),l)
    if k not in seen: seen.add(k); rows.append(k)
rows.sort()
if v:
    for f,n,msg in rows: print("%s:%d %s"%(f,n,msg.replace("SCRIPT ERROR: Parse Error: ","").replace(" (Warning treated as error.)","")))
c=collections.Counter(f for f,_,_ in rows)
for f,n in c.most_common(): print("%5d %s"%(n,f))
print("warn_count: %d"%len(rows))
' "$verbose" $files
