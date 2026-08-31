package com.sao.engine;

import zombie.characters.IsoZombie;

/**
 * Legacy-coexistence discriminator (DR-009): the workshop KnoxSurvivors
 * NPCs are IsoZombie-backed human shells. Their own predicate marks them
 * with the animation variable "KnoxSurvivor"/"KnoxSurvivorShell" and
 * modData ids; we honor the same marks. A Knox human is NEVER a threat,
 * NEVER a combat target, NEVER a director subject - and IS a person to
 * the scanner.
 */
public final class SAOKnox {

    private SAOKnox() {
    }

    public static boolean isKnoxHuman(IsoZombie zombie) {
        if (zombie == null) {
            return false;
        }
        try {
            if (zombie.getVariableBoolean("KnoxSurvivor")
                || zombie.getVariableBoolean("KnoxSurvivorShell")) {
                return true;
            }
        } catch (Throwable ignored) {
        }
        try {
            se.krka.kahlua.vm.KahluaTable modData = zombie.getModData();
            if (modData != null) {
                if (modData.rawget("KnoxSurvivorId") != null
                    || modData.rawget("KnoxSurvivorProfileId") != null
                    || modData.rawget("KnoxSurvivor") != null
                    || modData.rawget("KnoxSurvivorShell") != null) {
                    return true;
                }
            }
        } catch (Throwable ignored) {
        }
        return false;
    }

    /** A stable identity for a Knox human: their own profile id when the
     * legacy mod stamped one (modData KnoxSurvivorId/ProfileId), else the
     * forename - two Anas stay two records ([A17] collision seam). */
    public static String knoxId(IsoZombie zombie) {
        try {
            se.krka.kahlua.vm.KahluaTable modData = zombie.getModData();
            if (modData != null) {
                Object id = modData.rawget("KnoxSurvivorId");
                if (id == null) {
                    id = modData.rawget("KnoxSurvivorProfileId");
                }
                if (id != null) {
                    return String.valueOf(id).replace('|', '_').replace(':', '_');
                }
            }
        } catch (Throwable ignored) {
        }
        return knoxName(zombie);
    }

    /** A display name for a Knox human: descriptor forename when real,
     * else a stable fallback so beliefs key consistently. */
    public static String knoxName(IsoZombie zombie) {
        try {
            zombie.characters.SurvivorDesc desc = zombie.getDescriptor();
            if (desc != null) {
                String forename = desc.getForename();
                if (forename != null && !forename.isEmpty()) {
                    String surname = desc.getSurname();
                    return forename + (surname == null || surname.isEmpty()
                        ? "" : " " + surname);
                }
            }
        } catch (Throwable ignored) {
        }
        // [B33] The same collision the foreign path had, in the other
        // place: a constant here made every unnamed legacy human ONE
        // person, and the id that keys their record falls through to
        // this. The object's own id keeps two of them two. Both sides
        // of the lookup call this, so the round trip still closes.
        try {
            return "#" + zombie.getID();
        } catch (Throwable ignored) {
        }
        return "someone";
    }
}
