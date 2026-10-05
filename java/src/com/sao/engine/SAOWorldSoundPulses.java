package com.sao.engine;

import java.lang.ref.WeakReference;
import java.util.LinkedHashMap;
import java.util.HashSet;
import java.util.Objects;
import java.util.UUID;
import java.util.WeakHashMap;
import zombie.WorldSoundManager.WorldSound;
import zombie.characters.IsoGameCharacter;
import zombie.iso.IsoCell;
import se.krka.kahlua.vm.KahluaTable;

/** Occurrences, not emitter identities. The init hook also covers pooled reuse. */
public final class SAOWorldSoundPulses {
    private static final int MAX_PULSES = 4096;
    private static final int MAX_HEARD = 64;
    // Bounded acquisition custody, not a learned hearing or pleasure estimate.
    private static final double CLAIM_HORIZON_HOURS = 0.05;
    private static final WeakHashMap<WorldSound, Pulse> PULSES = new WeakHashMap<>();
    private static final WeakHashMap<WorldSound, Emission> EMISSIONS = new WeakHashMap<>();
    private static final WeakHashMap<IsoGameCharacter, Heard> HEARD = new WeakHashMap<>();
    private static String epoch = UUID.randomUUID().toString();
    private static long next;

    public record Pulse(String id, long sequence, int x, int y, int z) {}
    private record Emission(Pulse pulse, WeakReference<IsoGameCharacter> body,
            WeakReference<IsoCell> cell, String actorId, Object bodyToken,
            String workId, double atHours, WeakHashMap<IsoGameCharacter, Boolean> claims) {}
    private static final class Heard {
        final WeakReference<IsoCell> cell;
        final Object actorId, bodyToken;
        final LinkedHashMap<String, Pulse> pulses = new LinkedHashMap<>();
        final LinkedHashMap<String, Double> acquiredAt = new LinkedHashMap<>();
        final HashSet<String> claimed = new HashSet<>();
        final LinkedHashMap<String, Double> witnessedAt = new LinkedHashMap<>();
        Heard(IsoGameCharacter body) {
            cell = new WeakReference<>(body.getCell());
            actorId = body.getModData().rawget("SAOPersonId");
            bodyToken = body.getModData().rawget("SAOExternalToken");
        }
        boolean owns(IsoGameCharacter body) {
            return cell.get() == body.getCell()
                && Objects.equals(actorId, body.getModData().rawget("SAOPersonId"))
                && Objects.equals(bodyToken, body.getModData().rawget("SAOExternalToken"));
        }
    }
    private SAOWorldSoundPulses() {}

    /** Called once after the installed final init overload returns normally. */
    public static synchronized void initialized(Object value) {
        if (!(value instanceof WorldSound sound)) return;
        EMISSIONS.remove(sound); // A pooled object's new init is another occurrence.
        if (PULSES.size() >= MAX_PULSES && !PULSES.containsKey(sound)) {
            // Missing occurrence evidence is safer than relabeling old sound.
            var iterator = PULSES.keySet().iterator();
            if (iterator.hasNext()) { EMISSIONS.remove(iterator.next()); iterator.remove(); }
        }
        long sequence = ++next;
        PULSES.put(sound, new Pulse(epoch + "-" + sequence, sequence,
            sound.x, sound.y, sound.z));
    }

    /** The scanner calls this only after this observer passes audible access. */
    public static synchronized String heard(IsoGameCharacter observer, WorldSound sound) {
        Pulse pulse = PULSES.get(sound);
        if (pulse == null || observer == null || observer.getCell() == null) return null;
        Heard heard = HEARD.get(observer);
        if (heard == null || !heard.owns(observer)) {
            heard = new Heard(observer); HEARD.put(observer, heard);
        }
        heard.pulses.put(pulse.id(), pulse);
        heard.acquiredAt.putIfAbsent(pulse.id(), now());
        Emission emission = EMISSIONS.get(sound);
        if (emission != null && emission.body().get() instanceof IsoGameCharacter emitter
                && SAOPerceptionScanner.canSeePersonNow(observer, emitter, 16)) {
            heard.witnessedAt.putIfAbsent(pulse.id(), now());
        }
        while (heard.pulses.size() > MAX_HEARD) {
            var iterator = heard.pulses.keySet().iterator(); String old = iterator.next(); iterator.remove();
            heard.acquiredAt.remove(old); heard.claimed.remove(old);
            heard.witnessedAt.remove(old);
        }
        return pulse.id();
    }

    static synchronized Pulse acquired(IsoGameCharacter observer, String id, float x, float y) {
        Heard heard = HEARD.get(observer);
        if (heard == null || !heard.owns(observer)) return null;
        Pulse pulse = heard.pulses.get(id);
        return pulse != null && x == pulse.x() && y == pulse.y() ? pulse : null;
    }

