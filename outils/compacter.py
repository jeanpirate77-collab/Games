# Fabrique les scripts compacts du jeu (à la racine du projet) à partir des
# scripts lisibles et commentés du dossier source/.
#
# Pourquoi : la version gratuite de Xogot (Godot sur iPad) limite le projet à
# 200 Ko de scripts. On enlève donc les commentaires, les lignes vides et les
# espaces inutiles, et on compacte les cartes des niveaux ("12." = 12 cases vides).
# Le programme obtenu est exactement le même (vérifié avec gdtoolkit si installé).
#
# Utilisation (depuis la racine du projet) :  python3 outils/compacter.py
import glob
import os
import re
import sys

IDENT = set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_")


def minify(src):
    out_lines = []
    line = []
    line_in_string = False   # la ligne a commencé dans une chaîne sur plusieurs lignes
    state = None             # None, '"', "'", '"""'
    i = 0
    n = len(src)

    def flush():
        nonlocal line, line_in_string
        text = ''.join(line).rstrip(' ')
        if line_in_string or text.strip():
            out_lines.append(text)
        line = []
        line_in_string = state is not None

    while i < n:
        ch = src[i]
        if state is None:
            if ch == '\n':
                flush()
                i += 1
                continue
            if ch == '#':
                while i < n and src[i] != '\n':
                    i += 1
                continue
            if src.startswith('"""', i):
                state = '"""'
                line.append('"""')
                i += 3
                continue
            if ch in '"\'':
                state = ch
                line.append(ch)
                i += 1
                continue
            if ch == ' ':
                # garder les espaces d'indentation
                if all(c in ' \t' for c in line):
                    line.append(ch)
                    i += 1
                    continue
                j = i
                while j < n and src[j] == ' ':
                    j += 1
                prev = next((c for c in reversed(line) if c != ' '), '')
                nxt = src[j] if j < n else ''
                if (prev in IDENT or prev in '"\'') and (nxt in IDENT or nxt in '"\'@$'):
                    line.append(' ')
                i = j
                continue
            line.append(ch)
            i += 1
        else:
            if state == '"""':
                if src.startswith('"""', i):
                    line.append('"""')
                    state = None
                    i += 3
                    continue
            else:
                if ch == '\\':
                    line.append(src[i:i + 2])
                    i += 2
                    continue
                if ch == state:
                    state = None
            if ch == '\n':
                flush()
                i += 1
                continue
            line.append(ch)
            i += 1
    flush()
    return '\n'.join(out_lines) + '\n'


def pack_row(row):
    out = []
    i = 0
    while i < len(row):
        j = i
        while j < len(row) and row[j] == row[i]:
            j += 1
        count = j - i
        out.append((str(count) if count > 1 else '') + row[i])
        i = j
    return ''.join(out)


def pack_levels(src):
    # chaque ligne de carte "####....##" devient "4#4.2#"
    def repl(m):
        row = m.group(2).replace('\\\\', '\\')
        packed = pack_row(row).replace('\\', '\\\\')
        return m.group(1) + '"' + packed + '",'
    return re.sub(r'^(\t\t\t)"([^"]*)",', repl, src, flags=re.M)


def same_program(a, b):
    try:
        from gdtoolkit.parser import parser
    except ImportError:
        return None
    return str(parser.parse(a)) == str(parser.parse(b))


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    total = 0
    ok = True
    for path in sorted(glob.glob(os.path.join(root, 'source', '*.gd'))):
        name = os.path.basename(path)
        src = open(path, encoding='utf-8').read()
        if name == 'levels.gd':
            src = pack_levels(src)
        small = minify(src)
        check = same_program(src, small)
        if check is False:
            print('ERREUR : le fichier compacté diffère :', name)
            ok = False
            continue
        with open(os.path.join(root, name), 'w', encoding='utf-8') as f:
            f.write(small)
        size = len(small.encode('utf-8'))
        total += size
        print('%-18s %7d octets%s' % (name, size, '' if check else '  (non vérifié)'))
    for extra in ('main.tscn', 'project.godot'):
        p = os.path.join(root, extra)
        if os.path.exists(p):
            total += os.path.getsize(p)
    print('TOTAL (scripts + scène) : %d octets = %.1f Ko' % (total, total / 1024))
    if not ok:
        sys.exit(1)


if __name__ == '__main__':
    main()
