#!/usr/bin/env bash
# The offline mirrors ([B19] brought them into the repo;
# [B19] added a fourth, [B20] a fifth, [B24] a sixth, [B25] a
# seventh, [B25] an eighth, [B28] a ninth, [B32] a tenth, [B33] an
# eleventh, [B33] a twelfth, [B33] a thirteenth,
# [B33] a fourteenth, [B33] a fifteenth,
# [B34] a sixteenth, [B34] a
# seventeenth, [B34] an eighteenth,
# [B34] a nineteenth, [B35] a
# twentieth, [B35] a twenty-first and [B35] a
# twenty-second and [B35] a
# twenty-third and [B36] a
# twenty-fourth and [B36] a
# twenty-fifth and [B37] a twenty-sixth,
# so this is no
# longer a trilogy and the script was renamed rather than left
# carrying a name that had stopped being true).
#
# These are offline Python mirrors of the social laws: they re-run the
# exact hash math and the exact convergence rules outside the game, so
# a claim about how this county behaves can be CHECKED rather than
# asserted. B-ERA-OFFLINE-RECEIPTS.md cites their results; before
# [B19] the scripts themselves lived only in a session temp directory
# and the cited proof could not be re-run by anyone, including a later
# session of the author.
#
# Social-law changes port to these mirrors in the same batch.
set -uo pipefail
cd "$(dirname "$0")/.."
fail=0
for t in depth_test_c3 census_test equilibrium_test joining_test triage_test ask_test work_test identity_test outsider_test betweentime_test radius_test arrival_test foreign_test combat_patch_test bulkhead_test menu_reach queue_drop_test ledger_rows exchange_test belief_life_test key_domain_test voice_reach_test policy_reach_test claim_lifecycle_test save_compat_test age_test; do
    echo "=== $t ==="
    if python "tools/$t.py"; then :; else
        echo "[mirrors] $t FAILED"; fail=1
    fi
done
if [ "$fail" -eq 0 ]; then echo "[mirrors] all twenty-six ran"; fi
exit "$fail"
