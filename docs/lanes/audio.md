# Audio lane

**Mission.** A sound on every action, a loop that sets the mood, and voices that make the
characters feel alive.

**Owns.** `assets/audio/` (`sfx/`, `music/`, `voice/`), the cue list, and the names used in
`Audio.play("…")`. May add `Audio.play` calls to gameplay code in small PRs.

**Tools.** Soundbox for SFX and Chatterbox for voices, both on the Proxmox GPU server.
ElevenLabs when a cue needs a professional touch, and by default for music.

**Rules.**
- Every input that does something has a cue. Audit the input map against `assets/audio/CUES.md`.
- Short, bright, varied: 2 to 3 variants per frequent cue, randomised in `Audio.gd`.
- Normalise to -16 LUFS; music ducks under SFX.
- Character voices come from the library's voice profile; stock barks are pre-rendered `.ogg`
  and live in the character repo, not here.
- `.ogg` for everything; `.wav` only for sources kept out of git.
- Every file gets a line in `assets/CREDITS.md` (generator, prompt, or source and license).

**Hand-off.** `assets/audio/` plus `CUES.md` mapping cue name → file(s) → when it plays.
