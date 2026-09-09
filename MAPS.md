| Document | Survivor Awareness Overhaul Maps |
|---|---|
| Version | `4.2.3.0-pre-alpha` |
| Author | ellyj3rain |
| Repository | `MAPS.md` |
| Status | CANONICAL - the three pictures a human reads first: runtime, knowledge, catalog. |

# Maps

Three maps of the project as it is built. Every node names the file or the
rule that owns it. If a fact below disagrees with the tree, the tree is right
and this file is wrong - say so rather than repairing around it.

## Runtime - what talks to what

Two tick loops, one save story.

```mermaid
flowchart LR
    subgraph Engine["the engine (zombie.*)"]
        T["Events.OnTick"]:::e
        D["Events.OnPlayerDeath"]:::e
        M["Events.OnAddMessage (radio voice in)"]:::e
        R["Events.OnLoadRadioScripts (the wire out)"]:::e
        CTX["Events.OnFillWorldObjectContextMenu"]:::e
        GS["Events.OnGameStart"]:::e
        MD["ModData (the save)"]:::e
    end
    subgraph Java["java/ - the bridge and agent"]
        BR["SAOBridge.java - the bridge verbs, string protocols"]
        MV["SAOMovement - route supervision"]
        SC["SAOPerceptionScanner - faces, occlusion"]
        CP["SAOCombat + transformer - melee"]
        HB["SAOHibernation - pack and restore"]
    end
    subgraph Lua["mod/42.20/media/lua - the county"]
        POP["Population - genesis, bands, dormant days, the boot digest"]
        CTL["Controller - one action owns a body"]
        PER["Perception - beliefs with provenance and decay"]
        STA["Standing - trust, claims, elections, feuds"]
        EXC["Exchange - the conversation between two people"]
        VOI["Voice - decisions rendered audible"]
        NDS["Needs - hunger/thirst/wounds through timed actions"]
        LOC["Locomotion - verdict consumer; stalls and faults give up locally"]
        PLA["Places - what a place offers, spent by visits"]
        NBR["Neighbours - the neighbour framework's narration, held"]
        BOD["Body - materialize, release, hibernate"]
        IDE["Identity - the record is the person"]
        UIX["UI - the Ledger window"]
        HAR["Harness - the menus the player meets"]
        RDE["RadioEar - the player heard on 101.2"]
        TEL["Telemetry - the learning history, required inert"]
    end
    Lua -- "SAOJavaBridge - the county's one Java door" --> BR
    BR --> MV & SC & CP & HB
    T --> POP
    T --> CTL
    D --> CTL
    CTL --> PER & STA & EXC & VOI & LOC & NDS
    POP --> IDE & BOD & TEL
    EXC --> PER & STA & VOI
    IDE --> MD
    STA --> MD
    PLA --> MD
    M --> RDE --> STA
    R --> Lua
    CTX --> HAR --> UIX
    GS --> NBR
```

Rules these edges honor: Lua never iterates or indexes an engine object - the
bridge hands back verdict strings or opaque values
([`ARCHITECTURE.md`, the interop law](ARCHITECTURE.md)); one
action owns a body at a time ([`SAO_Controller.lua`](mod/42.20/media/lua/client/SAO_Controller.lua)
- DR-011); the save is Identity's records, Standing's store, and Places'
depletion rows ([DR-002, DR-005](DECISION_REGISTRY.md); [B39](Batches/)).

## Knowledge - how a fact is allowed to arrive

```mermaid
flowchart TD
    subgraph Src["how it was come by"]
        OBS["seen - the scanner, or stood there yourself"]
        HRD["heard - a world sound whose radius reached you"]
        TLD["told - somebody said so, and you believed them"]
        LVD["lived - the past a life carries in"]
        UNK["unknown - a caller that did not say (border 39-fault)"]
    end
    subgraph Bel["the belief store (SAO_Perception)"]
        B1["zombies / people / factions / places, timestamped, personal distance"]
    end
    OBS --> B1
    HRD --> B1
    TLD --> B1
    LVD --> B1
    UNK -. "never silently the strongest claim" .-> B1
    B1 --> WGT["weight: observed > heard > told; lived stands alone (the ladder)"]
    WGT --> ACT["decisions read beliefs, never the world (no omniscience)"]
    B1 --> SPH["speech and standing render from claims at read time (claims, not chapters)"]
    ACT --> STA2["Standing effects: trust, warnings, grudges, lessons"]
    SPH --> SPH2["SAO_Voice bubbles / Talk / wire bulletins / journals"]
```

The laws: told never outranks observed ([A15, DR-007](Batches/)); every
acquisition says how, and `unknown` fails the gate ([B39, Border 28](Batches/));
memory of the dead does not decay ([F-033](FINDINGS.md)); speech is a
transport, never a pathway ([B27, the one-experience-loop law](Batches/)).

## Catalog - how to find the work

```mermaid
flowchart LR
    subgraph Hist["the portable history"]
        BAT["Batches/ - the closed records: A and B eras entire, C as it closes"]
        LOG["BATCH_LOG.md - the chronological index"]
        REG["DECISION_REGISTRY.md / FINDINGS.md - append-only"]
    end
    subgraph Idx["the classification layer (regulatory; may be corrected)"]
        THR["Batches/THREADS.md - TF families, T threads"]
        VMAP["VERSION_MAP.md - version units over time"]
        XW["Batches/FORMER_LABELS.md - the pre-recatalog names"]
    end
    subgraph Now["where work stands"]
        SS["SESSION_STATE.md - current truth, and the derived counts"]
        C["the open C era - the next batch is named in SESSION_STATE.md"]
    end
    BAT --> LOG
    BAT --> THR
    THR --> VMAP
    XW -. "former id -> current record" .-> BAT
    LOG --> SS
    SS --> C
    GATE["tools/check.sh - every border, on every commit; SESSION_STATE.md states the derived counts"] -.-> BAT
```

Rules: the ledgers are extended, never rewritten ([GOVERNANCE.md](GOVERNANCE.md));
indexes are regulatory and live one edit from the tree ([B52](Batches/));
raw history before the recatalog resolves only through
[FORMER_LABELS.md](Batches/FORMER_LABELS.md).
