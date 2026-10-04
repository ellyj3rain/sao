"""Integration decisions for the operator-directed owner/interface catalogue."""

# Supporting sources join the boundary they actually extend. Each boundary has
# one externally meaningful output/state contract; shared files do not fuse it
# with every other contract that happens to call those files.
LATER_KEYS = {
    'native-source-ledger': 'material',
    'performed-material-actions': 'material_actions',
    'material-entitlement-projection': 'provisioning',
    'private-evidence': 'knowledge',
    'communication-access': 'communication',
    'claim-catalogue': 'knowledge',
    'person-continuity': 'snapshot',
    'physiological-recovery': 'recovery',
    'action-result-lifecycle': 'action',
    'acquired-purpose-planning': 'planning',
    'conditional-cognition': 'choice',
    'enacted-social-procedures': 'social',
    'physical-movement': 'movement',
    'mobile-place-continuity': 'place',
    'capture-lineage': 'data',
    'bounded-inference': 'inference',
    'causal-episodes': 'data',
    'study-world-admission': 'study',
    'study-session-lifecycle': 'study',
    'observation-publication': 'observation',
    'native-view-transport': 'native_view',
    'curated-source-adapters': 'source_ownership',
    'process-evidence-governance': 'verification',
}

# Dependency edges state the information/effect exchanged, not a claim that a
# consumer implements its producer. A feedback loop may legitimately be cyclic.
DEPENDENCIES = {
 'catalogue_replay': {},
 'verification': {'catalogue_replay':'Resolve source generations and exact inputs before reusing a receipt.'},
 'source_ownership': {'compatibility':'Assembly invokes the installed supported API and preserves source/loading identity.'},
 'identity': {'time':'Admission, age and death retain county-time provenance.'},
 'snapshot': {'identity':'Captured and restored envelopes retain the same durable person identity.'},
 'custody': {'identity':'Resolve the person before assigning a native shell.', 'snapshot':'Validate and commit the envelope before relinquishing the owned body.'},
 'return': {'custody':'Stage a viable receiving body and publish adoption only after source removal acknowledgement.', 'snapshot':'Combine authorized current possessions with matching predeath state.', 'reconstruction':'Replay the narrow authorized transaction journal after load.'},
 'reconstruction': {'identity':'Rebuild runtime indexes around stable durable keys.'},
 'time': {},
 'population': {'time':'Advance actual historical intervals and refresh time per substep.', 'identity':'Admission and census own who exists.', 'custody':'Representation requests body transitions through the sole owner.'},
 'health': {'time':'Integrate conditions, drugs and withdrawal over truthful elapsed county intervals.', 'snapshot':'Persist native physiology and its supported counters.'},
 'capacity': {'health':'Current physiology constrains embodied ability.', 'snapshot':'Native skills, recipes and age/form state survive body transitions.'},
 'knowledge': {'identity':'Private evidence belongs to a specific observer.', 'time':'Timestamp admitted evidence and age confidence using county hours.'},
 'choice': {'knowledge':'Condition predictions on the person\'s admitted evidence.', 'capacity':'Use authentic current capability and acquired experience.', 'time':'Interpret and age evidence at the actual decision hour.'},
 'standing': {'knowledge':'Recognition, culprit attribution and command assent use private evidence.', 'identity':'Relations, claims and obligations identify durable people.'},
 'social': {'standing':'Reception and assent determine accepted authority/responsibility.', 'communication':'Require actual delivery/reception before social state advances.', 'action':'Advance work and delivery only from authentic effect receipts.', 'reconstruction':'Persist the causal process graph and restore its runtime indexes.'},
 'action': {'custody':'Respect the current native actor owner and in-flight action custody.', 'access':'Revalidate exact native target and reach during execution.'},
 'access': {'knowledge':'Remembered possibilities stay distinct from current visible physical reach.', 'custody':'Use the currently owned native actor and loaded physical facts.'},
 'material': {'access':'Reconcile observations of exact reachable native sources.', 'time':'Revisions, observations and reservations retain explicit temporal meaning.'},
 'material_actions': {'material':'Consume reserved/reconciled source identities and report actual quantity changes.', 'standing':'Obtain permission before taking or transferring resources.', 'action':'Retain native queue custody and authenticate completion.'},
 'provisioning': {'material':'Derive partial observed stores from exact source revisions and measured results.', 'standing':'Revalidate the action-time claim incarnation and retire released entitlement.', 'reconstruction':'Persist derivation phases and acknowledge only after their durable effects.'},
 'movement': {'custody':'Move only the currently owned body.', 'access':'Use current route/aperture/vehicle feasibility.', 'time':'Measure physical progress over actual elapsed intervals.'},
 'expression': {'knowledge':'Constrain expressed facts to actual acquired knowledge.', 'communication':'Deliver expression through a concrete communication medium.'},
 'data': {'knowledge':'Capture immutable observer-conditioned inputs separately from diagnostic truth.', 'action':'Join later outcomes only to their actual producer receipts.', 'time':'Preserve decision-time and outcome-time identities.'},
 'observation': {'identity':'Identify the observed person without admitting observer knowledge into that person.', 'data':'Retain source/run/revision provenance and explicit evidence horizons.'},
 'place': {'movement':'Actual travel and return establish use of places.', 'material':'Material availability and depletion constrain development.', 'social':'Occupancy and collective work use enacted relations and processes.'},
 'random': {'reconstruction':'Keep durable draw state separate from disposable runtime wrappers.'},
 'compatibility': {},
 'configuration': {'source_ownership':'Expose settings only for the assembled supported mechanism.'},
 'communication': {'knowledge':'Deliver received content to private admission with source attribution.', 'standing':'Preserve recipient/contact permissions separately from physical audibility.'},
 'recovery': {'health':'Read actual bodily burden and measured recovery changes.', 'standing':'Use a personally permitted recovery place.', 'action':'Sleep/rest retains native queue and pose ownership until safe interruption.', 'choice':'Compare recovery consequences against continued responsibilities.'},
 'planning': {'choice':'Select among candidate-specific predictions with the configured model.', 'knowledge':'Construct purposes and alternatives from privately acquired places/sources.', 'standing':'Admit claims, consent and responsibilities before assigning work.', 'movement':'Continue an accepted purpose using real progress and encountered failures.'},
 'inference': {'data':'Load only schema-compatible, pinned exported artifacts and admissible inputs.', 'source_ownership':'Speakeasy owns model/data/training/export; SAO owns bounded invocation.'},
 'study': {'compatibility':'Launch and observe the real installed native runtime.', 'population':'Admit causal inhabitants without fabricating a completed society.', 'observation':'Freeze run/frame provenance and retain limits of the measured study.'},
 'native_view': {'observation':'Transport source-derived snapshots/frames with explicit revision and staleness.', 'study':'Bind the observer to the selected isolated run/world and its lifecycle.'},
}

