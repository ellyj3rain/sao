"""Qualify actual participant poll/cache/frame methods with injected clocks.

Nine participant and five observer sources compile against installed jars.
Explicit engine fixtures execute that compiled producer and its unchanged helper
and StatePublisher. Restored and inverse controls stay in ignored evidence.
"""
from __future__ import annotations

import argparse
import ast
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
GAME = Path(os.environ.get("PZ_DIR", "C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid"))
JDK = Path(os.environ.get("JDK_BIN", str(Path.home()/"Peanut Butter/JetBrains/Java/bin")))
ALLOWED = ROOT/"_scratch/d2-leisure-01/participant-integration21/native-play04/resolution12/start-cache12"
PREIMAGE_SHA = "f5c268243425223178b4a64692f8c641cab9f7f86148444b0c2ce97f9fcc5734"
HELPER_SHA = "5c3d24699029fde969bec156ff93a93fa6db0cb17c6a856afd72e2317dae1139"

PROBE = r'''
import java.lang.reflect.Field;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.atomic.AtomicLong;
import java.util.function.LongSupplier;
import se.krka.kahlua.j2se.KahluaTableImpl;
import se.krka.kahlua.vm.KahluaTable;
import zombie.characters.IsoPlayer;
import zombie.core.Core;

public final class StartCache12Probe {
 static final AtomicLong wall=new AtomicLong(),tick=new AtomicLong();
 static Path output,fixture; static IsoPlayer player;
 static int checks,failures,errors;
 interface Run {void run() throws Exception;}
 static void require(boolean value,String message){if(!value)throw new AssertionError(message);}
 static void set(String name,Object value)throws Exception{
  Field f=StudyParticipant.class.getDeclaredField(name);f.setAccessible(true);f.set(null,value);
 }
 static Object get(String name)throws Exception{
  Field f=StudyParticipant.class.getDeclaredField(name);f.setAccessible(true);return f.get(null);
 }
 static Object watermark()throws Exception{
  try{return get("captureWatermarkSample");}
  catch(NoSuchFieldException preimageHasNoWatermark){return null;}
 }
 static KahluaTableImpl table(Object... pairs){
  Map<Object,Object> map=new LinkedHashMap<>();
  for(int i=0;i<pairs.length;i+=2)map.put(pairs[i],pairs[i+1]);
  return new KahluaTableImpl(map);
 }
 static KahluaTableImpl data(){return table("WhereIWas",table(
  "scenario","tourist","lifecycleVersion",3.0,"kitVersion",3.0,
  "lifecycleState","ready","setupComplete",true,"setupFailed",false,
  "lifecycleProtected",false),"TIYL",table("originId","rosewood"));}
 static void reset(String name)throws Exception{
  wall.set(10000);tick.set(1000000000);
  set("wallClock",(LongSupplier)wall::get);set("elapsedClock",(LongSupplier)tick::get);
  System.clearProperty("study.observer");System.setProperty("study.nativePlay","true");
  System.setProperty("study.participantSession","12345678-1234-1234-1234-123456789abc");
  System.setProperty("study.attempt","1");fixture=output.resolve(name);Files.createDirectories(fixture);
  System.setProperty("study.participantState",fixture.resolve("participant-state.json").toString());
  Core.gameSaveWorld="FixtureSave";Core.mode="Sandbox";Core.currentTextEntryBox=null;
  zombie.ZomboidFileSystem.instance.directory=null;
  org.lwjglx.opengl.Display.active=true;org.lwjglx.opengl.Display.fail=false;
  zombie.GameTime.hours=25.5;zombie.iso.IsoWorld.instance.currentCell=new zombie.iso.IsoCell();
  player=new IsoPlayer();player.modData=data();IsoPlayer.players[0]=player;
  StudyParticipant.configure();
 }
 static void test(String name,Run action)throws Exception{
  checks++;
  try{reset(name);action.run();System.out.println("CONTROL PASS "+name);}
  catch(AssertionError failure){failures++;System.out.println("CONTROL FAIL "+name+" :: "+failure.getMessage());}
  catch(Throwable failure){errors++;System.out.println("CONTROL ERROR "+name+" :: "+failure);}
  finally{if(!StudyParticipant.finishPublication(2000)){errors++;System.out.println("CONTROL ERROR "+name+" :: publisher failed to drain");}}
 }
 static StudyParticipant.StartSample sample()throws Exception{return (StudyParticipant.StartSample)get("latestStart");}
 static String context(){return StudyParticipant.startContext(StudyParticipant.binding(),wall.get(),Core.mode);}
 static String frame(){var f=StudyParticipant.frame();return f==null?null:f.participant().json();}
 static boolean includes(String value){return value!=null&&value.contains("\"startContext\":");}
 static void advance(long millis){wall.addAndGet(millis);tick.addAndGet(millis*1000000);}
 static StudyParticipant.Binding body(Object owner,int slot,int sql,String save,int attempt,double hour){
  return new StudyParticipant.Binding(owner,slot,sql,save,attempt,hour,true,10,20,0,"Controlled",true);
 }
 static String context(StudyParticipant.Binding body,String mode){return StudyParticipant.startContext(body,wall.get(),mode);}
 static class SlowPlayer extends IsoPlayer {
  boolean slow=true;
  @Override public KahluaTable getModData(){if(slow)tick.addAndGet(301000000);return super.getModData();}
 }
 public static void main(String[]args)throws Exception{
  output=Path.of(args[0]);Files.createDirectories(output);
  test("initial-native-sample",()->{
   StudyParticipant.poll();var s=sample();
   require(s!=null&&s.owner()==player&&s.observedAt()==10000&&s.worldHours()==25.5,"source clocks or owner lost");
   require(context()!=null&&context().contains("\"scenarioReady\":true"),"actual helper result missing");
   require(player.modDataReads==1,"poll must observe helper once");
  });
  test("bounded-render-reuse",()->{
   StudyParticipant.poll();String saved=context();
   for(int i=0;i<3;i++){advance(100);require(saved.equals(context())&&includes(frame()),"fresh immutable cache changed");}
   require(player.modDataReads==1,"render/cache reread Lua tables");
  });
  test("elapsed-expiry-with-frozen-wall",()->{
   StudyParticipant.poll();tick.addAndGet(300000001);
   require(context()==null&&!includes(frame()),"stalled cache admitted beyond 300 ms elapsed");
   require(player.modDataReads==1,"expiry performed a render-path Lua read");
  });
  test("unix-expiry-with-fresh-elapsed",()->{
   StudyParticipant.poll();wall.addAndGet(301);tick.incrementAndGet();
   require(context()==null&&!includes(frame()),"old raw Unix sample admitted");
  });
  test("unix-future-sample",()->{
   StudyParticipant.poll();wall.decrementAndGet();tick.incrementAndGet();
   require(context()==null&&!includes(frame()),"future Unix sample admitted");
  });
  test("elapsed-future-sample",()->{
   StudyParticipant.poll();tick.decrementAndGet();
   require(context()==null&&!includes(frame()),"future elapsed sample admitted");
  });
  test("unix-capture-watermark-regression",()->{
   StudyParticipant.poll();advance(20);require(context()!=null,"normal watermark advance");
   wall.addAndGet(-10);tick.addAndGet(10000000);
   require(context()==null&&!includes(frame()),"regressed capture admitted after sample timestamp");
  });
  test("elapsed-capture-watermark-regression",()->{
   StudyParticipant.poll();advance(20);require(context()!=null,"normal elapsed advance");
   tick.addAndGet(-10000000);wall.incrementAndGet();
   require(context()==null&&!includes(frame()),"regressed elapsed capture admitted after sample tick");
  });
  test("monotonic-cadence-after-wall-rollback",()->{
   StudyParticipant.poll();wall.set(5000);tick.addAndGet(99999999);StudyParticipant.poll();
   require(player.modDataReads==1,"sampled before 100 ms interval");
   tick.incrementAndGet();StudyParticipant.poll();
   require(player.modDataReads==2&&sample().observedAt()==5000,"wall rollback suspended native polling");
   require(context()!=null&&includes(frame()),"fresh rollback generation not usable locally");
   require(frame().contains("\"capturedAtUnixMs\":5000"),"rollback timestamp corrected or invented");
   advance(100);StudyParticipant.poll();require(player.modDataReads==3,"cadence did not continue after rollback");
  });
  test("wall-jump-does-not-accelerate-poll",()->{
   StudyParticipant.poll();wall.addAndGet(86400000);tick.incrementAndGet();StudyParticipant.poll();
   require(player.modDataReads==1,"wall jump accelerated native sampling");
   require(!includes(frame()),"old sample survives raw wall jump");
   tick.addAndGet(99999999);StudyParticipant.poll();require(player.modDataReads==2&&includes(frame()),"new due sample not recovered");
  });
  test("no-catchup-burst-after-stall",()->{
   StudyParticipant.poll();advance(10000);require(!includes(frame()),"stall failed to withhold old context");
   StudyParticipant.poll();for(int i=0;i<40;i++)StudyParticipant.poll();
   require(player.modDataReads==2&&includes(frame()),"resumed poll replayed missed intervals or failed to sample");
  });
  test("negative-nano-origin",()->{
   tick.set(-1000000000);StudyParticipant.poll();advance(99);StudyParticipant.poll();
   require(player.modDataReads==1,"negative nano origin changes interval");
   advance(1);StudyParticipant.poll();require(player.modDataReads==2&&context()!=null,"negative nano clock cannot sample");
  });
  test("zero-nano-origin",()->{
   tick.set(0);StudyParticipant.poll();StudyParticipant.poll();
   require(player.modDataReads==1,"zero tick confused initialized state");
   advance(100);StudyParticipant.poll();require(player.modDataReads==2,"zero-origin interval did not resume");
  });
  test("signed-nano-wrap",()->{
   tick.set(Long.MAX_VALUE-50000000);StudyParticipant.poll();advance(100);StudyParticipant.poll();
   require(tick.get()<0&&player.modDataReads==2&&context()!=null,"signed nano wrap stops cadence or cache");
  });
  test("regressed-injected-nano-reschedules",()->{
   StudyParticipant.poll();tick.addAndGet(-100000000);wall.incrementAndGet();StudyParticipant.poll();
   require(player.modDataReads==2&&context()!=null,"regressed scheduler clock suspends native polling");
   advance(100);StudyParticipant.poll();require(player.modDataReads==3,"reset clock failed next interval");
  });
  test("slow-native-helper-result-withheld",()->{
   SlowPlayer slow=new SlowPlayer();slow.modData=data();player=slow;IsoPlayer.players[0]=slow;
   StudyParticipant.poll();require(player.modDataReads==1,"slow helper not sampled once");
   require(!includes(frame())&&context()==null,"helper stall restamped an expired observation");
   require(StudyParticipant.finishPublication(2000),"actual writer did not drain");
   String stored=Files.readString(fixture.resolve("participant-state.json"));
   require(!includes(stored),"publisher admitted start context already stale after helper");
   slow.slow=false;StudyParticipant.configure();StudyParticipant.poll();
   require(player.modDataReads==2&&includes(frame()),"slow helper recovery did not resample");
  });
  test("body-turnover-does-not-leak-cache",()->{
   StudyParticipant.poll();var oldFrame=StudyParticipant.frame();
   IsoPlayer replacement=new IsoPlayer();replacement.modData=data();IsoPlayer.players[0]=replacement;
   require(!includes(frame())&&!StudyParticipant.isCurrent(oldFrame.participant()),"foreign native body inherited old cache/frame");
   advance(100);StudyParticipant.poll();require(replacement.modDataReads==1&&includes(frame()),"new owner did not get its own sample");
  });
  test("foreign-owner-refused",()->{
   StudyParticipant.poll();require(context(body(new Object(),0,1,"FixtureSave",1,25.5),"Sandbox")==null,"foreign owner admitted");
  });
  test("foreign-slot-refused",()->{
   StudyParticipant.poll();require(context(body(player,1,1,"FixtureSave",1,25.5),"Sandbox")==null,"foreign slot admitted");
  });
  test("foreign-sql-refused",()->{
   StudyParticipant.poll();require(context(body(player,0,2,"FixtureSave",1,25.5),"Sandbox")==null,"foreign SQL identity admitted");
  });
  test("foreign-save-refused",()->{
   StudyParticipant.poll();require(context(body(player,0,1,"OtherSave",1,25.5),"Sandbox")==null,"foreign save admitted");
  });
  test("foreign-mode-refused",()->{
   StudyParticipant.poll();require(context(StudyParticipant.binding(),"Rising")==null,"foreign mode admitted");
  });
  test("foreign-attempt-refused",()->{
   StudyParticipant.poll();require(context(body(player,0,1,"FixtureSave",2,25.5),"Sandbox")==null,"foreign attempt admitted");
  });
  test("world-clock-regression-refused",()->{
   StudyParticipant.poll();zombie.GameTime.hours=25.4;
   require(context()==null&&!includes(frame()),"future world-hour sample admitted");
  });
  test("nonfinite-world-clock-refused",()->{
   StudyParticipant.poll();require(context(body(player,0,1,"FixtureSave",1,Double.NaN),"Sandbox")==null,"nonfinite body clock admitted");
  });
  test("unbound-clears-current-not-ready-identity",()->{
   StudyParticipant.poll();IsoPlayer.players[0]=null;advance(100);StudyParticipant.poll();
   require(sample()==null&&frame()==null&&watermark()==null,"unbound body retained current sample or watermark owner");
   require(StudyParticipant.finishPublication(2000),"writer did not drain");
   String state=Files.readString(fixture.resolve("participant-state.json"));
   String identity=Files.readString(fixture.resolve("participant-identity.json"));
   require(state.contains("\"ready\":false")&&!includes(state),"unbound current state not published honestly");
   require(identity.contains("\"ready\":true")&&identity.contains("FixtureSave"),"unbound state replaced last ready identity");
  });
  test("absent-cache-stays-unknown",()->{
   require(context()==null&&!includes(frame())&&player.modDataReads==0,"cache lookup created an observation");
  });
  test("native-play-off-clears-cache",()->{
   StudyParticipant.poll();System.clearProperty("study.nativePlay");advance(100);StudyParticipant.poll();
   require(sample()==null&&!includes(frame())&&player.modDataReads==1&&watermark()==null,"observer path retained native cache or watermark owner");
  });
  test("attempt-reconfiguration-clears-cache",()->{
   StudyParticipant.poll();System.setProperty("study.attempt","2");StudyParticipant.configure();
   require(sample()==null&&!includes(frame()),"reconfigured attempt retained cache");
   StudyParticipant.poll();require(sample().attempt()==2&&includes(frame()),"new attempt not sampled immediately");
  });
  test("missing-writer-does-not-observe-tables",()->{
   Object writer=get("publisher");set("publisher",null);
   try{StudyParticipant.poll();require(player.modDataReads==0&&sample()==null,"writerless hook sampled Lua");}
   finally{set("publisher",writer);}
  });
  System.out.println("COUNTS checks="+checks+"; failures="+failures+"; errors="+errors);
  if(failures!=0||errors!=0)System.exit(1);
 }
}
'''


