"""Native Java capture accounting/timing proof, without launching a game."""
from __future__ import annotations
import argparse
import hashlib
import json
import os
import re
from pathlib import Path
import subprocess
import sys
import time

import world_lab_run as Run

ROOT = Path(__file__).resolve().parents[1]
GAME = Path(os.environ.get('PZ_DIR', 'C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid'))
JDK = Path(os.environ.get('JDK_BIN', str(Path.home()/'Peanut Butter/JetBrains/Java/bin')))
PROBE = r'''
import java.io.*;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.*;
public class CaptureDiagnosticsProbe {
 static int checks;
 static void check(boolean condition,String label){checks++;if(!condition)throw new AssertionError(label);}
 static void field(String name,Object value)throws Exception{
  var f=StudyVideoCapture.class.getDeclaredField(name);f.setAccessible(true);f.set(null,value);
 }
 static class GPU implements StudyVideoCapture.Readback {
  long next;Set<Long> ready=new HashSet<>();int captures,maps;
  public int width(){return 320;}public int height(){return 180;}
  public void verifyContext(){}public int createBuffer(int w,int h){return 0;}
  public long capture(int b,int w,int h){captures++;return ++next;}
  public boolean ready(long fence){return ready.contains(fence);}
  public byte[] pixels(int b,int w,int h){maps++;return new byte[w*h*3];}
  public void releaseFence(long f){}public void releaseBuffer(int b){}
 }
 static void tick(boolean ceiling)throws Exception{
  if(!ceiling)field("nextCapture",0L);
  StudyVideoCapture.swapped(new StudyViewCapture.FrameStamp(1,30));
 }
 static StudyVideoCapture.Frame frame(){return new StudyVideoCapture.Frame(1,1,1,30,new StudyVideoCapture.Site[0],320,180,new byte[320*180*3]);}
 static void pbo(StudyVideoCapture.Producer p,GPU gpu)throws Exception{
  tick(false);tick(false);tick(false);tick(false);
  check(gpu.captures==3,"original native admission changed under full PBO");
  check(p.captured.get()==3&&p.dropped.get()==0,"pre-admission PBO skips altered video stats");
  check(p.diagnostics.counts[5].get()==1,"pboBusySkips omitted");
  check(p.diagnostics.counts[8].get()==3,"fenceNotReady omitted");
  check(p.diagnostics.timings[1][0].get()==3,"pboSubmit timing omitted");
  gpu.ready.add(1L);tick(false);
  check(gpu.maps==1&&p.diagnostics.counts[9].get()==1,"readback transfer count differs");
  check(p.diagnostics.timings[2][0].get()==1&&p.diagnostics.timings[2][1].get()>0,"fenceAge timing omitted");
  check(p.diagnostics.timings[3][0].get()==1,"pboMapCopy timing omitted");
  check(p.diagnostics.counts[6].get()==1,"handoffBusySkips omitted");
  check(p.captured.get()==3&&p.dropped.get()==0,"occupied handoff changed capture admission");
  check(p.diagnostics.counts[3].get()==5&&p.diagnostics.counts[7].get()==3,"capture attempt/admission counters differ");
 }
 static void ceiling(StudyVideoCapture.Producer p,GPU gpu)throws Exception{
  field("nextCapture",Long.MAX_VALUE);tick(true);
  check(p.diagnostics.counts[4].get()==1,"ceilingSkips omitted");
  check(gpu.captures==0&&p.captured.get()==0&&p.dropped.get()==0,"ceiling admission behavior changed");
  check(p.diagnostics.timings[0][0].get()==1,"captureCallback timing omitted");
 }
 static void hook(StudyVideoCapture.Producer p)throws Exception{
  StudyViewCapture.swapped(null);StudyViewCapture.swapped(new IOException("controlled swap failure"));
  check(p.diagnostics.counts[0].get()==2,"native swap callback counter omitted");
  check(p.diagnostics.counts[1].get()==2&&p.diagnostics.counts[2].get()==1,"missing/failing native stamp counters differ");
  var f=StudyViewCapture.class.getDeclaredField("RENDERED");f.setAccessible(true);
  @SuppressWarnings("unchecked") var rendered=(ThreadLocal<StudyViewCapture.FrameStamp>)f.get(null);
  field("pngAt",Long.MAX_VALUE);
  rendered.set(new StudyViewCapture.FrameStamp(1,30));StudyViewCapture.swapped(null);
  check(p.diagnostics.counts[0].get()==3&&p.diagnostics.counts[3].get()==1,"stamped real hook did not count once");
  check(p.captured.get()==1&&p.dropped.get()==0,"real hook changed capture behavior");
  StudyVideoCapture.pngReadbackDuration(12345);
  check(p.diagnostics.timings[5][0].get()==1&&p.diagnostics.timings[5][1].get()==12345,"pngReadback timer omitted");
 }
 static void pipe(StudyVideoCapture.Producer p)throws Exception{
  var entered=new CountDownLatch(1);var release=new CountDownLatch(1);var flushed=new CountDownLatch(1);
  ByteArrayOutputStream bytes=new ByteArrayOutputStream();
  OutputStream sink=new OutputStream(){
   public void write(int b){bytes.write(b);}
   public void write(byte[] b)throws IOException{
    entered.countDown();try{release.await();}catch(InterruptedException e){throw new IOException(e);}bytes.write(b);
   }
   public void flush(){flushed.countDown();}
  };
  var error=new java.util.concurrent.atomic.AtomicReference<Throwable>();
  Thread thread=new Thread(()->{try{p.writePixels(sink,frame());}catch(Throwable t){error.set(t);}});thread.start();
  check(entered.await(2,TimeUnit.SECONDS),"actual source pipe write did not enter");
  check(p.diagnostics.counts[10].get()==0&&flushed.getCount()==1,"blocked source pipe was falsely completed");
  Thread.sleep(20);release.countDown();thread.join(2000);
  check(!thread.isAlive()&&error.get()==null,"actual pipe write did not return");
  check(bytes.size()==320*180*3&&flushed.getCount()==0,"original RGB write/flush changed");
  check(p.diagnostics.counts[10].get()==1,"pipeWrites omitted");
  check(p.diagnostics.timings[4][0].get()==1&&p.diagnostics.timings[4][1].get()>=10_000_000,"pipeWriteFlush stall timing omitted");
  check(p.captured.get()==0&&p.dropped.get()==0,"diagnostic-only pipe proof changed video stats");
  try{p.writePixels(new OutputStream(){public void write(int b)throws IOException{throw new IOException("controlled pipe refusal");}},frame());throw new AssertionError("source pipe failure swallowed");}
  catch(IOException expected){check(expected.getMessage().equals("controlled pipe refusal"),"pipe failure changed");}
  check(p.diagnostics.counts[10].get()==1&&p.diagnostics.timings[4][0].get()==2,"failed pipe timing/success semantics differ");
 }
 static void worker(StudyVideoCapture.Producer p,Path root)throws Exception{
  synchronized(p) {
   p.diagnosticWriter.start();long deadline=System.nanoTime()+TimeUnit.SECONDS.toNanos(2);
   while(!Files.isRegularFile(root.resolve("capture-diagnostics.json"))&&System.nanoTime()<deadline)Thread.sleep(5);
   check(Files.isRegularFile(root.resolve("capture-diagnostics.json")),"sidecar writer shared video-publication lock");
  }
  var modified=Files.getLastModifiedTime(root.resolve("capture-diagnostics.json"));Thread.sleep(100);
  check(Files.getLastModifiedTime(root.resolve("capture-diagnostics.json")).equals(modified),"sidecar worker performed high-rate writes");
  p.diagnosticsStopped=true;java.util.concurrent.locks.LockSupport.unpark(p.diagnosticWriter);p.diagnosticWriter.join(2000);
  check(!p.diagnosticWriter.isAlive(),"diagnostic worker not retired");
  check(!Files.exists(root.resolve("capture-diagnostics.json.tmp")),"sidecar atomic temporary left behind");
  check(!p.failed()&&p.captured.get()==0,"sidecar changed video status");
  Path blocked=root.resolve("blocked-root");Files.writeString(blocked,"controlled file");
  var q=new StudyVideoCapture.Producer(blocked,root.resolve("unused.exe"),320,180,120,false);
  q.diagnosticsStopped=true;q.diagnosticWriter.start();q.diagnosticWriter.join(2000);
  check(q.diagnostics.counts[11].get()==1&&!q.failed(),"sidecar failure escaped into video lifecycle");
 }
 public static void main(String[] args)throws Exception{
  String mode=args[0];Path root=Path.of(args[1]);Files.createDirectories(root);
  System.setProperty("study.videoEncoder",root.resolve("not-started.exe").toString());
  var p=new StudyVideoCapture.Producer(root,root.resolve("not-started.exe"),320,180,120,false);
  GPU gpu=new GPU();field("producer",p);field("readback",gpu);field("initialized",true);
  switch(mode){case "pbo"->pbo(p,gpu);case "ceiling"->ceiling(p,gpu);case "hook"->hook(p);case "pipe"->pipe(p);case "worker"->worker(p,root);default->throw new IllegalArgumentException(mode);}
  p.writeDiagnostics();p.writeManifest();
  check(p.command().contains("constqp")&&p.command().contains("18")&&p.command().contains("passthrough"),"qualified encoder policy changed");
  System.out.println("PASS "+checks);
 }
}
'''

