"""Execute participant video geometry epochs against the installed Java cohort.

GPU operations are controlled at the maintained Readback seam. The optional
NVENC case executes the actual encoder at both native dimensions, with no game.
All outputs are exclusive, and every proof pins the exact source/dependencies.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

import world_lab_run as Run

ROOT = Path(__file__).resolve().parents[1]
GAME = Path(os.environ.get("PZ_DIR", "C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid"))
JDK = Path(os.environ.get("JDK_BIN", str(Path.home() / "Peanut Butter/JetBrains/Java/bin")))

PROBE = r'''
import java.io.*;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.*;
public class ParticipantGeometryProbe {
 static int checks, constructions;
 static void check(boolean value,String message) {checks++;if(!value)throw new AssertionError(message);}
 static void field(String name,Object value)throws Exception {
  var f=StudyVideoCapture.class.getDeclaredField(name);f.setAccessible(true);f.set(null,value);
 }
 static Object field(String name)throws Exception {
  var f=StudyVideoCapture.class.getDeclaredField(name);f.setAccessible(true);return f.get(null);
 }
 static StudyVideoCapture.Producer current()throws Exception {return (StudyVideoCapture.Producer)field("producer");}
 static void tick()throws Exception {
  field("nextCapture",0L);StudyVideoCapture.swapped(new StudyViewCapture.FrameStamp(0,30));
 }
 static void stable()throws Exception {field("geometryChangedAt",System.nanoTime()-StudyVideoCapture.GEOMETRY_STABLE_NS-1);}
 static void retired()throws Exception {
  Thread worker=(Thread)field("retirementWorker");worker.join(12000);
  check(!worker.isAlive(),"retirement worker retained");
 }
 static class GPU implements StudyVideoCapture.Readback {
  int w=960,h=540,nextBuffer,maps,failFence,failBuffer;
  long nextFence;boolean signal;
  Set<Integer> buffers=new HashSet<>();Set<Long> fences=new HashSet<>();
  List<String> geometry=new ArrayList<>();
  public int width(){return w;} public int height(){return h;}
  public void verifyContext(){}
  public int createBuffer(int width,int height){int id=++nextBuffer;buffers.add(id);geometry.add("allocate:"+width+"x"+height);return id;}
  public long capture(int buffer,int width,int height){check(buffers.contains(buffer),"capture used released PBO");check(width==w&&height==h,"capture resized native framebuffer");long fence=++nextFence;fences.add(fence);geometry.add("capture:"+width+"x"+height);return fence;}
  public boolean ready(long fence){return signal;}
  public byte[] pixels(int buffer,int width,int height){maps++;check(buffers.contains(buffer),"map used released PBO");check(width==w&&height==h,"old dimensions mapped new framebuffer");byte[] pixels=new byte[width*height*3];for(int i=0;i<pixels.length;i++)pixels[i]=(byte)(i*17+3);return pixels;}
  public void releaseFence(long fence){check(fences.remove(fence),"fence released twice");if(fence==failFence)throw new IllegalStateException("controlled fence disposal failure");}
  public void releaseBuffer(int buffer){check(buffers.remove(buffer),"buffer released twice");if(buffer==failBuffer)throw new IllegalStateException("controlled buffer disposal failure");}
 }
 static GPU setup(Path root,boolean participant,Path encoder,boolean real)throws Exception {
  Files.createDirectories(root);System.setProperty("study.viewDirectory",root.toString());
  System.setProperty("study.videoEncoder",encoder.toString());System.setProperty("study.videoFps","30");
  System.setProperty("study.participantInput",Boolean.toString(participant));System.clearProperty("study.observer");
  GPU gpu=new GPU();field("readback",gpu);
  field("producerFactory",(StudyVideoCapture.ProducerFactory)(r,e,w,h,f)->{constructions++;return new StudyVideoCapture.Producer(r,e,w,h,f,real);});
  zombie.GameWindow.closeRequested=false;tick();return gpu;
 }
 static void geometry(Path root,boolean churn)throws Exception {
  GPU gpu=setup(root,true,root.resolve("not-started.exe"),false);
  var old=current();tick();tick();check(old.captured.get()==3,"initial PBO admissions absent");
  synchronized(old.closeLock) {
   gpu.w=2488;gpu.h=1566;long began=System.nanoTime();tick();
   check(System.nanoTime()-began<TimeUnit.MILLISECONDS.toNanos(200),"render thread waited for retiring encoder");
   check(gpu.buffers.isEmpty()&&gpu.fences.isEmpty(),"old geometry GPU resources retained");
   check(old.dropped.get()==3&&old.captured.get()==3,"old admitted frames not cancelled exactly once");
   check(old.closing&&old.retired&&!old.failed(),"participant resize made video unavailable");
   check(field("publicationOwner")==null,"retired epoch kept shared publication authority");
   if(churn)for(int i=0;i<60;i++){gpu.w=960+(i%2)*1528;gpu.h=540+(i%2)*1026;tick();}
   stable();tick();check(constructions==1,"encoder churn while previous close was blocked");
  }
  retired();gpu.w=1280;gpu.h=720;tick();gpu.w=2488;gpu.h=1566;tick();
  check(constructions==1,"new epoch ignored native geometry debounce");
  stable();tick();var now=current();
  check(now!=old&&!now.streamId.equals(old.streamId)&&constructions==2,"stable geometry did not create distinct epoch");
  check(now.width==2488&&now.height==1566&&now.fps==30,"new epoch is not actual native geometry/rate");
  check(gpu.buffers.size()==3&&gpu.fences.size()==1,"new native buffers/admission missing");
  check(now.captured.get()==1&&now.dropped.get()==0,"new epoch counters did not reset honestly");
  gpu.signal=true;tick();var frame=now.latest.get();
  check(frame!=null&&frame.width()==2488&&frame.height()==1566&&frame.sequence()==1,"new readback has wrong source identity");
  for(int i=0;i<frame.pixels().length;i++)if(frame.pixels()[i]!=(byte)(i*17+3))throw new AssertionError("source RGB pixels changed");
  check(frame.pixels().length==2488*1566*3,"source RGB pixels resized");
  now.latest.set(null); // controlled sink consumes exact original bytes
  zombie.GameWindow.closeRequested=true;tick();
  check(gpu.buffers.isEmpty()&&gpu.fences.isEmpty(),"final epoch shutdown retained GPU resources");
  now.close();check(now.quiescent()&&old.quiescent(),"epoch shutdown retained worker/process");
  check(Files.isRegularFile(root.resolve("video-"+old.streamId+"-closed.json")),"old epoch terminal receipt absent");
  check(Files.isRegularFile(root.resolve("video-"+now.streamId+"-closed.json")),"final epoch terminal receipt absent");
  byte[] closed=Files.readAllBytes(root.resolve("video-"+now.streamId+"-closed.json"));now.close();
  check(Arrays.equals(closed,Files.readAllBytes(root.resolve("video-"+now.streamId+"-closed.json"))),"terminal receipt overwritten");
  Files.writeString(root.resolve("geometry.txt"),String.join("\n",gpu.geometry));
 }
 static void defaultResize(Path root)throws Exception {
  GPU gpu=setup(root,false,root.resolve("not-started.exe"),false);var old=current();tick();tick();
  gpu.w=2488;gpu.h=1566;tick();
  check(old.failed()&&old.failureReason.get().equals("Native video capture unavailable"),"observer resize behavior changed");
  check(constructions==1&&!old.retired,"observer created participant geometry epoch");
  check(old.captured.get()==3&&old.dropped.get()==3&&gpu.buffers.isEmpty()&&gpu.fences.isEmpty(),"observer failure cleanup changed");
  old.close();check(old.quiescent(),"observer failure worker retained");
  check(!Files.exists(root.resolve("video-"+old.streamId+"-closed.json")),"default observer received participant terminal protocol");
 }
 static void publicationBusy(Path root)throws Exception {
  GPU gpu=setup(root,true,root.resolve("not-started.exe"),false);var old=current();
  var lock=(java.util.concurrent.locks.ReentrantLock)field("PUBLICATION_LOCK");
  CountDownLatch entered=new CountDownLatch(1),release=new CountDownLatch(1);
  Thread publishing=new Thread(()->{lock.lock();try{entered.countDown();release.await();}catch(InterruptedException e){throw new RuntimeException(e);}finally{lock.unlock();}});
  publishing.start();check(entered.await(2,TimeUnit.SECONDS),"controlled publication did not enter");
  gpu.w=2488;gpu.h=1566;long began=System.nanoTime();tick();
  check(System.nanoTime()-began<TimeUnit.MILLISECONDS.toNanos(200),"render thread waited for file publication");
  check(gpu.buffers.isEmpty()&&gpu.fences.isEmpty()&&field("retirementWorker")==null,"busy publication started unowned retirement");
  check(constructions==1&&!old.failed(),"busy publication failed/churned encoder");
  release.countDown();publishing.join(2000);tick();retired();stable();tick();
  check(constructions==2&&current()!=old,"deferred publication transfer did not recover");
  zombie.GameWindow.closeRequested=true;tick();current().close();
  check(gpu.buffers.isEmpty()&&gpu.fences.isEmpty(),"deferred publication retained GPU resources");
 }
 static void shutdownPending(Path root)throws Exception {
  GPU gpu=setup(root,true,root.resolve("not-started.exe"),false);var old=current();Thread shutdown;
  var stop=StudyVideoCapture.class.getDeclaredMethod("shutdown");stop.setAccessible(true);
  synchronized(old.closeLock) {
   gpu.w=2488;gpu.h=1566;tick();
   shutdown=new Thread(()->{try{stop.invoke(null);}catch(Exception e){throw new RuntimeException(e);}});shutdown.start();
   long until=System.nanoTime()+TimeUnit.SECONDS.toNanos(2);
   while(!(boolean)field("captureStopped")&&System.nanoTime()<until)Thread.sleep(1);
   check((boolean)field("captureStopped"),"shutdown did not stop native admissions");
   stable();tick();check(constructions==1,"shutdown started a successor geometry epoch");
  }
  shutdown.join(12000);retired();
  check(!shutdown.isAlive()&&old.quiescent(),"shutdown during retirement retained worker/process");
  check(gpu.buffers.isEmpty()&&gpu.fences.isEmpty(),"shutdown during retirement retained native GPU resources");
  check(Files.isRegularFile(root.resolve("video-"+old.streamId+"-closed.json")),"shutdown during retirement lost old terminal receipt");
 }
 static void cleanup(Path root,boolean fence)throws Exception {
  GPU gpu=setup(root,true,root.resolve("not-started.exe"),false);var old=current();tick();tick();
  if(fence)gpu.failFence=1;else gpu.failBuffer=1;
  gpu.w=2488;gpu.h=1566;tick();
  check(old.failed(),"native GPU disposal failure hidden");
  check(gpu.buffers.isEmpty()&&gpu.fences.isEmpty(),"cleanup exception skipped remaining native disposals");
  check(old.captured.get()==3&&old.dropped.get()==3,"cleanup failure duplicated or omitted admitted losses");
  tick();check(old.dropped.get()==3,"repeat callback duplicated disposed admissions");
  old.close();check(old.quiescent(),"cleanup failure worker retained");
 }
 static void authority(Path root)throws Exception {
  System.setProperty("study.participantInput","true");System.clearProperty("study.observer");Files.createDirectories(root);
  var old=new StudyVideoCapture.Producer(root,root.resolve("unused.exe"),960,540,30,false);
  old.writeManifest();old.writeDiagnostics();old.retired=true;
  var now=new StudyVideoCapture.Producer(root,root.resolve("unused.exe"),2488,1566,30,false);
  now.writeManifest();now.writeDiagnostics();byte[] latest=Files.readAllBytes(root.resolve("latest-video.json"));
  byte[] metrics=Files.readAllBytes(root.resolve("capture-diagnostics.json"));
  old.diagnosticWriter.start();old.writeManifest();old.fail("controlled old epoch failure");old.close();
  check(Arrays.equals(latest,Files.readAllBytes(root.resolve("latest-video.json"))),"old asynchronous epoch overwrote current video");
  check(Arrays.equals(metrics,Files.readAllBytes(root.resolve("capture-diagnostics.json"))),"old asynchronous epoch overwrote current diagnostics");
  check(Files.isRegularFile(root.resolve("video-"+old.streamId+"-capture-diagnostics.json")),"old diagnostics were lost");
  check(Files.readString(root.resolve("video-"+old.streamId+"-closed.json")).contains("controlled old epoch failure"),"old failure terminal state hidden");
  now.close();check(now.quiescent()&&old.quiescent(),"authority test workers retained");
 }
 static void tail(Path root)throws Exception {
  System.setProperty("study.participantInput","true");System.clearProperty("study.observer");Files.createDirectories(root);
  var old=new StudyVideoCapture.Producer(root,root.resolve("unused.exe"),960,540,30,false);
  old.timeScale=1000;old.codecs="avc1.640033";old.initFile="video-"+old.streamId+"-init.mp4";
  byte[] init={1,2,3,4};Files.write(root.resolve(old.initFile),init);old.initSha=StudyVideoCapture.sha(init);
  var publish=StudyVideoCapture.Producer.class.getDeclaredMethod("publishFragment",StudyVideoCapture.Fragment.class,byte[].class);publish.setAccessible(true);
  for(int i=1;i<=29;i++) {
   if(i==9){old.retired=true;old.writeManifest();}
   long seq=old.admitCapture();old.submitted.add(new StudyVideoCapture.Frame(seq,1000+i,0,30+i*.001,new StudyVideoCapture.Site[0],960,540,null));
   publish.invoke(old,new StudyVideoCapture.Fragment(1,(i-1)*100,100),new byte[]{(byte)i,13,21});
   check(old.segments.size()<=8,"retirement manifest exceeds existing list bound");
   var segment=old.segments.getLast();
   check(segment.sites().length==0&&segment.first().observerSequence()==0,"participant viewport invented body/camera provenance");
   check(segment.crops().length==1&&segment.crops()[0].equals(new StudyVideoCapture.Crop("participant-viewport",0,0,0,960,540)),"participant source viewport crop absent or resized");
  }
  old.close();check(old.quiescent(),"tail close retained source worker");
  for(int i=1;i<=29;i++) {
   String stem="video-"+old.streamId+"-"+String.format("%016d",i);
   check(Arrays.equals(Files.readAllBytes(root.resolve(stem+".m4s")),new byte[]{(byte)i,13,21}),"retired original tail media deleted or changed");
   if(i>=8)check(Files.isRegularFile(root.resolve("video-"+old.streamId+"-tail-"+String.format("%016d",i)+".json")),"retirement window receipt missing");
  }
 }
 static void terminalTail(Path root)throws Exception {
  System.setProperty("study.participantInput","true");System.clearProperty("study.observer");
  for(String terminal:new String[]{"ended","failed"}) {
   Path directory=root.resolve(terminal);Files.createDirectories(directory);
   var old=new StudyVideoCapture.Producer(directory,directory.resolve("unused.exe"),960,540,30,false);
   old.timeScale=1000;old.codecs="avc1.640033";
   old.initFile="video-"+old.streamId+"-init.mp4";byte[] init={1,2,3,4};
   Files.write(directory.resolve(old.initFile),init);old.initSha=StudyVideoCapture.sha(init);
   long seq=old.admitCapture();old.submitted.add(new StudyVideoCapture.Frame(seq,1001,0,30,new StudyVideoCapture.Site[0],960,540,null));
   var publish=StudyVideoCapture.Producer.class.getDeclaredMethod("publishFragment",StudyVideoCapture.Fragment.class,byte[].class);publish.setAccessible(true);
   publish.invoke(old,new StudyVideoCapture.Fragment(1,0,100),new byte[]{11,13,21});
   old.requestClose();
   if(terminal.equals("ended"))old.state="ended";
   else {old.fail("controlled terminal-before-retirement failure");old.failureWriter.join(2000);}
   // Reproduce encoder completion before the first retirement snapshot.
   old.retired=true;old.writeManifest();
   try(var paths=Files.list(directory)){check(paths.noneMatch(p->p.getFileName().toString().contains("-tail-")),"terminal retirement emitted inadmissible tail snapshot");}
   old.close();check(old.quiescent(),"terminal retirement retained worker/process");
   String json=Files.readString(directory.resolve("video-"+old.streamId+"-closed.json"));
   check(json.contains("\"state\":\""+terminal+"\""),"closed receipt lost actual terminal state");
   check(json.contains("\"sequence\":1")&&json.contains("\"encodedFrames\":1"),"closed receipt lost final retained window");
   check(Arrays.equals(Files.readAllBytes(directory.resolve(old.segments.getFirst().file())),new byte[]{11,13,21}),"terminal retirement changed original tail bytes");
   try(var paths=Files.list(directory)){check(paths.noneMatch(p->p.getFileName().toString().contains("-tail-")),"close emitted inadmissible terminal tail snapshot");}
  }
 }
 static class ControlledProcess extends Process {
  boolean live=true,forced;int destroys;
  public OutputStream getOutputStream(){return OutputStream.nullOutputStream();}
  public InputStream getInputStream(){return InputStream.nullInputStream();}
  public InputStream getErrorStream(){return InputStream.nullInputStream();}
  public int waitFor(){return 0;}
  public boolean waitFor(long time,TimeUnit unit){return !live;}
  public int exitValue(){if(live)throw new IllegalThreadStateException();return 1;}
  public void destroy(){destroys++;}
  public Process destroyForcibly(){forced=true;live=false;return this;}
  public boolean isAlive(){return live;}
 }
 static void closeFailure(Path root)throws Exception {
  System.setProperty("study.participantInput","true");System.clearProperty("study.observer");Files.createDirectories(root);
  var old=new StudyVideoCapture.Producer(root,root.resolve("unused.exe"),960,540,30,false);
  var process=new ControlledProcess();old.process=process;old.close();
  check(old.failed()&&process.forced&&!process.live,"owned child shutdown failure not terminated/reflected");
  check(old.quiescent(),"failed close retained resource ownership");
  check(Files.readString(root.resolve("video-"+old.streamId+"-closed.json")).contains("\"state\":\"failed\""),"failed close published successful end");
 }
 static void real(Path root,Path encoder)throws Exception {
  GPU gpu=setup(root,true,encoder,true);var old=current();gpu.signal=true;
  for(int i=0;i<14;i++){tick();Thread.sleep(60);}
  gpu.w=2488;gpu.h=1566;tick();retired();stable();tick();var now=current();
  check(now!=old&&!now.failed(),"actual encoder did not survive geometry rollover");
  for(int i=0;i<14;i++){tick();Thread.sleep(90);}
  zombie.GameWindow.closeRequested=true;tick();now.close();
  check(!old.failed()&&!now.failed()&&old.encoded.get()>0&&now.encoded.get()>0,"actual geometry epochs failed to encode");
  check(old.quiescent()&&now.quiescent()&&gpu.buffers.isEmpty()&&gpu.fences.isEmpty(),"actual geometry encoder resources retained");
  Files.writeString(root.resolve("streams.json"),"[\""+old.streamId+"\",\""+now.streamId+"\"]");
 }
 public static void main(String[] args)throws Exception {
  Path root=Path.of(args[1]);
  switch(args[0]) {
   case "geometry"->geometry(root,false);case "churn"->geometry(root,true);
   case "observer"->defaultResize(root);case "fence-cleanup"->cleanup(root,true);case "buffer-cleanup"->cleanup(root,false);
   case "authority"->authority(root);case "tail"->tail(root);case "close-failure"->closeFailure(root);
   case "publication-busy"->publicationBusy(root);case "shutdown-pending"->shutdownPending(root);
   case "terminal-tail"->terminalTail(root);
   case "nvenc"->real(root,Path.of(args[2]));default->throw new IllegalArgumentException(args[0]);
  }
  System.out.println("PASS "+checks);
 }
}
'''


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def execute(command, cwd=ROOT, timeout=60):
    return subprocess.run(list(map(str, command)), cwd=cwd, capture_output=True, text=True,
                          timeout=timeout, creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--encoder", type=Path)
    parser.add_argument("--source-controls", action="store_true")
    args = parser.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    sources = [ROOT / "tools/world_lab" / n for n in Run.PARTICIPANT_SOURCES]
    inputs = [Path(__file__).resolve(), *sources, GAME / "projectzomboid.jar", GAME / "ZombieBuddy.jar"]
    if args.encoder:
        inputs.append(args.encoder.resolve())
    before = {str(p): digest(p) for p in inputs}
    fixture = out / "ParticipantGeometryProbe.java"
    fixture.write_text(PROBE, encoding="utf-8")
    compiles = []
    for label, names in [("participant", Run.PARTICIPANT_SOURCES), ("observer", Run.OBSERVER_SOURCES)]:
        classes = out / (label + "-classes")
        classes.mkdir()
        cp = os.pathsep.join(map(str, [classes, GAME / "projectzomboid.jar", GAME / "ZombieBuddy.jar"]))
        command = [JDK / "javac.exe", "-cp", cp, "-d", classes,
                   *(ROOT / "tools/world_lab" / n for n in names), fixture]
        result = execute(command)
        (out / (label + "-compile.log")).write_text(result.stdout + result.stderr, encoding="utf-8")
        assert result.returncode == 0, result.stdout + result.stderr
        compiles.append({"cohort": label, "sources": list(names), "classes": len(list(classes.rglob("*.class"))), "command": list(map(str, command)), "exitCode": result.returncode})
    cp = os.pathsep.join(map(str, [out / "participant-classes", GAME / "projectzomboid.jar", GAME / "ZombieBuddy.jar"]))
    rows = []
    modes = ["geometry", "churn", "observer", "fence-cleanup", "buffer-cleanup", "authority", "tail", "close-failure", "publication-busy", "shutdown-pending", "terminal-tail"]
    if args.encoder:
        modes.append("nvenc")
    for mode in modes:
        destination = out / mode
        command = [GAME / "jre64/bin/java.exe", "-Djava.awt.headless=true", "-cp", cp,
                   "ParticipantGeometryProbe", mode, destination]
        if mode == "nvenc":
            command.append(args.encoder.resolve())
        result = execute(command, GAME, 45)
        log = result.stdout + result.stderr
        (out / (mode + ".log")).write_text(log, encoding="utf-8")
        assert result.returncode == 0, (mode, log)
        for path in destination.rglob("video-*-tail-*.json"):
            assert json.loads(path.read_text())["state"] in {"starting", "running"}, path
        closed = []
        for path in sorted(destination.rglob("video-*-closed.json")):
            value = json.loads(path.read_text())
            assert len(value["segments"]) <= 8 and value["state"] in {"ended", "failed"}
            assert value["stats"]["encodedFrames"] + value["stats"]["droppedFrames"] <= value["stats"]["capturedFrames"]
            closed.append({"file": path.name, "sha256": digest(path), "state": value["state"], "width": value["width"], "height": value["height"], "stats": value["stats"]})
        if mode == "tail":
            receipts = sorted(destination.glob("video-*-tail-*.json"))
            assert len(receipts) == 22
            sequence = set()
            for path in receipts:
                value = json.loads(path.read_text())
                assert len(value["segments"]) <= 8
                assert int(path.stem.rsplit("-", 1)[1]) == value["segments"][-1]["sequence"]
                for segment in value["segments"]:
                    media = destination / segment["file"]
                    assert digest(media) == segment["sha256"]
                    sequence.add(segment["sequence"])
            assert sequence == set(range(1, 30)), sequence
        if mode == "nvenc":
            ffprobe = args.encoder.with_name("ffprobe.exe")
            for index, stream in enumerate(json.loads((destination / "streams.json").read_text())):
                value = json.loads((destination / f"video-{stream}-closed.json").read_text())
                recording = destination / f"epoch-{index}.mp4"
                data = (destination / value["init"]["file"]).read_bytes()
                assert hashlib.sha256(data).hexdigest() == value["init"]["sha256"]
                for segment in value["segments"]:
                    assert segment["observerSequence"] == 0 and segment["sites"] == []
                    assert segment["crops"] == [{"id": "participant-viewport", "slot": 0, "left": 0, "top": 0,
                                                 "width": value["width"], "height": value["height"]}]
                    media = (destination / segment["file"]).read_bytes()
                    assert hashlib.sha256(media).hexdigest() == segment["sha256"]
                    data += media
                recording.write_bytes(data)
                decode = execute([args.encoder, "-v", "error", "-i", recording, "-f", "null", "-"], GAME, 30)
                (destination / f"epoch-{index}-decode.log").write_text(decode.stdout + decode.stderr)
                assert decode.returncode == 0, decode.stderr
                probe = execute([ffprobe, "-v", "error", "-show_entries", "stream=width,height,codec_name", "-of", "json", recording], GAME, 30)
                assert probe.returncode == 0, probe.stderr
                info = json.loads(probe.stdout)["streams"][0]
                assert (info["width"], info["height"]) == (value["width"], value["height"])
                (destination / f"epoch-{index}-probe.json").write_text(probe.stdout)
        rows.append({"mode": mode, "checks": int(re.search(r"(?m)^PASS (\d+)$", log).group(1)), "closed": closed})
    controls = []
    if args.source_controls:
        original = (ROOT / "tools/world_lab/StudyVideoCapture.java").read_text(encoding="utf-8")
        defects = [
            ("fixed-geometry", "geometry", "if (!StudyViewCapture.participantMode())", "if (true)", "participant resize made video unavailable"),
            ("old-video-owner", "authority", 'if (publicationOwner == this) replace("latest-video.json", json);', 'replace("latest-video.json", json);', "old asynchronous epoch overwrote current video"),
            ("old-diagnostics-owner", "authority", 'if (publicationOwner == this) replace("capture-diagnostics.json", json);', 'replace("capture-diagnostics.json", json);', "old asynchronous epoch overwrote current diagnostics"),
            ("deleted-retirement-tail", "tail", "if (!retired) for (Segment old : expired)", "for (Segment old : expired)", "NoSuchFileException"),
            ("no-debounce", "geometry", "now - geometryChangedAt < GEOMETRY_STABLE_NS", "false", "new epoch ignored native geometry debounce"),
            ("early-terminal", "geometry", 'commit("video-" + streamId + "-closed.json", json.getBytes(StandardCharsets.UTF_8));', "// omitted immutable terminal receipt", "old epoch terminal receipt absent"),
            ("skipped-buffer-cleanup", "fence-cleanup", "try { if (fence != 0) readback.releaseFence(fence); }\n        finally { if (releaseBuffer && buffer != 0) readback.releaseBuffer(buffer); }", "if (fence != 0) readback.releaseFence(fence);\n        if (releaseBuffer && buffer != 0) readback.releaseBuffer(buffer);", "cleanup exception skipped remaining native disposals"),
            ("empty-participant-crop", "tail", "Crop[] crops = participantEpoch", "Crop[] crops = false", "participant source viewport crop absent or resized"),
            ("terminal-tail-race", "terminal-tail", 'if (retired && !segments.isEmpty() && !failed()\n                        && (state.equals("starting") || state.equals("running")))', 'if (retired && !segments.isEmpty())', "terminal retirement emitted inadmissible tail snapshot"),
        ]
        for label, mode, anchor, replacement, expected in defects:
            assert original.count(anchor) == 1, (label, original.count(anchor))
            folder = out / ("restored-" + label)
            folder.mkdir()
            bad_source = folder / "StudyVideoCapture.java"
            bad_source.write_text(original.replace(anchor, replacement), encoding="utf-8")
            classes = folder / "classes"
            classes.mkdir()
            compiled = execute([JDK / "javac.exe", "-cp", cp, "-d", classes, bad_source])
            (folder / "compile.log").write_text(compiled.stdout + compiled.stderr, encoding="utf-8")
            assert compiled.returncode == 0, compiled.stdout + compiled.stderr
            bad_cp = os.pathsep.join([str(classes), cp])
            result = execute([GAME / "jre64/bin/java.exe", "-Djava.awt.headless=true", "-cp", bad_cp,
                              "ParticipantGeometryProbe", mode, folder / "output"], GAME, 45)
            log = result.stdout + result.stderr
            (folder / "probe.log").write_text(log, encoding="utf-8")
            assert result.returncode != 0 and expected in log, (label, expected, log)
            controls.append({"defect": label, "mode": mode, "detected": True, "expectedFailure": expected})
    after = {str(p): digest(p) for p in inputs}
    assert after == before, "proof inputs changed"
    receipt = {"schema": "sao-participant-video-geometry-proof/1", "status": "PASS", "inputsBefore": before,
               "inputsAfter": after, "cohorts": compiles, "cases": rows, "restoredDefects": controls, "checks": sum(r["checks"] for r in rows),
               "boundary": "Maintained native Java compiled against installed dependencies; controlled GPU seam and owned child failure. Optional actual NVENC/full decode of two native-resolution epochs. No game, desktop, service, or installed rendered acceptance."}
    (out / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"status": "PASS", "checks": receipt["checks"], "cases": len(rows), "receipt": str(out / "receipt.json")}))


if __name__ == "__main__":
    main()
