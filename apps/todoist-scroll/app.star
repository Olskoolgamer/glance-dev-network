# Todoist
#
# Todoist REST v2 with a personal API token (Settings -> Integrations
# -> Developer). The filter asks for today plus anything overdue,
# because a task list that hides what you already missed is worse
# than no list at all.



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


TODOIST_SAMPLE = {"status_code": 200, "json": [
    {"content": "Renew the panel firmware certificate"},
    {"content": "Email the surf club"}, {"content": "Water the tomatoes"}]}

CHECK = [
    ".......#",
    "......##",
    "#....###",
    "##..###.",
    ".######.",
    "..####..",
    "...##...",
]


def today(c, ctx):
    token = str(ctx.inputs.get("apikey", "")).strip()
    if token == "":
        nodata(c, "NO TOKEN", "ADD TOKEN")
        return

    r = TODOIST_SAMPLE if is_demo(ctx) else http.get(
        "https://api.todoist.com/rest/v2/tasks",
        params = {"filter": "today | overdue"},
        headers = {"Authorization": "Bearer " + token},
        ttl_seconds = 300)
    if r["status_code"] == 401:
        nodata(c, "BAD TOKEN", "BAD TOKEN")
        return
    if r["status_code"] != 200 or r["json"] == None:
        nodata(c, "NO TASKS DATA", "NO CONNECTION")
        return

    tasks = r["json"]
    n = len(tasks)
    if n == 0:
        c.fill("#06110A")
        c.sprite(CHECK, (c.width - 8) // 2, 6, color = "#4EE38A")
        c.text("ALL DONE", c.width // 2, 18,
               font = "10x16" if c.width >= 128 else "6x8", color = "#4EE38A",
               align = "center")
        return

    top = str(tasks[0].get("content", "")).upper()

    c.fill("#12070A")
    c.rect(0, 0, c.width - 1, 6, fill = "#E44332")
    c.text(str(n) + (" TASKS" if n != 1 else " TASK"), 3, 1, font = "4x5",
           color = "#2A0806")
    if c.width >= 128:
        c.text("TODOIST", c.width - 3, 1, font = "4x5", color = "#2A0806",
               align = "right")
    block(c, top, 3, 9, c.width - 6, 21, ["10x16", "6x8", "5x7", "4x5"],
          "#F0E0DC", 1)
    if is_demo(ctx):
        demo_badge(c)