def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def run(args, cwd, timeout=60):
    r = subprocess.run(list(map(str,args)),cwd=cwd,capture_output=True,text=True,timeout=timeout)
    return r, r.stdout+r.stderr

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path,required=True);args=parser.parse_args()
    out=args.output.resolve();out.mkdir(parents=True,exist_ok=False)
    sources=[ROOT/'tools/world_lab'/name for name in Run.OBSERVER_SOURCES]
    inputs=[Path(__file__).resolve(),*sources,GAME/'projectzomboid.jar',GAME/'ZombieBuddy.jar']
    before={str(p):digest(p) for p in inputs};fixture=out/'CaptureDiagnosticsProbe.java';fixture.write_text(PROBE,encoding='utf-8')
    classes=out/'classes';classes.mkdir()
    cp=os.pathsep.join(map(str,[classes,GAME/'projectzomboid.jar',GAME/'ZombieBuddy.jar']))
    r,log=run([JDK/'javac.exe','-cp',cp,'-d',classes,*sources,fixture],ROOT)
    (out/'compile.log').write_text(log,encoding='utf-8');assert r.returncode==0,log
    results=[]
    def execute(mode, dest, classpath=cp, expected=None):
        r,log=run([GAME/'jre64/bin/java.exe','-Djava.awt.headless=true','-cp',classpath,'CaptureDiagnosticsProbe',mode,dest],GAME,30)
        dest.with_suffix('.log').write_text(log,encoding='utf-8')
        if expected:
            assert r.returncode!=0 and expected in log, (mode,expected,log)
            return {'mode':mode,'expectedFailure':expected,'detected':True}
        assert r.returncode==0,log
        metrics=json.loads((dest/'capture-diagnostics.json').read_text())
        public=json.loads((dest/'latest-video.json').read_text())
        assert set(public)=={'schema','streamId','state','mimeType','codecs','width','height','fps','init','segments','stats','message'},set(public)
        assert set(public['stats'])=={'capturedFrames','encodedFrames','droppedFrames'}
        assert set(metrics['counts'])==set(['nativeSwapCallbacks','missingStampSwaps','failedSwaps','stampedCaptureAttempts','ceilingSkips','pboBusySkips','handoffBusySkips','captureAdmissions','fenceNotReady','readbackTransfers','pipeWrites','sidecarWriteFailures'])
        for row in metrics['timings'].values(): assert len(row['histogram'])==8 and sum(row['histogram'])==row['calls']
        return {'mode':mode,'checks':int(re.search(r'(?m)^PASS (\d+)$',log).group(1)),'sidecarSha256':digest(dest/'capture-diagnostics.json'),'publicManifestSha256':digest(dest/'latest-video.json')}
    for mode in ['pbo','ceiling','hook','pipe','worker']:results.append(execute(mode,out/mode))
    original=sources[Run.OBSERVER_SOURCES.index('StudyVideoCapture.java')].read_text(encoding='utf-8')
    controls=[
        ('pbo-counter','pbo','producer.diagnostics.count(5);','', 'pboBusySkips omitted'),
        ('handoff-counter','pbo','producer.diagnostics.count(6);','', 'handoffBusySkips omitted'),
        ('fence-timing','pbo','producer.diagnostics.duration(2,System.nanoTime()-oldest.submittedAtNs);','', 'fenceAge timing omitted'),
        ('pipe-timing','pipe','diagnostics.duration(4,System.nanoTime()-started);','', 'pipeWriteFlush stall timing omitted'),
        ('old-drop-semantics','pbo','producer.diagnostics.count(5);','producer.diagnostics.count(5); producer.dropped.incrementAndGet();', 'pre-admission PBO skips altered video stats'),
        ('ceiling-counter','ceiling','producer.diagnostics.count(4);','', 'ceilingSkips omitted'),
        ('swap-counter','hook','owner.diagnostics.count(0);','', 'native swap callback counter omitted'),
        ('sidecar-rate','worker','LockSupport.parkNanos(TimeUnit.SECONDS.toNanos(1));','', 'sidecar worker performed high-rate writes'),
    ]
    kills=[]
    for label,mode,anchor,replacement,failure in controls:
        assert original.count(anchor)==1,(label,original.count(anchor))
        folder=out/label;folder.mkdir();source=folder/'StudyVideoCapture.java';source.write_text(original.replace(anchor,replacement),encoding='utf-8')
        bad=folder/'classes';bad.mkdir()
        r,log=run([JDK/'javac.exe','-cp',cp,'-d',bad,source],ROOT)
        (folder/'compile.log').write_text(log,encoding='utf-8');assert r.returncode==0,log
        kills.append(execute(mode,folder/'output',os.pathsep.join([str(bad),cp]),failure))
    after={str(p):digest(p) for p in inputs};assert after==before,'inputs changed during native proof'
    receipt={'schema':'sao-native-capture-diagnostics-proof/1','status':'PASS','inputsBefore':before,'inputsAfter':after,
             'nativeControlledCases':results,'restoredDefects':kills,'checks':sum(x['checks'] for x in results),
             'boundary':'Actual maintained Java observer code compiled against installed native engine. GPU readiness and pipe sink controlled; real source method writes/flushes and concurrent stall executed. No game, GL rendering, live FPS attribution or encoder replay.'}
    (out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'status':'PASS','checks':receipt['checks'],'restoredControls':len(kills),'receipt':str(out/'receipt.json')}))

if __name__=='__main__':main()
