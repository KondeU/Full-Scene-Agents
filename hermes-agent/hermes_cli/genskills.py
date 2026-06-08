"""Helpers for the /genskills slash command."""

from __future__ import annotations

import re
from pathlib import Path

from tools.genskills_capabilities import load_capability_prompt_bundle


GENSKILLS_TITLE = "创建任务"
GENERIC_PLANNER_SKILL = "generic-planner"


def _repo_root() -> Path:
    return Path(__file__).resolve().parent.parent


def _skill_path(name: str) -> Path:
    return _repo_root() / "skills" / "productivity" / name / "SKILL.md"


def _read_bundled_skill(name: str) -> tuple[str, Path]:
    path = _skill_path(name)
    return path.read_text(encoding="utf-8"), path


def _title_from_goal(goal: str) -> str:
    cleaned = re.sub(r"\s+", " ", goal).strip()
    if not cleaned:
        return GENSKILLS_TITLE
    return f"{GENSKILLS_TITLE}: {cleaned[:32]}"


def genskills_title(goal: str = "") -> str:
    """Return a small user-facing session title for /genskills."""
    return _title_from_goal(goal)


def build_genskills_invocation_message(goal: str = "", task_id: str | None = None) -> str:
    """Build the first user message for a /genskills session.

    This intentionally reads the bundled skill from the repository instead of
    relying on the user's seeded ~/.hermes/skills tree. New installations may
    not have synced this skill yet, but the explicit slash command should work
    immediately from the checked-out code.
    """
    planner, planner_path = _read_bundled_skill(GENERIC_PLANNER_SKILL)
    capability_bundle = load_capability_prompt_bundle()
    trimmed_goal = goal.strip()
    if trimmed_goal:
        user_goal = f"用户想保存的做法：{trimmed_goal}"
        first_instruction = "请直接围绕这个做法开始澄清，不要再问用户想保存哪件事。"
    else:
        user_goal = "用户还没有说明想保存哪件事。"
        first_instruction = "请先问用户：你想把哪件常做的事保存成以后能直接用的做法？"

    task_note = f"\n[Session id: {task_id}]" if task_id else ""
    return "\n".join(
        [
            (
                "[IMPORTANT: The user invoked /genskills. Start a fresh mobile "
                "wizard for turning one recurring task into a saved task flow. Follow "
                "the loaded instructions below. Prefer Interaction cards from "
                "`pending_interaction` over text choice lists. User-facing wording must avoid "
                "internal terms like Agent, Skill, Planner, schema, runtime, or tool registry.]"
            ),
            "",
            planner.strip(),
            "",
            "# Genskills Capability Context",
            "",
            capability_bundle,
            "",
            f"[Skill directory: {planner_path.parent}]",
            (
                "Resolve any relative paths in this skill against that directory. "
                "When the user approves the confirmed steps, call generic_generate_skill; "
                "do not save anything before approval."
            ),
            (
                "Tool restriction for this /genskills session: The runtime should "
                "expose only `generic_plan` during planning and "
                "`generic_generate_skill` after `generic_plan` returns "
                "`status: approved`. These tool names are internal debug stages, "
                "not user-facing choices. Do not ask questions, inspect files, "
                "or save workflows through any other tool path."
            ),
            task_note,
            "",
            user_goal,
            first_instruction,
        ]
    ).strip()
