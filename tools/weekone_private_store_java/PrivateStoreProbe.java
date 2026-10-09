import com.sao.engine.SAOWeekOnePrivateStore;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.util.Arrays;
import zombie.ZomboidFileSystem;
import zombie.network.GameClient;

public final class PrivateStoreProbe {
    private static int checks;
    private static final String REINFORCEMENT = "VBandit.schedule/SpawnGroup";
    private static final String SCENARIO = "VBandit.setup/SpawnGroupArea";

    private static void check(String name, String expected, String actual) {
        checks++;
        if (!expected.equals(actual))
            throw new AssertionError(name + ": expected " + expected + ", got " + actual);
        System.out.println("PASS " + name);
    }

    private static String retire(String action, String person, String account,
            String player, double descriptor, String mode) {
        return SAOWeekOnePrivateStore.retirement(action, "person:314:5.5:1",
            person, 314, 5.5, account, player, descriptor, "Ava", "Lee",
            "Knox", mode);
    }

    private static String reinforce(String action, String cohort, double count,
            String player) {
        return SAOWeekOnePrivateStore.reinforcement(action, REINFORCEMENT,
            cohort, count, "account-a", player, 7, "Ava", "Lee",
            "Knox", "Sandbox");
    }

    private static String scenario(String action, String cohort,
            double ordinal, String player) {
        return SAOWeekOnePrivateStore.scenario(action, SCENARIO, cohort,
            ordinal, "account-a", player, 7, "Ava", "Lee",
            "Knox", "Sandbox");
    }

