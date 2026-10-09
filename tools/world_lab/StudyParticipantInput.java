import java.lang.reflect.Method;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.BitSet;

import zombie.core.Core;
import zombie.input.KeyboardState;
import zombie.input.MouseState;
import zombie.ui.UITextEntryInterface;

/**
 * Native-or-leased player input for an explicitly isolated participant JVM.
 *
 * Installed only when {@code -Dstudy.participantInput} is set and
 * {@code study.observer} is false. Session is the sole writer of the lease file
 * ({@code sao.participant-input-lease/1}). This class never writes the lease.
 *
 * Focus uses the installed {@code org.lwjglx.opengl.Display.isActive} API.
 * Missing or failed focus acquisition rejects leased input. Native physical
 * keyboard and mouse values remain unchanged.
 */
public final class StudyParticipantInput {
    public static final String LEASE_SCHEMA = "sao.participant-input-lease/1";

    private static final Object LOCK = new Object();
    private static volatile boolean enabled;
    private static volatile String expectedSession;
    private static volatile Path leasePath;
    private static volatile String lastClearReason;

    private static long acceptedGeneration = -1;
    private static String acceptedLeaseId;
    private static Object acceptedBody;
    private static int acceptedPlayerSqlId;
    private static String acceptedSave;
    private static boolean acceptedCoreSaveKnown;
    private static long acceptedExpiresAtUnixMs;
    private static boolean releasing;
    private static boolean offline;
    private static final BitSet heldKeys = new BitSet();
    private static int mouseX;
    private static int mouseY;
    private static final BitSet heldButtons = new BitSet();
    private static boolean focusProbeMissingLogged;
    private static Boolean focusProbeAvailable;
    private static Method displayIsActive;

    private StudyParticipantInput() {}

    /** Called from StudyLoadingAgent when participant hooks install. */
    public static void enableFromProperties() {
        String flag = System.getProperty("study.participantInput");
        if (flag == null || flag.isBlank() || "false".equalsIgnoreCase(flag.trim())) {
            enabled = false;
            return;
        }
        if (Boolean.getBoolean("study.observer")) {
            throw new IllegalStateException("participant input refuses study.observer");
        }
        String session = System.getProperty("study.participantSession");
        String path = System.getProperty("study.participantLease");
        if (session == null || session.isBlank() || path == null || path.isBlank()) {
            throw new IllegalStateException("participant input requires study.participantSession and study.participantLease");
        }
        expectedSession = session.trim();
        leasePath = Path.of(path);
        if (!leasePath.isAbsolute()) throw new IllegalArgumentException("absolute participant lease path required");
        StudyParticipant.configure();
        acceptedBody = null;
        acceptedPlayerSqlId = -1;
        acceptedSave = null;
        acceptedCoreSaveKnown = false;
        acceptedExpiresAtUnixMs = 0;
        acceptedGeneration = -1;
        acceptedLeaseId = null;
        heldKeys.clear();
        heldButtons.clear();
        releasing = false;
        offline = true;
        enabled = true;
        System.out.println("[StudyParticipant] input hooks armed session=" + expectedSession
            + " lease=" + leasePath);
    }

    public static boolean isEnabled() {
        return enabled;
    }

    public static String lastClearReason() {
        return lastClearReason;
    }

    /**
     * Called at entry to the installed GameKeyboard.update and Mouse.update.
     * One native update acquires one lease snapshot before its scalar queries.
     * Native input remains available while the main menu has no player body.
     */
    public static void beginInputUpdate() {
        refresh();
    }

    /** MemberSubstitution target for KeyboardState.isKeyDown(I) inside GameKeyboard.update. */
    public static boolean isKeyDown(KeyboardState state, int keyCode) {
        boolean nativeDown = state != null && state.isKeyDown(keyCode);
        if (!enabled) return nativeDown;
        synchronized (LOCK) {
            checkCurrentSafety();
            if (releasing || offline || !heldKeys.get(keyCode)) return nativeDown;
            return true;
        }
    }

    /** MemberSubstitution target for MouseState.isButtonDown(I) inside Mouse.update. */
    public static boolean isButtonDown(MouseState state, int button) {
        boolean nativeDown = state != null && state.isButtonDown(button);
        if (!enabled) return nativeDown;
        synchronized (LOCK) {
            checkCurrentSafety();
            if (releasing || offline || !heldButtons.get(button)) return nativeDown;
            return true;
        }
    }

    /** MemberSubstitution target for MouseState.getX() inside Mouse.update. */
    public static int getX(MouseState state) {
        int nativeX = state == null ? 0 : state.getX();
        if (!enabled) return nativeX;
        synchronized (LOCK) {
            checkCurrentSafety();
            if (releasing || offline) return nativeX;
            return mouseX;
        }
    }

