"""Compatibility wrappers for the Markdown-backed genskills capability registry."""

from __future__ import annotations

from typing import Any, Dict, List

from tools.genskills_capabilities import load_capability_registry


def _legacy_spec() -> Dict[str, Any]:
    registry = load_capability_registry()
    domains: Dict[str, Dict[str, Any]] = {}
    for capability in registry.capabilities:
        domain = domains.setdefault(
            capability.domain,
            {
                "id": capability.domain,
                "label": capability.domain,
                "supported": False,
                "capabilities": [],
            },
        )
        if capability.supported:
            domain["supported"] = True
        domain["capabilities"].append({
            "id": capability.id,
            "label": capability.label,
            "aliases": list(capability.user_words),
            "available": capability.supported,
        })
    return {"version": 1, "domains": list(domains.values())}


GENSKILLS_CAPABILITY_SPEC: Dict[str, Any] = _legacy_spec()


def supported_capability_labels() -> List[str]:
    return [
        capability.label
        for capability in load_capability_registry().capabilities
        if capability.supported
    ]


def unsupported_capability_matches(text: str) -> List[Dict[str, str]]:
    return load_capability_registry().unsupported_matches(text)
