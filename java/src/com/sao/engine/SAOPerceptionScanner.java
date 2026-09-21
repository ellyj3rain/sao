package com.sao.engine;

import zombie.characters.IsoGameCharacter;
import zombie.characters.IsoPlayer;
import zombie.characters.IsoZombie;
import zombie.characters.animals.IsoAnimal;
import zombie.iso.IsoCell;
import zombie.iso.IsoGridSquare;
import zombie.iso.LosUtil;
import zombie.iso.weather.ClimateManager;
import zombie.inventory.ItemContainer;
import zombie.scripting.objects.CharacterTrait;

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
        if (person == null || person instanceof IsoAnimal
            || person instanceof SAOIsoPlayerShell) {
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
            try {
                if (zombie.isUseless()) {
                    // [C124] Stealth mod / debug AI deactivation: useless
                    // zombies are left alone; nothing to perceive while active.
                    continue;
                }
            } catch (Throwable ignored) {
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
                && !(person instanceof IsoAnimal)
                && person != shell && !person.isDead()) {
                // [C60] Animals inherit IsoPlayer in Build 42. Classify them
                // before this human-output branch; isForeignPerson only
                // chooses a person's key and cannot suppress a P row.
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
        if (!visibleFrom(eye, sx, sy, sz, faceX, faceY, other, RANGE)) {
            return;
        }
        float ox = other.getX();
        float oy = other.getY();
        float dx = ox - sx;
        float dy = oy - sy;
        float dist = (float) Math.sqrt(dx * dx + dy * dy);
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
            if (isProneOrCrawling(other)) {
                out.append("+p");
            }
            appendZaoForm(out, other);
        }
        // The turned are recognizable ([B3], corrected [C8]): descriptors
        // do NOT survive the turn - reanimate() builds the zombie a fresh
        // one carrying gender and voice only (F-044). What DOES survive is
        // the body's modData, which the engine itself copies character ->
        // corpse -> risen body, so the person id stamped on the living
        // shell walks. A Z row therefore tags its zombie "@<id>" when the
        // mark is there; the bare descriptor name stays as the trailing
        // field for bodies that never died through that path (the
        // neighbour framework's living people read as Z too). Existing
        // parsers read positionally and are unaffected; the belief layer
        // decides whether the identity means anything to the witness.
        if ("Z".equals(kind)) {
            out.append(':');
            String tag = "";
            try {
                Object mark = other.getModData().rawget("SAOPersonId");
                if (mark instanceof String personId && !personId.isEmpty()) {
                    // Knox record ids carry ':' ("ks:<kid>"), which is this
                    // protocol's field separator - encoded reversibly as
                    // '~', decoded by the one Lua reader (resolveBodyTag).
                    tag = "@" + sanitize(personId.replace(':', '~'));
                } else {
                    zombie.characters.SurvivorDesc desc = other.getDescriptor();
                    if (desc != null) {
                        String fore = desc.getForename();
                        String sur = desc.getSurname();
                        if (fore != null && sur != null) {
                            tag = sanitize(fore + " " + sur);
                        }
                    }
                }
            } catch (Throwable ignored) {
            }
            out.append(tag);
            appendZaoForm(out, other);
            if (isProneOrCrawling(other)) {
                out.append(":prone");
            }
        }
    }

    /**
     * [C60] Current physical visibility for an action participant. The
     * candidate still has to come from the observer's belief store; this is
     * the use-time recheck against the same floor, facing and occlusion law
     * used by acquisition.
     */
    public static boolean canSeePersonNow(IsoGameCharacter observer,
                                           IsoGameCharacter other,
                                           float actionRange) {
        if (observer == null || other == null || observer == other
                || other instanceof IsoAnimal || actionRange < 0.0f) {
            return false;
        }
        try {
            if (observer.isDead() || other.isDead()) {
                return false;
            }
            IsoGridSquare eye = observer.getCurrentSquare();
            if (eye == null) {
                return false;
            }
            return visibleFrom(
                eye,
                observer.getX(), observer.getY(), observer.getZ(),
                observer.getForwardDirectionX(), observer.getForwardDirectionY(),
                other, Math.min(RANGE, actionRange));
        } catch (Throwable ignored) {
            return false;
        }
    }

    /** Admit a firsthand transfer observation at its native completion boundary. */
    public static boolean canWitnessWorldTransfer(IsoGameCharacter observer,
            IsoGameCharacter actor, ItemContainer container, float actionRange) {
        try {
            if (!Float.isFinite(actionRange) || actionRange < 0.0f
                    || observer == actor || !awakeHuman(observer)
                    || !awakeHuman(actor) || container == null
                    || !Float.isFinite(observer.getForwardDirectionX())
                    || !Float.isFinite(observer.getForwardDirectionY())
                    || !sameLoadedCell(observer, actor)) return false;
            float actorRange = isProneOrCrawling(actor)
                ? Math.min(actionRange, Math.max(NEAR_SENSE, RANGE * 0.6f)) : actionRange;
            if (!visibleTransferPoint(observer, actor.getCurrentSquare(),
                    actor.getX(), actor.getY(), actor.getZ(),
                    Math.min(RANGE, actorRange))) return false;
            IsoGridSquare target = transferSquare(container, actor.getCell());
            return target != null && visibleWorldPoint(observer, target,
                Math.min(RANGE, actionRange));
        } catch (Throwable unavailable) {
            return false;
        }
    }

    /** A directed spoken exchange: the listener must be able to hear it now. */
    public static boolean canConverseNow(IsoGameCharacter speaker,
            IsoGameCharacter listener, float actionRange) {
        try {
            if (!Float.isFinite(actionRange) || actionRange < 0.0f
                    || speaker == listener || !awakeHuman(speaker)
                    || !awakeHuman(listener) || !sameLoadedCell(speaker, listener)
                    || listener.hasTrait(CharacterTrait.DEAF)) return false;
            float hearing = listener.getWornItemsHearingMultiplier();
            float weather = speechWeatherHearing();
            if (!Float.isFinite(hearing) || hearing <= 0.0f
                    || !Float.isFinite(weather) || weather <= 0.0f) return false;
            float reach = Math.min(RANGE, actionRange)
                * Math.min(1.0f, hearing) * Math.min(1.0f, weather);
            return withinSameFloorRange(speaker.getX(), speaker.getY(),
                speaker.getZ(), listener.getX(), listener.getY(), listener.getZ(),
                reach) && clearPath(speaker.getCurrentSquare(),
                    listener.getCurrentSquare(), false);
        } catch (Throwable unavailable) {
            return false;
        }
    }

    private static boolean awakeHuman(IsoGameCharacter person) {
        return person != null && !(person instanceof IsoAnimal)
            && (person instanceof IsoPlayer
                || (person instanceof IsoZombie zombie && SAOKnox.isKnoxHuman(zombie)))
            && !person.isDead() && !person.isAsleep()
            && Float.isFinite(person.getX()) && Float.isFinite(person.getY())
            && Float.isFinite(person.getZ());
    }

    /** Installed IsoGameCharacter.getWeatherHearingMultiplier, without a body. */
    public static float speechWeatherHearing() {
        try {
            ClimateManager climate = ClimateManager.getInstance();
            if (climate == null) return Float.NaN;
            float rain = climate.getRainIntensity(), fog = climate.getFogIntensity();
            if (!Float.isFinite(rain) || rain < 0.0f || rain > 1.0f
                    || !Float.isFinite(fog) || fog < 0.0f || fog > 1.0f) return Float.NaN;
            return 1.0f - rain * 0.33f - fog * 0.1f;
        } catch (Throwable unavailable) {
            return Float.NaN;
        }
    }

    private static boolean sameLoadedCell(IsoGameCharacter a, IsoGameCharacter b) {
        IsoCell cell = a.getCell();
        return cell != null && b.getCell() == cell
            && currentSquare(a, cell) && currentSquare(b, cell);
    }

    private static boolean currentSquare(IsoGameCharacter person, IsoCell cell) {
        IsoGridSquare square = person.getCurrentSquare();
        return square != null && square.getCell() == cell
            && cell.getGridSquare(square.getX(), square.getY(), square.getZ()) == square;
    }

    /** Resolve only the world holder that still owns this exact container. */
    private static IsoGridSquare transferSquare(ItemContainer container, IsoCell cell) {
        IsoGridSquare square;
        if (container.isVehiclePart()) {
            var vehicle = container.getVehicle();
            var part = container.getVehiclePart();
            if (vehicle == null || part == null || vehicle.isRemovedFromWorld()
                    || !cell.getVehicles().contains(vehicle)
                    || part.getItemContainer() != container) return null;
            String area = part.getArea();
            square = area == null || area.isBlank()
                ? vehicle.getSquare() : vehicle.getSquareForArea(area);
        } else {
            var parent = container.getParent();
            square = parent == null ? null : parent.getSquare();
            if (square == null || !square.getObjects().contains(parent)) return null;
            boolean owns = false;
            for (int index = 0; index < parent.getContainerCount(); index++) {
                if (parent.getContainerByIndex(index) == container) owns = true;
            }
            if (!owns) return null;
        }
        return square != null && square.getCell() == cell
            && cell.getGridSquare(square.getX(), square.getY(), square.getZ()) == square
            ? square : null;
    }

    private static boolean visibleWorldPoint(IsoGameCharacter observer,
            IsoGridSquare target, float range) {
        return visibleTransferPoint(observer, target, target.getX() + 0.5f,
            target.getY() + 0.5f, target.getZ(), range);
    }

    private static boolean visibleTransferPoint(IsoGameCharacter observer,
            IsoGridSquare target, float x, float y, float z, float range) {
        float sx = observer.getX(), sy = observer.getY(), sz = observer.getZ();
        if (!withinSameFloorRange(sx, sy, sz, x, y, z, range)) {
            return false;
        }
        double dx = (double) x - sx, dy = (double) y - sy;
        double distance = Math.sqrt(dx * dx + dy * dy);
        if (distance > NEAR_SENSE) {
            double alignment = (dx * observer.getForwardDirectionX()
                + dy * observer.getForwardDirectionY()) / distance;
            if (alignment < CONE_COS) return false;
        }
        return clearPath(observer.getCurrentSquare(), target, true);
    }

    private static boolean withinSameFloorRange(float ax, float ay, float az,
            float bx, float by, float bz, float range) {
        if (!Float.isFinite(ax) || !Float.isFinite(ay) || !Float.isFinite(az)
                || !Float.isFinite(bx) || !Float.isFinite(by) || !Float.isFinite(bz)
                || !Float.isFinite(range) || range < 0.0f
                || Math.abs(az - bz) >= 0.5f) return false;
        double dx = (double) ax - bx, dy = (double) ay - by;
        return dx * dx + dy * dy <= (double) range * range;
    }

    /** Endpoint adjacency alone does not inspect intervening tiles. */
    private static boolean clearPath(IsoGridSquare from, IsoGridSquare to,
            boolean visual) {
        LosUtil.TestResults result = LosUtil.lineClear(from.getCell(),
            from.getX(), from.getY(), from.getZ(), to.getX(), to.getY(), to.getZ(), false);
        return result == LosUtil.TestResults.Clear
            || result == LosUtil.TestResults.ClearThroughOpenDoor
            || (visual && result == LosUtil.TestResults.ClearThroughWindow);
    }

    private static boolean visibleFrom(
            IsoGridSquare eye, float sx, float sy, float sz,
            float faceX, float faceY, IsoGameCharacter other,
            float requestedRange) {
        float ox = other.getX();
        float oy = other.getY();
        if (Math.abs(other.getZ() - sz) >= 0.5f) {
            return false;
        }
        float dx = ox - sx;
        float dy = oy - sy;
        float dist = (float) Math.sqrt(dx * dx + dy * dy);
        // [C124] Ground stance: a prone or crawling body presents a reduced
        // visual silhouette. Beyond near-sense, perception range is reduced.
        float stanceRange = isProneOrCrawling(other)
            ? Math.max(NEAR_SENSE, RANGE * 0.6f) : RANGE;
        float maxRange = Math.min(requestedRange, stanceRange);
        if (dist > maxRange) {
            return false;
        }
        if (dist > NEAR_SENSE) {
            // outside near-sense radius, require the facing cone
            float inv = dist <= 0.001f ? 0.0f : 1.0f / dist;
            double alignment = (dx * inv) * faceX + (dy * inv) * faceY;
            if (alignment < CONE_COS) {
                return false;
            }
        }
        IsoGridSquare target = other.getCurrentSquare();
        return target != null && !eye.isSomethingTo(target);
    }

    /** [C104] The sister mod's form and performance, appended the
     *  same way for the living and the turned: whichever kind of body
     *  carries the marks, the crossing reads identically, and the one
     *  place this was two copies was the one place the two spellings
     *  could have drifted apart (Border 14's finding). The guard lives
     *  here so both callers share one try; a body without the marks
     *  appends nothing.
     */
    private static void appendZaoForm(StringBuilder out, IsoGameCharacter other) {
        try {
            Object form = other.getModData().rawget("ZAOForm");
            Object performance =
                other.getModData().rawget("ZAOFormPerformance");
            if (form instanceof String formName
                && !formName.isEmpty()
                && performance instanceof Number performanceNumber) {
                out.append(":zao:")
                   .append(sanitize(formName))
                   .append(':')
                   .append(Math.round(performanceNumber.doubleValue() * 100.0) / 100.0);
                Object attributes =
                    other.getModData().rawget("ZAOAttributes");
                if (attributes instanceof String attributeText
                    && !attributeText.isBlank()) {
                    String encoded = attributeText
                        .replace('|', ';')
                        .replace(':', '=');
                    out.append(":attrs:")
                       .append(sanitize(encoded));
                }
            }
        } catch (Throwable ignored) {
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

    /**
     * [C124] Ground stance recognition: engine knocked down/crawler states,
     * or mod-authored prone and crawl states stored in animation variables
     * or modData.
     */
    public static boolean isProneOrCrawling(IsoGameCharacter character) {
        if (character == null) {
            return false;
        }
        try {
            if (character.isOnFloor()) {
                return true;
            }
        } catch (Throwable ignored) {
        }
        try {
            if (character instanceof IsoZombie zombie && zombie.isCrawling()) {
                return true;
            }
        } catch (Throwable ignored) {
        }
        try {
            if (character.getVariableBoolean("isProne")
                || character.getVariableBoolean("Prone")
                || character.getVariableBoolean("isCrawling")
                || character.getVariableBoolean("Crawling")
                || character.getVariableBoolean("Crawl")
                // Lethal Stealth 42 writes this exact animation variable.
                || character.getVariableBoolean("ltsproneposition")) {
                return true;
            }
        } catch (Throwable ignored) {
        }
        try {
            var modData = character.getModData();
            if (modData != null) {
                Object p = modData.rawget("isProne");
                if (Boolean.TRUE.equals(p) || "true".equals(String.valueOf(p))) {
                    return true;
                }
                Object c = modData.rawget("isCrawling");
                if (Boolean.TRUE.equals(c) || "true".equals(String.valueOf(c))) {
                    return true;
                }
                // Lethal Stealth 42 mirrors its prone state here.
                Object lts = modData.rawget("ret_lts_acostado");
                if (Boolean.TRUE.equals(lts)
                        || "true".equals(String.valueOf(lts))) {
                    return true;
                }
            }
        } catch (Throwable ignored) {
        }
        return false;
    }

    private static String sanitize(String value) {
        return value.replace('|', '_').replace(':', '_');
    }
}
