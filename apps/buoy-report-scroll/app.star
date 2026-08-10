# Buoy Report
#
# NDBC's latest_obs file is plain text, not JSON, and about 400
# bytes — far kinder than the 600KB full history file. It is parsed
# by finding a line by its prefix and pulling the first number out,
# which is robust to the column drift between buoy types.



NODATA_FONTS = ["10x16", "6x8", "5x7", "4x5"]


def _fit_clip(c, text, fonts, maxw):
    """[font, text] for the largest font that fits, clipping if none do.

    text_fit alone was not enough here: when even its smallest option
    overflows it still draws, which ran these messages off a 64 panel."""
    pick = fonts[len(fonts) - 1]
    for f in fonts:
        if c.text_width(text, f) <= maxw:
            pick = f
            break
    t = text
    if c.text_width(t, pick) > maxw:
        for k in range(len(t), 0, -1):
            if c.text_width(t[:k], pick) <= maxw:
                t = t[:k]
                break
    return [pick, t]


def nodata(c, title, sub):
    """Shown whenever a feed is unreachable or a key is missing.

    Every network app needs one: the publish-time validator renders each page
    with the network disabled, and a panel on a wall must say something
    sensible rather than going blank.

    The two lines get explicit, non-overlapping bands — a 16px title centred
    on the panel ran straight through the line beneath it.
    Wide:   4-19 title | 22-28 detail
    Narrow: 5-12 title | 18-22 detail
    """
    c.fill("#0B0C12")
    maxw = c.width - 6
    if c.width >= 128:
        t = _fit_clip(c, title, NODATA_FONTS, maxw)
        c.text(t[1], c.width // 2, 4, font = t[0], color = "#E8B04A",
               align = "center")
        d = _fit_clip(c, sub, ["5x7", "4x5"], maxw)
        c.text(d[1], c.width // 2, 22, font = d[0], color = "#6A7090",
               align = "center")
    else:
        t = _fit_clip(c, title, ["6x8", "5x7", "4x5"], maxw)
        c.text(t[1], c.width // 2, 5, font = t[0], color = "#E8B04A",
               align = "center")
        d = _fit_clip(c, sub, ["4x5"], maxw)
        c.text(d[1], c.width // 2, 18, font = d[0], color = "#6A7090",
               align = "center")


def clip(c, text, font, maxw):
    """Longest prefix of `text` that fits maxw in `font`.

    text_fit shrinks the font instead, and when even its smallest option
    overflows it still draws — which is how a station name ended up running
    straight through the readout beside it."""
    t = str(text)
    if c.text_width(t, font) <= maxw:
        return t
    for k in range(len(t), 0, -1):
        if c.text_width(t[:k], font) <= maxw:
            return t[:k]
    return ""


DIGITS = "0123456789"


def firstnum(line):
    """First number in a line, or None. Handles 15.5, -3, 30.07."""
    n = ""
    started = False
    for i in range(len(line)):
        ch = line[i]
        if DIGITS.find(ch) >= 0 or (ch == "." and started) or \
           (ch == "-" and not started and i + 1 < len(line) and DIGITS.find(line[i + 1]) >= 0):
            n += ch
            started = True
        elif started:
            break
    if n == "" or n == "-":
        return None
    return float(n)


def findline(lines, prefix):
    for ln in lines:
        if ln.startswith(prefix):
            return ln
    return None


def buoy(c, ctx):
    station = str(ctx.inputs.get("station", "")).strip()
    if station == "":
        nodata(c, "NO STATION", "SET A BUOY ID")
        return

    r = http.get("https://www.ndbc.noaa.gov/data/latest_obs/" + station + ".txt",
                 ttl_seconds = 1800)
    if r["status_code"] != 200 or r["body"] == "":
        nodata(c, "NO BUOY DATA", "CHECK STATION ID")
        return

    lines = r["body"].split("\n")
    wind = findline(lines, "Wind:")
    gust = findline(lines, "Gust:")
    wtmp = findline(lines, "Water Temp:")
    atmp = findline(lines, "Air Temp:")
    wave = findline(lines, "Significant Wave Height:")

    kt = firstnum(wind[wind.find(",") + 1:]) if wind != None and wind.find(",") >= 0 else None
    gkt = firstnum(gust) if gust != None else None
    wt = firstnum(wtmp) if wtmp != None else None
    at = firstnum(atmp) if atmp != None else None
    wv = firstnum(wave) if wave != None else None

    c.gradient_rect(0, 0, c.width - 1, c.height - 1, "#04101E", "#0C2C48",
                    horizontal = False)
    sz = 24 if c.width >= 128 else 16
    c.image("BUOY.png", 1, c.height - sz, w = sz, h = sz)

    if c.width >= 128:
        c.text("BUOY " + station, 30, 2, font = "5x7", color = "#5E88AC")
        big = (str(int(wv * 10) / 10.0) + "FT") if wv != None else \
              ((str(int(kt)) + "KT") if kt != None else "--")
        c.text_fit(big, 30, 10, ["16x20", "10x16"], color = "#DCF0FF",
                   maxw = c.width - 120)
        if wt != None:
            c.text("WATER " + str(int(wt)) + "F", c.width - 6, 4, font = "6x8",
                   color = "#8FD4FF", align = "right")
        if at != None:
            c.text("AIR " + str(int(at)) + "F", c.width - 6, 14, font = "6x8",
                   color = "#B4D8F0", align = "right")
        if kt != None:
            g = ("  G" + str(int(gkt))) if gkt != None else ""
            c.text("WIND " + str(int(kt)) + "KT" + g, c.width - 6, 24,
                   font = "5x7", color = "#6E9CBC", align = "right")
    else:
        big = (str(int(wv * 10) / 10.0) + "FT") if wv != None else \
              ((str(int(kt)) + "KT") if kt != None else "--")
        c.text_fit(big, c.width - 2, 3, ["16x20", "10x16"], color = "#DCF0FF",
                   align = "right", maxw = c.width - 20)
        if wt != None:
            c.text(str(int(wt)) + "F WATER", c.width - 2, 25, font = "4x5",
                   color = "#8FD4FF", align = "right")
