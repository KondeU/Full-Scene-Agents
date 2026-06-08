"""Markdown-backed capability registry for /genskills.

Developers add or update genskills capabilities by editing Markdown files under
``capabilities/genskills``. The planner and generator consume this registry so
user-facing options and unsupported-capability checks stay declarative.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, List

import yaml


CAPABILITIES_DIR = Path(__file__).resolve().parents[2] / "capabilities" / "genskills"


@dataclass(frozen=True)
class Capability:
    id: str
    domain: str
    label: str
    status: str
    user_words: tuple[str, ...]
    clarification: Dict[str, Any]
    body: str
    path: Path

    @property
    def supported(self) -> bool:
        return self.status == "supported"


@dataclass(frozen=True)
class ClarificationGroup:
    id: str
    title: str
    body: str
    coverage: str
    priority: int
    capabilities: tuple[Capability, ...]

    def as_question(self) -> Dict[str, Any]:
        return {
            "id": self.id,
            "title": self.title,
            "prompt": self.body,
            "coverage": self.coverage,
            "choices": [
                {
                    "id": capability.id,
                    "label": capability.label,
                    "value": capability.label,
                    "capability_id": capability.id,
                }
                for capability in self.capabilities[:3]
            ],
        }


@dataclass(frozen=True)
class CapabilityRegistry:
    source_dir: Path
    capabilities: tuple[Capability, ...]

    @property
    def by_id(self) -> Dict[str, Capability]:
        return {capability.id: capability for capability in self.capabilities}

    def unsupported_matches(self, text: str) -> List[Dict[str, str]]:
        lowered = text.lower()
        matches: List[Dict[str, str]] = []
        for capability in self.capabilities:
            if capability.supported:
                continue
            words = [capability.label, *capability.user_words]
            if any(word and word.lower() in lowered for word in words):
                matches.append({
                    "domain": capability.domain,
                    "capability": capability.label,
                    "capability_id": capability.id,
                })
        return matches

    def clarification_groups(self) -> List[ClarificationGroup]:
        grouped: Dict[str, Dict[str, Any]] = {}
        for capability in self.capabilities:
            if not capability.supported or not capability.clarification:
                continue
            group_id = str(capability.clarification.get("id") or "").strip()
            if not group_id:
                continue
            group = grouped.setdefault(
                group_id,
                {
                    "id": group_id,
                    "title": str(capability.clarification.get("title") or "").strip(),
                    "body": str(capability.clarification.get("body") or "").strip(),
                    "coverage": str(capability.clarification.get("coverage") or capability.domain).strip(),
                    "priority": int(capability.clarification.get("priority") or 100),
                    "capabilities": [],
                },
            )
            group["capabilities"].append(capability)
            group["priority"] = min(group["priority"], int(capability.clarification.get("priority") or group["priority"]))
        return [
            ClarificationGroup(
                id=str(group["id"]),
                title=str(group["title"]),
                body=str(group["body"]),
                coverage=str(group["coverage"]),
                priority=int(group["priority"]),
                capabilities=tuple(sorted(
                    group["capabilities"],
                    key=lambda capability: (
                        int(capability.clarification.get("choice_order") or 100),
                        capability.id,
                    ),
                )),
            )
            for group in sorted(grouped.values(), key=lambda item: (int(item["priority"]), str(item["id"])))
        ]


def _split_frontmatter(markdown: str, path: Path) -> tuple[Dict[str, Any], str]:
    if not markdown.startswith("---\n"):
        raise ValueError(f"{path} missing YAML frontmatter")
    end = markdown.find("\n---\n", 4)
    if end < 0:
        raise ValueError(f"{path} has unterminated YAML frontmatter")
    meta = yaml.safe_load(markdown[4:end]) or {}
    if not isinstance(meta, dict):
        raise ValueError(f"{path} frontmatter must be a mapping")
    return meta, markdown[end + 5:].strip()


def _load_capability(path: Path) -> Capability:
    meta, body = _split_frontmatter(path.read_text(encoding="utf-8"), path)
    capability_id = str(meta.get("id") or "").strip()
    label = str(meta.get("label") or "").strip()
    if not capability_id or not label:
        raise ValueError(f"{path} must define id and label")
    words = meta.get("user_words") or []
    if not isinstance(words, list):
        words = []
    clarification = meta.get("clarification") or {}
    if not isinstance(clarification, dict):
        clarification = {}
    return Capability(
        id=capability_id,
        domain=str(meta.get("domain") or "").strip(),
        label=label,
        status=str(meta.get("status") or "unsupported").strip(),
        user_words=tuple(str(word).strip() for word in words if str(word).strip()),
        clarification=clarification,
        body=body,
        path=path,
    )


def load_capability_registry(source_dir: Path | None = None) -> CapabilityRegistry:
    root = source_dir or CAPABILITIES_DIR
    capabilities = tuple(_load_capability(path) for path in sorted(root.glob("*.md")))
    return CapabilityRegistry(source_dir=root, capabilities=capabilities)


def load_capability_prompt_bundle(source_dir: Path | None = None) -> str:
    registry = load_capability_registry(source_dir)
    sections: List[str] = []
    for capability in registry.capabilities:
        sections.extend([
            f"## Capability: {capability.label}",
            f"- id: {capability.id}",
            f"- domain: {capability.domain}",
            f"- status: {capability.status}",
            "",
            capability.body.strip(),
            "",
        ])
    return "\n".join(sections).strip()
