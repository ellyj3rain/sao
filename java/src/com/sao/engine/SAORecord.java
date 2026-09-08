package com.sao.engine;

import com.sao.agent.SAOAgent;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import se.krka.kahlua.vm.KahluaTable;
import zombie.GameTime;
import zombie.core.Translator;
import zombie.inventory.InventoryItem;
import zombie.inventory.ItemContainer;
import zombie.radio.scripting.RadioChannel;
import zombie.radio.scripting.RadioScript;
import zombie.radio.scripting.RadioScriptManager;
import zombie.scripting.logic.RecipeCodeHelper;
import zombie.scripting.objects.Newspaper;
import zombie.scripting.objects.Registries;

/**
 * [C36] The shipped record on the county's calendar (DR-031).
 *
 * The engine keys every broadcast to days since the save began and
 * dates no newspaper at all (ENGINE_CONTRACT Addendum E). The record
 * itself carries dates: its broadcast day 0 is July 9, 1993, and each
 * paper's issues are named by their July date. So a living start on
 * any 1993 day can have the record reach it on the record's own
 * calendar: every vanilla channel's running script is re-keyed to
 * start on the save day that July 9 falls on (the engine's own
 * re-keying surface, the one its game modes use), and a paper found on
 * a day shows the newest issue printed by that day - or is not on the
 * shelf yet.
 *
 * The date arithmetic is pure and checked off the game (Border 110);
 * the two engine-facing calls never throw.
 */
public final class SAORecord {

    /** The record's own day 0 (DR-031; the Speakeasy document knox-event.md). */
    public static final LocalDate RECORD_DAY_ZERO = LocalDate.of(1993, 7, 9);

    /** [C43] The record's own FIRST day - the earliest thing it
     *  carries, the July 1 Knox Knews and the outages around it. The
     *  eight days between this and day 0 are the ordinary county the
     *  shipped record already has, and they are the record's own
     *  number rather than anybody's setting. */
    public static final LocalDate RECORD_FIRST_DAY = LocalDate.of(1993, 7, 1);

    /** [C43] How the record's timeline is placed against this save.
     *
     * ANCHORED (shift 0) is the shipped calendar and what [C36]
     * built: the Knox Event happens on the dates it carries, so a
     * save beginning July 1 lives eight ordinary days and then the
     * fall arrives on July 9 because that is when it arrived.
     *
     * SHIFTED re-bases the whole record onto the game actually being
     * played. The outbreak lands a chosen number of days into the
     * save, and everything the record carries - the broadcasts, the
     * dated papers, the outages before it and the cordon after -
     * keeps its own order and spacing around that point. A save
     * beginning in March 1993 with a fortnight's lead-in gets a
     * fortnight of ordinary county, then the fall, then the record
     * in its shipped order. The lead-in is not fixed at the eight
     * days the shipped record happens to have.
     *
     * One integer does all of it: every record read asks for the
     * EFFECTIVE date, which is the real one plus this shift, and
     * every function [C36] and [C38] already wrote works unchanged
     * on it.
     */
    private static int shiftDays = 0;
    private static int leadInDays = 0;
    private static boolean shifted = false;

    private static int keyedChannels = 0;
    private static int keyedPapers = 0;
    private static int removedPapers = 0;
    private static String lastError = "";

    private SAORecord() {
    }

    // ---------------------------------------------------------------- dates

    /** GameTime's month and day are zero-based; the year is not. */
    public static LocalDate dateOf(int year, int month0, int day0) {
        return LocalDate.of(year, month0 + 1, day0 + 1);
    }

    /** Days since the record's day 0; negative before it. */
    public static int recordDayOf(int year, int month0, int day0) {
        return (int) ChronoUnit.DAYS.between(RECORD_DAY_ZERO, dateOf(year, month0, day0));
    }

