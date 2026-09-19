import com.sao.engine.SAODurableText;
import com.sao.engine.SAODurableProbeSink;
import com.sao.engine.SAOIsoPlayerShell;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.HexFormat;
import se.krka.kahlua.vm.KahluaTable;
import zombie.Lua.LuaManager;

/** Actual native Kahlua serialization; extracted bridge methods use recording codec sinks. */
public final class DurableTextProbe {
    private static void check(boolean value, String reason) { if (!value) throw new AssertionError(reason); }
    private static KahluaTable table() { return LuaManager.platform.newTable(); }
    private static Object roundtrip(Object value) throws Exception {
        KahluaTable source = table(); source.rawset("state", value);
        ByteBuffer bytes = ByteBuffer.allocate(2 * 1024 * 1024);
        source.save(bytes); bytes.flip();
        KahluaTable restored = table(); restored.load(bytes, 249);
        check(!bytes.hasRemaining(), "native durable table has trailing bytes");
        return restored.rawget("state");
    }
    private static KahluaTable packed(String text) { return (KahluaTable) SAODurableText.pack(text); }
    private static KahluaTable chunks(KahluaTable value) { return (KahluaTable) value.rawget("chunks"); }
    private static void fragments(Object value) {
        var iterator = chunks((KahluaTable)value).iterator();
        while (iterator.advance()) check(((String)iterator.getValue()).getBytes(StandardCharsets.UTF_8).length <= 16000, "fragment exceeds native byte bound");
    }
    private static void refuses(Object value, String reason) {
        boolean refused = false;
        try { SAODurableText.unpack(value); } catch (IllegalArgumentException expected) { refused = true; }
        check(refused, reason);
    }
    private static String hash(String text) throws Exception {
        return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(text.getBytes(StandardCharsets.UTF_8)));
    }
    private static void bootstrap() throws Exception {
        zombie.core.random.RandStandard.INSTANCE.init(); zombie.ZomboidFileSystem.instance.init();
        zombie.SoundManager.instance = new zombie.DummySoundManager();
        LuaManager.platform = new se.krka.kahlua.j2se.J2SEPlatform(); LuaManager.env = table();
        zombie.Lua.LuaEventManager.register(LuaManager.platform, LuaManager.env);
        zombie.characters.SurvivorDesc.HairCommonColors.add(new zombie.core.ImmutableColor(.2f,.3f,.4f));
        zombie.core.skinnedmodel.population.HairStyles.instance = new zombie.core.skinnedmodel.population.HairStyles();
        zombie.core.skinnedmodel.population.BeardStyles.instance = new zombie.core.skinnedmodel.population.BeardStyles();
    }
    public static void main(String[] args) throws Exception {
        bootstrap();
        String text = "A".repeat(16000) + "B".repeat(16000) + "C".repeat(42000);
        boolean unsafe = false;
        try { unsafe = !text.equals(roundtrip(text)); } catch (Exception | AssertionError expected) { unsafe = true; }
        check(unsafe, "native long-string motivating defect did not reproduce");
        System.out.println("PASS native Kahlua long-string defect reproduced; native save/load uses signed-short UTF-8 strings");
        String boundary = "S".repeat(32767);
        check(SAODurableText.pack(boundary) instanceof String && boundary.equals(roundtrip(boundary)), "short-string boundary changed");
        check(SAODurableText.pack("S".repeat(32768)) instanceof KahluaTable, "oversize string was not fragmented");
        Object ascii = SAODurableText.pack(text); fragments(ascii);
        check(text.equals(SAODurableText.unpack(roundtrip(ascii))), "fragmented native roundtrip changed text");
        String unicode = "a".repeat(15999) + "\uD83D\uDE42\u6F22\u00E9".repeat(9000);
        Object encoded = SAODurableText.pack(unicode);
        check(unicode.equals(SAODurableText.unpack(roundtrip(encoded))), "Unicode native roundtrip changed text");
        fragments(encoded);
        refuses("\uD800", "invalid Unicode accepted");
        KahluaTable changed = packed(text); chunks(changed).rawset(2, null); refuses(changed, "missing chunk accepted");
        changed = packed(text); Object first = chunks(changed).rawget(1); chunks(changed).rawset(1, chunks(changed).rawget(2)); chunks(changed).rawset(2, first);
        refuses(changed, "reordered chunks accepted");
        changed = packed(text); chunks(changed).rawset(1, "A"); refuses(changed, "truncated chunk accepted");
        changed = packed(text); changed.rawset("version", 2.0); refuses(changed, "unsupported version accepted");
        changed = packed(text); changed.rawset("bytes", (double)text.length() + 1); refuses(changed, "false length accepted");
        changed = packed(text); changed.rawset("count", Double.NaN); refuses(changed, "nonfinite count accepted");
        changed = packed(text); chunks(changed).rawset("1", "A"); refuses(changed, "foreign chunk key accepted");
        changed = packed(text); changed.rawset("extra", true); refuses(changed, "foreign envelope field accepted");
        changed = packed(text); KahluaTable oversized = table(); oversized.rawset(1, text); changed.rawset("chunks", oversized); changed.rawset("count", 1.0);
        changed.rawset("sha256", hash(text)); refuses(changed, "oversize chunk accepted");
        System.out.println("PASS bounded UTF-8 durable text, legacy strings, missing/reordered/truncated/version/shape controls");

        SAODurableProbeSink.payload = "v3;" + text; SAODurableProbeSink.visual = "visual;" + unicode;
        DurableBridgeSurface bridge = new DurableBridgeSurface();
        SAOIsoPlayerShell shell = new SAOIsoPlayerShell();
        zombie.characters.SurvivorDesc desc = new zombie.characters.SurvivorDesc(); desc.getHumanVisual().setSkinTextureName("fixture");
        zombie.characters.IsoZombie source = new zombie.characters.IsoZombie(null, desc, 0);
        Object[] captures = {bridge.hibernate(shell), bridge.captureReturnLiving(shell), bridge.captureReturn(source, shell), bridge.captureReturnVisual(shell)};
        for (int i = 0; i < captures.length; i++) {
            check(captures[i] instanceof KahluaTable, "bridge writer bypassed durable packing: " + i);
            check((i == 3 ? SAODurableProbeSink.visual : SAODurableProbeSink.payload).equals(SAODurableText.unpack(roundtrip(captures[i]))), "bridge capture native roundtrip changed");
        }
        for (boolean legacy : new boolean[]{false, true}) {
            Object state = legacy ? SAODurableProbeSink.payload : roundtrip(captures[0]);
            Object visual = legacy ? SAODurableProbeSink.visual : roundtrip(captures[3]);
            check(bridge.validateHibernation(state) && bridge.validateReturnVisual(visual), "bridge reader bypassed durable unpacking");
            check(bridge.restoreReturnLiving(shell, state) && SAODurableProbeSink.payload.equals(SAODurableProbeSink.last), "bridge living restore did not unwrap");
            check(bridge.awaken(shell, state, 0).startsWith("AWAKENED ") && SAODurableProbeSink.payload.equals(SAODurableProbeSink.last), "bridge awaken did not unwrap");
            check(bridge.restoreReturnVisual(shell, visual) && SAODurableProbeSink.visual.equals(SAODurableProbeSink.last), "bridge visual restore did not unwrap");
            check(bridge.returnMaterialsMatch(source, state, visual), "bridge material comparison did not unwrap");
        }
        KahluaTable malformed = packed(text); malformed.rawset("version", 2.0);
        SAODurableProbeSink.restores = 0;
        check(!bridge.validateHibernation(malformed) && !bridge.validateReturnVisual(malformed), "malformed envelope validated");
        check(!bridge.restoreReturnLiving(shell, malformed) && !bridge.restoreReturnVisual(shell, malformed)
            && bridge.awaken(shell, malformed, 0).startsWith("AWAKEN_FAILED")
            && !bridge.returnMaterialsMatch(source, malformed, captures[3]), "malformed envelope reader accepted");
        check(SAODurableProbeSink.restores == 0, "malformed envelope reached native restore");
        SAODurableProbeSink.payload = "legacy-short";
        check(bridge.hibernate(shell) instanceof String, "short bridge capture changed representation");
        System.out.println("PASS actual bridge adapter methods wrap all writers, unwrap all readers and refuse malformed data before restoration");
    }
}
