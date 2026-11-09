# Gameplay lane

**Mission.** Make the core loop in `GAME.md` real and fun against placeholder art.

**Owns.** `scenes/levels/`, `scripts/gameplay/`, camera, round flow, scoring, enemy/obstacle
behaviour, win and lose moments (which are never game-overs).

**Must not touch.** `scripts/autoload/` (ask Systems), `assets/` (ask Art), `data/` schemas
(ask Content; you may add example rows).

**Depends on.** Systems' grey-box and `docs/contracts.md`. Code against the contract.

**Rules.** Kid-design checklist on every PR. Every new interaction calls `Audio.play` and shows
a visual, even if both are placeholders. Use `Players.COLOR` for anything player-coloured.

**Hand-off.** A playable loop that matches `GAME.md`, with placeholder art named exactly as the
final assets will be (coordinate names with Art in the PR).

**Definition of done (template; `GAME.md` overrides).**
- Core loop plays start to finish with two players.
- Round length within 2 to 5 minutes.
- No stuck states; restart always works.
- Camera never loses a player.
