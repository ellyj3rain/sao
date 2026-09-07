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

    // ---------------------------------------------------------------- clock

    /** [C38] The date a world-age hour falls on, from the save's own
     *  start, in a person's words: "July 12, 1993". */
    public static String countyDate(int year, int month0, int day0, double hours) {
        LocalDate date = dateOf(year, month0, day0).plusDays((long) Math.floor(hours / 24.0));
        return wordsOf(date);
    }

    /** [C38] The record's own first day, in the same words. */
    public static String recordDayZero() {
        return wordsOf(RECORD_DAY_ZERO);
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

    public static int[] today() {
        try {
            GameTime gt = GameTime.getInstance();
            return new int[] { gt.getYear(), gt.getMonth(), gt.getDay() };
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
