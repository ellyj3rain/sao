import java.io.Reader;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.vm.*;

/** Installed Lua VM and native save format; unattached controlled action receivers. */
public final class ResourcePlumbingProbe {
    public static void main(String[] args) throws Exception {
        J2SEPlatform platform=new J2SEPlatform();
        KahluaTable env=platform.newEnvironment();
        KahluaThread thread=new KahluaThread(platform,env);
        thread.debugOwnerThread=Thread.currentThread();
        env.rawset("print",new JavaFunction(){public int call(LuaCallFrame frame,int n){
            for(int i=0;i<n;i++)System.out.print((i==0?"":"\t")+String.valueOf(frame.get(i)));
            System.out.println();return 0;
        }});
        env.rawset("__nativeRoundtrip",new JavaFunction(){public int call(LuaCallFrame frame,int n){
            try {
                ByteBuffer bytes=ByteBuffer.allocate(1048576);
                ((KahluaTable)frame.get(0)).save(bytes);bytes.flip();
                KahluaTable restored=platform.newTable();restored.load(bytes,zombie.iso.IsoWorld.WorldVersion);
                if(bytes.hasRemaining())throw new IllegalStateException("unconsumed save bytes");
                return frame.push(restored);
            } catch(Exception e){throw new IllegalStateException(e);}
        }});
        Path production=null;
        for(String arg:args)if(Path.of(arg).getFileName().toString().equals("production.lua"))production=Path.of(arg);
        final Path reloadSource=production;
        env.rawset("__reloadProduction",new JavaFunction(){public int call(LuaCallFrame frame,int n){
            try(Reader reader=Files.newBufferedReader(reloadSource,StandardCharsets.UTF_8)){
                Object[] result=thread.pcall(LuaCompiler.loadis(reader,"production-reload",env),new Object[0]);
                if(!Boolean.TRUE.equals(result[0]))throw new IllegalStateException(java.util.Arrays.toString(result));
                return frame.push(true);
            } catch(Exception e){throw new IllegalStateException(e);}
        }});
        for(String arg:args)try(Reader reader=Files.newBufferedReader(Path.of(arg),StandardCharsets.UTF_8)){
            Object[] result=thread.pcall(LuaCompiler.loadis(reader,arg,env),new Object[0]);
            if(!Boolean.TRUE.equals(result[0])){
                System.out.println("ERROR chunk="+arg);
                for(int i=1;i<result.length;i++)System.out.println(result[i]);
                System.exit(1);
            }
        }
    }
}
