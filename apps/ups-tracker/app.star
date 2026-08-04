# UPS Tracker - the current delivery milestone for one UPS package.
#
# WHY NOT UPS'S OWN API: it authenticates with OAuth client credentials, which
# means POSTing to mint a bearer token that then expires in a few hours. GDN
# apps may only `http.get`, so a UPS-direct panel is impossible here -- and a
# hand-pasted token would go dead by dinnertime. This reads Ship24 instead,
# which resells UPS scans behind a static API key over a plain GET.
#
# ONE-TIME SETUP, done once per package, from your own machine:
#
#   curl -X POST https://api.ship24.com/public/v1/trackers \
#     -H "Authorization: Bearer $SHIP24_KEY" -H "Content-Type: application/json" \
#     -d '{"trackingNumber":"1Z999AA10123456784","courierCode":["ups"]}'
#
# That POST is what creates the Tracker. This app only READS it, via
# GET /public/v1/trackers/search/{trackingNumber}/results, so a number that has
# never been registered draws the NO TRACKER screen rather than a status.
#
# LAYOUT (128x32). Right-edge items are measured from c.width.
#
#   header  y=0..7    UPS gold bar: UPS left, package name / last-4 right
#   status  y=10      the milestone, largest font that fits
#   line    y=23      last scan location left, ETA right
#   rail    y=29..30  four milestone segments, filled to where the parcel is

UPS_GOLD = "#FFB500"
UPS_BROWN = "#3A2317"
RAIL_BG = "#2A1B10"

GRAY = "#9AA6B2"
BLUE = "#4FC3F7"
GREEN = "#3ED87B"
RED = "#FF5A5A"
PURPLE = "#C792EA"

MONTHS = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN",
          "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]

# Ship24's eight statusMilestone values -> (how far along out of 4, label, color).
# Labels are kept short enough to survive a 128px panel; `step` drives the rail.
MILESTONES = {
    "pending": (0, "PENDING", GRAY),
    "info_received": (1, "LABEL CREATED", GRAY),
    "in_transit": (2, "IN TRANSIT", BLUE),
    "out_for_delivery": (3, "OUT FOR DELIVERY", UPS_GOLD),
    "available_for_pickup": (3, "READY FOR PICKUP", PURPLE),
    "failed_attempt": (2, "DELIVERY MISSED", RED),
    "exception": (2, "EXCEPTION", RED),
    "delivered": (4, "DELIVERED", GREEN),
}

STATUS_FONTS = ["7x12", "6x8", "5x7", "4x5"]

# ---------- input ----------

def _s(ctx, key, fallback):
    # An unset input can come back as None, so coerce before using it.
    v = ctx.inputs.get(key, fallback)
    if v == None:
        return fallback
    return str(v).strip()

# ---------- text ----------

DIGITS = "0123456789"

def _clip(c, s, font, maxw):
    """Longest prefix of `s` that fits in maxw pixels."""
    if c.text_width(s, font) <= maxw:
        return s
    out = ""
    for i in range(len(s)):
        nxt = out + s[i]
        if c.text_width(nxt, font) > maxw:
            return out.strip()
        out = nxt
    return out.strip()

def _all_digits(p):
    for i in range(len(p)):
        if not p[i] in DIGITS:
            return False
    return True

def _place(c, raw, font, maxw):
    """'SAN RAFAEL, CA 94901' -> 'SAN RAFAEL CA'. Drop the postcode: on a 128px
    panel the town and state are what tell you anything.

    A long city name is cut short, but the state code is reserved first and
    always survives -- 'SAINT PETERSBURG BEACH FL' becomes 'SAINT PETERS FL'
    rather than losing the FL off the end. Cutting mid-word is deliberate:
    dropping whole words instead would render that same city as 'SAINT FL',
    which reads as a place that doesn't exist."""
    words = []
    for p in raw.replace(",", " ").split(" "):
        # A postcode is the only all-digit chunk a courier puts in a location.
        if p and not _all_digits(p):
            words.append(p.upper())
    if not words:
        return ""

    # A trailing 2-letter token is the state; reserve its width up front so the
    # city gets whatever is left rather than the state falling off the end.
    tail = ""
    if len(words) > 1 and len(words[len(words) - 1]) == 2:
        tail = " " + words[len(words) - 1]
        words = words[:len(words) - 1]

    city = " ".join(words)
    if c.text_width(city + tail, font) <= maxw:
        return city + tail
    return _clip(c, city, font, maxw - c.text_width(tail, font)) + tail

def _md(stamp):
    """'2026-08-06T18:00:00' -> 'AUG 6'. Returns '' for anything unexpected."""
    if not stamp or len(stamp) < 10:
        return ""
    mo = int(stamp[5:7])
    if mo < 1 or mo > 12:
        return ""
    return MONTHS[mo - 1] + " " + str(int(stamp[8:10]))

# ---------- the lookup ----------
# Returns {"ok": True, ...} or {"ok": False, "title":..., "sub":...}

