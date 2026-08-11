# Trakt
#
# Trakt's /users/me/watching returns 204 with no body when nothing is
# playing, which is a perfectly good answer and gets its own screen
# rather than being treated as an error.
#
# Auth here is the client id of an application you create, sent as
# trakt-api-key — no OAuth dance, which matters because this platform
# can only make GET requests.



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


TRAKT_SAMPLE = {"status_code": 200, "json": {
    "type": "episode", "show": {"title": "The Expanse"},
    "episode": {"season": 4, "number": 6}}}

PLAY = [
    "#........",
    "###......",
    "#####....",
    "#######..",
    "#####....",
    "###......",
    "#........",
]


def now(c, ctx):
    cid = str(ctx.inputs.get("apikey", "")).strip()
    user = str(ctx.inputs.get("user", "")).strip()
    if cid == "" or user == "":
        nodata(c, "NOT CONFIGURED", "SET ID+USER")
        return

    r = TRAKT_SAMPLE if is_demo(ctx) else http.get(
        "https://api.trakt.tv/users/" + user + "/watching",
        headers = {"trakt-api-key": cid, "trakt-api-version": "2",
                   "Content-Type": "application/json"}, ttl_seconds = 60)

    if r["status_code"] == 204 or (r["status_code"] == 200 and not r["json"]):
        c.fill("#0A0A10")
        c.sprite(PLAY, (c.width - 9) // 2, 6, color = "#2E3444")
        c.text("NOTHING PLAYING", c.width // 2, 20,
               font = "6x8" if c.width >= 128 else "4x5", color = "#5A6078",
               align = "center")
        return
    if r["status_code"] == 401 or r["status_code"] == 403:
        nodata(c, "BAD CLIENT ID", "BAD CLIENT ID")
        return
    if r["status_code"] != 200 or not r["json"]:
        nodata(c, "NO TRAKT DATA", "NO CONNECTION")
        return

    j = r["json"]
    kind = str(j.get("type", "")).upper()
    if kind == "EPISODE":
        show = str(j.get("show", {}).get("title", "")).upper()
        ep = j.get("episode", {})
        sub = "S" + str(ep.get("season", 0)) + "E" + str(ep.get("number", 0))
        title = show
    else:
        title = str(j.get("movie", {}).get("title", "")).upper()
        sub = "MOVIE"

    c.fill("#0A0A10")
    c.rect(0, 0, c.width - 1, 6, fill = "#ED1C24")
    c.text(sub, 3, 1, font = "4x5", color = "#160406")
    if c.width >= 128:
        c.text("TRAKT", c.width - 3, 1, font = "4x5", color = "#160406",
               align = "right")
    block(c, title, 3, 9, c.width - 6, 21, ["10x16", "6x8", "5x7", "4x5"],
          "#F0E4E4", 1)
    if is_demo(ctx):
        demo_badge(c)
