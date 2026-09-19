import java.nio.*;
import java.nio.file.*;
import java.io.*;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.vm.*;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
public class GraphSerializationProbe {
  static J2SEPlatform p = new J2SEPlatform();
  static KahluaTable e;
  static KahluaThread t;
  static Object run(String s) throws Exception { return t.call(LuaCompiler.loadstring(s,"probe",e),null,null,null); }
  static void load(Path r,String name) throws Exception { run(Files.readString(r.resolve("mod/42.20/media/lua/shared/SAO_"+name+".lua"))); }
  static void init(Path r,KahluaTable store) throws Exception {
    e=p.newEnvironment(); t=new KahluaThread(p,e); t.debugOwnerThread=Thread.currentThread();
    zombie.Lua.LuaManager.platform=p;
    e.rawset("_store",store);
    run("Events={OnGameStart={Add=function() end}}; ModData={getOrCreate=function() _store=_store or {}; return _store end}; SAO={Pressure={total=function() return 0 end},Labor={},PathogenPressure={},Organization={},Settlement={},Material={},Communication={},PlayerInteraction={}};");
    load(r,"Branching"); load(r,"GraphPersistence"); load(r,"Integration");
  }
  public static void main(String[] args) throws Exception {
    Path r=Path.of(args[0]); init(r,null);
    run("assert(SAO.Integration.ensure()); SAO.Branching.record('p','work',123); SAO.Branching.registerBranch({id='extension', weight=function() return 2 end});");
    KahluaTable st=(KahluaTable)e.rawget("_store"); ByteBuffer b=ByteBuffer.allocate(100000); st.save(b); int n=b.position(); b.flip();
    KahluaTable restored=p.newTable(); restored.load(b,249);
    e.rawset("_store",restored);
    System.out.println("SERIALIZED bytes="+n);
    System.out.println("RESTORED "+run("local g=_store.branching; return type(g.surfaces.person)..','..type(g.pressures.needs)..','..type(g.branches.work.weight)..','..tostring(g.branches.work.id)..','..g.patterns['p:work'].count"));
    init(r,restored); run("assert(SAO.Integration.ensure())");
    System.out.println("REINITIALIZED "+run("local g=SAO.Branching; return type(g.surfaces.person)..','..type(g.pressures.needs)..','..type(g.branches.work.weight)..','..type(g.branches.extension.weight)..','..g.patterns['p:work'].count"));
  }
}
