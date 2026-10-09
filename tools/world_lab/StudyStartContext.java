import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import se.krka.kahlua.j2se.KahluaTableImpl;
import se.krka.kahlua.vm.KahluaTable;
import zombie.characters.IsoPlayer;

/** Passive, bounded native-thread observation of installed start-flow records.
 * Selection, setup, placement, persistence and companion admission retain their
 * existing owners. A root or pending selection does not establish an applied start.
 */
public final class StudyStartContext {
    public static final String SCHEMA = "sao-native-start-context/1";
    public static final int MAX_STRING_CHARS = 160;
    public static final int MAX_JSON_CHARS = 16000;
    private static final Object UNAVAILABLE = new Object();
    private StudyStartContext() { }

    /** Called alongside the actual native participant binding, on its thread. */
    public static String observe(IsoPlayer player) {
        if (player == null) return unavailable(false);
        try {
            // getModData allocates when absent. Test first, to keep this reader passive.
            return fromModData(player.hasModData() ? player.getModData() : null);
        } catch (RuntimeException | LinkageError failure) {
            return unavailable(true);
        }
    }

    /** Fixed own-key reads never enumerate a table or invoke its Lua metatable. */
    static String fromModData(KahluaTable root) {
        if (root != null && !ownTable(root)) return unavailable(true);
        Object current = raw(root, "WhereIWas");
        String source = "WhereIWas";
        if (current == null || Boolean.FALSE.equals(current)) {
            current = raw(root, "KnoxScenarios");
            source = "KnoxScenarios";
        }
        Record scenario = new Record(current, source);
        scenario.text("scenario", "lifecycleState", "setupFailureReason", "anchorName", "locationName");
        scenario.integer("lifecycleVersion", "kitVersion");
        scenario.flag("setupComplete", "setupFailed", "lifecycleProtected", "placementVerified",
            "failureRestored", "failureRestoreTimedOut", "challengeFailed");
        scenario.number("originX", "originY", "originZ", "startX", "startY", "startZ", "safeX", "safeY", "safeZ");
        scenario.status = scenarioStatus(scenario);

        Record life = new Record(raw(root, "TIYL"), "TIYL");
        life.text("originId", "scriptedStartId", "scriptedPartnerSex", "scriptedStartState",
            "scriptedStartInstanceId", "posterStoryId");
        life.integer("schemaVersion");
        life.flag("outcomesApplied", "originSpawnPending", "originSpawnApplied", "originTraitApplied",
            "serverOriginRegistered", "scriptedPartnerDead", "scriptedPartnerBuried", "scriptedStartComplete");
        life.number("originSpawnX", "originSpawnY", "originSpawnZ");
        life.status = lifeStatus(life);

        Boolean ready = scenarioReady(scenario);
        String result = "{\"schema\":" + quote(SCHEMA) + ",\"observed\":true,\"available\":true"
            + ",\"whereIWas\":" + scenario.json() + ",\"tiyl\":" + life.json()
            + ",\"scenarioReady\":" + ready + "}";
        // Fixed field counts and per-value caps bound work and bytes independently of table size.
        if (result.length() > MAX_JSON_CHARS) return unavailable(true);
        return result;
    }

    private static String unavailable(boolean observed) {
        return "{\"schema\":" + quote(SCHEMA) + ",\"observed\":" + observed
            + ",\"available\":false,\"whereIWas\":" + Record.unknown()
            + ",\"tiyl\":" + Record.unknown() + ",\"scenarioReady\":null}";
    }

    private static String scenarioStatus(Record r) {
        if (!r.readable()) return r.status;
        String state = r.string("lifecycleState");
        if (r.yes("setupFailed") || "failed".equals(state) || "restoring".equals(state)) return "failed";
        if (r.string("scenario") == null || r.string("scenario").isEmpty()) return "unknown";
        if (r.yes("setupComplete") && "ready".equals(state)) return "ready";
        if (r.yes("lifecycleProtected") || r.no("setupComplete")
                || "initialized".equals(state) || "loading".equals(state) || "placed".equals(state)) return "pending";
        return "unknown";
    }

