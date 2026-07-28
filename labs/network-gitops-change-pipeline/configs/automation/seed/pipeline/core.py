"""Validation, rendering, deployment, verification, and evidence primitives."""

from __future__ import annotations

import difflib
import hashlib
import json
import os
import subprocess
import time
import urllib.request
from copy import deepcopy
from datetime import datetime, timezone
from pathlib import Path

import jsonschema
import yaml
from jinja2 import Environment, FileSystemLoader, StrictUndefined

from .eapi import EapiDevice, EapiError

LAB_REPO = Path("/workspace/lab-repo")
CANARY = "203.0.113.12/32"
DEVICE_ORDER = ("leaf1", "leaf2", "edge1")


class PipelineError(RuntimeError):
    """A safe pipeline gate stopped the change."""


def assert_lab_repo():
    cwd = Path.cwd().resolve()
    expected = Path(os.environ.get("LAB_REPO", str(LAB_REPO))).resolve()
    if expected != LAB_REPO or cwd != LAB_REPO:
        raise PipelineError(
            f"refusing to operate outside disposable lab repo {LAB_REPO}; cwd={cwd}"
        )
    if not (cwd / ".git").is_dir():
        raise PipelineError("disposable lab repository has no .git directory")
    return cwd


def load_yaml(path):
    with Path(path).open(encoding="utf-8") as handle:
        return yaml.safe_load(handle)


def dump_yaml(path, data):
    with Path(path).open("w", encoding="utf-8") as handle:
        yaml.safe_dump(data, handle, sort_keys=False)


def repository_state():
    commit = subprocess.run(
        ["git", "rev-parse", "HEAD"],
        check=True,
        text=True,
        capture_output=True,
    ).stdout.strip()
    status = subprocess.run(
        ["git", "status", "--porcelain"],
        check=True,
        text=True,
        capture_output=True,
    ).stdout.strip()
    return {"commit": commit, "dirty": bool(status), "status": status.splitlines()}


def validate_intent(intent_path, inventory_path):
    assert_lab_repo()
    intent = load_yaml(intent_path)
    inventory = load_yaml(inventory_path)
    schema = json.loads(Path("intent/schema.json").read_text(encoding="utf-8"))
    jsonschema.validate(intent, schema)

    intent_devices = set(intent["devices"])
    inventory_devices = set(inventory["devices"])
    if intent_devices != inventory_devices:
        raise PipelineError(
            "intent/inventory referential integrity failed: "
            f"intent={sorted(intent_devices)} inventory={sorted(inventory_devices)}"
        )
    if tuple(inventory["deploy_order"]) != DEVICE_ORDER:
        raise PipelineError("deploy order must be leaf1, leaf2, edge1")
    if intent["allowed_prefixes"] != [CANARY]:
        raise PipelineError(
            f"unauthorized prefix set {intent['allowed_prefixes']}; only {CANARY} is allowed"
        )

    protected_tokens = (
        "management0",
        "172.31.112.",
        "0.0.0.0/0",
        "username ",
        "password",
        "secret",
    )
    all_commands = []
    for device, values in intent["devices"].items():
        all_commands.extend(values.get("candidate_pre_commands", []))
        all_commands.extend(
            inventory["devices"][device].get("candidate_pre_commands", [])
        )
    candidate_text = "\n".join(all_commands).lower()
    blocked = [token for token in protected_tokens if token in candidate_text]
    if blocked:
        raise PipelineError(
            f"management/secret safety gate rejected candidate token(s): {blocked}"
        )
    return intent, inventory


def validate_workflow(path="workflow/change-policy.yml"):
    assert_lab_repo()
    workflow_path = Path(path)
    if not workflow_path.is_file():
        raise PipelineError(
            "workflow/change-policy.yml is missing; define the withheld "
            "transaction/rollback/reconciliation policy"
        )
    workflow = load_yaml(workflow_path)
    expected = {
        "version": 1,
        "transaction": {
            "snapshot": "running-config",
            "candidate": "eos-config-session",
            "commit": "staged-stop-on-first-error",
            "rollback": "configure-replace",
        },
        "verification": {
            "state": "structured-eapi",
            "service": "independent-client-positive-negative",
            "rollback_on_failure": True,
        },
        "reconciliation": {
            "drift": "explicit-adopt-or-revert",
            "require_clean_git_for_break": True,
        },
    }
    if workflow != expected:
        raise PipelineError(
            "workflow policy must require snapshots, config sessions, "
            "stop-on-first-error, structured/service checks, explicit "
            "replace rollback, and explicit drift disposition"
        )
    return workflow


