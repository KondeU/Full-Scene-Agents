#!/usr/bin/env python3
"""Generic /genskills planning and skill-generation tools."""

from __future__ import annotations

import json
import re
import time
from pathlib import Path
from typing import Any, Dict, List

import yaml

from tools.genskills_capabilities import load_capability_prompt_bundle, load_capability_registry
from tools.registry import registry


INPUT_EXAMPLE_QUESTION = {
    "id": "input_example",
    "prompt": "举个例子：你下次会发什么给我？",
    "choices": [
        {"id": "text", "label": "一段文字", "value": "一段文字"},
        {"id": "image_or_file", "label": "图片或文件", "value": "图片或文件"},
        {"id": "ask_later", "label": "执行时再问我", "value": "执行时再问我"},
    ],
    "coverage": "材料示例",
}

APPROACH_QUESTION = {
    "id": "approach_choice",
    "prompt": "这个做法想怎么保存？",
    "choices": ["简单稳妥", "自动化更多", "分成几步"],
    "coverage": "复杂任务处理方式",
}

REVISION_QUESTION = {
    "id": "approval_revision",
    "prompt": "你想先改哪部分？",
    "choices": ["需要内容", "输出结果", "确认方式"],
    "coverage": "用户修改反馈",
}

CONFIRMATION_QUESTION = {
    "id": "confirmation",
    "prompt": "这样创建可以吗？",
    "choices": [
        {"id": "save", "label": "可以保存", "value": "可以保存"},
        {"id": "details", "label": "修改前面的选择", "value": "修改前面的选择"},
        {"id": "rewrite", "label": "重新描述", "value": "重新描述"},
    ],
    "coverage": "最终确认",
}

STATIC_QUESTIONS_BY_ID = {
    item["id"]: item
    for item in [INPUT_EXAMPLE_QUESTION, APPROACH_QUESTION, REVISION_QUESTION, CONFIRMATION_QUESTION]
}
REUSE_CHOICES = ["直接用", "改一下", "新建"]
GOAL_QUESTION = "你想把哪件常做的事保存成以后能直接用的做法？"

VAGUE_RE = re.compile(r"^(不知道|不清楚|随便|都行|先不确定|还没想好|不知道呢|not sure|unknown|idk)?$", re.I)
SAVE_APPROVAL_ANSWERS = {"可以", "可以保存", "保存", "确认", "好的", "好", "yes", "ok", "approve", "approved"}
DETAIL_ANSWERS = {"补充细节", "补充", "改一下", "完善一下", "修改前面的选择", "detail", "details"}
REWRITE_ANSWERS = {"重新描述", "重写", "换一个", "rewrite", "restart"}
DYNAMIC_QUESTION_SOURCE = "brainstorming_dynamic_analyzer"
REQUIRED_PROPOSED_DESIGN_FIELDS = (
    "inputs_needed",
    "processing_action",
    "schedule_or_trigger",
    "memory_scope",
    "output_or_delivery",
)

GENSKILLS_ANALYZER_SYSTEM_PROMPT = """You design a mobile, non-technical /genskills clarification flow.

Reference interaction flow from superpowers-main brainstorming:
1. Explore project context before asking.
2. Ask clarifying questions one at a time.
3. Propose 2-3 approaches when there are meaningful tradeoffs.
4. Present design only after enough context is known.

Rules:
- Ask exactly one narrowing question at a time.
- The question must be specific to the user's goal and previous answers.
- Choices must be mutually exclusive, at most 3, and tappable on a phone.
- Do not ask generic questionnaire slots.
- Do not expose internal terms like Agent, Skill, Planner, schema, runtime, or tool registry.
- Do not offer unsupported capabilities as choices.
- If the user asks for unsupported capability, return blocked.
- Return JSON only.

JSON schema:
{
  "status": "needs_clarification" | "awaiting_confirmation" | "blocked",
  "brainstorm_phase": "explore_context" | "ask_clarifying_question" | "propose_approaches" | "present_design",
  "question": {"id": "short_snake_case", "title": "...", "body": "...", "choices": ["...", "..."]},
  "missing_slot": "short description",
  "capabilities_used": ["capability.id"],
  "unsupported_capability": {"capability": "...", "domain": "..."},
  "proposed_design": {
    "inputs_needed": ["..."],
    "processing_action": "...",
    "schedule_or_trigger": "...",
    "memory_scope": "...",
    "output_or_delivery": "...",
    "steps": ["..."],
    "constraints": ["..."],
    "failure_handling": "...",
    "acceptance_criteria": ["..."]
  },
  "rationale": "short internal reason"
}
"""

_APPROVED_PLAN_CACHE: Dict[str, Dict[str, Any]] = {}
_PLANNING_SESSION_CACHE: Dict[str, Dict[str, Any]] = {}
_APPROVED_PLAN_CACHE_TTL_SECONDS = 30 * 60
_PLANNING_SESSION_CACHE_TTL_SECONDS = 30 * 60


def _json(data: Dict[str, Any]) -> str:
    return json.dumps(data, ensure_ascii=False, indent=2)


def _with_debug_stage(payload: Dict[str, Any], stage: str, next_stage: str | None = None) -> Dict[str, Any]:
    payload["debug_stage"] = stage
    if next_stage:
        payload["debug_next_stage"] = next_stage
    session = payload.get("session")
    if isinstance(session, dict):
        session["debug_stage"] = stage
        if next_stage:
            session["debug_next_stage"] = next_stage
    return payload


def _plan_json(payload: Dict[str, Any], next_stage: str | None = None) -> str:
    payload = _with_debug_stage(payload, "plan", next_stage)
    _store_planning_state_from_payload(payload)
    return _json(payload)


def _now_id(prefix: str) -> str:
    return f"{prefix}-{int(time.time() * 1000)}"


def _runtime_session_id(state: Dict[str, Any], session_id: str = "", task_id: str = "") -> str:
    return str(session_id or state.get("runtime_session_id") or task_id or state.get("id") or "").strip()


def _runtime_task_id(state: Dict[str, Any], task_id: str = "") -> str:
    return str(task_id or state.get("runtime_task_id") or state.get("id") or "").strip()


def _plan_ref(state: Dict[str, Any], plan: Dict[str, Any], session_id: str = "", task_id: str = "") -> Dict[str, str]:
    return {
        "session_id": _runtime_session_id(state, session_id=session_id, task_id=task_id),
        "task_id": _runtime_task_id(state, task_id=task_id),
        "plan_id": str(plan.get("id") or "").strip(),
    }


def _cache_keys(plan_ref: Dict[str, Any]) -> List[str]:
    session_id = str(plan_ref.get("session_id") or "").strip()
    task_id = str(plan_ref.get("task_id") or "").strip()
    plan_id = str(plan_ref.get("plan_id") or "").strip()
    keys: List[str] = []
    if session_id and task_id:
        keys.append(f"session:{session_id}|task:{task_id}")
    if session_id and plan_id:
        keys.append(f"session:{session_id}|plan:{plan_id}")
    return keys


def _planning_cache_keys(state: Dict[str, Any], session_id: str = "", task_id: str = "") -> List[str]:
    resolved_session_id = str(session_id or state.get("runtime_session_id") or state.get("id") or "").strip()
    resolved_task_id = str(task_id or state.get("runtime_task_id") or state.get("id") or "").strip()
    keys: List[str] = []
    if resolved_session_id and resolved_task_id:
        keys.append(f"session:{resolved_session_id}|task:{resolved_task_id}")
    if resolved_session_id:
        keys.append(f"session:{resolved_session_id}")
    return keys


def _jsonable_copy(value: Dict[str, Any]) -> Dict[str, Any]:
    try:
        return json.loads(json.dumps(value, ensure_ascii=False))
    except Exception:
        return dict(value)


def _store_planning_state(state: Dict[str, Any]) -> None:
    keys = _planning_cache_keys(state)
    if not keys:
        return
    record = {"stored_at": time.time(), "session": _jsonable_copy(state)}
    for key in keys:
        _PLANNING_SESSION_CACHE[key] = record


def _recover_planning_state(
    state: Dict[str, Any],
    *,
    session_id: str = "",
    task_id: str = "",
) -> Dict[str, Any]:
    probe = dict(state)
    if session_id:
        probe["runtime_session_id"] = session_id
    if task_id:
        probe["runtime_task_id"] = task_id
    now = time.time()
    for key in _planning_cache_keys(probe, session_id=session_id, task_id=task_id):
        record = _PLANNING_SESSION_CACHE.get(key)
        if not record:
            continue
        if now - float(record.get("stored_at") or 0) > _PLANNING_SESSION_CACHE_TTL_SECONDS:
            _PLANNING_SESSION_CACHE.pop(key, None)
            continue
        recovered = record.get("session")
        if isinstance(recovered, dict):
            return _jsonable_copy(recovered)
    return {}


def _store_planning_state_from_payload(payload: Dict[str, Any]) -> None:
    session = payload.get("session")
    if isinstance(session, dict):
        _store_planning_state(session)