    private static Boolean scenarioReady(Record r) {
        if (!r.readable() || "absent".equals(r.status) || "unknown".equals(r.status)) return null;
        if (!"ready".equals(r.status)) return false;
        if (r.yes("setupFailed") || r.yes("lifecycleProtected")) return false;
        // Legacy records missing an explicit restored protection flag remain unknown.
        if (!r.no("setupFailed") || !r.no("lifecycleProtected")) return null;
        return true;
    }

    private static String lifeStatus(Record r) {
        if (!r.readable()) return r.status;
        if ("failed".equals(r.string("scriptedStartState"))) return "failed";
        if (r.yes("originSpawnPending")) return "pending";
        String origin = r.string("originId");
        if (origin != null && !origin.isEmpty() && r.yes("originSpawnApplied")
                && r.yes("serverOriginRegistered") && r.no("originSpawnPending")) return "ready";
        // SP persistLife does not provide a placement acknowledgement. Do not invent one.
        return "unknown";
    }

    private static String note(Record r) {
        boolean life = "TIYL".equals(r.source);
        if ("absent".equals(r.status)) return "No saved start record is present on this player.";
        if ("invalid".equals(r.status)) return "Some saved fields have invalid types, sizes or text; readiness is unknown.";
        if (r.table == null) return "This player's start record could not be read safely.";
        if (life) {
            if ("failed".equals(r.status)) return "The scripted start records a setup failure.";
            if ("pending".equals(r.status)) return "The recorded origin relocation is pending.";
            if ("ready".equals(r.status)) return "The server acknowledged the recorded origin placement.";
            return "Saved origin or story fields are present; an applied placement is not recorded.";
        }
        if ("failed".equals(r.status)) return "Scenario setup failed or is restoring the ordinary start.";
        if ("pending".equals(r.status)) return "Scenario setup is underway.";
        if ("ready".equals(r.status)) {
            Boolean ready = scenarioReady(r);
            if (Boolean.TRUE.equals(ready)) return "Scenario setup records completion and released its temporary protection.";
            if (Boolean.FALSE.equals(ready)) return "Scenario setup records completion, but temporary protection is still active.";
            return "Scenario setup records completion; protection release has not been recorded.";
        }
        return "Saved scenario fields are present; setup readiness is unknown.";
    }

    private static Object raw(KahluaTable table, String key) {
        if (table == null) return null;
        try {
            if (!ownTable(table)) return UNAVAILABLE;
            // Installed rawget falls through to metatable and debugger callbacks.
            // The actual J2SEPlatform table owns a plain LinkedHashMap instead.
            return ((KahluaTableImpl)table).delegate.get(key);
        }
        catch (RuntimeException | LinkageError failure) { return UNAVAILABLE; }
    }

    private static boolean ownTable(KahluaTable table) {
        if (!(table instanceof KahluaTableImpl nativeTable) || nativeTable.getRewriteTable() != null) return false;
        Map<Object,Object> map = nativeTable.delegate;
        return map != null && (map.getClass() == LinkedHashMap.class || map.getClass() == HashMap.class);
    }

    private static Double numeric(Object value) {
        // Lua numbers are Double. Accept final Java primitive wrappers, never an arbitrary Number callback.
        if (!(value instanceof Double || value instanceof Float || value instanceof Integer
                || value instanceof Long || value instanceof Short || value instanceof Byte)) return null;
        double d = ((Number)value).doubleValue();
        return Double.isFinite(d) && Math.abs(d) <= 1_000_000_000 ? d : null;
    }