    private static double now() { return zombie.GameTime.getInstance().getWorldAgeHours(); }
    private static String actor(IsoGameCharacter body) {
        if (!SAOSenses.awakeHuman(body) || body.getCell() == null || body.getCurrentSquare() == null) return null;
        Object id = body.getModData().rawget("SAOPersonId");
        return id instanceof String text && !text.isEmpty() && text.length() <= 160 ? text : null;
    }
    private static KahluaTable table() { return zombie.Lua.LuaManager.platform.newTable(); }
    private static KahluaTable emissionView(Emission emission) {
        KahluaTable out = table();
        out.rawset("schema", "sao.instrument-occurrence/1");
        out.rawset("clock", "native-world-age-hours");
        out.rawset("actorId", emission.actorId()); out.rawset("workId", emission.workId());
        out.rawset("pulseId", emission.pulse().id()); out.rawset("epoch", epoch);
        out.rawset("sequence", (double)emission.pulse().sequence());
        out.rawset("emittedAtHours", emission.atHours()); return out;
    }

    /** Called by the exact Gesture native emission owner; never manufactures a pulse. */
    public static synchronized KahluaTable bindInstrument(Object candidate, Object value, String workId) {
        if (!(candidate instanceof IsoGameCharacter body) || !(value instanceof WorldSound sound)) return null;
        String id = actor(body); Pulse pulse = PULSES.get(sound); double at = now();
        if (id == null || pulse == null || sound.source != body || workId == null
                || !workId.startsWith("instrument:" + id + ":") || workId.length() > 224
                || !Double.isFinite(at) || at < 0) return null;
        Emission old = EMISSIONS.get(sound);
        if (old != null) return old.body().get() == body && old.workId().equals(workId)
            && old.pulse() == pulse ? emissionView(old) : null;
        Emission emission = new Emission(pulse, new WeakReference<>(body),
            new WeakReference<>(body.getCell()), id, body.getModData().rawget("SAOExternalToken"), workId, at,
            new WeakHashMap<>());
        EMISSIONS.put(sound, emission); return emissionView(emission);
    }

    /** Consume only this observer's previously scanner-acquired exact occurrence. */
    public static synchronized KahluaTable claimInstrument(Object candidate, Object performer,
            String workId, String pulseId) {
        if (!(candidate instanceof IsoGameCharacter observer) || !(performer instanceof IsoGameCharacter body)
                || observer == body || workId == null || pulseId == null) return null;
        String observerId = actor(observer), performerId = actor(body); double at = now();
        if (observerId == null || performerId == null || SAOSenses.hearing(observer, true) <= 0
                || observer.getCell() != body.getCell() || !Double.isFinite(at) || at < 0
                || !SAOPerceptionScanner.canSeePersonNow(observer, body, 16)) return null;
        Heard heard = HEARD.get(observer);
        if (heard == null || !heard.owns(observer) || heard.claimed.contains(pulseId)) return null;
        Pulse acquired = heard.pulses.get(pulseId); Double heardAt = heard.acquiredAt.get(pulseId);
        Double witnessedAt = heard.witnessedAt.get(pulseId);
        if (acquired == null || heardAt == null || !Double.isFinite(heardAt) || heardAt > at
                || at - heardAt > CLAIM_HORIZON_HOURS || witnessedAt == null
                || !Double.isFinite(witnessedAt) || witnessedAt < heardAt || witnessedAt > at) return null;
        for (var entry : EMISSIONS.entrySet()) {
            Emission emission = entry.getValue();
            if (emission.pulse() != acquired || !emission.workId().equals(workId)
                    || emission.claims().containsKey(observer)
                    || emission.body().get() != body || !emission.actorId().equals(performerId)
                    || emission.cell().get() != body.getCell() || PULSES.get(entry.getKey()) != acquired
                    || entry.getKey().source != body
                    || !Objects.equals(emission.bodyToken(), body.getModData().rawget("SAOExternalToken"))
                    || emission.atHours() > heardAt || at - emission.atHours() > CLAIM_HORIZON_HOURS) continue;
            KahluaTable out = emissionView(emission);
            out.rawset("schema", "sao.instrument-hearing/1");
            out.rawset("observerId", observerId); out.rawset("heardAtHours", heardAt);
            out.rawset("witnessedAtHours", witnessedAt);
            out.rawset("atHours", at); out.rawset("basis", "native-scanner-acquired-occurrence");
            heard.claimed.add(pulseId); emission.claims().put(observer, true); return out;
        }
        return null;
    }

    public static synchronized void forget(IsoGameCharacter observer) { HEARD.remove(observer); }

    public static synchronized void resetRuntimeForWorld() {
        PULSES.clear(); EMISSIONS.clear(); HEARD.clear(); next = 0; epoch = UUID.randomUUID().toString();
    }
}
