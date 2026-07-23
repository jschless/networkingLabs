# Wireless Core Operations Evidence Manifest

## Provenance and license

Created by the WP-02 lab author on 2026-07-23 for this repository. These are
small, **synthetic evidence** records under CC0-1.0, created solely to teach
how to distinguish an RF hypothesis from an authentication failure. They are
not customer, production, or hardware captures.

## Capture method and anonymization

The rows were hand-authored from the documented case conditions; no radio,
packet payload, device identifier, credential, person, or customer address was
captured. `events.log` mirrors event *categories* observable in this lab's
EAP/RADIUS logs, not a physical AP log. The absence of hardware measurements is
intentional and is the residual limitation.

## Expected deductions and limits

- A strong signal plus high channel utilization supports an airtime/CCI
  hypothesis, not an EAP failure conclusion.
- Reassociation before EAP begins can be coverage/driver related, but this pack
  cannot distinguish those alternatives conclusively.
- A visible network and an untrusted-server certificate isolate the fault to
  authentication trust, not RF.

These files cannot establish RSSI accuracy, SNR, DFS, retries, 802.11r, or RF
coverage. The live fallback proves only wired EAPOL/RADIUS and policy behavior.

## Checksums

Calculated with `sha256sum survey.csv events.log`.

| File | SHA-256 |
|---|---|
| `survey.csv` | `3374d7915b86ba5b927021431926fd32ef68fa56c5d1a5b64f324731a9d09bbc` |
| `events.log` | `098e81cd398c81ac99123d5721053e6c56422cf24dd3d3385475171d96b4934d` |
