# SolarEdge
#
# The SolarEdge monitoring API: one GET to the site overview, with
# the key as a query parameter. Current power is the number people
# actually watch; today's energy is the one that pays the bill.



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


DEMO = "DEMO"


def is_demo(ctx):
    """True when the key is the literal DEMO opt-in.

    Catalog previews are rendered with this so they show the real layout
    carrying representative values. A panel with no key configured still gets
    the plain error screen — this never fires by accident."""
    return str(ctx.inputs.get("apikey", "")).strip().upper() == DEMO


def demo_badge(c):
    """A single corner marker. A SAMPLE word across the top-right covered real
    content in half these apps, which defeats the point of the preview."""
    c.rect(c.width - 5, 0, c.width - 1, 4, fill = "#3A3F52")
    c.text("S", c.width - 2, 0, font = "3x4", color = "#D8DEF0",
           align = "right")


SOLAR_SAMPLE = {"status_code": 200, "json": {"overview": {
    "currentPower": {"power": 4180.0}, "lastDayData": {"energy": 21400.0}}}}

PANEL = [
    "#########",
    "#..#..#..",
    "#########",
    "..#..#..#",
    "#########",
]


def output(c, ctx):
    site = str(ctx.inputs.get("siteid", "")).strip()
    key = str(ctx.inputs.get("apikey", "")).strip()
    if site == "" or key == "":
        nodata(c, "NOT CONFIGURED", "SET ID+KEY")
        return

    r = SOLAR_SAMPLE if is_demo(ctx) else http.get(
        "https://monitoringapi.solaredge.com/site/" + site + "/overview",
        params = {"api_key": key}, ttl_seconds = 900)
    if r["status_code"] == 403:
        nodata(c, "ACCESS DENIED", "CHECK KEY")
        return
    if r["status_code"] != 200 or not r["json"]:
        nodata(c, "NO SOLAR DATA", "NO CONNECTION")
        return

    ov = r["json"].get("overview", {})
    watts = float(ov.get("currentPower", {}).get("power", 0) or 0)
    today = float(ov.get("lastDayData", {}).get("energy", 0) or 0) / 1000.0

    if watts >= 1000:
        nowstr = str(int(watts / 100) / 10.0) + "KW"
    else:
        nowstr = str(int(watts)) + "W"

    col = "#FFC53F" if watts > 50 else "#5A6078"

    c.fill("#100C04")
    c.sprite(PANEL, 3, c.height - 9, color = "#3E4A6A")
    if c.width >= 128:
        c.text("GENERATING NOW", 6, 2, font = "5x7", color = "#8A7040")
        c.text_fit(nowstr, 6, 10, ["16x20", "10x16", "6x8"], color = col,
                   maxw = c.width - 108)
        c.text("TODAY", c.width - 6, 4, font = "4x5", color = "#8A7040",
               align = "right")
        c.text(str(int(today * 10) / 10.0) + " KWH", c.width - 6, 12,
               font = "10x16", color = "#FFE9A8", align = "right")
    else:
        c.text_fit(nowstr, c.width // 2, 4, ["16x20", "10x16", "6x8"],
                   color = col, align = "center", maxw = c.width - 4)
        c.text(str(int(today * 10) / 10.0) + "KWH", c.width // 2, 25,
               font = "4x5", color = "#FFE9A8", align = "center")
    if is_demo(ctx):
        demo_badge(c)
