import com.sao.engine.SAOEducationPrior;
import com.sao.engine.SAODurableText;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.vm.JavaFunction;
import se.krka.kahlua.vm.KahluaTable;
import se.krka.kahlua.vm.KahluaThread;

/** Native registry staging uses no engine world or physical people. */
public final class EducationBackgroundProbe {
    private static String text(Object v) throws IOException { if(!(v instanceof String)) throw new IOException("string-type"); return (String)v; }
    private static Object run(KahluaThread thread,KahluaTable env,String source) throws Exception {
        return thread.call(LuaCompiler.loadstring(source,"education-registry-probe",env),null,null,null);
    }
    public static void main(String[] args) throws Exception {
        byte[] raw=Files.readAllBytes(Path.of(args[1])); double tick=Double.parseDouble(args[6]);
        if(args[0].equals("java")) {
            try { System.out.print(SAOEducationPrior.checkedRegistry(raw,args[2],args[3],args[4],args[5],tick)); }
            catch(IOException refused) { System.out.print(SAOEducationPrior.refusalWire(refused.getMessage())); System.exit(2); }
            return;
        }
        J2SEPlatform platform=new J2SEPlatform(); KahluaTable env=platform.newEnvironment();
        KahluaThread thread=new KahluaThread(platform,env); thread.debugOwnerThread=Thread.currentThread(); zombie.Lua.LuaManager.platform=platform;
        KahluaTable bridge=platform.newTable(); env.rawset("SAOJavaBridge",bridge);
        bridge.rawset("educationCheckedRegistry",(JavaFunction)(frame,count)->{
            String port;
            try { if(count!=7) throw new IOException("registry-arguments");
                port=SAOEducationPrior.checkedRegistry(text(frame.get(1)).getBytes(StandardCharsets.UTF_8),text(frame.get(2)),text(frame.get(3)),text(frame.get(4)),text(frame.get(5)),(Double)frame.get(6));
            } catch(Exception invalid) { port=SAOEducationPrior.refusalWire("invalid-source-registry"); }
            frame.push(port); return 1;
        });
        JavaFunction decode=(frame,count)->{
            try { frame.push(SAOEducationPrior.decodeRegistryField(text(frame.get(1)))); } catch(Exception invalid) { frame.push((Object)null); } return 1;
        };
        bridge.rawset("educationRegistryDecode",decode); bridge.rawset("educationDecode",decode);
        JavaFunction pack=(frame,count)->{ try { frame.push(SAODurableText.pack(text(frame.get(1)))); } catch(Exception invalid) { frame.push((Object)null); } return 1; };
        JavaFunction unpack=(frame,count)->{ try { frame.push(SAODurableText.unpack(frame.get(1))); } catch(Exception invalid) { frame.push((Object)null); } return 1; };
        bridge.rawset("educationRegistryPack",pack); bridge.rawset("educationRegistryUnpack",unpack);
        bridge.rawset("educationPack",pack); bridge.rawset("educationUnpack",unpack);
        JavaFunction query=(frame,count)->{
            String port;
            try { if(count!=11) throw new IOException("prior-arguments");
                var binding=new SAOEducationPrior.Bindings(text(frame.get(3)),text(frame.get(4)),text(frame.get(5)),text(frame.get(6)),text(frame.get(7)),text(frame.get(8)),text(frame.get(9)));
                double now=(Double)frame.get(10);
                port=SAOEducationPrior.load(text(frame.get(1)).getBytes(StandardCharsets.UTF_8),text(frame.get(2)),binding,now).snapshotWire(now);
            } catch(Exception invalid) { port=SAOEducationPrior.refusalWire("invalid-source-prior"); }
            frame.push(port); return 1;
        };
        bridge.rawset("educationValidate",query); bridge.rawset("educationQuery",query);
        bridge.rawset("educationCheckConcept",(JavaFunction)(frame,count)->{
            boolean ok=false;
            try { ok=count==9 && SAOEducationPrior.checkConceptView(text(frame.get(1)),text(frame.get(2)),text(frame.get(3)),text(frame.get(4)),text(frame.get(5)),text(frame.get(6)),text(frame.get(7)),text(frame.get(8))); } catch(Exception invalid) { ok=false; }
            frame.push(ok); return 1;
        });
        env.rawset("__roundtrip",(JavaFunction)(frame,count)->{
            try { ByteBuffer bytes=ByteBuffer.allocate(24*1024*1024); ((KahluaTable)frame.get(0)).save(bytes); bytes.flip();
                KahluaTable restored=platform.newTable(); restored.load(bytes,249); if(bytes.hasRemaining()) throw new AssertionError("serialized-tail"); frame.push(restored); return 1;
            } catch(Exception invalid) { throw new RuntimeException(invalid); }
        });
        env.rawset("_raw",new String(raw,StandardCharsets.UTF_8)); env.rawset("_rawSha",args[2]); env.rawset("_worldSha",args[3]);
        env.rawset("_bankSha",args[4]); env.rawset("_archiveSha",args[5]); env.rawset("_tick",tick);
        String wire=SAOEducationPrior.checkedRegistry(raw,args[2],args[3],args[4],args[5],tick);
        String[] row=wire.split("\n")[1].split("\t",-1);
        env.rawset("_personId",SAOEducationPrior.decodeRegistryField(row[0])); env.rawset("_birthYear",Double.valueOf(row[3]));
        env.rawset("_profileSha",row[2]);
        env.rawset("__educationBridge",bridge);
        for (int index=7;index<args.length;index++) run(thread,env,Files.readString(Path.of(args[index])));
        Object result=env.rawget("__result");
        if (!(result instanceof String value) || !value.startsWith("PASS background"))
            throw new AssertionError("background result "+result);
        System.out.println("VALUE "+result);
        KahluaTable restoredEnv=platform.newEnvironment();
        KahluaThread restoredThread=new KahluaThread(platform,restoredEnv);
        restoredThread.debugOwnerThread=Thread.currentThread(); restoredEnv.rawset("SAOJavaBridge",bridge);
        restoredEnv.rawset("_expectsAuthoredExposures",args[0].equals("lua-authored") || args[0].equals("lua-workbench"));
        restoredEnv.rawset("_expectsWorkbenchExposure",args[0].equals("lua-workbench"));
        for (String name : new String[]{"_rawSha","_worldSha","_bankSha","_archiveSha","_persistedWorld","_persistedActor"})
            restoredEnv.rawset(name,env.rawget(name));
        run(restoredThread,restoredEnv,"""
            SAO={History={TICKS_PER_DAY=216000,ticks=function()return 108000 end,countyHours=function()return 12 end,birthYearOf=function()return 1960 end},
                Identity={get=function(id)if id=='runner' then return _persistedActor end end}}
            """);
        for (String name : new String[]{"education.lua","registry.lua","concepts.lua"})
            run(restoredThread,restoredEnv,Files.readString(Path.of(name)));
        run(restoredThread,restoredEnv,"""
            assert(SAO.Education.backgroundRelations('runner')==nil,'fresh VM retained source provider')
            assert(SAO.EducationRegistry.bind(_persistedWorld,_rawSha,_worldSha,_bankSha,_archiveSha,108000),'fresh source rebind')
            local result=SAO.ConceptKnowledge.infer('runner','stove','relief-from-hunger','house:A')
            assert(result.status=='expectation' and result.paths[1].roots[1].basis=='generated-schooling-exposure','fresh VM lost content')
            assert(_persistedActor.education.revision==1 and _persistedActor.cookReceipts==nil,'reload fabricated learning or food')
            local roots=SAO.Education.backgroundRelations('runner')
            if _expectsAuthoredExposures then
                assert(#roots==(_expectsWorkbenchExposure and 5 or 4),'fresh VM lost authored roots')
                local work=SAO.ConceptKnowledge.infer('runner','workshop','tools')
                local civic=SAO.ConceptKnowledge.infer('runner','family-cooperation','possible-mutual-support')
                assert(work.status=='expectation' and work.paths[1].roots[1].exposureEventId=='work-reading-1982','fresh VM lost work exposure')
                assert(civic.status=='expectation' and civic.paths[1].roots[1].assent=='not-established','fresh VM invented cultural assent')
                assert(civic.paths[1].roots[1].contentExposureHistorySha256==work.paths[1].roots[1].contentExposureHistorySha256,'fresh VM lost shared history custody')
                if _expectsWorkbenchExposure then
                    local bench=SAO.ConceptKnowledge.infer('runner','workbench','tools')
                    assert(bench.status=='expectation' and bench.paths[1].modal,'fresh VM lost workbench expectation')
                    assert(bench.paths[1].roots[1].exposureReceiptSha256==work.paths[1].roots[1].exposureReceiptSha256,'fresh VM invented another exposure')
                end
            end
            """);
        System.out.println("PASS fresh VM 4 checks: source rebind, private meaning and unchanged outcome custody");
        if(args[0].equals("lua-authored") || args[0].equals("lua-workbench")) System.out.println("PASS fresh VM authored exposures 4 checks: count, work, cultural assent and history custody");
        if(args[0].equals("lua-workbench")) System.out.println("PASS fresh VM workbench 2 checks: conditional meaning and same exposure");
    }
}
