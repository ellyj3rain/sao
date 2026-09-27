import com.sao.bridge.SAOBridge;
import com.sao.engine.SAOIsoPlayerShell;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import se.krka.kahlua.converter.KahluaConverterManager;
import se.krka.kahlua.integration.LuaCaller;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.vm.JavaFunction;
import se.krka.kahlua.vm.KahluaThread;
import zombie.Lua.LuaManager;
import zombie.inventory.ItemContainer;
import zombie.iso.IsoCell;
import zombie.iso.objects.IsoStove;
import zombie.iso.sprite.IsoSprite;
import zombie.scripting.ScriptManager;
import zombie.world.WorldDictionary;

/** Real native shells, native timed-action stack and installed Lua queue. */
public final class GestureOwnershipProbe {
    public static void main(String[] args) throws Exception {
        var boot=MovementCrossingProbe.class.getDeclaredMethod("boot");boot.setAccessible(true);
        var cell=(IsoCell)boot.invoke(null);
        var create=MovementCrossingProbe.class.getDeclaredMethod("person",IsoCell.class);create.setAccessible(true);
        var cook=(SAOIsoPlayerShell)create.invoke(null,cell);cook.playerIndex=99;
        var speaker=(SAOIsoPlayerShell)create.invoke(null,cell);speaker.playerIndex=98;
        for(var body:new SAOIsoPlayerShell[]{cook,speaker}) {
            body.setSquare(body.getCurrentSquare());body.getCurrentSquare().getMovingObjects().add(body);cell.getObjectList().add(body);
        }
        cook.getModData().rawset("SAOPersonId","cook");speaker.getModData().rawset("SAOPersonId","speaker");
        for(int i=0;i<zombie.characters.IsoPlayer.players.length;i++) zombie.characters.IsoPlayer.players[i]=null;
        var platform=new J2SEPlatform();var env=platform.newEnvironment();var thread=new KahluaThread(platform,env);
        thread.debugOwnerThread=Thread.currentThread();LuaManager.platform=platform;LuaManager.env=env;LuaManager.thread=thread;
        zombie.ui.UIManager.defaultthread=thread;
        LuaManager.converterManager=new KahluaConverterManager();zombie.Lua.KahluaNumberConverter.install(LuaManager.converterManager);
        LuaManager.caller=new LuaCaller(LuaManager.converterManager);
        var exposer=new LuaManager.Exposer(LuaManager.converterManager,platform,env);
        Class<?>[] types={SAOBridge.class,SAOIsoPlayerShell.class,zombie.characters.IsoPlayer.class,
            zombie.characters.IsoGameCharacter.class,zombie.inventory.InventoryItem.class,zombie.inventory.types.Food.class,
            ItemContainer.class,IsoCell.class,zombie.iso.IsoGridSquare.class,zombie.iso.IsoObject.class,IsoStove.class,
            ArrayList.class,java.util.Stack.class,java.util.Vector.class,zombie.util.list.PZArrayList.class,zombie.characters.Stats.class,zombie.characters.CharacterStat.class,
            zombie.characters.Moodles.Moodles.class,zombie.scripting.objects.MoodleType.class,
            zombie.characters.BodyDamage.BodyDamage.class,zombie.characters.BodyDamage.BodyPart.class,
            zombie.characters.BodyDamage.BodyPartType.class,zombie.characters.CharacterTimedActions.LuaTimedActionNew.class,
            zombie.characters.CharacterTimedActions.BaseAction.class,
            zombie.ai.states.ClimbThroughWindowState.class,zombie.ai.states.ClimbOverFenceState.class,zombie.ai.states.ClimbOverWallState.class,
            zombie.ai.states.ClimbSheetRopeState.class,zombie.ai.states.ClimbDownSheetRopeState.class,
            zombie.ai.states.CloseWindowState.class,zombie.ai.states.OpenWindowState.class};
        for(Class<?> type:types)exposer.setExposed(type);
        for(Class<?> type:types)exposer.exposeLikeJava(type,env);
        zombie.Lua.LuaEventManager.register(platform,env);
        env.rawset("instanceof",(JavaFunction)(frame,count)->{
            Object value=frame.get(0);String name=(String)frame.get(1);boolean match=false;
            for(Class<?> type=value==null?null:value.getClass();type!=null;type=type.getSuperclass())
                if(type.getSimpleName().equals(name)){match=true;break;}
            frame.push(match);return 1;
        });
        var init=ResourceApproachProbe.class.getDeclaredMethod("initFluids");init.setAccessible(true);init.invoke(null);
        var dc=Class.forName("CognitionUseProbe$Dictionary");var ctor=dc.getDeclaredConstructor();ctor.setAccessible(true);
        var dictionary=ctor.newInstance();var data=WorldDictionary.class.getDeclaredField("data");data.setAccessible(true);data.set(null,dictionary);
        var item=CognitionUseProbe.class.getDeclaredMethod("item",Path.class,zombie.scripting.objects.ScriptModule.class,
            dc,String.class,String.class,short.class);item.setAccessible(true);
        var food=(zombie.inventory.types.Food)item.invoke(null,Path.of(args[0]),ScriptManager.instance.getModule("Base"),
            dictionary,"food.txt","MuttonChop",(short)2901);cook.getInventory().AddItem(food);
        var square=cook.getCurrentSquare();var stove=new IsoStove(cell,square,new IsoSprite());
        var container=new ItemContainer("stove",square,stove);stove.setContainer(container);square.getObjects().add(stove);square.chunk.addGeneratorPos(10,20,0);
        env.rawset("__cook",cook);env.rawset("__speaker",speaker);env.rawset("__realBridge",SAOBridge.INSTANCE);
        env.rawset("__nativePrint",(JavaFunction)(frame,count)->{System.out.println(frame.get(0));return 0;});
        for(int i=1;i<args.length;i++)thread.call(LuaCompiler.loadstring(Files.readString(Path.of(args[i])),args[i],env),null,null,null);
        System.out.println("GESTURE_NATIVE_DONE");
    }
}
