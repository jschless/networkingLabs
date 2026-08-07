# Network Automation with NetBox — Validation Record

## Status

Independent live validation of the remediated implementation completed on
2026-08-05. The required reviewer loop follows this record; no `lab-tutor`
validation is claimed.

## Required live cases

| Case | Required evidence | Result |
|------|-------------------|--------|
| Cold bootstrap | Bounded authenticated readiness; underlay healthy; service withheld | Pass — authenticated NetBox 4.1.11 became ready inside the 360-second bound; every node had two established eBGP peers and loopback reachability; BLUE was absent |
| Idempotent model | Baseline seed twice; service import twice; exact counts | Pass — baseline remained 4 devices, 16 interfaces, 16 addresses, 4 cables, 6 prefixes, 0 VRFs/VLANs; complete remained 4/20/18/4/7/1/1 |
| Healthy render | Four native device-specific files; stable hashes; no secrets | Pass — two renders produced identical SHA-256 values for all four `0644` candidates; bootstrap credential/API scan was empty |
| Graph failure | Cable deletion and bad `/31` endpoint both fail before render; old hashes preserved | Pass — missing cable named both uncabled endpoints; `10.0.0.9/31` named the exact address and cable subnet; both exited 2 and preserved hashes |
| Deployment | First BLUE apply succeeds; second check/apply changes zero nodes | Pass — first apply converged all four devices; the following precheck and apply each reported `changed=0` four times |
| Ownership | Serial adoption only; dirty `leaf1 Ethernet3` description remains intent drift | Pass — four serials adopted; discovery preserved intent; the dirty report contained only `[INTENT_DESCRIPTION_DRIFT]` |
| Reconciliation | NetBox-wins deploy restores description; fresh drift is clean | Pass — only leaf1 changed during restore; fresh resource-parsed facts produced `CLEAN` |
| Fault contract | Break twice changes only one NetBox assignment; live fabric/candidates healthy | Pass — both runs were idempotent; leaf1 retained two established peers and candidate hashes were unchanged |
| Repair contract | Solution twice restores only the assignment and recovered candidates | Pass — both runs succeeded and complete model/render integrity recovered |
| Checker | Solved passes; broken fails only graph/address/render-readiness assertions; temps cleaned | Pass — solved `62 passed, 0 failed`; broken `58 passed, 4 failed`; repaired `62 passed, 0 failed`; cleanup assertion passed |
| Resources/cleanup | Aggregate below 16 GiB; scoped destroy leaves no residual deployment | Pass — peak snapshot was about 5.6 GiB; scoped destroy removed all eight containers, the lab network, and ignored learner/generated/fact artifacts |

## Reviewer-fix revalidation

- The full solved checker passed after the reviewer fixes: `62 passed, 0 failed`.
- One combined NetBox tamper changed the `leaf1` role, `leaf2` platform,
  config-template body, and one cable status. The audit reported the exact
  role/platform/template failures under `core` and the status failure under
  `cables`; `render_from_netbox.py --validate-only` exited 2, and all four
  candidate hashes remained unchanged.
- Two baseline seed runs restored the exact modeled role, platform, template,
  and connected cable status. The complete audit and validate-only render then
  passed again.
- NetBox was observed removing the source template's single terminal newline.
  That terminal CR/LF normalization is the only accepted normalization;
  substantive content and internal whitespace remain exact.
- Final scoped cleanup again removed all eight containers, the lab network,
  and runtime artifacts.

## Known validation limitation

The required `lab-tutor` skill is unavailable. The remediation follows
`labs/AUTHORING.md`, and no tutor validation will be claimed.
