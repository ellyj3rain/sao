import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.util.Map;

/** Proves the process singleton releases its body/world lookup projections. */
public final class RuntimeResetProbe {
    @SuppressWarnings({"rawtypes", "unchecked"})
    private static Map fill(Object owner, String name) throws Exception {
        Field field = owner instanceof Class<?> type
            ? type.getDeclaredField(name) : owner.getClass().getDeclaredField(name);
        field.setAccessible(true);
        Map map = (Map) field.get(owner instanceof Class<?> ? null : owner);
        map.put(new Object(), new Object());
        return map;
    }

    public static void main(String[] ignored) throws Exception {
        Class<?> bridgeType = Class.forName("com.sao.bridge.SAOBridge");
        Object bridge = bridgeType.getField("INSTANCE").get(null);
        Map<?, ?>[] bridgeMaps = {
            fill(bridge, "routes"), fill(bridge, "combats"),
            fill(bridge, "drives"), fill(bridge, "crossedDrives")
        };
        Class<?> needs = Class.forName("com.sao.engine.SAONeeds");
        Map<?, ?>[] needMaps = {
            fill(needs, "SOURCES"), fill(needs, "WATER_SOURCES"),
            fill(needs, "WEAPON_SOURCES"), fill(needs, "AMMO_SOURCES"),
            fill(needs, "OFFERED")
        };
        Method reset = bridgeType.getDeclaredMethod("resetRuntimeForWorld");
        reset.setAccessible(true);
        reset.invoke(bridge);
        for (Map<?, ?> map : bridgeMaps) {
            if (!map.isEmpty()) throw new AssertionError("bridge map crossed world");
        }
        for (Map<?, ?> map : needMaps) {
            if (!map.isEmpty()) throw new AssertionError("needs map crossed world");
        }
        System.out.println("RUNTIME_RESET_OK");
    }
}
