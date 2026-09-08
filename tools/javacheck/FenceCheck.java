import com.sao.engine.SAOFence;

/**
 * [C47] Border 120's Java half: the fence proved mechanically over a
 * test corpus, which is how Decision 4's ratification said it must be
 * proved - "verified mechanically over test corpora, not by review".
 *
 * The corpus is built here rather than harvested because there is no
 * speaker yet: these are the fillings a speaker WOULD produce, true
 * ones and fabricated ones, including the near-misses that are the
 * only interesting case. A fence that catches "a brother who does not
 * exist" but passes a name one letter off is not a fence.
 *
 * Prints one FENCE PASS or FENCE FAIL line; tools/fence_test.py reads
 * it.
 */
public final class FenceCheck {

    private FenceCheck() {
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

    // One person's claims, in the knowledge surface's own fields.
    private static final String CLAIMS = String.join("\n",
        "person=Dana",
        "person=Marcus",
        "dead=Marcus",
        "teller=Dana",
        "zombieCount=2",
        "whereWord=north of here",
        "ageWord=just now",
        "house=the Mill",
        "leader=Ruth Hall",
        "bornYear=1949",
        "war=Vietnam",
        "region=Muldraugh",
        "lesson=Quiet keeps you alive.");

    public static void main(String[] args) {
        // What they can say.
        expect("a person they know", SAOFence.permits(CLAIMS, "person", "Dana"), true);
        expect("the dead they know of", SAOFence.permits(CLAIMS, "dead", "Marcus"), true);
        expect("who told them", SAOFence.permits(CLAIMS, "teller", "Dana"), true);
        expect("the count they saw", SAOFence.permits(CLAIMS, "zombieCount", "2"), true);
        expect("their own war", SAOFence.permits(CLAIMS, "war", "Vietnam"), true);

        // What they cannot. A brother who does not exist.
        expect("a person who does not exist",
            SAOFence.permits(CLAIMS, "person", "Elias"), false);
        expect("a death nobody told them of",
            SAOFence.permits(CLAIMS, "dead", "Dana"), false);
        expect("a war they were not in",
            SAOFence.permits(CLAIMS, "war", "Korea"), false);

        // The near-misses, which are the only interesting case.
        expect("a name one letter off",
            SAOFence.permits(CLAIMS, "person", "Dan"), false);
        expect("a name with different case",
            SAOFence.permits(CLAIMS, "person", "dana"), false);
        expect("a count larger than they saw",
            SAOFence.permits(CLAIMS, "zombieCount", "3"), false);
        expect("a value that is real but in the wrong slot",
            SAOFence.permits(CLAIMS, "leader", "Dana"), false);
        expect("a leader who is a person they know",
            SAOFence.permits(CLAIMS, "person", "Ruth Hall"), false);

        // A slot they have no claims for cannot be filled at all.
        expect("a slot they hold nothing in",
            SAOFence.permits(CLAIMS, "pact", "the Yard"), false);
        expect("and an unknown slot is not permissive",
            SAOFence.permits(CLAIMS, "anything", "at all"), false);

        // Whole fillings.
        expect("a sentence they could say",
            SAOFence.sayable(CLAIMS, "person=Dana\nwhereWord=north of here"), true);
        expect("a sentence with one invented part",
            SAOFence.sayable(CLAIMS, "person=Dana\nperson=Elias"), false);
        expect("and it names the invented part",
            SAOFence.violations(CLAIMS, "person=Dana\nperson=Elias"), "person=Elias");
        expect("a sentence that is entirely invented",
            SAOFence.violations(CLAIMS, "person=Elias\nwar=Korea"),
            "person=Elias\nwar=Korea");

        // A person who knows nothing can say nothing.
        expect("an empty claim set permits nothing",
            SAOFence.permits("", "person", "Dana"), false);
        expect("and its vocabulary is empty", SAOFence.vocabulary(""), "");
        expect("and every filling violates it",
            SAOFence.violations("", "person=Dana"), "person=Dana");

        // Whitespace and malformed input must not open holes.
        expect("trailing space does not smuggle a value in",
            SAOFence.permits(CLAIMS, "person", " Dana "), true);
        expect("an empty value is never permitted",
            SAOFence.permits(CLAIMS, "person", ""), false);
        expect("a line with no separator is not a claim",
            SAOFence.permits("person Dana", "person", "Dana"), false);

        expect("the fence measures what it holds",
            SAOFence.measure(CLAIMS), "slots=12 values=13");

        System.out.println(faults == 0 ? "FENCE PASS" : "FENCE FAIL faults=" + faults);
    }
}
