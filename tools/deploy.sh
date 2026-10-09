#!/usr/bin/env bash
# Install the current SAO package into an explicitly selected Windows profile.
# WSL's $HOME may be /root, so it cannot identify the player's mod directory.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
SCRATCH="$ROOT/_scratch"
TARGET="${SAO_DEPLOY_TARGET:-}"
APPROVAL_STORE="${SAO_APPROVAL_STORE:-}"
MODE="${1:-}"

refuse() {
    echo "[deploy] REFUSED: $*" >&2
    exit 1
}

case "$MODE" in
    ""|--dry-run) ;;
    *) refuse "usage: set SAO_DEPLOY_TARGET and SAO_APPROVAL_STORE, then run tools/deploy.sh [--dry-run]" ;;
esac
[ "$#" -le 1 ] || refuse "unexpected arguments"
[ -n "$TARGET" ] || refuse "set SAO_DEPLOY_TARGET to the exact Windows profile SAO install"
[[ "$TARGET" =~ ^/mnt/[a-z]/Users/[^/]+/Zomboid/mods/SurvivorAwareness$ ]] ||
    refuse "target must be a Windows user-profile SurvivorAwareness install"
[ -d "$TARGET" ] || refuse "installed SAO target does not exist: $TARGET"
[ "$(realpath -e -- "$TARGET")" = "$TARGET" ] ||
    refuse "target or one of its parent directories resolves through a link"

PROFILE_ROOT="${TARGET%/Zomboid/mods/SurvivorAwareness}"
MODS_DIR="$PROFILE_ROOT/Zomboid/mods"
[ -d "$MODS_DIR" ] && [ -d "$PROFILE_ROOT" ] || refuse "profile mod tree is missing"
[ "$(realpath -e -- "$MODS_DIR")" = "$MODS_DIR" ] || refuse "profile mod tree resolves through a link"
[ -d "$SCRATCH" ] && [ ! -L "$SCRATCH" ] || refuse "worktree _scratch is missing or linked"
[ "$(realpath -e -- "$SCRATCH")" = "$SCRATCH" ] || refuse "worktree _scratch resolves through a link"
[ "$(stat -c %d -- "$TARGET")" = "$(stat -c %d -- "$SCRATCH")" ] ||
    refuse "target and worktree _scratch must be on the same filesystem for rollback"

mod_id_is_sao() {
    [ -f "$1" ] && [ ! -L "$1" ] &&
        [ "$(sed -n 's/^id=//p' "$1" | tr -d '\r')" = SurvivorAwareness ]
}

mod_id_is_sao "$TARGET/mod.info" || refuse "installed root mod.info is not SurvivorAwareness"
mod_id_is_sao "$TARGET/42.20/mod.info" || refuse "installed Build 42 mod.info is not SurvivorAwareness"
mod_id_is_sao "$ROOT/mod/mod.info" || refuse "source root mod.info is not SurvivorAwareness"
mod_id_is_sao "$ROOT/mod/42.20/mod.info" || refuse "source Build 42 mod.info is not SurvivorAwareness"
[ -s "$ROOT/java/dist/SAOAgent.jar" ] || refuse "built SAOAgent.jar is missing"
[ -f "$ROOT/LICENSE" ] && [ -f "$ROOT/CREDITS.md" ] ||
    refuse "LICENSE and CREDITS.md must accompany the package"
[ -f "$TARGET/42.20/media/java/SAO.jar" ] || refuse "installed SAO.jar is missing"

[ -n "$APPROVAL_STORE" ] || refuse "set SAO_APPROVAL_STORE to the Windows profile approval file"
[ "$APPROVAL_STORE" = "$PROFILE_ROOT/.zombie_buddy/mod_approvals.json" ] ||
    refuse "approval store must belong to the selected Windows profile"
[ -f "$APPROVAL_STORE" ] && [ ! -L "$APPROVAL_STORE" ] ||
    refuse "Windows profile approval store is missing or linked"
[ "$(realpath -e -- "$APPROVAL_STORE")" = "$APPROVAL_STORE" ] ||
    refuse "approval store resolves through a link"
command -v python3 >/dev/null || refuse "python3 is required for approval"
command -v rsync >/dev/null || refuse "rsync is required for staged installation"
command -v powershell.exe >/dev/null || refuse "Windows process check is unavailable"
python3 -m json.tool "$APPROVAL_STORE" >/dev/null || refuse "approval store is not valid JSON"

game_closed() {
    local status
    # Only process metadata crosses into PowerShell. All paths and file operations
    # remain in this Bash process after Linux-side canonical checks.
    powershell.exe -NoProfile -NonInteractive -Command '
        $ErrorActionPreference = "Stop"
        try {
            $running = @(Get-CimInstance Win32_Process | Where-Object {
                $_.Name -match "^(ProjectZomboid64|ProjectZomboid|java|javaw)\.exe$" -and
                ($_.Name -like "ProjectZomboid*" -or
                 $_.CommandLine -like "*ProjectZomboid*" -or
                 $_.ExecutablePath -like "*ProjectZomboid*")
            })
            if ($running.Count -gt 0) { exit 10 }
            exit 0
        } catch { exit 20 }
    ' >/dev/null 2>&1 && return 0
    status=$?
    case "$status" in
        10) refuse "the game is running (jar is locked). Close it first." ;;
        *) refuse "Windows game-process check failed (exit $status)" ;;
    esac
}

