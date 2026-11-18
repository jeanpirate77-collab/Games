# Génère source/levels.gd (lisible) à partir de morceaux de niveaux.
# Utilisation : python3 outils/niveaux.py niveaux.txt
import sys
H = 12

def ch(w, spec, ground=True, ceiling=False):
    g = []
    for r in range(H):
        if r in spec:
            s = spec[r]
        elif ground and r >= 10:
            s = '#' * w
        elif ceiling and r <= 1:
            s = '#' * w
        else:
            s = '.' * w
        assert len(s) == w, (w, r, s, len(s))
        g.append(s)
    return g

# ---------- FORÊT ----------
F = {}
F['start'] = ch(12, {8: "....o.o.o...", 9: ".P.........."})
F['walk'] = ch(14, {8: "..o..o..o..o..", 9: "........w....."})
F['pit3'] = ch(9, {7: "...ooo...", 10: "###...###", 11: "###...###"})
F['steps'] = ch(16, {
    4: "..........*.....",
    5: "..........o.....",
    6: "........=====...",
    7: "...ooo..........",
    8: "...====.........",
    9: "..............w.",
})
F['spikes'] = ch(14, {7: "......ooo.....", 9: "..B....^^^...."})
F['shooter'] = ch(16, {8: "..o.o...........", 9: "......B.....s..."})
F['check'] = ch(6, {9: "..C..."})
F['bats'] = ch(16, {4: "....f.......f...", 9: "..o..o..o..o..o."})
F['mover'] = ch(14, {6: "......*.......", 7: "......o.......", 8: "....m.........",
                     10: "##.........###", 11: "##.........###"})
F['hill'] = ch(20, {
    6: "........*..o........",
    7: "......o.....w.o.....",
    8: "......########......",
    9: "......########......",
})
F['jumper'] = ch(14, {8: "..o.......o...", 9: ".......j......"})
F['heart'] = ch(8, {7: "...h....", 8: "..====.."})
F['crates'] = ch(12, {6: "....*.......", 8: "....B.......", 9: "...BBB...w.."})
F['secret'] = ch(14, {
    2: "..........*...",
    3: "..........o...",
    4: ".........===..",
    5: "..............",
    6: "......===.....",
    7: "..............",
    8: "..===.........",
    9: ".........^^...",
})
F['pit2bat'] = ch(10, {4: ".....f....", 7: "....oo....", 10: "###....###", 11: "###....###"})
F['exit'] = ch(10, {9: "......E...", 8: ".........."})
F['exit'] = [r[:-1] + '#' if i < 10 else r for i, r in enumerate(F['exit'])]

# ---------- GROTTE (plafond) ----------
def cave(c):
    out = []
    for i, r in enumerate(c):
        if i <= 1:
            r = '#' * len(r)
        out.append(r)
    return out

G = {}
G['start'] = cave(ch(12, {2: ".v....v..v..", 8: "....o.o.o...", 9: ".P.........."}))
G['drip'] = cave(ch(16, {2: "..vv....vvv.....", 8: "..o..o..o..o..o.", 9: ".....w.........."}))
G['pit4'] = cave(ch(12, {6: "....oooo....", 8: ".....==.....", 10: "###......###", 11: "###......###"}))
G['low'] = cave(ch(18, {
    2: "##################",
    3: "################..",
    4: "....v.....v.......",
    8: "...o..o..o..o.....",
    9: "..........w.......",
}))
G['tower'] = cave(ch(18, {
    3: "............*.....",
    4: "...........===....",
    5: "..................",
    6: "......====........",
    7: "..................",
    8: "..====.......o....",
    9: "..........j.......",
}))
G['spikes'] = cave(ch(16, {2: "....vvvv........", 7: "....ooo.........", 9: "...^^^.....s...."}))
G['bats'] = cave(ch(16, {4: "...f......f.....", 9: "..o..o..o..o..o."}))
G['mover2'] = cave(ch(20, {6: "........*.....o.....", 8: "....m.........m.....",
                          10: "##................##", 11: "##................##"}))
G['check'] = cave(ch(6, {9: "..C..."}))
G['crates'] = cave(ch(12, {6: "...*........", 8: "..BB........", 9: "..BB..j....."}))
G['heart'] = cave(ch(8, {7: "...h....", 8: "..====.."}))
G['shoot2'] = cave(ch(18, {8: "......===.........", 7: ".......s..........", 9: "..............s..."}))
G['exit'] = cave(ch(10, {9: "......E..#", 8: ".........#", 7: ".........#", 6: ".........#",
                         5: ".........#", 4: ".........#", 3: ".........#", 2: ".........#"}))

