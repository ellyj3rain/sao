package com.sao.engine;

import com.sao.agent.SAOAgent;
import com.sao.agent.SAOLootDensityWeave;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;
import java.util.WeakHashMap;
import zombie.characters.CharacterStat;
import zombie.characters.IsoPlayer;
import zombie.core.Core;
import zombie.entity.components.fluids.Fluid;
import zombie.entity.components.fluids.FluidContainer;
import zombie.inventory.InventoryItem;
import zombie.inventory.ItemContainer;
import zombie.inventory.ItemPickerJava;
import zombie.inventory.types.InventoryContainer;
import zombie.iso.BuildingDef;
import zombie.iso.IsoCell;
import zombie.iso.IsoChunk;
import zombie.iso.IsoChunkMap;
import zombie.iso.IsoGridSquare;
import zombie.iso.IsoObject;
import zombie.iso.IsoWorld;
import zombie.iso.WorldStreamer;
import zombie.iso.objects.IsoWorldInventoryObject;
import zombie.iso.objects.IsoThumpable;
import zombie.iso.objects.IsoGenerator;
import zombie.network.GameClient;
import zombie.network.GameServer;
import zombie.vehicles.BaseVehicle;
import zombie.vehicles.VehiclePart;

/**
 * R10a's native ground transaction.
 *
 * A meta-grid building says where a source may exist. This class is the first
 * place that answers what exists: it loads one real PZ chunk under the normal
 * chunk lifecycle, asks ItemPickerJava to populate unexplored containers,
 * records exact native identities and contents, synchronously saves, and then
 * removes an off-screen chunk from the live world. Loaded chunks are observed
 * in place. It never creates an SAO inventory or rolls a distribution itself.
 *
 * The text protocol deliberately contains observations only. Durable state,
 * reservations, private knowledge, and result ownership live in Lua ModData.
 */
public final class SAOWorldSources {
    private static final String PROTOCOL = "SAOWS1";
    private static final String SOURCE_TOKEN = "SAOWorldSourceId";
    private static final String ITEM_TOKEN = "SAOWorldItemSourceId";
    private static final int MAX_SOURCES_PER_CHUNK = 2048;
    private static final int MAX_ITEMS_PER_SOURCE = 2048;
    private static final int MAX_CONTAINER_DEPTH = 16;
    private static final int MAX_INSPECTION_OPTIONS = 128;
    private static final int INSPECTION_RANGE = 14;
    private static final int CHUNK_SIZE = IsoChunkMap.CHUNK_SIZE_IN_SQUARES;
    private static final ThreadLocal<Integer> HYDRATION_DEPTH =
        ThreadLocal.withInitial(() -> 0);
    private static final Map<IsoPlayer, ActionBinding> ACTIONS =
        new WeakHashMap<>();
    private static final Map<IsoPlayer, Map<String, InspectionBinding>> INSPECTIONS =
        new WeakHashMap<>();
    private static final Map<IsoPlayer, se.krka.kahlua.vm.KahluaTable> INSPECTION_MEMORY =
        new WeakHashMap<>();
    private static final Map<IsoPlayer, LinkedHashMap<String, CollectorSiteBinding>> COLLECTOR_SITES =
        new WeakHashMap<>();
    private static final Map<IsoPlayer, Map<String, UtilityBinding>> UTILITY_BINDINGS = new WeakHashMap<>();
    private static boolean transactionActive;

    // Read-only native recipe observations; durable demand and acquisition live in Lua.
    private static final Map<IsoPlayer, Map<String, RecipeWorkplaceBinding>> RECIPE_WORKPLACES = new WeakHashMap<>();

    private static se.krka.kahlua.vm.KahluaTable recipeTable() {
        return zombie.Lua.LuaManager.platform.newTable();
    }

    private static String recipeActor(SAOIsoPlayerShell body) {
        String actor = SAOConceptObservation.actor(body);
        var sao = table(zombie.Lua.LuaManager.env.rawget("SAO"));
        var bodies = sao == null ? null : table(sao.rawget("Body"));
        var active = bodies == null ? null : table(bodies.rawget("active"));
        var recordsRoot=zombie.world.moddata.GlobalModData.instance.get("SurvivorAwareness_Records");
        var records=recordsRoot==null ? null : table(recordsRoot.rawget("records"));
        var record=records==null || actor==null ? null : table(records.rawget(actor));
        return actor != null && active != null && active.rawget(actor) == body && record!=null
            && actor.equals(record.rawget("id")) && !Boolean.TRUE.equals(record.rawget("dead")) ? actor : null;
    }

// Native physical operations. The retained Lua NetworkWork capsule owns
    // private knowledge, permission, exact payment and once-only execution.
    private static boolean networkActor(IsoPlayer body) {
        return !GameClient.client && !GameServer.server && body != null
            && !body.isDead() && !body.isAsleep() && body.getCell() == IsoWorld.instance.currentCell
            && body.getCurrentSquare() != null && body.isExistInTheWorld()
            && (body instanceof SAOIsoPlayerShell shell ? recipeActor(shell) != null : body.isLocalPlayer());
    }
    private static String networkType(String kind) {
        return switch (kind == null ? "" : kind) {
            case "floor", "riser" -> "Base.MetalPipe";
            case "valve" -> "SAO.WaterValve";
            case "pump" -> "SAO.WaterPump";
            default -> null;
        };
    }
    private static boolean networkLoaded(IsoPlayer body, IsoGridSquare q) {
        return q != null && q.getCell() == body.getCell()
            && body.getCell().getGridSquare(q.getX(), q.getY(), q.getZ()) == q;
    }
    public static synchronized Object networkSite(IsoPlayer body, String kind, String axis, int x, int y, int z) {
        try {
            if (!networkActor(body) || networkType(kind) == null || !("x".equals(axis) || "y".equals(axis))
                || Math.floor(body.getZ()) != z || Math.hypot(body.getX()-x-.5, body.getY()-y-.5)>1.8) return null;
            IsoGridSquare q=body.getCell().getGridSquare(x,y,z);
            boolean vertical="riser".equals(kind);
            IsoGridSquare end=body.getCell().getGridSquare(x+(vertical?0:"x".equals(axis)?1:0),
                y+(vertical?0:"y".equals(axis)?1:0),z+(vertical?1:0));
            if (!networkLoaded(body,q) || !networkLoaded(body,end) || !q.TreatAsSolidFloor()
                || vertical && q.getWall("y".equals(axis))==null
                || !vertical && (q.isBlockedTo(end) || q.isWallTo(end) || q.isDoorTo(end) || q.isWindowTo(end))) return null;
            // A wall-mounted riser is worked from its visible base. The loaded
            // upper endpoint is a physical fit condition, not acquired sight
            // of another floor. Private route planning retains that separately.
            if(body instanceof SAOIsoPlayerShell shell && (!SAOPerceptionScanner.canSeeWorldSquareNow(shell,q,3)
                || !vertical && !SAOPerceptionScanner.canSeeWorldSquareNow(shell,end,3)))return null;
            var signature=new StringBuilder();
            for (IsoGridSquare square:new IsoGridSquare[]{q,end}) {
                appendLengthPrefixed(signature,Integer.toString(square.getX()));
                appendLengthPrefixed(signature,Integer.toString(square.getY()));
                appendLengthPrefixed(signature,Integer.toString(square.getZ()));
                for (int index=0;index<square.getObjects().size();index++) {
                    IsoObject o=square.getObjects().get(index);
                    appendLengthPrefixed(signature,o.getClass().getName());
                    appendLengthPrefixed(signature,o.getSprite()==null?"":o.getSprite().getName());
                }
                for (IsoWorldInventoryObject o:square.getWorldObjects()) {
                    InventoryItem i=o.getItem();
                    if (i!=null && i.hasModData() && i.getModData().rawget("SAOWaterNetworkPart")!=null) {
                        appendLengthPrefixed(signature,Integer.toString(i.getID()));
                        appendLengthPrefixed(signature,i.getFullType());
                    }
                }
            }
            var row=recipeTable();row.rawset("kind",kind);row.rawset("axis",axis);
            row.rawset("x",(double)x);row.rawset("y",(double)y);row.rawset("z",(double)z);
            row.rawset("revision",digest(signature.toString()));row.rawset("itemType",networkType(kind));
            return row;
        } catch (Throwable unavailable) { return null; }
    }
    public static synchronized boolean networkPartCurrent(IsoPlayer body,IsoWorldInventoryObject object,InventoryItem item) {
        try {
            if(!networkActor(body)||object==null||item==null)return false;
            IsoGridSquare q=object.getSquare();
            return networkLoaded(body,q) && q.getWorldObjects().contains(object) && object.getItem()==item
                && item.getWorldItem()==object && item.getCondition()>0
                && zombie.scripting.ScriptManager.instance.getItem(item.getFullType())==item.getScriptItem();
        } catch(Throwable unavailable) { return false; }
    }
    public static synchronized Object placeNetworkPart(IsoPlayer body,InventoryItem item,
            se.krka.kahlua.vm.KahluaTable site) {
        if(site==null||site.getMetatable()!=null)return null;
        try {
            if(!(site.rawget("x") instanceof Double x)||!(site.rawget("y") instanceof Double y)
                ||!(site.rawget("z") instanceof Double z)||x!=Math.rint(x)||y!=Math.rint(y)||z!=Math.rint(z)
                ||!(site.rawget("kind") instanceof String kind)||!(site.rawget("axis") instanceof String axis))return null;
            var actual=networkSite(body,kind,axis,x.intValue(),y.intValue(),z.intValue());
            if(!constructionPlainSame(actual,site)||item==null||!networkType(kind).equals(item.getFullType())
                ||item.getContainer()!=body.getInventory()||!body.getInventory().contains(item)||item.getWorldItem()!=null
                ||item.getCondition()<=0||item.getIsCraftingConsumed()
                ||zombie.scripting.ScriptManager.instance.getItem(item.getFullType())!=item.getScriptItem()
                ||item.hasModData()&&item.getModData().rawget("SAOWaterNetworkPart")!=null||item.getTex()==null)return null;
            IsoGridSquare q=body.getCell().getGridSquare(x.intValue(),y.intValue(),z.intValue());
            InventoryItem returned=q.AddWorldInventoryItem(item,.5f,.5f,0f,false);
            IsoWorldInventoryObject object=item.getWorldItem();
            if(returned!=item||!networkPartCurrent(body,object,item))return null;
            // Factory initialization resets pose. Set the installed pose afterwards.
            item.setWorldXRotation("riser".equals(kind)?90f:0f);
            item.setWorldYRotation(0f);
            // Owned valve ports run along mesh X; the pump inlet runs along
            // mesh Z. Inventory world-Z is the renderer's Y-axis yaw.
            item.setWorldZRotation("riser".equals(kind)?0f:"valve".equals(kind)
                ?"x".equals(axis)?0f:90f:"x".equals(axis)?90f:0f);
            object.setIgnoreRemoveSandbox(true);
            body.getInventory().Remove(item);
            return !body.getInventory().contains(item)&&networkPartCurrent(body,object,item)?object:null;
        } catch(Throwable unavailable) { return null; }
    }

public static synchronized Object networkFluidObservation(IsoPlayer body,IsoObject object) {
        try {
            if(!networkActor(body)||object==null||object instanceof IsoWorldInventoryObject)return null;
            IsoGridSquare q=object.getSquare();var fc=object.getFluidContainer();
            if(!networkLoaded(body,q)||!q.getObjects().contains(object)||fc==null
                ||Math.floor(body.getZ())!=q.getZ()||Math.hypot(body.getX()-q.getX()-.5,body.getY()-q.getY()-.5)>1.8
                ||body instanceof SAOIsoPlayerShell shell&&!SAOPerceptionScanner.canSeeWorldSquareNow(shell,q,3)
                ||!Float.isFinite(fc.getAmount())||!Float.isFinite(fc.getCapacity())||fc.getAmount()<0||fc.getCapacity()<=0)return null;
            Source source=objectFluidSource(new Snapshot(Math.floorDiv(q.getX(),CHUNK_SIZE),Math.floorDiv(q.getY(),CHUNK_SIZE)),q,object);
            var row=recipeTable();row.rawset("sourceId",source.id);row.rawset("fingerprint",source.fingerprint);
            row.rawset("revision",source.revision);row.rawset("nativeClass",object.getClass().getName());
            row.rawset("x",(double)q.getX());row.rawset("y",(double)q.getY());row.rawset("z",(double)q.getZ());
            row.rawset("amount",(double)fc.getAmount());row.rawset("capacity",(double)fc.getCapacity());
            row.rawset("water",fc.contains(Fluid.Water)||fc.contains(Fluid.TaintedWater));
            row.rawset("tainted",fc.isTainted());row.rawset("externalReceiver",object.getUsesExternalWaterSource());
            row.rawset("included",Boolean.TRUE.equals(object.getModData().rawget("SAOHouseholdSource"))
                ||object.getModData().rawget("SAOHouseholdSource")==null&&Boolean.TRUE.equals(object.getModData().rawget("LGEPInclude")));
            return row;
        }catch(Throwable unavailable){return null;}
    }
    public static synchronized Object networkFluidObject(IsoPlayer body,se.krka.kahlua.vm.KahluaTable expected) {
        try {
            if(expected==null||expected.getMetatable()!=null||!networkActor(body)
                ||!(expected.rawget("x")instanceof Double x)||!(expected.rawget("y")instanceof Double y)
                ||!(expected.rawget("z")instanceof Double z)||x!=Math.rint(x)||y!=Math.rint(y)||z!=Math.rint(z))return null;
            IsoGridSquare q=body.getCell().getGridSquare(x.intValue(),y.intValue(),z.intValue());
            if(!networkLoaded(body,q))return null;
            IsoObject found=null;
            for(int index=0;index<q.getObjects().size();index++){
                IsoObject object=q.getObjects().get(index);
                if(!("F:"+object.getModData().rawget(SOURCE_TOKEN)).equals(expected.rawget("sourceId")))continue;
                if(found!=null||!constructionPlainSame(expected,networkFluidObservation(body,object)))return null;
                found=object;
            }
            return found;
        }catch(Throwable unavailable){return null;}
    }

    private static String recipeRevision(zombie.scripting.entity.components.crafting.CraftRecipe recipe) {
        StringBuilder signature = new StringBuilder();
        appendLengthPrefixed(signature, recipe.getScriptObjectFullType());
        appendLengthPrefixed(signature, recipe.getModID());
        appendLengthPrefixed(signature, recipe.getCategory());
        appendLengthPrefixed(signature, Boolean.toString(recipe.needToBeLearn()));
        for (var input : recipe.getInputs()) {
            appendLengthPrefixed(signature, Integer.toString(recipe.getIndexForIO(input)));
            appendLengthPrefixed(signature, input.getOriginalLine());
        }
        for (var output : recipe.getOutputs()) {
            appendLengthPrefixed(signature, Integer.toString(recipe.getIndexForIO(output)));
            appendLengthPrefixed(signature, output.getOriginalLine());
        }
        return digest(signature.toString());
    }

    private static zombie.scripting.entity.components.crafting.InputScript recipeInput(String recipeId, int index, String declaration) {
        var recipe = zombie.scripting.ScriptManager.instance.getCraftRecipe(recipeId);
        var io = recipe == null ? null : recipe.getIOForIndex(index);
        if (!(io instanceof zombie.scripting.entity.components.crafting.InputScript input)
                || recipe.getIndexForIO(input) != index || !java.util.Objects.equals(declaration, input.getOriginalLine())
                || input.getResourceType() != zombie.entity.components.resources.ResourceType.Item
                || input.isVariableAmount() || input.isApplyOnTick() || input.isAutomationOnly()
                || input.hasCreateToItem() || input.hasConsumeFromItem() || input.hasParentScript()) return null;
        return input;
    }

    private static se.krka.kahlua.vm.KahluaTable privateRecipeSource(String actor, String id, String fingerprint, String revision) {
        var sao = table(zombie.Lua.LuaManager.env.rawget("SAO"));
        var perception = sao == null ? null : table(sao.rawget("Perception"));
        var beliefs = perception == null ? null : table(perception.rawget("beliefs"));
        var mind = beliefs == null ? null : table(beliefs.rawget(actor));
        var known = mind == null ? null : table(mind.rawget("known"));
        if (known == null) return null;
        var places = known.iterator();
        while (places.advance()) {
            var place = table(places.getValue());
            var facts = place == null ? null : table(place.rawget("sourceFacts"));
            var fact = facts == null ? null : table(facts.rawget(id));
            if (fact != null && fingerprint.equals(fact.rawget("fingerprint")) && revision.equals(fact.rawget("revision"))
                    && ("available".equals(fact.rawget("state")) || "spent".equals(fact.rawget("state")))
                    && (Boolean.TRUE.equals(fact.rawget("explored"))
                        || id.startsWith("G:") && "visible-ground".equals(fact.rawget("knowledgeKind")))) return fact;
        }
        return null;
    }

    public static synchronized Object recipeInputObservation(SAOIsoPlayerShell body, String sourceId,
            String fingerprint, String revision, String recipeId, int inputIndex, String declaration,
            String demandId, String purposeId, String stepId) {
        try {
            String actor = recipeActor(body);
            var input = recipeInput(recipeId, inputIndex, declaration);
            if (actor == null || transactionActive || input == null || demandId == null || demandId.isBlank()
                    || purposeId == null || purposeId.isBlank() || stepId == null || stepId.isBlank()) return null;
            var sao=table(zombie.Lua.LuaManager.env.rawget("SAO"));
            var planning=sao==null ? null : table(sao.rawget("ProceduralPlanning"));
            Object admission=planning==null ? null : planning.rawget("recipeInputAdmission");
            if (admission==null || !Boolean.TRUE.equals(zombie.Lua.LuaManager.caller.pcallBoolean(
                    zombie.Lua.LuaManager.thread,admission,new Object[]{actor,demandId,purposeId,stepId,recipeId,(double)inputIndex,declaration}))) return null;
            var fact = privateRecipeSource(actor, sourceId, fingerprint, revision);
            if (fact == null || !(fact.rawget("x") instanceof Number x) || !(fact.rawget("y") instanceof Number y)
                    || !(fact.rawget("z") instanceof Number z)) return null;
            var rows = recipeTable(); int count = 0;
            // Full inspected facts intentionally carry source identity rather than every item.
            var source = resolveRecipeSource(body, sourceId, fingerprint, revision, x.intValue(), y.intValue(), z.intValue());
            if (source == null) return null;
            for (var item : source) {
                if (!input.canUseItem(item.getFullType())) continue;
                var row = recipeItemState(item);
                row.rawset("nativeEligible", zombie.entity.components.crafting.recipe.CraftRecipeManager.isItemValidForInputScript(input, item, body));
                var status = recipeTable();
                status.rawset("favorite", input.passesFavoriteTest(item)); status.rawset("rotten", input.passesRottenTest(item));
                status.rawset("frozen", input.passesFrozenTest(item)); status.rawset("broken", input.passesBrokenTest(item));
                status.rawset("sealed", input.passesSealedTest(item)); status.rawset("routine", input.doesItemPassRoutineStatusTests(item, body));
                status.rawset("clothing", input.doesItemPassClothingTypeStatusTests(item)); status.rawset("sharpness", input.doesItemPassSharpnessStatusTests(item));
                status.rawset("damage", input.doesItemPassDamageStatusTests(item)); status.rawset("fullEmpty", input.doesItemPassIsOrNotEmptyAndFullTests(item));
                status.rawset("foodCooking", input.doesItemPassFoodAndCookingTests(item)); row.rawset("status", status);
                rows.rawset((double) ++count, row);
            }
            var out = recipeTable(); out.rawset("actorId", actor); out.rawset("sourceId", sourceId);
            out.rawset("fingerprint", fingerprint); out.rawset("revision", revision); out.rawset("recipeId", recipeId);
            out.rawset("index", (double) inputIndex); out.rawset("declaration", declaration);
            out.rawset("demandId", demandId); out.rawset("purposeId", purposeId); out.rawset("stepId", stepId); out.rawset("items", rows);
            return out;
        } catch (Throwable unavailable) { return null; }
    }

    private static List<InventoryItem> resolveRecipeSource(SAOIsoPlayerShell body, String id, String fingerprint,
            String revision, int x, int y, int z) throws ActionRefusal {
        var square = body.getCell().getGridSquare(x, y, z);
        if (!SAOPerceptionScanner.canSeeWorldSquareNow(body, square, INSPECTION_RANGE)) return null;
        String[] parts = id.split(":");
        if (parts.length == 3 && "C".equals(parts[0])) {
            int index = Integer.parseInt(parts[2]);
            for (int objectIndex = 0; objectIndex < square.getObjects().size(); objectIndex++) {
                var object = square.getObjects().get(objectIndex);
                if (!parts[1].equals(object.getModData().rawget(SOURCE_TOKEN)) || index < 0 || index >= object.getContainerCount()) continue;
                var container = object.getContainerByIndex(index);
                if (container == null || !knowsContainerContents(body, object, container, index)) return null;
                var source = containerSourceKnown(square, object, container, index, parts[1]);
                if (!fingerprint.equals(source.fingerprint) || !revision.equals(source.revision)
                        || !SAONeeds.containerAccessibleNow(body, container)) return null;
                return SAOPrivateInventory.containerItems(container);
            }
        } else if (parts.length == 2 && "G".equals(parts[0])) {
            for (var world : square.getWorldObjects()) {
                var item = world.getItem();
                if (item == null || !parts[1].equals(item.getModData().rawget(ITEM_TOKEN))) continue;
                if(!networkStockAvailable(item))return null;
                var source = groundSourceKnown(square, world, parts[1]);
                if (!fingerprint.equals(source.fingerprint) || !revision.equals(source.revision)) return null;
                return List.of(item);
            }
        }
        return null;
    }

    private static se.krka.kahlua.vm.KahluaTable recipeItemState(InventoryItem item) {
        var row = recipeTable(); row.rawset("itemId", Integer.toString(item.getID())); row.rawset("itemType", item.getFullType());
        row.rawset("currentUses", (double) item.getCurrentUsesFloat()); row.rawset("condition", (double) item.getCondition());
        row.rawset("maxCondition", (double) item.getConditionMax()); row.rawset("sharpness", (double) item.getSharpness());
        row.rawset("maxSharpness", (double) item.getMaxSharpness()); row.rawset("maxUses", (double) item.getMaxUses());
        return row;
    }

    public static synchronized Object recipeSupplyNeeds(SAOIsoPlayerShell body, String recipeId) {
        try {
            String actor = recipeActor(body); var recipe = zombie.scripting.ScriptManager.instance.getCraftRecipe(recipeId);
            if (actor == null || recipe == null || !(!recipe.needToBeLearn() || body.isRecipeActuallyKnown(recipe))) return null;
            var out = recipeTable(); var slots = recipeTable(); out.rawset("actorId", actor); out.rawset("recipeId", recipeId);
            out.rawset("nativeRevision", recipeRevision(recipe)); out.rawset("slots", slots);
            var items = SAOPrivateInventory.carriedItems(body); var used = new java.util.HashSet<Integer>(); int count = 0;
            for (var input : recipe.getInputs()) {
                int index = recipe.getIndexForIO(input); var row = recipeTable(); var held = recipeTable(); var alternatives = recipeTable();
                row.rawset("index", (double) index); row.rawset("declaration", input.getOriginalLine());
                row.rawset("requiredAmount", (double) input.getAmount()); row.rawset("heldItems", held); row.rawset("alternatives", alternatives);
                boolean supported = recipeInput(recipeId, index, input.getOriginalLine()) == input;
                row.rawset("channelStatus", supported ? "item" : "unsupported-native-channel");
                double fraction = 0; int itemCount = 0, alternativeCount = 0;
                if (supported) {
                    for (var item : items) {
                        if (fraction >= 1 || used.contains(item.getID()) || item.getIsCraftingConsumed()
                                || !recipeItemUnreserved(item.getID())
                                || !zombie.entity.components.crafting.recipe.CraftRecipeManager.isItemValidForInputScript(input, item, body)) continue;
                        float amount = input.getAmount(item.getFullType());
                        if (!(amount > 0)) continue;
                        double contribution = input.isItemCount() ? 1 : item.getCurrentUses();
                        if (!(contribution > 0)) continue;
                        used.add(item.getID()); fraction += contribution / amount;
                        held.rawset((double) ++itemCount, recipeItemState(item));
                    }
                    var possible = input.getPossibleInputItems();
                    if (possible != null) for (var item : possible) {
                        var alternative = recipeTable(); double amount = input.getAmount(item.getFullName());
                        boolean partial = input.isUsesPartialItem(item);
                        alternative.rawset("itemType", item.getFullName()); alternative.rawset("amount", amount);
                        alternative.rawset("maxAmount", (double) input.getMaxAmount(item.getFullName())); alternative.rawset("partialUse", partial);
                        alternative.rawset("desiredAmount", amount * Math.max(0, 1 - fraction)); alternative.rawset("quantityUnit", partial ? "uses" : "items");
                        alternatives.rawset((double) ++alternativeCount, alternative);
                    }
                }
                row.rawset("heldFraction", fraction); row.rawset("remainingFraction", Math.max(0, 1 - fraction));
                slots.rawset((double) ++count, row);
            }
            return out;
        } catch (Throwable unavailable) { return null; }
    }

    private static boolean recipeItemUnreserved(int itemId) {
        var data = zombie.world.moddata.GlobalModData.instance.get("SurvivorAwareness_WorldSources");
        var reservations = data == null ? null : table(data.rawget("reservations"));
        if (reservations == null) return true;
        var it = reservations.iterator();
        while (it.advance()) {
            var reservation = table(it.getValue());
            Object reservedId = reservation == null ? null : reservation.rawget("itemId");
            if (reservation != null && "reserved".equals(reservation.rawget("status"))
                    && (reservedId instanceof Number n && n.intValue() == itemId
                        || Integer.toString(itemId).equals(reservedId))) return false;
        }
        return true;
    }

    private static String upkeepMetric(zombie.scripting.entity.components.crafting.CraftRecipe recipe,
            zombie.scripting.entity.components.crafting.InputScript input, InventoryItem item) {
        if (input.isSharpenable() && item.hasSharpness() && item.getSharpness() < item.getMaxSharpness()) return "sharpness";
        if (input.notFull() && "Base.RefillBlowTorch".equals(recipe.getScriptObjectFullType())
                && item.getCurrentUsesFloat() < item.getMaxUses()) return "uses";
        boolean replacement = input.isDestroy() && recipe.getOutputs().stream().anyMatch(output -> output.getPossibleResultItems()!=null && output.getPossibleResultItems().contains(item.getScriptItem()));
        if ((input.isKeep() && input.isDamaged() || replacement) && item.getCondition() < item.getConditionMax()) return "condition";
        return null;
    }

