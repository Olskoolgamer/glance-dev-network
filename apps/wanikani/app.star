# WaniKani
#
# The WaniKani v2 summary endpoint. The number that matters is how
# many reviews are waiting right now — the whole method depends on
# clearing them when they appear, so the panel leads with it.



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


WK_SAMPLE = {"status_code": 200, "json": {"data": {
    "reviews": [{"subject_ids": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12,
                                 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23]},
                {"subject_ids": [1, 2, 3, 4, 5, 6, 7]}],
    "lessons": [{"subject_ids": [1, 2, 3, 4, 5]}]}}}

TORII = [
    "#########",
    ".#######.",
    "..#...#..",
    "#########",
    "..#...#..",
    "..#...#..",
    "..#...#..",
]


def queue(c, ctx):
    token = str(ctx.inputs.get("apikey", "")).strip()
    if token == "":
        nodata(c, "NO TOKEN", "ADD TOKEN")
        return

    r = WK_SAMPLE if is_demo(ctx) else http.get(
        "https://api.wanikani.com/v2/summary",
        headers = {"Authorization": "Bearer " + token,
                   "Wanikani-Revision": "20170710"}, ttl_seconds = 300)
    if r["status_code"] == 401:
        nodata(c, "BAD TOKEN", "BAD TOKEN")
        return
    if r["status_code"] != 200 or not r["json"]:
        nodata(c, "NO WANIKANI", "NO CONNECTION")
        return

    data = r["json"].get("data", {})
    reviews = data.get("reviews", [])
    lessons = data.get("lessons", [])

    now_reviews = 0
    if len(reviews) > 0:
        now_reviews = len(reviews[0].get("subject_ids", []))
    now_lessons = 0
    if len(lessons) > 0:
        now_lessons = len(lessons[0].get("subject_ids", []))

    upcoming = 0
    for i in range(1, len(reviews)):
        n = len(reviews[i].get("subject_ids", []))
        if n > 0:
            upcoming = n
            break

    col = "#F5A0D8" if now_reviews > 0 else "#5A6078"

    c.fill("#0E0710")
    c.sprite(TORII, 3, c.height - 9, color = "#54324E")
    if c.width >= 128:
        c.text("REVIEWS WAITING", 6, 2, font = "5x7", color = "#8A5E80")
        c.text(str(now_reviews), 6, 10, font = "16x20", color = col)
        c.text(str(now_lessons) + " LESSONS", c.width - 6, 6, font = "6x8",
               color = "#D8B4CC", align = "right")
        c.text("NEXT " + str(upcoming), c.width - 6, 18, font = "6x8",
               color = "#8A5E80", align = "right")
    else:
        c.text_fit(str(now_reviews), c.width // 2, 5, ["16x20", "10x16"],
                   color = col, align = "center", maxw = c.width - 4)
        c.text(str(now_lessons) + " LSN", c.width // 2, 26, font = "4x5",
               color = "#D8B4CC", align = "center")
    if is_demo(ctx):
        demo_badge(c)
