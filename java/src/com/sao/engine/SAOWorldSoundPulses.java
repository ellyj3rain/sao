package com.sao.engine;

import java.lang.ref.WeakReference;
import java.util.LinkedHashMap;
import java.util.HashSet;
import java.util.Objects;
import java.util.UUID;
import java.util.WeakHashMap;
import zombie.WorldSoundManager.WorldSound;
import zombie.characters.IsoGameCharacter;
import zombie.characters.IsoPlayer;
import zombie.characters.IsoZombie;
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
    private static final WeakHashMap<WorldSound, WeekOneEmission> WEEK_ONE_EMISSIONS = new WeakHashMap<>();
    private static final WeakHashMap<IsoGameCharacter, Heard> HEARD = new WeakHashMap<>();
    private static final WeakHashMap<IsoPlayer, NativeCallout> NATIVE_CALLOUTS = new WeakHashMap<>();
    private static String epoch = UUID.randomUUID().toString();
    private static long next;

    public record Pulse(String id, long sequence, int x, int y, int z) {}
    private record Emission(Pulse pulse, WeakReference<IsoGameCharacter> body,
            WeakReference<IsoCell> cell, String actorId, Object bodyToken,
            String workId, double atHours, WeakHashMap<IsoGameCharacter, Boolean> claims) {}
    private record NativeCallout(Pulse pulse, WeakReference<WorldSound> sound,
            WeakReference<IsoCell> cell) {}
    private record WeekOneEmission(Pulse pulse, WeakReference<IsoZombie> body,
            WeakReference<IsoCell> cell, String actorId, long brainId, double born,
            String soundId, long soundHandle, double atHours,
            WeakHashMap<IsoGameCharacter, Boolean> claims) {}
    private record WeekOneObserver(String id, long brainId, double born) {}
    private static final class Heard {
        final WeakReference<IsoCell> cell;
        final Object actorId, bodyToken;
        final Object weekOneId, weekOneBrainId, weekOneBorn, weekOneOrigin;
        final LinkedHashMap<String, Pulse> pulses = new LinkedHashMap<>();
        final LinkedHashMap<String, Double> acquiredAt = new LinkedHashMap<>();
        final HashSet<String> claimed = new HashSet<>();
        final LinkedHashMap<String, Double> witnessedAt = new LinkedHashMap<>();
        Heard(IsoGameCharacter body) {
            cell = new WeakReference<>(body.getCell());
            actorId = body.getModData().rawget("SAOPersonId");
            bodyToken = body.getModData().rawget("SAOExternalToken");
            weekOneId = body.getModData().rawget("SAOWeekOnePersonId");
            weekOneBrainId = body.getModData().rawget("SAOWeekOneBrainId");
            weekOneBorn = body.getModData().rawget("SAOWeekOneBorn");
            weekOneOrigin = body.getModData().rawget("SAOWeekOneOrigin");
        }
        boolean owns(IsoGameCharacter body) {
            return body.getModData() != null && cell.get() == body.getCell()
                && Objects.equals(actorId, body.getModData().rawget("SAOPersonId"))
                && Objects.equals(bodyToken, body.getModData().rawget("SAOExternalToken"))
                && Objects.equals(weekOneId, body.getModData().rawget("SAOWeekOnePersonId"))
                && Objects.equals(weekOneBrainId, body.getModData().rawget("SAOWeekOneBrainId"))
                && Objects.equals(weekOneBorn, body.getModData().rawget("SAOWeekOneBorn"))
                && Objects.equals(weekOneOrigin, body.getModData().rawget("SAOWeekOneOrigin"));
        }
    }
    private SAOWorldSoundPulses() {}

    /** Called once after the installed final init overload returns normally. */
    public static synchronized void initialized(Object value) {
        if (!(value instanceof WorldSound sound)) return;
        EMISSIONS.remove(sound); // A pooled object's new init is another occurrence.
        WEEK_ONE_EMISSIONS.remove(sound);
        if (PULSES.size() >= MAX_PULSES && !PULSES.containsKey(sound)) {
            // Missing occurrence evidence is safer than relabeling old sound.
            var iterator = PULSES.keySet().iterator();
            if (iterator.hasNext()) {
                WorldSound oldest = iterator.next();
                EMISSIONS.remove(oldest); WEEK_ONE_EMISSIONS.remove(oldest); iterator.remove();
            }
        }
        long sequence = ++next;
        PULSES.put(sound, new Pulse(epoch + "-" + sequence, sequence,
            sound.x, sound.y, sound.z));
    }

    /** Called only at the entry of the installed zero-argument Callout(). */
    public static synchronized long beforeNativeCallout(Object candidate) {
        return candidate instanceof IsoPlayer ? next : -1;
    }

    /** Bind the one native sound emitted during this actual Callout() frame.
     * Multiple matching emissions are ambiguous and give no occurrence. */
    public static synchronized void completedNativeCallout(Object candidate, long before) {
        if (!(candidate instanceof IsoPlayer player) || before < 0 || !player.callOut
                || player.getCell() == null || zombie.WorldSoundManager.instance == null) return;
        WorldSound found = null;
        Pulse occurrence = null;
        for (WorldSound sound : zombie.WorldSoundManager.instance.soundList) {
            if (sound == null || sound.source != player || sound.life <= 0
                    || sound.radius != 6 && sound.radius != 18
                        && sound.radius != 30 && sound.radius != 90
                    || sound.volume != sound.radius || sound.repeating
                    || sound.x != (int) Math.floor(player.getX())
                    || sound.y != (int) Math.floor(player.getY())
                    || sound.z != (int) Math.floor(player.getZ())) continue;
            Pulse pulse = PULSES.get(sound);
            if (pulse == null || pulse.sequence() <= before) continue;
            if (found != null) { NATIVE_CALLOUTS.remove(player); return; }
            found = sound;
            occurrence = pulse;
        }
        if (found == null) { NATIVE_CALLOUTS.remove(player); return; }
        NATIVE_CALLOUTS.put(player, new NativeCallout(occurrence,
            new WeakReference<>(found), new WeakReference<>(player.getCell())));
    }

    /** A pooled object's next init changes its pulse; an expired or removed
     * sound cannot revive the old callout merely because callOut stays true. */
    public static synchronized WorldSound nativeCalloutSound(IsoPlayer player) {
        NativeCallout callout = NATIVE_CALLOUTS.get(player);
        if (callout == null || player == null || !player.callOut
                || callout.cell().get() != player.getCell()
                || zombie.WorldSoundManager.instance == null) return null;
        WorldSound sound = callout.sound().get();
        if (sound != null && sound.life > 0 && sound.source == player
            && PULSES.get(sound) == callout.pulse()
            && sound.x == callout.pulse().x() && sound.y == callout.pulse().y()
            && sound.z == callout.pulse().z()
            && zombie.WorldSoundManager.instance.soundList.contains(sound)) return sound;
        NATIVE_CALLOUTS.remove(player);
        return null;
    }

    public static synchronized String nativeCalloutId(IsoPlayer player) {
        WorldSound sound = nativeCalloutSound(player);
        Pulse pulse = sound == null ? null : PULSES.get(sound);
        return pulse == null ? null : pulse.id();
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
        WeekOneEmission weekOne = WEEK_ONE_EMISSIONS.get(sound);
        IsoGameCharacter emitter = emission != null ? emission.body().get()
            : weekOne != null ? weekOne.body().get() : null;
        if (emitter != null
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

    private static boolean weekOneBody(IsoZombie body, String actorId,
            long brainId, double born) {
        if (body == null || body.isDead() || body.isAsleep()
                || !body.getVariableBoolean("Bandit") || body.getCell() == null
                || body.getCurrentSquare() == null || body.getModData() == null
                || actorId == null || !actorId.startsWith("bwo-")
                || actorId.length() > 160 || !Double.isFinite(born)
                || body.getPersistentOutfitID() != brainId) return false;
        var md = body.getModData();
        Object markedBrain = md.rawget("SAOWeekOneBrainId");
        Object markedBorn = md.rawget("SAOWeekOneBorn");
        return "BanditsWeekOne".equals(md.rawget("SAOWeekOneOrigin"))
            && actorId.equals(md.rawget("SAOWeekOnePersonId"))
            && markedBrain instanceof Number id
            && Double.isFinite(id.doubleValue()) && id.doubleValue() == (double) brainId
            && markedBorn instanceof Number time
            && Double.isFinite(time.doubleValue())
            && Double.compare(time.doubleValue(), born) == 0;
    }

    private static WeekOneObserver weekOneObserver(IsoZombie body) {
        if (body == null || body.getModData() == null) return null;
        var md = body.getModData();
        Object id = md.rawget("SAOWeekOnePersonId");
        Object brain = md.rawget("SAOWeekOneBrainId");
        Object born = md.rawget("SAOWeekOneBorn");
        if (!(id instanceof String personId) || !(brain instanceof Number brainNumber)
                || !(born instanceof Number bornNumber)) return null;
        double brainValue = brainNumber.doubleValue();
        double birthValue = bornNumber.doubleValue();
        if (!Double.isFinite(brainValue) || brainValue != Math.rint(brainValue)
                || brainValue < Integer.MIN_VALUE || brainValue > Integer.MAX_VALUE
                || !weekOneBody(body, personId, (long) brainValue, birthValue)) return null;
        return new WeekOneObserver(personId, (long) brainValue, birthValue);
    }

    private static boolean playing(IsoZombie body, long handle) {
        try { return handle > 0 && body.getEmitter() != null
            && body.getEmitter().isPlaying(handle); }
        catch (Throwable unavailable) { return false; }
    }

    private static KahluaTable weekOneView(WeekOneEmission emission) {
        KahluaTable out = table();
        out.rawset("schema", "sao.weekone-performance-occurrence/1");
        out.rawset("clock", "native-world-age-hours");
        out.rawset("actorId", emission.actorId());
        out.rawset("brainId", (double) emission.brainId());
        out.rawset("born", emission.born());
        out.rawset("soundId", emission.soundId());
        out.rawset("soundHandle", (double) emission.soundHandle());
        out.rawset("pulseId", emission.pulse().id());
        out.rawset("epoch", epoch);
        out.rawset("sequence", (double) emission.pulse().sequence());
        out.rawset("emittedAtHours", emission.atHours());
        return out;
    }

    /** Bind the physical Week One emitter and one native world occurrence.
     * The source action remains the performer; this only permits private hearing. */
    public static synchronized KahluaTable bindWeekOnePerformance(Object candidate,
            Object value, String actorId, double brainNumber, double born,
            String soundId, double handleNumber) {
        if (!(candidate instanceof IsoZombie body) || !(value instanceof WorldSound sound)
                || !Double.isFinite(brainNumber) || brainNumber != Math.rint(brainNumber)
                || brainNumber < Integer.MIN_VALUE || brainNumber > Integer.MAX_VALUE
                || !Double.isFinite(handleNumber) || handleNumber != Math.rint(handleNumber)
                || handleNumber <= 0 || handleNumber > 9007199254740991.0
                || soundId == null || soundId.isEmpty() || soundId.length() > 96) return null;
        long brainId = (long) brainNumber, handle = (long) handleNumber;
        Pulse pulse = PULSES.get(sound);
        double at = now();
        if (!weekOneBody(body, actorId, brainId, born) || !playing(body, handle)
                || pulse == null || sound.source != body || sound.life <= 0
                || sound.radius != 45 || sound.volume != 45 || sound.z != (int) Math.floor(body.getZ())
                || sound.x != (int) Math.floor(body.getX())
                || sound.y != (int) Math.floor(body.getY())
                || zombie.WorldSoundManager.instance == null
                || !zombie.WorldSoundManager.instance.soundList.contains(sound)
                || !Double.isFinite(at) || at < 0 || WEEK_ONE_EMISSIONS.containsKey(sound)) return null;
        WeekOneEmission emission = new WeekOneEmission(pulse, new WeakReference<>(body),
            new WeakReference<>(body.getCell()), actorId, brainId, born,
            soundId, handle, at, new WeakHashMap<>());
        WEEK_ONE_EMISSIONS.put(sound, emission);
        return weekOneView(emission);
    }

    /** The source action renews only its still-playing exact world occurrence. */
    public static synchronized boolean renewWeekOnePerformance(Object candidate,
            String pulseId) {
        if (!(candidate instanceof IsoZombie body) || pulseId == null) return false;
        for (var entry : WEEK_ONE_EMISSIONS.entrySet()) {
            WeekOneEmission emission = entry.getValue();
            WorldSound sound = entry.getKey();
            if (emission.body().get() != body || !pulseId.equals(emission.pulse().id())) continue;
            if (!weekOneBody(body, emission.actorId(), emission.brainId(), emission.born())
                    || !playing(body, emission.soundHandle()) || sound.source != body
                    || sound.life <= 0 || PULSES.get(sound) != emission.pulse()
                    || emission.cell().get() != body.getCell()
                    || zombie.WorldSoundManager.instance == null
                    || !zombie.WorldSoundManager.instance.soundList.contains(sound)) return false;
            sound.life = 16;
            return true;
        }
        return false;
    }

    /** Retire sound custody without touching a pooled occurrence reused elsewhere. */
    public static synchronized boolean revokeWeekOnePerformance(Object candidate,
            String pulseId) {
        if (!(candidate instanceof IsoZombie body) || pulseId == null) return false;
        for (var iterator = WEEK_ONE_EMISSIONS.entrySet().iterator(); iterator.hasNext();) {
            var entry = iterator.next();
            WeekOneEmission emission = entry.getValue();
            if (emission.body().get() != body || !pulseId.equals(emission.pulse().id())) continue;
            WorldSound sound = entry.getKey();
            if (PULSES.get(sound) == emission.pulse() && sound.source == body) sound.life = 0;
            iterator.remove();
            return true;
        }
        return false;
    }

    /** One observer consumes their scanner-acquired, visibly attributable sound. */
    public static synchronized KahluaTable claimWeekOnePerformance(Object candidate,
            Object performer, String actorId, double brainNumber, double born,
            String pulseId) {
        if (!(candidate instanceof IsoGameCharacter observer)
                || !(performer instanceof IsoZombie body) || observer == body
                || pulseId == null || !Double.isFinite(brainNumber)
                || brainNumber != Math.rint(brainNumber)
                || brainNumber < Integer.MIN_VALUE || brainNumber > Integer.MAX_VALUE) return null;
        WeekOneObserver proxy = observer instanceof IsoZombie zombie
            ? weekOneObserver(zombie) : null;
        String observerId = proxy == null ? actor(observer) : proxy.id();
        float hearing = proxy == null ? SAOSenses.hearing(observer, true)
            : SAOSenses.weekOneHearing((IsoZombie) observer);
        double at = now();
        if (observerId == null) { HEARD.remove(observer); return null; }
        if (observerId.equals(actorId)
                || !weekOneBody(body, actorId, (long) brainNumber, born)
                || hearing <= 0 || observer.getCell() != body.getCell()
                || !Double.isFinite(at) || at < 0
                || !SAOPerceptionScanner.canSeePersonNow(observer, body, 16)) return null;
        Heard heard = HEARD.get(observer);
        if (heard == null) return null;
        if (!heard.owns(observer)) { HEARD.remove(observer); return null; }
        if (heard.claimed.contains(pulseId)) return null;
        Pulse acquired = heard.pulses.get(pulseId);
        Double heardAt = heard.acquiredAt.get(pulseId);
        Double witnessedAt = heard.witnessedAt.get(pulseId);
        if (acquired == null || heardAt == null || !Double.isFinite(heardAt)
                || heardAt > at || at - heardAt > CLAIM_HORIZON_HOURS
                || witnessedAt == null || !Double.isFinite(witnessedAt)
                || witnessedAt < heardAt || witnessedAt > at) return null;
        for (var entry : WEEK_ONE_EMISSIONS.entrySet()) {
            WeekOneEmission emission = entry.getValue();
            WorldSound sound = entry.getKey();
            if (emission.pulse() != acquired || !emission.actorId().equals(actorId)
                    || emission.brainId() != (long) brainNumber
                    || Double.compare(emission.born(), born) != 0
                    || emission.claims().containsKey(observer)
                    || emission.body().get() != body || emission.cell().get() != body.getCell()
                    || PULSES.get(sound) != acquired || sound.source != body || sound.life <= 0
                    || zombie.WorldSoundManager.instance == null
                    || !zombie.WorldSoundManager.instance.soundList.contains(sound)
                    || !playing(body, emission.soundHandle())
                    // A renewed performance can outlive the claim window.
                    // Freshness belongs to this listener's scanner acquisition.
                    || emission.atHours() > heardAt) continue;
            KahluaTable out = weekOneView(emission);
            out.rawset("schema", "sao.weekone-performance-hearing/1");
            out.rawset("observerId", observerId);
            if (proxy != null) {
                out.rawset("observerBrainId", (double) proxy.brainId());
                out.rawset("observerBorn", proxy.born());
            }
            out.rawset("heardAtHours", heardAt);
            out.rawset("witnessedAtHours", witnessedAt);
            out.rawset("atHours", at);
            out.rawset("basis", "native-scanner-acquired-occurrence");
            heard.claimed.add(pulseId);
            emission.claims().put(observer, true);
            return out;
        }
        return null;
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
        PULSES.clear(); EMISSIONS.clear(); WEEK_ONE_EMISSIONS.clear();
        HEARD.clear(); NATIVE_CALLOUTS.clear();
        next = 0; epoch = UUID.randomUUID().toString();
    }
}
