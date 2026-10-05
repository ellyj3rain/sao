import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.file.AccessDeniedException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.lang.reflect.Field;
import java.util.Arrays;
import java.util.Collection;
import java.util.Iterator;
import java.util.Properties;
import java.util.Set;
import java.util.Spliterator;
import java.util.concurrent.atomic.AtomicLong;
import java.util.function.Consumer;
import java.util.function.IntFunction;
import java.util.function.Predicate;
import java.util.stream.Stream;
import zombie.GameTime;
import zombie.GameWindow;
import zombie.characters.IsoGameCharacter;
import zombie.characters.IsoPlayer;
import zombie.characters.SurvivorDesc;
import zombie.core.Core;
import zombie.core.opengl.Shader;
import zombie.core.physics.WorldSimulation;
import zombie.core.textures.ColorInfo;
import zombie.core.textures.MultiTextureFBO2;
import zombie.iso.IsoCamera;
import zombie.iso.IsoCell;
import zombie.iso.IsoChunkMap;
import zombie.iso.IsoGridSquare;
import zombie.iso.IsoMovingObject;
import zombie.iso.IsoWorld;
import zombie.iso.LightingJNI;
import zombie.ui.SpeedControls;
import zombie.ui.UIManager;
import zombie.ui.UIElementInterface;
import zombie.Lua.LuaManager;
import se.krka.kahlua.vm.KahluaTable;

/** Study-JVM host infrastructure, excluded from the world's actor collections.
 * The native player slot supplies rendering/streaming infrastructure only. The
 * separate camera supplies view coordinates, and neither object is updated as
 * a character. See StudyLoadingAgent for the narrowly scoped native adapters.
 */
public final class StudyObserver {
    public static final String MARKER = "SAO_ObserverAnchor";
    private static final Set<String> CONTROL_KEYS = Set.of("sequence", "viewX", "viewY", "viewZ",
        "residencyX", "residencyY", "residencyZ", "paused", "speed", "stop",
        "selectedPersonId", "panelId", "panelPersonId", "panelVisible", "zoomStep", "siteId", "opponentShare", "opportunitiesPerHour", "maxDepth");
    private static Anchor anchor;
    private static View camera;
    private static Anchor[] extraAnchors = new Anchor[0];
    private static View[] extraCameras = new View[0];
    private static String[] siteIds = { "main" }, siteLabels = { "Main view" };
    private static float[][] siteOrigins;
    private static IsoCell cell;
    private static Path controlFile, stateFile;
    private static float originX, originY, originZ, minX, minY, maxX, maxY;
    private static volatile long sequence;
    private static long rejectedSequence = -1, nextPoll, nextState, logicCalls;
    private static long suppressedBirths, suppressedSaves, suppressedUpdates;
    private static long streamingChecks;
    private static long retainedResidencies;
    private static final AtomicLong blockedAdmissions = new AtomicLong();
    private static double startHours;
    private static int desiredSpeed = 1;
    private static boolean stopping, stopIssued, statePublicationFailed, contextFailed;
    private static Boolean previousSlowLuaCallbacks;
    private static long exportDrainStarted;
    private static boolean exportDrainFailed;
    private static final int MAX_STATE_DEFERRALS = 30;
    private static int stateDeferrals;
    private static volatile boolean initializing, ready;
    private static String error;
    private static String selectedPersonId, inspectionError;
    private static UIElementInterface inspectionPanel;
    private static volatile String runtimeFailure;
    private static volatile String lastSnapshot = "{\"schema\":\"sao-study-observer/1\",\"status\":\"starting\",\"sequence\":0}";

    private StudyObserver() { }

    public static boolean threatReady(double x, double y, double z) {
        requireGameThread();
        if (!hostOnly() || cell != IsoWorld.instance.currentCell)
            throw new IllegalStateException("initial threat requires the owned native study world");
        if (!Double.isFinite(x) || x != Math.rint(x) || !Double.isFinite(y) || y != Math.rint(y)
                || !Double.isFinite(z) || z != Math.rint(z))
            throw new IllegalArgumentException("invalid native threat placement");
        bounded((float) x, (float) y, (float) z);
        return cell.getGridSquare((int) x, (int) y, (int) z) != null;
    }

    /** The native constructor owns stats, actor admission, events and identity.
     * The study supplies one initial placement and never a pursuit target.
     */
    public static KahluaTable seedThreat(double x, double y, double z, double count) {
        requireGameThread();
        if (!hostOnly() || cell != IsoWorld.instance.currentCell)
            throw new IllegalStateException("initial threat requires the owned native study world");
        if (!Double.isFinite(x) || x != Math.rint(x) || !Double.isFinite(y) || y != Math.rint(y)
                || !Double.isFinite(z) || z != Math.rint(z) || !Double.isFinite(count)
                || count != Math.rint(count) || count < 1 || count > 32)
            throw new IllegalArgumentException("invalid native threat placement");
        bounded((float) x, (float) y, (float) z);
        KahluaTable receipt = LuaManager.platform.newTable(), actors = LuaManager.platform.newTable();
        receipt.rawset("owner", "native-VirtualZombieManager"); receipt.rawset("actors", actors);
        receipt.rawset("requested", count); receipt.rawset("created", 0.0);
        var square = cell.getGridSquare((int) x, (int) y, (int) z);
        if (IsoWorld.getZombiesDisabled() || square == null || !square.isFree(false)) {
            receipt.rawset("status", "refused");
            receipt.rawset("reason", IsoWorld.getZombiesDisabled() ? "native-zombies-disabled" : square == null
                ? "native-square-unavailable" : "native-square-blocked");
            return receipt;
        }
        var manager = zombie.VirtualZombieManager.instance;
        var previous = new java.util.ArrayList<>(manager.choices);
        int created = 0;
        try {
            for (int index = 0; index < (int) count; index++) {
                manager.choices.clear(); manager.choices.add(square);
                var actor = manager.createRealZombieAlways(zombie.iso.IsoDirections.getRandom(), false);
                if (actor == null) break;
                KahluaTable row = LuaManager.platform.newTable();
                row.rawset("persistentId", (double) actor.persistentId);
                row.rawset("x", (double) actor.getX()); row.rawset("y", (double) actor.getY()); row.rawset("z", (double) actor.getZ());
                row.rawset("nativeMember", cell.getZombieList().contains(actor) && cell.getObjectList().contains(actor));
                row.rawset("targetAssigned", actor.target != null);
                actors.rawset((double) ++created, row);
            }
        } finally {
            manager.choices.clear(); manager.choices.addAll(previous);
        }
        receipt.rawset("created", (double) created);
        receipt.rawset("status", created == count ? "created" : created == 0 ? "refused" : "partial");
        if (created < count) receipt.rawset("reason", "native-creation-refused");
        return receipt;
    }

    /** This is a class identity test during construction, before ModData exists. */
    public static boolean isObserver(Object value) {
        return value instanceof Anchor || value instanceof View;
    }

    /** Native far-region streaming republishes its slot player into addList. */
    public static boolean admitChunkActor(Set<Object> actors, Object value) {
        return !isObserver(value) && actors.add(value);
    }

    /** IsoCell.updateInternal skips chunk delivery for dead slot players. This
     * one infrastructure call must admit the host while AI/targeting still sees
     * the observer's native dead/ineligible sentinel everywhere else.
     */
    public static boolean deadForStreaming(IsoGameCharacter value) {
        if (!isObserver(value)) return value.isDead();
        streamingChecks++;
        return false;
    }

    /** Bind the actual installed cell owners before either observer exists.
     * IsoCell stores all three as private final Set fields, assigned only in its
     * constructor. Keep the existing sets/content and native iteration behavior;
     * reject our infrastructure references before any caller can publish them.
     */
    public static void installCellAdmission(IsoCell owner) {
        try {
            for (String name : new String[] {"objectList", "addList", "removeList"}) {
                Field field = IsoCell.class.getDeclaredField(name);
                if (field.getType() != Set.class) throw new IllegalStateException("native actor owner type changed: " + name);
                field.setAccessible(true);
                @SuppressWarnings("unchecked") Set<Object> original = (Set<Object>) field.get(owner);
                if (original instanceof ActorSet) continue;
                if (original.stream().anyMatch(StudyObserver::isObserver))
                    throw new IllegalStateException("observer was already published before admission binding");
                ActorSet guarded = new ActorSet(original, name);
                field.set(owner, guarded);
                if (field.get(owner) != guarded) throw new IllegalStateException("native actor owner binding failed: " + name);
            }
        } catch (ReflectiveOperationException failure) {
            throw new IllegalStateException("cannot bind installed native actor owners", failure);
        }
    }

