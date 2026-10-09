package com.sao.engine;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.DataInputStream;
import java.io.DataOutputStream;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.LinkOption;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.nio.file.StandardOpenOption;
import java.nio.channels.FileChannel;
import java.nio.ByteBuffer;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.util.Arrays;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import zombie.ZomboidFileSystem;
import zombie.network.GameClient;

/** Save-local, server/SP-only Week One transaction data. No GlobalModData mirror. */
public final class SAOWeekOnePrivateStore {
    private static final String FILE = "SAOWeekOnePrivate.v1";
    private static final String SAVE_ID_FILE = "SAOWeekOneSaveId.v1";
    private static final int MAGIC = 0x53415731;
    private static final int VERSION = 1;
    private static final int SAVE_ID_MAGIC = 0x53415749;
    private static final int SAVE_ID_BYTES = 72;
    private static final int MAX_BYTES = 4 * 1024 * 1024;
    private static final int MAX_ROWS = 10_000;
    private static final long RELEASE_NANOS = 60_000_000_000L;
    private static final String REINFORCEMENT = "VBandit.schedule/SpawnGroup";
    private static final String SCENARIO = "VBandit.setup/SpawnGroupArea";
    private static final String START = "BWOEvents.Start/StartBabe";
    private static final SecureRandom random = new SecureRandom();
    private static final Map<String, Long> freshReservations = new HashMap<>();

    private SAOWeekOnePrivateStore() { }

    public static synchronized void resetRuntimeForWorld() {
        freshReservations.clear();
    }

    public static synchronized String retirement(String action, String token,
            String personId, double id, double born, String accountKey,
            String playerKey, double descriptorId, String forename,
            String surname, String world, String gameMode) {
        if (GameClient.client) return "REFUSED";
        try {
            Owner owner = owner(accountKey, playerKey, descriptorId,
                forename, surname, world, gameMode);
            check(token, 512, false);
            check(personId, 256, false);
            finite(id, false);
            finite(born, true);
            if (action == null || !(action.equals("prepare")
                    || action.equals("finish") || action.equals("status"))) return "REFUSED";
            Path save = saveDirectory();
            Store data = read(save);
            Retirement row = data.retirements.get(token);
            if (row != null && !row.exact(token, personId, id, born, owner))
                return "REFUSED";
            if (action.equals("status"))
                return row == null ? "MISSING" : row.retired ? "RETIRED" : "PREPARED";
            if (action.equals("finish")) {
                if (row == null) return "MISSING";
                if (row.retired) return "RETIRED";
                data.retirements.put(token, row.advance(owner));
                write(save, data);
                return "RETIRED";
            }
            if (row != null) {
                if (!row.owner.playerKey.equals(owner.playerKey)) {
                    data.retirements.put(token, row.withOwner(owner));
                    write(save, data);
                }
                return row.retired ? "RETIRED" : "PREPARED";
            }
            if (data.count() >= MAX_ROWS) return "REFUSED";
            for (Retirement old : data.retirements.values()) {
                if (Double.doubleToLongBits(old.id) == Double.doubleToLongBits(id)
                        && Double.doubleToLongBits(old.born) == Double.doubleToLongBits(born))
                    return "REFUSED";
            }
            data.retirements.put(token,
                new Retirement(token, personId, id, born, owner, false));
            write(save, data);
            return "PREPARED";
        } catch (Exception refused) {
            return "REFUSED";
        }
    }

