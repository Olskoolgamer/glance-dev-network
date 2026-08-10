# River Level
#
# USGS Instantaneous Values. Parameter 00065 is gauge height in feet;
# station numbers are on every USGS site page. Useful if you live
# near water and would rather know before the road closes.



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


def level(c, ctx):
    site = str(ctx.inputs.get("site", "")).strip()
    if site == "":
        nodata(c, "NO STATION", "SET A USGS SITE")
        return

    r = http.get("https://waterservices.usgs.gov/nwis/iv/",
                 params = {"format": "json", "sites": site,
                           "parameterCd": "00065", "siteStatus": "all"},
                 ttl_seconds = 900)
    if r["status_code"] != 200 or not r["json"]:
        nodata(c, "NO GAUGE DATA", "USGS UNREACHABLE")
        return

    series = r["json"].get("value", {}).get("timeSeries", [])
    if len(series) == 0:
        nodata(c, "NO READING", "CHECK SITE NUMBER")
        return

    s = series[0]
    vals = s.get("values", [{}])[0].get("value", [])
    if len(vals) == 0:
        nodata(c, "NO READING", "STATION IDLE")
        return

    ft = float(vals[len(vals) - 1].get("value", 0) or 0)
    name = str(s.get("sourceInfo", {}).get("siteName", "")).upper()
    flood = float(ctx.inputs.get("flood", 10) or 10)

    pct = ft * 100.0 / flood if flood > 0 else 0.0
    col = "#4EE38A"
    if pct >= 100:
        col = "#FF3B3B"
    elif pct >= 80:
        col = "#FF7A18"
    elif pct >= 60:
        col = "#F5C242"

    c.fill("#04080C")
    if c.width >= 128:
        # Right column first (flood stage + bar), then the station name and
        # the reading fitted into the space that remains.
        c.text("FLOOD " + str(int(flood)) + " FT", c.width - 6, 3, font = "5x7",
               color = "#4E6A80", align = "right")
        c.progress_bar(c.width - 76, 13, 70, 7, pct if pct < 100 else 100,
                       color = col, bg = "#152230", border = "#26384A")
        c.text(clip(c, name, "5x7", c.width - 92), 6, 2, font = "5x7",
               color = "#4E6A80")
        c.text_fit(str(int(ft * 100) / 100.0) + " FT", 6, 11,
                   ["16x20", "10x16", "6x8"], color = col, maxw = c.width - 88)
    else:
        c.text_fit(str(int(ft * 10) / 10.0) + "FT", c.width // 2, 4,
                   ["16x20", "10x16", "6x8"], color = col, align = "center",
                   maxw = c.width - 4)
        c.progress_bar(3, 25, c.width - 6, 4, pct if pct < 100 else 100,
                       color = col, bg = "#152230")