    private static final class ActorSet implements Set<Object> {
        private final Set<Object> delegate;
        private final String owner;
        private boolean reported;
        private ActorSet(Set<Object> delegate, String owner) { this.delegate = delegate; this.owner = owner; }
        @Override public boolean add(Object value) {
            if (!isObserver(value)) return delegate.add(value);
            blockedAdmissions.incrementAndGet();
            if (!reported) {
                reported = true;
                String caller = StackWalker.getInstance().walk(frames -> frames.skip(1).limit(8)
                    .map(Object::toString).collect(java.util.stream.Collectors.joining(" <- ")));
                System.out.println("[StudyObserver] blocked actor admission owner=" + owner
                    + " identity=" + Integer.toHexString(System.identityHashCode(value))
                    + " type=" + value.getClass().getName() + " caller=" + caller);
            }
            return false;
        }
        @Override public boolean addAll(Collection<?> values) {
            boolean changed = false;
            for (Object value : values) changed |= add(value);
            return changed;
        }
        @Override public int size() { return delegate.size(); }
        @Override public boolean isEmpty() { return delegate.isEmpty(); }
        @Override public boolean contains(Object value) { return delegate.contains(value); }
        @Override public Iterator<Object> iterator() { return delegate.iterator(); }
        @Override public Object[] toArray() { return delegate.toArray(); }
        @Override public <T> T[] toArray(T[] target) { return delegate.toArray(target); }
        @Override public <T> T[] toArray(IntFunction<T[]> generator) { return delegate.toArray(generator); }
        @Override public boolean remove(Object value) { return delegate.remove(value); }
        @Override public boolean containsAll(Collection<?> values) { return delegate.containsAll(values); }
        @Override public boolean retainAll(Collection<?> values) { return delegate.retainAll(values); }
        @Override public boolean removeAll(Collection<?> values) { return delegate.removeAll(values); }
        @Override public void clear() { delegate.clear(); }
        @Override public boolean equals(Object other) { return delegate.equals(other); }
        @Override public int hashCode() { return delegate.hashCode(); }
        @Override public String toString() { return delegate.toString(); }
        @Override public void forEach(Consumer<? super Object> action) { delegate.forEach(action); }
        @Override public boolean removeIf(Predicate<? super Object> predicate) { return delegate.removeIf(predicate); }
        @Override public Spliterator<Object> spliterator() { return delegate.spliterator(); }
        @Override public Stream<Object> stream() { return delegate.stream(); }
        @Override public Stream<Object> parallelStream() { return delegate.parallelStream(); }
    }

    public static boolean suppressBirth(String event, Object value) {
        if ("OnCreateLivingCharacter".equals(event) && isObserver(value)) {
            suppressedBirths++;
            return true;
        }
        return false;
    }

    public static boolean suppressSave(Object value) {
        if (!isObserver(value)) return false;
        suppressedSaves++;
        System.out.println("[StudyObserver] suppressed player save identity="
            + Integer.toHexString(System.identityHashCode(value)));
        return true;
    }

    /** The host sentinel is ineligible for native targeting/alive-player scans.
     * Its body is never killed: health, death events and corpse creation are not
     * used. Native allPlayersDead's speed-1 fallback is a separate host concern.
     */
    public static boolean hostOnly() {
        return ready && ownsSlots();
    }

    private static boolean ownsSlots() {
        if (anchor == null || IsoPlayer.players[0] != anchor) return false;
        for (int i = 1; i < IsoPlayer.players.length; i++)
            if (IsoPlayer.players[i] != (i <= extraAnchors.length ? extraAnchors[i - 1] : null)) return false;
        return true;
    }

    public static boolean hideNativeUi() { return initializing || hostOnly(); }

    /** Called between installed Core.StartFrameUI and EndFrameUI. Only the
     * explicit inspector is drawn. Blend/style setup follows UIManager.render;
     * avatar UI, Lua draw events and player overlays remain suppressed.
     */
    public static boolean renderObserverUi() {
        if (!hideNativeUi()) return false;
        if (!ready || inspectionPanel == null || !Boolean.TRUE.equals(inspectionPanel.isVisible())
            || UIManager.suspend || (UIManager.useUiFbo && !Core.getInstance().uiRenderThisFrame)) return true;
        try {
            requireGameThread();
            Field stencil = zombie.ui.UIElement.class.getDeclaredField("stencilLevel");
            stencil.setAccessible(true); stencil.setInt(null, 0);
            zombie.IndieGL.enableBlend();
            if (UIManager.useUiFbo) {
                zombie.core.SpriteRenderer.instance.setDefaultStyle(zombie.core.Styles.UIFBOStyle.instance);
                zombie.IndieGL.glBlendFuncSeparate(770, 771, 1, 771);
            } else zombie.IndieGL.glBlendFunc(770, 771);
            zombie.IndieGL.disableDepthTest();
            inspectionPanel.render();
        } catch (Exception failure) {
            String message = failure.getClass().getSimpleName() + ": " + failure.getMessage();
            if (!message.equals(inspectionError)) System.err.println("[StudyObserver] inspector render failed: " + message);
            inspectionError = message;
        } finally {
            if (UIManager.useUiFbo) {
                zombie.core.SpriteRenderer.instance.setDefaultStyle(zombie.core.Styles.TransparentStyle.instance);
                zombie.IndieGL.glBlendFunc(770, 771);
            }
        }
        return true;
    }

    private static Object observationCall(String name, Object... arguments) {
        Object root = LuaManager.env == null ? null : LuaManager.env.rawget("SAO");
        Object module = root instanceof KahluaTable ? ((KahluaTable) root).rawget("Observation") : null;
        Object function = module instanceof KahluaTable ? ((KahluaTable) module).rawget(name) : null;
        if (function == null || LuaManager.thread == null || LuaManager.caller == null)
            throw new IllegalStateException("person inspection is not ready");
        Object[] result = LuaManager.caller.pcall(LuaManager.thread, function, arguments);
        if (result.length < 1 || !Boolean.TRUE.equals(result[0]))
            throw new IllegalStateException("person inspection failed: " + (result.length > 1 ? result[1] : "missing Lua return"));
        return result.length > 1 ? result[1] : null;
    }

    private static String person(Properties values, String key) {
        String id = values.getProperty(key);
        if (id == null || id.isEmpty() || id.length() > 128
            || id.chars().anyMatch(c -> c < 32 || c == 127))
            throw new IllegalArgumentException("invalid " + key);
        if (!Boolean.TRUE.equals(observationCall("validatePerson", id)))
            throw new IllegalArgumentException("person is unavailable: " + id);
        return id;
    }

    /** A hidden debugger would block the very game thread that polls stop.
     * Keep the original Lua error/log and permanently fail the observer receipt;
     * skip only the interactive debugger loop, not the failed Lua operation.
     */
    public static boolean suppressDebugger(String source, long line) {
        if (!hideNativeUi()) return false;
        String where = source == null ? "unknown" : source.replace('\n', ' ').replace('\r', ' ');
        if (where.length() > 512) where = where.substring(0, 512);
        String failure = "native Lua debugger requested at " + where + ":" + line;
        if (runtimeFailure == null) {
            runtimeFailure = failure;
            System.err.println("[StudyObserver] FAILED " + failure + "; interactive debugger skipped");
        }
        return true;
    }

    /** ItemPickerJava also reads the global player internally; null selects its
     * native container-location fallback and avoids observer traits/position.
     */
    public static IsoPlayer participantInstance() {
        IsoPlayer value = IsoPlayer.getInstance();
        return isObserver(value) ? null : value;
    }

    public static boolean beginWorld() {
        if (zombie.network.GameClient.client || zombie.network.GameServer.server)
            throw new IllegalStateException("study observer requires the isolated single-player host");
        if (anchor != null) throw new IllegalStateException("study observer already owns a world");
        originX = property("study.originX"); originY = property("study.originY"); originZ = property("study.originZ");
        minX = property("study.minX"); minY = property("study.minY");
        maxX = property("study.maxX"); maxY = property("study.maxY");
        if (maxX <= minX || maxY <= minY) throw new IllegalArgumentException("invalid study extent");
        bounded(originX, originY, originZ);
        int count = Integer.parseInt(System.getProperty("study.siteCount", "1"));
        if (count < 1 || count > 4) throw new IllegalArgumentException("native observation site count outside 1..4");
        siteOrigins = new float[count][3]; siteIds = new String[count]; siteLabels = new String[count];
        Set<String> ids = new java.util.HashSet<>(), locations = new java.util.HashSet<>();
        for (int index = 0; index < count; index++) {
            String prefix = "study.site." + index + ".";
            siteIds[index] = System.getProperty(prefix + "id", index == 0 ? "main" : "site-" + index);
            siteLabels[index] = System.getProperty(prefix + "label", index == 0 ? "Main view" : "Site " + index);
            if (!siteIds[index].matches("[a-z][a-z0-9-]{0,47}") || !ids.add(siteIds[index])
                    || siteLabels[index].isEmpty() || siteLabels[index].length() > 160
                    || siteLabels[index].chars().anyMatch(value -> value < 32 || value >= 127))
                throw new IllegalArgumentException("invalid native observation site identity");
            siteOrigins[index][0] = Float.parseFloat(System.getProperty(prefix + "x", Float.toString(originX)));
            siteOrigins[index][1] = Float.parseFloat(System.getProperty(prefix + "y", Float.toString(originY)));
            siteOrigins[index][2] = Float.parseFloat(System.getProperty(prefix + "z", Float.toString(originZ)));
            bounded(siteOrigins[index][0], siteOrigins[index][1], siteOrigins[index][2]);
            if (!locations.add(Arrays.toString(siteOrigins[index])))
                throw new IllegalArgumentException("native observation sites share a position");
        }
        controlFile = absoluteProperty("study.observerControl");
        stateFile = absoluteProperty("study.observerState");
        if (controlFile != null && controlFile.equals(stateFile))
            throw new IllegalArgumentException("observer control and state paths must differ");
        boolean previous = zombie.SystemDisabler.doPlayerCreation;
        initializing = true;
        zombie.SystemDisabler.doPlayerCreation = false;
        return previous;
    }

