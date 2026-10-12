import java.lang.reflect.*;
import java.nio.file.*;
import java.util.*;
import zombie.inventory.*;
import zombie.inventory.types.*;
import zombie.iso.*;
import zombie.characters.*;
import zombie.characters.skills.PerkFactory;
import zombie.scripting.*;
import zombie.scripting.objects.ScriptModule;
import zombie.scripting.entity.*;
import zombie.scripting.entity.components.crafting.*;
import zombie.entity.ComponentType;
import zombie.entity.components.build.BuildLogic;
import zombie.entity.components.crafting.recipe.CraftRecipeManager;

/** Installed D3.15 definitions, native reading and inventory payment.
 * Adapts the qualified D3.14 loader; its actor is a native IsoPlayer and
 * all runtime classes come from installed game jars. No SAO runtime input. */
public final class MetalEnclosurePrerequisiteProbe {
    private static final class MaterialInfo extends zombie.world.ItemInfo {
        MaterialInfo(zombie.scripting.objects.Item item,short id) {
            name=item.getName();moduleName=item.getModule().getName();fullType=item.getFullName();
            registryId=id;isLoaded=true;scriptItem=item;entityScript=item;modId="fixture-installed-source";
        }
    }
    private static final class MaterialDictionary extends zombie.world.DictionaryData {
        void register(zombie.scripting.objects.Item item,short id) {
            var info=new MaterialInfo(item,id);itemIdToInfoMap.put(id,info);itemTypeToInfoMap.put(info.getFullType(),info);
        }
    }
    private static InventoryItem material(Path file,String name,short id,MaterialDictionary dictionary)throws Exception {
        String text=ScriptParser.stripComments(Files.readString(file));
        var match=java.util.regex.Pattern.compile("\\bitem\\s+"+java.util.regex.Pattern.quote(name)+"\\s*\\{").matcher(text);
        if(!match.find())throw new AssertionError("Installed item missing "+name);
        int end=match.end(),depth=1;while(depth>0&&end<text.length()){char c=text.charAt(end++);if(c=='{')depth++;else if(c=='}')depth--;}
        if(depth!=0)throw new AssertionError("Unclosed installed item "+name);
        var module=ScriptManager.instance.moduleMap.get("Base");
        if(module==null){module=new ScriptModule();module.name="Base";ScriptManager.instance.moduleMap.put("Base",module);ScriptManager.instance.moduleList.add(module);}
        var definition=new zombie.scripting.objects.Item();definition.setModule(module);definition.setName(name);
        var mf=ScriptManager.class.getDeclaredField("currentLoadFileMod");mf.setAccessible(true);Object old=mf.get(null);mf.set(null,"fixture-installed-source");
        try{definition.setModID("fixture-installed-source");definition.InitLoadPP(name);
            // The qualified material loader omits an unsupported research-only
            // property. Item costs, literature knowledge and charge are intact.
            definition.Load(name,text.substring(match.start(),end).replaceAll("(?im)^\\s*Researchablerecipes\\s*=.*$", ""));
        }finally{mf.set(null,old);}
        definition.setRegistry_id(id);module.items.getScriptMap().put(name,definition);dictionary.register(definition,id);
        var bucketsField=ScriptManager.class.getDeclaredField("items");bucketsField.setAccessible(true);
        var buckets=(ScriptBucketCollection<zombie.scripting.objects.Item>)bucketsField.get(ScriptManager.instance);
        buckets.registerModule(module);buckets.getFullTypeToScriptMap().put(definition.getFullName(),definition);
        var value=InventoryItemFactory.CreateItem(definition.getFullName());
        if(value==null)throw new AssertionError("Native item creation failed "+definition.getFullName());
        value.setID(id);value.setName(name);return value;
    }
    private static int checks;
    private static void check(String name,boolean value){System.out.println("CHECK "+name+"="+value);checks++;}
    private static String block(Path file,String kind,String name)throws Exception{
        var source=Files.readString(file);var m=java.util.regex.Pattern.compile("\\b"+kind+"\\s+"+java.util.regex.Pattern.quote(name)+"\\s*\\{").matcher(source);
        if(!m.find())throw new IllegalStateException("missing installed "+name);int end=m.end(),depth=1;
        while(depth>0){char c=source.charAt(end++);if(c=='{')depth++;else if(c=='}')depth--;}
        return source.substring(m.start(),end);
    }
    private static void index(ScriptModule module)throws Exception{
        for(var field:ScriptManager.class.getDeclaredFields())if(ScriptBucketCollection.class.isAssignableFrom(field.getType())){
            field.setAccessible(true);var c=(ScriptBucketCollection)field.get(ScriptManager.instance);c.registerModule(module);
            var b=c.getBucketFromModule(module);for(var value:b.getScriptMap().values()){
                var s=(zombie.scripting.objects.BaseScriptObject)value;c.getFullTypeToScriptMap().put(s.getScriptObjectFullType(),s);
                if(!b.getScriptList().contains(s))b.getScriptList().add(s);if(!c.getAllScripts().contains(s))c.getAllScripts().add(s);
            }
        }
    }
    private static IsoPlayer actor()throws Exception{
        // Controlled world/clock/cosmetic setup adapts MovementCrossingProbe's
        // native boot. It creates no saved world and advances no physical actor.
        zombie.core.random.RandStandard.INSTANCE.init();zombie.ZomboidFileSystem.instance.init();
        zombie.SoundManager.instance=new zombie.DummySoundManager();
        zombie.Lua.LuaManager.platform=new se.krka.kahlua.j2se.J2SEPlatform();
        zombie.Lua.LuaManager.env=zombie.Lua.LuaManager.platform.newTable();
        zombie.Lua.LuaEventManager.register(zombie.Lua.LuaManager.platform,zombie.Lua.LuaManager.env);
        SurvivorDesc.HairCommonColors.add(new zombie.core.ImmutableColor(.2f,.3f,.4f));
        var styles=new zombie.core.skinnedmodel.population.HairStyles();zombie.core.skinnedmodel.population.HairStyles.instance=styles;
        zombie.core.skinnedmodel.population.BeardStyles.instance=new zombie.core.skinnedmodel.population.BeardStyles();
        var hair=new zombie.core.skinnedmodel.population.HairStyle();hair.name="fixture";styles.maleStyles.add(hair);styles.femaleStyles.add(hair);
        var beard=new zombie.core.skinnedmodel.population.BeardStyle();beard.name="fixture";zombie.core.skinnedmodel.population.BeardStyles.instance.styles.add(beard);
        zombie.GameTime.setInstance(new zombie.GameTime());zombie.GameTime.getInstance().updateCalendar(1993,0,1,12,0);
        PerkFactory.init();var cell=new IsoCell(1,1);zombie.iso.WorldReuserThread.instance.stop();IsoWorld.instance.currentCell=cell;
        var square=new IsoGridSquare(cell,null,10,20,0);square.getProperties().set(zombie.iso.SpriteDetails.IsoFlagType.solidfloor);
        var desc=new SurvivorDesc(false);desc.getHumanVisual().setSkinTextureName("fixture");
        var body=new IsoPlayer(cell,desc,10,20,0,false);body.setCurrentSquare(square);body.setMovingSquareNow();body.setX(10.5f);body.setY(20.5f);body.setZ(0);
        return body;
    }
    private record Policy(String name,String file,int skill,boolean learned,String magazine,String[] names,int[] amounts){}
    private static final List<Policy> POLICIES=List.of(
        new Policy("MetalWindowFrameLvl1","entity_metal_windowframelvl1",3,true,"MetalworkMag1",new String[]{"BlowTorch","SmallSheetMetal"},new int[]{4,3}),
        new Policy("MetalWindowFrameLvl2","entity_metal_windowframelvl2",5,true,"MetalworkMag1",new String[]{"BlowTorch","SmallSheetMetal"},new int[]{4,4}),
        new Policy("MetalFenceLvl1","entity_metal_fencelvl1",3,true,"MetalworkMag3",new String[]{"BlowTorch","MetalBar","WeldingRods"},new int[]{2,2,2}),
        new Policy("MetalFenceLvl2","entity_metal_fencelvl2",5,false,null,new String[]{"BlowTorch","MetalBar","WeldingRods"},new int[]{2,2,2}),
        new Policy("MetalSmallPoleFence","entity_metal_smallpolelfence",3,true,"MetalworkMag3",new String[]{"BlowTorch","MetalPipe","WeldingRods"},new int[]{2,3,2}),
        new Policy("MetalBigMetalFence","entity_metal_bigmetalfence",3,true,"MetalworkMag3",new String[]{"BlowTorch","MetalPipe","ScrapMetal","WeldingRods"},new int[]{5,5,2,5}),
        new Policy("MetalSmallWireFence","entity_metal_smallwirefence",3,true,"MetalworkMag3",new String[]{"BlowTorch","MetalPipe","ScrapMetal","Wire","WeldingRods"},new int[]{2,2,1,1,2}),
        new Policy("MetalBigWireFence","entity_metal_bigwirefence",3,true,"MetalworkMag3",new String[]{"BlowTorch","MetalPipe","ScrapMetal","Wire","WeldingRods"},new int[]{4,3,4,3,5}),
        new Policy("MetalPoleFenceGate","entity_metal_polefencegate",3,true,"MetalworkMag3",new String[]{"BlowTorch","MetalPipe","Hinge","ScrapMetal","WeldingRods"},new int[]{4,5,2,4,4}),
        new Policy("MetalPoleFenceGateSmall","entity_metal_polefencegatesmall",3,true,"MetalworkMag3",new String[]{"BlowTorch","MetalPipe","Hinge","ScrapMetal","WeldingRods"},new int[]{4,3,2,2,4}),
        new Policy("MetalWireFenceGate","entity_metal_wirefencegate",3,true,"MetalworkMag3",new String[]{"BlowTorch","MetalPipe","Hinge","ScrapMetal","WeldingRods"},new int[]{4,3,2,4,4}),
        new Policy("MetalWireFenceGateSmall","entity_metal_wirefencegatesmall",3,true,"MetalworkMag3",new String[]{"BlowTorch","MetalPipe","ScrapMetal","Wire","WeldingRods"},new int[]{2,2,1,1,2})
    );
    public static void main(String[] args)throws Exception{
        Thread.setDefaultUncaughtExceptionHandler((t,e)->{e.printStackTrace();System.exit(1);});
        var game=Path.of(args[0]);var body=actor();body.getInventory().getItems().clear();body.getKnownRecipes().clear();
        zombie.SandboxOptions.instance.seeNotLearntRecipe.setValue(true);
        var dictionary=new MaterialDictionary();var df=zombie.world.WorldDictionary.class.getDeclaredField("data");df.setAccessible(true);df.set(null,dictionary);
        short registry=2400;var items=new LinkedHashMap<String,InventoryItem>();
        for(String name:List.of("BlowTorch","SmallSheetMetal","MetalBar","MetalPipe","ScrapMetal","Wire","Hinge","WeldingRods","MetalworkMag1","MetalworkMag3")){
            String type=name.startsWith("MetalworkMag")?"literature":name.equals("BlowTorch")||name.equals("WeldingRods")||name.equals("Wire")?"drainable":name.equals("MetalBar")||name.equals("MetalPipe")?"weapon":"normal";
            items.put(name,material(game.resolve("media/scripts/generated/items/"+type+".txt"),name,registry++,dictionary));
        }
        zombie.entity.components.attributes.Attribute.init();var module=ScriptManager.instance.moduleMap.get("Base");index(module);
        var loadMod=ScriptManager.class.getDeclaredField("currentLoadFileMod");loadMod.setAccessible(true);loadMod.set(null,"pz-vanilla");
        for(String name:List.of("BuildWallMetal","BuildMetalStructureScrap","BuildPoleFence","BuildPoleFenceSmall","BuildWireFence")){
            var timed=new zombie.scripting.objects.TimedActionScript();timed.setModule(module);timed.InitLoadPP(name);
            timed.Load(name,block(game.resolve("media/scripts/generated/timedactions.txt"),"timedAction",name));module.timedActionScripts.getScriptMap().put(name,timed);
        }
        var entities=new LinkedHashMap<String,GameEntityScript>();
        for(var p:POLICIES){var entity=new GameEntityScript();entity.setModule(module);entity.setModID("pz-vanilla");entity.InitLoadPP(p.name());
            // UiConfig affects unattended UI loading, not recipe or sprite data.
            entity.Load(p.name(),block(game.resolve("media/scripts/generated/entities/walls/"+p.file()+".txt"),"entity",p.name()).replaceAll("(?s)component UiConfig\\s*\\{.*?\\}",""));
            module.entities.getScriptMap().put(p.name(),entity);entities.put(p.name(),entity);}
        index(module);for(var entity:entities.values())entity.OnScriptsLoaded(ScriptLoadMode.Init);index(module);
        zombie.inventory.ItemTags.Init(ScriptManager.instance.getAllItems());for(var entity:entities.values())entity.OnPostWorldDictionaryInit();
        var queue=zombie.Lua.LuaManager.platform.newTable();queue.rawset("queues",zombie.Lua.LuaManager.platform.newTable());zombie.Lua.LuaManager.env.rawset("ISTimedActionQueue",queue);
        for(var p:POLICIES){
            String prefix=p.name()+"_";var entity=entities.get(p.name());
            var recipe=((CraftRecipeComponentScript)entity.getComponentScriptFor(ComponentType.CraftRecipe)).getCraftRecipe();
            var sprite=(zombie.scripting.entity.components.spriteconfig.SpriteConfigScript)entity.getComponentScriptFor(ComponentType.SpriteConfig);
            check(prefix+"identity_time_knowledge",entity.getFullName().equals("Base."+p.name())&&recipe.getScriptObjectFullType().equals("Base."+p.name())&&recipe.getTime()==200&&recipe.needToBeLearn()==p.learned());
            body.setPerkLevelDebug(PerkFactory.Perks.MetalWelding,p.skill()-1);boolean below=recipe.characterHasRequiredSkills(body);
            body.setPerkLevelDebug(PerkFactory.Perks.MetalWelding,p.skill());check(prefix+"native_skill_boundary",!below&&recipe.characterHasRequiredSkills(body)&&recipe.getHighestSkillRequirement()==p.skill());
            var faceStorage=sprite.getClass().getDeclaredField("faces");faceStorage.setAccessible(true);int faceSlots=java.lang.reflect.Array.getLength(faceStorage.get(sprite));
            var faces=new HashSet<String>();boolean dimensions=true;for(int n=0;n<faceSlots;n++){var face=sprite.getFace(n);if(face!=null){faces.add(face.getFaceName());dimensions&=face.getTotalWidth()==1&&face.getTotalHeight()==1&&face.getZLayers()==1;System.out.println("FACE|"+p.name()+"|"+face.getFaceName()+"|"+face.getTotalWidth()+"|"+face.getTotalHeight()+"|"+face.getZLayers());}}
            boolean gate=p.name().contains("Gate");var expectedFaces=gate?Set.of("n","w","n_open","w_open"):Set.of("n","w");
            check(prefix+"complete_native_faces",dimensions&&faces.equals(expectedFaces)&&sprite.getDontNeedFrame()==gate);
            var stages=new HashSet<String>();for(var stage:sprite.getPreviousStages())stages.add(stage);
            var expectedStages=p.name().equals("MetalWindowFrameLvl1")?Set.of("WoodenWallFrame","MetalWallFrame"):p.name().equals("MetalWindowFrameLvl2")?Set.of("WoodenWallFrame","MetalWallFrame","MetalWindowFrameLvl1"):Set.<String>of();
            check(prefix+"exact_native_previous_stages",stages.equals(expectedStages));
            boolean exact=recipe.getInputs().size()==p.names().length;
            for(int n=0;n<recipe.getInputs().size();n++){var input=recipe.getInputs().get(n);boolean unrecorded=p.names()[n].equals("BlowTorch")||p.names()[n].equals("WeldingRods");
                exact&=input.getIntAmount()==p.amounts()[n]&&!input.isKeep()&&input.isRecordInput()==!unrecorded&&input.getPossibleInputItems().size()==1&&input.getPossibleInputItems().contains(items.get(p.names()[n]).getScriptItem());
                System.out.println("INPUT|"+p.name()+"|"+p.names()[n]+"|"+input.getIntAmount()+"|keep="+input.isKeep()+"|record="+input.isRecordInput()+"|apply="+input.getItemApplyMode());}
            check(prefix+"exact_native_inputs_keep_record",exact);
            body.getKnownRecipes().clear();body.getAlreadyReadBook().clear();boolean actual=body.isRecipeActuallyKnown(recipe),visible=CraftRecipeManager.hasPlayerLearnedRecipe(recipe,body);
            check(prefix+"actual_knowledge_independent_visibility",p.learned()?(!actual&&visible):visible);
            if(p.learned()){var book=(Literature)items.get(p.magazine());check(prefix+"magazine_teaches_exact_recipe",book.getLearnedRecipes().contains(p.name()));body.ReadLiterature(book);
                check(prefix+"native_read_acquires_recipe",body.isRecipeActuallyKnown(recipe)&&body.isRecipeActuallyKnown(p.name()));}
            else {check(prefix+"magazine_teaches_exact_recipe",!((Literature)items.get("MetalworkMag3")).getLearnedRecipes().contains(p.name()));check(prefix+"native_read_acquires_recipe",!recipe.needToBeLearn());}
            body.getInventory().getItems().clear();var allocatedItems=new ArrayList<List<InventoryItem>>();int nextId=2700;boolean allocated=true;
            for(int n=0;n<p.names().length;n++){var list=new ArrayList<InventoryItem>();var prototype=items.get(p.names()[n]);boolean drain=prototype instanceof DrainableComboItem;
                for(int k=0;k<(drain?1:p.amounts()[n]);k++){var item=InventoryItemFactory.CreateItem(prototype.getFullType());item.setID(nextId++);body.getInventory().AddItem(item);list.add(item);}allocatedItems.add(list);}
            var containers=new ArrayList<ItemContainer>();containers.add(body.getInventory());var logic=new BuildLogic(body,null,null);logic.setContainers(containers);logic.setRecipe(recipe);logic.setManualSelectInputs(true);logic.clearManualInputs();
            for(int n=0;n<p.names().length;n++)allocated&=logic.setManualInputsFor(recipe.getInputs().get(n),new ArrayList<>(allocatedItems.get(n)));
            check(prefix+"exact_native_allocation",allocated);logic.getPossibleCraftCount(true);logic.startCraftAction(null);check(prefix+"native_can_perform",logic.canPerformCurrentRecipe());
            int[] charges=new int[p.names().length];for(int n=0;n<charges.length;n++)charges[n]=allocatedItems.get(n).get(0).getCurrentUses();
            boolean performed=logic.performCurrentRecipe();check(prefix+"native_performed",performed);
            if(performed){var data=logic.getRecipeDataInProgress();data.luaCallOnCreate(body);data.processDestroyAndUsedItems(body);}
            boolean payment=performed;
            for(int n=0;n<p.names().length;n++)for(var item:allocatedItems.get(n)){boolean drain=item instanceof DrainableComboItem;
                payment&=drain?(body.getInventory().contains(item)&&item.getCurrentUses()==charges[n]-p.amounts()[n]):!body.getInventory().contains(item);
                System.out.println("PAYMENT|"+p.name()+"|"+item.getFullType()+"|before="+charges[n]+"|after="+item.getCurrentUses()+"|held="+body.getInventory().contains(item));}
            check(prefix+"exact_native_payment",payment);
            var empty=new BuildLogic(body,null,null);empty.setContainers(containers);empty.setRecipe(recipe);check(prefix+"paid_stock_cannot_pay_again",empty.getPossibleCraftCount(true)==0);
        }
        System.out.println("COMPLETE native metal enclosure prerequisite verdicts|checks="+checks+"|families="+POLICIES.size());System.exit(0);
    }
}