def _store_approved_plan(plan: Dict[str, Any], plan_ref: Dict[str, Any]) -> None:
    now = time.time()
    record = {"stored_at": now, "plan": dict(plan), "plan_ref": dict(plan_ref)}
    for key in _cache_keys(plan_ref):
        _APPROVED_PLAN_CACHE[key] = record


def _recover_approved_plan(plan_ref: Dict[str, Any]) -> Dict[str, Any]:
    now = time.time()
    for key in _cache_keys(plan_ref):
        record = _APPROVED_PLAN_CACHE.get(key)
        if not record:
            continue
        if now - float(record.get("stored_at") or 0) > _APPROVED_PLAN_CACHE_TTL_SECONDS:
            _APPROVED_PLAN_CACHE.pop(key, None)
            continue
        recovered = record.get("plan")
        if isinstance(recovered, dict) and recovered.get("approved"):
            return dict(recovered)
    return {}


def _as_record(value: Any) -> Dict[str, Any]:
    return value if isinstance(value, dict) else {}


def _answer_text(answer: Any) -> str:
    if isinstance(answer, str):
        return answer.strip()
    if isinstance(answer, dict):
        for key in ("user_response", "free_text", "freeText", "value", "label", "answer"):
            value = answer.get(key)
            if isinstance(value, str) and value.strip():
                return value.strip()
    return ""


def _capability_questions() -> List[Dict[str, Any]]:
    # Capability Markdown describes what the agent can do. It no longer owns
    # the question flow; runtime brainstorming analysis generates questions.
    return []


def _question_by_id(session: Dict[str, Any], question_id: str) -> Dict[str, Any] | None:
    pending = session.get("pending_question")
    if isinstance(pending, dict) and str(pending.get("id") or "") == question_id:
        return pending
    static = STATIC_QUESTIONS_BY_ID.get(question_id)
    if static:
        return static
    for question in _capability_questions():
        if str(question.get("id") or "") == question_id:
            return question
    return None


def _response_content(response: Any) -> str:
    try:
        return str(response.choices[0].message.content or "").strip()
    except Exception:
        return ""


def _json_object_from_text(text: str) -> Dict[str, Any]:
    stripped = text.strip()
    if not stripped:
        return {}
    if stripped.startswith("```"):
        stripped = re.sub(r"^```(?:json)?\s*", "", stripped)
        stripped = re.sub(r"\s*```$", "", stripped)
    try:
        parsed = json.loads(stripped)
        return parsed if isinstance(parsed, dict) else {}
    except Exception:
        start = stripped.find("{")
        end = stripped.rfind("}")
        if start >= 0 and end > start:
            try:
                parsed = json.loads(stripped[start:end + 1])
                return parsed if isinstance(parsed, dict) else {}
            except Exception:
                return {}
    return {}


def _answered_summary(session: Dict[str, Any]) -> List[Dict[str, str]]:
    answers = session.get("answers") if isinstance(session.get("answers"), list) else []
    return [
        {
            "question_id": str(item.get("question_id") or ""),
            "question": str(item.get("question") or ""),
            "answer": str(item.get("answer") or ""),
        }
        for item in answers
        if isinstance(item, dict)
    ]


def _is_filled_design_value(value: Any) -> bool:
    if isinstance(value, str):
        return bool(value.strip())
    if isinstance(value, list):
        return any(str(item).strip() for item in value)
    return value is not None


def _missing_proposed_design_fields(design: Dict[str, Any]) -> List[str]:
    return [
        field
        for field in REQUIRED_PROPOSED_DESIGN_FIELDS
        if not _is_filled_design_value(design.get(field))
    ]


def _invalid_proposed_design_payload(
    state: Dict[str, Any],
    design: Dict[str, Any],
    *,
    reason: str = "Analyzer returned awaiting_confirmation without required proposed_design fields.",
) -> Dict[str, Any]:
    missing = _missing_proposed_design_fields(design)
    state["phase"] = "blocked"
    state["status"] = "blocked"
    state["design_completeness"] = {
        "source": "invalid_analyzer_proposed_design",
        "missing_fields": missing,
        "reason": reason,
    }
    return {
        "status": "blocked",
        "session": state,
        "diagnostics": [{
            "code": "invalid_proposed_design",
            "message": "规划分析返回了确认状态，但缺少生成确认卡片所需的设计字段。",
            "missing_fields": missing,
            "reason": reason,
        }],
        "user_display": "规划结果不完整，不能保存这个任务。请重新确认或重新描述任务，我会继续澄清，而不是用默认内容补全。",
        "question_source": DYNAMIC_QUESTION_SOURCE,
        "brainstorm_phase": state.get("brainstorm_phase") or "present_design",
        "design_completeness": state["design_completeness"],
    }


def _planning_analyzer_failed_payload(state: Dict[str, Any], warning: str) -> Dict[str, Any]:
    state["phase"] = "blocked"
    state["status"] = "blocked"
    state["design_completeness"] = {
        "source": "planning_analyzer_failed",
        "missing_fields": list(REQUIRED_PROPOSED_DESIGN_FIELDS),
        "reason": warning,
    }
    return {
        "status": "blocked",
        "session": state,
        "diagnostics": [{
            "code": "planning_analyzer_failed",
            "message": "动态规划分析失败，不能安全生成确认卡片。",
            "missing_fields": list(REQUIRED_PROPOSED_DESIGN_FIELDS),
            "reason": warning,
        }],
        "user_display": "规划分析失败，不能保存这个任务。请重试上一条回答或重新描述任务，我不会用默认流程代替你的需求。",
        "question_source": DYNAMIC_QUESTION_SOURCE,
        "brainstorm_phase": state.get("brainstorm_phase") or "ask_clarifying_question",
        "design_completeness": state["design_completeness"],
    }


def _fallback_analyzer_result(state: Dict[str, Any], warning: str = "") -> Dict[str, Any]:
    goal = str(state.get("user_goal") or "这个任务").strip()
    answers = _answered_summary(state)
    if not answers:
        return {
            "status": "needs_clarification",
            "brainstorm_phase": "ask_clarifying_question",
            "question": {
                "id": "fallback_first_detail",
                "title": "先确认重点",
                "prompt": f"关于「{goal}」，你最想先确认哪一点？",
                "choices": ["最后想看到什么", "会提供哪些信息", "什么时候使用"],
            },
            "missing_slot": "first_detail",
            "capabilities_used": [],
            "rationale": warning or "Fallback when dynamic analyzer is unavailable.",
        }
    return {
        "status": "blocked",
        "brainstorm_phase": "ask_clarifying_question",
        "diagnostic_code": "planning_analyzer_failed",
        "missing_slot": "planning_analyzer",
        "capabilities_used": [],
        "rationale": warning or "Dynamic analyzer failed after user answers.",
    }


def _normalize_analyzer_choices(raw_choices: Any) -> List[Dict[str, str]]:
    if not isinstance(raw_choices, list):
        return []
    choices: List[Dict[str, str]] = []
    for index, raw in enumerate(raw_choices[:3]):
        if isinstance(raw, dict):
            label = str(raw.get("label") or raw.get("value") or raw.get("id") or "").strip()
            value = str(raw.get("value") or label).strip()
            choice_id = str(raw.get("id") or f"choice_{index + 1}").strip()
        else:
            label = str(raw).strip()
            value = label
            choice_id = f"choice_{index + 1}"
        if label:
            choices.append({"id": choice_id, "label": label, "value": value})
    return choices


def _normalize_analyzer_result(state: Dict[str, Any], result: Dict[str, Any]) -> Dict[str, Any]:
    status = str(result.get("status") or "").strip()
    phase = str(result.get("brainstorm_phase") or "").strip()
    capabilities_used = _normalize_string_list(result.get("capabilities_used"))
    missing_slot = str(result.get("missing_slot") or "").strip()
    base = {
        "question_source": DYNAMIC_QUESTION_SOURCE,
        "brainstorm_phase": phase or "ask_clarifying_question",
        "missing_slot": missing_slot,
        "capabilities_used": capabilities_used,
        "rationale": str(result.get("rationale") or "").strip(),
    }
    if status == "blocked":
        unsupported = result.get("unsupported_capability")
        if isinstance(unsupported, dict) and str(unsupported.get("capability") or "").strip():
            base.update({
                "status": "blocked",
                "unsupported_capability": {
                    "capability": str(unsupported.get("capability") or "").strip(),
                    "domain": str(unsupported.get("domain") or "").strip(),
                },
            })
            return base
    if status == "awaiting_confirmation":
        design = result.get("proposed_design")
        if isinstance(design, dict):
            base.update({"status": "awaiting_confirmation", "proposed_design": design})
            return base
    if status == "needs_clarification":
        question = result.get("question")
        if isinstance(question, dict):
            body = str(question.get("body") or question.get("prompt") or "").strip()
            choices = _normalize_analyzer_choices(question.get("choices"))
            question_id = str(question.get("id") or missing_slot or "dynamic_clarification").strip()
            if body and choices:
                base.update({
                    "status": "needs_clarification",
                    "question": {
                        "id": question_id,
                        "title": str(question.get("title") or "补充一个细节").strip(),
                        "prompt": body,
                        "coverage": missing_slot or question_id,
                        "choices": choices,
                    },
                })
                return base
    return _fallback_analyzer_result(state, "Analyzer returned invalid JSON shape.")