# ---------- CHÂTEAU ----------
C = {}
C['start'] = ch(12, {8: "....o.o.o...", 9: ".P.........."})
C['ghost'] = ch(16, {5: "..........g.....", 9: "..o..o..o..o..o."})
C['wall'] = ch(18, {
    4: "...........*......",
    5: "..........###.....",
    6: "......===.###.....",
    7: "..........###.....",
    8: "...===....###.....",
    9: "..........###..w..",
})
C['pit3'] = ch(10, {6: "...ooo....", 4: "....f.....", 10: "###...####", 11: "###...####"})
C['spikes'] = ch(18, {7: "....ooo....ooo....", 9: "...^^^....^^^...s."})
C['mover'] = ch(22, {6: "...*.........o........", 7: "......................", 8: "...m.........m........",
                     10: "##..................##", 11: "##..................##"})
C['shard'] = ch(16, {
    1: ".........*......",
    2: ".........o......",
    3: "........===.....",
    4: "................",
    5: "....===.........",
    6: "................",
    7: "........===.....",
    8: "...=====........",
    9: "............g...",
})
C['check'] = ch(6, {9: "..C..."})
C['knights'] = ch(16, {8: "..o..o..o..o..o.", 9: "...w.....j...w.."})
C['heart'] = ch(8, {7: "...h....", 8: "..====.."})
C['crates'] = ch(12, {6: "....*.......", 8: "....B..B....", 9: "...BBBBBB..."})
C['bats'] = ch(16, {3: "..f....f....f...", 9: "..o..o..o..o..o."})
C['shard2'] = ch(14, {
    7: "...........*..",
    8: ".........=====",
    9: "...^^^........",
})
C['exit'] = ch(10, {9: "......E..."})


# ---------- NOUVEAUX MORCEAUX (obstacles) ----------
# FORÊT
F['springs'] = ch(16, {
    2: "..........*.....",
    3: "..........o.....",
    4: ".........===....",
    7: ".....o..........",
    9: "....k......w....",
})
F['saws'] = ch(18, {8: "....r.......r.....", 6: "......o..o........", 9: "........o.........", 7: "..o............o.."})
F['pend'] = ch(16, {6: "........q.......", 9: "..o..o.....o..o."})
F['fragile'] = ch(12, {7: "....oooo....", 10: "##xxxxxxxx##", 11: "##........##"})
F['flames'] = ch(16, {7: "...ooo....ooo...", 9: "....l......l...."})
F['eyes'] = ch(14, {4: "......e.......", 9: "..o..o..o..o.."})
F['knight'] = ch(14, {8: "...o....o....o", 9: ".......K......"})
F['shard_spring'] = ch(12, {1: "........*...", 9: "........k...", 2: "........o...", 3: "........o..."})

# GROTTE
G['stal'] = cave(ch(18, {2: "...u....u....u....", 9: "..o..o..o..o..o..."}))
G['flames'] = cave(ch(18, {9: "...l....l....l....", 6: "..o....o....o....o", 8: "..T...............".replace('T', '.')}))
G['torches'] = cave(ch(14, {9: ".T.....w....T."}))
G['saws'] = cave(ch(16, {8: "...r......r.....", 9: "......o.........", 7: "..o..........o.."}))
G['springs'] = cave(ch(14, {
    3: "......*.......",
    4: ".....===......",
    9: "...k......e...".replace('e', '.'),
    5: "..............",
}))
G['eyes'] = cave(ch(14, {5: "....e.....e...", 9: "..o..o..o..o.."}))
G['fragile'] = cave(ch(14, {6: "....oooooo....", 10: "##xxxxxxxxxx##", 11: "##..........##"}))

# CHÂTEAU
C['pend'] = ch(18, {6: "....q.......q.....", 9: "..o...o...o...o...", 8: "T................T"})
C['flames'] = ch(16, {9: "..l...l...l...l.", 6: "..o...o...o...o."})
C['knight2'] = ch(16, {9: "..T...K.....K.T.", 8: "...o..o..o..o..."})
C['saws'] = ch(18, {8: "...r.....r.....r..", 6: "...o.....o.....o.."})
C['springs'] = ch(16, {
    2: ".........*......",
    3: "........===.....",
    9: "....k.......e...".replace('e', '.'),
    5: "....e...........",
})
C['fragile'] = ch(14, {7: "...oooooooo...", 10: "##xxxxxxxxxx##", 11: "##..........##"})
C['eyes'] = ch(14, {4: "...e......e...", 9: "..o..o..o..o.."})