    public static synchronized String reinforcement(String action,
            String source, String cohort, double count, String accountKey,
            String playerKey, double descriptorId, String forename,
            String surname, String world, String gameMode) {
        if (GameClient.client) return "REFUSED";
        try {
            if (!REINFORCEMENT.equals(source)) return "REFUSED";
            check(cohort, 240, false);
            int size = integer(count, 1, 64);
            Owner owner = owner(accountKey, playerKey, descriptorId,
                forename, surname, world, gameMode);
            Path save = saveDirectory();
            Store data = read(save);
            String key = owner.stable() + "|" + cohort;
            Reinforcement row = data.reinforcements.get(key);
            if (row != null && (!row.source.equals(source)
                    || !row.cohort.equals(cohort) || row.count != size
                    || !row.owner.matches(owner))) return "REFUSED";
            String fresh = freshKey(save, "reinforcement", key, size, owner);
            if ("status".equals(action)) return row == null ? "MISSING" : "RESERVED";
            if ("release".equals(action)) {
                if (row == null) return "MISSING";
                if (!fresh(fresh)) return "REFUSED";
                data.reinforcements.remove(key);
                write(save, data);
                freshReservations.remove(fresh);
                return "RELEASED";
            }
            if (!"reserve".equals(action)) return "REFUSED";
            if (row != null) {
                freshReservations.remove(fresh);
                if (!row.owner.playerKey.equals(owner.playerKey)) {
                    data.reinforcements.put(key, new Reinforcement(source,
                        cohort, size, owner));
                    write(save, data);
                }
                return "DUPLICATE";
            }
            if (data.count() >= MAX_ROWS) return "REFUSED";
            data.reinforcements.put(key, new Reinforcement(source, cohort,
                size, owner));
            write(save, data);
            markFresh(fresh);
            return "RESERVED";
        } catch (Exception refused) {
            return "REFUSED";
        }
    }

    public static synchronized String scenario(String action, String source,
            String cohort, double ordinal, String accountKey, String playerKey,
            double descriptorId, String forename, String surname,
            String world, String gameMode) {
        if (GameClient.client) return "REFUSED";
        try {
            if (!SCENARIO.equals(source)) return "REFUSED";
            check(cohort, 240, false);
            int index = integer(ordinal, 1, 24);
            int bit = 1 << (index - 1);
            Owner owner = owner(accountKey, playerKey, descriptorId,
                forename, surname, world, gameMode);
            Path save = saveDirectory();
            Store data = read(save);
            String key = owner.stable();
            Scenario row = data.scenarios.get(key);
            if (row != null && (!row.source.equals(source)
                    || !row.cohort.equals(cohort)
                    || !row.owner.matches(owner))) return "REFUSED";
            String fresh = freshKey(save, "scenario", key, index, owner);
            boolean seen = row != null && (row.seenMask & bit) != 0;
            if ("status".equals(action)) return seen ? "RESERVED" : "MISSING";
            if ("release".equals(action)) {
                if (!seen) return "MISSING";
                if (!fresh(fresh)) return "REFUSED";
                int next = row.seenMask & ~bit;
                if (next == 0) data.scenarios.remove(key);
                else data.scenarios.put(key,
                    new Scenario(source, cohort, row.owner, next));
                write(save, data);
                freshReservations.remove(fresh);
                return "RELEASED";
            }
            if (!"reserve".equals(action)) return "REFUSED";
            if (seen) {
                freshReservations.remove(fresh);
                return "DUPLICATE";
            }
            if (row == null && data.count() >= MAX_ROWS) return "REFUSED";
            data.scenarios.put(key, new Scenario(source, cohort, owner,
                (row == null ? 0 : row.seenMask) | bit));
            write(save, data);
            markFresh(fresh);
            return "RESERVED";
        } catch (Exception refused) {
            return "REFUSED";
        }
    }

    /** Return only an opaque crosswalk, bound to a real server-verified owner. */
    public static synchronized String ownerReceipt(String action, String source,
            double id, double born, String accountKey, String playerKey,
            double descriptorId, String forename, String surname,
            String world, String gameMode) {
        if (GameClient.client) return "REFUSED";
        try {
            if (!(REINFORCEMENT.equals(source) || SCENARIO.equals(source)
                    || START.equals(source))) return "REFUSED";
            finite(id, false); finite(born, true);
            Owner owner = owner(accountKey, playerKey, descriptorId,
                forename, surname, world, gameMode);
            Path save = saveDirectory();
            Store data = read(save);
            String key = part(source) + part(Double.doubleToLongBits(id))
                + part(Double.doubleToLongBits(born));
            OwnerReceipt row = data.ownerReceipts.get(key);
            if (row != null && !row.owner.matches(owner)) return "REFUSED";
            if ("get".equals(action))
                return row == null ? "MISSING" : "MATCHED\t" + row.eventRef;
            if (!"put".equals(action)) return "REFUSED";
            if (row != null) {
                if (!row.owner.playerKey.equals(owner.playerKey)) {
                    data.ownerReceipts.put(key, row.withOwner(owner));
                    write(save, data);
                }
                return "DUPLICATE\t" + row.eventRef;
            }
            if (data.count() >= MAX_ROWS) return "REFUSED";
            String ref;
            do {
                byte[] bytes = new byte[16];
                random.nextBytes(bytes);
                ref = java.util.HexFormat.of().formatHex(bytes);
            } while (containsRef(data, ref));
            data.ownerReceipts.put(key,
                new OwnerReceipt(source, id, born, owner, ref));
            write(save, data);
            return "STORED\t" + ref;
        } catch (Exception refused) {
            return "REFUSED";
        }
    }