    /** MemberSubstitution target for MouseState.getY() inside Mouse.update. */
    public static int getY(MouseState state) {
        int nativeY = state == null ? 0 : state.getY();
        if (!enabled) return nativeY;
        synchronized (LOCK) {
            checkCurrentSafety();
            if (releasing || offline) return nativeY;
            return mouseY;
        }
    }

    private static boolean textEntryBlocksLease() {
        UITextEntryInterface box = Core.currentTextEntryBox;
        return box != null && box.isDoingTextEntry();
    }

    /** No disk, process-liveness or focus probing in per-key/button queries. */
    private static void checkCurrentSafety() {
        if (releasing || offline || acceptedGeneration < 0) return;
        if (textEntryBlocksLease()) { clearLocked("typing"); return; }
        if (acceptedExpiresAtUnixMs <= System.currentTimeMillis()) {
            clearLocked("lease-expired");
            return;
        }
        // These are the current native slot and cheap body fields, rather than
        // the independently published participant-state file or a later frame.
        zombie.characters.IsoPlayer[] players = zombie.characters.IsoPlayer.players;
        zombie.characters.IsoPlayer player = players.length > 0 ? players[0] : null;
        if (player == null || player != acceptedBody) {
            acceptedBody = null;
            clearLocked("native-body-changed");
            return;
        }
        if (player.isDead()) { clearLocked("player-dead"); return; }
        if (player.playerIndex != 0 || player.getPlayerNum() != 0
                || player.sqlId != acceptedPlayerSqlId) {
            clearLocked("player-identity-mismatch");
            return;
        }
        if (player.getCurrentSquare() == null || zombie.iso.IsoWorld.instance == null
                || zombie.iso.IsoWorld.instance.currentCell == null) {
            clearLocked("native-identity-unavailable");
            return;
        }
        String save = Core.gameSaveWorld;
        if ((acceptedCoreSaveKnown && (save == null || save.isBlank()))
                || (save != null && !save.isBlank() && !save.equals(acceptedSave))) {
            clearLocked("save-mismatch");
        }
    }

    private static void refresh() {
        synchronized (LOCK) {
            if (!enabled) return;
            if (releasing) {
                // A cleared update exposes native key-up/button-up edges. A
                // later update requires a newer explicit generation to resume.
                releasing = false;
                offline = true;
                heldKeys.clear();
                heldButtons.clear();
            }
            if (textEntryBlocksLease()) { clearLocked("typing"); return; }
            if (focusLost()) {
                clearLocked("focus-loss");
                return;
            }
            Path path = leasePath;
            if (path == null || !Files.isRegularFile(path)) {
                clearLocked("missing-file");
                return;
            }
            final String raw;
            try {
                if (Files.size(path) > 65536) throw new IllegalArgumentException("lease size");
                raw = Files.readString(path, StandardCharsets.UTF_8);
            } catch (Exception failure) {
                clearLocked("unreadable-file");
                return;
            }
            Lease lease;
            try {
                lease = Lease.parse(raw);
            } catch (IllegalArgumentException failure) {
                clearLocked("unreadable-file");
                return;
            }
            if (!LEASE_SCHEMA.equals(lease.schema)) {
                clearLocked("unreadable-file");
                return;
            }
            if (!expectedSession.equals(lease.sessionId)) {
                clearLocked("session-mismatch");
                return;
            }
            long self = ProcessHandle.current().pid();
            if (lease.pid != self) {
                clearLocked("pid-mismatch");
                return;
            }
            if (lease.holderPid <= 0 || ProcessHandle.of(lease.holderPid).filter(ProcessHandle::isAlive).isEmpty()) {
                clearLocked("holder-pid-dead");
                return;
            }
            var body = StudyParticipant.binding();
            if (body == null || !body.ready()) { clearLocked("native-identity-unavailable"); return; }
            if (!body.alive()) { clearLocked("player-dead"); return; }
            if (lease.attempt != body.attempt()) { clearLocked("attempt-mismatch"); return; }
            if (lease.playerIndex != body.playerIndex() || lease.playerSqlId != body.playerSqlId()) {
                clearLocked("player-identity-mismatch"); return;
            }
            if (acceptedBody != null && body.owner() != acceptedBody) {
                acceptedBody = null; clearLocked("native-body-changed"); return;
            }
            if (!body.save().equals(lease.save)) {
                clearLocked("save-mismatch");
                return;
            }
            if (acceptedLeaseId != null && !acceptedLeaseId.equals(lease.leaseId)) {
                clearLocked("lease-id-changed");
                return;
            }
            if (acceptedGeneration >= 0 && lease.generation < acceptedGeneration) {
                clearLocked("generation-rollback");
                return;
            }
            if (lease.released || lease.expiresAtUnixMs <= System.currentTimeMillis()) {
                acceptedGeneration = Math.max(acceptedGeneration, lease.generation);
                acceptedLeaseId = lease.leaseId;
                clearLocked(lease.released ? "released" : "lease-expired");
                return;
            }
            if (offline && lease.generation <= acceptedGeneration) {
                // Stay off until a newer generation arrives after a clear.
                return;
            }
            acceptedGeneration = lease.generation;
            acceptedLeaseId = lease.leaseId;
            acceptedBody = body.owner();
            acceptedPlayerSqlId = body.playerSqlId();
            acceptedSave = body.save();
            acceptedCoreSaveKnown = Core.gameSaveWorld != null && !Core.gameSaveWorld.isBlank();
            acceptedExpiresAtUnixMs = lease.expiresAtUnixMs;
            offline = false;
            heldKeys.clear();
            for (int key : lease.keys) {
                if (key >= 0) heldKeys.set(key);
            }
            heldButtons.clear();
            for (int button : lease.buttons) {
                if (button >= 0) heldButtons.set(button);
            }
            mouseX = lease.mouseX;
            mouseY = lease.mouseY;
        }
    }

