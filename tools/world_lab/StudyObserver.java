import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.file.AccessDeniedException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.lang.reflect.Field;
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
import zombie.iso.IsoCamera;
import zombie.iso.IsoCell;
import zombie.iso.IsoChunkMap;
import zombie.iso.IsoGridSquare;
import zombie.iso.IsoMovingObject;
import zombie.iso.IsoWorld;
import zombie.iso.LightingJNI;
import zombie.ui.SpeedControls;
import zombie.ui.UIManager;

/** Study-JVM host infrastructure, excluded from the world's actor collections.
 * The native player slot supplies rendering/streaming infrastructure only. The
 * separate camera supplies view coordinates, and neither object is updated as
 * a character. See StudyLoadingAgent for the narrowly scoped native adapters.
 */
public final class StudyObserver {
    public static final String MARKER = "SAO_ObserverAnchor";
    private static final Set<String> CONTROL_KEYS = Set.of("sequence", "viewX", "viewY", "viewZ",
        "residencyX", "residencyY", "residencyZ", "paused", "speed", "stop");
    private static Anchor anchor;
    private static View camera;
    private static IsoCell cell;
    private static Path controlFile, stateFile;
    private static float originX, originY, originZ, minX, minY, maxX, maxY;
    private static volatile long sequence;
    private static long rejectedSequence = -1, nextPoll, nextState, logicCalls;
    private static long suppressedBirths, suppressedSaves, suppressedUpdates;
    private static long streamingChecks;
    private static final AtomicLong blockedAdmissions = new AtomicLong();
    private static double startHours;
    private static int desiredSpeed = 1;
    private static boolean stopping, stopIssued, statePublicationFailed;
    private static final int MAX_STATE_DEFERRALS = 30;
    private static int stateDeferrals;
    private static volatile boolean initializing, ready;
    private static String error;
    private static volatile String runtimeFailure;
    private static volatile String lastSnapshot = "{\"schema\":\"sao-study-observer/1\",\"status\":\"starting\",\"sequence\":0}";