def _run_brainstorming_analyzer(state: Dict[str, Any]) -> Dict[str, Any]:
    payload = {
        "user_goal": str(state.get("user_goal") or "").strip(),
        "answers": _answered_summary(state),
        "pending_question": state.get("pending_question") if isinstance(state.get("pending_question"), dict) else {},
        "capability_context": load_capability_prompt_bundle(),
    }
    messages = [
        {"role": "system", "content": GENSKILLS_ANALYZER_SYSTEM_PROMPT},
        {"role": "user", "content": json.dumps(payload, ensure_ascii=False, indent=2)},
    ]
    try:
        from agent.auxiliary_client import call_llm

        response = call_llm(
            task="genskills_planning",
            messages=messages,
            temperature=0,
            max_tokens=1200,
            timeout=20,
        )
    except Exception as exc:
        return _fallback_analyzer_result(state, f"Dynamic analyzer unavailable: {exc}")
    parsed = _json_object_from_text(_response_content(response))
    return _normalize_analyzer_result(state, parsed)


def _resolve_choice_answer(session: Dict[str, Any], raw_answer: str) -> str:
    text = raw_answer.strip()
    if not text:
        return ""
    pending_id = str(session.get("pending_question_id") or "").strip()
    pending = _question_by_id(session, pending_id)
    if not pending:
        return text
    choices = list(pending.get("choices") or [])[:3]
    numeric = re.match(r"^([1-3])(?:[.、)]|\s|$)", text)
    if numeric:
        index = int(numeric.group(1)) - 1
        if 0 <= index < len(choices):
            return _choice_value(choices[index])
    for index, choice in enumerate(choices):
        labels = {
            _choice_label(choice),
            _choice_value(choice),
            f"{index + 1}. {_choice_label(choice)}",
            f"{index + 1}、{_choice_label(choice)}",
        }
        if text in labels:
            return _choice_value(choice)
    return text


def _is_vague(value: str) -> bool:
    text = value.strip()
    if not text:
        return True
    return bool(VAGUE_RE.match(text))


def _is_clear_goal(value: str) -> bool:
    text = value.strip()
    if _is_vague(text):
        return False
    if re.search(r"[\u4e00-\u9fff]", text):
        return len(re.findall(r"[\u4e00-\u9fff]", text)) >= 3
    return len([part for part in re.split(r"\s+", text) if part]) >= 3


def _slugify(value: str, fallback: str = "saved-workflow") -> str:
    text = value.lower()
    # Preserve ASCII safety for Hermes skill names.
    slug = re.sub(r"[^a-z0-9]+", "-", text).strip("-")
    if not slug:
        # Deterministic enough for non-ASCII goals while staying readable.
        ascii_hint = re.sub(r"\W+", "-", value.encode("utf-8").hex()[:24]).strip("-")
        slug = ascii_hint or fallback
    slug = re.sub(r"-{2,}", "-", slug)[:56].strip("-")
    return slug or fallback


def _normalize_string_list(value: Any) -> List[str]:
    if isinstance(value, str):
        return [value.strip()] if value.strip() else []
    if not isinstance(value, list):
        return []
    return [str(item).strip() for item in value if str(item).strip()]


def _workflow_parts_from_answer(answer: Any) -> List[str]:
    if not isinstance(answer, dict):
        return []
    return _normalize_string_list(answer.get("workflow_parts"))[:5]


def _artifacts_from_workflow_parts(parts: List[str]) -> List[Dict[str, Any]]:
    artifacts: List[Dict[str, Any]] = []
    for index, part in enumerate(parts):
        artifacts.append({
            "type": "skill",
            "id": f"workflow_part_{index + 1}",
            "user_facing_label": part,
            "user_goal": part,
            "requires_user_confirmation": True,
        })
    if len(artifacts) > 1:
        artifacts.append({
            "type": "skill",
            "id": "orchestrator",
            "user_facing_label": "协调完整流程",
            "user_goal": "按用户确认的顺序协调这些步骤。",
            "requires_user_confirmation": True,
        })
    return artifacts


def _derive_cron_schedule(text: str) -> str:
    hour_match = re.search(r"([0-2]?\d)\s*(?:点|:|：)", text)
    hour = int(hour_match.group(1)) if hour_match else 9
    hour = max(0, min(23, hour))
    if re.search(r"(周日|星期日|礼拜日|sunday)", text, re.I):
        return f"0 {hour} * * 0"
    if re.search(r"(周一|星期一|礼拜一|monday)", text, re.I):
        return f"0 {hour} * * 1"
    if re.search(r"(周二|星期二|礼拜二|tuesday)", text, re.I):
        return f"0 {hour} * * 2"
    if re.search(r"(周三|星期三|礼拜三|wednesday)", text, re.I):
        return f"0 {hour} * * 3"
    if re.search(r"(周四|星期四|礼拜四|thursday)", text, re.I):
        return f"0 {hour} * * 4"
    if re.search(r"(周五|星期五|礼拜五|friday)", text, re.I):
        return f"0 {hour} * * 5"
    if re.search(r"(周六|星期六|礼拜六|saturday)", text, re.I):
        return f"0 {hour} * * 6"
    if re.search(r"(每周|weekly)", text, re.I):
        return f"0 {hour} * * 0"
    if re.search(r"(每月|monthly)", text, re.I):
        return f"0 {hour} 1 * *"
    return f"0 {hour} * * *"


def _normalize_search_text(value: str) -> str:
    return re.sub(r"\s+", "", value.lower())


def _score_existing_skill(goal: str, skill: Dict[str, Any]) -> int:
    goal_text = _normalize_search_text(goal)
    haystacks = [
        str(skill.get("name") or ""),
        str(skill.get("description") or ""),
        str(skill.get("category") or ""),
    ]
    score = 0
    for raw in haystacks:
        text = _normalize_search_text(raw)
        if not text:
            continue
        if text == goal_text:
            score += 12
        if goal_text in text or text in goal_text:
            score += 6
    for token in re.split(r"[_，,。:：\-、\s]+", goal):
        token = _normalize_search_text(token)
        if len(token) < 2:
            continue
        if any(token in _normalize_search_text(raw) for raw in haystacks):
            score += 2
    return score


def _find_similar_skills(goal: str, limit: int = 3) -> List[Dict[str, Any]]:
    try:
        from tools.skills_tool import _find_all_skills

        skills = _find_all_skills()
    except Exception:
        skills = []
    ranked = [
        (skill, _score_existing_skill(goal, skill))
        for skill in skills
        if isinstance(skill, dict)
    ]
    return [
        {
            "name": str(skill.get("name") or ""),
            "description": str(skill.get("description") or ""),
            "category": str(skill.get("category") or ""),
        }
        for skill, score in sorted(ranked, key=lambda item: item[1], reverse=True)
        if score >= 6 and str(skill.get("name") or "").strip()
    ][:limit]


def _answered_by_id(session: Dict[str, Any]) -> Dict[str, str]:
    answers = session.get("answers") if isinstance(session.get("answers"), list) else []
    out: Dict[str, str] = {}
    for item in answers:
        if not isinstance(item, dict):
            continue
        question_id = str(item.get("question_id") or "").strip()
        answer = str(item.get("answer") or "").strip()
        if question_id and answer:
            out[question_id] = answer
    return out


def _coverage_report(session: Dict[str, Any]) -> Dict[str, Any]:
    by_id = _answered_by_id(session)
    covered = [str(item.get("question") or item.get("question_id") or "") for item in (session.get("answers") or []) if isinstance(item, dict)]
    missing = []
    pending_slot = str(session.get("missing_slot") or "").strip()
    if pending_slot and session.get("phase") != "confirm":
        missing.append(pending_slot)
    if by_id.get("approach_choice"):
        covered.append(APPROACH_QUESTION["coverage"])
    return {
        "complete": bool(session.get("phase") == "confirm" or session.get("plan") or not missing),
        "covered": covered,
        "missing": missing,
    }


def _choice_label(choice: Any) -> str:
    if isinstance(choice, dict):
        return str(choice.get("label") or choice.get("value") or choice.get("id") or "").strip()
    return str(choice).strip()


def _choice_value(choice: Any) -> str:
    if isinstance(choice, dict):
        return str(choice.get("value") or choice.get("label") or choice.get("id") or "").strip()
    return str(choice).strip()


def _pending_choice(choice: Any, index: int, style: str = "secondary") -> Dict[str, str]:
    label = _choice_label(choice)
    numbered_label = label if re.match(r"^\d+[.、]\s*", label) else f"{index + 1}. {label}"
    return {
        "id": str(choice.get("id") if isinstance(choice, dict) else f"choice_{index + 1}") or f"choice_{index + 1}",
        "label": numbered_label,
        "value": _choice_value(choice),
        "style": style,
    }


