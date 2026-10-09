"""Qualify the production Lua ownership guard against installed Kahlua.
No game starts. Evidence stays in the required ignored output directory.
Exact call/public foreign-owner paths run unchanged compiled production.
Bound poll controls substitute only the two existing engine body/mode reads,
explicitly pinned, without changing poll/command logic or installed Lua code.
"""
from pathlib import Path
from datetime import datetime, timezone
import argparse
import ast
import difflib
import hashlib
import json
import os
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
GAME = Path("C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid")
JDK = Path("C:/Users/jleyv/Peanut Butter/JetBrains/Java/bin")
BASE = ROOT / "_scratch/d2-leisure-01/participant-integration21/native-play04/resolution12/communication-thread13"
PREIMAGE = BASE / "preimages/StudyNativeInteraction.java"
PREIMAGE_SHA = "7d2b11e1c1932d991207dbb2468abebe203c5a848a564616c91d85daa65c7b77"

PROBE = r'''
import java.nio.file.*;
import java.util.*;
import java.lang.reflect.*;
import java.util.concurrent.atomic.AtomicInteger;
import se.krka.kahlua.vm.*;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.integration.LuaCaller;
import se.krka.kahlua.converter.KahluaConverterManager;
import zombie.Lua.LuaManager;
import zombie.core.Core;

public final class NativeInteractionThread13Probe {
    interface Test { void run() throws Exception; }
    record Attempt(String value, Throwable error) { }
    static final String SESSION = "69f9025d-1204-4120-930d-700000000001";
    static Path module, output;
    static int checks, failures, errors, emitted, environmentReads, rootReads, callbackReads, bodyReads;
    static KahluaTable baseEnvironment, player, trackedEnvironment;
    static KahluaThread nativeThread;
    static final Thread foreignOwner = new Thread(() -> {}, "GameLoadingThread-controlled-fixture");
    static StudyParticipant.Binding selected;
    static String mode = "Sandbox";
    static Runnable onEnvironment, onRoot, onCallback, onBody;
    static boolean failAfterEmission;
    static StudyParticipant.StatePublisher writer;
    static final List<String> samples = new ArrayList<>();

    static void set(String key, Object value) throws Exception {
        Field field = StudyNativeInteraction.class.getDeclaredField(key);
        field.setAccessible(true); field.set(null, value);
    }
    static Object get(String key) throws Exception {
        Field field = StudyNativeInteraction.class.getDeclaredField(key);
        field.setAccessible(true); return field.get(null);
    }
    static void check(boolean condition, String reason) {
        if (!condition) throw new AssertionError(reason);
    }
    static void run(String name, Test test) {
        checks++;
        try { test.run(); System.out.println("CONTROL PASS " + name); }
        catch (AssertionError failure) {
            failures++; System.out.println("CONTROL FAIL " + name + ": " + failure.getMessage());
        } catch (Throwable unexpected) {
            errors++; System.out.println("CONTROL ERROR " + name + ": " + unexpected);
            unexpected.printStackTrace(System.err);
        } finally {
            if (writer != null) {
                boolean drained = writer.close(2000);
                if (!drained) { errors++; System.err.println("Publisher did not drain: " + name); }
                writer = null;
            }
        }
    }
    static KahluaTable tracked(KahluaTable delegate, String level) {
        return (KahluaTable) Proxy.newProxyInstance(KahluaTable.class.getClassLoader(),
            new Class<?>[]{KahluaTable.class}, (proxy, method, arguments) -> {
                Object value;
                try { value = method.invoke(delegate, arguments); }
                catch (InvocationTargetException target) { throw target.getCause(); }
                if (method.getName().equals("rawget") && arguments != null && arguments.length == 1) {
                    String key = String.valueOf(arguments[0]);
                    if (level.equals("environment") && key.equals("SAO")) {
                        environmentReads++;
                        Runnable hook = onEnvironment; onEnvironment = null; if (hook != null) hook.run();
                        if (value instanceof KahluaTable table) return tracked(table, "root");
                    } else if (level.equals("root") && key.equals("MousecatInteraction")) {
                        rootReads++;
                        Runnable hook = onRoot; onRoot = null; if (hook != null) hook.run();
                        if (value instanceof KahluaTable table) return tracked(table, "callback");
                    } else if (level.equals("callback") && (key.equals("speak") || key.equals("nearby"))) {
                        callbackReads++;
                        Runnable hook = onCallback; onCallback = null; if (hook != null) hook.run();
                    }
                }
                return value;
            });
    }
    static StudyParticipant.Binding selectedBody() {
        bodyReads++;
        Runnable hook = onBody; onBody = null; if (hook != null) hook.run();
        return selected;
    }
    static void initialize(String name) throws Exception {
        Core.debug = false;
        var platform = new J2SEPlatform();
        baseEnvironment = platform.newEnvironment();
        nativeThread = new KahluaThread(platform, baseEnvironment);
        nativeThread.debugOwnerThread = Thread.currentThread();
        LuaManager.thread = nativeThread;
        LuaManager.caller = new LuaCaller(new KahluaConverterManager());
        baseEnvironment.rawset("noteEmission", (JavaFunction)(frame, count) -> { emitted++; return 0; });
        baseEnvironment.rawset("fixtureTimestamp", (JavaFunction)(frame, count) -> {
            if (failAfterEmission) throw new IllegalStateException("Controlled post-emission clock failure");
            return frame.push((double)System.currentTimeMillis());
        });
        String setup = "local player={} "
            + "function player:isDead() return false end function player:getCurrentSquare() return {} end "
            + "function player:getX() return 0 end function player:getY() return 0 end function player:getZ() return 0 end "
            + "function player:Say(text) noteEmission() end fixturePlayer=player; "
            + "function getGameTime() return {getWorldAgeHours=function() return 10 end} end "
            + "function getTimestampMs() return fixtureTimestamp() end "
            + "SAO={Participants={player=function(n)return player end},"
            + "Standing={playerKey=function(p)return 'controlled-player' end},Body={active={buddy=true},foreign={}},"
            + "Identity={get=function(id)return {id=id} end,displayName=function(r)return 'Controlled buddy' end},"
            + "Communication={bodyFor=function(id)return player end,canConverse=function(f,to)return true end,executionOwners={}}}";
        Object[] init = nativeThread.pcall(LuaCompiler.loadstring(setup, "thread13-controlled-globals", baseEnvironment), new Object[0]);
        check(Boolean.TRUE.equals(init[0]), "Controlled Lua environment failed: " + Arrays.toString(init));
        Object[] loaded = nativeThread.pcall(LuaCompiler.loadstring(Files.readString(module), module.toString(), baseEnvironment), new Object[0]);
        check(Boolean.TRUE.equals(loaded[0]), "Actual source-owned Lua communication module failed: " + Arrays.toString(loaded));
        player = (KahluaTable)baseEnvironment.rawget("fixturePlayer");
        trackedEnvironment = tracked(baseEnvironment, "environment");
        LuaManager.env = trackedEnvironment;
        emitted = environmentReads = rootReads = callbackReads = bodyReads = 0;
        onEnvironment = onRoot = onCallback = onBody = null; failAfterEmission = false; mode = "Sandbox";
        selected = new StudyParticipant.Binding(player, 0, 23, "controlled-save", 1, 10, true, 0, 0, 0, "Controlled player", true);
        set("configured", true); set("session", SESSION); set("attempt", 1);
        set("epochBody", selected); set("epochMode", mode); set("bindingEpoch", 1L);
        set("pending", null); set("completed", 0L); set("result", null); set("sampled", false); set("lastTick", 0L);
        synchronized (samples) { samples.clear(); }
        writer = new StudyParticipant.StatePublisher(output.resolve(name + ".json"), (path, bytes) -> {
            synchronized (samples) { samples.add(bytes); }
        });
        set("writer", writer);
    }
    static Map<String,Object> fields() {
        long now = System.currentTimeMillis();
        var values = new LinkedHashMap<String,Object>();
        values.put("schema", StudyNativeInteraction.SCHEMA); values.put("sessionId", SESSION);
        values.put("pid", ProcessHandle.current().pid()); values.put("attempt", 1L); values.put("sequence", 1L);
        values.put("save", "controlled-save"); values.put("saveMode", "Sandbox");
        values.put("playerIndex", 0L); values.put("playerSqlId", 23L);
        values.put("issuedAtUnixMs", now - 1000); values.put("expiresAtUnixMs", now + 4000);
        values.put("personId", "buddy"); values.put("text", "Hello controlled recipient");
        values.put("inputMode", "typed"); values.put("bindingEpoch", 1L);
        return values;
    }
    static StudyNativeInteraction.Request queue(Map<String,Object> values) throws Exception {
        var request = new StudyNativeInteraction.Request(1, values, null); set("pending", request); return request;
    }
    static void poll() throws Exception { set("sampled", false); StudyNativeInteraction.poll(); }
    static Attempt call(String name) throws Exception {
        Method method = StudyNativeInteraction.class.getDeclaredMethod("call", String.class, Object[].class);
        method.setAccessible(true);
        Object[] arguments = name.equals("speak")
            ? new Object[]{player, "buddy", "Hello controlled recipient", "typed", "1", "1"}
            : new Object[]{player, "1"};
        try { return new Attempt((String)method.invoke(null, name, arguments), null); }
        catch (InvocationTargetException target) { return new Attempt(null, target.getCause()); }
    }
    static void blocked(Attempt attempt, String name) {
        check(attempt.error() != null, name + " entered or returned the Lua callback");
        check(emitted == 0, name + " emitted an utterance");
    }
    static String result() throws Exception { return (String)get("result"); }
    static void drain() {
        check(writer.close(2000), "Actual asynchronous publisher did not drain");
        writer = null;
    }

    static void direct() {
        run("direct-foreign-owner-no-env-read", () -> {
            initialize("direct-foreign"); nativeThread.debugOwnerThread = foreignOwner; blocked(call("speak"), "foreign owner");
            check(environmentReads == 0 && rootReads == 0 && callbackReads == 0, "Foreign owner accessed Lua tables");
        });
        run("direct-null-owner-no-env-read", () -> {
            initialize("direct-null-owner"); nativeThread.debugOwnerThread = null; blocked(call("speak"), "null owner");
            check(environmentReads == 0, "Unknown owner accessed the Lua environment");
        });
        run("direct-null-runtime-no-env-read", () -> {
            initialize("direct-null-runtime"); LuaManager.thread = null; blocked(call("speak"), "null runtime");
            check(environmentReads == 0, "Absent runtime accessed the Lua environment");
        });
        run("direct-current-owner-real-speech", () -> {
            initialize("direct-current"); Attempt got = call("speak");
            check(got.error() == null && got.value().contains("\"status\":\"applied\"") && emitted == 1, "Owned actual Lua speech failed");
            Attempt reach = call("nearby");
            check(reach.error() == null && reach.value().contains("utterance-heard-uninterpreted"), "Actual source did not preserve hearing event boundary");
        });
        run("direct-current-owner-real-reach", () -> {
            initialize("direct-reach"); Attempt got = call("nearby");
            check(got.error() == null && got.value().contains("native-communication") && emitted == 0, "Owned actual reach lookup failed");
        });
        run("direct-handoff-after-env-no-root-read", () -> {
            initialize("direct-env-handoff"); onEnvironment = () -> nativeThread.debugOwnerThread = foreignOwner;
            blocked(call("speak"), "environment handoff");
            check(environmentReads == 1 && rootReads == 0 && callbackReads == 0, "Lua root accessed after ownership changed");
        });
        run("direct-handoff-after-root-no-callback-read", () -> {
            initialize("direct-root-handoff"); onRoot = () -> nativeThread.debugOwnerThread = foreignOwner;
            blocked(call("speak"), "root handoff");
            check(environmentReads == 1 && rootReads == 1 && callbackReads == 0, "Lua callback table accessed after ownership changed");
        });
        run("direct-handoff-at-callback-no-emission", () -> {
            initialize("direct-callback-handoff"); onCallback = () -> nativeThread.debugOwnerThread = foreignOwner;
            blocked(call("speak"), "callback handoff"); check(callbackReads == 1, "Expected lookup handoff did not execute");
        });
        run("direct-runtime-replacement-no-old-callback", () -> {
            initialize("direct-runtime-swap");
            onCallback = () -> {
                var platform = new J2SEPlatform();
                var replacement = new KahluaThread(platform, platform.newEnvironment());
                replacement.debugOwnerThread = Thread.currentThread(); LuaManager.thread = replacement;
            };
            blocked(call("speak"), "runtime replacement");
        });
        run("direct-readiness-resumes-real-callback", () -> {
            initialize("direct-resume"); nativeThread.debugOwnerThread = foreignOwner;
            blocked(call("speak"), "before resume"); nativeThread.debugOwnerThread = Thread.currentThread();
            Attempt got = call("speak");
            check(got.error() == null && emitted == 1, "Owned callback did not resume once");
        });
    }

    static void exactPoll() {
        run("exact-public-poll-foreign-keeps-pending-and-epoch", () -> {
            initialize("exact-poll-foreign"); var pending = queue(fields()); nativeThread.debugOwnerThread = foreignOwner;
            poll(); check(get("pending") == pending && (long)get("completed") == 0 && result() == null, "Foreign public poll acknowledged pending speech");
            check((long)get("bindingEpoch") == 1 && get("epochBody") == selected, "Foreign public poll read/unbound engine body");
            check(environmentReads == 0 && emitted == 0, "Foreign public poll accessed Lua");
            drain(); synchronized(samples) { check(samples.isEmpty(), "Foreign poll published fresh availability"); }
        });
        run("exact-public-poll-null-runtime-keeps-pending", () -> {
            initialize("exact-poll-null"); var pending = queue(fields()); LuaManager.thread = null;
            poll(); check(get("pending") == pending && result() == null, "Absent runtime acknowledged pending speech");
            check((long)get("bindingEpoch") == 1 && environmentReads == 0, "Absent runtime observed body or Lua");
            drain(); synchronized(samples) { check(samples.isEmpty(), "Absent runtime published fresh availability"); }
        });
    }

    static void boundPoll() {
        run("bound-poll-foreign-no-body-read-no-ack", () -> {
            initialize("bound-foreign"); var pending = queue(fields()); nativeThread.debugOwnerThread = foreignOwner;
            poll(); check(bodyReads == 0 && get("pending") == pending && (long)get("completed") == 0 && result() == null, "Foreign poll read a body or acknowledged");
            drain(); synchronized(samples) { check(samples.isEmpty(), "Foreign poll offered fresh availability"); }
        });
        run("bound-poll-owned-actual-module-applied-once", () -> {
            initialize("bound-owned"); queue(fields()); poll();
            check(emitted == 1 && result().contains("\"status\":\"applied\"") && get("pending") == null, "Owned command path did not apply once");
            poll(); check(emitted == 1 && (long)get("completed") == 1, "Acknowledged command was replayed");
            drain(); synchronized(samples) { check(!samples.isEmpty(), "Owned poll did not reach real publisher"); }
        });
        run("bound-poll-resume-same-body-revalidates-lease", () -> {
            initialize("bound-resume"); var pending = queue(fields()); nativeThread.debugOwnerThread = foreignOwner; poll();
            check(get("pending") == pending && emitted == 0, "Unavailable owner did not preserve original lease");
            nativeThread.debugOwnerThread = Thread.currentThread(); poll();
            check(emitted == 1 && result().contains("\"status\":\"applied\""), "Same-body resume did not apply the original request");
        });
        run("bound-poll-resume-expired-rejected-not-emitted", () -> {
            initialize("bound-expired"); var values = fields(); queue(values); nativeThread.debugOwnerThread = foreignOwner; poll();
            values.put("expiresAtUnixMs", System.currentTimeMillis()-1); nativeThread.debugOwnerThread = Thread.currentThread(); poll();
            check(emitted == 0 && result().contains("\"status\":\"rejected\"") && result().contains("expired"), "Resumed expired request emitted or invented success");
        });
        run("bound-poll-resume-different-body-rejected", () -> {
            initialize("bound-body-change"); queue(fields()); nativeThread.debugOwnerThread = foreignOwner; poll();
            selected = new StudyParticipant.Binding(player, 0, 24, "replacement-save", 1, 10, true, 0, 0, 0, "Controlled replacement", true);
            nativeThread.debugOwnerThread = Thread.currentThread(); poll();
            check(emitted == 0 && result().contains("\"status\":\"rejected\"") && (long)get("bindingEpoch") == 2, "Prior-body speech was borrowed after resume");
        });
        run("bound-poll-resume-different-mode-rejected", () -> {
            initialize("bound-mode-change"); queue(fields()); nativeThread.debugOwnerThread = foreignOwner; poll();
            mode = "Rising"; nativeThread.debugOwnerThread = Thread.currentThread(); poll();
            check(emitted == 0 && result().contains("\"status\":\"rejected\""), "Prior-mode speech was borrowed after resume");
        });
        run("bound-poll-body-read-handoff-no-epoch-or-ack", () -> {
            initialize("bound-body-handoff"); var pending = queue(fields());
            onBody = () -> {
                nativeThread.debugOwnerThread = foreignOwner;
                selected = new StudyParticipant.Binding(player, 0, 24, "replacement-save", 1, 10, true, 0, 0, 0, "Controlled replacement", true);
            };
            poll(); check(bodyReads == 1 && (long)get("bindingEpoch") == 1 && get("pending") == pending && result() == null, "Body-read handoff observed a new epoch or acknowledged");
            drain(); synchronized(samples) { check(samples.isEmpty(), "Body-read handoff offered fresh availability"); }
        });
        run("bound-poll-callback-handoff-pending-not-unknown", () -> {
            initialize("bound-callback-handoff"); var pending = queue(fields());
            onCallback = () -> nativeThread.debugOwnerThread = foreignOwner; poll();
            check(emitted == 0 && get("pending") == pending && result() == null && (long)get("completed") == 0, "Pre-callback handoff falsely acknowledged or emitted");
            drain(); synchronized(samples) {
                check(!samples.isEmpty(), "Safe captured body had no source unavailability sample");
                check(samples.stream().allMatch(v -> v.contains("\"status\":\"unavailable\"")), "Handoff refreshed available reach");
            }
        });
        run("bound-poll-callback-handoff-resumes-once", () -> {
            initialize("bound-callback-resume"); queue(fields()); onCallback = () -> nativeThread.debugOwnerThread = foreignOwner; poll();
            check(emitted == 0 && get("pending") != null, "Handoff consumed original request");
            nativeThread.debugOwnerThread = Thread.currentThread(); poll(); poll();
            check(emitted == 1 && result().contains("\"status\":\"applied\"") && get("pending") == null, "Retained handoff command did not resolve exactly once");
        });
        run("bound-poll-post-emission-fault-unknown-no-replay", () -> {
            initialize("bound-unknown"); queue(fields()); failAfterEmission = true; poll();
            check(emitted == 1 && result().contains("\"status\":\"unknown\"") && get("pending") == null, "Actual post-emission failure was falsely rejected/applied");
            failAfterEmission = false; poll(); check(emitted == 1 && (long)get("completed") == 1, "Unknown command was automatically replayed");
        });
        run("bound-poll-unbound-no-utterance", () -> {
            initialize("bound-unbound"); queue(fields()); selected = null; poll();
            check(emitted == 0 && result().contains("\"status\":\"rejected\""), "Unbound body admitted a queued utterance");
        });
        for (String field : List.of("sessionId", "pid", "attempt", "save", "saveMode", "playerIndex", "playerSqlId", "bindingEpoch")) {
            run("bound-poll-foreign-" + field + "-rejected", () -> {
                initialize("bound-field-" + field); var values = fields(); Object prior = values.get(field);
                values.put(field, prior instanceof Long ? (Long)prior + 1 : prior + "-foreign"); queue(values); poll();
                check(emitted == 0 && result().contains("\"status\":\"rejected\""), "Foreign " + field + " was emitted");
            });
        }
    }
    public static void main(String[] args) throws Exception {
        module = Path.of(args[1]); output = Path.of(args[2]); Files.createDirectories(output);
        zombie.ZomboidFileSystem.instance.setCacheDir(output.resolve("isolated-user-cache").toString());
        if (args[0].equals("exact")) { direct(); exactPoll(); }
        else if (args[0].equals("bound")) boundPoll();
        else throw new AssertionError("Unknown probe layer");
        System.out.println("COUNTS checks=" + checks + "; failures=" + failures + "; errors=" + errors);
        if (failures != 0 || errors != 0) System.exit(1);
    }
}
'''