# ---------- MARAIS (acide, rondins, brume) ----------
M = {}
M['start'] = ch(12, {8: "....o.o.o...", 9: ".P.........."})
M['pool'] = ch(14, {6: "....oooooo....", 8: ".....====.....", 10: "##aaaaaaaaaa##"})
M['pool2'] = ch(18, {7: "...o.....o.....o..", 8: "..===...===...===.", 10: "#aaaaaaaaaaaaaaaa#"})
M['jumpers'] = ch(14, {8: "..o.......o...", 9: "....j....j...."})
M['eyes'] = ch(14, {4: "....e....e....", 9: "..o..o..o..o.."})
M['fragile'] = ch(14, {7: "...oooooooo...", 10: "##xxxxxxxxxx##", 11: "##aaaaaaaaaa##"})
M['shard'] = ch(16, {
    2: "...........*....",
    3: "...........o....",
    4: "..........===...",
    6: "......===.......",
    8: "..===...........",
    10: "################",
    9: ".........g......",
})
M['shard2'] = ch(12, {1: "......*.....", 2: "......o.....", 9: "......k.....", 10: "############"})
M['ghost'] = ch(16, {5: "..........g.....", 9: "..o..o..o..o..o."})
M['check'] = ch(6, {9: "..C..."})
M['heart'] = ch(8, {7: "...h....", 8: "..====.."})
M['crates'] = ch(12, {6: "....*.......", 8: "....B.......", 9: "...BBB...w.."})
M['pend'] = ch(16, {6: ".......q........", 9: "..o..o.....o..o."})
M['bats'] = ch(16, {4: "...f......f.....", 9: "..o..o..o..o..o."})
M['exit'] = ch(10, {9: "......E..."})

# ---------- NUAGES (îles flottantes, ressorts, vent) ----------
N = {}
def isl(w, spec):
    # île : sol seulement là où la ligne 10 l'indique
    return ch(w, spec)
N['start'] = ch(12, {8: "....o.o.o...", 9: ".P.........."})
N['gap'] = ch(14, {6: ".....oooo.....", 10: "#####....#####", 11: "#####....#####"})
N['islands'] = ch(20, {
    7: ".....o......o.......",
    8: "....===....===......",
    10: "###..............###",
    11: "###..............###",
})
N['springs'] = ch(16, {
    2: "..........*.....",
    3: ".........===....",
    9: "...k............",
    10: "################",
})
N['clouds'] = ch(16, {7: "..o....o....o...", 8: "..x....x....x...", 10: "##............##", 11: "##............##"})
N['saws'] = ch(18, {8: "....r.......r.....", 6: "....o.......o.....", 9: "........e.........".replace('e', '.')})
N['eyes'] = ch(14, {4: "...e......e...", 9: "..o..o..o..o.."})
N['fragile'] = ch(14, {7: "...oooooooo...", 10: "##xxxxxxxxxx##", 11: "##..........##"})
N['shard'] = ch(14, {1: "......*.......", 2: "......o.......", 9: "......k.......", 3: "......o......."})
N['shard2'] = ch(16, {
    3: "............*...",
    4: "...........===..",
    6: ".......===......",
    8: "...===..........",
    10: "###.............",
    11: "###.............",
})
N['land'] = ch(6, {10: "######", 11: "######"})
N['check'] = ch(6, {9: "..C..."})
N['heart'] = ch(8, {7: "...h....", 8: "..====.."})
N['knight'] = ch(14, {8: "...o....o....o", 9: ".......K......"})
N['bats'] = ch(16, {4: "...f......f.....", 9: "..o..o..o..o..o."})
N['exit'] = ch(10, {9: "......E..."})

def compose(lib, names):
    rows = [''] * H
    for n in names:
        c = lib[n]
        for i in range(H):
            rows[i] += c[i]
    # murs aux bords
    rows = ['#' + r[1:-1] + '#' for r in rows]
    # 3 éclats maximum par niveau (les autres deviennent des pièces)
    n = 0
    grid = [list(r) for r in rows]
    for c in range(len(rows[0])):
        for r in range(H):
            if grid[r][c] == '*':
                n += 1
                if n > 3:
                    grid[r][c] = 'o'
    return [''.join(r) for r in grid]

