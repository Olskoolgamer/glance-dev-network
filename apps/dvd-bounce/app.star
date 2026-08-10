# Corner Watch — the bouncing logo, and the thing everyone actually waits for.
#
# The logo's position is not simulated frame by frame (there is no frame loop:
# every render is a standalone static image). It is computed directly from the
# clock with a triangle wave, so the panel is correct no matter when it renders
# and never drifts.
#
# That also makes the corner count exact rather than estimated. The logo touches
# the left/right edge every `spanx` steps and the top/bottom every `spany`, so a
# corner happens exactly when a step is a multiple of both — every lcm(spanx,
# spany) steps. No simulation required.

STEP_SECONDS = 30                 # one pixel of travel per half minute

COLORS = ["#FF3B6B", "#FFA51F", "#F5E14B", "#54E36A",
          "#3FC8FF", "#8A6BFF", "#FF6BE0"]


def days_from_civil(y, m, d):
    """Days since the Unix epoch (Howard Hinnant's algorithm)."""
    yy = y - 1 if m <= 2 else y
    era = (yy if yy >= 0 else yy - 399) // 400
    yoe = yy - era * 400
    mp = m - 3 if m > 2 else m + 9
    doy = (153 * mp + 2) // 5 + d - 1
    doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
    return era * 146097 + doe - 719468


def gcd(a, b):
    # Starlark has no while loop; 64 rounds is far more than Euclid ever needs
    # for values this size.
    for i in range(64):
        if b == 0:
            return a
        t = b
        b = a % b
        a = t
    return a


def tri(t, span):
    """Triangle wave: bounce back and forth over 0..span."""
    if span <= 0:
        return 0
    p = t % (2 * span)
    return p if p <= span else 2 * span - p


def geometry(c, ctx):
    """Everything both pages need: logo box, position, and corner maths."""
    label = ctx.inputs.get("label", "GLANCE").upper()
    if len(label) > 8:
        label = label[:8]

    font = "5x7" if c.width >= 128 else "4x5"
    tw = c.text_width(label, font)
    th = 8 if font == "5x7" else 6
    lw = tw + 6
    lh = th + 4

    spanx = c.width - lw
    spany = c.height - lh
    # Count from the start of this year, not from 1970 — "93,332 corners" is a
    # meaningless number, "412 corners this year" is a scoreboard.
    year0 = days_from_civil(ctx.now.year, 1, 1) * 86400
    t = (ctx.now.unix - year0) // STEP_SECONDS

    period = 0
    if spanx > 0 and spany > 0:
        g = gcd(spanx, spany)
        period = spanx // g * spany        # lcm(spanx, spany)

    return {
        "label": label, "font": font, "lw": lw, "lh": lh,
        "x": tri(t, spanx), "y": tri(t, spany),
        "t": t, "period": period,
        "hits": t // period if period > 0 else 0,
        "togo": (period - t % period) if period > 0 else 0,
    }


def logo(c, g, color):
    c.round_rect(g["x"], g["y"], g["x"] + g["lw"] - 1, g["y"] + g["lh"] - 1,
                 2, fill = color)
    c.text(g["label"], g["x"] + g["lw"] // 2, g["y"] + 2, font = g["font"],
           color = "#0B0B12", align = "center")


def bounce(c, ctx):
    """Just the logo, drifting."""
    g = geometry(c, ctx)
    c.fill("#07070C")
    # The colour changes on every edge bounce, exactly like the real thing.
    bounces = g["t"] // max(1, c.width - g["lw"]) + g["t"] // max(1, c.height - g["lh"])
    logo(c, g, COLORS[bounces % len(COLORS)])


def record(c, ctx):
    """The score: corners hit, and how long until the next one."""
    g = geometry(c, ctx)
    c.fill("#07070C")

    mins = g["togo"] * STEP_SECONDS // 60
    if mins >= 1440:
        togo = "%dD" % (mins // 1440)
    elif mins >= 60:
        togo = "%dH" % (mins // 60)
    else:
        togo = "%dM" % mins

    if c.width >= 128:
        c.text("CORNERS THIS YEAR", 6, 2, font = "5x7", color = "#6A6A88")
        c.text(fmt.commas(g["hits"]), 6, 11, font = "16x20", color = "#F5E14B")
        c.text("NEXT IN", c.width - 6, 4, font = "4x5", color = "#6A6A88",
               align = "right")
        c.text(togo, c.width - 6, 12, font = "10x16", color = "#3FC8FF",
               align = "right")
    else:
        c.text("CORNERS", c.width // 2, 1, font = "4x5", color = "#6A6A88",
               align = "center")
        c.text(str(g["hits"]), c.width // 2, 8, font = "10x16",
               color = "#F5E14B", align = "center")
        c.text("NEXT " + togo, c.width // 2, 26, font = "4x5",
               color = "#3FC8FF", align = "center")
