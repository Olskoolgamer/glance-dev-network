# Pi-hole
#
# The Pi-hole v5 summary endpoint, which answers a plain GET with the
# API token as a query parameter. The block percentage is the number
# worth watching; the raw counts are there to give it scale.



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


PIHOLE_SAMPLE = {"status_code": 200, "json": {
    "dns_queries_today": "48213", "ads_blocked_today": "10774",
    "ads_percentage_today": "22.3"}}

SHIELD = [
    ".#####.",
    "#######",
    "#######",
    "#######",
    ".#####.",
    ".#####.",
    "..###..",
    "...#...",
]


def summary(c, ctx):
    base = str(ctx.inputs.get("baseurl", "")).strip()
    token = str(ctx.inputs.get("apikey", "")).strip()
    if base == "":
        nodata(c, "NO PI-HOLE URL", "SET URL")
        return
    if base.endswith("/"):
        base = base[:len(base) - 1]

    r = PIHOLE_SAMPLE if is_demo(ctx) else http.get(
        base + "/admin/api.php",
        params = {"summary": "", "auth": token},
        ttl_seconds = 120)
    if r["status_code"] != 200 or not r["json"]:
        nodata(c, "NO PI-HOLE", "CHECK URL")
        return

    j = r["json"]
    if j.get("dns_queries_today", None) == None:
        nodata(c, "BAD TOKEN", "BAD TOKEN")
        return

    queries = str(j.get("dns_queries_today", "0")).replace(",", "")
    blocked = str(j.get("ads_blocked_today", "0")).replace(",", "")
    pct = float(str(j.get("ads_percentage_today", "0")) or 0)

    c.fill("#07100C")
    c.sprite(SHIELD, 3, 3, color = "#2E7D4F")
    if c.width >= 128:
        c.text("BLOCKED TODAY", 14, 3, font = "5x7", color = "#4E8E68")
        # Counts own the right column; the percentage takes what is left.
        c.text_fit(str(int(pct * 10) / 10.0) + "%", 14, 11,
                   ["16x20", "10x16", "6x8"], color = "#4EE38A",
                   maxw = c.width - 110)
        c.text(fmt.commas(int(blocked)), c.width - 6, 6, font = "6x8",
               color = "#C8E8D4", align = "right")
        c.text("OF " + fmt.commas(int(queries)), c.width - 6, 18, font = "6x8",
               color = "#5E8E74", align = "right")
    else:
        c.text_fit(str(int(pct)) + "%", c.width // 2, 4, ["16x20", "10x16"],
                   color = "#4EE38A", align = "center", maxw = c.width - 4)
    if is_demo(ctx):
        demo_badge(c)
        c.text(fmt.commas(int(blocked)), c.width // 2, 25, font = "4x5",
               color = "#C8E8D4", align = "center")
