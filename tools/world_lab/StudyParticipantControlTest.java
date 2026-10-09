import java.nio.file.*;
import java.lang.reflect.*;
import java.util.*;
import zombie.core.Core;
import zombie.input.KeyboardState;
import zombie.input.MouseState;
import org.lwjglx.opengl.Display;
import se.krka.kahlua.j2se.KahluaTableImpl;
public final class StudyParticipantControlTest {
  static Path path; static Path root;static int checks,failures;
  static final String SESSION="12345678-1234-1234-1234-123456789abc";
  static void field(String name,Object value)throws Exception {Field f=StudyParticipantInput.class.getDeclaredField(name);f.setAccessible(true);f.set(null,value);}
  static void reset()throws Exception {
    zombie.characters.IsoPlayer.players[0]=new zombie.characters.IsoPlayer(); zombie.iso.IsoWorld.instance.currentCell=new zombie.iso.IsoCell(); zombie.GameTime.hours=25.5;
    Core.gameSaveWorld="ScratchSave";Core.currentTextEntryBox=null;zombie.ZomboidFileSystem.instance.directory=null;Display.active=true;Display.fail=false;
    for(String name:new String[]{"heldKeys","heldButtons"}){Field f=StudyParticipantInput.class.getDeclaredField(name);f.setAccessible(true);((BitSet)f.get(null)).clear();}
    field("acceptedGeneration",-1L);field("acceptedLeaseId",null);field("releasing",false);field("offline",false);field("focusProbeAvailable",null);field("displayIsActive",null);
    System.setProperty("study.participantInput","true");System.setProperty("study.participantSession",SESSION);System.setProperty("study.participantLease",path.toString());System.clearProperty("study.observer");System.setProperty("study.attempt","1");System.setProperty("study.participantState",root.resolve("participant-state.json").toString());System.setProperty("study.viewDirectory",root.resolve("native-view").toString());zombie.ZomboidFileSystem.instance.screens=root.resolve("screens").toString();
    Files.deleteIfExists(path);StudyParticipantInput.enableFromProperties();
  }
  static String value(long generation,long expiry,boolean released){long pid=ProcessHandle.current().pid();return "{\"schema\":\"sao.participant-input-lease/1\",\"sessionId\":\""+SESSION+"\",\"pid\":"+pid+",\"holderPid\":"+pid+",\"attempt\":1,\"save\":\"ScratchSave\",\"playerIndex\":0,\"playerSqlId\":1,\"leaseId\":\"lease-a\",\"generation\":"+generation+",\"expiresAtUnixMs\":"+expiry+",\"released\":"+released+",\"keys\":[17],\"mouse\":{\"x\":10,\"y\":20,\"buttons\":[0]}}";}
  static String valid(long gen){return value(gen,System.currentTimeMillis()+60000,false);}
  static void write(String json)throws Exception {Files.writeString(path,json);}
  // Each controlled query represents a new engine update, whose entry advice refreshes input.
  static boolean key(){StudyParticipantInput.beginInputUpdate();return StudyParticipantInput.isKeyDown(new KeyboardState(),17);}
  static boolean button(){StudyParticipantInput.beginInputUpdate();return StudyParticipantInput.isButtonDown(new MouseState(),0);}
  static void pollNow()throws Exception {Field sampled=StudyParticipant.class.getDeclaredField("stateSampled");sampled.setAccessible(true);sampled.set(null,false);StudyParticipant.poll();}
  static String awaitFile(Path file,java.util.function.Predicate<String> matches)throws Exception {
    long deadline=System.nanoTime()+2_000_000_000L;String value="";
    do {try {value=Files.readString(file);if(matches.test(value))return value;}catch(java.io.IOException pending){}Thread.sleep(5);}while(System.nanoTime()<deadline);
    throw new AssertionError("asynchronous publication did not match within 2 seconds: "+file.getFileName());
  }
  static void require(boolean ok,String message){if(!ok)throw new AssertionError(message);}
  static KahluaTableImpl table(Object... pairs){var values=new LinkedHashMap<Object,Object>();for(int i=0;i<pairs.length;i+=2)values.put(pairs[i],pairs[i+1]);return new KahluaTableImpl(values);}
  static KahluaTableImpl[] objectivePair(){
    var attempt=table("id","route-home","stepId","return","owner","ManualRoute","status","arrived",
      "x",10.0,"y",20.0,"z",0.0,"startedAt",9.0,"endedAt",9.5);
    var report=table("processId","process-1","revision",2.0,"actorId","helper-1",
      "recipientId","player:one","outboundReceiptId","route-out","watchReceiptId","watch-1",
      "returnReceiptId","route-home","status","completed","channel","spoken","deliveredAt",9.6);
    var review=table("processId","process-1","revision",2.0,"actorId","helper-1",
      "playerId","player:one","commitmentId","commitment-1","outboundReceiptId","route-out",
      "watchReceiptId","watch-1","returnReceiptId","route-home","reportDeliveredAt",9.6,
      "reviewedAt",9.7,"status","inspected","attempts",table(1.0,attempt));
    return new KahluaTableImpl[]{report,review};
  }
  static String objectiveReceipt(KahluaTableImpl report,KahluaTableImpl review)throws Exception {
    Class<?> cls=Class.forName("StudyParticipant$ObjectiveReviews");
    Method method=cls.getDeclaredMethod("receipt",String.class,String.class,String.class,
      se.krka.kahlua.vm.KahluaTable.class,se.krka.kahlua.vm.KahluaTable.class);
    method.setAccessible(true);return (String)method.invoke(null,"process-1","player:one","helper-1",report,review);
  }
  interface Run{void run()throws Exception;}
  static void test(String label,Run run)throws Exception {reset();checks++;try{run.run();System.out.println("CONTROL PASS "+label);}catch(Throwable error){failures++;System.out.println("CONTROL FAIL "+label+" :: "+error.getClass().getSimpleName()+" "+error.getMessage());}}
  public static void main(String[] args)throws Exception {
    root=Path.of(args[0]);Files.createDirectories(root);path=root.resolve("lease.json");
    test("known-save-owned-lease",()->{write(valid(1));require(key()&&button(),"owned input missing");});
    test("no-lease-startup",()->require(!key()&&!button(),"startup lease injection"));
    test("unknown-save-startup",()->{Core.gameSaveWorld=null;write(valid(1));require(!key()&&!button(),"unknown save admitted");});
    test("unknown-save-after-world",()->{write(valid(5));require(key(),"precondition");Core.gameSaveWorld=null;require(!key(),"lost native identity kept input");});
    test("different-save-refusal",()->{write(valid(1).replace("ScratchSave","OtherSave"));require(!key(),"foreign save admitted");});
    test("installed-singleton-fallback-shape",()->{Core.gameSaveWorld=null;zombie.ZomboidFileSystem.instance.directory="C:/isolated/ScratchSave";write(valid(1));require(key(),"fallback should bind exact known save");});
    test("focus-loss-clear",()->{write(valid(1));require(key(),"precondition");Display.active=false;require(!key()&&!button(),"focus retained input");});
    test("focus-query-failure-refusal",()->{write(valid(1));Display.fail=true;require(!key(),"failed focus query admitted input");});
    test("focus-return-same-generation-stays-cleared",()->{write(valid(1));require(key(),"precondition");Display.active=false;require(!key(),"focus clear");Display.active=true;require(!key()&&!key(),"same generation resumed");write(valid(2));require(key(),"new generation failed");});
    test("typing-blocks-leased-buttons",()->{write(valid(1));Core.currentTextEntryBox=()->true;require(!button(),"typing button injected");});
    test("typing-restores-native-pointer",()->{write(valid(1));Core.currentTextEntryBox=()->true;StudyParticipantInput.beginInputUpdate();require(StudyParticipantInput.getX(new MouseState())==77&&StudyParticipantInput.getY(new MouseState())==88,"typing pointer replaced");});
    test("typing-clears-until-new-generation",()->{write(valid(1));require(key(),"precondition");Core.currentTextEntryBox=()->true;require(!key(),"typed key injected");Core.currentTextEntryBox=null;require(!key()&&!key(),"stale pretyping intent resumed");write(valid(2));require(key(),"new intent failed");});
    test("expired-lease-refusal",()->{write(value(1,System.currentTimeMillis()-1,false));require(!key(),"expired admitted");});
    test("zero-expiry-refusal",()->{write(value(1,0,false));require(!key(),"unbounded expiry admitted");});
    test("negative-expiry-refusal",()->{write(value(1,-1,false));require(!key(),"negative expiry admitted");});
    test("release-generation-floor",()->{write(valid(5));require(key(),"precondition");write(value(10,System.currentTimeMillis()+60000,true));require(!key()&&!key(),"release retained input");write(valid(7));require(!key(),"stale generation after release admitted");});
    test("expiry-generation-floor",()->{write(valid(5));require(key(),"precondition");write(value(10,System.currentTimeMillis()-1,false));require(!key()&&!key(),"expiry retained input");write(valid(7));require(!key(),"stale generation after expiry admitted");});
    test("generation-rollback-refusal",()->{write(valid(10));require(key(),"precondition");write(valid(5));require(!key(),"rollback admitted");});
    test("missing-file-disconnect-and-new-intent",()->{write(valid(5));require(key(),"precondition");Files.delete(path);require(!key()&&!key(),"disconnect retained input");write(valid(5));require(!key(),"same generation reconnected");write(valid(6));require(key(),"explicit new generation failed");});
    test("holder-death-refusal",()->{long dead=Integer.MAX_VALUE;require(ProcessHandle.of(dead).isEmpty(),"dead PID control unavailable");write(valid(1).replace("\"holderPid\":"+ProcessHandle.current().pid(),"\"holderPid\":"+dead));require(!key(),"dead holder admitted");});
    test("missing-holder-refusal",()->{write(valid(1).replace("\"holderPid\":"+ProcessHandle.current().pid(),"\"holderPid\":0"));require(!key(),"missing holder admitted");});
    test("session-refusal",()->{write(valid(1).replace(SESSION,"22345678-1234-1234-1234-123456789abc"));require(!key(),"session replacement admitted");});
    test("game-pid-refusal",()->{write(valid(1).replace("\"pid\":"+ProcessHandle.current().pid(),"\"pid\":1"));require(!key(),"foreign PID admitted");});
    test("lease-identity-refusal",()->{write(valid(1));require(key(),"precondition");write(valid(2).replace("lease-a","lease-b"));require(!key(),"foreign lease resumed");});
    test("physical-key-preserved",()->{KeyboardState state=new KeyboardState();state.physical=true;Core.gameSaveWorld=null;require(StudyParticipantInput.isKeyDown(state,17),"physical source input lost");});
    test("duplicate-field-refusal",()->{write(valid(1).replace("\"keys\":[17]","\"keys\":[17],\"keys\":[]"));require(!key(),"duplicate fields admitted");});
    test("trailing-garbage-refusal",()->{write(valid(1)+" garbage");require(!key(),"trailing garbage admitted");});
    test("truncated-root-refusal",()->{String s=valid(1);write(s.substring(0,s.length()-1));require(!key(),"truncated root admitted");});
    test("scientific-key-refusal",()->{write(valid(1).replace("[17]","[1e7]"));require(!key(),"scientific key coerced");});
    test("fractional-key-refusal",()->{write(valid(1).replace("[17]","[1.7]"));require(!key(),"fractional key coerced");});
    test("negative-key-refusal",()->{write(valid(1).replace("[17]","[-1,17]"));require(!key(),"invalid key silently skipped");});
    test("overflow-player-binding-refusal",()->{write(valid(1).replace("\"playerIndex\":0","\"playerIndex\":4294967296"));require(!key(),"overflow binding admitted");});
    test("unknown-field-refusal",()->{String s=valid(1);write(s.substring(0,s.length()-1)+",\"extra\":true}");require(!key(),"unknown field admitted");});
    test("released-input-and-pointer",()->{write(valid(1));require(key()&&button(),"precondition");write(value(2,System.currentTimeMillis(),true));require(!key()&&!button(),"released state retained");require(StudyParticipantInput.getX(new MouseState())==77,"released pointer replaced");});

    test("actual-positive-sql-not-fixed-one",()->{zombie.characters.IsoPlayer.players[0].sqlId=7;write(valid(1).replace("\"playerSqlId\":1","\"playerSqlId\":7"));require(key(),"actual SQL7 refused");});
    test("forged-sql-refusal",()->{zombie.characters.IsoPlayer.players[0].sqlId=7;write(valid(1));require(!key(),"constant SQL1 bypassed actual7");});
    test("native-attempt-refusal",()->{write(valid(1).replace("\"attempt\":1","\"attempt\":2"));require(!key(),"foreign attempt admitted");});
    test("absent-physical-body-refusal",()->{zombie.characters.IsoPlayer.players[0]=null;write(valid(1));require(!key()&&StudyParticipant.frame()==null,"absent body admitted");});
    test("unloaded-square-refusal",()->{zombie.characters.IsoPlayer.players[0].square=null;write(valid(1));require(!key()&&StudyParticipant.frame()==null,"unloaded body admitted");});
    test("dead-body-native-only",()->{zombie.characters.IsoPlayer.players[0].dead=true;write(valid(1));require(!key(),"dead body leased");require(StudyParticipant.json(StudyParticipant.binding(),123).contains("\"alive\":false"),"death concealed");});
    test("sql-unassigned-observable-capture",()->{
      var player=zombie.characters.IsoPlayer.players[0];player.sqlId=-1;write(valid(1));require(!key(),"SQL unassigned accepted");
      var stamp=StudyParticipant.frame();require(stamp!=null&&stamp.observerSequence()==0&&stamp.participant().playerSqlId()==-1,"SQL wait hid framebuffer");
      String state=StudyParticipant.json(StudyParticipant.binding(),123);Files.writeString(root.resolve("unready-observed.json"),state);
      require(state.contains("\"ready\":false")&&state.contains("\"alive\":true")&&state.contains("\"body\":")&&state.contains("\"playerSqlId\":-1"),"unready observed body dishonest");
      require(StudyViewCapture.beginCapture(stamp),"unready whole frame refused");String filename=StudyViewCapture.pending;
      StudyViewCapture.publishPixels(filename,2,2,new byte[]{1,2,3,4,5,6,7,8,9,10,11,12});
      String manifest=Files.readString(root.resolve("native-view/native.json"));Files.copy(root.resolve("native-view/native.json"),root.resolve("unready-native.json"),StandardCopyOption.REPLACE_EXISTING);
      require(manifest.contains("\"observerSequence\":0")&&manifest.contains("\"participant\":")&&manifest.contains("\"ready\":false"),"unready PNG binding missing");
      require(zombie.characters.IsoPlayer.players[0]==player&&player.sqlId==-1,"capture mutated native body");
    });
    test("sql-assignment-enables-ready-identity",()->{var player=zombie.characters.IsoPlayer.players[0];player.sqlId=-1;write(valid(1));require(!key(),"precondition");player.sqlId=7;write(valid(2).replace("\"playerSqlId\":1","\"playerSqlId\":7"));key();require(key()&&StudyParticipant.binding().ready(),"actual assignment did not recover");});
    test("sql-change-clears-and-binds-new-intent",()->{write(valid(1));require(key(),"precondition");zombie.characters.IsoPlayer.players[0].sqlId=7;require(!key(),"SQL change retained");write(valid(2).replace("\"playerSqlId\":1","\"playerSqlId\":7"));key();require(key(),"new exact SQL intent refused");});
    test("body-object-replacement-clears",()->{write(valid(1));require(key(),"precondition");zombie.characters.IsoPlayer.players[0]=new zombie.characters.IsoPlayer();require(!key(),"replacement retained");key();require(!key(),"same generation resumed replacement");write(valid(2));require(key(),"new generation refused");});
    test("old-frame-owner-refusal",()->{var frame=StudyParticipant.frame();zombie.characters.IsoPlayer.players[0]=new zombie.characters.IsoPlayer();StudyParticipant.binding();require(!StudyViewCapture.frameCurrent(frame),"old owner frame admitted");});
    test("nonfinite-body-refusal",()->{zombie.characters.IsoPlayer.players[0].x=Float.NaN;write(valid(1));require(!key()&&StudyParticipant.frame()==null,"NaN body admitted");});
    test("state-label-json-escape",()->{zombie.characters.IsoPlayer.players[0].label="Actual \"label\"\n";pollNow();String state=awaitFile(root.resolve("participant-state.json"),value->value.contains("\\\"label\\\"\\u000a"));Files.writeString(root.resolve("ready-state.json"),state);require(state.contains("\\\"label\\\"\\u000a"),"label not JSON escaped");});
    test("original-observer-frame-constructor",()->{System.clearProperty("study.participantInput");var frame=new StudyViewCapture.FrameStamp(0,20);require(frame.participant()==null&&StudyViewCapture.frameCurrent(frame),"original observer stamp changed");});
    test("original-observer-png-schema",()->{System.clearProperty("study.participantInput");var stamp=new StudyViewCapture.FrameStamp(0,25.5);require(StudyViewCapture.beginCapture(stamp),"original capture refused");StudyViewCapture.publishPixels(StudyViewCapture.pending,2,2,new byte[12]);String value=Files.readString(root.resolve("native-view/native.json"));Files.copy(root.resolve("native-view/native.json"),root.resolve("observer-native.json"),StandardCopyOption.REPLACE_EXISTING);require(!value.contains("\"participant\""),"observer schema gained participant fields");});
    test("prepared-participant-frame-without-observer",()->{zombie.characters.IsoPlayer.players[0].sqlId=-1;Object state=new Object();StudyViewCapture.frameReady(state);Field field=StudyViewCapture.class.getDeclaredField("FRAMES");field.setAccessible(true);var frames=(Map<?,?>)field.get(null);var stamp=(StudyViewCapture.FrameStamp)frames.get(state);require(stamp!=null&&stamp.participant()!=null&&stamp.observerSequence()==0,"prepared participant frame missing");});
    test("last-real-identity-retained-during-unready",()->{Path identity=root.resolve("participant-identity.json");Files.deleteIfExists(identity);zombie.characters.IsoPlayer.players[0].sqlId=-1;pollNow();awaitFile(root.resolve("participant-state.json"),value->value.contains("\"playerSqlId\":-1")&&value.contains("\"ready\":false"));require(!Files.exists(identity),"unassigned SQL fabricated identity");zombie.characters.IsoPlayer.players[0].sqlId=7;pollNow();String known=awaitFile(identity,value->value.contains("\"playerSqlId\":7")&&value.contains("\"ready\":true"));require(known.contains("\"playerSqlId\":7")&&known.contains("\"ready\":true"),"actual positive identity missing");zombie.characters.IsoPlayer.players[0]=null;pollNow();String current=awaitFile(root.resolve("participant-state.json"),value->value.contains("\"ready\":false")&&!value.contains("\"body\""));require(current.contains("\"ready\":false")&&!current.contains("\"body\""),"current readiness concealed");require(Files.readString(identity).equals(known),"unready exit erased actual identity");Files.writeString(root.resolve("retained-identity.json"),known);});
    test("later-actual-sql-refreshes-identity",()->{zombie.characters.IsoPlayer.players[0].sqlId=12;zombie.characters.IsoPlayer.players[0].dead=true;pollNow();String value=awaitFile(root.resolve("participant-identity.json"),current->current.contains("\"playerSqlId\":12")&&current.contains("\"alive\":false"));require(value.contains("\"playerSqlId\":12")&&value.contains("\"alive\":false"),"identity invented older SQL/life status");});
    test("bounded-actual-body-label",()->{zombie.characters.IsoPlayer.players[0].label="x".repeat(180);require(StudyParticipant.binding().label().length()==160,"pipeline label limit differs");});
    test("participant-rejects-observer-property",()->{System.setProperty("study.observer","true");boolean refused=false;try{StudyParticipantInput.enableFromProperties();}catch(IllegalStateException expected){refused=true;}require(refused,"observer host leased");});
    test("objective-review-exact-report-projection",()->{var pair=objectivePair();String row=objectiveReceipt(pair[0],pair[1]);require(row!=null&&row.contains("\"processId\":\"process-1\"")&&row.contains("\"returnReceiptId\":\"route-home\"")&&row.contains("\"attempts\":[{"),"exact source review missing");});
    test("objective-review-conflicting-report-refusal",()->{var pair=objectivePair();pair[0].delegate.put("returnReceiptId","foreign-route");require(objectiveReceipt(pair[0],pair[1])==null,"conflicting report admitted");});
    test("objective-review-attempt-cap",()->{var pair=objectivePair();var attempts=table();for(int i=1;i<=65;i++)attempts.delegate.put((double)i,table("id","route-"+i));pair[1].delegate.put("attempts",attempts);require(objectiveReceipt(pair[0],pair[1])==null,"oversized attempt history admitted");});
    test("objective-review-game-thread-lua-source",()->{
      var pair=objectivePair();var saved=table("actorId","helper-1","revision",2.0);
      var savedReviews=table("helper-1:2",saved);
      var process=table("originatorId","player:one","kind","cooperative-action",
        "objectivePlayerReviews",savedReviews);
      var order=table(1.0,"process-1");
      var organization=table("processes",table("process-1",process),"processOrder",order,
        "objectivePlayerReviewFor",(se.krka.kahlua.vm.JavaFunction)(frame,count)->frame.push(pair[1]),
        "objectiveReportFor",(se.krka.kahlua.vm.JavaFunction)(frame,count)->frame.push(pair[0]));
      var standing=table("playerAccountKey",(se.krka.kahlua.vm.JavaFunction)(frame,count)->frame.push("player:one"));
      var history=table("countyHours",(se.krka.kahlua.vm.JavaFunction)(frame,count)->frame.push(100.0));
      var environment=table("SAO",table("Standing",standing,"Organization",organization,"History",history));
      zombie.Lua.LuaManager.env=environment;
      var lua=new se.krka.kahlua.vm.KahluaThread(new se.krka.kahlua.j2se.J2SEPlatform(),environment);
      lua.debugOwnerThread=Thread.currentThread();zombie.Lua.LuaManager.thread=lua;
      zombie.Lua.LuaManager.caller=new se.krka.kahlua.integration.LuaCaller(new se.krka.kahlua.converter.KahluaConverterManager());
      Field epoch=StudyParticipant.class.getDeclaredField("nativeCaptureEpoch");epoch.setAccessible(true);epoch.setLong(null,1);
      try {
        var body=StudyParticipant.binding();
        String sample=StudyParticipant.json(body,123)+"\n";
        String observed=StudyParticipant.ObjectiveReviews.observe(body,123,sample);
        require(observed!=null&&observed.contains("\"countyHours\":100.0")
          &&observed.contains("\"captureEpoch\":1")&&observed.contains("\"processId\":\"process-1\""),
          "validated Lua source review was not captured: " + observed);
        savedReviews.delegate.put("alias",saved);
        String aliased=StudyParticipant.ObjectiveReviews.observe(body,123,sample);
        String mark="\"processId\":\"process-1\"";
        require(aliased!=null&&aliased.indexOf(mark)>=0&&aliased.indexOf(mark)==aliased.lastIndexOf(mark),
          "aliased source review emitted a duplicate");
        savedReviews.delegate.remove("alias");order.delegate.put(2.0,"process-1");
        String repeated=StudyParticipant.ObjectiveReviews.observe(body,123,sample);
        require(repeated!=null&&repeated.indexOf(mark)>=0&&repeated.indexOf(mark)==repeated.lastIndexOf(mark),
          "repeated process order emitted a duplicate");
        lua.debugOwnerThread=new Thread();
        require(StudyParticipant.ObjectiveReviews.observe(body,124,sample)==null,"foreign Lua owner admitted");
      } finally {zombie.Lua.LuaManager.env=null;zombie.Lua.LuaManager.thread=null;zombie.Lua.LuaManager.caller=null;}
    });
    if(Boolean.getBoolean("study.controlAgent")) {
      test("actual-member-substitution-keyboard",()->{write(valid(1));zombie.input.GameKeyboard.update();require(zombie.input.GameKeyboard.observed,"real transformer missed callsite");Display.active=false;zombie.input.GameKeyboard.update();require(!zombie.input.GameKeyboard.observed,"transformed focus clear failed");});
      test("actual-member-substitution-mouse",()->{write(valid(1));zombie.input.Mouse.update();require(zombie.input.Mouse.observed&&zombie.input.Mouse.x==10&&zombie.input.Mouse.y==20,"real mouse transformer missed callsite");});
      test("actual-logic-advice-state-publication",()->{Files.deleteIfExists(root.resolve("participant-state.json"));zombie.GameWindow.logic();awaitFile(root.resolve("participant-state.json"),value->value.contains("\"ready\":true"));require(Files.exists(root.resolve("participant-state.json")),"logic advice did not publish");});
    }
    System.out.println("checks="+checks+"; pass="+(checks-failures)+"; failures="+failures+"; scope=controlled-engine-stubs");
    System.exit(failures==0?0:1);
  }
}