def _pending_interaction(
    *,
    interaction_id: str,
    kind: str,
    title: str,
    body: str,
    choices: List[Any],
    input_meta: Dict[str, Any] | None = None,
) -> Dict[str, Any]:
    return {
        "id": interaction_id,
        "kind": kind,
        "title": title,
        "body": body,
        "risk_level": "low",
        "choices": [
            _pending_choice(choice, index, "primary" if index == 0 else "secondary")
            for index, choice in enumerate(choices[:3])
            if _choice_label(choice)
        ],
        "input": input_meta,
        "status": "pending",
    }


def _question_object(question: Dict[str, Any]) -> Dict[str, Any]:
    return {
        "id": question["id"],
        "prompt": question["prompt"],
        "choices": [f"{index + 1}. {_choice_label(choice)}" for index, choice in enumerate(list(question["choices"])[:3])],
        "allow_other": True,
    }


def _question_payload(session: Dict[str, Any], question: Dict[str, Any]) -> Dict[str, Any]:
    session["phase"] = "clarify"
    session["pending_question_id"] = question["id"]
    session["pending_question"] = question
    session["question_source"] = DYNAMIC_QUESTION_SOURCE
    session["brainstorm_phase"] = str(question.get("brainstorm_phase") or session.get("brainstorm_phase") or "ask_clarifying_question")
    session["missing_slot"] = str(question.get("missing_slot") or question.get("coverage") or "")
    session["capabilities_used"] = _normalize_string_list(question.get("capabilities_used"))
    session["coverage"] = _coverage_report(session)
    question_obj = _question_object(question)
    return {
        "status": "needs_clarification",
        "session": session,
        "question": question_obj,
        "choices": question_obj["choices"],
        "question_id": question["id"],
        "user_display": question["prompt"],
        "question_source": DYNAMIC_QUESTION_SOURCE,
        "brainstorm_phase": session["brainstorm_phase"],
        "missing_slot": session["missing_slot"],
        "capabilities_used": session["capabilities_used"],
        "pending_interaction": _pending_interaction(
            interaction_id=f"{session.get('id', 'genskills')}:{question['id']}",
            kind="clarification",
            title=str(question.get("title") or "补充一个细节"),
            body=question["prompt"],
            choices=list(question["choices"])[:3],
            input_meta={"type": "text", "placeholder": "也可以直接输入你的情况"},
        ),
    }


def _next_question(session: Dict[str, Any]) -> Dict[str, Any] | None:
    by_id = _answered_by_id(session)
    for question in _capability_questions():
        if not by_id.get(question["id"]):
            return question
    return None


def _append_answer(session: Dict[str, Any], question_id: str, question: str, answer: str) -> None:
    answers = session.get("answers")
    if not isinstance(answers, list):
        answers = []
        session["answers"] = answers
    answers.append({
        "question_id": question_id,
        "question": question,
        "answer": answer,
        "answered_at": int(time.time()),
    })
    session["coverage"] = _coverage_report(session)


def _unsupported_capability_payload(state: Dict[str, Any], matches: List[Dict[str, str]]) -> Dict[str, Any]:
    first = matches[0]
    state["phase"] = "blocked"
    state["status"] = "blocked"
    return {
        "status": "blocked",
        "session": state,
        "diagnostics": [{
            "code": "unsupported_capability",
            "message": f"当前不支持：{first['capability']}。",
            "domain": first["domain"],
            "capability": first["capability"],
        }],
        "user_display": f"这个任务里有我现在做不到的能力：{first['capability']}。你可以改成手动输入、截图，或在聊天里提供材料，我再帮你处理。",
        "question_source": DYNAMIC_QUESTION_SOURCE,
        "brainstorm_phase": "explore_context",
        "capability_context": load_capability_prompt_bundle(),
    }


def _build_plan(session: Dict[str, Any], *, approved: bool = False) -> Dict[str, Any]:
    goal = str(session.get("user_goal") or "").strip()
    answers = session.get("answers") if isinstance(session.get("answers"), list) else []
    by_id = _answered_by_id(session)
    design = session.get("proposed_design") if isinstance(session.get("proposed_design"), dict) else {}
    output = str(design.get("output_or_delivery") or by_id.get("output_delivery") or by_id.get("output_or_delivery", "") or "给你一份结果").strip()
    parts = _normalize_string_list(session.get("workflow_parts"))
    design_inputs = _normalize_string_list(design.get("inputs_needed"))
    input_answer = (", ".join(design_inputs) if design_inputs else "") or by_id.get("input_modality") or by_id.get("input_example") or by_id.get("inputs_needed") or "执行时你在聊天里提供需要处理的内容。"
    processing_answer = str(design.get("processing_action") or by_id.get("processing_action") or "按用户当次说明处理").strip()
    memory_answer = str(design.get("memory_scope") or by_id.get("memory_scope") or "只保存流程，不保存具体数据").strip()
    boundary_answer = "只处理你提供的信息，不直接操作外部账号"
    failure_answer = str(design.get("failure_handling") or by_id.get("failure_handling", "") or "缺少必要内容时，执行时再问你补充。").strip()
    approach = by_id.get("approach_choice", "")
    design_steps = _normalize_string_list(design.get("steps"))
    steps = design_steps or [
        f"确认这次要处理的任务：{goal}。",
        f"输入材料：{input_answer}。",
        f"加工方式：{processing_answer}。",
        f"记忆边界：{memory_answer}。",
        f"交付结果：{output}。",
    ]
    if len(parts) > 1 and approach == "分成几步":
        steps = [
            f"先完成：{part}。"
            for part in parts
        ] + ["汇总各步骤结果，交给用户检查。"]
    constraints = [
        "保存前必须得到用户确认。",
        "不编造不存在的外部账号、服务或自动化能力。",
        boundary_answer,
    ]
    constraints.extend(_normalize_string_list(design.get("constraints")))
    if failure_answer:
        constraints.append(f"缺少内容时：{failure_answer}。")
    plan = {
        "id": session.get("plan_id") or _now_id("generic-plan"),
        "approved": approved,
        "user_goal": goal,
        "plain_language_summary": f"以后按固定步骤处理：{goal}",
        "clarified_requirements": answers,
        "inputs_needed": _normalize_string_list(input_answer),
        "steps": steps,
        "tools_required": [],
        "capability_context": load_capability_prompt_bundle(),
        "permissions_or_accounts": [boundary_answer],
        "schedule_or_trigger": str(design.get("schedule_or_trigger") or by_id.get("start_mode") or by_id.get("schedule_or_trigger", "你需要时手动触发。")).strip(),
        "output_or_delivery": output,
        "user_confirmation_required": True,
        "constraints": constraints,
        "failure_handling": failure_answer or "缺少必要内容时先告诉用户还缺什么。",
        "memory_scope": memory_answer,
        "processing_action": processing_answer,
        "design_completeness": session.get("design_completeness") if isinstance(session.get("design_completeness"), dict) else {
            "source": "not_checked",
            "missing_fields": [],
        },
        "approach_choice": approach or "简单稳妥",
        "acceptance_criteria": _normalize_string_list(design.get("acceptance_criteria")) or [
            "用户能用一句话再次触发这个做法。",
            "缺少必要输入时会先说明还缺什么。",
            "不会使用能力文档里标为 unsupported 的外部能力。",
        ],
    }
    artifacts = _artifacts_from_workflow_parts(parts) if len(parts) > 1 else []
    if artifacts:
        plan["artifacts"] = artifacts
    return plan


def _confirmation_payload(
    state: Dict[str, Any],
    plan: Dict[str, Any],
    *,
    session_id: str = "",
    task_id: str = "",
) -> Dict[str, Any]:
    state["phase"] = "confirm"
    state["status"] = "awaiting_confirmation"
    state["pending_question_id"] = CONFIRMATION_QUESTION["id"]
    state["plan"] = plan
    state["plan_document"] = plan
    state["coverage"] = _coverage_report(state)
    ref = _plan_ref(state, plan, session_id=session_id, task_id=task_id)
    by_id = _answered_by_id(state)
    summary_lines = [
        "用户交互流程描述",
        f"任务：{plan['user_goal']}",
        f"1. 用户提供材料：{', '.join(plan['inputs_needed']) or '执行时再问你'}。",
        f"2. 处理方式：{plan.get('processing_action', '执行时再确认')}。",
        f"3. 开始方式：{plan['schedule_or_trigger']}。",
        f"4. 记忆边界：{plan.get('memory_scope', '只保存流程，不保存具体数据')}。",
        f"5. 完成后：{plan['output_or_delivery']}。",
        f"6. 能力边界：{', '.join(plan['permissions_or_accounts']) or '只处理你提供的信息'}。",
    ]
    summary = "\n".join(summary_lines)
    pending = _pending_interaction(
        interaction_id=f"{state.get('id', 'genskills')}:confirm",
        kind="confirmation",
        title="确认创建任务",
        body=summary,
        choices=list(CONFIRMATION_QUESTION["choices"]),
    )
    return {
        "status": "awaiting_confirmation",
        "session": state,
        "plan": plan,
        "plan_document": plan,
        "plan_ref": ref,
        "summary": summary,
        "user_display": summary,
        "confirmation_question": "这样创建可以吗？",
        "question_source": DYNAMIC_QUESTION_SOURCE,
        "brainstorm_phase": "present_design",
        "missing_slot": "",
        "capabilities_used": _normalize_string_list(state.get("capabilities_used")),
        "pending_interaction": pending,
    }


