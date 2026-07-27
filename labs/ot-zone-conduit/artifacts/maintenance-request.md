# Synthetic OT Maintenance Request — MR-LAB-042

**Lab-only fixture. It does not authorize work on any real system.**

| Field | Synthetic value |
|---|---|
| Requestor | `LAB-ONLY / OT Engineering` |
| Assets | `plc1` and `plc2`, fake process registers only |
| Window | 60 seconds after explicit enablement |
| Source | `eng-ws` (`10.110.40.20`) through `jump` |
| Change | Set and restore holding register 1 in the fake process |
| Required evidence | Jump and engineering authentication logs, firewall rule counters, PLC application event, IDS write event |
| Stop conditions | Unexpected process value, missing owner approval, clock spread over 2 seconds, or loss of HMI reads |
| Rollback | Restore the prior synthetic value; run `disable-maintenance.sh`; verify HMI/historian and deny paths |
| Approvals | Process owner: **required**; safety owner: **required for real plant work, evidence-only here** |

The network operator may prove that the route and policy are technically valid.
That does not replace process-owner authorization or a plant recovery checklist.
