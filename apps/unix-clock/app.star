# Unix Epoch Clock
#
# Seconds since 1970-01-01. The milestone page counts down to the next
# repdigit or power-of-ten epoch, which is the only reason anyone
# actually watches this number.



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


def next_milestone(now):
    """The next 'interesting' epoch: a power of ten, or a round hundred-million."""
    marks = []
    p = 1000000000
    for i in range(4):
        marks.append(p)
        p = p * 10
    step = 100000000
    k = (now // step + 1) * step
    for i in range(6):
        marks.append(k)
        k += step
    best = marks[0]
    for m in marks:
        if m > now and (best <= now or m < best):
            best = m
    return best


def epoch(c, ctx):
    n = ctx.now.unix
    c.fill("#04060A")
    c.text("UNIX EPOCH", c.width // 2, 2, font = "4x5", color = "#4C7A6A",
           align = "center")
    c.text_fit(str(n), c.width // 2, 10,
               ["16x20", "10x16", "6x8", "5x7", "4x5"],
               color = "#5CF08A", align = "center", maxw = c.width - 4)


def milestone(c, ctx):
    n = ctx.now.unix
    m = next_milestone(n)
    left = m - n
    days = left // 86400
    hours = (left % 86400) // 3600

    c.fill("#04060A")
    if c.width >= 128:
        c.text("NEXT MILESTONE", 6, 2, font = "5x7", color = "#4C7A6A")
        # Reserve the right column first, then fit the figure to what is left,
        # so a ten-digit epoch can never run into the countdown.
        c.text(str(days) + "D " + str(hours) + "H", c.width - 6, 14,
               font = "6x8", color = "#C8D0E8", align = "right")
        c.text_fit(str(m), 6, 11, ["16x20", "10x16", "6x8"],
                   color = "#5CF08A", maxw = c.width - 82)
    else:
        c.text(str(m), c.width // 2, 1, font = "4x5", color = "#4C7A6A",
               align = "center")
        c.text_fit(str(days) + "D", c.width // 2, 8, ["16x20", "10x16"],
                   color = "#5CF08A", align = "center", maxw = c.width - 4)
        c.text(str(hours) + "H TO GO", c.width // 2, 26, font = "4x5",
               color = "#C8D0E8", align = "center")