    private static Path saveDirectory() throws IOException {
        String raw = ZomboidFileSystem.instance.getCurrentSaveDir();
        if (raw == null || raw.isBlank()) throw new IOException("no current save");
        Path path = Path.of(raw);
        if (!path.isAbsolute() || !Files.isDirectory(path))
            throw new IOException("save directory unavailable");
        return path.toRealPath();
    }

    private static Store read(Path save) throws Exception {
        Path path = save.resolve(FILE);
        Path identityPath = save.resolve(SAVE_ID_FILE);
        boolean hasSidecar = Files.exists(path, LinkOption.NOFOLLOW_LINKS);
        boolean hasIdentity = Files.exists(identityPath, LinkOption.NOFOLLOW_LINKS);
        // An old path-bound sidecar or an interrupted pair cannot become fresh state.
        if (!hasSidecar && !hasIdentity) return new Store();
        if (!hasSidecar || !hasIdentity)
            throw new IOException("incomplete save-local private store");
        byte[] identity = readSaveIdentity(identityPath);
        if (Files.isSymbolicLink(path) || !Files.isRegularFile(path))
            throw new IOException("invalid sidecar file");
        long length = Files.size(path);
        if (length < 88 || length > MAX_BYTES) throw new IOException("invalid sidecar size");
        byte[] bytes = Files.readAllBytes(path);
        byte[] content = Arrays.copyOf(bytes, bytes.length - 32);
        byte[] expected = Arrays.copyOfRange(bytes, bytes.length - 32, bytes.length);
        if (!MessageDigest.isEqual(expected, hash(content)))
            throw new IOException("invalid sidecar digest");
        try (DataInputStream in = new DataInputStream(new ByteArrayInputStream(content))) {
            if (in.readInt() != MAGIC || in.readInt() != VERSION)
                throw new IOException("unsupported sidecar version");
            byte[] bound = new byte[32];
            in.readFully(bound);
            if (!MessageDigest.isEqual(bound, identity))
                throw new IOException("sidecar save mismatch");
            Store data = new Store();
            data.identity = identity;
            int retirements = count(in.readInt());
            for (int i = 0; i < retirements; i++) {
                String token = checked(in.readUTF(), 512, false);
                String person = checked(in.readUTF(), 256, false);
                double id = finite(in.readDouble(), false);
                double born = finite(in.readDouble(), true);
                Owner owner = readOwner(in);
                int state = in.readUnsignedByte();
                if (state != 1 && state != 2) throw new IOException("retirement state");
                if (data.retirements.putIfAbsent(token,
                    new Retirement(token, person, id, born, owner, state == 2)) != null)
                    throw new IOException("duplicate retirement");
            }
            int reinforcements = count(in.readInt());
            for (int i = 0; i < reinforcements; i++) {
                String source = checked(in.readUTF(), 80, false);
                String cohort = checked(in.readUTF(), 240, false);
                int size = integer(in.readInt(), 1, 64);
                Owner owner = readOwner(in);
                if (!REINFORCEMENT.equals(source) || data.reinforcements.putIfAbsent(
                    owner.stable() + "|" + cohort,
                    new Reinforcement(source, cohort, size, owner)) != null)
                    throw new IOException("duplicate reinforcement");
            }
            int scenarios = count(in.readInt());
            for (int i = 0; i < scenarios; i++) {
                String source = checked(in.readUTF(), 80, false);
                String cohort = checked(in.readUTF(), 240, false);
                Owner owner = readOwner(in);
                int seen = in.readInt();
                if (!SCENARIO.equals(source) || seen == 0
                        || (seen & ~0x00ffffff) != 0
                        || data.scenarios.putIfAbsent(owner.stable(),
                            new Scenario(source, cohort, owner, seen)) != null)
                    throw new IOException("invalid scenario");
            }
            int receipts = count(in.readInt());
            var refs = new HashSet<String>();
            for (int i = 0; i < receipts; i++) {
                String source = checked(in.readUTF(), 80, false);
                double id = finite(in.readDouble(), false);
                double born = finite(in.readDouble(), true);
                Owner owner = readOwner(in);
                String ref = checked(in.readUTF(), 32, false);
                if (!(REINFORCEMENT.equals(source) || SCENARIO.equals(source)
                        || START.equals(source))
                        || !ref.matches("[0-9a-f]{32}") || !refs.add(ref))
                    throw new IOException("invalid owner receipt");
                String key = part(source) + part(Double.doubleToLongBits(id))
                    + part(Double.doubleToLongBits(born));
                if (data.ownerReceipts.putIfAbsent(key,
                    new OwnerReceipt(source, id, born, owner, ref)) != null)
                    throw new IOException("duplicate owner receipt");
            }
            if (data.count() > MAX_ROWS || in.available() != 0)
                throw new IOException("sidecar trailing or oversized");
            var generations = new HashSet<String>();
            for (Retirement row : data.retirements.values()) {
                String generation = Double.doubleToLongBits(row.id) + ":"
                    + Double.doubleToLongBits(row.born);
                if (!generations.add(generation))
                    throw new IOException("duplicate brain generation");
            }
            return data;
        }
    }

