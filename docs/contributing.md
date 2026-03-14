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
