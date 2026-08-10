# Octopus Agile
#
# Octopus Energy publishes Agile unit rates openly — no key at all,
# which is unusual and worth taking advantage of. Rates are per
# half hour, so the panel shows the slot you are in, the one coming,
# and the cheapest slot still ahead of you.
#
# Negative pricing happens on Agile and is the whole point of the
# tariff, so it gets its own colour rather than being clamped away.



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


def price(c, ctx):
    product = str(ctx.inputs.get("product", "AGILE-24-10-01")).strip()
    region = str(ctx.inputs.get("region", "C")).strip().upper()
    if product == "" or region == "":
        nodata(c, "NOT CONFIGURED", "SET PRODUCT")
        return

    code = "E-1R-" + product + "-" + region
    url = "https://api.octopus.energy/v1/products/" + product + \
        "/electricity-tariffs/" + code + "/standard-unit-rates/"
    r = http.get(url, ttl_seconds = 900)
    if r["status_code"] != 200 or not r["json"]:
        nodata(c, "NO PRICES", "NO CONNECTION")
        return

    rows = r["json"].get("results", [])
    if len(rows) == 0:
        nodata(c, "NO PRICES", "BAD PRODUCT")
        return

    # The feed is newest first; the current slot is the last one that has
    # already started.
    cur = None
    nxt = None
    for i in range(len(rows)):
        start = str(rows[i].get("valid_from", ""))
        if start <= _iso(ctx):
            cur = rows[i]
            nxt = rows[i - 1] if i > 0 else None
            break

    if cur == None:
        cur = rows[len(rows) - 1]

    p = float(cur.get("value_inc_vat", 0) or 0)
    col = "#4EE38A"
    if p < 0:
        col = "#7FD4FF"
    elif p > 30:
        col = "#FF5B5B"
    elif p > 18:
        col = "#FFB03A"

    cheapest = cur
    for row in rows:
        if str(row.get("valid_from", "")) >= _iso(ctx):
            if float(row.get("value_inc_vat", 0) or 0) < float(cheapest.get("value_inc_vat", 0) or 0):
                cheapest = row

    c.fill("#0B0714")
    if c.width >= 128:
        c.text("AGILE NOW", 6, 2, font = "5x7", color = "#7A6AA8")
        # The cheapest-slot line owns the lower right, so the headline price is
        # fitted to the width left over rather than centred into it.
        c.text_fit(str(int(p * 10) / 10.0) + "P", 6, 10, ["16x20", "10x16"],
                   color = col, maxw = c.width - 130)
        if nxt != None:
            c.text("NEXT " + str(int(float(nxt.get("value_inc_vat", 0) or 0) * 10) / 10.0) + "P",
                   c.width - 6, 6, font = "6x8", color = "#C8BCE8",
                   align = "right")
        c.text("LOW " + str(int(float(cheapest.get("value_inc_vat", 0) or 0) * 10) / 10.0)
               + "P AT " + _hhmm(str(cheapest.get("valid_from", ""))),
               c.width - 6, 20, font = "6x8", color = "#8FE38A", align = "right")
    else:
        c.text_fit(str(int(p * 10) / 10.0) + "P", c.width // 2, 5,
                   ["16x20", "10x16"], color = col, align = "center",
                   maxw = c.width - 4)
        c.text("LOW " + _hhmm(str(cheapest.get("valid_from", ""))), c.width // 2,
               26, font = "4x5", color = "#8FE38A", align = "center")


def _iso(ctx):
    return str(ctx.now.year) + "-" + fmt.pad(ctx.now.month) + "-" \
        + fmt.pad(ctx.now.day) + "T" + fmt.pad(ctx.now.hour) + ":" \
        + fmt.pad(ctx.now.minute)


def _hhmm(iso):
    if len(iso) < 16:
        return "--:--"
    return iso[11:16]
