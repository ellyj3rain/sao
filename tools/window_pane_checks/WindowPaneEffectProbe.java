import java.lang.reflect.Field;
import java.nio.file.Files;
import java.nio.file.Path;
import java.io.Reader;
import java.util.ArrayList;
import java.util.concurrent.ConcurrentLinkedQueue;
import se.krka.kahlua.vm.*;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import zombie.Lua.LuaManager;
import zombie.iso.IsoCell;
import zombie.iso.objects.IsoWindow;
import zombie.iso.sprite.IsoSprite;
import zombie.iso.sprite.IsoSpriteManager;
import zombie.inventory.InventoryItem;
import zombie.inventory.InventoryItemFactory;
import zombie.inventory.ItemContainer;

/** Real native cell/window/sprites/navigation queue, factory materials and
 * installed Lua producer; actor, sprite configuration, clock/network controlled.
 * This is isolated native execution, not a launched/rendered or MP game. */
public final class WindowPaneEffectProbe {
    private static Field field(Class<?> type,String name)throws Exception{var field=type.getDeclaredField(name);field.setAccessible(true);return field;}
    private static void chunk(KahluaThread thread,KahluaTable env,Path path)throws Exception{
        try(Reader reader=Files.newBufferedReader(path)){
            Object[] result=thread.pcall(LuaCompiler.loadis(reader,path.toString(),env),new Object[0]);
            if(!Boolean.TRUE.equals(result[0]))throw new AssertionError(java.util.Arrays.toString(result));
        }
    }
    public static void main(String[] args)throws Exception{
        WindowPaneNativeProbe.main(new String[]{args[0],"absent",args[1],args[2]});
        var boot=MovementCrossingProbe.class.getDeclaredMethod("boot");boot.setAccessible(true);
        IsoCell cell=(IsoCell)boot.invoke(null);
        zombie.pathfind.nativeCode.PathfindNative.useNativeCode=false;
        var scheduler=Class.forName("zombie.pathfind.PolygonalMap2$PMThread").getDeclaredConstructor(zombie.pathfind.PolygonalMap2.class);
        scheduler.setAccessible(true);
        // Real native notifier, intentionally not started: queue submission is
        // measured independently of asynchronous pathfinding computation.
        field(zombie.pathfind.PolygonalMap2.class,"thread").set(zombie.pathfind.PolygonalMap2.instance,scheduler.newInstance(zombie.pathfind.PolygonalMap2.instance));
        var nav=(ConcurrentLinkedQueue<?>)field(zombie.pathfind.PolygonalMap2.class,"squareTaskQueue").get(zombie.pathfind.PolygonalMap2.instance);
        var platform=new se.krka.kahlua.j2se.J2SEPlatform();var env=platform.newEnvironment();
        var thread=new KahluaThread(platform,env);thread.debugOwnerThread=Thread.currentThread();
        LuaManager.platform=platform;LuaManager.env=env;LuaManager.thread=thread;
        LuaManager.converterManager=new se.krka.kahlua.converter.KahluaConverterManager();
        zombie.Lua.KahluaNumberConverter.install(LuaManager.converterManager);
        LuaManager.caller=new se.krka.kahlua.integration.LuaCaller(LuaManager.converterManager);
        var exposer=new LuaManager.Exposer(LuaManager.converterManager,platform,env);
        for(Class<?> type:new Class<?>[]{IsoWindow.class,zombie.iso.IsoObject.class,zombie.iso.IsoGridSquare.class,
            ItemContainer.class,InventoryItem.class,ArrayList.class,IsoSprite.class}){
            exposer.setExposed(type);exposer.exposeLikeJava(type,env);
        }
        env.rawset("require",(JavaFunction)(frame,count)->frame.push(platform.newTable()));
        env.rawset("__print",(JavaFunction)(frame,count)->{System.out.println("CHECK "+frame.get(0)+"="+frame.get(1));return 0;});
        env.rawset("__navCount",(JavaFunction)(frame,count)->frame.push((double)nav.size()));
        env.rawset("__reset",(JavaFunction)(frame,count)->{
            try{
                var square=cell.getGridSquare(10,20,0);square.getObjects().clear();square.getSpecialObjects().clear();
                IsoSprite closed=IsoSpriteManager.instance.AddSprite("fixtures_windows_01_0",1800);
                IsoSprite open=IsoSpriteManager.instance.AddSprite("fixtures_windows_01_1",1801);
                IsoSprite smashed=IsoSpriteManager.instance.AddSprite("fixtures_windows_01_2",1802);
                IsoSprite removed=IsoSpriteManager.instance.AddSprite("fixtures_windows_01_3",1803);
                closed.name="fixtures_windows_01_0";open.name="fixtures_windows_01_1";
                smashed.name="fixtures_windows_01_2";removed.name="fixtures_windows_01_3";
                IsoWindow window=new IsoWindow(cell,square,closed,true);
                window.setOpenSprite(open);window.setSmashedSprite(smashed);field(IsoWindow.class,"glassRemovedSprite").set(window,removed);
                square.getObjects().add(window);square.getSpecialObjects().add(window);window.keyId=492;
                window.setIsLocked(true);window.setPermaLocked(true);
                field(IsoWindow.class,"open").setBoolean(window,Boolean.TRUE.equals(frame.get(0)));
                window.setSmashed(true);window.setGlassRemoved(true);field(IsoWindow.class,"health").setInt(window,7);
                nav.clear();
                ItemContainer inventory=new ItemContainer();
                InventoryItem first=InventoryItemFactory.CreateItem("RepairableWindows.LargeGlassPane");
                InventoryItem second=InventoryItemFactory.CreateItem("RepairableWindows.LargeGlassPane");
                InventoryItem wrong=InventoryItemFactory.CreateItem("Base.GlassPanel");
                wrong.setName("Glass panel");inventory.AddItem(first);inventory.AddItem(second);inventory.AddItem(wrong);
                first.setID(7201);second.setID(7202);wrong.setID(7203);
                env.rawset("__window",window);env.rawset("__closed",closed);env.rawset("__open",open);
                env.rawset("__inventory",inventory);env.rawset("__first",first);env.rawset("__second",second);env.rawset("__wrong",wrong);
                env.rawset("__maxHealth",(double)field(IsoWindow.class,"maxHealth").getInt(window));
                return frame.push(true);
            }catch(Exception failure){throw new IllegalStateException(failure);}
        });
        Path game=Path.of(args[0]);Path root=Path.of(args[3]);
        thread.call(LuaCompiler.loadstring("function getGameTime() return nil end; function isClient() return false end; function isServer() return false end; function sendRemoveItemFromContainer(i,p) __sent=(__sent or 0)+1 end", "native-setup",env),null,null,null);
        chunk(thread,env,game.resolve("media/lua/shared/ISBaseObject.lua"));
        chunk(thread,env,game.resolve("media/lua/shared/TimedActions/ISBaseTimedAction.lua"));
        chunk(thread,env,root.resolve("mod/42.20/media/lua/shared/SAO_WindowPaneSources.lua"));
        chunk(thread,env,Path.of(args[4]));
        chunk(thread,env,root.resolve("tools/window_pane_checks/native_effect_cases.lua"));
        System.exit(0); // Native fixture's background workers are process-owned.
    }
}
