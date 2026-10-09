"""Execute native video framing, receipt binding and an actual NVENC pipeline."""
from __future__ import annotations

import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import tempfile
import types
import unittest
import uuid
from types import SimpleNamespace
from unittest.mock import patch

import world_lab_run as Run

ROOT = Path(__file__).resolve().parents[1]
GAME = Path(os.environ.get("PZ_DIR", "C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid"))
JDK = Path(os.environ.get("JDK_BIN", str(Path.home() / "Peanut Butter/JetBrains/Java/bin")))

PROBE = r'''
import java.nio.file.*;
import java.util.*;
import java.io.*;
import java.lang.reflect.*;
public class NativeVideoProbe {
    static void check(boolean value, String why) { if (!value) throw new AssertionError(why); }
    static void field(String name,Object value) throws Exception {
        var field=StudyVideoCapture.class.getDeclaredField(name);field.setAccessible(true);field.set(null,value);
    }
    static void observerField(String name,Object value) throws Exception {
        var field=StudyObserver.class.getDeclaredField(name);field.setAccessible(true);field.set(null,value);
    }
    static StudyVideoCapture.Producer nativeFactory(Path root,Path encoder) throws Exception {
        System.setProperty("study.viewDirectory",root.toString());System.setProperty("study.videoEncoder",encoder.toString());
        System.clearProperty("study.videoFps");field("readback",new StubReadback());
        var initialize=StudyVideoCapture.class.getDeclaredMethod("initialize",int.class,int.class);
        initialize.setAccessible(true);initialize.invoke(null,320,180);
        var owner=StudyVideoCapture.class.getDeclaredField("producer");owner.setAccessible(true);
        var producer=(StudyVideoCapture.Producer)owner.get(null);
        check(producer.fps==120,"native factory default capture ceiling differs");
        return producer;
    }
    static void tick() throws Exception {
        field("nextCapture",0L);
        StudyVideoCapture.swapped(new StudyViewCapture.FrameStamp(1,30));
    }
    static void snapshot(StudyVideoCapture.Producer producer,Path root,String name) throws Exception {
        producer.writeManifest();
        Files.copy(root.resolve("latest-video.json"),root.resolve(name+".snapshot.json"),StandardCopyOption.REPLACE_EXISTING);
        check(producer.encoded.get()+producer.dropped.get()<=producer.captured.get(),"capture stats contradict admitted frames");
    }
    static class StubReadback implements StudyVideoCapture.Readback {
        long nextFence; int maps,releasedBuffers;boolean mappingFailure;
        Set<Long> ready=new HashSet<>(),live=new HashSet<>();
        public int width(){return 320;}public int height(){return 180;}
        public void verifyContext(){}public int createBuffer(int width,int height){return 0;}
        public long capture(int buffer,int width,int height){long fence=++nextFence;live.add(fence);return fence;}
        public boolean ready(long fence){return ready.contains(fence);}
        public byte[] pixels(int buffer,int width,int height) throws IOException {
            maps++;if(mappingFailure)throw new IOException("controlled PBO mapping failure");
            return new byte[width*height*3];
        }
        public void releaseFence(long fence){check(live.remove(fence),"PBO fence disposed twice");}
        public void releaseBuffer(int buffer){releasedBuffers++;}
    }
    static void pbo(String mode,Path root) throws Exception {
        Files.createDirectories(root);
        System.setProperty("study.videoEncoder",root.resolve("not-started.exe").toString());
        var producer=new StudyVideoCapture.Producer(root,root.resolve("not-started.exe"),320,180,60,false);
        var gpu=new StubReadback();field("producer",producer);field("readback",gpu);field("initialized",true);
        var slots=StudyVideoCapture.class.getDeclaredField("SLOTS");slots.setAccessible(true);
        int buffer=0;for(Object slot:(Object[])slots.get(null)){
            var id=slot.getClass().getDeclaredField("buffer");id.setAccessible(true);id.setInt(slot,++buffer);
        }
        zombie.GameWindow.closeRequested=false;
        for(int i=0;i<3;i++)tick();
        check(producer.captured.get()==3,"PBO capture admission count differs");
        snapshot(producer,root,"admitted");
        for(int i=0;i<20;i++)tick();
        check(producer.captured.get()==3&&producer.dropped.get()==0,"unadmitted opportunities counted as captures or losses");
        snapshot(producer,root,"busy-slots");
        if(mode.equals("pbo-shutdown")) {
            zombie.GameWindow.closeRequested=true;tick();
            check(producer.closing,"PBO shutdown did not request encoder close");
            check(producer.dropped.get()==3,"cancelled PBO captures missing losses");
            check(gpu.live.isEmpty()&&gpu.releasedBuffers==3,"pending PBO shutdown retained resources");
            snapshot(producer,root,"cancelled");tick();
            check(producer.dropped.get()==3&&gpu.releasedBuffers==3,"PBO shutdown duplicated losses or disposal");
            snapshot(producer,root,"cancelled-again");
        } else if(mode.equals("pbo-failure")) {
            gpu.ready.addAll(gpu.live);gpu.mappingFailure=true;tick();
            check(producer.failed(),"PBO mapping failure was hidden");
            check(producer.captured.get()==3&&producer.dropped.get()==3,"failed PBO readbacks lost admission accounting");
            check(gpu.live.isEmpty()&&gpu.releasedBuffers==3,"failed PBO readbacks retained resources");
            snapshot(producer,root,"readback-failed");
        } else {
            gpu.ready.add(2L);tick();check(gpu.maps==0,"later PBO overtook pending older capture");
            snapshot(producer,root,"out-of-order-fence");
            gpu.ready.add(1L);tick();
            check(producer.captured.get()==3,"PBO readback counted twice");
            check(producer.latest.get().sequence()==2&&producer.dropped.get()==1,"completed PBO queue loss receipt differs");
            snapshot(producer,root,"two-completed");
            gpu.ready.add(3L);tick();
            check(producer.captured.get()==3,"PBO readback counted twice");
            check(producer.latest.get().sequence()==3&&producer.dropped.get()==2,"completed PBO order or drops differ");
            for(int i=0;i<20;i++)tick();
            check(producer.captured.get()==3&&producer.dropped.get()==2,"unadmitted opportunities counted as captures or losses");
            snapshot(producer,root,"encoder-backpressure");
            zombie.GameWindow.closeRequested=true;tick();
            check(producer.dropped.get()==2,"completed PBO release duplicated losses");
            producer.fail("PBO probe completed without encoding");
            check(producer.dropped.get()==3,"unsubmitted admitted frame missing loss");
            snapshot(producer,root,"closed");
        }
        producer.close();check(!producer.writer.isAlive(),"PBO accounting probe retained encoder worker");
    }
    static void publication(String mode,Path root,Path fixture,StudyVideoCapture.Site[] nativeSites) throws Exception {
        Files.createDirectories(root);
        var producer=new StudyVideoCapture.Producer(root,root.resolve("not-started.exe"),320,180,60,false);
        try(var input=Files.newInputStream(fixture)) {
            var ftyp=StudyVideoCapture.readBox(input);var moov=StudyVideoCapture.readBox(input);
            var init=StudyVideoCapture.parseInit(moov.bytes(),320,180);
            producer.timeScale=init.timeScale();producer.codecs=init.codecs();
            producer.initFile="video-"+producer.streamId+"-init.mp4";
            var commit=producer.getClass().getDeclaredMethod("commit",String.class,byte[].class);commit.setAccessible(true);
            var joined=new ByteArrayOutputStream();joined.write(ftyp.bytes());joined.write(moov.bytes());
            producer.initSha=(String)commit.invoke(producer,producer.initFile,joined.toByteArray());
            var moof=StudyVideoCapture.readBox(input);var mdat=StudyVideoCapture.readBox(input);
            var fragment=StudyVideoCapture.parseFragment(moof.bytes(),mdat.bytes());
            check(fragment.samples()>=3,"alignment fixture has no intermediate samples");
            var baseline=new StudyVideoCapture.Site("subject","Subject",0,10,20,-1.5f,0,0,320,180,1,1);
            long now=System.currentTimeMillis();
            for(int index=0;index<fragment.samples();index++) {
                var site=baseline;long command=1;
                if(index==fragment.samples()/2) {
                    if(mode.equals("zoom"))site=new StudyVideoCapture.Site("subject","Subject",0,10,20,-1.5f,0,0,320,180,Math.nextUp(1f),1);
                    if(mode.equals("target-zoom"))site=new StudyVideoCapture.Site("subject","Subject",0,10,20,-1.5f,0,0,320,180,1,Math.nextUp(1f));
                    if(mode.equals("pose"))site=new StudyVideoCapture.Site("subject","Subject",0,Math.nextUp(10f),20,-1.5f,0,0,320,180,1,1);
                    if(mode.equals("elevation"))site=new StudyVideoCapture.Site("subject","Subject",0,10,20,Math.nextUp(-1.5f),0,0,320,180,1,1);
                    if(mode.equals("geometry"))site=new StudyVideoCapture.Site("subject","Subject",0,10,20,-1.5f,0,0,319,180,1,1);
                    if(mode.equals("identity"))site=new StudyVideoCapture.Site("other","Other",0,10,20,-1.5f,0,0,320,180,1,1);
                    if(mode.equals("label"))site=new StudyVideoCapture.Site("subject","Renamed subject",0,10,20,-1.5f,0,0,320,180,1,1);
                    if(mode.equals("slot"))site=new StudyVideoCapture.Site("subject","Subject",1,10,20,-1.5f,0,0,320,180,1,1);
                    if(mode.equals("epoch"))command=2;
                }
                var sites=nativeSites==null?new StudyVideoCapture.Site[]{site}:nativeSites;
                if(mode.equals("unknown")&&index==fragment.samples()/2)sites=new StudyVideoCapture.Site[0];
                long sequence=producer.admitCapture();
                producer.submitted.add(new StudyVideoCapture.Frame(sequence,now+index,command,30+index*.01,sites,320,180,null));
            }
            joined.reset();joined.write(moof.bytes());joined.write(mdat.bytes());
            var publish=producer.getClass().getDeclaredMethod("publishFragment",StudyVideoCapture.Fragment.class,byte[].class);
            publish.setAccessible(true);publish.invoke(producer,fragment,joined.toByteArray());
            boolean stable=mode.equals("stable")||nativeSites!=null;
            check(producer.segments.getFirst().sites().length==(stable?1:0),
                "fragment misstates intermediate "+mode+" camera receipts");
            boolean cropStable=!Set.of("geometry","identity","slot","unknown").contains(mode);
            check(producer.segments.getFirst().crops().length==(cropStable?1:0),
                "fragment misstates intermediate "+mode+" crop receipts");
            check(producer.encoded.get()==fragment.samples()&&producer.captured.get()==fragment.samples(),
                "published sample receipt accounting differs");
            check(producer.submitted.isEmpty(),"publication left encoded metadata unmatched");
        }
        producer.close();
    }
    static void videoSites(String mode,Path root,Path fixture) throws Exception {
        System.setProperty("study.videoEncoder",root.resolve("not-started.exe").toString());
        zombie.core.random.RandStandard.INSTANCE.init();
        zombie.ZomboidFileSystem.instance.init();
        zombie.SoundManager.instance=new zombie.DummySoundManager();
        zombie.Lua.LuaManager.platform=new se.krka.kahlua.j2se.J2SEPlatform();
        zombie.Lua.LuaManager.env=zombie.Lua.LuaManager.platform.newTable();
        zombie.Lua.LuaEventManager.register(zombie.Lua.LuaManager.platform,zombie.Lua.LuaManager.env);
        check(StudyObserver.videoFrames().length==0,"uninitialized video invented a camera receipt");
        var view=new StudyObserver.View();view.setX(123.25f);view.setY(89.75f);view.setZ(-1.5f);
        observerField("camera",view);
        observerField("siteIds",new String[]{"declared-person"});observerField("siteLabels",new String[]{"Declared subject"});
        if(mode.equals("sites-declared"))System.setProperty("study.site.0.id","declared-person");
        zombie.characters.IsoPlayer.numPlayers=1;zombie.core.Core.width=960;zombie.core.Core.height=540;
        check(StudyObserver.siteFrames().length==0,"single video changed the legacy PNG site contract");
        var source=StudyObserver.videoFrames();check(source.length==1,"single native video receipt missing");
        check(source[0].id().equals(mode.equals("sites-declared")?"declared-person":"current")
            &&source[0].label().equals(mode.equals("sites-declared")?"Declared subject":"Current view"),
            "single native video identity differs from its declaration");
        check(source[0].slot()==0&&source[0].left()==0&&source[0].top()==0&&source[0].width()==960&&source[0].height()==540,
            "single native video did not cover the real primary viewport");
        check(source[0].x()==123.25f&&source[0].y()==89.75f&&source[0].z()==-1.5f,
            "single native video pose differs from its camera");
        var buffer=zombie.core.Core.getInstance().offscreenBuffer;buffer.setZoom(0,1.25f);buffer.setTargetZoom(0,1.75f);
        var sites=StudyVideoCapture.snapshotSites(StudyObserver.siteFrames());
        check(sites.length==1,"single video was disconnected from the capture hook");
        check(sites[0].x()==source[0].x()&&sites[0].y()==source[0].y()&&sites[0].z()==source[0].z()
            &&sites[0].zoom()==1.25f&&sites[0].targetZoom()==1.75f,"single video lost the current native pose or zoom");
        if(mode.equals("sites-multiple")) {
            var other=new StudyObserver.View();other.setX(73.5f);other.setY(42.25f);other.setZ(.5f);
            observerField("extraCameras",new StudyObserver.View[]{other});
            observerField("siteIds",new String[]{"first","second"});observerField("siteLabels",new String[]{"First","Second"});
            zombie.characters.IsoPlayer.numPlayers=2;zombie.core.Core.width=2560;zombie.core.Core.height=720;
            var png=StudyObserver.siteFrames();var video=StudyObserver.videoFrames();
            check(Arrays.equals(png,video)&&video.length==2,"video altered native split-site receipts");
            check(video[0].width()==1280&&video[0].height()==720&&video[1].left()==1280
                &&video[1].width()==1280&&video[1].height()==720&&video[1].x()==73.5f&&video[1].z()==.5f,
                "two native video sites collapsed or changed dimensions");
            return;
        }
        zombie.core.Core.width=320;zombie.core.Core.height=180;
        publication("stable",root,fixture,StudyVideoCapture.snapshotSites(StudyObserver.siteFrames()));
    }
    static void lowRate(Path root,Path encoder) throws Exception {
        var producer=nativeFactory(root,encoder);
        for(int index=0;index<36;index++) {
            byte[] pixels=new byte[320*180*3];
            for(int y=0;y<180;y++)for(int x=0;x<320;x++) {
                int at=(y*320+x)*3;pixels[at]=(byte)(x<160?220:20);pixels[at+1]=(byte)(index*5);
                pixels[at+2]=(byte)(x<160?20:220);
            }
            var first=new StudyVideoCapture.Site("first","First",0,10+index*.125f,20,-1.5f,0,0,160,180,1,1);
            var second=new StudyVideoCapture.Site("second","Second",1,30,40+index*.125f,.5f,160,0,160,180,1,1);
            producer.accept(new StudyVideoCapture.Frame(index+1,System.currentTimeMillis(),1+index/8,30+index*.01,
                new StudyVideoCapture.Site[]{first,second},320,180,pixels));
            Thread.sleep(75);
        }
        producer.close();check(!producer.failed(),"low-rate producer failed: "+producer.message);
        check(!producer.writer.isAlive(),"low-rate producer retained encoder worker");
        check(producer.captured.get()==36&&producer.encoded.get()>24
            &&producer.encoded.get()+producer.dropped.get()==36,"low-rate producer fabricated or lost frame receipts");
        check(producer.segments.size()>=4&&producer.segments.stream().allMatch(segment -> segment.durationMs()<=650),
            "time-scheduled fragments still depend on capture ceiling");
        check(producer.segments.stream().allMatch(segment -> segment.crops().length==2),"moving camera lost stable crop geometry");
        check(producer.segments.stream().anyMatch(segment -> segment.sites().length==0),"moving camera advertised a false stable pose");
    }
    static double gapWindow(StudyVideoCapture.Producer producer,Path root,Map<Long,String> receipts) throws Exception {
        synchronized(producer) {
            if(producer.segments.isEmpty())return Double.POSITIVE_INFINITY;
            var archive=root.resolve("observed-media");Files.createDirectories(archive);
            for(var segment:producer.segments) {
                if(receipts.containsKey(segment.sequence()))continue;
                byte[] media=Files.readAllBytes(root.resolve(segment.file()));
                StudyVideoCapture.Fragment parsed;
                try(var input=new ByteArrayInputStream(media)) {
                    var moof=StudyVideoCapture.readBox(input);var mdat=StudyVideoCapture.readBox(input);
                    parsed=StudyVideoCapture.parseFragment(moof.bytes(),mdat.bytes());
                    check(StudyVideoCapture.readBox(input)==null,"gap receipt contains trailing media");
                }
                check(parsed.pts()*1000.0/producer.timeScale==segment.ptsStartMs()
                    &&parsed.duration()*1000.0/producer.timeScale==segment.durationMs(),"gap receipt changed actual encoded clocks");
                Files.write(archive.resolve(segment.file()),media);
                receipts.put(segment.sequence(),"{\"segment\":"+segment.json()+",\"encodedSamples\":"+parsed.samples()+"}");
            }
            long last=producer.segments.getLast().sequence();
            Files.copy(root.resolve("latest-video.json"),root.resolve(String.format("window-%016d.snapshot.json",last)),
                StandardCopyOption.REPLACE_EXISTING);
            return producer.segments.size()==StudyVideoCapture.RETAIN_SEGMENTS
                ?producer.segments.stream().mapToDouble(segment->segment.durationMs()).sum():Double.POSITIVE_INFINITY;
        }
    }
    static void delayedGap(Path root,Path encoder) throws Exception {
        var producer=nativeFactory(root,encoder);var receipts=new LinkedHashMap<Long,String>();
        var admitted=new ArrayList<String>();double minimumWindow=Double.POSITIVE_INFINITY;
        for(int index=0;index<100;index++) {
            byte[] pixels=new byte[320*180*3];
            for(int y=0;y<180;y++)for(int x=0;x<320;x++) {
                int at=(y*320+x)*3;pixels[at]=(byte)(x<160?220:20);pixels[at+1]=(byte)(index*2);
                pixels[at+2]=(byte)(x<160?20:220);
            }
            var first=new StudyVideoCapture.Site("first","First",0,10+index*.125f,20,-1.5f,0,0,160,180,1,1);
            var second=new StudyVideoCapture.Site("second","Second",1,30,40+index*.125f,.5f,160,0,160,180,1,1);
            long now=System.currentTimeMillis();
            admitted.add("{\"sequence\":"+(index+1)+",\"capturedAtUnixMs\":"+now+"}");
            producer.accept(new StudyVideoCapture.Frame(index+1,now,1+index/8,30+index*.01,
                new StudyVideoCapture.Site[]{first,second},320,180,pixels));
            Thread.sleep(45);
            minimumWindow=Math.min(minimumWindow,gapWindow(producer,root,receipts));
            if(index==35)Thread.sleep(2200);
        }
        producer.close();minimumWindow=Math.min(minimumWindow,gapWindow(producer,root,receipts));
        check(!producer.failed(),"delayed-gap producer failed: "+producer.message);
        check(!producer.writer.isAlive(),"delayed-gap producer retained encoder worker");
        check(producer.captured.get()==100&&producer.encoded.get()>80
            &&producer.encoded.get()+producer.dropped.get()==100,"delayed-gap producer fabricated or lost frame receipts");
        check(Double.isFinite(minimumWindow),"delayed-gap probe did not observe a full source window");
        Files.writeString(root.resolve("gap-receipts.json"),
            "{\"schema\":\"sao-native-video-gap-probe/1\",\"captureCeiling\":120,\"submissionIntervalMs\":45,"
            +"\"requestedGapMs\":2200,\"minimumFullWindowMs\":"+minimumWindow+",\"admitted\":["
            +String.join(",",admitted)+"],\"fragments\":["+String.join(",",receipts.values())+"]}");
        check(minimumWindow>=1500,"time-gap IDR catch-up shrank the retained source window");
    }
    static void qualityImage(Path root, Path encoder, Path image, int ceiling) throws Exception {
        var source=javax.imageio.ImageIO.read(image.toFile());
        int width=source.getWidth(),height=source.getHeight();
        byte[] pixels=new byte[width*height*3];
        for(int y=0;y<height;y++)for(int x=0;x<width;x++) {
            int rgb=source.getRGB(x,y),offset=((height-1-y)*width+x)*3;
            pixels[offset]=(byte)(rgb>>>16);pixels[offset+1]=(byte)(rgb>>>8);pixels[offset+2]=(byte)rgb;
        }
        var producer=new StudyVideoCapture.Producer(root,encoder,width,height,ceiling);
        for(int i=0;i<30;i++) {
            producer.accept(new StudyVideoCapture.Frame(i+1,System.currentTimeMillis(),1,2+i*.001,
                new StudyVideoCapture.Site[0],width,height,pixels));
            Thread.sleep(100);
        }
        producer.close();
        check(!producer.failed(),"quality producer failed");
        check(producer.encoded.get()>=25,"quality producer dropped too many sparse frames");
        check(producer.encoded.get()+producer.dropped.get()==30,"quality producer lost source accounting");
    }
    public static void main(String[] args) throws Exception {
        String mode=args[0]; Path root=Path.of(args[1]);
        if(mode.equals("quality-image")){qualityImage(root,Path.of(args[2]),Path.of(args[3]),Integer.parseInt(args[4]));return;}
        if(mode.startsWith("pbo-")){pbo(mode,root);return;}
        if(mode.startsWith("sites-")){videoSites(mode,root,Path.of(args[2]));return;}
        if(mode.startsWith("alignment-")){publication(mode.substring(10),root,Path.of(args[2]),null);return;}
        if(mode.equals("low-rate")){lowRate(root,Path.of(args[2]));return;}
        if(mode.equals("delayed-gap")){delayedGap(root,Path.of(args[2]));return;}
        if (mode.equals("parse")) {
            try (var input=Files.newInputStream(root)) {
                var ftyp=StudyVideoCapture.readBox(input); check(ftyp.type().equals("ftyp"), "ftyp missing");
                var moov=StudyVideoCapture.readBox(input);
                var init=StudyVideoCapture.parseInit(moov.bytes(),320,180);
                int frames=0, fragments=0; long end=-1;
                for (;;) {
                    var moof=StudyVideoCapture.readBox(input); if (moof==null) break;
                    var mdat=StudyVideoCapture.readBox(input); check(mdat!=null,"partial fragment advertised");
                    var fragment=StudyVideoCapture.parseFragment(moof.bytes(),mdat.bytes());
                    check(fragment.pts()>=end,"video clock regressed"); end=fragment.pts()+fragment.duration();
                    frames+=fragment.samples(); fragments++;
                }
                System.out.println("PARSED "+init.codecs()+" "+frames+" "+fragments);
            }
        } else if (mode.equals("produce")) {
            var producer=new StudyVideoCapture.Producer(root,Path.of(args[2]),320,180,60);
            long base=System.currentTimeMillis();
            for (int index=0;index<180;index++) {
                byte[] pixels=new byte[320*180*3];
                for (int y=0;y<180;y++) for(int x=0;x<320;x++) {
                    int at=(y*320+x)*3;
                    pixels[at]=(byte)(y<90?220:20); pixels[at+1]=(byte)(index%180); pixels[at+2]=(byte)(y<90?20:220);
                }
                long command=(index>=170&&(index&1)==0)?2:1;
                var site=new StudyVideoCapture.Site("subject","Subject",0,10,20,0,0,0,320,180,1,1);
                producer.accept(new StudyVideoCapture.Frame(index+1,System.currentTimeMillis(),command,30+index*.01,
                    new StudyVideoCapture.Site[]{site},320,180,pixels));
                Thread.sleep(index==160?650:16);
            }
            producer.close();
            check(!producer.writer.isAlive(),"video worker did not finish");
            check(!producer.failed(),"video producer failed: "+producer.message);
            check(producer.encoded.get()>80,"video did not encode enough unique frames");
            check(producer.captured.get()==180,"native captured count differs");
            check(producer.encoded.get()+producer.dropped.get()==180,"video losses are unaccounted");
            System.out.println("PRODUCED "+base+" "+System.currentTimeMillis());
        } else if (mode.equals("failure")) {
            var producer=new StudyVideoCapture.Producer(root,Path.of(args[2]),320,180,60);
            producer.accept(new StudyVideoCapture.Frame(1,1,1,30,new StudyVideoCapture.Site[0],320,180,new byte[320*180*3]));
            Thread.sleep(200); producer.close();
            check(producer.failed(),"missing encoder failure hidden");
            check(!producer.writer.isAlive(),"failed encoder worker retained");
            check(producer.encoded.get()==0,"failure fabricated encoded frames");
        } else if (mode.equals("bounded")) {
            var producer=new StudyVideoCapture.Producer(root,Path.of(args[2]),320,180,60);
            for (int index=0;index<2000;index++) {
                producer.accept(new StudyVideoCapture.Frame(index+1,index+1,1,30,new StudyVideoCapture.Site[0],320,180,new byte[320*180*3]));
            }
            check(producer.latest.get()==null||producer.latest.get().sequence()>0,"latest frame queue invalid");
            check(producer.submitted.size()<=StudyVideoCapture.MAX_PENDING_METADATA,"metadata queue unbounded");
            producer.close();
            check(producer.dropped.get()>0,"backpressure did not account for dropped captures");
            check(!producer.writer.isAlive(),"backpressure retained encoder worker");
        }
    }
}
'''


