#!/usr/bin/env python3
from pathlib import Path
import sys, time
root = Path('/runtime/controller'); cmd = sys.argv[1:]
if len(cmd) != 2 or cmd[0] not in {'publish','rollback'} or cmd[1] not in {'v1','v2'}:
    raise SystemExit('usage: controllerctl.py publish|rollback v1|v2')
(root/'policy-version').write_text(cmd[1]+'\n')
with (root/'audit.log').open('a') as f: f.write(f'{int(time.time())} {cmd[0]} {cmd[1]}\n')
print(f'{cmd[0]}d {cmd[1]}')
