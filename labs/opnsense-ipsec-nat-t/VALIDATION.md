# opnsense-ipsec-nat-t validation record

This record separates the native design probe, implementation-worker static
checks, and main-orchestrator acceptance.

## External base provenance — 2026-09-01

- Base path: `/var/lib/containerlab/opnsense/opnsense-base.qcow2`
- SHA-256: `ba0c15261917e34d002c75c1ecd4e3c200420f78fe30d34cf34299158000f444`
- Guest: OPNsense 26.1, FreeBSD 14.3-RELEASE-p10, amd64
- qcow2 virtual size: 3,221,225,472 bytes
- Observed host allocation: 2,347,438,080 bytes
- qcow2 compatibility: 1.1; dirty flag: false
- `qemu-img check` completed successfully before the probe.

The disk is an external local prerequisite, not a repository artifact. These
values identify the image used for this validation; they do not make arbitrary
OPNsense releases equivalent.

## Native design probe — 2026-09-01

The main orchestrator used clean disposable overlays and supported OPNsense
26.1 surfaces: `OPNsense\Core\Config`, `OPNsense\Routing\Gateways`,
`OPNsense\IPsec\Swanctl`, `OPNsense\IPsec\IPsec`, and
`OPNsense\Firewall\Filter`. The probe established the required application
order: save base models, reconfigure `opt1`/`opt2` and routes, reload the
IPsec template and service, register dynamic `enc0`, save its MVC firewall
rule, and reload PF.

Observed native evidence:

- Both peers reached one IKEv2 SA in `ESTABLISHED` state on UDP/4500.
- HQ reported remote NAT; Branch reported local NAT; both reported NAT and
  CHILD encapsulation.
- IKE used AES-CBC-256, HMAC-SHA2-256-128, PRF-HMAC-SHA2-256, and MODP-2048.
- The installed tunnel-mode ESP CHILD used AES-CBC-256 and
  HMAC-SHA2-256-128 with exact opposite `/24` selectors.
- Bidirectional protected-host pings succeeded through active `enc0` PF
  policy.
- A bounded public capture showed bidirectional
  `198.51.100.2:4500` ↔ `198.51.100.1:4500` ESP-in-UDP and no readable
  protected addresses.
- Exact UDP/4500 forwarding drops at `nat-cpe` stopped protected traffic while
  Branch still reached HQ's public address and the SAs initially remained
  established. Removing the drops restored traffic.

This probe established mechanism and automation feasibility. It does not
replace the clean acceptance cycle against the committed scripts.

## Implementation-worker static checks — 2026-09-01

The implementation worker did not deploy, destroy, or alter the
orchestrator-owned live topology. The following read-only gates passed after
the final implementation edits:

- Bash syntax for all 14 target shell scripts;
- ShellCheck at warning severity for all 14 target shell scripts;
- repository Markdown block spacing;
- repository lab lint: 142 labs and 53 distinct images;
- target topology YAML parse, name, image, and seven-node inventory;
- `git diff --check`.

PHP CLI was not installed on the Linux host, so host-side `php -l` was not
available. Main acceptance subsequently parsed all three PHP files on genuine
OPNsense before exercising them.

## Main acceptance — 2026-09-02

One clean deployment was used for answer-free baseline and acceptance. The
baseline passed all 12 incidental/readiness checks and failed all 51 intended
OPNsense configuration/live checks. No learner answer was applied before that
measurement.

Acceptance results:

- `solution.sh` converged to exactly 63 passes and zero failures. Its repeat
  invocation also produced 63/0 with the same deterministic model inventory.
- An injected extra saved connection produced exactly one failure, the HQ saved
  IKE connection inventory check. A same-identity wrong PSK produced exactly
  one failure, the HQ saved PSK identity/digest check. Solution restored 63/0
  after each mutation.
- `capture.sh` accepted exactly four bidirectional public UDP/4500 ESP-in-UDP
  packets. It exposed neither protected subnet and left no capture file or
  `tcpdump` process. A forced INT returned 130 and left the same clean state.
