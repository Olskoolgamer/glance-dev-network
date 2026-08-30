# New Orleans Saints live scoreboard for the GLANCE LED.
# Data source: ESPN's public NFL JSON endpoints.

SCOREBOARD_URL = "https://site.api.espn.com/apis/site/v2/sports/football/nfl/scoreboard"
SUMMARY_URL = "https://site.api.espn.com/apis/site/v2/sports/football/nfl/summary"
INJURY_URL = "https://site.api.espn.com/apis/site/v2/sports/football/nfl/teams/18/injuries"
SAINTS_ID = "18"


def pad2(n):
    s = str(n)
    if len(s) == 1:
        return "0" + s
    return s


def days_from_civil(y, m, d):
    yy = y - 1 if m <= 2 else y
    era = (yy if yy >= 0 else yy - 399) // 400
    yoe = yy - era * 400
    mm = m + (-3 if m > 2 else 9)
    doy = (153 * mm + 2) // 5 + d - 1
    doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
    return era * 146097 + doe - 719468


def civil_from_days(z):
    z = z + 719468
    era = (z if z >= 0 else z - 146096) // 146097
    doe = z - era * 146097
    yoe = (doe - doe // 1460 + doe // 36524 - doe // 146096) // 365
    y = yoe + era * 400
    doy = doe - (365 * yoe + yoe // 4 - yoe // 100)
    mp = (5 * doy + 2) // 153
    d = doy - (153 * mp + 2) // 5 + 1
    m = mp + (3 if mp < 10 else -9)
    y = y + (1 if m <= 2 else 0)
    return [y, m, d]


def date8(y, m, d):
    return str(y) + pad2(m) + pad2(d)


def recent_range(ctx):
    today = days_from_civil(ctx.now.year, ctx.now.month, ctx.now.day)
    prior = civil_from_days(today - 31)
    return date8(prior[0], prior[1], prior[2]) + "-" + date8(ctx.now.year, ctx.now.month, ctx.now.day)


def fetch_json(url, params, ttl):
    r = http.get(url, params=params, ttl_seconds=ttl)
    if r["status_code"] != 200:
        return {}
    return r["json"]


def team_is_saints(team):
    return str(team.get("id", "")) == SAINTS_ID or team.get("abbreviation", "") == "NO"


def saints_competition(event):
    comps = event.get("competitions", [])
    if len(comps) == 0:
        return {}
    comp = comps[0]
    for item in comp.get("competitors", []):
        if team_is_saints(item.get("team", {})):
            return comp
    return {}


def event_record(event):
    comp = saints_competition(event)
    if len(comp) == 0:
        return {}
    saints = {}
    opponent = {}
    for item in comp.get("competitors", []):
        if team_is_saints(item.get("team", {})):
            saints = item
        else:
            opponent = item
    if len(saints) == 0 or len(opponent) == 0:
        return {}
    status = comp.get("status", {}).get("type", {})
    return {
        "id": str(event.get("id", "")),
        "date": event.get("date", ""),
        "short_date": event.get("date", "")[5:10],
        "opponent": opponent.get("team", {}).get("abbreviation", "OPP"),
        "saints_score": str(saints.get("score", "0")),
        "opponent_score": str(opponent.get("score", "0")),
        "state": status.get("state", "post"),
        "detail": status.get("shortDetail", status.get("detail", "Final")),
        "home_away": saints.get("homeAway", "away"),
    }


def load_games(ctx):
    data = fetch_json(SCOREBOARD_URL, {"dates": recent_range(ctx), "limit": 1000}, 60)
    games = []
    for event in data.get("events", []):
        row = event_record(event)
        if len(row) > 0:
            games.append(row)
    return games


def choose_current(games):
    live = {}
    latest = {}
    for game in games:
        if game.get("state", "") == "in":
            live = game
        if len(latest) == 0 or game.get("date", "") > latest.get("date", ""):
            latest = game
    if len(live) > 0:
        return live
    return latest


def load_summary(game):
    if len(game) == 0 or game.get("id", "") == "":
        return {}
    return fetch_json(SUMMARY_URL, {"event": game["id"]}, 60)


def all_plays(summary):
    plays = []
    drives = summary.get("drives", {})
    current = drives.get("current", {})
    if len(current) > 0:
        for play in current.get("plays", []):
            plays.append(play)
    for drive in drives.get("previous", []):
        for play in drive.get("plays", []):
            plays.append(play)
    for play in summary.get("plays", []):
        plays.append(play)
    return plays


def play_has_saints(play, side):
    if str(play.get("team", {}).get("id", "")) == SAINTS_ID:
        return side == "offense"
    for participant in play.get("teamParticipants", []):
        if str(participant.get("id", "")) == SAINTS_ID:
            if participant.get("type", "") == side:
                return True
    text = play.get("text", "")
    if side == "defense" and ("NO-" in text or "Saints" in text):
        return True
    return False


def lower(s):
    return str(s).lower()


def event_kind(play):
    text = lower(play.get("text", ""))
    type_text = lower(play.get("type", {}).get("text", ""))
    scoring = lower(play.get("scoringType", {}).get("name", ""))
    combined = text + " " + type_text + " " + scoring

    if play.get("isPenalty", False):
        return ""
    if ("safety" in combined) and play_has_saints(play, "defense"):
        return "SAFETY"
    if ("interception" in combined or "pass intercepted" in combined) and play_has_saints(play, "defense"):
        return "INTERCEPTION"
    if ("fumble recovery" in combined or "fumbles" in combined and "recovered by" in combined) and play_has_saints(play, "defense"):
        return "FUMBLE RECOVERY"
    if ("sack" in combined) and play_has_saints(play, "defense"):
        return "SACK"
    if ("touchdown" in combined or scoring == "touchdown") and play_has_saints(play, "offense"):
        return "TOUCHDOWN"
    if ("field goal" in combined or scoring == "field-goal") and play_has_saints(play, "offense"):
        return "FIELD GOAL"

    start_down = play.get("start", {}).get("down", 0)
    end_down = play.get("end", {}).get("down", 0)
    if end_down == 1 and start_down in [2, 3, 4] and play_has_saints(play, "offense"):
        return "FIRST DOWN"
    return ""


def play_name(play):
    participants = play.get("participants", [])
    for participant in participants:
        athlete = participant.get("athlete", {})
        if len(athlete) > 0 and participant.get("type", "") in ["scorer", "rusher", "passer", "receiver", "sacker", "interceptor", "fumble-recoverer"]:
            return athlete.get("displayName", athlete.get("fullName", athlete.get("shortName", "SAINTS")))
    text = play.get("text", "")
    if len(text) > 0:
        return text[:34]
    return "SAINTS"


def latest_saints_event(summary):
    plays = all_plays(summary)
    latest = {}
    for play in plays:
        kind = event_kind(play)
        if kind != "":
            latest = {"kind": kind, "name": play_name(play), "text": play.get("text", "")}
    return latest


def team_stat(summary, label):
    for team in summary.get("boxscore", {}).get("teams", []):
        if team_is_saints(team.get("team", {})):
            for stat in team.get("statistics", []):
                if stat.get("name", "") == label:
                    return stat.get("displayValue", "-")
    return "-"


def player_groups(summary):
    result = []
    for team in summary.get("boxscore", {}).get("players", []):
        if not team_is_saints(team.get("team", {})):
            continue
        for group in team.get("statistics", []):
            name = group.get("name", "")
            if name in ["passing", "rushing", "receiving", "defensive", "interceptions", "kicking"]:
                result.append(group)
    return result


def leader_line(summary, group_name, index, label):
    for group in player_groups(summary):
        if group.get("name", "") != group_name:
            continue
        athletes = group.get("athletes", [])
        if len(athletes) == 0:
            return "NO " + label
        row = athletes[index if index < len(athletes) else 0]
        athlete = row.get("athlete", {})
        stats = row.get("stats", [])
        name = athlete.get("displayName", athlete.get("fullName", athlete.get("shortName", "SAINTS")))
        if group_name == "passing":
            value = stats[0] + " " + stats[1] + "Y"
        elif group_name == "rushing":
            value = stats[0] + "C " + stats[1] + "Y"
        elif group_name == "receiving":
            value = stats[0] + "R " + stats[1] + "Y"
        elif group_name == "defensive":
            value = stats[0] + "T " + stats[2] + "S"
        elif group_name == "interceptions":
            value = stats[0] + " INT"
        else:
            value = stats[0] + " FG"
        return name + " " + value
    return "NO " + label


def draw_field(c):
    # Photo background imported as field_background.png.
    c.image("field_background.png", 0, 0, w=c.width, h=c.height)

    # Dark translucent-style strips are approximated with a solid dark border
    # so the live data remains readable over the photograph.
    c.rect(0, 0, c.width - 1, c.height - 1, outline="black")

def team_text(c, value, x, y, font="7x12", color="yellow"):
    # Stroke keeps text readable over the real field photograph.
    c.text_stroke(
        value,
        x,
        y,
        font=font,
        color=color,
        stroke="black",
        thickness=1,
    )


def draw_pulse(c, kind, name, frame):
    colors = {
        "TOUCHDOWN": "yellow",
        "SACK": "red",
        "INTERCEPTION": "cyan",
        "FUMBLE RECOVERY": "amber",
        "FIELD GOAL": "green",
        "SAFETY": "red",
        "FIRST DOWN": "white",
    }

    color = colors.get(kind, "green")

    if frame % 2 == 0:
        c.rect(0, 0, c.width - 1, c.height - 1, outline=color)
        c.rect(2, 2, c.width - 3, c.height - 3, outline=color)

    c.text_center(kind, 2, font="7x12", color=color)
    c.text_center(name.upper()[:44], 18, font="5x7", color="white")


def live(c, ctx):
    draw_field(c)
    games = load_games(ctx)
    game = choose_current(games)
    summary = load_summary(game)
    status = "LIVE" if game.get("state", "") == "in" else "FINAL"
    team_text(c, "NO", 4, 2, font="7x12", color="yellow")
    c.text(str(game.get("saints_score", "-")), 25, 2, font="7x12", color="white")
    team_text(c, game.get("opponent", "-")[:4], 78, 2, font="7x12", color="white")
    c.text(str(game.get("opponent_score", "-")), 103, 2, font="7x12", color="white")
    c.text(status, 145, 4, font="5x7", color="green" if status == "LIVE" else "gray")
    c.text(game.get("detail", "NO GAME")[:32].upper(), 4, 17, font="5x7", color="white")
    event = latest_saints_event(summary)
    if game.get("state", "") == "in" and len(event) > 0:
        draw_pulse(c, event["kind"], event["name"], ctx.now.second)


def scores(c, ctx):
    draw_field(c)

    # Match the Saints injuries page style.
    team_text(c, "LAST 31 DAYS", 4, 1, font="6x8", color="yellow")

    games = load_games(ctx)

    if len(games) == 0:
        c.text(
            "NO SCORES",
            4,
            14,
            font="6x8",
            color="white",
        )
        return

    y = 9
    shown = 0

    for game in games:
        if shown >= 3:
            break

        saints_score = int(game.get("saints_score", "0"))
        opponent_score = int(game.get("opponent_score", "0"))
        result = "W" if saints_score > opponent_score else "L"

        line = (
            game.get("short_date", "")
            + " "
            + result
            + " NO "
            + str(saints_score)
            + "-"
            + str(opponent_score)
            + " "
            + game.get("opponent", "")
        )

        c.text(
            line[:62].upper(),
            4,
            y,
            font="5x7",
            color="green" if result == "W" else "red",
        )

        y = y + 7
        shown = shown + 1

def full_player_name(athlete):
    return athlete.get("displayName", athlete.get("fullName", athlete.get("shortName", "SAINTS")))


def player_photo(athlete):
    return athlete.get("headshot", athlete.get("photo", athlete.get("image", "")))


def stat_player_rows(summary):
    rows = []
    for team in summary.get("boxscore", {}).get("players", []):
        if not team_is_saints(team.get("team", {})):
            continue
        for group in team.get("statistics", []):
            group_name = group.get("name", "")
            if group_name not in ["passing", "rushing", "receiving", "defensive", "interceptions", "kicking"]:
                continue
            for item in group.get("athletes", []):
                athlete = item.get("athlete", {})
                if len(athlete) == 0:
                    continue
                rows.append({
                    "name": full_player_name(athlete),
                            "group": group_name,
                    "stats": item.get("stats", []),
                })
    return rows


def rotating_player(rows, ctx):
    if len(rows) == 0:
        return {}
    return rows[ctx.now.minute % len(rows)]


def player_stat_line(player):
    stats = player.get("stats", [])
    group_name = player.get("group", "")
    if len(stats) == 0:
        return "NO STAT DATA"
    if group_name == "passing" and len(stats) >= 3:
        return stats[0] + " CMP " + stats[1] + " YDS " + stats[2] + " TD"
    if group_name == "rushing" and len(stats) >= 2:
        return stats[0] + " CAR " + stats[1] + " YDS"
    if group_name == "receiving" and len(stats) >= 2:
        return stats[0] + " REC " + stats[1] + " YDS"
    if group_name == "defensive" and len(stats) >= 3:
        return stats[0] + " TCK " + stats[2] + " SCK"
    if group_name == "interceptions":
        return stats[0] + " INT"
    if group_name == "kicking":
        return stats[0] + " FG"
    return stats[0]


def draw_player_card(c, player, color):
    team_text(
        c,
        player.get("name", "SAINTS").upper(),
        4,
        10,
        font="5x7",
        color=color,
    )

    team_text(
        c,
        player_stat_line(player).upper()[:60],
        4,
        21,
        font="5x7",
        color="white",
    )

def stats(c, ctx):
    draw_field(c)
    games = load_games(ctx)
    game = choose_current(games)
    summary = load_summary(game)
    rows = stat_player_rows(summary)

    team_text(c, "LATEST GAME", 4, 1, font="6x8", color="yellow")

    if len(rows) == 0:
        team_text(c, "NO PLAYER DATA", 4, 14, font="5x7", color="white")
        return

    player = rotating_player(rows, ctx)
    team_text(
        c,
        player.get("name", "SAINTS").upper()[:60],
        4,
        11,
        font="5x7",
        color="cyan",
    )
    team_text(
        c,
        player_stat_line(player).upper()[:60],
        4,
        21,
        font="5x7",
        color="white",
    )


def injuries(c, ctx):
    draw_field(c)
    team_text(c, "SAINTS INJURIES", 4, 1, font="6x8", color="yellow")
    data = fetch_json(INJURY_URL, {}, 300)
    rows = data.get("injuries", [])
    if len(rows) == 0:
        rows = data.get("athletes", [])

    players = []
    for row in rows:
        athlete = row.get("athlete", row.get("player", {}))
        status = row.get("status", row.get("type", {}).get("abbreviation", "?"))
        detail = row.get("details", {}).get("type", "")
        text = str(status)
        if detail != "":
            text = text + " " + detail
        players.append({
            "name": full_player_name(athlete),
            "group": "injury",
            "stats": [text],
        })

    if len(players) == 0:
        team_text(c, "NO REPORT", 4, 14, font="6x8", color="white")
        return

    player = rotating_player(players, ctx)
    status_text = player_stat_line(player).upper()
    color = "red" if "OUT" in status_text or "IR" in status_text else "yellow"
    draw_player_card(c, player, color)