def pin(path):
    data = path.read_bytes()
    return {"path": str(path), "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}

def declarations():
    tree = ast.parse((ROOT / "tools/world_lab_run.py").read_text(encoding="utf-8-sig"))
    result = {}
    for node in tree.body:
        if isinstance(node, ast.Assign):
            for target in node.targets:
                if isinstance(target, ast.Name) and target.id in ("PARTICIPANT_SOURCES", "OBSERVER_SOURCES"):
                    result[target.id] = ast.literal_eval(node.value)
    if len(result["PARTICIPANT_SOURCES"]) != 9 or len(result["OBSERVER_SOURCES"]) != 5:
        raise ValueError("Current native participant/observer source inventory differs")
    return result

def run(output):
    output = output.resolve()
    if not output.is_relative_to(BASE.resolve()) or output == BASE.resolve():
        raise ValueError("Qualification output must be a new ignored communication-thread13 subdirectory")
    output.mkdir(parents=True, exist_ok=False)
    receipt = {"schema": "sao.native-communication-thread-qualification/13",
               "observedAtUtc": datetime.now(timezone.utc).isoformat(), "results": [], "probes": [],
               "productionInputEdits": ["tools/world_lab/StudyNativeInteraction.java"],
               "nativeActions": 0, "saveMutations": 0}
    participant = ROOT / "tools/world_lab/StudyNativeInteraction.java"
    if pin(PREIMAGE)["sha256"] != PREIMAGE_SHA:
        raise ValueError("Authorized exact preimage differs")
    cohorts = declarations()
    sources = [ROOT / "tools/world_lab" / name for name in sorted(set(sum((list(v) for v in cohorts.values()), [])))]
    module = ROOT / "mod/42.20/media/lua/client/SAO_MousecatInteraction.lua"
    dependencies = [GAME / "projectzomboid.jar", GAME / "ZombieBuddy.jar", JDK / "java.exe", JDK / "javac.exe", GAME / "stdlib.lua"]
    receipt["sourceBefore"] = [pin(p) for p in sources + [module, ROOT / "tools/world_lab_run.py", Path(__file__).resolve()]]
    receipt["preimage"] = pin(PREIMAGE)
    receipt["dependencies"] = [pin(p) for p in dependencies]
    frozen = output / "frozen"; frozen.mkdir()
    (output / "stdlib.lua").write_bytes((GAME / "stdlib.lua").read_bytes())
    receipt["installedStdlibCopy"] = pin(output / "stdlib.lua")
    for path in sources + [module, Path(__file__).resolve()]:
        (frozen / path.name).write_bytes(path.read_bytes())
    probe_source = output / "NativeInteractionThread13Probe.java"
    probe_source.write_text(PROBE, encoding="utf-8")
    cp = os.pathsep.join(str(p) for p in dependencies[:2])

    def command(label, arguments, expected=None):
        result = subprocess.run(list(map(str, arguments)), encoding="utf-8", errors="replace", text=True,
                                capture_output=True, timeout=60, cwd=output,
                                creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        stdout = output / (label + ".stdout.txt"); stderr = output / (label + ".stderr.txt")
        stdout.write_text(result.stdout, encoding="utf-8"); stderr.write_text(result.stderr, encoding="utf-8")
        receipt["results"].append({"label": label, "command": list(map(str, arguments)), "exitCode": result.returncode,
                                   "stdout": pin(stdout), "stderr": pin(stderr)})
        if expected is not None and result.returncode != expected:
            raise RuntimeError(f"{label}: exit {result.returncode}, expected {expected}; {result.stderr[:800]}")
        return result.returncode, result.stdout

    def probe(label, source, layer, required_failures=None):
        target = output / label; target.mkdir(); classes = target / "classes"; classes.mkdir()
        if source is not None:
            local = target / "StudyNativeInteraction.java"; local.write_text(source, encoding="utf-8")
            (target / "source.diff").write_text("".join(difflib.unified_diff(
                current.splitlines(True), source.splitlines(True), fromfile="exact-current", tofile=label)), encoding="utf-8")
            command(label + "-compile", [JDK / "javac.exe", "-cp", participant_cp, "-d", classes, local, probe_source], 0)
            source_pin = pin(local)
        else:
            command(label + "-probe-compile", [JDK / "javac.exe", "-cp", participant_cp, "-d", classes, probe_source], 0)
            source_pin = pin(frozen / "StudyNativeInteraction.java")
        runtime_cp = os.pathsep.join((str(classes), participant_cp))
        exit_code, stdout = command(label + "-run", [JDK / "java.exe", "-Djava.awt.headless=true", "-cp", runtime_cp,
                                     "NativeInteractionThread13Probe", layer, frozen / module.name, target / "fixtures"])
        controls = [{"status": status, "name": name} for status, name in re.findall(r"^CONTROL (PASS|FAIL|ERROR) ([^\s:]+)", stdout, re.M)]
        failures = {c["name"] for c in controls if c["status"] == "FAIL"}
        errors = {c["name"] for c in controls if c["status"] == "ERROR"}
        counts = re.search(r"^COUNTS checks=(\d+); failures=(\d+); errors=(\d+)$", stdout, re.M)
        if not counts or tuple(map(int, counts.groups())) != (len(controls), len(failures), len(errors)):
            raise RuntimeError(label + ": control counts do not reconcile")
        if len({c["name"] for c in controls}) != len(controls) or errors:
            raise RuntimeError(label + ": duplicate or error controls")
        if required_failures is None:
            if exit_code != 0 or failures:
                raise RuntimeError(label + ": candidate controls failed: " + repr(failures))
        elif exit_code != 1 or not required_failures <= failures:
            raise RuntimeError(label + ": meaningful defect failures missing: " + repr(failures))
        row = {"label": label, "layer": layer, "source": source_pin, "controls": controls,
               "pass": len(controls)-len(failures), "fail": len(failures), "errors": len(errors),
               "requiredDefectFailures": sorted(required_failures or set())}
        receipt["probes"].append(row)
        print(json.dumps({key: row[key] for key in ("label", "pass", "fail", "errors")}), flush=True)
        return row

    try:
        for name, files in cohorts.items():
            classes = output / name.lower(); classes.mkdir()
            command(name.lower() + "-compile", [JDK / "javac.exe", "-cp", cp, "-d", classes,
                                                 *[frozen / file for file in files]], 0)
        participant_cp = os.pathsep.join((str(output / "participant_sources"), cp))
        current = (frozen / participant.name).read_text(encoding="utf-8")
        # Established, bounded environmental fixtures: two input reads only.
        old_body = "StudyParticipant.Binding body = StudyParticipant.binding();"
        new_body = "StudyParticipant.Binding body = NativeInteractionThread13Probe.selectedBody();"
        old_mode = 'String mode = body == null ? "" : Core.getInstance().getGameMode();'
        new_mode = 'String mode = body == null ? "" : NativeInteractionThread13Probe.mode;'
        if current.count(old_body) != 1 or current.count(old_mode) != 1:
            raise ValueError("Bound fixture engine read anchors differ")
        bound = current.replace(old_body, new_body).replace(old_mode, new_mode)
        receipt["boundFixtureRedirections"] = [{"from": old_body, "to": new_body}, {"from": old_mode, "to": new_mode}]
        probe("exact-current", None, "exact")
        probe("bound-current", bound, "bound")
        probe("exact-preimage", PREIMAGE.read_text(encoding="utf-8"), "exact",
              {"direct-foreign-owner-no-env-read", "direct-handoff-at-callback-no-emission",
               "exact-public-poll-foreign-keeps-pending-and-epoch"})
        first_guard = "        if (!ownsLuaThread(luaThread)) return;"
        if current.count(first_guard) != 2:
            raise ValueError("Poll ownership guard count differs")
        inverse = bound.replace(first_guard, "        // Restored defect: owner not checked before binding.", 1)
        probe("inverse-before-body", inverse, "bound", {"bound-poll-foreign-no-body-read-no-ack"})
        anchor = '        if (!ownsLuaThread(luaThread)) return;\n        observeEpoch(body, mode);'
        inverse = bound.replace(anchor, "        // Restored defect: handoff ignored.\n        observeEpoch(body, mode);", 1)
        probe("inverse-after-body", inverse, "bound", {"bound-poll-body-read-handoff-no-epoch-or-ack"})
        anchor = "        requireLuaOwnership(thread);\n        Object[] value = LuaManager.caller.pcall(thread, callback, arguments);"
        if current.count(anchor) != 1:
            raise ValueError("Callback ownership anchor differs")
        inverse = current.replace(anchor, "        Object[] value = LuaManager.caller.pcall(thread, callback, arguments);", 1)
        probe("inverse-before-callback", inverse, "exact", {"direct-handoff-at-callback-no-emission"})
        anchor = "            } catch (LuaOwnershipUnavailable waiting) {\n                // No callback entered: retain the original request and lease."
        if bound.count(anchor) != 1:
            raise ValueError("Pending preservation anchor differs")
        inverse = bound.replace(anchor, "            } catch (LuaOwnershipUnavailable waiting) {\n                completed = request.sequence(); pending = null;\n                // Restored defect: falsely consume non-entered callback.", 1)
        probe("inverse-premature-ack", inverse, "bound", {"bound-poll-callback-handoff-pending-not-unknown",
                                                        "bound-poll-callback-handoff-resumes-once"})
        receipt["sourceAfter"] = [pin(p) for p in sources + [module, ROOT / "tools/world_lab_run.py", Path(__file__).resolve()]]
        receipt["stable"] = receipt["sourceBefore"] == receipt["sourceAfter"]
        if not receipt["stable"]:
            raise RuntimeError("Qualified source set changed during controls")
        receipt["status"] = "PASS"
    except Exception as failure:
        receipt["status"] = "FAIL"; receipt["failure"] = repr(failure)
    receipt["limits"] = [
        "Exact installed nine-source participant and five-source observer compiles; no game/native activation.",
        "Exact production private call and foreign/null-owner public poll run without source substitutions.",
        "Bound command/reach cases use exactly two documented engine-input read redirections, plus actual installed Kahlua and unchanged SAO Lua source.",
        "Controlled data/callbacks/publication demonstrate source boundaries, not live character, speech reception, voice or cognition acceptance.",
        "Ownership is rechecked at adapter access/call boundaries; engine owner fields do not provide an atomic callback-wide lock.",
        "Foreign initial owner does not refresh availability; the unchanged consumer withholds stale/future interaction samples at three seconds.",
    ]
    receipt["probePin"] = pin(probe_source)
    receipt_path = output / "receipt.json"
    receipt_path.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"status": receipt["status"], "receipt": pin(receipt_path), "failure": receipt.get("failure")}), flush=True)
    return 0 if receipt["status"] == "PASS" else 1

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    raise SystemExit(run(args.output))
