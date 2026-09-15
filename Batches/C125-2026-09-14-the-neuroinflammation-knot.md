# C125 - The neuroinflammation knot

| Field | Record |
| --- | --- |
| Batch | `C125` |
| Date | 2026-09-14 |
| Name | The neuroinflammation knot |
| Status | Closed append-only batch - the neuroinflammation knot |
| Threads | [`T-002`](THREADS.md#t-002), [`T-006`](THREADS.md#t-006), [`T-008`](THREADS.md#t-008) |

## Record

The operator's ruling of 2026-09-13:
1. **One continuous value per person**: brain health is represented as a single
   continuous scalar `rec.neuroinflammation` bounded in `[0.0, 1.0]`, never an enum,
   stage, or bucket. Functional cognitive capacities are derived as projections:
   - `clarityOf` (`1.0 - load`): cognitive sharpness, perception focus, and memory duration.
   - `affectiveVolatility` (`load * 0.85`): irritability, panic amplification, erratic shifts.
   - `motorSteadiness` (`1.0 - load * 0.70`): fine motor coordination, tremors, aim stability.
2. **In the shape of Antibodies (MIT, lonegamedev)**:
   - Re-verified Antibodies v1.98 across `42.0` and `42.13`. Antibodies uses `math.sin((infectionLevel / 100) * math.pi)`
     to drive antibody production.
   - `SAO_Neuro.lua` adopts the sine curve `math.sin(pos * math.pi)` over the pathogen
     course (`SAO.Course.posOfId`) to govern Knox neuroinflammation insult accumulation,
     peaking mid-course when immune response and viral load clash.
3. **Multi-source insult kinetics**:
   - Knox infection: sine curve activation (`math.sin(pos * math.pi) * 0.08` per hour).
   - Peripheral sepsis: infected wounds (`rec.woundInfected`) contribute `0.015` per hour.
   - Drug/alcohol toxicity: poison totals from the C121 ladder (`rec.drinkPoisonTotal`)
     contribute `0.02 * math.min(1.0, poison / 50.0)` per hour.
   - Severe withdrawal: late-stage withdrawal stress adds `0.03` per hour.
4. **Baselines and thresholds**:
   - Afflicted floor: bodies that endured or were marked Afflicted maintain a persistent `0.30`
     baseline floor representing permanent neuro-scarring.
   - Crossed floor: Crossed bodies sit at `0.90`, signifying humanity burned out by runaway
     neuroinflammation.
5. **Exponential clearance decay**:
   - When insult sources clear and the body rests, neuroinflammation clears exponentially:
     `decay = math.exp(-BASE_CLEARANCE_RATE * deltaHours)`, decaying toward baseline.
6. **Cognitive & memory degradation**:
   - `SAO_Conditions.lua`: `Cn.memoryFactor` scales lesson retention duration by `math.max(0.2, clarity)`,
     so severe neuroinflammation causes lessons and situational recall to fade rapidly.
7. **Clinical diagnosis & visual curve UI**:
   - `SAO_Medical.lua`: `readingOf` provides tiered observations across Doctor skill
     (<2: subtle lethargy, 2..4: clouded sensorium, 5..7: neuroinflammatory insult estimate,
     8+: precise load reading).
   - `SAO_MedicalWindow.lua`: renders an Antibodies-style visual progress curve bar (`drawRect`/`drawRectBorder`)
     under the health pane for skilled medics inspecting inflamed survivors.
   - `SAO_Inspect.lua`: renders neuroinflammation load, clarity, and motor score in the inspector.
8. **Advances**:
   - `SAO_Population.lua`: advances dormant survivors during the daily attrition pass (`24.0` hours).
   - `SAO_Drugs.lua`: advances active survivors during the ten-minute driver pass (`10 / 60` hours).
9. **Sandbox off-switch**:
   - `SurvivorAwareness.Neuroinflammation` (boolean, default true). When disabled, `SAO.Neuro.isActive()`
     returns false, skipping all kinetics and rendering.

## What changed

- `SAO_Neuro.lua` defines the continuous graph, projections, kinetics, baselines, and off-switch.
- `sandbox-options.txt` and `Sandbox.json` declare `SurvivorAwareness.Neuroinflammation`.
- `SAO_Conditions.lua` integrates `clarityOfId` into `memoryFactor`.
- `SAO_Medical.lua` adds tiered diagnostic observations.
- `SAO_MedicalWindow.lua` renders the visual curve progress bar.
- `SAO_Inspect.lua` adds the neuroinflammation status row.
- `SAO_Population.lua` and `SAO_Drugs.lua` wire kinetic advances.
- `tools/neuroinflammation_test.py` establishes Border 158.
- `tools/check.sh` wires Border 158 into the test gate.
- `FINDINGS.md` documents F-071 and F-072.

## Honest limits

- This is not a play receipt. No live player has yet treated a survivor with high neuroinflammation
  or observed their memory loss in a running game.
- The visual curve in the medical window displays current load rather than full historical spline
  history, mirroring Antibodies' progress-style bar without maintaining a multi-day curve ring buffer.

## Verification

- `python tools/neuroinflammation_test.py` passes all 5 source criteria, kinetic equations,
  and 5 controlled mutation checks.
- `check.sh` executes Border 158.
