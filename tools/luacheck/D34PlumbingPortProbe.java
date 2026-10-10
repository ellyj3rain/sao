import com.sao.bridge.SAOBridge;
import com.sao.engine.SAOIsoPlayerShell;
import com.sao.engine.SAOWorldSources;
import java.util.Map;
import se.krka.kahlua.vm.KahluaTable;
import zombie.Lua.LuaManager;
import zombie.entity.components.fluids.Fluid;
import zombie.entity.components.fluids.FluidContainer;
import zombie.iso.IsoCell;
import zombie.iso.IsoGridSquare;
import zombie.iso.IsoObject;
import zombie.iso.SpriteDetails.IsoFlagType;
import zombie.iso.sprite.IsoSprite;

/** Actual loaded-cell native supplier/mains and private source ports; no VM loader. */
public final class D34PlumbingPortProbe {
    private static int checks;
    private static void check(String name, boolean value) {
        if (!value) throw new AssertionError("D34_PLUMBING:" + name);
        checks++; System.out.println("CHECK D34_PLUMBING:" + name);
    }
    private static Object field(Object object, String name) throws Exception {
        var f=object.getClass().getDeclaredField(name);f.setAccessible(true);return f.get(object);
    }
    private static Object source(IsoObject object) throws Exception {
        var type=Class.forName("com.sao.engine.SAOWorldSources$Snapshot");
        var ctor=type.getDeclaredConstructor(int.class,int.class);ctor.setAccessible(true);
        var method=SAOWorldSources.class.getDeclaredMethod("objectFluidSource",type,IsoGridSquare.class,IsoObject.class);
        method.setAccessible(true);return method.invoke(null,ctor.newInstance(1,2),object.getSquare(),object);
    }
    private static KahluaTable table() { return LuaManager.platform.newTable(); }
    private static void remember(SAOIsoPlayerShell body,Object source)throws Exception {
        var fact=table();fact.rawset("fingerprint",field(source,"fingerprint"));fact.rawset("revision",field(source,"revision"));
        fact.rawset("state",field(source,"state"));fact.rawset("explored",true);fact.rawset("plumbing",field(source,"plumbing"));
        var facts=table();facts.rawset(field(source,"id"),fact);var place=table();place.rawset("sourceFacts",facts);
        var known=table();known.rawset(1.0,place);var mind=table();mind.rawset("known",known);
        var beliefs=table();beliefs.rawset(body.getModData().rawget("SAOPersonId"),mind);
        var perception=table();perception.rawset("beliefs",beliefs);var sao=table();sao.rawset("Perception",perception);
        LuaManager.env.rawset("SAO",sao);
    }
    private static String target(SAOIsoPlayerShell body,Object source)throws Exception {
        return SAOBridge.INSTANCE.worldPlumbTarget(body,(String)field(source,"id"),(String)field(source,"fingerprint"),
            (String)field(source,"revision"),10,20,0);
    }
    private static boolean valid(SAOIsoPlayerShell body,IsoObject object,Object source,boolean complete)throws Exception {
        return SAOBridge.INSTANCE.worldPlumbValid(body,object,(String)field(source,"id"),(String)field(source,"fingerprint"),10,20,0,complete);
    }
    private static String refill(SAOIsoPlayerShell body,Object source)throws Exception {
        return SAOBridge.INSTANCE.worldRefillTarget(body,(String)field(source,"id"),(String)field(source,"fingerprint"),
            (String)field(source,"revision"),10,20,0);
    }
    public static Map<String,String> run(IsoCell cell,SAOIsoPlayerShell body)throws Exception {
        body.getModData().rawset("SAOPersonId","plumbing-person");
        var square=cell.getGridSquare(10,20,0);square.room=new zombie.iso.areas.IsoRoom();square.roomId=1;
        var regions=zombie.iso.areas.isoregion.IsoRegions.class.getDeclaredField("dataRoot");regions.setAccessible(true);
        Object oldRegions=regions.get(null);
        if(oldRegions==null)regions.set(null,new zombie.iso.areas.isoregion.data.DataRoot());
        int oldShut=zombie.SandboxOptions.instance.waterShutModifier.getValue(),oldApo=zombie.SandboxOptions.instance.timeSinceApo.getValue();
        zombie.SandboxOptions.instance.waterShutModifier.setValue(0);zombie.SandboxOptions.instance.timeSinceApo.setValue(1);
        try {
            var tap=new IsoObject(cell,square,new IsoSprite());square.getObjects().add(tap);
            tap.getModData().rawset("SAOWorldSourceId","opaque-plumbing-tap");tap.getModData().rawset("canBeWaterPiped",true);
            var dry=source(tap);remember(body,dry);
            check("dry_zero_capacity_observed",tap.getFluidCapacity()==0 && tap.getFluidAmount()==0
                && "unconnected".equals(field(dry,"plumbing")) && ((Map<?,?>)field(dry,"quantities")).isEmpty());
            String before=SAOWorldSources.observeLoadedChunk(1,2);
            check("zero_capacity_scan_admits_fixture",before.contains("S|id=F:opaque-plumbing-tap") && before.contains("|plumbing=unconnected"));
            check("initial_native_supplier_absent",tap.FindExternalWaterSource()==null);
            String unavailable=target(body,dry);System.out.println("PLUMB_TARGET no_supplier="+unavailable);
            check("no_supplier_or_mains_refused",unavailable.equals("PLUMBING_UNAVAILABLE") && !valid(body,tap,dry,false));
            var upper=new IsoGridSquare(cell,null,10,20,1);upper.chunk=square.chunk;upper.getProperties().set(IsoFlagType.solidfloor);
            square.chunk.setSquare(2,4,1,upper);
            var collector=new zombie.iso.objects.IsoThumpable(cell);collector.setSquare(upper);upper.getObjects().add(collector);
            var add=ResourceApproachProbe.class.getDeclaredMethod("fluid",IsoObject.class);add.setAccessible(true);
            FluidContainer supply=(FluidContainer)add.invoke(null,collector);supply.Empty();
            check("actual_native_supplier_found",tap.FindExternalWaterSource()==collector);
            check("empty_supplier_allows_connection_without_water_credit",target(body,dry).startsWith("READY:")
                && valid(body,tap,dry,false) && tap.getFluidAmount()==0);
            check("exact_loaded_plumbing_object",SAOBridge.INSTANCE.worldPlumbObject(body,(String)field(dry,"id"),
                (String)field(dry,"fingerprint"),(String)field(dry,"revision"),10,20,0)==tap);
            check("null_revision_refused",SAOBridge.INSTANCE.worldPlumbObject(body,(String)field(dry,"id"),
                (String)field(dry,"fingerprint"),null,10,20,0)==null);
            LuaManager.env.rawset("SAO",table());check("private_actor_evidence_required",target(body,dry).equals("NOT_PRIVATELY_OBSERVED"));remember(body,dry);
            body.setX(14.5f);body.setCurrent(cell.getGridSquare(14,20,0));
            check("remembered_fixture_does_not_widen_reach",!valid(body,tap,dry,false));body.setX(10.5f);body.setCurrent(square);
            upper.getObjects().remove(collector);tap.getProperties().set(IsoFlagType.waterPiped);tap.getModData().rawset("waterAmount",0.0);
            var piped=source(tap);remember(body,piped);
            zombie.SandboxOptions.instance.waterShutModifier.setValue(14);
            check("native_mains_branch_admits",target(body,sourceAndRemember(body,tap)).startsWith("READY:"));
            zombie.SandboxOptions.instance.waterShutModifier.setValue(0);piped=sourceAndRemember(body,tap);
            check("native_shut_mains_refuses",target(body,piped).equals("PLUMBING_UNAVAILABLE"));
            upper.getObjects().add(collector);tap.getModData().rawset("canBeWaterPiped",null);piped=sourceAndRemember(body,tap);
            check("sprite_supplier_branch_without_modflag",target(body,piped).startsWith("READY:"));
            tap.getModData().rawset("canBeWaterPiped",true);dry=sourceAndRemember(body,tap);
            tap.getModData().rawset("canBeWaterPiped",false);tap.setUsesExternalWaterSource(true);
            check("connected_empty_poststate_valid",valid(body,tap,dry,true) && !valid(body,tap,dry,false) && tap.getFluidAmount()==0);
            var connected=source(tap);
            check("connection_changes_revision",!field(dry,"revision").equals(field(connected,"revision")));
            check("changed_revision_refuses",target(body,dry).equals("REVISION_CHANGED"));
            remember(body,connected);check("empty_connection_cannot_refill",refill(body,connected).equals("NO_CLEAN_WATER"));
            supply.addFluid(Fluid.Water,2);connected=sourceAndRemember(body,tap);
            check("native_connected_quantity_is_real",tap.getFluidAmount()==2 && ((Number)((Map<?,?>)field(connected,"quantities")).get("water")).floatValue()==2
                && refill(body,connected).startsWith("READY:"));
            String after=SAOWorldSources.observeLoadedChunk(1,2);
            tap.useFluid(.5f);check("native_connected_use_consumes_supplier",supply.getAmount()==1.5f && tap.getFluidAmount()==1.5f);
            supply.Empty();supply.addFluid(Fluid.Bleach,2);connected=sourceAndRemember(body,tap);
            check("poison_connection_custody_independent_of_water_safety",valid(body,tap,connected,true) && refill(body,connected).equals("NO_CLEAN_WATER"));
            tap.getModData().rawset("SAOWorldSourceId","replacement");
            check("changed_identity_refuses_connected_poststate",!valid(body,tap,connected,true));
            square.getObjects().remove(tap);upper.getObjects().remove(collector);
            System.out.println("D34_PLUMBING_PORT_OK "+checks);return Map.of("before",before,"after",after);
        } finally {zombie.SandboxOptions.instance.waterShutModifier.setValue(oldShut);zombie.SandboxOptions.instance.timeSinceApo.setValue(oldApo);regions.set(null,oldRegions);}
    }
    private static Object sourceAndRemember(SAOIsoPlayerShell body,IsoObject object)throws Exception {
        Object value=source(object);remember(body,value);return value;
    }
}