def arena(world):
    w = 26
    spec = {
        8: "....====..........====....",
        7: ".....h............h.......",
        9: "...P..................E...",
        3: "............Z.............",
    }
    if world == 3:
        spec[10] = "##########aaaaaa##########"
    if world == 4:
        spec[9] = "...P.......k..........E..."
    rows = ch(w, spec, ceiling=(world == 1))
    rows = ['#' + r[1:-1] + '#' for r in rows]
    return rows

LEVELS = [
    ("1-1  Forêt morte", 0, "", compose(F, ['start', 'walk', 'pit3', 'steps', 'spikes', 'check', 'shooter', 'heart', 'bats', 'mover', 'hill', 'exit'])),
    ("1-2  Le bois des corbeaux", 0, "", compose(F, ['start', 'jumper', 'pit2bat', 'crates', 'secret', 'check', 'hill', 'mover', 'shooter', 'heart', 'bats', 'pit3', 'steps', 'check', 'spikes', 'jumper', 'exit'])),
    ("1-3  Les pièges du bûcheron", 0, "", compose(F, ['start', 'springs', 'walk', 'saws', 'pit3', 'pend', 'check', 'fragile', 'flames', 'heart', 'eyes', 'shard_spring', 'check', 'saws', 'knight', 'crates', 'pend', 'exit'])),
    ("1-4  BOSS : le Corbeau", 0, "corbeau", arena(0)),
    ("2-1  Grotte humide", 1, "", compose(G, ['start', 'drip', 'pit4', 'tower', 'check', 'spikes', 'bats', 'heart', 'mover2', 'crates', 'exit'])),
    ("2-2  Profondeurs", 1, "", compose(G, ['start', 'low', 'shoot2', 'pit4', 'check', 'crates', 'tower', 'mover2', 'heart', 'spikes', 'check', 'bats', 'drip', 'pit4', 'shoot2', 'exit'])),
    ("2-3  La mine abandonnée", 1, "", compose(G, ['start', 'torches', 'stal', 'pit4', 'springs', 'flames', 'check', 'saws', 'eyes', 'heart', 'fragile', 'torches', 'stal', 'check', 'crates', 'flames', 'tower', 'exit'])),
    ("2-4  BOSS : le Golem", 1, "golem", arena(1)),
    ("3-1  Les marais", 3, "", compose(M, ['start', 'pool', 'jumpers', 'check', 'crates', 'pool2', 'eyes', 'heart', 'shard', 'ghost', 'pool', 'shard2', 'exit'])),
    ("3-2  La tourbière", 3, "", compose(M, ['start', 'jumpers', 'fragile', 'pend', 'check', 'pool2', 'bats', 'shard', 'heart', 'ghost', 'pool', 'check', 'eyes', 'fragile', 'crates', 'pool2', 'shard2', 'exit'])),
    ("3-3  Le cœur du marais", 3, "", compose(M, ['start', 'ghost', 'pool2', 'fragile', 'check', 'pend', 'shard2', 'eyes', 'heart', 'pool2', 'jumpers', 'check', 'crates', 'pend', 'pool', 'bats', 'shard', 'exit'])),
    ("3-4  BOSS : le Crapaud géant", 3, "crapaud", arena(3)),
    ("4-1  Mer de nuages", 4, "", compose(N, ['start', 'gap', 'islands', 'springs', 'check', 'clouds', 'bats', 'heart', 'land', 'shard', 'gap', 'eyes', 'shard2', 'land', 'exit'])),
    ("4-2  Les vents d'altitude", 4, "", compose(N, ['start', 'clouds', 'saws', 'gap', 'check', 'fragile', 'springs', 'eyes', 'heart', 'land', 'islands', 'check', 'knight', 'shard', 'gap', 'shard2', 'land', 'exit'])),
    ("4-3  Le sommet", 4, "", compose(N, ['start', 'islands', 'fragile', 'saws', 'check', 'clouds', 'shard2', 'land', 'eyes', 'heart', 'gap', 'bats', 'check', 'springs', 'knight', 'clouds', 'shard', 'land', 'exit'])),
    ("4-4  BOSS : le Dragon de brume", 4, "dragon", arena(4)),
    ("5-1  Remparts", 2, "", compose(C, ['start', 'ghost', 'wall', 'pit3', 'check', 'spikes', 'heart', 'shard', 'mover', 'knights', 'exit'])),
    ("5-2  Le donjon", 2, "", compose(C, ['start', 'crates', 'bats', 'pit3', 'wall', 'check', 'shard2', 'ghost', 'mover', 'heart', 'spikes', 'check', 'knights', 'shard', 'pit3', 'ghost', 'exit'])),
    ("5-3  La salle des supplices", 2, "", compose(C, ['start', 'pend', 'flames', 'knight2', 'check', 'saws', 'fragile', 'springs', 'heart', 'eyes', 'pend', 'check', 'shard', 'flames', 'knight2', 'shard2', 'exit'])),
    ("5-4  BOSS : le Roi Ombre", 2, "roi", arena(2)),
]


