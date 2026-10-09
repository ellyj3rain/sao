"""Exercise the packaged ProjectArcade claw menu in installed Kahlua.

The machine/sprite/properties/square are exposed Java userdata. The player, inventory,
queue, and event dispatcher are controlled receivers. This is a source contract
test; it does not click a rendered game or prove installed native userdata.
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
MENU = ROOT / "mod/42.20/media/lua/client/ProjectArcade_ClawMachine.lua"
CURRENCY = ROOT / "mod/42.20/media/lua/client/ProjectArcade_Currency.lua"
ACTION = ROOT / "mod/42.20/media/lua/client/TimedActions/ProjectArcade_ClawTimedAction.lua"
FIXTURE = ROOT / "tools/d2_claw_menu_fixture.lua"
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

public final class ClawMenuProbe {
    public static final class Properties {
        private final String groupName;
        public Properties(String groupName) { this.groupName = groupName; }
        public boolean has(String key) {
            return "GroupName".equals(key) && groupName != null;
        }
        public String get(String key) {
            return has(key) ? groupName : null;
        }
    }
    public static final class Front {
        public final String direction;
        public Front(String direction) { this.direction = direction; }
    }
    public static final class Square {
        private boolean electricity;
        private final Front south = new Front("S");
        private final Front east = new Front("E");
        private final Front north = new Front("N");
        private final Front west = new Front("W");
        public Square(boolean electricity) { this.electricity = electricity; }
        public boolean haveElectricity() { return electricity; }
        public Front getS() { return south; }
        public Front getE() { return east; }
        public Front getN() { return north; }
        public Front getW() { return west; }
        public void setElectricity(boolean value) { electricity = value; }
    }
    public static final class Sprite {
        private final String name;
        private final Properties properties;
        public Sprite(String name, String groupName) {
            this.name = name;
            this.properties = new Properties(groupName);
        }
        public String getName() { return name; }
        public Properties getProperties() { return properties; }
    }
    public static final class Machine {
        private Sprite sprite;
        private Square square;
        public Machine(String sprite, boolean powered, String groupName) {
            this.sprite = new Sprite(sprite, groupName);
            this.square = new Square(powered);
        }
        public Sprite getSprite() { return sprite; }
        public Square getSquare() { return square; }
        public void setSprite(String name) { sprite = new Sprite(name, null); }
        public void removeSquare() { square = null; }
    }

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
        for (var type : new Class<?>[]{Properties.class, Front.class, Square.class,
                Sprite.class, Machine.class}) {
            exposer.setExposed(type);
            exposer.exposeLikeJava(type, env);
        }
        env.rawset("__newMachine", (JavaFunction)(frame, count) ->
            frame.push(new Machine((String)frame.get(0), Boolean.TRUE.equals(frame.get(1)),
                count >= 3 ? (String)frame.get(2) : null)));
        env.rawset("__setPower", (JavaFunction)(frame, count) -> {
            ((Machine)frame.get(0)).getSquare().setElectricity(Boolean.TRUE.equals(frame.get(1)));
            return 0;
        });
        env.rawset("__setSprite", (JavaFunction)(frame, count) -> {
            ((Machine)frame.get(0)).setSprite((String)frame.get(1));
            return 0;
        });
        env.rawset("__removeSquare", (JavaFunction)(frame, count) -> {
            ((Machine)frame.get(0)).removeSquare();
            return 0;
        });
        env.rawset("print", (JavaFunction)(frame, count) -> {
            System.out.println(frame.get(0));
            return 0;
        });
        for (var name : args) {
            var source = Files.readString(Path.of(name));
            thread.call(LuaCompiler.loadstring(source, name, env), null, null, null);
        }
        var result = thread.call(LuaCompiler.loadstring(
            "return __runClawMenuCases()", "claw-menu-verdict", env), null, null, null);
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
    inputs = [Path(__file__), FIXTURE, MENU, CURRENCY, ACTION, BASE, TIMED,
              GAME / "stdlib.lua", *jars]
    before = {str(path): sha(path) for path in inputs}
    receipt = {
        "schema": "sao.d2-claw-menu-kahlua/1",
        "status": "INCOMPLETE",
        "boundary": "Actual packaged menu, currency and claw action compiled/executed in installed Kahlua with Java userdata machines and controlled game receivers. No rendered native click, actual IsoObject/IsoGridSquare, game queue, MP payment, or save claim.",
        "inputsBefore": before,
        "runs": [],
    }

    def save() -> None:
        (out / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")

    def run(label: str, command: list[Path | str]) -> tuple[int, str]:
        done = subprocess.run([str(part) for part in command], cwd=out,
                              capture_output=True, timeout=90)
        log = out / f"{label}.log"
        log.write_bytes(done.stdout + done.stderr)
        receipt["runs"].append({"name": label, "exitCode": done.returncode,
                                "logSha256": sha(log)})
        save()
        return done.returncode, log.read_text(encoding="utf-8", errors="replace")

    save()
    try:
        (out / "ClawMenuProbe.java").write_text(JAVA, encoding="utf-8")
        shutil.copyfile(GAME / "stdlib.lua", out / "stdlib.lua")
        classes = out / "classes"
        classes.mkdir()
        cp = os.pathsep.join(str(jar) for jar in jars)
        code, log = run("compile-host", [JDK / "javac.exe", "-cp", cp,
                                         "-d", classes, out / "ClawMenuProbe.java"])
        assert code == 0, log[-8000:]
        cp = str(classes) + os.pathsep + cp
        source = MENU.read_text(encoding="utf-8")
        action_source = ACTION.read_text(encoding="utf-8")
        variants = {"baseline": (MENU, ACTION)}
        controls = {
            "wrong-sprite-admitted": (
                'if spriteName == "pa_recreational_2" or spriteName == "pa_recreational_3"',
                'if spriteName == "pa_recreational_6" or spriteName == "pa_recreational_3"',
                "CLAW_MENU:wrong_sprite_rejected"),
            "unpowered-admitted": (
                "if square:haveElectricity() then", "if true then",
                "CLAW_MENU:power_reader_unpowered_refused"),
            "native-group-ignored": (
                "if props.has then return props:has(key) end",
                "if props.has then return false end",
                "CLAW_MENU:grouped_sprite_admitted"),
            "unoriented-group-admitted": (
                "return matched ~= nil",
                "return true",
                "CLAW_MENU:group_without_orientation_no_menu"),
            "front-debit-bypass": (
                "and playerObj:getSquare() == front",
                "and true",
                "CLAW_MENU:player_left_front_before_debit_refused"),
        }
        for name, (old, new, _) in controls.items():
            assert old in source, f"missing mutation anchor: {name}"
            mutated = out / f"{name}.lua"
            mutated.write_text(source.replace(old, new, 1), encoding="utf-8")
            variants[name] = (mutated, ACTION)
        action_control = (
            "and self.character ~= nil and self.character:getSquare() == self.selectedFront",
            "and self.character ~= nil",
            "CLAW_MENU:player_left_front_action_invalid",
        )
        old, new, marker = action_control
        assert old in action_source, "missing mutation anchor: front-action-bypass"
        mutated_action = out / "front-action-bypass.lua"
        mutated_action.write_text(action_source.replace(old, new, 1), encoding="utf-8")
        variants["front-action-bypass"] = (MENU, mutated_action)
        generated_variants = [path for pair in list(variants.values())[1:]
                              for path in pair if path not in (MENU, ACTION)]
        receipt["generated"] = {str(path): sha(path) for path in
                                [out / "ClawMenuProbe.java", out / "stdlib.lua",
                                 *generated_variants]}
        save()
        counts = {}
        for name, (menu_candidate, action_candidate) in variants.items():
            command = [JDK / "java.exe", "-Djava.awt.headless=true",
                       "--enable-native-access=ALL-UNNAMED", "-cp", cp,
                       "ClawMenuProbe", FIXTURE, BASE, TIMED, CURRENCY,
                       action_candidate, menu_candidate]
            code, log = run(name, command)
            if name == "baseline":
                match = re.search(r"PASS claw menu (\d+)", log)
                assert code == 0 and match, log[-9000:]
                counts[name] = int(match.group(1))
            else:
                marker = action_control[2] if name == "front-action-bypass" else controls[name][2]
                assert code != 0 and marker in log, (name, code, log[-9000:])
                counts[name] = marker
        after = {str(path): sha(path) for path in inputs}
        assert after == before, "executed source or dependency changed during test"
        receipt.update(status="PASS", inputsAfter=after, checks=counts["baseline"],
                       controls={name: counts[name] for name in counts if name != "baseline"})
        save()
        print(f"PASS claw menu {counts['baseline']} checks, {len(counts) - 1} inverses")
        return 0
    except Exception as error:
        receipt.update(status="FAIL", error=str(error),
                       inputsAfter={str(path): sha(path) for path in inputs if path.exists()})
        save()
        raise


if __name__ == "__main__":
    raise SystemExit(main())
