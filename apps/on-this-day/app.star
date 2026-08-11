# On This Day
#
# Wikipedia's 'selected' feed for today — the curated handful rather
# than the full events list, which runs to half a megabyte and would
# crowd the response cap for no gain.



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


FONTH = {"16x20": 20, "10x16": 16, "6x8": 8, "5x7": 7, "4x5": 5}


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
            cur = w
    if cur != "":
        lines.append(cur)
    return lines


def block(c, text, x, y, maxw, maxh, fonts, color, gap):
    """Draw text at the largest font whose wrapped lines fit maxh."""
    words = str(text).upper().split(" ")
    for f in fonts:
        lines = wrap(c, words, f, maxw)
        if len(lines) * (FONTH[f] + gap) - gap <= maxh:
            for i in range(len(lines)):
                c.text(lines[i], x, y + i * (FONTH[f] + gap), font = f,
                       color = color)
            return len(lines)
    # Nothing fits: use the smallest face, draw what we can, and mark the
    # cut so a dropped tail reads as deliberate rather than as a bug.
    f = fonts[len(fonts) - 1]
    lines = wrap(c, words, f, maxw)
    n = maxh // (FONTH[f] + gap)
    if n > len(lines):
        n = len(lines)
    for i in range(n):
        line = lines[i]
        if i == n - 1 and n < len(lines):
            # `while` is a reserved keyword in Starlark even though the
            # language has no while loop, so this walks back with a for.
            for k in range(len(line), 0, -1):
                if c.text_width(line[:k] + "..", f) <= maxw:
                    line = line[:k]
                    break
            line = line + ".."
        c.text(line, x, y + i * (FONTH[f] + gap), font = f, color = color)
    return n


def events(ctx):
    url = "https://api.wikimedia.org/feed/v1/wikipedia/en/onthisday/selected/" \
        + str(ctx.now.month) + "/" + str(ctx.now.day)
    # Wikimedia rejects requests with no User-Agent outright (403), and the
    # host client sends none by default.
    r = http.get(url, ttl_seconds = 21600,
                 headers = {"User-Agent": "glance-dev-network (glance-led.com)"})
    if r["status_code"] != 200 or not r["json"]:
        return None
    return r["json"].get("selected", [])


def draw(c, ctx, n):
    ev = events(ctx)
    if ev == None:
        nodata(c, "NO HISTORY", "WIKIPEDIA UNREACHABLE")
        return
    if len(ev) <= n:
        nodata(c, "NO ENTRY", "NOTHING LISTED")
        return

    e = ev[n]
    year = str(e.get("year", ""))
    text = str(e.get("text", "")).upper()

    c.fill("#080A10")
    if c.width >= 128:
        # A four-digit year at 16x20 is 68px wide, so the prose starts at 80.
        c.text(year, 6, 6, font = "16x20", color = "#F5C242")
        block(c, text, 80, 2, c.width - 86, 29, ["6x8", "5x7", "4x5"],
              "#D8DCE8", 1)
    else:
        c.text(year, 2, 0, font = "6x8", color = "#F5C242")
        block(c, text, 2, 10, c.width - 4, 21, ["5x7", "4x5"], "#D8DCE8", 1)


def first(c, ctx):
    draw(c, ctx, 0)


def second(c, ctx):
    draw(c, ctx, 1)


def third(c, ctx):
    draw(c, ctx, 2)
