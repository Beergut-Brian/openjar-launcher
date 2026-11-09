"""The one data block. Everything in art/palettes/ is generated from this.

Each colour: (key, name, hex, group, role).
Groups: ink, neutral, sky, ground, accent, fixed.
Sky colours are listed ground-level first, outer space last.
RINGS lists the Life of a Worm soil rings, surface first, core last.
FACE / COMB / BEAK / BALL say which palette colour the mock card uses for those parts.
"""

FIXED = [
    ("p1_green", "Player Green", "#3CC24A", "fixed", "P1 accents: Jeff's wing tips, headband, stitching"),
    ("p2_red", "Player Red", "#E4393C", "fixed", "P2 accents: Chuck's hat brim, tie-dye swirl, boot stitching"),
    ("jeff_yellow", "Costume Yellow", "#FFD84D", "fixed", "Jeff's chicken costume; Chuck's hat emblem"),
    ("jeans_blue", "Jeans Blue", "#3B5BA5", "fixed", "Jeans (both characters)"),
    ("boots_brown", "Boots Brown", "#8A5A2B", "fixed", "Chuck's cowboy boots"),
    ("hat_black", "Hat Near-Black", "#2B2B33", "fixed", "Chuck's trucker hat body"),
    ("shirt_black", "Shirt Black", "#1E1E26", "fixed", "Chuck's tie-dye shirt base"),
]

PALETTES = [
    {
        "id": "candy_pop",
        "letter": "A",
        "title": "Candy Pop",
        "mood": "Bubblegum and sherbet: a sweet-shop sky, sugar-pink and mint, everything shiny and silly.",
        "colours": [
            ("ink", "Licorice", "#0F0814", "ink", "Outlines, eyes, mouths, all ink lines"),
            ("cloud", "Marshmallow", "#FFF4FA", "neutral", "Clouds, highlights, eye whites, UI cards"),
            ("stone", "Lilac Taffy", "#B7A3E6", "neutral", "UI panels, rim light on dark costume parts; Worm rock ring"),
            ("sky1", "Mint Horizon", "#B9FBF0", "sky", "Sky tier 1: ground level"),
            ("sky2", "Sherbet Blue", "#76DDFF", "sky", "Sky tier 2: high sky"),
            ("sky3", "Cotton Cloud", "#8FA8FF", "sky", "Sky tier 3: cloud deck"),
            ("sky4", "Grape Fizz", "#A57BF4", "sky", "Sky tier 4: stratosphere"),
            ("sky5", "Berry Space", "#C044B0", "sky", "Sky tier 5: outer space"),
            ("grass", "Mint Leaf", "#62E8B8", "ground", "Grass, leaves, pitch"),
            ("topsoil", "Rocky Road", "#A08498", "ground", "Dirt; Worm ring 1 (topsoil)"),
            ("clay", "Caramel", "#F0B06A", "ground", "Paths, sand, skin placeholder; Worm ring 2 (clay)"),
            ("magma", "Butterscotch", "#FFA94A", "accent", "Sparkles, stars, Jeff's beak; Worm core"),
            ("comb", "Bubblegum", "#FF66C4", "accent", "Jeff's comb, hearts, pops, confetti"),
        ],
        "rings": ["topsoil", "clay", "stone", "magma"],
        "face": "clay", "comb": "comb", "beak": "magma",
    },
    {
        "id": "warm_toybox",
        "letter": "B",
        "title": "Warm Toybox",
        "mood": "Painted wooden toys on a sunny rug: butter, marigold, raspberry and teal sky, cosy and chunky.",
        "colours": [
            ("ink", "Burnt Walnut", "#100906", "ink", "Outlines, eyes, mouths, all ink lines"),
            ("cloud", "Cream", "#FFF3DA", "neutral", "Clouds, highlights, eye whites, UI cards"),
            ("stone", "Putty", "#C4B194", "neutral", "UI panels, rim light on dark costume parts; Worm rock ring"),
            ("sky1", "Butter Horizon", "#FFE6A8", "sky", "Sky tier 1: ground level"),
            ("sky2", "Toy Teal Sky", "#8ADCD2", "sky", "Sky tier 2: high sky"),
            ("sky3", "Sailor Blue", "#4FB0E0", "sky", "Sky tier 3: cloud deck"),
            ("sky4", "Paint-Tin Blue", "#4C7BDA", "sky", "Sky tier 4: stratosphere"),
            ("sky5", "Plum Space", "#7C5CC4", "sky", "Sky tier 5: outer space"),
            ("grass", "Felt Green", "#9CCB3B", "ground", "Grass, leaves, pitch"),
            ("topsoil", "Oak", "#BC8A44", "ground", "Dirt, wooden blocks; Worm ring 1 (topsoil)"),
            ("clay", "Biscuit", "#E9A86E", "ground", "Paths, sand, skin placeholder; Worm ring 2 (clay)"),
            ("magma", "Marigold", "#FFA020", "accent", "Sparkles, stars, Jeff's beak; Worm core"),
            ("comb", "Raspberry", "#D9428A", "accent", "Jeff's comb, hearts, pops, confetti"),
        ],
        "rings": ["topsoil", "clay", "stone", "magma"],
        "face": "clay", "comb": "comb", "beak": "magma",
    },
    {
        "id": "cool_arcade",
        "letter": "C",
        "title": "Cool Arcade",
        "mood": "A glowing arcade cabinet: ice cyan to electric violet, teal turf, neon pink and orange pops.",
        "colours": [
            ("ink", "Midnight Ink", "#0A0A14", "ink", "Outlines, eyes, mouths, all ink lines"),
            ("cloud", "Ice", "#EEF8FF", "neutral", "Clouds, highlights, eye whites, UI cards"),
            ("stone", "Slate", "#8E9CC0", "neutral", "UI panels, rim light on dark costume parts; Worm rock ring"),
            ("sky1", "Aqua Glow", "#86F6FF", "sky", "Sky tier 1: ground level"),
            ("sky2", "Cyan Beam", "#38C6FF", "sky", "Sky tier 2: high sky"),
            ("sky3", "Laser Blue", "#3D8BFF", "sky", "Sky tier 3: cloud deck"),
            ("sky4", "Ultraviolet", "#7A6CFF", "sky", "Sky tier 4: stratosphere"),
            ("sky5", "Electric Indigo", "#6628FF", "sky", "Sky tier 5: outer space"),
            ("grass", "Teal Turf", "#1CC9A6", "ground", "Grass, pitch"),
            ("topsoil", "Plum Dirt", "#9C5E9E", "ground", "Dirt; Worm ring 1 (topsoil)"),
            ("clay", "Peach Glow", "#FFBFA0", "ground", "Paths, skin placeholder; Worm ring 2 (clay)"),
            ("magma", "Neon Orange", "#FF9F2E", "accent", "Sparkles, stars, Jeff's beak; Worm core"),
            ("comb", "Neon Pink", "#FF4FD8", "accent", "Jeff's comb, pops, confetti"),
        ],
        "rings": ["topsoil", "clay", "stone", "magma"],
        "face": "clay", "comb": "comb", "beak": "magma",
    },
]

for _p in PALETTES:
    _p["colours"] = _p["colours"] + FIXED
