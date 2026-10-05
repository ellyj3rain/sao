package com.sao.engine;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.lang.ref.WeakReference;
import zombie.iso.IsoCell;
import zombie.iso.IsoGridSquare;
import zombie.iso.IsoObject;

/** Per-body route-following state, mirroring the reference's KnoxNpc movement fields. */
public final class SAORouteState {

    public final List<float[]> route = new ArrayList<>();
    public int routeIndex;
    public final Map<String, Long> edgeCooldowns = new HashMap<>();
    public boolean requested;
    public boolean running;
    public boolean mayForceEntry;
    public String interactionStage = "NONE";
    public String barrierResult;
    public long routeGeneration;
    long crossingSequence;
    String crossingResult;
    ApertureCrossing apertureCrossing;
    String pendingCrossingEvent;
    boolean crossingObserved;
    boolean realignAfterCrossing;
    public float targetX;
    public float targetY;
    public int targetZ;
    public void setRoute(List<float[]> nodes) {
        apertureCrossing = null;
        route.clear();
        route.addAll(nodes);
        routeIndex = 0;
    }

    public float[] currentNode() {
        return routeIndex < route.size() ? route.get(routeIndex) : null;
    }

    /** Read the already owned waypoint without advancing or computing a path. */
    public String progress() {
        if (!requested) return "MOVE_PROGRESS_UNAVAILABLE";
        float[] node = currentNode();
        return "MOVE_PROGRESS@" + (node == null ? -1 : routeIndex)
            + "@" + (node == null ? targetX : node[0])
            + "@" + (node == null ? targetY : node[1])
            + "@" + (node == null ? targetZ : node[2]);
    }

    public void advance() {
        routeIndex++;
        // Each edge starts fresh: without this, the SECOND window on a route
        // inherited OPEN_ATTEMPTED and skipped straight to decline/smash
        // ([A12] find).
        interactionStage = "NONE";
    }

    public boolean hasRoute() {
        return routeIndex < route.size();
    }

    public void clearRoute() {
        routeGeneration++;
        route.clear();
        routeIndex = 0;
        interactionStage = "NONE";
        barrierResult = null;
        crossingResult = null;
        apertureCrossing = null;
        pendingCrossingEvent = null;
        crossingObserved = false;
        realignAfterCrossing = false;
    }

    /** A single observed aperture belongs to this route and exact native body.
     * Weak body ownership keeps the bridge's weak route map collectible. */
    static final class ApertureCrossing {
        final WeakReference<SAOIsoPlayerShell> body;
        final IsoCell cell;
        final IsoGridSquare from, to;
        final IsoObject aperture;
        final long generation;
        final String kind, before;
        boolean reached;
        boolean admitted;

        ApertureCrossing(SAOIsoPlayerShell shell, SAORouteState route,
                IsoGridSquare from, IsoGridSquare to, IsoObject aperture, String kind, String before) {
            body = new WeakReference<>(shell);
            cell = shell.getCell();
            this.from = from;
            this.to = to;
            this.aperture = aperture;
            this.kind = kind;
            this.before = before;
            generation = route.routeGeneration;
        }
    }

    public String consumeCrossing() {
        String result = crossingResult;
        crossingResult = null;
        return result == null ? "MOVE_CROSSING_UNAVAILABLE" : result;
    }

    public boolean edgeCooling(String key) {
        Long until = edgeCooldowns.get(key);
        if (until == null) {
            return false;
        }
        if (System.currentTimeMillis() >= until) {
            edgeCooldowns.remove(key);
            return false;
        }
        return true;
    }

    public void rememberEdgeFailure(String key, String state) {
        long duration = state.contains("LOCKED") || state.contains("BARRICADED") ? 5000L : 1800L;
        edgeCooldowns.put(key, System.currentTimeMillis() + duration);
    }
}
