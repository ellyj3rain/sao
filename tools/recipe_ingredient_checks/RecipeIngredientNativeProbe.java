import com.sao.engine.*;
import com.sao.bridge.SAOBridge;
import java.lang.reflect.*;
import java.nio.file.*;
import java.util.*;
import se.krka.kahlua.vm.*;
import zombie.Lua.LuaManager;
import zombie.iso.*;
import zombie.iso.sprite.IsoSprite;
import zombie.inventory.*;

/** Production ports on real native shells/items/source inspection. The loaded
 * scene and exact retained-demand decision are controlled fixture ports. */
public final class RecipeIngredientNativeProbe {
    static int cases;
    static SAOIsoPlayerShell currentBody;
    static ItemContainer currentContainer;
    static IsoObject currentObject;
    static zombie.core.textures.Texture nonrenderingTexture;
    public static KahluaTable prepareIntegratedNative() throws Exception {
        currentObject.getProperties().set("GenericCraftingSurface","true");
        currentBody.getInventory().getItems().clear();currentContainer.getItems().clear();
        var first=RecipePolicyNativeProbe.item("Stone2");var second=RecipePolicyNativeProbe.item("Stone2");var target=RecipePolicyNativeProbe.item("Scissors");
        for(var item:List.of(first,second)){item.getContainer().Remove(item);currentContainer.AddItemBlind(item);item.setContainer(currentContainer);}
        target.getContainer().Remove(target);currentBody.getInventory().AddItemBlind(target);target.setContainer(currentBody.getInventory());target.setSharpness(.1f);
        var offer=Arrays.stream(SAOWorldSources.inspectionCandidates(currentBody,12).split("\\n")).filter(line->line.startsWith("C|")).map(RecipeIngredientNativeProbe::fields).findFirst().orElseThrow();
        String inspection=SAOWorldSources.inspectContainer(currentBody,offer.get("id"),offer.get("fp"),11,20,0);
        var source=Arrays.stream(inspection.split("\\n")).filter(line->line.startsWith("S|")&&fields(line).get("id").equals(offer.get("id"))).map(RecipeIngredientNativeProbe::fields).findFirst().orElseThrow();
        var sao=(KahluaTable)LuaManager.env.rawget("SAO");var perception=(KahluaTable)sao.rawget("Perception");
        // Real personal owners acquire this returned native inspection themselves.
        if(perception!=null&&perception.rawget("beliefs") instanceof KahluaTable beliefs)beliefs.rawset("ingredient-person",null);
        var records=(KahluaTable)zombie.world.moddata.GlobalModData.instance.get("SurvivorAwareness_Records").rawget("records");
        var out=table();out.rawset("body",currentBody);out.rawset("record",records.rawget("ingredient-person"));out.rawset("inspection",inspection);
        out.rawset("sourceId",source.get("id"));out.rawset("fingerprint",source.get("fp"));out.rawset("revision",source.get("rev"));
        out.rawset("container",currentContainer);out.rawset("object",currentObject);out.rawset("first",first);out.rawset("second",second);out.rawset("target",target);
        out.rawset("x",11.0);out.rawset("y",20.0);out.rawset("z",0.0);return out;
    }
    static void check(String name,boolean value){System.out.println("CHECK "+name+"="+value);if(!value)throw new AssertionError(name);cases++;}
    static KahluaTable table(){return LuaManager.platform.newTable();}
    static Object fixture(String name,Class<?>[] signature,Object...args)throws Exception{
        var m=MovementCrossingProbe.class.getDeclaredMethod(name,signature);m.setAccessible(true);return m.invoke(null,args);
    }
    static void run(String source)throws Exception{
        var result=LuaManager.thread.pcall(se.krka.kahlua.luaj.compiler.LuaCompiler.loadstring(source,"recipe-ingredient-fixture",LuaManager.env),new Object[0]);
        if(!Boolean.TRUE.equals(result[0]))throw new AssertionError(Arrays.toString(result));
    }
    static KahluaTable row(Object array,int index){return array instanceof KahluaTable t?(KahluaTable)t.rawget((double)index):null;}
    static Map<String,String> fields(String line){var out=new LinkedHashMap<String,String>();for(String field:line.split("\\|")){int at=field.indexOf('=');if(at>0)out.put(field.substring(0,at),field.substring(at+1));}return out;}
    static void initializeNonrenderingDrops() throws Exception {
        // Exact scene support reused from the qualified extraction fixture.
        // Metadata and native job receivers only; no GPU or worker thread starts.
        var slot=sun.misc.Unsafe.class.getDeclaredField("theUnsafe");slot.setAccessible(true);
        var texture=(zombie.core.textures.Texture)((sun.misc.Unsafe)slot.get(null)).allocateInstance(zombie.core.textures.Texture.class);
        nonrenderingTexture=texture;
        String name="media/inventory/Question_On.png";
        var named=zombie.core.textures.Texture.class.getDeclaredField("name");named.setAccessible(true);named.set(texture,name);
        for(String dimension:List.of("width","height","widthOrig","heightOrig")){
            var value=zombie.core.textures.Texture.class.getDeclaredField(dimension);value.setAccessible(true);value.setInt(texture,32);
        }
        var shared=zombie.core.textures.Texture.class.getDeclaredField("s_sharedTextureTable");shared.setAccessible(true);
        ((Map<String,zombie.core.textures.Texture>)shared.get(null)).put(name,texture);zombie.core.textures.Texture.nullTextures.remove(name);
        var regionConstructor=zombie.iso.areas.isoregion.IsoRegionWorker.class.getDeclaredConstructor();regionConstructor.setAccessible(true);
        var regionWorker=zombie.iso.areas.isoregion.IsoRegions.class.getDeclaredField("regionWorker");regionWorker.setAccessible(true);regionWorker.set(null,regionConstructor.newInstance());
        var polygon=zombie.pathfind.PolygonalMap2.instance;
        var threadConstructor=Class.forName("zombie.pathfind.PolygonalMap2$PMThread").getDeclaredConstructor(zombie.pathfind.PolygonalMap2.class);threadConstructor.setAccessible(true);
        var polygonThread=zombie.pathfind.PolygonalMap2.class.getDeclaredField("thread");polygonThread.setAccessible(true);polygonThread.set(polygon,threadConstructor.newInstance(polygon));
    }
    static KahluaTable observe(SAOIsoPlayerShell body,Map<String,String> source,String recipe,int index,String declaration){
        return (KahluaTable)SAOBridge.INSTANCE.recipeInputObservation(body,source.get("id"),source.get("fp"),source.get("rev"),recipe,index,declaration,"demand-1","purpose-1","acquire-1");
    }
    static void exposeSource(String actor,Map<String,String> source){
        var sao=(KahluaTable)LuaManager.env.rawget("SAO");var perception=(KahluaTable)sao.rawget("Perception");var beliefs=(KahluaTable)perception.rawget("beliefs");
        var mind=table();var known=table();var place=table();var facts=table();var fact=table();
        for(var key:List.of("id","fingerprint","revision","state","knowledgeKind"))fact.rawset(key,switch(key){case "fingerprint"->source.get("fp");case "revision"->source.get("rev");case "knowledgeKind"->"inspected-container";default->source.get(key);});
        fact.rawset("explored",true);for(String key:List.of("x","y","z"))fact.rawset(key,Double.valueOf(source.get(key)));
        facts.rawset(source.get("id"),fact);place.rawset("sourceFacts",facts);known.rawset(1.0,place);mind.rawset("known",known);beliefs.rawset(actor,mind);
    }
    public static void main(String[] args)throws Exception{
        IsoCell cell=(IsoCell)fixture("boot",new Class<?>[0]);
        initializeNonrenderingDrops();
        RecipePolicyNativeProbe.main(new String[]{args[0]});
        var properties=new HashMap<String,ArrayList<String>>();properties.put("GenericCraftingSurface",new ArrayList<>(List.of("true","false")));zombie.core.TilePropertyAliasMap.instance.Generate(properties);
        var region=zombie.iso.areas.isoregion.IsoRegions.class.getDeclaredField("dataRoot");region.setAccessible(true);region.set(null,new zombie.iso.areas.isoregion.data.DataRoot());
        var body=(SAOIsoPlayerShell)fixture("person",new Class<?>[]{IsoCell.class},cell);
        body.getModData().rawset("SAOPersonId","ingredient-person");body.setSquare(body.getCurrentSquare());
        body.getCurrentSquare().getMovingObjects().add(body);cell.getObjectList().add(body);body.setForwardDirection(1,0);
        var records=zombie.world.moddata.GlobalModData.instance.getOrCreate("SurvivorAwareness_Records");var registry=table();var rec=table();rec.rawset("id","ingredient-person");registry.rawset("ingredient-person",rec);records.rawset("records",registry);
        run("SAO={Body={active={}},Perception={beliefs={}},ProceduralPlanning={recipeInputAdmission=function(id,demand,purpose,step,recipe,index,declaration) return __demandCurrent~=false and id=='ingredient-person' and demand=='demand-1' and purpose=='purpose-1' and step=='acquire-1' end}};require=function()end");
        var sao=(KahluaTable)LuaManager.env.rawget("SAO");((KahluaTable)((KahluaTable)sao.rawget("Body")).rawget("active")).rawset("ingredient-person",body);
        LuaManager.exposer.setExposed(SAOBridge.class);LuaManager.exposer.exposeLikeJava(SAOBridge.class,LuaManager.env);LuaManager.env.rawset("SAOJavaBridge",SAOBridge.INSTANCE);
        RecipePolicyNativeProbe.reset("stone");var stone=RecipePolicyNativeProbe.item("Scotchtape");
        // Explicit native item-state control: the current generic fuel classifier
        // reads the cooking burn threshold; zero leaves this installed donor unclassified.
        stone.setMinutesToBurn(0);
        stone.getContainer().Remove(stone);
        var square=cell.getGridSquare(11,20,0);var object=new IsoObject(cell);object.setSquare(square);object.setSprite(new IsoSprite());square.getObjects().add(object);
        var container=new ItemContainer("counter",square,object);object.setContainer(container);container.setExplored(true);container.AddItemBlind(stone);stone.setContainer(container);
        currentBody=body;currentContainer=container;currentObject=object;
        var offer=Arrays.stream(SAOWorldSources.inspectionCandidates(body,12).split("\\n")).filter(line->line.startsWith("C|")).map(RecipeIngredientNativeProbe::fields).findFirst().orElseThrow();
        String inspection=SAOWorldSources.inspectContainer(body,offer.get("id"),offer.get("fp"),11,20,0);
        check("actual_native_full_inspection",inspection.startsWith("I|source="));
        var source=Arrays.stream(inspection.split("\\n")).filter(line->line.startsWith("S|")&&fields(line).get("id").equals(offer.get("id"))).map(RecipeIngredientNativeProbe::fields).findFirst().orElseThrow();
        var ingredientLine=Arrays.stream(inspection.split("\\n")).filter(line->line.startsWith("I|")&&line.contains("|type=Base.Scotchtape")).findFirst().orElseThrow();
        System.out.println("INGREDIENT "+ingredientLine);
        check("native_empty_category_item_row",fields(ingredientLine).get("cats").isEmpty());
        var recipe=zombie.scripting.ScriptManager.instance.getCraftRecipe("Base.FixWithAdhesiveTape");var input=recipe.getInputs().get(1);int index=recipe.getIndexForIO(input);
        check("unseen_signed_source_refused",observe(body,source,recipe.getScriptObjectFullType(),index,input.getOriginalLine())==null);
        exposeSource("ingredient-person",source);
        var observation=observe(body,source,recipe.getScriptObjectFullType(),index,input.getOriginalLine());
        check("exact_emptycat_native_input_observed",observation!=null&&row(observation.rawget("items"),1)!=null&&Boolean.TRUE.equals(row(observation.rawget("items"),1).rawget("nativeEligible")));
        check("wrong_native_slot_refused",observe(body,source,recipe.getScriptObjectFullType(),index+1,input.getOriginalLine())==null);
        check("wrong_declaration_refused",observe(body,source,recipe.getScriptObjectFullType(),index,input.getOriginalLine()+" ")==null);
        LuaManager.env.rawset("__demandCurrent",false);check("noncurrent_demand_observation_refused",observe(body,source,recipe.getScriptObjectFullType(),index,input.getOriginalLine())==null);LuaManager.env.rawset("__demandCurrent",true);
        var active=(KahluaTable)((KahluaTable)sao.rawget("Body")).rawget("active");active.rawset("ingredient-person",null);
        check("foreign_body_observation_refused",observe(body,source,recipe.getScriptObjectFullType(),index,input.getOriginalLine())==null);active.rawset("ingredient-person",body);
        stone.setFavorite(true);check("changed_native_item_revision_refused",observe(body,source,recipe.getScriptObjectFullType(),index,input.getOriginalLine())==null);stone.setFavorite(false);
        String old=source.get("rev");source.put("rev","0".repeat(64));check("stale_source_revision_refused",observe(body,source,recipe.getScriptObjectFullType(),index,input.getOriginalLine())==null);source.put("rev",old);
        // Native learned eligibility retains its exact current-person meaning.
        var demand=table();demand.rawset("kind","recipe-stock");demand.rawset("sourceRevision","native-request-1");demand.rawset("desiredType","Base.CrudeWhetstone");demand.rawset("desiredAmount",1.0);demand.rawset("consumerRecipeId","Base.SharpenBlade");
        zombie.SandboxOptions.instance.seeNotLearntRecipe.setValue(true);
        var means=(KahluaTable)SAOBridge.INSTANCE.recipeMeansForDemand(body,demand);
        boolean unrelated=false;if(means!=null)for(int n=1;n<=means.len();n++)if(!"Base.MakeCrudeWhetstone".equals(row(means,n).rawget("recipeId")))unrelated=true;
        check("unrelated_native_producer_refused",!unrelated);
        check("unlearned_native_mean_withheld",means!=null&&means.len()==0);
        body.getKnownRecipes().add("MakeCrudeWhetstone");means=(KahluaTable)SAOBridge.INSTANCE.recipeMeansForDemand(body,demand);
        check("exact_known_consumer_filtered_mean",means!=null&&means.len()==1&&"Base.MakeCrudeWhetstone".equals(row(means,1).rawget("recipeId")));
        demand.rawset("consumerRecipeId","Base.FixSaw");check("wrong_requesting_native_consumer_refused",((KahluaTable)SAOBridge.INSTANCE.recipeMeansForDemand(body,demand)).len()==0);
        var supply=(KahluaTable)SAOBridge.INSTANCE.recipeSupplyNeeds(body,"Base.MakeCrudeWhetstone");
        check("native_supply_shortage",supply!=null&&Double.valueOf(1).equals(row(supply.rawget("slots"),1).rawget("remainingFraction")));
        var supplyStone=RecipePolicyNativeProbe.item("Stone2");supplyStone.getContainer().Remove(supplyStone);body.getInventory().AddItemBlind(supplyStone);supplyStone.setContainer(body.getInventory());
        supply=(KahluaTable)SAOBridge.INSTANCE.recipeSupplyNeeds(body,"Base.MakeCrudeWhetstone");
        check("current_native_supply_fraction",Double.valueOf(.5).equals(row(supply.rawget("slots"),1).rawget("heldFraction")));
        var data=zombie.world.moddata.GlobalModData.instance.getOrCreate("SurvivorAwareness_WorldSources");var reservations=table();var reservation=table();reservation.rawset("status","reserved");reservation.rawset("itemId",(double)supplyStone.getID());reservations.rawset("foreign",reservation);data.rawset("reservations",reservations);
        supply=(KahluaTable)SAOBridge.INSTANCE.recipeSupplyNeeds(body,"Base.MakeCrudeWhetstone");check("foreign_reservation_not_supply",Double.valueOf(0).equals(row(supply.rawget("slots"),1).rawget("heldFraction")));data.rawset("reservations",table());
        var repairFixture=RecipePolicyNativeProbe.reset("fix");var target=(InventoryItem)((KahluaTable)repairFixture.rawget("items")).rawget("Saw");target.getContainer().Remove(target);body.getInventory().AddItemBlind(target);target.setContainer(body.getInventory());
        var upkeep=(KahluaTable)SAOBridge.INSTANCE.recipeUpkeepDemands(body);check("native_carried_upkeep_deficit",upkeep!=null&&upkeep.len()>0);
        target.setConditionNoSound(target.getConditionMax());upkeep=(KahluaTable)SAOBridge.INSTANCE.recipeUpkeepDemands(body);
        boolean same=false;for(int n=1;n<=upkeep.len();n++)if(Integer.toString(target.getID()).equals(row(upkeep,n).rawget("targetItemId")))same=true;
        check("full_native_target_not_upkeep",!same);
        // Native generic surface predicate and current native object occupancy.
        // The controlled loaded scene records actual native floor support.
        // It has no rendered puddle objects or OpenGL context.
        square.setSolidFloor(true);
        object.getProperties().set("GenericCraftingSurface","true");
        System.out.println("SURFACE native="+object.isGenericCraftingSurface()+" usable="+body.canUseAsGenericCraftingSurface(object)+" supported="+square.isSolidFloor()+" raw="+object.getProperties().get("GenericCraftingSurface"));
        var workplaces=(KahluaTable)SAOBridge.INSTANCE.observeRecipeWorkplaces(body,12);var workplace=row(workplaces,1);
        check("native_visible_surface_observed",workplace!=null&&Boolean.TRUE.equals(workplace.rawget("genericSurface")));
        String key=(String)workplace.rawget("key"),revision=(String)workplace.rawget("revision");
        check("acquired_reached_workplace_resolved",SAOBridge.INSTANCE.recipeWorkplace(body,key,revision,11,20,0)!=null);
        check("unobserved_workplace_refused",SAOBridge.INSTANCE.recipeWorkplace(body,key+"foreign",revision,11,20,0)==null);
        var other=(SAOIsoPlayerShell)fixture("person",new Class<?>[]{IsoCell.class},cell);object.setUsingPlayer(other);
        check("foreign_occupied_workplace_refused",SAOBridge.INSTANCE.recipeWorkplace(body,key,revision,11,20,0)==null);object.setUsingPlayer(null);
        object.getProperties().set("GenericCraftingSurface","false");check("changed_native_surface_refused",SAOBridge.INSTANCE.recipeWorkplace(body,key,revision,11,20,0)==null);
        var availablePlatform=LuaManager.platform;
        try {
            LuaManager.platform=null;
            boolean safeUpkeep=false,safeMeans=false,safeWorkplaces=false;
            try { safeUpkeep=SAOBridge.INSTANCE.recipeUpkeepDemands(body)==null; }catch(Throwable escaped){}
            try { safeMeans=SAOBridge.INSTANCE.recipeMeansForDemand(body,demand)==null; }catch(Throwable escaped){}
            try { safeWorkplaces=SAOBridge.INSTANCE.observeRecipeWorkplaces(body,12)==null; }catch(Throwable escaped){}
            check("unavailable_platform_upkeep_refused",safeUpkeep);
            check("unavailable_platform_means_refused",safeMeans);
            check("unavailable_platform_workplace_refused",safeWorkplaces);
        } finally { LuaManager.platform=availablePlatform; }
        System.out.println("PASS recipe ingredient native "+cases);
        // Optional real Lua acquisition cases receive only this explicit native fixture.
        LuaManager.env.rawset("__ingredientBody",body);LuaManager.env.rawset("__ingredientTarget",target);LuaManager.env.rawset("__nativeInputRecipe",recipe);
        LuaManager.env.rawset("__ingredientInspection",inspection);LuaManager.env.rawset("__ingredientDonor",stone);LuaManager.env.rawset("__ingredientContainer",container);LuaManager.env.rawset("__ingredientSourceId",source.get("id"));
        LuaManager.env.rawset("__nativeModData",(JavaFunction)(frame,n)->frame.push(zombie.world.moddata.GlobalModData.instance.getOrCreate((String)frame.get(0))));
        JavaFunction nativeType=(frame,n)->frame.push(zombie.Lua.LuaManager.GlobalObject.isType(frame.get(0),(String)frame.get(1)));
        LuaManager.env.rawset("__nativeInstanceOf",nativeType);
        LuaManager.env.rawset("__nativeInstanceof",nativeType);
        LuaManager.exposer.setExposed(zombie.scripting.objects.CharacterTrait.class);LuaManager.exposer.exposeLikeJava(zombie.scripting.objects.CharacterTrait.class,LuaManager.env);
        LuaManager.exposer.setExposed(SAOIsoPlayerShell.class);LuaManager.exposer.exposeLikeJava(SAOIsoPlayerShell.class,LuaManager.env);
        for(Class<?> type:new Class<?>[]{zombie.characters.CharacterTimedActions.LuaTimedActionNew.class,
                zombie.characters.CharacterTimedActions.BaseAction.class,zombie.characters.CharacterActionAnims.class,
                zombie.scripting.objects.TimedActionScript.class,zombie.scripting.objects.CharacterTrait.class,
                zombie.util.list.PZArrayList.class,IsoObject.class,IsoGridSquare.class,IsoCell.class,
                java.util.Stack.class,java.util.Vector.class,java.util.LinkedList.class,zombie.iso.objects.IsoWorldInventoryObject.class,
                zombie.characters.BaseCharacterSoundEmitter.class,zombie.characters.CharacterSoundEmitter.class,
                zombie.characters.DummyCharacterSoundEmitter.class,zombie.characters.IsoGameCharacter.XP.class,
                zombie.characters.Moodles.Moodles.class,zombie.scripting.objects.MoodleType.class,
                zombie.characters.Stats.class,zombie.characters.CharacterStat.class,
                zombie.characters.BodyDamage.BodyDamage.class,zombie.characters.BodyDamage.Metabolics.class,
                zombie.characters.BodyDamage.BodyPart.class,zombie.characters.BodyDamage.BodyPartType.class,
                zombie.characters.WornItems.WornItems.class,zombie.characters.WornItems.WornItem.class,
                zombie.characters.AttachedItems.AttachedItems.class,zombie.characters.AttachedItems.AttachedItem.class,
                zombie.core.skinnedmodel.visual.ItemVisuals.class,zombie.core.skinnedmodel.visual.ItemVisual.class,
                zombie.characters.skills.PerkFactory.class,zombie.characters.skills.PerkFactory.Perks.class,
                zombie.characters.PlayerCraftHistory.class,zombie.scripting.objects.ActionSoundTime.class,
                zombie.scripting.logic.RecipeCodeOnCreate.class}){
            LuaManager.exposer.setExposed(type);LuaManager.exposer.exposeLikeJava(type,LuaManager.env);
        }
        for(Class<?> type:new Class<?>[]{zombie.ai.states.ClimbThroughWindowState.class,zombie.ai.states.ClimbOverFenceState.class,
                zombie.ai.states.ClimbOverWallState.class,zombie.ai.states.ClimbSheetRopeState.class,
                zombie.ai.states.ClimbDownSheetRopeState.class,zombie.ai.states.CloseWindowState.class,zombie.ai.states.OpenWindowState.class}){
            LuaManager.exposer.setExposed(type);LuaManager.exposer.exposeLikeJava(type,LuaManager.env);
        }
        var callbacks=table();
        for(Method method:zombie.scripting.logic.RecipeCodeOnCreate.class.getDeclaredMethods()) {
            Class<?>[] p=method.getParameterTypes();
            if(Modifier.isStatic(method.getModifiers())&&p.length==2
                    &&p[0]==zombie.entity.components.crafting.recipe.CraftRecipeData.class&&p[1]==zombie.characters.IsoGameCharacter.class)
                callbacks.rawset(method.getName(),(JavaFunction)(frame,n)->{try{method.invoke(null,frame.get(0),frame.get(1));return 0;}catch(Exception failed){throw new IllegalStateException(failed);}});
        }
        LuaManager.env.rawset("RecipeCodeOnCreate",callbacks);
        LuaManager.env.rawset("__prepareIntegratedNative",(JavaFunction)(frame,n)->{try{return frame.push(prepareIntegratedNative());}catch(Exception failed){throw new IllegalStateException(failed);}});
        LuaManager.env.rawset("__dropNativeOutput",(JavaFunction)(frame,n)->{
            InventoryItem item=(InventoryItem)frame.get(0);
            if(item.getTex()==null)item.setTexture(nonrenderingTexture); // Isolated scene metadata, never a native eligibility change.
            currentBody.getSquare().AddWorldInventoryItem(item,.5f,.5f,0f);
            return frame.push(item.getWorldItem());
        });
        LuaManager.env.rawset("__retainConsumerProjection",(JavaFunction)(frame,n)->{
            String name=(String)frame.get(0);if(!name.matches("[a-z0-9-]+"))throw new IllegalArgumentException("private projection name");
            try { Files.writeString(Path.of(System.getProperty("user.home")).resolve(name+".json"),(String)frame.get(1));return frame.push(true); }
            catch(java.io.IOException failed){throw new java.io.UncheckedIOException(failed);}
        });
        LuaManager.env.rawset("__moveConsumerTo",(JavaFunction)(frame,n)->{
            int x=((Double)frame.get(0)).intValue(),y=((Double)frame.get(1)).intValue();
            var destination=currentBody.getCell().getGridSquare(x,y,0);if(destination==null)throw new IllegalArgumentException("unloaded controlled route endpoint");
            currentBody.getSquare().getMovingObjects().remove(currentBody);currentBody.setX(x+.5f);currentBody.setY(y+.5f);
            currentBody.setCurrent(destination);currentBody.setSquare(destination);currentBody.setLast(destination);destination.getMovingObjects().add(currentBody);
            return frame.push(true);
        });
        LuaManager.env.rawset("__nativeRefillObservations",(JavaFunction)(frame,n)->{
            try {
            var fixture=RecipePolicyNativeProbe.reset("refuel");var torch=(InventoryItem)((KahluaTable)fixture.rawget("items")).rawget("BlowTorch");
            torch.getContainer().Remove(torch);currentBody.getInventory().AddItemBlind(torch);torch.setContainer(currentBody.getInventory());
            var empty=SAOBridge.INSTANCE.recipeUpkeepDemands(currentBody);torch.setCurrentUses(Math.max(1,torch.getMaxUses()/2));
            var partial=SAOBridge.INSTANCE.recipeUpkeepDemands(currentBody);var out=table();out.rawset("empty",empty);out.rawset("partial",partial);out.rawset("itemId",Integer.toString(torch.getID()));
            currentBody.getInventory().Remove(torch);torch.setContainer(null);return frame.push(out);
            }catch(Exception failed){throw new IllegalStateException(failed);}
        });
        LuaManager.env.rawset("__prepareConsumerBench",(JavaFunction)(frame,n)->{
            try {return frame.push(Class.forName("BenchConsumerNativeSetup").getMethod("prepare",SAOIsoPlayerShell.class).invoke(null,currentBody));}catch(Exception failed){throw new IllegalStateException(failed);}
        });
        LuaManager.env.rawset("__nativeForeignBenchOwner",(JavaFunction)(frame,n)->{
            try {return frame.push(fixture("person",new Class<?>[]{IsoCell.class},currentBody.getCell()));}catch(Exception failed){throw new IllegalStateException(failed);}
        });
        LuaManager.env.rawset("__seedHeldRecipeItem",(JavaFunction)(frame,n)->{
            var item=RecipePolicyNativeProbe.item((String)frame.get(0));item.getContainer().Remove(item);
            currentBody.getInventory().AddItemBlind(item);item.setContainer(currentBody.getInventory());return frame.push(item);
        });
        for(int n=1;n<args.length;n++)run(Files.readString(Path.of(args[n])));
        System.exit(0);
    }
}
