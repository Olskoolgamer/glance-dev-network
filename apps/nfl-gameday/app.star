# DESIGN. One app, any NFL club. Every page wears the chosen team's colors:
# a 2px accent rail at the far left, a team-color chip carrying the nickname,
# and a quiet 4x5 page label — so the app reads as one unit in the scroll
# stream and identifies itself before its data does. Page 1 is a game card:
# both club crests at 24px facing a single hero (the score when the game is
# live or final, the local kickoff time when it isn't), records under the
# abbreviations, TV network and betting line in the footline. Page 2 is the
# last three results as W/L rows beside a right-hand record hero. Page 3 is
# the injury report, worst news first, three rows at a time. Black ground
# throughout; white for live numbers, gray for labels, green/amber/red kept
# for state. Data: ESPN's site.web.api.espn.com JSON (the plain site.api
# host is blocked from the render service's egress, so every fetch goes
# through site.web).

BASE = "https://site.web.api.espn.com/apis/site/v2/sports/football/nfl"

# ---------------------------------------------------------------- teams
# ESPN team id, crest asset stem, chip nickname, accent (the club color that
# reads on black — the brighter of ESPN's color/alternateColor, lifted when
# both are too dark for an LED), and the text color that survives the accent.
TEAMS = {
    "ARIZONA CARDINALS": ["22", "ari", "CARDINALS", "#FF044E", "white"],
    "ATLANTA FALCONS": ["1", "atl", "FALCONS", "#A71930", "white"],
    "BALTIMORE RAVENS": ["33", "bal", "RAVENS", "#7F37FF", "white"],
    "BUFFALO BILLS": ["2", "buf", "BILLS", "#D50A0A", "white"],
    "CAROLINA PANTHERS": ["29", "car", "PANTHERS", "#0085CA", "white"],
    "CHICAGO BEARS": ["3", "chi", "BEARS", "#E64100", "white"],
    "CINCINNATI BENGALS": ["4", "cin", "BENGALS", "#FB4F14", "white"],
    "CLEVELAND BROWNS": ["5", "cle", "BROWNS", "#FF3C00", "white"],
    "DALLAS COWBOYS": ["6", "dal", "COWBOYS", "#B0B7BC", "black"],
    "DENVER BRONCOS": ["7", "den", "BRONCOS", "#FC4C02", "white"],
    "DETROIT LIONS": ["8", "det", "LIONS", "#0076B6", "white"],
    "GREEN BAY PACKERS": ["9", "gb", "PACKERS", "#FFB612", "black"],
    "HOUSTON TEXANS": ["34", "hou", "TEXANS", "#EB0028", "white"],
    "INDIANAPOLIS COLTS": ["11", "ind", "COLTS", "#0087FF", "white"],
    "JACKSONVILLE JAGUARS": ["30", "jax", "JAGUARS", "#D7A22A", "black"],
    "KANSAS CITY CHIEFS": ["12", "kc", "CHIEFS", "#FFB612", "black"],
    "LAS VEGAS RAIDERS": ["13", "lv", "RAIDERS", "#A5ACAF", "black"],
    "LOS ANGELES CHARGERS": ["24", "lac", "CHARGERS", "#FFC20E", "black"],
    "LOS ANGELES RAMS": ["14", "lar", "RAMS", "#FFD100", "black"],
    "MIAMI DOLPHINS": ["15", "mia", "DOLPHINS", "#FC4C02", "white"],
    "MINNESOTA VIKINGS": ["16", "min", "VIKINGS", "#FFC62F", "black"],
    "NEW ENGLAND PATRIOTS": ["17", "ne", "PATRIOTS", "#C60C30", "white"],
    "NEW ORLEANS SAINTS": ["18", "no", "SAINTS", "#D3BC8D", "black"],
    "NEW YORK GIANTS": ["19", "nyg", "GIANTS", "#C9243F", "white"],
    "NEW YORK JETS": ["20", "nyj", "JETS", "#115740", "white"],
    "PHILADELPHIA EAGLES": ["21", "phi", "EAGLES", "#0D93AB", "white"],
    "PITTSBURGH STEELERS": ["23", "pit", "STEELERS", "#FFB612", "black"],
    "SAN FRANCISCO 49ERS": ["25", "sf", "49ERS", "#B3995D", "black"],
    "SEATTLE SEAHAWKS": ["26", "sea", "SEAHAWKS", "#69BE28", "white"],
    "TAMPA BAY BUCCANEERS": ["27", "tb", "BUCCANEERS", "#BD1C36", "white"],
    "TENNESSEE TITANS": ["10", "ten", "TITANS", "#4495D2", "white"],
    "WASHINGTON COMMANDERS": ["28", "wsh", "COMMANDERS", "#FFB612", "black"],
}

