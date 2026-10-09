"""Execute packaged ProjectArcade server authority with controlled Kahlua receivers."""

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
FIXTURE = ROOT / "tools/d2_claw_mp_server_fixture.lua"
PAYMENT = ROOT / "mod/42.20/media/lua/server/ProjectArcade_PaymentServer.lua"
ACTION = ROOT / "mod/42.20/media/lua/server/ProjectArcade_ClawNetAction.lua"
PRIZE = ROOT / "mod/42.20/media/lua/server/ProjectArcade_PrizeServer.lua"

JAVA = r'''
import java.nio.file.Files;
import java.nio.file.Path;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.vm.*;

public final class ClawMpServerProbe {
    public static void main(String[] args) throws Exception {
        var platform = new J2SEPlatform();
        var env = platform.newEnvironment();
        var thread = new KahluaThread(platform, env);
        thread.debugOwnerThread = Thread.currentThread();
        env.rawset("print", (JavaFunction)(frame, count) -> {
            System.out.println(frame.get(0));
            return 0;
        });
        for (var name : args) {
            var source = Files.readString(Path.of(name));
            thread.call(LuaCompiler.loadstring(source, name, env), null, null, null);
        }
        thread.call(LuaCompiler.loadstring(
            "return __runClawMpServerCases()", "claw-mp-verdict", env), null, null, null);
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
    inputs = [Path(__file__), FIXTURE, PAYMENT, ACTION, PRIZE,
              GAME / "stdlib.lua", *jars]
    before = {str(path): sha(path) for path in inputs}
    receipt = {
        "schema": "sao.d2-claw-mp-server-kahlua/1",
        "status": "INCOMPLETE",
        "boundary": "Packaged payment, native server timed action and prize Lua compiled and executed in installed Kahlua with controlled game receivers. This is source contract evidence, not live multiplayer or rendered game acceptance.",
        "inputsBefore": before,
        "runs": [],
    }

    def save() -> None:
        (out / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")

    def run(name: str, command: list[str | Path]) -> tuple[int, str]:
        done = subprocess.run([str(part) for part in command], cwd=out,
                              capture_output=True, timeout=90)
        log = out / f"{name}.log"
        log.write_bytes(done.stdout + done.stderr)
        receipt["runs"].append({"name": name, "exitCode": done.returncode,
                                "logSha256": sha(log)})
        save()
        return done.returncode, log.read_text(encoding="utf-8", errors="replace")

    save()
    try:
        java = out / "ClawMpServerProbe.java"
        java.write_text(JAVA, encoding="utf-8")
        shutil.copyfile(GAME / "stdlib.lua", out / "stdlib.lua")
        classes = out / "classes"
        classes.mkdir()
        cp = os.pathsep.join(str(jar) for jar in jars)
        code, log = run("compile-host", [JDK / "javac.exe", "-cp", cp,
                                         "-d", classes, java])
        assert code == 0, log[-8000:]
        cp = str(classes) + os.pathsep + cp

        payment = PAYMENT.read_text(encoding="utf-8")
        action = ACTION.read_text(encoding="utf-8")
        prize = PRIZE.read_text(encoding="utf-8")
        controls = {
            "front-bypass": (PAYMENT,
                "if not machine or not playerAtFront(player, front)",
                "if not machine", "CLAW_MP:front_required_payment"),
            "machine-bypass": (PAYMENT,
                "return machine == row.machine and square == row.square",
                "return machine ~= nil and square == row.square",
                "CLAW_MP:exact_machine_required"),
            "currency-bypass": (PAYMENT,
                "local currency = selectedCurrency()",
                'local currency = "Base.SilverCoin"',
                "CLAW_MP:selected_currency_and_cost"),
            "receipt-bypass": (PRIZE,
                "if checked and paid then",
                "if true then", "CLAW_MP:bare_roll_refused"),
            "completion-bypass": (PAYMENT,
                "if not row or row.player ~= player or row.completed ~= true then return false end",
                "if not row or row.player ~= player then return false end",
                "CLAW_MP:action_completion_required"),
            "native-completion-drop": (ACTION,
                "return ProjectArcade_ClawPayments.complete(self.character, self.serverAttemptId)",
                "return false", "CLAW_MP:S_server_completed"),
            "failed-add-bypass": (PRIZE,
                "if not item then return nil, nil end",
                "if not item then return prizeType, nil end",
                "CLAW_MP:failed_add_not_ok"),
        }
        variants = {"baseline": (PAYMENT, ACTION, PRIZE)}
        generated = [java, out / "stdlib.lua"]
        for name, (source_path, old, new, _) in controls.items():
            source = (payment if source_path == PAYMENT else
                      action if source_path == ACTION else prize)
            assert source.count(old) == 1, f"mutation anchor changed: {name}"
            mutated = out / f"{name}.lua"
            mutated.write_text(source.replace(old, new, 1), encoding="utf-8")
            generated.append(mutated)
            variants[name] = (mutated if source_path == PAYMENT else PAYMENT,
                              mutated if source_path == ACTION else ACTION,
                              mutated if source_path == PRIZE else PRIZE)
        receipt["generated"] = {str(path): sha(path) for path in generated}
        save()

        for name, (payment_path, action_path, prize_path) in variants.items():
            code, log = run(name, [JDK / "java.exe", "-Djava.awt.headless=true",
                                   "--enable-native-access=ALL-UNNAMED", "-cp", cp,
                                   "ClawMpServerProbe", FIXTURE, payment_path,
                                   action_path, prize_path])
            if name == "baseline":
                match = re.search(r"PASS claw MP server (\d+) checks", log)
                assert code == 0 and match, log[-9000:]
                receipt["checks"] = int(match.group(1))
            else:
                marker = controls[name][3]
                assert code != 0 and marker in log, (name, code, log[-9000:])
        after = {str(path): sha(path) for path in inputs}
        assert after == before, "executed source or dependency changed during test"
        receipt.update(status="PASS", inputsAfter=after,
                       controls={name: controls[name][3] for name in controls})
        save()
        print(f"PASS claw MP server {receipt['checks']} checks, {len(controls)} causal mutants")
        return 0
    except Exception as error:
        receipt.update(status="FAIL", error=str(error),
                       inputsAfter={str(path): sha(path) for path in inputs if path.exists()})
        save()
        raise


if __name__ == "__main__":
    raise SystemExit(main())
