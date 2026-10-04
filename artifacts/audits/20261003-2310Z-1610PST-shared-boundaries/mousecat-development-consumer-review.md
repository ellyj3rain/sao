# Development graph consumer independent review

Status: **PASS after one repaired P2 finding**. No remaining high- or medium-severity defect found in the reviewed scope.

Reviewed 2026-10-03T23:22:52.543771+00:00; working tree `mousecat-development-continuity`. Read applicable `AGENTS.md`; reviewed the new intake/model/view/CSS and registration, observer grants, runtime dispatch, loopback HTTP and Projects integration. Source changes belong to the implementation worker; this reviewer wrote only this ignored review record.

## Finding and closure

P2: a valid graph refresh that removed the selected node kind or relation rebuilt its select options but retained the obsolete filter in state. The control became blank while the projection still hid records. The defect was sent directly to the worker. `reconcileGraphFilters` now clears only absent view/kind/relation identities before rebuilding options and rendering; surviving filters remain selected.

Independent controlled reproduction used `node --input-type=module -`, the real exported view module and static operator server on an ephemeral loopback port, isolated headless Edge at 390x844, and a route-intercepted ten-node `developmentGraph(10)` fixture. Select `batch`, then refresh a schema-valid revision where every node becomes `contract`. Before repair: five matching nodes became zero, visible select was empty, state retained `batch`. After repair: all ten nodes and nine relations appear; both select and state are empty. Both diagnostics exited zero; the first explicitly reported `DEFECT_REPRODUCED`, the second asserted and reported `PASS`. No installed service or live project file was changed.

Pre-repair view SHA-256: `bc1d62f75da814b0f0971269082e3dc454b816c4f648329e9b4bc07ab85bf33d`.

## Reviewed boundaries

- Registered typed source only; resolved path containment, bounded read, changed-file refusal, project identity, schema/count/string/media validation and endpoint closure were inspected.
- Observer MCP and GET route share the existing read contract. No graph edit route, executable graph URL, browser command dispatch or upstream invocation is introduced.
- Filtering, pagination and natural numeric label ordering operate on a view; source graph identities, relations, status/provenance and complete JSON export remain source-owned. Evidence classes remain explicit in relation details.
- Invalid refresh withholds the old graph/export; repaired valid refresh reconciles filters. Keyboard activation/details, relationship navigation, focus handling, bounded SVG/list alternatives and responsive rules were inspected.

Worker's four-width browser receipt was read: 1680, 760, 390 and 320 widths pass, including removed-filter reset and valid-filter retention. This review did not repeat `pr:ready` or those broader browser cases. Worker reports final `pr:ready` 361 tests: 348 pass and 13 explicit skips; that run remains its own evidence. Consumer validation preserves and checks declared provenance structure, not the truth of every producer claim or source revision.

## Source pins

| Input | SHA-256 |
|---|---|
| `src/core/development-graph.mjs` | `e369d4332b2e552342df01d44a62ea76be724ea2ef43a9cd2ed71e6f9bc3528f` |
| `src/core/project-surfaces.mjs` | `5fcbcd1b0ce8926d37f9ac52b13c4a0a32bfba5e90870cae7bcd169373005251` |
| `src/core/runtime.mjs` | `24974f3899db0055d76215bb63d0d6198bd48915bd7f59dcf2bd5f7a905814c1` |
| `src/core/catalog.mjs` | `f65370c94d9a6cf2bbc4c2085dcc7a22961e9206b2aa00db7d2cdf16749481e7` |
| `src/operator/server.mjs` | `eb53635c56d0fc4fcb544105c742a398d02b4ad8a9988239969c1022f9591906` |
| `src/operator/public/development-graph-model.js` | `6cc3abd1ea9a2720080b78c3bc09ab329b7f534274648c0dd9d7fbe8db469d02` |
| `src/operator/public/development-graph-view.js` | `2a2a306c94fe7c3d930bc76c2debe6524a45bedcff58e0665a28e91ab0aba30b` |
| `src/operator/public/development-graph.css` | `5a2efcbb4aaaf54551ed6b40ebc589b5169d765f651f400f4fafc8174780e91b` |
| `src/operator/public/project-view.js` | `3070924fd1631840da3316b5dcd359cb585804f3f3546bd3f8184c42ade9b325` |
| `src/operator/public/project-model.js` | `41fa77a79fab7b09b136645b8c7156f5935d8d8923e6858d931c7075d140b59f` |
| `src/operator/public/operator.js` | `a58bc579494d1f0a23cfc94e9eb11afb395f5967eb580861f307e7c5a0a7e59c` |
| `src/operator/public/index.html` | `e9df92f177491a8b194fb988053c877e22af683bb6d632a28e54dd6baef27ef2` |
| `fixtures/development-graph.mjs` | `fadd5a1ad61d084803de140ce36910c2bdbad70560c3dc7d3ea48c63d45b4797` |
| `test/development-graph.test.mjs` | `2837bdb55acdbdeac951b101df2201078c60cbf0905f0a2c46bd52ede5493d17` |
| `scripts/development-graph-browser-check.mjs` | `0cc4abbd19883d80c99bbd41435f4bbdd1cf65f41c49355567ae2889698cee3d` |
| `.mousecat/development-graph-browser/receipt.json` | `de9cf30a81bc11677289aa7891c6671e2088ce27172fb7b62f47b9edc7690dc9` |

These pins identify the reviewed candidate. Subsequent semantic source changes need scoped review; documentation-only count updates do not change this consumer result.
