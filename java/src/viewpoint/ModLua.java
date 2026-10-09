package viewpoint;

import java.io.File;
import java.net.URISyntaxException;
import se.krka.kahlua.vm.KahluaTable;
import zombie.Lua.LuaManager;

/**
 * SAO adaptation of Viewpoint's play-start Lua fallback. The original class
 * enumerates every Lua file beside its JAR; in SAO.jar that would rerun the
 * entire SAO client folder. Only the four incorporated scripts belong here.
 */
final class ModLua {
    private static final String[] SCRIPTS = {
        "SAO_Viewpoint_Interact.lua",
        "SAO_Viewpoint_Loot.lua",
        "SAO_Viewpoint_Mouse.lua",
        "SAO_Viewpoint_Options.lua"
    };
    private static final String[] MARKERS = {
        "ViewpointInteract.run",
        "ViewpointLoot.closeWindow",
        "SAOViewpointMouseLoaded",
        "SAOViewpointOptionsLoaded"
    };

    private ModLua() {
    }

    static void load() {
        if (LuaManager.env == null) {
            return;
        }
        boolean[] pending = new boolean[SCRIPTS.length];
        boolean anyPending = false;
        for (int index = 0; index < SCRIPTS.length; index++) {
            pending[index] = !loaded(MARKERS[index]);
            anyPending |= pending[index];
        }
        if (!anyPending) {
            return;
        }
        final File folder;
        try {
            File jar = new File(ModLua.class.getProtectionDomain()
                .getCodeSource().getLocation().toURI());
            File modRoot = jar.getParentFile().getParentFile().getParentFile();
            folder = new File(modRoot, "media/lua/client").getCanonicalFile();
        } catch (URISyntaxException | java.io.IOException | NullPointerException failure) {
            System.out.println("[SAO Viewpoint] Lua folder unavailable: " + failure);
            return;
        }
        for (int index = 0; index < SCRIPTS.length; index++) {
            if (!pending[index]) {
                continue;
            }
            File file = new File(folder, SCRIPTS[index]);
            if (!file.isFile()) {
                System.out.println("[SAO Viewpoint] Lua script missing: " + file);
                return;
            }
        }
        for (int index = 0; index < SCRIPTS.length; index++) {
            if (pending[index]) {
                LuaManager.RunLua(new File(folder, SCRIPTS[index]).getAbsolutePath());
            }
        }
    }

    private static boolean loaded(String marker) {
        int dot = marker.indexOf('.');
        if (dot < 0) {
            return Boolean.TRUE.equals(LuaManager.env.rawget(marker));
        }
        Object table = LuaManager.env.rawget(marker.substring(0, dot));
        return table instanceof KahluaTable
            && ((KahluaTable) table).rawget(marker.substring(dot + 1)) != null;
    }
}
