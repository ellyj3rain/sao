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

        // [C62] The month a COUNTY hour falls in. County hour 0 is
        // the first of the days a save owes, so the anchor is the
        // save's start put back by the days behind it - a 1996 save
        // is at the record's own day zero on county hour 0, and back
        // at its own start once it has lived them all.
        expect("the shipped start's own month", SAORecord.countyMonth0(1993, 6, 8, 0.0, 0), 6);
        expect("a month into the shipped start", SAORecord.countyMonth0(1993, 6, 8, 31 * 24.0, 0), 7);
        expect("a 1996 save's first county hour is the record's July",
            SAORecord.countyMonth0(1996, 6, 8, 0.0, 1096), 6);
        expect("and a hundred and eighty days in is January",
            SAORecord.countyMonth0(1996, 6, 8, 180 * 24.0, 1096), 0);
        expect("and the day it has lived them all is its own start month",
            SAORecord.countyMonth0(1996, 6, 8, 1096 * 24.0, 1096), 6);
        expect("a January 1993 start owes nothing and reads its own month",
            SAORecord.countyMonth0(1993, 0, 0, 0.0, 0), 0);
        expect("and two hundred days into it is July",
            SAORecord.countyMonth0(1993, 0, 0, 200 * 24.0, 0), 6);
        // [C63] A shifted July 20 start owes nothing, so its months are
        // its own. Anchored on eleven days behind, they would read
        // eleven days early for the whole save.
        expect("a shifted July 20 start reads its own month",
            SAORecord.countyMonth0(1993, 6, 19, 0.0, 0), 6);
        expect("and a fortnight into it is August",
            SAORecord.countyMonth0(1993, 6, 19, 14 * 24.0, 0), 7);
        expect("the same start anchored eleven days behind is still July",
            SAORecord.countyMonth0(1993, 6, 19, 14 * 24.0, 11), 6);

        // [C63] The days a save owes, and the day-zero switch that is
        // half the answer. `daysBehindAtStart` needs the engine's own
        // clock for the save start, so the arithmetic under it is what
        // is checked here: `recordDayOf` is what the switch-off path
        // returns, and `mayShift` is the refusal the switch-on path
        // asks. Border 132 drives the whole function through the
        // bridge.
        expect("July 20 1993 is eleven days past the record's day 0",
            SAORecord.recordDayOf(1993, 6, 19), 11);
        expect("October 1 1993 is eighty-four",
            SAORecord.recordDayOf(1993, 9, 0), 84);
        expect("December 15 1993 is a hundred and fifty-nine",
            SAORecord.recordDayOf(1993, 11, 14), 159);
        expect("and every one of those may be shifted onto",
            SAORecord.mayShift(1993, 6, 19) && SAORecord.mayShift(1993, 9, 0)
                && SAORecord.mayShift(1993, 11, 14), true);
        expect("so a shifted start's own first day is the lead-in before day 0",
            SAORecord.recordDayOnSaveDay(1993, 11, 14, 0), -SAORecord.leadIn());
        expect("while 1996 may not be shifted onto at all",
            SAORecord.mayShift(1996, 6, 8), false);
        expect("and owes its thousand whatever the switch says",
            SAORecord.recordDayOf(1996, 6, 8), 1096);

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
