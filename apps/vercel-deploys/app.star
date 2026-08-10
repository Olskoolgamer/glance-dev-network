# Vercel Deploys
#
# The Vercel REST API with a personal access token. A wall panel that
# turns red the moment production breaks is worth more than a
# dashboard nobody has open.



MDAYS = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
DOW = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
MON = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN",
       "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]


def is_leap(y):
    return (y % 4 == 0 and y % 100 != 0) or (y % 400 == 0)


def days_from_civil(y, m, d):
    """Days since the Unix epoch (Howard Hinnant's algorithm)."""
    yy = y - 1 if m <= 2 else y
    era = (yy if yy >= 0 else yy - 399) // 400
    yoe = yy - era * 400
    mp = m - 3 if m > 2 else m + 9
    doy = (153 * mp + 2) // 5 + d - 1
    doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
    return era * 146097 + doe - 719468


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


VERCEL_SAMPLE = {"status_code": 200, "json": {"deployments": [
    {"state": "READY", "name": "storefront", "created": 0}]}}

STATE = {
    "READY": ["#4EE38A", "LIVE"], "BUILDING": ["#FFB03A", "BUILDING"],
    "ERROR": ["#FF4B4B", "FAILED"], "CANCELED": ["#7A8098", "CANCELLED"],
    "QUEUED": ["#7FD4FF", "QUEUED"], "INITIALIZING": ["#7FD4FF", "STARTING"],
}


def latest(c, ctx):
    token = str(ctx.inputs.get("apikey", "")).strip()
    if token == "":
        nodata(c, "NO TOKEN", "ADD TOKEN")
        return

    params = {"limit": "1"}
    proj = str(ctx.inputs.get("project", "")).strip()
    if proj != "":
        params["app"] = proj

    r = VERCEL_SAMPLE if is_demo(ctx) else http.get(
        "https://api.vercel.com/v6/deployments", params = params,
        headers = {"Authorization": "Bearer " + token}, ttl_seconds = 120)
    if r["status_code"] == 403 or r["status_code"] == 401:
        nodata(c, "BAD TOKEN", "BAD TOKEN")
        return
    if r["status_code"] != 200 or not r["json"]:
        nodata(c, "NO DEPLOYS", "NO CONNECTION")
        return

    ds = r["json"].get("deployments", [])
    if len(ds) == 0:
        nodata(c, "NO DEPLOYS", "NONE FOUND")
        return

    d = ds[0]
    st = str(d.get("state", d.get("readyState", ""))).upper()
    info = STATE.get(st, ["#7A8098", st if st != "" else "UNKNOWN"])
    name = str(d.get("name", "")).upper()

    mins = (ctx.now.unix - int(d.get("created", 0) or 0) // 1000) // 60
    if mins < 60:
        when = str(mins) + "M AGO"
    elif mins < 1440:
        when = str(mins // 60) + "H AGO"
    else:
        when = str(mins // 1440) + "D AGO"

    c.fill("#08090E")
    c.rect(0, 0, c.width - 1, 5, fill = info[0])
    if c.width >= 128:
        c.text(clip(c, name, "4x5", c.width - 60), 3, 0, font = "4x5",
               color = "#0A0A10")
        c.text(when, c.width - 3, 0, font = "4x5", color = "#0A0A10",
               align = "right")
        c.text_fit(info[1], c.width // 2, 10, ["16x20", "10x16"],
                   color = info[0], align = "center", maxw = c.width - 8)
    else:
        c.text(when, c.width - 3, 0, font = "4x5", color = "#0A0A10",
               align = "right")
        c.text_fit(info[1], c.width // 2, 9, ["10x16", "6x8", "5x7"],
                   color = info[0], align = "center", maxw = c.width - 4)
        c.text(clip(c, name, "4x5", c.width - 4), c.width // 2, 26,
               font = "4x5", color = "#7A8098", align = "center")
    if is_demo(ctx):
        demo_badge(c)
