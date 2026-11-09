#!/usr/bin/env python3
"""Line coverage for GDScript (Godot has none built in), run by tools/coverage.sh.
Copies the project, inserts `COV_<file#>.h(id)` (own const per file: a subclass may not redeclare its parent's) before every statement line of the target scripts, adds an autoload that
writes the hit bytes when the game exits (any runner: tests, drivers). Map = dest/cov_map.json [[file, line], ...].
Counted: statement lines inside functions at bracket depth 0. Not counted: func / class-level lines, elif / else,
match patterns, continuation lines, bodies of lambdas passed inside ( ) [ ] { }.
usage: instrument.py <src_project> <dest_project> <hits_file> <glob>...
"""

import glob
import json
import os
import re
import shutil
import sys

FUNC_RE = re.compile(r"^(static\s+)?func\s")
SKIP_DIRS = ("build", "shots", "docs", ".git", ".claude")


def scan_line(line, depth, in_str):
    """walk one physical line; returns (bracket depth after, open triple-quote or None, ends with backslash)"""
    i = 0
    n = len(line)
    code_end = n
    while i < n:
        if in_str:
            j = line.find(in_str, i)
            if j < 0:
                return depth, in_str, False
            i = j + 3
            in_str = None
            continue
        c = line[i]
        if c == "#":
            code_end = i
            break
        if c in "\"'":
            if line.startswith(c * 3, i):
                in_str = c * 3
                i += 3
                continue
            i += 1
            while i < n and line[i] != c:
                if line[i] == "\\":
                    i += 1
                i += 1
            i += 1
            continue
        if c in "([{":
            depth += 1
        elif c in ")]}":
            depth -= 1
        i += 1
    return depth, in_str, line[:code_end].rstrip().endswith("\\")


def instrument(text, start_id, rel, cname):
    lines = text.split("\n")
    out = []
    mapping = []
    nid = start_id
    depth = 0
    in_str = None
    cont = False
    func_indent = None
    match_stack = []
    pending = None  # out index of decorators (@warning_ignore) that must stay right above their statement
    for ln, line in enumerate(lines, 1):
        stripped = line.strip()
        if depth == 0 and in_str is None and not cont and stripped and not stripped.startswith("#"):
            ind = len(line) - len(line.lstrip("\t"))
            if func_indent is not None and ind <= func_indent:
                func_indent = None
                match_stack = []
            while match_stack and ind <= match_stack[-1]:
                match_stack.pop()
            if FUNC_RE.match(stripped):
                if func_indent is None:
                    func_indent = ind
                pending = None
            elif func_indent is not None and ind > func_indent:
                is_pattern = bool(match_stack) and ind == match_stack[-1] + 1
                if stripped.startswith("@"):
                    if pending is None:
                        pending = len(out)
                elif not is_pattern and not re.match(r"^(elif|else)\b", stripped):
                    out.insert(pending if pending is not None else len(out), "\t" * ind + "%s.h(%d)" % (cname, nid))
                    mapping.append([rel, ln])
                    nid += 1
                    pending = None
                    if re.match(r"^match\b", stripped) and stripped.split("#")[0].rstrip().endswith(":"):
                        match_stack.append(ind)
                else:
                    pending = None
        out.append(line)
        depth, in_str, cont = scan_line(line, depth, in_str)
    if mapping:
        out.append('const %s = preload("res://cov.gd")' % cname)
    return "\n".join(out), mapping, nid


def main():
    src, dst, hits_path = sys.argv[1], os.path.abspath(sys.argv[2]), os.path.abspath(sys.argv[3])
    if os.path.exists(dst):
        shutil.rmtree(dst)
    shutil.copytree(src, dst, ignore=shutil.ignore_patterns(*SKIP_DIRS), symlinks=True)
    nid = 0
    allmap = []
    nfile = 0
    for g in sys.argv[4:]:
        for path in sorted(glob.glob(os.path.join(dst, g), recursive=True)):
            rel = os.path.relpath(path, dst)
            with open(path) as f:
                new, mapping, nid = instrument(f.read(), nid, rel, "COV_%d" % nfile)
            nfile += 1
            with open(path, "w") as f:
                f.write(new)
            allmap.extend(mapping)
    if nid == 0:
        sys.exit("coverage: no statement lines matched %s" % sys.argv[4:])
    with open(os.path.join(dst, "cov.gd"), "w") as f:
        f.write(
            "extends RefCounted\n"
            "static var hits := PackedByteArray()\n\n"
            "static func h(i: int) -> void:\n"
            "\tif hits.is_empty():\n"
            "\t\thits.resize(%d)\n"
            "\thits[i] = 1\n\n"
            "## OR into the file so several runners add up\n"
            "static func dump() -> void:\n"
            "\tif hits.is_empty():\n"
            "\t\thits.resize(%d)\n"
            '\tvar path := "%s"\n'
            "\tvar old := FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()\n"
            "\tfor i in mini(old.size(), hits.size()):\n"
            "\t\thits[i] = hits[i] | old[i]\n"
            "\tvar f := FileAccess.open(path, FileAccess.WRITE)\n"
            "\tf.store_buffer(hits)\n"
            "\tf.close()\n" % (nid, nid, hits_path)
        )
    with open(os.path.join(dst, "cov_dump.gd"), "w") as f:
        f.write('extends Node\n\nfunc _exit_tree() -> void:\n\tpreload("res://cov.gd").dump()\n')
    proj = os.path.join(dst, "project.godot")
    with open(proj) as f:
        p = f.read()
    line = 'CovDump="*res://cov_dump.gd"\n'
    p = p.replace("[autoload]\n", "[autoload]\n" + line, 1) if "[autoload]\n" in p else p.rstrip("\n") + "\n\n[autoload]\n\n" + line
    with open(proj, "w") as f:
        f.write(p)
    with open(os.path.join(dst, "cov_map.json"), "w") as f:
        json.dump(allmap, f)
    print("coverage: %d statement lines instrumented" % nid)


main()
