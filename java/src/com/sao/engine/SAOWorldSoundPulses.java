package com.sao.engine;

import java.lang.ref.WeakReference;
import java.util.LinkedHashMap;
import java.util.UUID;
import java.util.WeakHashMap;
import zombie.WorldSoundManager.WorldSound;
import zombie.characters.IsoGameCharacter;
import zombie.iso.IsoCell;

/** Occurrences, not emitter identities. The init hook also covers pooled reuse. */
public final class SAOWorldSoundPulses {
    private static final int MAX_PULSES = 4096;
    private static final int MAX_HEARD = 64;
    private static final WeakHashMap<WorldSound, Pulse> PULSES = new WeakHashMap<>();
    private static final WeakHashMap<IsoGameCharacter, Heard> HEARD = new WeakHashMap<>();
    private static String epoch = UUID.randomUUID().toString();
    private static long next;

    public record Pulse(String id, long sequence, int x, int y, int z) {}
    private static final class Heard {
        final WeakReference<IsoCell> cell;
        final LinkedHashMap<String, Pulse> pulses = new LinkedHashMap<>();
        Heard(IsoCell value) { cell = new WeakReference<>(value); }
    }
    private SAOWorldSoundPulses() {}

    /** Called once after the installed final init overload returns normally. */
    public static synchronized void initialized(Object value) {
        if (!(value instanceof WorldSound sound)) return;
        if (PULSES.size() >= MAX_PULSES && !PULSES.containsKey(sound)) {
            // Missing occurrence evidence is safer than relabeling old sound.
            var iterator = PULSES.keySet().iterator();
            if (iterator.hasNext()) { iterator.next(); iterator.remove(); }
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
        if (heard == null || heard.cell.get() != observer.getCell()) {
            heard = new Heard(observer.getCell()); HEARD.put(observer, heard);
        }
        heard.pulses.put(pulse.id(), pulse);
        while (heard.pulses.size() > MAX_HEARD) {
            var iterator = heard.pulses.keySet().iterator(); iterator.next(); iterator.remove();
        }
        return pulse.id();
    }

    static synchronized Pulse acquired(IsoGameCharacter observer, String id, float x, float y) {
        Heard heard = HEARD.get(observer);
        if (heard == null || heard.cell.get() != observer.getCell()) return null;
        Pulse pulse = heard.pulses.get(id);
        return pulse != null && x == pulse.x() && y == pulse.y() ? pulse : null;
    }

    public static synchronized void forget(IsoGameCharacter observer) { HEARD.remove(observer); }

    public static synchronized void resetRuntimeForWorld() {
        PULSES.clear(); HEARD.clear(); next = 0; epoch = UUID.randomUUID().toString();
    }
}
