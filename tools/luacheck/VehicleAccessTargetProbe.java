import java.lang.reflect.Method;

/** Executes the shipped vehicle origin/part-area selection without a live car. */
public final class VehicleAccessTargetProbe {
    private VehicleAccessTargetProbe() {}

    public static void main(String[] args) throws Exception {
        Class<?> needs = Class.forName("com.sao.engine.SAONeeds");
        Method select = needs.getDeclaredMethod("vehicleAccessTarget",
            String.class, Object.class, Object.class);
        select.setAccessible(true);
        Object origin = "vehicle-origin";
        Object compartment = "named-part-area";
        Object selected = select.invoke(null, "TruckBed", origin, compartment);
        Object fallback = select.invoke(null, "", origin, compartment);
        if (selected != compartment || fallback != origin) {
            throw new AssertionError("vehicle access target selection drifted");
        }
        System.out.println("PASS origin-vs-part-area");
    }
}
