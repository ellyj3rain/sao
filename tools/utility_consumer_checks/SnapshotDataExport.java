import java.nio.*;import java.nio.file.*;import java.util.*;import se.krka.kahlua.vm.*;import se.krka.kahlua.j2se.J2SEPlatform;import se.krka.kahlua.luaj.compiler.LuaCompiler;
/** Native data-only saved person snapshot exporter: no body, actions or world scene. */
public final class SnapshotDataExport {
 static String json(Object v){if(v==null)return "null";if(v instanceof String s)return "\""+s.replace("\\","\\\\").replace("\"","\\\"").replace("\n","\\n").replace("\r","\\r").replace("\t","\\t")+"\"";if(v instanceof Number||v instanceof Boolean)return v.toString();if(v instanceof KahluaTable t&&t.getMetatable()==null){var rows=new ArrayList<String>();var it=t.iterator();while(it.advance())rows.add(json(String.valueOf(it.getKey()))+":"+json(it.getValue()));Collections.sort(rows);return "{"+String.join(",",rows)+"}";}throw new AssertionError("nonplain "+v.getClass());}
 public static void main(String[]args)throws Exception{
  var platform=new J2SEPlatform();var env=platform.newEnvironment();var thread=new KahluaThread(platform,env);thread.debugOwnerThread=Thread.currentThread();
  env.rawset("__savedNativeRoundTrip",(JavaFunction)(f,n)->{try{var b=ByteBuffer.allocate(8*1024*1024);((KahluaTable)f.get(0)).save(b);b.flip();Files.write(Path.of("saved-person-native.bin"),Arrays.copyOf(b.array(),b.limit()));var out=platform.newTable();out.load(b,zombie.iso.IsoWorld.WorldVersion);return f.push(out);}catch(Exception e){throw new RuntimeException(e);}});
  env.rawset("__exportPlain",(JavaFunction)(f,n)->{try{String name=(String)f.get(0);if(!name.matches("[a-z-]+"))throw new AssertionError("label");Files.writeString(Path.of(name+".json"),json(f.get(1)));return 0;}catch(Exception e){throw new RuntimeException(e);}});
  for(String arg:args){var chunk=LuaCompiler.loadstring(Files.readString(Path.of(arg)),arg,env);var r=thread.pcall(chunk,new Object[0]);if(!Boolean.TRUE.equals(r[0]))throw new AssertionError(Arrays.toString(r));}
  System.out.println("DATA_ONLY_ORIGINAL_SNAPSHOTS_EXPORTED");
 }
}
