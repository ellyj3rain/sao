package com.sao.engine;

import java.util.ConcurrentModificationException;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Iterator;
import java.util.Map;
import se.krka.kahlua.j2se.KahluaTableImpl;

/** Session-only bounded raw-key iteration for Week One source tables. */
public final class SAOWeekOnePollCursor {
    private static final int MAX_VISITS = 128;
    private static final Map<String, Cursor> streams = new HashMap<>();

    private SAOWeekOnePollCursor() {}

    private static boolean known(String stream) {
        return "ClientCache".equals(stream) || "ClientRows".equals(stream)
            || "ClientPerformanceRows".equals(stream)
            || "source-performance-hearers".equals(stream)
            || "SourceInquiryPersons".equals(stream)
            || "Babe".equals(stream) || "Native".equals(stream);
    }

    private static final class Cursor {
        KahluaTableImpl source;
        Iterator<Map.Entry<Object, Object>> iterator;
        boolean endPending;

        Cursor(KahluaTableImpl source) { replace(source); }

        void replace(KahluaTableImpl next) {
            source = next;
            iterator = next.delegate.entrySet().iterator();
            endPending = false;
        }
    }

    /**
     * Return at most limit raw keys as a dense 1-based Kahlua array. A short
     * nonempty batch ends this pass; the next call returns an empty boundary
     * batch, and the following call starts a new pass on the supplied table.
     * A replacement table does not discard a peer's unfinished pass. Call
     * reset(stream) for an immediate replacement when that is desired.
     */
    public static synchronized KahluaTableImpl entries(Object table,
            String stream, int limit) {
        if (!(table instanceof KahluaTableImpl source) || !known(stream)
                || limit < 1 || limit > MAX_VISITS) return null;
        Cursor cursor = streams.get(stream);
        if (cursor == null) {
            cursor = new Cursor(source);
            streams.put(stream, cursor);
        }
        KahluaTableImpl batch = new KahluaTableImpl(new HashMap<>());
        if (cursor.endPending) {
            cursor.replace(source);
            return batch;
        }

        int attempts = 0;
        int count = 0;
        int restarts = 0;
        boolean exhausted = false;
        HashSet<Object> inBatch = new HashSet<>();
        while (attempts < limit) {
            try {
                if (!cursor.iterator.hasNext()) {
                    exhausted = true;
                    break;
                }
                attempts++;
                Object key = cursor.iterator.next().getKey();
                if (key != null && inBatch.add(key)) batch.rawset(++count, key);
            } catch (ConcurrentModificationException changed) {
                if (++restarts > 1) return null;
                cursor.iterator = cursor.source.delegate.entrySet().iterator();
            } catch (RuntimeException unavailable) {
                return null;
            }
        }
        if (exhausted) {
            if (count > 0) cursor.endPending = true;
            else cursor.replace(source);
        }
        // An empty result after a mutation is not an end-of-pass marker.
        if (count == 0 && attempts > 0 && !exhausted) return null;
        return batch;
    }

    public static synchronized boolean reset(String stream) {
        if (!known(stream)) return false;
        streams.remove(stream);
        return true;
    }

    public static synchronized void resetRuntimeForWorld() {
        streams.clear();
    }
}