def encoder_path():
    configured = os.environ.get("FFMPEG_EXECUTABLE")
    if configured:
        return Path(configured)
    winget = Path.home() / "AppData/Local/Microsoft/WinGet/Packages"
    candidates = sorted(winget.glob("Gyan.FFmpeg_*/ffmpeg-*-full_build/bin/ffmpeg.exe"))
    return candidates[-1] if candidates else None


class VideoOptions(unittest.TestCase):
    def test_absent_encoder_preserves_default_capture(self):
        self.assertEqual(Run.video_options(SimpleNamespace(host="observer")), {})

    def test_missing_rate_option_defaults_to_120_and_preserves_explicit_ceilings(self):
        with tempfile.TemporaryDirectory() as directory:
            encoder = Path(directory) / "encoder.exe"; encoder.write_bytes(b"fixture")
            args = SimpleNamespace(host="observer", video_encoder=encoder)
            self.assertEqual(Run.video_options(args)["videoFps"], 120)
            for ceiling in (30, 60, 90, 120):
                args.video_fps = ceiling
                self.assertEqual(Run.video_options(args)["videoFps"], ceiling)

    def assert_cli_default(self, module, encoder, resume, explicit=None):
        argv = ["world_lab_run.py", "package", "--out", "owned-cache", "--game", "game", "--jdk", "jdk",
                "--video-encoder", str(encoder)]
        if resume:
            argv.append("--resume")
        if explicit is not None:
            argv.extend(("--video-fps", str(explicit)))
        with patch.object(sys, "argv", argv), patch.object(module, "run", return_value=0) as launch:
            self.assertEqual(module.main(), 0)
        args = launch.call_args.args[0]
        self.assertEqual(args.resume, resume)
        self.assertEqual(args.video_fps, explicit if explicit is not None else 120,
                         "runner CLI default capture ceiling differs")
        self.assertEqual(module.video_options(args)["videoFps"], args.video_fps)

    def test_initial_and_resume_cli_default_to_120_and_preserve_explicit_60(self):
        with tempfile.TemporaryDirectory() as directory:
            encoder = Path(directory) / "encoder.exe"; encoder.write_bytes(b"fixture")
            for resume in (False, True):
                self.assert_cli_default(Run, encoder, resume)
                self.assert_cli_default(Run, encoder, resume, explicit=60)

    def test_runner_default_source_controls_reject_old_sixty(self):
        path = Path(Run.__file__); original = path.read_text(encoding="utf-8")
        controls = [("api", 'getattr(args, "video_fps", 120)', 'getattr(args, "video_fps", 60)'),
                    ("cli", 'parser.add_argument("--video-fps", type=int, default=120,',
                     'parser.add_argument("--video-fps", type=int, default=60,')]
        with tempfile.TemporaryDirectory() as directory:
            encoder = Path(directory) / "encoder.exe"; encoder.write_bytes(b"fixture")
            for label, before, after in controls:
                self.assertEqual(original.count(before), 1)
                module = types.ModuleType("runner_default_control_" + label); module.__dict__["__file__"] = str(path)
                exec(compile(original.replace(before, after), "<runner-default-control>", "exec"), module.__dict__)
                with self.assertRaises(AssertionError):
                    if label == "api":
                        self.assertEqual(module.video_options(SimpleNamespace(host="observer", video_encoder=encoder))["videoFps"], 120,
                                         "runner API default capture ceiling differs")
                    else:
                        self.assert_cli_default(module, encoder, resume=True)
        self.assertEqual(path.read_text(encoding="utf-8"), original)

    def test_rate_and_host_are_validated(self):
        for fps in (29, 121, True):
            with self.assertRaises(ValueError):
                Run.video_options(SimpleNamespace(host="observer", video_fps=fps))
        with tempfile.TemporaryDirectory() as directory:
            encoder = Path(directory) / "encoder.exe"; encoder.write_bytes(b"fixture")
            self.assertEqual(Run.video_options(SimpleNamespace(host="observer", video_encoder=encoder, video_fps=120)),
                             {"videoEncoder": str(encoder.resolve()), "videoFps": 120})
            with self.assertRaisesRegex(ValueError, "captured observer or participant host"):
                Run.video_options(SimpleNamespace(host="player", video_encoder=encoder))

    def test_current_adapter_contains_the_video_source(self):
        self.assertEqual(set(Run.OBSERVER_SOURCES),
                         {"StudyLoadingAgent.java", "StudyObserver.java", "StudyViewCapture.java", "StudyExport.java", "StudyVideoCapture.java"})