    public static void endWorld(boolean previous, Throwable failure) {
        zombie.SystemDisabler.doPlayerCreation = previous;
        if (failure != null) { initializing = false; return; }
        cell = IsoWorld.instance.currentCell;
        if (cell == null) throw new IllegalStateException("native world initialization produced no cell");
        installCellAdmission(cell);
        for (IsoPlayer value : IsoPlayer.players)
            if (value != null) throw new IllegalStateException("native startup created a participating player");
        // IsoWorld.init places these world initializers inside its player branch.
        // WorldSimulation.create has its own idempotence guard. Poison values are
        // restored by normal save loading and must not be rerolled on reopen.
        WorldSimulation.instance.create();
        if (Core.getInstance().getPoisonousBerry() == null) Core.getInstance().initPoisonousBerry();
        if (Core.getInstance().getPoisonousMushroom() == null) Core.getInstance().initPoisonousMushroom();
        anchor = new Anchor();
        camera = new View();
        position(anchor, originX, originY, originZ);
        position(camera, originX, originY, originZ);
        anchor.playerIndex = 0;
        anchor.serverPlayerIndex = -1;
        anchor.setOnlineID((short) -1);
        anchor.sqlId = -1;
        extraAnchors = new Anchor[siteOrigins.length - 1];
        extraCameras = new View[extraAnchors.length];
        for (int index = 1; index < siteOrigins.length; index++) {
            Anchor resident = new Anchor(); View view = new View();
            position(resident, siteOrigins[index][0], siteOrigins[index][1], siteOrigins[index][2]);
            position(view, siteOrigins[index][0], siteOrigins[index][1], siteOrigins[index][2]);
            resident.playerIndex = index; resident.serverPlayerIndex = -1;
            resident.setOnlineID((short) -1); resident.sqlId = -1;
            extraAnchors[index - 1] = resident; extraCameras[index - 1] = view;
            IsoPlayer.players[index] = resident;
            initializeRegion(cell, index, resident.getX(), resident.getY());
        }
        IsoPlayer.numPlayers = siteOrigins.length;
        IsoPlayer.players[0] = anchor;
        IsoPlayer.setInstance(anchor);
        IsoCamera.setCameraCharacter(camera);
        configureGodView();
        startHours = GameTime.getInstance().getWorldAgeHours();
        publish(true);
        // IsoWorld.init runs on the loading thread while GameWindow.logic runs
        // on the game thread. Publish one complete host, never anchor alone.
        ready = true;
        initializing = false;
        System.out.println("[StudyObserver] installed detached=" + detached()
            + " origin=" + originX + "," + originY + "," + originZ
            + " identity=" + Integer.toHexString(System.identityHashCode(anchor))
            + " suppressedBirths=" + suppressedBirths + " hours=" + startHours);
    }

    /** Native AddCoopPlayer establishes full-grid references before deliveries
     * can reach a secondary map. A map enabled without these references can
     * hold shared chunks that another map is allowed to unload and recycle.
     */
    public static void initializeRegion(IsoCell owner, int slot, float x, float y) {
        IsoChunkMap.bSettingChunk.lock();
        try {
            IsoChunkMap map = owner.getChunkMap(slot);
            map.Unload();
            map.ignore = false;
            map.worldX = (int) Math.floor(x / IsoChunkMap.CHUNK_SIZE_IN_SQUARES);
            map.worldY = (int) Math.floor(y / IsoChunkMap.CHUNK_SIZE_IN_SQUARES);
            prepareRegionLighting(map);
            WorldSimulation.instance.activateChunkMap(slot);
            loadRegion(owner, map);
        } finally {
            IsoChunkMap.bSettingChunk.unlock();
        }
    }

    public static void prepareRegionLighting(IsoChunkMap map) {
        // The DLL can be initialized before this slot's first ordinary
        // lighting update creates its native state. Teleport requires it.
        int slot = map.playerId;
        if (LightingJNI.init && LightingJNI.getUpdateCounter(slot) >= 0) LightingJNI.teleport(slot,
            map.worldX - IsoChunkMap.chunkGridWidth / 2,
            map.worldY - IsoChunkMap.chunkGridWidth / 2);
    }

    public static void loadRegion(IsoCell owner, IsoChunkMap map) {
        int half = IsoChunkMap.chunkGridWidth / 2;
        int left = map.worldX - half, top = map.worldY - half;
        for (int x = left; x <= map.worldX + half; x++) {
            for (int y = top; y <= map.worldY + half; y++) {
                if (!IsoWorld.instance.getMetaGrid().isValidChunk(x, y)) continue;
                var chunk = map.LoadChunkForLater(x, y, x - left, y - top);
                if (chunk != null && chunk.loaded) owner.setCacheChunk(chunk, map.playerId);
            }
        }
        map.SwapChunkBuffers();
    }

    /** Native logic executes this while UI speed is zero as well as while running. */
    public static void poll() {
        if (!ready || GameWindow.closeRequested) return;
        requireGameThread();
        StudyExport.bind();
        beginCallbackTiming();
        if (!contextFailed) {
            String failure = contextFailure();
            if (failure != null) failContext(failure);
        }
        if (contextFailed) {
            long now = System.currentTimeMillis();
            if (now >= nextState) {
                nextState = now + 100;
                if (writeState() || statePublicationFailed) finishStop();
            }
            return;
        }
        logicCalls++;
        refreshSquare(anchor);
        refreshSquare(camera);
        for (int index = 0; index < extraAnchors.length; index++) {
            refreshSquare(extraAnchors[index]); refreshSquare(extraCameras[index]);
        }
        long now = System.currentTimeMillis();
        if (stopping) {
            if (now >= nextState) {
                nextState = now + 100;
                boolean published = publish(false);
                if (published || statePublicationFailed) finishStop();
            }
            return;
        }
        if (now >= nextPoll) {
            nextPoll = now + 100;
            readControl();
        }
        if (now >= nextState) {
            nextState = now + 1000;
            publish(false);
        }
    }

    private static String contextFailure() {
        if (cell != IsoWorld.instance.currentCell) return "native world replaced the owned observer cell";
        if (!ownsSlots() || IsoPlayer.numPlayers != siteIds.length)
            return "native observer player slots/count changed: count=" + IsoPlayer.numPlayers;
        for (int index = 0; index < siteIds.length; index++) {
            IsoChunkMap map = cell.getChunkMap(index);
            if (map == null || map.ignore || map.playerId != index)
                return "native observer chunk map unavailable: slot=" + index + " site=" + siteIds[index]
                    + " map=" + (map == null ? "null" : "playerId=" + map.playerId + " ignore=" + map.ignore);
        }
        return null;
    }

    /** Preserve the original streaming exception before native update resets its
     * world. Do not replace a missing map or suppress the failed native call. */
    public static void streamingFailure(Object nativeMap, Object actor, Throwable failure) {
        if (!ready || !isObserver(actor) || failure == null) return;
        IsoChunkMap map = (IsoChunkMap) nativeMap;
        IsoGameCharacter character = (IsoGameCharacter) actor;
        failContext("native observer streaming failed: slot=" + map.playerId + " map=" + map.worldX + "," + map.worldY
            + " residency=" + character.getX() + "," + character.getY() + "," + character.getZ()
            + " cause=" + failure.getClass().getSimpleName() + ": " + failure.getMessage());
        writeState();
    }

    private static void failContext(String message) {
        if (contextFailed) return;
        contextFailed = true;
        runtimeFailure = message.length() > 1024 ? message.substring(0, 1024) : message;
        // Retain the last verified world clock, geometry and ownership witness.
        // Refreshing those fields against an already disposed cell would lie or
        // throw repeatedly. Only the failure status/publication time changes.
        refreshFailureSnapshot();
        nextState = 0;
        System.err.println("[StudyObserver] FAILED " + runtimeFailure);
    }

    private static void refreshFailureSnapshot() {
        lastSnapshot = lastSnapshot.replaceFirst("\"status\":\"[^\"]*\"", "\"status\":\"failed\"")
            .replaceFirst("\"updatedAtUnixMs\":[0-9]+", "\"updatedAtUnixMs\":" + System.currentTimeMillis())
            .replaceFirst("\"failure\":(?:null|\"(?:[^\"\\\\]|\\\\.)*\")",
                java.util.regex.Matcher.quoteReplacement("\"failure\":" + quote(runtimeFailure)));
    }

