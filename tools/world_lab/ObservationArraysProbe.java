import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import se.krka.kahlua.converter.KahluaConverterManager;
import se.krka.kahlua.integration.LuaCaller;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.vm.KahluaTable;
import se.krka.kahlua.vm.KahluaTableIterator;
import se.krka.kahlua.vm.KahluaThread;
import zombie.GameWindow;
import zombie.ZomboidFileSystem;
import zombie.Lua.LuaManager;

/** Array-shape fixture with real installed Kahlua and the actual export worker. */
public final class ObservationArraysProbe {
    private static void check(boolean value, String reason) {
        if (!value) throw new AssertionError(reason);
        System.out.println("PASS " + reason);
    }
    public static void main(String[] args) throws Exception {
        GameWindow.gameThread=Thread.currentThread();
        zombie.core.random.RandStandard.INSTANCE.init();
        ZomboidFileSystem.instance.setCacheDir(args[1]);
        J2SEPlatform platform=new J2SEPlatform();
        KahluaTable env=platform.newEnvironment();
        KahluaThread thread=new KahluaThread(platform,env);
        thread.debugOwnerThread=Thread.currentThread();
        LuaManager.platform=platform; LuaManager.env=env; LuaManager.thread=thread;
        LuaManager.converterManager=new KahluaConverterManager();
        zombie.Lua.KahluaNumberConverter.install(LuaManager.converterManager);
        LuaManager.caller=new LuaCaller(LuaManager.converterManager);
        LuaManager.exposer=new LuaManager.Exposer(LuaManager.converterManager,platform,env);
        try {
            StudyExport.bind();
            StudyExport export=(StudyExport)env.rawget("SAO_StudyExport");
            thread.call(LuaCompiler.loadstring(Files.readString(Path.of(args[0])),args[0],env),null,null,null);
            KahluaTable frame=(KahluaTable)env.rawget("FRAME");
            KahluaTable marker=((KahluaTable)frame.rawget("people")).getMetatable();
            String fallback=(String)env.rawget("FALLBACK");
            Path root=Path.of(LuaManager.getLuaCacheDir());
            Files.writeString(Path.of(args[1]).resolve("fallback.json"),fallback,StandardCharsets.UTF_8);
            check(export.measure(frame,marker,64000000)==fallback.getBytes(StandardCharsets.UTF_8).length,
                "native measure equals production fallback byte count");
            String key=frame.rawget("definitionSha256")+"/"+frame.rawget("save")+"/"+frame.rawget("session");
            KahluaTable captured=platform.newTable(),deferred=platform.newTable();
            KahluaTableIterator fields=frame.iterator();
            while(fields.advance()) {captured.rawset(fields.getKey(),fields.getValue());deferred.rawset(fields.getKey(),fields.getValue());}
            captured.rawset("status","captured"); deferred.rawset("status","deferred");
            captured.rawset("worldHours",frame.rawget("hours")); deferred.rawset("worldHours",frame.rawget("hours"));
            deferred.rawset("attemptedSequence",1.0); deferred.rawset("reason","encoded-byte-budget");
            StringBuilder saveHex=new StringBuilder();
            for(char c:((String)frame.rawget("save")).toCharArray()) saveHex.append(String.format("%02x",(int)c));
            String relative="StudyWorld/"+frame.rawget("definitionSha256")+"/"+saveHex+"/"+frame.rawget("session")+"/0000000000000001.json";
            double ticket=export.reserve("archive",key+"/archive/1");
            check(export.submitArchive(ticket,frame,marker,64000000,relative,captured,deferred).equals("accepted"),
                "actual native archive submission admitted");
            long deadline=System.nanoTime()+10000000000L;
            while(export.receiptStatus(ticket).equals("pending") && System.nanoTime()<deadline) Thread.sleep(5);
            check(export.receiptStatus(ticket).equals("published"),"native archive completed and read back");
            String nativeText=Files.readString(root.resolve(relative));
            check(nativeText.equals(fallback+"\n"),"native publication equals fallback bytes plus newline");
            export.release(ticket); StudyExport.shutdown();
            System.out.println("NATIVE_FILE "+root.resolve(relative));
        } catch(Throwable failure) {
            failure.printStackTrace(); StudyExport.abort(); System.exit(1);
        }
    }
}
