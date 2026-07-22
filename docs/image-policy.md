# Third-Party Image Pinning and Vulnerability Refresh Policy

This policy applies to every new or materially rebuilt lab. It does not turn
legacy mutable references into a claim that they are pinned; those are tracked as
technical debt and must be corrected when their owning lab is next changed.

## Pin before documenting

- Every third-party registry image must use an immutable digest, or a specific
  upstream version tag when a digest cannot be recorded. `latest`, floating major
  tags, and unqualified tags are not acceptable for new work.
- A local image tag is allowed only when its Dockerfile is in this repository and
  every external `FROM` image is pinned by digest or specific version. Record the
  local build command and its external bases in the lab README and
  `docs/getting-started.md` when it is a new shared image.
- Licensed/imported images must state the exact imported version and acquisition
  prerequisite. They are not silently substituted with a different NOS.
- Pin image references in topology, Dockerfile, manifests, and documentation
  together. A tag change without a clean validation is not a completed refresh.

## Refresh and triage

- The owner reviews each maintained third-party image at least monthly and before
  a release or curriculum refresh, recording the selected version/digest and
  relevant advisories in the lab's `VALIDATION.md`.
- An actionable critical vulnerability is triaged within 7 days; high severity
  within 30 days. If a fix is unavailable or breaks the proven feature, document
  the exposure, mitigation, owner, and next review date instead of silently
  retaining a vulnerable image.
- Refreshes must run the lab's checks and the documented clean deploy/destroy
  walk before the new pin is claimed valid. Update the coverage record's live
  validation date only after that evidence exists.

## Scope and disclosure

Container images are lab dependencies, not a security certification. Do not put
credentials, customer captures, proprietary images, or unredacted vulnerability
reports in the repository. Use the
[fixture rules](https://github.com/jschless/networkingLabs/blob/main/labs/fixtures/README.md)
for evidence files and record any unavoidable unsupported behavior in the lab's
probe or validation record.
