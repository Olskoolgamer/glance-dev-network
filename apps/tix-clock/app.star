# TIX Clock
#
# The TIX clock: four panels holding tens-of-hours, hours, tens-of-
# minutes and minutes. You read it by COUNTING lit cells, not by
# position, so which cells light is deliberately shuffled each
# minute — that shuffle is the whole character of the design.



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


def offset_hours(ctx):
    """Real UTC offset for the configured zip, DST already applied.

    Two cached hops: zip -> lat/lon, then lat/lon -> offset. Any failure falls
    back to UTC, so a dead API costs you the timezone, not the panel."""
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
    weekday = (days + 3) % 7           # 1970-01-01 was a Thursday
    y = 1970
    for i in range(400):
        span = 366 if is_leap(y) else 365
        if days < span:
            break
        days -= span
        y += 1
    m = 0
    yd = days
    for i in range(12):
        span = MDAYS[m] + (1 if (m == 1 and is_leap(y)) else 0)
        if days < span:
            break
        days -= span
        m += 1
    return {"year": y, "month": m + 1, "day": days + 1, "weekday": weekday,
            "yday": yd + 1, "hour": secs // 3600, "minute": (secs % 3600) // 60,
            "second": secs % 60, "secs": secs, "unix": shifted}


def h12(h):
    v = h % 12
    return 12 if v == 0 else v


def lcg(state):
    return (state * 1103515245 + 12345) % 2147483648


def seeded(n):
    return (n * 2654435761) % 2147483647 + 1


FIELDS = [[3, "#FF4E5B"], [9, "#4EE38A"], [5, "#4EA8FF"], [9, "#F5D64E"]]


def tix(c, ctx):
    t = local(ctx)
    vals = [t["hour"] // 10, t["hour"] % 10, t["minute"] // 10, t["minute"] % 10]

    c.fill("#06070C")
    # Reshuffle once a minute so the pattern changes but a single render is stable.
    state = seeded(t["unix"] // 60)

    # Size the cells to the panel, then centre the whole block: the fields are
    # 1+3+3+3 = 10 columns wide plus three gaps.
    gaps = 3 if c.width < 128 else 6
    cw = (c.width - 8 - gaps * 3) // 10
    if cw > (c.height - 4) // 3:
        cw = (c.height - 4) // 3
    if cw < 3:
        cw = 3
    block = 10 * cw + gaps * 3
    x = (c.width - block) // 2
    for f in range(4):
        cells = FIELDS[f][0]
        col = FIELDS[f][1]
        cols = 1 if cells == 3 else 3
        rows = 3
        bw = cols * cw
        # choose `vals[f]` cells at random out of cells
        pick = []
        for i in range(cells):
            pick.append(0)
        remaining = vals[f]
        for i in range(cells):
            state = lcg(state)
            left = cells - i
            if remaining > 0 and (state // 1024) % left < remaining:
                pick[i] = 1
                remaining -= 1
        # If the shuffle came up short, fill from the front so the count is
        # always exactly right — the time must never be wrong.
        for i in range(cells):
            if remaining <= 0:
                break
            if pick[i] == 0:
                pick[i] = 1
                remaining -= 1

        y0 = (c.height - rows * cw) // 2
        for i in range(cells):
            cx = x + (i % cols) * cw
            cy = y0 + (i // cols) * cw
            if pick[i]:
                c.rect(cx, cy, cx + cw - 2, cy + cw - 2, fill = col)
            else:
                c.rect(cx, cy, cx + cw - 2, cy + cw - 2, outline = "#181B26")
        x += bw + gaps
