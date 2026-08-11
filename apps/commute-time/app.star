# Commute
#
# TomTom routing, free tier, static key in a query parameter.
#
# The derived number is the useful one: LEAVE BY is your target
# arrival minus the live drive time, which is what people actually
# want and never get from a map.
#
# The road across the strip is coloured by the traffic delay, so a
# jammed morning literally paints the panel red.



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
    c.rect(c.width - 5, c.height - 5, c.width - 1, c.height - 1,
           fill = "#3A3F52")
    c.text("S", c.width - 2, c.height - 5, font = "3x4", color = "#D8DEF0",
           align = "right")


def drive(c, ctx):
    key = str(ctx.inputs.get("apikey", "")).strip()
    a = str(ctx.inputs.get("origin", "")).strip()
    b = str(ctx.inputs.get("dest", "")).strip()
    demo = is_demo(ctx)

    if demo:
        mins = 24
        delay = 9
    else:
        if key == "" or a == "" or b == "":
            nodata(c, "NOT CONFIGURED", "SET KEY+POINTS")
            return
        r = http.get("https://api.tomtom.com/routing/1/calculateRoute/"
                     + a + ":" + b + "/json",
                     params = {"key": key, "traffic": "true",
                               "routeType": "fastest", "travelMode": "car"},
                     ttl_seconds = 300)
        if r["status_code"] == 403 or r["status_code"] == 401:
            nodata(c, "BAD KEY", "CHECK KEY")
            return
        if r["status_code"] != 200 or not r["json"]:
            nodata(c, "NO ROUTE", "CHECK POINTS")
            return
        routes = r["json"].get("routes", [])
        if len(routes) == 0:
            nodata(c, "NO ROUTE", "NO PATH FOUND")
            return
        sm = routes[0].get("summary", {})
        secs = int(sm.get("travelTimeInSeconds", 0) or 0)
        delay = int(sm.get("trafficDelayInSeconds", 0) or 0) // 60
        mins = secs // 60

    if delay >= 15:
        col = "#FF5B5B"
    elif delay >= 5:
        col = "#FFB03A"
    else:
        col = "#4EE38A"

    c.fill("#0A0C12")
    # The road: a dark ribbon whose colour carries the delay.
    ry = c.height - 9
    c.rect(0, ry, c.width - 1, ry + 6, fill = "#2A2E3A")
    share = 0 if mins <= 0 else int((c.width - 2) * min([delay * 4, 100]) / 100.0)
    if share > 0:
        c.rect(c.width - 1 - share, ry, c.width - 1, ry + 6, fill = col)
    for x in range(2, c.width - 2, 6):
        c.rect(x, ry + 3, x + 2, ry + 3, fill = "#6A7080")

    cs = 22 if c.width >= 128 else 15
    # The sprite has three blank rows under its wheels, so it sits ry+3 - cs
    # to put the tyres on the tarmac at both sizes.
    c.image("CAR.png", 2, ry + 3 - cs + (0 if c.width >= 128 else 2),
            w = cs, h = cs)

    if c.width >= 128:
        # One measured string instead of two placed strings: "MIN" was
        # positioned off the figure's width and ran into LEAVE BY.
        c.text_fit(str(mins) + " MIN", 30, 4, ["16x20", "10x16", "6x8"],
                   color = "#FFFFFF", maxw = c.width - 128)
        if delay > 0:
            c.text("+" + str(delay) + " TRAFFIC", c.width - 6, 3, font = "6x8",
                   color = col, align = "right")
        else:
            c.text("CLEAR", c.width - 6, 3, font = "6x8", color = col,
                   align = "right")
        arrive = str(ctx.inputs.get("arrive", "")).strip()
        if len(arrive) == 5 and arrive.find(":") == 2:
            hh = int(arrive[:2])
            mm = int(arrive[3:])
            total = hh * 60 + mm - mins
            if total < 0:
                total += 1440
            c.text("LEAVE BY " + fmt.pad(total // 60) + ":" + fmt.pad(total % 60),
                   c.width - 6, 13, font = "6x8", color = "#FFD86A",
                   align = "right")
    else:
        c.text_fit(str(mins) + "M", c.width - 2, 2, ["16x20", "10x16"],
                   color = "#FFFFFF", align = "right", maxw = c.width - 20)
        c.text(("+" + str(delay)) if delay > 0 else "CLEAR", c.width - 2, 19,
               font = "4x5", color = col, align = "right")
    if demo:
        demo_badge(c)