# =====================================================================
#  NIVEAUX EN RELIEF : 18 lignes, sol à hauteur variable, pentes, sections verticales
# =====================================================================
HT = 18

def place(chunk, h, cave):
    """Pose un morceau de 12 lignes avec son sol (ligne 10) à la ligne 14-h."""
    off = 4 - h
    w = len(chunk[0])
    rows = [['.'] * w for _ in range(HT)]
    for c in range(w):
        pit = chunk[11][c] == '.'
        top = chunk[0][c] == '#'
        for r in range(HT):
            cr = r - off
            if 0 <= cr < 12:
                ch = chunk[cr][c]
            elif cr < 0:
                ch = '#' if (cave and top) else '.'
            else:
                ch = '.' if pit else '#'
            rows[r][c] = ch
    return [''.join(r) for r in rows]

def slope(h1, h2, cave):
    """Transition en pente entre deux hauteurs de sol."""
    d = h2 - h1
    w = abs(d)
    g1 = 14 - h1
    rows = [['.'] * w for _ in range(HT)]
    for k in range(w):
        if d > 0:
            rr = g1 - 1 - k
            ch = '/'
        else:
            rr = g1 + k
            ch = '\\'
        rows[rr][k] = ch
        for r in range(rr + 1, HT):
            rows[r][k] = '#'
        if cave:
            for r in range(0, 6 - max(h1, h2)):
                rows[r][k] = '#'
    return [''.join(r) for r in rows]

def tall(rows_spec, w, cave):
    rows = []
    for r in range(HT):
        s2 = rows_spec.get(r, '#' * w if r >= 15 else '.' * w)
        assert len(s2) == w, (r, s2, len(s2), w)
        rows.append(s2)
    if cave:
        rows = ['#' * w if r < 2 else rows[r] for r in range(HT)]
    return rows

# Sections verticales : (lignes, hauteur d'entrée, hauteur de sortie)
TALL = {}
TALL['souterrain'] = ({
    10: "....................",
    11: "..o.o...........o...",
    12: "######...#######..##",
    13: "######.............#",
    14: "######.o.o.*.o.....#",
    15: "######......w...k..#",
    16: "####################",
    17: "####################",
}, 20, 2, 2)
TALL['ascension'] = ({
    7: "......f.......",
    8: "..........o.o.",
    9: "......o.......",
    10: ".........#####",
    11: ".........#####",
    12: "....===..#####",
    13: ".........#####",
    14: "##############",
}, 14, 0, 4)
TALL['falaise'] = ({
    9: "......o.o.....",
    10: "#####.........",
    11: "#####...o.....",
    12: "#####..===....",
    13: "#####.....w...",
    14: "##############",
}, 14, 4, 0)
TALL['ascenseur'] = ({
    7: "..o.o.......",
    8: "....o.....o.",
    10: ".......#####",
    11: ".......#####",
    12: "....M..#####",
    13: ".......#####",
    14: "############",
}, 12, 0, 4)
TALL['cachette'] = ({
    9: "......o..o......",
    10: "....########....",
    11: "....D......#....",
    12: "..#.D..o.c.#....",
    13: "################",
    14: "################",
}, 16, 1, 1)
TALL['bassin'] = ({
    10: "....o.......o.....",
    11: "..................",
    12: "...o..........o...",
    13: "###~~~~~~~~~~~~###",
    14: "###~~~~o~~o~~~~###",
    15: "###~~o~~~*~~o~~###",
    16: "###~~~~~~~~~~~~###",
    17: "##################",
}, 18, 1, 1)
TALL['douves'] = ({
    9: "...........o.o....",
    10: "......===.........",
    13: "###~~~~~~~~~~~~###",
    14: "###~~~~~~o~~~~~###",
    15: "###~~o~~~~~o~~~###",
    16: "###~~~~~~~~~~~~###",
    17: "##################",
}, 18, 1, 1)
TALL['puits'] = ({
    8: "..o..........o..",
    9: "................",
    10: "....====..====..",
    12: "#####......#####",
    13: "#####..o...#####",
    14: "#####...$..#####",
    15: "#####..k...#####",
    16: "################",
    17: "################",
}, 16, 2, 2)

