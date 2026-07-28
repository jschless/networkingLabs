# Sanitized sample attempt evidence

These text artifacts are reduced from the clean 2026-07-28 live validation of
cEOS 4.35.2F. They show the fields students should expect without preserving a
lab credential, HTTP authorization header, generated flash filename, container
identifier, or outer-repository path.

- `successful-idempotent.json` proves an independently verified zero-change run.
- `partial-push.json` proves leaf1 committed, leaf2 rejected the stale
  capability command, edge1 was stopped, and only leaf1 was rolled back.
- `postcheck-rollback.json` proves a three-device candidate was restored in
  reverse order after a forced post-check failure.
- `semantic-diff.json` is the normalized baseline-to-v2 review artifact.

Live attempts contain candidates, state, pre/post results, timestamps, snapshot
names, and NDJSON audit events under the automation container's disposable
`/workspace/lab-repo/evidence/` directory.
