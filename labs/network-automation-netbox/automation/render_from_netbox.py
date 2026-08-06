#!/usr/bin/env python3
"""Fail-closed native NetBox rendering with complete-set replacement."""

import argparse
import os
import pathlib
import shutil
import sys
import tempfile

from model_graph import build_render_contexts, load_state, validate_model
from netbox_common import api_post, build_clients


ROOT = pathlib.Path("/workspace")
EXPECTED_NAMES = ("leaf1", "leaf2", "spine1", "spine2")
FORBIDDEN_BOOTSTRAP_MARKERS = (
    "username",
    "secret",
    "password",
    "management api http-commands",
)


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--output",
        type=pathlib.Path,
        default=ROOT / "generated",
        help="complete candidate directory (default: /workspace/generated)",
    )
    parser.add_argument(
        "--validate-only",
        action="store_true",
        help="validate the model without calling render-config or writing files",
    )
    return parser.parse_args()


def replace_directory(stage, destination):
    destination = destination.resolve()
    destination.parent.mkdir(parents=True, exist_ok=True)
    backup = destination.parent / f".{destination.name}.previous-{os.getpid()}"
    moved_old = False
    try:
        if destination.exists():
            if backup.exists():
                shutil.rmtree(backup)
            os.replace(destination, backup)
            moved_old = True
        os.replace(stage, destination)
    except Exception:
        if moved_old and backup.exists() and not destination.exists():
            os.replace(backup, destination)
        raise
    else:
        if backup.exists():
            shutil.rmtree(backup)


def main():
    args = parse_args()
    _, session, _ = build_clients("network-automation-netbox render")
    state = load_state(session)
    errors = validate_model(state, require_service=True)
    if errors:
        for error in errors:
            print(f"MODEL INTEGRITY ERROR: {error}", file=sys.stderr)
        return 2
    if args.validate_only:
        print("Model integrity valid for four-device native rendering.")
        return 0

    contexts = build_render_contexts(state)
    destination = args.output.resolve()
    destination.parent.mkdir(parents=True, exist_ok=True)
    stage = pathlib.Path(
        tempfile.mkdtemp(prefix=f".{destination.name}.stage-", dir=destination.parent)
    )
    stage.chmod(0o755)
    try:
        for device_name in EXPECTED_NAMES:
            device = state["device_by_name"][device_name]
            rendered = api_post(
                session,
                f"/api/dcim/devices/{device['id']}/render-config/",
                contexts[device_name],
                accept="text/plain",
            )
            if not rendered.strip():
                raise RuntimeError(f"{device_name}: native render returned empty content")
            marker = f"! NetBox merge candidate for {device_name}"
            if marker not in rendered:
                raise RuntimeError(
                    f"{device_name}: native render lacks device-specific marker"
                )
            rendered_casefolded = rendered.casefold()
            forbidden_found = [
                marker
                for marker in FORBIDDEN_BOOTSTRAP_MARKERS
                if marker in rendered_casefolded
            ]
            if forbidden_found:
                raise RuntimeError(
                    f"{device_name}: rendered candidate contains forbidden bootstrap "
                    f"or secret marker(s): {', '.join(forbidden_found)}"
                )
            candidate = stage / f"{device_name}.cfg"
            candidate.write_text(rendered)
            candidate.chmod(0o644)
        staged_names = sorted(path.name for path in stage.glob("*.cfg"))
        expected_files = [f"{name}.cfg" for name in EXPECTED_NAMES]
        if staged_names != expected_files:
            raise RuntimeError(
                f"staged candidate set is incomplete: expected {expected_files}, "
                f"found {staged_names}"
            )
        replace_directory(stage, destination)
    except Exception as exc:
        if stage.exists():
            shutil.rmtree(stage)
        print(f"RENDER FAILURE: {exc}", file=sys.stderr)
        return 3

    print(f"Rendered 4 validated native configs into {destination}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
