#!/usr/bin/env bash
# [B14] The borders, enforced.
#
# Fifteen mechanical borders grew across the B era (T-030) and every one
# of them only ever ran when I remembered to run it. This is what the
# pre-commit hook calls, and what anyone can run by hand:
#
#   tools/check.sh            - check every Lua file in the tree
#   tools/check.sh --staged   - check only what is about to be committed
#
# Exit non-zero on any failure, so the hook can refuse the commit.
set -u
cd "$(dirname "$0")/.." || exit 2

PY=python
command -v python >/dev/null 2>&1 || PY=python3

fail=0
note() { printf '[check] %s\n' "$*"; }

# 1. Structural Lua check on the relevant files.
if [ "${1:-}" = "--staged" ]; then
    files=$(git diff --cached --name-only --diff-filter=ACM \
            | grep '\.lua$' || true)
else
    files=$(find mod -name '*.lua' 2>/dev/null || true)
fi

# [C1] The gate's verdict must not depend on who invoked it. A pre-commit
# hook exports GIT_DIR and GIT_INDEX_FILE, and any border that shells git
# from another directory (Border 54 builds its blinded tree with
# `git ls-files`, then runs every mirror inside it) inherits them and reads
# a different repository than it would from a terminal - in this worktree
# the hook run flipped Border 54's inner verdict from refused to clean.
# The staged file list above is the one thing that legitimately needs the
# hook's index; everything after this line runs with the git environment
# scrubbed, so a border answers the same on every machine and every caller.
unset "${!GIT_@}" 2>/dev/null || true

if [ -n "$files" ]; then
    for f in $files; do
        [ -f "$f" ] || continue
        if ! "$PY" tools/lua_check.py "$f"; then
            note "STRUCTURE FAILED: $f"
            fail=1
        fi
    done
else
    note "no Lua files to check"
fi

# 2. The scope-split scanner (F-030 class: a local declared after a
#    bare assignment to the same name).
if ! "$PY" tools/scope_split_audit.py; then
    note "SCOPE AUDIT ERRORED"
    fail=1
fi

# 3. The twelve in-repo cross-file borders. Any line reporting something other
#    than "none" is a finding; the sweep itself always exits 0, so the
#    judgement lives here.
sweep=$("$PY" tools/invariant_sweep.py 2>&1) || {
    note "SWEEP ERRORED"
    printf '%s\n' "$sweep"
    exit 1
}
printf '%s\n' "$sweep"
# Only the borders that MUST report "none" are failures.
# Check 2 (states relying on the errand default) is
# informational by design - it lists a healthy fact about
# the pressure taxonomy, and treating its list as a
# finding would make the hook cry wolf on every commit.
must_be_none='MOVEMENT keys missing|tick states not in MOVEMENT|takePurpose written but never handled|verbs missing in SAOBridge|voice events used but undefined|TAKE states entered with no queued work|sensor scale disagreement|states with no exit dispatcher|claim fields read but never written|news kinds written but rendered by nobody|designation literals nothing can ever be|wants Lua asks for that Java cannot answer'
if printf '%s\n' "$sweep" | grep -E "$must_be_none" | grep -qv "none"; then
    note "BORDER FINDING - read the sweep output above"
    fail=1
fi

# [B26] Border 13 - engine-string literals that match nothing the
# game actually produces. This is the only border that reads data
# OUTSIDE the repository (the game's own item scripts), which is why
# it lives in its own script and why it reports SKIPPED rather than
# "none" when the install is absent: a check that cannot run must not
# look like a check that passed.
#
# Negative-tested against the real [B26] defects rather than a
# synthetic typo - restoring Base.Cigarettes and the two
# DisplayCategory-via-getCategory reads makes it name all three.
lits=$("$PY" tools/engine_literals.py 2>&1)
printf '%s\n' "$lits"
if printf '%s\n' "$lits" | grep -qv -e "none" -e "SKIPPED"; then
    note "BORDER FINDING - a literal the engine never produces"
    fail=1
fi

# [B31] Border 15 - a wire format that grew on one side only.
#
# Java builds a delimited string, Lua tears it apart with a pattern.
# Add a field to the producer and forget the parser and the pattern
# simply stops matching: the Lua takes its `if not x then return nil`
# branch, the feature goes quiet, nothing is raised. [B31] and [B31]
# both had to check this by hand.
#
# Producer and consumer do not share a name - Lua calls
# findFoodSource, the bridge forwards to findFoodSourceNear - so this
# reads the bridge first to pair them. Producers with no statically
# pairable parser are printed as unchecked rather than failed.
arity=$("$PY" tools/protocol_arity.py 2>&1)
printf '%s\n' "$arity"
if printf '%s\n' "$arity" | grep -E "^15\)" | grep -qv -e "none" -e "SKIPPED"; then
    note "BORDER FINDING - a protocol's two ends disagree"
    fail=1
fi

# [B31] Border 14 - a second copy of a shared definition.
#
# Four fixes turned on "one definition, two callers" ([B20], [B27],
# [B28], [B30]) and nothing stopped anyone re-forking one. [B31] found
# the cost already paid: three copies of the hearth search, two of the
# drink filter, and four of the floor-ring sweep that had drifted far
# enough apart that only two still matched.
#
# The threshold was MEASURED, not chosen. On the tree as [B31] found
# it, fifteen normalised lines already repeated ten times over. The
# mess was fixed rather than tolerated, so the baseline here is ZERO -
# fifteen is not a tolerance, it is the line below which this codebase
# does not repeat itself.
dups=$("$PY" tools/duplicate_blocks.py 2>&1)
printf '%s\n' "$dups"
if printf '%s\n' "$dups" | grep -qv -e "none" -e "SKIPPED"; then
    note "BORDER FINDING - a shared definition has been copied"
    fail=1
fi

# [B33] The options screen is a surface the player READS. A dial
# nothing reads, an option with no tooltip, or a Lua fallback that
# disagrees with the declared default all ship as jank. Exact set
# comparisons, so this cannot manufacture a finding.
if ! "$PY" tools/sandbox_surface.py; then
    note "BORDER FINDING - the options screen and the mod disagree"
    fail=1
fi

# [B33] What ships is what was built. mod/ IS the distributed work,
# and the jar inside it is a tracked artifact a human has to refresh.
# Exact: a source with no class in the jar is a fact.
if ! "$PY" tools/shipped_jar.py; then
    note "BORDER FINDING - the shipped jar is not the built jar"
    fail=1
fi

# [B33] Every bridge call sits inside a pcall, so a misnamed method or
# a wrong arity dies silently and forever. Compared against the
# COMPILED class, because that is the surface that ships. SKIPs
# cleanly where there is no JDK or no build output.
if ! "$PY" tools/bridge_arity.py; then
    note "BORDER FINDING - Lua calls a bridge method that cannot answer"
    fail=1
fi

# [B33] mod.info is the first thing the game reads, and a key no
# parser recognises is ignored in silence. The valid key names come
# from the bytecode of the two parsers that consume the file, not
# from memory.
if ! "$PY" tools/modinfo_check.py; then
    note "BORDER FINDING - mod.info declares something nothing reads"
    fail=1
fi

# [B34] A once-only persisted write must be the LAST statement in
# its pcall. The guard opens once in the life of a world; anything
# that throws after the write lands keeps the flag, loses the work,
# and can never be retried - and the pcall discards the error, so
# nothing is said. Exact: it asks whether the pcall ends there.
if ! "$PY" tools/pcall_audit.py > /dev/null; then
    "$PY" tools/pcall_audit.py 2>&1 | grep -E "UNSAFE|still in the" || true
    note "BORDER FINDING - a once-only persisted write is not last"
    fail=1
fi

# [B23] Used-before-declared is a border, not advice. A file-level
# Lua local is invisible above its own line - it resolves to a nil
# global and indexing it throws. This missed a runtime-fatal bug
# inside an election, so the unambiguous half of the undeclared audit
# now gates. The advisory half still just prints.
if ! python tools/undeclared_audit.py > /dev/null 2>&1; then
    python tools/undeclared_audit.py 2>&1 | grep -E "used at line|used-before-declared" || true
    note "BORDER FINDING - a local is used above its own declaration"
    fail=1
fi

# [B37] The county's places are the map's own buildings, and what
# each one OFFERS is our reading of the room names the map gives them.
# An interpretation of a real vocabulary has to keep matching the real
# vocabulary: a stem matching no room name the shipped map uses is a
# category we invented and the county can never supply. Reads the
# game's Distributions.lua, which is keyed by room name; SKIPs cleanly
# where there is no install.
if ! "$PY" tools/places_test.py > /dev/null; then
    "$PY" tools/places_test.py 2>&1 | grep -E "FAULT|SKIPPED" || true
    note "BORDER FINDING - a place offers something the map does not"
    fail=1
fi

# [B38] The county sizes itself from the map that is installed, and
# the two numbers that govern it have to move TOGETHER. Arrivals are
# gated on `newcomers > population`; a derived county against a fixed
# ceiling closes the road with no error and no log line, and the only
# symptom is that nobody ever walks in again. Bounded, monotonic, and
# open at every scale a map mod could produce.
if ! "$PY" tools/population_scale_test.py > /dev/null; then
    "$PY" tools/population_scale_test.py 2>&1 | grep -E "FAULT|NO " || true
    note "BORDER FINDING - the county does not size itself safely"
    fail=1
fi

