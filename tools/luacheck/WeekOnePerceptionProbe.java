import com.sao.engine.SAOPerceptionScanner;
import zombie.characters.IsoZombie;
import zombie.characters.SurvivorDesc;
import java.lang.reflect.Method;

/** Installed-engine exact proxy marker admission; no world or player save. */
public final class WeekOnePerceptionProbe {
    private static void check(boolean value, String message) {
        if (!value) throw new AssertionError(message);
    }

    private static String label(Method classifier, IsoZombie body) throws Exception {
        return (String) classifier.invoke(null, body);
    }

    public static void main(String[] args) throws Exception {
        PersonSnapshotProbe.main(args);
        IsoZombie body = new IsoZombie(null, new SurvivorDesc(), 0);
        body.setVariable("Bandit", true);
        body.setPersistentOutfitID(73);
        Method classifier = SAOPerceptionScanner.class
            .getDeclaredMethod("weekOnePersonName", IsoZombie.class);
        classifier.setAccessible(true);
        check(label(classifier, body) == null, "unstamped Bandits actor became a person");
        var md = body.getModData();
        md.rawset("SAOWeekOneOrigin", "BanditsWeekOne");
        md.rawset("SAOWeekOnePersonId", "bwo-7");
        md.rawset("SAOWeekOneBrainId", 72.0);
        md.rawset("SAOWeekOneBorn", 12.5);
        md.rawset("SAOWeekOneName", "Alex: Harper");
        check(label(classifier, body) == null, "mismatched brain ID became a person");
        md.rawset("SAOWeekOneBrainId", 73.0);
        check("Alex_ Harper".equals(label(classifier, body)),
            "exact Week One brain was not classified as a living person");
        md.rawset("SAOWeekOneOrigin", "Bandits2");
        check(label(classifier, body) == null, "foreign origin became a person");
        System.out.println("PASS Week One scanner exact living-proxy classification and inverses");
    }
}
