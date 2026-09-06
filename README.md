# Reading Shootout

Playable builds of Reading Shootout (a first-person shooter set on Catherine Ave, Reading MA). Installed copies update themselves from the latest release here.

## PC (Windows)

1. Download **[ReadingShootout-Windows.zip](https://github.com/andyfreed/MyFPS-Releases/releases/latest/download/ReadingShootout-Windows.zip)** (about 400 MB; always the latest version).
2. Extract it anywhere under your user folder (Documents, Desktop, Downloads). Avoid `C:\Program Files`, the game needs to write to its own folder to update.
3. Run `MyFPS.exe`. Windows SmartScreen warns once because the build is unsigned: click *More info*, then *Run anyway*.

It checks for updates every time it starts and applies them automatically.

**"The following component(s) are required: Microsoft Visual C++ Runtime"**: the launcher found the runtime missing. Builds from v0.1.2 on carry the installer and offer to run it. If you have an older zip, install it from Microsoft directly: https://aka.ms/vs/17/release/vc_redist.x64.exe, then start the game again.

## Steam Deck

Open Desktop Mode, open Konsole, paste this and press Enter:

```bash
curl -fsSL https://raw.githubusercontent.com/andyfreed/MyFPS-Releases/main/steamdeck-install.sh | bash
```

That downloads the game to `~/Games/MyFPS`, adds **Reading Shootout** to your Steam library (Non-Steam tab) set to run with Proton, and restarts Steam. Go back to Gaming Mode and launch it. Re-running the command is safe and repairs the install.

## Controls

| Action | Keyboard / mouse | Controller |
|---|---|---|
| Move / look | WASD / mouse | Left stick / right stick |
| Fire | Left click | RT |
| Aim (hold) | Right click | LT |
| Sprint (hold) | Left Shift | L3 |
| Reload | R | X |
| Jump | Space | A |
| Switch weapon | Mouse wheel | Y |
| Ability 1 / 2 | Q / E | LB / RB |
| Pause menu | Esc | Start |

Every binding can be changed in the pause menu under **Controls**. At the start of each match, draft two abilities from the shared pool: first come, first served.
