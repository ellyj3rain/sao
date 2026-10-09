package com.sao.engine;

import java.lang.ref.WeakReference;
import java.security.MessageDigest;
import java.util.HexFormat;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.WeakHashMap;
import se.krka.kahlua.j2se.KahluaTableImpl;
import zombie.core.Translator;
import zombie.core.random.Rand;
import zombie.inventory.InventoryItem;
import zombie.network.GameClient;
import zombie.network.GameServer;
import zombie.network.ServerOptions;
import zombie.scripting.ScriptManager;
import zombie.scripting.entity.components.crafting.CraftRecipe;
import zombie.scripting.logic.RecipeCodeOnCreate;
import zombie.scripting.objects.ItemTag;

/** Native card/dice mechanics with actor-owned presentation instead of player-slot Halo text. */
public final class SAOTabletop {
    public static final String REVISION="a28157ee4cfe60d2117060bf016cb54462603279c54a069638ae0a0d1ae76adc";
    private static final Map<SAOIsoPlayerShell,LinkedHashMap<String,Result>> RESULTS=new WeakHashMap<>();
    private static Boolean sealed;
    private record Result(String actor,String token,String kind,WeakReference<InventoryItem> item,
        String cardKey,String display,int sides,int face) { }
    private SAOTabletop() { }
    public static void resetRuntimeForWorld() { RESULTS.clear(); }

