#!/usr/bin/env bash
# MyFPS - Steam Deck installer
#
# Run once from Desktop Mode (Konsole):
#   curl -fsSL https://raw.githubusercontent.com/andyfreed/MyFPS-Releases/main/steamdeck-install.sh | bash
#
# What it does:
#   1. Downloads the latest build from GitHub Releases into ~/Games/MyFPS (only changed files on re-runs).
#   2. Adds "MyFPS" to your Steam library as a non-Steam game, set to run with Proton.
#   3. Restarts Steam. Switch back to Gaming Mode and launch it like any other game.
#
# Re-running the script is safe: it re-checks every file and repairs or updates the install.
# The game also updates itself on launch, so normally you never need to run this again.

set -euo pipefail

REPO="${MYFPS_REPO:-andyfreed/MyFPS-Releases}"
APP_NAME="${MYFPS_APP_NAME:-MyFPS}"
INSTALL_DIR="${MYFPS_INSTALL_DIR:-$HOME/Games/MyFPS}"
PROTON="${MYFPS_PROTON:-proton_experimental}"
MANIFEST_URL="https://github.com/$REPO/releases/latest/download/manifest.json"

say()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m%s\033[0m\n' "$*"; }
die()  { printf '\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

command -v curl    >/dev/null || die "curl is missing"
command -v python3 >/dev/null || die "python3 is missing"
command -v md5sum  >/dev/null || die "md5sum is missing"

# ---------------------------------------------------------------- 1. download
say "Fetching latest release info from $REPO"
mkdir -p "$INSTALL_DIR"
MANIFEST="$INSTALL_DIR/.manifest.json"
curl -fsSL "$MANIFEST_URL" -o "$MANIFEST" || die "Could not download $MANIFEST_URL"

VERSION=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$MANIFEST")
say "Installing $APP_NAME $VERSION into $INSTALL_DIR"

# path|size|md5|url per line
python3 - "$MANIFEST" <<'PY' > "$INSTALL_DIR/.files.txt"
import json, sys
m = json.load(open(sys.argv[1]))
for f in m["files"]:
    p = f["path"].replace("\\", "/")
    if p.startswith("/") or ".." in p:
        continue
    print(f'{p}|{f["size"]}|{f["md5"].lower()}|{f["url"]}')
PY

TOTAL=$(wc -l < "$INSTALL_DIR/.files.txt")
DONE=0
FETCHED=0
while IFS='|' read -r path size md5 url; do
    url=${url%[[:cntrl:]]}   # tolerate CRLF line endings
    DONE=$((DONE + 1))
    dest="$INSTALL_DIR/$path"
    if [ -f "$dest" ] && [ "$(stat -c %s "$dest")" = "$size" ] && [ "$(md5sum "$dest" | cut -c1-32)" = "$md5" ]; then
        continue
    fi
    printf '  [%2d/%2d] %s\n' "$DONE" "$TOTAL" "$path"
    mkdir -p "$(dirname "$dest")"
    curl -fL --retry 3 --progress-bar "$url" -o "$dest.part"
    got=$(md5sum "$dest.part" | cut -c1-32)
    [ "$got" = "$md5" ] || die "Checksum mismatch for $path (expected $md5, got $got)"
    mv -f "$dest.part" "$dest"
    FETCHED=$((FETCHED + 1))
done < "$INSTALL_DIR/.files.txt"
echo "  $FETCHED file(s) downloaded, $((TOTAL - FETCHED)) already up to date."

# Remove binaries that are no longer part of the game (an old executable next to the new one would be
# launched by a stale Steam shortcut and crash against the updated content).
BIN_DIR="$INSTALL_DIR/$APP_NAME/Binaries/Win64"
if [ -d "$BIN_DIR" ]; then
    for f in "$BIN_DIR"/*.exe "$BIN_DIR"/*.dll "$BIN_DIR"/*.pdb; do
        [ -f "$f" ] || continue
        rel="$APP_NAME/Binaries/Win64/$(basename "$f")"
        if ! grep -q "^$rel|" "$INSTALL_DIR/.files.txt"; then
            echo "  removing stale $(basename "$f")"
            rm -f "$f"
        fi
    done
fi
rm -f "$INSTALL_DIR/.files.txt"

# Point Steam at the real game executable, not the launcher at the install root: the launcher only
# checks for the Visual C++ runtime, which Proton already provides, and its check fails under Proton.
# Prefer the Shipping executable (what releases ship since v0.1.3), then the Development one.
EXE=""
for candidate in "$BIN_DIR/$APP_NAME-Win64-Shipping.exe" "$BIN_DIR/$APP_NAME.exe"; do
    if [ -f "$candidate" ]; then EXE="$candidate"; break; fi
done
[ -n "$EXE" ] || die "Could not find the game executable under $BIN_DIR"
echo "  Steam will launch: $(basename "$EXE")"

# ---------------------------------------------------------------- 2. steam shortcut
say "Adding $APP_NAME to your Steam library (Proton: $PROTON)"

STEAM_ROOT=""
for candidate in "$HOME/.local/share/Steam" "$HOME/.steam/steam" "$HOME/.steam/root"; do
    if [ -d "$candidate/userdata" ]; then STEAM_ROOT="$candidate"; break; fi
done
[ -n "$STEAM_ROOT" ] || die "Could not find the Steam folder (is Steam installed and has it been run once?)"

# most recently used Steam account on this device
USER_CFG=$(ls -td "$STEAM_ROOT"/userdata/*/config 2>/dev/null | grep -v '/userdata/0/' | head -1)
[ -n "$USER_CFG" ] || die "No Steam user found under $STEAM_ROOT/userdata (log in to Steam once first)"

if pgrep -x steam >/dev/null; then
    echo "  Closing Steam so the library file can be edited..."
    steam -shutdown >/dev/null 2>&1 || true
    for _ in $(seq 1 30); do pgrep -x steam >/dev/null || break; sleep 1; done
    pgrep -x steam >/dev/null && warn "Steam is still running; the shortcut may not stick. Close Steam fully and re-run if it is missing."
fi

python3 - "$USER_CFG/shortcuts.vdf" "$STEAM_ROOT/config/config.vdf" "$APP_NAME" "$EXE" "$INSTALL_DIR" "$PROTON" <<'PY'
import os, struct, sys, zlib, shutil, re, time

shortcuts_path, config_path, app_name, exe, start_dir, proton = sys.argv[1:7]

# ---- minimal binary VDF (Valve KeyValues) reader/writer ----
def read_vdf(data):
    pos = 0
    def read_str():
        nonlocal pos
        end = data.index(b"\x00", pos)
        s = data[pos:end].decode("utf-8", "replace")
        pos = end + 1
        return s
    def read_map():
        nonlocal pos
        out = {}
        while True:
            if pos >= len(data):
                return out  # tolerate files missing their final terminator
            t = data[pos]; pos += 1
            if t == 0x08:
                return out
            key = read_str()
            if t == 0x00:
                out[key] = read_map()
            elif t == 0x01:
                out[key] = read_str()
            elif t == 0x02:
                out[key] = struct.unpack("<i", data[pos:pos+4])[0]; pos += 4
            else:
                raise ValueError(f"unknown vdf type {t}")
    return read_map()

def write_vdf(m):
    out = bytearray()
    def w_map(d):
        for k, v in d.items():
            if isinstance(v, dict):
                out.append(0x00); out.extend(k.encode() + b"\x00"); w_map(v)
            elif isinstance(v, int):
                out.append(0x02); out.extend(k.encode() + b"\x00"); out.extend(struct.pack("<i", v))
            else:
                out.append(0x01); out.extend(k.encode() + b"\x00"); out.extend(str(v).encode() + b"\x00")
        out.append(0x08)
    w_map(m)
    return bytes(out)

data = {"shortcuts": {}}
if os.path.exists(shortcuts_path) and os.path.getsize(shortcuts_path) > 0:
    shutil.copy2(shortcuts_path, shortcuts_path + ".bak")
    with open(shortcuts_path, "rb") as f:
        data = read_vdf(f.read())
shortcuts = data.setdefault("shortcuts", {})

exe_q = f'"{exe}"'
dir_q = f'"{start_dir}/"'

# Steam's app id for a non-Steam shortcut
appid_unsigned = zlib.crc32((exe_q + app_name).encode()) | 0x80000000
appid_signed = struct.unpack("<i", struct.pack("<I", appid_unsigned))[0]

existing = None
for idx, sc in shortcuts.items():
    if isinstance(sc, dict) and (sc.get("AppName") == app_name or sc.get("appname") == app_name):
        existing = idx
        break

entry = {
    "appid": appid_signed,
    "AppName": app_name,
    "Exe": exe_q,
    "StartDir": dir_q,
    "icon": "",
    "ShortcutPath": "",
    "LaunchOptions": "",
    "IsHidden": 0,
    "AllowDesktopConfig": 1,
    "AllowOverlay": 1,
    "OpenVR": 0,
    "Devkit": 0,
    "DevkitGameID": "",
    "DevkitOverrideAppID": 0,
    "LastPlayTime": int(time.time()),
    "FlatpakAppID": "",
    "tags": {},
}
if existing is not None:
    shortcuts[existing].update(entry)
    print(f"  Updated existing library entry '{app_name}'")
else:
    next_idx = str(max([int(k) for k in shortcuts.keys() if k.isdigit()] + [-1]) + 1)
    shortcuts[next_idx] = entry
    print(f"  Added library entry '{app_name}'")

os.makedirs(os.path.dirname(shortcuts_path), exist_ok=True)
with open(shortcuts_path, "wb") as f:
    f.write(write_vdf(data))

# ---- force Proton for this app in config.vdf (text KeyValues) ----
if os.path.exists(config_path):
    shutil.copy2(config_path, config_path + ".bak")
    text = open(config_path, encoding="utf-8", errors="replace").read()
    block = (f'\t\t\t\t\t"{appid_unsigned}"\n\t\t\t\t\t{{\n'
             f'\t\t\t\t\t\t"name"\t\t"{proton}"\n'
             f'\t\t\t\t\t\t"config"\t\t""\n'
             f'\t\t\t\t\t\t"priority"\t\t"250"\n'
             f'\t\t\t\t\t}}\n')
    # drop any previous mapping for this app id
    text = re.sub(rf'\n\s*"{appid_unsigned}"\s*\{{[^{{}}]*\}}', "", text)
    m = re.search(r'"CompatToolMapping"\s*\{\s*\n', text)
    if m:
        text = text[:m.end()] + block + text[m.end():]
    else:
        m = re.search(r'"Steam"\s*\{\s*\n', text)
        if m:
            text = text[:m.end()] + '\t\t\t\t"CompatToolMapping"\n\t\t\t\t{\n' + block + '\t\t\t\t}\n' + text[m.end():]
        else:
            print("  Could not find the Steam config block; set Proton manually in the game's Properties > Compatibility.")
            text = None
    if text is not None:
        open(config_path, "w", encoding="utf-8").write(text)
        print(f"  Compatibility tool set to {proton}")
else:
    print("  config.vdf not found; set Proton manually in the game's Properties > Compatibility.")
PY

# ---------------------------------------------------------------- 3. restart steam
say "Restarting Steam"
if command -v steam >/dev/null; then
    (nohup steam >/dev/null 2>&1 &) || true
fi

cat <<EOF

Done. $APP_NAME $VERSION is installed in $INSTALL_DIR and is in your Steam library.
Switch back to Gaming Mode and launch it from the Non-Steam tab (or search for $APP_NAME).
Abilities are on the shoulder buttons; the game updates itself on launch.
EOF