# [B38] Who the county IS. The census header states its grounding -
# circa-1993 Meade/Hardin County, Kentucky - and nothing ever checked
# the table against it, which is [B33]'s default drift one field over.
# Does not fail on divergence from the national 1990 distribution:
# rural Kentucky legitimately has more farmers and fewer executives.
# Fails on an unclassified row, a table that stopped summing to 10000,
# and a whole major group at zero - a kind of person the county cannot
# produce at all, which is how it found there were no managers.
if ! "$PY" tools/census_grounding_test.py > /dev/null; then
    "$PY" tools/census_grounding_test.py 2>&1 | grep -E "FAULT|ABSENT" || true
    note "BORDER FINDING - the county is not who it says it is"
    fail=1
fi

# [B38] The county arrives in twos and threes, and who two of them
# are to each other is DERIVED from ages that are already facts -
# never chosen alongside them. Also guards the coin: FNV's low bit is
# a parity checksum, so `hashOf % 2` is not a flip, and it decided
# partner-versus-sibling for every family (75/7) plus how many
# contacts a survivor starts with.
if ! "$PY" tools/units_test.py > /dev/null; then
    "$PY" tools/units_test.py 2>&1 | grep -E "FAULT|NO " || true
    note "BORDER FINDING - the county does not arrive as units"
    fail=1
fi

# [B38] The instrument must not perturb what it measures. Telemetry
# writes to no record, calls nothing that changes the world, is
# pcall-guarded at every reference so a broken instrument stops
# measuring rather than stopping the county, hooks death at the
# markDead funnel rather than one call site, and emits JSON that a
# parser actually accepts.
if ! "$PY" tools/telemetry_test.py > /dev/null; then
    "$PY" tools/telemetry_test.py 2>&1 | grep -E "FAULT|NO " || true
    note "BORDER FINDING - the instrument can perturb or throw"
    fail=1
fi

# [B38] Age you can see. The gradient must vary with age AND between
# people of the same age - a rule that greys everyone over fifty
# identically is a threshold wearing a gradient's clothes. The natural
# hair colour is never written, so this is undone by doing nothing,
# which is what makes it safe under two live saves.
if ! "$PY" tools/appearance_test.py > /dev/null; then
    "$PY" tools/appearance_test.py 2>&1 | grep -E "FAULT|NO " || true
    note "BORDER FINDING - age is not visible, or is being written over"
    fail=1
fi

# [B39] Nobody knows anything for no reason. Every place an agent
# comes to hold something must say HOW - `observed`/`lived` if they
# were there, `told`/`heard`/`witnessed` if it came through somebody.
# An acquisition saying neither is knowledge arriving from a registry
# or by fiat, which is the root of the class [B35], [B35] and [B37]
# each fixed one instance of. Reads and forgets are not acquisitions
# and are not counted.
if ! "$PY" tools/acquisition_test.py > /dev/null; then
    "$PY" tools/acquisition_test.py 2>&1 | grep -E "FAULT|NO " || true
    note "BORDER FINDING - somebody knows something for no reason"
    fail=1
fi

# [B39] Every option on the screen governs the WHOLE county. [B39]
# found Desperation read nine times in the live path and zero in the
# dormant one, so the county's own property law applied only to
# whoever happened to be loaded - and that was an instance, not the
# defect. An option read only in the live path must be named with a
# reason about the code; one read nowhere is dead either way.
if ! "$PY" tools/option_reach_test.py > /dev/null; then
    "$PY" tools/option_reach_test.py 2>&1 | grep -E "FAULT|LIVE ONLY|NOBODY" || true
    note "BORDER FINDING - an option governs only half the county"
    fail=1
fi

# [B40] A trade can find the book its road back rides on. Perk ids
# and item-script keywords are two vocabularies for one skill - the
# perk is `Doctor` and every first-aid book says `FirstAid` - and
# handing a perk id to the book lookup meant the medic's book was
# never found, which reads exactly like the scarcity [B22] intended.
# Checked against the game's own media/scripts.
if ! "$PY" tools/book_vocabulary_test.py > /dev/null; then
    "$PY" tools/book_vocabulary_test.py 2>&1 | grep -E "FAULT|CANNOT EXIST" || true
    note "BORDER FINDING - a trade asks for a book that cannot exist"
    fail=1
fi

# [B41] A field written onto a person is a field somebody reads. A
# fact the simulation establishes and cannot act on reads, from
# outside, exactly like a feature that exists - [B37]'s age and
# [B40]'s originAnchored were both found by hand, late. Resolves the
# one dataflow that occurs here (a function indexing a record by one
# of its parameters, and the literals its callers pass) so a read
# through a string key is not mistaken for silence.
if ! "$PY" tools/field_reach_test.py > /dev/null; then
    "$PY" tools/field_reach_test.py 2>&1 | grep -E "FAULT|NEVER READ" || true
    note "BORDER FINDING - a field is written onto a person and read by nothing"
    fail=1
fi

# [B36] A live save must survive every deploy - and [B41] found this
# was never actually in the gate, though [B36]'s record says it made
# it one. The operator keeps two worlds as test ground and deploys land
# under them constantly; a save never breaks loudly, so a dropped field
# is simply ignored forever. SKIPs cleanly when the baseline commit is
# not in this checkout.
if ! "$PY" tools/save_compat_test.py > /dev/null; then
    "$PY" tools/save_compat_test.py 2>&1 | grep -E "DROPPED|could lose|<-" || true
    note "BORDER FINDING - a running save could lose a field"
    fail=1
fi

# [B41] The standing mirrors, which for most of this project's life
# were not run by anything.
#
# Twenty-two of the thirty-three in tools/ were never invoked here -
# including key_domain_test, where [B37] and [B40] both put standing
# laws, and save_compat_test, whose own batch record said it had been
# gated. A mirror nobody runs is a claim nobody checks, and the proof
# arrived the same day: belief_life_test went blind the moment [B40]
# exported PLACE_SIGHT out of a file-level local, and nothing said so.
#
# Each mirror carries its own docstring naming the batch that wrote it
# and what it holds, so the reason lives with the mirror instead of
# being copied into a comment here that would drift from it.
for mirror in \
    age_test arrival_test ask_test belief_life_test betweentime_test \
    bulkhead_test census_test claim_lifecycle_test combat_patch_test \
    equilibrium_test exchange_test foreign_test identity_test \
    joining_test key_domain_test outsider_test policy_reach_test \
    queue_drop_test radius_test triage_test voice_reach_test \
    work_test
do
    if ! "$PY" "tools/$mirror.py" > /dev/null 2>&1; then
        "$PY" "tools/$mirror.py" 2>&1 | tail -8
        note "BORDER FINDING - $mirror no longer holds"
        fail=1
    fi
done

# [B41] A mirror nobody runs is a claim nobody checks. Thirty-three
# mirrors existed and eleven ran; the rest were cited in batch records
# as though writing one were the same as running it. Every
# tools/*_test.py must now be invoked above or declared one-off with
# the batch that wrote it, and every mirror must have a path that can
# fail - a report in the gate is runtime bought for a guaranteed pass.
if ! "$PY" tools/gate_reach_test.py > /dev/null; then
    "$PY" tools/gate_reach_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - a mirror is not in the gate, or cannot fail"
    fail=1
fi

# [B41] Border 33 - the player's own eyes reach their own belief store.
# [B27] shipped the Lua for this and the Java refused it for seventy-nine
# batches: perceive() gated on SAOIsoPlayerShell and the real player is a
# plain IsoPlayer, so every scan the player made returned "". Nothing
# errored, because P.observe creates the store BEFORE the bridge and
# writes beliefs only inside `if seen ~= "" then` - a live store with a
# rising scanCount is exactly what an empty player looks like. Store
# existence is not evidence of perception, so this asserts the whole
# chain instead: the engine's extends chain, the SHIPPED bytecode's gate
# type and scan descriptor, and the argument the tick actually hands
# over. SKIPs cleanly when the engine install or javap is absent.
if ! "$PY" tools/player_eyes_test.py > /dev/null; then
    "$PY" tools/player_eyes_test.py 2>&1 | grep -E "FAULT|SKIPPED" || true
    note "BORDER FINDING - the player cannot see for themselves"
    fail=1
fi

# [B41] Border 34 - an offer to speak opens on exactly what speaking
# carries. The harness gate iterated `zombies` and `places` itself,
# which was a second spelling of a rule that lives in Perception, and
# it was wrong in both directions: it never counted `factions` or the
# death news, and it counted stale sightings that `tell` refuses
# because they are past ZOMBIE_HORIZON - so the option appeared, the
# player spoke, and nothing crossed. Both sets are READ out of the
# shipped Lua rather than listed here, so adding a category to either
# side requires the other to move.
if ! "$PY" tools/relay_test.py > /dev/null; then
    "$PY" tools/relay_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - the offer and the transfer disagree"
    fail=1
fi

# [B42] Border 35 - the county's property law, read by both halves.
# Being near a held claim teaches you it is held ([A15], [A15]) and a
# claim that ended un-teaches ([B35]); [B35] wired the PLAYER's own
# ground into that. All of it lived inside dormantLife, whose loop
# gates on `not SAO.Body.get(id)` - so only the UNLOADED could learn
# whose ground they stood on, and the ledger reported "Nobody has come
# past it yet" with a survivor in the room. A rule that governs the
# whole county is written once and read by both halves.
if ! "$PY" tools/ground_reach_test.py > /dev/null; then
    "$PY" tools/ground_reach_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - only half the county learns whose ground it is"
    fail=1
fi

