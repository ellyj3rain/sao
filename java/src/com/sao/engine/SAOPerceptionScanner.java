package com.sao.engine;

import zombie.characters.IsoGameCharacter;
import zombie.characters.IsoPlayer;
import zombie.characters.IsoZombie;
import zombie.iso.IsoCell;
import zombie.iso.IsoGridSquare;

/**
 * The Perception pillar's acquisition step. Scans what one survivor body can
 * actually perceive RIGHT NOW — facing cone plus occlusion — and reports it as
 * one compact delimited string. Belief formation, provenance, memory and decay
 * live in Lua; this class answers only "what is visible from here, this tick".
 *
 * The string format exists because engine objects must never cross into
 * Kahlua: every Lua-side interop failure this project has had came from that.
 * Format, '|'-separated entries:
 *   Z:x:y:dist        a zombie the survivor can see
 *   P:username:x:y:dist  a player (or another shell) it can see
 * Coordinates are floored tiles; dist is one decimal.
 *
 * Vision model (deliberately human-bounded, CORE.md "no omniscience"):
 *   - range cap (tiles), tighter behind (a person has peripheral vision but
 *     not eyes in the back of the head): full range inside +-72 degrees of
 *     facing, 2.5 tiles otherwise;
 *   - tile occlusion via IsoGridSquare.isSomethingTo between eye and target;
 *   - same floor only (Z changes are not yet modeled anywhere in SAO).
 */
public final class SAOPerceptionScanner {

    private static final float RANGE = 14.0f;
    private static final float NEAR_SENSE = 2.5f;
    private static final double CONE_COS = Math.cos(Math.toRadians(72.0));

    private SAOPerceptionScanner() {
    }

    /** [B28] Somebody else's person, by property and never by name.
     *
     *  An IsoPlayer that is not in the engine's slot array and is not
     *  one of our shells belongs to another mod. That is the whole
     *  test, and it is the only place it is written: the scanner
     *  labels with it and the bridge looks bodies up with it, so the
     *  two cannot drift apart. */
    public static boolean isForeignPerson(IsoPlayer person) {
        if (person == null || person instanceof SAOIsoPlayerShell) {
            return false;
        }
        try {
            for (int pi = 0; pi < IsoPlayer.players.length; pi++) {
                if (IsoPlayer.players[pi] == person) {
                    return false;
                }
            }
        } catch (Throwable ignored) {
        }
        return true;
    }

    /** [B33] A stable name for someone else's person, in ONE place.
     *
     *  IsoPlayer.username is a plain field and is null unless the mod
     *  that made them called setUsername. The label used to fall back
     *  to a constant when it was, which meant every such person from
     *  every mod became the same key - and the bridge looked them up
     *  by username, so that key matched nobody. The label and the
     *  lookup were two different expressions and only agreed on the
     *  path where a username happened to exist.
     *
     *  Descriptor before object id, because a name someone authored
     *  outlives a session and an id does not; the id is the last
     *  resort that keeps two nameless people two people.
     *
     *  Delimiters are stripped for the same reason the Knox path
     *  strips them: this string is packed into a delimited record and
     *  read back out of it. */
    public static String foreignName(IsoPlayer person) {
        if (person == null) {
            return null;
        }
        try {
            String username = person.getUsername();
            if (username != null && !username.isEmpty()) {
                return clean(username);
            }
        } catch (Throwable ignored) {
        }
        try {
            zombie.characters.SurvivorDesc desc = person.getDescriptor();
            if (desc != null) {
                String forename = desc.getForename();
                if (forename != null && !forename.isEmpty()) {
                    String surname = desc.getSurname();
                    return clean(forename
                        + (surname == null || surname.isEmpty()
                            ? "" : " " + surname));
                }
            }
        } catch (Throwable ignored) {
        }
        try {
            return "#" + person.getID();
        } catch (Throwable ignored) {
        }
        return null;
    }

    private static String clean(String s) {
        return s.replace('|', '_').replace(':', '_');
    }