def compose2(lib, seq, cave=False):
    """seq : liste de 'morceau@hauteur' ou de noms de sections verticales."""
    parts = []
    cur_h = None
    for item in seq:
        if item in TALL:
            spec, w, hin, hout = TALL[item]
            block = tall(spec, w, cave)
        else:
            name, _, hs = item.partition('@')
            hin = hout = int(hs or 0)
            block = place(lib[name], hin, cave)
        if cur_h is not None and cur_h != hin:
            parts.append(slope(cur_h, hin, cave))
        parts.append(block)
        cur_h = hout
    rows = [''.join(p[r] for p in parts) for r in range(HT)]
    rows = ['#' + r[1:-1] + '#' for r in rows]
    # 3 éclats maximum par niveau
    n = 0
    grid = [list(r) for r in rows]
    for c in range(len(rows[0])):
        for r in range(HT):
            if grid[r][c] == '*':
                n += 1
                if n > 3:
                    grid[r][c] = 'o'
    return [''.join(r) for r in grid]

# ---- nouveaux morceaux (obstacles variés)
F['boules'] = ch(16, {7: ".....O.....O....", 9: "..o.....o.....o."})
F['bassin_vent'] = ch(16, {4: "....o....o......", 10: "##...V....V...##", 11: "##............##"})
F['tresor'] = ch(10, {7: "....$.....", 8: "...===...."})
G['boules'] = cave(ch(16, {6: ".....O.....O....", 9: "..o..T..o..T..o."}))
G['canons'] = cave(ch(16, {9: "...n.....B...n..", 8: ".........B......", 7: "..o.......o....."}))
G['tresor'] = cave(ch(10, {7: "....$.....", 8: "...===....", 9: ".T......T."}))
C['canons'] = ch(16, {9: "...n....B....n..", 8: "........B.......", 6: "..o....o....o..."})
C['boules'] = ch(16, {7: ".....O.....O....", 9: "..o..T..o..T..o."})
C['tresor'] = ch(10, {7: "....$.....", 8: "...===...."})
M['boules'] = ch(16, {7: ".....O..........", 9: "..o.....j.....o."})
M['tresor'] = ch(10, {7: "....$.....", 8: "...===....", 10: "##aaaaaa##"})
N['vents'] = ch(16, {4: "....o....o......", 10: "##...V....V...##", 11: "##............##"})
N['vents2'] = ch(20, {3: "...o.....o.....o....", 10: "##..V.....V.....V.##", 11: "##..................##"[:20]})
N['canons'] = ch(16, {9: "...n.....B...n..", 8: ".........B......", 7: "..o.......o....."})
N['tresor'] = ch(10, {7: "....$.....", 8: "...===...."})
N['ascenseur_v'] = ch(14, {6: "..o.......o...", 7: "....M.........", 10: "##..........##", 11: "##..........##"})

def arena(world):
    w = 26
    spec = {
        8: "....====..........====....",
        7: ".....h............h.......",
        9: "...P..................E...",
        3: "............Z.............",
    }
    if world == 3:
        spec[10] = "#####aaaaaa########aaaaa##"
    if world == 4:
        spec[9] = "...P.......k..........E..."
    rows = ch(w, spec, ceiling=(world == 1))
    rows = ['#' + r[1:-1] + '#' for r in rows]
    return rows

