package zombie.pot;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Locale;
import java.util.Arrays;
import zombie.ZomboidFileSystem;
import zombie.iso.MapFiles;
import zombie.iso.NewMapBinaryFile;

/** Actual installed native file loaders. No world, actors, rendering or saves. */
public final class NativeAuthoredMapProbe {
    private static void check(boolean ok, String reason) {
        if (!ok) throw new AssertionError(reason);
    }

    public static void main(String[] args) throws Exception {
        Path version = Path.of(args[0]).toAbsolutePath().normalize();
        String name = args[1];
        Path maps = version.resolve("media/maps/" + name);
        Path cache = Path.of(args[2]).toAbsolutePath().normalize();
        int minX = Integer.parseInt(args[3]), minY = Integer.parseInt(args[4]);
        int maxX = Integer.parseInt(args[5]), maxY = Integer.parseInt(args[6]);
        Files.createDirectories(cache);
        ZomboidFileSystem.instance.setCacheDir(cache.toString());
        ZomboidFileSystem.instance.init();
        zombie.core.random.RandStandard.INSTANCE.init();
        ZomboidFileSystem.instance.activeFileMap.put(
            ("media/maps/" + name + "/map.info").toLowerCase(Locale.ENGLISH), maps.resolve("map.info").toString());
        MapFiles nativeFiles = new MapFiles(name, "media/maps/" + name, maps.toString(), 0);
        check(nativeFiles.load(), "native map directory refused");
        nativeFiles.postLoad();
        check(nativeFiles.minX == minX && nativeFiles.minY == minY
            && nativeFiles.maxX == maxX && nativeFiles.maxY == maxY,
            "native authored map spilled beyond the selected extent");
        check(nativeFiles.infoHeaders.size() == (maxX - minX + 1) * (maxY - minY + 1),
            "native authored cell set differs");
        int totalRooms = 0, totalBuildings = 0, totalTiles = 0;
        for (int x = minX; x <= maxX; x++) for (int y = minY; y <= maxY; y++) {
            check(nativeFiles.hasCell(x, y) && !nativeFiles.hasCell300(x, y), "cell was not native POT format");
            POTLotHeader header = new POTLotHeader(x, y, true);
            header.load(maps.resolve(x + "_" + y + ".lotheader").toFile());
            check(header.version == 1 && header.width == 8 && header.height == 8, "native header format differs");
            for (var building : header.buildings) {
                check(building.x >= minX * 256 && building.y >= minY * 256
                    && building.x2 <= (maxX + 1) * 256 && building.y2 <= (maxY + 1) * 256,
                    "native building leaves selected extent");
            }
            POTLotPack pack = new POTLotPack(header);
            pack.load(maps.resolve("world_" + x + "_" + y + ".lotpack").toFile());
            POTChunkData chunk = new POTChunkData(x, y, true);
            chunk.load(maps.resolve("chunkdata_" + x + "_" + y + ".bin").toFile());
            for (int at = 7; at + 2 < args.length; at += 3) {
                int ox = Integer.parseInt(args[at]), oy = Integer.parseInt(args[at + 1]);
                int oz = Integer.parseInt(args[at + 2]);
                if (Math.floorDiv(ox, 256) != x || Math.floorDiv(oy, 256) != y) continue;
                check(oz == 0, "origin ground-bit probe supports floor zero only");
                int bits = chunk.getSquareBits(ox, oy);
                check((bits & (POTChunkData.BIT_SOLID | POTChunkData.BIT_WATER)) == 0
                    && (bits & POTChunkData.BIT_ROOM) != 0, "origin is not a clear native ground room");
                var tiles = pack.getSquareData(ox, oy, oz);
                check(tiles != null && tiles.length > 0, "origin lacks native tiles");
                System.out.println("ORIGIN " + ox + " " + oy + " " + oz + " bits=" + bits
                    + " tiles=" + Arrays.toString(tiles));
            }
            totalRooms += header.roomList.size();
            totalBuildings += header.buildings.size();
            totalTiles += pack.data.size();
            System.out.println("CELL " + x + " " + y + " " + header.roomList.size() + " " + header.buildings.size());
        }
        if (POTLotPack.in != null) POTLotPack.in.close();
        int assets = 0;
        for (String directory : new String[] {"binmap", "basement_access"}) {
            Path folder = version.resolve("media/" + directory);
            if (!Files.isDirectory(folder)) continue;
            try (var paths = Files.list(folder)) {
                for (Path asset : paths.filter(p -> p.toString().endsWith(".pzby")).sorted().toList()) {
                    NewMapBinaryFile binary = new NewMapBinaryFile(true);
                    var header = binary.loadHeader(asset.toString());
                    check(header.version == 0 && header.width > 0 && header.height > 0 && header.levels > 0,
                        "native basement header differs");
                    for (int x = 0; x < header.width; x++) for (int y = 0; y < header.height; y++) {
                        check(binary.loadChunk(header, x, y) != null, "native basement chunk unavailable");
                    }
                    assets++;
                }
            }
        }
        check(totalRooms > 0 && totalBuildings > 0 && totalTiles > 0, "authored environment is empty");
        System.out.println("PASS native authored loaders: " + totalRooms + " rooms, " + totalBuildings
            + " buildings, " + assets + " basement/access assets; file loading only, no gameplay claim");
    }
}