- `break.sh` produced exactly 60 passes and three failures: its two protected
  pings and the exact NAT-boundary fault check. Both public underlay reachability
  and the peer SAs remained available. A repeat invocation retained exactly
  two fault rules; `repair.sh` restored 63/0 and was idempotent.
- A direct TERM during the test-only post-mutation hold returned 143, removed
  both rules, restored 63/0, and completed in 14 seconds. The tracked hold child
  was added after an earlier artificial single-PID harness demonstrated that a
  foreground external `sleep` could defer Bash trap delivery.
- Forced TERM, INT, and ERR paths through `solution.sh` returned 143, 130, and
  1 respectively. Each restored byte-identical HQ and Branch pre-run
  configuration files and removed temporary backups. After tracking its test
  hold child explicitly, a direct single-PID TERM also completed rollback in
  seven seconds and returned 143.
- Remote `php -l` accepted `configure.php`, `grade-config.php`, and
  `grade-live.php` on OPNsense. This acceptance also caught and corrected an
  OPNsense version-pattern mismatch, POSIX snippets initially executed by the
  guest's root `csh`, and non-deterministic SimpleXML deletion while iterating.
  The final scripts and repeated solution were re-exercised after those fixes.
  After review, the native MVC and live PF policy were tightened and proven as
  exactly one inbound `enc0` rule from the role's remote protected `/24` to its
  local protected `/24`; exact checking remained 63/0.

During simultaneous high-rate protected pings, three samples observed maximum
resident memory of 1,960,100 KiB for HQ QEMU and 1,958,236 KiB for Branch QEMU.
Container maxima were 3.105 MiB (`hq-host`), 0.900 MiB (`branch-host`), and
1.410 MiB (`nat-cpe`), for an approximate aggregate of 3.742 GiB. Every
container reported zero restarts and no OOM kill. The incidental image reported
Linux/amd64; the host and both OPNsense guests were x86-64/amd64. Each VM is
configured for 3,072 MiB, so the README explicitly tells learners to run this
lab alone.

Repository-wide gates passed after the acceptance fixes: target Bash syntax,
ShellCheck warning severity, Markdown spacing, docs admonitions, lab lint (142
labs and 53 images), quiz validator positive/negative regression fixtures, all
44 quiz pairs, enterprise-coverage positive/negative fixtures, all 29
enterprise-coverage checks, `mkdocs build --strict`, and `git diff --check`.
The Material theme emitted its upstream MkDocs 2.0 advisory; the strict build
itself succeeded. One initial quiz-regression invocation used Bash on a Python
file; rerunning it with Python passed and exposed no product defect.

## Independent review and clean teardown — 2026-09-02

One read-only reviewer examined the full implementation, documentation,
security posture, checker boundaries, and lifecycle behavior. Its initial six
findings covered transaction finalization, reproducible prerequisites, stop
residue reporting, decrypted-policy scope, catalog metadata, and one reversed
negative-test sentence. The same reviewer performed both focused follow-ups.
After the fixes and live revalidation, it approved with no remaining actionable
findings. No tutor validation is claimed.

The main orchestrator then stopped both QEMU guests, removed their overlays and
runtime metadata, destroyed all three ContainerLab nodes, removed the four
exact bridges, and removed its temporary privileged validation helper. The
post-destroy audit found zero target containers, QEMU processes, taps, bridges,
listeners on ports 2301/2302/4301/4302/8544/8545, runtime directories, capture
files, generated ContainerLab directory, or validation helper. The external
base image was preserved as intended.

## Limitations

- The probe covered one x86-64 OPNsense 26.1 base image on KVM. Other releases,
  architectures, and hypervisors were not tested.
- PSK authentication, one tunnel-mode CHILD, fixed selectors, and static
  underlay routing were tested. Certificates, HA, dynamic routing, scale,
  performance, rekey endurance, adverse WANs, and hardware offload were not.
- Loopback-bound root/`opnsense` management and serial telnet are disposable
  local training conveniences, not production security controls.
- The requested `lab-tutor` validation surface was unavailable in the parent
  remediation workflow; no tutor validation is claimed.
