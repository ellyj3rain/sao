#!/usr/bin/env bash
# Deploy the mod (Lua + jar) to the game. Refuses while the game is running:
# the jar is locked in-process and a partial deploy corrupts the install.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DST="$HOME/Zomboid/mods/SurvivorAwareness"
if powershell.exe -NoProfile -Command "if (Get-Process ProjectZomboid64,java -EA SilentlyContinue | Where-Object { \$_.Path -like '*ProjectZomboid*' }) { exit 0 } else { exit 1 }" 2>/dev/null; then
  echo "REFUSED: the game is running (jar is locked). Close it first."
  exit 1
fi
rm -rf "$DST"
cp -r "$ROOT/mod" "$DST"
cp "$ROOT/java/dist/SAOAgent.jar" "$DST/42.20/media/java/SAO.jar"

# [B30] The licence travels with the mod. GPL-3.0 requires the
# text to accompany the distributed work, and only `mod/` is
# distributed - a LICENSE in the source repository reaches
# nobody who installs this. Copied rather than duplicated in
# the tree so there is one canonical file to keep true.
for doc in LICENSE CREDITS.md; do
    if [ -f "$ROOT/$doc" ]; then
        cp "$ROOT/$doc" "$DST/$doc"
    else
        echo "[deploy] WARNING: $doc missing - the mod would ship without it"
    fi
done
python "$ROOT/tools/approve.py"
echo "deployed to $DST"
find "$DST" -type f | sed "s|$DST|  .|"
