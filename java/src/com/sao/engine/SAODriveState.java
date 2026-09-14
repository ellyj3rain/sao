package com.sao.engine;

/** [C114] Per-shell driving state, sibling to SAORouteState. One trip:
 *  the walk to the claimed car, the lawful engine start, the drive to
 *  the venture's ground, and the stop. The route state stays separate
 *  because the walk-to-car leg is an ordinary SAOMovement route. */
public final class SAODriveState {

    /** "drive" (seat 0) or "ride" (a passenger seat). */
    public String mode;
    public boolean requested;
    /** WALK / START / WAIT / DRIVE / STOP / RIDE. */
    public String phase = "NONE";
    /** The pool name the claim was made under; the car is re-found by
     *  it, the same way spendVehicleFuel re-finds it. */
    public String name;
    public float targetX;
    public float targetY;
    /** Seats the driver waits on before departing ([B19]'s company
     *  cap made real: the car holds who it was promised to hold). */
    public int waitSeats;
    /** [C115] The drive's speed cap in km/h, ordered in from the
     *  sandbox dial by the Lua face (Java cannot read SandboxVars);
     *  SAODriver falls back to the credited default when unset or
     *  not positive. */
    public float speedCapKmh;
    public int engineTries;
    public int waitTicks;
    public int stuckTicks;
    public int stopTicks;
    public int rideTicks;
    /** [C116] The crossed body's walk to the car - the dead walk on
     * the engine's own zombie pathing, one leg per scan, so this is
     * the patience counter for a leg the survivor path never owns. */
    public int walkTicks;
}