    public static synchronized Object recipeUpkeepDemands(SAOIsoPlayerShell body) {
        try {
            var out = recipeTable();
            String actor = recipeActor(body); if (actor == null) return out;
            var items = SAOPrivateInventory.carriedItems(body); int count = 0;
            for (var recipe : zombie.scripting.ScriptManager.instance.getAllCraftRecipes()) {
                if (!("Repair".equals(recipe.getCategory()) || "Base.RefillBlowTorch".equals(recipe.getScriptObjectFullType()))
                        || !(!recipe.needToBeLearn() || body.isRecipeActuallyKnown(recipe))) continue;
                for (var input : recipe.getInputs()) for (var item : items) {
                    int index = recipe.getIndexForIO(input); String metric = upkeepMetric(recipe, input, item);
                    if (metric == null || recipeInput(recipe.getScriptObjectFullType(), index, input.getOriginalLine()) != input
                            || item.getIsCraftingConsumed() || !recipeItemUnreserved(item.getID())
                            || !zombie.entity.components.crafting.recipe.CraftRecipeManager.isItemValidForInputScript(input, item, body)) continue;
                    var row = recipeItemState(item); var state = recipeTable(); state.rawset("metric", metric); state.rawset("held", true);
                    double maximum = metric.equals("condition") ? item.getConditionMax() : metric.equals("sharpness") ? item.getMaxSharpness() : item.getMaxUses();
                    state.rawset("minimum", maximum); row.rawset("actorId", actor); row.rawset("targetItemId", Integer.toString(item.getID()));
                    row.rawset("recipeId", recipe.getScriptObjectFullType()); row.rawset("targetSlotIndex", (double) index);
                    row.rawset("declaration", input.getOriginalLine()); row.rawset("desiredState", state);
                    row.rawset("sourceRevision", recipeRevision(recipe)); row.rawset("nativeRevision", recipeRevision(recipe));
                    out.rawset((double) ++count, row);
                }
            }
            return out;
        } catch (Throwable unavailable) { return null; }
    }

    public static synchronized Object recipeMeansForDemand(SAOIsoPlayerShell body, se.krka.kahlua.vm.KahluaTable demand) {
        try {
            var out = recipeTable();
            String actor = recipeActor(body); if (actor == null || demand == null) return out;
            Object kind = demand.rawget("kind"), revision = demand.rawget("sourceRevision");
            if (!(revision instanceof String sourceRevision) || sourceRevision.isBlank()) return out;
            InventoryItem target = null;
            String desired = demand.rawget("desiredType") instanceof String name ? name : null;
            boolean stock = "recipe-stock".equals(kind), upkeep = "recipe-upkeep".equals(kind);
            if (stock) {
                if (desired == null || !(demand.rawget("desiredAmount") instanceof Number amount) || !(amount.doubleValue() > 0)) return out;
                boolean needed = "SAO.Generator".equals(demand.rawget("consumerOwner")) && "repair".equals(demand.rawget("consumerOperation"))
                    && "Base.ElectronicsScrap".equals(desired);
                if("SAO.NetworkWork".equals(demand.rawget("consumerOwner"))&&"place".equals(demand.rawget("consumerOperation"))
                    &&("SAO.WaterValve".equals(desired)||"SAO.WaterPump".equals(desired))) {
                    var sao=table(zombie.Lua.LuaManager.env.rawget("SAO"));var planning=sao==null?null:table(sao.rawget("ProceduralPlanning"));
                    Object current=planning==null?null:planning.rawget("networkMaterialDemandCurrent");
                    needed=current!=null&&Boolean.TRUE.equals(zombie.Lua.LuaManager.caller.pcallBoolean(
                        zombie.Lua.LuaManager.thread,current,new Object[]{actor,demand}));
                }
                var consumer = demand.rawget("consumerRecipeId") instanceof String id ? zombie.scripting.ScriptManager.instance.getCraftRecipe(id) : null;
                if (consumer != null && (consumer.isBuildableRecipe() || "Repair".equals(consumer.getCategory())
                        || "Base.RefillBlowTorch".equals(consumer.getScriptObjectFullType())))
                    for (var input : consumer.getInputs()) if (input.canUseItem(desired)) needed = true;
                if (!needed) return out;
            } else if (upkeep) {
                Object identity = demand.rawget("targetItemId");
                for (var item : SAOPrivateInventory.carriedItems(body)) if (Integer.toString(item.getID()).equals(identity)) {
                    if (target != null) return out; target = item;
                }
                if (target == null || !(demand.rawget("targetSlotIndex") instanceof Number) || table(demand.rawget("desiredState")) == null) return out;
            } else return out;
            int count = 0;
            for (var recipe : zombie.scripting.ScriptManager.instance.getAllCraftRecipes()) {
                boolean matches = false;
                if (stock) {
                    var item = zombie.scripting.ScriptManager.instance.getItem(desired);
                    if (item != null) for (var output : recipe.getOutputs()) if (output.getPossibleResultItems()!=null && output.getPossibleResultItems().contains(item)) matches = true;
                } else if ("Repair".equals(recipe.getCategory()) || "Base.RefillBlowTorch".equals(recipe.getScriptObjectFullType())) {
                    int index = ((Number) demand.rawget("targetSlotIndex")).intValue();
                    var io = recipe.getIOForIndex(index);
                    if (io instanceof zombie.scripting.entity.components.crafting.InputScript input) {
                        String metric = upkeepMetric(recipe, input, target);
                        var state = table(demand.rawget("desiredState"));
                        matches = metric != null && metric.equals(state.rawget("metric"))
                            && recipeInput(recipe.getScriptObjectFullType(), index, input.getOriginalLine()) == input
                            && !target.getIsCraftingConsumed() && recipeItemUnreserved(target.getID())
                            && zombie.entity.components.crafting.recipe.CraftRecipeManager.isItemValidForInputScript(input, target, body);
                    }
                }
                if (!matches || !(!recipe.needToBeLearn() || body.isRecipeActuallyKnown(recipe))) continue;
                var row = recipeTable(); row.rawset("recipeId", recipe.getScriptObjectFullType()); row.rawset("sourceRevision", sourceRevision);
                row.rawset("nativeRevision", recipeRevision(recipe)); row.rawset("knowledgeKind", recipe.needToBeLearn() ? "acquired" : "intrinsic");
                if (recipe.needToBeLearn()) row.rawset("acquisitionId", "native-known:" + actor + ":" + recipe.getScriptObjectFullType() + ":" + recipeRevision(recipe));
                out.rawset((double) ++count, row);
            }
            return out;
        } catch (Throwable unavailable) { return null; }
    }

    private static final class RecipeWorkplaceBinding {
        final String actor, key, revision; final java.lang.ref.WeakReference<IsoObject> object;
        final java.lang.ref.WeakReference<zombie.entity.components.crafting.CraftBench> bench;
        final String sprite, entityType, benchQuery; final IsoGridSquare square;
        RecipeWorkplaceBinding(String actor, String key, IsoObject object, zombie.entity.components.crafting.CraftBench bench) {
            this.actor = actor; this.key = key; this.object = new java.lang.ref.WeakReference<>(object);
            this.bench = new java.lang.ref.WeakReference<>(bench); this.square = object.getSquare();
            this.sprite = value(object.getSpriteName()); this.entityType = object.getEntityScript() == null ? "" : object.getEntityScript().getFullName();
            this.benchQuery = bench == null ? "" : value(bench.getRecipeTagQuery()); this.revision = UUID.randomUUID().toString();
        }
        boolean matches(String actor, IsoObject object, zombie.entity.components.crafting.CraftBench bench) {
            return this.actor.equals(actor) && this.object.get() == object && this.bench.get() == bench
                && object.getSquare() == square && sprite.equals(value(object.getSpriteName()))
                && entityType.equals(object.getEntityScript() == null ? "" : object.getEntityScript().getFullName())
                && benchQuery.equals(bench == null ? "" : value(bench.getRecipeTagQuery()));
        }
    }

    public static synchronized Object observeRecipeWorkplaces(SAOIsoPlayerShell body, int radius) {
        try {
            var out = recipeTable();
            String actor = recipeActor(body); if (actor == null || radius < 1 || radius > INSPECTION_RANGE) return out;
            var bindings = RECIPE_WORKPLACES.computeIfAbsent(body, ignored -> new LinkedHashMap<>()); int count = 0;
            var eye = body.getCurrentSquare();
            for (int dy = -radius; dy <= radius; dy++) for (int dx = -radius; dx <= radius; dx++) {
                var square = body.getCell().getGridSquare(eye.getX() + dx, eye.getY() + dy, eye.getZ());
                if (!SAOPerceptionScanner.canSeeWorldSquareNow(body, square, radius) || !square.isSolidFloor()) continue;
                for (int index = 0; index < square.getObjects().size(); index++) {
                    var object = square.getObjects().get(index); if (object == null || object.getSquare() != square) continue;
                    zombie.entity.components.crafting.CraftBench bench = object.getComponent(zombie.entity.ComponentType.CraftBench);
                    boolean surface = body.canUseAsGenericCraftingSurface(object);
                    if (bench == null && !surface) continue;
                    String key = "W:" + square.getX() + ":" + square.getY() + ":" + square.getZ() + ":" + index;
                    var binding = bindings.get(key);
                    if (binding == null || !binding.matches(actor, object, bench)) {
                        binding = new RecipeWorkplaceBinding(actor, key, object, bench); bindings.put(key, binding);
                    }
                    var row = recipeTable(); row.rawset("key", key); row.rawset("revision", binding.revision);
                    row.rawset("x", (double) square.getX()); row.rawset("y", (double) square.getY()); row.rawset("z", (double) square.getZ());
                    row.rawset("sprite", binding.sprite); row.rawset("entityType", binding.entityType); row.rawset("support", true);
                    row.rawset("craftBench", bench != null); row.rawset("genericSurface", surface);
                    row.rawset("occupied", object.getUsingPlayer() != null && object.getUsingPlayer() != body);
                    row.rawset("actorId", actor); rowsafeRecipes(row, bench); out.rawset((double) ++count, row);
                    if (count >= MAX_INSPECTION_OPTIONS) return out;
                }
            }
            if (bindings.size() > MAX_INSPECTION_OPTIONS) {
                var keys = new ArrayList<>(bindings.keySet()); for (int n = 0; n < keys.size() - MAX_INSPECTION_OPTIONS; n++) bindings.remove(keys.get(n));
            }
            return out;
        } catch (Throwable unavailable) { return null; }
    }

    private static void rowsafeRecipes(se.krka.kahlua.vm.KahluaTable row, zombie.entity.components.crafting.CraftBench bench) {
        // Bench capability is a local observed fact. Recipe knowledge stays with person admission.
        if (bench != null) {
            row.rawset("recipeTagQuery", value(bench.getRecipeTagQuery()));
            var ids=recipeTable();int count=0;
            for (var recipe:bench.getRecipes()) ids.rawset((double)++count,recipe.getScriptObjectFullType());
            row.rawset("recipeIds",ids);
        }
    }

    public static synchronized Object recipeWorkplace(SAOIsoPlayerShell body, String key, String revision, int x, int y, int z) {
        try {
            String actor = recipeActor(body); var bindings = RECIPE_WORKPLACES.get(body);
            var binding = bindings == null ? null : bindings.get(key); if (actor == null || binding == null || !binding.revision.equals(revision)) return null;
            var object = binding.object.get(); var bench = binding.bench.get(); var square = body.getCell().getGridSquare(x, y, z);
            if (object == null || square == null || object.getSquare() != square || !square.getObjects().contains(object)
                    || object.getComponent(zombie.entity.ComponentType.CraftBench) != bench || !binding.matches(actor, object, bench)
                    || !square.isSolidFloor() || !SAOPerceptionScanner.canSeeWorldSquareNow(body, square, INSPECTION_RANGE)
                    || !squareWithinReach(body, square) || !body.getCurrentSquare().canReachTo(square)
                    || bench == null && !body.canUseAsGenericCraftingSurface(object)
                    || object.getUsingPlayer() != null && object.getUsingPlayer() != body) return null;
            var out = recipeTable(); out.rawset("object", object); out.rawset("bench", bench); out.rawset("key", key); out.rawset("revision", revision); return out;
        } catch (Throwable unavailable) { return null; }
    }

    private SAOWorldSources() {
    }

    /** Read by the density advice from inside ItemPickerJava. */
    public static boolean isHydrating() {
        return HYDRATION_DEPTH.get() > 0;
    }

    public static String status() {
        return "protocol=" + PROTOCOL + "|" + SAOLootDensityWeave.report()
            + "|hydrating=" + isHydrating();
    }

    /** Drop body-keyed exact-source bindings when the owning world ends. */
    public static synchronized void resetRuntimeForWorld() {
        ACTIONS.clear();
        INSPECTIONS.clear();
        INSPECTION_MEMORY.clear();
        COLLECTOR_SITES.clear();
        UTILITY_BINDINGS.clear();
        RECIPE_WORKPLACES.clear();
    }

    /** Kahlua does not implement Lua weak tables. Keep body keys on the JVM;
     * the returned table contains only data, never a native body or holder. */
    public static synchronized Object inspectionMemory(IsoPlayer shell) {
        if (!inspectionActor(shell)) return null;
        return INSPECTION_MEMORY.computeIfAbsent(shell,
            ignored -> zombie.Lua.LuaManager.platform.newTable());
    }

    /** Personally visible loose material, through the existing exact source protocol. */
    public static synchronized ArrayList<String> visibleGroundSources(IsoPlayer shell, int radius) {
        ArrayList<String> out = new ArrayList<>();
        if (transactionActive || !inspectionActor(shell) || radius < 1 || radius > INSPECTION_RANGE) return out;
        try {
            IsoCell cell = shell.getCell();
            int x = (int) Math.floor(shell.getX()), y = (int) Math.floor(shell.getY());
            int z = (int) Math.floor(shell.getZ());
            ArrayList<Source> seen = new ArrayList<>();
            for (int dy = -radius; dy <= radius; dy++) for (int dx = -radius; dx <= radius; dx++) {
                IsoGridSquare square = cell.getGridSquare(x + dx, y + dy, z);
                if (!SAOPerceptionScanner.canSeeWorldSquareNow(shell, square, radius)) continue;
                for (IsoWorldInventoryObject world : new ArrayList<>(square.getWorldObjects())) {
                    InventoryItem item = world == null ? null : world.getItem();
                    if (item == null || world.getSquare() != square || item.getWorldItem() != world) continue;
                    Snapshot snapshot = new Snapshot(Math.floorDiv(square.getX(), CHUNK_SIZE), Math.floorDiv(square.getY(), CHUNK_SIZE));
                    Source source = groundSource(snapshot, square, world);
                    int at = Collections.binarySearch(seen, source, Comparator.comparingDouble((Source row) ->
                        Math.pow(row.x + 0.5 - shell.getX(), 2) + Math.pow(row.y + 0.5 - shell.getY(), 2))
                        .thenComparing(row -> row.id));
                    if (at < 0) at = -at - 1;
                    if (at < 32) { seen.add(at, source); if (seen.size() > 32) seen.remove(32); }
                }
            }
            for (Source source : seen) {
                Snapshot snapshot = new Snapshot(Math.floorDiv(source.x, CHUNK_SIZE), Math.floorDiv(source.y, CHUNK_SIZE));
                snapshot.mode = "visible-ground";
                snapshot.add(source); snapshot.finish(); out.add(encode(snapshot));
            }
        } catch (Throwable unavailable) { out.clear(); }
        return out;
    }

    /** Visible source geometry only: listing never reads or generates contents. */
    public static synchronized String inspectionCandidates(IsoPlayer shell, int radius) {
        if (transactionActive || !inspectionActor(shell) || radius < 1
                || radius > INSPECTION_RANGE) return "";
        try {
            IsoCell cell = shell.getCell();
            int x = (int) Math.floor(shell.getX()), y = (int) Math.floor(shell.getY());
            int z = (int) Math.floor(shell.getZ());
            ArrayList<InspectionBinding> candidates = new ArrayList<>();
            for (int dy = -radius; dy <= radius; dy++) {
                for (int dx = -radius; dx <= radius; dx++) {
                    IsoGridSquare square = cell.getGridSquare(x + dx, y + dy, z);
                    if (!SAOPerceptionScanner.canSeeWorldSquareNow(shell, square, radius)) continue;
                    IsoGridSquare approach = interactionSquare(shell, square);
                    if (approach == null) continue;
                    List<IsoObject> objects = square.getObjects();
                    for (int objectIndex = 0; objectIndex < objects.size(); objectIndex++) {
                        IsoObject object = objects.get(objectIndex);
                        if (object == null || object.getSquare() != square
                                || (object instanceof IsoThumpable locked
                                    && locked.isLockedToCharacter(shell))) continue;
                        // A fluid fixture is visible infrastructure; its quantities
                        // remain unknown until this actor performs the current read.
                        var fluid = object.getFluidContainer();
                        if (fluid != null && Float.isFinite(fluid.getCapacity()) && fluid.getCapacity() > 0
                                || object.getUsesExternalWaterSource()) {
                            var snapshot = new Snapshot(Math.floorDiv(square.getX(), CHUNK_SIZE), Math.floorDiv(square.getY(), CHUNK_SIZE));
                            String token = sourceToken(snapshot, object);
                            var candidate = new InspectionBinding("F:" + token, fluidFingerprint(square, object, token),
                                object, null, -1, square, approach, shell);
                            int at = Collections.binarySearch(candidates, candidate,
                                Comparator.comparingDouble((InspectionBinding item) -> item.distance).thenComparing(item -> item.id));
                            if (at < 0) at = -at - 1;
                            if (at < MAX_INSPECTION_OPTIONS) {
                                candidates.add(at, candidate);
                                if (candidates.size() > MAX_INSPECTION_OPTIONS) candidates.remove(MAX_INSPECTION_OPTIONS);
                            }
                        }
                        for (int index = 0; index < object.getContainerCount(); index++) {
                            ItemContainer container = object.getContainerByIndex(index);
                            if (container == null || container.getParent() != object
                                    || container.getSourceGrid() != square
                                    || container.getOutermostContainer() != container) continue;
                            String id = privateContainerId(object, index);
                            String token = id.split(":")[1];
                            String fingerprint = containerFingerprint(square, object, container, index, token);
                            var candidate = new InspectionBinding(id, fingerprint, object, container,
                                index, square, approach, shell);
                            int at = Collections.binarySearch(candidates, candidate,
                                Comparator.comparingDouble((InspectionBinding item) -> item.distance)
                                    .thenComparing(item -> item.id));
                            if (at < 0) at = -at - 1;
                            if (at < MAX_INSPECTION_OPTIONS) {
                                candidates.add(at, candidate);
                                if (candidates.size() > MAX_INSPECTION_OPTIONS) {
                                    candidates.remove(MAX_INSPECTION_OPTIONS);
                                }
                            }
                        }
                    }
                }
            }
            Map<String, InspectionBinding> bindings = new LinkedHashMap<>();
            StringBuilder out = new StringBuilder("H|protocol=SAOWI1\n");
            for (InspectionBinding candidate : candidates) {
                if (bindings.put(candidate.id, candidate) != null) {
                    INSPECTIONS.remove(shell);
                    return "";
                }
                out.append("C|id=").append(field(candidate.id))
                    .append("|fp=").append(candidate.fingerprint)
                    .append("|sx=").append(candidate.sourceX)
                    .append("|sy=").append(candidate.sourceY)
                    .append("|sz=").append(candidate.sourceZ)
                    .append("|x=").append(candidate.x)
                    .append("|y=").append(candidate.y)
                    .append("|z=").append(candidate.z)
                    .append("|reachable=").append(candidate.index < 0
                        ? fluidInspectionReachable(shell, candidate.square.get()) ? 1 : 0
                        : SAONeeds.containerAccessibleNow(shell, candidate.container.get()) ? 1 : 0).append('\n');
            }
            INSPECTIONS.put(shell, bindings);
            return out.append("E\n").toString();
        } catch (Throwable unavailable) {
            INSPECTIONS.remove(shell);
            SAOAgent.log("world inspection candidates threw: " + unavailable);
            return "";
        }
    }

    /** Caller owns current social permission; this owns exact native access and loot opening. */
    public static synchronized String inspectContainer(IsoPlayer shell, String sourceId,
            String fingerprint, int x, int y, int z) {
        if (transactionActive) return "BUSY";
        if (!inspectionActor(shell)) return "NO_LIVE_BODY";
        if (GameClient.client || GameServer.server) return "SERVER_AUTHORITY_REQUIRED";
        var bindings = INSPECTIONS.get(shell);
        InspectionBinding binding = bindings == null ? null : bindings.get(sourceId);
        if (binding == null || !binding.fingerprint.equals(fingerprint)) return "NOT_OFFERED";
        transactionActive = true;
        try {
            IsoGridSquare square = shell.getCell().getGridSquare(x, y, z);
            IsoObject object = binding.object.get();
            ItemContainer container = binding.container.get();
            if (binding.index < 0) {
                if (object == null || square == null || square != binding.square.get()
                        || object.getSquare() != square || !square.getObjects().contains(object)
                        || object.getFluidContainer() != binding.fluid.get()
                        || !sourceId.equals("F:" + object.getModData().rawget(SOURCE_TOKEN))
                        || !fingerprint.equals(fluidFingerprint(square, object, sourceId.substring(2)))) return "SOURCE_CHANGED";
                if ((object instanceof IsoThumpable locked && locked.isLockedToCharacter(shell))
                        || !fluidInspectionReachable(shell, square)) return "ACCESS_REFUSED";
                var chunk = square.getChunk();
                if (chunk == null || shell.getCell().getChunk(chunk.wx, chunk.wy) != chunk) return "NOT_LOADED";
                Snapshot snapshot = scan(chunk, false);
                Source source = snapshot.byId.get(sourceId);
                if (source == null || !"fluid".equals(source.kind) || !fingerprint.equals(source.fingerprint)) return "SOURCE_CHANGED";
                binding.observedRevision = source.revision;
                return "I|source=" + field(sourceId) + "\n" + encode(snapshot);
            }
            if (object == null || container == null || square == null
                    || square != binding.square.get() || object.getSquare() != square
                    || !square.getObjects().contains(object)
                    || binding.index >= object.getContainerCount()
                    || object.getContainerByIndex(binding.index) != container
                    || container.getParent() != object || container.getSourceGrid() != square
                    || !sourceId.equals(privateContainerId(object, binding.index))
                    || !fingerprint.equals(containerFingerprint(square, object, container,
                        binding.index, sourceId.split(":")[1]))) return "SOURCE_CHANGED";
            if ((object instanceof IsoThumpable locked && locked.isLockedToCharacter(shell))
                    || !SAONeeds.containerAccessibleNow(shell, container)) return "ACCESS_REFUSED";
            IsoChunk chunk = square.getChunk();
            if (chunk == null || shell.getCell().getChunk(chunk.wx, chunk.wy) != chunk) {
                return "NOT_LOADED";
            }
            // ISInventoryPage.checkExplored: native fill uses the actual opener.
            // An attempted roll is terminal even if a mod throws partway through;
            // do not roll it twice. No successful inspection is emitted on error.
            if (!container.isExplored()) {
                try { ItemPickerJava.fillContainer(container, shell); }
                finally { container.setExplored(true); }
            }
            Snapshot snapshot = scan(chunk, false);
            Source source = snapshot.byId.get(sourceId);
            if (source == null || !source.explored
                    || !fingerprint.equals(source.fingerprint)) return "SOURCE_CHANGED";
            binding.observedRevision = source.revision;
            return "I|source=" + field(sourceId) + "\n" + encode(snapshot);
        } catch (Throwable unavailable) {
            SAOAgent.log("world container inspection threw: " + unavailable);
            return "INSPECTION_FAILED";
        } finally {
            transactionActive = false;
        }
    }

    private static boolean inspectionActor(IsoPlayer shell) {
        return shell != null && !shell.isDead() && !shell.isAsleep()
            && shell.getCell() != null && shell.getCell() == currentCell()
            && shell.getCurrentSquare() != null
            && shell.getCell().getGridSquare((int) Math.floor(shell.getX()),
                (int) Math.floor(shell.getY()), (int) Math.floor(shell.getZ()))
                == shell.getCurrentSquare();
    }

    /** An explored bit belongs to the world, not to every person's knowledge.
     * Only exact private evidence can expose items through a decision view. */
    static synchronized boolean knowsContainerContents(IsoPlayer person,
            IsoObject object, ItemContainer container, int index) {
        try {
            if (person == null || object == null || container == null
                    || !container.isExplored() || object.getContainerByIndex(index) != container
                    || container.getParent() != object) return false;
            IsoGridSquare square = object.getSquare();
            if (square == null || square.getCell() != person.getCell()) return false;
            String id = privateContainerId(object, index);
            String token = id.split(":")[1];
            String fingerprint = containerFingerprint(square, object, container, index, token);
            var bindings = INSPECTIONS.get(person);
            InspectionBinding own = bindings == null ? null : bindings.get(id);
            String observed = own != null && own.object.get() == object
                && own.container.get() == container && own.fingerprint.equals(fingerprint)
                ? own.observedRevision : null;
            var remembered = rememberedContainerRevisions(person, id, fingerprint);
            if (observed == null && remembered.isEmpty()) return false;
            String current = containerSourceKnown(square, object, container, index, token).revision;
            return current.equals(observed) || remembered.contains(current);
        } catch (Throwable unavailable) {
            return false;
        }
    }

    private static se.krka.kahlua.vm.KahluaTable table(Object value) {
        return value instanceof se.krka.kahlua.vm.KahluaTable result ? result : null;
    }

    private static java.util.Set<String> rememberedContainerRevisions(IsoPlayer person, String id,
            String fingerprint) {
        var revisions = new java.util.HashSet<String>();
        var env = zombie.Lua.LuaManager.env;
        var sao = env == null ? null : table(env.rawget("SAO"));
        var perception = sao == null ? null : table(sao.rawget("Perception"));
        var beliefs = perception == null ? null : table(perception.rawget("beliefs"));
        Object personId = person.getModData().rawget("SAOPersonId");
        var mind = beliefs == null || !(personId instanceof String)
            ? null : table(beliefs.rawget(personId));
        var known = mind == null ? null : table(mind.rawget("known"));
        if (known == null) return revisions;
        var places = known.iterator();
        while (places.advance()) {
            var place = table(places.getValue());
            var facts = place == null ? null : table(place.rawget("sourceFacts"));
            var fact = facts == null ? null : table(facts.rawget(id));
            if (fact != null && fingerprint.equals(fact.rawget("fingerprint"))
                    && Boolean.TRUE.equals(fact.rawget("explored"))
                    && ("available".equals(fact.rawget("state")) || "spent".equals(fact.rawget("state")))
                    && fact.rawget("revision") instanceof String revision) revisions.add(revision);
        }
        return revisions;
    }

    /**
     * Resolve an observed identity back to the current loaded engine object
     * and select one reachable interaction square. This proves identity and
     * revision only; bindAction performs the actor-specific access proof after
     * locomotion reaches the returned square.
     */
    public static synchronized String actionTarget(IsoPlayer shell, String sourceId,
            String fingerprint, String revision, int itemId, String itemType,
            int expectedX, int expectedY, int expectedZ) {
        try {
            Located located = locate(shell, sourceId, fingerprint, revision,
                itemId, itemType, expectedX, expectedY, expectedZ);
            IsoGridSquare target = located.vehicle == null
                ? interactionSquare(shell, located.square)
                : vehicleInteractionSquare(located.vehicle, located.vehiclePart);
            if (target == null) return "NO_INTERACTION_POINT";
            return "READY:" + target.getX() + ":" + target.getY() + ":"
                + target.getZ() + ":" + located.square.getX() + ":"
                + located.square.getY() + ":" + located.square.getZ();
        } catch (ActionRefusal refusal) {
            return refusal.code;
        } catch (Throwable throwable) {
            SAOAgent.log("world source target threw: " + throwable);
            return "FAILED";
        }
    }

