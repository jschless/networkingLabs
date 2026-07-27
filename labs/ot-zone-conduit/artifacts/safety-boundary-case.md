# Safety-Boundary Evidence Case

This synthetic case represents an evidence discussion only. No safety controller,
fieldbus, process actuator, vendor engineering station, or hazardous process is
connected to the lab.

- The safety fixture is assigned `10.110.50.0/24` only on paper. It has no live
  topology link and no write conduit.
- A process trip is described as fail-safe and independently wired. The lab does
  not simulate, test, or certify that behavior.
- After a network repair, the operator preserves firewall, IDS, HMI, historian,
  and PLC-application timestamps before changing another layer.
- Recovery requires the process owner to confirm safe state, the safety owner to
  confirm the isolated boundary, and the network owner to prove only the intended
  conduit changed.

## Student decision

The historian is current again and the firewall counter increments. Explain why
that technically correct repair is not, by itself, authority to resume a physical
process or alter a safety zone.