    public static Object cameraFor(Object requested) {
        if (ready) for (int index = 0; index < extraAnchors.length; index++)
            if (requested == extraAnchors[index]) return extraCameras[index];
        return ready && requested == anchor ? camera : requested;
    }

    public static Object residencyFor(Object requested) {
        if (ready) for (int index = 0; index < extraCameras.length; index++)
            if (requested == extraCameras[index]) return extraAnchors[index];
        return ready && requested == camera ? anchor : requested;
    }

    /** Installed filming/render options, confined to this single-owner study
     * JVM. Geometry/materials remain native; terrain/model display is fullbright,
     * without a camera LOS mask. Native per-object cutaway/fading remains active.
     * Native lighting and actor perception
     * receive no substituted inputs, including when the camera moves.
     */
    public static boolean configureGodView() {
        if (!ownsSlots()) return false;
        if (!Core.debug) throw new IllegalStateException("native God-view requires the isolated debug launch");
        // Core.loadOptions resets its persisted uncapped flag to 60 FPS.
        // Apply the native UI's uncapped selection after that startup reset.
        Core.getInstance().setFramerate(1);
        System.out.println("[StudyObserver] renderer uncapped="
            + zombie.core.PerformanceSettings.instance.isFramerateUncapped());
        var options = zombie.debug.DebugOptions.instance;
        options.fboRenderChunk.nolighting.setValue(true);
        options.fboRenderChunk.renderVisionPolygon.setValue(false);
        options.terrain.renderTiles.forceFullAlpha.setValue(false);
        return true;
    }

    /** Select the installed tree renderer's cutaway for this study viewport.
     * Native jumbo sprites retain their separate trunk; single-texture trees
     * have no separate trunk and their complete display texture is cut away.
     * The tree object, its square, damage and simulation flags are unchanged.
     */
    public static boolean cutawayCanopy(int playerIndex) {
        return playerIndex >= 0 && playerIndex <= extraAnchors.length && hostOnly()
            && zombie.core.PerformanceSettings.fboRenderChunk;
    }

    public static boolean hideCharacterPreview(Object widget, Object character) {
        if (!isObserver(character)) return false;
        ((zombie.ui.UI3DModel) widget).setVisible(false);
        return true;
    }

    public static void frameState(Object state) {
        if (!ready) return;
        IsoCamera.FrameState frame = (IsoCamera.FrameState) state;
        int index = frame.playerIndex;
        if (index < 0 || index > extraCameras.length) return;
        View view = index == 0 ? camera : extraCameras[index - 1];
        Anchor resident = index == 0 ? anchor : extraAnchors[index - 1];
        if (IsoPlayer.players[index] != resident) return;
        frame.camCharacter = view;
        frame.camCharacterX = view.getX(); frame.camCharacterY = view.getY();
        frame.camCharacterZ = view.getZ();
        frame.camCharacterSquare = view.getCurrentSquare();
        frame.camCharacterRoom = frame.camCharacterSquare == null ? null : frame.camCharacterSquare.getRoom();
    }

    /** Native cutaway calculation begins with the slot player's position.
     * Our slot player retains streaming residency while its View follows the
     * subject. Replace only that primary render point; retain the engine's
     * auxiliary points, building geometry and native fading decisions.
     */
    public static void cutawayFocus(java.util.List<?> points) {
        if (!hostOnly() || points == null || points.isEmpty()) return;
        int slot = IsoCamera.frameState.playerIndex;
        if (slot < 0 || slot > extraCameras.length) return;
        View view = slot == 0 ? camera : extraCameras[slot - 1];
        Anchor resident = slot == 0 ? anchor : extraAnchors[slot - 1];
        if (IsoPlayer.players[slot] != resident || IsoCamera.frameState.camCharacter != view) return;
        if (!(points.get(0) instanceof zombie.iso.fboRenderChunk.FBORenderCutaways.PointOfInterest point)
                || point.mousePointer || point.x != (int) Math.floor(resident.getX())
                || point.y != (int) Math.floor(resident.getY())
                || point.z != (int) Math.floor(resident.getZ())) return;
        point.x = (int) Math.floor(view.getX());
        point.y = (int) Math.floor(view.getY());
        point.z = (int) Math.floor(view.getZ());
    }

    /** Data-only methods must be called from native game-thread work. */
    public static void setView(float x, float y, float z) {
        setView(0, x, y, z);
    }

    private static void setView(int slot, float x, float y, float z) {
        requireGameThread(); bounded(x, y, z);
        View view = slot == 0 ? camera : extraCameras[slot - 1];
        position(view, x, y, z);
        if (slot == 0) IsoCamera.setCameraCharacter(camera);
        IsoCamera.cameras[slot].center();
    }

    public static void setResidency(float x, float y, float z) {
        setResidency(0, x, y, z);
    }

    private static void setResidency(int slot, float x, float y, float z) {
        requireGameThread(); bounded(x, y, z);
        position(slot == 0 ? anchor : extraAnchors[slot - 1], x, y, z);
        if (slot == 0) IsoPlayer.setInstance(anchor);
        // The ordinary native chunk-map update performs streaming on its next
        // update. No world actor is teleported, added, removed or instructed.
    }

    private static void cameraResidency(int slot, float rx, float ry, float rz, float vx, float vy, float vz) {
        // Regional camera visits need not scroll the native chunk map whenever
        // their detached View moves. Retain real residency only while that
        // slot's actual loaded square lies inside a one-chunk boundary margin.
        // Independently specified residency retains its literal setter contract.
        if (extraAnchors.length > 0 && rx == vx && ry == vy && rz == vz
                && loadedInterior(cell.getChunkMap(slot), vx, vy, vz)) {
            retainedResidencies++;
            return;
        }
        setResidency(slot, rx, ry, rz);
    }

    private static boolean loadedInterior(IsoChunkMap map, float x, float y, float z) {
        if (map == null || map.ignore) return false;
        int tx = (int) Math.floor(x), ty = (int) Math.floor(y), tz = (int) Math.floor(z);
        int margin = IsoChunkMap.CHUNK_SIZE_IN_SQUARES;
        if (tx < map.getWorldXMinTiles() + margin || tx >= map.getWorldXMaxTiles() - margin
            || ty < map.getWorldYMinTiles() + margin || ty >= map.getWorldYMaxTiles() - margin) return false;
        var chunk = map.getChunkForGridSquare(tx, ty);
        return chunk != null && chunk.loaded && chunk.getGridSquare(Math.floorMod(tx, margin),
            Math.floorMod(ty, margin), tz) != null;
    }

    /** Readers on the render/bridge thread receive the last game-thread snapshot. */
    public static String snapshot() { return lastSnapshot; }
    public static long commandSequence() { return sequence; }

