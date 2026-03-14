# Enterprise Edge NAT and Firewall Lab

This lab teaches enterprise internet-edge policy using a small but realistic topology:

- PAT for inside users
- static NAT for DMZ publishing
- corp vs guest policy separation
- inside/outside trust boundaries
- logging and troubleshooting with `nftables`

## Build

```bash
docker build -t dmz-lab:local labs/enterprise-edge-nat-firewall/
sudo containerlab deploy -t labs/enterprise-edge-nat-firewall/topology.clab.yml
```

## Roles

- `internet-client`: simulated outside user
- `fw-outside`: perimeter firewall and NAT edge
- `fw-inside`: inside segmentation firewall
- `web-server`: DMZ web service to be published
- `mail-server`: second DMZ service
- `db-server`: inside application tier
- `workstation`: corporate inside user
- `guest-laptop`: guest user that should get internet, but not corp access

## What Is Prebuilt

- addressing and default routing
- the screened-subnet physical topology
- service nodes with basic IP reachability

## What You Configure

On the firewall nodes:

- PAT for `workstation` and `guest-laptop`
- static NAT for `web-server`
- internet -> DMZ web permit only
- guest -> internet permit, guest -> corp deny
- corp -> internet permit
- DMZ -> database allow only for the app flow you choose
- logging for denied and published traffic

## Suggested Exercises

### 1. Publish the Web Server

Make `internet-client` reach the DMZ web service through a static NAT on the perimeter.

### 2. Add PAT for Corp and Guest

Let `workstation` and `guest-laptop` reach the internet through source NAT.

### 3. Enforce Guest Isolation

Allow guest internet access but block guest access to:

- `db-server`
- `workstation`
- DMZ management paths

### 4. Inspect Counters and Logs

Use:

```bash
docker exec clab-enterprise-edge-nat-firewall-fw-outside nft list ruleset
docker exec clab-enterprise-edge-nat-firewall-fw-inside nft list ruleset
```

to explain exactly why a flow is allowed or denied.

## Verification

From outside:

```bash
docker exec clab-enterprise-edge-nat-firewall-internet-client curl -I http://203.0.114.2
```

From corp and guest:

```bash
docker exec clab-enterprise-edge-nat-firewall-workstation ping -c 3 203.0.113.1
docker exec clab-enterprise-edge-nat-firewall-guest-laptop ping -c 3 203.0.113.1
```

Then verify guest cannot reach corp/internal services.

## What This Lab Teaches

- NAT is separate from security policy
- “inside can get out” and “outside can reach published service” are different design problems
- guest policy is best enforced explicitly, not assumed