    /** Refill a carried vessel from an exact privately remembered fluid fixture. */
    public static synchronized String refillTarget(IsoPlayer shell, String sourceId,
            String fingerprint, String revision, int x, int y, int z) {
        try {
            if (revision == null || revision.isBlank()) return "BAD_REFILL_REQUEST";
            IsoObject object = refillFixture(shell, sourceId, fingerprint, revision, x, y, z);
            IsoGridSquare target = interactionSquare(shell, object.getSquare());
            if (target == null) return "NO_INTERACTION_POINT";
            return "READY:" + target.getX() + ":" + target.getY() + ":" + target.getZ();
        } catch (ActionRefusal refusal) { return refusal.code; }
        catch (Throwable unavailable) {
            SAOAgent.log("world refill target threw: " + unavailable);
            return "FAILED";
        }
    }

    public static synchronized Object refillObject(IsoPlayer shell, String sourceId,
            String fingerprint, String revision, int x, int y, int z) {
        try {
            if (revision == null || revision.isBlank()) return null;
            IsoObject object = refillFixture(shell, sourceId, fingerprint, revision, x, y, z);
            return refillWithinReach(shell, object.getSquare()) ? object : null;
        } catch (ActionRefusal refusal) { return null; }
        catch (Throwable unavailable) {
            SAOAgent.log("world refill object threw: " + unavailable);
            return null;
        }
    }

    /** Own transfer changes the fluid revision; physical identity and access remain exact. */
    public static synchronized boolean refillValid(IsoPlayer shell, IsoObject object,
            String sourceId, String fingerprint, int x, int y, int z) {
        try {
            return refillFixture(shell, sourceId, fingerprint, null, x, y, z) == object
                && refillWithinReach(shell, object.getSquare());
        } catch (ActionRefusal refusal) { return false; }
        catch (Throwable unavailable) {
            SAOAgent.log("world refill validation threw: " + unavailable);
            return false;
        }
    }

    private static IsoObject refillFixture(IsoPlayer shell, String sourceId,
            String fingerprint, String revision, int x, int y, int z) throws ActionRefusal {
        if (!inspectionActor(shell) || sourceId == null || !sourceId.startsWith("F:")
                || sourceId.length() <= 2) throw new ActionRefusal("BAD_REFILL_REQUEST");
        var remembered = rememberedContainerRevisions(shell, sourceId, fingerprint);
        if (remembered.isEmpty() || (revision != null && !remembered.contains(revision))) {
            throw new ActionRefusal("NOT_PRIVATELY_OBSERVED");
        }
        IsoGridSquare square = shell.getCell().getGridSquare(x, y, z);
        if (square == null || square.getCell() != shell.getCell()) throw new ActionRefusal("NOT_LOADED");
        String token = sourceId.substring(2);
        for (int index = 0; index < square.getObjects().size(); index++) {
            IsoObject object = square.getObjects().get(index);
            if (object == null || !token.equals(object.getModData().rawget(SOURCE_TOKEN))) continue;
            Source physical = objectFluidSource(new Snapshot(Math.floorDiv(x, CHUNK_SIZE),
                Math.floorDiv(y, CHUNK_SIZE)), square, object);
            if (!fingerprint.equals(physical.fingerprint)) throw new ActionRefusal("FINGERPRINT_CHANGED");
            if (revision != null && !revision.equals(physical.revision)) throw new ActionRefusal("REVISION_CHANGED");
            var fluid = object.getPrimaryFluid();
            if (object.isTaintedWater() || fluid != null && fluid.isPoisonous()
                    || object.getFluidAmount() > 0 && !object.hasWater()
                    || revision != null && object.getFluidAmount() <= 0) throw new ActionRefusal("NO_CLEAN_WATER");
            if (object instanceof IsoThumpable locked && locked.isLockedToCharacter(shell)
                    || GameClient.client && !zombie.iso.areas.SafeHouse.isSafehouseAllowInteract(square, shell)) {
                throw new ActionRefusal("ACCESS_REFUSED");
            }
            return object;
        }
        throw new ActionRefusal("SOURCE_MISSING");
    }

    private static boolean refillWithinReach(IsoPlayer shell, IsoGridSquare square) {
        IsoGridSquare here = shell == null ? null : shell.getCurrentSquare();
        return here != null && square != null && square.getCell() == shell.getCell()
            && shell.getCell().getGridSquare(square.getX(), square.getY(), square.getZ()) == square
            && square.getZ() == (int) Math.floor(shell.getZ())
            && Math.abs(shell.getX() - (square.getX() + 0.5f)) <= 1.6f
            && Math.abs(shell.getY() - (square.getY() + 0.5f)) <= 1.6f && here.canReachTo(square);
    }

    public static synchronized String plumbTarget(IsoPlayer shell, String sourceId,
            String fingerprint, String revision, int x, int y, int z) {
        try {
            if (revision == null || revision.isBlank()) return "BAD_PLUMB_REQUEST";
            IsoObject object = plumbFixture(shell, sourceId, fingerprint, revision, x, y, z, false);
            IsoGridSquare target = interactionSquare(shell, object.getSquare());
            return target == null ? "NO_INTERACTION_POINT"
                : "READY:" + target.getX() + ":" + target.getY() + ":" + target.getZ();
        } catch (ActionRefusal refusal) { return refusal.code; }
        catch (Throwable unavailable) { SAOAgent.log("world plumb target threw: " + unavailable); return "FAILED"; }
    }

    public static synchronized Object plumbObject(IsoPlayer shell, String sourceId,
            String fingerprint, String revision, int x, int y, int z) {
        try {
            if (revision == null || revision.isBlank()) return null;
            IsoObject object = plumbFixture(shell, sourceId, fingerprint, revision, x, y, z, false);
            return refillWithinReach(shell, object.getSquare()) ? object : null;
        } catch (Throwable unavailable) { return null; }
    }

    /** Connection changes the revision; exact identity and body custody persist. */
    public static synchronized boolean plumbValid(IsoPlayer shell, IsoObject object,
            String sourceId, String fingerprint, int x, int y, int z, boolean completedConnection) {
        try {
            return plumbFixture(shell, sourceId, fingerprint, null, x, y, z, completedConnection) == object
                && refillWithinReach(shell, object.getSquare());
        } catch (Throwable unavailable) { return false; }
    }

    private static IsoObject plumbFixture(IsoPlayer shell, String sourceId, String fingerprint,
            String revision, int x, int y, int z, boolean completedConnection) throws ActionRefusal {
        if (!inspectionActor(shell) || sourceId == null || !sourceId.startsWith("F:")
                || sourceId.length() <= 2 || fingerprint == null) throw new ActionRefusal("BAD_PLUMB_REQUEST");
        var remembered = rememberedContainerRevisions(shell, sourceId, fingerprint);
        if (remembered.isEmpty() || revision != null && !remembered.contains(revision)) {
            throw new ActionRefusal("NOT_PRIVATELY_OBSERVED");
        }
        IsoGridSquare square = shell.getCell().getGridSquare(x, y, z);
        if (square == null || square.getCell() != shell.getCell()) throw new ActionRefusal("NOT_LOADED");
        String token = sourceId.substring(2);
        for (int index = 0; index < square.getObjects().size(); index++) {
            IsoObject object = square.getObjects().get(index);
            if (object == null || object.getSquare() != square
                    || !token.equals(object.getModData().rawget(SOURCE_TOKEN))) continue;
            Source physical = objectFluidSource(new Snapshot(Math.floorDiv(x, CHUNK_SIZE), Math.floorDiv(y, CHUNK_SIZE)), square, object);
            if (!fingerprint.equals(physical.fingerprint)) throw new ActionRefusal("FINGERPRINT_CHANGED");
            if (revision != null && !revision.equals(physical.revision)) throw new ActionRefusal("REVISION_CHANGED");
            if (object instanceof IsoThumpable locked && locked.isLockedToCharacter(shell)
                    || GameClient.client && !zombie.iso.areas.SafeHouse.isSafehouseAllowInteract(square, shell)) {
                throw new ActionRefusal("ACCESS_REFUSED");
            }
            if (completedConnection ? !object.getUsesExternalWaterSource()
                    || !Boolean.FALSE.equals(object.getModData().rawget("canBeWaterPiped")) : !plumbingEligible(object)) {
                throw new ActionRefusal("PLUMBING_UNAVAILABLE");
            }
            return object;
        }
        throw new ActionRefusal("SOURCE_MISSING");
    }

    private static boolean waterPipedSprite(IsoObject object) {
        return object.getProperties() != null
            && object.getProperties().has(zombie.iso.SpriteDetails.IsoFlagType.waterPiped);
    }

    /** Local observable affordance only; supplier and mains truth belong to admission. */
    private static String plumbingState(IsoObject object) {
        if (object.getUsesExternalWaterSource()) {
            Object marker = object.getModData().rawget("canBeWaterPiped");
            return marker instanceof Boolean || waterPipedSprite(object) || object.getFluidCapacity() > 0
                ? "connected" : "";
        }
        IsoGridSquare square = object.getSquare();
        return square != null && square.isInARoom()
            && (Boolean.TRUE.equals(object.getModData().rawget("canBeWaterPiped")) || waterPipedSprite(object))
            ? "unconnected" : "";
    }

    /** Installed ISWorldObjectContextMenuLogic.fetch's two plumbing branches. */
    private static boolean plumbingEligible(IsoObject object) {
        IsoGridSquare square = object.getSquare();
        if (square == null || !square.isInARoom() || object.getUsesExternalWaterSource()) return false;
        boolean marked = Boolean.TRUE.equals(object.getModData().rawget("canBeWaterPiped"));
        boolean pipedSprite = waterPipedSprite(object);
        if (!marked && !pipedSprite) return false;
        if (object.FindExternalWaterSource() != null) return true;
        double days = zombie.GameTime.getInstance().getWorldAgeHours() / 24.0
            + (zombie.SandboxOptions.instance.getTimeSinceApo() - 1) * 30;
        return pipedSprite && marked && square.getRoom() != null
            && days < zombie.SandboxOptions.instance.waterShutModifier.getValue();
    }

    /** Personal generator identity; reached inspection alone supplies machine state. */
    private static boolean householdIncluded(IsoObject object) {
        if (object == null) return false;
        Object owned = object.getModData().rawget("SAOHouseholdSource");
        return owned != null ? Boolean.TRUE.equals(owned)
            : Boolean.TRUE.equals(object.getModData().rawget("LGEPInclude"));
    }
    private static boolean networkStockAvailable(InventoryItem item) {
        if(item==null||item.hasModData()&&item.getModData().rawget("SAOWaterNetworkPart")!=null)return false;
        var sao=table(zombie.Lua.LuaManager.env.rawget("SAO"));var owner=sao==null?null:table(sao.rawget("HouseholdService"));
        Object method=owner==null?null:owner.rawget("networkStockAvailable");
        return method==null||Boolean.TRUE.equals(zombie.Lua.LuaManager.caller.pcallBoolean(zombie.Lua.LuaManager.thread,method,new Object[]{item}));
    }
    private static boolean householdPumpCurrent(IsoObject object) {
        if(!(object instanceof IsoWorldInventoryObject world)||world.getItem()==null
            ||!"SAO.WaterPump".equals(world.getItem().getFullType())||world.getItem().getWorldItem()!=world
            ||world.getItem().getScriptItem()!=zombie.scripting.ScriptManager.instance.getItem("SAO.WaterPump"))return false;
        var sao=table(zombie.Lua.LuaManager.env.rawget("SAO"));var owner=sao==null?null:table(sao.rawget("HouseholdService"));
        Object method=owner==null?null:owner.rawget("pumpCurrent");
        return method!=null&&Boolean.TRUE.equals(zombie.Lua.LuaManager.caller.pcallBoolean(zombie.Lua.LuaManager.thread,method,new Object[]{object}));
    }
    private static boolean utilityObjectLive(IsoObject object,IsoGridSquare square) {
        return object!=null&&square!=null&&object.getSquare()==square&&(square.getObjects().contains(object)
            ||object instanceof IsoWorldInventoryObject world&&square.getWorldObjects().contains(world)
                &&world.getItem()!=null&&world.getItem().getWorldItem()==world);
    }
    private static List<IsoObject> utilityObjects(IsoGridSquare square) {
        var out=new ArrayList<IsoObject>();
        for(int i=0;i<square.getObjects().size();i++)out.add(square.getObjects().get(i));
        for(var world:square.getWorldObjects())if(!out.contains(world))out.add(world);
        return out;
    }
    private static boolean pumpFacetCurrent(UtilityBinding binding,IsoObject object) {
        if(binding.pumpItem!=null){var item=binding.pumpItem.get();
            return item!=null&&object instanceof IsoWorldInventoryObject world&&world.getItem()==item
                &&item.getScriptItem()==binding.pumpScript&&householdPumpCurrent(object);
        }
        return binding.pumpFluid!=null&&binding.pumpFluid.get()==object.getFluidContainer()&&householdIncluded(object);
    }

    public static synchronized String generatorCandidates(SAOIsoPlayerShell shell) {
        if (SAOConceptObservation.actor(shell) == null || transactionActive) return "";
        var eye = shell.getCurrentSquare();
        Snapshot snapshot = new Snapshot(Math.floorDiv(eye.getX(), CHUNK_SIZE), Math.floorDiv(eye.getY(), CHUNK_SIZE));
        snapshot.mode = "visible-generator";
        int count = 0;
        for (int distance = 0; distance <= INSPECTION_RANGE && count < 32; distance++) {
            for (int dy = -distance; dy <= distance && count < 32; dy++) for (int dx = -distance; dx <= distance && count < 32; dx++) {
                if (Math.max(Math.abs(dx), Math.abs(dy)) != distance) continue;
                var square = shell.getCell().getGridSquare(eye.getX() + dx, eye.getY() + dy, eye.getZ());
                if (!SAOPerceptionScanner.canSeeWorldSquareNow(shell, square, INSPECTION_RANGE)) continue;
                for (int index = 0; index < square.getObjects().size() && count < 32; index++) {
                    var object = square.getObjects().get(index);
                    if (!(object instanceof IsoGenerator generator) || generator.getSquare() != square) continue;
                    Source source = generatorSource(snapshot, generator, utilityReached(shell, square));
                    rememberUtility(shell, object, source); snapshot.add(source); count++;
                }
            }
        }
        snapshot.finish(); return encode(snapshot);
    }

    public static synchronized String generatorTarget(SAOIsoPlayerShell shell, String id, String fingerprint,
            String revision, int x, int y, int z, String operation) {
        try {
            if (revision == null || revision.isBlank()) return "BAD_GENERATOR_REQUEST";
            if (!generatorOperation(operation)) return "BAD_GENERATOR_OPERATION";
            var generator = generatorIdentityFixture(shell, id, fingerprint, revision, x, y, z);
            var square = interactionSquare(shell, generator.getSquare());
            return square == null ? "NO_INTERACTION_POINT" : "READY:" + square.getX() + ":" + square.getY() + ":" + square.getZ();
        } catch (ActionRefusal refusal) { return refusal.code; }
        catch (Throwable unavailable) { SAOAgent.log("generator target threw: " + unavailable); return "FAILED"; }
    }

    public static synchronized Object generatorObject(SAOIsoPlayerShell shell, String id, String fingerprint,
            String revision, int x, int y, int z, String operation) {
        try {
            if (revision == null || revision.isBlank()) return null;
            var generator = "inspect".equals(operation)
                ? generatorIdentityFixture(shell, id, fingerprint, revision, x, y, z)
                : generatorFixture(shell, id, fingerprint, revision, x, y, z, operation);
            return "verify-power".equals(operation) || utilityReached(shell, generator.getSquare()) ? generator : null;
        } catch (ActionRefusal refusal) { return null; }
        catch (Throwable unavailable) { SAOAgent.log("generator object threw: " + unavailable); return null; }
    }

    public static synchronized boolean generatorValid(SAOIsoPlayerShell shell, IsoGenerator generator,
            String id, String fingerprint, int x, int y, int z, String operation) {
        try {
            return generatorFixture(shell, id, fingerprint, null, x, y, z, operation) == generator
                && ("verify-power".equals(operation) || utilityReached(shell, generator.getSquare()));
        } catch (ActionRefusal refusal) { return false; }
        catch (Throwable unavailable) { SAOAgent.log("generator valid threw: " + unavailable); return false; }
    }

    private static IsoGenerator generatorFixture(SAOIsoPlayerShell shell, String id, String fingerprint,
            String revision, int x, int y, int z, String operation) throws ActionRefusal {
        var generator = generatorIdentityFixture(shell,id,fingerprint,revision,x,y,z);
        var binding = utilityBinding(shell, id, fingerprint, "J:");
        if (!generatorOperation(operation)) throw new ActionRefusal("BAD_GENERATOR_OPERATION");
        var square = shell.getCell().getGridSquare(x, y, z);
        boolean inspected = revision == null || Boolean.TRUE.equals(binding.revisions.get(revision));
        Source physical = generatorSource(new Snapshot(Math.floorDiv(x, CHUNK_SIZE), Math.floorDiv(y, CHUNK_SIZE)), generator, inspected);
        if (!fingerprint.equals(physical.fingerprint)) throw new ActionRefusal("FINGERPRINT_CHANGED");
        if (revision != null && !operation.equals("verify-power") && !revision.equals(physical.revision)) throw new ActionRefusal("REVISION_CHANGED");
        if (!operation.equals("inspect") && (revision == null ? !binding.revisions.containsValue(Boolean.TRUE)
                : !Boolean.TRUE.equals(binding.revisions.get(revision)))) throw new ActionRefusal("INSPECTION_REQUIRED");
        if (GameClient.client && !zombie.iso.areas.SafeHouse.isSafehouseAllowInteract(square, shell)) throw new ActionRefusal("ACCESS_REFUSED");
        boolean knowledge = shell.getPerkLevel(zombie.characters.skills.PerkFactory.Perks.Electricity) >= 3
            || shell.isRecipeActuallyKnown("Generator");
        if ((operation.equals("repair") || operation.equals("connect")) && !knowledge) throw new ActionRefusal("GENERATOR_KNOWLEDGE_REQUIRED");
        boolean ready = generatorStageReady(generator, square, operation);
        if (!ready) throw new ActionRefusal("GENERATOR_STAGE_UNAVAILABLE");
        return generator;
    }

    private static boolean generatorStageReady(IsoGenerator generator, IsoGridSquare square, String operation) {
        return switch (operation) {
            case "inspect" -> true;
            case "repair" -> !generator.isActivated() && generator.getCondition() < 100;
            case "fuel" -> !generator.isActivated() && generator.getFuel() < generator.getMaxFuel();
            case "connect" -> !generator.isActivated() && !generator.isConnected();
            case "activate" -> !generator.isActivated() && generator.isConnected() && generator.getFuel() > 0
                && generator.getCondition() > 0 && square.isOutside();
            case "verify-power", "verify-service" -> generator.isActivated() && generator.isConnected() && generator.getFuel() > 0
                && generator.getCondition() > 0 && square.isOutside();
            case "inspect-load" -> true;
            case "shed-load", "breaker-open" -> generator.isActivated() && generator.isConnected()
                && generator.getFuel() > 0 && generator.getCondition() > 0;
            case "breaker-reset" -> !generator.isActivated() && generator.isConnected() && generator.getFuel() > 0
                && generator.getCondition() > 0 && square.isOutside()
                && Boolean.TRUE.equals(generator.getModData().rawget("SAOElectricalBreaker"));
            default -> false;
        };
    }

    /** Remembered identity admits travel and reached reinspection, never physical stage effects. */
    private static IsoGenerator generatorIdentityFixture(SAOIsoPlayerShell shell,String id,String fingerprint,
            String revision,int x,int y,int z) throws ActionRefusal {
        var binding=utilityBinding(shell,id,fingerprint,"J:");
        if (revision!=null && (revision.isBlank() || !binding.revisions.containsKey(revision))) throw new ActionRefusal("NOT_PRIVATELY_OBSERVED");
        var square=shell.getCell().getGridSquare(x,y,z);var object=binding.object.get();
        if (!(object instanceof IsoGenerator generator) || square==null || binding.square.get()!=square
                || object.getSquare()!=square || !square.getObjects().contains(object)
                || !id.substring(2).equals(object.getModData().rawget(SOURCE_TOKEN))) throw new ActionRefusal("SOURCE_CHANGED");
        Source identity=utilitySource(new Snapshot(Math.floorDiv(x,CHUNK_SIZE),Math.floorDiv(y,CHUNK_SIZE)),object,"J:","generator");
        if (!fingerprint.equals(identity.fingerprint)) throw new ActionRefusal("FINGERPRINT_CHANGED");
        if (GameClient.client && !zombie.iso.areas.SafeHouse.isSafehouseAllowInteract(square,shell)) throw new ActionRefusal("ACCESS_REFUSED");
        return generator;
    }

    private static boolean generatorOperation(String operation) {
        return "inspect".equals(operation) || "repair".equals(operation) || "fuel".equals(operation)
            || "connect".equals(operation) || "activate".equals(operation) || "verify-power".equals(operation)
            || "inspect-load".equals(operation) || "shed-load".equals(operation) || "breaker-open".equals(operation)
            || "breaker-reset".equals(operation) || "verify-service".equals(operation);
    }

    private static boolean utilityReached(SAOIsoPlayerShell shell, IsoGridSquare square) {
        return refillWithinReach(shell, square) && Math.pow(shell.getX() - square.getX() - .5f, 2)
            + Math.pow(shell.getY() - square.getY() - .5f, 2) < 4
            && SAOPerceptionScanner.canSeeWorldSquareNow(shell, square, INSPECTION_RANGE);
    }

    public static synchronized String generatorConsumer(SAOIsoPlayerShell shell, IsoObject object) {
        if (SAOConceptObservation.actor(shell) == null || object == null || object.getSquare() == null
                || !utilityReached(shell, object.getSquare()) || object.getCell() != shell.getCell()
                || !object.getSquare().getObjects().contains(object) || !object.couldBePoweredByGenerator()) return "";
        var square = object.getSquare();
        Snapshot snapshot = new Snapshot(Math.floorDiv(square.getX(), CHUNK_SIZE), Math.floorDiv(square.getY(), CHUNK_SIZE));
        snapshot.mode = "reached-power-consumer";
        Source source = powerConsumerSource(snapshot, object); rememberUtility(shell, object, source);
        snapshot.add(source); snapshot.finish(); return encode(snapshot);
    }

    public static synchronized boolean generatorConsumerPowered(SAOIsoPlayerShell shell, IsoGenerator generator,
            String id, String fingerprint, int x, int y, int z) {
        try {
            var consumerBinding = utilityBinding(shell, id, fingerprint, "E:");
            var consumer = consumerBinding.object.get(); var square = shell.getCell().getGridSquare(x, y, z);
            if (consumer == null || square == null || consumerBinding.square.get() != square || consumer.getSquare() != square
                || !utilityObjectLive(consumer,square) || !utilityReached(shell, square)
                || !id.substring(2).equals(consumer.getModData().rawget(SOURCE_TOKEN))) return false;
            Source current = powerConsumerSource(new Snapshot(Math.floorDiv(x, CHUNK_SIZE), Math.floorDiv(y, CHUNK_SIZE)), consumer);
            if (!fingerprint.equals(current.fingerprint) || generator == null || generator.getSquare() == null) return false;
            var genSquare = generator.getSquare();
            String token = (String) generator.getModData().rawget(SOURCE_TOKEN);
            Source gen = generatorSource(new Snapshot(Math.floorDiv(genSquare.getX(), CHUNK_SIZE), Math.floorDiv(genSquare.getY(), CHUNK_SIZE)), generator, true);
            var genBinding = utilityBinding(shell, "J:" + token, gen.fingerprint, "J:");
            return genBinding.object.get() == generator && genBinding.square.get() == genSquare
                && generator.getCell() == shell.getCell() && shell.getCell().getGridSquare(genSquare.getX(), genSquare.getY(), genSquare.getZ()) == genSquare
                && genSquare.getObjects().contains(generator) && generator.isConnected() && generator.isActivated()
                && generator.getFuel() > 0 && generator.getCondition() > 0 && genSquare.isOutside()
                && IsoGenerator.isPoweringSquare(genSquare.getX(), genSquare.getY(), genSquare.getZ(), x, y, z)
                && square.haveElectricity() && current.powered == Boolean.TRUE;
        } catch (ActionRefusal refusal) { return false; }
        catch (Throwable unavailable) { SAOAgent.log("generator consumer power threw: " + unavailable); return false; }
    }

    public static synchronized String generatorConsumerTarget(SAOIsoPlayerShell shell, String id, String fingerprint,
            String revision, int x, int y, int z) {
        try {
            IsoObject object = generatorConsumerFixture(shell, id, fingerprint, revision, x, y, z);
            var square = interactionSquare(shell, object.getSquare());
            return square == null ? "NO_INTERACTION_POINT" : "READY:" + square.getX() + ":" + square.getY() + ":" + square.getZ();
        } catch (ActionRefusal refusal) { return refusal.code; }
        catch (Throwable unavailable) { SAOAgent.log("generator consumer target threw: " + unavailable); return "FAILED"; }
    }

    public static synchronized Object generatorConsumerObject(SAOIsoPlayerShell shell, String id, String fingerprint,
            String revision, int x, int y, int z) {
        try {
            var object = generatorConsumerFixture(shell, id, fingerprint, revision, x, y, z);
            return utilityReached(shell, object.getSquare()) ? object : null;
        } catch (ActionRefusal refusal) { return null; }
        catch (Throwable unavailable) { SAOAgent.log("generator consumer object threw: " + unavailable); return null; }
    }

    private static IsoObject generatorConsumerFixture(SAOIsoPlayerShell shell, String id, String fingerprint,
            String revision, int x, int y, int z) throws ActionRefusal {
        var binding = utilityBinding(shell, id, fingerprint, "E:");
        if (revision == null || !binding.revisions.containsKey(revision)) throw new ActionRefusal("NOT_PRIVATELY_OBSERVED");
        var square = shell.getCell().getGridSquare(x,y,z); var object = binding.object.get();
        if (square == null || object == null || binding.square.get() != square || object.getSquare() != square
                || !utilityObjectLive(object,square) || !id.substring(2).equals(object.getModData().rawget(SOURCE_TOKEN))) throw new ActionRefusal("SOURCE_CHANGED");
        var source = powerConsumerSource(new Snapshot(Math.floorDiv(x,CHUNK_SIZE),Math.floorDiv(y,CHUNK_SIZE)),object);
        if (!fingerprint.equals(source.fingerprint)) throw new ActionRefusal("FINGERPRINT_CHANGED");
        // Power may change during the owned generator sequence. Identity and the exact acquired revision remain binding.
        if (!(binding.pumpFacet?pumpFacetCurrent(binding,object):object.couldBePoweredByGenerator()) || GameClient.client && !zombie.iso.areas.SafeHouse.isSafehouseAllowInteract(square,shell)) throw new ActionRefusal("ACCESS_REFUSED");
        return object;
    }

    private static UtilityBinding utilityBinding(SAOIsoPlayerShell shell, String id, String fingerprint, String prefix) throws ActionRefusal {
        String actor = SAOConceptObservation.actor(shell);
        var bindings = UTILITY_BINDINGS.get(shell); var binding = bindings == null ? null : bindings.get(id);
        if (actor == null || id == null || !id.startsWith(prefix) || id.length() <= 2 || fingerprint == null) throw new ActionRefusal("NOT_PRIVATELY_OBSERVED");
        if (binding == null || binding.object.get() == null || binding.square.get() == null) {
            binding = restoreUtilityBinding(shell,actor,id,fingerprint,prefix);
        }
        if (binding == null || !actor.equals(binding.actor) || !fingerprint.equals(binding.fingerprint)) throw new ActionRefusal("NOT_PRIVATELY_OBSERVED");
        return binding;
    }