    private StudyObserver() { }

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
        for (int i = 1; i < IsoPlayer.players.length; i++) if (IsoPlayer.players[i] != null) return false;
        return true;
    }

    public static boolean hideNativeUi() { return initializing || hostOnly(); }

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
        IsoPlayer.numPlayers = 1;
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

    /** Native logic executes this while UI speed is zero as well as while running. */
    public static void poll() {
        if (!ready || GameWindow.closeRequested) return;
        requireGameThread();
        logicCalls++;
        refreshSquare(anchor);
        refreshSquare(camera);
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

    public static Object cameraFor(Object requested) {
        return ready && requested == anchor ? camera : requested;
    }

    public static Object residencyFor(Object requested) {
        return ready && requested == camera ? anchor : requested;
    }

    /** Installed filming/render options, confined to this single-owner study
     * JVM. Geometry/materials remain native; terrain/model display is fullbright,
     * without a camera LOS mask or fading. Native lighting and actor perception
     * receive no substituted inputs, including when the camera moves.
     */
    public static boolean configureGodView() {
        if (!ownsSlots()) return false;
        if (!Core.debug) throw new IllegalStateException("native God-view requires the isolated debug launch");
        var options = zombie.debug.DebugOptions.instance;
        options.fboRenderChunk.nolighting.setValue(true);
        options.fboRenderChunk.renderVisionPolygon.setValue(false);
        options.terrain.renderTiles.forceFullAlpha.setValue(true);
        return true;
    }

    /** Select the installed tree renderer's cutaway for this study viewport.
     * Native jumbo sprites retain their separate trunk; single-texture trees
     * have no separate trunk and their complete display texture is cut away.
     * The tree object, its square, damage and simulation flags are unchanged.
     */
    public static boolean cutawayCanopy(int playerIndex) {
        return playerIndex == 0 && hostOnly() && zombie.core.PerformanceSettings.fboRenderChunk;
    }

    public static boolean hideCharacterPreview(Object widget, Object character) {
        if (!isObserver(character)) return false;
        ((zombie.ui.UI3DModel) widget).setVisible(false);
        return true;
    }

    public static void frameState(Object state) {
        if (!ready) return;
        IsoCamera.FrameState frame = (IsoCamera.FrameState) state;
        if (frame.playerIndex != 0 || IsoPlayer.players[0] != anchor) return;
        frame.camCharacter = camera;
        frame.camCharacterX = camera.getX(); frame.camCharacterY = camera.getY();
        frame.camCharacterZ = camera.getZ();
        frame.camCharacterSquare = camera.getCurrentSquare();
        frame.camCharacterRoom = frame.camCharacterSquare == null ? null : frame.camCharacterSquare.getRoom();
    }

    /** Data-only methods must be called from native game-thread work. */
    public static void setView(float x, float y, float z) {
        requireGameThread(); bounded(x, y, z);
        position(camera, x, y, z);
        IsoCamera.setCameraCharacter(camera);
        IsoCamera.cameras[0].center();
    }

    public static void setResidency(float x, float y, float z) {
        requireGameThread(); bounded(x, y, z);
        position(anchor, x, y, z);
        IsoPlayer.setInstance(anchor);
        // The ordinary native chunk-map update performs streaming on its next
        // update. No world actor is teleported, added, removed or instructed.
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
            float vx = coordinate(values, "viewX", camera.getX());
            float vy = coordinate(values, "viewY", camera.getY());
            float vz = coordinate(values, "viewZ", camera.getZ());
            float rx = coordinate(values, "residencyX", anchor.getX());
            float ry = coordinate(values, "residencyY", anchor.getY());
            float rz = coordinate(values, "residencyZ", anchor.getZ());
            bounded(vx, vy, vz); bounded(rx, ry, rz);
            int speed = Integer.parseInt(values.getProperty("speed", Integer.toString(desiredSpeed)));
            if (speed < 1 || speed > 3) throw new IllegalArgumentException("speed must be 1, 2 or 3");
            SpeedControls controls = UIManager.getSpeedControls();
            boolean paused = bool(values, "paused", controls != null && controls.getCurrentGameSpeed() == 0);
            boolean stop = bool(values, "stop", false);
            if (controls == null && (values.containsKey("paused") || values.containsKey("speed")))
                throw new IllegalStateException("native speed controls are not ready");
            // Validate the entire command before changing any host coordinates.
            setResidency(rx, ry, rz); setView(vx, vy, vz);
            desiredSpeed = speed;
            if (controls != null) controls.SetCurrentGameSpeed(paused ? 0 : speed);
            synchronized (StudyObserver.class) { sequence = candidate; }
            error = null;
            stopping = stop;
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

    private static void finishStop() {
        if (stopIssued) return;
        stopIssued = true;
        System.out.println("[StudyObserver] stop hours=" + GameTime.getInstance().getWorldAgeHours());
        Core.getInstance().quitToDesktop();
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
        return (values.contains(anchor) ? 1 : 0) + (values.contains(camera) ? 1 : 0);
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
                            }
                }
        }
        return count;
    }

    private static boolean detached() {
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
            + ",\"originX\":" + originX + ",\"originY\":" + originY + ",\"originZ\":" + originZ
            + ",\"residencyX\":" + anchor.getX() + ",\"residencyY\":" + anchor.getY() + ",\"residencyZ\":" + anchor.getZ()
            + ",\"viewX\":" + camera.getX() + ",\"viewY\":" + camera.getY() + ",\"viewZ\":" + camera.getZ()
            + ",\"displayMode\":\"native-god-view\",\"fullbright\":" + zombie.debug.DebugOptions.instance.fboRenderChunk.nolighting.getValue()
            + ",\"visionMask\":" + zombie.debug.DebugOptions.instance.fboRenderChunk.renderVisionPolygon.getValue()
            + ",\"canopyCutaway\":" + cutawayCanopy(0)
            + ",\"detached\":" + absent + ",\"objects\":" + objects + ",\"additions\":" + additions
            + ",\"removals\":" + removals + ",\"squareMemberships\":" + squares
            + ",\"playerSqlId\":" + anchor.sqlId + ",\"suppressedSaves\":" + suppressedSaves
            + ",\"suppressedBirths\":" + suppressedBirths + ",\"suppressedUpdates\":" + suppressedUpdates
            + ",\"blockedAdmissions\":" + blockedAdmissions.get()
            + ",\"streamingChecks\":" + streamingChecks
            + ",\"anchorIdentity\":" + quote(Integer.toHexString(System.identityHashCode(anchor)))
            + ",\"viewIdentity\":" + quote(Integer.toHexString(System.identityHashCode(camera)))
            + streamingSnapshot()
            + lightingSnapshot()
            + ",\"nativeAlive\":" + anchor.isAlive() + ",\"ghost\":" + anchor.isGhostMode()
            + ",\"zombiesDontAttack\":" + anchor.isZombiesDontAttack()
            + ",\"collidable\":" + anchor.isCollidable() + ",\"error\":" + quote(error)
            + ",\"failure\":" + quote(runtimeFailure) + "}\n";
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
        if (immediate) System.out.println("[StudyObserver] state sequence=" + sequence + " detached=" + absent
            + " objects=" + objects + " squares=" + squares + " sqlId=" + anchor.sqlId
            + " hours=" + hours + " suppressedSaves=" + suppressedSaves);
        return published;
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
            // true skips clothes, sprite/action-state initialization and debug
            // cheats. The remaining birth event is intercepted before dispatch.
            super(null, new SurvivorDesc(false), 0, 0, 0, true);
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
