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
        // [C38] the county's own words for a day.
        expect("the county's date three days into a July 1 start", SAORecord.countyDate(1993, 6, 0, 72.0), "July 4, 1993");
        expect("the county's date at the shipped start", SAORecord.countyDate(1993, 6, 8, 0.0), "July 9, 1993");
        expect("the county's date a month on", SAORecord.countyDate(1993, 6, 8, 31 * 24.0), "August 9, 1993");
        expect("the record's own first day", SAORecord.recordDayZero(), "July 9, 1993");

        // [C43] The timeline placed against the game being played: the
        // outbreak lands the lead-in into the save, wherever in the year
        // it began, and the record keeps its order around that point.
        expect("the record's own ordinary county is eight days", SAORecord.leadIn(), 8);
        expect("a March start: the fall on save day eight",
            SAORecord.recordDayOnSaveDay(1993, 2, 0, 8), 0);
        expect("and day seven is still ordinary",
            SAORecord.recordDayOnSaveDay(1993, 2, 0, 7), -1);
        expect("and the first day is the record's first day",
            SAORecord.recordDayOnSaveDay(1993, 2, 0, 0), -8);
        expect("and a fortnight past the fall is record day 14",
            SAORecord.recordDayOnSaveDay(1993, 2, 0, 22), 14);
        expect("a January start shifts the same way",
            SAORecord.recordDayOnSaveDay(1993, 0, 0, 8), 0);
        // The shift is only for a 1993 start that begins before the
        // record does. A later start is owed the years simulated
        // forward instead, and moving the lore onto it would erase
        // the history it came for.
        expect("a January 1993 start may shift", SAORecord.mayShift(1993, 0, 0), true);
        expect("a March 1993 start may shift", SAORecord.mayShift(1993, 2, 0), true);
        expect("an October 1993 start may shift too", SAORecord.mayShift(1993, 9, 0), true);
        expect("and so may the shipped July 9 one, when asked",
            SAORecord.mayShift(1993, 6, 8), true);
        expect("a 1994 start may not shift", SAORecord.mayShift(1994, 2, 0), false);
        expect("a 2000 start may not shift", SAORecord.mayShift(2000, 0, 0), false);
        // The timeline moves backwards for a start later in the year:
        // an October save gets the record's own week and then the fall,
        // rather than the fall having happened three months before it
        // began.
        expect("an October start moves the record back onto it",
            SAORecord.recordDayOnSaveDay(1993, 9, 0, 8), 0);
        expect("and its first day is the record's first day",
            SAORecord.recordDayOnSaveDay(1993, 9, 0, 0), -8);

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
