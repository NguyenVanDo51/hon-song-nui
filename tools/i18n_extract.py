#!/usr/bin/env python3
"""Keep the translation catalogs in sync with the Vietnamese source text (docs/i18n.md).

  python3 tools/i18n_extract.py           -> rewrite locale/messages.pot + add missing msgids to every locale/*.po
  python3 tools/i18n_extract.py --check   -> exit 1 if a .po lacks a translation, or a Vietnamese literal in
                                             scripts/ is not wrapped in Lang.t(...) (lines marked i18n-const excepted)

msgid = the Vietnamese text exactly as the game shows it (GDScript escapes resolved). Sources: every string literal
with Vietnamese letters in scripts/**/*.gd and content/**/*.gd (code, theme, guide, levels, maps), plus any other
literal passed to Lang.t("...").
"""
import glob, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VI = re.compile('[àáảãạăằắẳẵặâầấẩẫậèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵđ'
                'ĐÀÁẢÃẠĂẰẮẲẴẶÂẦẤẨẪẬÈÉẺẼẸÊỀẾỂỄỆÌÍỈĨỊÒÓỎÕỌÔỒỐỔỖỘƠỜỚỞỠỢÙÚỦŨỤƯỪỨỬỮỰỲÝỶỸỴ]')
SOURCES = ['scripts/**/*.gd', 'content/**/*.gd']
LOCALE = os.path.join(ROOT, 'locale')


def literals(line):
    """(start, end, raw text between the quotes) of each "..." literal before a # comment"""
    out, i, n = [], 0, len(line)
    while i < n:
        c = line[i]
        if c == '#':
            break
        if c == '"':
            j = i + 1
            while j < n and line[j] != '"':
                j += 2 if line[j] == '\\' else 1
            out.append((i, j + 1, line[i + 1:j]))
            i = j + 1
            continue
        i += 1
    return out


def unescape(raw):
    return bytes(raw, 'utf-8').decode('unicode_escape').encode('latin-1').decode('utf-8') if '\\' in raw else raw


def po_escape(s):
    return s.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n').replace('\t', '\\t')


def scan():
    msgs, refs, bare = {}, {}, []
    files = sorted(set(f for p in SOURCES for f in glob.glob(os.path.join(ROOT, p), recursive=True)))
    for f in files:
        rel = os.path.relpath(f, ROOT)
        for no, line in enumerate(open(f, encoding='utf-8'), 1):
            st = line.lstrip()
            if st.startswith('#'):
                continue
            for a, b, raw in literals(line):
                before = line[:a].rstrip()
                wrapped = before.endswith('Lang.t(')
                if not VI.search(raw) and not wrapped:
                    continue
                s = unescape(raw)
                if s.strip() == '':
                    continue
                msgs.setdefault(s, None)
                refs.setdefault(s, []).append(f'{rel}:{no}')
                if rel.startswith('scripts/') and not wrapped and 'i18n-const' not in line \
                        and not st.startswith('const ') and VI.search(raw):
                    bare.append(f'{rel}:{no}: {s}')
    return list(msgs), refs, bare


def read_po(path):
    """msgid -> msgstr (single-line entries, as this tool writes them)"""
    out, mid = {}, None
    if not os.path.exists(path):
        return out
    for line in open(path, encoding='utf-8'):
        line = line.rstrip('\n')
        if line.startswith('msgid "'):
            mid = line[7:-1]
        elif line.startswith('msgstr "') and mid is not None:
            out[mid] = line[8:-1]
            mid = None
    return out


def write_po(path, ids, refs, old, lang):
    head = [
        '# Công Thành Chiến — %s (msgid = Vietnamese source text). Generated / merged by tools/i18n_extract.py.' % (lang or 'template'),
        'msgid ""', 'msgstr ""',
        '"Content-Type: text/plain; charset=UTF-8\\n"',
        '"Language: %s\\n"' % (lang or ''), '']
    body = []
    for s in ids:
        e = po_escape(s)
        body.append('#: ' + ' '.join(refs[s][:3]))
        body.append('msgid "%s"' % e)
        body.append('msgstr "%s"' % (old.get(e, '') if lang else ''))
        body.append('')
    open(path, 'w', encoding='utf-8').write('\n'.join(head + body))


def main():
    check = '--check' in sys.argv
    ids, refs, bare = scan()
    os.makedirs(LOCALE, exist_ok=True)
    pos = sorted(glob.glob(os.path.join(LOCALE, '*.po')))
    bad = 0
    if check:
        for p in pos:
            old = read_po(p)
            missing = [s for s in ids if not old.get(po_escape(s))]
            if missing:
                bad += 1
                print('%s: %d untranslated, e.g. %s' % (os.path.relpath(p, ROOT), len(missing), missing[:3]))
        if bare:
            bad += 1
            print('Vietnamese literal not in Lang.t(...):', *bare[:10], sep='\n  ')
        print('i18n: %d msgids, %s' % (len(ids), 'ok' if not bad else 'FAIL'))
        sys.exit(1 if bad else 0)
    write_po(os.path.join(LOCALE, 'messages.pot'), ids, refs, {}, None)
    for p in pos:
        lang = os.path.basename(p)[:-3]
        old = read_po(p)
        write_po(p, ids, refs, old, lang)
        left = sum(1 for s in ids if not old.get(po_escape(s)))
        print('%s: %d msgids, %d untranslated' % (os.path.relpath(p, ROOT), len(ids), left))
    print('pot: %d msgids; bare literals: %d' % (len(ids), len(bare)))
    for b in bare[:20]:
        print('  bare', b)


if __name__ == '__main__':
    main()
