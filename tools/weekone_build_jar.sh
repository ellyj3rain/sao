#!/usr/bin/env bash
# Scoped source build: keep all destructive output inside this SAO worktree.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$root"
for relative in java/out java/dist mod/42.20/media/java; do
    resolved="$(realpath -m "$relative")"
    if [ "$resolved" != "$root/$relative" ]; then
        echo "refused output path: $relative -> $resolved" >&2
        exit 9
    fi
done

receipt="$root/_scratch/d2-leisure-01/weekone21"
mkdir -p "$receipt"
bash "$root/tools/build-java.sh" > "$receipt/build-java.log" 2>&1
dist="$root/java/dist/SAOAgent.jar"
shipped="$root/mod/42.20/media/java/SAO.jar"
cmp "$dist" "$shipped"
sha256sum "$dist" "$shipped" > "$receipt/build-java-sha256.txt"
tail -n 12 "$receipt/build-java.log"
cat "$receipt/build-java-sha256.txt"
