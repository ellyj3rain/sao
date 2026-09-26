import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.Locale;
import se.krka.kahlua.converter.KahluaConverterManager;
import se.krka.kahlua.integration.LuaCaller;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.vm.KahluaThread;
import zombie.Lua.LuaManager;
import zombie.ZomboidFileSystem;
import zombie.core.Core;
import zombie.iso.worldgen.StaticModule;
import zombie.iso.worldgen.WorldGenChunk;

/** Actual per-map loader, native biome/prefab reader and region predicate.
 * This probe does not render tiles, initialize physics or launch a game window.
 */
public final class NativeGenerationProbe {
    private static void check(boolean value, String reason) {
        if (!value) throw new AssertionError(reason);
    }

    private static void lua(String source, String name) throws Exception {
        LuaManager.thread.call(LuaCompiler.loadstring(source, name, LuaManager.env), null, null, null);
    }

    private static void load(Path path) throws Exception {
        lua(Files.readString(path, StandardCharsets.UTF_8), path.toString());
    }

    private static void loadDirectory(Path path) throws Exception {
        try (var paths = Files.walk(path)) {
            for (Path file : paths.filter(p -> p.toString().endsWith(".lua")).sorted().toList()) load(file);
        }
    }

    private static StaticModule selected(List<StaticModule> modules, Method contains, int x, int y) throws Exception {
        // The production genRandomSquare stream uses this exact native predicate
        // and then List.get(0). The ordered module list is read by its constructor.
        for (StaticModule module : modules) {
            if ((Boolean) contains.invoke(null, x, y, module)) return module;
        }
        return null;
    }

    private static boolean roadAt(List<StaticModule> modules, Method contains, int x, int y) throws Exception {
        StaticModule module = selected(modules, contains, x, y);
        return module != null && module.prefab() != null;
    }

    private static boolean grassAt(List<StaticModule> modules, Method contains, int x, int y) throws Exception {
        StaticModule module = selected(modules, contains, x, y);
        return module != null && module.biome() != null;
    }

    @SuppressWarnings("unchecked")
    public static void main(String[] args) throws Exception {
        Path game = Path.of(args[0]).toAbsolutePath().normalize();
        Path override = Path.of(args[1]).toAbsolutePath().normalize();
        Path cache = Path.of(args[2]).toAbsolutePath().normalize();
        Files.createDirectories(cache);
        ZomboidFileSystem.instance.setCacheDir(cache.toString());
        ZomboidFileSystem.instance.init();
        zombie.core.random.RandStandard.INSTANCE.init();
        LuaManager.platform = new J2SEPlatform();
        LuaManager.env = LuaManager.platform.newEnvironment();
        LuaManager.thread = new KahluaThread(LuaManager.platform, LuaManager.env);
        LuaManager.thread.debugOwnerThread = Thread.currentThread();
        LuaManager.converterManager = new KahluaConverterManager();
        LuaManager.caller = new LuaCaller(LuaManager.converterManager);
        // Only dependency traversal is supplied by this fixture; all feature,
        // biome, selection and prefab data below is the installed native source.
        lua("require = function() end", "dependency-fixture");
        Path generation = game.resolve("media/lua/server/WorldGen");
        load(generation.resolve("WorldGen.lua"));
        lua("worldgen.features={GROUND={},PLANT={},BUSH={},TREE={},ORE={},NONE={}}; "
            + "worldgen.subbiomes={}; worldgen.biomes_map={}", "feature-registries");
        loadDirectory(generation.resolve("features"));
        loadDirectory(generation.resolve("biomes/subbiomes"));
        loadDirectory(generation.resolve("biomes/worldgen"));
        loadDirectory(generation.resolve("prefabs"));
        load(generation.resolve("Selection.lua"));
        String map = override.getParent().getFileName().toString();
        Core.gameMap = map;
        ZomboidFileSystem.instance.activeFileMap.put(
            ("media/maps/" + map + "/WorldGenOverride.lua").toLowerCase(Locale.ENGLISH), override.toString());
        WorldGenChunk generator = new WorldGenChunk(73L);
        Field field = WorldGenChunk.class.getDeclaredField("staticModules");
        field.setAccessible(true);
        List<StaticModule> modules = (List<StaticModule>) field.get(generator);
        check(modules.size() == 6, "native per-map override did not load all six regions");
        Method contains = WorldGenChunk.class.getDeclaredMethod("lambda$genRandomSquare$0", int.class, int.class, StaticModule.class);
        contains.setAccessible(true);
        for (int x : new int[] {128, 384}) for (int y : new int[] {128, 384}) {
            StaticModule road = selected(modules, contains, x, y);
            check(road != null && road.prefab() != null && road.biome() == null,
                "native first-match priority lost the origin road");
            check(road.prefab().getX() == 1 && road.prefab().getY() == 8
                && road.prefab().getTile(0).equals("blends_street_01_86"), "native road prefab differs");
            StaticModule grass = selected(modules, contains, x, y - 8);
            check(grass != null && grass.biome() != null && grass.prefab() == null,
                "native grass patch missing beside origin road");
        }
        check(roadAt(modules, contains, 0, 124) && roadAt(modules, contains, 511, 131),
            "native inclusive road boundary lost");
        check(selected(modules, contains, 0, 123) == null
            && selected(modules, contains, 512, 128) == null,
            "native region escaped its rectangle");
        check(grassAt(modules, contains, 64, 64) && grassAt(modules, contains, 191, 191),
            "native inclusive grass boundary lost");
        System.out.println("PASS native terrain loader: real override, six ordered regions, native grass/road and inclusive predicates; no tile/render claim");
    }
}
