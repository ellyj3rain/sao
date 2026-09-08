# C58 - The codeql-action halves travel together

| Field | Record |
|---|---|
| Batch | `C58` |
| Date | 2026-09-08 |
| Name | The codeql-action halves travel together |
| Status | Closed append-only batch - the CodeQL run on the published tip is its receipt |
| Threads | [`T-030`](THREADS.md#t-030) |

## Record

Two dependabot pull requests had stood open since 2026-08-31, both
failing, and both failing for the same reason:

```
Loaded a configuration file for version '4.37.7', but running version '4.37.9'
```

`github/codeql-action/init` and `github/codeql-action/analyze` are two
dependencies to dependabot and one action to CodeQL. The workflow
pinned both to the same commit, dependabot opened one pull request per
half, and inside each of them one half moved and the other did not.
CodeQL checks that its init and analyze agree and refuses when they do
not, so each pull request failed on its own change - and neither could
ever have passed, because the fix is not in either of them.

Both pins move to `v4.37.9` in one commit here, which is what those
two pull requests were each half of. The tag was read off the upstream
repository rather than taken from the pull requests: `v4.37.9`
resolves to `cdf488f5`, which is the commit both proposed.

And the config groups them, so a future bump carries both halves in
one pull request and the mismatch cannot arise again. The two open
pull requests are superseded by this and dependabot closes them on its
next run.

**What this was not.** CodeQL was passing on `main` throughout - the
`[C56]` and `[C57]` runs both succeeded. The failures were on the two
dependabot branches only. An earlier report in this session that
CodeQL was red on `main` was wrong and is corrected here.

This governed record is the portable project history for this unit.