LEVELS = [
    ("1-1  Forêt morte", 0, "", compose2(F, ['start@0', 'walk@1', 'pit3@1', 'steps@2', 'souterrain', 'spikes@1', 'check@1', 'shooter@0', 'ascension', 'heart@4', 'bats@3', 'falaise', 'mover@0', 'hill@1', 'exit@1'])),
    ("1-2  Le bois des corbeaux", 0, "", compose2(F, ['start@1', 'jumper@2', 'pit2bat@2', 'bassin', 'crates@0', 'secret@0', 'check@1', 'cachette', 'hill@2', 'mover@2', 'boules@1', 'heart@0', 'ascenseur', 'bats@4', 'tresor@3', 'pit3@3', 'falaise', 'check@0', 'spikes@1', 'jumper@2', 'exit@2'])),
    ("1-3  Les pièges du bûcheron", 0, "", compose2(F, ['start@0', 'springs@0', 'walk@1', 'saws@2', 'pit3@2', 'pend@1', 'check@1', 'puits', 'fragile@2', 'flames@1', 'heart@0', 'ascension', 'eyes@4', 'boules@3', 'shard_spring@3', 'check@2', 'bassin_vent@2', 'saws@1', 'knight@0', 'crates@1', 'pend@2', 'exit@2'])),
    ("1-4  BOSS : le Corbeau", 0, "corbeau", arena(0)),
    ("2-1  Grotte humide", 1, "", compose2(G, ['start@0', 'drip@1', 'pit4@1', 'tower@0', 'souterrain', 'check@2', 'spikes@1', 'bats@0', 'bassin', 'heart@2', 'mover2@2', 'crates@1', 'exit@1'], cave=True)),
    ("2-2  Profondeurs", 1, "", compose2(G, ['start@2', 'low@2', 'shoot2@1', 'pit4@0', 'check@0', 'canons@1', 'ascension', 'crates@4', 'tower@3', 'falaise', 'mover2@0', 'heart@1', 'spikes@2', 'check@2', 'cachette', 'bats@0', 'boules@1', 'drip@2', 'pit4@2', 'shoot2@1', 'exit@1'], cave=True)),
    ("2-3  La mine abandonnée", 1, "", compose2(G, ['start@1', 'torches@1', 'stal@2', 'pit4@2', 'springs@1', 'puits', 'flames@1', 'check@0', 'saws@0', 'canons@1', 'ascenseur', 'eyes@4', 'tresor@3', 'heart@2', 'fragile@2', 'boules@1', 'torches@0', 'stal@1', 'check@1', 'crates@2', 'flames@2', 'tower@1', 'exit@1'], cave=True)),
    ("2-4  BOSS : le Golem", 1, "golem", arena(1)),
    ("3-1  Les marais", 3, "", compose2(M, ['start@1', 'pool@1', 'jumpers@2', 'check@2', 'crates@1', 'bassin', 'pool2@1', 'eyes@0', 'heart@1', 'shard@2', 'ghost@1', 'boules@1', 'pool@0', 'shard2@1', 'exit@1'])),
    ("3-2  La tourbière", 3, "", compose2(M, ['start@0', 'jumpers@1', 'fragile@1', 'pend@2', 'check@2', 'souterrain', 'pool2@1', 'bats@0', 'shard@1', 'tresor@2', 'heart@2', 'ghost@1', 'ascension', 'pool@4', 'check@3', 'falaise', 'eyes@0', 'fragile@1', 'crates@2', 'pool2@1', 'shard2@1', 'exit@1'])),
    ("3-3  Le cœur du marais", 3, "", compose2(M, ['start@1', 'ghost@2', 'pool2@2', 'fragile@1', 'check@1', 'cachette', 'pend@2', 'shard2@3', 'eyes@2', 'boules@1', 'heart@1', 'bassin', 'pool2@2', 'jumpers@3', 'check@2', 'crates@1', 'pend@0', 'pool@1', 'bats@2', 'shard@1', 'exit@1'])),
    ("3-4  BOSS : le Crapaud géant", 3, "crapaud", arena(3)),
    ("4-1  Mer de nuages", 4, "", compose2(N, ['start@2', 'gap@2', 'islands@3', 'springs@1', 'check@1', 'vents@2', 'clouds@2', 'bats@3', 'heart@3', 'land@3', 'ascenseur_v@2', 'shard@1', 'gap@2', 'eyes@3', 'shard2@4', 'land@3', 'exit@2'])),
    ("4-2  Les vents d'altitude", 4, "", compose2(N, ['start@1', 'vents2@1', 'saws@2', 'gap@2', 'check@3', 'fragile@3', 'springs@2', 'canons@2', 'eyes@1', 'heart@1', 'land@1', 'islands@2', 'check@2', 'knight@3', 'tresor@3', 'shard@2', 'gap@1', 'vents@1', 'shard2@2', 'land@2', 'exit@1'])),
    ("4-3  Le sommet", 4, "", compose2(N, ['start@0', 'islands@1', 'fragile@1', 'saws@2', 'check@3', 'ascenseur_v@3', 'clouds@4', 'vents2@3', 'shard2@3', 'land@4', 'eyes@4', 'heart@4', 'gap@3', 'bats@2', 'check@2', 'springs@1', 'canons@2', 'knight@2', 'clouds@3', 'shard@2', 'land@2', 'exit@2'])),
    ("4-4  BOSS : le Dragon de brume", 4, "dragon", arena(4)),
    ("5-1  Remparts", 2, "", compose2(C, ['start@0', 'ghost@1', 'wall@1', 'pit3@1', 'check@2', 'douves', 'spikes@2', 'canons@2', 'heart@1', 'shard@0', 'ascension', 'mover@4', 'knights@3', 'exit@3'])),
    ("5-2  Le donjon", 2, "", compose2(C, ['start@1', 'crates@1', 'bats@2', 'pit3@2', 'wall@1', 'check@1', 'boules@2', 'shard2@2', 'cachette', 'ghost@2', 'mover@2', 'heart@3', 'canons@3', 'spikes@2', 'check@2', 'puits', 'knights@1', 'shard@0', 'pit3@1', 'ghost@1', 'exit@1'])),
    ("5-3  La salle des supplices", 2, "", compose2(C, ['start@0', 'pend@0', 'flames@1', 'knight2@1', 'check@2', 'saws@2', 'boules@1', 'fragile@1', 'douves', 'springs@2', 'canons@3', 'heart@3', 'eyes@2', 'pend@1', 'check@1', 'ascension', 'tresor@4', 'shard@3', 'flames@3', 'falaise', 'knight2@0', 'shard2@1', 'exit@1'])),
    ("5-4  BOSS : le Roi Ombre", 2, "roi", arena(2)),
]


