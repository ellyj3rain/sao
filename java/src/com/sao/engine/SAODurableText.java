package com.sao.engine;

import java.nio.ByteBuffer;
import java.nio.CharBuffer;
import java.nio.charset.CharacterCodingException;
import java.nio.charset.CodingErrorAction;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;
import java.util.Set;
import se.krka.kahlua.vm.KahluaTable;
import zombie.Lua.LuaManager;

/** Kahlua's native string length is a signed short of UTF-8 bytes. */
public final class SAODurableText {
    private static final String FORMAT = "sao-durable-text";
    private static final int SHORT_BYTES = 32767, CHUNK_BYTES = 16000;
    // Native v3: a 16 MiB binary envelope, Base64 encoded, with its prefix.
    private static final int MAX_BYTES = 3 + 4 * ((16 * 1024 * 1024 + 2) / 3);
    private static final int MAX_CHUNKS = (MAX_BYTES + CHUNK_BYTES - 1) / CHUNK_BYTES + 1;
    private static final Set<String> KEYS = Set.of("format", "version", "count", "bytes", "sha256", "chunks");

    private SAODurableText() { }

    public static Object pack(String value) {
        byte[] bytes = utf8(value);
        if (bytes.length <= SHORT_BYTES) return value;
        KahluaTable result = LuaManager.platform.newTable();
        KahluaTable chunks = LuaManager.platform.newTable();
        int count = 0;
        for (int start = 0; start < bytes.length;) {
            int end = Math.min(start + CHUNK_BYTES, bytes.length);
            while (end < bytes.length && (bytes[end] & 0xc0) == 0x80) end--;
            chunks.rawset(++count, new String(bytes, start, end - start, StandardCharsets.UTF_8));
            start = end;
        }
        result.rawset("format", FORMAT); result.rawset("version", 1.0);
        result.rawset("count", (double) count); result.rawset("bytes", (double) bytes.length);
        result.rawset("sha256", digest(bytes)); result.rawset("chunks", chunks);
        return result;
    }

    /** Complete validation precedes any native component restoration. */
    public static String unpack(Object value) {
        if (value instanceof String text) { utf8(text); return text; }
        if (!(value instanceof KahluaTable table)) throw invalid("Expected durable text");
        int fields = 0;
        var fieldsIterator = table.iterator();
        while (fieldsIterator.advance()) {
            if (!(fieldsIterator.getKey() instanceof String key) || !KEYS.contains(key))
                throw invalid("Unexpected durable text field");
            fields++;
        }
        if (fields != KEYS.size() || !FORMAT.equals(table.rawget("format"))
                || !Double.valueOf(1).equals(table.rawget("version")))
            throw invalid("Unsupported durable text version");
        int count = integer(table.rawget("count"), 1, MAX_CHUNKS);
        int expectedBytes = integer(table.rawget("bytes"), 1, MAX_BYTES);
        if (!(table.rawget("sha256") instanceof String expectedHash)
                || !expectedHash.matches("[0-9a-f]{64}")
                || !(table.rawget("chunks") instanceof KahluaTable chunks))
            throw invalid("Invalid durable text metadata");
        int keys = 0;
        var iterator = chunks.iterator();
        while (iterator.advance()) { integer(iterator.getKey(), 1, count); keys++; }
        if (keys != count) throw invalid("Missing durable text chunk");
        StringBuilder result = new StringBuilder(expectedBytes);
        int total = 0;
        for (int index = 1; index <= count; index++) {
            if (!(chunks.rawget(index) instanceof String chunk)) throw invalid("Missing durable text chunk");
            byte[] bytes = utf8(chunk);
            if (bytes.length == 0 || bytes.length > CHUNK_BYTES) throw invalid("Invalid durable text chunk size");
            total += bytes.length;
            if (total > expectedBytes) throw invalid("Excess durable text bytes");
            result.append(chunk);
        }
        if (total != expectedBytes) throw invalid("Truncated durable text");
        String text = result.toString();
        if (!expectedHash.equals(digest(utf8(text)))) throw invalid("Durable text checksum mismatch");
        return text;
    }

    private static int integer(Object value, int minimum, int maximum) {
        if (!(value instanceof Double number) || !Double.isFinite(number)
                || number != Math.rint(number) || number < minimum || number > maximum)
            throw invalid("Invalid durable text count/length");
        return ((Double) value).intValue();
    }

    private static byte[] utf8(String value) {
        if (value == null || value.length() > MAX_BYTES) throw invalid("Durable text exceeds bound");
        try {
            ByteBuffer buffer = StandardCharsets.UTF_8.newEncoder()
                .onMalformedInput(CodingErrorAction.REPORT).onUnmappableCharacter(CodingErrorAction.REPORT)
                .encode(CharBuffer.wrap(value));
            if (buffer.remaining() > MAX_BYTES) throw invalid("Durable text exceeds bound");
            byte[] bytes = new byte[buffer.remaining()]; buffer.get(bytes); return bytes;
        } catch (CharacterCodingException error) { throw new IllegalArgumentException("Invalid durable text Unicode", error); }
    }

    private static String digest(byte[] bytes) {
        try { return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(bytes)); }
        catch (NoSuchAlgorithmException error) { throw new IllegalStateException(error); }
    }

    private static IllegalArgumentException invalid(String reason) { return new IllegalArgumentException(reason); }
}
