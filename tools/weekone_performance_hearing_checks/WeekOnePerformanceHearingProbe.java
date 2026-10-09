import com.sao.engine.SAOIsoPlayerShell;
import com.sao.engine.SAOPerceptionScanner;
import com.sao.engine.SAOWorldSoundPulses;
import java.lang.reflect.Field;
import zombie.WorldSoundManager;
import zombie.GameTime;
import zombie.characters.IsoGameCharacter;
import zombie.characters.IsoZombie;
import zombie.characters.SurvivorDesc;
import zombie.iso.IsoCell;
import zombie.scripting.objects.CharacterTrait;

/** Installed geometry, scanner and exact Week One physical sound custody. */
public final class WeekOnePerformanceHearingProbe {
    private static void check(boolean value, String name) {
        System.out.println("CHECK " + name + "=" + value);
        if (!value) throw new AssertionError(name);
    }

    private static WorldSoundManager.WorldSound sound(IsoZombie performer) {
        SAOWorldSoundPulses.resetRuntimeForWorld();
        WorldSoundManager.instance.soundList.clear();
        return WorldSoundManager.instance.addSound(performer,
            (int)Math.floor(performer.getX()),
            (int)Math.floor(performer.getY()), 0, 45, 45,
            false, 0, 1, false, true, false, false, true);
    }

    private static void position(IsoGameCharacter body, IsoCell cell, float x, float y) {
        body.setX(x); body.setY(y); body.setZ(0);
        var square = cell.getGridSquare((int)x, (int)y, 0);
        body.setCurrent(square); body.setSquare(square);
        square.getMovingObjects().add(body); cell.getObjectList().add(body);
    }

