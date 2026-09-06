# MyFPS builds

Playable builds of MyFPS. Installed copies update themselves from the latest release here.

## PC (Windows)

1. Download the `MyFPS-Windows-vX.Y.Z.zip` from the [first release](https://github.com/andyfreed/MyFPS-Releases/releases/tag/v0.1.0) (later releases only carry changed files).
2. Extract it anywhere under your user folder (Documents, Desktop, Downloads). Avoid `C:\Program Files`, the game needs to write to its own folder to update.
3. Run `MyFPS.exe`. Windows SmartScreen warns once because the build is unsigned: click *More info*, then *Run anyway*.

It checks for updates every time it starts and applies them automatically.

## Steam Deck

Open Desktop Mode, open Konsole, paste this and press Enter:

```bash
curl -fsSL https://raw.githubusercontent.com/andyfreed/MyFPS-Releases/main/steamdeck-install.sh | bash
```

That downloads the game to `~/Games/MyFPS`, adds **MyFPS** to your Steam library (Non-Steam tab) set to run with Proton, and restarts Steam. Go back to Gaming Mode and launch it. Re-running the command is safe and repairs the install.

## Controls

Move with WASD or the left stick, aim with the mouse or right stick, fire with left click or RT. At the start of each match, draft two abilities from the shared pool: first come, first served. Use them with **Q** / **E** on keyboard or **LB** / **RB** on a gamepad.