    /** [B41] Any character with a body, not only a survivor
     *  shell. Every member below is an IsoGameCharacter surface
     *  and SAOIsoPlayerShell extends IsoPlayer extends
     *  IsoGameCharacter, so the survivor path is unchanged.
     *  This is what lets the PLAYER acquire beliefs through the
     *  same scanner their people use - the alternative was a
     *  second acquisition path written to look like this one. */
    public static String scan(IsoGameCharacter shell) {
        IsoCell cell = shell.getCell();
        IsoGridSquare eye = shell.getCurrentSquare();
        if (cell == null || eye == null) {
            return "";
        }
        float sx = shell.getX();
        float sy = shell.getY();
        float sz = shell.getZ();
        float faceX = shell.getForwardDirectionX();
        float faceY = shell.getForwardDirectionY();

        StringBuilder out = new StringBuilder(256);

        var zombies = cell.getZombieList();
        for (int index = 0; index < zombies.size(); index++) {
            IsoZombie zombie = zombies.get(index);
            if (zombie == null || zombie.isDead()) {
                continue;
            }
            if (SAOKnox.isKnoxHuman(zombie)) {
                // DR-009: a legacy Knox human is a PERSON in our eyes,
                // never one of the dead - the trust web opens cross-mod.
                appendIfVisible(out, "P", SAOKnox.knoxName(zombie),
                    eye, sx, sy, sz, faceX, faceY, zombie);
                continue;
            }
            appendIfVisible(out, "Z", null, eye, sx, sy, sz, faceX, faceY, zombie);
        }
        // F-011: IsoPlayer.players is the SLOT array - real players only.
        // Off-slot shells live in the cell's moving objects; scanning there
        // is what lets survivors see EACH OTHER, not just the player.
        for (zombie.iso.IsoMovingObject moving : cell.getObjectList()) {
            if (moving instanceof IsoPlayer person
                && person != shell && !person.isDead()) {
                // [A24] full names for OUR shells (two Anas stay two
                // people); the REAL player keeps their username - the
                // player: key domain is untouched.
                String label = person.getUsername();
                // [B10] Three kinds of person, and we say which. Our
                // shells get their full name; the REAL player keeps
                // their username (slot-array verified); anyone
                // ELSE's IsoPlayer-based NPC is marked so the key
                // layer never files them in the player's domain.
                // [B28] The same one test, wherever the question is
                // asked. This used to be inline here and nowhere
                // else, which is why nothing could ever look a
                // foreign person back UP by name.
                if (isForeignPerson(person)) {
                    // [B33] The same derivation the bridge looks them
                    // up by. A constant here made every nameless
                    // person one person, and one nobody could find.
                    String foreign = foreignName(person);
                    label = "~" + (foreign == null ? "someone" : foreign);
                }
                if (person instanceof SAOIsoPlayerShell) {
                    try {
                        zombie.characters.SurvivorDesc desc = person.getDescriptor();
                        if (desc != null && desc.getForename() != null) {
                            String surname = desc.getSurname();
                            label = desc.getForename()
                                + (surname == null || surname.isEmpty()
                                    ? "" : " " + surname);
                        }
                    } catch (Throwable ignored) {
                    }
                }
                appendIfVisible(out, "P", label,
                    eye, sx, sy, sz, faceX, faceY, person);
            }
        }

        // Hearing: world sounds whose own radius reaches this survivor.
        // Omnidirectional, no occlusion (walls muffle, they rarely silence) —
        // and inherently imprecise: the report is the sound's origin tile,
        // which Perception records as a "heard" belief, not an "observed" one.
        var sounds = zombie.WorldSoundManager.instance == null
            ? null : zombie.WorldSoundManager.instance.soundList;
        if (sounds != null) {
            for (int index = 0; index < sounds.size(); index++) {
                var sound = sounds.get(index);
                if (sound == null || !sound.stresshumans && sound.volume <= 0) {
                    continue;
                }
                float dx = sound.x - sx;
                float dy = sound.y - sy;
                float dist = (float) Math.sqrt(dx * dx + dy * dy);
                // [B17] Hard weather MASKS hearing: rain and wind eat
                // a sound's reach, down to half of it in a real
                // storm. Survivors know less in bad weather, which is
                // true, and everything downstream inherits it.
                float reach = sound.radius * weatherHearing();
                if (dist > reach || dist < 0.5f) {
                    continue;
                }
                if (out.length() > 0) {
                    out.append('|');
                }
                // [A24] tile-floored like every sighting: a heard belief
                // and an observed one at the same spot must share a key,
                // or they never merge Lua-side.
                out.append("S:").append((int) Math.floor(sound.x))
                    .append(':').append((int) Math.floor(sound.y))
                    .append(':').append(Math.round(dist * 10.0f) / 10.0f);
            }
        }
        return out.toString();
    }

