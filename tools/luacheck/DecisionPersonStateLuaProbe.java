import java.nio.ByteBuffer;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.*;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.vm.*;

/** Installed Lua owners, native table serialization, and actual owned calendar. */
public final class DecisionPersonStateLuaProbe {
    private static final Set<String> ARRAYS=Set.of("episodes","questions","revisions","evidence","anticipated",
        "paths","roots","observations","frontiers","participants","relations","parentIds","evidenceIds",
        "contradictions","missing","unknowns","beliefIds");
    private static String quote(String s) {
        StringBuilder out=new StringBuilder("\"");
        for(int i=0;i<s.length();i++) {
            char c=s.charAt(i);
            if(c=='"'||c=='\\')out.append('\\').append(c);
            else if(c<32)out.append(String.format("\\u%04x",(int)c));
            else out.append(c);
        }
        return out.append('"').toString();
    }
    private static String json(Object value,String key,IdentityHashMap<Object,Boolean> seen) {
        if(value==null)return "null";
        if(value instanceof String)return quote((String)value);
        if(value instanceof Boolean)return value.toString();
        if(value instanceof Number) {
            double number=((Number)value).doubleValue();
            if(!Double.isFinite(number))throw new IllegalArgumentException("nonfinite export");
            return number==Math.rint(number)?Long.toString((long)number):Double.toString(number);
        }
        if(!(value instanceof KahluaTable))throw new IllegalArgumentException("non-data export");
        if(seen.put(value,true)!=null)throw new IllegalArgumentException("cyclic export");
        TreeMap<String,Object> fields=new TreeMap<>();TreeMap<Integer,Object> rows=new TreeMap<>();
        KahluaTableIterator it=((KahluaTable)value).iterator();
        while(it.advance()) {
            Object k=it.getKey();
            if(k instanceof Number) {
                double n=((Number)k).doubleValue();
                if(n<1||n!=Math.rint(n))throw new IllegalArgumentException("invalid array key");
                rows.put((int)n,it.getValue());
            } else if(k instanceof String)fields.put((String)k,it.getValue());
            else throw new IllegalArgumentException("non-data key");
        }
        StringJoiner out;
        if(!rows.isEmpty()||fields.isEmpty()&&ARRAYS.contains(key)) {
            if(!fields.isEmpty())throw new IllegalArgumentException("mixed export keys");
            out=new StringJoiner(",","[","]");int index=1;
            for(var row:rows.entrySet()) {
                if(row.getKey()!=index++)throw new IllegalArgumentException("sparse export");
                out.add(json(row.getValue(),"",seen));
            }
        } else {
            out=new StringJoiner(",","{","}");
            for(var field:fields.entrySet())out.add(quote(field.getKey())+":"+json(field.getValue(),field.getKey(),seen));
        }
        seen.remove(value);return out.toString();
    }
    public static void main(String[] args) {
        var platform=new J2SEPlatform();var env=platform.newEnvironment();
        var thread=new KahluaThread(platform,env);thread.debugOwnerThread=Thread.currentThread();
        env.rawset("__countyCalendar",(JavaFunction)(frame,count)->frame.push(com.sao.engine.SAORecord.countyInstant(
            ((Number)frame.get(0)).intValue(),((Number)frame.get(1)).intValue(),
            ((Number)frame.get(2)).intValue(),((Number)frame.get(3)).doubleValue(),((Number)frame.get(4)).intValue())));
        env.rawset("__nativeRoundtrip",(JavaFunction)(frame,count)->{
            try {var bytes=ByteBuffer.allocate(4*1024*1024);((KahluaTable)frame.get(0)).save(bytes);bytes.flip();
                var restored=platform.newTable();restored.load(bytes,249);return frame.push(restored);
            }catch(Exception e){throw new IllegalStateException(e);}
        });
        env.rawset("__reloadCognition",(JavaFunction)(frame,count)->{
            try {((KahluaTable)env.rawget("SAO")).rawset("Cognition",null);
                thread.call(LuaCompiler.loadstring(Files.readString(Path.of("cognition.lua")),"reloaded-cognition",env),null,null,null);
                return frame.push(true);
            }catch(Exception e){throw new IllegalStateException(e);}
        });
        env.rawset("__emitPersonState",(JavaFunction)(frame,count)->{
            try {Files.writeString(Path.of("person-state-frame.json"),json(frame.get(0),"",new IdentityHashMap<>())+"\n");
                return frame.push(true);
            }catch(Exception e){throw new IllegalStateException(e);}
        });
        try {
            int index=0;
            for(;index<args.length&&!args[index].equals("--");index++)
                thread.call(LuaCompiler.loadstring(Files.readString(Path.of(args[index])),args[index],env),null,null,null);
            Object result=thread.call(LuaCompiler.loadstring("return "+args[index+1],"verdict",env),null,null,null);
            System.out.println("VALUE "+result);
        }catch(Throwable error){System.out.println("ERROR "+error.getClass().getSimpleName()+": "+error.getMessage());System.exit(1);}
    }
}