    /** The save day on which the record's day 0 falls: positive when the
     *  save starts before July 9, zero on the shipped default, negative
     *  after. */
    public static int startDayFor(int year, int month0, int day0) {
        return (int) ChronoUnit.DAYS.between(dateOf(year, month0, day0), RECORD_DAY_ZERO);
    }

    /** An issue's date from its name (KnoxKnews_July3 -> 1993-07-03), or null. */
    public static LocalDate issueDate(String issue) {
        if (issue == null) {
            return null;
        }
        int at = issue.lastIndexOf("_July");
        if (at < 0) {
            return null;
        }
        try {
            return LocalDate.of(1993, 7, Integer.parseInt(issue.substring(at + 5)));
        } catch (RuntimeException e) {
            return null;
        }
    }

    /** The newest issue dated on or before the day, or null when the
     *  paper has not printed one yet. */
    public static String issueFor(List<String> issues, LocalDate today) {
        String best = null;
        LocalDate bestDate = null;
        if (issues == null) {
            return null;
        }
        for (String issue : issues) {
            LocalDate date = issueDate(issue);
            if (date == null || date.isAfter(today)) {
                continue;
            }
            if (bestDate == null || date.isAfter(bestDate)) {
                best = issue;
                bestDate = date;
            }
        }
        return best;
    }

    public static String issueFor(Newspaper paper, int year, int month0, int day0) {
        return paper == null ? null : issueFor(paper.getIssues(), dateOf(year, month0, day0));
    }

    // ---------------------------------------------------------------- shift

    /** [C43] Place the record against this save. `leadIn` is the days
     *  of ordinary county before the outbreak reaches it; the record's
     *  day 0 is put exactly that far into the save. Returns the shift
     *  in days, or 0 when the clock cannot be read. */
    public static int shiftTo() {
        int[] start = saveStart();
        if (start == null || !mayShift(start[0], start[1], start[2])) {
            return 0;
        }
        shiftDays = shiftFor(start[0], start[1], start[2]);
        leadInDays = leadIn();
        shifted = true;
        return shiftDays;
    }

    /** [C43] The days to add to a real date so the save's start lands
     *  on the record's own first day. Pure, so Border 110 can check it
     *  off the game. */
    public static int shiftFor(int year, int month0, int day0) {
        return (int) ChronoUnit.DAYS.between(
            dateOf(year, month0, day0), RECORD_FIRST_DAY);
    }

    /** [C45] How many days of history a save begins with behind it:
     *  the record's day 0 to the save's own start. Zero for a 1993
     *  start, about a thousand for a 1996 one. Never negative - a
     *  world that begins before the fall has no years to catch up on,
     *  it has them ahead of it. -1 when the clock cannot be read, so
     *  the Lua side can tell that from a genuine nothing. */
    public static int daysBehindAtStart() {
        int[] start = saveStart();
        if (start == null) {
            return -1;
        }
        return Math.max(0, recordDayOf(start[0], start[1], start[2]));
    }

    /** [C43] The record's own ordinary county, in days: first day to
     *  day 0. Derived from the record, not chosen. */
    public static int leadIn() {
        return (int) ChronoUnit.DAYS.between(RECORD_FIRST_DAY, RECORD_DAY_ZERO);
    }

    /** [C43] MAY this save's timeline be shifted at all?
     *
     * Any 1993 start. That is the year the record is canonically in,
     * and a player who picks a date inside it and asks for the
     * day-zero start gets the record moved onto that date: the
     * ordinary county it carries, then the collapse, then the rest in
     * its own order. January, March or October - the timeline moves to
     * them rather than them waiting for July.
     *
     * A save that begins in 1994 or 2000 is a different case entirely
     * and must NOT be shifted: the Knox Event happened when it
     * happened, and what that player is owed is the years between
     * simulated forward, which is DR-036's other half. Moving the lore
     * onto their start would erase exactly the history they came for.
     */
    public static boolean mayShift(int year, int month0, int day0) {
        return year == RECORD_FIRST_DAY.getYear();
    }

