#!/usr/bin/env bash
# Dev launcher: jre64 java.exe with argument parity to ProjectZomboid64.json
# (including -agentlib:zbNative, which the shipped .bat omits and whose absence
# breaks the window), plus the SAO agent and -debug.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PZ="/c/Program Files (x86)/Steam/steamapps/common/ProjectZomboid"
AGENT_W="$(cygpath -w "$ROOT/java/dist/SAOAgent.jar")"

cd "$PZ"
exec ./jre64/bin/java.exe \
  "-javaagent:$AGENT_W=sao" \
  -agentlib:zbNative \
  -Djava.awt.headless=true \
  --enable-native-access=ALL-UNNAMED \
  --add-exports=java.base/jdk.internal.misc=ALL-UNNAMED \
  -Xmx3072m \
  -Dzomboid.steam=1 \
  -Dzomboid.znetlog=1 \
  "-Djava.library.path=win64/;." \
  -XX:-CreateCoredumpOnCrash \
  -XX:-OmitStackTraceInFastThrow \
  -XX:+UseZGC \
  -cp "./;projectzomboid.jar" \
  zombie.gameStates.MainScreenState -debug