    private static void clearLocked(String reason) {
        if (!heldKeys.isEmpty() || !heldButtons.isEmpty() || !offline && acceptedGeneration >= 0) {
            releasing = true;
        }
        offline = true;
        heldKeys.clear();
        heldButtons.clear();
        if (!reason.equals(lastClearReason)) {
            lastClearReason = reason;
            System.out.println("[StudyParticipant] input-cleared reason=" + reason);
        }
    }

    private static boolean focusLost() {
        Boolean available = focusProbeAvailable;
        if (available == null) {
            available = resolveFocusProbe();
            focusProbeAvailable = available;
        }
        if (!available) return true;
        try {
            Object active = displayIsActive.invoke(null);
            return active instanceof Boolean && !((Boolean) active);
        } catch (ReflectiveOperationException failure) {
            return true;
        }
    }

    private static boolean resolveFocusProbe() {
        try {
            Class<?> display = Class.forName("org.lwjglx.opengl.Display", false, StudyParticipantInput.class.getClassLoader());
            displayIsActive = display.getMethod("isActive");
            if (displayIsActive.getReturnType() != boolean.class) {
                displayIsActive = null;
                logFocusGap("Display.isActive return type differs");
                return false;
            }
            return true;
        } catch (ClassNotFoundException | NoSuchMethodException failure) {
            logFocusGap("Display.isActive not present in this engine extract cohort");
            return false;
        }
    }

    private static void logFocusGap(String detail) {
        if (focusProbeMissingLogged) return;
        focusProbeMissingLogged = true;
        System.out.println("[StudyParticipant] focus-probe unsupported: " + detail
            + "; leased input refused; native physical input preserved");
    }

    /**
     * Prefer Core.GameSaveWorld when present (typical B42 field). Fall back to the
     * basename of ZomboidFileSystem.getCurrentSaveDir when reflection finds it.
     * Returns null when neither binding is available yet (pre-world); lease save
     * matching is skipped until a native save name exists.
     */
    static String nativeSaveName() {
        try {
            var field = Core.class.getField("gameSaveWorld");
            Object value = field.get(null);
            if (value != null) {
                String text = String.valueOf(value).trim();
                if (!text.isEmpty()) return text;
            }
        } catch (ReflectiveOperationException ignored) {
            // Fall through.
        }
        try {
            Class<?> fs = Class.forName("zombie.ZomboidFileSystem");
            Object instance = fs.getField("instance").get(null);
            if (instance == null) return null;
            Object dir = fs.getMethod("getCurrentSaveDir").invoke(instance);
            if (dir == null) return null;
            String text = String.valueOf(dir).trim();
            if (text.isEmpty()) return null;
            int slash = Math.max(text.lastIndexOf('/'), text.lastIndexOf('\\'));
            return slash >= 0 ? text.substring(slash + 1) : text;
        } catch (ReflectiveOperationException ignored) {
            return null;
        }
    }

