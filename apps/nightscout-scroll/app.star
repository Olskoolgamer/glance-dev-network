# Nightscout Glucose
#
# Nightscout is the self-hosted CGM dashboard the diabetes community
# built. This reads the two most recent entries so it can show both
# the value and which way it is going.
#
# Colour follows the standard ranges, and the reading is deliberately
# the largest thing on the panel. This is a convenience display, not
# a medical device — treatment decisions belong with your meter.



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


NS_SAMPLE = {"status_code": 200, "json": [
    {"sgv": 112, "direction": "FortyFiveUp"}, {"sgv": 105}]}

ARROWS = {"DOUBLEUP": "^^", "SINGLEUP": "^", "FORTYFIVEUP": "/",
          "FLAT": "-", "FORTYFIVEDOWN": "\\\\", "SINGLEDOWN": "V",
          "DOUBLEDOWN": "VV"}


def glucose(c, ctx):
    base = str(ctx.inputs.get("baseurl", "")).strip()
    if base == "":
        nodata(c, "NO SITE URL", "SET URL")
        return
    if base.endswith("/"):
        base = base[:len(base) - 1]

    params = {"count": "2"}
    token = str(ctx.inputs.get("apikey", "")).strip()
    if token != "":
        params["token"] = token

    r = NS_SAMPLE if is_demo(ctx) else http.get(
        base + "/api/v1/entries.json", params = params, ttl_seconds = 120)
    if r["status_code"] != 200 or not r["json"]:
        nodata(c, "NO READINGS", "CHECK URL")
        return

    rows = r["json"]
    if len(rows) == 0:
        nodata(c, "NO READINGS", "NO ENTRIES")
        return

    mgdl = int(rows[0].get("sgv", 0) or 0)
    direction = str(rows[0].get("direction", "FLAT")).upper()
    arrow = ARROWS.get(direction, "-")

    mmol = str(ctx.inputs.get("units", "MGDL")).upper() == "MMOL"
    if mmol:
        shown = str(int(mgdl / 18.0 * 10) / 10.0)
        low, high = 3.9, 10.0
        value = mgdl / 18.0
    else:
        shown = str(mgdl)
        low, high = 70.0, 180.0
        value = mgdl * 1.0

    if value < low:
        col = "#FF4B4B"
    elif value > high:
        col = "#FFB03A"
    else:
        col = "#4EE38A"

    delta = ""
    if len(rows) > 1:
        d = mgdl - int(rows[1].get("sgv", 0) or 0)
        if mmol:
            delta = ("+" if d >= 0 else "-") + str(int(abs(d) / 18.0 * 10) / 10.0)
        else:
            delta = ("+" if d >= 0 else "-") + str(abs(d))

    c.fill("#08090F")
    if c.width >= 128:
        c.text("GLUCOSE", 6, 2, font = "5x7", color = "#5A6480")
        c.text(shown, 6, 10, font = "16x20", color = col)
        c.text(arrow, c.width - 6, 4, font = "16x20", color = col,
               align = "right")
        if delta != "":
            c.text(delta, c.width - 6, 24, font = "6x8", color = "#9AA4C0",
                   align = "right")
    else:
        c.text_fit(shown, c.width // 2 - 6, 5, ["16x20", "10x16"], color = col,
                   align = "center", maxw = c.width - 18)
        c.text(arrow, c.width - 3, 8, font = "6x8", color = col, align = "right")
        if delta != "":
            c.text(delta, c.width // 2, 26, font = "4x5", color = "#9AA4C0",
                   align = "center")
    if is_demo(ctx):
        demo_badge(c)
