# BGP RPKI / Route Origin Validation Lab

This lab teaches BGP RPKI (Resource Public Key Infrastructure) and Route Origin
Validation (ROV) using FRR's built-in `rpkid` daemon and a lightweight Python
RTR server serving pre-loaded ROA data.

## Topology

```
  [isp1 AS65100]               [hijacker AS65999]
  10.0.0.10/32                 10.0.0.99/32
  eth1: 10.0.1.1/30            eth1: 10.0.2.2/30
        |                              |
        | 10.0.1.0/30     10.0.2.0/30 |
        |                              |
        +--------[  edge  ]------------+
                  AS65000
                  lo:  10.0.0.1/32
                  eth1: 10.0.1.2/30
                  eth2: 10.0.2.1/30
                  eth3: 10.0.3.1/30
                        |
                        | 10.0.3.0/30
                        |
                  [rpki-server]
                  eth1: 10.0.3.2/30
                  RTR server :3323
```

## ROA Database

The RTR server (`rpki-server`) serves these Route Origin Authorizations:

| Prefix          | Max Length | Authorized Origin AS | Purpose                     |
|-----------------|------------|----------------------|-----------------------------|
| 10.100.0.0/24   | 24         | AS65100              | isp1's legitimate prefix    |
| 10.200.0.0/24   | 24         | AS65200              | not announced → NOT-FOUND   |

**What this means in the lab:**
- `isp1` announces `10.100.0.0/24` with origin AS65100 → **VALID** (matches ROA)
- `hijacker` announces `10.100.0.0/24` with origin AS65999 → **INVALID** (wrong origin)
- `10.200.0.0/24` appears in the ROA table but nobody announces it → **NOT-FOUND** as a received route

## Key Concepts

### Route Origin Authorization (ROA)
A ROA is a cryptographically signed object created by an address space holder that
states: *"Prefix X, up to max-length Y, may be originated by AS Z."*  ROAs are
stored in the global RPKI repository and fetched by RPKI validator software.

### RTR Protocol (RFC 8210)
Routers do not speak RPKI directly. Instead, an RPKI validator (Routinator, FORT,
etc.) fetches and validates ROAs, then serves the validated prefix-origin pairs to
routers using the lightweight RTR (RPKI-to-Router) protocol over TCP port 3323.

FRR's `rpkid` daemon connects to the RTR server, downloads the ROA table, and
makes it available to `bgpd` for validation decisions.

### Route States
| State     | Meaning                                                        |
|-----------|----------------------------------------------------------------|
| valid     | A matching ROA exists; origin AS and prefix length both match  |
| invalid   | A ROA covers this prefix but the origin AS does not match, OR  |
|           | the announced prefix is longer than the ROA's maxLength        |
| notfound  | No ROA covers this prefix at all                               |

### Route Origin Validation (ROV) Policy
ROV is enforced through BGP route-maps using `match rpki valid|invalid|notfound`.
A common policy:
- **VALID** → accept, raise local-preference (prefer validated routes)
- **NOT-FOUND** → accept at normal preference (most internet prefixes today)
- **INVALID** → drop (hijack protection)

## Deploy

```bash
# Build the custom FRR image first (if not already built)
docker build -t frr-lab:local images/frr/

# Deploy the lab
sudo containerlab deploy -t labs/bgp-rpki/topology.clab.yml
```

Edge uses `sleep 5 && vtysh -b` to give the RTR server time to start before
FRR's rpkid tries to connect.

## Verification Commands

### Check the RPKI session

```
# On edge:
docker exec -it clab-bgp-rpki-edge vtysh

edge# show rpki cache-connection
edge# show rpki prefix-table
edge# show rpki as-number 65100
edge# show rpki as-number 65999
```

Expected output for `show rpki cache-connection`:
```
Connected to group 1
  Cache 10.0.3.2:3323 (connected)
    Preference: 1
```

Expected output for `show rpki prefix-table` (partial):
```
Prefix                                   Prefix Length  Origin-AS
10.100.0.0                               24 - 24        65100
10.200.0.0                               24 - 24        65200
```

### Check BGP table with RPKI states

```
edge# show bgp ipv4 unicast
```

Look for the `rpki` column in the output flags. The flags characters include:
- `V` = VALID
- `I` = INVALID
- `N` = NOTFOUND

```
edge# show bgp ipv4 unicast 10.100.0.0/24
```

This will show both paths (from isp1 and hijacker) if the INVALID path is not
being dropped. Notice the RPKI state on each.

### Verify ROV policy is working

```
edge# show bgp ipv4 unicast
```

With the default `RPKI-POLICY` route-map applied:
- Route from isp1 (10.0.1.1) for `10.100.0.0/24` should be **accepted** (VALID, LP=200)
- Route from hijacker (10.0.2.2) for `10.100.0.0/24` should be **absent** (INVALID, denied by seq 30)

```
edge# show bgp neighbors 10.0.1.1 received-routes
edge# show bgp neighbors 10.0.2.2 received-routes
```

Both neighbors will show the route as *received*, but only isp1's survives the
inbound route-map.

## Tasks

### Task 1 — Verify the RPKI session

Open a vtysh session on `edge` and confirm the RTR connection is up:

```
edge# show rpki cache-connection
edge# show rpki prefix-table
```

