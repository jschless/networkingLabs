# Contributing

## Adding a New Lab

1. Create `labs/<name>/` with:
   - `topology.clab.yml` — ContainerLab topology
   - `README.md` — lab guide with tasks, topology diagram, and verification commands
   - `configs/<node>/frr.conf` (or `startup-config`) per node

2. Add a row to the appropriate track table in the root `README.md`

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

A good lab README includes:

- **Background**: Why this protocol/feature matters
- **Topology**: ASCII diagram or description of nodes and links
- **Pre-configured**: What's already set up (IPs, interfaces)
- **Tasks**: Numbered list of what the user needs to configure
- **Verification**: `show` commands and expected output to confirm success
- **Hints**: Commented config snippets (for practice labs)

README interaction rules:

- Practice labs keep explanations, addressing, and verification visible.
- Practice labs hide all actual node configuration commands inside `<details>` blocks.
- Use `<summary>Configuration — reveal if stuck</summary>` for practice config.
- Debug labs keep symptoms and diagnostic commands visible, but hide the exact fix in a solution `<details>` block.
- Do not expose the answer by default just because the platform changed.

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