    private static void readControl() {
        if (controlFile == null || !Files.isRegularFile(controlFile) || stopping) return;
        long candidate = -1;
        try {
            byte[] bytes;
            try (var input = Files.newInputStream(controlFile)) { bytes = input.readNBytes(8193); }
            if (bytes.length > 8192) throw new IllegalArgumentException("control exceeds 8192 bytes");
            Properties values = new Properties() {
                @Override public synchronized Object put(Object key, Object value) {
                    if (containsKey(key)) throw new IllegalArgumentException("duplicate control key: " + key);
                    return super.put(key, value);
                }
            };
            values.load(new ByteArrayInputStream(bytes));
            candidate = Long.parseLong(values.getProperty("sequence", "-1"));
            if (candidate <= sequence || candidate == rejectedSequence) return;
            if (!CONTROL_KEYS.containsAll(values.stringPropertyNames()))
                throw new IllegalArgumentException("unknown control key");
            int slot = 0;
            if (values.containsKey("siteId")) {
                slot = Arrays.asList(siteIds).indexOf(values.getProperty("siteId"));
                if (slot < 0) throw new IllegalArgumentException("unknown native site");
            }
            View controlledView = slot == 0 ? camera : extraCameras[slot - 1];
            Anchor controlledAnchor = slot == 0 ? anchor : extraAnchors[slot - 1];
            float vx = coordinate(values, "viewX", controlledView.getX());
            float vy = coordinate(values, "viewY", controlledView.getY());
            float vz = coordinate(values, "viewZ", controlledView.getZ());
            float rx = coordinate(values, "residencyX", controlledAnchor.getX());
            float ry = coordinate(values, "residencyY", controlledAnchor.getY());
            float rz = coordinate(values, "residencyZ", controlledAnchor.getZ());
            bounded(vx, vy, vz); bounded(rx, ry, rz);
            int speed = Integer.parseInt(values.getProperty("speed", Integer.toString(desiredSpeed)));
            if (speed < 1 || speed > 3) throw new IllegalArgumentException("speed must be 1, 2 or 3");
            SpeedControls controls = UIManager.getSpeedControls();
            boolean changeClock = values.containsKey("paused") || values.containsKey("speed");
            boolean paused = bool(values, "paused", controls != null && controls.getCurrentGameSpeed() == 0);
            boolean stop = bool(values, "stop", false);
            if (controls == null && changeClock)
                throw new IllegalStateException("native speed controls are not ready");
            boolean selection = values.containsKey("selectedPersonId");
            boolean panel = values.containsKey("panelId") || values.containsKey("panelPersonId") || values.containsKey("panelVisible");
            boolean cognition = values.containsKey("opponentShare") || values.containsKey("opportunitiesPerHour") || values.containsKey("maxDepth");
            double opponentShare = 0;
            int opportunitiesPerHour = 0, maxDepth = 0;
            if (cognition) {
                if (!values.stringPropertyNames().equals(Set.of("sequence", "opponentShare", "opportunitiesPerHour", "maxDepth")))
                    throw new IllegalArgumentException("cognition settings must be complete and independent");
                opponentShare = Double.parseDouble(values.getProperty("opponentShare"));
                opportunitiesPerHour = Integer.parseInt(values.getProperty("opportunitiesPerHour"));
                maxDepth = Integer.parseInt(values.getProperty("maxDepth"));
                if (!Double.isFinite(opponentShare) || opponentShare < 0 || opponentShare > 1
                        || opportunitiesPerHour < 1 || opportunitiesPerHour > 60 || maxDepth < 1 || maxDepth > 4)
                    throw new IllegalArgumentException("cognition settings outside bounded budget");
            }
            boolean zoom = values.containsKey("zoomStep");
            int zoomStep = 0;
            float nextZoom = 0;
            if (zoom) {
                Set<String> allowedZoom = values.containsKey("siteId") ? Set.of("sequence", "zoomStep", "siteId") : Set.of("sequence", "zoomStep");
                if (!values.stringPropertyNames().equals(allowedZoom))
                    throw new IllegalArgumentException("zoom requests must be independent");
                zoomStep = Integer.parseInt(values.getProperty("zoomStep"));
                if (zoomStep != -1 && zoomStep != 1)
                    throw new IllegalArgumentException("zoomStep must be -1 or 1");
                float[] levels = nativeZoomLevels();
                if (levels.length == 0) throw new IllegalStateException("native zoom is unavailable");
                nextZoom = Core.getInstance().getNextZoom(slot, zoomStep);
                if (Arrays.binarySearch(levels, nextZoom) < 0)
                    throw new IllegalStateException("native zoom did not select a configured level");
            }
            String inspectionId = null;
            boolean panelVisible = false;
            if (selection || panel) {
                Set<String> allowed = selection ? Set.of("sequence", "selectedPersonId")
                    : Set.of("sequence", "panelId", "panelPersonId", "panelVisible");
                if (!allowed.equals(values.stringPropertyNames()))
                    throw new IllegalArgumentException("inspection requests must be complete and independent");
                if (panel && !"person-inspection".equals(values.getProperty("panelId")))
                    throw new IllegalArgumentException("unsupported panel");
                inspectionId = person(values, selection ? "selectedPersonId" : "panelPersonId");
                panelVisible = panel && bool(values, "panelVisible", false);
            }
            // Validate the entire command before changing any host coordinates.
            if (cognition) {
                if (!Boolean.TRUE.equals(observationCall("cognition", opponentShare, (double) opportunitiesPerHour, (double) maxDepth)))
                    throw new IllegalStateException("cognition settings were not applied");
            } else if (zoom) {
                Core core = Core.getInstance();
                core.setAutoZoom(slot, false);
                core.doZoomScroll(slot, zoomStep);
                if (core.offscreenBuffer.getTargetZoom(slot) != nextZoom)
                    throw new IllegalStateException("native zoom target was not applied");
                // Use the installed immediate setter so one command sequence
                // names one projection scale, including while the world pauses.
                core.offscreenBuffer.setZoomAndTargetZoom(slot, nextZoom);
            } else if (selection || panel) {
                Object applied = selection ? observationCall("select", inspectionId)
                    : observationCall("panel", "person-inspection", inspectionId, panelVisible);
                if (!Boolean.TRUE.equals(applied)) throw new IllegalStateException("person inspection request was not applied");
                if (panel) {
                    Object element = observationCall("nativePanel");
                    if (panelVisible && !(element instanceof UIElementInterface))
                        throw new IllegalStateException("native person panel did not expose its UI element");
                    inspectionPanel = panelVisible ? (UIElementInterface) element : null;
                }
                selectedPersonId = inspectionId;
                inspectionError = null;
            } else {
                cameraResidency(slot, rx, ry, rz, vx, vy, vz); setView(slot, vx, vy, vz);
            }
            if (changeClock) {
                desiredSpeed = speed;
                controls.SetCurrentGameSpeed(paused ? 0 : speed);
                // Native SetCurrentGameSpeed resets the multiplier to 1. The
                // installed button/key handlers then apply these native presets.
                // Paused requests retain their intended preset for resume; camera
                // and residency commands never touch either native speed owner.
                if (!paused) GameTime.getInstance().setMultiplier(nativeSpeedMultiplier(speed));
            }
            synchronized (StudyObserver.class) { sequence = candidate; }
            error = null;
            if (stop) requestStop("explicit-save");
            boolean published = publish(true);
            if (stop) {
                nextState = 0;
                if (published || statePublicationFailed) finishStop();
            }
        } catch (Exception rejected) {
            rejectedSequence = candidate;
            String message = rejected.getClass().getSimpleName() + ": " + rejected.getMessage();
            if (!message.equals(error)) System.err.println("[StudyObserver] rejected control: " + message);
            error = message;
            publish(true);
        }
    }

    private static float nativeSpeedMultiplier(int speed) {
        return switch (speed) {
            case 1 -> 1.0f;
            case 2 -> 5.0f;
            case 3 -> 20.0f;
            default -> throw new IllegalArgumentException("speed must be 1, 2 or 3");
        };
    }

    private static float[] nativeZoomLevels() {
        MultiTextureFBO2 buffer = Core.getInstance().offscreenBuffer;
        if (buffer == null || !buffer.zoomEnabled) return new float[0];
        try {
            // This installed build exposes current/target zoom publicly, but
            // its active configured level array has no public getter.
            Field field = MultiTextureFBO2.class.getDeclaredField("zoomLevels");
            field.setAccessible(true);
            float[] configured = (float[]) field.get(buffer);
            if (configured == null || configured.length == 0) return new float[0];
            if (configured.length > 64) throw new IllegalStateException("native zoom level limit");
            float[] levels = configured.clone();
            Arrays.sort(levels);
            for (int index = 0; index < levels.length; index++)
                if (!Float.isFinite(levels[index]) || levels[index] <= 0
                    || (index > 0 && levels[index] <= levels[index - 1]))
                    throw new IllegalStateException("invalid native zoom levels");
            return levels;
        } catch (ReflectiveOperationException failure) {
            throw new IllegalStateException("cannot read installed native zoom levels", failure);
        }
    }

    private static String viewportSnapshot() {
        return viewportSnapshot(0);
    }

    private static String viewportSnapshot(int slot) {
        float[] levels = nativeZoomLevels();
        if (levels.length == 0) return "";
        MultiTextureFBO2 buffer = Core.getInstance().offscreenBuffer;
        return ",\"viewport\":{\"zoom\":" + buffer.getZoom(slot)
            + ",\"targetZoom\":" + buffer.getTargetZoom(slot)
            + ",\"zoomLevels\":" + Arrays.toString(levels) + "}";
    }

    private static void finishStop() {
        if (stopIssued) return;
        if (!drainExports()) return;
        stopIssued = true;
        restoreCallbackTiming();
        System.out.println("[StudyObserver] stop hours=" + GameTime.getInstance().getWorldAgeHours());
        Core.getInstance().quitToDesktop();
    }

    /** Installed inclusive callback timing; confined to the isolated study owner. */
    private static void beginCallbackTiming() {
        requireGameThread();
        if (previousSlowLuaCallbacks == null) {
            var option = zombie.debug.DebugOptions.instance.checks.slowLuaEvents;
            previousSlowLuaCallbacks = option.getValue();
            option.setValue(true);
        }
    }
    private static void restoreCallbackTiming() {
        requireGameThread();
        if (previousSlowLuaCallbacks != null) {
            zombie.debug.DebugOptions.instance.checks.slowLuaEvents.setValue(previousSlowLuaCallbacks);
            previousSlowLuaCallbacks = null;
        }
    }

    /** The tool's wall/horizon supervisor uses the same drain as an explicit save. */
    public static void requestStop(String reason) {
        requireGameThread();
        if (!stopping) {
            stopping = true;
            nextState = 0;
            System.out.println("[StudyObserver] requested stop: " + reason);
        }
        SpeedControls controls = UIManager.getSpeedControls();
        if (controls != null) controls.SetCurrentGameSpeed(0);
    }

