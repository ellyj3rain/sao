## Scope

Batch identifier:

Runtime behavior changed: yes / no

## Verification

- [ ] `bash tools/check.sh` passes — every border, not a subset.
- [ ] The batch's own border is wired into `tools/check.sh`.
- [ ] That border was **controlled**: the shipped artifact was mutated and
      the verdict flipped, *and* flipped naming the thing that was broken.
- [ ] A batch record exists under `Batches/` and a row was appended to
      `BATCH_LOG.md`.
- [ ] Any engine behavior asserted here has a file and line behind it, or
      is labelled a hypothesis.

## What was measured before it was designed

State how the code actually expresses the thing, before the pattern that
matches it was written. A rule derived from one example is an example.

## Operator boundary

Describe the play evidence that remains outstanding. Batches stay OPEN
until the operator has receipts from a session; the borders establish
that the code says what the record claims, never that it feels right in
the world.