out = []
out.append('# NIVEAUX DU JEU OMBRES : 1 caractère = 1 case de 32 px.')
out.append('# Ce fichier se modifie librement. Une ligne "=== nom|monde|boss" commence un niveau,')
out.append('# puis viennent les lignes de la carte (toutes de la même longueur).')
out.append('# Mondes : 0 forêt, 1 grotte, 2 château, 3 marais, 4 nuages.')
out.append('# Les lignes qui commencent par # (avant le premier niveau) sont des commentaires.')
out.append('#')
out.append('#   #  sol / mur            =  plateforme fine (traversable par le dessous)')
out.append('#   B  caisse cassable      ^  pics au sol      v  pics au plafond')
out.append('#   o  pièce   h  coeur   *  éclat de lune (3 par niveau)   $  grosse pièce (10)')
out.append('#   w  marcheur   s  tireur   f  chauve-souris   j  sauteur   g  spectre   e  oeil   K  chevalier noir')
out.append('#   a  acide   x  plateforme fragile   k  ressort   r  scie   l  jet de flammes')
out.append('#   u  stalactite qui tombe   q  pendule   T  torche   O  boule à pointes   n  canon   V  courant d\'air')
out.append('#   /  pente qui monte   \\  pente qui descend   ~  eau (on nage)   D  mur fissuré (à casser)')
out.append('#   c  coffre (à casser)   m  plateforme mobile   M  plateforme qui monte et descend')
out.append('#   C  point de passage   E  sortie   P  départ   Z  boss')
for name, world, boss, rows in LEVELS:
    wd = len(rows[0])
    assert all(len(r) == wd for r in rows), name
    txt = ''.join(rows)
    assert txt.count('P') == 1, name
    assert txt.count('E') == 1, name
    print(f"{name}: {wd} cases, éclats={txt.count('*')}, pièces={txt.count('o')}", file=sys.stderr)
    out.append('=== %s|%d|%s' % (name, world, boss))
    for r in rows:
        assert not r.startswith('#') or True
        out.append(r)
open(sys.argv[1], 'w').write('\n'.join(out) + '\n')
if len(sys.argv) > 2:
    for name, world, boss, rows in LEVELS:
        print(name, file=sys.stderr)
        for r in rows:
            print(r, file=sys.stderr)