    /** Save only after Lua has acknowledged the exact asynchronous archive. */
    private static boolean drainExports() {
        long now = System.currentTimeMillis();
        if (exportDrainStarted == 0) exportDrainStarted = now;
        if (exportDrainFailed) return writeState() || statePublicationFailed;
        try {
            SpeedControls controls = UIManager.getSpeedControls();
            if (controls == null) throw new IllegalStateException("native stop clock cannot be paused");
            controls.SetCurrentGameSpeed(0);
            if (controls.getCurrentGameSpeed() != 0) throw new IllegalStateException("native stop clock did not pause");
            Object root = LuaManager.env == null ? null : LuaManager.env.rawget("SAO_StudyWorld");
            Object function = root instanceof KahluaTable table ? table.rawget("drainExports") : null;
            if (function == null) {
                if (StudyExport.hasPending()) throw new IllegalStateException("pending export lost its Lua acknowledgement owner");
                StudyExport.shutdown();
                return true;
            }
            Object[] result = LuaManager.caller.pcall(LuaManager.thread, function, new Object[0]);
            if (result.length < 1 || !Boolean.TRUE.equals(result[0]))
                throw new IllegalStateException("export drain failed: " + (result.length > 1 ? result[1] : "missing result"));
            if (result.length > 1 && Boolean.TRUE.equals(result[1])) {
                StudyExport.shutdown();
                return true;
            }
            if (now - exportDrainStarted < 15000) return false;
            throw new IllegalStateException("export drain exceeded fifteen seconds");
        } catch (Exception failure) {
            String message = "asynchronous export stop failed: " + failure.getClass().getSimpleName() + ": " + failure.getMessage();
            if (runtimeFailure == null) runtimeFailure = message;
            refreshFailureSnapshot();
            System.err.println("[StudyObserver] FAILED " + message);
            exportDrainFailed = true;
            StudyExport.abort();
            return writeState() || statePublicationFailed;
        }
    }

    private static boolean bool(Properties values, String key, boolean fallback) {
        String value = values.getProperty(key);
        if (value == null) return fallback;
        if ("true".equals(value)) return true;
        if ("false".equals(value)) return false;
        throw new IllegalArgumentException(key + " must be true or false");
    }

    private static float coordinate(Properties values, String key, float fallback) {
        return values.containsKey(key) ? Float.parseFloat(values.getProperty(key)) : fallback;
    }

    private static float property(String name) {
        String value = System.getProperty(name);
        if (value == null) throw new IllegalArgumentException("missing property " + name);
        float result = Float.parseFloat(value);
        if (!Float.isFinite(result)) throw new IllegalArgumentException("nonfinite property " + name);
        return result;
    }

    private static Path absoluteProperty(String name) {
        String value = System.getProperty(name);
        if (value == null) return null;
        Path path = Path.of(value);
        if (!path.isAbsolute()) throw new IllegalArgumentException(name + " must be absolute");
        return path.normalize();
    }

    private static void bounded(float x, float y, float z) {
        if (!Float.isFinite(x) || !Float.isFinite(y) || !Float.isFinite(z)
                || x < minX || x >= maxX || y < minY || y >= maxY || z < -32 || z >= 32)
            throw new IllegalArgumentException("observer coordinates outside study extent/native height");
    }

    private static void requireGameThread() {
        if (!ready || Thread.currentThread() != GameWindow.gameThread)
            throw new IllegalStateException("observer control requires active game thread");
    }

    private static void position(IsoGameCharacter value, float x, float y, float z) {
        value.setX(x); value.setY(y); value.setZ(z);
        value.setLastX(x); value.setLastY(y); value.setLastZ(z);
        refreshSquare(value);
    }

    private static void refreshSquare(IsoGameCharacter value) {
        IsoGridSquare square = cell.getGridSquare((int) Math.floor(value.getX()),
            (int) Math.floor(value.getY()), (int) Math.floor(value.getZ()));
        // setCurrent only assigns the pointer; setMovingSquare would publish the
        // host object to the actor list and is deliberately never used.
        value.setCurrent(square);
        value.square = square;
    }

    private static int members(Set<IsoMovingObject> values) {
        int result = (values.contains(anchor) ? 1 : 0) + (values.contains(camera) ? 1 : 0);
        for (int index = 0; index < extraAnchors.length; index++)
            result += (values.contains(extraAnchors[index]) ? 1 : 0) + (values.contains(extraCameras[index]) ? 1 : 0);
        return result;
    }

    private static int squareMemberships() {
        int count = 0;
        // IsoChunk.getGridSquare returns null outside its inclusive min/max
        // levels. Traverse the active loaded chunks and those exact levels,
        // including basements and roofs, rather than probing 64 empty floors
        // through every tile's cell/map lookup on each state publication.
        for (IsoChunkMap map : cell.chunkMap) {
            if (map == null || map.ignore) continue;
            for (int cx = 0; cx < IsoChunkMap.chunkGridWidth; cx++)
                for (int cy = 0; cy < IsoChunkMap.chunkGridWidth; cy++) {
                    var chunk = map.getChunk(cx, cy);
                    if (chunk == null || !chunk.loaded) continue;
                    for (int z = chunk.getMinLevel(); z <= chunk.getMaxLevel(); z++)
                        for (int y = 0; y < IsoChunkMap.CHUNK_SIZE_IN_SQUARES; y++)
                            for (int x = 0; x < IsoChunkMap.CHUNK_SIZE_IN_SQUARES; x++) {
                                IsoGridSquare square = chunk.getGridSquare(x, y, z);
                                if (square == null) continue;
                                if (square.getMovingObjects().contains(anchor)) count++;
                                if (square.getMovingObjects().contains(camera)) count++;
                                if (square.getStaticMovingObjects().contains(anchor)) count++;
                                if (square.getStaticMovingObjects().contains(camera)) count++;
                                for (int index = 0; index < extraAnchors.length; index++) {
                                    if (square.getMovingObjects().contains(extraAnchors[index])) count++;
                                    if (square.getMovingObjects().contains(extraCameras[index])) count++;
                                    if (square.getStaticMovingObjects().contains(extraAnchors[index])) count++;
                                    if (square.getStaticMovingObjects().contains(extraCameras[index])) count++;
                                }
                            }
                }
        }
        return count;
    }

    private static boolean detached() {
        for (int index = 0; index < extraAnchors.length; index++)
            if (extraAnchors[index].getMovingSquare() != null || extraCameras[index].getMovingSquare() != null
                    || extraAnchors[index].isAddedToModelManager() || extraCameras[index].isAddedToModelManager()
                    || extraAnchors[index].sqlId != -1
                    || IsoGameCharacter.getSurvivorMap().containsValue(extraAnchors[index].getDescriptor())) return false;
        return members(cell.getObjectList()) == 0 && members(cell.getAddList()) == 0
            && members(cell.getRemoveList()) == 0 && anchor.getMovingSquare() == null
            && camera.getMovingSquare() == null && !anchor.isAddedToModelManager()
            && !camera.isAddedToModelManager() && anchor.sqlId == -1
            && !IsoGameCharacter.getSurvivorMap().containsValue(anchor.getDescriptor());
    }