game_closed
echo "[deploy] source: $ROOT/mod"
echo "[deploy] target: $TARGET"
echo "[deploy] built jar: $(sha256sum "$ROOT/java/dist/SAOAgent.jar" | cut -d' ' -f1)"
echo "[deploy] installed jar: $(sha256sum "$TARGET/42.20/media/java/SAO.jar" | cut -d' ' -f1)"

if [ "$MODE" = --dry-run ]; then
    echo "[deploy] dry run: checksum comparison; built jar and package documents overlay the source tree"
    rsync -anc --delete --itemize-changes \
        --filter='P /LICENSE' --filter='P /CREDITS.md' \
        -- "$ROOT/mod/" "$TARGET/" |
        awk '{
            kind = substr($0, 1, 2)
            if (kind == ">f" || kind == "<f" || kind == "cL" ||
                substr($0, 1, 9) == "*deleting") {
                content++
                if (content <= 20) print
            } else metadata++
        } END {
            printf "[deploy] content/path changes: %d (first 20 shown); metadata-only changes: %d\n", content, metadata
        }'
    echo "[deploy] dry run complete; install, approvals, default selection and saves unchanged"
    exit 0
fi

# Assemble an independent candidate in the verified worktree. The old install
# stays intact until the swap and is retained with its approval preimage.
DEPLOY_DIR="$(mktemp -d -- "$SCRATCH/deploy.XXXXXXXX")"
[ "$(realpath -e -- "$DEPLOY_DIR")" = "$DEPLOY_DIR" ] || refuse "staging path escaped worktree _scratch"
CANDIDATE="$DEPLOY_DIR/candidate"
PREVIOUS="$DEPLOY_DIR/previous"
mkdir -- "$CANDIDATE"
rsync -a -- "$ROOT/mod/" "$CANDIDATE/"
cp -- "$ROOT/java/dist/SAOAgent.jar" "$CANDIDATE/42.20/media/java/SAO.jar"
cp -- "$ROOT/LICENSE" "$ROOT/CREDITS.md" "$CANDIDATE/"
mod_id_is_sao "$CANDIDATE/mod.info" || refuse "staged root mod.info is invalid"
mod_id_is_sao "$CANDIDATE/42.20/mod.info" || refuse "staged Build 42 mod.info is invalid"
SOURCE_DIFF="$(rsync -rclni --exclude='/42.20/media/java/SAO.jar' -- "$ROOT/mod/" "$CANDIDATE/")"
[ -z "$SOURCE_DIFF" ] || refuse "staged mod tree differs from source outside the built jar"
cmp -s -- "$ROOT/java/dist/SAOAgent.jar" "$CANDIDATE/42.20/media/java/SAO.jar" ||
    refuse "staged jar differs from the built jar"
cmp -s -- "$ROOT/LICENSE" "$CANDIDATE/LICENSE" || refuse "staged LICENSE differs"
cmp -s -- "$ROOT/CREDITS.md" "$CANDIDATE/CREDITS.md" || refuse "staged CREDITS.md differs"
[ "$(realpath -e -- "$CANDIDATE")" = "$CANDIDATE" ] || refuse "candidate path escaped staging directory"
[ ! -e "$PREVIOUS" ] && [ ! -L "$PREVIOUS" ] || refuse "previous-install backup path already exists"
[ "$(realpath -m -- "$PREVIOUS")" = "$PREVIOUS" ] || refuse "backup path escaped staging directory"
cp -- "$APPROVAL_STORE" "$DEPLOY_DIR/approval-before.json"
game_closed
[ "$(realpath -e -- "$TARGET")" = "$TARGET" ] || refuse "target changed before install swap"

mv -- "$TARGET" "$PREVIOUS"
if ! mv -- "$CANDIDATE" "$TARGET"; then
    mv -- "$PREVIOUS" "$TARGET" || refuse "install swap failed and rollback also failed; previous install is $PREVIOUS"
    refuse "install swap failed; previous install restored"
fi

if ! python3 "$ROOT/tools/approve.py" --store "$APPROVAL_STORE" \
    --jar "$TARGET/42.20/media/java/SAO.jar"; then
    mv -- "$TARGET" "$CANDIDATE" || refuse "approval failed; installed candidate remains at $TARGET and previous install is $PREVIOUS"
    mv -- "$PREVIOUS" "$TARGET" || refuse "approval failed; previous install remains at $PREVIOUS"
    cp -- "$DEPLOY_DIR/approval-before.json" "$APPROVAL_STORE" ||
        refuse "approval failed; approval preimage is $DEPLOY_DIR/approval-before.json"
    refuse "approval failed; previous install and policy restored"
fi

echo "[deploy] deployed to $TARGET"
echo "[deploy] previous install and approval preimage retained at $DEPLOY_DIR"
