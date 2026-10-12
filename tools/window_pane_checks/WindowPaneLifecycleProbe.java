import java.io.Reader;
import java.lang.reflect.Field;
import java.nio.ByteBuffer;
import java.nio.file.Files;
import java.nio.file.Path;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.vm.*;
import zombie.Lua.LuaManager;
import zombie.characters.CharacterTimedActions.BaseAction;
import zombie.characters.CharacterTimedActions.LuaTimedActionNew;
import zombie.inventory.InventoryItem;
import zombie.inventory.ItemContainer;
import zombie.iso.objects.IsoWindow;
import sun.misc.Unsafe;

/** Actual native LuaTimedActionNew dispatch on initialized native player.
 * Owning actor/map/clock fixture stays controlled and explicitly separate from
 * the native dispatcher receiver. Native legacy effect receivers are real. */
public final class WindowPaneLifecycleProbe {
    private static IsoWindow window;private static ItemContainer inventory;private static InventoryItem pane;
    private static Object nativeOp(String operation)throws Exception{
        switch(operation){
            case "reset":
                Field uf=Unsafe.class.getDeclaredField("theUnsafe");uf.setAccessible(true);Unsafe unsafe=(Unsafe)uf.get(null);
                window=(IsoWindow)unsafe.allocateInstance(IsoWindow.class);pane=(InventoryItem)unsafe.allocateInstance(InventoryItem.class);
                pane.setModule("RepairableWindows");pane.setType("LargeGlassPane");pane.setID(713);
                inventory=new ItemContainer();inventory.AddItemBlind(pane);window.setSmashed(true);window.setGlassRemoved(true);return true;
            case "smashed":return window.isSmashed();case "glass":return window.isGlassRemoved();
            case "setSmashed":window.setSmashed(false);return true;case "setGlass":window.setGlassRemoved(false);return true;
            case "contains":return inventory.contains(pane);case "remove":inventory.Remove(pane);return true;
            case "poststate":return !window.isSmashed()&&!window.isGlassRemoved()&&!inventory.contains(pane);
            default:throw new IllegalArgumentException(operation);
        }
    }
    public static void main(String[] args)throws Exception{
        zombie.ZomboidFileSystem.instance.setCacheDir(System.getProperty("sao.paneFixtureCache"));
        var boot=MovementCrossingProbe.class.getDeclaredMethod("boot");boot.setAccessible(true);
        var cell=(zombie.iso.IsoCell)boot.invoke(null);
        var create=MovementCrossingProbe.class.getDeclaredMethod("person",zombie.iso.IsoCell.class);create.setAccessible(true);
        var receiver=(com.sao.engine.SAOIsoPlayerShell)create.invoke(null,cell);receiver.playerIndex=0;
        var platform=new J2SEPlatform();var env=platform.newEnvironment();var thread=new KahluaThread(platform,env);thread.debugOwnerThread=Thread.currentThread();
        LuaManager.platform=platform;LuaManager.env=env;LuaManager.thread=thread;
        LuaManager.converterManager=new se.krka.kahlua.converter.KahluaConverterManager();
        zombie.Lua.KahluaNumberConverter.install(LuaManager.converterManager);
        LuaManager.caller=new se.krka.kahlua.integration.LuaCaller(LuaManager.converterManager);
        var exposer=new LuaManager.Exposer(LuaManager.converterManager,platform,env);
        for(Class<?> type:new Class<?>[]{LuaTimedActionNew.class,BaseAction.class}){exposer.setExposed(type);exposer.exposeLikeJava(type,env);}
        env.rawset("__nativeOp",(JavaFunction)(frame,count)->{try{return frame.push(nativeOp((String)frame.get(0)));}catch(Exception error){throw new IllegalStateException(error);}});
        env.rawset("__nativeRoundtrip",(JavaFunction)(frame,count)->{try{
            ByteBuffer bytes=ByteBuffer.allocate(1048576);((KahluaTable)frame.get(0)).save(bytes);bytes.flip();
            var restored=platform.newTable();restored.load(bytes,zombie.iso.IsoWorld.WorldVersion);return frame.push(restored);
        }catch(Exception error){throw new IllegalStateException(error);}});
        env.rawset("__nativeDispatch",(JavaFunction)(frame,count)->{try{
            var action=(KahluaTable)frame.get(0);String phase=(String)frame.get(1);
            if(phase.equals("bind")){
                var nativeAction=new LuaTimedActionNew(action,receiver);
                Field started=LuaTimedActionNew.class.getDeclaredField("started");started.setAccessible(true);started.setBoolean(nativeAction,true);
                ((BaseAction)nativeAction).started=true;
                nativeAction.currentTime=nativeAction.maxTime;action.rawset("action",nativeAction);return frame.push(true);
            }
            var nativeAction=(LuaTimedActionNew)action.rawget("action");
            if(phase.equals("perform"))nativeAction.perform();else if(phase.equals("complete"))nativeAction.complete();else throw new IllegalArgumentException(phase);
            return frame.push(true);
        }catch(Exception error){throw new IllegalStateException(error);}});
        for(String file:args){try(Reader reader=Files.newBufferedReader(Path.of(file))){
            Object[] result=thread.pcall(LuaCompiler.loadis(reader,file,env),new Object[0]);
            if(!Boolean.TRUE.equals(result[0])){System.out.println("ERROR "+file);for(int i=1;i<result.length;i++)System.out.println(result[i]);System.exit(1);}
        }}
        System.out.println("VALUE "+env.rawget("__windowResults"));System.exit(0);
    }
}