    private static void appendIfVisible(
        StringBuilder out, String kind, String name,
        IsoGridSquare eye, float sx, float sy, float sz,
        float faceX, float faceY, IsoGameCharacter other) {

        float ox = other.getX();
        float oy = other.getY();
        if (Math.abs(other.getZ() - sz) >= 0.5f) {
            return;
        }
        float dx = ox - sx;
        float dy = oy - sy;
        float dist = (float) Math.sqrt(dx * dx + dy * dy);
        if (dist > RANGE) {
            return;
        }
        if (dist > NEAR_SENSE) {
            // outside near-sense radius, require the facing cone
            float inv = dist <= 0.001f ? 0.0f : 1.0f / dist;
            double alignment = (dx * inv) * faceX + (dy * inv) * faceY;
            if (alignment < CONE_COS) {
                return;
            }
        }
        IsoGridSquare target = other.getCurrentSquare();
        if (target == null || eye.isSomethingTo(target)) {
            return;
        }
        if (out.length() > 0) {
            out.append('|');
        }
        out.append(kind).append(':');
        if (name != null) {
            out.append(sanitize(name)).append(':');
        }
        out.append((int) Math.floor(ox)).append(':')
            .append((int) Math.floor(oy)).append(':')
            .append(Math.round(dist * 10.0f) / 10.0f);
        if ("P".equals(kind)) {
            out.append(':').append(conditionBracket(other));
            if (SAONeeds.isUnkempt(other)) {
                out.append("+u");
            }
        }
        // The turned are recognizable ([B3]): zombies carry their
        // descriptors through death, so a Z row names its zombie as a
        // trailing field - existing parsers read positionally and are
        // unaffected; the belief layer decides whether the name means
        // anything to the witness.
        if ("Z".equals(kind)) {
            try {
                zombie.characters.SurvivorDesc desc = other.getDescriptor();
                if (desc != null) {
                    String fore = desc.getForename();
                    String sur = desc.getSurname();
                    if (fore != null && sur != null) {
                        out.append(':')
                           .append(sanitize(fore + " " + sur));
                    }
                }
            } catch (Throwable ignored) {
            }
        }
    }

    /** [B17] How much of a sound survives the sky: 1.0 in clear
     *  weather, down to 0.5 when rain and wind are both up.
     *
     *  [B20] Public because the cry masks its reach by the SAME
     *  number this scanner masks sound by. A second copy of this
     *  formula in Lua is exactly the drift border 7 of the invariant
     *  sweep exists to catch. */
    public static float weatherHearing() {
        try {
            zombie.iso.weather.ClimateManager climate =
                zombie.iso.weather.ClimateManager.getInstance();
            if (climate == null) return 1.0f;
            float noise = Math.min(1.0f,
                climate.getRainIntensity() * 0.7f
                + climate.getWindIntensity() * 0.3f);
            return 1.0f - 0.5f * noise;
        } catch (Throwable ignored) {
            return 1.0f;
        }
    }

    /** What condition this person LOOKS to be in - readable at a glance the
     * way a limp or blood is: ok, hurt (visibly bleeding or worn down), or
     * bad (close to collapse). */
    private static String conditionBracket(IsoGameCharacter other) {
        try {
            float health = other.getHealth();
            boolean bleeding = other.getBodyDamage() != null
                && other.getBodyDamage().getNumPartsBleeding() > 0;
            float hunger = 0.0f;
            try {
                hunger = other.getStats().get(zombie.characters.CharacterStat.HUNGER);
            } catch (Throwable ignored) {
            }
            // The bite outranks everything ([B3]): a bite wound looks
            // like what it is, and everyone knows what it means.
            try {
                if (other.getBodyDamage() != null
                        && other.getBodyDamage().getNumPartsBitten() > 0) {
                    return "bitten";
                }
            } catch (Throwable ignored) {
            }
            // A wound gone bad shows ([B7]): fever and a foul dressing
            // are visible at a glance, and rank below a bite (which
            // is the worse news) but above ordinary hurt.
            try {
                if (other.getBodyDamage() != null
                        && other.getBodyDamage()
                            .getGeneralWoundInfectionLevel() > 0.0f) {
                    return "fevered";
                }
            } catch (Throwable ignored) {
            }
            // Starvation shows the way wounds do: gaunt reads as bad long
            // before collapse, and visibly hungry reads as hurt.
            if (health < 0.25f || hunger > 0.85f) {
                return "bad";
            }
            if (bleeding || health < 0.5f || hunger > 0.6f) {
                return "hurt";
            }
            return "ok";
        } catch (Throwable throwable) {
            return "ok";
        }
    }

    private static String sanitize(String value) {
        return value.replace('|', '_').replace(':', '_');
    }
}
