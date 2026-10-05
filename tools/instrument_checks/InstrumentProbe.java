import com.sao.bridge.SAOBridge;
import com.sao.engine.SAOIsoPlayerShell;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.HashMap;
import se.krka.kahlua.converter.KahluaConverterManager;
import se.krka.kahlua.integration.LuaCaller;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.vm.JavaFunction;
import se.krka.kahlua.vm.KahluaThread;
import zombie.Lua.LuaManager;
import zombie.characters.BaseCharacterSoundEmitter;
import zombie.characters.IsoGameCharacter;
import zombie.inventory.InventoryItem;
import zombie.iso.IsoCell;
import zombie.iso.IsoObject;
import zombie.scripting.ScriptManager;
import zombie.world.WorldDictionary;

/** Installed item/queue/world-noise owners; the audio hardware receiver is controlled. */
public final class InstrumentProbe {
    public static final class Emitter extends BaseCharacterSoundEmitter {
        final HashMap<Long,String> active=new HashMap<>();
        long next=1; public int played,stopped; public boolean refuse, stopFault, playingFault;
        public int getPlayed(){return played;} public int getStopped(){return stopped;}
        public void setRefuse(boolean value){refuse=value;}
        public void setStopFault(boolean value){stopFault=value;}
        public void setPlayingFault(boolean value){playingFault=value;}
        public Emitter(IsoGameCharacter body){super(body);}
        public long playSound(String name){if(refuse)return 0;long id=next++;active.put(id,name);played++;return id;}
        public long playSound(String name,IsoObject object){return playSound(name);}
        public long playSoundImpl(String name,IsoObject object){return playSound(name);}
        public long playVocals(String name){return playSound(name);}
        public void playFootsteps(String name,float volume){}
        public boolean isPlaying(long id){if(playingFault)throw new IllegalStateException("controlled playback receiver fault");return active.containsKey(id);}
        public boolean isPlaying(String name){return active.containsValue(name);}
        public int stopSound(long id){if(stopFault)throw new IllegalStateException("controlled stop receiver fault");if(active.remove(id)!=null)stopped++;return 0;}
        public void finish(){active.clear();}
        public void reset(){active.clear();played=stopped=0;refuse=stopFault=playingFault=false;}
        public int stopSoundDelayRelease(long id){return stopSound(id);}
        public void stopSoundLocal(long id){stopSound(id);}
        public void stopOrTriggerSoundLocal(long id){stopSound(id);}
        public void stopOrTriggerSound(long id){stopSound(id);}
        public int stopSoundByName(String name){throw new AssertionError("unowned sound-name cleanup");}
        public void stopOrTriggerSoundByName(String name){throw new AssertionError("unowned sound-name cleanup");}
        public void stopAll(){throw new AssertionError("unowned emitter cleanup");}
        public void register(){} public void unregister(){} public void tick(){}
        public void set(float x,float y,float z){} public boolean isClear(){return active.isEmpty();}
        public void setPitch(long id,float value){} public void setVolume(long id,float value){}
        public boolean hasSoundsToStart(){return false;}
        public void setParameterValue(long id,fmod.fmod.FMOD_STUDIO_PARAMETER_DESCRIPTION p,float value){}
        public void setParameterValueByName(long id,String name,float value){}
    }
    public static void main(String[] args)throws Exception{
        var boot=MovementCrossingProbe.class.getDeclaredMethod("boot");boot.setAccessible(true);
        var cell=(IsoCell)boot.invoke(null);
        var create=MovementCrossingProbe.class.getDeclaredMethod("person",IsoCell.class);create.setAccessible(true);
        var body=(SAOIsoPlayerShell)create.invoke(null,cell);body.playerIndex=1;
        var other=(SAOIsoPlayerShell)create.invoke(null,cell);other.playerIndex=2;
        for(var b:new SAOIsoPlayerShell[]{body,other}){
            b.setSquare(b.getCurrentSquare());b.getCurrentSquare().getMovingObjects().add(b);cell.getObjectList().add(b);
        }
        var emitter=new Emitter(body);
        var emitterField=IsoGameCharacter.class.getDeclaredField("emitter");emitterField.setAccessible(true);emitterField.set(body,emitter);
        var platform=new J2SEPlatform();var env=platform.newEnvironment();var thread=new KahluaThread(platform,env);
        thread.debugOwnerThread=Thread.currentThread();LuaManager.platform=platform;LuaManager.env=env;LuaManager.thread=thread;
        zombie.ui.UIManager.defaultthread=thread;
        LuaManager.converterManager=new KahluaConverterManager();zombie.Lua.KahluaNumberConverter.install(LuaManager.converterManager);
        LuaManager.caller=new LuaCaller(LuaManager.converterManager);
        var exposer=new LuaManager.Exposer(LuaManager.converterManager,platform,env);
        Class<?>[] types={SAOBridge.class,SAOIsoPlayerShell.class,zombie.characters.IsoPlayer.class,IsoGameCharacter.class,
            InventoryItem.class,zombie.inventory.ItemContainer.class,zombie.scripting.objects.ItemTag.class,
            zombie.scripting.objects.Item.class,BaseCharacterSoundEmitter.class,Emitter.class,
            zombie.WorldSoundManager.class,zombie.WorldSoundManager.WorldSound.class,
            ArrayList.class,java.util.List.class,java.util.Stack.class,java.util.Vector.class,zombie.util.list.PZArrayList.class,
            IsoCell.class,zombie.iso.IsoGridSquare.class,IsoObject.class,zombie.characters.Stats.class,
            zombie.characters.CharacterStat.class,zombie.characters.Moodles.Moodles.class,zombie.scripting.objects.MoodleType.class,
            zombie.characters.BodyDamage.BodyDamage.class,zombie.characters.BodyDamage.BodyPart.class,
            zombie.characters.BodyDamage.BodyPartType.class,zombie.characters.CharacterTimedActions.LuaTimedActionNew.class,
            zombie.characters.CharacterTimedActions.BaseAction.class};
        Class<?>[] states={zombie.ai.states.ClimbThroughWindowState.class,zombie.ai.states.ClimbOverFenceState.class,
            zombie.ai.states.ClimbOverWallState.class,zombie.ai.states.ClimbSheetRopeState.class,
            zombie.ai.states.ClimbDownSheetRopeState.class,zombie.ai.states.CloseWindowState.class,zombie.ai.states.OpenWindowState.class};
        for(var type:states){exposer.setExposed(type);exposer.exposeLikeJava(type,env);}
        for(var type:types)exposer.setExposed(type);for(var type:types)exposer.exposeLikeJava(type,env);
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
        var base=ScriptManager.instance.getModule("Base");
        for(var row:new String[][]{{"normal.txt","Harmonica","__harmonica"},{"normal.txt","Whistle","__whistle"},{"weapon.txt","GuitarAcoustic","__guitar"}}){
            var value=(InventoryItem)item.invoke(null,Path.of(args[0]),base,dictionary,row[0],row[1],(short)(2900+base.items.getScriptMap().size()));
            env.rawset(row[2],value);
        }
        env.rawset("__body",body);env.rawset("__other",other);env.rawset("__emitter",emitter);env.rawset("SAOJavaBridge",SAOBridge.INSTANCE);
        env.rawset("print",(JavaFunction)(frame,count)->{System.out.println(frame.get(0));return 0;});
        env.rawset("getWorldSoundManager",(JavaFunction)(frame,count)->{frame.push(zombie.WorldSoundManager.instance);return 1;});
        env.rawset("__noiseCount",(JavaFunction)(frame,count)->{frame.push((double)zombie.WorldSoundManager.instance.soundList.size());return 1;});
        env.rawset("__noiseExact",(JavaFunction)(frame,count)->{
            var rows=zombie.WorldSoundManager.instance.soundList;
            var last=rows.isEmpty()?null:rows.get(rows.size()-1);
            frame.push(last!=null&&last.source==body&&last.x==10&&last.y==20&&last.z==0&&last.radius==45&&last.volume==45);return 1;
        });
        env.rawset("__resetNoise",(JavaFunction)(frame,count)->{zombie.WorldSoundManager.instance.soundList.clear();return 0;});
        env.rawset("__roundTrip",(JavaFunction)(frame,count)->{
            try{var bytes=java.nio.ByteBuffer.allocate(1024*1024);((se.krka.kahlua.vm.KahluaTable)frame.get(0)).save(bytes);bytes.flip();
                var restored=platform.newTable();restored.load(bytes,249);return frame.push(restored);
            }catch(Exception error){throw new IllegalStateException(error);}
        });
        env.rawset("__reloadGesture",(JavaFunction)(frame,count)->{
            try{thread.call(LuaCompiler.loadstring(Files.readString(Path.of(args[args.length-2])),"reloaded-gesture",env),null,null,null);}
            catch(Exception error){throw new IllegalStateException(error);}return 0;
        });
        for(int i=1;i<args.length;i++){
            System.out.println("LOAD "+args[i]);
            thread.call(LuaCompiler.loadstring(Files.readString(Path.of(args[i])),args[i],env),null,null,null);
        }
        System.out.println("INSTRUMENT_NATIVE_DONE");
    }
}