    public static void main(String[] args) throws Exception {
        Path root = Path.of(args[0]);
        Path first = Files.createDirectory(root.resolve("first"));
        Path second = Files.createDirectory(root.resolve("second"));
        Path relocated = Files.createDirectory(root.resolve("relocated"));
        Path transplant = Files.createDirectory(root.resolve("transplant"));
        Path interrupted = Files.createDirectory(root.resolve("interrupted"));
        ZomboidFileSystem.instance.directory = first.toString();
        Path sidecar = first.resolve("SAOWeekOnePrivate.v1");
        Path identity = first.resolve("SAOWeekOneSaveId.v1");

        check("empty-retirement", "MISSING",
            retire("status", "person", "account-a", "account-a", 7, "Sandbox"));
        check("finish-needs-prepare", "MISSING",
            retire("finish", "person", "account-a", "account-a", 7, "Sandbox"));
        if (Files.exists(sidecar) || Files.exists(identity))
            throw new AssertionError("fresh read created private store files");
        checks++;
        System.out.println("PASS fresh-read-keeps-pair-absent");
        check("prepare", "PREPARED",
            retire("prepare", "person", "account-a", "account-a", 7, "Sandbox"));
        if (!Files.isRegularFile(sidecar)) throw new AssertionError("save sidecar absent");
        if (!Files.isRegularFile(identity) || Files.size(identity) != 72)
            throw new AssertionError("save identity absent or malformed");
        checks++;
        System.out.println("PASS fresh-store-identity-created");
        check("prepared-readback", "PREPARED",
            retire("status", "person", "account-a", "account-a", 7, "Sandbox"));
        check("person-mismatch", "REFUSED",
            retire("status", "other", "account-a", "account-a", 7, "Sandbox"));
        check("owner-mismatch", "REFUSED",
            retire("finish", "person", "account-b", "account-b", 7, "Sandbox"));
        check("mode-mismatch", "REFUSED",
            retire("status", "person", "account-a", "account-a", 7, "Survival"));
        check("descriptor-mismatch", "REFUSED",
            retire("status", "person", "account-a", "account-a", 8, "Sandbox"));
        check("creator-key-upgrade", "PREPARED",
            retire("prepare", "person", "account-a", "creator-1", 7, "Sandbox"));
        check("different-creator-key", "REFUSED",
            retire("status", "person", "account-a", "creator-2", 7, "Sandbox"));
        check("retire", "RETIRED",
            retire("finish", "person", "account-a", "creator-1", 7, "Sandbox"));
        check("retired-replay", "RETIRED",
            retire("status", "person", "account-a", "creator-1", 7, "Sandbox"));
        check("generation-reuse", "REFUSED", SAOWeekOnePrivateStore.retirement(
            "prepare", "other-token", "other-person", 314, 5.5,
            "account-a", "creator-1", 7, "Ava", "Lee", "Knox", "Sandbox"));

        check("reinforcement-empty", "MISSING",
            reinforce("status", "cohort-a", 4, "account-a"));
        check("reinforcement-reserve", "RESERVED",
            reinforce("reserve", "cohort-a", 4, "account-a"));
        check("reinforcement-readback", "RESERVED",
            reinforce("status", "cohort-a", 4, "account-a"));
        check("reinforcement-count-conflict", "REFUSED",
            reinforce("status", "cohort-a", 5, "account-a"));
        check("reinforcement-immediate-release", "RELEASED",
            reinforce("release", "cohort-a", 4, "account-a"));
        check("reinforcement-release-once", "MISSING",
            reinforce("release", "cohort-a", 4, "account-a"));
        check("reinforcement-reserve-again", "RESERVED",
            reinforce("reserve", "cohort-a", 4, "account-a"));
        check("reinforcement-duplicate", "DUPLICATE",
            reinforce("reserve", "cohort-a", 4, "creator-1"));
        check("reinforcement-creator-conflict", "REFUSED",
            reinforce("status", "cohort-a", 4, "creator-2"));
        check("reinforcement-renamed-owner-refused", "REFUSED",
            SAOWeekOnePrivateStore.reinforcement("reserve", REINFORCEMENT,
                "cohort-a", 4, "account-a", "creator-1", 7,
                "Changed", "Lee", "Knox", "Sandbox"));
        check("reinforcement-original-owner-still-reserved", "RESERVED",
            reinforce("status", "cohort-a", 4, "creator-1"));
        check("reinforcement-duplicate-release-refused", "REFUSED",
            reinforce("release", "cohort-a", 4, "creator-1"));

        check("scenario-reserve-1", "RESERVED",
            scenario("reserve", "scenario-a", 1, "account-a"));
        check("scenario-reserve-2", "RESERVED",
            scenario("reserve", "scenario-a", 2, "account-a"));
        check("scenario-readback-1", "RESERVED",
            scenario("status", "scenario-a", 1, "account-a"));
        check("scenario-future-missing", "MISSING",
            scenario("status", "scenario-a", 3, "account-a"));
        check("scenario-other-cohort-refused", "REFUSED",
            scenario("reserve", "scenario-b", 3, "account-a"));
        check("scenario-ordinal-bound", "REFUSED",
            scenario("reserve", "scenario-a", 25, "account-a"));
        check("scenario-release-2", "RELEASED",
            scenario("release", "scenario-a", 2, "account-a"));
        check("scenario-1-retained", "RESERVED",
            scenario("status", "scenario-a", 1, "account-a"));
        check("scenario-2-retry", "RESERVED",
            scenario("reserve", "scenario-a", 2, "account-a"));
        SAOWeekOnePrivateStore.resetRuntimeForWorld();
        check("reload-release-refused", "REFUSED",
            scenario("release", "scenario-a", 2, "account-a"));
        check("reload-scenario-readback", "RESERVED",
            scenario("status", "scenario-a", 2, "account-a"));

        String receipt = SAOWeekOnePrivateStore.ownerReceipt("put", SCENARIO,
            810, 6.75, "account-a", "account-a", 7, "Ava", "Lee",
            "Knox", "Sandbox");
        if (!receipt.matches("STORED\\t[0-9a-f]{32}"))
            throw new AssertionError("opaque receipt missing: " + receipt);
        checks++;
        System.out.println("PASS owner-receipt-new-opaque");
        String ref = receipt.substring("STORED\t".length());
        check("owner-receipt-readback", "MATCHED\t" + ref,
            SAOWeekOnePrivateStore.ownerReceipt("get", SCENARIO, 810, 6.75,
                "account-a", "account-a", 7, "Ava", "Lee", "Knox", "Sandbox"));
        check("owner-receipt-creator-upgrade", "DUPLICATE\t" + ref,
            SAOWeekOnePrivateStore.ownerReceipt("put", SCENARIO, 810, 6.75,
                "account-a", "creator-1", 7, "Ava", "Lee", "Knox", "Sandbox"));
        check("owner-receipt-wrong-owner", "REFUSED",
            SAOWeekOnePrivateStore.ownerReceipt("get", SCENARIO, 810, 6.75,
                "account-b", "creator-1", 7, "Ava", "Lee", "Knox", "Sandbox"));
        check("owner-receipt-wrong-creator", "REFUSED",
            SAOWeekOnePrivateStore.ownerReceipt("get", SCENARIO, 810, 6.75,
                "account-a", "creator-2", 7, "Ava", "Lee", "Knox", "Sandbox"));
        check("owner-receipt-wrong-generation", "MISSING",
            SAOWeekOnePrivateStore.ownerReceipt("get", SCENARIO, 810, 6.76,
                "account-a", "creator-1", 7, "Ava", "Lee", "Knox", "Sandbox"));
        check("owner-receipt-wrong-source", "MISSING",
            SAOWeekOnePrivateStore.ownerReceipt("get", REINFORCEMENT,
                810, 6.75, "account-a", "creator-1", 7, "Ava", "Lee",
                "Knox", "Sandbox"));
        SAOWeekOnePrivateStore.resetRuntimeForWorld();
        check("owner-receipt-reload", "MATCHED\t" + ref,
            SAOWeekOnePrivateStore.ownerReceipt("get", SCENARIO, 810, 6.75,
                "account-a", "creator-1", 7, "Ava", "Lee", "Knox", "Sandbox"));

        Files.copy(identity, relocated.resolve(identity.getFileName()));
        Files.copy(sidecar, relocated.resolve(sidecar.getFileName()));
        ZomboidFileSystem.instance.directory = relocated.toString();
        check("copied-save-retired", "RETIRED",
            retire("status", "person", "account-a", "creator-1", 7, "Sandbox"));
        check("copied-save-reinforcement", "RESERVED",
            reinforce("status", "cohort-a", 4, "creator-1"));
        check("copied-save-scenario", "RESERVED",
            scenario("status", "scenario-a", 2, "account-a"));
        check("copied-save-owner-receipt", "MATCHED\t" + ref,
            SAOWeekOnePrivateStore.ownerReceipt("get", SCENARIO, 810, 6.75,
                "account-a", "creator-1", 7, "Ava", "Lee", "Knox", "Sandbox"));

        ZomboidFileSystem.instance.directory = second.toString();
        check("other-save-empty", "MISSING",
            retire("status", "person", "account-a", "creator-1", 7, "Sandbox"));
        check("other-save-owner-receipt-missing", "MISSING",
            SAOWeekOnePrivateStore.ownerReceipt("get", SCENARIO, 810, 6.75,
                "account-a", "creator-1", 7, "Ava", "Lee", "Knox", "Sandbox"));
        check("other-save-reserve", "RESERVED",
            scenario("reserve", "scenario-a", 1, "account-a"));
        Path secondSidecar = second.resolve(sidecar.getFileName());
        byte[] secondOriginal = Files.readAllBytes(secondSidecar);
        Files.copy(sidecar, secondSidecar, java.nio.file.StandardCopyOption.REPLACE_EXISTING);
        check("sidecar-transplant-initialized-save-refused", "REFUSED",
            scenario("status", "scenario-a", 1, "account-a"));
        if (!Arrays.equals(Files.readAllBytes(sidecar), Files.readAllBytes(secondSidecar)))
            throw new AssertionError("foreign sidecar overwritten");
        Files.write(secondSidecar, secondOriginal);
        check("second-save-restored-after-transplant", "RESERVED",
            scenario("status", "scenario-a", 1, "account-a"));

        Files.copy(sidecar, transplant.resolve(sidecar.getFileName()));
        ZomboidFileSystem.instance.directory = transplant.toString();
        check("sidecar-only-transplant-uninitialized-save-refused", "REFUSED",
            retire("status", "person", "account-a", "creator-1", 7, "Sandbox"));
        if (Files.exists(transplant.resolve(identity.getFileName())))
            throw new AssertionError("sidecar-only transplant minted identity");

        Files.copy(identity, interrupted.resolve(identity.getFileName()));
        ZomboidFileSystem.instance.directory = interrupted.toString();
        check("interrupted-first-write-read-refused", "REFUSED",
            retire("status", "person", "account-a", "creator-1", 7, "Sandbox"));
        check("interrupted-first-write-retry-refused", "REFUSED",
            reinforce("reserve", "interrupted", 4, "account-a"));
        if (Files.exists(interrupted.resolve(sidecar.getFileName())))
            throw new AssertionError("interrupted pair overwritten");

        ZomboidFileSystem.instance.directory = first.toString();
        check("original-save-restored", "RETIRED",
            retire("status", "person", "account-a", "creator-1", 7, "Sandbox"));

        byte[] goodIdentity = Files.readAllBytes(identity);
        byte[] brokenIdentity = Arrays.copyOf(goodIdentity, goodIdentity.length);
        brokenIdentity[8] ^= 1;
        Files.write(identity, brokenIdentity);
        check("malformed-identity-refused", "REFUSED",
            scenario("reserve", "scenario-a", 3, "account-a"));
        if (!Arrays.equals(brokenIdentity, Files.readAllBytes(identity)))
            throw new AssertionError("malformed identity overwritten");
        Files.write(identity, goodIdentity);
        check("restored-identity", "RESERVED",
            scenario("status", "scenario-a", 1, "account-a"));
        byte[] wrongIdentityVersion = Arrays.copyOf(goodIdentity, goodIdentity.length);
        wrongIdentityVersion[7] = 2;
        byte[] identityChecksum = MessageDigest.getInstance("SHA-256").digest(
            Arrays.copyOf(wrongIdentityVersion, wrongIdentityVersion.length - 32));
        System.arraycopy(identityChecksum, 0, wrongIdentityVersion,
            wrongIdentityVersion.length - 32, identityChecksum.length);
        Files.write(identity, wrongIdentityVersion);
        check("unsupported-identity-version-refused", "REFUSED",
            scenario("status", "scenario-a", 1, "account-a"));
        if (!Arrays.equals(wrongIdentityVersion, Files.readAllBytes(identity)))
            throw new AssertionError("unsupported identity overwritten");
        Files.write(identity, goodIdentity);
        Path heldIdentity = first.resolve("SAOWeekOneSaveId.held");
        Files.move(identity, heldIdentity);
        check("missing-identity-refused", "REFUSED",
            scenario("reserve", "scenario-a", 3, "account-a"));
        if (Files.exists(identity)) throw new AssertionError("missing identity recreated");
        Files.move(heldIdentity, identity);
        Path heldSidecar = first.resolve("SAOWeekOnePrivate.held");
        Files.move(sidecar, heldSidecar);
        check("missing-sidecar-refused", "REFUSED",
            scenario("reserve", "scenario-a", 3, "account-a"));
        if (Files.exists(sidecar)) throw new AssertionError("missing sidecar recreated");
        Files.move(heldSidecar, sidecar);

        byte[] good = Files.readAllBytes(sidecar);
        byte[] malformed = Arrays.copyOf(good, good.length);
        malformed[8] ^= 1;
        Files.write(sidecar, malformed);
        check("malformed-refused", "REFUSED",
            scenario("reserve", "scenario-a", 3, "account-a"));
        if (!Arrays.equals(malformed, Files.readAllBytes(sidecar)))
            throw new AssertionError("malformed sidecar overwritten");
        Files.write(sidecar, good);
        check("restored-sidecar", "RESERVED",
            scenario("status", "scenario-a", 1, "account-a"));
        byte[] wrongVersion = Arrays.copyOf(good, good.length);
        wrongVersion[7] = 2;
        byte[] checksum = MessageDigest.getInstance("SHA-256").digest(
            Arrays.copyOf(wrongVersion, wrongVersion.length - 32));
        System.arraycopy(checksum, 0, wrongVersion,
            wrongVersion.length - 32, checksum.length);
        Files.write(sidecar, wrongVersion);
        check("unsupported-version-refused", "REFUSED",
            scenario("status", "scenario-a", 1, "account-a"));
        if (!Arrays.equals(wrongVersion, Files.readAllBytes(sidecar)))
            throw new AssertionError("unsupported sidecar overwritten");
        Files.write(sidecar, good);

        GameClient.client = true;
        check("client-read-refused", "REFUSED",
            scenario("status", "scenario-a", 1, "account-a"));
        check("client-write-refused", "REFUSED",
            reinforce("reserve", "client", 4, "account-a"));
        GameClient.client = false;
        check("client-did-not-write", "MISSING",
            reinforce("status", "client", 4, "account-a"));

        System.out.println("CHECKS " + checks + " FAILURES 0");
    }
}