def _payload_from_analyzer(
    state: Dict[str, Any],
    analysis: Dict[str, Any],
    *,
    session_id: str = "",
    task_id: str = "",
) -> Dict[str, Any]:
    status = str(analysis.get("status") or "").strip()
    state["question_source"] = DYNAMIC_QUESTION_SOURCE
    state["brainstorm_phase"] = str(analysis.get("brainstorm_phase") or "ask_clarifying_question")
    state["missing_slot"] = str(analysis.get("missing_slot") or "")
    state["capabilities_used"] = _normalize_string_list(analysis.get("capabilities_used"))
    if status == "blocked":
        if str(analysis.get("diagnostic_code") or "") == "planning_analyzer_failed":
            return _planning_analyzer_failed_payload(state, str(analysis.get("rationale") or "Dynamic analyzer failed."))
        unsupported = analysis.get("unsupported_capability") if isinstance(analysis.get("unsupported_capability"), dict) else {}
        return _unsupported_capability_payload(state, [{
            "domain": str(unsupported.get("domain") or ""),
            "capability": str(unsupported.get("capability") or "当前能力"),
        }])
    if status == "awaiting_confirmation":
        design = analysis.get("proposed_design") if isinstance(analysis.get("proposed_design"), dict) else {}
        missing = _missing_proposed_design_fields(design)
        if missing:
            return _invalid_proposed_design_payload(state, design)
        state["proposed_design"] = design
        state["design_completeness"] = {
            "source": "analyzer_proposed_design",
            "missing_fields": [],
        }
        plan = _build_plan(state, approved=False)
        return _confirmation_payload(state, plan, session_id=session_id, task_id=task_id)
    question = analysis.get("question") if isinstance(analysis.get("question"), dict) else {}
    question = dict(question)
    question["brainstorm_phase"] = state["brainstorm_phase"]
    question["missing_slot"] = state["missing_slot"]
    question["capabilities_used"] = state["capabilities_used"]
    return _question_payload(state, question)


def generic_plan(
    goal: str = "",
    session: Dict[str, Any] | None = None,
    answer: Any = None,
    approval: Dict[str, Any] | None = None,
    session_id: str = "",
    task_id: str = "",
) -> str:
    """Maintain a small reusable-workflow planning session."""
    state = dict(_as_record(session))
    trimmed_goal = goal.strip()
    if not trimmed_goal and not str(state.get("user_goal") or "").strip():
        recovered = _recover_planning_state(state, session_id=session_id, task_id=task_id)
        if recovered:
            state = recovered
    if not state:
        state = {
            "id": task_id or session_id or _now_id("genskills"),
            "phase": "reuse_check" if trimmed_goal else "capture_goal",
            "status": "planning",
            "user_goal": trimmed_goal,
            "answers": [],
            "matched_skills": [],
            "coverage": {"complete": False, "covered": [], "missing": []},
        }
        if session_id:
            state["runtime_session_id"] = session_id
        if task_id:
            state["runtime_task_id"] = task_id
    elif goal.strip() and not str(state.get("user_goal") or "").strip():
        state["user_goal"] = goal.strip()
    if session_id:
        state["runtime_session_id"] = session_id
    if task_id:
        state["runtime_task_id"] = task_id
    state.setdefault("phase", "capture_goal" if not str(state.get("user_goal") or "").strip() else "clarify")
    state.setdefault("matched_skills", [])
    state.setdefault("answers", [])

    answers = state.get("answers")
    if not isinstance(answers, list):
        answers = []
        state["answers"] = answers

    answer_text = _resolve_choice_answer(state, _answer_text(answer))
    if answer_text and not str(state.get("user_goal") or "").strip():
        if _is_clear_goal(answer_text):
            state["user_goal"] = answer_text
            state["phase"] = "reuse_check"
        else:
            state["phase"] = "capture_goal"

    goal_text = str(state.get("user_goal") or "").strip()

    if not _is_clear_goal(goal_text):
        state["user_goal"] = ""
        state["phase"] = "capture_goal"
        state["coverage"] = _coverage_report(state)
        return _plan_json({
            "status": "needs_goal",
            "session": state,
            "question": GOAL_QUESTION,
            "choices": [],
            "user_display": GOAL_QUESTION,
        })

    unsupported_goal = load_capability_registry().unsupported_matches(goal_text)
    if unsupported_goal:
        return _plan_json(_unsupported_capability_payload(state, unsupported_goal))

    if approval:
        approved = bool(approval.get("approved"))
        feedback = str(approval.get("feedback") or "").strip()
        if approved:
            plan = state.get("plan") if isinstance(state.get("plan"), dict) else _build_plan(state)
            plan["approved"] = True
            ref = _plan_ref(state, plan, session_id=session_id, task_id=task_id)
            plan["plan_ref"] = ref
            _store_approved_plan(plan, ref)
            state["phase"] = "approved"
            state["status"] = "approved"
            state["plan"] = plan
            return _plan_json({
                "status": "approved",
                "session": state,
                "plan": plan,
                "plan_ref": ref,
                "user_display": "好的，我会按这份确认后的步骤来保存这个做法。",
                "next_tool": {"name": "generic_generate_skill", "input": {"plan": plan, "plan_ref": ref, "persist": True}},
            }, next_stage="generate_skill")
        state["status"] = "planning"
        if feedback:
            _append_answer(state, "approval_feedback", "用户希望修改哪里？", feedback)
        state.pop("plan", None)
        return _plan_json(_question_payload(state, REVISION_QUESTION))

    if state.get("phase") == "reuse_check":
        matched = state.get("matched_skills") if isinstance(state.get("matched_skills"), list) else []
        if not matched:
            matched = _find_similar_skills(goal_text)
            state["matched_skills"] = matched
        if matched and not answer_text:
            state["status"] = "reuse_choice"
            return _plan_json({
                "status": "reuse_choice",
                "session": state,
                "question": "已经有相似做法，你想怎么处理？",
                "choices": REUSE_CHOICES,
                "matched_skills": matched,
                "user_display": "已经有相似做法，你想怎么处理？",
            })
        if answer_text in {"直接用", "direct", "execute"}:
            state["phase"] = "done"
            state["status"] = "blocked"
            return _plan_json({
                "status": "blocked",
                "session": state,
                "diagnostics": [{"code": "reuse_existing", "message": "用户选择直接使用已有做法。"}],
                "user_display": "可以直接使用已有做法，我不会重复保存。",
            })
        if answer_text in {"改一下", "新建", "revise", "create_new"} or not matched:
            state["phase"] = "clarify"

    if state.get("phase") == "confirm" and answer_text:
        normalized_answer = answer_text.strip().lower()
        workflow_parts = _workflow_parts_from_answer(answer)
        if workflow_parts:
            state["workflow_parts"] = workflow_parts
            _append_answer(state, "approach_choice", "这个做法是否需要分成几步？", answer_text)
            plan = _build_plan(state, approved=False)
            return _plan_json(_confirmation_payload(state, plan, session_id=session_id, task_id=task_id))
        if answer_text in SAVE_APPROVAL_ANSWERS or normalized_answer in SAVE_APPROVAL_ANSWERS:
            plan = state.get("plan") if isinstance(state.get("plan"), dict) else _build_plan(state)
            plan["approved"] = True
            ref = _plan_ref(state, plan, session_id=session_id, task_id=task_id)
            plan["plan_ref"] = ref
            _store_approved_plan(plan, ref)
            state["phase"] = "approved"
            state["status"] = "approved"
            state["plan"] = plan
            return _plan_json({
                "status": "approved",
                "session": state,
                "plan": plan,
                "plan_ref": ref,
                "user_display": "好的，我会按这份确认后的步骤来保存这个做法。",
                "next_tool": {"name": "generic_generate_skill", "input": {"plan": plan, "plan_ref": ref, "persist": True}},
            }, next_stage="generate_skill")
        if answer_text in DETAIL_ANSWERS or normalized_answer in DETAIL_ANSWERS:
            state.pop("plan", None)
            return _plan_json(_question_payload(state, REVISION_QUESTION))
        if answer_text in REWRITE_ANSWERS or normalized_answer in REWRITE_ANSWERS:
            state["user_goal"] = ""
            state["phase"] = "capture_goal"
            state.pop("plan", None)
            return _plan_json({
                "status": "needs_goal",
                "session": state,
                "question": GOAL_QUESTION,
                "choices": [],
                "user_display": GOAL_QUESTION,
            })

    if answer_text and state.get("phase") != "reuse_check":
        unsupported_answer = load_capability_registry().unsupported_matches(answer_text)
        if unsupported_answer:
            return _plan_json(_unsupported_capability_payload(state, unsupported_answer))
        pending_id = str(state.get("pending_question_id") or "").strip()
        pending = _question_by_id(state, pending_id)
        if pending and not _is_vague(answer_text):
            workflow_parts = _workflow_parts_from_answer(answer)
            if workflow_parts:
                state["workflow_parts"] = workflow_parts
            _append_answer(state, pending["id"], pending["prompt"], answer_text)
            state.pop("pending_question_id", None)
            state.pop("pending_question", None)
            analysis = _run_brainstorming_analyzer(state)
            return _plan_json(_payload_from_analyzer(state, analysis, session_id=session_id, task_id=task_id))
        elif pending and _is_vague(answer_text):
            analysis = _run_brainstorming_analyzer(state)
            return _plan_json(_payload_from_analyzer(state, analysis, session_id=session_id, task_id=task_id))

    analysis = _run_brainstorming_analyzer(state)
    return _plan_json(_payload_from_analyzer(state, analysis, session_id=session_id, task_id=task_id))


