#!/usr/bin/env python3
import pathlib
import yaml
from jinja2 import Template

root = pathlib.Path("/workspace")
data = yaml.safe_load((root / "intent.yml").read_text())
template = Template(
    "hostname {{ name }}\n"
    "ip routing\n"
    "interface Loopback0\n"
    "   ip address {{ loopback }}\n"
    "interface Ethernet1\n"
    "   no switchport\n"
    "   ip address {{ p2p_ip }}\n"
    "   no shutdown\n"
    "end\n"
)
outdir = root / "generated"
outdir.mkdir(exist_ok=True)
for device in data["devices"]:
    (outdir / f"{device['name']}.cfg").write_text(template.render(**device))
print(f"rendered {len(data['devices'])} device configs into {outdir}")