    public static void main(String[] args) throws Exception {
        var boot = MovementCrossingProbe.class.getDeclaredMethod("boot");
        boot.setAccessible(true);
        IsoCell cell = (IsoCell) boot.invoke(null);
        var makePerson = MovementCrossingProbe.class.getDeclaredMethod("person", IsoCell.class);
        makePerson.setAccessible(true);
        SAOIsoPlayerShell observer = (SAOIsoPlayerShell) makePerson.invoke(null, cell);
        observer.getModData().rawset("SAOPersonId", "listener");
        observer.setForwardDirection(1, 0);
        observer.getCurrentSquare().getMovingObjects().add(observer);
        cell.getObjectList().add(observer);

        IsoZombie performer = new IsoZombie(cell, new SurvivorDesc(), 0);
        position(performer, cell, 14.5f, 20.5f);
        performer.setVariable("Bandit", true);
        performer.setPersistentOutfitID(73);
        var marks = performer.getModData();
        marks.rawset("SAOWeekOneOrigin", "BanditsWeekOne");
        marks.rawset("SAOWeekOnePersonId", "bwo-73");
        marks.rawset("SAOWeekOneBrainId", 73.0);
        marks.rawset("SAOWeekOneBorn", 12.5);
        marks.rawset("SAOWeekOneName", "Ari Vale");
        var emitter = new InstrumentProbe.Emitter(performer);
        Field emitterField = IsoGameCharacter.class.getDeclaredField("emitter");
        emitterField.setAccessible(true);
        emitterField.set(performer, emitter);
        long handle = emitter.playSound("BWOInstrumentBassGuitar1");
        var first = sound(performer);
        check(SAOWorldSoundPulses.bindWeekOnePerformance(performer, first,
            "bwo-73", 74, 12.5, "BWOInstrumentBassGuitar1", handle) == null,
            "wrong_brain_refused");
        check(SAOWorldSoundPulses.bindWeekOnePerformance(performer, first,
            "bwo-73", 73, 13.5, "BWOInstrumentBassGuitar1", handle) == null,
            "wrong_birth_refused");
        check(SAOWorldSoundPulses.bindWeekOnePerformance(performer, first,
            "bwo-73", 73, 12.5, "BWOInstrumentBassGuitar1", handle + 100) == null,
            "wrong_handle_refused");
        var occurrence = SAOWorldSoundPulses.bindWeekOnePerformance(performer, first,
            "bwo-73", 73, 12.5, "BWOInstrumentBassGuitar1", handle);
        check(occurrence != null && "bwo-73".equals(occurrence.rawget("actorId"))
            && ((Number) occurrence.rawget("soundHandle")).longValue() == handle,
            "exact_physical_occurrence_bound");
        String pulse = (String) occurrence.rawget("pulseId");
        check(SAOWorldSoundPulses.claimWeekOnePerformance(observer, performer,
            "bwo-73", 73, 12.5, pulse) == null,
            "no_hearing_before_scan");
        check(SAOPerceptionScanner.canSeePersonNow(observer, performer, 16),
            "native_visible_performer");
        String scan = SAOPerceptionScanner.scan(observer);
        check(scan.contains(":cue:" + pulse), "native_scanner_acquired_sound");
        var heard = SAOWorldSoundPulses.claimWeekOnePerformance(observer, performer,
            "bwo-73", 73, 12.5, pulse);
        check(heard != null && "listener".equals(heard.rawget("observerId"))
            && "sao.weekone-performance-hearing/1".equals(heard.rawget("schema"))
            && "native-scanner-acquired-occurrence".equals(heard.rawget("basis")),
            "private_attributable_hearing");
        check(SAOWorldSoundPulses.claimWeekOnePerformance(observer, performer,
            "bwo-73", 73, 12.5, pulse) == null, "one_claim_per_listener");
        SAOIsoPlayerShell second = (SAOIsoPlayerShell) makePerson.invoke(null, cell);
        second.getModData().rawset("SAOPersonId", "listener-two");
        second.setForwardDirection(1, 0);
        second.getCurrentSquare().getMovingObjects().add(second);
        cell.getObjectList().add(second);
        check(SAOWorldSoundPulses.claimWeekOnePerformance(second, performer,
            "bwo-73", 73, 12.5, pulse) == null,
            "second_person_has_no_borrowed_acquisition");
        SAOPerceptionScanner.scan(second);
        var secondHearing = SAOWorldSoundPulses.claimWeekOnePerformance(second,
            performer, "bwo-73", 73, 12.5, pulse);
        check(secondHearing != null
            && "listener-two".equals(secondHearing.rawget("observerId"))
            && SAOWorldSoundPulses.claimWeekOnePerformance(second, performer,
                "bwo-73", 73, 12.5, pulse) == null,
            "second_person_owns_independent_one_time_hearing");

        // The source renews one still-playing occurrence. A listener arriving
        // later acquires it now; an earlier scanner receipt becomes stale.
        SAOIsoPlayerShell stale = (SAOIsoPlayerShell) makePerson.invoke(null, cell);
        stale.getModData().rawset("SAOPersonId", "stale-listener");
        stale.setForwardDirection(1, 0);
        stale.getCurrentSquare().getMovingObjects().add(stale);
        cell.getObjectList().add(stale);
        SAOIsoPlayerShell late = (SAOIsoPlayerShell) makePerson.invoke(null, cell);
        late.getModData().rawset("SAOPersonId", "late-listener");
        late.setForwardDirection(1, 0);
        late.getCurrentSquare().getMovingObjects().add(late);
        cell.getObjectList().add(late);
        var sustained = sound(performer);
        var sustainedRow = SAOWorldSoundPulses.bindWeekOnePerformance(performer,
            sustained, "bwo-73", 73, 12.5, "BWOInstrumentBassGuitar1", handle);
        String sustainedPulse = (String) sustainedRow.rawget("pulseId");
        check(SAOPerceptionScanner.scan(stale).contains(":cue:" + sustainedPulse),
            "stale_listener_initially_acquired");
        double started = GameTime.getInstance().getWorldAgeHours();
        GameTime.getInstance().setTimeOfDay(GameTime.getInstance().getTimeOfDay() + 0.10f);
        check(GameTime.getInstance().getWorldAgeHours() - started > 0.05
            && SAOWorldSoundPulses.renewWeekOnePerformance(performer, sustainedPulse),
            "renewed_sound_outlives_initial_claim_window");
        check(SAOWorldSoundPulses.claimWeekOnePerformance(late, performer,
            "bwo-73", 73, 12.5, sustainedPulse) == null,
            "late_listener_needs_own_scan");
        check(SAOPerceptionScanner.scan(late).contains(":cue:" + sustainedPulse),
            "late_listener_acquires_renewed_sound");
        var lateHearing = SAOWorldSoundPulses.claimWeekOnePerformance(late,
            performer, "bwo-73", 73, 12.5, sustainedPulse);
        check(lateHearing != null
            && "late-listener".equals(lateHearing.rawget("observerId"))
            && ((Number) lateHearing.rawget("emittedAtHours")).doubleValue() <
                ((Number) lateHearing.rawget("heardAtHours")).doubleValue()
            && SAOWorldSoundPulses.claimWeekOnePerformance(late, performer,
                "bwo-73", 73, 12.5, sustainedPulse) == null,
            "fresh_late_acquisition_claims_live_renewed_sound_once");
        check(SAOWorldSoundPulses.claimWeekOnePerformance(stale, performer,
            "bwo-73", 73, 12.5, sustainedPulse) == null,
            "stale_acquisition_still_refused");

        var pooled = sound(performer);
        var pooledRow = SAOWorldSoundPulses.bindWeekOnePerformance(performer,
            pooled, "bwo-73", 73, 12.5, "BWOInstrumentBassGuitar1", handle);
        String pooledPulse = (String) pooledRow.rawget("pulseId");
        check(SAOPerceptionScanner.scan(observer).contains(":cue:" + pooledPulse),
            "pooled_listener_initially_acquired");
        SAOWorldSoundPulses.initialized(pooled);
        check(SAOWorldSoundPulses.claimWeekOnePerformance(observer, performer,
            "bwo-73", 73, 12.5, pooledPulse) == null,
            "pooled_reinit_refuses_old_occurrence");
        var removed = sound(performer);
        var removedRow = SAOWorldSoundPulses.bindWeekOnePerformance(performer,
            removed, "bwo-73", 73, 12.5, "BWOInstrumentBassGuitar1", handle);
        String removedPulse = (String) removedRow.rawget("pulseId");
        check(SAOPerceptionScanner.scan(observer).contains(":cue:" + removedPulse),
            "removed_listener_initially_acquired");
        WorldSoundManager.instance.soundList.remove(removed);
        check(SAOWorldSoundPulses.claimWeekOnePerformance(observer, performer,
            "bwo-73", 73, 12.5, removedPulse) == null,
            "removed_world_sound_refuses_claim");
        var expired = sound(performer);
        var expiredRow = SAOWorldSoundPulses.bindWeekOnePerformance(performer,
            expired, "bwo-73", 73, 12.5, "BWOInstrumentBassGuitar1", handle);
        String expiredPulse = (String) expiredRow.rawget("pulseId");
        check(SAOPerceptionScanner.scan(observer).contains(":cue:" + expiredPulse),
            "expired_listener_initially_acquired");
        expired.life = 0;
        check(SAOWorldSoundPulses.claimWeekOnePerformance(observer, performer,
            "bwo-73", 73, 12.5, expiredPulse) == null,
            "expired_world_sound_refuses_claim");

        IsoZombie proxyListener = new IsoZombie(cell, new SurvivorDesc(), 0);
        position(proxyListener, cell, 11.5f, 20.5f);
        proxyListener.setForwardDirection(1, 0);
        proxyListener.setVariable("Bandit", true);
        proxyListener.setPersistentOutfitID(88);
        var proxyMarks = proxyListener.getModData();
        proxyMarks.rawset("SAOWeekOneOrigin", "BanditsWeekOne");
        proxyMarks.rawset("SAOWeekOnePersonId", "bwo-88");
        proxyMarks.rawset("SAOWeekOneBrainId", 88.0);
        proxyMarks.rawset("SAOWeekOneBorn", 14.5);
        proxyMarks.rawset("SAOWeekOneName", "Morgan Vale");
        var proxySound = sound(performer);
        var proxyRow = SAOWorldSoundPulses.bindWeekOnePerformance(performer,
            proxySound, "bwo-73", 73, 12.5, "BWOInstrumentBassGuitar1", handle);
        String proxyPulse = (String) proxyRow.rawget("pulseId");
        check(SAOWorldSoundPulses.claimWeekOnePerformance(proxyListener, performer,
            "bwo-73", 73, 12.5, proxyPulse) == null,
            "proxy_listener_needs_own_scan");
        check(SAOPerceptionScanner.scan(proxyListener).contains(":cue:" + proxyPulse),
            "stamped_proxy_scanner_acquires_sound");
        var proxyHearing = SAOWorldSoundPulses.claimWeekOnePerformance(
            proxyListener, performer, "bwo-73", 73, 12.5, proxyPulse);
        check(proxyHearing != null
            && "bwo-88".equals(proxyHearing.rawget("observerId"))
            && ((Number) proxyHearing.rawget("observerBrainId")).doubleValue() == 88.0
            && ((Number) proxyHearing.rawget("observerBorn")).doubleValue() == 14.5
            && "bwo-73".equals(proxyHearing.rawget("actorId"))
            && SAOWorldSoundPulses.claimWeekOnePerformance(proxyListener, performer,
                "bwo-73", 73, 12.5, proxyPulse) == null,
            "stamped_proxy_owns_private_hearing_once");
        var swapSound = sound(performer);
        var swapRow = SAOWorldSoundPulses.bindWeekOnePerformance(performer,
            swapSound, "bwo-73", 73, 12.5, "BWOInstrumentBassGuitar1", handle);
        String swapPulse = (String) swapRow.rawget("pulseId");
        check(SAOPerceptionScanner.scan(proxyListener).contains(":cue:" + swapPulse),
            "proxy_generation_swap_initially_acquired");
        proxyMarks.rawset("SAOWeekOneBorn", 14.6);
        check(SAOWorldSoundPulses.claimWeekOnePerformance(proxyListener, performer,
            "bwo-73", 73, 12.5, swapPulse) == null,
            "proxy_generation_swap_refused");
        proxyMarks.rawset("SAOWeekOneBorn", 14.5);
        check(SAOWorldSoundPulses.claimWeekOnePerformance(proxyListener, performer,
            "bwo-73", 73, 12.5, swapPulse) == null,
            "restored_proxy_marks_cannot_reuse_scan");
        check(SAOPerceptionScanner.scan(proxyListener).contains(":cue:" + swapPulse)
            && SAOWorldSoundPulses.claimWeekOnePerformance(proxyListener, performer,
                "bwo-73", 73, 12.5, swapPulse) != null,
            "restored_proxy_requires_fresh_scan");
        var forged = new IsoZombie(cell, new SurvivorDesc(), 0);
        position(forged, cell, 11.5f, 21.5f);
        forged.setForwardDirection(1, 0);
        forged.setVariable("Bandit", true);
        forged.setPersistentOutfitID(88);
        var forgedMarks = forged.getModData();
        forgedMarks.rawset("SAOWeekOneOrigin", "BanditsWeekOne");
        forgedMarks.rawset("SAOWeekOnePersonId", "bwo-88");
        forgedMarks.rawset("SAOWeekOneBrainId", 88.0);
        forgedMarks.rawset("SAOWeekOneBorn", 14.5);
        forgedMarks.rawset("SAOWeekOneName", "Morgan Vale");
        check(SAOWorldSoundPulses.claimWeekOnePerformance(forged, performer,
            "bwo-73", 73, 12.5, swapPulse) == null,
            "matching_proxy_marks_cannot_borrow_other_body_scan");

        var blocked = sound(performer);
        var blockedRow = SAOWorldSoundPulses.bindWeekOnePerformance(performer, blocked,
            "bwo-73", 73, 12.5, "BWOInstrumentBassGuitar1", handle);
        String blockedPulse = (String) blockedRow.rawget("pulseId");
        observer.setForwardDirection(-1, 0);
        check(!SAOPerceptionScanner.canSeePersonNow(observer, performer, 16),
            "native_facing_blocks_attribution");
        check(SAOPerceptionScanner.scan(observer).contains(":cue:" + blockedPulse),
            "native_sound_stays_audible_when_emitter_unseen");
        check(SAOWorldSoundPulses.claimWeekOnePerformance(observer, performer,
            "bwo-73", 73, 12.5, blockedPulse) == null,
            "unseen_emitter_not_identified");
        observer.setForwardDirection(1, 0);
        check(SAOWorldSoundPulses.claimWeekOnePerformance(observer, performer,
            "bwo-73", 73, 12.5, blockedPulse) == null,
            "later_sight_does_not_rewrite_anonymous_sound");

        var ended = sound(performer);
        var endedRow = SAOWorldSoundPulses.bindWeekOnePerformance(performer, ended,
            "bwo-73", 73, 12.5, "BWOInstrumentBassGuitar1", handle);
        String endedPulse = (String) endedRow.rawget("pulseId");
        SAOPerceptionScanner.scan(observer);
        emitter.finish();
        check(SAOWorldSoundPulses.claimWeekOnePerformance(observer, performer,
            "bwo-73", 73, 12.5, endedPulse) == null,
            "ended_audio_refuses_claim");
        handle = emitter.playSound("BWOInstrumentBassGuitar1");
        var generation = sound(performer);
        var generationRow = SAOWorldSoundPulses.bindWeekOnePerformance(performer, generation,
            "bwo-73", 73, 12.5, "BWOInstrumentBassGuitar1", handle);
        String generationPulse = (String) generationRow.rawget("pulseId");
        SAOPerceptionScanner.scan(observer);
        marks.rawset("SAOWeekOneBorn", 13.5);
        check(SAOWorldSoundPulses.claimWeekOnePerformance(observer, performer,
            "bwo-73", 73, 12.5, generationPulse) == null,
            "body_generation_change_refuses_claim");
        marks.rawset("SAOWeekOneBorn", 12.5);
        observer.getCharacterTraits().set(CharacterTrait.DEAF, true);
        check(SAOWorldSoundPulses.claimWeekOnePerformance(observer, performer,
            "bwo-73", 73, 12.5, generationPulse) == null,
            "deaf_listener_refuses_claim");
        observer.getCharacterTraits().set(CharacterTrait.DEAF, false);
        generation.life = 1;
        check(SAOWorldSoundPulses.renewWeekOnePerformance(performer, generationPulse)
            && generation.life == 16, "source_renews_only_live_sound");
        check(SAOWorldSoundPulses.revokeWeekOnePerformance(performer, generationPulse)
            && generation.life == 0, "source_revokes_exact_world_sound");
        check(SAOWorldSoundPulses.claimWeekOnePerformance(observer, performer,
            "bwo-73", 73, 12.5, generationPulse) == null,
            "revoked_sound_refuses_claim");
        var reloaded = sound(performer);
        var reloadedRow = SAOWorldSoundPulses.bindWeekOnePerformance(performer, reloaded,
            "bwo-73", 73, 12.5, "BWOInstrumentBassGuitar1", handle);
        String reloadPulse = (String) reloadedRow.rawget("pulseId");
        SAOPerceptionScanner.scan(observer);
        SAOWorldSoundPulses.resetRuntimeForWorld();
        check(SAOWorldSoundPulses.claimWeekOnePerformance(observer, performer,
            "bwo-73", 73, 12.5, reloadPulse) == null,
            "reload_discards_runtime_authority");
        WorldSoundManager.instance.soundList.clear();
        System.out.println("PASS Week One physical performance hearing");
    }
}