# Crest asset stem by ESPN scoreboard abbreviation, so the OPPONENT's logo can
# be found too. Anything not in here (Pro Bowl AFC/NFC, a TBD slot) falls back
# to drawing the abbreviation as text instead of a crest.
STEM_BY_ABBR = {
    "ARI": "ari", "ATL": "atl", "BAL": "bal", "BUF": "buf", "CAR": "car",
    "CHI": "chi", "CIN": "cin", "CLE": "cle", "DAL": "dal", "DEN": "den",
    "DET": "det", "GB": "gb", "HOU": "hou", "IND": "ind", "JAX": "jax",
    "KC": "kc", "LAC": "lac", "LAR": "lar", "LV": "lv", "MIA": "mia",
    "MIN": "min", "NE": "ne", "NO": "no", "NYG": "nyg", "NYJ": "nyj",
    "PHI": "phi", "PIT": "pit", "SEA": "sea", "SF": "sf", "TB": "tb",
    "TEN": "ten", "WSH": "wsh",
}

SAFE_L = 6                 # scroll safe zone: 6px at the app's outer edges
SAFE_R = 185
STRUCT = "darkgray"        # dividers, tracks
OFFLINE = "#3C4043"        # the rail when there is no data
INK = "#F4F7FF"            # primary text
DIM = "#6E7A94"            # secondary text

# ---------------------------------------------------------------- house kit

def clip(c, text, font, maxw):
    """Longest prefix of `text` that fits `maxw` — nothing in the API clips,
    so every API string comes through here before it is drawn."""
    t = str(text)
    if c.text_width(t, font) <= maxw:
        return t
    for k in range(len(t), 0, -1):
        if c.text_width(t[:k], font) <= maxw:
            return t[:k]
    return ""

def clip_words(c, text, font, maxw):
    """clip(), backed up to the last whole word unless that costs > 30%."""
    t = clip(c, text, font, maxw)
    if t == str(text):
        return t
    sp = t.rfind(" ")
    if sp > 0 and sp * 10 >= len(t) * 7:
        return t[:sp]
    return t

def fit(c, text, fonts, maxw):
    """[font, clipped text] for the largest listed font that fits."""
    t = str(text)
    pick = fonts[len(fonts) - 1]
    for f in fonts:
        if c.text_width(t, f) <= maxw:
            pick = f
            break
    return [pick, clip(c, t, pick, maxw)]

def rail(c, color):
    c.rect(0, 0, 1, 31, fill = color)

def message(c, head, sub, head_color = "amber"):
    """The one screen every failure/empty state shares."""
    c.text(clip(c, head, "5x7", 150), c.width // 2, 11, font = "5x7",
           color = head_color, align = "center")
    if sub != "":
        c.text(clip(c, sub, "4x5", 150), c.width // 2, 23, font = "4x5",
               color = DIM, align = "center")

def get(obj, key, fallback = None):
    """dict.get that survives a null parent, which ESPN hands back often."""
    if obj == None or type(obj) != "dict":
        return fallback
    v = obj.get(key, fallback)
    return fallback if v == None else v

def dig(obj, path, fallback = None):
    """get() down a chain: dig(ev, ["status", "type", "state"], "")."""
    cur = obj
    for key in path:
        cur = get(cur, key)
        if cur == None:
            return fallback
    return cur

def lst(obj, key):
    v = get(obj, key, [])
    return v if type(v) == "list" else []

def num(s, fallback = 0):
    """int() raises on anything non-numeric, and a raised error kills the
    whole render, so every number out of a feed comes through here."""
    t = str(s).strip()
    neg = t.startswith("-")
    if neg:
        t = t[1:]
    if t == "":
        return fallback
    for ch in t.elems():
        if ch < "0" or ch > "9":
            return fallback
    v = int(t)
    return -v if neg else v

# ---------------------------------------------------------------- time
# Civil-date math + a small IANA-zone table so kickoff shows in the panel's
# own time zone (the manifest's `timezone` dropdown), DST included.