def _available_tool_names() -> set[str]:
    try:
        return {entry.name for entry in registry._snapshot_entries()}  # type: ignore[attr-defined]
    except Exception:
        return set()


def _validate_frontmatter(content: str) -> str | None:
    if not content.startswith("---\n"):
        return "保存内容缺少开头信息。"
    end = content.find("\n---\n", 4)
    if end < 0:
        return "保存内容的开头信息没有正确结束。"
    try:
        parsed = yaml.safe_load(content[4:end]) or {}
    except Exception as exc:
        return f"保存内容的开头信息格式不正确：{exc}"
    if not isinstance(parsed, dict):
        return "保存内容的开头信息不是有效结构。"
    if not str(parsed.get("name") or "").strip():
        return "保存内容缺少名称。"
    if not str(parsed.get("description") or "").strip():
        return "保存内容缺少说明。"
    if not content[end + 5:].strip():
        return "保存内容缺少具体步骤。"
    return None


REQUIRED_GENERATED_SECTIONS = [
    "## When to Use",
    "## Inputs",
    "## Workflow",
    "## Confirmation and Boundaries",
    "## Failure Handling",
    "## Acceptance Criteria",
]


def _validate_generated_sections(content: str) -> str | None:
    missing = [section for section in REQUIRED_GENERATED_SECTIONS if section not in content]
    if missing:
        return f"保存内容缺少必要部分：{', '.join(missing)}"
    return None


def _blocked(code: str, message: str, user_display: str, debug_stage: str | None = "generate_skill", **extra: Any) -> str:
    payload: Dict[str, Any] = {
        "status": "blocked",
        "diagnostics": [{"code": code, "message": message}],
        "user_display": user_display,
    }
    if debug_stage:
        payload["debug_stage"] = debug_stage
    payload.update(extra)
    return _json(payload)


def _reload_skills_summary() -> Dict[str, Any]:
    try:
        from agent.skill_commands import reload_skills

        result = reload_skills()
        return {
            "added": result.get("added", []),
            "removed": result.get("removed", []),
            "total": int(result.get("total", 0) or 0),
            "commands": int(result.get("commands", 0) or 0),
        }
    except Exception as exc:
        try:
            from tools.skills_tool import _find_all_skills

            skills = _find_all_skills()
            return {"added": [], "removed": [], "total": len(skills), "commands": len(skills), "warning": str(exc)}
        except Exception:
            return {"added": [], "removed": [], "total": 0, "commands": 0, "warning": str(exc)}


def _validate_skill_markdown(markdown: str, code: str = "invalid_skill_markdown") -> str | None:
    return _validate_frontmatter(markdown) or _validate_generated_sections(markdown)


def _render_skill_markdown(plan: Dict[str, Any], name: str, description: str) -> str:
    triggers = [plan["user_goal"], plan.get("schedule_or_trigger", ""), plan.get("output_or_delivery", "")]
    triggers = [str(item).strip() for item in triggers if str(item).strip()]
    steps = _normalize_string_list(plan.get("steps")) or ["确认输入。", "处理任务。", "交付结果。"]
    constraints = _normalize_string_list(plan.get("constraints"))
    criteria = _normalize_string_list(plan.get("acceptance_criteria"))
    return "\n".join([
        "---",
        f"name: {json.dumps(name, ensure_ascii=False)}",
        f"description: {json.dumps(description, ensure_ascii=False)}",
        "version: 1.0.0",
        "author: Hermes Agent",
        "license: MIT",
        "metadata:",
        "  hermes:",
        "    tags: [generated, reusable-workflow]",
        "---",
        "",
        f"# {plan['user_goal']}",
        "",
        "## When to Use",
        *[f"- {trigger}" for trigger in triggers],
        "",
        "## Inputs",
        *[f"- {item}" for item in (_normalize_string_list(plan.get("inputs_needed")) or ["使用时由用户提供必要内容。"])],
        "",
        "## Workflow",
        *[f"{idx + 1}. {step}" for idx, step in enumerate(steps)],
        "",
        "## Confirmation and Boundaries",
        "- Stay within the genskills capability registry; if the user asks for an unsupported capability, explain the limit and offer a manual fallback.",
        *[f"- {item}" for item in constraints],
        "",
        "## Failure Handling",
        "- If required input is missing, ask for the smallest missing detail.",
        "- If a requested external service or account is unavailable, explain that clearly and offer a manual fallback.",
        "",
        "## Acceptance Criteria",
        *[f"- {item}" for item in (criteria or ["The user can reuse this workflow by asking for it directly."])],
    ])


def _render_orchestrator_skill_markdown(
    plan: Dict[str, Any],
    name: str,
    description: str,
    child_skills: List[Dict[str, str]],
) -> str:
    child_lines = [
        f"{idx + 2}. Load `{child['name']}` with `skill_view` and complete its workflow."
        for idx, child in enumerate(child_skills)
    ]
    review_step = f"{len(child_skills) + 2}. Summarize the combined result and ask the user to review it before any risky external action."
    child_refs = [f"- `{child['name']}`: {child['goal']}" for child in child_skills]
    return "\n".join([
        "---",
        f"name: {json.dumps(name, ensure_ascii=False)}",
        f"description: {json.dumps(description, ensure_ascii=False)}",
        "version: 1.0.0",
        "author: Hermes Agent",
        "license: MIT",
        "metadata:",
        "  hermes:",
        "    tags: [generated, reusable-workflow, orchestrator]",
        "---",
        "",
        f"# {plan['user_goal']}",
        "",
        "## When to Use",
        f"- {plan['user_goal']}",
        "- Use this orchestrator when the goal has multiple reusable parts that should run together.",
        "",
        "## Inputs",
        *[f"- {item}" for item in (_normalize_string_list(plan.get("inputs_needed")) or ["使用时由用户提供必要内容。"])],
        "",
        "## Child Skills",
        *child_refs,
        "",
        "## Workflow",
        "1. Confirm the user's current goal and inputs.",
        *child_lines,
        review_step,
        "",
        "## Confirmation and Boundaries",
        "- Stay within the genskills capability registry; if the user asks for an unsupported capability, explain the limit and offer a manual fallback.",
        *[f"- {item}" for item in _normalize_string_list(plan.get("constraints"))],
        "",
        "## Failure Handling",
        "- If any child skill is missing, call `skills_list` or ask the user to regenerate the reusable workflow.",
        "- If a child step is blocked by missing tools or inputs, stop and ask for the smallest missing detail.",
        "",
        "## Acceptance Criteria",
        "- Each child skill can be used independently.",
        "- The orchestrator can combine child skill outputs into one user-facing result.",
        *[f"- {item}" for item in _normalize_string_list(plan.get("acceptance_criteria"))],
    ])


def _skill_payload(name: str, description: str, markdown: str) -> Dict[str, str]:
    return {
        "name": name,
        "description": description[:1000],
        "markdown": markdown,
    }


def _artifact_child_plans(plan: Dict[str, Any], artifacts: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    child_plans: List[Dict[str, Any]] = []
    for artifact in artifacts:
        kind = str(artifact.get("type") or "").strip()
        artifact_id = str(artifact.get("id") or "").strip()
        if kind != "skill" or artifact_id == "orchestrator":
            continue
        goal = str(
            artifact.get("user_goal")
            or artifact.get("purpose")
            or artifact.get("user_facing_label")
            or ""
        ).strip()
        if not goal:
            continue
        label = str(artifact.get("user_facing_label") or goal).strip()
        purpose = str(artifact.get("purpose") or label).strip()
        child_plans.append({
            "user_goal": goal,
            "plain_language_summary": label,
            "steps": [
                "确认这一步需要的输入。",
                purpose,
                "把结果交给用户检查或交给下一步使用。",
            ],
            "tools_required": _normalize_string_list(artifact.get("tools_required")),
            "constraints": plan.get("constraints", []),
            "acceptance_criteria": [
                f"能独立完成：{label}",
                "缺少输入时会先说明还缺什么。",
            ],
        })
    return child_plans


def _schedule_artifact(artifacts: List[Dict[str, Any]]) -> Dict[str, Any] | None:
    for artifact in artifacts:
        if str(artifact.get("type") or "").strip() in {"cronjob", "schedule"}:
            return artifact
    return None


def _call_cronjob_tool(**kwargs: Any) -> Dict[str, Any]:
    from tools.cronjob_tools import cronjob

    raw = cronjob(**kwargs)
    try:
        parsed = json.loads(raw)
    except Exception:
        return {"success": False, "error": str(raw)}
    return parsed if isinstance(parsed, dict) else {"success": False, "error": str(parsed)}


def _remove_written_skill_paths(paths: List[Path]) -> None:
    for path in reversed(paths):
        try:
            path.unlink()
        except FileNotFoundError:
            pass
        except Exception:
            pass
        try:
            path.parent.rmdir()
        except Exception:
            pass


def _write_skill_paths_atomically(pending_writes: List[tuple[Path, str]]) -> tuple[bool, str, List[str]]:
    written_paths: List[Path] = []
    current_path: Path | None = None
    try:
        for path, content in pending_writes:
            current_path = path
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content + "\n", encoding="utf-8")
            written_paths.append(path)
            current_path = None
        return True, "", [str(path) for path in written_paths]
    except Exception as exc:
        _remove_written_skill_paths(written_paths)
        if current_path is not None:
            try:
                current_path.parent.rmdir()
            except Exception:
                pass
        return False, str(exc), []


