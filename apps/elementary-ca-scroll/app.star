# Elementary Automata — Wolfram's one-dimensional cellular automata.
#
# The top row is the seed. Each row below is derived from the one above: the
# three cells overhead form a 0-7 index, and bit `index` of the rule number says
# whether the cell below lives. Thirty-two rows later the panel holds a
# complete, self-similar structure.
#
# One rule per page, so the panel cycles through three characters of behaviour:
# Rule 30 is chaotic (it shipped as Mathematica's random generator), Rule 90
# draws a Sierpinski triangle, and Rule 110 is proven Turing-complete.
#
# The frame is emitted with c.sprite, which collapses to one bitmap op per
# colour. A page may emit only 4096 draw ops and no bitmap may exceed 4096
# cells, while a 192x32 panel is 6144 pixels — so per-pixel drawing is out, and
# the grid is chunked across the width.

LEVELS = "0123456789ABCDEF"
POW2 = [1, 2, 4, 8, 16, 32, 64, 128]

PALETTES = {
    "EMBER": [[38, 6, 2], [[18, 4, 12], [120, 22, 30], [240, 96, 24], [255, 226, 150]]],
    "ICE": [[3, 8, 26], [[8, 18, 52], [22, 92, 150], [86, 200, 226], [236, 252, 255]]],
    "ACID": [[4, 12, 4], [[10, 40, 14], [46, 138, 30], [150, 226, 44], [244, 255, 194]]],
    "MONO": [[8, 8, 10], [[52, 52, 62], [120, 120, 136], [198, 198, 212], [255, 255, 255]]],
}


def ramp(anchors, n):
    """Spread anchor colours into n evenly blended shades."""
    out = []
    segs = len(anchors) - 1
    for i in range(n):
        t = i * segs / (n - 1.0)
        k = int(t)
        if k >= segs:
            k = segs - 1
        f = t - k
        a = anchors[k]
        b = anchors[k + 1]
        out.append([int(a[0] + (b[0] - a[0]) * f),
                    int(a[1] + (b[1] - a[1]) * f),
                    int(a[2] + (b[2] - a[2]) * f)])
    return out


def draw_grid(c, rows, legend):
    """Emit the index grid, chunked so no bitmap exceeds 4096 cells."""
    step = 4096 // c.height
    for x0 in range(0, c.width, step):
        chunk = []
        for r in rows:
            chunk.append(r[x0:x0 + step])
        c.sprite(chunk, x0, 0, legend = legend)


def seed_row(ctx, w, h, mode):
    """The top row the automaton grows from.

    A single live cell spreads only one column per row, so on a panel wider than
    twice its height the classic triangle leaves the sides empty. But seeding
    the whole row at random destroys the very thing that makes each rule worth
    looking at — Rule 90's Sierpinski triangle turns to mush. So AUTO seeds one
    cell on a narrow panel, and evenly SPACED cells on a wide one, which repeats
    the rule's signature across the strip instead of erasing it."""
    if mode == "AUTO":
        mode = "SINGLE" if w <= 2 * h else "SPACED"

    cells = []
    for i in range(w):
        cells.append(0)

    if mode == "SINGLE":
        cells[w // 2] = 1
        return cells

    if mode == "SPACED":
        # One cone per panel-height of width. Spacing them 2h apart left big
        # dead bands under rules like 110 that only grow to one side.
        gap = h
        start = (w % gap) // 2 + gap // 2
        for x in range(start, w, gap):
            cells[x] = 1
        return cells

    state = (ctx.now.unix // 3600) * 2654435761 % 2147483647 + 1
    for i in range(w):
        state = (state * 1103515245 + 12345) % 2147483648
        cells[i] = 1 if (state // 65536) % 100 < 32 else 0
    return cells


def automaton(c, ctx, rule):
    pal = PALETTES.get(ctx.inputs.get("palette", "EMBER"), PALETTES["EMBER"])
    shades = ramp(pal[1], 16)
    legend = {}
    for i in range(16):
        legend[LEVELS[i]] = shades[i]

    w = c.width
    cells = seed_row(ctx, w, c.height, ctx.inputs.get("seed", "AUTO"))

    rows = []
    for y in range(c.height):
        # Colour deepens with depth, so the structure reads as lit from above.
        # The ramp starts at slot 4, not 0: the darkest shades were invisible
        # against the background and the top of every cone read as missing.
        ch = LEVELS[4 + int(y * 11.0 / (c.height - 1.0))]
        line = []
        for x in range(w):
            line.append(ch if cells[x] else ".")
        rows.append("".join(line))

        nxt = []
        for x in range(w):
            idx = cells[(x - 1) % w] * 4 + cells[x] * 2 + cells[(x + 1) % w]
            nxt.append((rule // POW2[idx]) % 2)
        cells = nxt

    c.fill(pal[0])
    draw_grid(c, rows, legend)


def rule30(c, ctx):
    automaton(c, ctx, 30)


def rule90(c, ctx):
    automaton(c, ctx, 90)


def rule110(c, ctx):
    automaton(c, ctx, 110)
