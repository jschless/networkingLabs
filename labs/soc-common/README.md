# soc-common — shared configs, not a lab

This directory is **not a deployable lab**. It holds the `setup.sh` scripts shared by
the `soc-*` labs (router-fw, sensor, attacker, dmz-web/dmz-api, siem, arkime, misp,
case-mgmt node roles), which each lab's `topology.clab.yml` bind-mounts by relative
path (`../soc-common/configs/...`).

To run the SOC track, start with `labs/soc-dmz-foundation/` and follow the
[Security Operations study path](../../docs/study-paths.md).

If you change a script here, re-validate every lab that mounts it — grep the
`soc-*/topology.clab.yml` files for the script's path to find them.