    private static boolean sealed() {
        if (sealed!=null) return sealed;
        try (var stream=RecipeCodeOnCreate.class.getResourceAsStream("/zombie/scripting/logic/RecipeCodeOnCreate.class")) {
            sealed=stream!=null && REVISION.equals(HexFormat.of().formatHex(
                MessageDigest.getInstance("SHA-256").digest(stream.readAllBytes())));
        } catch (Exception error) { sealed=false; }
        return sealed;
    }
    private static boolean carried(SAOIsoPlayerShell body,InventoryItem item) {
        if (item==null) return false;
        for (var own:SAOPrivateInventory.carriedItems(body)) if (own==item) return true;
        return false;
    }
    private static int sides(InventoryItem item) {
        ItemTag[] tags={ItemTag.D4,ItemTag.D6,ItemTag.D8,ItemTag.D10,ItemTag.D12,ItemTag.D20,ItemTag.D00};
        int[] faces={4,6,8,10,12,20,100};
        for (int i=0;i<tags.length;i++) if (item.hasTag(tags[i])) return faces[i];
        return 0; // Original native callback's unrecognized-tag branch.
    }
    private static CraftRecipe recipe(SAOIsoPlayerShell body,InventoryItem item,String kind) {
        if (GameClient.client || GameServer.server || SAOConceptObservation.actor(body)==null
                || !carried(body,item) || !sealed()) return null;
        return scriptRecipe(item.getScriptItem(),kind);
    }
    private static CraftRecipe scriptRecipe(zombie.scripting.objects.Item item,String kind) {
        if (item==null || !sealed()) return null;
        boolean card="draw-card".equals(kind),dice="roll-dice".equals(kind);
        if (!card && !dice || card && !"Base.CardDeck".equals(item.getFullName())
                || dice && !item.hasTag(ItemTag.DICE)) return null;
        var recipe=ScriptManager.instance.getCraftRecipe(card?"Base.DrawRandomCard":"Base.RollOneDice");
        if (recipe==null || recipe.getTime()!=20 || recipe.getInputCount()!=1 || recipe.getOutputCount()!=0
                || recipe.getXPAwardCount()!=0 || recipe.isUsesTools() || recipe.getToolLeft()!=null
                || recipe.getToolRight()!=null || recipe.getToolBoth()!=null || recipe.getProp1()!=null || recipe.getProp2()!=null
                || recipe.hasOnTickInputs() || recipe.hasOnTickOutputs()
                || !recipe.getInputs().getFirst().isKeep()
                || !recipe.getInputs().getFirst().containsItem(item)
                || !(card?"RecipeCodeOnCreate.drawRandomCard":"RecipeCodeOnCreate.rollDice")
                    .equals(recipe.getLuaCallString(CraftRecipe.LuaCall.OnCreate))) return null;
        var action=recipe.getTimedActionScript();
        if (action==null || action.hasMuscleStrain() || !(card?"DrawCard":"RollDice").equals(action.getName())) return null;
        var input=recipe.getInputs().getFirst();
        if (input.getAmount()!=1 || input.isDestroy() || input.isTool() || input.isReplace()
                || input.hasCreateToItem() || input.hasConsumeFromItem() || input.isApplyOnTick()) return null;
        for (var callback:CraftRecipe.LuaCall.values())
            if (callback!=CraftRecipe.LuaCall.OnCreate && recipe.hasLuaCall(callback)) return null;
        return recipe;
    }
    private static KahluaTableImpl table() { return new KahluaTableImpl(new java.util.HashMap<>()); }
    /** A type requirement describes a native recipe; it conveys no item custody or condition. */
    static KahluaTableImpl requirements(String fullType) {
        var rows=table();
        if (GameClient.client || GameServer.server || fullType==null || fullType.length()>160) return rows;
        var item=ScriptManager.instance.getItem(fullType);
        int count=0;
        for (String kind:new String[]{"draw-card","roll-dice"}) {
            var recipe=scriptRecipe(item,kind);
            if (recipe==null) continue;
            var row=table();row.rawset("owner","SAO.LeisureGames");row.rawset("family","games");
            row.rawset("activity",kind);row.rawset("sourceId","draw-card".equals(kind)
                ?"native:RecipeCodeOnCreate.drawRandomCard":"native:RecipeCodeOnCreate.rollDice");
            row.rawset("revision",REVISION);row.rawset("requirementId","Base."+recipe.getName()+":input:1");
            row.rawset("role","playable-item");row.rawset("itemType",fullType);
            rows.rawset((double)++count,row);
        }
        return rows;
    }
    public static Object affordance(SAOIsoPlayerShell body,InventoryItem item,String kind) {
        try {
            var recipe=recipe(body,item,kind);if (recipe==null) return null;
            var action=recipe.getTimedActionScript();var row=table();
            row.rawset("schema","sao.native-tabletop-affordance/1");row.rawset("actorId",SAOConceptObservation.actor(body));
            row.rawset("kind",kind);row.rawset("revision",REVISION);
            row.rawset("sourceId","draw-card".equals(kind)?"native:RecipeCodeOnCreate.drawRandomCard":"native:RecipeCodeOnCreate.rollDice");
            row.rawset("itemId",(double)item.getID());row.rawset("itemType",item.getFullType());
            row.rawset("time",(double)recipe.getTime(body));row.rawset("actionAnim",action.getActionAnim());
            row.rawset("recipeName",recipe.getName());row.rawset("translationName",recipe.getTranslationName());
            row.rawset("canWalk",recipe.isCanWalk());row.rawset("prop1",action.getProp1());row.rawset("prop2",action.getProp2());
            row.rawset("hasMuscleStrain",action.hasMuscleStrain());
            row.rawset("animVarKey",action.getAnimVarKey());row.rawset("animVarVal",action.getAnimVarVal());
            row.rawset("cantSit",action.isCantSit());row.rawset("metabolics",action.getMetabolics());
            row.rawset("sound",action.getSound());row.rawset("soundTime",action.getSoundTime()==null?null:action.getSoundTime().name());
            row.rawset("completionSound",action.getCompletionSound());row.rawset("sides",(double)sides(item));
            return row;
        } catch (Exception error) { return null; }
    }
    /** The Lua timed owner invokes this only at its authenticated source completion. */
    public static Object complete(SAOIsoPlayerShell body,InventoryItem item,String kind,String workId) {
        try {
            if (workId==null || workId.isBlank() || workId.length()>160 || recipe(body,item,kind)==null) return null;
            String actor=SAOConceptObservation.actor(body);
            Object rawToken=body.getModData().rawget("SAOExternalToken");
            String token=rawToken==null?null:rawToken instanceof String value?value:null;
            if (rawToken!=null && token==null) return null;
            var rows=RESULTS.computeIfAbsent(body,key->new LinkedHashMap<>());
            var result=rows.get(workId);boolean fresh=result==null;
            if (result!=null && (!actor.equals(result.actor()) || !java.util.Objects.equals(token,result.token())
                    || !kind.equals(result.kind()) || result.item().get()!=item)) return null;
            if (fresh) {
                String cardKey="draw-card".equals(kind)?ServerOptions.getRandomCard():null;
                int sides="roll-dice".equals(kind)?sides(item):0;
                int face=sides>0?Rand.NextInclusive(1,sides):0;
                String display=cardKey==null?String.valueOf(face):Translator.getText(cardKey);
                result=new Result(actor,token,kind,new WeakReference<>(item),cardKey,display,sides,face);
                if (rows.size()>=32) rows.remove(rows.keySet().iterator().next());
                rows.put(workId,result);
            }
            var row=table();row.rawset("schema","sao.native-tabletop-result/1");row.rawset("actorId",actor);
            row.rawset("workId",workId);row.rawset("kind",kind);row.rawset("revision",REVISION);
            row.rawset("itemId",(double)item.getID());row.rawset("itemType",item.getFullType());row.rawset("fresh",fresh);
            row.rawset("cardKey",result.cardKey());row.rawset("display",result.display());
            row.rawset("sides",(double)result.sides());row.rawset("face",(double)result.face());
            row.rawset("presentationOwner","person-private native result; no player-slot Halo write");
            return row;
        } catch (Exception error) { return null; }
    }
}
