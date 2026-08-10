# Storm Potential
#
# There is no free feed of live lightning strikes, and Open-Meteo's
# lightning field only covers Europe. What is available everywhere
# is CAPE — convective available potential energy — which is the
# fuel thunderstorms run on and what forecasters actually watch.
#
# This is honestly labelled as potential, not as strikes. CAPE is
# paired with the weather code so a loaded atmosphere that is
# already storming reads differently from one that is merely primed.



def geo(ctx):
    """[lat, lon, place] for the configured zip, or None when unavailable."""
    zip = str(ctx.inputs.get("zip", "")).strip()
    if zip == "":
        return None
    g = http.get("https://api.zippopotam.us/us/" + zip, ttl_seconds = 86400)
    if g["status_code"] != 200 or not g["json"]:
        return None
    places = g["json"].get("places", [])
    if not places:
        return None
    p = places[0]
    return [float(p["latitude"]), float(p["longitude"]),
            str(p.get("place name", "")).upper()]


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


def cape_band(j):
    if j < 300:
        return ["STABLE", "#5A6078", "NOTHING BREWING"]
    if j < 1000:
        return ["MARGINAL", "#6FD4FF", "WEAK CELLS POSSIBLE"]
    if j < 2500:
        return ["UNSTABLE", "#F5D64E", "STORMS LIKELY"]
    if j < 4000:
        return ["VERY UNSTABLE", "#FF9A4A", "STRONG STORMS"]
    return ["EXPLOSIVE", "#FF3B3B", "SEVERE POSSIBLE"]


def storm(c, ctx):
    g = geo(ctx)
    if g == None:
        nodata(c, "NO LOCATION", "SET A ZIP")
        return
    r = http.get("https://api.open-meteo.com/v1/forecast",
                 params = {"latitude": str(g[0]), "longitude": str(g[1]),
                           "current": "cape,weather_code", "timezone": "auto"},
                 ttl_seconds = 900)
    if r["status_code"] != 200 or not r["json"]:
        nodata(c, "NO STORM DATA", "NO CONNECTION")
        return
    cur = r["json"].get("current", {})
    if cur.get("cape", None) == None:
        nodata(c, "NO CAPE DATA", "NOT MODELLED HERE")
        return

    cape = float(cur.get("cape", 0) or 0)
    code = int(cur.get("weather_code", 0) or 0)
    b = cape_band(cape)
    storming = code >= 95
    if storming:
        b = ["STORMING NOW", "#FF3B3B", "THUNDER OVERHEAD"]

    c.gradient_rect(0, 0, c.width - 1, c.height - 1, "#0A0C16", "#1E2236",
                    horizontal = False)
    sz = 24 if c.width >= 128 else 16
    c.image("BOLT.png", 1, (c.height - sz) // 2, w = sz, h = sz)

    if c.width >= 128:
        c.text("CAPE", 30, 2, font = "4x5", color = "#6E7690")
        c.text_fit(str(int(cape)), 30, 8, ["16x20", "10x16"], color = b[1],
                   maxw = c.width - 128)
        c.text_fit(b[0], c.width - 6, 3, ["10x16", "6x8"], color = b[1],
                   align = "right", maxw = c.width - 100)
        c.text(b[2], c.width - 6, 22, font = "5x7", color = "#96A0B8",
               align = "right")
    else:
        c.text_fit(str(int(cape)), c.width - 2, 3, ["16x20", "10x16"],
                   color = b[1], align = "right", maxw = c.width - 20)
        c.text_fit(b[0], c.width - 2, 25, ["4x5", "3x4"], color = b[1],
                   align = "right", maxw = c.width - 4)