def pin(path: Path) -> dict:
    data=path.read_bytes()
    return {"path":str(path),"bytes":len(data),"sha256":hashlib.sha256(data).hexdigest()}


def literal(path: Path, names: set[str]) -> dict:
    found={}
    for node in ast.parse(path.read_text(encoding="utf-8-sig")).body:
        if isinstance(node,ast.Assign):
            for target in node.targets:
                if isinstance(target,ast.Name) and target.id in names:
                    found[target.id]=ast.literal_eval(node.value)
    if set(found)!=names:raise ValueError(f"Missing literal declarations: {path}")
    return found


def replaced(source: str, old: str, new: str) -> str:
    if source.count(old)!=1:raise ValueError(f"Inverse anchor not unique: {old[:100]}")
    return source.replace(old,new,1)


def run(output: Path, preimage: Path, cohort: Path|None) -> int:
    if ALLOWED.resolve() not in output.parents or output.exists():
        raise ValueError("Use a fresh evidence sibling under resolution12/start-cache12")
    output.mkdir(parents=True)
    declarations_file=ROOT/"tools/world_lab_run.py"
    stub_file=ROOT/"tools/world_lab_participant_java_test.py"
    declarations=literal(declarations_file,{"PARTICIPANT_SOURCES","OBSERVER_SOURCES"})
    if len(declarations["PARTICIPANT_SOURCES"])!=9 or len(declarations["OBSERVER_SOURCES"])!=5:
        raise ValueError("Current expected eight/five native cohort changed")
    stubs=literal(stub_file,{"STUBS"})["STUBS"]
    sources=[ROOT/"tools/world_lab"/name for name in sorted(set(sum((list(v) for v in declarations.values()),[])))]
    files=sources+[declarations_file,stub_file,Path(__file__).resolve()]
    source_before=[pin(p) for p in files]
    helper=ROOT/"tools/world_lab/StudyStartContext.java"
    if pin(helper)["sha256"]!=HELPER_SHA or pin(preimage)["sha256"]!=PREIMAGE_SHA:
        raise ValueError("Exact authorized helper or preimage differs")
    dependencies=[GAME/"projectzomboid.jar",GAME/"ZombieBuddy.jar",JDK/"javac.exe",JDK/"java.exe"]
    receipt={"schema":"sao.native-start-cache-resolution12/1","observedAtUtc":datetime.now(timezone.utc).isoformat(),
             "scope":"Actual compiled production poll/cache/frame/helper/publisher under explicit engine fixtures and injected system-clock suppliers.",
             "nativeGameStarted":False,"saveMutation":False,"sourcePins":source_before,"dependencies":[pin(p) for p in dependencies],
             "preimage":pin(preimage),"results":[],"variants":[],"policy":{"producerMinimumIntervalMs":100,"cacheMaximumAgeMs":300,
             "cacheClockGuards":"Elapsed and raw Unix age; nonregressing capture watermark per observed sample; exact binding and world clock.",
             "rateAssumption":"Only actual native logic exits with at least 100 ms elapsed; no catchup or achieved 10 Hz claim."},
             "limits":["Controlled fixtures do not establish native cadence, FPS, lag, rendered start or gameplay acceptance.",
                       "Cache-local watermark resets on actual observation; whole-frame Unix regression may still be quarantined by the consumer.",
                       "Helper/input/publication/capture sources remain unchanged; cache/frame queries never read start tables."]}
    frozen=output/"frozen";frozen.mkdir()
    for path in files:(frozen/path.name).write_bytes(path.read_bytes())
    if cohort is not None:
        cohort_receipt=cohort/"receipt.json"
        for row in json.loads(cohort_receipt.read_text(encoding="utf-8"))["sourcePins"]:
            path=Path(row["path"])
            if path.is_file() and pin(path)["sha256"]!=row["sha256"]:
                raise ValueError(f"Provided cohort no longer current: {path}")
        receipt["providedCohortReceipt"]=pin(cohort_receipt)
    reusable=ROOT/"_scratch/d2-leisure-01/participant-integration21/native-play04/start-compatibility04/text-safe08/qualification02/receipt.json"
    previous=json.loads(reusable.read_text(encoding="utf-8"))
    if previous["status"]!="PASS" or not any(Path(r["path"]).name==helper.name and r["sha256"]==HELPER_SHA for r in previous["sourcePins"]):
        raise ValueError("Unchanged helper 43-own-key proof no longer reusable")
    receipt["reusedHelperProof"]={**pin(reusable),"scope":"Exact unchanged helper: text safety, 43 own-key reads, small/large tables and inverse controls."}
    cp=os.pathsep.join(str(p) for p in dependencies[:2])

    def command(label: str, args: list, expected: int=0) -> str:
        result=subprocess.run(list(map(str,args)),text=True,encoding="utf-8",errors="replace",capture_output=True,timeout=120,
                              creationflags=getattr(subprocess,"CREATE_NO_WINDOW",0))
        stdout=output/(label+".stdout.txt");stderr=output/(label+".stderr.txt")
        stdout.write_text(result.stdout,encoding="utf-8");stderr.write_text(result.stderr,encoding="utf-8")
        receipt["results"].append({"label":label,"command":list(map(str,args)),"exitCode":result.returncode,"expectedExitCode":expected,
                                   "stdout":pin(stdout),"stderr":pin(stderr)})
        if result.returncode!=expected:raise RuntimeError(f"{label}: exit {result.returncode}, expected {expected}; {result.stderr[:800]}")
        return result.stdout

    def probe(label: str, participant_source: str|None, expected_failures: set[str]) -> dict:
        target=output/label;target.mkdir();classes=target/"classes";classes.mkdir()
        local=target/"StudyParticipant.java"
        if participant_source is not None:
            local.write_text(participant_source,encoding="utf-8")
            command(label+"-participant-compile",[JDK/"javac.exe","-cp",participant_cp,"-d",classes,local])
        runtime_cp=os.pathsep.join((str(stub_classes),str(classes),str(participant_classes),cp))
        command(label+"-probe-compile",[JDK/"javac.exe","-cp",runtime_cp,"-d",classes,probe_source])
        stdout=command(label+"-probe-run",[JDK/"java.exe","-Djava.awt.headless=true","-cp",runtime_cp,"StartCache12Probe",target/"fixtures"],
                       1 if expected_failures else 0)
        controls=[{"status":status,"name":name} for status,name in re.findall(r"^CONTROL (PASS|FAIL|ERROR) ([^\s:]+)",stdout,re.M)]
        failed={row["name"] for row in controls if row["status"]=="FAIL"}
        counts=re.search(r"^COUNTS checks=(\d+); failures=(\d+); errors=(\d+)$",stdout,re.M)
        if counts is None or tuple(map(int,counts.groups()))!=(len(controls),len(failed),0):
            raise RuntimeError(f"{label}: control lines differ from producer's reported counts")
        if len({row["name"] for row in controls})!=len(controls):
            raise RuntimeError(f"{label}: duplicate controls")
        if any(row["status"]=="ERROR" for row in controls) or not expected_failures<=failed or not controls:
            raise RuntimeError(f"{label}: missing specific failures or fixture error: {failed}")
        row={"label":label,"source":pin(local) if participant_source is not None else pin(frozen/"StudyParticipant.java"),
             "tests":len(controls),"passed":sum(row["status"]=="PASS" for row in controls),"failed":len(failed),"errors":0,
             "requiredFailures":sorted(expected_failures),"controls":controls}
        receipt["variants"].append(row)
        print(json.dumps({key:row[key] for key in ("label","tests","passed","failed","errors")}),flush=True)
        return row

    try:
        for label,names in declarations.items():
            target=output/label.lower();target.mkdir()
            command(label.lower()+"-compile",[JDK/"javac.exe","-cp",cp,"-d",target,*[frozen/name for name in names]])
        participant_classes=output/"participant_sources"
        participant_cp=os.pathsep.join((str(participant_classes),cp))
        stub_source=output/"stub-source";stub_classes=output/"stub-classes";stub_classes.mkdir()
        for name,body in stubs.items():
            path=stub_source/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_text(body,encoding="utf-8")
        command("stubs-compile",[JDK/"javac.exe","-cp",cp,"-d",stub_classes,*sorted(stub_source.rglob("*.java"))])
        probe_source=output/"StartCache12Probe.java";probe_source.write_text(PROBE,encoding="utf-8")
        receipt["probe"]=pin(probe_source)
        probe("exact-production",None,set())
        original=(frozen/"StudyParticipant.java").read_text(encoding="utf-8")
        restored=preimage.read_text(encoding="utf-8")
        restored=replaced(restored,"private StudyParticipant() { }",
            "private static java.util.function.LongSupplier wallClock = System::currentTimeMillis;\n"
            "    private static java.util.function.LongSupplier elapsedClock = System::nanoTime;\n"
            "    private StudyParticipant() { }")
        restored=restored.replace("System.currentTimeMillis()","wallClock.getAsLong()")
        receipt["preimageClockInstrumentation"]="Only injectable suppliers/currentTimeMillis call replacement; original scheduler/cache/publication logic retained."
        probe("restored-preimage",restored,{"elapsed-expiry-with-frozen-wall","unix-expiry-with-fresh-elapsed",
              "monotonic-cadence-after-wall-rollback","unix-capture-watermark-regression"})
        inverse={
            "wall-deadline":(replaced(replaced(original,"private static long lastStateTick;","private static long lastStateTick, restoredWallDeadline;"),
                "long elapsed = tick - lastStateTick;\n        if (stateSampled && elapsed >= 0 && elapsed < STATE_INTERVAL_NANOS) return;",
                "if (!stateSampled) restoredWallDeadline = 0;\n        if (now < restoredWallDeadline) return;\n        restoredWallDeadline = now + 100;"),
                {"monotonic-cadence-after-wall-rollback","wall-jump-does-not-accelerate-poll"}),
            "no-elapsed-expiry":(replaced(original,"if (age < 0 || age > START_MAX_AGE_NANOS) return null;","if (age < 0) return null;"),
                {"elapsed-expiry-with-frozen-wall","slow-native-helper-result-withheld"}),
            "no-unix-expiry":(replaced(original,"                || capturedAt - sample.observedAt() > START_MAX_AGE_MILLIS\n",""),
                {"unix-expiry-with-fresh-elapsed"}),
            "no-watermark":(replaced(original,"        if (capturedAt < lastStartCaptureUnix || tick - lastStartCaptureTick < 0) return null;\n",""),
                {"unix-capture-watermark-regression","elapsed-capture-watermark-regression"}),
            "retained-watermark-owner":(replaced(original,"else { latestStart = null; captureWatermarkSample = null; }","else latestStart = null;"),
                {"unbound-clears-current-not-ready-identity","native-play-off-clears-cache"}),
            "foreign-binding":(replaced(original,
                "if (body == null || sample == null || sample.owner() != body.owner()\n"
                "                || sample.playerIndex() != body.playerIndex() || sample.playerSqlId() != body.playerSqlId()\n"
                "                || !sample.save().equals(body.save()) || !java.util.Objects.equals(sample.mode(), mode)\n"
                "                || sample.attempt() != body.attempt()",
                "if (body == null || sample == null"),
                {"foreign-owner-refused","foreign-slot-refused","foreign-sql-refused","foreign-save-refused","foreign-mode-refused","foreign-attempt-refused"}),
        }
        for label,(source,failures) in inverse.items():probe("inverse-"+label,source,failures)
        publisher_marker="    /** Shutdown drains sampled bytes without acquiring or resampling a body. */"
        frame_marker="    /** Snapshot of the actual body when SpriteRenderState.onReady commits it. */"
        def publisher_region(text):return text[text.index(publisher_marker):text.index(frame_marker)]
        receipt["publisherRegionUnchanged"]=publisher_region(original)==publisher_region(preimage.read_text(encoding="utf-8"))
        if not receipt["publisherRegionUnchanged"]:raise ValueError("StatePublisher/publication implementation changed")
        receipt["status"]="PASS_CONTROLLED"
    except Exception as error:
        receipt["status"]="FAIL";receipt["error"]=f"{type(error).__name__}: {error}"
    receipt["sourcePinsAfter"]=[pin(p) for p in files]
    receipt["sourceUnchanged"]=source_before==receipt["sourcePinsAfter"]
    if not receipt["sourceUnchanged"]:receipt["status"]="SOURCE_CHANGED"
    target=output/"receipt.json";target.write_text(json.dumps(receipt,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({"status":receipt["status"],"receipt":pin(target),"error":receipt.get("error")}),flush=True)
    return 0 if receipt["status"]=="PASS_CONTROLLED" else 1


def main() -> int:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output",type=Path,required=True)
    parser.add_argument("--preimage",type=Path,default=ALLOWED/"StudyParticipant.java.preimage")
    parser.add_argument("--cohort",type=Path,help="Optional exact-current receipt to cross-check; eight/five cohorts still compile.")
    args=parser.parse_args()
    return run(args.output.resolve(),args.preimage.resolve(),args.cohort.resolve() if args.cohort else None)


if __name__=="__main__":raise SystemExit(main())
