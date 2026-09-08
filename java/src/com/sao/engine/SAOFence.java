package com.sao.engine;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * [C47] The fence: what a person is physically able to say.
 *
 * SPEECH_ML_DESIGN.md, Decision 4, ratified 2026-08-29 through
 * Crucible - no-invention is enforced by CONSTRAINED DECODING, not by
 * instruction. The speaker composes sentences freely, but every fact
 * position can only be filled from that person's actual memories: it
 * physically lacks a vocabulary for a brother who does not exist. The
 * ratification also fixed how it is proved - "no emitted sentence may
 * assert a fact absent from the input claim set, verified mechanically
 * over test corpora, not by review" - which is Border 120.
 *
 * There is no model yet, and this is deliberately built before one.
 * The fence is the thing that makes a wrong model harmless, so it
 * exists first and is proved on its own; a speaker that arrives later
 * is handed a vocabulary it cannot escape rather than being asked to
 * behave.
 *
 * THE SLOTS ARE NOT INVENTED. A slot is a field of the knowledge
 * surface's own facts (SAO_Knowledge: a zombie sighting's count and
 * where and how old, a dead person's name and who said so, a house's
 * name and leader, a life's birth year and war and region), and the
 * values permitted in it are the values that field actually has in
 * THIS person's claims. Nobody wrote a taxonomy: the fence is the
 * claim set, read sideways.
 *
 * The wire format is deliberately dull and flat, because it crosses
 * from Lua and has to be cheap: "field=value" pairs separated by
 * newlines, values trimmed, empties dropped. A field with no claims is
 * a slot with no vocabulary, and a slot with no vocabulary can never
 * be filled - which is the correct answer for a person who knows
 * nothing about that.
 */
public final class SAOFence {

    private SAOFence() {
    }

    /** Read a claim set into what each slot may hold. */
    public static Map<String, Set<String>> fence(String claims) {
        Map<String, Set<String>> allowed = new LinkedHashMap<>();
        if (claims == null || claims.isEmpty()) {
            return allowed;
        }
        for (String line : claims.split("\n")) {
            int at = line.indexOf('=');
            if (at <= 0) {
                continue;
            }
            String field = line.substring(0, at).trim();
            String value = line.substring(at + 1).trim();
            if (field.isEmpty() || value.isEmpty()) {
                continue;
            }
            allowed.computeIfAbsent(field, key -> new LinkedHashSet<>()).add(value);
        }
        return allowed;
    }

    /**
     * May this value be placed in this slot, for a person holding these
     * claims? An unknown field is not a permissive default: a slot
     * nobody has claims for cannot be filled at all.
     *
     * The comparison is exact after trimming. It is deliberately NOT
     * fuzzy: a name one letter different is a different person, and a
     * fence that accepts near-misses is a fence with a hole the exact
     * width of a plausible lie.
     */
    public static boolean permits(String claims, String field, String value) {
        if (field == null || value == null) {
            return false;
        }
        Set<String> allowed = fence(claims).get(field.trim());
        return allowed != null && allowed.contains(value.trim());
    }

    /**
     * Every part of a proposed filling that the person could not have
     * said, as "field=value" lines. Empty means the whole sentence is
     * sayable by this person. The filling uses the same flat format as
     * the claims.
     */
    public static String violations(String claims, String filling) {
        Map<String, Set<String>> allowed = fence(claims);
        List<String> bad = new ArrayList<>();
        if (filling == null || filling.isEmpty()) {
            return "";
        }
        for (String line : filling.split("\n")) {
            int at = line.indexOf('=');
            if (at <= 0) {
                continue;
            }
            String field = line.substring(0, at).trim();
            String value = line.substring(at + 1).trim();
            if (field.isEmpty() || value.isEmpty()) {
                continue;
            }
            Set<String> here = allowed.get(field);
            if (here == null || !here.contains(value)) {
                bad.add(field + "=" + value);
            }
        }
        return String.join("\n", bad);
    }

    /** Whether a whole filling is sayable. */
    public static boolean sayable(String claims, String filling) {
        return violations(claims, filling).isEmpty();
    }

    /**
     * What the speaker may draw on, slot by slot, as
     * "field:v1|v2|v3" lines. This is the vocabulary a decoder is
     * handed - the fence stated positively - and it is what makes the
     * constraint physical rather than advisory.
     */
    public static String vocabulary(String claims) {
        StringBuilder out = new StringBuilder();
        for (Map.Entry<String, Set<String>> slot : fence(claims).entrySet()) {
            if (out.length() > 0) {
                out.append('\n');
            }
            out.append(slot.getKey()).append(':')
               .append(String.join("|", slot.getValue()));
        }
        return out.toString();
    }

    /** How many slots and how many values in total - the size of what
     *  this person can say, for the log and the panel. */
    public static String measure(String claims) {
        Map<String, Set<String>> allowed = fence(claims);
        int values = 0;
        for (Set<String> slot : allowed.values()) {
            values += slot.size();
        }
        return "slots=" + allowed.size() + " values=" + values;
    }
}
