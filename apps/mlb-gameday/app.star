# MLB Gameday
#
# MLB's own stats API, no key, and already a proven dependency of
# the leaders apps in this repo.
#
# The diamond is the point. Bases light yellow when occupied, so
# 'anybody on?' is answered from across the room without reading a
# single character. The sprite is drawn without its bases exactly
# so the app can light them.
#
# Three states, three layouts: scheduled shows first pitch, live
# shows the diamond, final shows the result.



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


IDS = {"ARI": 109, "ATL": 144, "BAL": 110, "BOS": 111, "CHC": 112,
       "CWS": 145, "CIN": 113, "CLE": 114, "COL": 115, "DET": 116,
       "HOU": 117, "KC": 118, "LAA": 108, "LAD": 119, "MIA": 146,
       "MIL": 158, "MIN": 142, "NYM": 121, "NYY": 147, "OAK": 133,
       "PHI": 143, "PIT": 134, "SD": 135, "SF": 137, "SEA": 136,
       "STL": 138, "TB": 139, "TEX": 140, "TOR": 141, "WSH": 120}


def abbr(team):
    a = team.get("abbreviation", None)
    if a != None:
        return str(a).upper()
    return str(team.get("name", "")).upper()[:3]


def bases(c, x, y, n, on1, on2, on3):
    """Light the three bases on the infield sprite."""
    s = 3 if n > 16 else 2
    lit = "#FFD84A"
    dim = "#3E4A38"
    mid = n // 2
    # second = top vertex, first = right, third = left
    c.rect(x + mid - s // 2, y + 1, x + mid - s // 2 + s - 1, y + s,
           fill = lit if on2 else dim)
    c.rect(x + n - s - 1, y + mid - s // 2, x + n - 2, y + mid - s // 2 + s - 1,
           fill = lit if on1 else dim)
    c.rect(x + 1, y + mid - s // 2, x + s, y + mid - s // 2 + s - 1,
           fill = lit if on3 else dim)


def game(c, ctx):
    tm = str(ctx.inputs.get("team", "NYY")).upper()
    tid = IDS.get(tm, 147)

    r = http.get("https://statsapi.mlb.com/api/v1/schedule",
                 params = {"sportId": "1", "teamId": str(tid),
                           "hydrate": "linescore,team"},
                 ttl_seconds = 60)
    if r["status_code"] != 200 or not r["json"]:
        nodata(c, "NO MLB DATA", "NO CONNECTION")
        return

    dates = r["json"].get("dates", [])
    if len(dates) == 0 or len(dates[0].get("games", [])) == 0:
        c.fill("#06120A")
        c.text("NO GAME TODAY", c.width // 2, c.height // 2 - 4,
               font = "10x16" if c.width >= 128 else "5x7", color = "#4E8E68",
               align = "center")
        return

    g = dates[0]["games"][0]
    state = str(g.get("status", {}).get("abstractGameState", "")).upper()
    away = g["teams"]["away"]
    home = g["teams"]["home"]
    aw = abbr(away.get("team", {}))
    hm = abbr(home.get("team", {}))
    asc = away.get("score", None)
    hsc = home.get("score", None)
    ls = g.get("linescore", {})

    c.gradient_rect(0, 0, c.width - 1, c.height - 1, "#06140A", "#123018",
                    horizontal = False)

    if state == "PREVIEW":
        t = str(g.get("gameDate", ""))
        clock = t[11:16] if len(t) >= 16 else ""
        if c.width >= 128:
            # Right column first, then the matchup fitted to what is left —
            # at 16x20 it ran straight through the first-pitch line.
            c.text("FIRST PITCH", c.width - 6, 3, font = "5x7",
                   color = "#9FD8AE", align = "right")
            c.text(clock + " UTC", c.width - 6, 12, font = "10x16",
                   color = "#FFD84A", align = "right")
            c.text_fit(aw + " AT " + hm, 6, 6, ["16x20", "10x16", "6x8"],
                       color = "#DCF0E0", maxw = c.width - 104)
        else:
            c.text_fit(aw + " AT " + hm, c.width // 2, 4,
                       ["6x8", "5x7", "4x5"], color = "#DCF0E0",
                       align = "center", maxw = c.width - 4)
            c.text(clock, c.width // 2, 15, font = "10x16", color = "#FFD84A",
                   align = "center")
        return

    n = 21 if c.width >= 128 else 14
    dx = 2
    dy = (c.height - n) // 2
    c.image("DIAMOND.png", dx, dy, w = n, h = n)

    off = ls.get("offense", {})
    on1 = off.get("first", None) != None
    on2 = off.get("second", None) != None
    on3 = off.get("third", None) != None
    if state == "LIVE":
        bases(c, dx, dy, n, on1, on2, on3)

    sa = str(asc) if asc != None else "0"
    sh = str(hsc) if hsc != None else "0"
    x0 = dx + n + 4

    if c.width >= 128:
        c.text(aw + " " + sa, x0, 2, font = "10x16", color = "#FFFFFF")
        c.text(hm + " " + sh, x0, 17, font = "10x16", color = "#FFFFFF")
        if state == "LIVE":
            half = str(ls.get("inningState", ""))[:3].upper()
            c.text(half + " " + str(ls.get("currentInning", "")), c.width - 6,
                   2, font = "6x8", color = "#8FE3A0", align = "right")
            outs = int(ls.get("outs", 0) or 0)
            for i in range(3):
                ox = c.width - 24 + i * 7
                c.rect(ox, 13, ox + 4, 17,
                       fill = "#FF5B5B" if i < outs else "#2E4436")
            c.text(str(int(ls.get("balls", 0) or 0)) + "-"
                   + str(int(ls.get("strikes", 0) or 0)), c.width - 6, 21,
                   font = "6x8", color = "#C8E0CC", align = "right")
        else:
            c.text("FINAL", c.width - 6, 11, font = "10x16", color = "#8FE3A0",
                   align = "right")
    else:
        c.text(aw + " " + sa, x0, 3, font = "5x7", color = "#FFFFFF")
        c.text(hm + " " + sh, x0, 13, font = "5x7", color = "#FFFFFF")
        if state == "LIVE":
            outs = int(ls.get("outs", 0) or 0)
            c.text(str(outs) + " OUT", x0, 23, font = "4x5", color = "#8FE3A0")
        else:
            c.text("FINAL", x0, 23, font = "4x5", color = "#8FE3A0")
