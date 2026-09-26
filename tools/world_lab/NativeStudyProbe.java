import java.nio.file.Files;
import java.nio.file.Path;
import zombie.ZomboidFileSystem;
import zombie.core.Core;
import zombie.iso.IsoChunkMap;
import zombie.iso.worldgen.WorldGenParams;
import zombie.config.BooleanConfigOption;
import zombie.config.IntegerConfigOption;

/** Native parameter persistence and configuration semantics, without a game window. */
public final class NativeStudyProbe {
    private static void check(boolean ok, String reason) {
        if (!ok) throw new AssertionError(reason);
    }
    public static void main(String[] args) throws Exception {
        Path cache = Path.of(args[0]).toAbsolutePath().normalize();
        check(Files.isDirectory(cache), "isolated cache missing");
        zombie.core.random.RandStandard.INSTANCE.init();
        ZomboidFileSystem.instance.setCacheDir(cache.toString());
        Core.gameMode = "Sandbox";
        Core.gameSaveWorld = "NativeStudyProbe";
        Files.createDirectories(cache.resolve("Saves/Sandbox/NativeStudyProbe"));
        check(IsoChunkMap.CHUNK_SIZE_IN_SQUARES == 8, "native chunk size changed");
        check(zombie.iso.IsoCell.getCellSizeInSquares() == 256, "native cell size changed");
        check(zombie.Lua.LuaManager.GlobalObject.getCellSizeInSquares() == 256,
            "native Lua global cell size changed");
        WorldGenParams params = WorldGenParams.INSTANCE;
        params.setSeedString("study-parameter-roundtrip");
        params.setMinXCell(-2);
        params.setMinYCell(0);
        params.setMaxXCell(1);
        params.setMaxYCell(2);
        params.save();
        params.setSeedString("changed");
        params.setMinXCell(5);
        params.setMaxYCell(6);
        params.load();
        check(params.getSeedString().equals("study-parameter-roundtrip"), "native seed not restored");
        check(params.getMinXCell() == -2 && params.getMinYCell() == 0
            && params.getMaxXCell() == 1 && params.getMaxYCell() == 2,
            "native dimensions not restored");
        IntegerConfigOption population = new IntegerConfigOption("Population", 1, 500, 32);
        check(population.isValidString("64"), "valid population rejected");
        check(!population.isValidString("501"), "invalid population accepted");
        population.makeCopy().setValueFromObject(64.0);
        check(population.getValue() == 32, "candidate validation mutated native option");
        BooleanConfigOption enabled = new BooleanConfigOption("Enabled", false);
        check(enabled.isValidString("true"), "boolean validation differs");
        var refused = zombie.Lua.LuaManager.GlobalObject.getFileWriter("StudyWorld/check.jsonl", true, false);
        check(refused == null, "native extension restriction changed");
        var writer = zombie.Lua.LuaManager.GlobalObject.getFileWriter("StudyWorld/check.json", true, false);
        check(writer != null, "native observation writer unavailable");
        writer.write("{\"native\":true}\n");
        writer.close();
        var reader = zombie.Lua.LuaManager.GlobalObject.getFileReader("StudyWorld/check.json", false);
        check(reader != null, "native read-back unavailable");
        check("{\"native\":true}".equals(reader.readLine()) && reader.readLine() == null,
            "native observation read-back differs");
        reader.close();
        System.out.println("PASS native world parameters: isolated save/reload, dimensions, seed, option copies, writer/read-back");
    }
}