def _find_cron_name_conflict(schedule: Dict[str, Any]) -> Dict[str, Any] | None:
    name = str(schedule.get("name") or schedule.get("user_facing_label") or "").strip()
    if not name:
        return None
    listed = _call_cronjob_tool(action="list", include_disabled=True)
    if not bool(listed.get("success", True)):
        return None
    jobs = listed.get("jobs") if isinstance(listed.get("jobs"), list) else []
    for job in jobs:
        if not isinstance(job, dict):
            continue
        if str(job.get("name") or "").strip() == name:
            return job
    return None


def generic_generate_skill(
    plan: Dict[str, Any] | None = None,
    plan_ref: Dict[str, Any] | None = None,
    session: Dict[str, Any] | None = None,
    persist: bool = True,
    category: str = "productivity",
    output_path: str = "",
    session_id: str = "",
    task_id: str = "",
) -> str:
    """Generate and optionally persist a Hermes SKILL.md from an approved plan."""
    plan = _as_record(plan)
    session_record = _as_record(session)
    if not plan and isinstance(session_record.get("plan"), dict):
        plan = dict(session_record["plan"])
    if not plan or not str(plan.get("user_goal") or "").strip():
        ref = _as_record(plan_ref)
        if not ref:
            ref = {
                "session_id": str(session_id or session_record.get("runtime_session_id") or session_record.get("id") or "").strip(),
                "task_id": str(task_id or session_record.get("runtime_task_id") or session_record.get("id") or "").strip(),
                "plan_id": str(session_record.get("plan", {}).get("id") if isinstance(session_record.get("plan"), dict) else "").strip(),
            }
        recovered = _recover_approved_plan(ref)
        if recovered:
            plan = recovered
    goal = str(plan.get("user_goal") or "").strip()
    if not goal:
        return _blocked(
            "plan_handoff_failed",
            "保存阶段没有收到已确认的计划，也无法从当前会话恢复。",
            "保存步骤接力失败，请重新确认一次后再保存。",
        )
    if not bool(plan.get("approved")):
        return _blocked(
            "plan_not_approved",
            "用户还没有确认这份做法说明。",
            "还没有得到你的确认，暂时不能保存这个做法。",
        )

    missing_tools = [
        name for name in _normalize_string_list(plan.get("tools_required"))
        if name not in _available_tool_names()
    ]
    if missing_tools:
        return _blocked(
            "missing_tools",
            f"引用了当前不可用的能力：{', '.join(missing_tools)}",
            "这个做法里有我现在还不能使用的能力，所以暂时不能保存。",
        )

    risk_text = " ".join([
        goal,
        str(plan.get("output_or_delivery") or ""),
        " ".join(_normalize_string_list(plan.get("steps"))),
    ])
    unsupported_plan_capabilities = load_capability_registry().unsupported_matches(risk_text)
    if unsupported_plan_capabilities:
        first = unsupported_plan_capabilities[0]
        return _blocked(
            "unsupported_capability",
            f"计划引用了当前不可用的能力：{first['capability']}。",
            f"这个做法里有我现在做不到的能力：{first['capability']}。请先修改任务说明。",
        )

    raw_artifacts = plan.get("artifacts")
    artifacts = [item for item in raw_artifacts if isinstance(item, dict)] if isinstance(raw_artifacts, list) else []
    artifact_children = _artifact_child_plans(plan, artifacts)
    if artifact_children:
        return _generate_artifact_bundle(
            plan=plan,
            artifacts=artifacts,
            child_plans=artifact_children,
            persist=persist,
            category=category,
            output_path=output_path,
        )

    raw_children = plan.get("skills_to_generate")
    child_plans = [item for item in raw_children if isinstance(item, dict)] if isinstance(raw_children, list) else []
    if child_plans:
        return _generate_skill_bundle(
            plan=plan,
            child_plans=child_plans,
            persist=persist,
            category=category,
            output_path=output_path,
        )

    name = _slugify(goal)
    description = f"Use when the user wants to reuse this confirmed workflow: {goal}"
    markdown = _render_skill_markdown(plan, name, description[:1000])
    validation_error = _validate_skill_markdown(markdown)
    if validation_error:
        return _blocked("invalid_skill_markdown", validation_error, validation_error)

    saved_path = ""
    reload_summary: Dict[str, Any] = {"added": [], "removed": [], "total": 0, "commands": 0}
    if persist:
        if output_path:
            path = Path(output_path).expanduser()
        else:
            from tools.skills_tool import SKILLS_DIR
            path = SKILLS_DIR / category / name / "SKILL.md"
        if path.exists():
            return _blocked(
                "name_conflict",
                f"已经存在同名做法：{name}",
                "已经有同名做法，暂时不会覆盖。请换一个名称或先修改已有做法。",
            )
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(markdown + "\n", encoding="utf-8")
        saved_path = str(path)
        reload_summary = _reload_skills_summary()

    return _json({
        "status": "generated",
        "debug_stage": "generate_skill",
        "skill": _skill_payload(name, description, markdown),
        "output_path": saved_path,
        "reload": reload_summary,
        "user_display": "已保存这个做法，以后可以直接让我按这个来。",
    })


