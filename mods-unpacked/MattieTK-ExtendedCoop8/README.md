# Extended Coop - 8 players local + remote

(Workshop title; internal mod id: `MattieTK-ExtendedCoop8`)

Extends Brotato's local coop from 4 to 8 players, with the coop UI split into
a 2×4 grid (shop, level-ups, end-of-run screen), 8 join slots on the character
select screen, and 8 HUD positions in-game (4 corners + 4 edge midpoints).
Works with Steam Remote Play Together.

Built for **Brotato v1.1.15.4** (ModLoader 6.3.0). Clean-room rebuild inspired
by Memoh's discontinued "Extended Coop" mod, fixing its main issues: true
8-visible-at-once UI instead of paged sets of 4, extended controller bindings
for 8 gamepads, working run resume with >4 players, and shared (not forked)
progression saves.

## Installing

The Steam build of Brotato only loads mods from the Steam Workshop folder
(`steamapps/workshop/content/1942280/<item_id>/*.zip`). Until this mod is
published to the Workshop, drop `MattieTK-ExtendedCoop8.zip` into any workshop
item folder you are subscribed to. (The GOG/Epic builds load zips from the
`mods` folder next to Brotato.exe.)

To publish properly: use the `GodotWorkshopUtility.exe` that ships with the
game to upload the zip as your own (optionally hidden) workshop item, then
subscribe to it.

**Important:** unsubscribe from the original "Extended Coop" workshop mod
(id 3629226509) — the two mods extend the same scripts and conflict.

## Playing with 8 players

1. Start → character selection → toggle **Coop**.
2. Everyone holds their Accept button (A on pad / Enter on keyboard) to join —
   up to 8 players (players 5-8 appear in the compact grid on the right).
3. Everyone picks a character (and weapon, where applicable); the run starts
   after all players locked in and player 1 confirms difficulty.
4. Shop and level-up screens show all 8 players in a 2×4 grid.

## Controllers, and Steam Remote Play Together

- Supported inputs: up to 8 gamepads, or 7 gamepads + 1 keyboard player.
- **Remote Play Together:** invite friends via the Steam overlay; their
  controllers show up as local controllers, no extra setup. This works over
  the internet with no extra tooling.
- **Windows/XInput caveat (out of the mod's control):** Xbox-type (XInput)
  controllers are limited to 4 by Windows. Controllers 5-8 must enumerate via
  DirectInput — PlayStation (DualShock/DualSense), Switch Pro and most generic
  pads do. A practical 8-player mix: keyboard + up to 4 Xbox pads + PlayStation
  or generic pads for the rest. If a 5th+ controller isn't detected, try
  disabling Steam Input for Brotato (game Properties → Controller → Disable
  Steam Input), since Steam Input re-exposes everything as XInput.

## Saves

- Progression (unlocks, stats) uses your normal save, shared with vanilla.
- Runs with more than 4 players are saved to `run_coop8_v3_<profile>.json`
  next to the normal run file, and the vanilla run file is parked empty. The
  unmodded game therefore never sees an 8-player run (no crashes if you play
  without the mod mid-run); resume the 8-player run by launching with the mod.

## Known limitations

- Shop / level-up panels are scaled to roughly half height with 8 players —
  a 1080p or larger display is recommended (TV + big couch, ideally).
- Difficulty selection is player 1 only (vanilla behavior).
- Console builds are untouched (mod is PC-only by design).
- The old mod's separate `ModdedSave` folder is not used; if you have one from
  the old mod, its progress stays where it was.

## Source layout

- `mod_main.gd` — entry point, installs 21 script extensions.
- `c8.gd` / `c8_fit_cell.gd` — shared helpers (array padding, focus-emulator
  cloning, scale-to-fit grid cells).
- `extensions/` — script extensions mirroring the vanilla file layout.
