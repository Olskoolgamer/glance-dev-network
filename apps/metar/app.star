# METAR
#
# aviationweather.gov, no key. The flight category is the number
# that matters: VFR, MVFR, IFR or LIFR decides whether you are
# flying today, so it is the largest thing on the panel and carries
# the standard colour for its band.



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


CATS = {"VFR": "#4EE38A", "MVFR": "#4EA8FF", "IFR": "#FF5B5B",
        "LIFR": "#D46BE8"}


def report(c, ctx):
    station = str(ctx.inputs.get("station", "")).strip().upper()
    if station == "":
        nodata(c, "NO STATION", "SET AN ICAO CODE")
        return

    r = http.get("https://aviationweather.gov/api/data/metar",
                 params = {"ids": station, "format": "json"},
                 ttl_seconds = 600)
    if r["status_code"] != 200 or r["json"] == None:
        nodata(c, "NO METAR", "NO CONNECTION")
        return
    rows = r["json"]
    if len(rows) == 0:
        nodata(c, "NO REPORT", "CHECK THE CODE")
        return

    m = rows[0]
    cat = str(m.get("fltCat", "") or "").upper()
    col = CATS.get(cat, "#9AA4C0")
    if cat == "":
        cat = "NO CAT"

    temp = m.get("temp", None)
    wspd = m.get("wspd", None)
    wdir = m.get("wdir", None)
    visib = m.get("visib", None)

    c.gradient_rect(0, 0, c.width - 1, c.height - 1, "#050A14", "#132238",
                    horizontal = False)
    sz = 24 if c.width >= 128 else 16
    c.image("PLANE.png", 1, (c.height - sz) // 2, w = sz, h = sz)

    wind = "CALM"
    if wspd != None and float(wspd) > 0:
        wind = str(int(float(wspd))) + "KT"
        if wdir != None:
            wind = str(int(float(wdir))) + " AT " + wind

    if c.width >= 128:
        c.text(station, 30, 2, font = "6x8", color = "#8FB4D8")
        c.text_fit(cat, 30, 11, ["16x20", "10x16"], color = col,
                   maxw = c.width - 130)
        c.text(wind, c.width - 6, 4, font = "6x8", color = "#DCE8F8",
               align = "right")
        bits = ""
        if temp != None:
            bits = str(int(float(temp))) + "C"
        if visib != None:
            bits = bits + "   " + clip(c, str(visib) + "SM", "6x8", 50)
        c.text(bits, c.width - 6, 16, font = "6x8", color = "#8FB4D8",
               align = "right")
    else:
        c.text(station, c.width - 2, 1, font = "4x5", color = "#8FB4D8",
               align = "right")
        c.text_fit(cat, c.width - 2, 8, ["16x20", "10x16", "6x8"], color = col,
                   align = "right", maxw = c.width - 20)
        c.text(wind, c.width - 2, 26, font = "4x5", color = "#DCE8F8",
               align = "right")
