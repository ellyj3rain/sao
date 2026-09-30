import com.sao.engine.SAOIsoPlayerShell;
import com.sao.engine.SAOWorldSources;
import com.sao.bridge.SAOBridge;
import java.lang.reflect.Field;
import java.lang.reflect.Method;
import se.krka.kahlua.vm.KahluaTable;
import zombie.Lua.LuaManager;
import zombie.entity.components.fluids.Fluid;
import zombie.entity.components.fluids.FluidContainer;
import zombie.iso.IsoCell;
import zombie.iso.IsoObject;
import zombie.iso.SpriteDetails.IsoFlagType;
import zombie.iso.sprite.IsoSprite;

/** Native fixtures and private source evidence in a controlled loaded cell. */
public final class ResourceRefillProbe {
    private static void check(String name, boolean value) {
        System.out.println("CHECK " + name + "=" + value);
        if (!value) throw new AssertionError(name);
    }
    private static Object field(Object object, String name) throws Exception {
        Field field = object.getClass().getDeclaredField(name); field.setAccessible(true);
        return field.get(object);
    }
    private static Object source(IsoObject object) throws Exception {
        Class<?> snapshotClass = Class.forName("com.sao.engine.SAOWorldSources$Snapshot");
        var ctor = snapshotClass.getDeclaredConstructor(int.class, int.class); ctor.setAccessible(true);
        var snapshot = ctor.newInstance(1,2);
        Method method = SAOWorldSources.class.getDeclaredMethod("objectFluidSource", snapshotClass,
            zombie.iso.IsoGridSquare.class, IsoObject.class); method.setAccessible(true);
        return method.invoke(null,snapshot,object.getSquare(),object);
    }
    private static KahluaTable table() { return LuaManager.platform.newTable(); }
    private static void remember(SAOIsoPlayerShell body, Object source) throws Exception {
        var fact=table(); fact.rawset("fingerprint",field(source,"fingerprint"));
        fact.rawset("revision",field(source,"revision")); fact.rawset("state","available"); fact.rawset("explored",true);
        var facts=table(); facts.rawset(field(source,"id"),fact);
        var place=table();place.rawset("sourceFacts",facts);var known=table();known.rawset(1.0,place);
        var mind=table();mind.rawset("known",known);var beliefs=table();beliefs.rawset("refill-person",mind);
        var perception=table();perception.rawset("beliefs",beliefs);var sao=table();sao.rawset("Perception",perception);
        LuaManager.env.rawset("SAO",sao);
    }
    private static String target(SAOIsoPlayerShell body, Object source) throws Exception {
        return SAOWorldSources.refillTarget(body,(String)field(source,"id"),(String)field(source,"fingerprint"),
            (String)field(source,"revision"),10,20,0);
    }
    private static IsoObject fixture(IsoCell cell, String token) {
        var object=new IsoObject(cell,cell.getGridSquare(10,20,0),new IsoSprite());
        object.getModData().rawset("SAOWorldSourceId",token);object.getSquare().getObjects().add(object);
        return object;
    }
    public static void main(String[] args) throws Exception {
        var boot=MovementCrossingProbe.class.getDeclaredMethod("boot");boot.setAccessible(true);
        IsoCell cell=(IsoCell)boot.invoke(null);
        var make=MovementCrossingProbe.class.getDeclaredMethod("person",IsoCell.class);make.setAccessible(true);
        var body=(SAOIsoPlayerShell)make.invoke(null,cell);
        body.getModData().rawset("SAOPersonId","refill-person");
        var bridge = SAOBridge.INSTANCE;
        check("native_idle_read_does_not_admit_foreign_body",!bridge.movementIdle(new Object()));
        bridge.cancelMove(body);
        check("native_no_job_contactwait_has_idle_proof",bridge.movementIdle(body));
        body.getPathFindBehavior2().pathToLocation(11,20,0);
        check("independent_native_path_is_not_contactwait_idle",!bridge.movementIdle(body));
        bridge.cancelMove(body);
        check("acknowledged_native_cancellation_restores_idle_proof",bridge.movementIdle(body));
        var init=ResourceApproachProbe.class.getDeclaredMethod("initFluids");init.setAccessible(true);init.invoke(null);
        var addFluid=ResourceApproachProbe.class.getDeclaredMethod("fluid",IsoObject.class);addFluid.setAccessible(true);
        var tap=fixture(cell,"tap-1");FluidContainer fluid=(FluidContainer)addFluid.invoke(null,tap);
        var fact=source(tap);remember(body,fact);
        check("native_private_fixture_target",target(body,fact).startsWith("READY:"));
        check("native_exact_refill_object",SAOWorldSources.refillObject(body,(String)field(fact,"id"),
            (String)field(fact,"fingerprint"),(String)field(fact,"revision"),10,20,0)==tap);
        check("null_revision_cannot_bypass_initial_binding",SAOWorldSources.refillObject(body,
            (String)field(fact,"id"),(String)field(fact,"fingerprint"),null,10,20,0)==null);
        LuaManager.env.rawset("SAO",table());
        check("foreign_fixture_is_not_native_private_knowledge",target(body,fact).equals("NOT_PRIVATELY_OBSERVED"));
        remember(body,fact);body.setX(14.5f);body.setCurrent(cell.getGridSquare(14,20,0));
        check("private_memory_is_not_native_reach",SAOWorldSources.refillObject(body,(String)field(fact,"id"),
            (String)field(fact,"fingerprint"),(String)field(fact,"revision"),10,20,0)==null);
        body.setX(10.5f);body.setCurrent(cell.getGridSquare(10,20,0));
        fluid.removeFluid(.5f);
        check("changed_fluid_revision_refuses_new_admission",target(body,fact).equals("REVISION_CHANGED"));
        check("own_transfer_revision_retains_exact_physical_identity",SAOWorldSources.refillValid(body,tap,
            (String)field(fact,"id"),(String)field(fact,"fingerprint"),10,20,0));
        tap.getModData().rawset("SAOWorldSourceId","other-tap");
        check("replaced_fixture_identity_refused",!SAOWorldSources.refillValid(body,tap,
            (String)field(fact,"id"),(String)field(fact,"fingerprint"),10,20,0));
        var pipe=fixture(cell,"pipe-1");
        FluidContainer pipeComponent=(FluidContainer)addFluid.invoke(null,pipe);pipeComponent.Empty();
        pipe.getProperties().set(IsoFlagType.waterPiped);
        pipe.getModData().rawset("waterAmount",2.0);
        check("installed_pipe_reserve_has_water_without_primary",pipe.getFluidAmount()>0 && pipe.hasWater()
            && pipe.getPrimaryFluid()==null && !pipe.isTaintedWater());
        fact=source(pipe);remember(body,fact);
        var quantities=(java.util.Map<?,?>)field(fact,"quantities");
        check("native_pipe_reserve_projects_private_water",quantities.containsKey("water")
            && ((Number)quantities.get("water")).doubleValue()>0 && target(body,fact).startsWith("READY:"));
        pipe.getModData().rawset("waterAmount",0.0);fact=source(pipe);remember(body,fact);
        check("dry_native_pipe_refused",target(body,fact).equals("NO_CLEAN_WATER"));
        fluid.Empty();fluid.addFluid(Fluid.TaintedWater,2);fact=source(tap);remember(body,fact);
        check("native_tainted_fixture_refused",target(body,fact).equals("NO_CLEAN_WATER"));
        fluid.Empty();fluid.addFluid(Fluid.Bleach,2);fact=source(tap);remember(body,fact);
        check("native_poisonous_fixture_refused",target(body,fact).equals("NO_CLEAN_WATER"));
        fluid.Empty();fluid.addFluid(Fluid.Water,2);fact=source(tap);remember(body,fact);
        tap.getSquare().getObjects().remove(tap);
        check("removed_native_fixture_refused",target(body,fact).equals("SOURCE_MISSING"));
        System.out.println("RESOURCE_REFILL_NATIVE_OK");
    }
}