    private static boolean publish(boolean immediate) {
        if (anchor == null) return false;
        int objects = members(cell.getObjectList()), additions = members(cell.getAddList());
        int removals = members(cell.getRemoveList()), squares = squareMemberships();
        boolean absent = detached() && squares == 0;
        String invariant = !absent ? "study observer entered native actor ownership"
            : (!ownsSlots() || !Boolean.TRUE.equals(anchor.getModData().rawget(MARKER)))
                ? "study observer identity/slot invariant failed" : null;
        if (invariant != null && runtimeFailure == null) {
            runtimeFailure = invariant;
            System.err.println("[StudyObserver] FAILED " + invariant);
        }
        SpeedControls controls = UIManager.getSpeedControls();
        int speed = controls == null ? -1 : controls.getCurrentGameSpeed();
        double hours = GameTime.getInstance().getWorldAgeHours();
        lastSnapshot = "{\"schema\":\"sao-study-observer/1\",\"status\":\""
            + (runtimeFailure != null ? "failed" : stopping ? "stopping" : "active") + "\",\"sequence\":" + sequence
            + ",\"rejectedSequence\":" + rejectedSequence + ",\"updatedAtUnixMs\":" + System.currentTimeMillis()
            + ",\"hours\":" + hours + ",\"startHours\":" + startHours
            + ",\"worldAdvanced\":" + (hours > startHours) + ",\"logicCalls\":" + logicCalls
            + ",\"paused\":" + GameTime.isGamePaused() + ",\"speed\":" + speed
            + ",\"requestedSpeed\":" + desiredSpeed + ",\"nativeMultiplier\":" + GameTime.getInstance().getTrueMultiplier()
            + ",\"selectedPersonId\":" + quote(selectedPersonId)
            + ",\"inspectionPanelVisible\":" + (inspectionPanel != null && Boolean.TRUE.equals(inspectionPanel.isVisible()))
            + ",\"inspectionError\":" + quote(inspectionError)
            + ",\"originX\":" + originX + ",\"originY\":" + originY + ",\"originZ\":" + originZ
            + ",\"residencyX\":" + anchor.getX() + ",\"residencyY\":" + anchor.getY() + ",\"residencyZ\":" + anchor.getZ()
            + ",\"viewX\":" + camera.getX() + ",\"viewY\":" + camera.getY() + ",\"viewZ\":" + camera.getZ()
            + viewportSnapshot()
            + ",\"displayMode\":\"native-god-view\",\"fullbright\":" + zombie.debug.DebugOptions.instance.fboRenderChunk.nolighting.getValue()
            + ",\"visionMask\":" + zombie.debug.DebugOptions.instance.fboRenderChunk.renderVisionPolygon.getValue()
            + ",\"canopyCutaway\":" + cutawayCanopy(0)
            + ",\"detached\":" + absent + ",\"objects\":" + objects + ",\"additions\":" + additions
            + ",\"removals\":" + removals + ",\"squareMemberships\":" + squares
            + ",\"playerSqlId\":" + anchor.sqlId + ",\"suppressedSaves\":" + suppressedSaves
            + ",\"suppressedBirths\":" + suppressedBirths + ",\"suppressedUpdates\":" + suppressedUpdates
            + ",\"blockedAdmissions\":" + blockedAdmissions.get()
            + ",\"streamingChecks\":" + streamingChecks
            + ",\"retainedResidencies\":" + retainedResidencies
            + ",\"slowLuaCallbacks\":" + zombie.debug.DebugOptions.instance.checks.slowLuaEvents.getValue()
            + ",\"nativeZombieCount\":" + cell.getZombieList().size()
            + ",\"nativeZombiesDisabled\":" + IsoWorld.getZombiesDisabled()
            + ",\"slowLuaCallbackWarnings\":" + zombie.debug.DebugLog.isLogEnabled(zombie.debug.DebugType.Lua, zombie.debug.LogSeverity.Warning)
            + ",\"observationTiming\":" + (!initializing && Thread.currentThread() == GameWindow.gameThread
                ? StudyExport.diagnosticsJson() : "null")
            + ",\"anchorIdentity\":" + quote(Integer.toHexString(System.identityHashCode(anchor)))
            + ",\"viewIdentity\":" + quote(Integer.toHexString(System.identityHashCode(camera)))
            + ",\"sites\":" + siteSnapshot()
            + streamingSnapshot()
            + lightingSnapshot()
            + ",\"nativeAlive\":" + anchor.isAlive() + ",\"ghost\":" + anchor.isGhostMode()
            + ",\"zombiesDontAttack\":" + anchor.isZombiesDontAttack()
            + ",\"collidable\":" + anchor.isCollidable() + ",\"error\":" + quote(error)
            + ",\"failure\":" + quote(runtimeFailure) + "}\n";
        boolean published = writeState();
        if (immediate) System.out.println("[StudyObserver] state sequence=" + sequence + " detached=" + absent
            + " objects=" + objects + " squares=" + squares + " sqlId=" + anchor.sqlId
            + " hours=" + hours + " suppressedSaves=" + suppressedSaves);
        return published;
    }

    private static boolean writeState() {
        boolean published = true;
        if (stateFile != null) {
            try {
                Files.createDirectories(stateFile.getParent());
                Path temporary = stateFile.resolveSibling(stateFile.getFileName() + ".tmp");
                Files.writeString(temporary, lastSnapshot);
                Files.move(temporary, stateFile, StandardCopyOption.ATOMIC_MOVE, StandardCopyOption.REPLACE_EXISTING);
                if (stateDeferrals != 0)
                    System.out.println("[StudyObserver] state publication resumed after " + stateDeferrals + " deferred frames");
                stateDeferrals = 0;
            } catch (AccessDeniedException inUse) {
                published = false;
                stateDeferrals = Math.min(MAX_STATE_DEFERRALS, stateDeferrals + 1);
                nextState = System.currentTimeMillis() + 100;
                if (stateDeferrals >= MAX_STATE_DEFERRALS) statePublicationFailure(inUse);
                else if (stateDeferrals == 1)
                    System.out.println("[StudyObserver] state publication deferred while file is in use");
            } catch (IOException failure) {
                published = false;
                statePublicationFailure(failure);
            }
        }
        return published;
    }

    public static String siteSnapshot() {
        StringBuilder result = new StringBuilder("[");
        for (int index = 0; index <= extraAnchors.length; index++) {
            Anchor resident = index == 0 ? anchor : extraAnchors[index - 1];
            View view = index == 0 ? camera : extraCameras[index - 1];
            if (index != 0) result.append(',');
            IsoChunkMap map = cell.getChunkMap(index);
            int loaded = 0;
            for (int x = 0; x < IsoChunkMap.chunkGridWidth; x++) for (int y = 0; y < IsoChunkMap.chunkGridWidth; y++) {
                var chunk = map.getChunk(x, y); if (chunk != null && chunk.loaded) loaded++;
            }
            result.append("{\"id\":").append(quote(siteIds[index])).append(",\"label\":").append(quote(siteLabels[index]))
                .append(",\"slot\":").append(index).append(",\"residencyX\":").append(resident.getX())
                .append(",\"residencyY\":").append(resident.getY()).append(",\"residencyZ\":").append(resident.getZ())
                .append(",\"viewX\":").append(view.getX()).append(",\"viewY\":").append(view.getY())
                .append(",\"viewZ\":").append(view.getZ()).append(",\"loadedChunks\":").append(loaded)
                .append(",\"left\":").append(IsoCamera.getScreenLeft(index)).append(",\"top\":").append(IsoCamera.getScreenTop(index))
                .append(",\"width\":").append(IsoCamera.getScreenWidth(index)).append(",\"height\":").append(IsoCamera.getScreenHeight(index))
                .append(",\"anchorIdentity\":").append(quote(Integer.toHexString(System.identityHashCode(resident))))
                .append(",\"viewIdentity\":").append(quote(Integer.toHexString(System.identityHashCode(view))))
                .append(",\"playerSqlId\":").append(resident.sqlId).append(",\"nativeAlive\":").append(resident.isAlive())
                .append(",\"ghost\":").append(resident.isGhostMode()).append(",\"collidable\":").append(resident.isCollidable())
                .append(viewportSnapshot(index)).append('}');
        }
        return result.append(']').toString();
    }

    public record SiteFrame(String id, String label, int slot, float x, float y, float z,
                            int left, int top, int width, int height) { }

    public static SiteFrame[] siteFrames() {
        if (extraCameras.length == 0) return new SiteFrame[0];
        SiteFrame[] result = new SiteFrame[siteIds.length];
        for (int index = 0; index < result.length; index++) {
            View view = index == 0 ? camera : extraCameras[index - 1];
            result[index] = new SiteFrame(siteIds[index], siteLabels[index], index, view.getX(), view.getY(), view.getZ(),
                IsoCamera.getScreenLeft(index), IsoCamera.getScreenTop(index),
                IsoCamera.getScreenWidth(index), IsoCamera.getScreenHeight(index));
        }
        return result;
    }

    /** Video also names the actual primary camera when PNG has no site crops. */
    public static SiteFrame[] videoFrames() {
        if (extraCameras.length > 0) return siteFrames();
        if (camera == null || IsoPlayer.numPlayers != 1) return new SiteFrame[0];
        boolean declared = System.getProperty("study.site.0.id") != null;
        return new SiteFrame[] { new SiteFrame(declared ? siteIds[0] : "current",
            declared ? siteLabels[0] : "Current view", 0, camera.getX(), camera.getY(), camera.getZ(),
            IsoCamera.getScreenLeft(0), IsoCamera.getScreenTop(0),
            IsoCamera.getScreenWidth(0), IsoCamera.getScreenHeight(0)) };
    }

    private static void statePublicationFailure(IOException cause) {
        if (statePublicationFailed) return;
        statePublicationFailed = true;
        String message = "cannot publish observer state: " + cause;
        if (runtimeFailure == null) runtimeFailure = message;
        System.err.println("[StudyObserver] FAILED " + message);
    }

    private static String streamingSnapshot() {
        IsoChunkMap map = cell.getChunkMap(0);
        int loaded = 0;
        if (map != null) for (int x = 0; x < IsoChunkMap.chunkGridWidth; x++)
            for (int y = 0; y < IsoChunkMap.chunkGridWidth; y++) {
                var chunk = map.getChunk(x, y);
                if (chunk != null && chunk.loaded) loaded++;
            }
        return ",\"loadedChunks\":" + loaded + ",\"chunkMapIgnored\":" + (map == null || map.ignore)
            + ",\"chunkMapX\":" + (map == null ? "null" : map.worldX)
            + ",\"chunkMapY\":" + (map == null ? "null" : map.worldY)
            + ",\"residencySquare\":" + squarePosition(anchor.getCurrentSquare())
            + ",\"viewSquare\":" + squarePosition(camera.getCurrentSquare())
            + ",\"nativeCameraIsView\":" + (IsoCamera.getCameraCharacter() == camera)
            + ",\"nativePlayerIsAnchor\":" + (IsoPlayer.getInstance() == anchor);
    }

