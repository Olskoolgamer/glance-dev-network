# Crypto Prices
#
# CoinGecko's public price endpoint, no key required. Green and red
# are carried by an explicit arrow as well as the colour, so the
# direction still reads for anyone who cannot separate the two.



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


TICKER = {"bitcoin": "BTC", "ethereum": "ETH", "solana": "SOL",
          "dogecoin": "DOGE", "cardano": "ADA", "ripple": "XRP",
          "litecoin": "LTC", "polkadot": "DOT", "chainlink": "LINK",
          "monero": "XMR", "avalanche-2": "AVAX", "tron": "TRX"}


def money(v):
    if v >= 1000:
        return "$" + fmt.commas(int(v))
    if v >= 1:
        return "$" + str(int(v * 100) / 100.0)
    return "$" + str(int(v * 10000) / 10000.0)


def prices(c, ctx):
    raw = str(ctx.inputs.get("coins", "bitcoin,ethereum,solana"))
    ids = []
    for part in raw.split(","):
        p = part.strip().lower()
        if p != "" and len(ids) < 4:
            ids.append(p)
    if len(ids) == 0:
        nodata(c, "NO COINS", "ADD SOME IN SETTINGS")
        return

    r = http.get("https://api.coingecko.com/api/v3/simple/price",
                 params = {"ids": ",".join(ids), "vs_currencies": "usd",
                           "include_24hr_change": "true"},
                 ttl_seconds = 600)
    if r["status_code"] != 200 or not r["json"]:
        nodata(c, "NO PRICES", "COINGECKO UNREACHABLE")
        return
    j = r["json"]

    c.fill("#06070C")
    rows = len(ids)
    h = c.height // rows if rows > 0 else c.height
    for i in range(rows):
        cid = ids[i]
        d = j.get(cid, None)
        y = i * h + (h - 7) // 2
        name = TICKER.get(cid, cid[:4].upper())
        if d == None:
            c.text(name, 2, y, font = "5x7", color = "#4A4E60")
            c.text("N/A", c.width - 2, y, font = "5x7", color = "#4A4E60",
                   align = "right")
            continue
        price = float(d.get("usd", 0) or 0)
        chg = float(d.get("usd_24h_change", 0) or 0)
        up = chg >= 0
        col = "#4EE38A" if up else "#FF5B5B"
        c.text(name, 2, y, font = "5x7", color = "#C8CCE0")
        if c.width >= 128:
            c.text(money(price), 52, y, font = "5x7", color = "#FFFFFF")
            c.text(("+" if up else "-") + str(int(abs(chg) * 10) / 10.0) + "%",
                   c.width - 4, y, font = "5x7", color = col, align = "right")
        else:
            c.text(money(price), c.width - 2, y, font = "4x5", color = "#FFFFFF",
                   align = "right")
