# GitHub Repo
#
# The public REST API, unauthenticated. The contribution graph needs
# an authenticated GraphQL call, so this shows the numbers that are
# actually reachable without asking anyone for a token.



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


def short(n):
    if n >= 1000000:
        return str(int(n / 100000) / 10.0) + "M"
    if n >= 1000:
        return str(int(n / 100) / 10.0) + "K"
    return str(n)


def stats(c, ctx):
    repo = str(ctx.inputs.get("repo", "")).strip()
    if repo == "" or repo.find("/") < 0:
        nodata(c, "NO REPO", "SET OWNER/NAME")
        return

    r = http.get("https://api.github.com/repos/" + repo, ttl_seconds = 1800)
    if r["status_code"] == 404:
        nodata(c, "NOT FOUND", repo.upper())
        return
    if r["status_code"] != 200 or not r["json"]:
        nodata(c, "NO REPO DATA", "GITHUB UNREACHABLE")
        return
    j = r["json"]

    name = str(j.get("name", "")).upper()
    stars = int(j.get("stargazers_count", 0) or 0)
    forks = int(j.get("forks_count", 0) or 0)
    issues = int(j.get("open_issues_count", 0) or 0)

    c.fill("#08090E")
    if c.width >= 128:
        # Reserve the forks/issues column first, then fit the name to what is
        # left — long repository names ran straight into it.
        c.text_fit(name, 6, 2, ["6x8", "5x7", "4x5"], color = "#C8CCE0",
                   maxw = c.width - 96)
        c.text(short(stars), 6, 12, font = "16x20", color = "#F5C242")
        c.text("STARS", 6 + c.text_width(short(stars), "16x20") + 4, 24,
               font = "4x5", color = "#7A6A48")
        c.text("FORKS " + short(forks), c.width - 6, 6, font = "6x8",
               color = "#8FD4FF", align = "right")
        c.text("ISSUES " + short(issues), c.width - 6, 18, font = "6x8",
               color = "#FF9A5B", align = "right")
    else:
        # Clipped, not shrunk to 3x4: that font has no hyphen, which turned
        # GLANCE-DEV-NETWORK into GLANCEDEVNETWORK.
        c.text(clip(c, name, "4x5", c.width - 2), c.width // 2, 0,
               font = "4x5", color = "#C8CCE0", align = "center")
        c.text_fit(short(stars), c.width // 2, 6, ["16x20", "10x16", "6x8"],
                   color = "#F5C242", align = "center", maxw = c.width - 4)
        c.text(short(forks) + "F  " + short(issues) + "I", c.width // 2, 27,
               font = "4x5", color = "#7A8098", align = "center")