    /** Minimal JSON reader for the session-owned lease document. */
    static final class Lease {
        final String schema;
        final String sessionId;
        final long pid;
        final long holderPid;
        final int attempt;
        final String save;
        final int playerIndex;
        final int playerSqlId;
        final String leaseId;
        final long generation;
        final long expiresAtUnixMs;
        final boolean released;
        final int[] keys;
        final int mouseX;
        final int mouseY;
        final int[] buttons;

        Lease(String schema, String sessionId, long pid, long holderPid, int attempt, String save,
              int playerIndex, int playerSqlId, String leaseId, long generation, long expiresAtUnixMs,
              boolean released, int[] keys, int mouseX, int mouseY, int[] buttons) {
            this.schema = schema;
            this.sessionId = sessionId;
            this.pid = pid;
            this.holderPid = holderPid;
            this.attempt = attempt;
            this.save = save;
            this.playerIndex = playerIndex;
            this.playerSqlId = playerSqlId;
            this.leaseId = leaseId;
            this.generation = generation;
            this.expiresAtUnixMs = expiresAtUnixMs;
            this.released = released;
            this.keys = keys;
            this.mouseX = mouseX;
            this.mouseY = mouseY;
            this.buttons = buttons;
        }

        private static int boundedInt(long value, int low, int high, String label) {
            if (value < low || value > high) throw new IllegalArgumentException(label + " range");
            return (int) value;
        }
        static Lease parse(String raw) {
            JsonObject root = JsonObject.parse(raw);
            String schema = root.reqString("schema");
            String sessionId = root.reqString("sessionId");
            long pid = root.reqLong("pid");
            long holderPid = root.optLong("holderPid", -1);
            int attempt = boundedInt(root.reqLong("attempt"), 1, Integer.MAX_VALUE, "attempt");
            String save = root.optString("save", "");
            int playerIndex = boundedInt(root.optLong("playerIndex", 0), 0, 0, "playerIndex");
            int playerSqlId = boundedInt(root.reqLong("playerSqlId"), 1, Integer.MAX_VALUE, "playerSqlId");
            String leaseId = root.reqString("leaseId");
            long generation = root.reqLong("generation");
            long expires = root.reqLong("expiresAtUnixMs");
            boolean released = root.optBoolean("released", false);
            int[] keys = root.optIntArray("keys");
            JsonObject mouse = root.optObject("mouse");
            int mx = 0, my = 0;
            int[] buttons = new int[0];
            if (mouse != null) {
                mx = boundedInt(mouse.optLong("x", 0), -100000, 100000, "mouse.x");
                my = boundedInt(mouse.optLong("y", 0), -100000, 100000, "mouse.y");
                buttons = mouse.optIntArray("buttons");
            }
            if (playerIndex != 0) {
                throw new IllegalArgumentException("participant lease player binding differs");
            }
            if (pid <= 0 || pid > Integer.MAX_VALUE || holderPid <= 0 || holderPid > Integer.MAX_VALUE
                    || generation < 0 || generation > 9007199254740991L || expires < 0 || expires > 9007199254740991L
                    || save.isBlank() || save.length() > 180 || leaseId.isBlank() || leaseId.length() > 180)
                throw new IllegalArgumentException("lease identity/range");
            try { if (!java.util.UUID.fromString(sessionId).toString().equals(sessionId)) throw new IllegalArgumentException("session UUID"); }
            catch (IllegalArgumentException failure) { throw new IllegalArgumentException("session UUID", failure); }
            for (int key : keys) if (key < 0 || key >= 10000) throw new IllegalArgumentException("lease keycode");
            for (int button : buttons) if (button < 0 || button >= 32) throw new IllegalArgumentException("lease button");
            if (mouse != null && !java.util.Set.of("x","y","buttons").containsAll(mouse.values.keySet())) throw new IllegalArgumentException("mouse fields");
            return new Lease(schema, sessionId, pid, holderPid, attempt, save, playerIndex, playerSqlId,
                leaseId, generation, expires, released, keys, mx, my, buttons);
        }
    }