    private static String squarePosition(IsoGridSquare square) {
        return square == null ? "null" : "{\"x\":" + square.getX() + ",\"y\":" + square.getY()
            + ",\"z\":" + square.getZ() + "}";
    }

    /** Read existing native lighting results only. Calling ILighting getters can
     * refresh JNI caches and mark squares seen, so diagnostics read the exact
     * installed JNILighting cache fields without invoking those getters.
     */
    private static String lightingSnapshot() {
        if (!LightingJNI.init) return ",\"lighting\":{\"enabled\":false}";
        IsoChunkMap map = cell.getChunkMap(0);
        int lit = 0, pending = 0, dirty = 0;
        if (map != null) for (int x = 0; x < IsoChunkMap.chunkGridWidth; x++)
            for (int y = 0; y < IsoChunkMap.chunkGridWidth; y++) {
                var chunk = map.getChunk(x, y);
                if (chunk == null || !chunk.loaded) continue;
                if (chunk.lightingNeverDone[0]) pending++; else lit++;
                if (chunk.lightCheck[0]) dirty++;
            }
        IsoGridSquare center = camera.getCurrentSquare();
        var chunk = center == null ? null : center.getChunk();
        int sampled = 0, cached = 0, seen = 0, canSee = 0, couldSee = 0;
        double luma = 0;
        int cx = (int) Math.floor(camera.getX()), cy = (int) Math.floor(camera.getY());
        int cz = (int) Math.floor(camera.getZ());
        for (int dx = -12; dx <= 12; dx += 4) for (int dy = -12; dy <= 12; dy += 4) {
            IsoGridSquare square = cell.getGridSquare(cx + dx, cy + dy, cz);
            if (square == null) continue;
            sampled++;
            NativeLight sample = cachedLight(square.lighting[0]);
            if (sample == null || sample.updateTick < 0) continue;
            cached++;
            if ((sample.visibility & 1) != 0) seen++;
            if ((sample.visibility & 2) != 0) canSee++;
            if ((sample.visibility & 4) != 0) couldSee++;
            luma += sample.r * 0.299 + sample.g * 0.587 + sample.b * 0.114;
        }
        NativeLight light = center == null ? null : cachedLight(center.lighting[0]);
        var settings = zombie.core.opengl.RenderSettings.getInstance().getPlayerSettings(0);
        var look = anchor.getLookVector(new zombie.iso.Vector2());
        return ",\"lighting\":{\"enabled\":true,\"nativeUpdate\":" + LightingJNI.getUpdateCounter(0)
            + ",\"litChunks\":" + lit + ",\"pendingChunks\":" + pending + ",\"dirtyChunks\":" + dirty
            + ",\"viewChunkReady\":" + (chunk != null && chunk.loaded && !chunk.lightingNeverDone[0])
            + ",\"viewLight\":" + (light == null ? "null" : light.json())
            + ",\"sampledSquares\":" + sampled + ",\"cachedSquares\":" + cached
            + ",\"seenSquares\":" + seen + ",\"canSeeSquares\":" + canSee
            + ",\"couldSeeSquares\":" + couldSee + ",\"meanCachedLuma\":" + (cached == 0 ? "null" : luma / cached)
            + ",\"lookX\":" + look.x + ",\"lookY\":" + look.y
            + ",\"visionConeDegrees\":" + NativeLightFields.floatValue(NativeLightFields.cone, null)
            + ",\"lumaInverted\":" + NativeLightFields.floatValue(NativeLightFields.luma, null)
            + ",\"timeOfDay\":" + GameTime.getInstance().getTimeOfDay()
            + ",\"dayLight\":" + zombie.iso.weather.ClimateManager.getInstance().getDayLightStrength()
            + ",\"ambient\":" + settings.getAmbient() + ",\"night\":" + settings.getNight()
            + ",\"viewDistance\":" + settings.getViewDistance() + "}";
    }

    private record NativeLight(int updateTick, int visibility, float r, float g, float b,
                               float dark, float targetDark) {
        String json() {
            return "{\"updateTick\":" + updateTick + ",\"visibility\":" + visibility
                + ",\"r\":" + r + ",\"g\":" + g + ",\"b\":" + b
                + ",\"dark\":" + dark + ",\"targetDark\":" + targetDark + "}";
        }
    }

    private static NativeLight cachedLight(Object value) {
        if (value == null || value.getClass() != LightingJNI.JNILighting.class) return null;
        try {
            ColorInfo color = (ColorInfo) NativeLightFields.color.get(value);
            return new NativeLight(NativeLightFields.tick.getInt(value), NativeLightFields.vis.getByte(value) & 7,
                color.r, color.g, color.b, NativeLightFields.dark.getFloat(value), NativeLightFields.target.getFloat(value));
        } catch (ReflectiveOperationException failure) {
            throw new IllegalStateException("cannot read installed native lighting cache", failure);
        }
    }

    private static final class NativeLightFields {
        static final Field tick = cacheField("updateTick"), vis = cacheField("vis"), color = cacheField("lightInfo"),
            dark = cacheField("cacheDarkMulti"), target = cacheField("cacheTargetDarkMulti");
        static final Field cone = field(LightingJNI.class, "visionConeLerp"), luma = field(LightingJNI.class, "lumaInvertedLerp");
        private static Field cacheField(String name) { return field(LightingJNI.JNILighting.class, name); }
        private static Field field(Class<?> type, String name) {
            try { Field value = type.getDeclaredField(name); value.setAccessible(true); return value; }
            catch (ReflectiveOperationException failure) {
                throw new IllegalStateException("installed native lighting field missing: " + name, failure);
            }
        }
        private static float floatValue(Field field, Object owner) {
            try { return field.getFloat(owner); }
            catch (ReflectiveOperationException failure) { throw new IllegalStateException(failure); }
        }
    }

    private static String quote(String value) {
        if (value == null) return "null";
        StringBuilder result = new StringBuilder("\"");
        for (char c : value.toCharArray()) {
            if (c == '\\' || c == '"') result.append('\\').append(c);
            else if (c < 32) result.append(String.format("\\u%04x", (int) c));
            else result.append(c);
        }
        return result.append('"').toString();
    }

    public static final class Anchor extends IsoPlayer {
        public Anchor() {
            // The native zero-position constructor does not register an actor.
            // The final argument is isAnimal. Keep a human visual for native
            // animation refresh; observer guards suppress participation.
            // The birth event is intercepted before dispatch.
            super(null, new SurvivorDesc(false), 0, 0, 0, false);
            getModData().rawset(MARKER, Boolean.TRUE);
            setNpc(true); setGhostMode(true); setInvisible(true); setZombiesDontAttack(true);
            setCollidable(false); setAlphaAndTarget(0.0f);
            IsoGameCharacter.getSurvivorMap().remove(getDescriptor().getID(), getDescriptor());
        }
        @Override public boolean isDead() { return true; }
        @Override public boolean isInvisible() { return true; }
        @Override public boolean isGhostMode() { return true; }
        @Override public boolean isZombiesDontAttack() { return true; }
        @Override public boolean isCollidable() { return false; }
        @Override public void setSceneCulled(boolean value) { }
        @Override public void preupdate() { suppressedUpdates++; }
        @Override public void update() { suppressedUpdates++; }
        @Override public void postupdate() { suppressedUpdates++; }
        @Override public void render(float x, float y, float z, ColorInfo color, boolean a, boolean b, Shader shader) { }
        @Override public void renderlast() { }
        @Override public void renderShadow(float x, float y, float z) { }
        @Override public void renderObjectPicker(float x, float y, float z, ColorInfo color) { }
        @Override public void save() { suppressedSaves++; }
        @Override public void save(String path) { suppressedSaves++; }
        @Override public void save(ByteBuffer bytes, boolean net) throws IOException {
            throw new IOException("study observer must never be serialized as a player");
        }
    }

    public static final class View extends IsoGameCharacter {
        public View() {
            super(null, 0, 0, 0);
            getModData().rawset(MARKER, Boolean.TRUE);
            setInvisible(true); setCollidable(false); setAlphaAndTarget(0.0f);
        }
        @Override public boolean isDead() { return true; }
        @Override public boolean isInvisible() { return true; }
        @Override public boolean isZombiesDontAttack() { return true; }
        @Override public boolean isCollidable() { return false; }
        @Override public void setSceneCulled(boolean value) { }
        @Override public void preupdate() { }
        @Override public void update() { }
        @Override public void postupdate() { }
        @Override public void render(float x, float y, float z, ColorInfo color, boolean a, boolean b, Shader shader) { }
        @Override public void renderlast() { }
        @Override public void renderShadow(float x, float y, float z) { }
        @Override public void renderObjectPicker(float x, float y, float z, ColorInfo color) { }
    }
}
