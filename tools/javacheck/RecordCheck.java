import com.sao.engine.SAORecord;
import java.time.LocalDate;
import java.util.Arrays;
import java.util.List;

/**
 * [C36] Border 110's Java half: the record's date arithmetic, off the
 * game, against the same class the bridge calls. The month and day are
 * zero-based as GameTime gives them. Prints one RECORD PASS or RECORD
 * FAIL line; tools/record_calendar_test.py reads it. The shipped
 * registry of papers is asked too, and reported either way: it is the
 * engine's own static and may not load without the game.
 */
public final class RecordCheck {

    private RecordCheck() {
    }

    private static int faults = 0;

    private static void expect(String what, Object got, Object want) {
        boolean ok = (got == null && want == null) || (got != null && got.equals(want));
        System.out.println((ok ? "  ok   " : "  FAIL ") + what + " = " + got
            + (ok ? "" : " (wanted " + want + ")"));
        if (!ok) {
            faults++;
        }
    }

    public static void main(String[] args) {
        // July 9, 1993 is month 6, day 8 to the engine.
        expect("record day of the shipped start", SAORecord.recordDayOf(1993, 6, 8), 0);
        expect("save day of day 0 on the shipped start", SAORecord.startDayFor(1993, 6, 8), 0);
        expect("save day of day 0 on a July 1 start", SAORecord.startDayFor(1993, 6, 0), 8);
        expect("save day of day 0 on a July 20 start", SAORecord.startDayFor(1993, 6, 19), -11);
        expect("record day of August 1", SAORecord.recordDayOf(1993, 7, 0), 23);
        expect("record day of June 30", SAORecord.recordDayOf(1993, 5, 29), -9);
        expect("record day of July 9, 1994", SAORecord.recordDayOf(1994, 6, 8), 365);

        expect("an issue's date", SAORecord.issueDate("KnoxKnews_July3"), LocalDate.of(1993, 7, 3));
        expect("a name with no date", SAORecord.issueDate("Newspaper"), null);

        List<String> knews = Arrays.asList("KnoxKnews_July1", "KnoxKnews_July2", "KnoxKnews_July3",
            "KnoxKnews_July4", "KnoxKnews_July5", "KnoxKnews_July6");
        List<String> herald = Arrays.asList("KentuckyHerald_July6", "KentuckyHerald_July13",
            "KentuckyHerald_July14", "KentuckyHerald_July15", "KentuckyHerald_July16");
        expect("the county paper on July 3", SAORecord.issueFor(knews, LocalDate.of(1993, 7, 3)), "KnoxKnews_July3");
        expect("the county paper on June 30", SAORecord.issueFor(knews, LocalDate.of(1993, 6, 30)), null);
        expect("the county paper in August", SAORecord.issueFor(knews, LocalDate.of(1993, 8, 1)), "KnoxKnews_July6");
        expect("the Herald on July 3", SAORecord.issueFor(herald, LocalDate.of(1993, 7, 3)), null);
        expect("the Herald on July 14", SAORecord.issueFor(herald, LocalDate.of(1993, 7, 14)), "KentuckyHerald_July14");
        expect("the Herald on July 10", SAORecord.issueFor(herald, LocalDate.of(1993, 7, 10)), "KentuckyHerald_July6");
        expect("the Herald a year on", SAORecord.issueFor(herald, LocalDate.of(1994, 7, 9)), "KentuckyHerald_July16");

        // The engine's own registry, if it loads off the game.
        try {
            Object issues = zombie.scripting.objects.Newspaper.KNOX_KNEWS.getIssues();
            System.out.println("  registry=ok knews-issues=" + issues);
            expect("the registry's county paper on July 3",
                SAORecord.issueFor(zombie.scripting.objects.Newspaper.KNOX_KNEWS, 1993, 6, 2),
                "KnoxKnews_July3");
        } catch (Throwable throwable) {
            System.out.println("  registry=unavailable off the game (" + throwable.getClass().getSimpleName() + ")");
        }
        System.out.println(faults == 0 ? "RECORD PASS" : "RECORD FAIL faults=" + faults);
    }
}