class NativeVideo(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not (GAME / "projectzomboid.jar").is_file() or not (JDK / "javac.exe").is_file():
            raise unittest.SkipTest("installed game or JDK unavailable")
        cls.temporary = tempfile.TemporaryDirectory(prefix="sao-native-video-")
        cls.work = Path(cls.temporary.name)
        cls.classes = cls.work / "classes"; cls.classes.mkdir()
        cls.classpath = os.pathsep.join(map(str, [cls.classes, GAME / "projectzomboid.jar", GAME / "ZombieBuddy.jar"]))
        probe = cls.work / "NativeVideoProbe.java"; probe.write_text(PROBE, encoding="utf-8")
        result = subprocess.run([str(JDK / "javac.exe"), "-cp", cls.classpath, "-d", str(cls.classes),
            *map(str, [ROOT / "tools/world_lab" / name for name in Run.OBSERVER_SOURCES]), str(probe)],
            capture_output=True, text=True, timeout=60)
        if result.returncode:
            raise AssertionError(result.stdout + result.stderr)
        cls.encoder = encoder_path()
        cls.fixture = cls.work / "fixture.mp4"
        if cls.encoder:
            result = subprocess.run([str(cls.encoder), "-hide_banner", "-loglevel", "error", "-f", "lavfi", "-i",
                "testsrc2=size=320x180:rate=60", "-t", "2", "-c:v", "h264_nvenc", "-preset", "p1", "-tune", "ull",
                "-profile:v", "high", "-bf", "0", "-g", "15", "-movflags",
                "+frag_keyframe+empty_moov+default_base_moof+skip_trailer", str(cls.fixture)],
                capture_output=True, text=True, timeout=30)
            if result.returncode:
                raise AssertionError("configured NVENC encoder failed: " + result.stderr)

    @classmethod
    def tearDownClass(cls):
        cls.temporary.cleanup()

    def java(self, *args, bad=None, classpath=None):
        result = subprocess.run([str(GAME / "jre64/bin/java.exe"), "-Djava.awt.headless=true", "-cp", classpath or self.classpath,
            "NativeVideoProbe", *map(str, args)], cwd=GAME, capture_output=True, text=True, timeout=30)
        text = result.stdout + result.stderr
        if result.returncode and not bad:
            logs = list(Path(args[1]).glob("video-*.log")) if Path(args[1]).is_dir() else []
            for log in logs:
                text += "\nENCODER LOG\n" + log.read_text(encoding="utf-8", errors="replace")[-6000:]
            retained = ROOT / "_scratch/c116-video" / ("failed-" + uuid.uuid4().hex)
            retained.parent.mkdir(parents=True, exist_ok=True)
            if Path(args[1]).is_dir(): shutil.copytree(args[1], retained)
            retained.with_suffix(".log").write_text(text, encoding="utf-8")
        if bad:
            self.assertNotEqual(result.returncode, 0, "known bad video survived")
            self.assertIn(bad, text)
        else:
            self.assertEqual(result.returncode, 0, text)
        return text

    def require_encoder(self):
        if not self.encoder:
            self.skipTest("local NVENC FFmpeg executable unavailable")

    def current_consumers_available(self):
        return bool((ROOT.parent / "speakeasy-r88-video-observation/tools/native_video.py").is_file()
                    and shutil.which("node")
                    and (ROOT.parent / "mousecat-a24-live-observation/src/core/native-video.mjs").is_file())

    def validate_snapshots(self, root):
        snapshots = sorted(root.glob("*.snapshot.json"))
        self.assertGreater(len(snapshots), 2)
        values = [json.loads(path.read_text(encoding="utf-8")) for path in snapshots]
        values.append(json.loads((root / "latest-video.json").read_text(encoding="utf-8")))
        self.validate_values(values)

    def validate_values(self, values):
        for value in values:
            stats = value["stats"]
            self.assertEqual(set(stats), {"capturedFrames", "encodedFrames", "droppedFrames"})
            self.assertTrue(all(type(v) is int and v >= 0 for v in stats.values()))
            self.assertLessEqual(stats["encodedFrames"] + stats["droppedFrames"], stats["capturedFrames"])
        # Exercise the current typed consumer boundaries when their sibling
        # worktrees are installed; local counter checks run on every machine.
        python = ROOT.parent / "speakeasy-r88-video-observation/tools/native_video.py"
        if python.is_file():
            spec = importlib.util.spec_from_file_location("native_video_stats_consumer", python)
            consumer = importlib.util.module_from_spec(spec); spec.loader.exec_module(consumer)
            for value in values:
                consumer.validate(value)
        javascript = ROOT.parent / "mousecat-a24-live-observation/src/core/native-video.mjs"
        node = shutil.which("node")
        if node and javascript.is_file():
            program = ('import {readFileSync} from "node:fs";import {pathToFileURL} from "node:url";'
                       'const {validateNativeVideo}=await import(pathToFileURL(process.argv[1]));'
                       'for(const value of JSON.parse(readFileSync(0,"utf8")))'
                       'validateNativeVideo({...value,schema:"mousecat.native-video/1"});')
            result = subprocess.run([node, "--input-type=module", "-e", program, str(javascript)],
                                    input=json.dumps(values), capture_output=True, text=True, timeout=30)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def validate_publication(self, root):
        value = json.loads((root / "latest-video.json").read_text(encoding="utf-8"))
        self.validate_values([value])
        init = (root / value["init"]["file"]).read_bytes()
        self.assertEqual(hashlib.sha256(init).hexdigest(), value["init"]["sha256"])
        python = ROOT.parent / "speakeasy-r88-video-observation/tools/native_video.py"
        if python.is_file():
            spec = importlib.util.spec_from_file_location("native_video_receipt_consumer", python)
            consumer = importlib.util.module_from_spec(spec); spec.loader.exec_module(consumer)
            defaults = consumer.init_info(init, value)
            for segment in value["segments"]:
                media = (root / segment["file"]).read_bytes()
                self.assertEqual(hashlib.sha256(media).hexdigest(), segment["sha256"])
                consumer.media_info(media, segment, defaults)
        javascript = ROOT.parent / "mousecat-a24-live-observation/src/core/native-video.mjs"
        node = shutil.which("node")
        if node and javascript.is_file():
            program = ('import {readFileSync} from "node:fs";import {pathToFileURL} from "node:url";'
                       'import {join} from "node:path";'
                       'const {validateVideoInit,validateVideoBytes}=await import(pathToFileURL(process.argv[1]));'
                       'const video={...JSON.parse(readFileSync(0,"utf8")),schema:"mousecat.native-video/1"};'
                       'const defaults=validateVideoInit(readFileSync(join(process.argv[2],video.init.file)),video);'
                       'for(const segment of video.segments)'
                       'validateVideoBytes(readFileSync(join(process.argv[2],segment.file)),segment,video,defaults);')
            result = subprocess.run([node, "--input-type=module", "-e", program, str(javascript), str(root)],
                                    input=json.dumps(value), capture_output=True, text=True, timeout=30)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return value

    def test_actual_implicit_single_view_has_native_pose_zoom_and_full_receipt(self):
        self.require_encoder()
        out = self.work / "sites-implicit"; self.java("sites-implicit", out, self.fixture)
        value = self.validate_publication(out)
        site = value["segments"][0]["sites"][0]
        self.assertEqual((site["id"], site["label"]), ("current", "Current view"))
        self.assertEqual((site["x"], site["y"], site["z"]), (123.25, 89.75, -1.5))
        self.assertEqual((site["left"], site["top"], site["width"], site["height"]), (0, 0, 320, 180))
        self.assertEqual((site["zoom"], site["targetZoom"]), (1.25, 1.75))
        self.assertEqual(value["segments"][0]["crops"], [{key: site[key] for key in ("id", "slot", "left", "top", "width", "height")}])

    def test_actual_declared_single_view_keeps_its_authored_identity(self):
        self.require_encoder()
        out = self.work / "sites-declared"; self.java("sites-declared", out, self.fixture)
        value = self.validate_publication(out)
        site = value["segments"][0]["sites"][0]
        self.assertEqual((site["id"], site["label"]), ("declared-person", "Declared subject"))

    def test_actual_two_native_views_retain_their_existing_split_receipts(self):
        self.java("sites-multiple", self.work / "sites-multiple", self.fixture)

    def test_encoded_fragment_withholds_all_intermediate_camera_changes(self):
        self.require_encoder()
        for mode in ("stable", "zoom", "target-zoom", "pose", "elevation", "geometry", "identity", "label", "slot", "epoch", "unknown"):
            with self.subTest(mode=mode):
                out = self.work / ("alignment-" + mode)
                self.java("alignment-" + mode, out, self.fixture)
                value = self.validate_publication(out)
                self.assertEqual(len(value["segments"][0]["sites"]), 1 if mode == "stable" else 0)
                expected_crops = [] if mode in ("geometry", "identity", "slot", "unknown") else [
                    dict(id="subject", slot=0, left=0, top=0, width=320, height=180)]
                self.assertEqual(value["segments"][0]["crops"], expected_crops)

    def test_crop_source_controls_reject_coupled_pose_and_transient_geometry_identity(self):
        self.require_encoder()
        path = ROOT / "tools/world_lab/StudyVideoCapture.java"
        original = path.read_text(encoding="utf-8")
        controls = [
            ("crop-coupled-to-pose", "Crop[] crops = sameCrop ? firstCrops : new Crop[0];",
             "Crop[] crops = sameView ? firstCrops : new Crop[0];", "pose"),
            ("crop-endpoints-only", "frames.stream().allMatch(frame -> Arrays.equals(cropsOf(frame.sites()), firstCrops))",
             "Arrays.equals(cropsOf(last.sites()), firstCrops)", "geometry"),
            ("crop-identity-ignored", "new Crop(site.id(), site.slot(), site.left()",
             'new Crop("ignored", site.slot(), site.left()', "identity"),
            ("crop-slot-ignored", "new Crop(site.id(), site.slot(), site.left()",
             "new Crop(site.id(), 0, site.left()", "slot"),
        ]
        for label, before, after, mode in controls:
            self.assertEqual(original.count(before), 1, "Executable crop control target differs: " + label)
            bad = self.work / ("control-" + label); bad.mkdir()
            source = bad / path.name; source.write_text(original.replace(before, after), encoding="utf-8")
            result = subprocess.run([str(JDK / "javac.exe"), "-cp", self.classpath, "-d", str(bad), str(source)],
                                    capture_output=True, text=True, timeout=30)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.java("alignment-" + mode, bad / "output", self.fixture,
                      bad="fragment misstates intermediate " + mode + " crop receipts",
                      classpath=str(bad) + os.pathsep + self.classpath)
        self.assertEqual(path.read_text(encoding="utf-8"), original)

    def test_actual_low_frame_rate_with_high_ceiling_has_time_bounded_idr_fragments(self):
        self.require_encoder()
        out = self.work / "low-rate"; self.java("low-rate", out, self.encoder)
        value = self.validate_publication(out)
        self.assertEqual(value["state"], "ended")
        self.assertEqual(value["fps"], 120)
        self.assertEqual(value["stats"]["capturedFrames"], 36)
        self.assertEqual(value["stats"]["encodedFrames"] + value["stats"]["droppedFrames"], 36)
        init = (out / value["init"]["file"]).read_bytes()
        for segment in value["segments"]:
            self.assertLessEqual(segment["durationMs"], 650)
            self.assertEqual(segment["crops"], [dict(id="first", slot=0, left=0, top=0, width=160, height=180),
                                                dict(id="second", slot=1, left=160, top=0, width=160, height=180)])
            sample = out / "joined.mp4"; sample.write_bytes(init + (out / segment["file"]).read_bytes())
            result = subprocess.run([str(self.encoder), "-v", "error", "-i", str(sample), "-f", "null", "-"],
                                    capture_output=True, text=True, timeout=30)
            self.assertEqual(result.returncode, 0, result.stderr)
        proof = ROOT / "_scratch/c116-video" / ("low-rate-producer-proof-" + uuid.uuid4().hex)
        proof.parent.mkdir(parents=True, exist_ok=True); shutil.copytree(out, proof)
        (proof / "proof.json").write_text(json.dumps({
            "kind": "actual-raw-RGB-NVENC-low-rate", "loadedGame": False,
            "sourceSha256": {name: hashlib.sha256((ROOT / "tools/world_lab" / name).read_bytes()).hexdigest()
                             for name in Run.OBSERVER_SOURCES},
            "testSha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
            "stats": value["stats"], "fpsCeiling": 120, "nativeFactoryDefault": True, "submissionIntervalMs": 75,
            "fragmentDurationsMs": [segment["durationMs"] for segment in value["segments"]],
            "retainedSegments": len(value["segments"]), "codecs": value["codecs"],
            "encoderSha256": hashlib.sha256(self.encoder.read_bytes()).hexdigest(),
            "independentFragmentsDecode": True, "movingPoseWithheld": True,
            "stableTwoCropReceiptsRetained": True,
            "currentPythonJavaScriptBytesValidated": self.current_consumers_available()}, indent=2), encoding="utf-8")

    def delayed_gap_receipts(self, out):
        self.validate_snapshots(out)
        video = self.validate_publication(out)
        self.assertEqual(video["state"], "ended")
        self.assertEqual(video["fps"], 120)
        self.assertEqual(video["stats"]["capturedFrames"], 100)
        receipts = json.loads((out / "gap-receipts.json").read_text(encoding="utf-8"))
        archived_views = {}
        for path in sorted(out.glob("*.snapshot.json")):
            source = json.loads(path.read_text(encoding="utf-8"))
            for segment in source["segments"]:
                archived_views.setdefault(segment["file"], source)
        admitted = receipts["admitted"]
        self.assertEqual([row["sequence"] for row in admitted], list(range(1, 101)))
        capture_clocks = {row["sequence"]: row["capturedAtUnixMs"] for row in admitted}
        self.assertTrue(all(a["capturedAtUnixMs"] <= b["capturedAtUnixMs"] for a, b in zip(admitted, admitted[1:])))
        self.assertGreaterEqual(max(b["capturedAtUnixMs"] - a["capturedAtUnixMs"]
                                    for a, b in zip(admitted, admitted[1:])), 2100)
        fragments = receipts["fragments"]
        self.assertEqual(sum(row["encodedSamples"] for row in fragments), video["stats"]["encodedFrames"])
        self.assertGreaterEqual(max(row["segment"]["durationMs"] for row in fragments), 1900)
        init = (out / video["init"]["file"]).read_bytes()
        python = ROOT.parent / "speakeasy-r88-video-observation/tools/native_video.py"
        if python.is_file():
            spec = importlib.util.spec_from_file_location("native_video_gap_consumer", python)
            consumer = importlib.util.module_from_spec(spec); spec.loader.exec_module(consumer)
            defaults = consumer.init_info(init, video)
        prior = None
        for row in fragments:
            segment = row["segment"]
            self.assertIn(segment["file"], archived_views)
            self.assertIn(segment, archived_views[segment["file"]]["segments"])
            self.assertEqual(segment["capturedAtUnixMs"], capture_clocks[segment["firstFrameSequence"]])
            self.assertEqual(segment["endCapturedAtUnixMs"], capture_clocks[segment["lastFrameSequence"]])
            self.assertEqual(segment["worldHours"], 30 + (segment["firstFrameSequence"] - 1) * .01)
            self.assertEqual(segment["endWorldHours"], 30 + (segment["lastFrameSequence"] - 1) * .01)
            self.assertLessEqual(row["encodedSamples"], segment["lastFrameSequence"] - segment["firstFrameSequence"] + 1)
            if prior:
                self.assertEqual(segment["sequence"], prior["sequence"] + 1)
                self.assertGreater(segment["firstFrameSequence"], prior["lastFrameSequence"])
                self.assertGreaterEqual(segment["ptsStartMs"], prior["ptsStartMs"] + prior["durationMs"])
            prior = segment
            media = (out / "observed-media" / segment["file"]).read_bytes()
            self.assertEqual(hashlib.sha256(media).hexdigest(), segment["sha256"])
            if python.is_file():
                consumer.media_info(media, segment, defaults)
            joined = out / "joined.mp4"; joined.write_bytes(init + media)
            result = subprocess.run([str(self.encoder), "-v", "error", "-i", str(joined), "-f", "null", "-"],
                                    capture_output=True, text=True, timeout=30)
            self.assertEqual(result.returncode, 0, result.stderr)
        javascript = ROOT.parent / "mousecat-a24-live-observation/src/core/native-video.mjs"
        node = shutil.which("node")
        if node and javascript.is_file():
            program = ('import {readFileSync} from "node:fs";import {pathToFileURL} from "node:url";'
                       'import {join} from "node:path";'
                       'const {validateNativeVideo,validateVideoInit,validateVideoBytes}=await import(pathToFileURL(process.argv[1]));'
                       'const input=JSON.parse(readFileSync(0,"utf8"));'
                       'const video={...input.video,schema:"mousecat.native-video/1"};'
                       'const defaults=validateVideoInit(readFileSync(join(process.argv[2],video.init.file)),video);'
                       'for(const receipt of input.receipts.fragments){'
                       'const source={...input.archivedViews[receipt.segment.file],schema:"mousecat.native-video/1"};'
                       'validateNativeVideo(source);'
                       'validateVideoBytes(readFileSync(join(process.argv[2],"observed-media",receipt.segment.file)),receipt.segment,source,defaults);}')
            result = subprocess.run([node, "--input-type=module", "-e", program, str(javascript), str(out)],
                                    input=json.dumps(dict(video=video, receipts=receipts, archivedViews=archived_views)),
                                    capture_output=True, text=True, timeout=30)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return video, receipts

    def save_gap_proof(self, out, video, receipts, *, old_source=None, failure=None):
        label = "old-absolute-gap-control-" if old_source else "relative-keyframe-gap-proof-"
        proof = ROOT / "_scratch/c116-video" / (label + uuid.uuid4().hex)
        proof.parent.mkdir(parents=True, exist_ok=True); shutil.copytree(out, proof)
        if failure:
            (proof / "expected-failure.log").write_text(failure, encoding="utf-8")
        maximum_run = run = 0
        for row in receipts["fragments"]:
            run = run + 1 if row["encodedSamples"] == 1 else 0
            maximum_run = max(maximum_run, run)
        value = {
            "kind": "executing-old-absolute-keyframe-control" if old_source else "actual-raw-RGB-NVENC-delayed-keyframe",
            "loadedGame": False, "sourceSha256": {name: hashlib.sha256((ROOT / "tools/world_lab" / name).read_bytes()).hexdigest()
                                                     for name in Run.OBSERVER_SOURCES},
            "testSha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
            "fpsCeiling": 120, "nativeFactoryDefault": True, "submissionIntervalMs": 45,
            "deliberateGapMs": 2200, "minimumFullWindowMs": receipts["minimumFullWindowMs"],
            "maximumOneSampleRun": maximum_run, "stats": video["stats"], "codecs": video["codecs"],
            "fragmentDurationsMs": [row["segment"]["durationMs"] for row in receipts["fragments"]],
            "actualSamplesByFragment": [row["encodedSamples"] for row in receipts["fragments"]],
            "encoderSha256": hashlib.sha256(self.encoder.read_bytes()).hexdigest(),
            "independentFragmentsDecode": True, "nativeCaptureClocksPreserved": True,
            "encodedPtsGapPreserved": True, "currentPythonJavaScriptBytesValidated": self.current_consumers_available()}
        if old_source:
            value.update(modifiedSourceSha256=hashlib.sha256(old_source.read_bytes()).hexdigest(),
                         expectedFailure="time-gap IDR catch-up shrank the retained source window")
        (proof / "proof.json").write_text(json.dumps(value, indent=2), encoding="utf-8")
        return value

    def test_actual_delayed_frames_preserve_source_gaps_and_retained_time_window(self):
        self.require_encoder()
        out = self.work / "relative-delayed-gap"; self.java("delayed-gap", out, self.encoder)
        video, receipts = self.delayed_gap_receipts(out)
        self.assertGreaterEqual(receipts["minimumFullWindowMs"], 1500)
        proof = self.save_gap_proof(out, video, receipts)
        self.assertLessEqual(proof["maximumOneSampleRun"], 2)

    def test_old_absolute_keyframe_source_control_recreates_post_gap_burst(self):
        self.require_encoder()
        path = ROOT / "tools/world_lab/StudyVideoCapture.java"
        original = path.read_text(encoding="utf-8")
        before = '"expr:if(isnan(prev_forced_t),1,gte(t,prev_forced_t+0.25))"'
        self.assertEqual(original.count(before), 1)
        bad = self.work / "control-old-absolute-keyframes"; bad.mkdir()
        source = bad / path.name
        source.write_text(original.replace(before, '"expr:gte(t,n_forced*0.25)"'), encoding="utf-8")
        result = subprocess.run([str(JDK / "javac.exe"), "-cp", self.classpath, "-d", str(bad), str(source)],
                                capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        failure = self.java("delayed-gap", bad / "output", self.encoder,
                            bad="time-gap IDR catch-up shrank the retained source window",
                            classpath=str(bad) + os.pathsep + self.classpath)
        video, receipts = self.delayed_gap_receipts(bad / "output")
        self.assertLess(receipts["minimumFullWindowMs"], 1500)
        proof = self.save_gap_proof(bad / "output", video, receipts, old_source=source, failure=failure)
        self.assertGreaterEqual(proof["maximumOneSampleRun"], 5)
        self.assertEqual(path.read_text(encoding="utf-8"), original)

    def test_missing_forced_idr_source_control_restores_long_low_rate_fragments(self):
        self.require_encoder()
        path = ROOT / "tools/world_lab/StudyVideoCapture.java"
        original = path.read_text(encoding="utf-8"); before = '"-forced-idr", "1"'
        self.assertEqual(original.count(before), 1)
        bad = self.work / "control-missing-forced-idr"; bad.mkdir()
        source = bad / path.name; source.write_text(original.replace(before, '"-forced-idr", "0"'), encoding="utf-8")
        result = subprocess.run([str(JDK / "javac.exe"), "-cp", self.classpath, "-d", str(bad), str(source)],
                                capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        text = self.java("low-rate", bad / "output", self.encoder,
                         bad="time-scheduled fragments still depend on capture ceiling",
                         classpath=str(bad) + os.pathsep + self.classpath)
        value = self.validate_publication(bad / "output")
        self.assertGreater(max(segment["durationMs"] for segment in value["segments"]), 650)
        proof = ROOT / "_scratch/c116-video" / ("missing-forced-idr-control-" + uuid.uuid4().hex)
        proof.parent.mkdir(parents=True, exist_ok=True); shutil.copytree(bad / "output", proof)
        (proof / "expected-failure.log").write_text(text, encoding="utf-8")
        (proof / "proof.json").write_text(json.dumps({
            "kind": "executable-missing-forced-IDR-control", "loadedGame": False,
            "unmodifiedSourceSha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            "modifiedSourceSha256": hashlib.sha256(source.read_bytes()).hexdigest(),
            "expectedFailure": "time-scheduled fragments still depend on capture ceiling",
            "fragmentDurationsMs": [segment["durationMs"] for segment in value["segments"]],
            "stats": value["stats"],
            "currentPythonJavaScriptBytesValidated": self.current_consumers_available()}, indent=2), encoding="utf-8")
        self.assertEqual(path.read_text(encoding="utf-8"), original)

    def test_native_factory_default_source_control_rejects_old_sixty(self):
        self.require_encoder()
        path = ROOT / "tools/world_lab/StudyVideoCapture.java"
        original = path.read_text(encoding="utf-8"); before = 'System.getProperty("study.videoFps", "120")'
        self.assertEqual(original.count(before), 1)
        bad = self.work / "control-native-default-sixty"; bad.mkdir()
        source = bad / path.name; source.write_text(original.replace(before, 'System.getProperty("study.videoFps", "60")'), encoding="utf-8")
        result = subprocess.run([str(JDK / "javac.exe"), "-cp", self.classpath, "-d", str(bad), str(source)],
                                capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.java("low-rate", bad / "output", self.encoder, bad="native factory default capture ceiling differs",
                  classpath=str(bad) + os.pathsep + self.classpath)
        self.assertEqual(path.read_text(encoding="utf-8"), original)

    def test_single_view_and_fragment_alignment_source_controls_flip_defects(self):
        self.require_encoder()
        controls = [
            ("missing-single", "StudyObserver.java",
             "if (camera == null || IsoPlayer.numPlayers != 1) return new SiteFrame[0];",
             "if (camera == null || IsoPlayer.numPlayers != 1 || extraCameras.length == 0) return new SiteFrame[0];",
             "sites-implicit", "single native video receipt missing"),
            ("single-unwired", "StudyVideoCapture.java", "if (source.length == 0) source = StudyObserver.videoFrames();",
             "/* single video receipt disconnected */", "sites-implicit", "single video was disconnected from the capture hook"),
            ("native-zoom-lost", "StudyVideoCapture.java",
             "buffer.getZoom(site.slot()), buffer.getTargetZoom(site.slot())", "1f, 1f",
             "sites-implicit", "single video lost the current native pose or zoom"),
            ("intermediate-site-ignored", "StudyVideoCapture.java", "&& Arrays.equals(frame.sites(), first.sites())", "&& true",
             "alignment-zoom", "fragment misstates intermediate zoom camera receipts"),
            ("intermediate-epoch-ignored", "StudyVideoCapture.java",
             "frames.stream().allMatch(frame -> frame.observerSequence() == first.observerSequence()\n"
             "                && Arrays.equals(frame.sites(), first.sites()))",
             "first.observerSequence() == last.observerSequence() && Arrays.equals(first.sites(), last.sites())",
             "alignment-epoch", "fragment misstates intermediate epoch camera receipts"),
        ]
        for label, name, before, after, mode, reason in controls:
            path = ROOT / "tools/world_lab" / name
            original = path.read_text(encoding="utf-8")
            self.assertEqual(original.count(before), 1, "Executable receipt control target differs: " + label)
            bad = self.work / ("control-" + label); bad.mkdir()
            source = bad / name; source.write_text(original.replace(before, after), encoding="utf-8")
            result = subprocess.run([str(JDK / "javac.exe"), "-cp", self.classpath, "-d", str(bad), str(source)],
                                    capture_output=True, text=True, timeout=30)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.java(mode, bad / "output", self.fixture, bad=reason, classpath=str(bad) + os.pathsep + self.classpath)
            self.assertEqual(path.read_text(encoding="utf-8"), original)

    def test_actual_pbo_lifecycle_backpressure_counts_only_admitted_captures(self):
        out = self.work / "pbo-lifecycle"; self.java("pbo-lifecycle", out)
        self.validate_snapshots(out)

    def test_actual_pending_pbo_shutdown_drops_each_admitted_capture_once(self):
        out = self.work / "pbo-shutdown"; self.java("pbo-shutdown", out)
        self.validate_snapshots(out)

    def test_actual_failed_pbo_readback_releases_and_accounts_pending_captures(self):
        out = self.work / "pbo-failure"; self.java("pbo-failure", out)
        self.validate_snapshots(out)

    def test_native_pbo_stats_source_controls_flip_old_failure_modes(self):
        path = ROOT / "tools/world_lab/StudyVideoCapture.java"
        original = path.read_text(encoding="utf-8")
        controls = [
            ("skipped-opportunity", "if (free == null || producer.latest.get() != null) return;",
             "if (free == null || producer.latest.get() != null) { producer.dropped.incrementAndGet(); return; }",
             "pbo-lifecycle", "unadmitted opportunities counted as captures or losses"),
            ("missing-admission", "long admitCapture() { return captured.incrementAndGet(); }",
             "long admitCapture() { return captured.get() + 1; }", "pbo-shutdown", "PBO capture admission count differs"),
            ("double-readback", "void acceptCaptured(Frame frame) {\n            validateFrame(frame);",
             "void acceptCaptured(Frame frame) {\n            captured.incrementAndGet();\n            validateFrame(frame);",
             "pbo-lifecycle", "PBO readback counted twice"),
            ("missing-cancel-loss", "if (releaseBuffer && pending) producer.dropped.incrementAndGet();",
             "if (false) producer.dropped.incrementAndGet();", "pbo-shutdown", "cancelled PBO captures missing losses"),
            ("duplicate-release-loss", "if (releaseBuffer && pending) producer.dropped.incrementAndGet();",
             "if (releaseBuffer && buffer != 0) producer.dropped.incrementAndGet();",
             "pbo-lifecycle", "completed PBO release duplicated losses"),
        ]
        for label, before, after, mode, reason in controls:
            self.assertEqual(original.count(before), 1, "Executable native control target differs: " + label)
            bad = self.work / ("control-" + label); bad.mkdir()
            changed = original.replace(before, after); self.assertNotEqual(changed, original)
            source = bad / path.name; source.write_text(changed, encoding="utf-8")
            result = subprocess.run([str(JDK / "javac.exe"), "-cp", self.classpath, "-d", str(bad), str(source)],
                                    capture_output=True, text=True, timeout=30)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.java(mode, bad / "output", bad=reason, classpath=str(bad) + os.pathsep + self.classpath)
        self.assertEqual(path.read_text(encoding="utf-8"), original)

    def test_actual_fragment_parser_and_complete_decode(self):
        self.require_encoder()
        self.assertRegex(self.java("parse", self.fixture), r"PARSED avc1\.[0-9a-f]{6} 120 8")
        result = subprocess.run([str(self.encoder), "-v", "error", "-i", str(self.fixture), "-f", "null", "-"],
                                capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_truncated_fragment_is_refused(self):
        self.require_encoder()
        bad = self.work / "truncated.mp4"; bad.write_bytes(self.fixture.read_bytes()[:-1])
        self.java("parse", bad, bad="video box incomplete")

    def test_wrong_avcc_codec_is_refused(self):
        self.require_encoder()
        data = bytearray(self.fixture.read_bytes()); at = data.index(b"avcC") + 5; data[at] ^= 1
        bad = self.work / "wrong-codec.mp4"; bad.write_bytes(data)
        self.java("parse", bad, bad="codec differs from its sequence parameters")

    def test_fragment_with_dependent_first_frame_is_refused(self):
        self.require_encoder()
        data = bytearray(self.fixture.read_bytes()); at = data.index(b"trun")
        flags = struct.unpack_from(">I", data, at + 4)[0] & 0xffffff
        self.assertTrue(flags & 1 and flags & 4, "real encoder first-sample flag seam differs")
        struct.pack_into(">I", data, at + 16, 0x01010000)
        bad = self.work / "dependent-first-frame.mp4"; bad.write_bytes(data)
        self.java("parse", bad, bad="does not begin with an independent frame")

    def test_encoder_failure_is_explicit_and_finishes(self):
        out = self.work / "failed"; self.java("failure", out, self.work / "absent-encoder.exe")
        view = json.loads((out / "latest-video.json").read_text())
        self.assertEqual(view["state"], "failed")
        self.assertIsNone(view["init"]); self.assertIsNone(view["codecs"])
        self.assertEqual(view["segments"], [])
        self.assertNotIn(str(self.work), view["message"])

    def test_burst_backpressure_drops_frames_and_finishes(self):
        self.require_encoder()
        out = self.work / "backpressure"; self.java("bounded", out, self.encoder)
        view = json.loads((out / "latest-video.json").read_text())
        self.assertEqual(view["state"], "ended", view)
        self.assertGreater(view["stats"]["droppedFrames"], 0)
        self.assertEqual(view["stats"]["capturedFrames"], 2000)
        self.assertEqual(view["stats"]["encodedFrames"] + view["stats"]["droppedFrames"], 2000)

    def test_actual_raw_frame_stream_has_unique_receipts_and_bounded_files(self):
        self.require_encoder()
        out = self.work / "produced"
        self.java("produce", out, self.encoder)
        view = json.loads((out / "latest-video.json").read_text())
        self.assertEqual(view["state"], "ended", view)
        self.assertRegex(view["codecs"], r"^avc1\.[0-9a-f]{6}$")
        self.assertEqual(len(view["segments"]), 8)
        self.assertEqual(view["stats"]["capturedFrames"], 180)
        self.assertEqual(view["stats"]["encodedFrames"] + view["stats"]["droppedFrames"], 180)
        init = out / view["init"]["file"]
        self.assertEqual(hashlib.sha256(init.read_bytes()).hexdigest(), view["init"]["sha256"])
        prior = None
        for fragment in view["segments"]:
            media = out / fragment["file"]
            self.assertEqual(hashlib.sha256(media.read_bytes()).hexdigest(), fragment["sha256"])
            self.assertGreater(fragment["durationMs"], 0)
            self.assertGreaterEqual(fragment["endCapturedAtUnixMs"], fragment["capturedAtUnixMs"])
            self.assertGreaterEqual(fragment["endWorldHours"], fragment["worldHours"])
            self.assertAlmostEqual(fragment["worldHours"], 30 + (fragment["firstFrameSequence"] - 1) * .01)
            self.assertAlmostEqual(fragment["endWorldHours"], 30 + (fragment["lastFrameSequence"] - 1) * .01)
            if prior:
                self.assertGreater(fragment["firstFrameSequence"], prior["lastFrameSequence"])
                self.assertGreaterEqual(fragment["ptsStartMs"], prior["ptsStartMs"] + prior["durationMs"])
            prior = fragment
            sample = out / "joined.mp4"; sample.write_bytes(init.read_bytes() + media.read_bytes())
            result = subprocess.run([str(self.encoder), "-v", "error", "-i", str(sample), "-f", "null", "-"],
                                    capture_output=True, text=True, timeout=30)
            self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(list(out.glob("*.m4s"))), 8)
        self.assertEqual(list(out.glob("*.tmp")), [])
        # Real-time wall-clock PTS retains the deliberate 650 ms gap;
        # compressing native frames to constant 60 FPS would erase them.
        self.assertTrue(any(fragment["durationMs"] > 350 for fragment in view["segments"]))
        self.assertTrue(any(not fragment["sites"] for fragment in view["segments"]))
        proof = ROOT / "_scratch/c116-video" / ("raw-producer-proof-" + uuid.uuid4().hex)
        proof.parent.mkdir(parents=True, exist_ok=True)
        shutil.copytree(out, proof)
        (proof / "proof.json").write_text(json.dumps({
            "kind": "actual-raw-RGB-NVENC-producer", "loadedGame": False,
            "sourceSha256": {name: hashlib.sha256((ROOT / "tools/world_lab" / name).read_bytes()).hexdigest()
                             for name in Run.OBSERVER_SOURCES},
            "stats": view["stats"], "retainedSegments": len(view["segments"]), "codecs": view["codecs"],
            "encoderSha256": hashlib.sha256(self.encoder.read_bytes()).hexdigest(),
            "independentFragmentsDecode": True, "constantRateGapCompression": False}, indent=2), encoding="utf-8")


    def test_sparse_frames_preserve_image_detail_across_capture_ceilings(self):
        self.require_encoder()
        source = self.work / "quality-source.png"
        reference = os.environ.get("SAO_VIDEO_QUALITY_REFERENCE")
        if reference:
            shutil.copy2(reference, source)
        else:
            # Detailed RGB input makes nominal-rate bitrate starvation observable.
            made = subprocess.run([str(self.encoder), "-v", "error", "-f", "lavfi", "-i",
                "nullsrc=size=2560x720,format=rgb24,geq=r='mod(X*13+Y*7,256)':g='mod(X*3+Y*17,256)':b='mod(X*19+Y*5,256)'",
                "-frames:v", "1", str(source)], capture_output=True, text=True, timeout=30)
            self.assertEqual(made.returncode, 0, made.stderr)

        def detail(name, ceiling, classpath=None):
            out = self.work / name
            self.java("quality-image", out, self.encoder, source, ceiling, classpath=classpath)
            view = self.validate_publication(out)
            self.assertEqual(view["state"], "ended")
            self.assertEqual(view["fps"], ceiling)
            self.assertEqual((view["width"], view["height"]), (2560, 720))
            last = view["segments"][-1]
            joined = out / "quality-last.mp4"
            joined.write_bytes((out / view["init"]["file"]).read_bytes() + (out / last["file"]).read_bytes())
            decoded = out / "quality-decoded.png"
            result = subprocess.run([str(self.encoder), "-v", "error", "-i", str(joined),
                "-frames:v", "1", str(decoded)], capture_output=True, text=True, timeout=30)
            self.assertEqual(result.returncode, 0, result.stderr)
            result = subprocess.run([str(self.encoder), "-hide_banner", "-i", str(source), "-i", str(decoded),
                "-lavfi", "[0:v]format=yuv420p[ref];[1:v]format=yuv420p[decoded];[ref][decoded]ssim",
                "-f", "null", "-"], capture_output=True, text=True, timeout=30)
            self.assertEqual(result.returncode, 0, result.stderr)
            import re
            matched = re.search(r"SSIM Y:[0-9.]+.*All:([0-9.]+)", result.stderr)
            self.assertIsNotNone(matched, result.stderr)
            (out / "quality-ssim.log").write_text(result.stderr, encoding="utf8")
            return float(matched[1]), out

        high, high_out = detail("quality-current-120", 120)
        low, _ = detail("quality-current-30", 30)
        self.assertGreaterEqual(high, .98, "sparse capture lost native image detail")
        self.assertAlmostEqual(high, low, delta=.005,
                               msg="capture ceiling changed compression quality")
        # Restore the actual previous command in a separate compiled owner.
        original = (ROOT / "tools/world_lab/StudyVideoCapture.java").read_text(encoding="utf8")
        changed = original.replace('"-preset", "p4"', '"-preset", "p1"').replace(
            '"-rc", "constqp", "-qp", "18",',
            '"-b:v", "12M", "-maxrate", "18M", "-bufsize", "3M",')
        self.assertNotEqual(changed, original)
        old = self.work / "quality-old-owner"; old.mkdir()
        path = old / "StudyVideoCapture.java"; path.write_text(changed, encoding="utf8")
        compiled = subprocess.run([str(JDK / "javac.exe"), "-cp", self.classpath,
            "-d", str(old), str(path)], capture_output=True, text=True, timeout=60)
        self.assertEqual(compiled.returncode, 0, compiled.stdout + compiled.stderr)
        bad, _ = detail("quality-restored-old-120", 120, os.pathsep.join([str(old), self.classpath]))
        self.assertLess(bad, .98, "restored bitrate starvation did not fail image-detail verdict")
        self.assertGreater(high - bad, .04)
        proof = ROOT / "_scratch/stream-quality-01" / ("producer-quality-proof-" + uuid.uuid4().hex)
        proof.mkdir(parents=True, exist_ok=False)
        shutil.copytree(high_out, proof / "producer")
        shutil.copy2(source, proof / "source.png")
        (proof / "receipt.json").write_text(json.dumps({
            "status": "PASS_ACTUAL_PRODUCER_QUALITY_WITH_RESTORED_DEFECT",
            "loadedGame": False, "nativeScreenshotReference": bool(reference),
            "sourceSha256": hashlib.sha256(source.read_bytes()).hexdigest(),
            "producerSourceSha256": hashlib.sha256(original.encode()).hexdigest(),
            "testSha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
            "ssimCurrent120": high, "ssimCurrent30": low, "ssimRestoredOld120": bad,
            "detailThreshold": .98, "oldDefectRejected": True,
            "encoderSha256": hashlib.sha256(self.encoder.read_bytes()).hexdigest(),
            "boundary": "Actual Java raw-frame producer/NVENC/fragment decode with sparse input; no native game launch or historical stream replacement."
        }, indent=2) + "\n", encoding="utf8")


if __name__ == "__main__":
    raise SystemExit(0 if unittest.main(exit=False).result.wasSuccessful() else 1)
