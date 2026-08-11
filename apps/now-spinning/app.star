# Now Spinning
#
# Last.fm is the music service this platform can actually read:
# a static API key on a plain GET. Spotify's own API needs an
# OAuth refresh, which is a POST and therefore impossible here.
#
# The record's label colour is hashed from the track name, so every
# song gets its own sleeve and successive tracks look different.



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


LABELS = ["#E8443C", "#4EA8FF", "#4EE38A", "#F5D64E", "#B46BE8", "#FF8A3A"]


def track(c, ctx):
    key = str(ctx.inputs.get("apikey", "")).strip()
    user = str(ctx.inputs.get("user", "")).strip()
    demo = is_demo(ctx)

    if demo:
        name = "THE LESS I KNOW THE BETTER"
        artist = "TAME IMPALA"
        live = True
    else:
        if key == "" or user == "":
            nodata(c, "NOT CONFIGURED", "SET KEY+USER")
            return
        r = http.get("https://ws.audioscrobbler.com/2.0/",
                     params = {"method": "user.getrecenttracks", "user": user,
                               "api_key": key, "format": "json", "limit": "1"},
                     ttl_seconds = 60)
        if r["status_code"] != 200 or not r["json"]:
            nodata(c, "NO SCROBBLES", "NO CONNECTION")
            return
        rt = r["json"].get("recenttracks", {})
        items = rt.get("track", [])
        if len(items) == 0:
            nodata(c, "NO SCROBBLES", "NOTHING PLAYED")
            return
        t0 = items[0]
        name = str(t0.get("name", "")).upper()
        artist = str(t0.get("artist", {}).get("#text", "")).upper()
        attr = t0.get("@attr", {})
        live = attr.get("nowplaying", "false") == "true"

    h = 0
    for i in range(len(name)):
        h += i + 1
    col = LABELS[h % len(LABELS)]

    c.gradient_rect(0, 0, c.width - 1, c.height - 1, "#08070C", "#1C1826",
                    horizontal = False)
    vs = 22 if c.width >= 128 else 15
    c.image("VINYL.png", 2, (c.height - vs) // 2, w = vs, h = vs)
    # tint the label so each track gets its own sleeve
    cx = 2 + vs // 2
    cy = (c.height - vs) // 2 + vs // 2
    c.fill_circle(cx, cy, 2 if vs > 16 else 1, col)

    x0 = vs + 6
    if c.width >= 128:
        c.text("NOW SPINNING" if live else "LAST PLAYED", x0, 1, font = "4x5",
               color = "#6E6A88")
        c.text(fitwords(c, name, "10x16", c.width - x0 - 4), x0, 7,
               font = "10x16", color = "#F0ECF8")
        c.text(fitwords(c, artist, "5x7", c.width - x0 - 4), x0, 24,
               font = "5x7", color = col)
    else:
        # Two lines for the title and one for the artist: the old layout
        # gave a whole row to the word PLAYING and left the title as "THE".
        block(c, name, x0, 2, c.width - x0 - 2, 15, ["5x7", "4x5"],
              "#F0ECF8", 1)
        c.text(fitwords(c, artist, "4x5", c.width - x0 - 2), x0, 21,
               font = "4x5", color = col)
    if demo:
        demo_badge(c)
