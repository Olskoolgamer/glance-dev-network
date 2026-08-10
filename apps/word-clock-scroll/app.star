# Word Clock — the time as you would say it out loud.
#
# Page one spells the time in words, page two gives the plain digits and date
# for when you actually need to know. Both are pure ctx.now arithmetic.
#
# ctx.now is UTC, so it is shifted to your wall clock first — otherwise the
# words would be right only in Greenwich. The offset comes from a US zip code
# and is DST-aware, so there is nothing to change twice a year; if the lookup
# is unavailable the clock falls back to UTC rather than showing nothing.
#
# The phrase is laid out by trying the largest font first and falling back
# through smaller ones until the wrapped lines fit the panel. That is what lets
# the same file serve both a 64-wide and a 192-wide panel: "TWENTY FIVE" needs
# three lines on one and fits on a single line on the other.

MINWORDS = {5: "FIVE", 10: "TEN", 15: "QUARTER", 20: "TWENTY",
            25: "TWENTY FIVE", 30: "HALF"}
HOURS = ["TWELVE", "ONE", "TWO", "THREE", "FOUR", "FIVE", "SIX",
         "SEVEN", "EIGHT", "NINE", "TEN", "ELEVEN"]
DOW = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
MON = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN",
       "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
MDAYS = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

# font name -> pixel height, for the layout search
FONTH = {"16x20": 20, "10x16": 16, "7x12": 12, "6x8": 8, "5x7": 7, "4x5": 5}


def is_leap(y):
    return (y % 4 == 0 and y % 100 != 0) or (y % 400 == 0)


def offset_hours(ctx):
    """Real UTC offset for the configured zip, DST already applied.

    Two cached hops: zip -> lat/lon, then lat/lon -> offset. Both degrade to
    UTC on any failure, so a dead API costs you the timezone, not the panel."""
    zip = str(ctx.inputs.get("zip", "")).strip()
    if zip == "":
        return 0.0

    g = http.get("https://api.zippopotam.us/us/" + zip, ttl_seconds = 86400)
    if g["status_code"] != 200 or not g["json"]:
        return 0.0
    places = g["json"].get("places", [])
    if not places:
        return 0.0

    t = http.get(
        "https://timeapi.io/api/TimeZone/coordinate",
        params = {"latitude": places[0]["latitude"],
                  "longitude": places[0]["longitude"]},
        ttl_seconds = 3600,
    )
    if t["status_code"] != 200 or not t["json"]:
        return 0.0
    secs = t["json"].get("currentUtcOffset", {}).get("seconds", None)
    if secs == None:
        return 0.0
    return float(secs) / 3600.0


def local(ctx):
    """ctx.now shifted onto the viewer's wall clock."""
    shifted = ctx.now.unix + int(offset_hours(ctx) * 3600)
    days = shifted // 86400
    secs = shifted % 86400
    weekday = (days + 3) % 7          # 1970-01-01 was a Thursday

    y = 1970
    for i in range(400):
        span = 366 if is_leap(y) else 365
        if days < span:
            break
        days -= span
        y += 1
    m = 0
    for i in range(12):
        span = MDAYS[m] + (1 if (m == 1 and is_leap(y)) else 0)
        if days < span:
            break
        days -= span
        m += 1
    return {"year": y, "month": m + 1, "day": days + 1, "weekday": weekday,
            "hour": secs // 3600, "minute": (secs % 3600) // 60}


def phrase(t):
    """The time as a list of words, rounded to the nearest five minutes."""
    slot = ((t["minute"] + 2) // 5) * 5
    hour = t["hour"]
    if slot >= 60:
        slot = 0
        hour += 1
    if slot > 30:
        hour += 1

    words = ["IT", "IS"]
    if slot == 0:
        words.append(HOURS[hour % 12])
        words.append("O'CLOCK")
    elif slot <= 30:
        for w in MINWORDS[slot].split(" "):
            words.append(w)
        words.append("PAST")
        words.append(HOURS[hour % 12])
    else:
        for w in MINWORDS[60 - slot].split(" "):
            words.append(w)
        words.append("TO")
        words.append(HOURS[hour % 12])
    return words


def wrap(c, words, font, maxw):
    """Greedily pack words into lines no wider than maxw."""
    lines = []
    cur = ""
    for w in words:
        trial = w if cur == "" else cur + " " + w
        if c.text_width(trial, font) <= maxw:
            cur = trial
        else:
            if cur != "":
                lines.append(cur)
            # A single word wider than the panel still has to go somewhere.
            cur = w
    if cur != "":
        lines.append(cur)
    return lines


def layout(c, words, fonts, maxw, maxh):
    """Largest font whose wrapped lines still fit the panel height."""
    for f in fonts:
        lines = wrap(c, words, f, maxw)
        gap = 2 if FONTH[f] >= 10 else 1
        if len(lines) * (FONTH[f] + gap) - gap <= maxh:
            return [f, lines]
    f = fonts[len(fonts) - 1]
    return [f, wrap(c, words, f, maxw)]


def words(c, ctx):
    t = local(ctx)
    accent = ctx.inputs.get("accent", "#FFB03A")

    fonts = ["16x20", "10x16", "7x12", "6x8", "5x7", "4x5"]
    got = layout(c, phrase(t), fonts, c.width - 6, c.height - 2)
    font = got[0]
    lines = got[1]

    gap = 2 if FONTH[font] >= 10 else 1
    block = len(lines) * (FONTH[font] + gap) - gap
    y = (c.height - block) // 2

    # One colour for the whole phrase. Dimming just the "IT IS" looked good
    # when it wrapped onto its own line and inconsistent when it did not, and
    # which happens depends on the time of day.
    c.fill("#07070E")
    for i in range(len(lines)):
        c.text(lines[i], c.width // 2, y + i * (FONTH[font] + gap),
               font = font, color = accent, align = "center")


def digital(c, ctx):
    t = local(ctx)
    accent = ctx.inputs.get("accent", "#FFB03A")
    clock = "%d:%s" % (12 if t["hour"] % 12 == 0 else t["hour"] % 12,
                       fmt.pad(t["minute"]))
    ampm = "AM" if t["hour"] < 12 else "PM"
    date = "%s %s %d" % (DOW[t["weekday"]], MON[t["month"] - 1], t["day"])

    c.fill("#07070E")
    if c.width >= 128:
        c.text(clock, 6, 6, font = "16x20", color = "#FFFFFF")
        c.text(ampm, 6 + c.text_width(clock, "16x20") + 4, 18, font = "6x8",
               color = accent)
        c.text(date, c.width - 6, 12, font = "6x8", color = "#9A9AB8",
               align = "right")
    else:
        c.text(clock, c.width // 2, 3, font = "10x16", color = "#FFFFFF",
               align = "center")
        c.text(ampm, c.width // 2, 20, font = "4x5", color = accent,
               align = "center")
        c.text(date, c.width // 2, 25, font = "4x5", color = "#9A9AB8",
               align = "center")
