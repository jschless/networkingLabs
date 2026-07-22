# Contributing

## Adding a New Lab

1. Create `labs/<name>/` with:
   - `topology.clab.yml` — ContainerLab topology
   - `README.md` — lab guide written to the [authoring contract](https://github.com/jschless/networkingLabs/blob/main/labs/AUTHORING.md)
   - `configs/<node>/frr.conf` (or `startup-config`) per node
   - `check.sh` — automated assertions runnable via `./scripts/lab.sh check <name>`
     (source `scripts/check-lib.sh`; see any existing lab for the pattern)

2. Add a row to the track's table in `docs/tracks/<track>/index.md`, and update the
   track card count in `docs/index.md`

3. Add a thin wrapper page in `docs/tracks/<track>/<name>.md`:
   ```markdown
   ---
   title: <lab-name>
   ---

   !!! tip "Practice Lab"
       One-line description of what this lab teaches.

   !!! note "Image"
       `frr-lab:local` — `docker build -t frr-lab:local images/frr/`

   \{%
     include-markdown "../../../../labs/<lab-name>/README.md"
   %\}
   ```

4. Add the nav entry to `mkdocs.yml` under the appropriate track

## Lab README Requirements

The authoring contract lives in
[`labs/AUTHORING.md`](https://github.com/jschless/networkingLabs/blob/main/labs/AUTHORING.md)
— it is the single source of truth for README structure, task anatomy
(Objective → Predict → Hints → Solution → Check), difficulty-band ratios, and the
accuracy promise (every solution validated against a live deploy). Read it before
writing or converting a lab; don't work from an existing lab's README alone, since
older labs may predate the contract.

Two rules worth repeating here:

- Never expose a solution outside a collapsed `<details markdown="1">` block, and never make the
  solution toggle the *only* content of a task.
- Optional follow-on ideas belong in an `## Extensions` section, clearly labeled as
  unvalidated.

If the lab introduces a new image, add it to the table in
[getting-started](getting-started.md) and reference the build command in the lab README
and its wrapper page.

## Image pinning and validation records

New or materially rebuilt labs must follow the
[third-party image pinning and vulnerability-refresh policy](image-policy.md).
Copy the standard [probe](https://github.com/jschless/networkingLabs/blob/main/labs/templates/PROBE.md)
and [validation](https://github.com/jschless/networkingLabs/blob/main/labs/templates/VALIDATION.md)
records into the lab, then keep the exact versions, commands, output summary,
resource figures, and cleanup result. For evidence files, follow the
[fixture rules](https://github.com/jschless/networkingLabs/blob/main/labs/fixtures/README.md).

## Platform Validation Before Rebuild

Before migrating a lab from FRR to a router image:

1. Identify the exact behaviors the lab needs, not just the protocol name.
2. Spin up the target image locally in a minimal probe topology.
3. Validate the feature on the running image:
   - single-node CLI acceptance for pure syntax/control-plane features
   - multi-node validation for adjacency or signaling features such as DMVPN, EVPN, LDP pseudowires, or 6PE
4. Only rebuild the lab after the live probe passes.

If the local image lacks the feature or only supports part of it, keep the lab on FRR and document that choice.

## Debug Lab Pattern

Debug labs always have:
- One intentional bug in exactly one file (`frr.conf` or `startup-config`)
- README sections: Scenario → Symptoms → Hint 1 → Hint 2 → Hint 3 → Solution

## Building the Docs Locally

```bash
pip install -r requirements-docs.txt
mkdocs serve
# open http://127.0.0.1:8000
```

## Checking for Build Errors

```bash
mkdocs build --strict
```

This fails on broken links, missing include files, or YAML errors in `mkdocs.yml`.

CI also runs three linters on every push and PR — run them locally before pushing:

```bash
./scripts/check-docs-admonitions.sh   # malformed !!! admonitions
python3 scripts/lint-labs.py          # topology parse, image docs, nav consistency
shellcheck -S warning scripts/*.sh labs/*/check.sh enterprise-it-101/eit.sh
```

`lint-labs.py` fails if a lab's topology doesn't parse, references an image missing
from [getting-started](getting-started.md), lacks a README, is absent from the
`mkdocs.yml` nav, or if a track card count on the docs home page drifts from the nav.
