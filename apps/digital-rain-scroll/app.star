# Digital Rain — falling glyph columns with fading trails.
#
# A static frame, not an animation: each refresh reseeds the pseudo-random
# generator from the clock, so the rain has visibly moved next time you look.
# Glyphs are drawn as text ops (a few hundred per frame, well inside the 4096
# op budget), which keeps them crisp at any panel width.

GLYPHS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789*+=<>#$%&?"

# head colour, then the trail fading away behind it
PALETTES = {
    "GREEN": ["#DFFFE4", "#5CF08A", "#22C05A", "#14803C", "#0C4A24", "#062E16"],
    "AMBER": ["#FFF3D6", "#FFC24A", "#E08A12", "#9E5C08", "#5E3606", "#331D03"],
    "ICE": ["#EAF9FF", "#8FE2FF", "#3CAEE8", "#1C74AE", "#10456A", "#08283E"],
    "MAGENTA": ["#FFE8FA", "#FF8AD8", "#E043AC", "#A22078", "#631048", "#390828"],
}
DENSITY = {"SPARSE": 55, "MEDIUM": 78, "HEAVY": 96}


def lcg(state):
    return (state * 1103515245 + 12345) % 2147483648


def main(c, ctx):
    pal = PALETTES.get(ctx.inputs.get("palette", "GREEN"), PALETTES["GREEN"])
    fill_pct = DENSITY.get(ctx.inputs.get("density", "MEDIUM"), 70)

    # Wider panels get the larger glyph; the 64 needs the compact one to fit
    # enough columns to read as rain rather than as a few stray letters.
    font = "5x7" if c.width >= 128 else "4x5"
    gw = 6 if font == "5x7" else 5
    gh = 8 if font == "5x7" else 6

    c.fill("#02060A")
    state = (ctx.now.unix // 60) * 2654435761 % 2147483647 + 1

    rowsdown = c.height // gh + 1         # glyph rows that fit on the panel
    cols = c.width // gw
    for i in range(cols):
        state = lcg(state)
        if (state // 1024) % 100 >= fill_pct:
            continue                      # this column is empty this frame

        # Put the head somewhere on the panel, or just below it so the trail
        # still reaches up into view. Heads parked far off-panel would leave
        # most columns blank and the rain would read as scattered litter.
        state = lcg(state)
        head = ((state // 512) % (rowsdown + 2)) * gh
        state = lcg(state)
        trail = 3 + (state // 256) % 4

        x = i * gw
        for j in range(trail):
            y = head - j * gh
            if y <= -gh or y >= c.height:
                continue
            state = lcg(state)
            ch = GLYPHS[(state // 128) % len(GLYPHS)]
            c.text(ch, x, y, font = font, color = pal[j if j < len(pal) else len(pal) - 1])