    private static UtilityBinding restoreUtilityBinding(SAOIsoPlayerShell shell,String actor,String id,String fingerprint,String prefix) {
        var sao=table(zombie.Lua.LuaManager.env.rawget("SAO"));var perception=sao==null?null:table(sao.rawget("Perception"));
        var beliefs=perception==null?null:table(perception.rawget("beliefs"));var mind=beliefs==null?null:table(beliefs.rawget(actor));
        var known=mind==null?null:table(mind.rawget("known"));if(known==null)return null;
        var places=known.iterator();
        while(places.advance()) {
            var place=table(places.getValue());var facts=place==null?null:table(place.rawget("sourceFacts"));var fact=facts==null?null:table(facts.rawget(id));
            if(fact==null || !fingerprint.equals(fact.rawget("fingerprint")) || !(fact.rawget("revision") instanceof String revision) || revision.isBlank()
                    || !(prefix.equals("J:")?"generator":"power-consumer").equals(fact.rawget("kind"))
                    || fact.rawget("actorId")!=null && !actor.equals(fact.rawget("actorId"))
                    || !id.equals(fact.rawget("sourceId")) && !id.equals(fact.rawget("id")))continue;
            Object rx=fact.rawget("x"),ry=fact.rawget("y"),rz=fact.rawget("z");
            if(!(rx instanceof Number nx)||!(ry instanceof Number ny)||!(rz instanceof Number nz))continue;
            double x=nx.doubleValue(),y=ny.doubleValue(),z=nz.doubleValue();
            if(!Double.isFinite(x)||!Double.isFinite(y)||!Double.isFinite(z)||x!=Math.rint(x)||y!=Math.rint(y)||z!=Math.rint(z)
                    ||Math.abs(x)>Integer.MAX_VALUE||Math.abs(y)>Integer.MAX_VALUE||Math.abs(z)>Integer.MAX_VALUE)continue;
            var square=shell.getCell().getGridSquare((int)x,(int)y,(int)z);if(square==null || square.getCell()!=shell.getCell())continue;
            for(var object:utilityObjects(square)) {
                if(object==null||object.getSquare()!=square||!id.substring(2).equals(object.getModData().rawget(SOURCE_TOKEN))
                        || (prefix.equals("J:")?!(object instanceof IsoGenerator):!object.couldBePoweredByGenerator()&&!householdPumpCurrent(object)))continue;
                var identity=utilitySource(new Snapshot(Math.floorDiv((int)x,CHUNK_SIZE),Math.floorDiv((int)y,CHUNK_SIZE)),object,prefix,prefix.equals("J:")?"generator":"power-consumer");
                if(!fingerprint.equals(identity.fingerprint))continue;
                var binding=new UtilityBinding(actor,object,fingerprint);
                if(householdPumpCurrent(object)) {
                    binding.pumpFacet=true;binding.pumpItem=new java.lang.ref.WeakReference<>(((IsoWorldInventoryObject)object).getItem());
                    binding.pumpScript=((IsoWorldInventoryObject)object).getItem().getScriptItem();
                }
                // Saved inspection is historical person knowledge; reacquire current inspection before any operation.
                binding.revisions.put(revision,Boolean.FALSE);
                if (Boolean.TRUE.equals(fact.rawget("inspected"))) binding.historicalInspections.add(revision);
                var bindings=UTILITY_BINDINGS.computeIfAbsent(shell,ignored->new LinkedHashMap<>());bindings.put(id,binding);
                while(bindings.size()>MAX_INSPECTION_OPTIONS)bindings.remove(bindings.keySet().iterator().next());
                return binding;
            }
        }
        return null;
    }

    private static void rememberUtility(SAOIsoPlayerShell shell, IsoObject object, Source source) {
        var bindings = UTILITY_BINDINGS.computeIfAbsent(shell, ignored -> new LinkedHashMap<>());
        var binding = bindings.get(source.id);
        if (binding == null || binding.object.get() != object || !binding.fingerprint.equals(source.fingerprint)
                || !binding.actor.equals(SAOConceptObservation.actor(shell))) {
            binding = new UtilityBinding(SAOConceptObservation.actor(shell), object, source.fingerprint); bindings.put(source.id, binding);
        }
        binding.revisions.put(source.revision, Boolean.TRUE.equals(source.inspected));
        while (binding.revisions.size() > 16) binding.revisions.remove(binding.revisions.keySet().iterator().next());
        while (bindings.size() > MAX_INSPECTION_OPTIONS) bindings.remove(bindings.keySet().iterator().next());
    }

    private static final class UtilityBinding {
        final String actor, fingerprint;
        final java.lang.ref.WeakReference<IsoObject> object;
        final java.lang.ref.WeakReference<IsoGridSquare> square;
        final LinkedHashMap<String, Boolean> revisions = new LinkedHashMap<>();
        final java.util.Set<String> historicalInspections = new java.util.LinkedHashSet<>();
        final zombie.scripting.objects.Item generatorScript;
        final zombie.scripting.entity.GameEntityScript entityScript;
        boolean pumpFacet;
        java.lang.ref.WeakReference<FluidContainer> pumpFluid;
        java.lang.ref.WeakReference<InventoryItem> pumpItem;
        zombie.scripting.objects.Item pumpScript;
        String serviceRevision,serviceStructure,serviceConsumerId;
        List<ServiceMember> serviceMembers;
        UtilityBinding(String actor, IsoObject object, String fingerprint) {
            this.actor = actor; this.fingerprint = fingerprint;
            this.generatorScript=object instanceof IsoGenerator g?zombie.scripting.ScriptManager.instance.getItem(g.getGeneratorItemType()):null;
            this.entityScript=object.getEntityScript();
            this.object = new java.lang.ref.WeakReference<>(object); this.square = new java.lang.ref.WeakReference<>(object.getSquare());
        }
    }

    private static Source utilitySource(Snapshot snapshot, IsoObject object, String prefix, String kind) {
        var square = object.getSquare(); long building = buildingId(square); String token = sourceToken(snapshot, object);
        String identity = object.getClass().getName() + "|" + value(object.getSpriteName()) + "|" + kind + "|" + building
            + "|" + square.getX() + "|" + square.getY() + "|" + square.getZ() + "|" + token;
        return new Source(prefix + token, digest(identity), kind, square.getX(), square.getY(), square.getZ(), building, true);
    }

    private static Source generatorSource(Snapshot snapshot, IsoGenerator generator, boolean inspected) {
        Source source = utilitySource(snapshot, generator, "J:", "generator"); source.inspected = inspected;
        if (inspected) {
            source.generatorCondition = generator.getCondition(); source.generatorFuel = generator.getFuel(); source.generatorMaxFuel = generator.getMaxFuel();
            source.connected = generator.isConnected(); source.active = generator.isActivated(); source.outside = generator.getSquare().isOutside();
        }
        source.finish(); return source;
    }

    /** Current acquired pair; reach belongs to the operation's physical endpoint. */
    public static synchronized Object electricalServiceObjects(SAOIsoPlayerShell shell,
            String generatorId, String generatorFingerprint, String generatorRevision, int gx, int gy, int gz,
            String consumerId, String consumerFingerprint, String consumerRevision, int cx, int cy, int cz,
            String operation, boolean pre) {
        try {
            boolean consumerEndpoint = "inspect-load".equals(operation) || "shed-load".equals(operation)
                || "verify-service".equals(operation);
            if (!consumerEndpoint && !"breaker-open".equals(operation) && !"breaker-reset".equals(operation)) return null;
            var generator = generatorIdentityFixture(shell, generatorId, generatorFingerprint, generatorRevision, gx, gy, gz);
            var consumer = generatorConsumerFixture(shell, consumerId, consumerFingerprint, consumerRevision, cx, cy, cz);
            if (!IsoGenerator.isPoweringSquare(gx, gy, gz, cx, cy, cz)
                    || !utilityReached(shell, consumerEndpoint ? consumer.getSquare() : generator.getSquare())) return null;
            // Stage readiness samples current native state; the acquired identity revision remains binding.
            if (pre) {
                if (consumerEndpoint) {
                    var binding = utilityBinding(shell, generatorId, generatorFingerprint, "J:");
                    if (!Boolean.TRUE.equals(binding.revisions.get(generatorRevision))
                            && !binding.historicalInspections.contains(generatorRevision)) return null;
                    if (!generatorStageReady(generator, generator.getSquare(), operation)) return null;
                } else if (generatorFixture(shell, generatorId, generatorFingerprint, null, gx, gy, gz, operation) != generator) return null;
            }
            var load = electricalLoad(shell, consumerId, consumerFingerprint, consumer, false);
            if (load == null) return null;
            var row = recipeTable(); row.rawset("generator", generator); row.rawset("consumer", consumer); row.rawset("load", load);
            return row;
        } catch (Throwable unavailable) {
            SAOAgent.log("electrical service pair unavailable: " + unavailable); return null;
        }
    }

    /** An acquired appliance's native rates; this never replaces the engine bill. */
    public static synchronized Object electricalLoad(IsoPlayer body, String id, String fingerprint,
            IsoObject expected) {
        return electricalLoad(body, id, fingerprint, expected, true);
    }

    private static Object electricalLoad(IsoPlayer body, String id, String fingerprint,
            IsoObject expected, boolean reached) {
        try {
            var object = expected; var square = object == null ? null : object.getSquare();
            if (!networkActor(body) || square == null || !utilityObjectLive(object, square)) return null;
            if (body instanceof SAOIsoPlayerShell shell) {
                var binding = utilityBinding(shell, id, fingerprint, "E:");
                if (binding.object.get() != object || binding.square.get() != square || reached && !utilityReached(shell, square)) return null;
            } else if (!body.isLocalPlayer() || body.getCurrentSquare().getZ()!=square.getZ()
                    || Math.pow(body.getX()-square.getX()-.5,2)+Math.pow(body.getY()-square.getY()-.5,2)>=4) return null;
            var parts = object.getSpriteGridObjectsIncludingSelf(new ArrayList<>());
            var seen = Collections.newSetFromMap(new java.util.IdentityHashMap<IsoObject, Boolean>());
            double rate = 0; int count = 0;
            if (parts.isEmpty()) parts.add(object);
            for (var part : parts) {
                var location = part.getSquare();
                if (!seen.add(part)) continue;
                if (!utilityObjectLive(part, location) || part.getCell() != body.getCell()) return null;
                float value = part.getGeneratorPowerConsumption();
                if (!Float.isFinite(value) || value < 0) return null;
                rate += value; count++;
            }
            var row = recipeTable();
            row.rawset("nativeClass", object.getClass().getName());
            row.rawset("partRate", (double)object.getGeneratorPowerConsumption());
            row.rawset("groupRate", rate); row.rawset("partCount", (double)count);
            row.rawset("powered", ItemContainer.isObjectPowered(object, true));
            if (object instanceof zombie.iso.objects.IsoStove stove) row.rawset("consumerActive", stove.Activated());
            else if (object instanceof zombie.iso.objects.IsoLightSwitch light) row.rawset("consumerActive", light.isActivated());
            else row.rawset("consumerActive", object.getGeneratorPowerConsumption() > 0);
            row.rawset("switchable", object instanceof zombie.iso.objects.IsoStove
                || object instanceof zombie.iso.objects.IsoLightSwitch);
            return row;
        } catch (Throwable unavailable) {
            SAOAgent.log("electrical load observation unavailable: " + unavailable); return null;
        }
    }

    private static Source powerConsumerSource(Snapshot snapshot, IsoObject object) {
        Source source = utilitySource(snapshot, object, "E:", "power-consumer"); source.inspected = true;
        // The native static query is fresh; checkObjectPowered caches for one IngameState tick.
        source.powered = householdPumpCurrent(object) || object.getFluidContainer()!=null&&householdIncluded(object)
            ? object.getSquare().haveElectricity() : ItemContainer.isObjectPowered(object, true); source.finish(); return source;
    }

    /** Visible current-floor sites. Recipe-specific clearance remains native build authority. */
    public static synchronized String collectorSites(SAOIsoPlayerShell shell) {
        String actor = SAOConceptObservation.actor(shell);
        if (actor == null || transactionActive) return "";
        var remembered = COLLECTOR_SITES.computeIfAbsent(shell, ignored -> new LinkedHashMap<>());
        var eye = shell.getCurrentSquare();
        StringBuilder out = new StringBuilder();
        int count = 0;
        for (int distance = 0; distance <= INSPECTION_RANGE && count < 32; distance++) {
            for (int dy = -distance; dy <= distance && count < 32; dy++) {
                for (int dx = -distance; dx <= distance && count < 32; dx++) {
                    if (Math.max(Math.abs(dx), Math.abs(dy)) != distance) continue;
                    var square = shell.getCell().getGridSquare(eye.getX() + dx, eye.getY() + dy, eye.getZ());
                    if (!collectorSiteUsable(square)
                            || !SAOPerceptionScanner.canSeeWorldSquareNow(shell, square, INSPECTION_RANGE)) continue;
                    String key = square.getX() + ":" + square.getY() + ":" + square.getZ();
                    var binding = remembered.get(key);
                    if (binding == null || !binding.matches(actor, square)) {
                        binding = new CollectorSiteBinding(actor, square);
                        remembered.put(key, binding);
                    }
                    if (out.length() > 0) out.append('|');
                    out.append(square.getX()).append(',').append(square.getY()).append(',')
                        .append(square.getZ()).append(',').append(binding.revision.replace('|', '_').replace(',', '_'));
                    count++;
                }
            }
        }
        while (remembered.size() > MAX_INSPECTION_OPTIONS)
            remembered.remove(remembered.keySet().iterator().next());
        return out.toString();
    }

    public static synchronized IsoGridSquare collectorPlacementSquare(SAOIsoPlayerShell shell,
            int x, int y, int z, String revision) {
        String actor = SAOConceptObservation.actor(shell);
        var remembered = COLLECTOR_SITES.get(shell);
        var binding = remembered == null ? null : remembered.get(x + ":" + y + ":" + z);
        var square = actor == null ? null : shell.getCell().getGridSquare(x, y, z);
        return binding != null && binding.revision.equals(revision)
            && binding.matches(actor, square) && collectorSiteUsable(square)
            && SAOPerceptionScanner.canSeeWorldSquareNow(shell, square, INSPECTION_RANGE)
            && refillWithinReach(shell, square) ? square : null;
    }

    /** Physical validation; the native action owner proves this object's creation. */
    public static synchronized boolean collectorCreated(SAOIsoPlayerShell shell, IsoThumpable collector,
            String entityId, int x, int y, int z) {
        if (SAOConceptObservation.actor(shell) == null || collector == null || entityId == null
                || !(entityId.equals("Base.RainCollector") || entityId.equals("Base.RainCollectorRound")
                    || entityId.equals("Base.RainCollector_Tarp") || entityId.equals("Base.RainCollectorRound_Tarp"))) return false;
        var square = shell.getCell().getGridSquare(x, y, z);
        var script = collector.getEntityScript();
        var fluid = collector.getFluidContainer();
        return square != null && square.getCell() == shell.getCell() && collector.getCell() == shell.getCell()
            && collector.getSquare() == square && square.getObjects().contains(collector)
            && collector.getObjectIndex() >= 0 && !collector.getUsesExternalWaterSource()
            && script != null && entityId.equals(script.getFullName())
            && fluid != null && fluid.getGameEntity() == collector && fluid.getCapacity() > 0
            && fluid.getRainCatcher() > 0 && collector.getFluidCapacity() == fluid.getCapacity();
    }

    public static synchronized String collectorSource(SAOIsoPlayerShell shell, IsoThumpable collector,
            String entityId, int x, int y, int z) {
        if (!collectorCreated(shell, collector, entityId, x, y, z)) return "";
        Source source = objectFluidSource(new Snapshot(Math.floorDiv(x, CHUNK_SIZE), Math.floorDiv(y, CHUNK_SIZE)),
            collector.getSquare(), collector);
        return source.id + "|" + source.fingerprint;
    }

    public static synchronized boolean collectorFeedsFixture(SAOIsoPlayerShell shell, IsoThumpable collector,
            String sourceId, String fingerprint, int x, int y, int z) {
        if (SAOConceptObservation.actor(shell) == null || collector == null || collector.getSquare() == null
                || sourceId == null || !sourceId.startsWith("F:") || sourceId.length() <= 2 || fingerprint == null
                || rememberedContainerRevisions(shell, sourceId, fingerprint).isEmpty()) return false;
        var roof = collector.getSquare();
        var script = collector.getEntityScript();
        if (script == null || !collectorCreated(shell, collector, script.getFullName(), roof.getX(), roof.getY(), roof.getZ())) return false;
        var square = shell.getCell().getGridSquare(x, y, z);
        if (square == null || square.getCell() != shell.getCell()) return false;
        for (int index = 0; index < square.getObjects().size(); index++) {
            var fixture = square.getObjects().get(index);
            if (fixture == null || fixture.getSquare() != square
                    || !sourceId.substring(2).equals(fixture.getModData().rawget(SOURCE_TOKEN))) continue;
            Source source = objectFluidSource(new Snapshot(Math.floorDiv(x, CHUNK_SIZE), Math.floorDiv(y, CHUNK_SIZE)), square, fixture);
            if (!source.fingerprint.equals(fingerprint)
                    || fixture instanceof IsoThumpable locked && locked.isLockedToCharacter(shell)
                    || GameClient.client && !zombie.iso.areas.SafeHouse.isSafehouseAllowInteract(square, shell)) return false;
            return fixture.FindExternalWaterSource() == collector;
        }
        return false;
    }

    private static boolean collectorSiteUsable(IsoGridSquare square) {
        return square != null && square.isOutside() && square.isSolidFloor()
            && square.isFree(false) && !square.HasStairs() && !square.HasTree()
            && square.getMovingObjects().isEmpty() && !square.isVehicleIntersecting() && !square.haveFire();
    }

    private static final class CollectorSiteBinding {
        final String actor, revision = UUID.randomUUID().toString();
        final java.lang.ref.WeakReference<IsoGridSquare> square;
        final ArrayList<java.lang.ref.WeakReference<IsoObject>> objects = new ArrayList<>();
        final ArrayList<String> sprites = new ArrayList<>();
        CollectorSiteBinding(String actor, IsoGridSquare square) {
            this.actor = actor; this.square = new java.lang.ref.WeakReference<>(square);
            for (int index = 0; index < square.getObjects().size(); index++) {
                var object = square.getObjects().get(index);
                objects.add(new java.lang.ref.WeakReference<>(object));
                sprites.add(object.getSpriteName());
            }
        }
        boolean matches(String actor, IsoGridSquare square) {
            if (!this.actor.equals(actor) || this.square.get() != square || square == null
                    || objects.size() != square.getObjects().size()) return false;
            for (int index = 0; index < objects.size(); index++) {
                var object = square.getObjects().get(index);
                if (objects.get(index).get() != object
                        || !java.util.Objects.equals(sprites.get(index), object.getSpriteName())) return false;
            }
            return true;
        }
    }

    /** Bind the exact source only after the actor has reached its interaction point. */
    public static synchronized String bindAction(IsoPlayer shell, String sourceId,
            String fingerprint, String revision, int itemId, String itemType,
            int expectedX, int expectedY, int expectedZ) {
        try {
            Located located = locate(shell, sourceId, fingerprint, revision,
                itemId, itemType, expectedX, expectedY, expectedZ);
            boolean accessible = located.worldItem != null
                ? squareWithinReach(shell, located.square)
                : SAONeeds.containerAccessibleNow(shell,
                    located.permissionContainer);
            if (!accessible) return "ACCESS_REFUSED";
            ACTIONS.put(shell, new ActionBinding(located));
            return "BOUND:" + located.square.getX() + ":"
                + located.square.getY() + ":" + located.square.getZ();
        } catch (ActionRefusal refusal) {
            return refusal.code;
        } catch (Throwable throwable) {
            SAOAgent.log("world source bind threw: " + throwable);
            return "FAILED";
        }
    }

    public static synchronized Object actionItem(IsoPlayer shell) {
        ActionBinding binding = ACTIONS.get(shell);
        return binding == null ? null : binding.item;
    }

    public static synchronized Object actionSourceContainer(IsoPlayer shell) {
        ActionBinding binding = ACTIONS.get(shell);
        return binding == null ? null : binding.sourceContainer;
    }

    /** The item's actual holder at binding, including a carried nested bag. */
    public static synchronized Object actionOriginContainer(IsoPlayer shell) {
        ActionBinding binding = ACTIONS.get(shell);
        return binding == null ? null : binding.originContainer;
    }

    public static synchronized Object actionPermissionContainer(IsoPlayer shell) {
        ActionBinding binding = ACTIONS.get(shell);
        return binding == null ? null : binding.permissionContainer;
    }

    public static synchronized Object actionWorldItem(IsoPlayer shell) {
        ActionBinding binding = ACTIONS.get(shell);
        return binding == null ? null : binding.worldItem;
    }

    /** Find the exact transferred item in the body's native inventory. */
    public static synchronized Object carriedActionItem(IsoPlayer shell, int itemId,
            String itemType) {
        try {
            return findItem(shell == null ? null : shell.getInventory(), itemId,
                itemType, 0);
        } catch (Throwable throwable) {
            return null;
        }
    }

    public static synchronized String carriedTransferItem(IsoPlayer shell, int itemId,
            String itemType) {
        try {
            ItemContainer inventory = shell == null ? null : shell.getInventory();
            InventoryItem item = findItem(inventory, itemId, itemType, 0);
            return item == null || countItemId(inventory, itemId, 0) != 1
                ? "" : "T" + itemFields(ItemRow.of(item));
        } catch (Throwable throwable) {
            return "";
        }
    }

    /** Current absolute amount used to partition a reload-resumed native use. */
    public static synchronized float carriedActionMeasure(IsoPlayer shell,
            int itemId, String itemType, String category) {
        try {
            InventoryItem item = findItem(shell == null ? null : shell.getInventory(),
                itemId, itemType, 0);
            if (item == null) return -1.0f;
            return "water".equals(value(category))
                || "drink".equals(value(category))
                ? fluidAmount(item) : item.getCurrentUsesFloat();
        } catch (Throwable throwable) {
            return -1.0f;
        }
    }

    /** Snapshot the exact carried item and the body's native need before use. */
    public static synchronized boolean beginUse(IsoPlayer shell, int itemId,
            String itemType, String category, float durableBaseline) {
        try {
            InventoryItem item = findItem(shell == null ? null : shell.getInventory(),
                itemId, itemType, 0);
            if (item == null) return false;
            ActionBinding binding = ACTIONS.get(shell);
            if (binding == null || binding.item.getID() != itemId) {
                binding = new ActionBinding(item);
                ACTIONS.put(shell, binding);
            }
            binding.item = item;
            binding.category = value(category);
            binding.usesBefore = item.getUses();
            binding.currentUsesBefore = durableBaseline >= 0.0f
                ? durableBaseline : item.getCurrentUsesFloat();
            binding.amountBefore = durableBaseline >= 0.0f
                ? durableBaseline : fluidAmount(item);
            binding.hungerBefore = shell.getStats().get(CharacterStat.HUNGER);
            binding.thirstBefore = shell.getStats().get(CharacterStat.THIRST);
            binding.useStarted = true;
            binding.settled = false;
            return true;
        } catch (Throwable throwable) {
            SAOAgent.log("world source begin use threw: " + throwable);
            return false;
        }
    }

    /**
     * Verify what vanilla actually changed. Complete and stop both pass here:
     * a stopped drink may already have consumed fluid, while a stopped meal
     * may have applied its partial eat. No physical change means no result.
     */
    public static synchronized String finishUse(IsoPlayer shell, boolean completed) {
        try {
            ActionBinding binding = ACTIONS.get(shell);
            if (binding == null || !binding.useStarted || binding.settled) {
                return "NO_EFFECT:0:no-active-use";
            }
            binding.settled = true;
            InventoryItem carried = findItem(shell.getInventory(),
                binding.item.getID(), binding.item.getFullType(), 0);
            float amountAfter = carried == null ? 0.0f : fluidAmount(carried);
            float currentAfter = carried == null ? 0.0f
                : carried.getCurrentUsesFloat();
            float quantity;
            if ("water".equals(binding.category)
                    || "drink".equals(binding.category)) {
                quantity = Math.max(0.0f, binding.amountBefore - amountAfter);
            } else {
                quantity = Math.max(0.0f,
                    binding.currentUsesBefore - currentAfter);
            }
            if (carried == null && quantity <= 0.0001f) quantity = 1.0f;
            float hungerAfter = shell.getStats().get(CharacterStat.HUNGER);
            float thirstAfter = shell.getStats().get(CharacterStat.THIRST);
            boolean changed = quantity > 0.0001f
                || hungerAfter < binding.hungerBefore - 0.0001f
                || thirstAfter < binding.thirstBefore - 0.0001f;
            if (!changed) return "NO_EFFECT:0:native-use-made-no-change";
            return "APPLIED:" + (completed ? "completed" : "interrupted")
                + ":" + number(quantity) + ":"
                + (completed ? "native-complete" : "native-partial-stop");
        } catch (Throwable throwable) {
            SAOAgent.log("world source finish use threw: " + throwable);
            return "NO_EFFECT:0:verification-failed";
        }
    }

    public static synchronized void clearAction(IsoPlayer shell) {
        ACTIONS.remove(shell);
    }

    /** Locate a currently reachable native holder for use-time claim checks. */
    public static synchronized String transferPosition(IsoPlayer shell,
            ItemContainer container) {
        try {
            if (!SAONeeds.containerAccessibleNow(shell, container)) return "";
            IsoGridSquare square;
            if (container.isVehiclePart()) {
                square = container.getVehicle().getSquare();
            } else {
                IsoObject parent = container.getParent();
                square = parent == null ? null : parent.getSquare();
                if (square == null || !square.getObjects().contains(parent)) return "";
                boolean owns = false;
                for (int index = 0; index < parent.getContainerCount(); index++) {
                    if (parent.getContainerByIndex(index) == container) owns = true;
                }
                if (!owns) return "";
            }
            return square == null ? "" : "AT:" + square.getX() + ":"
                + square.getY() + ":" + square.getZ();
        } catch (Throwable unavailable) {
            return "";
        }
    }

