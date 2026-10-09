"""Qualify the asynchronous native participant publisher without starting PZ.

Actual installed Java dependencies compile a frozen seven-source cohort. Synthetic
engine fixtures exercise actual publisher code, including a real Windows sharing
denial, worker-only recovery and a restored blocking producer. All output is new.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import time
from pathlib import Path

import world_lab_participant_java_test as Fixture

ROOT = Path(__file__).resolve().parents[1]
PREIMAGE = ROOT / "_scratch/d2-leisure-01/participant-integration21/state-publisher04/StudyParticipant.preimage.java"
PREIMAGE_SHA = "15ddbe1337e2e5c939a3ca0f8cfb65378d4f5ee1637d9602e51cf40804012f6e"

PROBE = r'''
import java.io.*;
import java.lang.reflect.*;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.*;

public final class ParticipantPublisher04Probe {
    static Path root;
    static int count, failed;
    static final String SESSION="12345678-1234-1234-1234-123456789abc";
    static void require(boolean ok,String why) { if(!ok)throw new AssertionError(why); }
    static void property(Path destination) throws Exception {
        System.clearProperty("study.observer");
        System.setProperty("study.participantSession",SESSION);
        System.setProperty("study.attempt","1");
        System.setProperty("study.participantState",destination.toAbsolutePath().toString());
        zombie.characters.IsoPlayer.players[0]=new zombie.characters.IsoPlayer();
        zombie.iso.IsoWorld.instance.currentCell=new zombie.iso.IsoCell();
        zombie.core.Core.gameSaveWorld="Publisher04Fixture";
        zombie.GameTime.hours=25.5;
        org.lwjglx.opengl.Display.active=true;
        StudyParticipant.configure();
    }
    static void publisher(StudyParticipant.StatePublisher value) throws Exception {
        Field field=StudyParticipant.class.getDeclaredField("publisher");
        field.setAccessible(true);field.set(null,value);
    }
    static void poll() throws Exception {
        Field sampled=StudyParticipant.class.getDeclaredField("stateSampled");
        sampled.setAccessible(true);sampled.set(null,false);StudyParticipant.poll();
    }
    static void originalWrite(Path path,String sample) throws IOException {
        try {
            Method method=StudyParticipant.class.getDeclaredMethod("publish",Path.class,String.class);
            method.setAccessible(true);method.invoke(null,path,sample);
        } catch(InvocationTargetException wrapped) {
            if(wrapped.getCause() instanceof IOException failure)throw failure;
            throw new IllegalStateException(wrapped.getCause());
        } catch(ReflectiveOperationException missing) {throw new IllegalStateException(missing);}
    }
    static StudyParticipant.StatePublisher install(String name,StudyParticipant.Publication write) throws Exception {
        property(root.resolve(name).resolve("participant-state.json"));
        require(StudyParticipant.finishPublication(2000),"empty default publisher failed to drain");
        var writer=new StudyParticipant.StatePublisher(root.resolve(name).resolve("participant-state.json"),write);
        publisher(writer);return writer;
    }
    interface Check {void run() throws Exception;}
    static void check(String name,Check action) throws Exception {
        count++;
        try {action.run();System.out.println("CONTROL PASS "+name);}
        catch(Throwable failure) {failed++;System.out.println("CONTROL FAIL "+name+" :: "+failure);}
        finally {StudyParticipant.finishPublication(2000);publisher(null);}
    }
    static void blocked() throws Exception {
        CountDownLatch entered=new CountDownLatch(1),release=new CountDownLatch(1);
        AtomicInteger writes=new AtomicInteger();
        ConcurrentHashMap<String,String> delivered=new ConcurrentHashMap<>();
        var writer=install("blocked",(path,sample)->{
            require(Thread.currentThread().getName().equals("sao-participant-state"),"filesystem invoked by producer");
            if(writes.getAndIncrement()==0) {
                entered.countDown();
                try {if(!release.await(5,TimeUnit.SECONDS))throw new IOException("controlled writer never released");}
                catch(InterruptedException interrupted){Thread.currentThread().interrupt();throw new IOException(interrupted);}
            }
            delivered.put(path.getFileName().toString(),sample);
        });
        ExecutorService game=Executors.newSingleThreadExecutor(r->new Thread(r,"synthetic-game-logic"));
        try {
            poll();require(entered.await(1,TimeUnit.SECONDS),"writer never reached controlled filesystem boundary");
            Future<?> progress=game.submit(()->{
                try {
                    for(int n=0;n<200;n++) {poll();require(StudyParticipant.frame()!=null,"frame sampling lost body");}
                    for(int n=0;n<2000;n++)writer.offer("sample-"+n,n==731);
                    writer.offer("final-unready",false);
                } catch(Exception failure){throw new RuntimeException(failure);}
            });
            progress.get(200,TimeUnit.MILLISECONDS);
            Field state=writer.getClass().getDeclaredField("pendingState"),identity=writer.getClass().getDeclaredField("pendingIdentity");
            state.setAccessible(true);identity.setAccessible(true);
            require("final-unready".equals(state.get(writer)),"state mailbox retained an older sample");
            require("sample-731".equals(identity.get(writer)),"unready state erased independent ready identity");
            release.countDown();require(writer.close(2000),"final mailboxes did not drain");
            require("final-unready".equals(delivered.get("participant-state.json")),"final current state was not delivered");
            require("sample-731".equals(delivered.get("participant-identity.json")),"last ready identity was not delivered");
            require(writes.get()<12,"publisher queued every intermediate state");
        } finally {release.countDown();game.shutdownNow();}
    }
    static void actualSharing(Path destination,Path release) throws Exception {
        property(destination);
        Thread unlock=new Thread(()->{try {Thread.sleep(65);Files.writeString(release,"release");}catch(Exception failure){throw new RuntimeException(failure);}},"controlled-windows-unlock");
        unlock.start();poll();
        require(StudyParticipant.finishPublication(2000),"bounded actual sharing recovery did not drain");
        unlock.join();
        String state=Files.readString(destination),identity=Files.readString(destination.resolveSibling("participant-identity.json"));
        require(state.contains("\"sessionId\":\""+SESSION+"\"")&&state.contains("\"ready\":true"),"actual sharing conflict lost sampled state");
        require(state.equals(identity),"actual ready identity differs from source state");
        System.out.println("CONTROL PASS current-windows-sharing-recovery");
    }
    public static void main(String[] args) throws Exception {
        root=Path.of(args[0]);Files.createDirectories(root);
        if(args.length>1&&args[1].equals("actual-sharing")) {
            actualSharing(root.resolve("participant-state.json"),root.resolve("release"));return;
        }
        if(args.length>1&&args[1].equals("shutdown-hook")) {
            AtomicInteger calls=new AtomicInteger();CountDownLatch entered=new CountDownLatch(1);
            install("exit",(path,sample)->{
                if(calls.getAndIncrement()==0){entered.countDown();try{Thread.sleep(120);}catch(InterruptedException interrupted){throw new IOException(interrupted);}}
                originalWrite(path,sample);
            });
            zombie.characters.IsoPlayer.players[0].sqlId=23;zombie.characters.IsoPlayer.players[0].x=456;
            poll();require(entered.await(1,TimeUnit.SECONDS),"exit writer was not in flight");
            zombie.characters.IsoPlayer.players[0]=null;poll();
            System.out.println("EXIT final unready state and ready identity queued");return;
        }
        check("blocked-filesystem-never-blocks-game-or-frame-sampling",()->blocked());
        if(args.length>1&&args[1].equals("blocked-only")) {if(failed>0)System.exit(1);return;}
        check("immutable-state-and-real-identity-survive-unready-exit",()->{
            CountDownLatch entered=new CountDownLatch(1),release=new CountDownLatch(1);
            AtomicInteger calls=new AtomicInteger();
            var writer=install("immutable",(path,sample)->{
                if(calls.getAndIncrement()==0){entered.countDown();try{release.await();}catch(InterruptedException interrupted){throw new IOException(interrupted);}}
                originalWrite(path,sample);
            });
            try {
                var body=zombie.characters.IsoPlayer.players[0];body.sqlId=37;body.label="First \"native\"\nname";body.x=123;
                poll();require(entered.await(1,TimeUnit.SECONDS),"first immutable sample not queued");
                var oldFrame=StudyParticipant.frame();body.sqlId=38;body.label="replacement";body.x=321;
                StudyParticipant.binding();require(!StudyParticipant.isCurrent(oldFrame.participant()),"changed SQL retained old frame authority");
                body.sqlId=37;
                zombie.characters.IsoPlayer.players[0]=null;poll();
                require(!StudyParticipant.isCurrent(oldFrame.participant()),"stale frame still has body authority");
                release.countDown();require(writer.close(2000),"immutable final samples not drained");
                Path dir=root.resolve("immutable");String state=Files.readString(dir.resolve("participant-state.json")),identity=Files.readString(dir.resolve("participant-identity.json"));
                require(state.contains("\"ready\":false")&&!state.contains("\"body\""),"exit state claims a present body");
                require(identity.contains("\"playerSqlId\":37")&&identity.contains("\"x\":123.0")&&identity.contains("First \\\"native\\\"\\u000aname"),"writer resampled or changed exact ready identity");
            } finally {release.countDown();}
        });
        check("sql-unassigned-publishes-observation-without-identity",()->{
            property(root.resolve("sql-unassigned/participant-state.json"));
            zombie.characters.IsoPlayer.players[0].sqlId=-1;poll();
            require(StudyParticipant.finishPublication(2000),"unready observation not drained");
            String state=Files.readString(root.resolve("sql-unassigned/participant-state.json"));
            require(state.contains("\"playerSqlId\":-1")&&state.contains("\"body\"")&&state.contains("\"ready\":false"),"observed unassigned native body concealed");
            require(!Files.exists(root.resolve("sql-unassigned/participant-identity.json")),"unassigned SQL gained real identity");
        });
        check("worker-bounded-sharing-retry-recovers",()->{
            AtomicInteger calls=new AtomicInteger();
            var writer=install("sharing-retry",(path,sample)->{
                require(Thread.currentThread().getName().equals("sao-participant-state"),"retry entered game thread");
                if(calls.incrementAndGet()<=2)throw new AccessDeniedException(path.toString());
                originalWrite(path,sample);
            });
            writer.offer("immutable retry sample",false);
            require(writer.close(2000),"finite sharing retry did not recover");
            require(calls.get()>=3&&calls.get()<=4,"retry/drain work was not bounded");
            require(Files.readString(root.resolve("sharing-retry/participant-state.json")).equals("immutable retry sample"),"retry changed source sample");
        });
        check("permanent-sharing-failure-is-finite-and-not-complete",()->{
            AtomicInteger calls=new AtomicInteger();
            var writer=install("persistent-sharing",(path,sample)->{calls.incrementAndGet();throw new AccessDeniedException(path.toString());});
            writer.offer("never published",false);long began=System.nanoTime();
            require(!writer.close(2000),"failed publication claimed completed drain");
            require(calls.get()<=2*StudyParticipant.StatePublisher.MAX_ATTEMPTS,"sharing retries exceeded two finite sampled/final attempts");
            require(TimeUnit.NANOSECONDS.toMillis(System.nanoTime()-began)<1000,"sharing failure did not stop finitely");
        });
        check("ordinary-io-error-is-not-a-sharing-retry",()->{
            AtomicInteger calls=new AtomicInteger();
            var writer=install("real-io-error",(path,sample)->{calls.incrementAndGet();throw new IOException("controlled disk write failure");});
            writer.offer("failed sample",false);
            require(!writer.close(2000),"real IOException was concealed");
            require(calls.get()<=2,"ordinary IO was retried as a sharing conflict");
        });
        check("later-real-sql-and-alive-status-refresh-identity",()->{
            property(root.resolve("real-sql-refresh/participant-state.json"));
            zombie.characters.IsoPlayer.players[0].sqlId=58;zombie.characters.IsoPlayer.players[0].dead=true;
            poll();require(StudyParticipant.finishPublication(2000),"latest real identity did not drain");
            String identity=Files.readString(root.resolve("real-sql-refresh/participant-identity.json"));
            require(identity.contains("\"playerSqlId\":58")&&identity.contains("\"alive\":false"),"latest SQL/life observation was replaced");
        });
        check("configuration-refuses-foreign-session-observer-and-relative-path",()->{
            property(root.resolve("configuration/participant-state.json"));
            System.setProperty("study.observer","true");boolean observer=false;
            try{StudyParticipant.configure();}catch(IllegalStateException expected){observer=true;}System.clearProperty("study.observer");
            System.setProperty("study.participantSession",SESSION.toUpperCase(Locale.ROOT));boolean session=false;
            try{StudyParticipant.configure();}catch(IllegalArgumentException expected){session=true;}
            System.setProperty("study.participantSession",SESSION);System.setProperty("study.participantState","relative.json");boolean relative=false;
            try{StudyParticipant.configure();}catch(IllegalArgumentException expected){relative=true;}
            require(observer&&session&&relative,"configuration admitted invalid producer identity");
        });
        System.out.println("checks="+count+"; pass="+(count-failed)+"; failures="+failed);
        if(failed>0)System.exit(1);
    }
}
'''

ORIGINAL_PROBE = r'''
import java.nio.file.*;
public final class OriginalParticipantSharing04Probe {
    public static void main(String[] args) throws Exception {
        Path state=Path.of(args[0]);
        System.setProperty("study.participantSession","12345678-1234-1234-1234-123456789abc");
        System.setProperty("study.attempt","1");System.setProperty("study.participantState",state.toString());
        zombie.characters.IsoPlayer.players[0]=new zombie.characters.IsoPlayer();
        zombie.iso.IsoWorld.instance.currentCell=new zombie.iso.IsoCell();zombie.core.Core.gameSaveWorld="Publisher04Fixture";
        StudyParticipant.configure();StudyParticipant.poll();
        if(!Files.readString(state).equals("original sentinel"))throw new AssertionError("known-bad source did not retain rejected state");
        if(Files.exists(state.resolveSibling("participant-identity.json")))throw new AssertionError("known-bad source unexpectedly published identity");
        System.out.println("CONTROL PASS original-windows-sharing-rejection");
    }
}
'''

LOCKER = r'''
param([string]$Target,[string]$Ready,[string]$Release)
$stream = [System.IO.File]::Open($Target,[System.IO.FileMode]::Open,[System.IO.FileAccess]::Read,[System.IO.FileShare]::Read)
try {
    [System.IO.File]::WriteAllText($Ready,'ready')
    $limit = [DateTime]::UtcNow.AddSeconds(20)
    while (!(Test-Path -LiteralPath $Release) -and [DateTime]::UtcNow -lt $limit) { [System.Threading.Thread]::Sleep(5) }
} finally { $stream.Dispose() }
'''


def pin(path: Path) -> dict:
    data = path.read_bytes()
    return {"path": str(path), "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def run(output: Path) -> int:
    output.mkdir(parents=True, exist_ok=False)
    if pin(PREIMAGE)["sha256"] != PREIMAGE_SHA:
        raise ValueError("immutable publisher preimage differs")
    source = output / "source-snapshot"
    source.mkdir()
    live_sources = [ROOT / "tools/world_lab" / name for name in Fixture.COHORTS["participant"]]
    before = [pin(path) for path in live_sources]
    for path, stamp in zip(live_sources, before):
        raw = path.read_bytes()
        if hashlib.sha256(raw).hexdigest() != stamp["sha256"]:
            raise ValueError("Java input changed while snapshotting: " + str(path))
        (source / path.name).write_bytes(raw)
    owned_before = [pin(ROOT / "tools/world_lab/StudyParticipant.java"), pin(Path(__file__))]
    dependencies = [Fixture.GAME / name for name in ["projectzomboid.jar", "ZombieBuddy.jar"]]
    dependencies += [Fixture.JDK / name for name in ["javac.exe", "java.exe", "jar.exe"]]
    dependency_before = [pin(path) for path in dependencies]
    results: list[dict] = []

    def command(label: str, args: list, expected: int = 0, timeout: int = 60):
        stdout = output / (label + ".stdout.log")
        stderr = output / (label + ".stderr.log")
        with stdout.open("xb") as out, stderr.open("xb") as err:
            result = subprocess.run(list(map(str, args)), stdout=out, stderr=err, timeout=timeout,
                                    creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        controls = re.findall(r"^CONTROL (PASS|FAIL) (.*)$", stdout.read_text(), re.M)
        row = {"label": label, "command": list(map(str, args)), "exitCode": result.returncode,
               "expectedExitCode": expected, "passed": result.returncode == expected,
               "stdout": pin(stdout), "stderr": pin(stderr),
               "controls": [{"status": state, "name": name} for state, name in controls]}
        results.append(row)
        print(json.dumps({"label": label, "exitCode": result.returncode, "expectedExitCode": expected}), flush=True)
        return row

    jars = [Fixture.GAME / "projectzomboid.jar", Fixture.GAME / "ZombieBuddy.jar"]
    installed_cp = os.pathsep.join(map(str, jars))
    for cohort, names in Fixture.COHORTS.items():
        classes = output / (cohort + "-classes")
        classes.mkdir()
        command(cohort + "-compile", [Fixture.JDK / "javac.exe", "-cp", installed_cp, "-d", classes,
                                     *[source / name for name in names]])
    stubs, stub_classes = output / "stub-source", output / "stub-classes"
    stub_classes.mkdir()
    for name, body in Fixture.STUBS.items():
        path = stubs / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(body, encoding="utf-8")
    command("synthetic-stubs-compile", [Fixture.JDK / "javac.exe", "-cp", installed_cp, "-d", stub_classes,
                                        *sorted(stubs.rglob("*.java"))])
    cp = os.pathsep.join(map(str, [stub_classes, output / "participant-classes", *jars]))
    probe = output / "ParticipantPublisher04Probe.java"
    probe.write_text(PROBE, encoding="utf-8")
    command("publisher-probe-compile", [Fixture.JDK / "javac.exe", "-cp", cp, "-d", stub_classes, probe])
    if all(row["passed"] for row in results):
        command("publisher-controls", [Fixture.JDK / "java.exe", "-Djava.awt.headless=true", "-cp", cp,
                                       "ParticipantPublisher04Probe", output / "controlled-fixture"])
        exit_root = output / "shutdown-fixture"
        row = command("normal-jvm-exit-drain", [Fixture.JDK / "java.exe", "-cp", cp,
                                               "ParticipantPublisher04Probe", exit_root, "shutdown-hook"])
        exit_state = exit_root / "exit/participant-state.json"
        exit_identity = exit_root / "exit/participant-identity.json"
        if exit_state.is_file() and exit_identity.is_file():
            state, identity = json.loads(exit_state.read_text()), json.loads(exit_identity.read_text())
            row["sourceAssertions"] = {"finalStateUnready": state["ready"] is False and "body" not in state,
                                     "lastReadyIdentity": identity["ready"] is True and identity["playerSqlId"] == 23
                                     and identity["body"]["x"] == 456.0,
                                     "stateAndIdentity": [pin(exit_state), pin(exit_identity)]}
            row["passed"] = row["passed"] and row["sourceAssertions"]["finalStateUnready"] and row["sourceAssertions"]["lastReadyIdentity"]
        else:
            row["passed"] = False
            row["sourceAssertions"] = {"finalStateUnready": False, "lastReadyIdentity": False}
        manifest = output / "agent.mf"
        manifest.write_text("Manifest-Version: 1.0\nPremain-Class: StudyLoadingAgent\nCan-Retransform-Classes: true\n\n")
        command("participant-agent-package", [Fixture.JDK / "jar.exe", "cfm", output / "StudyLoadingAgent.jar",
                                               manifest, "-C", output / "participant-classes", "."])
        mutated = output / "restored-blocking-source"
        mutated.mkdir()
        text = (source / "StudyParticipant.java").read_text()
        old = 'writer.offer(json(body, now) + "\\n", body != null && body.ready());'
        new = '''String sample = json(body, now) + "\\n";
        writer.offer(sample, body != null && body.ready());
        long deadline = System.nanoTime() + 2_000_000_000L;
        while (!sample.equals(writer.writtenState) && System.nanoTime() < deadline) {
            try { Thread.sleep(25); } catch (InterruptedException interrupted) { Thread.currentThread().interrupt(); break; }
        }'''
        if text.count(old) != 1:
            raise ValueError("blocking control mutation did not land exactly once")
        (mutated / "StudyParticipant.java").write_text(text.replace(old, new), encoding="utf-8")
        mutated_classes = output / "restored-blocking-classes"
        mutated_classes.mkdir()
        command("restored-blocking-compile", [Fixture.JDK / "javac.exe", "-cp", cp, "-d", mutated_classes,
                                              mutated / "StudyParticipant.java"])
        mutant_cp = os.pathsep.join(map(str, [mutated_classes, stub_classes, output / "participant-classes", *jars]))
        command("restored-blocking-rejected", [Fixture.JDK / "java.exe", "-Djava.awt.headless=true", "-cp", mutant_cp,
                                               "ParticipantPublisher04Probe", output / "blocking-fixture", "blocked-only"], expected=1)
        no_drain = output / "removed-shutdown-drain-source"
        no_drain.mkdir()
        hook = 'Runtime.getRuntime().addShutdownHook(new Thread(() -> {'
        if text.count(hook) != 1:
            raise ValueError("shutdown-drain mutation did not land exactly once")
        (no_drain / "StudyParticipant.java").write_text(text.replace(hook, 'if (false) ' + hook), encoding="utf-8")
        no_drain_classes = output / "removed-shutdown-drain-classes"
        no_drain_classes.mkdir()
        command("removed-shutdown-drain-compile", [Fixture.JDK / "javac.exe", "-cp", cp, "-d", no_drain_classes,
                                                    no_drain / "StudyParticipant.java"])
        no_drain_cp = os.pathsep.join(map(str, [no_drain_classes, stub_classes, output / "participant-classes", *jars]))
        missing_root = output / "removed-shutdown-drain-fixture"
        row = command("removed-shutdown-drain-rejected", [Fixture.JDK / "java.exe", "-cp", no_drain_cp,
                                                           "ParticipantPublisher04Probe", missing_root, "shutdown-hook"])
        row["sourceAssertions"] = {"queuedMarker": "EXIT final unready state and ready identity queued" in Path(row["stdout"]["path"]).read_text(),
                                 "finalFilesAbsent": not (missing_root / "exit/participant-state.json").exists()
                                 and not (missing_root / "exit/participant-identity.json").exists()}
        row["passed"] = row["passed"] and all(row["sourceAssertions"].values())

        original_classes = output / "original-classes"
        original_classes.mkdir()
        original_source = output / "original-source"
        original_source.mkdir()
        (original_source / "StudyParticipant.java").write_bytes(PREIMAGE.read_bytes())
        original_probe = original_source / "OriginalParticipantSharing04Probe.java"
        original_probe.write_text(ORIGINAL_PROBE, encoding="utf-8")
        command("original-sharing-source-compile", [Fixture.JDK / "javac.exe", "-cp", cp, "-d", original_classes,
                                                     original_source / "StudyParticipant.java", original_probe])
        locker_path = output / "windows-sharing-lock.ps1"
        locker_path.write_text(LOCKER, encoding="utf-8")
        for version in ["original", "current"]:
            fixture = output / (version + "-windows-sharing")
            fixture.mkdir()
            state, ready, release = fixture / "participant-state.json", fixture / "locked", fixture / "release"
            state.write_text("original sentinel")
            with (fixture / "locker.stdout.log").open("xb") as out, (fixture / "locker.stderr.log").open("xb") as err:
                locker = subprocess.Popen(["powershell.exe", "-NoProfile", "-NonInteractive", "-File", str(locker_path),
                                           "-Target", str(state), "-Ready", str(ready), "-Release", str(release)],
                                          stdout=out, stderr=err, creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
                try:
                    deadline = time.monotonic() + 10
                    while not ready.exists() and locker.poll() is None and time.monotonic() < deadline:
                        time.sleep(0.01)
                    if not ready.exists():
                        raise ValueError("actual Windows file-sharing control did not acquire its handle")
                    if version == "original":
                        original_cp = os.pathsep.join(map(str, [original_classes, stub_classes, output / "participant-classes", *jars]))
                        row = command("original-windows-sharing", [Fixture.JDK / "java.exe", "-cp", original_cp,
                                                                  "OriginalParticipantSharing04Probe", state])
                        row["accessDeniedObserved"] = "AccessDeniedException" in Path(row["stderr"]["path"]).read_text()
                        row["passed"] = row["passed"] and row["accessDeniedObserved"]
                    else:
                        command("current-windows-sharing", [Fixture.JDK / "java.exe", "-cp", cp,
                                                            "ParticipantPublisher04Probe", fixture, "actual-sharing"])
                finally:
                    release.write_text("release")
                    locker.wait(timeout=10)
                if locker.returncode != 0:
                    raise ValueError("actual sharing locker did not close normally")
    owned_after = [pin(ROOT / "tools/world_lab/StudyParticipant.java"), pin(Path(__file__))]
    dependency_after = [pin(path) for path in dependencies]
    passed = all(row["passed"] for row in results) and owned_before == owned_after and dependency_before == dependency_after
    receipt = {"schema": "sao.participant-state-publisher-controlled/1", "status": "PASS" if passed else "FAIL",
               "scope": "actual installed cohort compilation/package; synthetic engine fixtures and actual Windows sharing denial; no game or playable acceptance",
               "sourceSnapshot": before, "ownedBefore": owned_before, "ownedAfter": owned_after,
               "liveSourceAfter": [pin(path) for path in live_sources], "dependenciesBefore": dependency_before,
               "dependenciesAfter": dependency_after, "preimage": pin(PREIMAGE), "results": results,
               "fixtures": [pin(path) for path in [probe, output / "original-source/OriginalParticipantSharing04Probe.java",
                                                  output / "restored-blocking-source/StudyParticipant.java",
                                                  output / "removed-shutdown-drain-source/StudyParticipant.java"] if path.is_file()]}
    (output / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"status": receipt["status"], "receipt": pin(output / "receipt.json")}), flush=True)
    return 0 if passed else 1


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    raise SystemExit(run(args.output.resolve()))
