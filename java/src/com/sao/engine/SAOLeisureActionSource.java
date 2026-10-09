package com.sao.engine;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.util.HexFormat;
import java.util.Map;
import se.krka.kahlua.j2se.KahluaTableImpl;
import zombie.ZomboidFileSystem;

/** Audited native action text for private actor environments. No caller paths. */
public final class SAOLeisureActionSource {
    private static final Map<String,String> PINS = Map.of(
        "ISEquipWeaponAction", "5aaf0e6942d83caed3df3acae63aa10c3b77bf9618208067b81d579a6e2bf66f",
        "ISWearClothing", "146c66743d8593581bae58e7e1d954886f73a1e6b8bc51720fd2271afbb50524",
        "ISUnequipAction", "e0a3d66680ab19c1704152991de1b8742531d90cdc129fdb3f570479b4a07784",
        "ISRestAction", "dcd87cadfeb028770795a9a745ca8c2f4a866baf28c202a7ae654ad98bc92444");
    private SAOLeisureActionSource() { }

    public static Object read(String name) {
        String expected=PINS.get(name);
        if (expected==null) return null;
        try {
            Path path=Path.of(ZomboidFileSystem.instance.getString(
                "media/lua/shared/TimedActions/"+name+".lua"));
            long size=Files.size(path);
            if (size<1 || size>24000) return null;
            byte[] bytes=Files.readAllBytes(path);
            String hash=HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(bytes));
            if (!expected.equals(hash)) return null;
            var row=new KahluaTableImpl(new java.util.HashMap<>());
            row.rawset("className",name); row.rawset("sha256",hash);
            row.rawset("sourceText",new String(bytes,StandardCharsets.UTF_8));
            row.rawset("nativeOwner","native:"+name);
            return row;
        } catch (Exception error) { return null; }
    }
}