def _generate_artifact_bundle(
    *,
    plan: Dict[str, Any],
    artifacts: List[Dict[str, Any]],
    child_plans: List[Dict[str, Any]],
    persist: bool,
    category: str,
    output_path: str,
) -> str:
    schedule = _schedule_artifact(artifacts)
    if schedule and not bool(schedule.get("requires_user_confirmation", True)):
        return _blocked(
            "schedule_confirmation_required",
            "定时任务需要用户确认后才能创建或更新。",
            "定时提醒需要先得到你的确认，暂时不能保存。",
        )
    if schedule:
        schedule_text = str(schedule.get("schedule") or schedule.get("trigger") or "").strip()
        if not schedule_text:
            return _blocked(
                "missing_schedule",
                "定时任务缺少时间设置。",
                "还缺少提醒时间，暂时不能创建定时提醒。",
            )
    cron_conflict = _find_cron_name_conflict(schedule) if schedule else None
    if cron_conflict and not bool(schedule.get("update_existing")):
        return _blocked(
            "cron_name_conflict",
            f"已经存在同名提醒：{cron_conflict.get('name')}",
            "已经有同名提醒，暂时不会覆盖。请确认是更新已有提醒，还是换一个名称。",
            existing_cron=cron_conflict,
        )

    generated = json.loads(_generate_skill_bundle(
        plan=plan,
        child_plans=child_plans,
        persist=False,
        category=category,
        output_path=output_path,
    ))
    if generated.get("status") != "generated":
        return _json(generated)

    saved_paths: List[str] = []
    reload_summary: Dict[str, Any] = {"added": [], "removed": [], "total": 0, "commands": 0}
    if persist:
        from tools.skills_tool import SKILLS_DIR

        skills = generated.get("skills") if isinstance(generated.get("skills"), list) else []
        pending_writes: List[tuple[Path, str]] = []
        for skill in skills:
            if not isinstance(skill, dict):
                continue
            name = str(skill.get("name") or "").strip()
            markdown = str(skill.get("markdown") or "")
            if not name or not markdown:
                continue
            if output_path and name == str((generated.get("skill") or {}).get("name") or ""):
                path = Path(output_path).expanduser()
            else:
                path = SKILLS_DIR / category / name / "SKILL.md"
            if path.exists():
                return _blocked(
                    "name_conflict",
                    f"已经存在同名做法：{name}",
                    "已经有同名做法，暂时不会覆盖。请换一个名称或先修改已有做法。",
                )
            pending_writes.append((path, markdown))

        written_paths: List[Path] = []
        cron_failure: Dict[str, Any] | None = None
        ok, write_error, saved_paths = _write_skill_paths_atomically(pending_writes)
        if not ok:
            return _blocked(
                "skill_write_failed",
                write_error or "保存做法文件失败。",
                "保存做法文件失败，所以这次没有保存任何做法。",
            )
        written_paths = [Path(path) for path in saved_paths]

        try:
            if schedule:
                schedule_text = str(schedule.get("schedule") or schedule.get("trigger") or "").strip()
                orchestrator = generated.get("skill") if isinstance(generated.get("skill"), dict) else {}
                skill_name = str(orchestrator.get("name") or "").strip()
                cron_action = "update" if bool(schedule.get("update_existing")) else "create"
                cron_kwargs = {
                    "action": cron_action,
                    "schedule": schedule_text,
                    "name": str(schedule.get("name") or schedule.get("user_facing_label") or plan.get("user_goal") or "保存的做法"),
                    "prompt": str(schedule.get("prompt") or schedule.get("purpose") or "按已保存的做法提醒用户。"),
                    "skills": [skill_name] if skill_name else [],
                }
                if cron_action == "update":
                    cron_kwargs["job_id"] = str(schedule.get("existing_job_id") or schedule.get("job_id") or "").strip()
                    if not cron_kwargs["job_id"]:
                        cron_failure = {"success": False, "error": "更新已有提醒需要 existing_job_id。"}
                    else:
                        cron_summary = _call_cronjob_tool(**cron_kwargs)
                        if not bool(cron_summary.get("success", True)):
                            cron_failure = cron_summary
                        else:
                            generated["cronjobs"] = [cron_summary]
                            generated["cron"] = cron_summary
                else:
                    cron_summary = _call_cronjob_tool(**cron_kwargs)
                    if not bool(cron_summary.get("success", True)):
                        cron_failure = cron_summary
                    else:
                        generated["cronjobs"] = [cron_summary]
                        generated["cron"] = cron_summary

            if cron_failure is None:
                reload_summary = _reload_skills_summary()
        finally:
            if cron_failure is not None:
                _remove_written_skill_paths(written_paths)
                saved_paths = []
        if cron_failure is not None:
            return _blocked(
                "cron_create_failed",
                str(cron_failure.get("error") or "定时提醒创建失败。"),
                "定时提醒创建失败，所以这次没有保存任何做法。",
            )

        generated["output_paths"] = saved_paths
        generated["output_path"] = saved_paths[-1] if saved_paths else ""
        generated["reload"] = reload_summary

    if not persist and schedule:
        orchestrator = generated.get("skill") if isinstance(generated.get("skill"), dict) else {}
        generated["cronjobs"] = [{
            "action": "create",
            "schedule": str(schedule.get("schedule") or schedule.get("trigger") or ""),
            "name": str(schedule.get("name") or schedule.get("user_facing_label") or plan.get("user_goal") or "保存的做法"),
            "skills": [orchestrator.get("name")] if isinstance(orchestrator.get("name"), str) else [],
        }]
    return _json(generated)


def _generate_skill_bundle(
    *,
    plan: Dict[str, Any],
    child_plans: List[Dict[str, Any]],
    persist: bool,
    category: str,
    output_path: str,
) -> str:
    saved_paths: List[str] = []
    skills: List[Dict[str, str]] = []
    child_refs: List[Dict[str, str]] = []
    pending_writes: List[tuple[Path, str]] = []
    used_names: set[str] = set()
    skills_dir: Path | None = None
    if persist:
        from tools.skills_tool import SKILLS_DIR
        skills_dir = SKILLS_DIR

    for index, child in enumerate(child_plans):
        child_goal = str(child.get("user_goal") or child.get("goal") or "").strip()
        if not child_goal:
            return _blocked("missing_child_goal", "有一个子做法缺少目标。", "有一个子做法还不知道要完成什么，暂时不能保存。")
        missing_child_tools = [
            name for name in _normalize_string_list(child.get("tools_required"))
            if name not in _available_tool_names()
        ]
        if missing_child_tools:
            return _blocked(
                "missing_tools",
                f"子做法引用了当前不可用的能力：{', '.join(missing_child_tools)}",
                "这个做法里有我现在还不能使用的能力，所以暂时不能保存。",
            )

        name = _slugify(child_goal)
        if name in used_names:
            name = f"{name}-{index + 1}"
        used_names.add(name)
        description = f"Use this child workflow as part of: {plan.get('user_goal')}"
        child_plan = {
            **plan,
            **child,
            "user_goal": child_goal,
            "inputs_needed": child.get("inputs_needed", plan.get("inputs_needed", [])),
            "constraints": child.get("constraints", plan.get("constraints", [])),
            "acceptance_criteria": child.get("acceptance_criteria", plan.get("acceptance_criteria", [])),
        }
        markdown = _render_skill_markdown(child_plan, name, description[:1000])
        validation_error = _validate_skill_markdown(markdown)
        if validation_error:
            return _blocked("invalid_child_skill_markdown", validation_error, validation_error)
        skills.append(_skill_payload(name, description, markdown))
        child_refs.append({"name": name, "goal": child_goal})
        if persist:
            assert skills_dir is not None
            path = skills_dir / category / name / "SKILL.md"
            if path.exists():
                return _blocked(
                    "name_conflict",
                    f"已经存在同名做法：{name}",
                    "已经有同名做法，暂时不会覆盖。请换一个名称或先修改已有做法。",
                )
            pending_writes.append((path, markdown))

    orchestrator_name = _slugify(str(plan.get("user_goal") or "saved workflow"), "saved-workflow")
    orchestrator_name = f"{orchestrator_name}-workflow"
    description = f"Use this orchestrator to run the reusable workflow: {plan['user_goal']}"
    markdown = _render_orchestrator_skill_markdown(plan, orchestrator_name, description[:1000], child_refs)
    validation_error = _validate_skill_markdown(markdown)
    if validation_error:
        return _blocked("invalid_orchestrator_skill_markdown", validation_error, validation_error)
    orchestrator = _skill_payload(orchestrator_name, description, markdown)
    skills.append(orchestrator)
    saved_path = ""
    reload_summary: Dict[str, Any] = {"added": [], "removed": [], "total": 0, "commands": 0}
    if persist:
        if output_path:
            orchestrator_path = Path(output_path).expanduser()
        else:
            assert skills_dir is not None
            orchestrator_path = skills_dir / category / orchestrator_name / "SKILL.md"
        if orchestrator_path.exists():
            return _blocked(
                "name_conflict",
                f"已经存在同名做法：{orchestrator_name}",
                "已经有同名做法，暂时不会覆盖。请换一个名称或先修改已有做法。",
            )
        pending_writes.append((orchestrator_path, markdown))

        ok, write_error, saved_paths = _write_skill_paths_atomically(pending_writes)
        if not ok:
            return _blocked(
                "skill_write_failed",
                write_error or "保存做法文件失败。",
                "保存做法文件失败，所以这次没有保存任何做法。",
            )
        saved_path = str(orchestrator_path)
        reload_summary = _reload_skills_summary()

    return _json({
        "status": "generated",
        "debug_stage": "generate_skill",
        "skill": orchestrator,
        "skills": skills,
        "output_path": saved_path,
        "output_paths": saved_paths,
        "reload": reload_summary,
        "user_display": "已保存这些做法，以后可以直接让我按这个来。",
    })


GENERIC_PLAN_SCHEMA = {
    "name": "generic_plan",
    "description": "Guide a /genskills user through a simple reusable-workflow plan before saving it.",
    "parameters": {
        "type": "object",
        "properties": {
            "goal": {"type": "string"},
            "session": {"type": "object"},
            "answer": {"description": "Latest user answer as text or object."},
            "approval": {"type": "object", "description": "Use {approved: true} only after the user confirms the summary."},
        },
    },
}

GENERIC_GENERATE_SKILL_SCHEMA = {
    "name": "generic_generate_skill",
    "description": "Generate and optionally save a Hermes SKILL.md from an approved /genskills plan.",
    "parameters": {
        "type": "object",
        "properties": {
            "plan": {"type": "object"},
            "plan_ref": {"type": "object"},
            "session": {"type": "object"},
            "persist": {"type": "boolean"},
            "category": {"type": "string"},
            "output_path": {"type": "string"},
        },
    },
}


registry.register(
    name="generic_plan",
    toolset="skills",
    schema=GENERIC_PLAN_SCHEMA,
    handler=lambda args, **kw: generic_plan(
        goal=args.get("goal", ""),
        session=args.get("session"),
        answer=args.get("answer"),
        approval=args.get("approval"),
        session_id=kw.get("session_id", ""),
        task_id=kw.get("task_id", ""),
    ),
    emoji="🧭",
)

registry.register(
    name="generic_generate_skill",
    toolset="skills",
    schema=GENERIC_GENERATE_SKILL_SCHEMA,
    handler=lambda args, **kw: generic_generate_skill(
        plan=args.get("plan"),
        plan_ref=args.get("plan_ref"),
        session=args.get("session"),
        persist=args.get("persist", True),
        category=args.get("category", "productivity"),
        output_path=args.get("output_path", ""),
        session_id=kw.get("session_id", ""),
        task_id=kw.get("task_id", ""),
    ),
    emoji="📝",
)