# [B42] Border 36 - the player is never shown a placeholder. Two rules,
# both from screenshots of the Ledger: no non-ASCII in code, because
# U+2026 has no glyph in the game's font and rendered as a stray `&`
# where a survivor's activity should have been; and "Unnamed" is the
# ABSENCE of a name - backfillName needs a body, so the county carries
# the sentinel for anyone it has never materialised, and Bonds printed
# five rows of "Unnamed & Unnamed". Identity.knownName is that rule with
# one name; displayName must KEEP rendering the sentinel, because
# beliefs are keyed by it.
if ! "$PY" tools/placeholder_test.py > /dev/null; then
    "$PY" tools/placeholder_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - a placeholder is reaching the player"
    fail=1
fi

# [B42] Border 37 - a foreign store informs this county and never
# speaks for it. The County Ledger read another framework's ModData and
# printed its world-event string verbatim, unconditionally, while this
# mod's own radioNews reached the player only over a live wire ([A26]):
# their news was free and ours had to be earned. Reading a foreign store
# is fine - their people are real people here (DR-009) - but a surface
# where this mod speaks AS THE COUNTY must report our own records. A
# foreign person's own dialogue is excluded, because that is them
# speaking about themselves and claims nothing on our behalf.
if ! "$PY" tools/sovereignty_test.py > /dev/null; then
    "$PY" tools/sovereignty_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - a foreign store is speaking for the county"
    fail=1
fi

# [B42] Border 38 - a method called on an inventory item is a method
# items have. `bridge_arity` holds this line for calls into OUR bridge;
# nothing held it for calls into the engine. [B42] found
# `it:getDeviceData()` walking the player's inventory - that method is
# on zombie.inventory.types.Radio, not on InventoryItem, so it threw on
# every ordinary item, once per item, every context-menu open, and the
# pcall made the failure indistinguishable from finding nothing. This
# border immediately found the second instance in SAO_Standing, which
# ran on every radio-ownership check. Reads InventoryItem's own 577
# methods from the installed jar rather than a list kept here, and
# allows a subclass call once an instanceof has ASKED. SKIPs cleanly
# when the game or javap is absent.
if ! "$PY" tools/item_api_test.py > /dev/null; then
    "$PY" tools/item_api_test.py 2>&1 | grep -E "FAULT|SKIPPED" || true
    note "BORDER FINDING - a call assumes an item is something it may not be"
    fail=1
fi

# [B42] Border 39 - the county's history is written and read by the
# same list. [B23] found `creed` written by the election and dropped
# silently by the Chronicle, fixed that one, and left the class open;
# it had two more instances, `chair` and `unseated`, which are the two
# kinds that are about the PLAYER - a house giving you a seat and
# taking it back. And `abandon` carried a timestamp and nothing else,
# so the Chronicle could say a house gave up their ground and never
# which ground. Holds three ways: every kind written is rendered, every
# kind rendered is written, and every field a renderer reads is one
# some writer of that kind actually puts there.
if ! "$PY" tools/chronicle_test.py > /dev/null; then
    "$PY" tools/chronicle_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - the county records what it cannot show"
    fail=1
fi

# [B42] Border 40 - an order the player can give is an order that can
# land. "go back to your own place" aims at the home on a survivor's
# record, and [B7] clears those fields for everyone in a house that
# gives up its ground - so the order has a precondition the county
# itself can take away. An option offered in that state does nothing
# when clicked, silently, and the player concludes they were ignored.
# The gate and the aim must read the same field; a field read with a
# default is not a precondition, because the fallback is the handling.
if ! "$PY" tools/order_landing_test.py > /dev/null; then
    "$PY" tools/order_landing_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - an order is offered that cannot land"
    fail=1
fi

# [B42] Border 41 - who somebody was is this county's judgement.
# DR-009 ratified that where the two systems collide SAO's reading
# overrides on SAO's side; [A20] then let a foreign archetype overwrite
# rec.occupation through a hand-written table and contradicted it for
# thirty-odd batches, because the decision lived in a ledger and the
# code lived in a file and nothing compared them. Worse, it CLEARED
# rec.occupationPresumed - the flag that makes Census.describe say
# "carries themselves like a nurse" instead of "was a nurse", and makes
# originNote refuse to invent a beginning ([A22]) - so it laundered
# our own guess into a fact. DR-012 reverses it; this holds it.
if ! "$PY" tools/census_authority_test.py > /dev/null; then
    "$PY" tools/census_authority_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - something else is deciding who somebody was"
    fail=1
fi

# [B43] Border 42 - the jar says which jar it is, truthfully.
# getVersion returned a hardcoded "0.1.0.0-pre-alpha+java2" while
# VERSION said 0.6.0.0-pre-alpha, and it was the ONE bridge method no
# Lua ever called - bridge_arity had printed "never called: 1" in every
# gate run for months and the name was never looked at. The two halves
# hid each other: an unread method cannot be caught lying, and a lying
# method is worth nothing to read. [B33] is why it matters at all - a
# stale shipped jar is invisible from inside a play session. The string
# is stamped from VERSION at build time and read out of the SHIPPED
# bytecode here.
if ! "$PY" tools/version_stamp_test.py > /dev/null; then
    "$PY" tools/version_stamp_test.py 2>&1 | grep -E "FAULT|SKIPPED" || true
    note "BORDER FINDING - the jar cannot say which jar it is"
    fail=1
fi

# [B43] Border 43 - the doc-pack states one version, and the index
# knows its own root. Twelve headers carried a version AND a batch tip
# reading "B tip [B30]" while the sequence stood at [B43]; three said
# 0.4.0.0-pre-alpha with a tip 111 batches behind. All are CANONICAL by
# MEMORY.md's own vocabulary - "current truth, edit in place when
# superseded". The tip was dropped rather than corrected, because a
# claim in twelve files is twelve things to maintain: BATCH_LOG.md owns
# it now, one spelling. MEMORY.md also said "Nothing at the root is
# unclassified" while five files were.
if ! "$PY" tools/doc_currency_test.py > /dev/null; then
    "$PY" tools/doc_currency_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - the doc-pack misstates its own currency"
    fail=1
fi

# [B43] Border 44 - the file that says where the work stands is where
# it stands. SESSION_STATE.md is CANONICAL, its role is literally
# "where the work actually stands", and it said "[A15] close, seventy-
# one batches, versions 0.4.0.0" while the sequence was at [B43] on
# 0.6.0.0 - about 283 batches behind, on the first file a new session
# reads. [B43] dropped the tip from twelve headers rather than commit
# to maintaining it in twelve places; this is the opposite case, where
# currency IS the document, so it is gated: one file, one line, updated
# when a batch closes.
if ! "$PY" tools/session_state_test.py > /dev/null; then
    "$PY" tools/session_state_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - session state does not say where the work stands"
    fail=1
fi

# [B43] Border 45 - the shelves are spent by whoever empties them.
# [B39] built the scarcity model and wired Pl.take into dormantLife
# ALONE - one caller for twenty-three batches - so a survivor standing
# in a grocery could eat it bare while the county's ledger never moved
# and two hundred dormant ones still walked there expecting food. Same
# asymmetry as [B39] on Desperation, [B39] on ErrandRadius and [B42]
# on whose ground it is, and the largest of them: not one option but a
# whole economy half the county was outside of. Reading offersNow stays
# dormant-only on purpose - the loaded half scans the real world and
# has ground truth; its job is to keep the model honest about what the
# world lost.
if ! "$PY" tools/scarcity_reach_test.py > /dev/null; then
    "$PY" tools/scarcity_reach_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - only half the county spends the shelves"
    fail=1
fi

# [B43] Border 46 - one question about witnessing, asked one way. The
# county asks whether somebody witnessed a thing happen to another
# person in three places - a killing twice, a fight once - and every
# one asked it identically in shape: an OBSERVED belief of that person,
# taken RECENTLY, from CLOSE BY. One question spelled three times with
# two answers: ten tiles for a killing, twelve for a fight, nothing
# saying why. [B41] found this shape when a docstring said "within 3
# tiles" and the code said <= 9.0; here the coincidence had already
# broken and nothing could see it, because there was no name for the
# spellings to disagree about. [B40] kept two feud reaches apart on
# purpose AND WROTE THE REASON; there was none here.
if ! "$PY" tools/witness_reach_test.py > /dev/null; then
    "$PY" tools/witness_reach_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - witnessing is asked more than one way"
    fail=1
fi

# [B43] Border 47 - the reaches still typed bare are counted. [B43]
# measured twenty-six radius comparisons in the tree with exactly ONE
# reading a declared reach; [B41] had named the one it was standing on
# and left twenty-five, with nothing recording that they existed, so
# "we will get to them" and "we forgot" were the same state. A census
# rather than a ban, because a name invented for a single use reads as
# a shared rule that nothing shares - which is [B40]'s trap running
# backwards, and why GROUND_REACH and EARSHOT sit in the same function
# under different names. The count may FALL (a batch named a group, and
# the census comes down with it) and may not RISE.
if ! "$PY" tools/reach_census_test.py > /dev/null; then
    "$PY" tools/reach_census_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - the bare-reach backlog moved and was not recorded"
    fail=1
fi