    /** Inspect one reachable transfer while retaining complete chunk coverage. */
    public static synchronized String transferOffer(IsoPlayer shell,
            InventoryItem item, ItemContainer worldContainer, String operation) {
        if (transactionActive || shell == null || item == null
                || worldContainer == null
                || !("acquire".equals(operation) || "store".equals(operation))) {
            return "";
        }
        transactionActive = true;
        try {
            boolean storing = "store".equals(operation);
            if (!transferPermitted(shell, item, worldContainer, storing)) return "";
            IsoCell cell = shell.getCell();
            if (cell == null || cell != currentCell()) return "";
            IsoGridSquare square;
            IsoObject object = null;
            BaseVehicle vehicle = null;
            VehiclePart part = null;
            int containerIndex = -1;
            if (worldContainer.isVehiclePart()) {
                vehicle = worldContainer.getVehicle();
                part = worldContainer.getVehiclePart();
                if (vehicle == null || part == null || vehicle.getSqlId() < 0
                        || vehicle.isRemovedFromWorld()
                        || !cell.getVehicles().contains(vehicle)
                        || part.getItemContainer() != worldContainer) return "";
                square = vehicle.getSquare();
            } else {
                object = worldContainer.getParent();
                square = object == null ? null : object.getSquare();
                if (square == null || !square.getObjects().contains(object)) return "";
                for (int index = 0; index < object.getContainerCount(); index++) {
                    if (object.getContainerByIndex(index) == worldContainer) {
                        containerIndex = index;
                        break;
                    }
                }
                if (containerIndex < 0) return "";
            }
            if (square == null || square.getCell() != cell
                    || cell.getGridSquare(square.getX(), square.getY(), square.getZ())
                        != square) return "";
            int chunkX = Math.floorDiv(square.getX(), CHUNK_SIZE);
            int chunkY = Math.floorDiv(square.getY(), CHUNK_SIZE);
            IsoChunk chunk = cell.getChunk(chunkX, chunkY);
            if (chunk == null) return "";
            Snapshot snapshot = scan(chunk, false);
            String sourceId = vehicle == null
                ? "C:" + value((String) object.getModData().rawget(SOURCE_TOKEN))
                    + ":" + containerIndex
                : "V:" + vehicle.getSqlId() + ":" + part.getIndex();
            Source source = snapshot.byId.get(sourceId);
            if (source == null || !source.explored) return "";
            Located located = locate(shell, source.id, source.fingerprint,
                source.revision, item.getID(), item.getFullType(), source.x,
                source.y, source.z, storing ? ItemLocation.CARRIED : ItemLocation.SOURCE);
            if (located.item != item || located.permissionContainer != worldContainer
                    || !transferPermitted(shell, item, worldContainer, storing)) return "";
            if (snapshot.identitiesStamped) save(chunk);
            ItemRow row = ItemRow.of(item);
            return "T|operation=" + operation + "|source=" + field(source.id)
                + itemFields(row) + "\n" + encode(snapshot);
        } catch (Throwable throwable) {
            SAOAgent.log("world transfer offer refused: " + throwable);
            return "";
        } finally {
            transactionActive = false;
        }
    }

    public static synchronized String storeActionTarget(IsoPlayer shell,
            String sourceId, String fingerprint, String revision, int itemId,
            String itemType, int expectedX, int expectedY, int expectedZ) {
        try {
            Located located = locate(shell, sourceId, fingerprint, revision,
                itemId, itemType, expectedX, expectedY, expectedZ, ItemLocation.CARRIED);
            IsoGridSquare target = located.vehicle == null
                ? interactionSquare(shell, located.square)
                : vehicleInteractionSquare(located.vehicle, located.vehiclePart);
            if (target == null) return "NO_INTERACTION_POINT";
            return "READY:" + target.getX() + ":" + target.getY() + ":"
                + target.getZ() + ":" + located.square.getX() + ":"
                + located.square.getY() + ":" + located.square.getZ();
        } catch (ActionRefusal refusal) {
            return refusal.code;
        } catch (Throwable throwable) {
            SAOAgent.log("world store target threw: " + throwable);
            return "FAILED";
        }
    }

    public static synchronized String bindStoreAction(IsoPlayer shell,
            String sourceId, String fingerprint, String revision, int itemId,
            String itemType, int expectedX, int expectedY, int expectedZ) {
        try {
            Located located = locate(shell, sourceId, fingerprint, revision,
                itemId, itemType, expectedX, expectedY, expectedZ, ItemLocation.CARRIED);
            if (!transferPermitted(shell, located.item, located.permissionContainer,
                    true)) return "ACCESS_REFUSED";
            ACTIONS.put(shell, new ActionBinding(located));
            return "BOUND:" + located.square.getX() + ":"
                + located.square.getY() + ":" + located.square.getZ();
        } catch (ActionRefusal refusal) {
            return refusal.code;
        } catch (Throwable throwable) {
            SAOAgent.log("world store bind threw: " + throwable);
            return "FAILED";
        }
    }

    /** Holder evidence survives queue loss and never moves or recreates an item. */
    public static synchronized String storeTransferState(IsoPlayer shell,
            String sourceId, String fingerprint, int itemId, String itemType,
            int expectedX, int expectedY, int expectedZ) {
        try {
            Located located = locate(shell, sourceId, fingerprint, null, itemId,
                itemType, expectedX, expectedY, expectedZ, ItemLocation.CONTAINER);
            return transferHolderState(shell.getInventory(),
                located.permissionContainer, itemId, itemType);
        } catch (ActionRefusal refusal) {
            return "NOT_LOADED".equals(refusal.code)
                || ("SOURCE_MISSING".equals(refusal.code)
                    && sourceId != null && sourceId.startsWith("V:"))
                || "BAD_REQUEST".equals(refusal.code) ? "UNAVAILABLE" : "CONFLICT";
        } catch (Throwable throwable) {
            SAOAgent.log("world store state unreadable: " + throwable);
            return "UNAVAILABLE";
        }
    }

    private static String transferHolderState(ItemContainer carried,
            ItemContainer destination, int itemId, String itemType) {
        if (carried == null || destination == null || carried == destination) {
            return "CONFLICT";
        }
        int carriedCount = countItemId(carried, itemId, 0);
        int destinationCount = countItemId(destination, itemId, 0);
        InventoryItem atDestination = findItem(destination, itemId, itemType, 0);
        if (carriedCount == 0 && destinationCount == 1 && atDestination != null
                && atDestination.getContainer() == destination) return "TRANSFERRED";
        if (carriedCount == 1 && destinationCount == 0
                && findItem(carried, itemId, itemType, 0) != null) return "CARRIED";
        return "CONFLICT";
    }

    private static boolean transferPermitted(IsoPlayer shell, InventoryItem item,
            ItemContainer worldContainer, boolean storing) {
        if (shell == null || item == null || worldContainer == null
                || !worldContainer.isExplored()
                || worldContainer.getOutermostContainer() != worldContainer
                || worldContainer.isInCharacterInventory(shell)
                || !SAONeeds.containerAccessibleNow(shell, worldContainer)
                || item instanceof InventoryContainer || item.getIsCraftingConsumed() || !networkStockAvailable(item)
                || "CandleLit".equals(item.getType())
                || "Lantern_HurricaneLit".equals(item.getType())) return false;
        ItemRow row = ItemRow.of(item);
        if (row.categories.isEmpty()) {
            return false;
        }
        ItemContainer inventory = shell.getInventory();
        ItemContainer holder = storing ? inventory : worldContainer;
        ItemContainer other = storing ? worldContainer : inventory;
        if (findItem(holder, item.getID(), item.getFullType(), 0) != item
                || countItemId(holder, item.getID(), 0) != 1
                || countItemId(other, item.getID(), 0) != 0) return false;
        ItemContainer origin = item.getContainer();
        ItemContainer destination = storing ? worldContainer : inventory;
        return origin != null && origin != destination && origin.contains(item)
            && (!storing || !item.isFavorite()) && origin.isRemoveItemAllowed(item)
            && destination.isItemAllowed(item) && !destination.isInside(item)
            && destination.hasRoomFor(shell, item);
    }

    private static int countItemId(ItemContainer container, int itemId, int depth) {
        if (container == null) return 0;
        if (depth > MAX_CONTAINER_DEPTH) {
            throw new IllegalStateException("native transfer nesting exceeds bound");
        }
        int count = 0;
        for (InventoryItem item : new ArrayList<>(container.getItems())) {
            if (item == null) continue;
            if (item.getID() == itemId) count++;
            if (item instanceof InventoryContainer nested) {
                count += countItemId(nested.getInventory(), itemId, depth + 1);
            }
        }
        return count;
    }

    /** Observe a chunk already owned by a live player map. Never rolls loot. */
    public static synchronized String observeLoadedChunk(int chunkX, int chunkY) {
        if (transactionActive) {
            return error("BUSY", "another source transaction is active", chunkX, chunkY);
        }
        transactionActive = true;
        try {
            IsoCell cell = currentCell();
            if (cell == null) {
                return error("NO_WORLD", "no current cell", chunkX, chunkY);
            }
            IsoChunk chunk = cell.getChunk(chunkX, chunkY);
            if (chunk == null) {
                return error("NOT_LOADED", "chunk is outside every active map", chunkX, chunkY);
            }
            Snapshot snapshot = scan(chunk, false);
            if (snapshot.identitiesStamped) {
                save(chunk);
            }
            snapshot.status = "OBSERVED";
            snapshot.mode = "loaded";
            return encode(snapshot);
        } catch (Throwable throwable) {
            SAOAgent.log("world sources: loaded observation failed at " + chunkX + ","
                + chunkY + " (" + throwable + ")");
            return error("FAILED", String.valueOf(throwable), chunkX, chunkY);
        } finally {
            transactionActive = false;
        }
    }

    /** Generate/load, natively populate, observe, save, and release one chunk. */
    public static synchronized String hydrateChunk(int chunkX, int chunkY) {
        if (transactionActive) {
            return error("BUSY", "another source transaction is active", chunkX, chunkY);
        }
        transactionActive = true;
        LoadedChunk held = null;
        enterHydration();
        try {
            String refusal = hydrationRefusal(chunkX, chunkY);
            if (refusal != null) {
                return refusal;
            }
            held = acquire(chunkX, chunkY);
            Snapshot snapshot = scan(held.chunk, true);
            save(held.chunk);
            snapshot.status = "HYDRATED";
            snapshot.mode = held.borrowed ? "native-offscreen" : "loaded";
            return encode(snapshot);
        } catch (Busy busy) {
            return error("BUSY", busy.getMessage(), chunkX, chunkY);
        } catch (Throwable throwable) {
            SAOAgent.log("world sources: hydration failed at " + chunkX + "," + chunkY
                + " (" + throwable + ")");
            return error("FAILED", String.valueOf(throwable), chunkX, chunkY);
        } finally {
            release(held);
            exitHydration();
            transactionActive = false;
        }
    }

    private static String hydrationRefusal(int chunkX, int chunkY) {
        if (GameClient.client || GameServer.server) {
            return error("UNSUPPORTED", "native hydration is single-player only",
                chunkX, chunkY);
        }
        if (Core.getInstance().isNoSave()) {
            return error("NO_SAVE", "the engine has disabled world persistence",
                chunkX, chunkY);
        }
        if (!SAOLootDensityWeave.isReady()) {
            return error("WEAVE_NOT_READY", SAOLootDensityWeave.report(), chunkX, chunkY);
        }
        if (currentCell() == null || WorldStreamer.instance == null) {
            return error("NO_WORLD", "world streamer or cell is unavailable",
                chunkX, chunkY);
        }
        return null;
    }

    private static IsoCell currentCell() {
        return IsoWorld.instance == null ? null : IsoWorld.instance.currentCell;
    }

    private static LoadedChunk acquire(int chunkX, int chunkY) throws Exception {
        IsoCell cell = currentCell();
        IsoChunk live = cell.getChunk(chunkX, chunkY);
        if (live != null) {
            return new LoadedChunk(live, false);
        }

        ArrayList<IsoChunk> pending = new ArrayList<>();
        IsoChunk.loadGridSquare.copyTo(pending);
        for (IsoChunk chunk : pending) {
            if (chunk != null && chunk.wx == chunkX && chunk.wy == chunkY) {
                throw new Busy("target chunk is entering an active map");
            }
        }
        if (WorldStreamer.instance.isBusy()) {
            throw new Busy("world streamer is busy");
        }

        IsoChunk chunk = new IsoChunk(cell);
        try {
            WorldStreamer.instance.addJobInstant(chunk, chunkX, chunkY, chunkX, chunkY);
            IsoChunk.loadGridSquare.remove(chunk);
            if (!chunk.loaded) {
                throw new IllegalStateException("native chunk load did not complete");
            }
            // DoChunkAlways has loaded/generated the chunk, but an off-screen
            // coordinate cannot be adopted by any active IsoChunkMap. Run only
            // the streamer's own pre-live square phase; doLoadGridsquare is a
            // live-map phase and is deliberately not entered here.
            chunk.loadInWorldStreamerThread();
            return new LoadedChunk(chunk, true);
        } catch (Throwable throwable) {
            IsoChunk.loadGridSquare.remove(chunk);
            try {
                chunk.doReuseGridsquares();
            } catch (Throwable cleanup) {
                throwable.addSuppressed(cleanup);
            }
            if (throwable instanceof Exception exception) {
                throw exception;
            }
            throw new RuntimeException(throwable);
        }
    }

    private static void release(LoadedChunk held) {
        if (held == null || !held.borrowed) {
            return;
        }
        try {
            IsoChunk.loadGridSquare.remove(held.chunk);
            held.chunk.doReuseGridsquares();
        } catch (Throwable throwable) {
            SAOAgent.log("world sources: chunk release failed at " + held.chunk.wx + ","
                + held.chunk.wy + " (" + throwable + ")");
        }
    }

    private static void save(IsoChunk chunk) throws Exception {
        chunk.Save(true);
    }

    private static Snapshot scan(IsoChunk chunk, boolean fill) {
        Snapshot snapshot = new Snapshot(chunk.wx, chunk.wy);
        for (int z = chunk.getMinLevel(); z <= chunk.getMaxLevel(); z++) {
            for (int localY = 0; localY < CHUNK_SIZE; localY++) {
                for (int localX = 0; localX < CHUNK_SIZE; localX++) {
                    IsoGridSquare square = chunk.getGridSquare(localX, localY, z);
                    if (square != null) {
                        scanSquare(snapshot, square, fill);
                    }
                }
            }
        }
        for (BaseVehicle vehicle : new ArrayList<>(chunk.vehicles)) {
            // C61 observes vehicle identity but does not mutate its separate
            // VehiclesDB2 persistence surface. Access remains unsupported.
            scanVehicle(snapshot, vehicle, false);
        }
        snapshot.finish();
        return snapshot;
    }

    private static void scanSquare(Snapshot snapshot, IsoGridSquare square, boolean fill) {
        List<IsoObject> objects = square.getObjects();
        for (int objectIndex = 0; objectIndex < objects.size(); objectIndex++) {
            IsoObject object = objects.get(objectIndex);
            if (object == null) {
                continue;
            }
            int count = object.getContainerCount();
            for (int containerIndex = 0; containerIndex < count; containerIndex++) {
                ItemContainer container = object.getContainerByIndex(containerIndex);
                if (container == null) {
                    continue;
                }
                if (fill && !container.isExplored()) {
                    ItemPickerJava.fillContainer(container, lootParticipant());
                    container.setExplored(true);
                    ItemPickerJava.updateOverlaySprite(object);
                }
                snapshot.add(containerSource(snapshot, square, object, container,
                    containerIndex));
            }
            if (object.getFluidCapacity() > 0.0f || !plumbingState(object).isEmpty()) {
                snapshot.add(objectFluidSource(snapshot, square, object));
            }
        }
        for (IsoWorldInventoryObject worldObject
                : new ArrayList<>(square.getWorldObjects())) {
            if (worldObject != null && worldObject.getItem() != null) {
                snapshot.add(groundSource(snapshot, square, worldObject));
            }
        }
    }

    private static void scanVehicle(Snapshot snapshot, BaseVehicle vehicle, boolean fill) {
        if (vehicle == null || vehicle.getParts() == null) {
            return;
        }
        for (int index = 0; index < vehicle.getParts().size(); index++) {
            VehiclePart part = vehicle.getParts().get(index);
            ItemContainer container = part == null ? null : part.getItemContainer();
            if (container == null) {
                continue;
            }
            if (fill && !container.isExplored()) {
                ItemPickerJava.fillContainer(container, lootParticipant());
                container.setExplored(true);
            }
            snapshot.add(vehicleSource(vehicle, part, container));
        }
    }

    private static IsoPlayer lootParticipant() {
        IsoPlayer player = IsoPlayer.getInstance();
        return player != null && Boolean.TRUE.equals(player.getModData().rawget("SAO_ObserverAnchor"))
            ? null : player;
    }

    private static Source containerSource(Snapshot snapshot, IsoGridSquare square,
            IsoObject object, ItemContainer container, int containerIndex) {
        long building = buildingId(square);
        String token = sourceToken(snapshot, object);
        String id = "C:" + token + ":" + containerIndex;
        String physical = object.getClass().getName() + "|" + value(object.getSpriteName())
            + "|" + value(container.getType()) + "|" + building + "|"
            + square.getX() + "|" + square.getY() + "|" + square.getZ()
            + "|" + containerIndex + "|" + token;
        Source source = new Source(id, digest(physical), "container", square.getX(),
            square.getY(), square.getZ(), building, container.isExplored());
        source.containerType = value(container.getType());
        if (container.isExplored()) {
            addItems(source, container.getItems(), 0);
        }
        source.finish();
        return source;
    }

    private static boolean fluidInspectionReachable(IsoPlayer person, IsoGridSquare square) {
        return inspectionActor(person) && networkLoaded(person, square)
            && Math.floor(person.getZ()) == square.getZ()
            && Math.hypot(person.getX() - square.getX() - .5, person.getY() - square.getY() - .5) <= 1.8
            && SAOPerceptionScanner.canSeeWorldSquareNow((SAOIsoPlayerShell)person, square, INSPECTION_RANGE)
            && interactionSquare(person, square) != null;
    }

    private static String fluidFingerprint(IsoGridSquare square, IsoObject object, String token) {
        String physical = object.getClass().getName() + "|" + value(object.getSpriteName())
            + "|fluid|" + buildingId(square) + "|" + square.getX() + "|" + square.getY()
            + "|" + square.getZ() + "|" + token;
        return digest(physical);
    }

    private static Source objectFluidSource(Snapshot snapshot, IsoGridSquare square,
            IsoObject object) {
        long building = buildingId(square);
        String token = sourceToken(snapshot, object);
        String id = "F:" + token;
        Source source = new Source(id, fluidFingerprint(square, object, token), "fluid", square.getX(),
            square.getY(), square.getZ(), building, true);
        source.plumbing = plumbingState(object);
        float amount = object.getFluidAmount();
        Fluid fluid = object.getPrimaryFluid();
        boolean cleanWater = amount > 0.0f && (fluid == null || !fluid.isPoisonous())
            && object.hasWater() && !object.isTaintedWater();
        ItemRow row = ItemRow.fluid(object, amount, fluid, cleanWater, object.isTaintedWater());
        source.items.add(row);
        source.finish();
        return source;
    }

    private static Source groundSource(Snapshot snapshot, IsoGridSquare square,
            IsoWorldInventoryObject worldObject) {
        InventoryItem item = worldObject.getItem();
        String token = itemToken(snapshot, item);
        String id = "G:" + token;
        String physical = value(item.getFullType()) + "|" + item.getID() + "|"
            + square.getX() + "|" + square.getY() + "|" + square.getZ()
            + "|" + token;
        Source source = new Source(id, digest(physical), "ground", square.getX(),
            square.getY(), square.getZ(), buildingId(square), true);
        if(networkStockAvailable(item))source.items.add(ItemRow.of(item));
        source.finish();
        return source;
    }

    private static Source vehicleSource(BaseVehicle vehicle, VehiclePart part,
            ItemContainer container) {
        int sqlId = vehicle.getSqlId();
        int partIndex = part.getIndex();
        String id = "V:" + sqlId + ":" + partIndex;
        String physical = sqlId + "|" + partIndex + "|" + value(part.getId())
            + "|" + value(container.getType());
        int x = (int) Math.floor(vehicle.getX());
        int y = (int) Math.floor(vehicle.getY());
        int z = (int) Math.floor(vehicle.getZ());
        Source source = new Source(id, digest(physical), "vehicle", x, y, z, -1,
            container.isExplored());
        source.access = "unsupported";
        source.containerType = value(container.getType());
        if (container.isExplored()) {
            addItems(source, container.getItems(), 0);
        }
        source.finish();
        return source;
    }

    private static void addItems(Source source, List<InventoryItem> items,
            int depth) {
        if (depth > MAX_CONTAINER_DEPTH) {
            throw new IllegalStateException("native container nesting exceeds bound");
        }
        for (InventoryItem item : new ArrayList<>(items)) {
            if (item == null) {
                continue;
            }
            if (source.items.size() >= MAX_ITEMS_PER_SOURCE) {
                throw new IllegalStateException("native source item count exceeds bound");
            }
            source.items.add(ItemRow.of(item));
            if (item instanceof InventoryContainer nested
                    && nested.getInventory() != null) {
                addItems(source, nested.getInventory().getItems(), depth + 1);
            }
        }
    }

    private static String sourceToken(Snapshot snapshot, IsoObject object) {
        Object existing = object.getModData().rawget(SOURCE_TOKEN);
        if (existing instanceof String token && !token.isBlank() && token.length() <= 64) {
            return token;
        }
        if (existing != null) {
            throw new IllegalStateException("invalid native source token");
        }
        String token = UUID.randomUUID().toString();
        object.getModData().rawset(SOURCE_TOKEN, token);
        snapshot.identitiesStamped = true;
        return token;
    }

    private static String itemToken(Snapshot snapshot, InventoryItem item) {
        Object existing = item.getModData().rawget(ITEM_TOKEN);
        if (existing instanceof String token && !token.isBlank() && token.length() <= 64) {
            return token;
        }
        if (existing != null) {
            throw new IllegalStateException("invalid native item source token");
        }
        String token = UUID.randomUUID().toString();
        item.getModData().rawset(ITEM_TOKEN, token);
        snapshot.identitiesStamped = true;
        return token;
    }

    /** Reuse C61's persistent static-holder identity in a loaded private view. */
    static synchronized String privateContainerId(IsoObject object, int containerIndex) {
        if (object == null || containerIndex < 0
                || object.getContainerByIndex(containerIndex) == null) {
            throw new IllegalArgumentException("invalid native container holder");
        }
        Object existing = object.getModData().rawget(SOURCE_TOKEN);
        String token;
        if (existing instanceof String text && !text.isBlank() && text.length() <= 64) {
            token = text;
        } else if (existing == null) {
            token = UUID.randomUUID().toString();
            object.getModData().rawset(SOURCE_TOKEN, token);
        } else {
            throw new IllegalStateException("invalid native source token");
        }
        return "C:" + token + ":" + containerIndex;
    }

    /** Reuse C61's persistent placed-item identity in a loaded private view. */
    static synchronized String privateGroundId(InventoryItem item) {
        if (item == null) throw new IllegalArgumentException("missing native ground item");
        Object existing = item.getModData().rawget(ITEM_TOKEN);
        String token;
        if (existing instanceof String text && !text.isBlank() && text.length() <= 64) {
            token = text;
        } else if (existing == null) {
            token = UUID.randomUUID().toString();
            item.getModData().rawset(ITEM_TOKEN, token);
        } else {
            throw new IllegalStateException("invalid native item source token");
        }
        return "G:" + token;
    }

    static String privateVehicleId(BaseVehicle vehicle, VehiclePart part) {
        if (vehicle == null || part == null || part.getItemContainer() == null) {
            throw new IllegalArgumentException("invalid native vehicle holder");
        }
        return "V:" + vehicle.getSqlId() + ":" + part.getIndex();
    }

    private static long buildingId(IsoGridSquare square) {
        BuildingDef building = square.getBuildingDef();
        return building == null ? -1L : building.getID();
    }

    private static void enterHydration() {
        HYDRATION_DEPTH.set(HYDRATION_DEPTH.get() + 1);
    }

    private static void exitHydration() {
        int depth = HYDRATION_DEPTH.get() - 1;
        if (depth <= 0) {
            HYDRATION_DEPTH.remove();
        } else {
            HYDRATION_DEPTH.set(depth);
        }
    }

    private static String encode(Snapshot snapshot) {
        StringBuilder out = new StringBuilder(4096);
        out.append("H|protocol=").append(PROTOCOL)
            .append("|status=").append(field(snapshot.status))
            .append("|detail=").append(field(snapshot.detail))
            .append("|mode=").append(field(snapshot.mode))
            .append("|cx=").append(snapshot.chunkX)
            .append("|cy=").append(snapshot.chunkY)
            .append("|revision=").append(snapshot.revision)
            .append("|sources=").append(snapshot.sources.size()).append('\n');
        for (Source source : snapshot.sources) {
            out.append("S|id=").append(field(source.id))
                .append("|fp=").append(source.fingerprint)
                .append("|rev=").append(source.revision)
                .append("|kind=").append(source.kind)
                .append("|x=").append(source.x)
                .append("|y=").append(source.y)
                .append("|z=").append(source.z)
                .append("|building=").append(source.buildingId)
                .append("|explored=").append(source.explored ? 1 : 0)
                .append("|state=").append(source.state)
                .append("|access=").append(source.access)
                .append("|container=").append(field(source.containerType));
            if (!source.plumbing.isEmpty()) out.append("|plumbing=").append(source.plumbing);
            if (source.inspected != null) out.append("|inspected=").append(source.inspected ? 1 : 0);
            if (source.generatorCondition != null) out.append("|condition=").append(source.generatorCondition);
            if (source.generatorFuel != null) out.append("|fuel=").append(number(source.generatorFuel)).append("|maxFuel=").append(number(source.generatorMaxFuel));
            if (source.connected != null) out.append("|connected=").append(source.connected ? 1 : 0);
            if (source.active != null) out.append("|active=").append(source.active ? 1 : 0);
            if (source.outside != null) out.append("|outside=").append(source.outside ? 1 : 0);
            if (source.powered != null) out.append("|powered=").append(source.powered ? 1 : 0);
            for (Map.Entry<String, Float> entry : source.quantities.entrySet()) {
                out.append("|q:").append(entry.getKey()).append('=')
                    .append(number(entry.getValue()));
            }
            out.append('\n');
            for (ItemRow item : source.items) {
                out.append("I|source=").append(field(source.id))
                    .append(itemFields(item))
                    .append('\n');
            }
        }
        out.append("E\n");
        return out.toString();
    }

    private static String itemFields(ItemRow item) {
        return "|id=" + item.itemId + "|type=" + field(item.fullType)
            + "|uses=" + item.uses + "|currentUses=" + number(item.currentUses)
            + "|condition=" + item.condition + "|amount=" + number(item.amount)
            + "|fluid=" + field(item.fluid) + "|poison=" + (item.poison ? 1 : 0)
            + "|tainted=" + (item.tainted ? 1 : 0) + "|hydrationAmount=" + number(item.hydrationAmount)
            + "|rotten=" + (item.rotten ? 1 : 0)
            + "|cats=" + field(String.join(",", item.categories))
            + (item.ingredientState == null ? "" : "|ingredientState=" + item.ingredientState + "|sharpness=" + number(item.sharpness));
    }

    private static String error(String status, String detail, int chunkX, int chunkY) {
        return "H|protocol=" + PROTOCOL + "|status=" + field(status)
            + "|detail=" + field(detail) + "|mode=none|cx=" + chunkX
            + "|cy=" + chunkY + "|revision=|sources=0\nE\n";
    }

