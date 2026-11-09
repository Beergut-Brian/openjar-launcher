"""Constraint checks for the master palettes. Each check returns rows:
(palette_id, check_id, subject, value, threshold, ok)."""
import colormath as cm

GREEN, RED = "#3CC24A", "#E4393C"
# Fixed colours darker than any legal ink can be. They cannot reach 3:1 against a
# near-black outline, so the house rule for them is a rim-light line in the palette's
# "stone" colour, and that is what we test instead.
DARK_FIXED = {"hat_black", "shirt_black"}

SKY_STEP_MIN = 12.0
PLAYER_VS_WORLD_MIN = 25.0
DEUTAN_MIN = 20.0
INK_CONTRAST_MIN = 3.0
COMB_VS_RED_MIN = 15.0


def by_key(p):
    return {k: (name, hx, grp, role) for k, name, hx, grp, role in p["colours"]}


def sky(p):
    return [(k, hx) for k, _, hx, grp, _ in p["colours"] if grp == "sky"]


def run(p):
    pid = p["id"]
    c = by_key(p)
    rows = []
    n = len(p["colours"])
    rows.append((pid, "count", "colours in palette", n, "16-20", 16 <= n <= 20))

    # 1. Sky ramp
    s = sky(p)
    rows.append((pid, "sky.tiers", "sky colours", len(s), ">=5", len(s) >= 5))
    for (k1, h1), (k2, h2) in zip(s, s[1:]):
        d = cm.de(h1, h2)
        rows.append((pid, "sky.step", f"{k1}->{k2} dE00", round(d, 1), f">={SKY_STEP_MIN:g}", d >= SKY_STEP_MIN))
    Ls = [cm.lab(h)[0] for _, h in s]
    mono = all(a > b for a, b in zip(Ls, Ls[1:]))
    rows.append((pid, "sky.order", "L* falls every tier (ground to space)",
                 " > ".join(f"{L:.0f}" for L in Ls), "strictly falling", mono))

    # 2. Players vs world, and vs each other for deuteranopes
    world = [(k, c[k][1]) for k in p["rings"]] + s
    for pk, ph in (("p1_green", GREEN), ("p2_red", RED)):
        worst = min(((cm.de(ph, h), k) for k, h in world))
        rows.append((pid, "player.world", f"{pk} vs nearest ring/sky ({worst[1]}) dE00",
                     round(worst[0], 1), f">={PLAYER_VS_WORLD_MIN:g}", worst[0] >= PLAYER_VS_WORLD_MIN))
    d = cm.de(cm.deutan(GREEN), cm.deutan(RED))
    rows.append((pid, "player.deutan", "green vs red, Machado deuteranopia dE00",
                 round(d, 1), f">={DEUTAN_MIN:g}", d >= DEUTAN_MIN))

    # 3. Ink contrast
    ink = c["ink"][1]
    rim = c["stone"][1]
    for k, (name, hx, grp, _) in c.items():
        if k == "ink":
            continue
        if k in DARK_FIXED:
            r = cm.contrast(hx, rim)
            rows.append((pid, "ink.rim", f"{k} vs rim (stone) WCAG", round(r, 2),
                         f">={INK_CONTRAST_MIN:g}", r >= INK_CONTRAST_MIN))
            continue
        r = cm.contrast(hx, ink)
        rows.append((pid, "ink.contrast", f"{k} vs ink WCAG", round(r, 2),
                     f">={INK_CONTRAST_MIN:g}", r >= INK_CONTRAST_MIN))

    # Look-sheet rule: Jeff's comb must not read as the player red.
    d = cm.de(c[p["comb"]][1], RED)
    rows.append((pid, "comb.not_red", f"comb ({p['comb']}) vs player red dE00",
                 round(d, 1), f">={COMB_VS_RED_MIN:g}", d >= COMB_VS_RED_MIN))
    return rows


def all_rows(palettes):
    out = []
    for p in palettes:
        out.extend(run(p))
    return out
