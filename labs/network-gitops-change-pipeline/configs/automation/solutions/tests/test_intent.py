import hashlib
from pathlib import Path

import pytest

from pipeline.core import PipelineError, render_is_deterministic, validate_intent


def test_change_intent_schema_and_references():
    intent, inventory = validate_intent(
        "intent/change.yml", "inventory/inventory.yml"
    )
    assert list(inventory["deploy_order"]) == ["leaf1", "leaf2", "edge1"]
    assert set(intent["devices"]) == set(inventory["devices"])


def test_render_is_deterministic_and_secret_safe():
    intent, inventory = validate_intent(
        "intent/change.yml", "inventory/inventory.yml"
    )
    deterministic, hashes = render_is_deterministic(intent, inventory)
    assert deterministic
    assert set(hashes) == {"leaf1", "leaf2", "edge1"}
    for candidate in Path("rendered").glob("*.cfg"):
        text = candidate.read_text(encoding="utf-8").lower()
        assert "password" not in text
        assert "secret" not in text
        assert hashlib.sha256(candidate.read_bytes()).hexdigest() in hashes.values()


@pytest.mark.parametrize(
    "fixture",
    ["intent/bad-route-leak.yml", "intent/bad-management.yml"],
)
def test_precheck_rejects_unsafe_intent(fixture):
    with pytest.raises(Exception):
        validate_intent(fixture, "inventory/inventory.yml")