def render_candidates(intent, inventory, output_dir="rendered"):
    assert_lab_repo()
    template_path = Path("templates/device.j2")
    if not template_path.is_file():
        raise PipelineError("templates/device.j2 is missing; complete Task 2")
    environment = Environment(
        loader=FileSystemLoader("templates"),
        undefined=StrictUndefined,
        autoescape=False,
        keep_trailing_newline=True,
    )
    template = environment.get_template("device.j2")
    output = Path(output_dir)
    output.mkdir(parents=True, exist_ok=True)
    rendered = {}
    for device in sorted(intent["devices"]):
        text = template.render(
            device=device,
            desired=intent["devices"][device],
            inventory=inventory["devices"][device],
            canary=CANARY,
            canary_distance=intent["canary_distance"],
        )
        normalized = "\n".join(
            line.rstrip() for line in text.splitlines() if line.strip()
        ) + "\n"
        if any(secret in normalized.lower() for secret in ("password", "secret")):
            raise PipelineError("rendered candidate contains a secret-like token")
        path = output / f"{device}.cfg"
        path.write_text(normalized, encoding="utf-8")
        rendered[device] = {
            "path": str(path),
            "sha256": hashlib.sha256(normalized.encode()).hexdigest(),
            "text": normalized,
        }
    return rendered


def render_is_deterministic(intent, inventory):
    first = render_candidates(intent, inventory)
    first_hashes = {name: value["sha256"] for name, value in first.items()}
    second = render_candidates(intent, inventory)
    second_hashes = {name: value["sha256"] for name, value in second.items()}
    return first_hashes == second_hashes, second_hashes


def parse_commands(text):
    return [line.strip() for line in text.splitlines() if line.strip()]


def desired_state(intent, device):
    return {
        "description": intent["devices"][device]["desired_description"],
        "canary_present": True,
    }


def semantic_diff(current, desired):
    differences = {}
    for key in ("description", "canary_present"):
        if current.get(key) != desired.get(key):
            differences[key] = {
                "current": current.get(key),
                "desired": desired.get(key),
            }
    return differences


class Attempt:
    def __init__(self, kind, intent_path):
        stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S")
        suffix = str(time.time_ns())[-6:]
        self.name = f"{stamp}-{suffix}-{kind}"
        self.path = Path("evidence") / self.name
        self.path.mkdir(parents=True, exist_ok=False)
        self.summary = {
            "attempt": self.name,
            "kind": kind,
            "intent": str(intent_path),
            "started_utc": datetime.now(timezone.utc).isoformat(),
            "status": "running",
            "applied": [],
            "changed": [],
            "snapshots": {},
            "rollback": [],
            "device_access_count": 0,
            "repository": repository_state(),
        }
        self.audit("attempt_started", kind=kind)
        self.save()

    def audit(self, event, **values):
        record = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "event": event,
            **values,
        }
        with (self.path / "audit.ndjson").open("a", encoding="utf-8") as handle:
            handle.write(json.dumps(record, sort_keys=True) + "\n")

    def write_json(self, name, value):
        (self.path / name).write_text(
            json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8"
        )

    def save(self):
        self.summary["device_access_count"] = EapiDevice.calls
        self.write_json("summary.json", self.summary)

    def finish(self, status, **values):
        self.summary.update(values)
        self.summary["status"] = status
        self.summary["finished_utc"] = datetime.now(timezone.utc).isoformat()
        self.audit("attempt_finished", status=status)
        self.save()


def make_devices(inventory):
    return {
        name: EapiDevice(name, values["address"])
        for name, values in inventory["devices"].items()
    }


def service_paths():
    try:
        with urllib.request.urlopen(
            "http://172.31.112.21:9090/verify", timeout=10
        ) as response:
            result = json.load(response)
    except OSError as error:
        raise PipelineError(f"client service-path agent unavailable: {error}") from error
    result["corp_allowed"] = result["corp"] == {"code": "200", "exit": 0}
    result["guest_denied"] = result["guest"]["code"] == "000" and result["guest"][
        "exit"
    ] != 0
    return result


def inspect_fleet(devices, intent):
    state = {}
    diff = {}
    for device in DEVICE_ORDER:
        state[device] = devices[device].state()
        diff[device] = semantic_diff(state[device], desired_state(intent, device))
    return state, diff


def rollback_attempt(attempt, devices, only=None):
    targets = only or list(reversed(attempt.summary["applied"]))
    rolled_back = []
    for device in targets:
        filename = attempt.summary["snapshots"][device]
        devices[device].rollback(filename)
        rolled_back.append(device)
        attempt.audit("device_rolled_back", device=device, snapshot=filename)
    attempt.summary["rollback"] = rolled_back
    attempt.save()
    return rolled_back