# [B44] Border 48 - the standard library this engine actually has.
# SAO_Places.lua called `next(out)` and Kahlua does not register `next`,
# so it raised "Object tried to call nil" on every dormant tick - inside
# the pcall in Pl.at, so nothing surfaced but the log. The county chose
# places for its unloaded half with NO CONTENTS RESOLVED, which is the
# whole of [B38] silently inert, and the flood pushed the operator's
# mod-loading phase out of console.txt entirely. The registry is read
# from projectzomboid.jar rather than remembered: this engine has no
# assert, dofile, load, loadstring, next, rawlen, require or xpcall.
if ! "$PY" tools/lua_stdlib_test.py > /dev/null; then
    "$PY" tools/lua_stdlib_test.py 2>&1 | grep -E "FAULT|SKIPPED" || true
    note "BORDER FINDING - a call the engine's Lua cannot answer"
    fail=1
fi

# 49) A number that already has a name, typed anyway. [B45] named
# ARRIVAL_REACH and TALK_REACH and found on the way that three tiles
# ALREADY had a name - MEET_RANGE, in another file, read once since
# [B41] - while the live half typed 9.0 in three places. Border 47
# counts bare radii; it cannot tell a fresh one-off from a number that
# duplicates a rule already spoken for. A collision is either wired to
# the name or argued in ALLOWED, and an argument whose collision has
# gone is a fault in the other direction.
if ! "$PY" tools/reach_collision_test.py > /dev/null; then
    "$PY" tools/reach_collision_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - a reach typed past its own name"
    fail=1
fi

# 50) The engine's own parser, before the game gets it. [B45] rewrote
# six `if` conditions across line breaks and said in its own record that
# nothing here would have caught a broken one - the game would have, at
# load, which to an operator is indistinguishable from "the mod did not
# load" ([B44]). No hand-written Lua parser: this calls the compiler
# that ships inside projectzomboid.jar, so the verdict is the engine's.
# Being a real compile, it also catches Kahlua's structural limits,
# which no highlighter would.
if ! "$PY" tools/lua_syntax_test.py > /dev/null; then
    "$PY" tools/lua_syntax_test.py 2>&1 | grep -E "FAULT|SKIPPED" || true
    note "BORDER FINDING - Lua the engine's compiler will not accept"
    fail=1
fi

# 51) Whose namespace we are in, as the engine sees it. Kahlua compiles
# each file and this walks the bytecode for GETGLOBAL/SETGLOBAL, so a
# local and a same-named global read are told apart - which grep cannot
# do. On its first run it found `uname`, read three times in
# onPlayerDeath and declared nowhere (the county mourned a person called
# "nil"), and `ksData` out of scope in SAO_Harness, gating a block that
# had never run. Every global we touch is classified exactly, and every
# global we WRITE must be ours - the promise to the rest of the load
# order, stated as a rule rather than left as a habit.
if ! "$PY" tools/globals_census_test.py > /dev/null; then
    "$PY" tools/globals_census_test.py 2>&1 | grep -E "FAULT|SKIPPED" || true
    note "BORDER FINDING - a global nobody classified"
    fail=1
fi

# 52) A clock told what time it is. Nineteen call sites answered the
# player through Voice with the literal 0 where the tick goes, and
# `speak` gates on (tick - lastSpokeAt) < COOLDOWN - so with any real
# last-spoke stamp the subtraction is hugely negative and the reply is
# swallowed, forever. That is the whole of "talking doesn't surface
# anything". A tick is only knowable at the moment of the call.
if ! "$PY" tools/tick_literal_test.py > /dev/null; then
    "$PY" tools/tick_literal_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - a number typed where a clock goes"
    fail=1
fi

# 53) An answer is decided by who asked. Talkativeness runs 0.20-0.85
# and gated replies to the player too, so a reserved survivor ignored a
# direct question four in five times, silently. `V.answer` is the
# player's entry point and `V.onEvent` everyone else's - decided by
# call site, because `company`, `ownCompany` and `parting` are each
# raised from BOTH a menu handler and the tick loop and no list of
# event names can be right about that.
if ! "$PY" tools/answer_set_test.py > /dev/null; then
    "$PY" tools/answer_set_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - a reply on the murmur path"
    fail=1
fi

# 54) A pass that survives the artifact being gone. Border 32 claims
# "every one able to fail" by GREPPING each mirror for a `return 1` -
# that proves a fail path exists in the text, not that anything reaches
# it, which is how [B46]'s Border 52 shipped printing "call sites: 0"
# and reporting clean. This runs every gated mirror against the tree
# with mod/42.20/media/lua emptied: a border that still passes was not
# reading the mod. Found three on its first run, one of them the Lua
# syntax border printing "all 0 shipped Lua files compile".
if ! "$PY" tools/vacuous_pass_test.py > /dev/null; then
    "$PY" tools/vacuous_pass_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - a verdict about an empty set"
    fail=1
fi

# 55) Two reaches less than a tile apart. Border 49 catches a bare
# radius that EQUALS a named reach; [B41]'s drift does not always land
# on equality. The Controller asked "am I already at the body" at 2.5
# tiles twice and asked the identical question as ARRIVAL_REACH - 3 -
# in five other places, and exactly-equal never happened, so nothing
# said anything for a hundred batches. Half a tile is not a distinction
# anyone chose in a world that moves in whole ones.
if ! "$PY" tools/reach_drift_test.py > /dev/null; then
    "$PY" tools/reach_drift_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - one rule written twice, half a tile apart"
    fail=1
fi

# 56) One door out to the console, and a lid on it. Measured from the
# operator's own log after [B44] made it readable: 898 of 2353 Lua
# lines - 38% - were ours, and the shape was one line per person in a
# county of 234. [B44] is that cost paid in full: our flood pushed the
# mod-loading phase out of console.txt and made "did my mods load?"
# unanswerable. Not a mute - a report becomes a signal. Every module
# speaks through SAO.Log, per-person lines are tallied rather than
# printed, and the tick empties the tallies.
if ! "$PY" tools/log_volume_test.py > /dev/null; then
    "$PY" tools/log_volume_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - the console written to around the lid"
    fail=1
fi

# 57) A registry nobody can see is a subsystem nobody can check. The
# operator played a session and asked whether it worked: 234 identities
# in the log, 340 population lines, and not one body materialising -
# with no way from inside the game to tell "nobody came near me" from
# "the live half never ran". The Ledger counted IDENTITIES and never
# read SAO.Body.active at all, and `Near you` vanishes when empty, so
# absent-because-nobody-is-near and absent-because-nobody-exists looked
# the same. Every registry of people must reach the panel.
if ! "$PY" tools/registry_surface_test.py > /dev/null; then
    "$PY" tools/registry_surface_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - a registry with no surface"
    fail=1
fi

# 58) A report that runs before the thing it reports on. The operator's
# own log, frame 240: "day 1: 0 living, 0 dead, 0 companies / target 0"
# - and 234 people created moments later. The boot digest sat at the TOP
# of populationTick, before genesis, so on a new world it was
# structurally guaranteed to describe an empty county. And `target 0` is
# the RAW sandbox option, where 0 means "size it from the map" - the one
# line saying what world you are in said this mod creates nobody. Plus
# the presence band, the only subsystem behind a bare `if` with no else.
if ! "$PY" tools/digest_order_test.py > /dev/null; then
    "$PY" tools/digest_order_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - a county described before it existed"
    fail=1
fi

# 59) A pool the code builds must say what it drew. The operator's
# session settled 49 pasts and every one was 'doors-decide-lives' -
# out of seven grammar entries, one of which fits EVERYBODY and so is
# in every pool ever built, and which came up not once. Simulating the
# loop over the same ids gives a healthy spread, so the source does not
# explain it and four batches of log-reading did not either. The defect
# bordered here is not the draw: it is that the draw had no instrument.
# A built pool can collapse to one entry, and a pool of one answers
# every question the same way.
if ! "$PY" tools/pool_draw_test.py > /dev/null; then
    "$PY" tools/pool_draw_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - a draw nobody counts"
    fail=1
fi

# 60) Arithmetic this engine cannot actually do. Four modules each
# carried `value = (value * 16777619 + byte) % 4294967296` - correct
# FNV that Kahlua CANNOT COMPUTE, because Lua numbers are doubles and
# the product reaches 7.2e16, eight times past the 2^53 a mantissa
# holds exactly. Measured over 59 real ids, hash % 1000 gave SIX
# distinct values instead of 59: every trait, occupation and face in
# the county collapsed to a handful of profiles. [B48] tested four
# hypotheses in Python, in exact integers, and so confirmed the code
# was fine - a model more capable than the machine.
if ! "$PY" tools/mantissa_test.py > /dev/null; then
    "$PY" tools/mantissa_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - an intermediate the mantissa cannot hold"
    fail=1
fi

# 61) Ask the engine, not a model. [B48] cleared four hypotheses about
# the lesson draw by simulating the Lua in Python, in exact integers -
# and [B48] then found the defect was that the engine CANNOT do exact
# integers past 2^53. The simulation was not wrong about the code, it
# was wrong about the machine, and a model more capable than the
# machine will always confirm the code is fine. So this loads the
# shipped SAO_Hash.lua into a real Kahlua VM out of projectzomboid.jar
# and reads back what the engine actually computes: 200 ids x 2 salts,
# all distinct, all equal to exact FNV. Restoring the old line makes
# the engine itself report 10 distinct values out of 200.
if ! "$PY" tools/hash_spread_test.py > /dev/null; then
    "$PY" tools/hash_spread_test.py 2>&1 | grep -E "FAULT|SKIPPED" || true
    note "BORDER FINDING - the engine cannot spread this hash"
    fail=1
fi