    /** Text must cross UTF-8 and Mousecat without changing the native value. */
    private static boolean protocolText(String value) {
        if (value.length() > MAX_STRING_CHARS) return false;
        for (int i = 0; i < value.length(); i++) {
            char c = value.charAt(i);
            if (Character.isHighSurrogate(c)) {
                if (i + 1 >= value.length() || !Character.isLowSurrogate(value.charAt(i + 1))) return false;
                i++;
            } else if (Character.isLowSurrogate(c)) return false;
            else if (c < 0x20 && c != '\t' && c != '\n' && c != '\r') return false;
        }
        return true;
    }

    private static final class Record {
        final String source;
        final KahluaTable table;
        final Map<String, Object> values = new LinkedHashMap<>();
        final List<String> invalid = new ArrayList<>();
        String status;
        Record(Object raw, String candidateSource) {
            source = raw == null || raw == UNAVAILABLE || Boolean.FALSE.equals(raw) ? null : candidateSource;
            table = raw instanceof KahluaTable t && ownTable(t) ? t : null;
            status = raw == null || Boolean.FALSE.equals(raw) ? "absent"
                : raw == UNAVAILABLE || raw instanceof KahluaTable && table == null ? "unknown"
                : table == null ? "invalid" : "unknown";
            if (table == null && "invalid".equals(status)) invalid.add("$root");
        }
        void text(String... fields) { read(0, fields); }
        void integer(String... fields) { read(1, fields); }
        void flag(String... fields) { read(2, fields); }
        void number(String... fields) { read(3, fields); }
        void read(int kind, String... fields) {
            if (table == null) return;
            for (String key : fields) {
                Object value = raw(table, key);
                if (value == null) continue;
                boolean good;
                if (kind == 0) good = value instanceof String s && protocolText(s);
                else if (kind == 2) good = value instanceof Boolean;
                else {
                    Double d = numeric(value);
                    good = d != null && (kind == 3 || d >= 0 && d <= 100000 && d == Math.rint(d));
                    if (good) {
                        if (kind == 1) value = Integer.valueOf(d.intValue());
                        else value = d;
                    }
                }
                if (good) values.put(key, value);
                else { invalid.add(key); status = "invalid"; }
            }
        }
        boolean readable() { return table != null && invalid.isEmpty(); }
        boolean yes(String key) { return Boolean.TRUE.equals(values.get(key)); }
        boolean no(String key) { return Boolean.FALSE.equals(values.get(key)); }
        String string(String key) { return values.get(key) instanceof String s ? s : null; }
        static String unknown() {
            return "{\"sourceKey\":null,\"status\":\"unknown\",\"values\":{},\"invalidFields\":[]"
                + ",\"note\":\"This player's start record could not be read safely.\"}";
        }
        String json() {
            StringBuilder b = new StringBuilder("{\"sourceKey\":").append(quote(source))
                .append(",\"status\":").append(quote(status)).append(",\"values\":{");
            boolean first = true;
            for (Map.Entry<String,Object> entry : values.entrySet()) {
                if (!first) b.append(','); first = false;
                b.append(quote(entry.getKey())).append(':');
                Object value = entry.getValue();
                b.append(value instanceof String s ? quote(s) : value);
            }
            b.append("},\"invalidFields\":["); first = true;
            for (String field : invalid) {
                if (!first) b.append(','); first = false;
                b.append(quote(field));
            }
            return b.append("],\"note\":").append(quote(note(this))).append('}').toString();
        }
    }

    private static String quote(String value) {
        if (value == null) return "null";
        StringBuilder result = new StringBuilder("\"");
        for (int i = 0; i < value.length(); i++) {
            char c = value.charAt(i);
            if (c == '"' || c == '\\') result.append('\\').append(c);
            else if (c < 0x20 || Character.isSurrogate(c)) {
                result.append("\\u");
                for (int shift = 12; shift >= 0; shift -= 4) result.append("0123456789abcdef".charAt((c >> shift) & 15));
            } else result.append(c);
        }
        return result.append('"').toString();
    }
}