def run_pipeline(intent_path="intent/change.yml", inventory_path="inventory/inventory.yml"):
    assert_lab_repo()
    EapiDevice.calls = 0
    attempt = Attempt("pipeline", intent_path)
    try:
        intent, inventory = validate_intent(intent_path, inventory_path)
        workflow = validate_workflow()
        deterministic, hashes = render_is_deterministic(intent, inventory)
        if not deterministic:
            raise PipelineError("render output changed between identical runs")
        attempt.write_json(
            "precheck.json",
            {
                "schema": "pass",
                "referential_integrity": "pass",
                "prefix_policy": "pass",
                "management_protection": "pass",
                "deterministic": deterministic,
                "candidate_sha256": hashes,
                "workflow": workflow,
            },
        )
    except (PipelineError, jsonschema.ValidationError) as error:
        attempt.finish(
            "rejected_precheck",
            error=str(error),
            device_access_count=EapiDevice.calls,
        )
        raise PipelineError(str(error)) from error

    devices = make_devices(inventory)
    rendered = render_candidates(intent, inventory)
    for device, value in rendered.items():
        (attempt.path / f"candidate-{device}.cfg").write_text(
            value["text"], encoding="utf-8"
        )

    state_before, diff_before = inspect_fleet(devices, intent)
    attempt.write_json("state-before.json", state_before)
    attempt.write_json("semantic-diff.json", diff_before)
    attempt.audit("review_artifact_ready", devices=list(DEVICE_ORDER))

    snapshot_token = attempt.name.replace("-", "")[-16:]
    session_token = attempt.name.split("-")[-2]
    for device in DEVICE_ORDER:
        filename = f"gitops-{snapshot_token}-{device}.cfg"
        devices[device].snapshot(filename)
        attempt.summary["snapshots"][device] = filename
        attempt.audit("snapshot_complete", device=device, snapshot=filename)
    attempt.save()

    for index, device in enumerate(DEVICE_ORDER, start=1):
        desired = desired_state(intent, device)
        current = devices[device].state()
        extra = inventory["devices"][device].get("candidate_pre_commands", [])
        extra += intent["devices"][device].get("candidate_pre_commands", [])
        if not semantic_diff(current, desired) and not extra:
            attempt.audit("device_idempotent", device=device)
            continue
        commands = extra + parse_commands(rendered[device]["text"])
        try:
            devices[device].apply(commands, f"gitops-{index}-{session_token}")
        except EapiError as error:
            attempt.finish(
                "partial",
                error=str(error),
                failed_device=device,
                stopped_before=list(DEVICE_ORDER[index:]),
            )
            raise PipelineError(
                f"{device} rejected candidate; partial application preserved for diagnosis"
            ) from error
        attempt.summary["applied"].append(device)
        attempt.summary["changed"].append(device)
        attempt.audit("device_committed", device=device)
        attempt.save()

    state_after, diff_after = inspect_fleet(devices, intent)
    path_result = service_paths()
    attempt.write_json("state-after.json", state_after)
    attempt.write_json("postcheck.json", {"diff": diff_after, "service": path_result})
    post_ok = not any(diff_after.values()) and path_result["corp_allowed"] and path_result[
        "guest_denied"
    ]
    if intent.get("force_postcheck_failure"):
        post_ok = False
        attempt.audit("forced_postcheck_failure")
    if not post_ok:
        rollback_attempt(attempt, devices)
        attempt.finish(
            "failed_rolled_back",
            error="post-change structured or service-path assertion failed",
            service=path_result,
        )
        raise PipelineError("post-check failed; snapshots restored")

    attempt.finish(
        "success",
        service=path_result,
        idempotent=len(attempt.summary["changed"]) == 0,
    )
    return attempt


def create_review_artifact(
    intent_path="intent/change.yml", inventory_path="inventory/inventory.yml"
):
    intent, inventory = validate_intent(intent_path, inventory_path)
    workflow = validate_workflow()
    deterministic, hashes = render_is_deterministic(intent, inventory)
    devices = make_devices(inventory)
    state, diff = inspect_fleet(devices, intent)
    plan = {
        "change_id": intent["change_id"],
        "repository": repository_state(),
        "deploy_order": inventory["deploy_order"],
        "expected_transient_state": "one device may differ until the next commit",
        "rollback_trigger": "any rejected candidate or failed structured/service check",
        "rollback_method": "configure replace from per-attempt flash snapshot",
        "workflow": workflow,
        "candidate_sha256": hashes,
        "deterministic": deterministic,
        "semantic_diff": diff,
        "state": state,
    }
    Path("rendered/change-plan.json").write_text(
        json.dumps(plan, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    return plan


def normalized_candidate_diff(old, new):
    return "\n".join(
        difflib.unified_diff(
            old.splitlines(),
            new.splitlines(),
            fromfile="running-structured",
            tofile="declared-intent",
            lineterm="",
        )
    )


def latest_attempt(status=None):
    matches = []
    for path in Path("evidence").glob("*/summary.json"):
        data = json.loads(path.read_text(encoding="utf-8"))
        if status is None or data["status"] == status:
            matches.append((path.stat().st_mtime_ns, path.parent, data))
    if not matches:
        raise PipelineError(f"no evidence attempt found for status={status!r}")
    return sorted(matches)[-1][1:]


def load_attempt(path):
    summary_path = Path(path) / "summary.json"
    summary = json.loads(summary_path.read_text(encoding="utf-8"))
    instance = object.__new__(Attempt)
    instance.name = summary["attempt"]
    instance.path = Path(path)
    instance.summary = summary
    return instance


def copy_intent_with_failure(source="intent/change.yml"):
    intent = deepcopy(load_yaml(source))
    intent["change_id"] = "postcheck-rollback"
    intent["force_postcheck_failure"] = True
    for values in intent["devices"].values():
        values["desired_description"] = "gitops-postcheck-candidate"
    path = Path("intent/postcheck-failure.yml")
    dump_yaml(path, intent)
    return path