# 62) Seven kinds of past, in the engine. The operator's session settled
# 49 pasts and every one was the same key. [B48] disproved four
# hypotheses by reimplementing the loop in Python; [B48] found Kahlua
# cannot compute the FNV step; [B48] found the values then marched.
# None of it could be closed by reading, so this does not read: LuaRun
# loads the real Hash, Disposition, Census and History into a real
# Kahlua VM, calls the real H.generate 300 times, and records what the
# real draw drew. Every grammar key must appear; none may take 60%.
if ! "$PY" tools/lesson_draw_test.py > /dev/null; then
    "$PY" tools/lesson_draw_test.py 2>&1 | grep -E "FAULT|SKIPPED" || true
    note "BORDER FINDING - a county with one kind of person in it"
    fail=1
fi

# 63) A range a comment promises and the code cannot reach. Eight
# decisions in SAO_Disposition carried their range in a trailing
# comment and ALL EIGHT were wrong the same way: written as if a trait
# ran 0..1, when trait() returns 0.15..0.85 - the human envelope [A14]
# imposes. `overwhelmThreshold` promised a seventh step that is
# structurally unreachable; the rest described survivors who cannot
# exist. [B46] reasoned from one of them and got a number wrong. This
# reads each comment and asks a real Kahlua VM over 3000 ids.
if ! "$PY" tools/decision_range_test.py > /dev/null; then
    "$PY" tools/decision_range_test.py 2>&1 | grep -E "FAULT|SKIPPED" || true
    note "BORDER FINDING - a range the code cannot reach"
    fail=1
fi

# 64) A tick is a frame, so a tick count is not a duration. Measured
# from the operator's own log rather than assumed: the boot digest
# fires at `tickCounter % 240 == 0` and appears at FRAME 240, so the
# two counters are the same one - and that machine ran at 64.5 frames a
# second, not 60. Every `600 ticks -- ~10s` was 9.3s there, 20s at
# 30fps, 4.2s at 144Hz. Every duration claim must now name the frame
# rate it assumes, and what the player feels in real time (the voice
# cooldown) must read the engine's own clock.
if ! "$PY" tools/tick_duration_test.py > /dev/null; then
    "$PY" tools/tick_duration_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - seconds promised by a frame count"
    fail=1
fi

# 65) Time softens, and enmity ends. [B8] made the county's feelings
# age and nobody has ever watched it happen - it runs once a world-day
# inside a runSub, moves numbers in ModData, and every way for it to be
# wrong reads from inside a game as "the county is like that": too slow
# and every grudge is permanent, too fast and the standing layer is
# decoration, grace ignored and no feeling is ever current, bonds not
# exempt and the closest relationships are the ones eroding. This
# drives the real driftStandings in a real Kahlua VM a world-day at a
# time. Measured: grace holds 13 days, a grudge at -0.8 ends day 31, a
# bond is untouched after 200.
if ! "$PY" tools/time_softens_test.py > /dev/null; then
    "$PY" tools/time_softens_test.py 2>&1 | grep -E "FAULT|SKIPPED" || true
    note "BORDER FINDING - the county's feelings do not age as written"
    fail=1
fi

# 66) The county's composition is ours, not the mod list's. [B38]
# holds mod-added lives to MOD_SHARE and nobody had measured whether it
# does. Driven in a real Kahlua VM with the bridge stubbed: the base
# table holds at 10000 whatever is installed, the block caps at 1200
# while it can, and past that each life keeps a floor of 1 so rounding
# never deletes somebody's mod. [B50] also found this engine's
# table.sort dies between 1000 and 1500 entries - not a JVM stack limit
# - and catalog() sorts exactly that list during genesis inside a
# pcall, so the failure would be a county with no occupations.
if ! "$PY" tools/mod_share_test.py > /dev/null; then
    "$PY" tools/mod_share_test.py 2>&1 | grep -E "FAULT|SKIPPED" || true
    note "BORDER FINDING - the county's composition is up for grabs"
    fail=1
fi

# 67) Every sort is handed a list somebody has bounded. The engine ships
# its own stdlib.lua and table.sort is a Lua quicksort whose pivot is
# ALWAYS the leftmost element, so recursion depth follows the input's
# ORDER rather than its length - measured, a 1500-element list throws
# while a 4000-element one sorts fine. No size threshold is safe on its
# own, so depth is not what gets bounded here: the input is, and every
# sort site says what limits the list it receives.
if ! "$PY" tools/sort_bound_test.py > /dev/null; then
    "$PY" tools/sort_bound_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - a sort handed an unbounded list"
    fail=1
fi

# 68) A gmatch that never ends. The engine implements string.gmatch in
# its own stdlib.lua and advances `init` to `e + 1` - which for a
# ZERO-WIDTH match is exactly where it already was, so the iterator
# returns the same empty match forever. Measured on "a|b||c": "[^|]+"
# finishes in 3 pieces, "[^|]*" was still going at 50,001. In a game
# that is the Lua thread hung with no error and no log line, which is
# worse than [B44]'s throw - a throw at least reaches console.txt.
# Every pattern is put to the engine as string.find("", pattern).
if ! "$PY" tools/gmatch_progress_test.py > /dev/null; then
    "$PY" tools/gmatch_progress_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - a pattern that would hang the game"
    fail=1
fi

# 69) The engine facts this mod is built on. Six behaviours of PZ's Lua
# are in no documentation and this project built code around every one:
# `next` absent ([B44]), doubles losing the low bits past 2^53
# ([B48]), `assert` and `require` present ([B50], [B45]),
# table.sort's unchosen pivot ([B50]), gmatch not advancing on a
# zero-width match ([B50]). Each has a border checking OUR code
# against the fact - and nothing checked the fact. The mod pins to
# 42.20 and an update can move any of them, leaving workarounds nobody
# can justify and reasoning nobody can check.
if ! "$PY" tools/engine_facts_test.py > /dev/null; then
    "$PY" tools/engine_facts_test.py 2>&1 | grep -E "FAULT|SKIPPED" || true
    note "BORDER FINDING - an engine fact has moved under us"
    fail=1
fi

# 70) Somebody else's text in our protocol. Everything Java tells Lua it
# tells as a delimited string, and some of the values in those strings
# belong to other mods: profession paths, vehicle script names, item
# full types. [B50] found listProfessions packing a mod's namespace
# and path unsanitised - one '|' splits an entry, the Lua half skips
# the fragment it cannot parse, and a phantom trade appears while a
# real one goes missing. And SAOHibernation packed item full types into
# a ';,*@=' protocol that is WRITTEN TO THE SAVE. Each builder declares
# its own delimiters and must strip every one.
if ! "$PY" tools/protocol_field_test.py > /dev/null; then
    "$PY" tools/protocol_field_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - a protocol that trusts foreign text"
    fail=1
fi

# 71) A Java throw into Kahlua takes the Lua frame with it. SAOBridge's
# own class comment promises every method is exception-safe, and
# nothing checked it - of 112 public methods 60 carry no catch of their
# own because they delegate, and following the graph two hops is the
# only way to know. Lua calls all of these, usually inside a pcall, so
# a throw does not report: it makes the county quietly do less, the
# shape [B42] and [B44] each cost a batch to find.
if ! "$PY" tools/bridge_safety_test.py > /dev/null; then
    "$PY" tools/bridge_safety_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - a Lua-facing method with no net"
    fail=1
fi

# 72) The county keeps its dead on purpose - "death is durable: the
# record stays". Nothing else was told to forget them. Perception and
# Voice already HAD the right forget functions, nilling the right
# tables, reached only by the test harness - so every survivor who
# died left their beliefs about the world in memory for the session,
# and two pair-keyed cooldowns kept an entry per pair they had ever
# met. Written-but-never-reached, invisible to every other border
# here, because nothing about the code is wrong except that nobody
# calls it.
if ! "$PY" tools/forget_on_death_test.py > /dev/null; then
    "$PY" tools/forget_on_death_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - a per-id cache that outlives the id"
    fail=1
fi

# 73) The icon and poster are drawn by tools/make_art.py from
# arithmetic, and this regenerates them and compares the decoded
# pixels. Committing two hand-drawn PNGs would have left this tree with
# the only shipped artifact nothing can check - the jar is compared
# against its sources, the sandbox options against their translations,
# and the art would have been compared against nothing. Pixels rather
# than bytes, so a better zlib does not turn the gate red.
if ! "$PY" tools/art_derived_test.py > /dev/null; then
    "$PY" tools/art_derived_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - shipped art that is not what the generator draws"
    fail=1
fi

# 74) The population pass walks the whole identity store eight times,
# every 240 frames, and the store keeps the dead on purpose - in
# ModData, so the graveyard grows across every session of a save.
# Measured: about 0.086 ms per thousand records per walk, so at thirty
# thousand graves the pass spends more than a whole 60fps frame
# walking past the dead. Each walk is declared with what bounds it,
# and a sub the tick runs that nobody declared is a fault.
if ! "$PY" tools/tick_walk_test.py > /dev/null; then
    "$PY" tools/tick_walk_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - an undeclared walk over a store nothing shrinks"
    fail=1
fi

# 75) The hibernation record is Java -> the SAVE -> Java. Border 15
# pairs delimited protocols against the Lua that parses them and has
# printed this one as UNCHECKED on every run, correctly: Lua carries
# the string and never looks inside it. So the one protocol written to
# somebody's save was the one protocol with nothing checking that its
# two ends agree. Adding a key to the packer and forgetting the reader
# loses that field in silence - the switch has no default that
# complains.
if ! "$PY" tools/hibernation_pact_test.py > /dev/null; then
    "$PY" tools/hibernation_pact_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - the two ends of the saved record disagree"
    fail=1