BASELINES = {
 'catalogue_replay': ('patch', 'Catalogue links and deterministic classification replay correct the existing regulatory surface.'),
 'verification': ('patch', 'Evidence semantics, defective instruments and provenance reuse are corrections to established verification.'),
 'source_ownership': ('kohai', 'Ratified repository ownership and curated source adapters mature the existing assembly contract.'),
 'identity': ('kohai', 'Stable naming, admission, death and census mature existing durable person identity.'),
 'snapshot': ('minor', 'A validated versioned native-person envelope supplies a distinct capture/restore contract.'),
 'custody': ('kohai', 'Commit-before-release and owner-preserving transitions mature the existing body lifecycle.'),
 'return': ('minor', 'Authorized cross-owner staging and source-removal acknowledgement establish a distinct return transaction.'),
 'reconstruction': ('kohai', 'Plain durable data, runtime reset and narrow replay complete existing persistence lifecycles.'),
 'time': ('patch', 'Authoritative county hours and per-substep refresh correct existing clocks and unit mismatches.'),
 'population': ('kohai', 'Explicit cadence/admission/representation seams mature the existing county scheduler.'),
 'health': ('minor', 'Owned condition and integrated drug/brain courses add a time-grounded physiology contract.'),
 'capacity': ('kohai', 'Age, form and authentic acquired native fields extend existing embodied capability.'),
 'knowledge': ('kohai', 'Typed private observation, acquisition and attribution extend the existing knowledge boundary.'),
 'choice': ('minor', 'Conditional cognitive contestants and durable personal experience establish individual prediction contracts.'),
 'standing': ('kohai', 'Contextual assent, recognition and material entitlement mature established social permission.'),
 'social': ('minor', 'Durable enacted social procedures join reception, assent, work and delivery through causal process state.'),
 'action': ('kohai', 'Exact native queue custody and measured results mature the existing action lifecycle.'),
 'access': ('patch', 'Current target, floor, range, aperture and transfer revalidation repair physical feasibility.'),
 'material': ('minor', 'A revisioned conserved native source ledger adds observation, reservation and reconciliation authority.'),
 'material_actions': ('minor', 'Performed acquisition, consumption, preparation and handover establish conserved physical resource effects.'),
 'provisioning': ('kohai', 'Receipt-derived partial stores and claim-incarnation reconciliation mature existing material provisioning.'),
 'movement': ('kohai', 'Elapsed physical progress, stable continuation and measured transport extend existing locomotion.'),
 'expression': ('kohai', 'Acquired-fact vocabulary and decoding mature the existing expression interface.'),
 'data': ('minor', 'Immutable decision capture and causal outcome joins define cross-project evidence admission contracts.'),
 'observation': ('kohai', 'Source-bound read-only projections and publication mature existing inspection and telemetry.'),
 'place': ('kohai', 'Observed use, return and mobile-place continuity extend existing inhabited-ground state.'),
 'random': ('kohai', 'Persisted deterministic draw state and fresh runtime wrappers mature reproducibility.'),
 'compatibility': ('patch', 'Installed API, compiler and loading repairs preserve established execution contracts.'),
 'configuration': ('patch', 'Settings and interaction copy are corrected to implemented behavior.'),
 'communication': ('minor', 'Medium-specific audibility, contact and reception establish a shared delivery/access contract.'),
 'recovery': ('minor', 'Native bodily recovery, interruption and measured results add a purposeful recovery contract.'),
 'planning': ('minor', 'Acquired purposes, observed alternatives and retained unfinished work establish private procedural planning.'),
 'inference': ('minor', 'Pinned in-process model artifacts and bounded invocation establish an executable inference contract.'),
 'study': ('minor', 'Causal world admission and an isolated study lifecycle establish a controlled native observation contract.'),
 'native_view': ('minor', 'Revision-bound native capture and observer transport establish a native-view publication contract.'),
}

