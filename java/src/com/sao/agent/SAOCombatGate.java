package com.sao.agent;

/**
 * The predicate the melee-callback patch redirects to, plus the readiness
 * flag combat refuses to start without. The patched callbacks originally call
 * the static IsoPlayer.isLocalPlayer(IsoGameCharacter); this gate answers the
 * same question while also admitting the SAO shell, so an NPC swing's
 * collision/sound callbacks fire exactly as a player's do.
 */
public final class SAOCombatGate {

    private static volatile int patchedCalls;

    private SAOCombatGate() {
    }

    public static boolean allowLocalCombatHook(Object character) {
        if (character instanceof com.sao.engine.SAOIsoPlayerShell) {
            return true;
        }
        if (character instanceof zombie.characters.IsoGameCharacter gameCharacter) {
            return zombie.characters.IsoPlayer.isLocalPlayer(gameCharacter);
        }
        return false;
    }

    public static void markPatchReady(int count) {
        patchedCalls = count;
    }

    public static boolean isPatchReady() {
        return patchedCalls == SAOMeleeTransformer.EXPECTED_PATCH_COUNT;
    }

    public static int getPatchedCallCount() {
        return patchedCalls;
    }
}