fi

# 76) SESSION_STATE.md is marked CANONICAL - where the work actually
# stands - and until [B52] it opened by claiming a hundred and
# fifty-five B-batches when there were a hundred and eighty-nine, and
# forty-four borders when there were seventy-five. That is [B43]'s
# finding in the document that exists to prevent it. The figures are
# derived here and the document must state them, so a count in prose
# cannot go stale in silence.
if ! "$PY" tools/state_counts_test.py > /dev/null; then
    "$PY" tools/state_counts_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - the canonical document counts wrongly"
    fail=1
fi

# 77) Comparing `dx*dx + dy*dy` against a radius without squaring it is
# the oldest arithmetic mistake in this kind of code and it is
# invisible: `d2 <= 40` reads as forty tiles and means 6.3, and nothing
# in the game will ever say so - a survivor is simply not noticed until
# they are much closer than the source says. All twelve squared
# comparisons in this tree use a perfect square. This keeps it that way.
if ! "$PY" tools/squared_scale_test.py > /dev/null; then
    "$PY" tools/squared_scale_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - a distance compared at the wrong scale"
    fail=1
fi

# 78) The pressure answer is a closed domain of four - need,
# designation, chosen rest, errand - and every transition fills it, so
# a survivor is never doing nothing. [B52] found the tree spelling
# five: four sites answered "rest" against three answering "chosen
# rest". Nothing compared against either, so the split was free and
# invisible, and the day somebody writes `answer == "chosen rest"` it
# silently misses four of the seven rests in the county.
if ! "$PY" tools/pressure_answer_test.py > /dev/null; then
    "$PY" tools/pressure_answer_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - a pressure answer outside the four"
    fail=1
fi

# 79) MAPS.md is what a new reader trusts first. A link or node naming a
# file that is gone, or a rule that no longer exists, is the map lying
# quietly - the class [C1] found in the flicker that outlived its fix.
if ! "$PY" tools/map_reference_test.py > /dev/null; then
    "$PY" tools/map_reference_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - a map points at something that is not there"
    fail=1
fi

# [C2] Border 80 - the version is a machine (DR-013). 0.6.0.0 was picked
# at [B12] by a policy sentence after the diary bumped through hundreds
# of entries; the old map then walked to it in six flat minors so the
# number looked earned. Now the tier table in tools/version_replay.py is
# the input, CAO's caps are the rules, and the coordinate is the output -
# this border refuses a tree whose VERSION, VERSION_MAP.md or mod.info
# state anything the replay does not derive.
if ! "$PY" tools/version_replay.py > /dev/null; then
    "$PY" tools/version_replay.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - a stated version the machine does not derive"
    fail=1
fi

# [C3] Border 81 - one person, one name (DR-014). A follower shown as
# one name dropped an ID card for somebody else: the spawn path stamped
# placeholders over the engine's generated name, adoption took a
# descriptor name the neighbour never shows, and the [B45] hold tested
# a global that does not exist. The pipeline has one owner per name now
# and this border keeps each leak closed.
if ! "$PY" tools/name_pipeline_test.py > /dev/null; then
    "$PY" tools/name_pipeline_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - two names on one person"
    fail=1
fi

# [C4] Border 82 - the seat and the mesh move together; the follow
# crosses. enter() was bare (no mesh pairing, no rollback), a fence was
# an eternal unnamed stall, and riding was a flag the truth of the seat
# could contradict. The operator's wreck - a driven truck with no
# visible driver who could not exit - is the class this refuses.
if ! "$PY" tools/seat_and_crossing_test.py > /dev/null; then
    "$PY" tools/seat_and_crossing_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - a flag moved without its body, or a stall with a name"
    fail=1
fi

# [C5] Border 83 - a top-level function is at the top level. P.tell was
# never closed and three column-zero functions were being defined
# inside its body: nil until the first tell of a session, their absence
# pcall-swallowed. Legal Lua, invisible to every syntax gate.
if ! "$PY" tools/toplevel_function_test.py > /dev/null; then
    "$PY" tools/toplevel_function_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - an unclosed block has swallowed a function"
    fail=1
fi

# [C5] Border 84 - world text is a person talking (SPEECH.md). No
# coordinates in anyone's mouth, the tell surface speaks the thing
# itself rather than a count of things, the day-zero innocent asserts
# nothing they hold no claim for.
if ! "$PY" tools/spoken_word_test.py > /dev/null; then
    "$PY" tools/spoken_word_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - world text that is not a person talking"
    fail=1
fi

# [C6] Border 85 - the inspect harness reads everything and teaches
# nothing. A panel that can see every store is one function call from
# being a pathway; this holds the window shut, holds it to a normal
# launch, and holds its lines to the one telemetry door.
if ! "$PY" tools/inspect_inert_test.py > /dev/null; then
    "$PY" tools/inspect_inert_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - a window became a pathway, or the harness is gone"
    fail=1
fi

# [C7] Border 86 - the neighbour's menu stays, and the county is inside
# it (DR-015). "Use what KS puts in the game for UI" means superimpose:
# his per-survivor root is kept, retitled to the person, and rebuilt
# from the county - never stripped, never doubled.
if ! "$PY" tools/superimpose_test.py > /dev/null; then
    "$PY" tools/superimpose_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - two person menus on one body, or a stripped root"
    fail=1
fi

# [C8] Border 87 - the turn is real (DR-016, F-044/F-045). Every dead
# shell reaches the engine's own die() through the corpse net, the
# person id rides modData through the engine's own copies, and
# recognition keys on the id that survives the turn rather than the
# descriptor that does not.
if ! "$PY" tools/turn_real_test.py > /dev/null; then
    "$PY" tools/turn_real_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - a death that never turns, or an identity that dies with the descriptor"
    fail=1
fi

# [C9] Border 88 - the pool is only the fungible crowd. The zombie
# list holds living neighbours, risen players, and the county's marked
# dead; one deletion-grade predicate (failing closed) guards every
# consumer, and the removeFromWorld census is closed.
if ! "$PY" tools/pool_identity_test.py > /dev/null; then
    "$PY" tools/pool_identity_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - a deletion or a choreography that could take a person"
    fail=1
fi

# [C10] Border 89 - the kept promise swings at the BODY carrying the
# person's mark, misses honestly, and never takes the nearest stranger.
if ! "$PY" tools/promise_body_test.py > /dev/null; then
    "$PY" tools/promise_body_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - a mercy kill that would take the wrong body"
    fail=1
fi

# [C11] Border 90 - the bite kills on the engine's own deterministic
# clock (F-047), read off the body or mirrored with citation; no
# constant claims engine authority it does not have.
if ! "$PY" tools/bite_clock_test.py > /dev/null; then
    "$PY" tools/bite_clock_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - an invented number wearing the engine's name"
    fail=1
fi

# [C12] Border 91 - the front end speaks player (DR-017): no decode
# tables, no mode-sentinels, no apologies for the encoding; the one
# word-to-sentinel translation lives in the policy reader.
if ! "$PY" tools/frontend_language_test.py > /dev/null; then
    "$PY" tools/frontend_language_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - engine language on the player's screen"
    fail=1
fi

# [C13] Border 92 - player-facing copy is ratified, not drafted
# (DR-018): the shipped strings match the declaration verbatim, and a
# copy change fails the gate until it is re-declared with the
# operator's eyes on it.
if ! "$PY" tools/copy_ratified_test.py > /dev/null; then
    "$PY" tools/copy_ratified_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - unratified copy on the player's screen"
    fail=1
fi

# [C14] Border 93 - every qualified SAO.<Module>.<fn> call resolves to
# a definition. A missing target inside this tree's pcall discipline
# is a silent no-op forever (F-030/F-039's shape).
if ! "$PY" tools/call_target_test.py > /dev/null; then
    "$PY" tools/call_target_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - a call that no-ops silently forever"
    fail=1
fi

# [C15] Border 94 - whole minds survive the reload (DR-020): the
# belief store binds to ModData at game start, the tick axis rebases
# once, the hours axis crosses intact, and F-033's durability stands.
if ! "$PY" tools/whole_minds_test.py > /dev/null; then
    "$PY" tools/whole_minds_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - a mind that dies with the session, or stale intel reading fresh"
    fail=1
fi

# [C16] Border 95 - the dead census (DR-021's instrument): raw
# numbers through verified surfaces, the identity split honored, the
# instrument inert, assumptions stated where figures are made.
if ! "$PY" tools/dead_census_test.py > /dev/null; then
    "$PY" tools/dead_census_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - a census missing, mutating, or hiding its assumptions"
    fail=1
fi

# [C17] Border 96 - the crowd ledger (DR-021's state agreement): the
# pool's takes counted durable, restitution debt-bounded and paced on
# distant ground, the dial off by default, one accounting for both.
if ! "$PY" tools/crowd_ledger_test.py > /dev/null; then
    "$PY" tools/crowd_ledger_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - two systems mutating one crowd without one ledger"
    fail=1
fi

# [C19] Border 97 - play receipts accrue (DR-025): the ledger parses
# and cites real records, and the perpetual-untested blanket claim is
# banned from the canonical documents.
if ! "$PY" tools/receipts_test.py > /dev/null; then
    "$PY" tools/receipts_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - a broken receipts ledger, or the tautology returned"
    fail=1
fi

