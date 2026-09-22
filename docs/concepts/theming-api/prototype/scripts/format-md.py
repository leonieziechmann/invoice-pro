# Formats final.md the way prettier (proseWrap: preserve) prints Markdown:
# aligned GFM tables, no trailing spaces, single trailing newline. Also lints
# the other rules the repo's `prettier --check` would enforce.
import re, sys, unicodedata

p = sys.argv[1] if len(sys.argv) > 1 else 'final.md'
s = open(p, encoding='utf8').read()


def width(t):
    w = 0
    for ch in t:
        if unicodedata.combining(ch):
            continue
        w += 2 if unicodedata.east_asian_width(ch) in ('W', 'F') else 1
    return w


def split_row(line):
    body = line.strip()
    assert body.startswith('|') and body.endswith('|'), line
    body = body[1:-1]
    cells, cur, i, in_code = [], '', 0, False
    while i < len(body):
        c = body[i]
        if c == '\\' and i + 1 < len(body):
            cur += body[i:i + 2]; i += 2; continue
        if c == '`':
            in_code = not in_code
        if c == '|' and not in_code:
            cells.append(cur.strip()); cur = ''
        else:
            cur += c
        i += 1
    cells.append(cur.strip())
    return cells


out, lines, i, in_fence = [], s.split('\n'), 0, False
problems = []
while i < len(lines):
    line = lines[i]
    if line.startswith('```'):
        in_fence = not in_fence
        if in_fence and line.strip() == '```':
            problems.append('untagged fence at line %d' % (i + 1))
    if not in_fence and line.startswith('|'):
        block = []
        while i < len(lines) and lines[i].startswith('|'):
            block.append(lines[i]); i += 1
        rows = [split_row(l) for l in block]
        n = len(rows[0])
        for k, r in enumerate(rows):
            if len(r) != n:
                problems.append('table row has %d cells, header %d: %s' % (len(r), n, block[k][:80]))
        assert all(re.fullmatch(r':?-+:?', c) for c in rows[1]), block[1]
        ws = [max(3, max(width(r[j]) if j < len(r) else 0 for k, r in enumerate(rows) if k != 1)) for j in range(n)]
        for k, r in enumerate(rows):
            if k == 1:
                out.append('| ' + ' | '.join('-' * ws[j] for j in range(n)) + ' |')
            else:
                out.append('| ' + ' | '.join(r[j] + ' ' * (ws[j] - width(r[j])) for j in range(n)) + ' |')
        continue
    out.append(line.rstrip())
    i += 1

text = '\n'.join(out).rstrip('\n') + '\n'
# lint: blank lines around headings, fences, tables, lists
L = text.split('\n')
in_fence = False
for k, line in enumerate(L):
    if line.startswith('```'):
        opening = not in_fence
        in_fence = not in_fence
        if opening and k > 0 and L[k - 1].strip() != '':
            problems.append('no blank line before fence at %d' % (k + 1))
        if not opening and k + 1 < len(L) and L[k + 1].strip() != '':
            problems.append('no blank line after fence at %d' % (k + 1))
        continue
    if in_fence:
        continue
    if '\t' in line:
        problems.append('tab at %d' % (k + 1))
    if line.startswith('#'):
        if k > 0 and L[k - 1].strip() != '':
            problems.append('no blank before heading %d' % (k + 1))
        if k + 1 < len(L) and L[k + 1].strip() != '':
            problems.append('no blank after heading %d' % (k + 1))
    if re.match(r'^\s*[*+] ', line):
        problems.append('non-dash bullet at %d' % (k + 1))
    if line.startswith('|') and k > 0 and not L[k - 1].startswith('|') and L[k - 1].strip() != '':
        problems.append('no blank before table %d' % (k + 1))
    if line.startswith('|') and k + 1 < len(L) and not L[k + 1].startswith('|') and L[k + 1].strip() != '':
        problems.append('no blank after table %d' % (k + 1))
    if re.match(r'^(- |\d+\. )', line) and k > 0 and L[k - 1].strip() != '' and not re.match(r'^(\s*- |\s*\d+\. |\s+)', L[k - 1]):
        problems.append('no blank before list %d: %s' % (k + 1, line[:40]))
    if re.search(r'(?<![*\w`])\*(?!\*)[^*\s][^*]*\*(?!\*)', line) and '`' not in line:
        problems.append('single-star emphasis (prettier uses _) at %d' % (k + 1))
open(p, 'w', encoding='utf8', newline='\n').write(text)
print('\n'.join(problems) if problems else 'no problems')
