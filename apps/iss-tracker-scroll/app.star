# ISS Tracker
#
# Live position from wheretheiss.at. The distance uses the haversine
# formula against your zip, and the ground speed and altitude come
# straight off the feed — the station covers about 7.6 km every
# second, which is the part that makes people look twice.



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


def haversine(lat1, lon1, lat2, lon2):
    """Great-circle distance in kilometres."""
    r = 6371.0
    p1 = math.radians(lat1)
    p2 = math.radians(lat2)
    dp = math.radians(lat2 - lat1)
    dl = math.radians(lon2 - lon1)
    a = math.sin(dp / 2) * math.sin(dp / 2) + \
        math.cos(p1) * math.cos(p2) * math.sin(dl / 2) * math.sin(dl / 2)
    if a < 0:
        a = 0.0
    if a > 1:
        a = 1.0
    return 2 * r * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def hemi(v, pos, neg):
    return (pos if v >= 0 else neg) + str(int(abs(v) * 10) / 10.0)


def position(c, ctx):
    r = http.get("https://api.wheretheiss.at/v1/satellites/25544",
                 ttl_seconds = 120)
    if r["status_code"] != 200 or not r["json"]:
        nodata(c, "NO ISS DATA", "FEED UNREACHABLE")
        return
    j = r["json"]
    lat = float(j.get("latitude", 0))
    lon = float(j.get("longitude", 0))
    alt = float(j.get("altitude", 0))
    vel = float(j.get("velocity", 0))
    lit = str(j.get("visibility", "")).upper()

    c.fill("#04060C")
    if c.width >= 128:
        c.text("ISS", 6, 2, font = "5x7", color = "#5A80B8")
        # Reserve the telemetry column, then fit the coordinates to the rest.
        c.text_fit(hemi(lat, "N", "S") + " " + hemi(lon, "E", "W"), 6, 10,
                   ["10x16", "6x8", "5x7"], color = "#8FD4FF",
                   maxw = c.width - 104)
        c.text(str(int(alt)) + " KM UP", c.width - 6, 2, font = "4x5",
               color = "#5A80B8", align = "right")
        c.text(fmt.commas(int(vel)) + " KM/H", c.width - 6, 10, font = "6x8",
               color = "#D8E8FF", align = "right")
        g = geo(ctx)
        if g != None:
            d = haversine(g[0], g[1], lat, lon)
            c.text(fmt.commas(int(d)) + " KM AWAY", c.width - 6, 22,
                   font = "6x8", color = "#7FA8D8", align = "right")
        else:
            c.text(lit, c.width - 6, 22, font = "6x8", color = "#7FA8D8",
                   align = "right")
    else:
        c.text("ISS", c.width // 2, 0, font = "4x5", color = "#5A80B8",
               align = "center")
        c.text(hemi(lat, "N", "S"), c.width // 2, 6, font = "10x16",
               color = "#8FD4FF", align = "center")
        c.text(hemi(lon, "E", "W"), c.width // 2, 22, font = "6x8",
               color = "#D8E8FF", align = "center")