# [C20] Border 98 - absorption obeys the neighbour's body law
# (DR-022/023/024, F-051/F-052): the one spawn door wrapped with an
# honest fallback, remove-never-kill, no marker keys, truth mirrored
# back, dials blocked, verb parity kept.
if ! "$PY" tools/absorb_test.py > /dev/null; then
    "$PY" tools/absorb_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - an absorption that doubles, kills, or diminishes a person"
    fail=1
fi

# [C25] Border 99 - how far a person goes is knowledge and desire
# (DR-027): the errand dial is dead everywhere, the probe is a named
# perception span, all four needs fall back to the nearest KNOWN
# offering under the same property law, horizons derive from the
# engine's own cell, and held knowledge is revalidated and expires.
if ! "$PY" tools/knowledge_first_test.py > /dev/null; then
    "$PY" tools/knowledge_first_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - a leash returned, or need still gives up at the probe line"
    fail=1
fi

# [C26] Border 100 - the click lands, the body is dressed, the line
# holds (R-005/R-006, DR-028, F-054): answers bypass the murmur
# guards, the talk wall is down to the advertised split, dressing is
# outcome-verified with a worn report, and the wake law keeps foreign
# ground - one species: nothing is REPORTED that was not VERIFIED.
if ! "$PY" tools/click_lands_test.py > /dev/null; then
    "$PY" tools/click_lands_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - a click eaten, a naked body called dressed, or a line crossed"
    fail=1
fi

# [C27] Border 101 - the knowledge surface (SPEECH_ML_DESIGN.md rung
# 1): loads bare in the engine's own VM, answers a stub county with
# provenance and age, withholds the earned until trust, bundles the
# ratified conditioning, writes nothing, and the inspect panel reads
# through it.
if ! "$PY" tools/knowledge_surface_test.py > /dev/null; then
    "$PY" tools/knowledge_surface_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - the knowledge surface does not answer, or it writes"
    fail=1
fi

# [C28] Border 102 - the inference budget instrument
# (SPEECH_ML_DESIGN.md): a deterministic model-shaped workload,
# warmed, nanosecond-timed, checksum-carried, fired from the debug
# menu, reported under BUDGET with its conditions named.
if ! "$PY" tools/inference_budget_test.py > /dev/null; then
    "$PY" tools/inference_budget_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - the budget instrument is missing or dishonest"
    fail=1
fi

# [C29] Border 104 - the body is scaled from inside the animation
# player (DR-032): one exit advice on AnimationPlayer's model-transform
# build, only the shell carries a size, the arithmetic is uniform about
# the feet, both load paths install it, the body is sized after it is
# dressed, the harness carries the click and the report, and the
# installed game's class weaves, links and verifies off the game.
if ! "$PY" tools/body_scale_test.py > /dev/null; then
    "$PY" tools/body_scale_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - the body scale is missing, misplaced, or does not weave"
    fail=1
fi

# [C30] Border 105 - age is a system on the county's people (DR-032):
# children and elders in the bands as facts about the person, the age
# deciding the work, the size and the pace, the stages drifting the
# living every ten minutes, and the old dying of it on the life table -
# driven in the engine's own VM against a stub county.
if ! "$PY" tools/age_bands_test.py > /dev/null; then
    "$PY" tools/age_bands_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - the county's ages are not a system"
    fail=1
fi

# [C31] Border 106 - the child's day (DR-032): the fear floor by age,
# the night and the comfort object, the kills that harden; literacy;
# the throttle and the birthday floors; the kit from the child's own
# temperament; the child's head - driven in the engine's own VM and
# read off every seam that carries it.
if ! "$PY" tools/childs_day_test.py > /dev/null; then
    "$PY" tools/childs_day_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - the child's day is not carried"
    fail=1
fi

# [C32] Border 107 - conditions are facts about a person (DR-032):
# drawn at the record's prevalence and gated by age, deterministic,
# named in plain words; bending the axes inside the envelope, adding
# fear, setting how long a belief is kept, what the body carries,
# what the skills lose and what a book costs - driven in the engine's
# own VM and read off every seam, with the two required mods named in
# both manifests.
if ! "$PY" tools/conditions_test.py > /dev/null; then
    "$PY" tools/conditions_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - the conditions are not facts about a person"
    fail=1
fi

# [C33] Border 108 - habits are facts about a person (DR-032, S6): the
# drinker at the record's prevalence with The Alcoholic's phases, the
# drink taken and the habit lost or gained on the record; the users
# the county fell with on N and C's schedule; what a habit carries
# every pass; the drink found and taken through the engine's own
# fluid surfaces - driven in the engine's own VM and read off every
# seam.
if ! "$PY" tools/habits_test.py > /dev/null; then
    "$PY" tools/habits_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - the habits are not facts about a person"
    fail=1
fi

# [C35] Border 109 - the county's gestures (DR-034): every copied file
# present, rigged and credited; every node parsing and naming a file;
# every name the module uses bound; the sounds defined; and the
# moments - the meeting, the voice's events, the seat, the tune -
# wired to the gesture that shows them.
if ! "$PY" tools/gestures_test.py > /dev/null; then
    "$PY" tools/gestures_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - the county's gestures are not carried"
    fail=1
fi

# [C36] Border 110 - the record on the county's calendar (DR-031): the
# date arithmetic run off the game against the installed jar, and
# every seam - the once-per-save re-key with its retry, the container
# fill, the option, the harness, the contract, the helper's own
# argument order.
if ! "$PY" tools/record_calendar_test.py > /dev/null; then
    "$PY" tools/record_calendar_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - the record is not on the county's calendar"
    fail=1
fi

# [C37] Border 111 - an order lands through standing (DR-033, ruled):
# CAO's obedience check on the Standing that exists, run in the
# engine's own VM over the county sampled - the leader's word, the
# disliked stranger's, the proven hand's, the chair's - and the
# envelope's refusals; by text, every ask in the harness through the
# gate, the three answers, the gesture, the panel and the margin.
if ! "$PY" tools/command_test.py > /dev/null; then
    "$PY" tools/command_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - an order does not land through standing"
    fail=1
fi

# [C38] Border 112 - the era remembered (Day Zero slice 6): the
# knowledge surface answers "before" and "the day it started" in
# the engine's own VM with provenance and the county's dates, writes
# nothing; the chronicle and the surface read one calendar.
if ! "$PY" tools/era_test.py > /dev/null; then
    "$PY" tools/era_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - the era is not remembered"
    fail=1
fi

# [C39] Border 113 - SAO carries its own conditions (DR-032 amended):
# the traits registered from shared Lua and priced off vanilla's own
# file, vanilla's trait used where vanilla has one, the condition
# stamped onto a body, the player's traits asserted and driven, and
# neither manifest requiring another mod.
if ! "$PY" tools/traits_test.py > /dev/null; then
    "$PY" tools/traits_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - the conditions are not SAO's own"
    fail=1
fi

# [C40] Border 114 - the county stands on its own (DR-035): nothing
# this mod does requires another mod's namespace, every reach into
# one is behind the bridge that defaults off, and what stays always
# on uses none of their code.
if ! "$PY" tools/self_contained_test.py > /dev/null; then
    "$PY" tools/self_contained_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - the county leans on another mod"
    fail=1
fi

# [C41] Border 115 - the world is generated before it is spawned
# (DR-036): the whole county on a fresh save, the pace only once it
# exists, and genesis ahead of the band in the tick - the ordering
# law the claim rests on.
if ! "$PY" tools/world_before_spawn_test.py > /dev/null; then
    "$PY" tools/world_before_spawn_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - the world is spawned as it is generated"
    fail=1
fi

# [C42] Border 116 - before the fall, an ordinary life (DR-036): the
# county can be asked whether the fall has reached it, the answer is
# derived from the record and never from the sandbox dial, and every
# survival-shaped decision asks it.
if ! "$PY" tools/before_the_fall_test.py > /dev/null; then
    "$PY" tools/before_the_fall_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - the county lives a survival day before the fall"
    fail=1
fi

# [C44] Border 117 - they either build or they do not (DR-036 ruled):
# the capability is the engine's own barricade at its own price, every
# clause of the decision can fail, and nothing anywhere places a
# fortification that nobody built.
if ! "$PY" tools/they_build_test.py > /dev/null; then
    "$PY" tools/they_build_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - building is forced, free, or absent"
    fail=1
fi

# [C45] Border 118 - the years between are lived, not invented
# (DR-036): every call in a simulated day is the live county's own,
# at the measured daily cadence, sliced so it cannot hang, after
# genesis and before the band.
if ! "$PY" tools/years_between_test.py > /dev/null; then
    "$PY" tools/years_between_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - the years are invented or not lived"
    fail=1
fi

# [C46] Border 119 - the ground is looked at and not written to
# (DR-036, DR-037): a claim's chunks are loaded off disk during the
# years where the world does not hold them, read, and let go - and
# nothing in that path saves a chunk or places anything.
if ! "$PY" tools/ground_survey_test.py > /dev/null; then
    "$PY" tools/ground_survey_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - the ground is written to, or never read"
    fail=1
fi

# [C47] Border 120 - a person can only say what they know: the
# constrained-decoding fence (SPEECH_ML_DESIGN Decision 4, ratified)
# proved mechanically over a corpus off the game, near-misses
# included, with its slots read off the claim set.
if ! "$PY" tools/fence_test.py > /dev/null; then
    "$PY" tools/fence_test.py 2>&1 | grep -E "FAULT|FAIL" || true
    note "BORDER FINDING - a person could say what they do not know"
    fail=1
