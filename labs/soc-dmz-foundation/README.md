# soc-dmz-foundation — DMZ Visibility Foundation

Build the shared DMZ/SOC topology used by the Security Infrastructure track. The lab focuses on routed segmentation, high-value DMZ services, and a mirror feed into a sensor.


## How to use this lab

This is a **practice analysis lab**. The environment and evidence are
pre-built; your job is to *investigate*, not to follow a script. For each
task, **form a hypothesis about what the logs/PCAP will show before you
query them**, then run the filter and compare. The challenge questions push
you from "find the indicator" to "explain and respond."
## Topology

```mermaid
flowchart LR
    attacker(["attacker<br/>10.10.10.10"])
    fw["router-fw<br/>10.10.10.1<br/>172.16.10.1<br/>172.16.20.1"]
    web(["dmz-web<br/>172.16.10.10<br/>HTTP + SSH"])
    api(["dmz-api<br/>172.16.20.10<br/>HTTP 8080"])
    sensor(["sensor<br/>mirror eth1"])

    attacker --- fw
    fw --- web
    fw --- api
    fw -. "tc mirror" .- sensor
```

## Build And Deploy

```bash
docker build -t soc-endpoint:local images/soc-endpoint/
docker build -t soc-sensor:local images/soc-sensor/
docker build -t soc-attacker:local images/soc-attacker/

./scripts/lab.sh deploy soc-dmz-foundation
./scripts/lab.sh check soc-dmz-foundation
```

## What Is Prebuilt

- `attacker` can route to both DMZ hosts through `router-fw`.
- `dmz-web` serves HTTP on `172.16.10.10:80` and SSH on TCP 22.
- `dmz-api` serves HTTP on `172.16.20.10:8080`.
- `router-fw` mirrors ingress traffic from attacker and DMZ interfaces to `sensor:eth1`.
- `sensor` has deterministic SOC artifacts under `/var/log/zeek`, `/var/log/suricata`, `/var/log/yara`, and `/var/log/soc`.

## Workflow

Generate baseline traffic:

```bash
./scripts/lab.sh cmd soc-dmz-foundation attacker -- /opt/soc-lab/run-attack-sequence.sh
```

Watch mirrored frames:

```bash
./scripts/lab.sh cmd soc-dmz-foundation sensor -- tcpdump -ni eth1 -c 20
```

Verify service reachability:

```bash
./scripts/lab.sh cmd soc-dmz-foundation attacker -- curl -s http://172.16.10.10/
./scripts/lab.sh cmd soc-dmz-foundation attacker -- curl -s http://172.16.20.10:8080/
```

## Outcome

You have a repeatable DMZ topology with a working sensor mirror. Later labs reuse the same design and add Zeek, Suricata, YARA, SIEM, packet search, threat intel, and case workflow layers.

## Challenge questions

No answers provided — reason them through.

1. The sensor sees a *mirror* of traffic, not inline. What can a mirror-fed sensor detect that an inline device can't easily, and what can it never *prevent*? Why does that shape where you place each.
2. Distinguish a true positive from a false positive in this lab's data, and
   state the *one* corroborating source you'd pull to raise confidence.
3. From detection to response: given a confirmed finding here, what's the
   minimal containment action, and what evidence must you preserve first?
4. What single additional log source or visibility gap, if added, would have
   made this investigation faster — and why isn't it free?
