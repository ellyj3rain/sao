import com.sao.bridge.SAOBridge;
import com.sao.engine.SAOIsoPlayerShell;
import java.io.Reader;
import java.lang.reflect.*;
import java.nio.ByteBuffer;
import java.nio.file.*;
import java.util.*;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.vm.*;
import zombie.inventory.InventoryItem;
import zombie.inventory.types.Literature;
import zombie.iso.*;
import zombie.iso.objects.IsoGenerator;
import zombie.iso.SpriteDetails.IsoFlagType;
import zombie.scripting.ScriptManager;

/** Installed generator/items/fluid/power methods and Kahlua; controlled dispatch/actor adapter. */
public final class GeneratorNativeProbe {
    METADATA
    private static IsoCell cell;
    private static SAOIsoPlayerShell body;
    private static IsoGenerator generator;
    private static IsoObject consumer;
    private static zombie.gameStates.IngameState gameState;
    private static final Map<String,InventoryItem> prototypes=new LinkedHashMap<>();
    private static final Map<Integer,InventoryItem> items=new LinkedHashMap<>();
    private static final List<IsoGenerator> extraGenerators=new ArrayList<>();
    private static int nextItem=90000;
    private static Object invoke(Class<?> type,String name,Class<?>[] signature,Object... args)throws Exception{
        Method method=type.getDeclaredMethod(name,signature);method.setAccessible(true);return method.invoke(null,args);
    }
    private static void field(Class<?> type,String name,Object value)throws Exception{
        Field field=type.getDeclaredField(name);field.setAccessible(true);field.set(null,value);
    }
    public static IsoCell initialise(Path game)throws Exception{
        if(cell!=null)return cell;
        cell=(IsoCell)invoke(MovementCrossingProbe.class,"boot",new Class<?>[0]);
        for(int x=8;x<=16;x++)for(int y=18;y<=22;y++){
            var square=cell.getGridSquare(x,y,0);var sprite=new zombie.iso.sprite.IsoSprite();sprite.getProperties().set(IsoFlagType.solidfloor);
            var floor=new IsoObject(cell,square,sprite);square.getObjects().add(floor);square.getProperties().set(IsoFlagType.solidfloor);square.setSolidFloor(true);
        }
        body=(SAOIsoPlayerShell)invoke(MovementCrossingProbe.class,"person",new Class<?>[]{IsoCell.class},cell);
        cell.getObjectList().add(body);body.getModData().rawset("SAOPersonId","native-generator");
        invoke(ResourceApproachProbe.class,"initFluids",new Class<?>[0]);
        var dictionary=new MaterialDictionary();field(zombie.world.WorldDictionary.class,"data",dictionary);
        short registry=1400;
        for(String name:List.of("Generator","Generator_Yellow","Generator_Blue","Generator_Old","ElectronicsScrap","PetrolCan","ElectronicsMag4")){
            String file=name.equals("ElectronicsMag4")?"literature.txt":"normal.txt";
            InventoryItem item=material(game.resolve("media/scripts/generated/items/"+file),"Base",name,registry++,dictionary);
            prototypes.put(item.getFullType(),item);
        }
        field(zombie.iso.areas.isoregion.IsoRegions.class,"dataRoot",new zombie.iso.areas.isoregion.data.DataRoot());
        var regionCtor=zombie.iso.areas.isoregion.IsoRegionWorker.class.getDeclaredConstructor();regionCtor.setAccessible(true);
        field(zombie.iso.areas.isoregion.IsoRegions.class,"regionWorker",regionCtor.newInstance());
        var loggerCtor=zombie.iso.areas.isoregion.IsoRegionsLogger.class.getDeclaredConstructor(boolean.class);loggerCtor.setAccessible(true);
        field(zombie.iso.areas.isoregion.IsoRegions.class,"logger",loggerCtor.newInstance(false));
        zombie.SandboxOptions.instance.elecShutModifier.setValue(0);zombie.SandboxOptions.instance.timeSinceApo.setValue(1);
        Field unsafeField=sun.misc.Unsafe.class.getDeclaredField("theUnsafe");unsafeField.setAccessible(true);
        gameState=(zombie.gameStates.IngameState)((sun.misc.Unsafe)unsafeField.get(null)).allocateInstance(zombie.gameStates.IngameState.class);
        gameState.numberTicks=100;zombie.gameStates.IngameState.instance=gameState;
        var square=cell.getGridSquare(14,20,0);square.setSolidFloor(true);square.room=new zombie.iso.areas.IsoRoom();square.roomId=1;
        consumer=new IsoObject(cell,square,new zombie.iso.sprite.IsoSprite());square.getObjects().add(consumer);
        consumer.setContainer(new zombie.inventory.ItemContainer("fridge",square,consumer));square.getChunk().addObjectPoweredByGenerator(consumer);
        return cell;
    }
    private static InventoryItem item(String type){
        InventoryItem item=prototypes.get(type).getScriptItem().InstanceItem(null,false);item.setID(nextItem++);items.put(item.getID(),item);return item;
    }
    public static IsoGenerator generator(String type,int x,int y){
        var square=cell.getGridSquare(x,y,0);square.getProperties().set(IsoFlagType.exterior);square.setSolidFloor(true);
        IsoGenerator created=new IsoGenerator(item(type),cell,square);created.addToWorld();return created;
    }
    private static void position(int x,int y){
        if(body.getSquare()!=null)body.getSquare().getMovingObjects().remove(body);
        var square=cell.getGridSquare(x,y,0);square.setSolidFloor(true);
        body.setX(x+.5f);body.setY(y+.5f);body.setZ(0);body.setCurrent(square);body.setSquare(square);square.getMovingObjects().add(body);
        body.setForwardDirection(x>10?-1:1,0);
    }
    private static int integer(Object value){return ((Number)value).intValue();}
    private static InventoryItem selected(Object id){return items.get(integer(id));}
    private static Object nativeCall(LuaCallFrame f)throws Exception{
        String op=(String)f.get(0);String key=f.get(1) instanceof String?(String)f.get(1):null;
        switch(op){
            case "reset":
                for(var extra:extraGenerators){extra.removeFromWorld();extra.getSquare().getObjects().remove(extra);}extraGenerators.clear();
                if(generator!=null){generator.setActivated(false);generator.removeFromWorld();generator.getSquare().getObjects().remove(generator);}
                body.getInventory().getItems().clear();body.getKnownRecipes().clear();body.getAlreadyReadBook().clear();
                body.getModData().rawset("SAOPersonId",f.get(2));
                generator=generator(key,10,20);generator.setCondition(integer(f.get(3)));generator.setFuel(((Number)f.get(4)).floatValue());
                body.setPerkLevelDebug(zombie.characters.skills.PerkFactory.Perks.Electricity,integer(f.get(5)));
                gameState.numberTicks++;position(11,20);return true;
            case "position":position(integer(f.get(1)),integer(f.get(2)));return true;
            case "get":return switch(key){
                case "condition"->(double)generator.getCondition();case "fuel"->(double)generator.getFuel();case "maxFuel"->(double)generator.getMaxFuel();
                case "connected"->generator.isConnected();case "active"->generator.isActivated();case "outside"->generator.getSquare().isOutside();
                case "index"->(double)generator.getObjectIndex();case "known"->body.isRecipeActuallyKnown("Generator");
                case "powered"->consumer.getContainer().isPowered();case "covered"->IsoGenerator.isPoweringSquare(10,20,0,14,20,0);
                case "skill"->(double)body.getPerkLevel(zombie.characters.skills.PerkFactory.Perks.Electricity);default->throw new IllegalArgumentException(key);};
            case "set":
                switch(key){case "condition"->generator.setCondition(integer(f.get(2)));case "fuel"->generator.setFuel(((Number)f.get(2)).floatValue());
                    case "connected"->generator.setConnected((Boolean)f.get(2));case "active"->{generator.setActivated((Boolean)f.get(2));gameState.numberTicks++;}
                    case "outside"->{if((Boolean)f.get(2))generator.getSquare().getProperties().set(IsoFlagType.exterior);else generator.getSquare().getProperties().unset(IsoFlagType.exterior);}
                    default->throw new IllegalArgumentException(key);}return true;
            case "new-item":{InventoryItem value=item(key);body.getInventory().AddItem(value);return(double)value.getID();}
            case "item":{var item=selected(f.get(1));String method=(String)f.get(2);return switch(method){
                case "type"->item.getFullType();case "id"->(double)item.getID();case "amount"->(double)item.getFluidContainer().getAmount();
                case "capacity"->(double)item.getFluidContainer().getCapacity();case "petrol"->item.getFluidContainer().contains(zombie.entity.components.fluids.Fluid.Petrol);
                case "consumed"->item.getIsCraftingConsumed();case "held"->body.getInventory().contains(item);case "pages"->(double)((Literature)item).getNumberOfPages();
                case "manual"->((Literature)item).getLearnedRecipes().contains("Generator");default->throw new IllegalArgumentException(method);};}
            case "drain":selected(f.get(1)).getFluidContainer().adjustAmount(((Number)f.get(2)).floatValue());return true;
            case "remove":body.getInventory().Remove(selected(f.get(1)));return true;
            case "read":body.ReadLiterature((Literature)selected(f.get(1)));return true;
            case "learn":return body.learnRecipe((String)f.get(1));
            case "fail-start":generator.failToStart();return true;
            case "extra-generator":{
                int x=integer(f.get(1)),y=integer(f.get(2));var square=cell.getGridSquare(x,y,0);
                var sprite=new zombie.iso.sprite.IsoSprite();sprite.getProperties().set(IsoFlagType.solidfloor);
                square.getObjects().add(new IsoObject(cell,square,sprite));square.getProperties().set(IsoFlagType.solidfloor);square.setSolidFloor(true);
                extraGenerators.add(generator("Base.Generator",x,y));return true;}
            case "reset-bindings":com.sao.engine.SAOWorldSources.resetRuntimeForWorld();return true;
            case "wire-generators":return SAOBridge.INSTANCE.worldGeneratorCandidates(body);
            case "wire-consumer":return SAOBridge.INSTANCE.worldGeneratorConsumer(body,consumer);
            case "consumer-power":return SAOBridge.INSTANCE.worldGeneratorConsumerPowered(body,generator,(String)f.get(1),(String)f.get(2),14,20,0);
            case "target":return SAOBridge.INSTANCE.worldGeneratorTarget(body,(String)f.get(1),(String)f.get(2),(String)f.get(3),10,20,0,(String)f.get(4));
            case "object":return SAOBridge.INSTANCE.worldGeneratorObject(body,(String)f.get(1),(String)f.get(2),(String)f.get(3),10,20,0,(String)f.get(4))==generator;
            case "valid":return SAOBridge.INSTANCE.worldGeneratorValid(body,generator,(String)f.get(1),(String)f.get(2),10,20,0,(String)f.get(3));
            case "consumer-target":return SAOBridge.INSTANCE.worldGeneratorConsumerTarget(body,(String)f.get(1),(String)f.get(2),(String)f.get(3),14,20,0);
            case "consumer-object":return SAOBridge.INSTANCE.worldGeneratorConsumerObject(body,(String)f.get(1),(String)f.get(2),(String)f.get(3),14,20,0)==consumer;
            default:throw new IllegalArgumentException(op);
        }
    }
    public static void main(String[] args)throws Exception{
        Thread.setDefaultUncaughtExceptionHandler((t,e)->{e.printStackTrace();System.exit(1);});
        initialise(Path.of(args[0]));
        var platform=new J2SEPlatform();var env=platform.newEnvironment();var thread=new KahluaThread(platform,env);thread.debugOwnerThread=Thread.currentThread();
        zombie.Lua.LuaManager.platform=platform;zombie.Lua.LuaManager.env=env;zombie.Lua.LuaManager.thread=thread;
        env.rawset("print",(JavaFunction)(f,n)->{for(int i=0;i<n;i++)System.out.print((i==0?"":"\t")+f.get(i));System.out.println();return 0;});
        env.rawset("__generatorNative",(JavaFunction)(f,n)->{try{return f.push(nativeCall(f));}catch(Exception e){throw new IllegalStateException(e);}});
        env.rawset("__nativeRoundtrip",(JavaFunction)(f,n)->{try{var bytes=ByteBuffer.allocate(1048576);((KahluaTable)f.get(0)).save(bytes);bytes.flip();var restored=platform.newTable();restored.load(bytes,IsoWorld.WorldVersion);return f.push(restored);}catch(Exception e){throw new IllegalStateException(e);}});
        final Map<String,Path> reload=new HashMap<>();for(int i=1;i<args.length;i++){Path path=Path.of(args[i]);reload.put(path.getFileName().toString(),path);}
        env.rawset("__reloadGeneratorOwner",(JavaFunction)(f,n)->{try{Path p=reload.get((String)f.get(0));thread.call(LuaCompiler.loadstring(Files.readString(p),p.toString(),env),null,null,null);return f.push(true);}catch(Exception e){throw new IllegalStateException(e);}});
        for(int i=1;i<args.length;i++)try(Reader reader=Files.newBufferedReader(Path.of(args[i]))){
            Object[] result=thread.pcall(LuaCompiler.loadis(reader,args[i],env),new Object[0]);
            if(!Boolean.TRUE.equals(result[0])){System.out.println("ERROR chunk="+args[i]);for(int j=1;j<result.length;j++)System.out.println(result[j]);System.exit(1);}
        }
        System.exit(0);
    }
}