    private static void write(Path save, Store data) throws Exception {
        if (!save.equals(saveDirectory())) throw new IOException("current save changed");
        Path target = save.resolve(FILE);
        Path identityPath = save.resolve(SAVE_ID_FILE);
        boolean hasSidecar = Files.exists(target, LinkOption.NOFOLLOW_LINKS);
        boolean hasIdentity = Files.exists(identityPath, LinkOption.NOFOLLOW_LINKS);
        byte[] identity;
        if (data.identity == null) {
            if (hasSidecar || hasIdentity)
                throw new IOException("private store appeared after read");
            identity = new byte[32];
            random.nextBytes(identity);
        } else {
            if (!hasSidecar || !hasIdentity)
                throw new IOException("incomplete save-local private store");
            identity = readSaveIdentity(identityPath);
            if (!MessageDigest.isEqual(data.identity, identity))
                throw new IOException("save identity changed after read");
        }
        ByteArrayOutputStream bytes = new ByteArrayOutputStream();
        try (DataOutputStream out = new DataOutputStream(bytes)) {
            out.writeInt(MAGIC);
            out.writeInt(VERSION);
            out.write(identity);
            out.writeInt(data.retirements.size());
            for (Retirement row : data.retirements.values()) {
                out.writeUTF(row.token); out.writeUTF(row.personId);
                out.writeDouble(row.id); out.writeDouble(row.born);
                writeOwner(out, row.owner); out.writeByte(row.retired ? 2 : 1);
            }
            out.writeInt(data.reinforcements.size());
            for (Reinforcement row : data.reinforcements.values()) {
                out.writeUTF(row.source); out.writeUTF(row.cohort);
                out.writeInt(row.count); writeOwner(out, row.owner);
            }
            out.writeInt(data.scenarios.size());
            for (Scenario row : data.scenarios.values()) {
                out.writeUTF(row.source); out.writeUTF(row.cohort);
                writeOwner(out, row.owner); out.writeInt(row.seenMask);
            }
            out.writeInt(data.ownerReceipts.size());
            for (OwnerReceipt row : data.ownerReceipts.values()) {
                out.writeUTF(row.source); out.writeDouble(row.id);
                out.writeDouble(row.born); writeOwner(out, row.owner);
                out.writeUTF(row.eventRef);
            }
        }
        byte[] content = bytes.toByteArray();
        if (content.length + 32 > MAX_BYTES) throw new IOException("sidecar full");
        if (Files.exists(target, LinkOption.NOFOLLOW_LINKS)
                && (Files.isSymbolicLink(target) || !Files.isRegularFile(target)))
            throw new IOException("invalid sidecar target");
        Path temp = Files.createTempFile(save, "sao-week-one-private-", ".tmp");
        try {
            try (var channel = java.nio.channels.FileChannel.open(temp,
                    java.nio.file.StandardOpenOption.WRITE)) {
                var output = java.nio.ByteBuffer.wrap(content);
                while (output.hasRemaining()) channel.write(output);
                output = java.nio.ByteBuffer.wrap(hash(content));
                while (output.hasRemaining()) channel.write(output);
                channel.force(true);
            }
            if (data.identity == null) createSaveIdentity(identityPath, identity);
            Files.move(temp, target, StandardCopyOption.ATOMIC_MOVE,
                StandardCopyOption.REPLACE_EXISTING);
            data.identity = identity;
        } finally {
            Files.deleteIfExists(temp);
        }
    }

