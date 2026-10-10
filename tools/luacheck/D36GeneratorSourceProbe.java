import com.sao.bridge.SAOBridge;
import com.sao.engine.SAOIsoPlayerShell;
import com.sao.engine.SAONeeds;
import com.sao.engine.SAOWorldSources;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import zombie.Lua.LuaManager;
import zombie.inventory.InventoryItem;
import zombie.iso.IsoCell;
import zombie.iso.IsoGridSquare;
import zombie.iso.IsoObject;
import zombie.iso.SpriteDetails.IsoFlagType;
import zombie.iso.objects.IsoGenerator;
import zombie.iso.sprite.IsoSprite;
import zombie.scripting.ScriptManager;
import se.krka.kahlua.vm.JavaFunction;
import se.krka.kahlua.vm.KahluaTable;
import se.krka.kahlua.luaj.compiler.LuaCompiler;

/** Real native generator/source/power methods; loaded-cell and Lua actor receivers are controlled. */
public final class D36GeneratorSourceProbe {
    private static int checks;
    private static void check(String name,boolean value) {
        if(!value)throw new AssertionError("D36_SOURCES:"+name);
        checks++;System.out.println("CHECK "+name);
    }
    METADATA
    private static void position(SAOIsoPlayerShell body,IsoGridSquare square) {
        if(body.getSquare()!=null)body.getSquare().getMovingObjects().remove(body);
        body.setX(square.getX()+.5f);body.setY(square.getY()+.5f);body.setZ(square.getZ());body.setCurrent(square);body.setSquare(square);
        square.getMovingObjects().add(body);square.setSolidFloor(true);
    }
    private static String part(String wire,String prefix) {
        for(String line:wire.split("\n"))if(line.startsWith("S|"))for(String field:line.split("\\|"))if(field.startsWith(prefix+"="))return field.substring(prefix.length()+1);
        return null;
    }
    private static String source(IsoGenerator generator,boolean inspected)throws Exception {
        var snapshot=Class.forName("com.sao.engine.SAOWorldSources$Snapshot");var ctor=snapshot.getDeclaredConstructor(int.class,int.class);ctor.setAccessible(true);
        var row=SAOWorldSources.class.getDeclaredMethod("generatorSource",snapshot,IsoGenerator.class,boolean.class);row.setAccessible(true);
        Object snap=ctor.newInstance(1,2),record=row.invoke(null,snap,generator,inspected);
        var add=snapshot.getDeclaredMethod("add",record.getClass());add.setAccessible(true);add.invoke(snap,record);
        var finish=snapshot.getDeclaredMethod("finish");finish.setAccessible(true);finish.invoke(snap);
        var encode=SAOWorldSources.class.getDeclaredMethod("encode",snapshot);encode.setAccessible(true);return(String)encode.invoke(null,snap);
    }
    private static String categories(InventoryItem item)throws Exception {
        var row=Class.forName("com.sao.engine.SAOWorldSources$ItemRow");var of=row.getDeclaredMethod("of",InventoryItem.class);of.setAccessible(true);
        var categories=row.getDeclaredField("categories");categories.setAccessible(true);return categories.get(of.invoke(null,item)).toString();
    }
    private static void verifyDriftOnly(IsoCell cell,SAOIsoPlayerShell body,InventoryItem generatorItem)throws Exception {
        var region=zombie.iso.areas.isoregion.IsoRegions.class.getDeclaredField("dataRoot");region.setAccessible(true);region.set(null,new zombie.iso.areas.isoregion.data.DataRoot());
        var worker=zombie.iso.areas.isoregion.IsoRegions.class.getDeclaredField("regionWorker");worker.setAccessible(true);
        var workerCtor=zombie.iso.areas.isoregion.IsoRegionWorker.class.getDeclaredConstructor();workerCtor.setAccessible(true);worker.set(null,workerCtor.newInstance());
        var logger=zombie.iso.areas.isoregion.IsoRegions.class.getDeclaredField("logger");logger.setAccessible(true);logger.set(null,new zombie.iso.areas.isoregion.IsoRegionsLogger(false));
        zombie.SandboxOptions.instance.elecShutModifier.setValue(0);zombie.SandboxOptions.instance.timeSinceApo.setValue(1);
        if(Boolean.getBoolean("sao.d36.savedReturnOnly"))for(int y=19;y<=21;y++)for(int x=9;x<=15;x++) {
            var square=cell.getGridSquare(x,y,0);var sprite=new IsoSprite();sprite.getProperties().set(IsoFlagType.solidfloor);
            square.getObjects().add(new IsoObject(cell,square,sprite));square.getProperties().set(IsoFlagType.solidfloor);square.setSolidFloor(true);square.setCachedIsFree(false);
        }
        var genSquare=cell.getGridSquare(10,20,0);genSquare.setSolidFloor(true);genSquare.getProperties().set(IsoFlagType.exterior);
        var consumerSquare=cell.getGridSquare(14,20,0);consumerSquare.setSolidFloor(true);consumerSquare.room=new zombie.iso.areas.IsoRoom();consumerSquare.roomId=1;
        var consumer=new IsoObject(cell,consumerSquare,new IsoSprite());consumerSquare.getObjects().add(consumer);
        var fridge=new zombie.inventory.ItemContainer("fridge",consumerSquare,consumer);consumer.setContainer(fridge);consumerSquare.getChunk().addObjectPoweredByGenerator(consumer);
        var generator=new IsoGenerator(generatorItem,cell,genSquare);generator.setFuel(3);generator.setCondition(100);generator.setConnected(true);
        var bridge=SAOBridge.INSTANCE;position(body,cell.getGridSquare(13,20,0));body.setForwardDirection(1,0);
        String cold=bridge.worldGeneratorConsumer(body,consumer),eid=part(cold,"id"),efp=part(cold,"fp");
        if(Boolean.getBoolean("sao.d36.savedReturnOnly")){savedReturnCases(cell,body,generator,consumer,cold);return;}
        check("drift_consumer_initially_unpowered",eid!=null&&cold.contains("|powered=0"));
        position(body,cell.getGridSquare(6,20,0));body.setForwardDirection(1,0);String far=bridge.worldGeneratorCandidates(body);
        String id=part(far,"id"),fp=part(far,"fp"),uninspected=part(far,"rev");
        position(body,cell.getGridSquare(11,20,0));body.setForwardDirection(-1,0);String before=bridge.worldGeneratorCandidates(body);
        check("drift_actual_activation_admitted",bridge.worldGeneratorObject(body,id,fp,part(before,"rev"),10,20,0,"activate")==generator);
        generator.setActivated(true);String active=bridge.worldGeneratorCandidates(body);String acquired=part(active,"rev");
        check("drift_inspected_active_revision_retained",active.contains("|inspected=1")&&active.contains("|active=1"));
        position(body,cell.getGridSquare(13,20,0));body.setForwardDirection(1,0);generator.setFuel(2.5f);generator.setCondition(99);
        check("verify_power_accepts_current_drift",bridge.worldGeneratorObject(body,id,fp,acquired,10,20,0,"verify-power")==generator);
        check("verify_drift_still_requires_reached_power",bridge.worldGeneratorConsumerPowered(body,generator,eid,efp,14,20,0));
        check("verify_drift_rejects_uninspected_revision",bridge.worldGeneratorObject(body,id,fp,uninspected,10,20,0,"verify-power")==null);
        check("verify_drift_rejects_unknown_revision",bridge.worldGeneratorObject(body,id,fp,"unknown-revision",10,20,0,"verify-power")==null);
        check("verify_drift_rejects_wrong_fingerprint",bridge.worldGeneratorObject(body,id,"wrong-fingerprint",acquired,10,20,0,"verify-power")==null);
        genSquare.getProperties().unset(IsoFlagType.exterior);
        check("verify_drift_rejects_unsafe_source",bridge.worldGeneratorObject(body,id,fp,acquired,10,20,0,"verify-power")==null
            &&!bridge.worldGeneratorConsumerPowered(body,generator,eid,efp,14,20,0));genSquare.getProperties().set(IsoFlagType.exterior);
        genSquare.getObjects().remove(generator);
        var replacement=new IsoGenerator(cell);replacement.setSquare(genSquare);replacement.setSprite(generator.getSprite());replacement.getModData().rawset("SAOWorldSourceId",id.substring(2));genSquare.getObjects().add(replacement);
        check("verify_drift_rejects_replacement",bridge.worldGeneratorObject(body,id,fp,acquired,10,20,0,"verify-power")==null
            &&!bridge.worldGeneratorValid(body,replacement,id,fp,10,20,0,"verify-power"));genSquare.getObjects().remove(replacement);genSquare.getObjects().add(generator);
        generator.setActivated(false);
        check("verify_drift_rejects_inactive_source",bridge.worldGeneratorObject(body,id,fp,acquired,10,20,0,"verify-power")==null
            &&!bridge.worldGeneratorConsumerPowered(body,generator,eid,efp,14,20,0));
        check("ordinary_operation_still_rechecks_revision",bridge.worldGeneratorObject(body,id,fp,acquired,10,20,0,"fuel")==null);
        System.out.println("PASS D36 verify drift "+checks);
    }
    private static void savedReturnCases(IsoCell cell,SAOIsoPlayerShell body,IsoGenerator generator,IsoObject consumer,String cold)throws Exception {
        var bridge=SAOBridge.INSTANCE;String eid=part(cold,"id"),efp=part(cold,"fp"),erev=part(cold,"rev");
        position(body,cell.getGridSquare(11,20,0));body.setForwardDirection(-1,0);String remembered=bridge.worldGeneratorCandidates(body);
        String id=part(remembered,"id"),fp=part(remembered,"fp"),revision=part(remembered,"rev");
        var platform=LuaManager.platform;var facts=platform.newTable();
        for(String wire:new String[]{remembered,cold}) {
            var fact=platform.newTable();String sourceId=part(wire,"id");fact.rawset("id",sourceId);fact.rawset("sourceId",sourceId);
            fact.rawset("fingerprint",part(wire,"fp"));fact.rawset("revision",part(wire,"rev"));fact.rawset("kind",part(wire,"kind"));
            fact.rawset("actorId","generator-person");fact.rawset("inspected",true);
            for(String key:new String[]{"x","y","z"})fact.rawset(key,Double.valueOf(part(wire,key)));facts.rawset(sourceId,fact);
        }
        var place=platform.newTable();place.rawset("sourceFacts",facts);var known=platform.newTable();known.rawset("source:remembered",place);
        var mind=platform.newTable();mind.rawset("known",known);var beliefs=platform.newTable();beliefs.rawset("generator-person",mind);
        var perception=platform.newTable();perception.rawset("beliefs",beliefs);var sao=platform.newTable();sao.rawset("Perception",perception);
        var bytes=java.nio.ByteBuffer.allocate(65536);sao.save(bytes);bytes.flip();var restored=platform.newTable();restored.load(bytes,249);LuaManager.env.rawset("SAO",restored);
        SAOWorldSources.resetRuntimeForWorld();
        check("saved_consumer_return_route",bridge.worldGeneratorConsumerTarget(body,eid,efp,erev,14,20,0).startsWith("READY:"));
        check("saved_consumer_not_reached",bridge.worldGeneratorConsumerObject(body,eid,efp,erev,14,20,0)==null);
        String savedRoute=bridge.worldGeneratorTarget(body,id,fp,revision,10,20,0,"activate");
        if(!savedRoute.startsWith("READY:"))System.out.println("SAVED_GENERATOR_ROUTE_DIAGNOSTIC "+savedRoute+" id="+id+" fp="+fp+" revision="+revision);
        check("saved_generator_return_route",savedRoute.startsWith("READY:"));
        check("saved_inspection_not_minted",bridge.worldGeneratorObject(body,id,fp,revision,10,20,0,"activate")==null);
        generator.setFuel(0);generator.setCondition(39);generator.setConnected(false);
        position(body,cell.getGridSquare(13,20,0));body.setForwardDirection(1,0);
        check("stale_shutdown_still_routes",bridge.worldGeneratorTarget(body,id,fp,revision,10,20,0,"verify-power").startsWith("READY:"));
        check("stale_fuel_wear_still_routes",bridge.worldGeneratorTarget(body,id,fp,revision,10,20,0,"fuel").startsWith("READY:"));
        check("stale_remote_inspection_not_reached",bridge.worldGeneratorObject(body,id,fp,revision,10,20,0,"inspect")==null);
        position(body,cell.getGridSquare(11,20,0));body.setForwardDirection(-1,0);
        check("reached_stale_inspection_reacquires",bridge.worldGeneratorObject(body,id,fp,revision,10,20,0,"inspect")==generator);
        String current=bridge.worldGeneratorCandidates(body);String freshRevision=part(current,"rev");
        check("reinspection_measures_actual_shutdown",current.contains("|fuel=0.000000")&&current.contains("|condition=39")&&current.contains("|connected=0")&&!freshRevision.equals(revision));
        check("stale_physical_mutation_refused",bridge.worldGeneratorObject(body,id,fp,revision,10,20,0,"fuel")==null);
        check("fresh_physical_fuel_admission",bridge.worldGeneratorObject(body,id,fp,freshRevision,10,20,0,"fuel")==generator);
        check("fresh_connect_still_requires_knowledge",bridge.worldGeneratorObject(body,id,fp,freshRevision,10,20,0,"connect")==null);
        check("shutdown_cannot_mint_power",!bridge.worldGeneratorConsumerPowered(body,generator,eid,efp,14,20,0));
        var person=MovementCrossingProbe.class.getDeclaredMethod("person",IsoCell.class);person.setAccessible(true);
        var newBody=(SAOIsoPlayerShell)person.invoke(null,cell);newBody.getModData().rawset("SAOPersonId","generator-person");cell.getObjectList().add(newBody);
        position(newBody,cell.getGridSquare(11,20,0));newBody.setForwardDirection(1,0);
        check("replacement_body_remembered_consumer_route",bridge.worldGeneratorConsumerTarget(newBody,eid,efp,erev,14,20,0).startsWith("READY:"));
        check("replacement_body_remembered_generator_route",bridge.worldGeneratorTarget(newBody,id,fp,revision,10,20,0,"fuel").startsWith("READY:"));
        check("replacement_body_no_current_inspection",bridge.worldGeneratorObject(newBody,id,fp,revision,10,20,0,"fuel")==null);
        newBody.getModData().rawset("SAOPersonId","unknown-person");
        check("unknown_actor_cannot_rebind",!bridge.worldGeneratorConsumerTarget(newBody,eid,efp,erev,14,20,0).startsWith("READY:"));newBody.getModData().rawset("SAOPersonId","generator-person");
        check("unknown_fact_cannot_rebind",!bridge.worldGeneratorConsumerTarget(newBody,"E:unknown",efp,erev,14,20,0).startsWith("READY:"));
        check("wrong_fingerprint_cannot_rebind",!bridge.worldGeneratorTarget(newBody,id,"wrong",revision,10,20,0,"inspect").startsWith("READY:"));
        check("unknown_revision_cannot_route",!bridge.worldGeneratorTarget(newBody,id,fp,"unknown-revision",10,20,0,"inspect").startsWith("READY:"));
        check("wrong_coordinates_cannot_route",!bridge.worldGeneratorTarget(newBody,id,fp,revision,12,20,0,"inspect").startsWith("READY:"));
        position(newBody,cell.getGridSquare(13,20,0));newBody.setForwardDirection(1,0);
        check("reached_remembered_consumer_reacquires",bridge.worldGeneratorConsumerObject(newBody,eid,efp,erev,14,20,0)==consumer);
        Object token=consumer.getModData().rawget("SAOWorldSourceId");consumer.getModData().rawset("SAOWorldSourceId","replacement-token");
        check("replacement_token_cannot_route",!bridge.worldGeneratorConsumerTarget(newBody,eid,efp,erev,14,20,0).startsWith("READY:"));consumer.getModData().rawset("SAOWorldSourceId",token);
        consumer.getSquare().getObjects().remove(consumer);
        var substitute=new IsoObject(cell,consumer.getSquare(),consumer.getSprite());substitute.getModData().rawset("SAOWorldSourceId",token);
        substitute.setContainer(new zombie.inventory.ItemContainer("fridge",consumer.getSquare(),substitute));consumer.getSquare().getObjects().add(substitute);
        check("replacement_pointer_cannot_route",!bridge.worldGeneratorConsumerTarget(newBody,eid,efp,erev,14,20,0).startsWith("READY:"));
        consumer.getSquare().getObjects().remove(substitute);consumer.getSquare().getObjects().add(consumer);
        var priorCell=zombie.iso.IsoWorld.instance.currentCell;zombie.iso.IsoWorld.instance.currentCell=null;
        check("wrong_world_cannot_rebind",!bridge.worldGeneratorTarget(newBody,id,fp,revision,10,20,0,"inspect").startsWith("READY:"));zombie.iso.IsoWorld.instance.currentCell=priorCell;
        position(body,cell.getGridSquare(11,20,0));body.setForwardDirection(-1,0);generator.setFuel(1);generator.setCondition(100);generator.setConnected(true);
        generator.getSquare().getProperties().unset(IsoFlagType.exterior);current=bridge.worldGeneratorCandidates(body);
        check("current_unsafe_effect_still_refused",bridge.worldGeneratorObject(body,id,fp,part(current,"rev"),10,20,0,"activate")==null);
        System.out.println("PASS D36 saved return "+checks);
    }
    public static void main(String[] args)throws Exception {
        Thread.setDefaultUncaughtExceptionHandler((t,e)->{e.printStackTrace();System.exit(1);});
        var boot=MovementCrossingProbe.class.getDeclaredMethod("boot");boot.setAccessible(true);var cell=(IsoCell)boot.invoke(null);
        var person=MovementCrossingProbe.class.getDeclaredMethod("person",IsoCell.class);person.setAccessible(true);var body=(SAOIsoPlayerShell)person.invoke(null,cell);
        body.getModData().rawset("SAOPersonId","generator-person");cell.getObjectList().add(body);
        var fluidInit=ResourceApproachProbe.class.getDeclaredMethod("initFluids");fluidInit.setAccessible(true);fluidInit.invoke(null);
        var platform=new se.krka.kahlua.j2se.J2SEPlatform();var env=platform.newEnvironment();var thread=new se.krka.kahlua.vm.KahluaThread(platform,env);thread.debugOwnerThread=Thread.currentThread();
        LuaManager.platform=platform;LuaManager.env=env;LuaManager.thread=thread;LuaCompiler.register(env);
        env.rawset("print",(JavaFunction)(f,n)->{System.out.println(f.get(0));return 0;});
        var data=Class.forName("zombie.world.WorldDictionary").getDeclaredField("data");data.setAccessible(true);var dictionary=new MaterialDictionary();data.set(null,dictionary);
        var items=new java.util.LinkedHashMap<String,InventoryItem>();short registry=1000;
        for(String line:Files.readAllLines(Path.of(args[1]))) {String[] columns=line.split("\t");var item=material(Path.of(columns[0]),columns[1],columns[2],registry++,dictionary);items.put(item.getFullType(),item);}
        if(Boolean.getBoolean("sao.d36.verifyDriftOnly")||Boolean.getBoolean("sao.d36.savedReturnOnly")){verifyDriftOnly(cell,body,items.get("Base.Generator"));System.exit(0);}
        var scrap=items.get("Base.ElectronicsScrap");var petrol=items.get("Base.PetrolCan");var manual=items.get("Base.ElectronicsMag4");
        check("exact_scrap",SAONeeds.wantsMaterial(scrap,"electronics-scrap"));check("wire_not_scrap",!SAONeeds.wantsMaterial(items.get("Base.ElectricWire"),"electronics-scrap"));
        check("native_petrol",SAONeeds.wantsMaterial(petrol,"petrol"));check("water_not_petrol",!SAONeeds.wantsMaterial(items.get("Base.WaterBottle"),"petrol"));
        var gas=petrol.getFluidContainer();float original=gas.getAmount();gas.adjustAmount(.05f);check("petrol_below_native_threshold",!SAONeeds.wantsMaterial(petrol,"petrol"));gas.adjustAmount(original);
        check("actual_generator_manual",SAONeeds.wantsMaterial(manual,"generator-manual"));check("ordinary_magazine_not_manual",!SAONeeds.wantsMaterial(items.get("Base.ElectronicsMag1"),"generator-manual"));
        scrap.setIsCraftingConsumed(true);check("consumed_scrap_refused",!SAONeeds.wantsMaterial(scrap,"electronics-scrap"));scrap.setIsCraftingConsumed(false);
        petrol.setIsCraftingConsumed(true);check("consumed_petrol_refused",!SAONeeds.wantsMaterial(petrol,"petrol"));petrol.setIsCraftingConsumed(false);
        manual.setIsCraftingConsumed(true);check("consumed_manual_refused",!SAONeeds.wantsMaterial(manual,"generator-manual"));manual.setIsCraftingConsumed(false);
        var bag=(zombie.inventory.types.InventoryContainer)items.get("Base.Bag_Schoolbag");body.getInventory().AddItem(bag);
        for(var item:new InventoryItem[]{scrap,petrol,manual})bag.getInventory().AddItem(item);
        for(String category:new String[]{"electronics-scrap","petrol","generator-manual"})check("nested_count_"+category,SAOBridge.INSTANCE.constructionMaterialCount(body,category)==1);
        check("source_scrap",categories(scrap).contains("electronics-scrap"));check("source_petrol",categories(petrol).contains("petrol"));check("source_manual",categories(manual).contains("generator-manual"));
        var captured=com.sao.engine.SAONativeSnapshot.capture(body);var restored=(SAOIsoPlayerShell)person.invoke(null,cell);com.sao.engine.SAONativeSnapshot.restoreStaged(restored,captured);
        for(String category:new String[]{"electronics-scrap","petrol","generator-manual"})check("saved_count_"+category,SAOBridge.INSTANCE.constructionMaterialCount(restored,category)==1);
        var region=zombie.iso.areas.isoregion.IsoRegions.class.getDeclaredField("dataRoot");region.setAccessible(true);region.set(null,new zombie.iso.areas.isoregion.data.DataRoot());
        var regionWorker=zombie.iso.areas.isoregion.IsoRegions.class.getDeclaredField("regionWorker");regionWorker.setAccessible(true);
        var regionConstructor=zombie.iso.areas.isoregion.IsoRegionWorker.class.getDeclaredConstructor();regionConstructor.setAccessible(true);
        regionWorker.set(null,regionConstructor.newInstance());
        var regionLogger=zombie.iso.areas.isoregion.IsoRegions.class.getDeclaredField("logger");regionLogger.setAccessible(true);
        var loggerConstructor=zombie.iso.areas.isoregion.IsoRegionsLogger.class.getDeclaredConstructor(boolean.class);loggerConstructor.setAccessible(true);
        regionLogger.set(null,loggerConstructor.newInstance(false));
        zombie.SandboxOptions.instance.elecShutModifier.setValue(0);zombie.SandboxOptions.instance.timeSinceApo.setValue(1);
        var genSquare=cell.getGridSquare(10,20,0);genSquare.getProperties().set(IsoFlagType.exterior);genSquare.setSolidFloor(true);
        var consumerSquare=cell.getGridSquare(14,20,0);consumerSquare.setSolidFloor(true);consumerSquare.room=new zombie.iso.areas.IsoRoom();consumerSquare.roomId=1;
        var consumer=new IsoObject(cell,consumerSquare,new IsoSprite());consumerSquare.getObjects().add(consumer);
        var fridge=new zombie.inventory.ItemContainer("fridge",consumerSquare,consumer);consumer.setContainer(fridge);consumerSquare.getChunk().addObjectPoweredByGenerator(consumer);
        check("native_fridge_consumer",consumer.couldBePoweredByGenerator()&&!fridge.isPowered());
        var bridge=SAOBridge.INSTANCE;
        var unsafeField=sun.misc.Unsafe.class.getDeclaredField("theUnsafe");unsafeField.setAccessible(true);
        var unsafe=(sun.misc.Unsafe)unsafeField.get(null);
        var gameState=(zombie.gameStates.IngameState)unsafe.allocateInstance(zombie.gameStates.IngameState.class);
        gameState.numberTicks=100;zombie.gameStates.IngameState.instance=gameState;
        var powerTick=IsoObject.class.getDeclaredField("hasPowerTick");powerTick.setAccessible(true);
        var cachedPower=IsoObject.class.getDeclaredField("hasPower");cachedPower.setAccessible(true);
        for(String type:new String[]{"Base.Generator","Base.Generator_Yellow","Base.Generator_Blue","Base.Generator_Old"}) {
            var generator=new IsoGenerator(items.get(type),cell,genSquare);generator.setFuel(0);generator.setCondition(40);
            position(body,cell.getGridSquare(6,20,0));body.setForwardDirection(1,0);
            String far=bridge.worldGeneratorCandidates(body);String id=part(far,"id"),fp=part(far,"fp"),rev=part(far,"rev");
            check("partial_visible_identity_"+type,id!=null&&id.startsWith("J:")&&far.contains("inspected=0")&&!far.contains("|fuel=")&&!far.contains("|condition="));
            String invisibleBefore=source(generator,false);generator.setFuel(.5f);generator.setCondition(41);
            check("partial_revision_has_no_hidden_state_"+type,source(generator,false).equals(invisibleBefore));generator.setFuel(0);generator.setCondition(40);
            check("partial_cannot_fuel_"+type,bridge.worldGeneratorTarget(body,id,fp,rev,10,20,0,"fuel").startsWith("READY:")
                &&bridge.worldGeneratorObject(body,id,fp,rev,10,20,0,"fuel")==null);
            check("null_revision_refused_"+type,bridge.worldGeneratorObject(body,id,fp,null,10,20,0,"inspect")==null);
            position(body,cell.getGridSquare(11,20,0));body.setForwardDirection(-1,0);String full=bridge.worldGeneratorCandidates(body);rev=part(full,"rev");
            check("reached_generator_state_"+type,full.contains("inspected=1")&&full.contains("|condition=40")&&full.contains("|fuel=0.000000"));
            check("native_exact_generator_bound_"+type,bridge.worldGeneratorObject(body,id,fp,rev,10,20,0,"inspect")==generator);
            check("knowledge_gates_repair_"+type,bridge.worldGeneratorTarget(body,id,fp,rev,10,20,0,"repair").startsWith("READY:")
                &&bridge.worldGeneratorObject(body,id,fp,rev,10,20,0,"repair")==null);
            check("wrong_fingerprint_refused_"+type,!bridge.worldGeneratorValid(body,generator,id,"wrong-fingerprint",10,20,0,"inspect"));
            generator.setFuel(1);check("changed_revision_refused_"+type,bridge.worldGeneratorObject(body,id,fp,rev,10,20,0,"fuel")==null);
            check("owned_change_identity_poststate_"+type,bridge.worldGeneratorValid(body,generator,id,fp,10,20,0,"inspect"));
            generator.setConnected(true);generator.setCondition(100);full=bridge.worldGeneratorCandidates(body);rev=part(full,"rev");
            genSquare.getProperties().unset(IsoFlagType.exterior);check("indoor_activation_refused_"+type,bridge.worldGeneratorObject(body,id,fp,rev,10,20,0,"activate")==null);genSquare.getProperties().set(IsoFlagType.exterior);
            position(body,cell.getGridSquare(13,20,0));body.setForwardDirection(1,0);String cold=bridge.worldGeneratorConsumer(body,consumer);
            String eid=part(cold,"id"),efp=part(cold,"fp"),erev=part(cold,"rev");check("reached_consumer_without_contents_"+type,eid!=null&&eid.startsWith("E:")&&cold.contains("|powered=0")&&!cold.contains("I|"));
            generator.activated=true;
            check("activation_flag_alone_not_power_"+type,!bridge.worldGeneratorConsumerPowered(body,generator,eid,efp,14,20,0));generator.activated=false;
            generator.addToWorld();generator.setActivated(true);
            gameState.numberTicks++;
            check("native_consumer_power_propagated_"+type,consumerSquare.haveElectricity()&&fridge.isPowered());
            powerTick.setLong(consumer,gameState.numberTicks);cachedPower.setBoolean(consumer,false);
            check("native_cache_is_controlled_cold_"+type,!fridge.isPowered());
            check("exact_fresh_consumer_power_"+type,bridge.worldGeneratorConsumerPowered(body,generator,eid,efp,14,20,0));
            check("wrong_consumer_fingerprint_refused_"+type,!bridge.worldGeneratorConsumerPowered(body,generator,eid,"wrong",14,20,0));
            check("consumer_route_accepts_expected_power_change_"+type,bridge.worldGeneratorConsumerTarget(body,eid,efp,erev,14,20,0).startsWith("READY:"));
            String hot=bridge.worldGeneratorConsumer(body,consumer);check("consumer_reinspection_power_"+type,hot.contains("|powered=1")&&!part(hot,"rev").equals(erev));
            position(body,cell.getGridSquare(11,20,0));check("unreached_consumer_cannot_credit_"+type,!bridge.worldGeneratorConsumerPowered(body,generator,eid,efp,14,20,0));
            if(type.equals("Base.Generator")){env.rawset("__far",far);env.rawset("__full",full);env.rawset("__cold",cold);env.rawset("__hot",hot);}
            generator.setActivated(false);gameState.numberTicks++;
            check("native_shutdown_removes_consumer_power_"+type,!consumerSquare.haveElectricity()&&!fridge.isPowered());
            generator.removeFromWorld();genSquare.getObjects().remove(generator);
            check("removed_generator_refused_"+type,!bridge.worldGeneratorValid(body,generator,id,fp,10,20,0,"inspect"));
        }
        SAOWorldSources.resetRuntimeForWorld();check("world_reset_clears_authority",bridge.worldGeneratorCandidates(new Object()).isEmpty());
        env.rawset("__roundTrip",(JavaFunction)(f,n)->{try{var bytes=java.nio.ByteBuffer.allocate(1024*1024);((KahluaTable)f.get(0)).save(bytes);bytes.flip();var value=platform.newTable();value.load(bytes,249);return f.push(value);}catch(Exception e){throw new IllegalStateException(e);}});
        for(int index=2;index<args.length;index++)thread.call(LuaCompiler.loadstring(Files.readString(Path.of(args[index])),args[index],env),null,null,null);
        System.out.println("PASS D36 native sources "+checks);System.exit(0);
    }
}
