"""Qualify native-play capture methods with synthetic pixels, no game or encoder.

Actual installed cohorts, actual Readback/ProducerFactory seams and actual
StudyParticipant.isCurrent execute in a headless probe JVM. Body bindings are
explicitly synthetic immutable samples; no native game state is initialized.
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
import world_lab_participant_geometry_test as Geometry

ROOT = Path(__file__).resolve().parents[1]
GAME = Geometry.GAME
JDK = Geometry.JDK
PROBE = r'''
import java.nio.file.*;
import java.io.*;
import java.util.*;
import java.util.concurrent.*;
import javax.imageio.ImageIO;

public class NativeCapture04Probe {
 static int checks, constructions;
 static Path root;
 static final List<StudyVideoCapture.Producer> producers=new ArrayList<>();
 static void check(boolean value,String message){checks++;if(!value)throw new AssertionError(message);}
 static Object field(Class<?> type,String name)throws Exception{var f=type.getDeclaredField(name);f.setAccessible(true);return f.get(null);}
 static void field(Class<?> type,String name,Object value)throws Exception{var f=type.getDeclaredField(name);f.setAccessible(true);f.set(null,value);}
 static Object value(Object target,String name)throws Exception{var f=target.getClass().getDeclaredField(name);f.setAccessible(true);return f.get(target);}
 static StudyVideoCapture.Producer current()throws Exception{return (StudyVideoCapture.Producer)field(StudyVideoCapture.class,"producer");}
 static StudyViewCapture.FrameStamp sample(Object body,String save,int sql,double hours,String marker)throws Exception{
  var binding=new StudyParticipant.Binding(body,0,sql,save,1,hours,true,10,20,0,marker,true);
  field(StudyParticipant.class,"latest",binding);
  var p=new StudyViewCapture.ParticipantFrame("{\"syntheticBody\":\""+marker+"\",\"save\":\""+save+"\",\"playerSqlId\":"+sql+"}",body,save,0,sql,1);
  return new StudyViewCapture.FrameStamp(0,hours,new StudyObserver.SiteFrame[0],new StudyVideoCapture.Site[0],p);
 }
 static class GPU implements StudyVideoCapture.Readback {
  int w,h,nextBuffer,maps,captures;long nextFence;boolean signal;
  byte[] original;
  Set<Integer> buffers=new HashSet<>();Set<Long> fences=new HashSet<>();
  GPU(int w,int h){this.w=w;this.h=h;}
  public int width(){return w;}public int height(){return h;}public void verifyContext(){}
  public int createBuffer(int width,int height){check(width==w&&height==h,"PBO allocation changed source geometry");int b=++nextBuffer;buffers.add(b);return b;}
  public long capture(int buffer,int width,int height){check(buffers.contains(buffer)&&width==w&&height==h,"PBO capture changed source geometry");captures++;long f=++nextFence;fences.add(f);return f;}
  public boolean ready(long fence){return signal;}
  public byte[] pixels(int buffer,int width,int height){maps++;check(buffers.contains(buffer)&&width==w&&height==h,"PBO map changed source geometry");original=new byte[width*height*3];for(int i=0;i<original.length;i++)original[i]=(byte)(i*17+3);return original;}
  public void releaseFence(long fence){check(fences.remove(fence),"PBO fence released twice");}
  public void releaseBuffer(int buffer){check(buffers.remove(buffer),"PBO buffer released twice");}
 }
 static GPU setup(boolean nativePlay,boolean participant,int w,int h)throws Exception{
  Files.createDirectories(root);System.setProperty("study.viewDirectory",root.toString());System.setProperty("study.videoEncoder",root.resolve("NEVER_START.exe").toString());
  System.setProperty("study.nativePlay",Boolean.toString(nativePlay));System.setProperty("study.participantInput",Boolean.toString(participant));
  System.setProperty("study.observer",Boolean.toString(!participant));System.setProperty("study.videoFps","120");
  zombie.ZomboidFileSystem.instance.setCacheDir(root.resolve("isolated-cache").toString());
  check(Path.of(zombie.ZomboidFileSystem.instance.getScreenshotDir()).toAbsolutePath().startsWith(root),"screenshot path escaped fixture");
  zombie.GameWindow.closeRequested=false;
  var gpu=new GPU(w,h);field(StudyVideoCapture.class,"readback",gpu);
  field(StudyVideoCapture.class,"producerFactory",(StudyVideoCapture.ProducerFactory)(r,e,a,b,f)->{constructions++;var p=new StudyVideoCapture.Producer(r,e,a,b,f,false);producers.add(p);return p;});
  return gpu;
 }
 static void tick(StudyViewCapture.FrameStamp stamp)throws Exception{field(StudyVideoCapture.class,"nextCapture",0L);StudyVideoCapture.swapped(stamp);}
 static void hook(StudyViewCapture.FrameStamp stamp)throws Exception{
  @SuppressWarnings("unchecked") ThreadLocal<StudyViewCapture.FrameStamp> rendered=(ThreadLocal<StudyViewCapture.FrameStamp>)field(StudyViewCapture.class,"RENDERED");
  rendered.set(stamp);field(StudyVideoCapture.class,"nextCapture",0L);StudyViewCapture.swapped(null);
 }
 static void waitPublication()throws Exception{
  long end=System.nanoTime()+TimeUnit.SECONDS.toNanos(10);
  while(StudyViewCapture.pending!=null&&System.nanoTime()<end)Thread.sleep(2);
  check(StudyViewCapture.pending==null,"PNG publication did not retire bounded pending slot");
 }
 static Object pendingSlot()throws Exception{
  for(var slot:(Object[])field(StudyVideoCapture.class,"SLOTS"))if((long)value(slot,"fence")!=0)return slot;
  throw new AssertionError("no admitted native PBO");
 }
 static void png(byte[] rgb,int w,int h,StudyViewCapture.FrameStamp stamp,long at)throws Exception{
  waitPublication();var manifest=root.resolve("native.json");check(Files.isRegularFile(manifest),"shared PNG was not published");
  var name=root.resolve(StudyViewCapture.PREFIX+String.format("%016d",StudyViewCapture.sequence)+".png");
  check(Files.isRegularFile(name),"original PNG file is absent");
  var image=ImageIO.read(name.toFile());check(image!=null&&image.getWidth()==w&&image.getHeight()==h,"PNG changed original dimensions");
  for(int y=0;y<h;y++)for(int x=0;x<w;x++){
   int offset=((h-y-1)*w+x)*3;int expected=((rgb[offset]&255)<<16)|((rgb[offset+1]&255)<<8)|(rgb[offset+2]&255);
   if((image.getRGB(x,y)&0xffffff)!=expected)throw new AssertionError("PNG changed original RGB pixels");
  }
  check(Files.readString(manifest).contains("\"capturedAtUnixMs\":"+at+","),"PNG relabeled readback with publication wall time");
  check(Files.readString(manifest).contains("\"hours\":"+stamp.hours()+","),"PNG relabeled original world clock");
  check(Files.readString(manifest).contains(stamp.participant().json()),"PNG relabeled original participant stamp");
  check(StudyViewCapture.validatePng(Files.readAllBytes(name))[0]==w,"original PNG failed full validation");
 }
 static void shared()throws Exception{
  GPU gpu=setup(true,true,2488,1566);Object body=new Object();var original=sample(body,"synthetic-save-a",42,100.5,"admitted-A");
  hook(original);var admitted=(StudyVideoCapture.Frame)value(pendingSlot(),"frame");
  check(gpu.captures==1&&gpu.maps==0&&StudyViewCapture.pending==null,"swap read synchronous PNG before its PBO was ready");
  Thread.sleep(25);var later=sample(body,"synthetic-save-a",42,101.5,"later-B");gpu.signal=true;hook(later);
  var frame=current().latest.get();check(frame!=null&&frame.pixels()==gpu.original&&frame.pixels().length==2488*1566*3,"video changed original RGB ownership or dimensions");
  check(gpu.maps==1&&gpu.captures==1,"shared publication required a second native readback");
  check(frame.capturedAtUnixMs()==admitted.capturedAtUnixMs()&&frame.worldHours()==original.hours(),"video changed original time binding");
  png(gpu.original,2488,1566,original,admitted.capturedAtUnixMs());
  check(current().diagnostics.counts[12].get()==1,"shared PNG admission diagnostic missing");
  check(current().diagnostics.timings[5][0].get()==0,"interactive share used synchronous GL PNG readback");
 }
 static void stale()throws Exception{
  GPU gpu=setup(true,true,320,180);Object body=new Object();var original=sample(body,"synthetic-save-a",42,100,"original-A");
  var executor=(ExecutorService)field(StudyViewCapture.class,"PUBLICATION");var entered=new CountDownLatch(1);var release=new CountDownLatch(1);
  executor.execute(()->{entered.countDown();try{release.await();}catch(InterruptedException e){Thread.currentThread().interrupt();}});
  check(entered.await(5,TimeUnit.SECONDS),"controlled PNG worker hold did not enter");
  try {
   tick(original);gpu.signal=true;tick(original);check(StudyViewCapture.pending!=null,"controlled shared PNG was not queued");
   sample(new Object(),"synthetic-save-b",43,1,"new-B");
  } finally {release.countDown();}
  waitPublication();check(!Files.exists(root.resolve("native.json")),"stale body published a false native PNG manifest");
  try(var files=Files.list(root)){check(files.noneMatch(p->p.getFileName().toString().startsWith(StudyViewCapture.PREFIX)),"stale body published PNG bytes");}
 }
 static void defaults(boolean participant)throws Exception{
  GPU gpu=setup(false,participant,320,180);var stamp=participant?sample(new Object(),"synthetic-save",42,100,"default"):new StudyViewCapture.FrameStamp(0,100);
  tick(stamp);gpu.signal=true;tick(stamp);waitPublication();
  check(!StudyVideoCapture.sharesPng()&&current().diagnostics.counts[12].get()==0&&!Files.exists(root.resolve("native.json")),"default observer/participant switched to native-play sharing");
  check(gpu.maps==1,"default video readback changed");
 }
 static void failure()throws Exception{
  GPU gpu=setup(true,true,320,180);var stamp=sample(new Object(),"synthetic-save",42,100,"fallback");tick(stamp);
  var p=current();p.fail("controlled encoder failure");field(StudyVideoCapture.class,"pngAt",System.nanoTime()+TimeUnit.HOURS.toNanos(1));
  check(!StudyVideoCapture.sharesPng()&&StudyVideoCapture.pngDue(),"encoder failure suppressed independent PNG fallback");
  check(StudyViewCapture.beginCapture(stamp),"fallback could not bind current body");
  var bytes=new byte[320*180*3];for(int i=0;i<bytes.length;i++)bytes[i]=(byte)(i*17+3);
  StudyViewCapture.submitPixels(320,180,bytes);waitPublication();check(Files.exists(root.resolve("native.json")),"fallback pixel seam did not publish current PNG");
  check(gpu.maps==0,"failed encoder mapped video PBO for independent fallback");
 }
 static void epoch(String mode)throws Exception{
  GPU gpu=setup(true,true,320,180);Object body=new Object();String save="synthetic-save-a";int sql=42;double hours=100;
  var first=sample(body,save,sql,hours,"A");tick(first);tick(first);tick(first);var old=current();check(old.captured.get()==3,"initial source admissions missing");
  if(mode.equals("body"))body=new Object();if(mode.equals("save"))save="synthetic-save-b";if(mode.equals("sql"))sql=43;if(mode.equals("clock"))hours=1;
  var next=sample(body,save,sql,hours,"B");
  synchronized(old.closeLock){
   tick(next);check(old.retired&&old.closing&&old.dropped.get()==3,"same-dimension source boundary did not retire original admissions");
   check(gpu.buffers.isEmpty()&&gpu.fences.isEmpty()&&gpu.maps==0,"source boundary mapped or retained old GPU pixels");
   check(field(StudyVideoCapture.class,"publicationOwner")==null,"old source retained shared publication authority");
   field(StudyVideoCapture.class,"geometryChangedAt",System.nanoTime()-StudyVideoCapture.GEOMETRY_STABLE_NS-1);tick(next);
   check(constructions==1,"new source started an encoder while the retiring source was held");
  }
  Thread retirement=(Thread)field(StudyVideoCapture.class,"retirementWorker");retirement.join(10000);check(!retirement.isAlive(),"bounded source retirement did not finish");
  field(StudyVideoCapture.class,"geometryChangedAt",System.nanoTime()-StudyVideoCapture.GEOMETRY_STABLE_NS-1);tick(next);var now=current();
  check(now!=old&&!now.streamId.equals(old.streamId)&&constructions==2&&now.width==320&&now.height==180,"same-dimension source boundary did not create a new epoch");
  gpu.signal=true;tick(next);check(now.latest.get().worldHours()==hours&&now.latest.get().sequence()==1,"successor epoch reused old sequence or world time");
  png(gpu.original,320,180,next,now.latest.get().capturedAtUnixMs());
  check(Files.isRegularFile(root.resolve("video-"+old.streamId+"-closed.json"))&&old.quiescent(),"old source lacked durable terminal receipt");
 }
 static void cleanup()throws Exception{
  var p=current();if(p!=null){zombie.GameWindow.closeRequested=true;tick(new StudyViewCapture.FrameStamp(0,0));}
  for(var slot:(Object[])field(StudyVideoCapture.class,"SLOTS"))check(value(slot,"stamp")==null&&value(slot,"frame")==null&&(long)value(slot,"fence")==0,"discard retained source-owned frame/body stamp");
  waitPublication();for(var producer:producers){check(producer.process==null,"probe launched a real encoder process");producer.close();check(producer.quiescent(),"capture epoch retained owned writer/process");}
 }
 public static void main(String[] args)throws Exception{
  root=Path.of(args[1]).toAbsolutePath();String mode=args[0];Throwable failure=null;
  try{switch(mode){case "shared"->shared();case "stale"->stale();case "observer"->defaults(false);case "participant"->defaults(true);case "failure"->failure();default->epoch(mode);}}
  catch(Throwable t){failure=t;}finally{try{cleanup();}catch(Throwable t){if(failure==null)failure=t;else failure.addSuppressed(t);}}
  if(failure!=null){failure.printStackTrace();System.exit(1);}System.out.println("PASS "+checks);
 }
}
'''


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def execute(args, destination, cwd=ROOT, timeout=45):
    result = subprocess.run(list(map(str, args)), cwd=cwd, capture_output=True, text=True,
        timeout=timeout, creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
    destination.write_text(result.stdout + result.stderr, encoding='utf-8')
    return result, result.stdout + result.stderr


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    names = sorted(set(Run.PARTICIPANT_SOURCES) | set(Run.OBSERVER_SOURCES))
    before = {str(ROOT / 'tools/world_lab' / name): digest(ROOT / 'tools/world_lab' / name) for name in names}
    snapshots = out / 'source'; snapshots.mkdir()
    for name in names:
        src = ROOT / 'tools/world_lab' / name
        data = src.read_bytes(); (snapshots / name).write_bytes(data)
        assert hashlib.sha256(data).hexdigest() == before[str(src)] == digest(src), name
    probe = out / 'NativeCapture04Probe.java'; probe.write_text(PROBE, encoding='utf-8')
    geometry = out / 'ParticipantGeometryProbe.java'; geometry.write_text(Geometry.PROBE, encoding='utf-8')
    jars = [GAME / 'projectzomboid.jar', GAME / 'ZombieBuddy.jar']
    dependency_pins = {str(p): digest(p) for p in [*jars, JDK / 'javac.exe', GAME / 'jre64/bin/java.exe']}
    rows = []; errors = []
    def compile_set(label, cohort, changed=None):
        target = out / (label + '-classes'); target.mkdir()
        sources = [snapshots / name for name in cohort]
        if changed:
            name, text = changed; alt = out / (label + '-source'); alt.mkdir(); (alt / name).write_text(text, encoding='utf-8')
            sources = [alt / name if path.name == name else path for path in sources]
        cp = os.pathsep.join(map(str, [target, *jars]))
        probes = [probe, geometry] if 'StudyParticipant.java' in cohort else [geometry]
        result, log = execute([JDK / 'javac.exe', '-cp', cp, '-d', target, *sources, *probes], out / (label + '-compile.log'))
        rows.append(dict(label=label + '-compile', exitCode=result.returncode))
        if result.returncode: errors.append(label + '-compile')
        return cp
    participant_cp = compile_set('participant', Run.PARTICIPANT_SOURCES)
    observer_cp = compile_set('observer', Run.OBSERVER_SOURCES)
    def case(mode, cp=participant_cp, label=None, expected=None, probe_name='NativeCapture04Probe'):
        label = label or mode; dest = out / label
        result, log = execute([GAME / 'jre64/bin/java.exe', '-Djava.awt.headless=true',
            '-Duser.home=' + str(dest / 'isolated-home'), '-cp', cp, probe_name, mode, dest], out / (label + '.log'))
        okay = result.returncode == 0 if expected is None else result.returncode != 0 and expected in log
        row = dict(label=label, mode=mode, exitCode=result.returncode, passed=okay, expectedFailure=expected,
            checks=int(re.search(r'(?m)^PASS (\d+)$', log).group(1)) if result.returncode == 0 else None)
        rows.append(row)
        if not okay: errors.append(label)
        print(json.dumps(row), flush=True)
    if not errors:
        for mode in ['shared', 'stale', 'observer', 'participant', 'failure', 'body', 'save', 'sql', 'clock']:
            case(mode)
        for mode in ['geometry', 'observer', 'shutdown-pending']:
            case(mode, label='reused-geometry-' + mode, probe_name='ParticipantGeometryProbe')
        view = (snapshots / 'StudyViewCapture.java').read_text(encoding='utf-8')
        video = (snapshots / 'StudyVideoCapture.java').read_text(encoding='utf-8')
        controls = [
            ('original-time', 'StudyViewCapture.java', view, 'submitPixels(width, height, pixels, capturedAt);',
                'submitPixels(width, height, pixels, System.currentTimeMillis());', 'shared', 'PNG relabeled readback with publication wall time'),
            ('original-pixels', 'StudyViewCapture.java', view, 'submitPixels(width, height, pixels, capturedAt);',
                'byte[] altered = pixels.clone(); altered[0] ^= 1; submitPixels(width, height, altered, capturedAt);', 'shared', 'PNG changed original RGB pixels'),
            ('current-body', 'StudyViewCapture.java', view,
                'return Boolean.TRUE.equals(Class.forName("StudyParticipant").getMethod("isCurrent", ParticipantFrame.class)\n                .invoke(null, frame.participant()));',
                'Class.forName("StudyParticipant"); return true;', 'stale', 'stale body published a false native PNG manifest'),
            ('source-epoch', 'StudyVideoCapture.java', video, 'boolean nativeBoundary = Boolean.getBoolean("study.nativePlay") && nativeSourceSeen',
                'boolean nativeBoundary = false && nativeSourceSeen', 'clock', 'same-dimension source boundary did not retire original admissions'),
            ('discard-stamp', 'StudyVideoCapture.java', video, 'slot.stamp = null;', '', 'participant', 'discard retained source-owned frame/body stamp'),
            ('encoder-fallback', 'StudyVideoCapture.java', video, '(producer == null || !producer.failed())', 'true', 'failure', 'encoder failure suppressed independent PNG fallback'),
        ]
        for label, name, original, old, new, mode, expected in controls:
            assert original.count(old) == 1, (label, original.count(old))
            cp = compile_set('control-' + label, Run.PARTICIPANT_SOURCES, (name, original.replace(old, new)))
            if rows[-1]['exitCode'] == 0: case(mode, cp, 'control-' + label, expected)
    after = {p: digest(Path(p)) for p in before}
    if before != after:
        errors.append('production-source-changed-during-qualification')
    receipt = dict(schema='sao.native-play-capture-source-qualification/4', status='PASS_SOURCE_CONTROLLED' if not errors else 'FAIL',
        scope='Actual capture/participant methods under synthetic immutable body samples and controlled original RGB readback; no game or real encoder process.',
        menuVideoImplemented=False, sourceBefore=before, sourceAfter=after, current=before == after,
        dependencies=dependency_pins, testSourceSha256=digest(Path(__file__)), results=rows, errors=errors,
        limitations=['Native menu video and actual GL/framebuffer timing remain unqualified.',
            'Encoder failure fallback policy and downstream PNG pixel seam are exercised; real independent GL fallback read is not executed.',
            'No live body sampling, saves, game windows, services or registry are modified.'])
    target = out / 'qualification04.json'; target.write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(dict(status=receipt['status'], current=receipt['current'], receipt=str(target), sha256=digest(target), errors=errors)), flush=True)
    return 1 if errors else 0

if __name__ == '__main__':
    raise SystemExit(main())
