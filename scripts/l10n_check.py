#!/usr/bin/env python3
"""Checks the UI translations against the L("...") strings in Sources/PlayHub.

  python3 scripts/l10n_check.py            # report missing / unused / broken entries (exit 1 on problems)
  python3 scripts/l10n_check.py --keys     # print every key found in the source

The Turkish text is the key (see Sources/PlayHub/L10n.swift). Each Resources/<lang>.lproj/Localizable.strings
must translate every key and keep the same number of %@ placeholders. "<key>##one" entries are optional
singular forms.
"""
import glob
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def skip_lit(src, i):
    i += 1
    while i < len(src):
        c = src[i]
        if c == '\\':
            if src[i + 1] == '(':
                i = skip_interp(src, i + 2)
                continue
            i += 2
            continue
        if c == '"':
            return i + 1
        if c == '\n':
            raise ValueError('unterminated string literal')
        i += 1
    raise ValueError('unterminated string literal')


def skip_interp(src, i):
    depth = 1
    while depth:
        c = src[i]
        if c == '"':
            i = skip_lit(src, i)
            continue
        if c == '(':
            depth += 1
        elif c == ')':
            depth -= 1
        i += 1
    return i


def key_of(body):
    out, i = [], 0
    while i < len(body):
        if body[i] == '\\' and body[i + 1] == '(':
            i = skip_interp(body, i + 2)
            out.append('%@')
            continue
        if body[i] == '\\':
            out.append(body[i:i + 2])
            i += 2
            continue
        out.append(body[i])
        i += 1
    return ''.join(out)


def source_keys():
    keys = {}
    for path in sorted(glob.glob(os.path.join(ROOT, 'Sources/PlayHub/*.swift'))):
        src = open(path, encoding='utf-8').read()
        for m in re.finditer(r'\b(L|LKey)\("', src):
            start = m.end() - 1
            end = skip_lit(src, start)
            key = key_of(src[start + 1:end - 1])
            line = src.count('\n', 0, start) + 1
            keys.setdefault(key, f'{os.path.basename(path)}:{line}')
    return keys


def load_strings(path):
    """Parse a .strings file via plutil (keeps the same escaping rules macOS uses)."""
    out = subprocess.run(['plutil', '-convert', 'json', '-o', '-', path], capture_output=True, text=True)
    if out.returncode != 0:
        sys.exit(f'{path}: {out.stderr.strip()}')
    import json
    return json.loads(out.stdout)


def placeholders(s):
    return len(re.findall(r'%(?:\d+\$)?@', s))


def unescape(key):
    return key.encode('utf-8').decode('unicode_escape').encode('latin-1').decode('utf-8')


def main():
    keys = {unescape(k): where for k, where in source_keys().items()}
    if '--keys' in sys.argv:
        for k, where in keys.items():
            print(f'{where}\t{k}')
        return 0
    problems = 0
    for path in sorted(glob.glob(os.path.join(ROOT, 'Resources/*.lproj/Localizable.strings'))):
        lang = os.path.basename(os.path.dirname(path))[:-len('.lproj')]
        table = load_strings(path)
        missing = [k for k in keys if k not in table]
        unused = [k for k in table if k.split('##')[0] not in keys]
        broken = [k for k, v in table.items() if placeholders(v) != placeholders(k.split('##')[0])]
        for k in missing:
            print(f'{lang}: missing  {k!r}  ({keys[k]})')
        for k in unused:
            print(f'{lang}: unused   {k!r}')
        for k in broken:
            print(f'{lang}: placeholder count differs  {k!r} -> {table[k]!r}')
        problems += len(missing) + len(unused) + len(broken)
        print(f'{lang}: {len(table)} entries, {len(missing)} missing, {len(unused)} unused, {len(broken)} broken')
    print(f'{len(keys)} keys in source')
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main())
