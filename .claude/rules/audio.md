---
paths:
  - "scripts/audio/**"
  - "resources/audio/**"
---

# Audio

- A sound is a `SoundCue` in `resources/audio/sound_bank.tres`; gameplay already emits the signals, `AudioDirector` (autoload) maps them to cues. Console `sound <cue>` auditions one.
- **Positional audio is van-local.** Enemies and projectiles live under `VanRig`, so a 3D sound left at a world position pans to the rear within a second. `AudioDirector.play_at()` reparents the pooled player into the emitter's space.
- Don't parent an `AudioStreamPlayer3D` to an enemy or a pooled projectile: both die (or recycle) before the tail finishes.
- Don't call `play()` from `gun_controller`; emit `shot` and let the autoload map it to a cue.
- The `Interior` bus sends to SFX and has no FX yet; that's the van-shell low-pass / short-reverb slot.
- Import SFX as `.wav` (no decode latency) and music as `.ogg` with the loop flag.
- Volumes live on `MetaProgression` (Master caps Music and SFX).