    /** [C43] Which record day a save day falls on when shifted.
     *  Negative through the ordinary county, 0 the day the outbreak
     *  reaches it. */
    public static int recordDayOnSaveDay(int year, int month0, int day0,
                                         int saveDay) {
        LocalDate real = dateOf(year, month0, day0).plusDays(saveDay);
        LocalDate at = real.plusDays(shiftFor(year, month0, day0));
        return (int) ChronoUnit.DAYS.between(RECORD_DAY_ZERO, at);
    }

    /** [C43] Back to the shipped calendar. */
    public static void anchor() {
        shiftDays = 0;
        leadInDays = 0;
        shifted = false;
    }

    public static boolean isShifted() {
        return shifted;
    }

    public static int leadInApplied() {
        return leadInDays;
    }

    /** [C43] The date the record should be read at, which is the real
     *  one while anchored. */
    public static LocalDate effective(LocalDate real) {
        return shiftDays == 0 ? real : real.plusDays(shiftDays);
    }

    // ---------------------------------------------------------------- clock

    /** [C38] The date a world-age hour falls on, from the save's own
     *  start, in a person's words: "July 12, 1993". */
    public static String countyDate(int year, int month0, int day0, double hours) {
        LocalDate date = dateOf(year, month0, day0).plusDays((long) Math.floor(hours / 24.0));
        return wordsOf(date);
    }

    /** [C38] The record's own first day, in the same words - and
     *  [C43] the day it actually falls on in this world, which is not
     *  July 9 once the timeline has been shifted onto this save. */
    public static String recordDayZero() {
        if (!shifted) {
            return wordsOf(RECORD_DAY_ZERO);
        }
        int[] start = saveStart();
        if (start == null) {
            return wordsOf(RECORD_DAY_ZERO);
        }
        return wordsOf(dateOf(start[0], start[1], start[2]).plusDays(leadInDays));
    }

    public static String wordsOf(LocalDate date) {
        return date.getMonth().getDisplayName(java.time.format.TextStyle.FULL, java.util.Locale.US)
            + " " + date.getDayOfMonth() + ", " + date.getYear();
    }

    /** The save's start, from the engine's own clock; null off the game. */
    public static int[] saveStart() {
        try {
            GameTime gt = GameTime.getInstance();
            return new int[] { gt.getStartYear(), gt.getStartMonth(), gt.getStartDay() };
        } catch (Throwable throwable) {
            return null;
        }
    }

    /** [C43] The date the RECORD is read at: the county's real day
     *  while anchored, and the day the record has reached while
     *  shifted. Every caller here wants the second - which paper is on
     *  the shelf, how far into the schedule the county is - and the
     *  chronicle's own dates go through countyDate instead, which does
     *  not shift, because a person who lived a day lived it on the day
     *  the calendar actually said. */
    public static int[] today() {
        try {
            GameTime gt = GameTime.getInstance();
            LocalDate real = dateOf(gt.getYear(), gt.getMonth(), gt.getDay());
            LocalDate at = effective(real);
            return new int[] { at.getYear(), at.getMonthValue() - 1, at.getDayOfMonth() - 1 };
        } catch (Throwable throwable) {
            return null;
        }
    }

    // ---------------------------------------------------------------- radio

    /** Re-key every vanilla channel's running script to begin on the
     *  given save day - the engine's own surface, as its game modes use
     *  it. Non-vanilla channels (the county wire among them) are left
     *  alone. Returns the count, -1 when the manager is not there. */
    public static int rekeyRadio(int startDay) {
        try {
            RadioScriptManager manager = RadioScriptManager.getInstance();
            if (manager == null) {
                lastError = "no radio script manager";
                return -1;
            }
            int keyed = 0;
            for (RadioChannel channel : new ArrayList<>(manager.getChannelsList())) {
                if (channel == null || !channel.isVanilla()) {
                    continue;
                }
                RadioScript script = channel.getCurrentScript();
                if (script == null) {
                    continue;
                }
                channel.setActiveScript(script.GetName(), startDay);
                keyed++;
            }
            keyedChannels = keyed;
            return keyed;
        } catch (Throwable throwable) {
            lastError = "rekeyRadio threw: " + throwable;
            SAOAgent.log(lastError);
            return -1;
        }
    }

