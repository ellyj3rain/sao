# C66 - The county carries its own randomness

| Field | Record |
|---|---|
| Batch | `C66` |
| Date | 2026-09-08 |
| Name | The county carries its own randomness |
| Status | Closed append-only batch - awaiting live receipts (two fresh saves whose counties differ; one save reloaded that continues its sequence rather than repeating it) |
| Threads | [`T-007`](THREADS.md#t-007), [`T-009`](THREADS.md#t-009) |

## Record

Forty-two places asked the engine for a random number through
`ZombRand`. That generator carries no state SAO can see, set or write
down, so no county could ever be run twice: a defect somebody reported
could not be reproduced, and a sweep that moved one sandbox dial could
not tell whether the difference it saw came from the dial or from the
draw.

`[C65]` recorded that as a fact about the trajectory corpus rather than
a defect - samples, not replays. The operator ruled the other way, and
chose the wider of the two options put to them: SAO carries its own
generator and every draw goes through it, so a whole save is
reproducible. The seed is derived from the save and stays private.

## What changed

`SAO_Rand` is the county's draw. All forty-two sites across six files
go through it and nothing else in the tree asks the engine.

It is **counter-based** rather than a running state machine. A draw is
`SAO.Hash.of(counter, seed)` for a counter that only goes up. The state
is then two small values - a seed string and a count - which persist
into ModData as-is and cannot drift out of shape, and the arithmetic is
`[B48]`'s, already verified against exact integer FNV over sixteen
hundred pairs, rather than a second answer to a question this
repository has already answered.

The seed comes off `IsoWorld.getWorld()` and the save's start date,
both javap-verified, and is written down on first use so a save keeps
the county it started with. With no save to be identified - a bare VM,
a load before the world is up - the draw falls through to the engine,
so nothing that runs before a world exists runs differently.

## What was measured before it was designed

**The first draft ramped, and only measuring caught it.**

It was `SAO.Hash.of(seed, counter) % n`: the counter in the salt
position, the answer off FNV's low digits. Over two thousand draws mod
one hundred:

```
14, 15, 16, 17, 18, 55, 56, 57, ...
1626 of 1999 draws were exactly the one before plus one
```

Four in five. That is `[B48]`'s arithmetic progression arriving through
a different door, compounded by `[B38]`'s finding that FNV's low bits
are a parity checksum of the input rather than a random bit. Shipped,
every choice in the county - who arrives, who meets whom, which way
somebody goes - would have marched in lockstep, and from inside a game
it would have looked like variety.

Two changes fixed it and both were chosen on evidence rather than
argument. The counter goes FIRST, so one FNV pass multiplies its
difference through the whole tail. The answer comes from ABOVE the low
sixteen bits, which is what `[B38]`'s coin already does.

Four candidate forms were measured over two thousand draws before one
was picked:

| form | consecutive runs | worst bucket (expect ~32) |
|---|---|---|
| `of(seed, n) % 100` | 1626 / 1999 | 31 |
| `of(seed, n)` high half | 1 / 1999 | 56 |
| `of(n, seed) % 100` | 13 / 1999 | 33 |
| `of(n, seed)` high half | 4 / 1999 | 32 |

The second row is why the obvious fix was not taken: moving to the high
half alone kills the ramp and leaves the distribution lumpy. Then chi-
square over six thousand draws at the three moduli that matter:

| n | chi-square | df | critical (p=0.001) |
|---|---|---|---|
| 2 | 0.0 | 1 | 10.83 |
| 6 | 1.9 | 5 | 20.52 |
| 100 | 101.6 | 99 | 148.2 |

`n=2` is the case `[B38]` measured at 9% heads on the raw low bit.

**Border 134 measures the draw and does not read the formula.** That is
the point of it. A border asserting the module calls `SAO.Hash` would
have passed the ramping draft; a border asserting the corrected
expression would pass any rewrite that spelled it the same way while
meaning something else. It runs the real module in the engine's VM and
does statistics on what comes out, with the reproducibility, per-save
distinctness and persistence cases each in their own process.

Its own first draft was wrong in a way worth recording. It cleared
ModData between cases while the module's memoised store reference
survived, so nothing reset, the count ran on to twenty-one, and the
border reported the module irreproducible when what had failed was the
probe. A separate process is also what the property actually means: the
same save, opened again, draws the same county.

Its control is the tree at `[C65]`, which has no module at all and
forty-two direct calls to the engine.

## What the gate refused

**The sweep gave the draw one arity and the engine has two.**
`zombie.Lua.LuaManager$GlobalObject` declares `ZombRand(double)` and
`ZombRand(double, double)` (javap), and nine sites in this tree use the
second: three pairs of goal coordinates in `SAO_Controller`, the dormant
day's fallback drift, and the radio's broadcast id. A textual sweep
replaced every call, `R.int` took one parameter, and every one of those
sites handed its LOW bound over as the modulus - negative at seven of
them, so the guard answered zero. Every goal offset collapsed to the
anchor tile, the fallback drift stopped drifting, and every broadcast
went out as `SAOW-0`.

Border 22 caught it, and only indirectly: it asserts that the old drift
survives as the fallback and was reading a spelling of that line which
the sweep had changed. The property held; the spelling had moved; and
following that thread found nine sites returning a constant. `R.int`
answers both arities now and Border 134 holds the contract, because
nothing else would have.

**Border 134's own seam named `R.int(n)`** and went red when the second
arity was added - a border refusing a fix for the shape of its own
declaration. It names the function now, which is the correction Border
118 took earlier the same day.

**Border 123** stubs `ZombRand` to force a deterministic line pick and
drives a module that no longer calls it. Stubbed at what the probe
already forced, so the pick stays deterministic rather than becoming a
real seeded draw.

## Not in this batch

**Cross-version reproducibility.** The counter is a position in a
sequence of calls, so a later batch that changes the order or number of
draws gives the same seed a different county. The state is in the save,
so a county already running is unaffected; what does not hold is
starting fresh on a later version and expecting the county a previous
version produced. That is ordinary for seeded games and is not paid for
here.

**Sharing a seed.** Derived and private was the ruling. There is no
option, nothing is displayed, and two people cannot deliberately play
the same county.

This governed record is the portable project history for this unit.
