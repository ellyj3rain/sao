import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.lang.reflect.Modifier;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;
import zombie.SandboxOptions;
import zombie.sandbox.CustomSandboxOptions;

/** Installed ScriptParser/CustomSandboxOptions and SandboxOptions receiver. */
public final class WeekOneSandboxProbe {
    private static int checks;

    private static void check(String name, boolean good) {
        if (!good) throw new AssertionError(name);
        checks++;
        System.out.println("CASE " + name);
    }

    private static Object field(Object target, String key) throws Exception {
        Field f = target.getClass().getDeclaredField(key);
        f.setAccessible(true);
        return f.get(target);
    }

    private static CustomSandboxOptions parse(String text) throws Exception {
        var parsed = new CustomSandboxOptions();
        Method method = CustomSandboxOptions.class.getDeclaredMethod("parse", String.class);
        method.setAccessible(true);
        method.invoke(parsed, text);
        return parsed;
    }

    private static Map<String, Object> options(CustomSandboxOptions source) throws Exception {
        var result = new LinkedHashMap<String, Object>();
        for (Object option : (List<?>) field(source, "options")) {
            String id = (String) option.getClass().getField("id").get(option);
            check("unique_" + id, result.put(id, option) == null);
        }
        return result;
    }

    private static String valuesWithoutPage(Object option, boolean omitDefault) throws Exception {
        var values = new TreeMap<String, String>();
        for (Field f : option.getClass().getFields()) {
            if (Modifier.isStatic(f.getModifiers()) || f.getName().equals("page")
                || omitDefault && f.getName().equals("defaultValue")) continue;
            values.put(f.getName(), String.valueOf(f.get(option)));
        }
        return option.getClass().getSimpleName() + values;
    }

    public static void main(String[] args) throws Exception {
        Thread.setDefaultUncaughtExceptionHandler((thread, error) -> {
            error.printStackTrace();
            System.exit(1);
        });
        var platform = new se.krka.kahlua.j2se.J2SEPlatform();
        var env = platform.newEnvironment();
        var thread = new se.krka.kahlua.vm.KahluaThread(platform, env);
        thread.debugOwnerThread = Thread.currentThread();
        se.krka.kahlua.luaj.compiler.LuaCompiler.register(env);
        zombie.Lua.LuaManager.platform = platform;
        zombie.Lua.LuaManager.env = env;
        zombie.Lua.LuaManager.thread = thread;
        zombie.Lua.LuaManager.converterManager = new se.krka.kahlua.converter.KahluaConverterManager();
        zombie.Lua.LuaManager.caller = new se.krka.kahlua.integration.LuaCaller(
            zombie.Lua.LuaManager.converterManager);
        zombie.ZomboidFileSystem.instance.base.set(Path.of(args[3]).toFile());
        ((zombie.ZomboidFileSystem.PZFolder) field(zombie.ZomboidFileSystem.instance,
            "workdir")).set(Path.of(args[3]).toFile());
        var source = parse(Files.readString(Path.of(args[0])));
        var owned = parse(Files.readString(Path.of(args[1])));
        var originals = options(source);
        var imported = options(owned);
        var pages = new HashMap<String, String>();
        for (String line : Files.readAllLines(Path.of(args[2]))) {
            String[] pair = line.split("\t", 2);
            check("unique_page_" + pair[0], pages.put(pair[0], pair[1]) == null);
        }
        check("exact_source_24", originals.size() == 24);
        check("exact_owned_24", pages.size() == 24);
        check("creator_variant_unregistered", !imported.containsKey("BanditsWeekOne.Variant"));
        for (var entry : pages.entrySet()) {
            String id = entry.getKey();
            Object old = originals.get(id);
            Object current = imported.get(id);
            check("source_present_" + id, old != null && current != null);
            boolean strike = id.equals("BanditsWeekOne.EventFinalSolution");
            check("native_definition_parity_" + id,
                valuesWithoutPage(old, strike).equals(valuesWithoutPage(current, strike)));
            if (strike) {
                check("source_original_strike_true",
                    old.getClass().getField("defaultValue").getBoolean(old));
                check("sao_integrated_strike_false",
                    !current.getClass().getField("defaultValue").getBoolean(current));
            }
            check("owned_page_" + id,
                entry.getValue().equals(current.getClass().getField("page").get(current)));
        }

        int baseCount = new SandboxOptions().getNumOptions();
        var ownedOnly = new SandboxOptions();
        owned.initInstance(ownedOnly);
        check("sao_only_count", ownedOnly.getNumOptions() == baseCount + imported.size());
        for (var entry : pages.entrySet()) {
            var option = ownedOnly.getOptionByName(entry.getKey());
            check("sao_only_binding_" + entry.getKey(), option != null
                && entry.getValue().equals(option.getPageName()));
        }
        check("sao_only_strike_default_false", !((zombie.config.BooleanConfigOption)
            ownedOnly.getOptionByName("BanditsWeekOne.EventFinalSolution")
                .asConfigOption()).getDefaultValue());
        check("sao_strike_default_false", !((zombie.config.BooleanConfigOption)
            ownedOnly.getOptionByName("SurvivorAwareness.WeekOneNuke")
                .asConfigOption()).getDefaultValue());

        var sourceFirst = new SandboxOptions();
        source.initInstance(sourceFirst);
        owned.initInstance(sourceFirst);
        var sourceLast = new SandboxOptions();
        owned.initInstance(sourceLast);
        source.initInstance(sourceLast);
        int expectedCount = baseCount + imported.size() + originals.size();
        check("source_first_dual_count", sourceFirst.getNumOptions() == expectedCount);
        check("source_last_dual_count", sourceLast.getNumOptions() == expectedCount);
        for (var entry : pages.entrySet()) {
            String id = entry.getKey();
            check("source_first_selected_owned_" + id,
                entry.getValue().equals(sourceFirst.getOptionByName(id).getPageName()));
            check("source_last_selected_original_" + id,
                "BanditsWeekOne".equals(sourceLast.getOptionByName(id).getPageName()));
        }
        check("source_first_selected_strike_false", !((zombie.config.BooleanConfigOption)
            sourceFirst.getOptionByName("BanditsWeekOne.EventFinalSolution")
                .asConfigOption()).getDefaultValue());
        check("source_last_selected_strike_true", ((zombie.config.BooleanConfigOption)
            sourceLast.getOptionByName("BanditsWeekOne.EventFinalSolution")
                .asConfigOption()).getDefaultValue());
        sourceFirst.set("BanditsWeekOne.EventFinalSolution", "true");
        check("source_first_explicit_strike_true", "true".equals(sourceFirst
            .getOptionByName("BanditsWeekOne.EventFinalSolution")
                .asConfigOption().getValueAsString()));
        for (var pair : List.of(sourceFirst, sourceLast, ownedOnly)) {
            pair.set("BanditsWeekOne.VehiclesMax", "6");
            check("saved_id_vehicle_" + checks,
                "6".equals(pair.getOptionByName("BanditsWeekOne.VehiclesMax")
                    .asConfigOption().getValueAsString()));
        }
        System.out.println("PASS native Week One sandbox " + checks);
        System.exit(0);
    }
}
