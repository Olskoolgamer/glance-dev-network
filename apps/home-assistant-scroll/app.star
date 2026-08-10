# Home Assistant
#
# One entity, read straight from your own Home Assistant. Needs a
# long-lived access token (Profile -> Security) and a base URL the
# panel can reach.
#
# The state is shown as large as it will go and the unit is taken
# from the entity's own attributes, so this works for a temperature,
# a power reading, a battery percentage or a plain ON/OFF.



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
    c.rect(c.width - 5, 0, c.width - 1, 4, fill = "#3A3F52")
    c.text("S", c.width - 2, 0, font = "3x4", color = "#D8DEF0",
           align = "right")


HA_SAMPLE = {"status_code": 200, "json": {
    "state": "18.4",
    "attributes": {"unit_of_measurement": "°C",
                   "friendly_name": "Outside Temperature"}}}

ON_COLORS = {"ON": "#4EE38A", "OPEN": "#FFB03A", "HOME": "#4EE38A",
             "OFF": "#5A6078", "CLOSED": "#5A6078", "AWAY": "#FF7A5B",
             "UNAVAILABLE": "#7A3E3E", "UNKNOWN": "#7A3E3E"}

HOUSE = [
    "....#....",
    "...###...",
    "..#####..",
    ".#######.",
    "#########",
    ".#.....#.",
    ".#.###.#.",
    ".#.###.#.",
]


def entity(c, ctx):
    base = str(ctx.inputs.get("baseurl", "")).strip()
    token = str(ctx.inputs.get("apikey", "")).strip()
    eid = str(ctx.inputs.get("entity", "")).strip()

    if base == "" or token == "" or eid == "":
        nodata(c, "NOT CONFIGURED", "SET URL+TOKEN")
        return
    if base.endswith("/"):
        base = base[:len(base) - 1]

    r = HA_SAMPLE if is_demo(ctx) else http.get(
        base + "/api/states/" + eid,
        headers = {"Authorization": "Bearer " + token,
                   "Content-Type": "application/json"},
        ttl_seconds = 60)
    if r["status_code"] == 401:
        nodata(c, "BAD TOKEN", "BAD TOKEN")
        return
    if r["status_code"] == 404:
        nodata(c, "NO SUCH ENTITY", clip(c, eid.upper(), "4x5", c.width - 6))
        return
    if r["status_code"] != 200 or not r["json"]:
        nodata(c, "NO CONNECTION", "CHECK BASE URL")
        return

    j = r["json"]
    state = str(j.get("state", "")).upper()
    attrs = j.get("attributes", {})
    unit = str(attrs.get("unit_of_measurement", "") or "")
    label = str(ctx.inputs.get("label", "")).strip()
    if label == "":
        label = str(attrs.get("friendly_name", eid))
    label = label.upper()

    col = ON_COLORS.get(state, "#8FD4FF")

    c.fill("#070A10")
    c.sprite(HOUSE, 3, 3, color = "#2A3A54")
    c.text_fit(label, 15, 3, ["5x7", "4x5", "3x4"], color = "#7C88A8",
               maxw = c.width - 20)
    c.text_fit(state + unit.upper(), c.width // 2, 12,
               ["16x20", "10x16", "6x8", "5x7"], color = col,
               align = "center", maxw = c.width - 6)
    if is_demo(ctx):
        demo_badge(c)
