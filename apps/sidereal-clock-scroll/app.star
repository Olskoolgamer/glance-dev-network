# Sidereal Clock
#
# Sidereal time runs about four minutes a day fast against civil time,
# because it tracks the stars rather than the sun. Point a telescope
# by it: an object's right ascension equals the local sidereal time
# when it crosses your meridian.
#
# Longitude comes from the zip lookup; without it the panel shows
# Greenwich sidereal time and says so, rather than a wrong local one.



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


def longitude(ctx):
    """Longitude for the configured zip, or None when unavailable."""
    zip = str(ctx.inputs.get("zip", "")).strip()
    if zip == "":
        return None
    g = http.get("https://api.zippopotam.us/us/" + zip, ttl_seconds = 86400)
    if g["status_code"] != 200 or not g["json"]:
        return None
    places = g["json"].get("places", [])
    if not places:
        return None
    return float(places[0]["longitude"])


def gmst_hours(unix):
    """Greenwich mean sidereal time, in hours."""
    jd = unix / 86400.0 + 2440587.5
    d = jd - 2451545.0
    g = 18.697374558 + 24.06570982441908 * d
    return g % 24.0


def lst(c, ctx):
    lon = longitude(ctx)
    g = gmst_hours(ctx.now.unix)
    local_lst = g if lon == None else (g + lon / 15.0) % 24.0

    h = int(local_lst)
    m = int((local_lst - h) * 60)
    s = int((((local_lst - h) * 60) - m) * 60)

    c.fill("#050810")
    title = "SIDEREAL" if lon != None else "GREENWICH ST"
    c.text(title, c.width // 2, 2, font = "4x5", color = "#7C8CC8",
           align = "center")
    # 7x12 is excluded: it carries no ':' glyph, which silently turned
    # "06:57:22" into "065722".
    clock = fmt.pad(h) + ":" + fmt.pad(m) + ":" + fmt.pad(s)
    if c.width >= 128:
        c.text("UTC " + fmt.pad(ctx.now.hour) + ":" + fmt.pad(ctx.now.minute),
               c.width - 6, 13, font = "6x8", color = "#4E5A80", align = "right")
        c.text_fit(clock, 8, 9, ["16x20", "10x16"], color = "#AEC6FF",
                   maxw = c.width - 74)
    else:
        c.text_fit(clock, c.width // 2, 10, ["10x16", "6x8", "5x7"],
                   color = "#AEC6FF", align = "center", maxw = c.width - 4)
