import zombie.entity.components.fluids.Fluid;
import zombie.entity.components.fluids.FluidContainer;
import com.sao.engine.SAONeeds;

/** Installed native amounts and clean-water predicates; controlled headless cell. */
public final class NativeStockProbe {
    private static void check(String name, boolean value) {
        System.out.println("CHECK " + name + "=" + value);
        if (!value) throw new AssertionError(name);
    }
    private static boolean clean(FluidContainer value) {
        return value.getAmount() > 0 && value.isWaterSource()
            && !value.isPoisonous() && !value.isTainted();
    }
    public static void main(String[] args) throws Exception {
        var boot = MovementCrossingProbe.class.getDeclaredMethod("boot");
        boot.setAccessible(true); boot.invoke(null);
        var fluids = ResourceApproachProbe.class.getDeclaredMethod("initFluids");
        fluids.setAccessible(true); fluids.invoke(null);
        var a = FluidContainer.CreateContainer(); a.setCapacity(4);
        var b = FluidContainer.CreateContainer(); b.setCapacity(4);
        a.addFluid(Fluid.Water, .2f); b.addFluid(Fluid.Water, .3f);
        check("native_amount_is_not_vessel_count", clean(a) && clean(b)
            && Math.abs(a.getAmount() + b.getAmount() - .5f) < .00001f);
        a.removeFluid(.1f);
        check("native_consumption_changes_held_amount", Math.abs(a.getAmount() - .1f) < .00001f);
        a.Empty(); check("empty_vessel_is_zero_stock", !clean(a));
        a.addFluid(Fluid.TaintedWater, 1); check("tainted_fluid_is_not_usable_stock", !clean(a));
        a.Empty(); a.addFluid(Fluid.Bleach, 1); check("poisonous_fluid_is_not_usable_stock", !clean(a));
        a.Empty(); a.addFluid(Fluid.Water, 1.25f);
        check("fractional_native_amount_retains_native_units", clean(a) && a.getAmount() == 1.25f);
        for (Fluid fluid : new Fluid[]{Fluid.Water, Fluid.SodaPop, Fluid.Tea, Fluid.Coffee, Fluid.Get("Cola"), Fluid.Get("ColaDiet")}) {
            a.Empty(); a.addFluid(fluid, .75f);
            check("native_hydration_" + fluid.getFluidTypeString(), SAONeeds.hydrationAmount(a) == .75f);
        }
        a.Empty(); a.addFluid(Fluid.SodaPop, .75f);
        check("native_cola_hydrates_without_clean_water_stock", SAONeeds.hydrationAmount(a) == .75f && !clean(a));
        a.Empty(); check("empty_native_fluid_cannot_hydrate", SAONeeds.hydrationAmount(a) < 0);
        a.addFluid(Fluid.TaintedWater, .75f);
        check("tainted_native_fluid_cannot_hydrate", SAONeeds.hydrationAmount(a) < 0);
        a.Empty(); a.addFluid(Fluid.Bleach, .75f);
        check("poison_native_fluid_cannot_hydrate", SAONeeds.hydrationAmount(a) < 0);
        a.Empty(); a.addFluid(Fluid.SodaPop, .75f); a.addFluid(Fluid.TaintedWater, .1f);
        check("tainted_soda_primary_is_not_safe_hydration", a.getPrimaryFluid() == Fluid.SodaPop
            && a.isTainted() && SAONeeds.hydrationAmount(a) < 0);
        a.Empty(); a.addFluid(Fluid.Water, .75f); a.addFluid(Fluid.Bleach, .1f);
        check("poison_water_primary_is_not_safe_hydration", a.getPrimaryFluid() == Fluid.Water
            && a.isPoisonous() && SAONeeds.hydrationAmount(a) < 0);
        a.Empty(); a.addFluid(Fluid.Beer, .75f);
        check("other_native_drinks_remain_unqualified_for_thirst", SAONeeds.hydrationAmount(a) < 0);
        System.out.println("NATIVE_OUTCOME_STOCK_OK");
    }
}
