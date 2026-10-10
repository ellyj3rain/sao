import com.sao.bridge.SAOBridge;
import com.sao.engine.SAOIsoPlayerShell;
import com.sao.engine.SAOWorldSources;
import java.nio.file.Path;
import java.util.Map;
import zombie.Lua.LuaManager;
import zombie.entity.components.fluids.FluidContainer;
import zombie.entity.components.fluids.FluidContainerUpdateSystem;
import zombie.iso.IsoCell;
import zombie.iso.IsoGridSquare;
import zombie.iso.IsoObject;
import zombie.iso.SpriteDetails.IsoFlagType;
import zombie.iso.objects.IsoThumpable;
import zombie.iso.sprite.IsoSprite;
import zombie.iso.weather.ClimateManager;

/** Native placement, entity components, precipitation and supplier ports in a controlled loaded cell. */
public final class D35CollectorPortProbe {
    private static int checks;
    private static void check(String name,boolean value) {
        if(!value)throw new AssertionError("D35_COLLECTOR:"+name);
        checks++;System.out.println("CHECK D35_COLLECTOR:"+name);
    }
    private static final class Weather extends ClimateManager {
        float intensity=1;boolean snow;
        @Override public float getPrecipitationIntensity(){return intensity;}
        @Override public boolean getPrecipitationIsSnow(){return snow;}
    }
    private static void position(SAOIsoPlayerShell body,IsoGridSquare square) {
        if(body.getSquare()!=null)body.getSquare().getMovingObjects().remove(body);
        body.setX(square.getX()+.5f);body.setY(square.getY()+.5f);body.setZ(square.getZ());body.setCurrent(square);
        body.setSquare(square);square.getMovingObjects().add(body);
    }
    private static String revision(String rows,int x,int y,int z) {
        for(String row:rows.split("\\|")) {String[] fields=row.split(",");
            if(fields.length==4 && fields[0].equals(""+x)&&fields[1].equals(""+y)&&fields[2].equals(""+z))return fields[3];}
        return null;
    }
    private static Object source(IsoObject object)throws Exception {
        var method=D34PlumbingPortProbe.class.getDeclaredMethod("source",IsoObject.class);method.setAccessible(true);return method.invoke(null,object);
    }
    private static Object field(Object object,String name)throws Exception {
        var f=object.getClass().getDeclaredField(name);f.setAccessible(true);return f.get(object);
    }
    private static void remember(SAOIsoPlayerShell body,Object source)throws Exception {
        var method=D34PlumbingPortProbe.class.getDeclaredMethod("remember",SAOIsoPlayerShell.class,Object.class);method.setAccessible(true);method.invoke(null,body,source);
    }
    public static void run(Path game,IsoCell cell,SAOIsoPlayerShell body)throws Exception {
        var bridge=SAOBridge.INSTANCE;body.getModData().rawset("SAOPersonId","collector-person");
        if(!cell.getObjectList().contains(body))cell.getObjectList().add(body);
        var regions=zombie.iso.areas.isoregion.IsoRegions.class.getDeclaredField("dataRoot");regions.setAccessible(true);
        Object oldRegions=regions.get(null);if(oldRegions==null)regions.set(null,new zombie.iso.areas.isoregion.data.DataRoot());
        var weather=new Weather();ClimateManager oldWeather=ClimateManager.getInstance();ClimateManager.setInstance(weather);
        int oldShut=zombie.SandboxOptions.instance.waterShutModifier.getValue();zombie.SandboxOptions.instance.waterShutModifier.setValue(0);
        try {
            var here=cell.getGridSquare(11,20,0);var site=cell.getGridSquare(12,20,0);position(body,here);
            here.setSolidFloor(true);site.setSolidFloor(true);
            here.getProperties().set(IsoFlagType.exterior);site.getProperties().set(IsoFlagType.exterior);body.setForwardDirection(1,0);
            var farSite=cell.getGridSquare(16,20,0);farSite.setSolidFloor(true);farSite.getProperties().set(IsoFlagType.exterior);
            check("unknown_site_not_authority",bridge.worldCollectorPlacementSquare(body,12,20,0,"unobserved")==null);
            String rows=bridge.worldCollectorSites(body),rev=revision(rows,12,20,0);
            if(rev==null) {
                var actor=Class.forName("com.sao.engine.SAOConceptObservation").getDeclaredMethod("actor",SAOIsoPlayerShell.class);actor.setAccessible(true);
                System.out.println("COLLECTOR_SITE_DIAGNOSTIC actor="+actor.invoke(null,body)+" exists="+body.isExistInTheWorld()
                    +" outside="+site.isOutside()+" solidfloor="+site.isSolidFloor()+" free="+site.isFree(false)+" moving="+site.getMovingObjects().size()+" rows="+rows);
            }
            check("actual_visible_site_projected",rev!=null && rows.split("\\|").length<=32);
            check("exact_observed_square_admitted",bridge.worldCollectorPlacementSquare(body,12,20,0,rev)==site);
            check("native_forward_gaze_observes_distant_site",revision(rows,16,20,0)!=null);
            body.setForwardDirection(-1,0);
            check("current_native_gaze_refuses_unseen_site",revision(bridge.worldCollectorSites(body),16,20,0)==null);body.setForwardDirection(1,0);
            body.getModData().rawset("SAOExternalOwner","foreign");
            check("current_foreign_body_refused",bridge.worldCollectorSites(body).isEmpty()&&bridge.worldCollectorPlacementSquare(body,12,20,0,rev)==null);
            body.getModData().rawset("SAOExternalOwner",null);
            check("wrong_revision_refused",bridge.worldCollectorPlacementSquare(body,12,20,0,"wrong-private-revision")==null);
            check("fractional_and_nonfinite_sites_refused",bridge.worldCollectorPlacementSquare(body,12.25,20,0,rev)==null
                &&bridge.worldCollectorPlacementSquare(body,Double.NaN,20,0,rev)==null);
            check("unseen_roof_not_projected",!rows.matches(".*(?:^|\\|)[^|]*,1,[^|]*.*")
                &&bridge.worldCollectorPlacementSquare(body,12,20,1,rev)==null);
            var foreign=MovementCrossingProbe.class.getDeclaredMethod("person",IsoCell.class);foreign.setAccessible(true);
            var other=(SAOIsoPlayerShell)foreign.invoke(null,cell);other.getModData().rawset("SAOPersonId","other-collector-person");
            if(!cell.getObjectList().contains(other))cell.getObjectList().add(other);
            position(other,cell.getGridSquare(13,20,0));
            check("another_body_cannot_borrow_site",bridge.worldCollectorPlacementSquare(other,12,20,0,rev)==null);
            var obstacle=new IsoObject(cell,site,new IsoSprite());site.getObjects().add(obstacle);
            check("changed_native_object_revision_refused",bridge.worldCollectorPlacementSquare(body,12,20,0,rev)==null);
            site.getObjects().remove(obstacle);site.setSolidFloor(false);
            check("missing_floor_refused",bridge.worldCollectorPlacementSquare(body,12,20,0,rev)==null);site.setSolidFloor(true);
            position(body,cell.getGridSquare(15,20,0));body.setForwardDirection(-1,0);
            check("observed_site_does_not_widen_reach",bridge.worldCollectorPlacementSquare(body,12,20,0,rev)==null);position(body,here);body.setForwardDirection(1,0);
            LuaManager.env.rawset("__nativeCollectorSites",rows);
            var lower=cell.getGridSquare(10,20,0);lower.room=new zombie.iso.areas.IsoRoom();lower.roomId=1;
            var tap=new IsoObject(cell,lower,new IsoSprite());lower.getObjects().add(tap);tap.getModData().rawset("SAOWorldSourceId","opaque-constructed-sink");
            tap.getModData().rawset("canBeWaterPiped",true);var sink=source(tap);remember(body,sink);
            for(int x=9;x<=11;x++)for(int y=19;y<=21;y++) {
                var sq=new IsoGridSquare(cell,null,x,y,1);sq.chunk=lower.chunk;sq.setSolidFloor(true);sq.getProperties().set(IsoFlagType.solidfloor);sq.getProperties().set(IsoFlagType.exterior);
                lower.chunk.setSquare(x%8,y%8,1,sq);
            }
            var roof=cell.getGridSquare(10,20,1);position(body,cell.getGridSquare(11,20,1));body.setForwardDirection(-1,0);
            String roofRows=bridge.worldCollectorSites(body),roofRev=revision(roofRows,10,20,1);
            check("personally_observed_roof_site_admitted",roofRev!=null&&bridge.worldCollectorPlacementSquare(body,10,20,1,roofRev)==roof);
            RainCollectorNativeProbe.initialise(game);
            var update=FluidContainerUpdateSystem.class.getDeclaredMethod("updateEntity",zombie.entity.GameEntity.class,FluidContainer.class,boolean.class);update.setAccessible(true);
            var system=new FluidContainerUpdateSystem(0);
            for(String entityId:new String[]{"Base.RainCollector","Base.RainCollectorRound","Base.RainCollector_Tarp","Base.RainCollectorRound_Tarp"}) {
                var script=RainCollectorNativeProbe.entity(entityId);check("installed_entity_"+entityId,script!=null);
                var collector=RainCollectorNativeProbe.createCollector(entityId,roof);roof.getObjects().add(collector);roof.getSpecialObjects().add(collector);
                var fluid=collector.getFluidContainer();
                check("native_factory_empty_components_"+entityId,collector.getEntityScript()==script&&fluid!=null&&fluid.getAmount()==0&&fluid.getRainCatcher()>0);
                check("native_created_port_"+entityId,bridge.worldCollectorCreated(body,collector,entityId,10,20,1));
                String differentEntity=entityId.equals("Base.RainCollector")?"Base.RainCollectorRound":"Base.RainCollector";
                check("wrong_entity_and_coordinate_refused_"+entityId,!bridge.worldCollectorCreated(body,collector,differentEntity,10,20,1)
                    &&!bridge.worldCollectorCreated(body,collector,entityId,11,20,1));
                String identity=bridge.worldCollectorSource(body,collector,entityId,10,20,1);check("exact_created_source_identity_"+entityId,identity.startsWith("F:")&&identity.split("\\|").length==2);
                check("exact_native_supplier_"+entityId,tap.FindExternalWaterSource()==collector
                    &&bridge.worldCollectorFeedsFixture(body,collector,(String)field(sink,"id"),(String)field(sink,"fingerprint"),10,20,0));
                check("wrong_original_fixture_identity_refused_"+entityId,!bridge.worldCollectorFeedsFixture(body,collector,
                    "F:wrong-fixture",(String)field(sink,"fingerprint"),10,20,0));
                var privateSao=LuaManager.env.rawget("SAO");LuaManager.env.rawset("SAO",LuaManager.platform.newTable());
                check("missing_private_fixture_fact_refused_"+entityId,!bridge.worldCollectorFeedsFixture(body,collector,
                    (String)field(sink,"id"),(String)field(sink,"fingerprint"),10,20,0));LuaManager.env.rawset("SAO",privateSao);
                var differentCollector=RainCollectorNativeProbe.createCollector(entityId,cell.getGridSquare(9,19,1));
                differentCollector.getSquare().getObjects().add(differentCollector);
                check("wrong_collector_cannot_supply_claim_"+entityId,!bridge.worldCollectorFeedsFixture(body,differentCollector,
                    (String)field(sink,"id"),(String)field(sink,"fingerprint"),10,20,0));
                differentCollector.getSquare().getObjects().remove(differentCollector);
                weather.intensity=0;update.invoke(system,collector,fluid,false);check("no_precipitation_no_gain_"+entityId,fluid.getAmount()==0);
                weather.intensity=1;roof.getProperties().unset(IsoFlagType.exterior);update.invoke(system,collector,fluid,false);
                check("inside_no_rain_gain_"+entityId,fluid.getAmount()==0);roof.getProperties().set(IsoFlagType.exterior);
                float factor=fluid.getRainCatcher();fluid.setRainCatcher(0);update.invoke(system,collector,fluid,false);
                check("zero_rain_factor_no_gain_"+entityId,fluid.getAmount()==0);fluid.setRainCatcher(factor);
                update.invoke(system,collector,fluid,false); // measured native precipitation
                check("actual_native_rain_is_tainted_"+entityId,fluid.getAmount()>0&&fluid.isTainted()&&collector.isTaintedWater());
                check("unconnected_empty_fixture_no_water_credit_"+entityId,tap.getFluidAmount()==0);
                tap.getModData().rawset("canBeWaterPiped",false);tap.setUsesExternalWaterSource(true); // native connection poststate setup
                check("native_external_water_is_purified_"+entityId,tap.getFluidAmount()==fluid.getAmount()&&tap.hasWater()&&!tap.isTaintedWater());
                sink=source(tap);remember(body,sink);position(body,cell.getGridSquare(11,20,0));
                check("purified_fixture_refill_port_"+entityId,bridge.worldRefillTarget(body,(String)field(sink,"id"),(String)field(sink,"fingerprint"),(String)field(sink,"revision"),10,20,0).startsWith("READY:"));
                var heldItem=zombie.inventory.InventoryItemFactory.CreateItem("Base.WaterBottle");
                if(heldItem==null)throw new AssertionError("installed held vessel unavailable");heldItem.setName("WaterBottle");body.getInventory().AddItem(heldItem);
                var held=heldItem.getFluidContainer();held.Empty();float before=fluid.getAmount();float transferred=tap.transferFluidTo(held,before);
                check("actual_held_clean_water_gain_"+entityId,transferred>0&&held.getAmount()>0&&held.isWaterSource()&&!held.isTainted()&&!held.isPoisonous()&&fluid.getAmount()<before);
                body.getInventory().Remove(heldItem);position(body,cell.getGridSquare(11,20,1));
                collector.setUsesExternalWaterSource(true);check("dependent_collector_refused_"+entityId,!bridge.worldCollectorCreated(body,collector,entityId,10,20,1));collector.setUsesExternalWaterSource(false);
                roof.getObjects().remove(collector);roof.getSpecialObjects().remove(collector);
                tap.setUsesExternalWaterSource(false);tap.getModData().rawset("canBeWaterPiped",true);sink=source(tap);remember(body,sink);
            }
            lower.getObjects().remove(tap);position(body,here);SAOWorldSources.resetRuntimeForWorld();
            check("world_reset_retires_site_revision",bridge.worldCollectorPlacementSquare(body,12,20,0,rev)==null);
            System.out.println("D35_COLLECTOR_PORT_OK "+checks);
        } finally {ClimateManager.setInstance(oldWeather);zombie.SandboxOptions.instance.waterShutModifier.setValue(oldShut);regions.set(null,oldRegions);}
    }
}