    private static void createSaveIdentity(Path path, byte[] identity) throws Exception {
        ByteArrayOutputStream bytes = new ByteArrayOutputStream();
        try (DataOutputStream out = new DataOutputStream(bytes)) {
            out.writeInt(SAVE_ID_MAGIC);
            out.writeInt(VERSION);
            out.write(identity);
        }
        byte[] content = bytes.toByteArray();
        Path temp = Files.createTempFile(path.getParent(),
            "sao-week-one-save-id-", ".tmp");
        try {
            try (FileChannel channel = FileChannel.open(temp,
                    StandardOpenOption.WRITE)) {
                ByteBuffer output = ByteBuffer.wrap(content);
                while (output.hasRemaining()) channel.write(output);
                output = ByteBuffer.wrap(hash(content));
                while (output.hasRemaining()) channel.write(output);
                channel.force(true);
            }
            Files.createLink(path, temp);
        } finally {
            Files.deleteIfExists(temp);
        }
    }

    private static byte[] readSaveIdentity(Path path) throws Exception {
        if (Files.isSymbolicLink(path) || !Files.isRegularFile(path)
                || Files.size(path) != SAVE_ID_BYTES)
            throw new IOException("invalid save identity file");
        byte[] bytes = Files.readAllBytes(path);
        if (bytes.length != SAVE_ID_BYTES)
            throw new IOException("invalid save identity size");
        byte[] content = Arrays.copyOf(bytes, bytes.length - 32);
        if (!MessageDigest.isEqual(Arrays.copyOfRange(bytes,
                bytes.length - 32, bytes.length), hash(content)))
            throw new IOException("invalid save identity digest");
        try (DataInputStream in = new DataInputStream(new ByteArrayInputStream(content))) {
            if (in.readInt() != SAVE_ID_MAGIC || in.readInt() != VERSION)
                throw new IOException("unsupported save identity version");
            byte[] identity = new byte[32];
            in.readFully(identity);
            return identity;
        }
    }

    private static Owner owner(String account, String player, double descriptor,
            String first, String last, String world, String mode) throws IOException {
        check(account, 512, false);
        if (player == null || player.isBlank()) player = account;
        check(player, 512, false);
        check(first, 256, true); check(last, 256, true);
        check(world, 256, false); check(mode, 256, false);
        int number = integer(descriptor, 0, 2_147_483_647);
        return new Owner(account, player, number, first, last, world, mode);
    }

    private static Owner readOwner(DataInputStream in) throws IOException {
        return owner(in.readUTF(), in.readUTF(), in.readInt(), in.readUTF(),
            in.readUTF(), in.readUTF(), in.readUTF());
    }