    private static String field(String value) {
        if (value == null) {
            return "";
        }
        byte[] bytes = value.getBytes(StandardCharsets.UTF_8);
        StringBuilder out = new StringBuilder(bytes.length);
        for (byte raw : bytes) {
            int c = raw & 0xff;
            if (c == '|' || c == '=') {
                out.append('%');
                out.append(Character.forDigit((c >>> 4) & 0xf, 16));
                out.append(Character.forDigit(c & 0xf, 16));
            } else if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
                    || (c >= '0' && c <= '9') || c == '-' || c == '_'
                    || c == '.' || c == ':' || c == ',') {
                out.append((char) c);
            } else {
                out.append('%');
                out.append(Character.forDigit((c >>> 4) & 0xf, 16));
                out.append(Character.forDigit(c & 0xf, 16));
            }
        }
        return out.toString();
    }

    private static String snapshotRevision(List<Source> sources) {
        StringBuilder exact = new StringBuilder();
        for (Source source : sources) {
            appendLengthPrefixed(exact, source.id);
            appendLengthPrefixed(exact, source.fingerprint);
            appendLengthPrefixed(exact, source.revision);
        }
        return digest(exact.toString());
    }

    private static void appendLengthPrefixed(StringBuilder out, String value) {
        String present = value(value);
        out.append(present.length()).append(':').append(present);
    }

    private static String number(float value) {
        return String.format(Locale.ROOT, "%.6f", value);
    }

    private static String value(String value) {
        return value == null ? "" : value;
    }

    private static String digest(String value) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] bytes = digest.digest(value.getBytes(StandardCharsets.UTF_8));
            StringBuilder out = new StringBuilder(bytes.length * 2);
            for (byte b : bytes) {
                out.append(Character.forDigit((b >>> 4) & 0xf, 16));
                out.append(Character.forDigit(b & 0xf, 16));
            }
            return out.toString();
        } catch (Exception impossible) {
            throw new IllegalStateException(impossible);
        }
    }

    private enum ItemLocation { SOURCE, CARRIED, CONTAINER }

    private static Located locate(IsoPlayer shell, String sourceId,
            String fingerprint, String revision, int itemId, String itemType,
            int expectedX, int expectedY, int expectedZ) throws ActionRefusal {
        return locate(shell, sourceId, fingerprint, revision, itemId, itemType,
            expectedX, expectedY, expectedZ, ItemLocation.SOURCE);
    }

    private static Located locate(IsoPlayer shell, String sourceId,
            String fingerprint, String revision, int itemId, String itemType,
            int expectedX, int expectedY, int expectedZ, ItemLocation location)
            throws ActionRefusal {
        if (shell == null || sourceId == null || sourceId.isBlank()) {
            throw new ActionRefusal("BAD_REQUEST");
        }
        IsoCell cell = shell.getCell();
        if (cell == null) throw new ActionRefusal("NOT_LOADED");
        String[] parts = sourceId.split(":");
        Source source;
        InventoryItem item = null;
        ItemContainer sourceContainer = null;
        ItemContainer permissionContainer = null;
        IsoWorldInventoryObject worldItem = null;
        IsoGridSquare square = null;
        BaseVehicle sourceVehicle = null;
        VehiclePart sourceVehiclePart = null;

        try {
            if (parts.length == 3 && "C".equals(parts[0])) {
                square = cell.getGridSquare(expectedX, expectedY, expectedZ);
                if (square == null) throw new ActionRefusal("NOT_LOADED");
                int containerIndex = Integer.parseInt(parts[2]);
                IsoObject matched = null;
                // Native PZArrayList has no iterator or iterator-backed copy;
                // use its installed indexed access on the game thread.
                for (int objectIndex = 0; objectIndex < square.getObjects().size(); objectIndex++) {
                    IsoObject object = square.getObjects().get(objectIndex);
                    Object token = object == null ? null
                        : object.getModData().rawget(SOURCE_TOKEN);
                    if (parts[1].equals(token)) {
                        matched = object;
                        break;
                    }
                }
                if (matched == null || containerIndex < 0
                        || containerIndex >= matched.getContainerCount()) {
                    throw new ActionRefusal("SOURCE_MISSING");
                }
                ItemContainer root = matched.getContainerByIndex(containerIndex);
                if (root == null) throw new ActionRefusal("SOURCE_MISSING");
                source = containerSourceKnown(square, matched, root,
                    containerIndex, parts[1]);
                sourceContainer = root;
                permissionContainer = root;
            } else if (parts.length == 2 && "G".equals(parts[0])) {
                if (location != ItemLocation.SOURCE) {
                    throw new ActionRefusal("STORE_SOURCE_UNSUPPORTED");
                }
                square = cell.getGridSquare(expectedX, expectedY, expectedZ);
                if (square == null) throw new ActionRefusal("NOT_LOADED");
                InventoryItem matchedItem = null;
                for (IsoWorldInventoryObject candidate
                        : new ArrayList<>(square.getWorldObjects())) {
                    InventoryItem candidateItem = candidate == null
                        ? null : candidate.getItem();
                    Object token = candidateItem == null ? null
                        : candidateItem.getModData().rawget(ITEM_TOKEN);
                    if (parts[1].equals(token)) {
                        worldItem = candidate;
                        matchedItem = candidateItem;
                        break;
                    }
                }
                if (worldItem == null || matchedItem == null) {
                    throw new ActionRefusal("SOURCE_MISSING");
                }
                if(!networkStockAvailable(matchedItem))throw new ActionRefusal("ACCESS_REFUSED");
                source = groundSourceKnown(square, worldItem, parts[1]);
                item = matchedItem;
            } else if (parts.length == 3 && "V".equals(parts[0])) {
                int sqlId = Integer.parseInt(parts[1]);
                int partIndex = Integer.parseInt(parts[2]);
                BaseVehicle matched = null;
                for (BaseVehicle candidate : cell.getVehicles()) {
                    if (candidate != null && candidate.getSqlId() == sqlId) {
                        matched = candidate;
                        break;
                    }
                }
                if (matched == null || matched.isRemovedFromWorld()
                        || partIndex < 0 || matched.getParts() == null
                        || partIndex >= matched.getParts().size()) {
                    throw new ActionRefusal("SOURCE_MISSING");
                }
                VehiclePart part = matched.getParts().get(partIndex);
                ItemContainer root = part == null ? null : part.getItemContainer();
                square = matched.getSquare();
                if (root == null || square == null) {
                    throw new ActionRefusal("SOURCE_MISSING");
                }
                source = vehicleSource(matched, part, root);
                sourceContainer = root;
                permissionContainer = root;
                sourceVehicle = matched;
                sourceVehiclePart = part;
            } else if (parts.length >= 2 && "F".equals(parts[0])) {
                throw new ActionRefusal("FLUID_OBJECT_UNSUPPORTED");
            } else {
                throw new ActionRefusal("BAD_SOURCE_ID");
            }
        } catch (ActionRefusal refusal) {
            throw refusal;
        } catch (Throwable malformed) {
            throw new ActionRefusal("BAD_SOURCE_ID");
        }

        if (!value(fingerprint).equals(source.fingerprint)) {
            throw new ActionRefusal("FINGERPRINT_CHANGED");
        }
        if (revision != null && !value(revision).equals(source.revision)) {
            throw new ActionRefusal("REVISION_CHANGED");
        }
        if (location != ItemLocation.CONTAINER) {
            if (location == ItemLocation.CARRIED) {
                item = findItem(shell.getInventory(), itemId, itemType, 0);
                if (countItemId(shell.getInventory(), itemId, 0) != 1
                        || countItemId(permissionContainer, itemId, 0) != 0) {
                    throw new ActionRefusal("ITEM_CONFLICT");
                }
            } else if (worldItem == null) {
                item = findItem(sourceContainer, itemId, itemType, 0);
                if (item != null) sourceContainer = item.getContainer();
            }
            if (item == null) throw new ActionRefusal("ITEM_MISSING");
            if (item.getID() != itemId
                    || !value(itemType).equals(value(item.getFullType()))) {
                throw new ActionRefusal("ITEM_CHANGED");
            }
        }
        return new Located(source, item, sourceContainer, permissionContainer,
            worldItem, square, sourceVehicle, sourceVehiclePart);
    }

    private static Source containerSourceKnown(IsoGridSquare square,
            IsoObject object, ItemContainer container, int containerIndex,
            String token) {
        long building = buildingId(square);
        String id = "C:" + token + ":" + containerIndex;
        Source source = new Source(id, containerFingerprint(square, object, container,
            containerIndex, token), "container", square.getX(), square.getY(),
            square.getZ(), building, container.isExplored());
        source.containerType = value(container.getType());
        if (container.isExplored()) addItems(source, container.getItems(), 0);
        source.finish();
        return source;
    }

    private static String containerFingerprint(IsoGridSquare square,
            IsoObject object, ItemContainer container, int containerIndex, String token) {
        String physical = object.getClass().getName() + "|"
            + value(object.getSpriteName()) + "|" + value(container.getType())
            + "|" + buildingId(square) + "|" + square.getX() + "|" + square.getY()
            + "|" + square.getZ() + "|" + containerIndex + "|" + token;
        return digest(physical);
    }

    private static Source groundSourceKnown(IsoGridSquare square,
            IsoWorldInventoryObject worldObject, String token) {
        InventoryItem item = worldObject.getItem();
        String id = "G:" + token;
        String physical = value(item.getFullType()) + "|" + item.getID() + "|"
            + square.getX() + "|" + square.getY() + "|" + square.getZ()
            + "|" + token;
        Source source = new Source(id, digest(physical), "ground", square.getX(),
            square.getY(), square.getZ(), buildingId(square), true);
        if(networkStockAvailable(item))source.items.add(ItemRow.of(item));
        source.finish();
        return source;
    }

    private static InventoryItem findItem(ItemContainer container, int itemId,
            String itemType, int depth) {
        if (container == null || depth > MAX_CONTAINER_DEPTH) return null;
        for (InventoryItem candidate : new ArrayList<>(container.getItems())) {
            if (candidate == null) continue;
            if (candidate.getID() == itemId
                    && value(itemType).equals(value(candidate.getFullType()))) {
                return candidate;
            }
            if (candidate instanceof InventoryContainer nested) {
                InventoryItem found = findItem(nested.getInventory(), itemId,
                    itemType, depth + 1);
                if (found != null) return found;
            }
        }
        return null;
    }

    static IsoGridSquare interactionSquare(IsoPlayer shell,
            IsoGridSquare source) {
        if (shell == null || source == null || shell.getCell() == null) return null;
        IsoGridSquare best = null;
        float bestDistance = Float.POSITIVE_INFINITY;
        for (int dy = -1; dy <= 1; dy++) {
            for (int dx = -1; dx <= 1; dx++) {
                IsoGridSquare candidate = shell.getCell().getGridSquare(
                    source.getX() + dx, source.getY() + dy, source.getZ());
                if (candidate == null || !candidate.isFree(false)) continue;
                if (candidate != source && candidate.isSomethingTo(source)) continue;
                float px = candidate.getX() + 0.5f - shell.getX();
                float py = candidate.getY() + 0.5f - shell.getY();
                float distance = px * px + py * py;
                if (best == null || distance < bestDistance) {
                    best = candidate;
                    bestDistance = distance;
                }
            }
        }
        return best;
    }

    /** Use the same named part area that vanilla vehicle interactions path to. */
    static IsoGridSquare vehicleInteractionSquare(BaseVehicle vehicle,
            VehiclePart part) {
        if (vehicle == null || part == null || part.getArea() == null
                || part.getArea().isBlank()) return null;
        IsoGridSquare square = vehicle.getSquareForArea(part.getArea());
        return square != null && square.isFree(false) ? square : null;
    }

    private static boolean squareWithinReach(IsoPlayer shell,
            IsoGridSquare square) {
        if (shell == null || square == null || shell.getCell() == null
                || square.getCell() != shell.getCell()
                || square.getZ() != (int) shell.getZ()) return false;
        IsoGridSquare here = shell.getCurrentSquare();
        if (here == null) return false;
        float dx = shell.getX() - (square.getX() + 0.5f);
        float dy = shell.getY() - (square.getY() + 0.5f);
        return dx * dx + dy * dy <= 4.0f && !here.isSomethingTo(square);
    }

    private static float fluidAmount(InventoryItem item) {
        FluidContainer fluids = item == null
            ? null : item.getFluidContainerFromSelfOrWorldItem();
        return fluids == null ? 0.0f : fluids.getAmount();
    }

    private static final class ActionRefusal extends Exception {
        final String code;
        ActionRefusal(String code) {
            super(code);
            this.code = code;
        }
    }

    private static final class Located {
        final Source source;
        final InventoryItem item;
        final ItemContainer sourceContainer;
        final ItemContainer permissionContainer;
        final IsoWorldInventoryObject worldItem;
        final IsoGridSquare square;
        final BaseVehicle vehicle;
        final VehiclePart vehiclePart;
        Located(Source source, InventoryItem item, ItemContainer sourceContainer,
                ItemContainer permissionContainer,
                IsoWorldInventoryObject worldItem, IsoGridSquare square,
                BaseVehicle vehicle, VehiclePart vehiclePart) {
            this.source = source;
            this.item = item;
            this.sourceContainer = sourceContainer;
            this.permissionContainer = permissionContainer;
            this.worldItem = worldItem;
            this.square = square;
            this.vehicle = vehicle;
            this.vehiclePart = vehiclePart;
        }
    }

    private static final class InspectionBinding {
        final String id, fingerprint;
        final java.lang.ref.WeakReference<IsoObject> object;
        final java.lang.ref.WeakReference<ItemContainer> container;
        final java.lang.ref.WeakReference<zombie.entity.components.fluids.FluidContainer> fluid;
        final java.lang.ref.WeakReference<IsoGridSquare> square;
        final int index;
        final int sourceX, sourceY, sourceZ, x, y, z;
        final double distance;
        String observedRevision;
        InspectionBinding(String id, String fingerprint, IsoObject object,
                ItemContainer container, int index, IsoGridSquare square,
                IsoGridSquare approach, IsoPlayer shell) {
            this.id = id; this.fingerprint = fingerprint;
            this.object = new java.lang.ref.WeakReference<>(object);
            this.container = new java.lang.ref.WeakReference<>(container);
            this.fluid = new java.lang.ref.WeakReference<>(index < 0 ? object.getFluidContainer() : null);
            this.square = new java.lang.ref.WeakReference<>(square);
            this.index = index;
            this.sourceX = square.getX(); this.sourceY = square.getY(); this.sourceZ = square.getZ();
            this.x = approach.getX(); this.y = approach.getY(); this.z = approach.getZ();
            double dx = approach.getX() + 0.5 - shell.getX();
            double dy = approach.getY() + 0.5 - shell.getY();
            this.distance = dx * dx + dy * dy;
        }
    }

    private static final class ActionBinding {
        InventoryItem item;
        final ItemContainer sourceContainer;
        final ItemContainer originContainer;
        final ItemContainer permissionContainer;
        final IsoWorldInventoryObject worldItem;
        String category = "";
        int usesBefore;
        float currentUsesBefore;
        float amountBefore;
        float hungerBefore;
        float thirstBefore;
        boolean useStarted;
        boolean settled;

        ActionBinding(Located located) {
            item = located.item;
            sourceContainer = located.sourceContainer;
            originContainer = item == null ? null : item.getContainer();
            permissionContainer = located.permissionContainer;
            worldItem = located.worldItem;
        }

        ActionBinding(InventoryItem item) {
            this.item = item;
            sourceContainer = null;
            originContainer = item == null ? null : item.getContainer();
            permissionContainer = null;
            worldItem = null;
        }
    }

    private static final class Busy extends Exception {
        Busy(String message) {
            super(message);
        }
    }

    private static final class LoadedChunk {
        final IsoChunk chunk;
        final boolean borrowed;

        LoadedChunk(IsoChunk chunk, boolean borrowed) {
            this.chunk = chunk;
            this.borrowed = borrowed;
        }
    }

    private static final class Snapshot {
        final int chunkX;
        final int chunkY;
        final ArrayList<Source> sources = new ArrayList<>();
        final Map<String, Source> byId = new LinkedHashMap<>();
        String status = "OBSERVED";
        String detail = "";
        String mode = "loaded";
        String revision = "";
        boolean identitiesStamped;

        Snapshot(int chunkX, int chunkY) {
            this.chunkX = chunkX;
            this.chunkY = chunkY;
        }

        void add(Source source) {
            if (sources.size() >= MAX_SOURCES_PER_CHUNK) {
                throw new IllegalStateException("native chunk source count exceeds bound");
            }
            Source previous = byId.put(source.id, source);
            if (previous != null) {
                throw new IllegalStateException("duplicate native source identity " + source.id);
            }
            sources.add(source);
        }

        void finish() {
            sources.sort(Comparator.comparing(source -> source.id));
            revision = snapshotRevision(sources);
        }
    }

    private static final class Source {
        final String id;
        final String fingerprint;
        final String kind;
        final int x;
        final int y;
        final int z;
        final long buildingId;
        final boolean explored;
        final ArrayList<ItemRow> items = new ArrayList<>();
        final Map<String, Float> quantities = new LinkedHashMap<>();
        String containerType = "";
        String plumbing = "";
        Boolean inspected, connected, active, outside, powered;
        Integer generatorCondition;
        Float generatorFuel, generatorMaxFuel;
        String revision = "";
        String state = "unknown";
        String access = "unknown";
        Source(String id, String fingerprint, String kind, int x, int y, int z,
                long buildingId, boolean explored) {
            this.id = id;
            this.fingerprint = fingerprint;
            this.kind = kind;
            this.x = x;
            this.y = y;
            this.z = z;
            this.buildingId = buildingId;
            this.explored = explored;
        }

        void finish() {
            items.sort(Comparator.comparingInt(row -> row.itemId));
            StringBuilder exact = new StringBuilder(explored ? "explored\n" : "unknown\n");
            if (!plumbing.isEmpty()) exact.append("plumbing=").append(plumbing).append('\n');
            if (inspected != null) exact.append("utility=").append(kind).append(':').append(inspected).append(':')
                .append(generatorCondition).append(':').append(generatorFuel).append(':').append(generatorMaxFuel).append(':')
                .append(connected).append(':').append(active).append(':').append(outside).append(':').append(powered).append('\n');
            for (ItemRow item : items) {
                item.addQuantities(quantities);
                exact.append(item.revisionLine()).append('\n');
            }
            revision = digest(exact.toString());
            if (!explored) {
                state = "unknown";
            } else if ("generator".equals(kind) || "power-consumer".equals(kind)) {
                state = "available";
            } else if ("fluid".equals(kind)) {
                state = !items.isEmpty() && items.get(0).amount > 0.0f
                    ? "available" : "spent";
            } else if (items.isEmpty()) {
                state = "spent";
            } else {
                state = "available";
            }
        }
    }

    private static final class ItemRow {
        final int itemId;
        final String fullType;
        final int uses;
        final float currentUses;
        final int condition;
        final float amount;
        final String fluid;
        final boolean poison;
        final boolean rotten;
        final boolean cleanWater;
        final boolean tainted;
        final float hydrationAmount;
        final ArrayList<String> categories;
        String ingredientState;
        float sharpness;
        ItemRow(int itemId, String fullType, int uses, float currentUses,
                int condition, float amount, String fluid,
                boolean poison, boolean rotten, boolean cleanWater, boolean tainted, float hydrationAmount,
                ArrayList<String> categories) {
            this.itemId = itemId;
            this.fullType = fullType;
            this.uses = uses;
            this.currentUses = currentUses;
            this.condition = condition;
            this.amount = amount;
            this.fluid = fluid;
            this.poison = poison;
            this.rotten = rotten;
            this.cleanWater = cleanWater;
            this.tainted = tainted;
            this.hydrationAmount = hydrationAmount;
            this.categories = categories;
        }

        static ItemRow of(InventoryItem item) {
            FluidContainer fluids = item.getFluidContainerFromSelfOrWorldItem();
            float amount = fluids == null ? 0.0f : fluids.getAmount();
            Fluid primary = fluids == null ? null : fluids.getPrimaryFluid();
            boolean poison = fluids != null && fluids.isPoisonous();
            boolean rotten = item.IsRotten();
            boolean cleanWater = fluids != null && amount > 0.0f
                && fluids.isWaterSource() && !poison && !fluids.isTainted();
            ArrayList<String> categories = categories(item, fluids, amount,
                cleanWater);
            var row = new ItemRow(item.getID(), value(item.getFullType()), item.getUses(),
                item.getCurrentUsesFloat(), item.getCondition(), amount,
                primary == null ? "" : value(primary.getFluidTypeString()),
                poison, rotten, cleanWater, fluids != null && fluids.isTainted(),
                Math.max(0.0f, SAONeeds.hydrationAmount(fluids)), categories);
            row.sharpness=item.getSharpness();
            row.ingredientState=digest(Float.toHexString(item.getSharpness())+"|"+item.isBroken()+"|"+item.isSealed()
                +"|"+item.isFavorite()+"|"+item.isEmptyOfFluid()+"|"+item.isFullOfFluid()+"|"+item.isCooked()+"|"+item.isBurnt()
                +"|"+(item instanceof zombie.inventory.types.Food food && food.isFrozen()));
            return row;
        }

        static ItemRow fluid(IsoObject object, float amount, Fluid fluid,
                boolean cleanWater, boolean tainted) {
            ArrayList<String> categories = new ArrayList<>();
            if (amount > 0.0f && (fluid == null || !fluid.isPoisonous())) {
                categories.add("drink");
                if (cleanWater) {
                    categories.add("water");
                }
            }
            return new ItemRow(0, "", 0, 0.0f, 0, amount,
                fluid == null ? "" : value(fluid.getFluidTypeString()),
                fluid != null && fluid.isPoisonous(), false, cleanWater, tainted,
                cleanWater ? amount : 0.0f,
                categories);
        }

        void addQuantities(Map<String, Float> into) {
            for (String category : categories) {
                float quantity = ("water".equals(category) || "drink".equals(category))
                    && amount > 0.0f ? amount : 1.0f;
                into.put(category, into.getOrDefault(category, 0.0f) + quantity);
            }
        }

        String revisionLine() {
            return itemId + "|" + fullType + "|" + uses + "|"
                + Float.toHexString(currentUses) + "|" + condition + "|"
                + Float.toHexString(amount) + "|" + fluid + "|" + poison + "|"
                + rotten + "|" + tainted + "|" + Float.toHexString(hydrationAmount)
                + "|" + String.join(",", categories)
                + (ingredientState==null ? "" : "|ingredientState="+ingredientState);
        }

        private static ArrayList<String> categories(InventoryItem item,
                FluidContainer fluids, float amount, boolean cleanWater) {
            ArrayList<String> out = new ArrayList<>();
            if (SAONeeds.isEdibleMaterial(item)) out.add("food");
            if (cleanWater || (fluids == null && item.isWaterSource())) out.add("water");
            if (fluids != null && amount > 0.0f && !fluids.isPoisonous()) out.add("drink");
            if (SAONeeds.wantsMaterial(item, "weapon")) out.add("weapons");
            if (SAONeeds.wantsMaterial(item, "medical")) out.add("medicine");
            if (SAONeeds.wantsMaterial(item, "tool")) out.add("tools");
            if (SAONeeds.wantsMaterial(item, "device")) out.add("device");
            if (SAONeeds.wantsMaterial(item, "smokes")) out.add("smokes");
            if (SAONeeds.wantsMaterial(item, "instrument")) out.add("instrument");
            if (SAOLeisureMaterials.recognizes(item.getFullType())) out.add("leisure-material");
            if (SAONeeds.wantsMaterial(item, "memento")) out.add("memento");
            if (SAONeeds.wantsMaterial(item, "reading")) out.add("reading");
            if (SAONeeds.wantsMaterial(item, "glass-pane")) out.add("glass-pane");
            if (SAONeeds.wantsMaterial(item, "hammer")) out.add("hammer");
            for(String kind:List.of("movable-window","metal-bar","small-sheet-metal","shelter-manual","metal-pipe","wire","scrap-metal","welding-torch","welding-rods","gate-manual"))
                if(SAONeeds.wantsMaterial(item,kind))out.add(kind);
            if (SAONeeds.wantsMaterial(item, "pipe-wrench")) out.add("pipe-wrench");
            if (SAONeeds.wantsMaterial(item, "garbage-bag")) out.add("garbage-bag");
            if (SAONeeds.wantsMaterial(item, "mattress")) out.add("mattress");
            if (SAONeeds.wantsMaterial(item, "hinge")) out.add("hinge");
            if (SAONeeds.wantsMaterial(item, "doorknob")) out.add("doorknob");
            if (SAONeeds.wantsMaterial(item, "tarp")) out.add("tarp");
            if (SAONeeds.wantsMaterial(item, "electronics-scrap")) out.add("electronics-scrap");
            if (SAONeeds.wantsMaterial(item, "petrol")) out.add("petrol");
            if (SAONeeds.wantsMaterial(item, "generator-manual")) out.add("generator-manual");
            if (SAONeeds.wantsMaterial(item, "plank")) out.add("plank");
            if (SAONeeds.wantsMaterial(item, "log")) out.add("log");
            if (SAONeeds.wantsMaterial(item, "saw")) out.add("saw");
            if (SAONeeds.wantsMaterial(item, "file")) out.add("file");
            if (SAONeeds.wantsMaterial(item, "whetstone")) out.add("whetstone");
            if (SAONeeds.wantsMaterial(item, "nails")) out.add("nails");
            if (SAONeeds.wantsMaterial(item, "fuel")) out.add("fuel");
            Collections.sort(out);
            return out;
        }
    }
    // Proposed original generic site/result observation. Physical/private work
    // and all Standing/admission/freshness receipts remain existing Lua owners.
    private static final Map<SAOIsoPlayerShell,LinkedHashMap<String,ConstructionSiteBinding>> CONSTRUCTION_SITES=new WeakHashMap<>();
    private static final int[][] CONSTRUCTION_SIDES={{-1,0},{1,0},{0,-1},{0,1}};
    private static final class ConstructionDefinition {
        final zombie.scripting.entity.GameEntityScript entity;
        final zombie.entity.components.spriteconfig.SpriteConfigManager.ObjectInfo info;
        final zombie.entity.components.spriteconfig.SpriteConfigManager.FaceInfo face;
        final String entityId,recipeId,faceName,sourceRevision;
        final int cursor;
        ConstructionDefinition(String entityId,String name,int cursor) {
            this.entityId=entityId;this.cursor=cursor;
            entity=zombie.scripting.ScriptManager.instance.getGameEntityScript(entityId);
            if(entity==null)throw new IllegalArgumentException("registered construction entity required");
            var config=(zombie.scripting.entity.components.spriteconfig.SpriteConfigScript)entity.getComponentScriptFor(zombie.entity.ComponentType.SpriteConfig);
            var recipeComponent=(zombie.scripting.entity.components.crafting.CraftRecipeComponentScript)entity.getComponentScriptFor(zombie.entity.ComponentType.CraftRecipe);
            if(config==null||recipeComponent==null)throw new IllegalArgumentException("native build components required");
            info=zombie.entity.components.spriteconfig.SpriteConfigManager.GetObjectInfo(config.getName());
            var recipe=recipeComponent.getCraftRecipe();
            if(info==null||info.getScript()!=config||info.getRecipe()==null||info.getRecipe().getCraftRecipe()!=recipe
                    ||zombie.scripting.ScriptManager.instance.getCraftRecipe(recipe.getScriptObjectFullType())!=recipe)
                throw new IllegalArgumentException("current registered recipe identity required");
            String expected=cursor==1?"W":cursor==2?"N":cursor==3?"E":cursor==4?"S":null;
            if(expected==null||name==null||!expected.equalsIgnoreCase(name))throw new IllegalArgumentException("exact selected cursor required");
            face=info.getFace(name);if(face==null||!expected.equalsIgnoreCase(face.getFaceName()))throw new IllegalArgumentException("face fallback refused");
            faceName=expected;recipeId=recipe.getScriptObjectFullType();
            StringBuilder signature=new StringBuilder(recipeRevision(recipe));
            signature.append('|').append(entityId).append('|').append(info.getVersion()).append('|').append(cursor)
                .append('|').append(config.isProp()).append('|').append(config.getOnIsValid()).append('|').append(config.getOnCreate())
                .append('|').append(face.getWidth()).append('|').append(face.getHeight()).append('|').append(face.getzLayers())
                .append('|').append(face.getMasterX()).append('|').append(face.getMasterY()).append('|').append(face.getMasterZ());
            for(int i=0;i<config.getPreviousStages().size();i++)signature.append('|').append(config.getPreviousStages().get(i));
            var benchScript=(zombie.scripting.entity.components.crafting.CraftBenchScript)entity.getComponentScriptFor(zombie.entity.ComponentType.CraftBench);
            if(benchScript!=null){signature.append("|bench:").append(benchScript.getRecipeTagQuery());if(benchScript.getRecipes()!=null)for(var r:benchScript.getRecipes())signature.append('|').append(recipeRevision(r));}
            for(int z=0;z<face.getzLayers();z++)for(int y=0;y<face.getHeight();y++)for(int x=0;x<face.getWidth();x++){
                var tile=face.getTileInfo(x,y,z);signature.append('|').append(x).append(',').append(y).append(',').append(z);
                if(tile!=null)signature.append(':').append(tile.getSpriteName()).append(':').append(tile.isBlocking()).append(':').append(tile.isMaster())
                    .append(':').append(tile.getMasterOffsetX()).append(':').append(tile.getMasterOffsetY()).append(':').append(tile.getMasterOffsetZ());
            }
            sourceRevision=digest(signature.toString());
        }
        boolean member(int x,int y,int z){var t=face.getTileInfo(x,y,z);return t!=null&&(t.getSpriteName()!=null||t.isBlocking());}
        se.krka.kahlua.vm.KahluaTable geometry(){
            var row=recipeTable();row.rawset("face",face.getFaceName());row.rawset("selectedFace",faceName);row.rawset("cursor",(double)cursor);
            row.rawset("width",(double)face.getWidth());row.rawset("height",(double)face.getHeight());row.rawset("zLayers",(double)face.getzLayers());
            row.rawset("masterX",(double)face.getMasterX());row.rawset("masterY",(double)face.getMasterY());row.rawset("masterZ",(double)face.getMasterZ());
            row.rawset("masterSet",face.isMasterSet());row.rawset("multiSquare",face.isMultiSquare());var tiles=recipeTable();int count=0,occupied=0,blocking=0;
            for(int z=0;z<face.getzLayers();z++)for(int y=0;y<face.getHeight();y++)for(int x=0;x<face.getWidth();x++){
                var t=face.getTileInfo(x,y,z);if(t==null)continue;var v=recipeTable();v.rawset("x",(double)t.getX());v.rawset("y",(double)t.getY());v.rawset("z",(double)t.getZ());
                v.rawset("sprite",t.getSpriteName());v.rawset("occupied",t.getSpriteName()!=null);v.rawset("blocking",t.isBlocking());v.rawset("empty",t.isEmpty());v.rawset("master",t.isMaster());
                v.rawset("masterOffsetX",(double)t.getMasterOffsetX());v.rawset("masterOffsetY",(double)t.getMasterOffsetY());v.rawset("masterOffsetZ",(double)t.getMasterOffsetZ());
                if(t.getSpriteName()!=null)occupied++;if(t.isBlocking())blocking++;tiles.rawset((double)++count,v);
            }
            row.rawset("tiles",tiles);row.rawset("occupiedCount",(double)occupied);row.rawset("blockingCount",(double)blocking);return row;
        }
    }
    private static final class ConstructionSquareSnapshot {
        final java.lang.ref.WeakReference<IsoGridSquare> square;
        final ArrayList<java.lang.ref.WeakReference<IsoObject>> objects=new ArrayList<>();final ArrayList<String> sprites=new ArrayList<>();
        ConstructionSquareSnapshot(IsoGridSquare s){square=new java.lang.ref.WeakReference<>(s);for(int i=0;i<s.getObjects().size();i++){var o=s.getObjects().get(i);objects.add(new java.lang.ref.WeakReference<>(o));sprites.add(o.getSpriteName());}}
        boolean matches(IsoGridSquare s){if(s==null||square.get()!=s||objects.size()!=s.getObjects().size())return false;
            for(int i=0;i<objects.size();i++)if(objects.get(i).get()!=s.getObjects().get(i)||!java.util.Objects.equals(sprites.get(i),s.getObjects().get(i).getSpriteName()))return false;return true;}
    }
    private static final class ConstructionSiteBinding {
        final String actor,key,revision=UUID.randomUUID().toString(),sourceRevision;final ConstructionDefinition definition;
        final int x,y,z,ax,ay,az;final ArrayList<ConstructionSquareSnapshot> squares=new ArrayList<>();final ConstructionSquareSnapshot approach;
        ConstructionSiteBinding(String actor,String key,SAOIsoPlayerShell body,ConstructionDefinition d,int x,int y,int z,IsoGridSquare a){
            this.actor=actor;this.key=key;definition=d;sourceRevision=d.sourceRevision;this.x=x;this.y=y;this.z=z;ax=a.getX();ay=a.getY();az=a.getZ();approach=new ConstructionSquareSnapshot(a);
            for(int dz=0;dz<d.face.getzLayers();dz++)for(int dy=0;dy<d.face.getHeight();dy++)for(int dx=0;dx<d.face.getWidth();dx++)if(d.member(dx,dy,dz))squares.add(new ConstructionSquareSnapshot(body.getCell().getGridSquare(x+dx,y+dy,z+dz)));
        }
        boolean matches(String actor,SAOIsoPlayerShell body,ConstructionDefinition d){
            if(!this.actor.equals(actor)||definition.entity!=d.entity||definition.info!=d.info||definition.face!=d.face||!sourceRevision.equals(d.sourceRevision))return false;
            int i=0;for(int dz=0;dz<d.face.getzLayers();dz++)for(int dy=0;dy<d.face.getHeight();dy++)for(int dx=0;dx<d.face.getWidth();dx++)if(d.member(dx,dy,dz))
                if(!squares.get(i++).matches(body.getCell().getGridSquare(x+dx,y+dy,z+dz)))return false;
            return approach.matches(body.getCell().getGridSquare(ax,ay,az));
        }
        se.krka.kahlua.vm.KahluaTable plain(){var t=recipeTable();t.rawset("key",key);t.rawset("revision",revision);t.rawset("sourceRevision",sourceRevision);t.rawset("entityId",definition.entityId);t.rawset("recipeId",definition.recipeId);
            t.rawset("actorId",actor);t.rawset("face",definition.faceName);t.rawset("cursor",(double)definition.cursor);t.rawset("x",(double)x);t.rawset("y",(double)y);t.rawset("z",(double)z);
            t.rawset("approachX",(double)ax);t.rawset("approachY",(double)ay);t.rawset("approachZ",(double)az);t.rawset("geometry",definition.geometry());t.rawset("observedAtHours",zombie.GameTime.getInstance().getWorldAgeHours());
            t.rawset("standingRequired",true);t.rawset("privateAcquisitionRequired",true);t.rawset("physicalWorkReceiptRequired",true);return t;}
    }
    private static boolean constructionVisible(SAOIsoPlayerShell body,IsoGridSquare s,float radius){return SAOPerceptionScanner.canSeeWorldSquareNow(body,s,radius);}
    private static boolean constructionApproachFree(SAOIsoPlayerShell body,IsoGridSquare square){
        if(square==null||!square.isSolidFloor()||!square.isFree(false)||square.isSolid()||square.isSolidTrans()||square.HasStairs()||square.HasTree()||square.haveFire()||square.isVehicleIntersecting())return false;
        for(var m:square.getMovingObjects())if(m!=body&&m.isCharacter())return false;return true;
    }
    private static se.krka.kahlua.vm.KahluaTable constructionCursor(SAOIsoPlayerShell body,ConstructionDefinition d){
        var env=zombie.Lua.LuaManager.env;var cls=table(env.rawget("ISBuildIsoEntity"));if(cls==null||cls.rawget("new")==null)throw new IllegalArgumentException("installed construction cursor unavailable");
        var containers=new ArrayList<ItemContainer>();containers.add(body.getInventory());var logic=new zombie.entity.components.build.BuildLogic(body,null,null);logic.setContainers(containers);
        // The exact ObjectInfo/recipe is already registered and supplied.
        // Native setRecipes is an unrelated UI filter with implicit player0.
        var preference=body.getModData().rawget("buildLastRecipe");
        try{logic.setRecipe(d.info.getRecipe().getCraftRecipe());
            Object[] returned=zombie.Lua.LuaManager.caller.pcall(zombie.Lua.LuaManager.thread,cls.rawget("new"),cls,body,d.info,(double)d.cursor,containers,logic);
            if(returned.length<2||!Boolean.TRUE.equals(returned[0])||!(returned[1]instanceof se.krka.kahlua.vm.KahluaTable cursor))throw new IllegalArgumentException("native cursor initialization refused");return cursor;
        }finally{body.getModData().rawset("buildLastRecipe",preference);}
    }
    private static boolean constructionNativeFootprint(SAOIsoPlayerShell body,ConstructionDefinition d,int x,int y,int z,float radius){
        var cursor=constructionCursor(body,d);var cls=table(zombie.Lua.LuaManager.env.rawget("ISBuildIsoEntity"));Object method=cls.rawget("isValidPerSquare");if(method==null)return false;
        // Material-independent native placement policy. Original effect-time
        // isValid and exact material/action admission remain the physical owner.
        cursor.rawset("north",d.cursor==2);cursor.rawset("west",d.cursor==1);cursor.rawset("east",d.cursor==3);cursor.rawset("south",d.cursor==4);
        for(int dz=0;dz<d.face.getzLayers();dz++)for(int dy=0;dy<d.face.getHeight();dy++)for(int dx=0;dx<d.face.getWidth();dx++)if(d.member(dx,dy,dz)){
            var square=body.getCell().getGridSquare(x+dx,y+dy,z+dz);if(!constructionVisible(body,square,radius))return false;
            Object[] returned=zombie.Lua.LuaManager.caller.pcall(zombie.Lua.LuaManager.thread,method,cursor,square,d.face.getTileInfo(dx,dy,dz),dz==0,dy>0,dx>0);
            if(returned.length<2||!Boolean.TRUE.equals(returned[0])||!Boolean.TRUE.equals(returned[1]))return false;
        }return true;
    }
    private static boolean constructionApproachEligible(SAOIsoPlayerShell body,ConstructionDefinition d,int x,int y,int z,IsoGridSquare square,float radius){
        if(!constructionVisible(body,square,radius)||!constructionApproachFree(body,square)||square.getCell()!=body.getCell()
                ||body.getCell().getGridSquare(square.getX(),square.getY(),square.getZ())!=square||square.getZ()!=z)return false;
        int ax=square.getX(),ay=square.getY();
        if(ax>=x&&ax<x+d.face.getWidth()&&ay>=y&&ay<y+d.face.getHeight()&&d.member(ax-x,ay-y,0))return false;
        for(int dy=0;dy<d.face.getHeight();dy++)for(int dx=0;dx<d.face.getWidth();dx++)if(d.member(dx,dy,0)&&Math.abs(ax-x-dx)+Math.abs(ay-y-dy)==1){
            var touched=body.getCell().getGridSquare(x+dx,y+dy,z);
            if(touched!=null&&square.getRoom()==touched.getRoom()&&!square.isBlockedTo(touched)&&!square.isWallTo(touched)
                    &&!square.isDoorTo(touched)&&!square.isWindowTo(touched)&&!square.isHoppableTo(touched))return true;
        }return false;
    }
    private static IsoGridSquare constructionApproach(SAOIsoPlayerShell body,ConstructionDefinition d,int x,int y,int z,float radius){
        IsoGridSquare best=null;double distance=Double.POSITIVE_INFINITY;
        for(int dy=0;dy<d.face.getHeight();dy++)for(int dx=0;dx<d.face.getWidth();dx++)if(d.member(dx,dy,0))for(var side:CONSTRUCTION_SIDES){
            int ax=x+dx+side[0],ay=y+dy+side[1];if(ax>=x&&ax<x+d.face.getWidth()&&ay>=y&&ay<y+d.face.getHeight()&&d.member(ax-x,ay-y,0))continue;
            var square=body.getCell().getGridSquare(ax,ay,z);var touched=body.getCell().getGridSquare(x+dx,y+dy,z);
            if(!constructionApproachEligible(body,d,x,y,z,square,radius))continue;
            double value=Math.hypot(body.getX()-ax-.5,body.getY()-ay-.5);if(value<distance){best=square;distance=value;}
        }return best;
    }
    public static synchronized Object constructionSite(SAOIsoPlayerShell body,String entityId,String face,int cursor,int x,int y,int z,double radius){
        try{String actor=recipeActor(body);if(actor==null||!Double.isFinite(radius)||radius<0||Math.floor(body.getZ())!=z)return null;
            float range=(float)Math.min(INSPECTION_RANGE,radius);var d=new ConstructionDefinition(entityId,face,cursor);
            if(!constructionNativeFootprint(body,d,x,y,z,range))return null;var approach=constructionApproach(body,d,x,y,z,range);if(approach==null)return null;
            String key=entityId+":"+d.faceName+":"+cursor+":"+x+":"+y+":"+z;var sites=CONSTRUCTION_SITES.computeIfAbsent(body,ignored->new LinkedHashMap<>());var site=sites.get(key);
            if(site==null||!site.matches(actor,body,d)||!constructionApproachEligible(body,d,x,y,z,body.getCell().getGridSquare(site.ax,site.ay,site.az),range)){site=new ConstructionSiteBinding(actor,key,body,d,x,y,z,approach);sites.put(key,site);}
            while(sites.size()>MAX_INSPECTION_OPTIONS)sites.remove(sites.keySet().iterator().next());return site.plain();
        }catch(Throwable unavailable){return null;}
    }
    private static boolean constructionPlainSame(Object a,Object b){
        if(a instanceof se.krka.kahlua.vm.KahluaTable x&&b instanceof se.krka.kahlua.vm.KahluaTable y){
            if(x.getMetatable()!=null||y.getMetatable()!=null)return false;int n=0;var it=x.iterator();while(it.advance()){n++;if(!constructionPlainSame(it.getValue(),y.rawget(it.getKey())))return false;}
            int m=0;var jt=y.iterator();while(jt.advance())m++;return n==m;
        }return java.util.Objects.equals(a,b);
    }
    public static synchronized Object exactConstructionSite(SAOIsoPlayerShell body,se.krka.kahlua.vm.KahluaTable plain){
        try{String actor=recipeActor(body);if(actor==null||plain==null||plain.getMetatable()!=null)return null;var sites=CONSTRUCTION_SITES.get(body);var site=sites==null?null:sites.get((String)plain.rawget("key"));
            if(site==null||!site.revision.equals(plain.rawget("revision"))||!actor.equals(plain.rawget("actorId")))return null;
            var d=new ConstructionDefinition(site.definition.entityId,site.definition.faceName,site.definition.cursor);
            var expected=site.plain();for(String name:new String[]{"sourceRevision","entityId","recipeId","face","cursor","x","y","z","approachX","approachY","approachZ","geometry"})if(!constructionPlainSame(plain.rawget(name),expected.rawget(name)))return null;
            var approach=body.getCell().getGridSquare(site.ax,site.ay,site.az);
            if(!site.matches(actor,body,d)||!constructionApproachEligible(body,d,site.x,site.y,site.z,approach,INSPECTION_RANGE)
                    ||Math.hypot(body.getX()-site.ax-.5,body.getY()-site.ay-.5)>.35||Math.abs(body.getZ()-site.az)>.1
                    ||!constructionNativeFootprint(body,d,site.x,site.y,site.z,INSPECTION_RANGE))return null;
            return body.getCell().getGridSquare(site.x,site.y,site.z);
        }catch(Throwable unavailable){return null;}
    }
    // Result source provenance is distinct from each actual native object's identity.
    private static String constructionResultFactory(ConstructionDefinition d) {
        var script=d.info.getScript();String callback=script.getOnCreate();
        if(!script.getPreviousStages().isEmpty())return null;
        boolean hasCallback=callback!=null&&!callback.isBlank();
        if(script.isProp()) {
            return !hasCallback&&"Base.Log_Stool".equals(d.entityId)&&"Base.Log_Stool".equals(d.recipeId)
                &&("S".equals(d.faceName)||"E".equals(d.faceName))&&d.face.getWidth()==1&&d.face.getHeight()==1&&d.face.getzLayers()==1
                &&d.entity.getComponentScriptFor(zombie.entity.ComponentType.CraftBench)==null ? "native-moveable-prop" : null;
        }
        if(hasCallback) {
            return "Base.BarrelOven".equals(d.entityId)&&"Base.BarrelOven".equals(d.recipeId)&&"S".equals(d.faceName)
                &&"BuildRecipeCode.barrelOven.OnCreate".equals(callback)&&d.face.getWidth()==1&&d.face.getHeight()==1&&d.face.getzLayers()==1
                &&d.entity.getComponentScriptFor(zombie.entity.ComponentType.CraftBench)==null ? "native-oncreate-fireplace" : null;
        }
        return "native-thumpable";
    }
    // Reuse the existing exact-object workplace binding; private acquisition
    // and a fresh canonical owned work/result remain the Lua owners' authority.
    private static se.krka.kahlua.vm.KahluaTable constructionResultWorkplace(SAOIsoPlayerShell body,String actor,IsoObject part,
            zombie.entity.components.crafting.CraftBench bench,boolean surface) {
        if(bench==null&&!surface)return null;
        var square=part.getSquare();String key="W:"+square.getX()+":"+square.getY()+":"+square.getZ()+":"+part.getObjectIndex();
        var bindings=RECIPE_WORKPLACES.computeIfAbsent(body,ignored->new LinkedHashMap<>());
        var binding=bindings.get(key);
        if(binding==null||!binding.matches(actor,part,bench)){binding=new RecipeWorkplaceBinding(actor,key,part,bench);bindings.put(key,binding);}
        while(bindings.size()>MAX_INSPECTION_OPTIONS)bindings.remove(bindings.keySet().iterator().next());
        var row=recipeTable();row.rawset("key",key);row.rawset("revision",binding.revision);
        row.rawset("x",(double)square.getX());row.rawset("y",(double)square.getY());row.rawset("z",(double)square.getZ());return row;
    }
    private static se.krka.kahlua.vm.KahluaTable constructionResultRelation(IsoObject part,ConstructionDefinition d,int index,String actor) {
        if(!part.hasModData())return null;
        var relation=table(part.getModData().rawget("SAOPhysicalResult"));
        if(relation==null||relation.getMetatable()!=null)return null;
        var fields=java.util.Set.of("schema","workId","actorId","world","bodyToken","partIndex","sourceEntityId","recipeId",
            "siteKey","sourceRevision","face","cursor","x","y","z","sprite","nativeClass");
        var numeric=java.util.Set.of("partIndex","cursor","x","y","z");
        var out=recipeTable();int count=0;var iterator=relation.iterator();
        while(iterator.advance()){
            Object key=iterator.getKey(),value=iterator.getValue();if(!(key instanceof String name)||!fields.contains(name))return null;
            if(numeric.contains(name)) {
                if(!(value instanceof Number n))return null;double v=n.doubleValue();if(!Double.isFinite(v)||v!=Math.rint(v)||Math.abs(v)>2147483647)return null;
            }else if(!(value instanceof String s)||s.isBlank()||s.length()>512)return null;
            out.rawset(key,value);count++;
        }
        if(count!=fields.size()||!"sao.native-physical-result/1".equals(out.rawget("schema"))||!actor.equals(out.rawget("actorId"))
            ||!d.entityId.equals(out.rawget("sourceEntityId"))||!d.recipeId.equals(out.rawget("recipeId"))||!d.sourceRevision.equals(out.rawget("sourceRevision"))
            ||!d.faceName.equals(out.rawget("face"))||!Double.valueOf(d.cursor).equals(out.rawget("cursor"))||!Double.valueOf(index).equals(out.rawget("partIndex"))
            ||!Double.valueOf(part.getX()).equals(out.rawget("x"))||!Double.valueOf(part.getY()).equals(out.rawget("y"))||!Double.valueOf(part.getZ()).equals(out.rawget("z"))
            ||!part.getSpriteName().equals(out.rawget("sprite"))||!part.getClass().getName().equals(out.rawget("nativeClass")))return null;
        return out;
    }
    public static synchronized Object constructionCreated(SAOIsoPlayerShell body,se.krka.kahlua.vm.KahluaTable supplied,String entityId,String face,int cursor,int x,int y,int z){
        try{String actor=recipeActor(body);if(actor==null||supplied==null||supplied.getMetatable()!=null)return null;
            var d=new ConstructionDefinition(entityId,face,cursor);String factory=constructionResultFactory(d);if(factory==null)return null;
            var measured=recipeTable();var seen=java.util.Collections.newSetFromMap(new java.util.IdentityHashMap<IsoObject,Boolean>());int count=0;
            for(int dz=0;dz<d.face.getzLayers();dz++)for(int dy=0;dy<d.face.getHeight();dy++)for(int dx=0;dx<d.face.getWidth();dx++){
                var tile=d.face.getTileInfo(dx,dy,dz);if(tile==null||tile.getSpriteName()==null)continue;Object candidate=supplied.rawget((double)++count);
                if(!(candidate instanceof IsoObject part)||!seen.add(part))return null;
                var square=body.getCell().getGridSquare(x+dx,y+dy,z+dz);
                if(square==null||part.getSquare()!=square||part.getCell()!=body.getCell()||part.getObjectIndex()<0||!square.getObjects().contains(part)
                        ||!constructionVisible(body,square,INSPECTION_RANGE)||!tile.getSpriteName().equals(part.getSpriteName()))return null;
                var nativeEntity=part.getEntityScript();
                if("native-thumpable".equals(factory)) {
                    if(!(part instanceof IsoThumpable)||nativeEntity!=d.entity)return null;
                }else if("native-moveable-prop".equals(factory)) {
                    if(part.getClass()!=IsoThumpable.class||nativeEntity!=null&&nativeEntity!=d.entity)return null;
                }else if(part.getClass()!=zombie.iso.objects.IsoFireplace.class||nativeEntity!=null)return null;
                zombie.entity.components.crafting.CraftBench bench=part.getComponent(zombie.entity.ComponentType.CraftBench);
                var required=d.entity.getComponentScriptFor(zombie.entity.ComponentType.CraftBench);
                if(required instanceof zombie.scripting.entity.components.crafting.CraftBenchScript expected
                    &&(bench==null||bench.getGameEntity()!=part||!java.util.Objects.equals(bench.getRecipeTagQuery(),expected.getRecipeTagQuery())))return null;
                var row=recipeTable();row.rawset("x",(double)square.getX());row.rawset("y",(double)square.getY());row.rawset("z",(double)square.getZ());
                row.rawset("sprite",part.getSpriteName());row.rawset("nativeClass",part.getClass().getName());
                row.rawset("sourceEntityId",entityId);row.rawset("factoryPath",factory);
                if(nativeEntity!=null)row.rawset("entityId",nativeEntity.getScriptObjectFullType());
                row.rawset("objectIndex",(double)part.getObjectIndex());row.rawset("nativeEntityNetId",Long.toString(part.getEntityNetID()));
                row.rawset("nativeEntityNetIdKind","position-index");row.rawset("nativeInstanceIdentityEstablished",false);
                var relation=constructionResultRelation(part,d,count,actor);if(relation!=null)row.rawset("physicalResult",relation);
                row.rawset("master",tile.isMaster());row.rawset("blocking",tile.isBlocking());
                boolean surface=body.canUseAsGenericCraftingSurface(part);
                row.rawset("genericSurface",part.isGenericCraftingSurface());row.rawset("currentUsableSurface",surface);row.rawset("craftBench",bench!=null);
                var workplace=constructionResultWorkplace(body,actor,part,bench,surface);
                if(workplace!=null)row.rawset("recipeWorkplace",workplace);
                if(bench!=null)row.rawset("recipeTagQuery",bench.getRecipeTagQuery());measured.rawset((double)count,row);
            }
            if(count==0||supplied.len()!=count)return null;
            var result=recipeTable();result.rawset("actorId",actor);result.rawset("sourceEntityId",entityId);result.rawset("recipeId",d.recipeId);
            if("native-thumpable".equals(factory))result.rawset("entityId",entityId);
            result.rawset("factoryPath",factory);result.rawset("sourceRevision",d.sourceRevision);
            result.rawset("face",d.faceName);result.rawset("cursor",(double)cursor);result.rawset("x",(double)x);result.rawset("y",(double)y);result.rawset("z",(double)z);
            result.rawset("geometry",d.geometry());result.rawset("parts",measured);result.rawset("observedAtHours",zombie.GameTime.getInstance().getWorldAgeHours());
            result.rawset("ownedPhysicalReceiptRequired",true);result.rawset("preexistingBaselineRequired",true);result.rawset("standingRequired",true);result.rawset("observationOnly",true);return result;
        }catch(Throwable unavailable){return null;}
    }

    /** Registered potential workspace means; no local site, stock or station observation. */
    public static synchronized Object constructionMeans(SAOIsoPlayerShell body, se.krka.kahlua.vm.KahluaTable request) {
        try {
            var out=recipeTable();String actor=recipeActor(body);
            var purpose=constructionMeansPurpose(body,actor,request);
            if(purpose==null)return out;
            String requestingId=(String)request.rawget("recipeId"),sourceRevision=(String)request.rawget("sourceRevision");
            var requesting=zombie.scripting.ScriptManager.instance.getCraftRecipe(requestingId);
            if(requesting==null || requesting.needToBeLearn()&&!body.isRecipeActuallyKnown(requesting)
                    || !Boolean.valueOf(requesting.isAnySurfaceCraft()).equals(request.rawget("anySurface"))
                    || !Boolean.valueOf(requesting.requiresSpecificWorkstation()).equals(request.rawget("specificWorkstation")))return out;
            boolean anySurface=requesting.isAnySurfaceCraft(),specific=requesting.requiresSpecificWorkstation();
            if(!anySurface&&!specific)return out;
            var sao=table(zombie.Lua.LuaManager.env.rawget("SAO"));
            var policy=sao==null?null:table(sao.rawget("ConstructionPolicy"));
            Object describe=policy==null?null:policy.rawget("describe");
            if(describe==null)return null;
            int count=0;
            // Native BuildLogic lookup may refresh the manager's returned list.
            for(var entity:new ArrayList<>(zombie.scripting.ScriptManager.instance.getAllGameEntities())) {
                String entityId=entity.getScriptObjectFullType();
                if(zombie.scripting.ScriptManager.instance.getGameEntityScript(entityId)!=entity)continue;
                zombie.scripting.entity.components.spriteconfig.SpriteConfigScript sprite=entity.getComponentScriptFor(zombie.entity.ComponentType.SpriteConfig);
                zombie.scripting.entity.components.crafting.CraftRecipeComponentScript component=entity.getComponentScriptFor(zombie.entity.ComponentType.CraftRecipe);
                if(sprite==null||component==null)continue;
                var recipe=component.getCraftRecipe();
                if(recipe==null||zombie.scripting.ScriptManager.instance.getCraftRecipe(recipe.getScriptObjectFullType())!=recipe
                        || recipe.needToBeLearn()&&!body.isRecipeActuallyKnown(recipe))continue;
                boolean skills=true;
                for(int n=0;n<recipe.getRequiredSkillCount();n++)if(!zombie.entity.components.crafting.recipe.CraftRecipeManager.hasPlayerRequiredSkill(recipe.getRequiredSkill(n),body))skills=false;
                if(!skills)continue;
                var info=zombie.entity.components.spriteconfig.SpriteConfigManager.GetObjectInfo(sprite.getName());
                if(info==null||info.getScript()!=sprite||info.getRecipe()!=component)continue;
                zombie.scripting.entity.components.crafting.CraftBenchScript bench=entity.getComponentScriptFor(zombie.entity.ComponentType.CraftBench);
                boolean supportedBench=specific&&bench!=null&&bench.getRecipes()!=null&&bench.getRecipes().contains(requesting);
                if(specific&&!supportedBench)continue;
                String[] cardinal={"W","N","E","S"};
                for(int direction=0;direction<4;direction++) {
                    var face=info.getFace(cardinal[direction]);if(face==null)continue;
                    String supportSprite=null;
                    if(anySurface) {
                        for(int z=0;z<face.getzLayers()&&supportSprite==null;z++)
                        for(int y=0;y<face.getHeight()&&supportSprite==null;y++)
                        for(int x=0;x<face.getWidth()&&supportSprite==null;x++) {
                            var tile=face.getTileInfo(x,y,z);if(tile==null||tile.getSpriteName()==null)continue;
                            var original=zombie.iso.sprite.IsoSpriteManager.instance.getSprite(tile.getSpriteName());
                            if(original==null||!tile.getSpriteName().equals(original.getName()))continue;
                            // Metadata-only native receiver: never placed, inserted or given components.
                            var receiver=new IsoObject(null,null,original);
                            if(receiver.isGenericCraftingSurface())supportSprite=tile.getSpriteName();
                        }
                        if(supportSprite==null)continue;
                    }
                    var selected=recipeTable();selected.rawset("face",cardinal[direction]);selected.rawset("cursor",(double)(direction+1));
                    Object[] described=zombie.Lua.LuaManager.caller.pcall(zombie.Lua.LuaManager.thread,describe,
                        new Object[]{entityId,body,purpose,selected});
                    var candidate=described.length>1&&Boolean.TRUE.equals(described[0])?table(described[1]):null;
                    if(candidate==null||!Boolean.TRUE.equals(candidate.rawget("admissible")))continue;
                    var requirements=table(candidate.rawget("requirements"));var shape=requirements==null?null:table(requirements.rawget("geometry"));
                    if(requirements==null||shape==null||!entityId.equals(requirements.rawget("entity"))
                            ||!recipe.getScriptObjectFullType().equals(requirements.rawget("recipe")))continue;
                    var row=recipeTable();var relationship=recipeTable();
                    row.rawset("entityId",entityId);row.rawset("recipeId",recipe.getScriptObjectFullType());row.rawset("face",shape.rawget("face"));
                    row.rawset("cursor",(double)(direction+1));row.rawset("sourceRevision",sourceRevision);
                    String nativeRevision=digest(entityId+"|"+info.getVersion()+"|"+recipeRevision(recipe)+"|"+cardinal[direction]
                        +"|"+requestingId+"|"+(bench==null?"":bench.getRecipeTagQuery())+"|"+value(supportSprite));
                    row.rawset("nativeRevision",nativeRevision);row.rawset("knowledgeKind",recipe.needToBeLearn()?"acquired":"intrinsic");
                    if(recipe.needToBeLearn())row.rawset("acquisitionId","native-known:"+actor+":"+recipe.getScriptObjectFullType()+":"+recipeRevision(recipe));
                    relationship.rawset("status","potential");relationship.rawset("requestingRecipeId",requestingId);
                    relationship.rawset("kind",specific?"specific-workstation":"generic-surface");
                    if(specific)relationship.rawset("recipeTagQuery",bench.getRecipeTagQuery());
                    if(supportSprite!=null)relationship.rawset("sprite",supportSprite);
                    relationship.rawset("localObservation",false);relationship.rawset("stockKnown",false);relationship.rawset("siteKnown",false);
                    row.rawset("workspaceRelationship",relationship);out.rawset((double)++count,row);
                }
            }
            return out;
        }catch(Throwable unavailable){return null;}
    }

    private static se.krka.kahlua.vm.KahluaTable constructionMeansPurpose(SAOIsoPlayerShell body,String actor,se.krka.kahlua.vm.KahluaTable request) {
        if(actor==null||request==null||!actor.equals(request.rawget("actorId"))
                ||!(request.rawget("purposeId") instanceof String purposeId)||purposeId.isBlank()
                ||!(request.rawget("stepId") instanceof String stepId)||stepId.isBlank()
                ||!(request.rawget("recipeId") instanceof String recipeId)||recipeId.isBlank()
                ||!(request.rawget("sourceRevision") instanceof String revision)||revision.isBlank()
                ||!(request.rawget("nativeRevision") instanceof String nativeRevision)||nativeRevision.isBlank())return null;
        var recordsRoot=zombie.world.moddata.GlobalModData.instance.get("SurvivorAwareness_Records");
        var records=recordsRoot==null?null:table(recordsRoot.rawget("records"));var record=records==null?null:table(records.rawget(actor));
        var planning=record==null?null:table(record.rawget("proceduralPlanning"));var purposes=planning==null?null:table(planning.rawget("purposes"));
        var purpose=purposes==null?null:table(purposes.rawget(purposeId));
        var steps=purpose==null?null:table(purpose.rawget("steps"));Object cursor=purpose==null?null:purpose.rawget("cursor");
        var step=steps==null||!(cursor instanceof Number n)?null:table(steps.rawget(n.doubleValue()));
        if(purpose==null||"completed".equals(purpose.rawget("status"))||"abandoned".equals(purpose.rawget("status"))
                ||step==null||!stepId.equals(step.rawget("id"))||!recipeId.equals(step.rawget("recipeId"))
                ||!revision.equals(step.rawget("sourceRevision"))||"completed".equals(step.rawget("status")))return null;
        var requesting=zombie.scripting.ScriptManager.instance.getCraftRecipe(recipeId);
        if(requesting==null||!nativeRevision.equals(step.rawget("nativeRevision"))
                ||!nativeRevision.equals(recipeRevision(requesting)))return null;
        var out=recipeTable();out.rawset("id",purposeId);out.rawset("actorId",actor);out.rawset("consumerId",stepId);
        out.rawset("kind","construction-workspace");out.rawset("sourceRevision",revision);return out;
    }

    // Appended inside existing SAOWorldSources. No binding registry: R retains
    // exact transient body/item/material references; plain rows grant no custody.
    private static String garmentSourceRevision(zombie.inventory.types.Clothing clothing) {
        var d=clothing.getScriptItem();
        if(d==null||zombie.scripting.ScriptManager.instance.getItem(clothing.getFullType())!=d)return null;
        var b=new StringBuilder();b.append(d.getScriptObjectFullType()).append('|').append(d.getModID())
            .append('|').append(d.getFileName()).append('|').append(d.getFabricType()).append('|').append(d.getBodyLocation())
            .append('|').append(d.getConditionMax()).append('|').append(d.canHaveHoles)
            .append('|').append(clothing.getScratchDefense()).append('|').append(clothing.getBiteDefense());
        for(var part:clothing.getCoveredParts())b.append('|').append(part.index());
        try{var bytes=java.security.MessageDigest.getInstance("SHA-256").digest(b.toString().getBytes(java.nio.charset.StandardCharsets.UTF_8));return java.util.HexFormat.of().formatHex(bytes);}
        catch(java.security.NoSuchAlgorithmException e){throw new IllegalStateException(e);}
    }
    public static synchronized Object garmentObserve(SAOIsoPlayerShell body,zombie.inventory.types.Clothing clothing,zombie.characterTextures.BloodBodyPartType part) {
        try {
        String actor=recipeActor(body);if(actor==null||clothing==null||part==null||!body.isEquippedClothing(clothing)
            ||!body.getInventory().contains(clothing)||clothing.getVisual()==null||!clothing.getCoveredParts().contains(part))return null;
        String source=garmentSourceRevision(clothing);if(source==null)return null;
        var row=recipeTable();row.rawset("actorId",actor);row.rawset("bodyToken",body.getModData().rawget("SAOExternalToken"));
        row.rawset("itemId",Long.toString(clothing.getID()));row.rawset("itemType",clothing.getFullType());row.rawset("sourceRevision",source);
        row.rawset("nativeClass",clothing.getClass().getName());
        row.rawset("part",part.toString());row.rawset("fabricType",clothing.getFabricType());row.rawset("condition",(double)clothing.getCondition());
        row.rawset("hole",(double)clothing.getVisual().getHole(part));var patch=clothing.getPatchType(part);
        row.rawset("patchPresent",patch!=null);if(patch!=null){row.rawset("patchFabric",(double)patch.getFabricType());row.rawset("scratchDefense",(double)patch.getScratchDefense());row.rawset("biteDefense",(double)patch.getBiteDefense());}
        row.rawset("wornScratchDefense",(double)body.getBodyPartClothingDefense(part.index(),false,false));
        row.rawset("wornBiteDefense",(double)body.getBodyPartClothingDefense(part.index(),true,false));
        // Native wearer aggregation counts only a covered visual with no hole
        // and delegates that garment's contribution to this original API.
        row.rawset("targetScratchDefense",clothing.getVisual().getHole(part)==0?(double)clothing.getDefForPart(part,false,false):0.0);
        row.rawset("targetBiteDefense",clothing.getVisual().getHole(part)==0?(double)clothing.getDefForPart(part,true,false):0.0);
        row.rawset("tailoring",(double)body.getPerkLevel(zombie.characters.skills.PerkFactory.Perks.Tailoring));
        var signature=new StringBuilder();for(String k:new String[]{"actorId","bodyToken","itemId","itemType","sourceRevision","part","fabricType","condition","hole","patchPresent","patchFabric","scratchDefense","biteDefense","wornScratchDefense","wornBiteDefense","targetScratchDefense","targetBiteDefense","tailoring"})signature.append(k).append('=').append(row.rawget(k)).append('|');
        try{row.rawset("observationRevision",java.util.HexFormat.of().formatHex(java.security.MessageDigest.getInstance("SHA-256").digest(signature.toString().getBytes(java.nio.charset.StandardCharsets.UTF_8))));}catch(java.security.NoSuchAlgorithmException e){throw new IllegalStateException(e);}
        row.rawset("observedAtHours",zombie.GameTime.getInstance().getWorldAgeHours());row.rawset("observationOnly",true);
        row.rawset("privateAcquisitionRequired",true);row.rawset("standingRequired",true);row.rawset("ownedPhysicalReceiptRequired",true);return row;

        } catch(Throwable unavailable) { return null; }
    }
    public static synchronized boolean garmentCurrent(SAOIsoPlayerShell body,zombie.inventory.types.Clothing expected,
        zombie.characterTextures.BloodBodyPartType part,se.krka.kahlua.vm.KahluaTable observation) {
        try {
        if(observation==null||observation.getMetatable()!=null)return false;var fresh=(se.krka.kahlua.vm.KahluaTable)garmentObserve(body,expected,part);
        if(fresh==null)return false;for(String k:new String[]{"actorId","bodyToken","itemId","itemType","sourceRevision","part"})
            if(!java.util.Objects.equals(fresh.rawget(k),observation.rawget(k)))return false;return true;

        } catch(Throwable unavailable) { return false; }
    }
    public static synchronized Object garmentObservations(SAOIsoPlayerShell body) {
        try {
        var rows=recipeTable();if(recipeActor(body)==null)return rows;int count=0;
        for(int i=0;i<body.getWornItems().size();i++)if(body.getWornItems().getItemByIndex(i)instanceof zombie.inventory.types.Clothing c)
            for(var part:c.getCoveredParts()){var row=garmentObserve(body,c,part);if(row!=null)rows.rawset((double)++count,row);}
        return rows;

        } catch(Throwable unavailable) { return null; }
    }
    // Existing R retains exact expected instance. The scalar id/revisions alone
    // never re-authorize a same-id replacement or transfer-back.
    public static synchronized Object exactGarment(SAOIsoPlayerShell body,zombie.inventory.types.Clothing expected,
        String itemId,zombie.characterTextures.BloodBodyPartType part,String sourceRevision,String observationRevision) {
        try {
        if(itemId==null||sourceRevision==null||observationRevision==null)return null;
        var row=(se.krka.kahlua.vm.KahluaTable)garmentObserve(body,expected,part);
        return row!=null&&itemId.equals(row.rawget("itemId"))&&sourceRevision.equals(row.rawget("sourceRevision"))
            &&observationRevision.equals(row.rawget("observationRevision"))?expected:null;

        } catch(Throwable unavailable) { return null; }
    }

    /** Resolve a currently worn native target against the canonical service
     * relationship supplied by its owning result reader. Never authors one. */
    public static synchronized Object garmentForResult(SAOIsoPlayerShell body,se.krka.kahlua.vm.KahluaTable expected) {
        try {
            String actor=recipeActor(body);
            if(actor==null||expected==null||expected.getMetatable()!=null
                    ||!"sao.native-physical-service/1".equals(expected.rawget("schema"))
                    ||!"maintain-garment".equals(expected.rawget("kind"))||!actor.equals(expected.rawget("actorId")))return null;
            String[] fields={"schema","workId","actorId","world","bodyToken","kind","itemId","itemType","part",
                "sourceRevision","operation","requestedEffect","nativeClass"};
            int expectedCount=0;var keys=expected.iterator();
            while(keys.advance()) { boolean allowed=false;
                for(String field:fields)if(field.equals(keys.getKey())){allowed=true;break;}
                if(!allowed||!(keys.getValue()instanceof String value)||value.isBlank())return null;
                expectedCount++;
            }
            int fieldCount=fields.length-(expected.rawget("bodyToken")==null?1:0);
            if(expectedCount!=fieldCount)return null;
            var part=zombie.characterTextures.BloodBodyPartType.valueOf((String)expected.rawget("part"));
            if(part==zombie.characterTextures.BloodBodyPartType.MAX)return null;
            zombie.inventory.types.Clothing found=null;
            for(int i=0;i<body.getWornItems().size();i++) {
                if(!(body.getWornItems().getItemByIndex(i)instanceof zombie.inventory.types.Clothing clothing)
                        ||!Long.toString(clothing.getID()).equals(expected.rawget("itemId")))continue;
                if(found!=null||!clothing.getFullType().equals(expected.rawget("itemType"))
                        ||!clothing.getClass().getName().equals(expected.rawget("nativeClass"))
                        ||!java.util.Objects.equals(garmentSourceRevision(clothing),expected.rawget("sourceRevision"))
                        ||garmentObserve(body,clothing,part)==null)return null;
                var map=table(clothing.getModData().rawget("SAOPhysicalService"));
                var actual=map==null||map.getMetatable()!=null?null:table(map.rawget(expected.rawget("part")));
                if(actual==null||actual.getMetatable()!=null)return null;
                int actualCount=0;var actualKeys=actual.iterator();
                while(actualKeys.advance()){actualCount++;
                    if(!java.util.Objects.equals(expected.rawget(actualKeys.getKey()),actualKeys.getValue()))return null;
                }
                if(actualCount!=fieldCount)return null;
                found=clothing;
            }
            return found;
        } catch(Throwable unavailable) { return null; }
    }

    // Existing source resolver and actor/private perception admission; no recipe
    // declaration or new native transfer owner is synthesized for garment stock.
    public static synchronized Object garmentInputObservation(SAOIsoPlayerShell body,String sourceId,String fingerprint,String revision,
        se.krka.kahlua.vm.KahluaTable requirement) {
        try {
            String actor=recipeActor(body);if(actor==null||requirement==null||requirement.getMetatable()!=null||transactionActive
                ||!"sao.garment-input/1".equals(requirement.rawget("schema"))||!actor.equals(requirement.rawget("actorId"))
                ||!Double.valueOf(1).equals(requirement.rawget("requiredUses")))return null;
            var sao=table(zombie.Lua.LuaManager.env.rawget("SAO"));var planning=sao==null?null:table(sao.rawget("ProceduralPlanning"));Object admission=planning==null?null:planning.rawget("garmentInputAdmission");
            if(admission==null||!Boolean.TRUE.equals(zombie.Lua.LuaManager.caller.pcallBoolean(zombie.Lua.LuaManager.thread,admission,new Object[]{actor,requirement})))return null;
            String itemType=(String)requirement.rawget("itemType"),role=(String)requirement.rawget("role"),targetId=(String)requirement.rawget("targetItemId"),partName=(String)requirement.rawget("part");
            zombie.inventory.types.Clothing target=null;
            for(int i=0;i<body.getWornItems().size();i++)if(body.getWornItems().getItemByIndex(i)instanceof zombie.inventory.types.Clothing c&&targetId.equals(Integer.toString(c.getID()))){if(target!=null)return null;target=c;}
            var part=zombie.characterTextures.BloodBodyPartType.valueOf(partName);if(target==null||part==zombie.characterTextures.BloodBodyPartType.MAX||!target.getFullType().equals(requirement.rawget("targetItemType")))return null;
            var observed=(se.krka.kahlua.vm.KahluaTable)garmentObserve(body,target,part);if(observed==null||!java.util.Objects.equals(observed.rawget("sourceRevision"),requirement.rawget("sourceRevision"))
                ||!java.util.Objects.equals(observed.rawget("observationRevision"),requirement.rawget("observationRevision"))||!java.util.Objects.equals(observed.rawget("bodyToken"),requirement.rawget("bodyToken")))return null;
            var fact=privateRecipeSource(actor,sourceId,fingerprint,revision);if(fact==null||!(fact.rawget("x")instanceof Number x)||!(fact.rawget("y")instanceof Number y)||!(fact.rawget("z")instanceof Number z))return null;
            var source=resolveRecipeSource(body,sourceId,fingerprint,revision,x.intValue(),y.intValue(),z.intValue());if(source==null)return null;
            var rows=recipeTable();int count=0;
            for(var item:source){var script=item.getScriptItem();if(script==null||zombie.scripting.ScriptManager.instance.getItem(item.getFullType())!=script
                ||item.getIsCraftingConsumed()||item instanceof zombie.inventory.types.InventoryContainer)continue;
                boolean eligible=switch(role){case "needle"->item.getFullType().equals("Base.Needle")||item.hasTag(zombie.scripting.objects.ItemTag.SEWING_NEEDLE);
                    case "thread"->item instanceof zombie.inventory.types.DrainableComboItem&&item.getCurrentUses()>0&&(item.getFullType().equals("Base.Thread")||item.hasTag(zombie.scripting.objects.ItemTag.THREAD));
                    case "fabric"->itemType.equals(item.getFullType())&&java.util.Map.of("Base.RippedSheets","Cotton","Base.DenimStrips","Denim","Base.LeatherStrips","Leather").getOrDefault(itemType,"").equals(item.getFabricType());default->false;};
                if(eligible){var row=recipeItemState(item);row.rawset("nativeEligible",true);rows.rawset((double)++count,row);}
            }
            var out=recipeTable();out.rawset("actorId",actor);out.rawset("sourceId",sourceId);out.rawset("fingerprint",fingerprint);out.rawset("revision",revision);out.rawset("garmentRequirement",copyGarmentRequirement(requirement));out.rawset("items",rows);return out;
        }catch(Throwable unavailable){return null;}
    }
    private static se.krka.kahlua.vm.KahluaTable copyGarmentRequirement(se.krka.kahlua.vm.KahluaTable r){var out=recipeTable();var it=r.iterator();while(it.advance())out.rawset(it.getKey(),it.getValue());return out;}

    /** Reached included native fluid collector as a power consumer facet. */
    public static synchronized String generatorPumpConsumer(SAOIsoPlayerShell shell, IsoObject object) {
        try {
        if (SAOConceptObservation.actor(shell) == null || object == null || object.getSquare() == null
                || object.getCell() != shell.getCell() || !utilityObjectLive(object,object.getSquare())
                || !utilityReached(shell, object.getSquare())
                || !(householdPumpCurrent(object)||object.getFluidContainer()!=null&&householdIncluded(object))) return "";
        var square = object.getSquare();
        Snapshot snapshot = new Snapshot(Math.floorDiv(square.getX(), CHUNK_SIZE), Math.floorDiv(square.getY(), CHUNK_SIZE));
        snapshot.mode = "reached-power-consumer";
        Source source = utilitySource(snapshot, object, "E:", "power-consumer");
        source.inspected = true; source.powered = square.haveElectricity(); source.finish();
        rememberUtility(shell, object, source);var binding=UTILITY_BINDINGS.get(shell).get(source.id);binding.pumpFacet=true;
        if(object instanceof IsoWorldInventoryObject world&&householdPumpCurrent(object)) {
            binding.pumpItem=new java.lang.ref.WeakReference<>(world.getItem());binding.pumpScript=world.getItem().getScriptItem();
        }else binding.pumpFluid=new java.lang.ref.WeakReference<>(object.getFluidContainer());
        snapshot.add(source); snapshot.finish(); return encode(snapshot);
        } catch(Throwable unavailable) { return ""; }
    }

    /** Existing private native bindings retain the acquired service scope. */
    public static synchronized Object generatorServiceScope(SAOIsoPlayerShell shell, IsoGenerator generator,
            se.krka.kahlua.vm.KahluaTable generatorFact, se.krka.kahlua.vm.KahluaTable consumerFact,
            se.krka.kahlua.vm.KahluaTable nativeGroup, String structure, boolean acquire) {
        try {
            String gid = serviceText(generatorFact, "sourceId"), gfp = serviceText(generatorFact, "fingerprint");
            String grev = serviceText(generatorFact, "revision"), cid = serviceText(consumerFact, "sourceId");
            String cfp = serviceText(consumerFact, "fingerprint"), crev = serviceText(consumerFact, "revision");
            var boundGenerator = generatorIdentityFixture(shell, gid, gfp, grev,
                    serviceInt(generatorFact,"x"),serviceInt(generatorFact,"y"),serviceInt(generatorFact,"z"));
            var gb = utilityBinding(shell, gid, gfp, "J:"); var cb = utilityBinding(shell, cid, cfp, "E:");
            var consumer = cb.object.get(); var cs = cb.square.get();
            if (generator != boundGenerator || !utilityReached(shell,generator.getSquare()) || consumer == null || cs == null || consumer.getCell()!=shell.getCell()
                    || !cb.revisions.containsKey(crev) || consumer.getSquare() != cs || !utilityObjectLive(consumer,cs)
                    || shell.getCell().getGridSquare(cs.getX(),cs.getY(),cs.getZ()) != cs
                    || gb.generatorScript == null || gb.generatorScript != zombie.scripting.ScriptManager.instance.getItem(generator.getGeneratorItemType())
                    || !cid.substring(2).equals(consumer.getModData().rawget(SOURCE_TOKEN))
                    || !cfp.equals(utilitySource(new Snapshot(Math.floorDiv(cs.getX(),CHUNK_SIZE),Math.floorDiv(cs.getY(),CHUNK_SIZE)),consumer,"E:","power-consumer").fingerprint)
                    || cb.entityScript != consumer.getEntityScript()
                    || (cb.pumpFacet?!pumpFacetCurrent(cb,consumer):!consumer.couldBePoweredByGenerator())
                    || nativeGroup == null || structure == null || structure.isBlank()) return null;
            var members = new ArrayList<ServiceMember>();
            for(int i=1;;i++) {
                Object raw = nativeGroup.rawget((double)i); if(raw == null) break;
                if(!(raw instanceof se.krka.kahlua.vm.KahluaTable row) || !(row.rawget("object") instanceof IsoObject object)
                        || object.getCell() != shell.getCell() || object.getSquare() == null
                        || shell.getCell().getGridSquare(object.getSquare().getX(),object.getSquare().getY(),object.getSquare().getZ()) != object.getSquare()
                        || !object.getSquare().getObjects().contains(object) || object.getFluidContainer() == null) return null;
                var fc = object.getFluidContainer();
                if(!Float.isFinite(fc.getAmount()) || !Float.isFinite(fc.getCapacity()) || fc.getAmount()<0 || fc.getCapacity()<fc.getAmount()
                        || fc.getAmount()>0 && !fc.contains(Fluid.Petrol)) return null;
                for(var prior:members)if(prior.object.get()==object)return null;
                members.add(new ServiceMember(object));
            }
            int entries=0;var iterator=nativeGroup.iterator();while(iterator.advance()){Object key=iterator.getKey();if(!(key instanceof Double n)||n<1||n%1!=0||n>members.size())return null;entries++;}if(entries!=members.size())return null;
            boolean same = cid.equals(gb.serviceConsumerId) && structure.equals(gb.serviceStructure) && serviceMembersSame(gb.serviceMembers,members);
            if(acquire && !same) {
                gb.serviceConsumerId=cid;gb.serviceStructure=structure;gb.serviceMembers=members;gb.serviceRevision=UUID.randomUUID().toString();
            } else if(!acquire && !same) return null;
            if(gb.serviceRevision == null) return null;
            var result=recipeTable();result.rawset("actorId",SAOConceptObservation.actor(shell));result.rawset("generatorId",gid);
            result.rawset("consumerId",cid);result.rawset("serviceRevision",gb.serviceRevision);
            result.rawset("nativeScopeCurrent",true);result.rawset("nativeMembersFinite",true);
            var sites=recipeTable();int index=1;for(var member:gb.serviceMembers){var square=member.square.get();if(square==null)return null;var site=recipeTable();site.rawset("x",(double)square.getX());site.rawset("y",(double)square.getY());site.rawset("z",(double)square.getZ());sites.rawset((double)index++,site);}result.rawset("memberSites",sites);
            // Supplier amounts stay inside source validation, separate from acquired knowledge.
            return result;
        } catch(Throwable unavailable) { return null; }
    }
    private static String serviceText(se.krka.kahlua.vm.KahluaTable fact,String key) {
        Object v=fact==null?null:fact.rawget(key);return v instanceof String s&&!s.isBlank()?s:null;
    }
    private static int serviceInt(se.krka.kahlua.vm.KahluaTable fact,String key) {
        Object v=fact.rawget(key);if(!(v instanceof Number n)||!Double.isFinite(n.doubleValue())||n.doubleValue()!=n.intValue())throw new IllegalArgumentException();return n.intValue();
    }
    private static boolean serviceMembersSame(List<ServiceMember> expected,List<ServiceMember> current) {
        if(expected==null||current==null)return false;
        for(var now:current){boolean found=false;for(var old:expected)if(now.object.get()==old.object.get())found=true;if(!found)return false;}
        for(var old:expected) {
            var object=old.object.get();boolean found=false;
            for(var now:current)if(now.object.get()==object&&object!=null&&old.square.get()==object.getSquare()
                    &&old.fluid.get()==object.getFluidContainer()&&old.entityScript==object.getEntityScript())found=true;
            if(!found) {
                var square=old.square.get();var fluid=old.fluid.get();
                if(object==null||square==null||fluid==null||object.getSquare()!=square||!square.getObjects().contains(object)
                        ||object.getFluidContainer()!=fluid||old.entityScript!=object.getEntityScript()
                        ||!householdIncluded(object)||!Float.isFinite(fluid.getAmount())||fluid.getAmount()!=0)return false;
            }
        }
        return true;
    }
    private static final class ServiceMember {
        final java.lang.ref.WeakReference<IsoObject> object;
        final java.lang.ref.WeakReference<IsoGridSquare> square;
        final java.lang.ref.WeakReference<FluidContainer> fluid;
        final zombie.scripting.entity.GameEntityScript entityScript;
        ServiceMember(IsoObject o){object=new java.lang.ref.WeakReference<>(o);square=new java.lang.ref.WeakReference<>(o.getSquare());fluid=new java.lang.ref.WeakReference<>(o.getFluidContainer());entityScript=o.getEntityScript();}
    }
}
