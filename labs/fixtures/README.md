# Fixture Rules

`labs/fixtures/` holds evidence used by labs when a mechanism cannot be honestly
run in ContainerLab (for example RF survey data, optical evidence, or hardware
fabric telemetry). A fixture is evidence, not a substitute for a live feature.

Every fixture directory must include a `MANIFEST.md` or `manifest.yaml` with:

1. **Provenance** — who created it, source system/type, capture date, and why it
   can be redistributed. Never include customer, production, or credential data.
2. **License** — the license/permission for every source file and attribution
   required for reuse.
3. **Capture method** — tools, versions, filters, topology/context, and any
   transformations used to obtain the artifact.
4. **Anonymization** — fields removed or replaced, residual-risk assessment, and
   confirmation that names, addresses, identifiers, secrets, and payloads are safe.
5. **Synthetic labeling** — prominently label generated, reduced, or simulated
   evidence. Do not describe synthetic counters or screenshots as hardware output.
6. **Expected deductions** — the observation a student should be able to make,
   alternative explanations, and the limits of the evidence.
7. **Checksums** — SHA-256 for every distributable binary, capture, image, CSV,
   or archive, plus the command used to calculate them.

Keep fixtures minimal, text-friendly where practical, and free of access tokens,
private keys, packet payloads, or personal data. A lab README must identify the
fixture as evidence-only and must not raise its coverage level beyond level 1
unless a separate live, checked mechanism supplies the higher-level evidence.