fi

# [C48] Border 121 - a place is judged by how hard it is to get
# into: the scout counts the ways in off the loaded ground with the
# boarding's own predicate, and breaks ties within one room's worth
# by them - never pricing a door against a room.
if ! "$PY" tools/ways_in_test.py > /dev/null; then
    "$PY" tools/ways_in_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - a door has a price, or the scout is blind"
    fail=1
fi

# [C49] Border 122 - survivor orders use the command check: orders one
# survivor gives another go through SAO_Command like the player's,
# reading divided houses, designations and claims from Standing, and
# the hardcoded authority test in SAO_Controller is deleted.
if ! "$PY" tools/survivor_orders_test.py > /dev/null; then
    "$PY" tools/survivor_orders_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - an authority test is hardcoded, or an order skips the check"
    fail=1
fi

# [C50] Border 123 - what a survivor says follows what they have
# learned: the line tables about the dead are split by register and
# the register is the county's own innocence boundary, the taught
# lines are unchanged, an unreadable lesson store keeps the taught
# register, and the first lesson is audible once.
if ! "$PY" tools/speech_register_test.py > /dev/null; then
    "$PY" tools/speech_register_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - the innocent speak like veterans, or the register is invented"
    fail=1
fi

# [C51] Border 124 - the habits are the player's too: the county's
# habits registered as engine traits at vanilla's own price, cannabis
# skipped because it costs nothing, smoking left to vanilla's trait,
# the player's habit state bound to their own modData so it can lapse,
# and the withdrawal driven on their own ten-minute pass.
if ! "$PY" tools/habit_traits_test.py > /dev/null; then
    "$PY" tools/habit_traits_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - a habit the player cannot take, or one that never lets go"
    fail=1
fi

# [C52] Border 125 - every prevalence figure is traceable to a stated
# source: each row in both prevalence tables names a year or points at
# the table above it, states a figure, and its constant is reachable
# from that figure by a derivation the row itself names; a zero draws
# nobody, so a zero must say out loud that no figure was read.
if ! "$PY" tools/prevalence_sourced_test.py > /dev/null; then
    "$PY" tools/prevalence_sourced_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - a prevalence figure has drifted from its citation"
    fail=1
fi

# [C54] Border 126 - the objection picks the car: the appraisal takes
# the goer's own loudness ceiling, so somebody who refuses a loud car
# gets the quiet one out of the same yard instead of walking past it,
# and walks only when there is nothing quiet to take.
if ! "$PY" tools/motor_pool_test.py > /dev/null; then
    "$PY" tools/motor_pool_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - a refused car ends the question instead of choosing the next"
    fail=1
fi

# [C55] Border 127 - seeing a death is not seeing who did it (Law 1):
# a killer is named only by a witness who could have seen them - a
# fresh observed belief of them at the place for a live witness, the
# positional question for a dormant one - while the death itself still
# lands on everybody who saw the victim.
if ! "$PY" tools/blame_test.py > /dev/null; then
    "$PY" tools/blame_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - blame lands on somebody the witness never saw"
    fail=1
fi

# [C56] Border 128 - a border that cannot run says so: every tool that
# reads the installed game returns 0 and prints SKIPPED when it is
# absent, so a machine without Project Zomboid reports what ran rather
# than the gate refusing. Fifteen exited 1 instead, which would have
# failed CI on every machine but the operator's.
if ! "$PY" tools/skips_cleanly_test.py > /dev/null; then
    "$PY" tools/skips_cleanly_test.py 2>&1 | grep -E "FAULT" || true
    note "BORDER FINDING - a border reads a finding into a missing game"
    fail=1
fi

# [C60] Border 129 - the player's looting spends a place ([B39]'s
# standing gap): read off the engine's own looted flag, raising the
# county's tally for the place the player is standing in and never
# lowering it.
if ! "$PY" tools/player_looting_test.py > /dev/null; then
    "$PY" tools/player_looting_test.py 2>&1 | grep -E "FAULT|SKIPPED" || true
    note "BORDER FINDING - the county cannot see what the player emptied"
    fail=1
fi

# [C61] Border 130 - one clock for how long this has been going on:
# what a person knows is aged off the record's own calendar, the way
# [C42] ruled the fall is read, with the sandbox dial answering only
# where the calendar cannot be read at all.
if ! "$PY" tools/one_clock_test.py > /dev/null; then
    "$PY" tools/one_clock_test.py 2>&1 | grep -E "FAULT|SKIPPED" || true
    note "BORDER FINDING - the county keeps two clocks"
    fail=1
fi

# [C62] Border 131 - the county's clock moves while the years are
# lived: one answer to what hour it is, read by every module, so the
# systems that gate on a change of day see one during [C45]'s span.
if ! "$PY" tools/county_clock_test.py > /dev/null; then
    "$PY" tools/county_clock_test.py 2>&1 | grep -E "FAULT|SKIPPED" || true
    note "BORDER FINDING - the county's clock stops while the years run"
    fail=1
fi

# [C63] Border 132 - a save the record is moved onto owes no years:
# the day-zero switch decides the timeline and the days owed together,
# so a county cannot live months of collapse before an outbreak its
# own record says has not happened.
if ! "$PY" tools/day_zero_owes_test.py > /dev/null; then
    "$PY" tools/day_zero_owes_test.py 2>&1 | grep -E "FAULT|SKIPPED" || true
    note "BORDER FINDING - a day-zero start owes years it should not"
    fail=1
fi

# [C65] Border 133 - the years pass leaves a trajectory: a run
# boundary, what the run was run under, and a county line per
# simulated day that says what the years actually produced.
if ! "$PY" tools/years_trajectory_test.py > /dev/null; then
    "$PY" tools/years_trajectory_test.py 2>&1 | grep -E "FAULT|SKIPPED" || true
    note "BORDER FINDING - a span of years leaves no trajectory"
    fail=1
fi

# [C66] Border 134 - the county's draw is its own, and it is measured:
# statistics over what the real module produces, at the three moduli
# that matter, because the first draft of it ramped and a border that
# read the formula would have passed it.
if ! "$PY" tools/county_draw_test.py > /dev/null; then
    "$PY" tools/county_draw_test.py 2>&1 | grep -E "FAULT|SKIPPED" || true
    note "BORDER FINDING - the county's draw is the engine's, or it is not flat"
    fail=1
fi

# [C67] Border 135 - a founded company is still standing afterwards:
# the roster is written whole and elected once, so the widow release
# cannot fire in the middle of a founding and dissolve the house being
# born. Measured in the VM, because the defect called the right verb
# the right number of times.
if ! "$PY" tools/company_forms_test.py > /dev/null; then
    "$PY" tools/company_forms_test.py 2>&1 | grep -E "FAULT|SKIPPED" || true
    note "BORDER FINDING - founding a company dissolves it"
    fail=1
fi

# [C68] Border 136 - a death leaves the company: the roster means
# living membership, so a dead member's row goes and the house settles
# again. Before this the widow release fired when a housemate LEFT and
# never when one DIED.
if ! "$PY" tools/death_leaves_company_test.py > /dev/null; then
    "$PY" tools/death_leaves_company_test.py 2>&1 | grep -E "FAULT|SKIPPED" || true
    note "BORDER FINDING - a death does not leave the company"
    fail=1
fi

# [C71] Border 137 - a belief is about a person: every person has a
# belief key of their own, a dormant meeting is written down, and word
# of a death opens a store in a head that has nothing in it. Before
# this the whole county keyed on the sentinel "Unnamed", so one death
# notice was everybody's entire memory of the dead.
if ! "$PY" tools/person_belief_test.py > /dev/null; then
    "$PY" tools/person_belief_test.py 2>&1 | grep -E "FAULT|SKIPPED" || true
    note "BORDER FINDING - beliefs about people are not about people"
    fail=1
fi

# [C72] Border 138 - the dormant day can go to a person: the goal path
# decided from thirst, hunger, lessons, beliefs and barred ground and
# had no social term in it, so nobody in the county had ever decided to
# go to another person and every meeting was two need-driven walks
# coinciding within three tiles.
if ! "$PY" tools/seek_test.py > /dev/null; then
    "$PY" tools/seek_test.py 2>&1 | grep -E "FAULT|SKIPPED" || true
    note "BORDER FINDING - nobody in the county decides to go to anybody"
    fail=1
fi

# [C73] Border 139 - a person is named when they are made (DR-039):
# backfillName read a name off the engine descriptor the first time a
# body was built for somebody, so a county that materialises nobody had
# 271 of 271 people carrying the Unnamed sentinel.
if ! "$PY" tools/named_at_genesis_test.py > /dev/null; then
    "$PY" tools/named_at_genesis_test.py 2>&1 | grep -E "FAULT|SKIPPED" || true
    note "BORDER FINDING - the county's people have no names"
    fail=1
fi

# Border 103 - the operator's speech is not in the repository: no
# profanity in the tracked tree and no operator-quote attributions;
# rulings are paraphrased content, speech stays with the speaker.
if ! "$PY" tools/operator_speech_test.py > /dev/null; then
    "$PY" tools/operator_speech_test.py 2>&1 | grep -E "FAULT" | head -6 || true
    note "BORDER FINDING - quoted speech or profanity is in the tree"
    fail=1
fi

if [ "$fail" -ne 0 ]; then
    note "REFUSING: fix the findings above, or state why they are"
    note "acceptable in the batch record and re-run."
    exit 1
fi
note "all borders clean"
exit 0