# Producer/consumer review: permission, delivered commitment and native effect
# authentication are separate authorities even when one choice consumes all.
DEPENDENCIES['social']['standing'] = 'Existing recognition and permission inform private appraisal; Organization owns revision-bound delivered assent and resulting commitments.'
DEPENDENCIES['choice']['capacity'] = 'Current native capability constrains prediction without inventing acquired experience.'
DEPENDENCIES['choice']['action'] = 'Authenticate experience by rereading the canonical physical-result producer.'
DEPENDENCIES['choice']['recovery'] = 'Authenticate measured same-body recovery segments before learning from their outcomes.'
DEPENDENCIES['planning']['standing'] = 'Admit contextual permission and claims before selecting physical work.'
DEPENDENCIES['planning']['social'] = 'Consume the person\'s actual received and accepted Organization commitments.'
DEPENDENCIES['planning']['material'] = 'Compare exact privately admitted source/item/revision offers.'
DEPENDENCIES['planning']['action'] = 'Advance purpose steps through canonical results and independent acknowledgments.'
DEPENDENCIES['recovery']['social'] = 'Compare continuing work using actual received and accepted personal responsibilities.'
DEPENDENCIES['place']['social'] = 'Collective use and development consume enacted relations and processes; individual mobile interior admission keeps its own physical contract.'
DEPENDENCIES['place']['material'] = 'Development uses material availability/depletion; mobile interiors retain exact vehicle stores and anchor identity.'
DEPENDENCIES['place']['custody'] = 'Body restoration preserves mobile interior position separately from the exterior vehicle anchor.'
DEPENDENCIES['place']['access'] = 'Native mobile interior transitions require exact vehicle/provider admission.'
DEPENDENCIES['data']['population'] = 'Causal episode generation advances actual county producers before recording prefix checkpoints.'
DEPENDENCIES['data']['random'] = 'Causal episode replay retains seed/draw provenance for the same production trajectory.'
DEPENDENCIES['inference']['social'] = 'Validate exact request and process revision; current shadow output has no social decision authority.'
DEPENDENCIES['inference']['custody'] = 'Reject stale actor/owner results after detach, death or custody changes.'
