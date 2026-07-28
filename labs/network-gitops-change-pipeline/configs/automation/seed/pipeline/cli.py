"""Inspect and run the local safe-change pipeline."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

import jsonschema

from .core import (
    DEVICE_ORDER,
    PipelineError,
    assert_lab_repo,
    copy_intent_with_failure,
    create_review_artifact,
    desired_state,
    dump_yaml,
    inspect_fleet,
    latest_attempt,
    load_attempt,
    load_yaml,
    make_devices,
    render_candidates,
    render_is_deterministic,
    rollback_attempt,
    run_pipeline,
    semantic_diff,
    service_paths,
    validate_intent,
    validate_workflow,
)
from .eapi import EapiDevice, EapiError


def pretty(value):
    print(json.dumps(value, indent=2, sort_keys=True))


def cmd_survey(args):
    intent = load_yaml(args.intent)
    inventory = load_yaml(args.inventory)
    devices = make_devices(inventory)
    state, _ = inspect_fleet(devices, intent)
    pretty(
        {
            "design_truth": intent,
            "current_truth": state,
            "service_truth": service_paths(),
            "repository_truth": subprocess.run(
                ["git", "log", "-1", "--format=%H %an <%ae> %s"],
                check=True,
                text=True,
                capture_output=True,
            ).stdout.strip(),
        }
    )


def cmd_validate(args):
    intent, inventory = validate_intent(args.intent, args.inventory)
    print(
        f"VALID: {intent['change_id']} references "
        f"{len(inventory['devices'])} known devices"
    )


def cmd_render(args):
    intent, inventory = validate_intent(args.intent, args.inventory)
    deterministic, hashes = render_is_deterministic(intent, inventory)
    render_candidates(intent, inventory)
    pretty({"deterministic": deterministic, "candidate_sha256": hashes})
    if not deterministic:
        raise PipelineError("render is not deterministic")


def cmd_plan(args):
    pretty(create_review_artifact(args.intent, args.inventory))


def cmd_run(args):
    attempt = run_pipeline(args.intent, args.inventory)
    pretty(attempt.summary)


def cmd_verify(args):
    intent, inventory = validate_intent(args.intent, args.inventory)
    devices = make_devices(inventory)
    state, diff = inspect_fleet(devices, intent)
    result = {"state": state, "diff": diff, "service": service_paths()}
    pretty(result)
    if any(diff.values()):
        raise PipelineError("structured state differs from declared intent")
    if not result["service"]["corp_allowed"] or not result["service"]["guest_denied"]:
        raise PipelineError("independent service-path assertion failed")


def cmd_drift(args):
    intent, inventory = validate_intent(args.intent, args.inventory)
    devices = make_devices(inventory)
    state, diff = inspect_fleet(devices, intent)
    pretty({"drift": diff, "state": state})
    if any(diff.values()):
        return 3
    return 0


def cmd_inject_drift(args):
    _, inventory = validate_intent(args.intent, args.inventory)
    device = EapiDevice(
        args.device, inventory["devices"][args.device]["address"]
    )
    device.apply(
        [
            "interface Loopback0",
            "description emergency-manual-change",
            "exit",
        ],
        f"manual-{args.device}",
    )
    print(f"manual drift injected on {args.device}")


def cmd_reconcile(args):
    intent, inventory = validate_intent(args.intent, args.inventory)
    validate_workflow()
    device = EapiDevice(
        args.device, inventory["devices"][args.device]["address"]
    )
    current = device.state()
    if args.mode == "revert":
        rendered = render_candidates(intent, inventory)
        device.apply(
            [
                line.strip()
                for line in rendered[args.device]["text"].splitlines()
                if line.strip()
            ],
            f"revert-{args.device}",
        )
        print(f"reverted {args.device} to declared intent")
    else:
        adopted = load_yaml(args.intent)
        adopted["change_id"] = "adopt-emergency-drift"
        adopted["devices"][args.device]["desired_description"] = current[
            "description"
        ]
        dump_yaml("intent/adopted.yml", adopted)
        print(
            "wrote intent/adopted.yml for review; running state was not changed"
        )


def cmd_inject_partial(args):
    assert_lab_repo()
    status = subprocess.run(
        ["git", "status", "--porcelain"],
        check=True,
        text=True,
        capture_output=True,
    ).stdout.strip()
    if status:
        raise PipelineError(
            "commit or discard student work before injecting the partial-push case"
        )
    inventory = load_yaml(args.inventory)
    inventory["devices"]["leaf2"]["candidate_pre_commands"] = [
        "interface Ethernet1",
        "ip address 10.999.1.1/30",
        "exit",
    ]
    intent = load_yaml(args.intent)
    intent["change_id"] = "partial-push-v3"
    for values in intent["devices"].values():
        values["desired_description"] = "gitops-v3-split"
    dump_yaml(args.inventory, inventory)
    dump_yaml(args.intent, intent)
    subprocess.run(["git", "add", args.inventory, args.intent], check=True)
    subprocess.run(
        ["git", "commit", "-m", "break: stale leaf2 capability data"], check=True
    )
    print("stale authoritative capability data committed for leaf2")


def cmd_rollback(args):
    _, inventory = validate_intent(args.intent, args.inventory)
    validate_workflow()
    path, _ = latest_attempt("partial") if not args.attempt else (
        Path(args.attempt),
        None,
    )
    attempt = load_attempt(path)
    devices = make_devices(inventory)
    rollback_attempt(attempt, devices)
    previous_error = attempt.summary.get("error", "")
    attempt.finish("partial_rolled_back", original_error=previous_error)
    print(f"rolled back {', '.join(attempt.summary['rollback'])}")


def cmd_postcheck_fixture(args):
    print(copy_intent_with_failure(args.intent))


def cmd_history(_args):
    rows = []
    for path in sorted(Path("evidence").glob("*/summary.json")):
        summary = json.loads(path.read_text(encoding="utf-8"))
        rows.append(
            {
                "attempt": summary["attempt"],
                "status": summary["status"],
                "changed": summary.get("changed", []),
                "rollback": summary.get("rollback", []),
            }
        )
    pretty(rows)


def parser():
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--intent", default="intent/change.yml")
    common.add_argument("--inventory", default="inventory/inventory.yml")

    root = argparse.ArgumentParser(description=__doc__)
    commands = root.add_subparsers(dest="command", required=True)
    for name, handler in (
        ("survey", cmd_survey),
        ("validate", cmd_validate),
        ("render", cmd_render),
        ("plan", cmd_plan),
        ("run", cmd_run),
        ("verify", cmd_verify),
        ("drift", cmd_drift),
        ("history", cmd_history),
    ):
        command = commands.add_parser(name, parents=[common])
        command.set_defaults(handler=handler)

    inject = commands.add_parser("inject-drift", parents=[common])
    inject.add_argument("--device", choices=DEVICE_ORDER, default="leaf1")
    inject.set_defaults(handler=cmd_inject_drift)

    reconcile = commands.add_parser("reconcile", parents=[common])
    reconcile.add_argument("--device", choices=DEVICE_ORDER, default="leaf1")
    reconcile.add_argument("--mode", choices=("adopt", "revert"), required=True)
    reconcile.set_defaults(handler=cmd_reconcile)

    partial = commands.add_parser("inject-partial", parents=[common])
    partial.set_defaults(handler=cmd_inject_partial)

    rollback = commands.add_parser("rollback", parents=[common])
    rollback.add_argument("--attempt")
    rollback.set_defaults(handler=cmd_rollback)

    postcheck = commands.add_parser("make-postcheck-fixture", parents=[common])
    postcheck.set_defaults(handler=cmd_postcheck_fixture)
    return root


def main():
    arguments = parser().parse_args()
    try:
        assert_lab_repo()
        result = arguments.handler(arguments)
        return result or 0
    except (PipelineError, EapiError, jsonschema.ValidationError) as error:
        print(f"PIPELINE STOPPED: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