    private static void writeOwner(DataOutputStream out, Owner owner) throws IOException {
        out.writeUTF(owner.accountKey); out.writeUTF(owner.playerKey);
        out.writeInt(owner.descriptorId); out.writeUTF(owner.forename);
        out.writeUTF(owner.surname); out.writeUTF(owner.world);
        out.writeUTF(owner.gameMode);
    }

    private static int count(int value) throws IOException {
        if (value < 0 || value > MAX_ROWS) throw new IOException("sidecar count");
        return value;
    }

    private static String checked(String value, int max, boolean empty)
            throws IOException {
        check(value, max, empty); return value;
    }

    private static void check(String value, int max, boolean empty) throws IOException {
        if (value == null || value.length() > max || (!empty && value.isBlank())
                || value.indexOf('\0') >= 0) throw new IOException("invalid field");
    }

    private static double finite(double value, boolean negative) throws IOException {
        if (!Double.isFinite(value) || (!negative && value < 0))
            throw new IOException("invalid number");
        return value;
    }

    private static int integer(double value, int min, int max) throws IOException {
        if (!Double.isFinite(value) || value < min || value > max
                || value != Math.rint(value)) throw new IOException("invalid integer");
        return (int) value;
    }

    private static byte[] hash(byte[] input) throws Exception {
        return MessageDigest.getInstance("SHA-256").digest(input);
    }

    private static String freshKey(Path save, String kind, String key,
            int number, Owner owner) {
        return part(save) + part(kind) + part(key) + part(number)
            + part(owner.playerKey);
    }

    private static boolean fresh(String key) {
        Long since = freshReservations.get(key);
        return since != null && System.nanoTime() - since >= 0
            && System.nanoTime() - since <= RELEASE_NANOS;
    }

    private static void markFresh(String key) {
        if (freshReservations.size() >= 128) freshReservations.clear();
        freshReservations.put(key, System.nanoTime());
    }

    private static boolean containsRef(Store data, String ref) {
        for (OwnerReceipt row : data.ownerReceipts.values()) {
            if (row.eventRef.equals(ref)) return true;
        }
        return false;
    }

    private record Owner(String accountKey, String playerKey, int descriptorId,
            String forename, String surname, String world, String gameMode) {
        String stable() {
            return part(accountKey) + part(descriptorId)
                + part(world) + part(gameMode);
        }
        boolean matches(Owner other) {
            return stable().equals(other.stable())
                && forename.equals(other.forename)
                && surname.equals(other.surname)
                && (playerKey.equals(other.playerKey)
                    || playerKey.equals(accountKey));
        }
    }

    private static String part(Object value) {
        String text = String.valueOf(value);
        return text.length() + ":" + text;
    }

    private record Retirement(String token, String personId, double id,
            double born, Owner owner, boolean retired) {
        boolean exact(String otherToken, String otherPerson, double otherId,
                double otherBorn, Owner otherOwner) {
            return token.equals(otherToken) && personId.equals(otherPerson)
                && Double.doubleToLongBits(id) == Double.doubleToLongBits(otherId)
                && Double.doubleToLongBits(born) == Double.doubleToLongBits(otherBorn)
                && owner.matches(otherOwner);
        }
        Retirement withOwner(Owner other) {
            return new Retirement(token, personId, id, born, other, retired);
        }
        Retirement advance(Owner other) {
            return new Retirement(token, personId, id, born, other, true);
        }
    }

    private record Reinforcement(String source, String cohort, int count,
            Owner owner) { }

    private record Scenario(String source, String cohort, Owner owner,
            int seenMask) { }

    private record OwnerReceipt(String source, double id, double born,
            Owner owner, String eventRef) {
        OwnerReceipt withOwner(Owner other) {
            return new OwnerReceipt(source, id, born, other, eventRef);
        }
    }

    private static final class Store {
        byte[] identity;
        final Map<String, Retirement> retirements = new HashMap<>();
        final Map<String, Reinforcement> reinforcements = new HashMap<>();
        final Map<String, Scenario> scenarios = new HashMap<>();
        final Map<String, OwnerReceipt> ownerReceipts = new HashMap<>();
        int count() {
            return retirements.size() + reinforcements.size() + scenarios.size()
                + ownerReceipts.size();
        }
    }
}
