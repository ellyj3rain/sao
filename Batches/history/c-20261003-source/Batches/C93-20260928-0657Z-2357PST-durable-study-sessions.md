# C93 - Durable configurable study sessions

| Field | Record |
|---|---|
| Batch | C93 |
| Date | 2026-09-28 |
| Timestamp | 2026-09-28 06:57 UTC / 23:57 PST |
| Name | Durable configurable study sessions |
| Status | Closed; mechanical verification complete. |
| Threads | T-002, T-006, T-008, T-009, T-030 |

C93 turns the existing verified native save and resume path into one durable
study session. Each native process remains a finite attempt. The session keeps
its attempt duration, accumulated simulated hours, latest world hour, last stop
reason and exact consumed lifecycle requests outside the save. A normal save can
continue; a failed or forced attempt cannot.

The ordinary attempt limit moves from ten minutes to one hour and remains
configurable from 30 seconds through seven days. Longer studies can use repeated
saved attempts instead of requiring one unbounded process. Automatic continuation
is off by default and applies only after a clean wall-time checkpoint. An
explicit save stays stopped until continued.

Speakeasy projects the bounded path-free session state into its existing native
view and accepts only three additional lifecycle requests: save the current
attempt, configure later attempt duration and automatic continuation, or continue
a completed save. Mousecat shows Save session or Continue session as the current
primary action. Duration and automatic continuation remain inside the expandable
Session settings section. A successor feed replaces its predecessor only after
the first complete frame is available.

Session state and every observation retain `datasetAdmission: unreviewed` and a
null behavioral verdict. Lifecycle controls cannot approve a scenario, create a
training row or teach a preferred behavior.

| Verification | Result |
|---|---|
| Border 210 | Pass: bounded settings, verified saved continuation, native-attempt binding and exact-once command consumption. |
| Focused SAO session checks | Bounded configuration, normal saved continuation and exact-once lifecycle consumption pass. |
| Complete SAO gate | All 225 scripts and Borders through 210 pass; shipped JARs carry `3.4.0.0-pre-alpha`. |
| Existing native supervision | Wall limit, fatal error, pause, stale producer, shutdown and owner-loss checks pass. |
| Speakeasy bridge | Record 77 focused 29-test and complete 233-test suites pass; PR #45 merged. |
| Mousecat | A20 complete 293-test gate and 1680/760 px browser checks pass; PR #14 merged and Desktop installed. |

Loaded-world acceptance remains separate. This batch establishes resumable
operation and observation controls; the next native study measures whether the
C90-C92 cooperation and posture mechanisms form, persist and adapt in varied
two-to-seven-person survival situations.
