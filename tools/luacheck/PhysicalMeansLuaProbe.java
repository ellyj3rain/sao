import java.nio.ByteBuffer;
import java.nio.file.Files;
import java.nio.file.Path;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.vm.*;

/** Production Lua owners plus installed Kahlua table serialization. No game process. */
public final class PhysicalMeansLuaProbe {
    public static void main(String[] args) {
        var platform=new J2SEPlatform();var env=platform.newEnvironment();
        var thread=new KahluaThread(platform,env);thread.debugOwnerThread=Thread.currentThread();
        env.rawset("__nativeRoundtrip",(JavaFunction)(frame,count)->{
            try {
                var bytes=ByteBuffer.allocate(4*1024*1024);
                ((KahluaTable)frame.get(0)).save(bytes);bytes.flip();
                var restored=platform.newTable();restored.load(bytes,249);
                if(bytes.hasRemaining())throw new IllegalStateException("unconsumed native state bytes");
                return frame.push(restored);
            } catch(Exception error) {throw new IllegalStateException(error);}
        });
        try {
            int index=0;
            for(;index<args.length&&!args[index].equals("--");index++) {
                String source=Files.readString(Path.of(args[index]));
                thread.call(LuaCompiler.loadstring(source,args[index],env),null,null,null);
            }
            var result=thread.call(LuaCompiler.loadstring("return "+args[index+1],"verdict",env),null,null,null);
            System.out.println("VALUE "+result);
        } catch(Throwable error) {
            System.out.println("ERROR "+error.getClass().getSimpleName()+": "+error.getMessage());System.exit(1);
        }
    }
}
