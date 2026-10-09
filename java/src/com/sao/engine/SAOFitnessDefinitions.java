package com.sao.engine;

import java.lang.reflect.Field;
import java.util.HashMap;
import se.krka.kahlua.j2se.KahluaTableImpl;
import zombie.characters.BodyDamage.Fitness;

/** Actor-local equivalent of installed Fitness.init's definition construction.
 * The installed method reads global Lua definitions once and caches native
 * FitnessExercise instances. This adapter preserves that cache and constructor,
 * supplying the selected person's source-derived definitions without changing
 * another actor's Lua environment. Lua admission owns the source provenance.
 */
public final class SAOFitnessDefinitions {
    private SAOFitnessDefinitions() { }
    private static final Field EXERCISES = field(Fitness.class,"exercises");
    private static final Field XP_MODIFIER = field(Fitness.FitnessExercise.class,"xpModifier");
    private static Field field(Class<?> owner,String name) {
        try { Field f=owner.getDeclaredField(name); f.setAccessible(true); return f; }
        catch (ReflectiveOperationException | RuntimeException unavailable) { return null; }
    }
    @SuppressWarnings("unchecked")
    private static HashMap<String,Fitness.FitnessExercise> exercises(SAOIsoPlayerShell body) {
        if (SAOConceptObservation.actor(body)==null || EXERCISES==null
                || body.getFitness().getParent()!=body) return null;
        try { return (HashMap<String,Fitness.FitnessExercise>)EXERCISES.get(body.getFitness()); }
        catch (ReflectiveOperationException | RuntimeException unavailable) { return null; }
    }
    public static boolean initialized(SAOIsoPlayerShell body) {
        var values=exercises(body); return values!=null && !values.isEmpty();
    }
    public static String initialize(SAOIsoPlayerShell body,Object definitions) {
        var values=exercises(body);
        if (values==null) return "unavailable";
        if (!values.isEmpty()) return "retained";
        if (!(definitions instanceof KahluaTableImpl rows) || rows.delegate.isEmpty()
                || rows.delegate.size()>128) return "unavailable";
        var prepared=new HashMap<String,Fitness.FitnessExercise>();
        try {
            for (var entry:rows.delegate.entrySet()) {
                if (!(entry.getKey() instanceof String name) || name.isBlank() || name.length()>96
                        || !(entry.getValue() instanceof KahluaTableImpl row)
                        || !(row.rawget("xpMod") instanceof Number modifier)
                        || !Double.isFinite(modifier.doubleValue()) || modifier.doubleValue()<0
                        || modifier.doubleValue()>100000) return "unavailable";
                prepared.put(name,new Fitness.FitnessExercise(row));
            }
            // Construct every row before publishing any of this person's cache.
            values.putAll(prepared);
            body.getFitness().initRegularityMapProfession();
            return "initialized";
        } catch (RuntimeException unavailable) {
            // A native initialization that became partial remains cached, as in
            // the installed owner. It must not be replayed as an empty attempt.
            return "unavailable";
        }
    }
    public static double xpModifier(SAOIsoPlayerShell body,String name) {
        var values=exercises(body);
        var value=values==null || name==null ? null : values.get(name);
        if (value==null || XP_MODIFIER==null) return Double.NaN;
        try { return XP_MODIFIER.getFloat(value); }
        catch (ReflectiveOperationException | RuntimeException unavailable) { return Double.NaN; }
    }
}
