# Calendar
#
# Any .ics URL works: Google Calendar's private address, a school
# calendar, a shared family calendar, an Airbnb booking feed.
#
# iCal is parsed by hand because there is no parser here. Two
# details matter: lines are folded at 75 characters and continue
# with a leading space, and DTSTART comes either as a date-time or
# as a bare date for all-day events. Both are handled.



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


def fitwords(c, text, font, maxw):
    """Longest run of WHOLE words that fits maxw.

    clip() cuts at the pixel and leaves things like "SCHOOL PI" or
    "PAINTED B", which read as a rendering fault rather than an
    abbreviation. This stops at a word boundary instead, and only falls back
    to a hard cut when a single word cannot fit on its own."""
    t = str(text).strip()
    if c.text_width(t, font) <= maxw:
        return t
    parts = t.split(" ")
    out = ""
    for w in parts:
        trial = w if out == "" else out + " " + w
        if c.text_width(trial, font) > maxw:
            break
        out = trial
    if out != "":
        return out
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


DIGITS = "0123456789"
CAL_SAMPLE = {"status_code": 200, "body": ""}
SAMPLE_ROWS = [["DENTIST", "9:30A"], ["SCHOOL PICKUP", "3:15P"],
               ["DINNER WITH SAM", "7:00P"]]


def unfold(body):
    """iCal folds long lines with a leading space; rejoin them."""
    out = []
    for raw in body.split("\n"):
        ln = raw.replace("\r", "")
        if ln.startswith(" ") and len(out) > 0:
            out[len(out) - 1] = out[len(out) - 1] + ln[1:]
        else:
            out.append(ln)
    return out


def digits_only(s):
    n = ""
    for i in range(len(s)):
        if DIGITS.find(s[i]) >= 0:
            n += s[i]
    return n


def parse_events(lines):
    """[[sortkey, summary, hhmm or ''], ...] for every VEVENT with a start."""
    events = []
    start = ""
    summary = ""
    inside = False
    for ln in lines:
        if ln.startswith("BEGIN:VEVENT"):
            inside = True
            start = ""
            summary = ""
        elif ln.startswith("END:VEVENT"):
            if inside and start != "":
                events.append([start, summary, start])
            inside = False
        elif inside:
            if ln.startswith("DTSTART"):
                c = ln.find(":")
                if c >= 0:
                    start = digits_only(ln[c + 1:])
            elif ln.startswith("SUMMARY"):
                c = ln.find(":")
                if c >= 0:
                    summary = ln[c + 1:]
    return events


def hhmm(stamp, off):
    """'' for all-day events, else a shifted local clock time."""
    if len(stamp) < 12:
        return ""
    h = int(stamp[8:10])
    m = int(stamp[10:12])
    h = (h + int(off)) % 24
    ap = "A" if h < 12 else "P"
    h12 = h % 12
    if h12 == 0:
        h12 = 12
    return str(h12) + ":" + stamp[10:12] + ap


def agenda(c, ctx):
    url = str(ctx.inputs.get("url", "")).strip()
    off = float(ctx.inputs.get("utcoffset", 0) or 0)
    demo = is_demo(ctx) or url == "DEMO"

    rows = []
    if demo:
        rows = SAMPLE_ROWS
    else:
        if url == "":
            nodata(c, "NO CALENDAR", "SET AN ICAL URL")
            return
        r = http.get(url, ttl_seconds = 900)
        if r["status_code"] != 200 or r["body"] == "":
            nodata(c, "NO CALENDAR", "CHECK THE URL")
            return

        today = str(ctx.now.year) + fmt.pad(ctx.now.month) + fmt.pad(ctx.now.day)
        events = parse_events(unfold(r["body"]))
        upcoming = []
        for e in events:
            if e[0][:8] >= today:
                upcoming.append(e)
        if len(upcoming) == 0:
            c.fill("#080B12")
            c.text("NOTHING COMING UP", c.width // 2, c.height // 2 - 4,
                   font = "6x8" if c.width >= 128 else "4x5",
                   color = "#5E7AA8", align = "center")
            return
        upcoming = sorted(upcoming)
        n = 3 if c.width >= 128 else 2
        for i in range(n if n < len(upcoming) else len(upcoming)):
            e = upcoming[i]
            rows.append([str(e[1]).upper(), hhmm(e[2], off)])

    # Two events is the most a 64 panel can show legibly: each needs its
    # own line for the name and another for the time.
    if c.width < 128 and len(rows) > 2:
        rows = rows[:2]

    c.gradient_rect(0, 0, c.width - 1, c.height - 1, "#080B12", "#161E30",
                    horizontal = False)
    sz = 24 if c.width >= 128 else 16
    c.image("CALENDAR.png", 1, (c.height - sz) // 2, w = sz, h = sz)

    x0 = 28 if c.width >= 128 else 19
    lh = c.height // len(rows)
    for i in range(len(rows)):
        y = i * lh + (lh - 7) // 2
        t = rows[i][1]
        tw = c.text_width(t, "5x7") + 4 if t != "" else 0
        if c.width >= 128:
            if t != "":
                c.text(t, c.width - 4, y, font = "5x7", color = "#FFD86A",
                       align = "right")
            c.text(clip(c, rows[i][0], "5x7", c.width - x0 - tw - 6), x0, y,
                   font = "5x7", color = "#DCE4F4")
        else:
            c.text(fitwords(c, rows[i][0], "4x5", c.width - x0 - 2), x0,
                   i * lh + 2, font = "4x5", color = "#DCE4F4")
            if t != "":
                c.text(t, x0, i * lh + 9, font = "4x5", color = "#FFD86A")
    if demo:
        demo_badge(c)
