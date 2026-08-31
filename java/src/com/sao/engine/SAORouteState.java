package com.sao.engine;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/** Per-body route-following state, mirroring the reference's KnoxNpc movement fields. */
public final class SAORouteState {

    public final List<float[]> route = new ArrayList<>();
    public int routeIndex;
    public final Map<String, Long> edgeCooldowns = new HashMap<>();
    public boolean requested;
    public boolean running;
    public boolean mayForceEntry;
    public String interactionStage = "NONE";
    public float targetX;
    public float targetY;
    public int targetZ;
    public void setRoute(List<float[]> nodes) {
        route.clear();
        route.addAll(nodes);
        routeIndex = 0;
    }

    public float[] currentNode() {
        return routeIndex < route.size() ? route.get(routeIndex) : null;
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
        route.clear();
        routeIndex = 0;
        interactionStage = "NONE";
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
