# Feature Probe Record — `private-5g-enterprise`

## Scope and decision

- **Feature and learning objective:** prove a real Open5GS 5G core can establish
  a UERANSIM gNB NGAP association, register a UE, establish a PDU session and
  carry traffic through a UPF before authoring the Lab A topology.
- **Decision:** **blocked** — do not implement or advertise the Lab A user-plane
  lab from this probe.
- **Reason and fidelity statement:** the host can create a TUN device, run SCTP,
  form NGAP and PFCP associations, and complete UE registration.  The disposable
  `2.7.0` core did not establish a PDU session: a hand-built subscriber first
  lacked mandatory UE-AMBR/access data, then an SMF/PCF policy response rejected
  the session.  The upstream-compatible `2.7.5` reference composition was still
  pulling/starting when this probe window ended and was destroyed before it could
  provide a clean PDU-session result.  The required load-bearing claim (PDU TUN,
  UE address and enterprise ping) is therefore unproven.  No HTTP/mock fallback
  is authorized by WP-05.
- **Owner and date:** Codex, 2026-07-23

## Environment

| Item | Exact value |
|---|---|
| Host OS/kernel | Linux `5.15.0-181-generic` |
| ContainerLab | `0.74.1`, commit `1866b3a2b` |
| Docker | `29.5.3` |
| Probe core image | `gradiant/open5gs:2.7.0`, digest `sha256:b2ce2bc3f2b033c64621d131ace37d6e6dd8f154f1bd9bce2cbd2e7efef57986` |
| Probe RAN image | `gradiant/ueransim:3.2.6`, digest `sha256:015b30d5fa0f9fa847cfa254ba48a336195c2a77a25122cea71114d8b09265ab` |
| Database image | `mongo:7.0.14`, digest `sha256:0032d2ca20db5fa34926f196c8a43b74e34ed239a7f2453ff1505b6f12ba8ea6` |
| Upstream cross-check | Gradiant `5g-images` shallow clone, upstream `gradiant/open5gs:2.7.5` compose reference |
| Host before probe | 15 GiB total / 11 GiB available memory; 149 GiB free filesystem |

## Smallest load-bearing test

The disposable Docker network contained MongoDB; NRF/SCP/AUSF/UDM/UDR/PCF/PCRF;
AMF and SMF; a privileged UPF; one UERANSIM gNB; and one UERANSIM UE.  The UPF
was intentionally privileged because the image entrypoint must create `ogstun`
and enable forwarding.  This was a host-capability probe, not lab content.

```text
docker pull gradiant/open5gs:2.7.0
docker pull gradiant/ueransim:3.2.6
docker network create clab-private5g-probe
# start Open5GS functions with Docker aliases nrf, scp, amf, smf, upf and mongo
# start the UPF with --privileged
# insert disposable IMSI 999700000000001 into MongoDB
# start gNB and UE with MCC/MNC 999/70, TAC 1 and SST/SD 1/000001
docker logs probe5g-gnb
docker logs probe5g-ue
docker exec probe5g-upf ip -br addr
```

Observed positive output:

```text
gNB: SCTP connection established (...:38412)
gNB: NG Setup procedure is successful
UE:  Initial Registration is successful
SMF: PFCP associated (...:8805)
UPF: ogstun UP 10.45.0.1/16
```

Observed failure after registration:

```text
UE:  PDU Session Establishment Reject received [OUT_OF_LADN_SERVICE_AREA]
SMF: HTTP response error [400]
```

An earlier, deliberately minimal subscriber document failed with `No UE-AMBR`
and `No AccessAndMobilitySubscriptionData`; after adding those fields registration
succeeded, but the PDU session still failed.  The upstream `5g-images` compose
reference confirms that its SMF omits freeDiameter and uses the image's `DB_URI`
handling; it was fetched as a follow-up compatibility check, not substituted as
evidence of success.

Measured steady memory immediately before the failed PDU flow was approximately
174 MiB total across the 12 probe containers (MongoDB 71 MiB, SMF 31 MiB, AMF
19 MiB, UPF 18 MiB, remaining functions/UE/gNB about 35 MiB).  The image pulls
took 7.08 s (Open5GS) and 8.09 s (UERANSIM); the core was given 30 s readiness
before UE launch.  The upstream reference image pull was incomplete in the
available probe window, so no deploy or peak-memory claim is recorded for it.

## Cleanup and repeatability

- **Cleanup commands:** exact `docker rm -f probe5g-*`; `docker network rm
  clab-private5g-probe`; and `docker compose -p private5gupstream ... down -v
  --remove-orphans` for the upstream cross-check only.
- **Artifacts checked:** probe containers, the probe Docker network, compose
  project containers/networks/volumes, and `ogstun`/UERANSIM TUN links.
- **Result:** no `probe5g` or `private5gupstream` containers/networks and no
  probe TUN links remained after cleanup.

## Unsupported behavior and fallback

The host capability is not the blocker; the unproven behavior is a clean,
repeatable PDU session and user-plane data path on the selected image/configuration
set.  WP-05 permits stopping when the core probe cannot safely prove SCTP/TUN/PDU
behavior and explicitly forbids replacing the core with HTTP mocks.  No fallback
or rename is taken.  A future implementation must first complete the upstream
`2.7.5` compatibility walk (or another pinned, fully proven Open5GS/UERANSIM
release set), then re-run this probe including UE TUN address, app ping, decodable
NGAP/PFCP/GTP-U capture, and a clean second cycle.
