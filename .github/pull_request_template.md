## Scope

Batch identifier:

Runtime behavior changed: yes / no

## Verification

- [ ] Relevant checks pass; reused evidence and its applicability are recorded.
- [ ] New or changed borders, when needed, are wired into `tools/check.sh`.
- [ ] New or changed instruments have executing controls that reject the
      motivating defect for its stated reason; applicable existing controls
      retain their provenance.
- [ ] A batch record exists under `Batches/` and a row was appended to
      `BATCH_LOG.md`.
- [ ] Any engine behavior asserted here has a file and line behind it, or
      is labelled a hypothesis.

## Validation scope and evidence

State which inputs changed, which behaviors or contracts they affect, what
ran and its result, which evidence was reused and why it remains applicable,
why any broader run was necessary, and what remains unverified. Identify
required external checks that add work. Each proposed check or review resolves
a relevant uncertainty in the larger objective and builds on previous work.
Commit and publication events alone
do not require a repeat of valid evidence.

## What was measured before it was designed

State how the code actually expresses the thing, before the pattern that
matches it was written. A rule derived from one example is an example.

## Product result

Describe the delivered mechanic and any concrete issue that affects it. Credit
applicable implementation, simulation and operator feedback. Link later
improvements to the completed batch. Neo maintains the current description
from the accumulated records; the operator plays the aggregate build.
