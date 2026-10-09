"""Execute packaged ProjectArcade client payment and claw Lua in installed Kahlua.

The machine is Java userdata; game events, command transport, inventory, and
timed-action queue are controlled receivers. This proves a client source
contract, not an actual multiplayer server or rendered game interaction.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess


ROOT = Path(__file__).resolve().parents[1]
GAME = Path(r"C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid")
JDK = Path(r"C:/Users/jleyv/Peanut Butter/JetBrains/Java/bin")
FIXTURE = ROOT / "tools/d2_claw_mp_client_fixture.lua"
MENU = ROOT / "mod/42.20/media/lua/client/ProjectArcade_ClawMachine.lua"
CURRENCY = ROOT / "mod/42.20/media/lua/client/ProjectArcade_Currency.lua"
ACTION = ROOT / "mod/42.20/media/lua/client/TimedActions/ProjectArcade_ClawTimedAction.lua"
PRIZE_NET = ROOT / "mod/42.20/media/lua/shared/ProjectArcade_PrizeNet.lua"
BASE = GAME / "media/lua/shared/ISBaseObject.lua"
TIMED = GAME / "media/lua/shared/TimedActions/ISBaseTimedAction.lua"

JAVA = r'''
import java.nio.file.Files;
import java.nio.file.Path;
import se.krka.kahlua.converter.KahluaConverterManager;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.vm.*;
import zombie.Lua.LuaManager;

public final class ClawMpClientProbe {
    public static final class Front {
        public final String direction;
        public Front(String direction) { this.direction = direction; }
    }
    public static final class Square {
        private final int x, y, z;
        private boolean electricity;
        private final Front south = new Front("S"), east = new Front("E");
        private final Front north = new Front("N"), west = new Front("W");
        public Square(boolean electricity, int x, int y, int z) {
            this.electricity = electricity;
            this.x = x;
            this.y = y;
            this.z = z;
        }
        public int getX() { return x; }
        public int getY() { return y; }
        public int getZ() { return z; }
        public boolean haveElectricity() { return electricity; }
        public Front getS() { return south; }
        public Front getE() { return east; }
        public Front getN() { return north; }
        public Front getW() { return west; }
    }
    public static final class Sprite {
        private final String name;
        public Sprite(String name) { this.name = name; }
        public String getName() { return name; }
        public Object getProperties() { return null; }
    }
    public static final class Machine {
        private final Sprite sprite;
        private final Square square;
        private final int objectIndex;
        public Machine(String name, boolean powered, int x, int y, int z, int index) {
            sprite = new Sprite(name);
            square = new Square(powered, x, y, z);
            objectIndex = index;
        }
        public Sprite getSprite() { return sprite; }
        public Square getSquare() { return square; }
        public int getObjectIndex() { return objectIndex; }
    }
    private static int integer(Object value) { return ((Number)value).intValue(); }

    public static void main(String[] args) throws Exception {
        var platform = new J2SEPlatform();
        var env = platform.newEnvironment();
        var thread = new KahluaThread(platform, env);
        thread.debugOwnerThread = Thread.currentThread();
        LuaManager.platform = platform;
        LuaManager.env = env;
        LuaManager.thread = thread;
        LuaManager.converterManager = new KahluaConverterManager();
        zombie.Lua.KahluaNumberConverter.install(LuaManager.converterManager);
        var exposer = new LuaManager.Exposer(LuaManager.converterManager, platform, env);
        for (var type : new Class<?>[]{Front.class, Square.class, Sprite.class, Machine.class}) {
            exposer.setExposed(type);
            exposer.exposeLikeJava(type, env);
        }
        env.rawset("__newMachine", (JavaFunction)(frame, count) -> frame.push(
            new Machine((String)frame.get(0), Boolean.TRUE.equals(frame.get(1)),
                integer(frame.get(2)), integer(frame.get(3)), integer(frame.get(4)),
                integer(frame.get(5)))));
        env.rawset("print", (JavaFunction)(frame, count) -> {
            System.out.println(frame.get(0));
            return 0;
        });
        for (var name : args) {
            var source = Files.readString(Path.of(name));
            thread.call(LuaCompiler.loadstring(source, name, env), null, null, null);
        }
        var result = thread.call(LuaCompiler.loadstring(
            "return __runClawMpClientCases()", "claw-mp-client-verdict", env), null, null, null);
        System.out.println(result);
    }
}
'''


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args()
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=False)
    jars = [GAME / "projectzomboid.jar", *sorted((GAME / "jars").glob("*.jar"))]
    inputs = [Path(__file__), FIXTURE, MENU, CURRENCY, ACTION, PRIZE_NET,
              BASE, TIMED, GAME / "stdlib.lua", JDK / "javac.exe",
              JDK / "java.exe", *jars]
    before = {str(path): sha(path) for path in inputs}
    receipt = {
        "schema": "sao.d2-claw-mp-client-kahlua/1",
        "status": "INCOMPLETE",
        "boundary": "Actual packaged menu, currency, claw action, and prize-net Lua executed in installed Kahlua with Java userdata machines and controlled MP client receivers. No actual MP server, rendered game, native queue, or save claim.",
        "inputsBefore": before,
        "runs": [],
    }

    def save() -> None:
        (out / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")

    def run(label: str, command: list[Path | str]) -> tuple[int, str]:
        command_args = [str(part) for part in command]
        done = subprocess.run(command_args, cwd=out,
                              capture_output=True, timeout=90)
        log = out / f"{label}.log"
        log.write_bytes(done.stdout + done.stderr)
        receipt["runs"].append({"name": label, "command": command_args,
                                "exitCode": done.returncode,
                                "logSha256": sha(log)})
        save()
        return done.returncode, log.read_text(encoding="utf-8", errors="replace")

    save()
    try:
        host = out / "ClawMpClientProbe.java"
        host.write_text(JAVA, encoding="utf-8")
        shutil.copyfile(GAME / "stdlib.lua", out / "stdlib.lua")
        classes = out / "classes"
        classes.mkdir()
        cp = os.pathsep.join(str(jar) for jar in jars)
        code, log = run("compile-host", [JDK / "javac.exe", "-cp", cp,
                                         "-d", classes, host])
        assert code == 0, log[-8000:]
        cp = str(classes) + os.pathsep + cp

        currency = CURRENCY.read_text(encoding="utf-8")
        action = ACTION.read_text(encoding="utf-8")
        controls = {
            "client-payment-gate-disabled": (CURRENCY, currency,
                "if isClient() and not isServer() then",
                "if false then", "CLAW_MP:no_local_debit"),
            "client-price-fields-restored": (CURRENCY, currency,
                "local request = { nonce = nonce }",
                "local request = { nonce = nonce, cost = self.cost, currencyFullType = self.currencyFullType }",
                "CLAW_MP:exact_pay_command"),
            "receipt-replay-enabled": (CURRENCY, currency,
                "paidReceipts[token] = nil",
                "paidReceipts[token] = paidReceipts[token]", "CLAW_MP:token_replay_refused"),
            "missing-attempt-gate-disabled": (ACTION, action,
                "if (missingServerAttempt or self.saoPaymentReceipt or self.paidReceipt",
                "if (self.saoPaymentReceipt or self.paidReceipt",
                "CLAW_MP:direct_debug_without_attempt_refused"),
        }
        variants: dict[str, tuple[Path, Path]] = {}
        for name, (original, source, old, new, _) in controls.items():
            assert source.count(old) == 1, f"mutation anchor count for {name}: {source.count(old)}"
            mutated = out / f"{name}.lua"
            mutated.write_text(source.replace(old, new, 1), encoding="utf-8")
            variants[name] = (original, mutated)

        receipt["generated"] = {str(path): sha(path) for path in
                                [host, out / "stdlib.lua", *sorted(classes.rglob("*.class")),
                                 *(row[1] for row in variants.values())]}
        save()

        counts: dict[str, int | str] = {}
        for name in ["baseline", *controls]:
            selected = variants.get(name)
            currency_path = selected[1] if selected and selected[0] == CURRENCY else CURRENCY
            action_path = selected[1] if selected and selected[0] == ACTION else ACTION
            command = [JDK / "java.exe", "-Djava.awt.headless=true",
                       "--enable-native-access=ALL-UNNAMED", "-cp", cp,
                       "ClawMpClientProbe", FIXTURE, BASE, TIMED,
                       PRIZE_NET, currency_path, action_path, MENU]
            code, log = run(name, command)
            if name == "baseline":
                match = re.search(r"PASS claw MP client (\d+)", log)
                assert code == 0 and match, log[-9000:]
                counts[name] = int(match.group(1))
            else:
                marker = controls[name][4]
                assert code != 0 and marker in log, (name, code, log[-9000:])
                counts[name] = marker

        after = {str(path): sha(path) for path in inputs}
        assert after == before, "executed source or dependency changed during test"
        receipt.update(status="PASS", inputsAfter=after, checks=counts["baseline"],
                       controls={name: counts[name] for name in controls})
        save()
        print(f"PASS claw MP client {counts['baseline']} checks, {len(controls)} inverses")
        return 0
    except Exception as error:
        receipt.update(status="FAIL", error=str(error),
                       inputsAfter={str(path): sha(path) for path in inputs if path.exists()})
        save()
        raise


if __name__ == "__main__":
    raise SystemExit(main())