**Questions:**
- How many ROA entries are in the prefix table?
- What does `show rpki as-number 65100` tell you?

---

### Task 2 — Observe RPKI states on received routes

Check the BGP table:

```
edge# show bgp ipv4 unicast
edge# show bgp ipv4 unicast 10.100.0.0/24
```

**Questions:**
- What RPKI state is shown for the route received from isp1?
- Is the hijacker's route present? Why or why not?

---

### Task 3 — Temporarily disable INVALID drop to see both routes

Edit the route-map on edge to comment out the deny clause for INVALID routes.
Change sequence 30 from `deny` to `permit`:

```
edge# conf t
edge(config)# route-map RPKI-POLICY permit 30
edge(config-route-map)# match rpki invalid
edge(config-route-map)# end
```

Then soft-clear BGP to re-evaluate:

```
edge# clear bgp * soft in
edge# show bgp ipv4 unicast 10.100.0.0/24
```

You should now see **two paths** for `10.100.0.0/24`. Observe:
- The `rpki` state column on each path
- The local-preference values (200 for VALID from isp1, 100 for INVALID from hijacker)
- Which path is selected as best (BGP uses LP in best-path selection)

Even without the explicit deny, the VALID route wins on local-preference.

Restore the deny:

```
edge# conf t
edge(config)# route-map RPKI-POLICY deny 30
edge(config-route-map)# match rpki invalid
edge(config-route-map)# end
edge# clear bgp * soft in
```

---

### Task 4 — Simulate equal local-preference (VALID still wins)

This task shows that when LP is equal, BGP treats VALID > NOTFOUND > INVALID
in the best-path selection (FRR respects `bgp bestpath prefix-validate allow-invalid`
to change this behavior).

First, temporarily remove the LP manipulation:

```
edge# conf t
edge(config)# route-map RPKI-POLICY permit 10
edge(config-route-map)# match rpki valid
edge(config-route-map)# no set local-preference 200
edge(config-route-map)# exit
edge(config)# route-map RPKI-POLICY permit 30
edge(config-route-map)# match rpki invalid
edge(config-route-map)# end
edge# clear bgp * soft in
edge# show bgp ipv4 unicast 10.100.0.0/24
```

**Observation:** Without the explicit LP difference, which path does FRR select?
Does RPKI state influence the tie-break?

Restore after exploring:

```
edge# conf t
edge(config)# route-map RPKI-POLICY permit 10
edge(config-route-map)# match rpki valid
edge(config-route-map)# set local-preference 200
edge(config-route-map)# exit
edge(config)# route-map RPKI-POLICY deny 30
edge(config-route-map)# match rpki invalid
edge(config-route-map)# end
edge# clear bgp * soft in
```

---

### Task 5 — NOT-FOUND behavior

Add a new announcement from isp1 for a prefix that has *no* ROA:

On `isp1`:

```
docker exec -it clab-bgp-rpki-isp1 vtysh

isp1# conf t
isp1(config)# ip route 10.50.0.0/24 Null0
isp1(config)# router bgp 65100
isp1(config-router)# address-family ipv4 unicast
isp1(config-router-af)# network 10.50.0.0/24
isp1(config-router-af)# end
```

On `edge`:

```
edge# show bgp ipv4 unicast 10.50.0.0/24
```

**Questions:**
- What is the RPKI state of `10.50.0.0/24`?
- Is it accepted or rejected by the route-map?
- Why does the current policy accept NOT-FOUND routes?
- In a strict ROV deployment, should NOT-FOUND routes be accepted?

---

### Task 6 — Strict ROV (drop NOT-FOUND)

Modify the policy to only accept VALID routes (strict mode):

```
edge# conf t
edge(config)# route-map RPKI-POLICY deny 20
edge(config-route-map)# match rpki notfound
edge(config-route-map)# end
edge# clear bgp * soft in
edge# show bgp ipv4 unicast
```

**Questions:**
- What prefixes remain in the BGP table?
- What is the practical drawback of strict ROV today (2024)?
  (Hint: what fraction of internet prefixes have ROAs?)

Restore permissive NOT-FOUND policy when done:

```
edge# conf t
edge(config)# route-map RPKI-POLICY permit 20
edge(config-route-map)# match rpki notfound
edge(config-route-map)# set local-preference 100
edge(config-route-map)# end
edge# clear bgp * soft in
```

---

## Reference: FRR RPKI Commands

| Command                                    | What it shows                               |
|--------------------------------------------|---------------------------------------------|
| `show rpki cache-connection`               | RTR server connection status                |
| `show rpki prefix-table`                   | All ROA entries downloaded from RTR server  |
| `show rpki as-number <ASN>`                | ROAs for a specific origin AS               |
| `show bgp ipv4 unicast`                    | BGP table with RPKI state flags             |
| `show bgp ipv4 unicast <prefix>`           | Detailed path info including rpki state     |
| `show bgp neighbors <ip> received-routes`  | Routes received before policy               |
| `clear bgp * soft in`                      | Re-evaluate inbound policies (soft reset)   |
| `rpki reset`                               | Reconnect to RTR server                     |
| `debug rpki`                               | Enable RPKI debug logging                   |

## Cleanup

```bash
sudo containerlab destroy -t labs/bgp-rpki/topology.clab.yml --cleanup
```
