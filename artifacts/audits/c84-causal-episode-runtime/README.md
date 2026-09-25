# C84 causal episode runtime evidence

| Field | Value |
|---|---|
| Timestamp | 2026-09-25 12:01 UTC / 05:01 PST |
| Standing | Controlled headless candidate observation |
| Episode file | `episodes.jsonl` |
| Episode file SHA-256 | `84008e521ebb29325632421e6956817329acdfd65e39391573103191232d2e2d` |
| Episode seal | `fc4ecb3b874bab9f5193908707bab3aee188ff01a676506530271ec93fe58b41` |
| Complete replay seal | `4c96d2d0d6ceb7c2cce9fdd29d51394b0759b391fc44b072c060e5bed16dd09b` |
| Scene manifest seal | `3f77aec4dc7d9570626402099364b30cacecbcc0f7c69dc7315de093754f0fbd` |

`episodes.jsonl` is one production joint SAO+ZAO dormant county advanced to day
30 with checkpoints at days 0, 7 and 30. The exporter reran the same save seed
in a fresh Kahlua process and compared the complete canonical simulation result
before publishing. The row retains source hashes, 81,189 draws, daily
snapshots, all 22 observed death events, terminal state and the complete
coordination capture. Terminal counts include 29 alive, 22 dead, six turned,
three ZAO Afflicted and sixteen ZAO dead.

The county formed no organization or matter in this seed. Decision count and
capture-failure count are both zero. That result is intentionally retained: an
episode is the provenance unit even when it contributes no decision. Speakeasy
Record 68 ingests the exact row and emits one episode, zero decisions and zero
candidate tasks.

`coordination-scenes/` is a separate discriminating mechanism audit. Its twenty
pre-partitioned situations do not supply outcomes to the natural episode. They
execute the production appraisal owners and cover accept 5, qualify 4,
counter-propose 3, defer 4 and contest 4 across Survivor, Afflicted and Crossed
recipients. The manifest binds the indexed SAO and ZAO source blobs.

Reproduction commands:

```text
python tools/county_episode.py --days 30 --checkpoints 0,7,30 --runs 1 --population 32 --joint --engine --seed-prefix C84Joint30 --out <new-file>.jsonl
python tools/coordination_scene_dump.py --out <new-directory>
python tools/causal_episode_test.py
python tools/coordination_scene_dump_test.py
```

This evidence is dormant and headless. It observes neither loaded bodies nor
gameplay presentation, and it authorizes no dataset admission, model training,
learned choice or late-start accelerator.
