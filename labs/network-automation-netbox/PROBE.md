# Network Automation with NetBox — Platform Probe

## Scope

This is the main-agent platform/design probe that preceded remediation. It
records observed behavior, including defects in the old implementation; it is
not a claim that the remediated workflow has passed final validation.

## Platform evidence

- ContainerLab: `0.74.1`.
- Four cEOS nodes reported engineering build
  `4.35.2F-46221466.4352F`, build ID
  `6f39e5bb-e6c7-4637-b931-ecb30d43e034`, from local image ID beginning
  `sha256:f27a`.
- All four raw authenticated eAPI hostname requests returned HTTP 200.
- Every fabric node had exactly two established eBGP peers, redundant BGP
  loopback paths, and working privileged loopback pings.
- Native VRF, VLAN, SVI, access-interface, BGP, and eAPI syntax was accepted.
- Authenticated `/api/status/` reported NetBox `4.1.11`. Anonymous status
  returned 403. Cold first initialization was roughly 3.5 minutes, motivating
  bounded authenticated polling rather than a fixed sleep.

## Relationship and rendering evidence

- The old seed was repeatable at four devices, 24 interfaces, 20 IPs, four
  cables, two VRFs, two VLANs, and one template/context. The remediated baseline
  intentionally separates the BLUE learner service, so its exact counts differ.
- Deleting one old cable changed its count from four to three, yet old candidate
  hashes remained identical; reseeding restored four cables.
- Changing old `leaf1:Ethernet1` intent from `10.0.0.1/31` to
  `10.0.0.9/31` made the old renderer exit zero, omit the interface/neighbor,
  and overwrite candidates. The assignment was restored after the probe.
- Rendering plaintext EOS username configuration produced a new salted hash on
  every run. Removing that line yielded Ansible check mode with zero changes on
  all four nodes. The remediated template therefore excludes credentials and
  management API bootstrap.

## Automation and fact-shape evidence

- Existing fact gathering/deployment worked with bundled `arista.eos 12.0.1`
  and `ansible.netcommon 8.4.0`.
- EOS interface facts used `operstatus: connected`; serial was populated; each
  interface dictionary exposed description, MTU, MAC address, and IPv4
  address/mask length.
- This shape supports serial adoption and intent-owned description/MTU/address
  comparisons without allowing discovery to overwrite those fields.

## Reproducibility and resources

- NetBox image:
  `netboxcommunity/netbox:v4.1.11@sha256:d1260201d775b3f1d0b19e425bd19facc1e907e7153a8247d04d996037969e53`.
- Postgres image:
  `postgres:15@sha256:f30e3de0ac9cc938dac627ef2231099867c694b5f949fadb924c8c977428c399`.
- Redis image:
  `redis:7-alpine@sha256:8b81dd37ff027bec4e516d41acfbe9fe2460070dc6d4a4570a2ac5b9d59df065`.
- Point sample: leaf1 1.256 GiB, leaf2 1.258 GiB, spine1 1.254 GiB,
  spine2 1.252 GiB, NetBox 726 MiB, Postgres 120.5 MiB, controller
  39.86 MiB, Redis 4.824 MiB; aggregate approximately 5.9 GiB.
- One scoped deployment was destroyed cleanly. Root-owned probe artifacts were
  removed with a scoped one-shot container.

The required `lab-tutor` skill was unavailable. No tutor validation is claimed.