def fetch(ctx):
    key = _s(ctx, "apikey", "")
    tn = _s(ctx, "tracking", "").replace(" ", "").upper()

    if not key:
        return {"ok": False, "title": "NO API KEY", "sub": "ADD ONE IN SETTINGS"}
    if not tn:
        return {"ok": False, "title": "NO TRACKING #", "sub": "ADD ONE IN SETTINGS"}

    r = http.get(
        "https://api.ship24.com/public/v1/trackers/search/" + tn + "/results",
        headers = {"Authorization": "Bearer " + key},
        # Just under the manifest's refresh, so each render is one API call.
        ttl_seconds = 840,
    )

    # ALWAYS check status_code before touching the json.
    status = r["status_code"]
    if status == 0:
        return {"ok": False, "title": "NO SIGNAL", "sub": "PANEL IS OFFLINE", "tn": tn}
    if status == 401 or status == 403:
        return {"ok": False, "title": "BAD API KEY", "sub": "CHECK IT IN SETTINGS", "tn": tn}
    if status == 404:
        return {"ok": False, "title": "NO TRACKER", "sub": "CREATE IT IN SHIP24", "tn": tn}
    if status != 200:
        return {"ok": False, "title": "API ERROR", "sub": "CODE " + str(status), "tn": tn}

    j = r["json"]
    if not j:
        return {"ok": False, "title": "NO DATA", "sub": "EMPTY RESPONSE", "tn": tn}

    data = j.get("data", {})
    if not data:
        data = {}
    trackings = data.get("trackings", [])
    if not trackings:
        # The number is fine, but nobody ever POSTed a Tracker for it.
        return {"ok": False, "title": "NO TRACKER", "sub": "CREATE IT IN SHIP24", "tn": tn}

    t = trackings[0]
    shipment = t.get("shipment", {})
    if not shipment:
        shipment = {}
    delivery = shipment.get("delivery", {})
    if not delivery:
        delivery = {}

    # Events come back newest-first, but `order` is the field that actually says
    # so, so prefer it and fall back to position.
    events = t.get("events", [])
    if not events:
        events = []
    last = events[0] if events else {}
    best = None
    for e in events:
        o = e.get("order", None)
        if o != None and (best == None or o > best):
            best = o
            last = e

    return {
        "ok": True,
        "tn": tn,
        "milestone": str(shipment.get("statusMilestone", "") or ""),
        "where": str(last.get("location", "") or ""),
        "what": str(last.get("status", "") or ""),
        "when": str(last.get("occurrenceDatetime", "") or ""),
        "eta": str(delivery.get("estimatedDeliveryDate", "") or ""),
    }

# ---------- drawing ----------

def _header(c, ctx, tn):
    c.rect(0, 0, c.width - 1, 7, fill = UPS_GOLD)
    c.text("UPS", 2, 1, font = "5x7b", color = UPS_BROWN)

    # Which package this is: the name you gave it, else the last 4 digits.
    name = _s(ctx, "label", "").upper()
    if not name and len(tn) >= 4:
        name = "..." + tn[len(tn) - 4:]
    if name:
        c.text(_clip(c, name, "4x5", c.width - 26), c.width - 2, 2,
               font = "4x5", color = UPS_BROWN, align = "right")

def _rail(c, step, color):
    """Four segments: label created, in transit, out for delivery, delivered."""
    c.rect(0, 29, c.width - 1, 30, fill = RAIL_BG)
    seg = c.width // 4
    if step > 0:
        c.rect(0, 29, seg * step - 2, 30, fill = color)
    for i in range(1, 4):
        c.rect(i * seg - 1, 29, i * seg, 30, fill = "black")

def _err(c, ctx, d):
    _header(c, ctx, d.get("tn", ""))
    c.text(d["title"], 2, 11, font = "6x8", color = UPS_GOLD)
    c.text(d["sub"], 2, 22, font = "4x5", color = GRAY)

def main(c, ctx):
    c.fill("black")

    d = fetch(ctx)
    if not d["ok"]:
        _err(c, ctx, d)
        return

    step, label, color = MILESTONES.get(d["milestone"], (0, "TRACKING", GRAY))

    _header(c, ctx, d["tn"])

    # The one thing you read from across the room.
    c.text_fit(label, 2, 10, STATUS_FONTS, color = color, maxw = c.width - 4)

    # Where it was last seen, and when it should land.
    eta = _md(d["eta"])
    eta_s = ""
    if step == 4:
        # Already delivered -- the useful date is when, not when-expected.
        got = _md(d["when"])
        eta_s = got if got else ""
    elif eta:
        eta_s = "ETA " + eta

    eta_w = c.text_width(eta_s, "4x5") if eta_s else 0
    if eta_s:
        c.text(eta_s, c.width - 2, 23, font = "4x5",
               color = GREEN if step == 4 else UPS_GOLD, align = "right")

    # Where it was last scanned. Before the first physical scan a courier sends
    # no location at all, so fall back to what the scan actually said.
    # The 14px keeps a clear gutter between this and the ETA on its right.
    room = c.width - 14 - eta_w
    where = _place(c, d["where"], "4x5", room)
    if not where:
        where = _clip(c, d["what"].upper(), "4x5", room)
    if where:
        c.text(where, 2, 23, font = "4x5", color = GRAY)

    _rail(c, step, color)