def days_from_civil(y, m, d):
    yy = y - 1 if m <= 2 else y
    era = (yy if yy >= 0 else yy - 399) // 400
    yoe = yy - era * 400
    mm = m + (-3 if m > 2 else 9)
    doy = (153 * mm + 2) // 5 + d - 1
    doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
    return era * 146097 + doe - 719468

def civil_year(days):
    z = days + 719468
    era = (z if z >= 0 else z - 146096) // 146097
    doe = z - era * 146097
    yoe = (doe - doe // 1460 + doe // 36524 - doe // 146096) // 365
    y = yoe + era * 400
    doy = doe - (365 * yoe + yoe // 4 - yoe // 100)
    mp = (5 * doy + 2) // 153
    m = mp + 3 if mp < 10 else mp - 9
    return y + 1 if m <= 2 else y

def weekday(days):
    """0 = Monday. 1970-01-01 (day 0) was a Thursday."""
    return (days + 3) % 7

def nth_sunday(y, m, n):
    """Day of month of the nth Sunday, or the last one when n is -1."""
    if n == -1:
        last = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][m - 1]
        if m == 2 and y % 4 == 0 and (y % 100 != 0 or y % 400 == 0):
            last = 29
        return last - ((weekday(days_from_civil(y, m, last)) + 1) % 7)
    first = 1 + ((6 - weekday(days_from_civil(y, m, 1))) % 7)
    return first + 7 * (n - 1)

# [minutes east of UTC in standard time, DST rule]. Rules: 0 none, 1 US,
# 2 Europe, 3 AU southeast, 4 NZ. Matches the manifest's dropdown exactly.
TZ = {
    "Pacific/Honolulu": [-600, 0],
    "America/Anchorage": [-540, 1],
    "America/Los_Angeles": [-480, 1],
    "America/Phoenix": [-420, 0],
    "America/Denver": [-420, 1],
    "America/Chicago": [-360, 1],
    "America/Mexico_City": [-360, 0],
    "America/New_York": [-300, 1],
    "America/Sao_Paulo": [-180, 0],
    "UTC": [0, 0],
    "Europe/London": [0, 2],
    "Europe/Paris": [60, 2],
    "Africa/Johannesburg": [120, 0],
    "Europe/Moscow": [180, 0],
    "Asia/Dubai": [240, 0],
    "Asia/Kolkata": [330, 0],
    "Asia/Shanghai": [480, 0],
    "Asia/Singapore": [480, 0],
    "Asia/Tokyo": [540, 0],
    "Australia/Sydney": [600, 3],
    "Pacific/Auckland": [720, 4],
}

def _utcmin(y, m, d, hh):
    return days_from_civil(y, m, d) * 1440 + hh * 60

def zone_offset(ctx):
    """Minutes east of UTC for the panel's dropdown zone, DST-correct at the
    UTC instant `ctx.now`."""
    zone = str(ctx.inputs.get("timezone", "America/New_York")).strip()
    z = TZ[zone] if zone in TZ else TZ["UTC"]
    std, rule = z[0], z[1]
    if rule == 0:
        return std
    t = ctx.now.unix // 60
    y = civil_year(t // 1440)
    if rule == 1:
        start = _utcmin(y, 3, nth_sunday(y, 3, 2), 2) - std
        end = _utcmin(y, 11, nth_sunday(y, 11, 1), 2) - std - 60
        return std + 60 if t >= start and t < end else std
    if rule == 2:
        start = _utcmin(y, 3, nth_sunday(y, 3, -1), 1)
        end = _utcmin(y, 10, nth_sunday(y, 10, -1), 1)
        return std + 60 if t >= start and t < end else std
    m0 = 10 if rule == 3 else 9
    n0 = 1 if rule == 3 else -1
    start = _utcmin(y, m0, nth_sunday(y, m0, n0), 2) - std
    end = _utcmin(y, 4, nth_sunday(y, 4, 1), 3) - std - 60
    return std if t >= end and t < start else std + 60

MONTHS = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN",
          "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
DAYS = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]

def parse_iso_unix(s):
    """ESPN's Zulu stamps ("2026-09-09T00:20Z") -> unix seconds, or -1."""
    t = str(s)
    if len(t) < 16:
        return -1
    y = num(t[0:4], -1)
    mo = num(t[5:7], -1)
    d = num(t[8:10], -1)
    h = num(t[11:13], -1)
    mi = num(t[14:16], -1)
    if y < 0 or mo < 1 or mo > 12 or d < 1 or h < 0 or mi < 0:
        return -1
    return days_from_civil(y, mo, d) * 86400 + h * 3600 + mi * 60

def local_parts(unix, off_min):
    """[weekday name, "SEP 13", "8:20P"] for a unix instant in panel time."""
    u = unix + off_min * 60
    days = u // 86400
    secs = u % 86400
    z = days + 719468
    era = (z if z >= 0 else z - 146096) // 146097
    doe = z - era * 146097
    yoe = (doe - doe // 1460 + doe // 36524 - doe // 146096) // 365
    doy = doe - (365 * yoe + yoe // 4 - yoe // 100)
    mp = (5 * doy + 2) // 153
    d = doy - (153 * mp + 2) // 5 + 1
    m = mp + 3 if mp < 10 else mp - 9
    hh = secs // 3600
    mi = (secs % 3600) // 60
    ap = "P" if hh >= 12 else "A"
    h12 = hh % 12
    if h12 == 0:
        h12 = 12
    mm = ("0" + str(mi)) if mi < 10 else str(mi)
    return [DAYS[weekday(days)], MONTHS[m - 1] + " " + str(d),
            str(h12) + ":" + mm + ap]

# ---------------------------------------------------------------- fetching

def espn(path, params, ttl):
    """One GET against site.web.api.espn.com. ttl_seconds per feed: 120 for
    the live scoreboard (matches the manifest's refresh), slower elsewhere.
    Returns the decoded JSON dict, or None so pages can draw the offline card."""
    r = http.get(BASE + path, params = params, ttl_seconds = ttl)
    if r["status_code"] != 200:
        return None
    j = r["json"]
    return j if type(j) == "dict" else None

def my_team(ctx):
    key = str(ctx.inputs.get("team", "NEW ORLEANS SAINTS")).strip().upper()
    if key not in TEAMS:
        key = "NEW ORLEANS SAINTS"
    t = TEAMS[key]
    return {"id": t[0], "stem": t[1], "nick": t[2], "accent": t[3],
            "chip_text": t[4], "abbr": ""}

def unpack_event(ev, tid):
    """Everything the game card needs out of a scoreboard / nextEvent /
    schedule event, null-proofed. Returns {} when the event is not usable."""
    comps = lst(ev, "competitions")
    if len(comps) == 0:
        return {}
    comp = comps[0]
    home = {}
    away = {}
    mine_at_home = False
    for cr in lst(comp, "competitors"):
        if get(cr, "homeAway", "") == "home":
            home = cr
        else:
            away = cr
    if len(home) == 0 or len(away) == 0:
        return {}
    if str(dig(home, ["team", "id"], "")) == tid:
        mine_at_home = True
    stype = dig(comp, ["status", "type"], None)
    if stype == None:
        stype = dig(ev, ["status", "type"], {})
    situation = get(comp, "situation", {})
    odds = ""
    ol = lst(comp, "odds")
    if len(ol) > 0:
        odds = str(get(ol[0], "details", "")).upper()
    return {
        "date": get(ev, "date", ""),
        "state": get(stype, "state", "pre"),
        "detail": str(get(stype, "shortDetail", "")).upper(),
        "completed": get(stype, "completed", False),
        "home": side_of(home),
        "away": side_of(away),
        "mine_at_home": mine_at_home,
        "network": broadcast_of(comp),
        "odds": odds,
        "down": str(get(situation, "shortDownDistanceText", "")).upper(),
    }

def side_of(cr):
    team = get(cr, "team", {})
    s = get(cr, "score", "")
    if type(s) == "dict":
        s = get(s, "displayValue", get(s, "value", ""))
    rec = ""
    for r in lst(cr, "records"):
        if get(r, "type", "") == "total" or get(r, "name", "") == "overall":
            rec = str(get(r, "summary", ""))
            break
    return {
        "abbr": str(get(team, "abbreviation", "?")).upper(),
        "score": str(s),
        "record": rec,
        "winner": get(cr, "winner", False),
    }

def broadcast_of(comp):
    for b in lst(comp, "broadcasts"):
        names = lst(b, "names")
        if len(names) > 0:
            return str(names[0]).upper()
        short = dig(b, ["media", "shortName"], "")
        if short != "":
            return str(short).upper()
    return ""

def pick_event(ctx, team):
    """The game the card shows: this week's scoreboard game if the team is in
    it (that is where live scores are), else the club's next scheduled game,
    else its most recent completed one. Second value is False when every feed
    failed, so the page can tell "offline" from "no games"."""
    sb = espn("/scoreboard", {}, 120)
    detail = espn("/teams/" + team["id"], {}, 600)
    online = sb != None or detail != None
    for ev in lst(sb, "events"):
        comps = lst(ev, "competitions")
        if len(comps) == 0:
            continue
        for cr in lst(comps[0], "competitors"):
            if str(dig(cr, ["team", "id"], "")) == team["id"]:
                got = unpack_event(ev, team["id"])
                if len(got) > 0:
                    return [got, online]
    nxt = lst(dig(detail, ["team"], {}), "nextEvent")
    if len(nxt) > 0:
        got = unpack_event(nxt[0], team["id"])
        if len(got) > 0:
            return [got, online]
    sched = espn("/teams/" + team["id"] + "/schedule", {}, 1800)
    online = online or sched != None
    done = past_games(sched, team["id"])
    if len(done) > 0:
        return [done[0], online]
    return [{}, online]

def past_games(sched, tid):
    """Completed schedule games, newest first."""
    out = []
    for ev in lst(sched, "events"):
        got = unpack_event(ev, tid)
        if len(got) > 0 and got["completed"]:
            out.append(got)
    return sorted(out, key = lambda g: g["date"], reverse = True)

# ---------------------------------------------------------------- chrome

FONTH = {"4x5": 5, "5x7": 7, "6x8": 8, "10x16": 16}

def chrome(c, team, label, meta, meta_color):
    """Rail + team chip + page label + right-aligned meta, on every page.
    The label is clipped against the meta so the two can never collide
    (chip "BUCCANEERS" + "INJURY REPORT" + a wide meta is the worst case)."""
    rail(c, team["accent"])
    w = c.badge(team["nick"], 4, 0, color = team["chip_text"],
                bg = team["accent"], font = "4x5")
    lx = 4 + w + 3
    meta_t = clip(c, meta, "4x5", 80)
    mx = SAFE_R - c.text_width(meta_t, "4x5")
    if meta_t != "":
        c.text(meta_t, mx, 1, font = "4x5", color = meta_color)
    room = mx - lx - 4 if meta_t != "" else SAFE_R - lx
    if room > 8:
        c.text(clip_words(c, label, "4x5", room), lx, 1, font = "4x5",
               color = DIM)

# ---------------------------------------------------------------- pages

def crest(c, stem_or_abbr, x, y, size):
    """A club crest at its authored size — or the abbreviation as text when
    we have no crest for it (Pro Bowl sides, TBD opponents)."""
    stem = STEM_BY_ABBR.get(stem_or_abbr, "")
    if stem != "":
        c.image(stem + str(size) + ".png", x, y)
        return
    c.text(clip(c, stem_or_abbr, "5x7", size + 4), x, y + (size - 7) // 2,
           font = "5x7", color = DIM)

def game(c, ctx):
    team = my_team(ctx)
    ev, online = pick_event(ctx, team)

    if len(ev) == 0:
        chrome(c, team, "GAMEDAY", "", DIM)
        if not online:
            rail(c, OFFLINE)
            message(c, "ESPN UNREACHABLE", "SCORES RETURN NEXT REFRESH")
        else:
            message(c, "NO GAMES SCHEDULED", "SEE YOU NEXT SEASON", "green")
        return

    state = ev["state"]
    off = zone_offset(ctx)
    when = parse_iso_unix(ev["date"])
    parts = local_parts(when, off) if when >= 0 else ["", "", ""]

    if state == "in":
        chrome(c, team, "GAMEDAY", "LIVE " + ev["detail"], "red")
    elif state == "post":
        chrome(c, team, "GAMEDAY", ev["detail"], DIM)
    else:
        chrome(c, team, "GAMEDAY", parts[0] + " " + parts[1], INK)

    # Matchup band, away at home's place: crests just inside the safe zone,
    # abbreviations + records beside them, one hero in the middle.
    away, home = ev["away"], ev["home"]
    crest(c, away["abbr"], SAFE_L, 8, 24)
    crest(c, home["abbr"], SAFE_R - 23, 8, 24)

    a_color = INK
    h_color = INK
    if state == "post":
        # Past game: the loser dims, the winner keeps full white.
        if away["winner"] and not home["winner"]:
            h_color = DIM
        if home["winner"] and not away["winner"]:
            a_color = DIM
    c.text(clip(c, away["abbr"], "6x8", 22), 33, 10, font = "6x8", color = a_color)
    c.text(clip(c, home["abbr"], "6x8", 22), 159, 10, font = "6x8",
           color = h_color, align = "right")
    if away["record"] != "":
        c.text(clip(c, away["record"], "4x5", 26), 33, 21, font = "4x5", color = DIM)
    if home["record"] != "":
        c.text(clip(c, home["record"], "4x5", 26), 159, 21, font = "4x5",
               color = DIM, align = "right")

    # Center hero + footline. 62..130 is what's left between the abbr blocks;
    # "45-42" at 10x16 is 54px, so the ladder only drops for weird strings.
    if state == "pre":
        f, t = fit(c, parts[2], ["10x16", "6x8"], 66)
        c.text(t, 96, 9 + (16 - FONTH[f]) // 2, font = f, color = INK,
               align = "center")
        foot = ev["network"]
        if ev["odds"] != "":
            foot = foot + ("  " if foot != "" else "") + ev["odds"]
        if foot == "":
            foot = "AT " + home["abbr"]
        c.text(clip(c, foot, "4x5", 66), 96, 27, font = "4x5", color = DIM,
               align = "center")
    else:
        f, t = fit(c, away["score"] + "-" + home["score"], ["10x16", "6x8"], 66)
        c.text(t, 96, 9 + (16 - FONTH[f]) // 2, font = f, color = INK,
               align = "center")
        if state == "in":
            foot = ev["down"] if ev["down"] != "" else ev["detail"]
            c.text(clip(c, foot, "4x5", 66), 96, 27, font = "4x5",
                   color = "amber", align = "center")
        else:
            c.text(clip(c, parts[1], "4x5", 66), 96, 27, font = "4x5",
                   color = DIM, align = "center")

def results(c, ctx):
    team = my_team(ctx)
    sched = espn("/teams/" + team["id"] + "/schedule", {}, 1800)
    detail = espn("/teams/" + team["id"], {}, 600)

    record = ""
    for item in lst(dig(detail, ["team", "record"], {}), "items"):
        if get(item, "type", "") == "total":
            record = str(get(item, "summary", ""))
            break
    standing = str(dig(detail, ["team", "standingSummary"], "")).upper()

    if sched == None and detail == None:
        chrome(c, team, "RESULTS", "", DIM)
        rail(c, OFFLINE)
        message(c, "ESPN UNREACHABLE", "RESULTS RETURN NEXT REFRESH")
        return

    games = past_games(sched, team["id"])
    evs = lst(sched, "events")
    stype = ""
    if len(evs) > 0:
        stype = str(dig(evs[0], ["seasonType", "abbreviation"], "")).lower()
    season = {"pre": "PRESEASON", "post": "PLAYOFFS"}.get(stype, "SEASON")

    chrome(c, team, "RESULTS", standing if standing != "" else season, DIM)

    if len(games) == 0:
        message(c, "NO GAMES PLAYED YET", "RESULTS LAND AFTER WEEK 1", "green")
        return

    off = zone_offset(ctx)

    # Left: newest three results. Right of the divider: the record hero with
    # the club crest, so the page still says whose record it is at 30 ft.
    y = 10
    for g in games[:3]:
        me = g["home"] if g["mine_at_home"] else g["away"]
        opp = g["away"] if g["mine_at_home"] else g["home"]
        won = me["winner"] and not opp["winner"]
        tied = me["score"] == opp["score"]
        letter = "T" if tied else ("W" if won else "L")
        lcolor = "gray" if tied else ("green" if won else "red")
        c.rect(SAFE_L, y + 1, SAFE_L + 1, y + 2, fill = lcolor)
        when = parse_iso_unix(g["date"])
        date = local_parts(when, off)[1] if when >= 0 else ""
        x = SAFE_L + 5
        c.text(date, x, y, font = "4x5", color = DIM)
        x = x + c.text_width(date, "4x5") + 3
        # 4x5's W reads as an H at this size; 5x5 is the same ink height
        # with a proper 5-column W.
        c.text(letter, x, y, font = "5x5", color = lcolor)
        x = x + c.text_width(letter, "5x5") + 3
        score = me["score"] + "-" + opp["score"]
        c.text(score, x, y, font = "4x5", color = INK)
        x = x + c.text_width(score, "4x5") + 3
        tail = ("VS " if g["mine_at_home"] else "AT ") + opp["abbr"]
        c.text(clip(c, tail, "4x5", 106 - x), x, y, font = "4x5", color = DIM)
        y = y + 7

    # Right of the divider: crest + season record hero. x136 leaves 49px,
    # so "10-3" (43px at 10x16) keeps the hero font.
    c.vline(110, 8, 24, STRUCT)
    crest(c, team_abbr_of(team), 116, 12, 16)
    hero = record if record != "" else "0-0"
    f, t = fit(c, hero, ["10x16", "6x8"], SAFE_R - 136)
    c.text(t, 136, 10 + (16 - FONTH[f]) // 2, font = f, color = INK)
    c.text(clip(c, "RECORD", "4x5", SAFE_R - 136), 136, 27, font = "4x5",
           color = DIM)

def team_abbr_of(team):
    for abbr in STEM_BY_ABBR:
        if STEM_BY_ABBR[abbr] == team["stem"]:
            return abbr
    return "?"

# Injury statuses, worst news first: [chip text, color, sort rank].
def severity(status):
    s = str(status).lower()
    if s.find("reserve") >= 0 or s == "ir":
        return ["IR", "red", 0]
    if s.find("out") >= 0:
        return ["OUT", "red", 1]
    if s.find("physically unable") >= 0 or s.find("pup") >= 0:
        return ["PUP", "red", 2]
    if s.find("doubtful") >= 0:
        return ["DOUB", "orange", 3]
    if s.find("question") >= 0:
        return ["QUES", "amber", 4]
    if s.find("day") >= 0:
        return ["DTD", "green", 5]
    return [str(status).upper()[:4], "amber", 6]

def injuries(c, ctx):
    team = my_team(ctx)
    data = espn("/injuries", {"team": team["id"]}, 1800)

    if data == None:
        chrome(c, team, "INJURY REPORT", "", DIM)
        rail(c, OFFLINE)
        message(c, "ESPN UNREACHABLE", "REPORT RETURNS NEXT REFRESH")
        return

    rows = []
    for item in lst(data, "injuries"):
        athlete = get(item, "athlete", {})
        name = str(get(athlete, "shortName",
                       get(athlete, "displayName", ""))).upper()
        if name == "":
            continue
        sev = severity(get(item, "status", ""))
        rows.append({
            "name": name,
            "pos": str(dig(athlete, ["position", "abbreviation"], "")).upper(),
            "sev": sev,
            "part": str(dig(item, ["details", "type"], "")).upper(),
        })
    rows = sorted(rows, key = lambda r: r["sev"][2])

    if len(rows) == 0:
        chrome(c, team, "INJURY REPORT", "", DIM)
        message(c, "NO INJURIES LISTED", "FULL SQUAD AVAILABLE", "green")
        return

    # Three rows per look; the panel pages through the report on its own
    # refresh clock (120 s), worst news in the first group.
    groups = (len(rows) + 2) // 3
    g = (ctx.now.unix // 120) % groups
    meta = str(len(rows)) + " LISTED"
    if groups > 1:
        meta = meta + "  " + str(g + 1) + "/" + str(groups)
    chrome(c, team, "INJURY REPORT", meta, "amber")

    y = 10
    for r in rows[g * 3:g * 3 + 3]:
        c.rect(SAFE_L, y + 1, SAFE_L + 1, y + 2, fill = r["sev"][1])
        # Fixed columns so 25 rows scan as a table: name, position, status,
        # body part. "C. GARDNER-JOHNSON" is the name that set the 72px.
        c.text(clip(c, r["name"], "4x5", 72), SAFE_L + 5, y, font = "4x5",
               color = INK)
        c.text(clip(c, r["pos"], "4x5", 14), 86, y, font = "4x5", color = DIM)
        c.text(clip(c, r["sev"][0], "4x5", 22), 104, y, font = "4x5",
               color = r["sev"][1])
        c.text(clip(c, r["part"], "4x5", SAFE_R - 130), 130, y, font = "4x5",
               color = DIM)
        y = y + 7
