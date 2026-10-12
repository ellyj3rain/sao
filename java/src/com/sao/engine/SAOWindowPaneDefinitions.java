package com.sao.engine;

import java.lang.reflect.Field;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import zombie.ZomboidFileSystem;
import zombie.scripting.ScriptBucketCollection;
import zombie.scripting.ScriptLoadMode;
import zombie.scripting.ScriptManager;
import zombie.scripting.objects.Item;
import zombie.scripting.objects.ItemType;
import zombie.scripting.objects.ScriptModule;
import zombie.scripting.entity.components.crafting.CraftRecipe;
import zombie.world.WorldDictionary;

/** Original startup definitions from inspected native/material data facts.
 * No foreign script object, dictionary ID, saved item or runtime is rewritten.
 * RepairableWindows42.13 (albion2.1.0) supplies attributed scale/legacy names;
 * engine GlassPane/GlassPanel/MoldGlass assets remain native references. */
public final class SAOWindowPaneDefinitions {
    public static final String MOD="SurvivorAwareness";
    private static final Map<String,String> status=new LinkedHashMap<>();
    private static String failure;
    private SAOWindowPaneDefinitions() { }
    record Material(String name,float weight,String icon,String model) {
        String full(){return "RepairableWindows."+name;}
        String body(){return "item "+name+" { ItemType = base:normal, DisplayCategory = Material, DisplayName = "+
            (name.equals("LargeGlassPane")?"Large glass pane":name.equals("ClayLargeSheetMoldUnfired")?"Unfired large sheet mold":"Large sheet mold")+", Weight = "+weight
            +", Icon = "+icon+", StaticModel = "+model+", WorldStaticModel = "+model
            +(name.equals("LargeGlassPane")?", Tags = base:glass":"")+", }";}
        boolean equal(Item item){return item!=null&&item.isItemType(ItemType.NORMAL)&&Math.abs(item.getActualWeight()-weight)<.00001f
            && "Material".equals(item.getDisplayCategory())&&icon.equals(item.getIcon())&&model.equals(item.getStaticModel())&&model.equals(item.getWorldStaticModel())
            &&(!name.equals("LargeGlassPane")||item.hasTag(zombie.scripting.objects.ItemTag.GLASS));}
    }
    private static final List<Material> MATERIALS=List.of(
        new Material("LargeGlassPane",.8f,"GlassPane","GlassPanel"),
        new Material("ClayLargeSheetMoldUnfired",.3f,"ClayMold_GlassPane_Unfired","MoldGlass_Unfired"),
        new Material("ClayLargeSheetMold",.3f,"ClayMold_GlassPane_Fired","MoldGlass_Fired"));
    record Supply(String name,int time,String category,String tags,boolean learned,String meta,int xp,
                  List<String> inputs,String output) {
        String full(){return "Base."+name;}
        String body(){return "craftRecipe "+name+" { time = "+time+", category = "+category+", Tags = "+tags+","+
            (name.equals("MakeLargeSheetMold")?" timedAction = Craft_PotteryBench,":name.equals("FireClayLargeSheetMold")?" timedAction = Making_With_Kiln,":"")+
            (learned?" NeedToBeLearn = true, metaRecipe = "+meta+",":"")+
            (xp>0?" xpAward = "+category+":"+xp+",":"")+
            " inputs { "+String.join(", ",inputs)+", } outputs { "+output+", } }";}
        boolean equal(CraftRecipe recipe){
            if(recipe.getTime()!=time||recipe.needToBeLearn()!=learned||!category.equals(recipe.getCategory())
                ||!java.util.Objects.equals(empty(recipe.getMetaRecipe()),empty(meta))
                ||recipe.getInputCount()!=inputs.size()||recipe.getOutputCount()!=1
                ||!new java.util.HashSet<>(recipe.getTags()).equals(new java.util.HashSet<>(List.of(tags.split(";")))))return false;
            String timed=name.equals("MakeLargeSheetMold")?"Craft_PotteryBench":name.equals("FireClayLargeSheetMold")?"Making_With_Kiln":"";
            try{
                Field source=CraftRecipe.class.getDeclaredField("loadedTimedActionScript");source.setAccessible(true);
                if(!empty(timed).equals(empty((String)source.get(recipe))))return false;
            }catch(ReflectiveOperationException error){return false;}
            if(recipe.getXPAwardCount()!=(xp>0?1:0)||xp>0&&(recipe.getXPAward(0).getAmount()!=xp||!category.equals(recipe.getXPAward(0).getPerk().getId())))return false;
            for(int i=0;i<inputs.size();i++)if(!normal(inputs.get(i)).equals(normal(recipe.getInputs().get(i).getOriginalLine())))return false;
            return normal(output).equals(normal(recipe.getOutputs().get(0).getOriginalLine()));
        }
    }
    private static String normal(String value){return value==null?"":value.replaceAll("\\s+","").replaceAll(",+$","");}
    private static String empty(String value){return value==null||value.isEmpty()?"":value;}
    private static final List<Supply> SUPPLY=List.of(
        new Supply("MakeLargeSheetMold",100,"Pottery","PotteryBench",false,"",15,
            List.of("item 12 [Base.Clay]","item 1 tags[base:claytool] mode:keep"),"item 1 RepairableWindows.ClayLargeSheetMoldUnfired"),
        new Supply("FireClayLargeSheetMold",20,"Pottery","KilnSmall;KilnLarge",false,"",0,
            List.of("item 1 [RepairableWindows.ClayLargeSheetMoldUnfired]","item 1 tags[base:startfire]","item 1 tags[base:log;base:charcoal]"),"item 1 RepairableWindows.ClayLargeSheetMold"),
        new Supply("MakeLargeGlassPane",120,"Glassmaking","AnySurfaceCraft;Glassmaking",true,"MakeGlassPanel",25,
            List.of("item 1 [RepairableWindows.ClayLargeSheetMold] mode:keep","item 4 [Base.CeramicCrucibleWithGlass]"),"item 1 RepairableWindows.LargeGlassPane"));
    @SuppressWarnings("unchecked")
    private static <T extends zombie.scripting.objects.BaseScriptObject> ScriptBucketCollection<T> collection(String field)throws Exception{
        Field found=ScriptManager.class.getDeclaredField(field);found.setAccessible(true);
        return (ScriptBucketCollection<T>)found.get(ScriptManager.instance);
    }
    private static ScriptModule module(String name)throws Exception{
        ScriptManager sm=ScriptManager.instance;ScriptModule found=sm.moduleMap.get(name);
        if(found!=null)return found;
        ScriptModule created=new ScriptModule();created.name=name;if(!name.equals("Base"))created.imports.add("Base");
        sm.moduleMap.put(name,created);sm.moduleList.add(created);
        // Use native collection registration; the new module is never a
        // replacement for an existing module or its foreign bucket objects.
        for(Field field:ScriptManager.class.getDeclaredFields())if(ScriptBucketCollection.class.isAssignableFrom(field.getType())){
            field.setAccessible(true);((ScriptBucketCollection<?>)field.get(sm)).registerModule(created);
        }
        return created;
    }
    private static ScriptModule stage(String name){ScriptModule staged=new ScriptModule();staged.name=name;
        if(!name.equals("Base"))staged.imports.add("Base");return staged;}
    public static synchronized void beforeScriptsLoaded(){
        if(!ZomboidFileSystem.instance.getModIDs().contains(MOD))return;
        if(!WorldDictionary.isAllowScriptItemLoading()){failure="outside-native-script-loading";return;}
        ScriptManager sm=ScriptManager.instance;
        try{
            // Native Load stores source attribution through these context
            // fields. Restore all of them after this narrow owned load.
            Field mod=ScriptManager.class.getDeclaredField("currentLoadFileMod"),
                path=ScriptManager.class.getDeclaredField("currentLoadFileAbsPath"),
                name=ScriptManager.class.getDeclaredField("currentLoadFileName");
            for(Field f:List.of(mod,path,name))f.setAccessible(true);
            Object oldMod=mod.get(null),oldPath=path.get(null),oldName=name.get(null);
            try{
                mod.set(null,MOD);path.set(null,"SAO:original-window-pane-definitions");name.set(null,"SAO_window_pane_definitions");
                module("RepairableWindows");module("Base");
                var materialStage=stage("RepairableWindows");var missing=new ArrayList<Material>();
                for(Material spec:MATERIALS){Item existing=sm.getItem(spec.full());
                    if(existing!=null){status.put(spec.full(),spec.equal(existing)?"kept-equal":"kept-conflicting");continue;}
                    if(!materialStage.items.CreateFromTokenPP(ScriptLoadMode.Init,"item",spec.body()))throw new IllegalStateException("material-parse:"+spec.full());
                    missing.add(spec);
                }
                if(!missing.isEmpty()){
                    materialStage.items.LoadScripts(ScriptLoadMode.Init);
                    ScriptModule target=module("RepairableWindows");var items=SAOWindowPaneDefinitions.<Item>collection("items");
                    for(Material spec:missing){Item created=materialStage.getItem(spec.name());
                        if(created==null||!spec.equal(created))throw new IllegalStateException("material-qualification:"+spec.full());
                        created.setModule(target);target.items.getScriptMap().put(spec.name(),created);target.items.getScriptList().add(created);
                        items.getFullTypeToScriptMap().put(spec.full(),created);
                        if(!sm.getAllItems().contains(created))sm.getAllItems().add(created);
                        status.put(spec.full(),"owned-registered");
                    }
                }
                boolean compatible=MATERIALS.stream().allMatch(spec->spec.equal(sm.getItem(spec.full())));
                var recipeStage=stage("Base");var recipes=new ArrayList<Supply>();
                for(Supply spec:SUPPLY){CraftRecipe existing=sm.getCraftRecipe(spec.full());
                    if(existing!=null){status.put(spec.full(),spec.equal(existing)?"kept-equal":"kept-conflicting");continue;}
                    if(!compatible){status.put(spec.full(),"held-material-conflict");continue;}
                    if(!recipeStage.craftRecipes.CreateFromTokenPP(ScriptLoadMode.Init,"craftRecipe",spec.body()))throw new IllegalStateException("recipe-parse:"+spec.full());
                    recipes.add(spec);
                }
                if(!recipes.isEmpty()){
                    recipeStage.craftRecipes.LoadScripts(ScriptLoadMode.Init);
                    ScriptModule target=module("Base");var craft=SAOWindowPaneDefinitions.<CraftRecipe>collection("craftRecipes");
                    for(Supply spec:recipes){CraftRecipe created=recipeStage.getCraftRecipe(spec.name());
                        if(created==null||!spec.equal(created))throw new IllegalStateException("recipe-qualification:"+spec.full());
                        created.setModule(target);target.craftRecipes.getScriptMap().put(spec.name(),created);target.craftRecipes.getScriptList().add(created);
                        craft.getFullTypeToScriptMap().put(spec.full(),created);
                        if(!sm.getAllCraftRecipes().contains(created))sm.getAllCraftRecipes().add(created);
                        created.OnScriptsLoaded(ScriptLoadMode.Init);status.put(spec.full(),"owned-registered");
                    }
                }
            }finally{mod.set(null,oldMod);path.set(null,oldPath);name.set(null,oldName);}
        }catch(Throwable error){failure=String.valueOf(error);}
    }
    public static synchronized String status(){return "window-pane-definition/1|"+String.valueOf(failure)+"|"+status;}
}
