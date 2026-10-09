import java.nio.file.*;
import java.util.*;
import java.util.regex.*;
import se.krka.kahlua.vm.*;
import zombie.Lua.LuaManager;
import zombie.characters.IsoGameCharacter;
import zombie.inventory.InventoryItem;
import zombie.scripting.ScriptManager;
import zombie.scripting.ScriptLoadMode;
import zombie.scripting.entity.components.crafting.CraftRecipe;

/** Native initialization and controlled callback scheduling in a private process. */
final class TabletopFixture {
 static final class CountingRandom extends Random {
  int calls; CountingRandom(long seed){super(seed);}
  protected int next(int bits){calls++;return super.next(bits);}
 }
 static CountingRandom random;
 static final Map<String,InventoryItem> items=new LinkedHashMap<>();
 static String block(String text,String type,String name){
  text=zombie.scripting.ScriptParser.stripComments(text);
  var m=Pattern.compile("\\b"+type+"\\s+"+name+"\\s*\\{").matcher(text);
  if(!m.find())throw new AssertionError(name);int end=m.end(),depth=1;
  while(depth>0){char c=text.charAt(end++);if(c=='{')depth++;else if(c=='}')depth--;}
  return text.substring(m.start(),end);
 }
 static void seed(long seed){
  try{random=new CountingRandom(seed);var f=zombie.core.random.RandAbstract.class.getDeclaredField("rand");f.setAccessible(true);f.set(zombie.core.random.RandStandard.INSTANCE,random);}
  catch(Exception e){throw new IllegalStateException(e);}
 }
 static String halo(){
  try{String text="";for(String name:new String[]{"queuedLines","currentLines"}){var f=zombie.characters.HaloTextHelper.class.getDeclaredField(name);f.setAccessible(true);text+=Arrays.deepToString((Object[])f.get(null));}return text;}
  catch(Exception e){throw new IllegalStateException(e);}
 }
 static void install(KahluaTable env,LuaManager.Exposer exposer,IsoGameCharacter body,IsoGameCharacter other,Path game)throws Exception {
  for(var type:new Class<?>[]{zombie.characters.BodyDamage.Metabolics.class,zombie.scripting.objects.CharacterTrait.class,zombie.characters.CharacterActionAnims.class,zombie.scripting.objects.TimedActionScript.class,CraftRecipe.class}){
   exposer.setExposed(type);exposer.exposeLikeJava(type,env);
  }
  var dc=Class.forName("CognitionUseProbe$Dictionary");var ctor=dc.getDeclaredConstructor();ctor.setAccessible(true);
  var dictionary=ctor.newInstance();var field=zombie.world.WorldDictionary.class.getDeclaredField("data");field.setAccessible(true);field.set(null,dictionary);
  var make=CognitionUseProbe.class.getDeclaredMethod("item",Path.class,zombie.scripting.objects.ScriptModule.class,dc,String.class,String.class,short.class);make.setAccessible(true);
  var base=ScriptManager.instance.getModule("Base");
  short id=3300;var table=LuaManager.platform.newTable();
  for(String name:new String[]{"CardDeck","Dice","Dice_Bone","Dice_Wood","Dice_4","Dice_6","Dice_8","Dice_10","Dice_12","Dice_20","Dice_00","ChessWhite","CheckerBoard"}){
   var item=(InventoryItem)make.invoke(null,game,base,dictionary,"normal.txt",name,id++);
   items.put(name,item);table.rawset(name,item);base.items.getScriptList().add(item.getScriptItem());
  }
  env.rawset("__items",table);
  env.rawset("__nativeRecipe",(JavaFunction)(f,n)->f.push(ScriptManager.instance.getCraftRecipe("draw-card".equals(f.get(0))?"Base.DrawRandomCard":"Base.RollOneDice")));
  env.rawset("__sourceItems",(JavaFunction)(f,n)->{var rows=new ArrayList<InventoryItem>();rows.add((InventoryItem)f.get(0));return f.push(rows);});
  var bucketField=ScriptManager.class.getDeclaredField("items");bucketField.setAccessible(true);
  var bucket=(zombie.scripting.ScriptBucketCollection<?>)bucketField.get(ScriptManager.instance);
  var modulesField=zombie.scripting.ScriptBucketCollection.class.getDeclaredField("scriptModules");modulesField.setAccessible(true);
  if(!((List<?>)modulesField.get(bucket)).contains(base))bucket.registerModule(base);
  // Bootstrap loads item definitions incrementally; rebuild the native caches
  // after all real definitions exist, as full ScriptManager loading does.
  ScriptManager.instance.getAllItems().clear();
  var tagCache=ScriptManager.class.getDeclaredField("tagToItemMap");tagCache.setAccessible(true);((Map<?,?>)tagCache.get(ScriptManager.instance)).clear();
  zombie.inventory.ItemTags.Init(ScriptManager.instance.getAllItems());
  String timed=Files.readString(game.resolve("media/scripts/generated/timedactions.txt"));
  for(String name:new String[]{"DrawCard","RollDice"}){
   var d=new zombie.scripting.objects.TimedActionScript();d.setModule(base);d.InitLoadPP(name);d.Load(name,block(timed,"timedAction",name));d.OnScriptsLoaded(ScriptLoadMode.Init);
   base.timedActionScripts.getScriptMap().put(name,d);base.timedActionScripts.getScriptList().add(d);
  }
  String recipes=Files.readString(game.resolve("media/scripts/generated/recipes/recipes_cardsAndDice.txt"));
  var currentMod=ScriptManager.class.getDeclaredField("currentLoadFileMod");currentMod.setAccessible(true);currentMod.set(null,"pz-vanilla");
  for(String name:new String[]{"DrawRandomCard","RollOneDice"}){
   var r=new CraftRecipe();r.setModule(base);r.InitLoadPP(name);r.Load(name,block(recipes,"craftRecipe",name));r.OnScriptsLoaded(ScriptLoadMode.Init);r.OnPostWorldDictionaryInit();
   base.craftRecipes.getScriptMap().put(name,r);base.craftRecipes.getScriptList().add(r);
   System.out.println("RECIPE "+name+" inputs="+r.getInputCount()+" outputs="+r.getOutputCount()+" time="+r.getTime());
  }
  seed(177);String baselineHalo=halo();
  env.rawset("__seed",(JavaFunction)(f,n)->{seed(((Double)f.get(0)).longValue());return 0;});
  env.rawset("__rngCalls",(JavaFunction)(f,n)->f.push((double)random.calls));
  env.rawset("__haloUnchanged",(JavaFunction)(f,n)->f.push(halo().equals(baselineHalo)));
  env.rawset("__sourceExpected",(JavaFunction)(f,n)->{
   String kind=(String)f.get(0);InventoryItem item=(InventoryItem)f.get(1);
   if(kind.equals("draw-card")){String key=zombie.network.ServerOptions.getRandomCard();return f.push(key);}
   int sides=0;var tags=new zombie.scripting.objects.ItemTag[]{zombie.scripting.objects.ItemTag.D4,zombie.scripting.objects.ItemTag.D6,zombie.scripting.objects.ItemTag.D8,zombie.scripting.objects.ItemTag.D10,zombie.scripting.objects.ItemTag.D12,zombie.scripting.objects.ItemTag.D20,zombie.scripting.objects.ItemTag.D00};
   int[] counts={4,6,8,10,12,20,100};for(int k=0;k<tags.length;k++)if(item.hasTag(tags[k])){sides=counts[k];break;}
   return f.push((double)(sides>0?zombie.core.random.Rand.NextInclusive(1,sides):0));
  });
  env.rawset("__queueNative",(JavaFunction)(f,n)->{
   var tableAction=(KahluaTable)f.get(0);var nativeAction=new zombie.characters.CharacterTimedActions.LuaTimedActionNew(tableAction,body);
   tableAction.rawset("action",nativeAction);body.StartAction(nativeAction);return f.push(true);
  });
  env.rawset("__nativeAction",(JavaFunction)(f,n)->{
   var a=(zombie.characters.CharacterTimedActions.LuaTimedActionNew)f.get(0);String op=(String)f.get(1);
   if(op.equals("start"))a.start();else if(op.equals("progress")){a.setJobDelta(((Double)f.get(2)).floatValue());a.update();}else if(op.equals("delta-only"))a.setJobDelta(((Double)f.get(2)).floatValue());
   else if(op.equals("perform"))a.perform();else if(op.equals("complete"))a.complete();else if(op.equals("stop"))a.stop();else throw new AssertionError(op);return 0;
  });
  env.rawset("__clearInventory",(JavaFunction)(f,n)->{body.getInventory().getItems().clear();other.getInventory().getItems().clear();body.getCharacterActions().clear();return 0;});
  env.rawset("__foreignNative",(JavaFunction)(f,n)->f.push(new zombie.characters.CharacterTimedActions.LuaTimedActionNew((KahluaTable)f.get(0),other)));
  env.rawset("__recipeTime",(JavaFunction)(f,n)->{
   try{var r=ScriptManager.instance.getCraftRecipe("Base.DrawRandomCard");var t=CraftRecipe.class.getDeclaredField("time");t.setAccessible(true);t.setInt(r,((Double)f.get(0)).intValue());return 0;}
   catch(Exception e){throw new IllegalStateException(e);}
  });
  env.rawset("__recipeOverride",(JavaFunction)(f,n)->{
   try{
    String kind=(String)f.get(0);boolean on=Boolean.TRUE.equals(f.get(1));
    var r=ScriptManager.instance.getCraftRecipe("Base.DrawRandomCard");var input=r.getInputs().get(0);
    if(kind.equals("xp")){r.xpAward=on?new ArrayList<>():null;if(on)r.xpAward.add(new CraftRecipe.XpAward(zombie.characters.skills.PerkFactory.Perks.Fitness,1));}
    else if(kind.equals("prop"))r.setProp1(on?input:null);
    else if(kind.equals("tool")){var fld=CraftRecipe.class.getDeclaredField("toolLeft");fld.setAccessible(true);fld.set(r,on?input:null);}
    else if(kind.equals("callback")){var fld=CraftRecipe.class.getDeclaredField("luaCalls");fld.setAccessible(true);var calls=(Map)fld.get(r);if(on)calls.put(CraftRecipe.LuaCall.OnStart,"Unadapted.OnStart");else calls.remove(CraftRecipe.LuaCall.OnStart);}
    else if(kind.equals("input")){var fld=zombie.scripting.entity.components.crafting.InputScript.class.getDeclaredField("itemScriptCache");fld.setAccessible(true);var rows=(List)fld.get(input);rows.clear();rows.add(items.get(on?"ChessWhite":"CardDeck").getScriptItem());}
    else {String name=kind.equals("tick")?"applyOnTick":kind.equals("amount")?"amount":"consumeFromItemScript";var fld=zombie.scripting.entity.components.crafting.InputScript.class.getDeclaredField(name);fld.setAccessible(true);
     if(kind.equals("tick"))fld.setBoolean(input,on);else if(kind.equals("amount"))fld.setFloat(input,on?2:1);else fld.set(input,on?input:null);}
    return 0;
   }catch(Exception e){throw new IllegalStateException(e);}
  });
  env.rawset("__logicModels",(JavaFunction)(f,n)->{
   var item=(InventoryItem)f.get(0);String kind=(String)f.get(1);var r=ScriptManager.instance.getCraftRecipe(kind.equals("draw-card")?"Base.DrawRandomCard":"Base.RollOneDice");
   var logic=new zombie.entity.components.crafting.recipe.HandcraftLogic(body,null,null);var c=new ArrayList<zombie.inventory.ItemContainer>();c.add(body.getInventory());logic.setContainers(c);logic.setRecipe(r);
   logic.setManualSelectInputs(true);logic.clearManualInputs();var selected=new ArrayList<InventoryItem>();selected.add(item);logic.setManualInputsFor(r.getInputs().get(0),selected);logic.canPerformCurrentRecipe();
   var row=LuaManager.platform.newTable();row.rawset("one",logic.getModelHandOne());row.rawset("two",logic.getModelHandTwo());return f.push(row);
  });
 }
}
