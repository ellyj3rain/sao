package com.sao.engine;

import com.sao.agent.SAOAgent;
import zombie.scripting.ScriptManager;
import zombie.scripting.objects.Item;
import zombie.scripting.objects.VehicleScript;

/**
 * [B21] What THIS world actually contains.
 *
 * <p>The operator's directive: build the substrate before continuing,
 * so the county can recall that "this exists and this exists and this
 * exists" - across a mod load that is theirs, not ours, and that will
 * change.
 *
 * <p>The rule this whole file obeys: <b>never name a mod, never name
 * an item.</b> Everything is discovered from the live script registry
 * and classified by the properties content uses to describe itself -
 * {@code displayCategory}, {@code subCategory}, the module prefix of
 * {@code moduleDotType}. A modded instrument, a modded RV and a
 * modded crop announce themselves the same way vanilla ones do, so
 * nothing here needs updating when the load changes.
 *
 * <p>This is deliberately a READ. It answers what is registered, not
 * what is lying on the ground - that is the perception layer's job
 * and it stays there.
 */
public final class SAOWorldCensus {

    private SAOWorldCensus() {
    }

    /**
     * Survey every registered item, grouped by the category content
     * uses to describe itself. Serialized
     * {@code modules=N|items=N|cat:<name>=<count>|...}, categories
     * sorted by count so the caller can trust the head of the list.
     */
    public static String surveyItems(int topCategories) {
        StringBuilder out = new StringBuilder();
        try {
            ScriptManager scripts = ScriptManager.instance;
            if (scripts == null) return "";
            java.util.ArrayList<Item> items = scripts.getAllItems();
            if (items == null) return "";
            java.util.TreeMap<String, Integer> byCategory =
                new java.util.TreeMap<>();
            java.util.TreeSet<String> modules = new java.util.TreeSet<>();
            int counted = 0;
            for (Item item : items) {
                if (item == null || item.obsolete) continue;
                counted++;
                String full = item.moduleDotType;
                if (full != null) {
                    int dot = full.indexOf('.');
                    modules.add(dot > 0 ? full.substring(0, dot) : full);
                }
                String category = item.displayCategory;
                if (category == null || category.isEmpty()) {
                    category = "Uncategorised";
                }
                byCategory.merge(category, 1, Integer::sum);
            }
            out.append("modules=").append(modules.size())
               .append("|items=").append(counted);
            java.util.ArrayList<java.util.Map.Entry<String, Integer>> ranked =
                new java.util.ArrayList<>(byCategory.entrySet());
            ranked.sort((a, b) -> b.getValue() - a.getValue());
            int shown = 0;
            for (java.util.Map.Entry<String, Integer> row : ranked) {
                if (shown++ >= topCategories) break;
                out.append("|cat:")
                   .append(row.getKey().replace("|", " ").replace("=", " "))
                   .append("=").append(row.getValue());
            }
        } catch (Throwable throwable) {
            SAOAgent.log("surveyItems threw: " + throwable);
        }
        return out.toString();
    }

    /**
     * Survey every registered vehicle by what it can DO. The county
     * never needs to know a thing is called an RV - it needs to know
     * this world contains something that carries eight people and
     * their gear. Serialized
     * {@code veh=N|seatsMax=N|seatsBig=N|storeMax=N|quietest=N|loudest=N}.
     */
    public static String surveyVehicles(int bigSeats) {
        StringBuilder out = new StringBuilder();
        try {
            ScriptManager scripts = ScriptManager.instance;
            if (scripts == null) return "";
            java.util.ArrayList<VehicleScript> all =
                scripts.getAllVehicleScripts();
            if (all == null) return "";
            int count = 0, seatsMax = 0, big = 0, storeMax = 0;
            int quietest = Integer.MAX_VALUE, loudest = 0;
            for (VehicleScript script : all) {
                if (script == null) continue;
                count++;
                int seats = script.getSeats();
                if (seats > seatsMax) seatsMax = seats;
                if (seats >= bigSeats) big++;
                int storage = script.getStorageCapacity();
                if (storage > storeMax) storeMax = storage;
                int loud = script.getEngineLoudness();
                if (loud > 0 && loud < quietest) quietest = loud;
                if (loud > loudest) loudest = loud;
            }
            if (quietest == Integer.MAX_VALUE) quietest = 0;
            out.append("veh=").append(count)
               .append("|seatsMax=").append(seatsMax)
               .append("|seatsBig=").append(big)
               .append("|storeMax=").append(storeMax)
               .append("|quietest=").append(quietest)
               .append("|loudest=").append(loudest);
        } catch (Throwable throwable) {
            SAOAgent.log("surveyVehicles threw: " + throwable);
        }
        return out.toString();
    }
}
