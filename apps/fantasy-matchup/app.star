# Fantasy Matchup
#
# Sleeper's public API needs no authentication at all, which makes
# it the only major US fantasy platform readable here: ESPN and
# Yahoo both require cookies or OAuth.
#
# Five cached GETs — state, user, rosters, users, matchups — well
# inside the eight-request budget.
#
# The tug bar is the whole design: the notch sits where the score
# ratio puts it, so who is winning reads instantly.



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


def matchup(c, ctx):
    league = str(ctx.inputs.get("league", "")).strip()
    user = str(ctx.inputs.get("user", "")).strip()
    demo = is_demo(ctx) or league == "DEMO"

    if demo:
        me = ["YOU", 87.4]
        opp = ["RIVAL", 71.2]
    else:
        if league == "" or user == "":
            nodata(c, "NOT CONFIGURED", "SET LEAGUE+USER")
            return
        st = http.get("https://api.sleeper.app/v1/state/nfl", ttl_seconds = 1800)
        if st["status_code"] != 200 or not st["json"]:
            nodata(c, "NO SLEEPER", "NO CONNECTION")
            return
        week = int(st["json"].get("week", 1) or 1)

        u = http.get("https://api.sleeper.app/v1/user/" + user, ttl_seconds = 86400)
        if u["status_code"] != 200 or not u["json"]:
            nodata(c, "NO SUCH USER", "CHECK USERNAME")
            return
        uid = str(u["json"].get("user_id", ""))

        ros = http.get("https://api.sleeper.app/v1/league/" + league + "/rosters",
                       ttl_seconds = 3600)
        mus = http.get("https://api.sleeper.app/v1/league/" + league
                       + "/matchups/" + str(week), ttl_seconds = 300)
        usr = http.get("https://api.sleeper.app/v1/league/" + league + "/users",
                       ttl_seconds = 86400)
        if ros["status_code"] != 200 or mus["status_code"] != 200 or \
           not ros["json"] or not mus["json"]:
            nodata(c, "NO MATCHUP", "CHECK LEAGUE ID")
            return

        myroster = None
        owner = {}
        for rr in ros["json"]:
            owner[str(rr.get("roster_id", ""))] = str(rr.get("owner_id", ""))
            if str(rr.get("owner_id", "")) == uid:
                myroster = str(rr.get("roster_id", ""))
        if myroster == None:
            nodata(c, "NOT IN LEAGUE", "CHECK USERNAME")
            return

        names = {}
        if usr["status_code"] == 200 and usr["json"]:
            for uu in usr["json"]:
                names[str(uu.get("user_id", ""))] = str(
                    uu.get("display_name", "")).upper()

        mine = None
        for m in mus["json"]:
            if str(m.get("roster_id", "")) == myroster:
                mine = m
        if mine == None:
            nodata(c, "NO MATCHUP", "BYE WEEK?")
            return

        opponent = None
        for m in mus["json"]:
            if m.get("matchup_id", None) == mine.get("matchup_id", None) and \
               str(m.get("roster_id", "")) != myroster:
                opponent = m

        me = [names.get(uid, "YOU")[:9], float(mine.get("points", 0) or 0)]
        if opponent == None:
            opp = ["BYE", 0.0]
        else:
            oid = owner.get(str(opponent.get("roster_id", "")), "")
            opp = [names.get(oid, "RIVAL")[:9],
                   float(opponent.get("points", 0) or 0)]

    lead = me[1] >= opp[1]
    c.gradient_rect(0, 0, c.width - 1, c.height - 1, "#080C14", "#182338",
                    horizontal = False)

    # The bar owns the bottom rows and nothing else may enter them.
    total = me[1] + opp[1]
    frac = 0.5 if total <= 0 else me[1] / total
    bx0 = 2
    bw = c.width - 4
    by = c.height - 8
    c.rect(bx0, by, bx0 + bw - 1, by + 5, fill = "#1E2A3E")
    fill = int(bw * frac)
    if fill > 0:
        c.rect(bx0, by, bx0 + fill - 1, by + 5, fill = "#4EE38A")
    if fill < bw:
        c.rect(bx0 + fill, by, bx0 + bw - 1, by + 5, fill = "#FF5B5B")

    ms = str(int(me[1] * 10) / 10.0)
    os_ = str(int(opp[1] * 10) / 10.0)
    bs = 12 if c.width >= 128 else 8
    bxx = bx0 + fill - bs // 2
    if bxx < 0:
        bxx = 0
    if bxx > c.width - bs:
        bxx = c.width - bs
    c.image("FOOTBALL.png", bxx, by - bs + 3, w = bs, h = bs)

    if c.width >= 128:
        c.text(clip(c, me[0], "5x7", 58), 4, 1, font = "5x7", color = "#9FB4D8")
        c.text_fit(ms, 4, 8, ["16x20", "10x16"],
                   color = "#4EE38A" if lead else "#C8D4EC", maxw = 62)
        c.text(clip(c, opp[0], "5x7", 58), c.width - 4, 1, font = "5x7",
               color = "#9FB4D8", align = "right")
        c.text_fit(os_, c.width - 4, 8, ["16x20", "10x16"],
                   color = "#C8D4EC" if lead else "#FF7A5B",
                   align = "right", maxw = 62)
    else:
        # A gap in the middle: the two scores previously fused into one
        # unreadable run of digits.
        c.text_fit(ms, 2, 3, ["10x16", "6x8", "5x7"],
                   color = "#4EE38A" if lead else "#C8D4EC",
                   maxw = c.width // 2 - 5)
        c.text_fit(os_, c.width - 2, 3, ["10x16", "6x8", "5x7"],
                   color = "#C8D4EC" if lead else "#FF7A5B",
                   align = "right", maxw = c.width // 2 - 5)
        c.rect(c.width // 2 - 1, 4, c.width // 2, 14, fill = "#3A4358")
    if demo:
        demo_badge(c)