    /** Strict bounded lease JSON; duplicate and malformed fields are refused. */
    static final class JsonObject {
        private final java.util.Map<String,Object> values;
        private JsonObject(java.util.Map<String,Object> values) { this.values=values; }
        static JsonObject parse(String text) {
            Reader reader=new Reader(text); Object value=reader.value(0);reader.ws();
            if(reader.i!=text.length()||!(value instanceof JsonObject object))throw new IllegalArgumentException("lease root/trailing data");
            var allowed=java.util.Set.of("schema","sessionId","pid","holderPid","attempt","save","playerIndex","playerSqlId","leaseId","generation","expiresAtUnixMs","released","keys","mouse","releaseReason");
            if(!allowed.containsAll(object.values.keySet()))throw new IllegalArgumentException("unknown lease field");
            return object;
        }
        String reqString(String key) {String value=optString(key,null);if(value==null)throw new IllegalArgumentException("missing "+key);return value;}
        String optString(String key,String fallback) {if(!values.containsKey(key))return fallback;Object value=values.get(key);if(!(value instanceof String result))throw new IllegalArgumentException(key+" must be string");return result;}
        long reqLong(String key) {if(!values.containsKey(key))throw new IllegalArgumentException("missing "+key);return optLong(key,0);}
        long optLong(String key,long fallback) {if(!values.containsKey(key))return fallback;Object value=values.get(key);if(!(value instanceof Long result))throw new IllegalArgumentException(key+" must be integer");return result;}
        boolean optBoolean(String key,boolean fallback) {if(!values.containsKey(key))return fallback;Object value=values.get(key);if(!(value instanceof Boolean result))throw new IllegalArgumentException(key+" must be boolean");return result;}
        JsonObject optObject(String key) {if(!values.containsKey(key))return null;Object value=values.get(key);if(!(value instanceof JsonObject result))throw new IllegalArgumentException(key+" must be object");return result;}
        int[] optIntArray(String key) {
            if(!values.containsKey(key))return new int[0];Object value=values.get(key);
            if(!(value instanceof java.util.List<?> list))throw new IllegalArgumentException(key+" must be array");
            int[] result=new int[list.size()];for(int i=0;i<result.length;i++){Object item=list.get(i);if(!(item instanceof Long n)||n<Integer.MIN_VALUE||n>Integer.MAX_VALUE)throw new IllegalArgumentException(key+" integer range");result[i]=n.intValue();}return result;
        }
        static final class Reader {
            final String text;int i;
            Reader(String text){if(text==null||text.length()>65536)throw new IllegalArgumentException("lease size");this.text=text;}
            void ws(){while(i<text.length()&&" \t\r\n".indexOf(text.charAt(i))>=0)i++;}
            boolean take(char c){ws();if(i<text.length()&&text.charAt(i)==c){i++;return true;}return false;}
            void need(char c){if(!take(c))throw new IllegalArgumentException("expected "+c);}
            Object value(int depth){
                ws();if(depth>4||i>=text.length())throw new IllegalArgumentException("lease nesting/value");char c=text.charAt(i);
                if(c=='"')return string();
                if(c=='{'){
                    i++;var map=new java.util.LinkedHashMap<String,Object>();if(take('}'))return new JsonObject(map);
                    do{ws();if(i>=text.length()||text.charAt(i)!='"')throw new IllegalArgumentException("object key");String key=string();if(map.containsKey(key))throw new IllegalArgumentException("duplicate key");need(':');map.put(key,value(depth+1));}while(take(','));need('}');return new JsonObject(map);
                }
                if(c=='['){i++;var list=new java.util.ArrayList<Object>();if(take(']'))return list;do{list.add(value(depth+1));}while(take(','));need(']');return list;}
                if(text.startsWith("true",i)){i+=4;return Boolean.TRUE;}if(text.startsWith("false",i)){i+=5;return Boolean.FALSE;}if(text.startsWith("null",i)){i+=4;return null;}
                int start=i;if(c=='-')i++;if(i>=text.length()||!Character.isDigit(text.charAt(i)))throw new IllegalArgumentException("integer");
                if(text.charAt(i)=='0')i++;else while(i<text.length()&&text.charAt(i)>='0'&&text.charAt(i)<='9')i++;
                try{return Long.valueOf(text.substring(start,i));}catch(NumberFormatException failure){throw new IllegalArgumentException("integer range",failure);}
            }
            String string(){
                need('"');var result=new StringBuilder();while(i<text.length()){
                    char c=text.charAt(i++);if(c=='"')return result.toString();if(c<32)throw new IllegalArgumentException("string control");
                    if(c!='\\'){result.append(c);continue;}if(i>=text.length())throw new IllegalArgumentException("escape");char e=text.charAt(i++);
                    switch(e){case '"','\\','/'->result.append(e);case 'b'->result.append('\b');case 'f'->result.append('\f');case 'n'->result.append('\n');case 'r'->result.append('\r');case 't'->result.append('\t');case 'u'->{if(i+4>text.length())throw new IllegalArgumentException("unicode");try{result.append((char)Integer.parseInt(text.substring(i,i+4),16));}catch(NumberFormatException failure){throw new IllegalArgumentException("unicode",failure);}i+=4;}default->throw new IllegalArgumentException("escape");}
                }throw new IllegalArgumentException("unterminated string");
            }
        }
    }

}
