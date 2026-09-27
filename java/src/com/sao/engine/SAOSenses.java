package com.sao.engine;

import zombie.characters.IsoGameCharacter;
import zombie.characters.IsoPlayer;
import zombie.characters.IsoZombie;
import zombie.characters.animals.IsoAnimal;
import zombie.iso.Vector2;
import zombie.scripting.objects.CharacterTrait;

/** Shared current native sense access, without actor knowledge or decisions. */
public final class SAOSenses {
    private SAOSenses() {}

    public static boolean awakeHuman(IsoGameCharacter body) {
        return body != null && !(body instanceof IsoAnimal)
            && (body instanceof IsoPlayer || body instanceof IsoZombie zombie && SAOKnox.isKnoxHuman(zombie))
            && !body.isDead() && !body.isAsleep()
            && Float.isFinite(body.getX()) && Float.isFinite(body.getY()) && Float.isFinite(body.getZ());
    }

    /** PZ's inverse hearing-distance modifier includes worn gear and Hard of Hearing. */
    public static float hearing(IsoGameCharacter body, boolean includeWeather) {
        try {
            if (!awakeHuman(body) || body.hasTrait(CharacterTrait.DEAF)) return 0;
            float distanceModifier = body.getHearDistanceModifier();
            float weather = includeWeather ? body.getWeatherHearingMultiplier() : 1;
            if (!Float.isFinite(distanceModifier) || distanceModifier <= 0
                    || !Float.isFinite(weather) || weather <= 0) return 0;
            return Math.min(1, 1 / distanceModifier) * Math.min(1, weather);
        } catch (Throwable unavailable) { return 0; }
    }

    /** No desired heading masquerades as an already completed native turn. */
    public static Vector2 gaze(IsoGameCharacter body, Vector2 out) {
        float angle = gazeAngle(body);
        if (!Float.isFinite(angle)) return out.set(Float.NaN, Float.NaN);
        return out.setLengthAndDirection(angle, 1);
    }

    public static float gazeAngle(IsoGameCharacter body) {
        if (body == null) return Float.NaN;
        float angle = nativeGazeAngle(body);
        if (body instanceof SAOIsoPlayerShell shell) {
            angle += SAOOrientationAnimation.physicalHeadOffset(shell);
        }
        return angle;
    }
    /** Same installed angle convention, reading the last prepared pose without lazy initialization. */
    static float nativeGazeAngle(IsoGameCharacter body) {
        var player = SAOOrientationAnimation.nativePlayer(body);
        if (player == null || !player.hasSkinningData()) return body.getDirectionAngleRadians();
        float angle = player.getAngle() + player.getTwistAngle();
        return body.isHeadLookAround() ? angle + body.getHeadLookHorizontal() : angle;
    }
    public static float gazeX(IsoGameCharacter body) { return (float)Math.cos(gazeAngle(body)); }
    public static float gazeY(IsoGameCharacter body) { return (float)Math.sin(gazeAngle(body)); }
}
