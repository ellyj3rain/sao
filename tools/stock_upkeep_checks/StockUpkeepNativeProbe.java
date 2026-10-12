import java.nio.file.*;
import java.util.*;
import java.lang.reflect.*;
import se.krka.kahlua.vm.*;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import zombie.Lua.LuaManager;
import zombie.characters.*;
import zombie.characters.skills.PerkFactory;
import zombie.inventory.*;
import zombie.iso.*;
import zombie.iso.objects.IsoWorldInventoryObject;
import zombie.entity.components.crafting.recipe.*;

/** Registered native metadata, actual items/inventory/callback/effects and
 * installed ISHandcraftAction. Body/map/dispatch are explicit controlled ports. */
public final class StockUpkeepNativeProbe {
    static int callbackCount;
    public static class Receiver extends RecipePolicyNativeProbe.Receiver {
        IsoGameCharacter.XP xp;
        public Receiver(){super();}
        @Override public IsoGameCharacter.XP getXp(){return xp;}
        @Override public int getWeaponLevel(){return 0;}
        @Override public int getWeaponLevel(zombie.inventory.types.HandWeapon weapon){return 0;}
    }
    public static class Xp extends IsoGameCharacter.XP {
        Xp(Receiver actor){actor.super(actor);}
        @Override public void AddXP(PerkFactory.Perk p,float a,boolean b,boolean c,boolean d,boolean e){}
    }
    public static class Station extends RecipePolicyNativeProbe.Station {
        public Station(){super();}
        @Override public boolean isUsingPlayer(IsoPlayer actor){return custody && getUsingPlayer()==actor;}
    }
    static KahluaTable reset(String kind)throws Exception {
        KahluaTable fixture=RecipePolicyNativeProbe.reset(kind);
        var old=RecipePolicyNativeProbe.body;
        Receiver actor=(Receiver)RecipePolicyNativeProbe.unsafe().allocateInstance(Receiver.class);
        actor.inventory=old.inventory;actor.history=new PlayerCraftHistory(actor);actor.skill=10;actor.learned=true;actor.xp=new Xp(actor);
        RecipePolicyNativeProbe.body=actor;fixture.rawset("body",actor);callbackCount=0;
        if(kind.equals("grind")){
            var prior=(RecipePolicyNativeProbe.Station)fixture.rawget("object");
            Station station=(Station)RecipePolicyNativeProbe.unsafe().allocateInstance(Station.class);
            station.definition=prior.definition;station.square=prior.square;station.custody=true;
            station.setSquare(station.square);station.square.getObjects().add(station);
            fixture.rawset("object",station);
        }
        var selected=(KahluaTable)fixture.rawget("items");
        var layouts=Map.of("adhesive",List.of("Hammer","Scotchtape","Scotchtape","Scotchtape"),
            "zipties",List.of("Hammer","Zipties"),"glue",List.of("Hammer","Glue"),"woodglue",List.of("Hammer","Woodglue"),
            "epoxy-rags",List.of("Hammer","Epoxy","RippedSheets","RippedSheets"),
            "whetstone",List.of("Scissors","Whetstone"),"file-blade",List.of("Scissors","File"),
            "small-replace",List.of("SmallSaw","SmallSawblade"));
        if(layouts.containsKey(kind)){
            for(String name:layouts.get(kind))selected.rawset(name,RecipePolicyNativeProbe.item(name));
            for(String name:List.of("Hammer","SmallSaw","Scissors"))if(selected.rawget(name) instanceof InventoryItem item){item.setConditionNoSound(3);item.setSharpness(.1f);}
            if(List.of("adhesive","zipties","glue","woodglue","epoxy-rags").contains(kind)){
                RecipePolicyNativeProbe.Station surface=(RecipePolicyNativeProbe.Station)RecipePolicyNativeProbe.unsafe().allocateInstance(RecipePolicyNativeProbe.Station.class);
                surface.custody=true;surface.setFar(false);fixture.rawset("object",surface);
            }
        }
        if(kind.equals("refuel")){
            InventoryItem tank=(InventoryItem)((KahluaTable)fixture.rawget("items")).rawget("PropaneTank");
            tank.setCurrentUses(tank.getMaxUses());
        }
        if(kind.equals("stone")){
            var items=(KahluaTable)fixture.rawget("items");items.rawset("SecondStone",RecipePolicyNativeProbe.item("Stone2"));
            RecipePolicyNativeProbe.Station surface=(RecipePolicyNativeProbe.Station)RecipePolicyNativeProbe.unsafe().allocateInstance(RecipePolicyNativeProbe.Station.class);
            surface.custody=true;surface.setFar(false);fixture.rawset("object",surface);
        }
        return fixture;
    }
    public static void main(String[] args)throws Exception {
        // Reuse the pinned selected native parser/dictionary instrument, with
        // no policy cases or effects run during initialization.
        RecipePolicyNativeProbe.main(new String[]{args[0]});
        zombie.network.GameServer.server=true;
        Path game=Path.of(args[0]);
        var module=RecipePolicyNativeProbe.module;
        for(String name:List.of("Nails","Mattress")){
            Path source=game.resolve("media/scripts/generated/items/"+(name.equals("Mattress")?"moveable.txt":"normal.txt"));
            String definition=RecipePolicyNativeProbe.block(Files.readString(source),"item",name).replaceAll("(?im)^\\s*Researchablerecipes\\s*=.*$","");
            var item=new zombie.scripting.objects.Item();item.setModule(module);item.setModID("pz-vanilla");item.InitLoadPP(name);item.Load(name,definition);item.setDisplayName(name);
            module.items.getScriptMap().put(name,item);
        }
        var entity=new zombie.scripting.entity.GameEntityScript();entity.setModule(module);entity.InitLoadPP("Wood_Bed");
        String source=Files.readString(game.resolve("media/scripts/generated/entities/furniture/entity_carpentry_bed.txt"));
        entity.Load("Wood_Bed","entity Wood_Bed { "+RecipePolicyNativeProbe.block(source,"component","CraftRecipe")+" }");
        entity.OnScriptsLoaded(zombie.scripting.ScriptLoadMode.Init);
        var component=(zombie.scripting.entity.components.crafting.CraftRecipeComponentScript)entity.getComponentScriptFor(zombie.entity.ComponentType.CraftRecipe);
        var consumer=component.getCraftRecipe();module.craftRecipes.getScriptMap().put("Wood_Bed",consumer);
        RecipePolicyNativeProbe.register();zombie.inventory.ItemTags.Init(zombie.scripting.ScriptManager.instance.getAllItems());
        consumer.OnPostWorldDictionaryInit();
        zombie.network.GameServer.server=false;
        var env=RecipePolicyNativeProbe.env;var thread=LuaManager.thread;var exposer=LuaManager.exposer;
        for(Class<?> type:new Class<?>[]{Receiver.class,Station.class,zombie.entity.GameEntity.class,zombie.scripting.objects.TimedActionScript.class,
            zombie.characters.CharacterTimedActions.BaseAction.class,zombie.characters.CharacterActionAnims.class,
            zombie.scripting.objects.CharacterTrait.class,zombie.inventory.ItemContainer.class,
            zombie.util.list.PZArrayList.class,IsoWorldInventoryObject.class,IsoGridSquare.class,
            zombie.scripting.logic.RecipeCodeOnCreate.class}){exposer.setExposed(type);exposer.exposeLikeJava(type,env);}
        KahluaTable callbacks=RecipePolicyNativeProbe.platform.newTable();
        for(Method method:zombie.scripting.logic.RecipeCodeOnCreate.class.getDeclaredMethods()){
            Class<?>[] p=method.getParameterTypes();
            if(Modifier.isStatic(method.getModifiers()) && p.length==2 && p[0]==CraftRecipeData.class && p[1]==IsoGameCharacter.class){
                callbacks.rawset(method.getName(),(JavaFunction)(f,n)->{try{callbackCount++;method.invoke(null,f.get(0),f.get(1));return 0;}catch(Exception e){e.printStackTrace();throw new IllegalStateException(e);}});
            }
        }
        env.rawset("RecipeCodeOnCreate",callbacks);
        env.rawset("__stockReset",(JavaFunction)(f,n)->{try{return f.push(reset((String)f.get(0)));}catch(Exception e){throw new IllegalStateException(e);}});
        env.rawset("__callbackCount",(JavaFunction)(f,n)->f.push((double)callbackCount));
        env.rawset("__addOrDrop",(JavaFunction)(f,n)->{
            InventoryItem item=(InventoryItem)f.get(0);var actor=RecipePolicyNativeProbe.body;
            if(Boolean.TRUE.equals(f.get(1))){
                zombie.network.GameServer.server=true;
                var square=new IsoGridSquare(null,null,0,0,0);
                var world=new IsoWorldInventoryObject(item,square,.5f,.5f,0);
                square.getWorldObjects().add(world);square.getObjects().add(world);item.setWorldItem(world);item.setContainer(null);
                zombie.network.GameServer.server=false;
            }else{actor.inventory.AddItemBlind(item);item.setContainer(actor.inventory);}
            return 0;
        });
        env.rawset("__nativeBody",(JavaFunction)(f,n)->f.push(RecipePolicyNativeProbe.body));
        env.rawset("__seed",(JavaFunction)(f,n)->{zombie.core.random.RandStandard.INSTANCE.init();return 0;});
        for(int n=1;n<args.length;n++){
            Object[] result=thread.pcall(LuaCompiler.loadstring(Files.readString(Path.of(args[n])),args[n],env),new Object[0]);
            if(!Boolean.TRUE.equals(result[0]))throw new AssertionError(Arrays.toString(result));
        }
    }
}