    // ---------------------------------------------------------------- papers

    private static Newspaper paperOf(InventoryItem item) {
        String type = "";
        try {
            type = String.valueOf(item.getType());
        } catch (Throwable throwable) {
            return null;
        }
        if (type.contains("Knews")) {
            return Newspaper.KNOX_KNEWS;
        }
        if (type.contains("Herald")) {
            return Newspaper.KENTUCKY_HERALD;
        }
        if (type.contains("Times")) {
            return Newspaper.LOUISVILLE_SUN_TIMES;
        }
        if (type.contains("Dispatch")) {
            return Newspaper.NATIONAL_DISPATCH;
        }
        if (!type.startsWith("Newspaper")) {
            return null;
        }
        // A paper of no named title keeps the one the engine dealt it,
        // read back from the print media it wrote; the county paper
        // when there is none.
        try {
            Object media = item.getModData().rawget("printMedia");
            if (media instanceof KahluaTable table) {
                Object id = table.rawget("id");
                for (Newspaper paper : Registries.NEWSPAPER.values()) {
                    if (paper != null && String.valueOf(paper).equals(String.valueOf(id))) {
                        return paper;
                    }
                }
            }
        } catch (Throwable throwable) {
            // fall through to the county paper
        }
        return Newspaper.KNOX_KNEWS;
    }

    /** Key one paper to the day: the newest issue printed by then,
     *  written the way the engine writes it (name, then the print media
     *  table: title, info, text, id - the order the helper takes them).
     *  Returns "keyed", "removed" (nothing printed yet), or "" (not a paper). */
    public static String keyItem(InventoryItem item, ItemContainer container, LocalDate today) {
        try {
            if (item == null) {
                return "";
            }
            Object done = item.getModData().rawget("SAORecordKeyed");
            if (Boolean.TRUE.equals(done)) {
                return "";
            }
            Newspaper paper = paperOf(item);
            if (paper == null) {
                return "";
            }
            String issue = issueFor(paper.getIssues(), today);
            if (issue == null) {
                if (container != null) {
                    container.Remove(item);
                }
                removedPapers++;
                return "removed";
            }
            String title = Translator.getText(paper.getTitle(issue));
            item.setName(title);
            RecipeCodeHelper.setPrintMediaInfo(item, title,
                paper.getTranslationInfoKey(issue), paper.getTranslationTextKey(issue),
                String.valueOf(paper));
            item.getModData().rawset("SAORecordKeyed", Boolean.TRUE);
            keyedPapers++;
            return "keyed";
        } catch (Throwable throwable) {
            lastError = "keyItem threw: " + throwable;
            return "";
        }
    }

    /** Every paper in a container, keyed to the day. "keyed=n removed=m". */
    public static String keyContainer(ItemContainer container, int year, int month0, int day0) {
        try {
            if (container == null) {
                return "";
            }
            LocalDate today = dateOf(year, month0, day0);
            int keyed = 0;
            int removed = 0;
            for (InventoryItem item : new ArrayList<>(container.getItems())) {
                String result = keyItem(item, container, today);
                if ("keyed".equals(result)) {
                    keyed++;
                } else if ("removed".equals(result)) {
                    removed++;
                }
            }
            return "keyed=" + keyed + " removed=" + removed;
        } catch (Throwable throwable) {
            lastError = "keyContainer threw: " + throwable;
            return "";
        }
    }

    public static String report() {
        return "channels=" + keyedChannels + " papers=" + keyedPapers
            + " removed=" + removedPapers + (lastError.isEmpty() ? "" : " error=" + lastError);
    }
}
