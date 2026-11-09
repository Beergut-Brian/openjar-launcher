# Audio cues

Every file here is synthesised by `assets/audio/tools/make_cues.py` (run it to regenerate; see
the script header). Loudness: SFX -16 LUFS (short cues measured while sounding; `ui_move` -20,
`pause` -18 because they repeat), music -20 LUFS, everything at or below -1 dBTP.
`tests/test_audio_cues.gd` checks that every cue and track below resolves to a loadable file.

## SFX: `Audio.play("<cue>")`, files in `assets/audio/sfx/`

| Cue name (`Audio.play`) | Files | Plays when | Sounds like |
| --- | --- | --- | --- |
| ui_move | sfx/ui_move_1.ogg, sfx/ui_move_2.ogg, sfx/ui_move_3.ogg | menu cursor moves (launcher: card row, profile picker; also at the row ends) | soft wooden tick, three pitches (F5 G5 A5), 90 ms |
| ui_confirm | sfx/ui_confirm.ogg | menu select (launcher: profile confirmed, intro skipped) | xylophone G5 → C6 "yes!" + tiny sparkle, 250 ms |
| ui_back | sfx/ui_back.ogg | launcher: B, Start (quit), "can't do that" (empty row, launch failed) | round sliding "boop" D5 → G4, 200 ms |
| ui_toggle | sfx/ui_toggle.ogg | launcher: LB + RB held 1 s, dev builds shown/hidden | toy-switch clunk then one bell ding, 250 ms |
| intro_pop | sfx/intro_pop.ogg | launcher: the jar lid pops off (launch sequence) | cork POP + fizz, crackle and soda bubbles, 1.2 s |
| intro_thump | sfx/intro_thump.ogg | launcher intro: logo lands | cartoon landing THUMP with a wobbly boing tail, 1.3 s |
| launch | sfx/launch.ogg | launcher: the camera dives into the jar, game starting | whoosh + slide whistle up, then marimba/kazoo ta-DA, 1.15 s |
| player_join | sfx/player_join.ogg | P2 drops in | two rising toy blips, "here I am!", 230 ms |
| round_start | sfx/round_start.ogg | Game.start_round | marimba G-C-E "ready, set", xylophone + kazoo "go!", 0.9 s |
| round_end | sfx/round_end.ogg | Game.end_round | kazoo + marimba ta-DA with sparkle, 0.95 s |
| jar_rattle | sfx/jar_rattle.ogg | launcher: A at a jar, the lid rattles before it pops (hub lane placeholder) | tin ticks speeding up and rising, 0.55 s |
| jarling_jump | sfx/jarling_jump.ogg | launcher: the Jarling leaps at the jar (hub lane placeholder) | slide-whistle "hup!" E4 → E6 with a breath of air, 0.4 s |
| lid_land | sfx/lid_land.ogg | launcher: the flown-off lid lands (on the other Jarling's head) (hub lane placeholder) | tin "tonk" that wobbles like a spun coin, 0.6 s |
| jar_splash | sfx/jar_splash.ogg | launcher: the Jarling lands inside the jar (hub lane placeholder) | plop + rising glockenspiel run and sparkles, 0.9 s |
| jar_pop_out | sfx/jar_pop_out.ogg | launcher: back from a game, the Jarling pops out of the jar (hub lane placeholder) | pop then "boi-oing", 0.5 s |
| lid_bonk | sfx/lid_bonk.ogg | launcher: the lid drops back on the jar (hub lane placeholder) | round tin BONK with a short boing, 0.7 s |
| pause | sfx/pause.ogg | pause / resume | soft muted marimba plink, 140 ms |

## Music: `Audio.music("<track>")`, files in `assets/audio/music/`

| Track name (`Audio.music`) | Files | Plays when | Sounds like |
| --- | --- | --- | --- |
| card_row_loop | music/card_row_loop.ogg | launcher: under the card row (and picker); stops when a game launches | 105 BPM C major, marimba tune + off-beat stabs, soft plucked bass, light shaker; 8 bars = 18.286 s, seamless loop (`Audio.music` sets `loop = true`) |
