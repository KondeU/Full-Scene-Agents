import json
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

from hermes_cli.commands import resolve_command
from hermes_cli.genskills import build_genskills_invocation_message, genskills_title
from tools.genskills_capabilities import load_capability_registry, load_capability_prompt_bundle
from tools.generic_planning_tool import generic_generate_skill, generic_plan
from tools.skills_tool import skill_view


def _llm_response(payload):
    return SimpleNamespace(choices=[SimpleNamespace(message=SimpleNamespace(content=json.dumps(payload, ensure_ascii=False)))])


def _clarify_payload(question_id, title, body, choices, *, missing_slot=""):
    return {
        "status": "needs_clarification",
        "brainstorm_phase": "ask_clarifying_question",
        "question": {
            "id": question_id,
            "title": title,
            "body": body,
            "choices": choices,
        },
        "missing_slot": missing_slot or question_id,
        "capabilities_used": ["input.photo_or_screenshot", "processing.draft_review"],
        "rationale": "Ask one context-specific question.",
    }


def _confirm_payload():
    return {
        "status": "awaiting_confirmation",
        "brainstorm_phase": "present_design",
        "proposed_design": {
            "inputs_needed": ["用户提供的截图或文字"],
            "processing_action": "整理并生成可检查的结果",
            "schedule_or_trigger": "用户需要时手动开始",
            "output_or_delivery": "在聊天里给用户确认",
            "memory_scope": "记住用户确认过的偏好或字段",
            "steps": ["确认本次材料。", "整理关键内容。", "生成结果给用户检查。"],
            "constraints": ["只处理用户提供的信息。"],
            "failure_handling": "缺少必要内容时只问一个最小问题。",
            "acceptance_criteria": ["用户确认后可以保存。"],
        },
        "missing_slot": "",
        "capabilities_used": ["interaction.choice_cards"],
        "rationale": "Ready to confirm.",
    }


def _empty_confirm_payload():
    return {
        "status": "awaiting_confirmation",
        "brainstorm_phase": "present_design",
        "proposed_design": {},
        "missing_slot": "",
        "capabilities_used": ["interaction.choice_cards"],
        "rationale": "Ready to confirm but missing design fields.",
    }


def test_genskills_command_is_registered():
    cmd = resolve_command("genskills")
    assert cmd is not None
    assert cmd.name == "genskills"
    assert cmd.args_hint == "[what you want to save]"


def test_genskills_invocation_loads_planner_with_goal():
    message = build_genskills_invocation_message("每周整理会议纪要", task_id="session-1")
    assert "generic-planner" in message
    assert "每周整理会议纪要" in message
    assert "不要再问用户想保存哪件事" in message
    assert "pending_interaction" in message
    assert "expose only `generic_plan`" in message
    assert "internal debug stages" in message
    assert "any other tool path" in message
    assert "## Capability: 拍照或截图" in message
    assert "## Capability: 付款或转账" in message
    assert genskills_title("每周整理会议纪要").startswith("创建任务")


def test_genskills_toolset_only_exposes_planner_and_generator():
    from toolsets import TOOLSETS

    assert TOOLSETS["genskills"]["tools"] == ["generic_plan", "generic_generate_skill"]
    assert "skill_manage" not in TOOLSETS["genskills"]["tools"]
    assert "skill_view" not in TOOLSETS["genskills"]["tools"]


def test_genskills_capability_registry_loads_markdown_docs():
    registry = load_capability_registry()
    bundle = load_capability_prompt_bundle()

    assert registry.source_dir.name == "genskills"
    assert "input.photo_or_screenshot" in registry.by_id
    assert "external.payment" in registry.by_id
    assert registry.by_id["input.photo_or_screenshot"].status == "supported"
    assert registry.by_id["external.payment"].status == "unsupported"
    assert "## Capability: 拍照或截图" in bundle
    assert "## Capability: 付款或转账" in bundle
    assert all(not capability.clarification for capability in registry.capabilities)


def test_genskills_capability_registry_detects_unsupported_boundaries_from_markdown():
    registry = load_capability_registry()

    matches = registry.unsupported_matches("从日历读取账单并按地理围栏提醒")

    assert {match["capability"] for match in matches} >= {"日历读取", "地理围栏"}


def test_generic_plan_health_weekly_report_starts_with_contextual_question():
    analyzer = _clarify_payload(
        "health_report_scope",
        "先确认报告内容",
        "这份健康周报里，你最想先看到哪类内容？",
        ["血压、血糖、心率这些指标", "运动和睡眠变化", "异常提醒和建议"],
        missing_slot="report_focus",
    )
    with patch("tools.generic_planning_tool._find_similar_skills", return_value=[]):
        with patch("agent.auxiliary_client.call_llm", return_value=_llm_response(analyzer)):
            first = json.loads(generic_plan(goal="健康周报", session_id="mobile-session", task_id="task-1"))

    assert first["status"] == "needs_clarification"
    assert first["session"]["phase"] == "clarify"
    assert first["question_source"] == "brainstorming_dynamic_analyzer"
    assert first["brainstorm_phase"] == "ask_clarifying_question"
    assert first["question_id"] == "health_report_scope"
    assert first["pending_interaction"]["kind"] == "clarification"
    assert first["pending_interaction"]["title"] == "先确认报告内容"
    assert first["pending_interaction"]["body"] == "这份健康周报里，你最想先看到哪类内容？"
    assert [choice["label"] for choice in first["pending_interaction"]["choices"]] == [
        "1. 血压、血糖、心率这些指标",
        "2. 运动和睡眠变化",
        "3. 异常提醒和建议",
    ]
    assert "你通常会给我什么材料" not in first["user_display"]


def test_generic_plan_different_goals_get_different_first_questions():
    health = _clarify_payload(
        "health_report_scope",
        "先确认报告内容",
        "这份健康周报里，你最想先看到哪类内容？",
        ["健康指标", "运动睡眠", "异常提醒"],
    )
    bill = _clarify_payload(
        "bill_record_target",
        "先确认记账结果",
        "你希望记账助手先帮你整理哪类账单信息？",
        ["金额和商家", "分类和用途", "报销字段"],
    )
    with patch("tools.generic_planning_tool._find_similar_skills", return_value=[]):
        with patch("agent.auxiliary_client.call_llm", side_effect=[_llm_response(health), _llm_response(bill)]):
            health_first = json.loads(generic_plan(goal="健康周报", session_id="health-session", task_id="task-1"))
            bill_first = json.loads(generic_plan(goal="记账助手", session_id="bill-session", task_id="task-2"))

    assert health_first["question_id"] != bill_first["question_id"]
    assert "健康周报" in health_first["session"]["user_goal"]
    assert "记账助手" in bill_first["session"]["user_goal"]
    assert "健康" in health_first["pending_interaction"]["body"]
    assert "账单" in bill_first["pending_interaction"]["body"]


def test_generic_plan_numeric_choice_continues_with_contextual_next_question():
    first_payload = _clarify_payload(
        "health_report_scope",
        "先确认报告内容",
        "这份健康周报里，你最想先看到哪类内容？",
        ["健康指标", "运动睡眠", "异常提醒"],
    )
    second_payload = _clarify_payload(
        "health_data_source",
        "确认数据来源",
        "下次做健康周报时，你会怎么把这些健康数据给我？",
        ["发截图", "直接输入数字", "执行时再问"],
    )
    with patch("tools.generic_planning_tool._find_similar_skills", return_value=[]):
        with patch("agent.auxiliary_client.call_llm", side_effect=[_llm_response(first_payload), _llm_response(second_payload)]):
            first = json.loads(generic_plan(goal="健康周报", session_id="mobile-session", task_id="task-1"))
            second = json.loads(generic_plan(session=first["session"], answer="1", session_id="mobile-session", task_id="task-1"))

    assert second["status"] == "needs_clarification"
    assert second["question_id"] == "health_data_source"
    assert second["session"]["answers"][-1]["answer"] == "健康指标"
    assert "健康周报" in second["pending_interaction"]["body"]
    assert "拿到材料后" not in second["pending_interaction"]["body"]


def test_generic_plan_brainstorming_flow_confirms_when_analyzer_says_ready():
    first_payload = _clarify_payload(
        "health_report_scope",
        "先确认报告内容",
        "这份健康周报里，你最想先看到哪类内容？",
        ["健康指标", "运动睡眠", "异常提醒"],
    )
    with patch("tools.generic_planning_tool._find_similar_skills", return_value=[]):
        with patch("agent.auxiliary_client.call_llm", side_effect=[_llm_response(first_payload), _llm_response(_confirm_payload())]):
            current = json.loads(generic_plan(goal="健康周报", session_id="mobile-session", task_id="task-1"))
            summary = json.loads(generic_plan(session=current["session"], answer="1", session_id="mobile-session", task_id="task-1"))

    assert summary["status"] == "awaiting_confirmation"
    assert summary["question_source"] == "brainstorming_dynamic_analyzer"
    assert summary["brainstorm_phase"] == "present_design"
    assert "用户交互流程描述" in summary["summary"]
    assert "1. 用户提供材料：用户提供的截图或文字。" in summary["summary"]
    assert "2. 处理方式：整理并生成可检查的结果。" in summary["summary"]
    assert "Agent" not in summary["summary"]
    assert "付款" not in summary["summary"]
    assert "删除" not in summary["summary"]
    assert "发布" not in summary["summary"]
    assert "这样创建可以吗？" == summary["confirmation_question"]
    assert [choice["label"] for choice in summary["pending_interaction"]["choices"]] == [
        "1. 可以保存",
        "2. 修改前面的选择",
        "3. 重新描述",
    ]


def test_generic_plan_blocks_premature_confirmation_when_design_is_empty():
    payloads = [
        _clarify_payload("health_data_source", "周报数据从哪来？", "周报数据从哪来？", ["文字", "截图", "文字和截图都会提供"]),
        _clarify_payload("health_focus", "周报重点放哪类内容？", "周报重点放哪类内容？", ["指标变化", "异常提醒", "本周总结"]),
        _clarify_payload("health_format", "周报更想看哪种形式？", "周报更想看哪种形式？", ["简短总结＋提醒", "分项清单", "表格汇总"]),
        _clarify_payload("health_start", "周报什么时候做？", "周报什么时候做？", ["每周固定时间提醒我", "手动开始", "以后再定"]),
        _clarify_payload("health_day", "每周什么时候提醒？", "每周什么时候提醒？", ["周日晚上", "周一早上", "其他时间"]),
        _clarify_payload("health_time", "周日晚上几点提醒你？", "周日晚上几点提醒你？", ["19:00", "20:00", "21:00"]),
        _clarify_payload("health_delivery", "周报发在哪里给你看？", "周报发在哪里给你看？", ["就在聊天里看", "用微信通知我看结果", "先提醒我再查看"]),
        _empty_confirm_payload(),
    ]
    answers = ["3", "3", "1", "1", "1", "1", "2"]

    with patch("tools.generic_planning_tool._find_similar_skills", return_value=[]):
        with patch("agent.auxiliary_client.call_llm", side_effect=[_llm_response(payload) for payload in payloads]):
            current = json.loads(generic_plan(goal="健康周报", session_id="mobile-session", task_id="task-1"))
            for answer in answers:
                current = json.loads(generic_plan(session=current["session"], answer=answer, session_id="mobile-session", task_id="task-1"))

    assert current["status"] == "blocked"
    assert current["diagnostics"][0]["code"] == "invalid_proposed_design"
    assert set(current["diagnostics"][0]["missing_fields"]) == {
        "inputs_needed",
        "processing_action",
        "schedule_or_trigger",
        "memory_scope",
        "output_or_delivery",
    }
    assert "规划结果不完整" in current["user_display"]
    assert "用户交互流程描述" not in current.get("summary", "")
    assert "plan_document" not in current


def test_generic_plan_blocks_premature_confirmation_when_design_is_partial():
    first_payload = _clarify_payload(
        "health_report_scope",
        "先确认报告内容",
        "这份健康周报里，你最想先看到哪类内容？",
        ["健康指标", "运动睡眠", "异常提醒"],
    )
    partial = _confirm_payload()
    partial["proposed_design"] = {
        "inputs_needed": ["用户提供的健康数据"],
        "processing_action": "整理成健康周报",
    }

    with patch("tools.generic_planning_tool._find_similar_skills", return_value=[]):
        with patch("agent.auxiliary_client.call_llm", side_effect=[_llm_response(first_payload), _llm_response(partial)]):
            first = json.loads(generic_plan(goal="健康周报", session_id="mobile-session", task_id="task-1"))
            summary = json.loads(generic_plan(session=first["session"], answer="1", session_id="mobile-session", task_id="task-1"))

    assert summary["status"] == "blocked"
    assert summary["diagnostics"][0]["code"] == "invalid_proposed_design"
    assert summary["diagnostics"][0]["missing_fields"] == [
        "schedule_or_trigger",
        "memory_scope",
        "output_or_delivery",
    ]
    assert "规划结果不完整" in summary["user_display"]
    assert "用户交互流程描述" not in summary.get("summary", "")
    assert "plan_document" not in summary


def test_generic_plan_blocks_dynamic_analyzer_fallback_instead_of_confirming_with_defaults():
    first_payload = _clarify_payload(
        "health_data_source",
        "周报数据从哪来？",
        "周报数据从哪来？",
        ["文字", "截图", "文字和截图都会提供"],
    )
    with patch("tools.generic_planning_tool._find_similar_skills", return_value=[]):
        with patch("agent.auxiliary_client.call_llm", side_effect=[_llm_response(first_payload), RuntimeError("timeout")]):
            first = json.loads(generic_plan(goal="健康周报", session_id="mobile-session", task_id="task-1"))
            result = json.loads(generic_plan(session=first["session"], answer="3", session_id="mobile-session", task_id="task-1"))

    assert result["status"] == "blocked"
    assert result["diagnostics"][0]["code"] == "planning_analyzer_failed"
    assert "规划分析失败" in result["user_display"]
    assert "用户交互流程描述" not in result.get("summary", "")
    assert "plan_document" not in result


def test_generic_plan_dynamic_analyzer_prompt_includes_superpowers_brainstorming_principles():
    payload = _clarify_payload(
        "health_report_scope",
        "先确认报告内容",
        "这份健康周报里，你最想先看到哪类内容？",
        ["健康指标", "运动睡眠", "异常提醒"],
    )
    with patch("tools.generic_planning_tool._find_similar_skills", return_value=[]):
        with patch("agent.auxiliary_client.call_llm", return_value=_llm_response(payload)) as call:
            json.loads(generic_plan(goal="健康周报", session_id="mobile-session", task_id="task-1"))

    messages = call.call_args.kwargs["messages"]
    prompt_text = "\n".join(str(message.get("content") or "") for message in messages)
    assert "Explore project context" in prompt_text
    assert "Ask clarifying questions" in prompt_text
    assert "Propose 2-3 approaches" in prompt_text
    assert "Present design" in prompt_text


def test_generic_plan_detail_from_summary_asks_next_missing_or_revision_question():
    with patch("tools.generic_planning_tool._find_similar_skills", return_value=[]):
        with patch("agent.auxiliary_client.call_llm", side_effect=[_llm_response(_confirm_payload())]):
            current = json.loads(generic_plan(goal="整理资料", session_id="mobile-session", task_id="task-1"))
    detail = json.loads(generic_plan(session=current["session"], answer="2", session_id="mobile-session", task_id="task-1"))

    assert current["status"] == "awaiting_confirmation"
    assert detail["status"] == "needs_clarification"
    assert detail["question_id"] == "approval_revision"
    assert detail["pending_interaction"]["choices"][0]["label"] == "1. 需要内容"


def test_generic_plan_recovers_pending_confirmation_by_session_for_choice_only_reply():
    clarify = _clarify_payload("health_report_scope", "先确认报告内容", "健康周报先看什么？", ["指标", "趋势", "提醒"])
    with patch("tools.generic_planning_tool._find_similar_skills", return_value=[]):
        with patch("agent.auxiliary_client.call_llm", side_effect=[_llm_response(clarify), _llm_response(_confirm_payload())]):
            first = json.loads(generic_plan(goal="健康周报", session_id="mobile-session", task_id="task-1"))
            current = json.loads(generic_plan(answer="1", session_id="mobile-session", task_id="task-1"))
    detail = json.loads(generic_plan(answer="2", session_id="mobile-session", task_id="task-1"))

    assert first["status"] == "needs_clarification"
    assert current["status"] == "awaiting_confirmation"
    assert detail["status"] == "needs_clarification"
    assert detail["session"]["user_goal"] == "健康周报"
    assert detail["question_id"] == "approval_revision"
    assert "健康周报" not in detail["pending_interaction"]["body"]
    assert "修改前面的选择" != detail["session"]["user_goal"]


def test_generic_plan_recovers_pending_confirmation_from_skeletal_session_object():
    clarify = _clarify_payload("health_report_scope", "先确认报告内容", "健康周报先看什么？", ["指标", "趋势", "提醒"])
    with patch("tools.generic_planning_tool._find_similar_skills", return_value=[]):
        with patch("agent.auxiliary_client.call_llm", side_effect=[_llm_response(clarify), _llm_response(_confirm_payload())]):
            first = json.loads(generic_plan(goal="健康周报", session={"id": "mobile-session"}))
            current = json.loads(generic_plan(answer="1", session={"id": "mobile-session"}))
    detail = json.loads(generic_plan(answer="2", session={"id": "mobile-session"}))

    assert first["status"] == "needs_clarification"
    assert current["status"] == "awaiting_confirmation"
    assert detail["status"] == "needs_clarification"
    assert detail["session"]["user_goal"] == "健康周报"
    assert detail["pending_interaction"]["choices"][0]["label"] == "1. 需要内容"


def test_generic_plan_recovers_pending_confirmation_for_save_button_reply():
    clarify = _clarify_payload("health_report_scope", "先确认报告内容", "健康周报先看什么？", ["指标", "趋势", "提醒"])
    with patch("tools.generic_planning_tool._find_similar_skills", return_value=[]):
        with patch("agent.auxiliary_client.call_llm", side_effect=[_llm_response(clarify), _llm_response(_confirm_payload())]):
            first = json.loads(generic_plan(goal="健康周报", session={"id": "mobile-session"}))
            current = json.loads(generic_plan(answer="1", session={"id": "mobile-session"}))
    approved = json.loads(generic_plan(answer="1", session={"id": "mobile-session"}))

    assert first["status"] == "needs_clarification"
    assert current["status"] == "awaiting_confirmation"
    assert approved["status"] == "approved"
    assert approved["plan"]["user_goal"] == "健康周报"
    assert approved["next_tool"]["name"] == "generic_generate_skill"


def test_generic_plan_vague_detail_answer_asks_for_one_concrete_example():
    with patch("tools.generic_planning_tool._find_similar_skills", return_value=[]):
        with patch("agent.auxiliary_client.call_llm", return_value=_llm_response(_clarify_payload(
            "document_scope",
            "先确认资料范围",
            "这次整理资料，你最想先处理哪部分？",
            ["重点", "清单", "摘要"],
        ))):
            first = json.loads(generic_plan(goal="整理资料", session_id="mobile-session", task_id="task-1"))
    followup = _clarify_payload(
        "document_example",
        "换个具体例子",
        "下次整理资料时，你会先发哪类内容？",
        ["一段文字", "图片或文件", "执行时再问"],
    )
    with patch("agent.auxiliary_client.call_llm", return_value=_llm_response(followup)):
        vague = json.loads(generic_plan(session=first["session"], answer="先不确定", session_id="mobile-session", task_id="task-1"))

    assert vague["status"] == "needs_clarification"
    assert vague["question_id"] == "document_example"
    assert vague["pending_interaction"]["body"] == "下次整理资料时，你会先发哪类内容？"
    assert vague["pending_interaction"]["choices"][0]["label"] == "1. 一段文字"


def test_generic_generate_skill_recovers_approved_plan_from_same_session(tmp_path):
    with patch("tools.generic_planning_tool._find_similar_skills", return_value=[]):
        with patch("agent.auxiliary_client.call_llm", return_value=_llm_response(_confirm_payload())):
            current = json.loads(generic_plan(goal="weekly meeting notes", session_id="mobile-session", task_id="task-1"))
    approved = json.loads(generic_plan(session=current["session"], approval={"approved": True}, session_id="mobile-session", task_id="task-1"))

    skills_dir = tmp_path / "skills"
    with patch("tools.skills_tool.SKILLS_DIR", skills_dir):
        generated = json.loads(generic_generate_skill(plan={}, persist=True, session_id="mobile-session", task_id="task-1"))

    assert approved["status"] == "approved"
    assert generated["status"] == "generated"
    assert generated["skill"]["name"] == "weekly-meeting-notes"
    assert (skills_dir / "productivity" / "weekly-meeting-notes" / "SKILL.md").exists()


def test_generic_generate_skill_blocks_empty_plan_without_same_session_recovery():
    result = json.loads(generic_generate_skill(plan={}, session_id="other-session", task_id="task-1"))

    assert result["status"] == "blocked"
    assert result["diagnostics"][0]["code"] == "plan_handoff_failed"
    assert "还不知道这个做法要完成什么" not in result["user_display"]


def test_generic_plan_walks_to_confirmation():
    with patch("agent.auxiliary_client.call_llm", side_effect=[
        _llm_response(_clarify_payload("meeting_scope", "先确认纪要重点", "会议纪要里最想保留什么？", ["决定", "行动项", "风险"])),
        _llm_response(_confirm_payload()),
    ]):
        first = json.loads(generic_plan(goal="每周整理会议纪要"))
    assert first["status"] == "needs_clarification"
    assert first["question_id"] == "meeting_scope"

    current = first
    with patch("agent.auxiliary_client.call_llm", return_value=_llm_response(_confirm_payload())):
        current = json.loads(generic_plan(session=current["session"], answer="1"))
    assert current["status"] == "awaiting_confirmation"
    assert current["session"]["phase"] == "confirm"
    assert "每周整理会议纪要" in current["summary"]
    assert current["plan_document"]["user_goal"] == "每周整理会议纪要"
    assert current["confirmation_question"] == "这样创建可以吗？"

    approved = json.loads(generic_plan(session=current["session"], approval={"approved": True}))
    assert approved["status"] == "approved"
    assert approved["plan"]["approved"] is True
    assert approved["next_tool"]["name"] == "generic_generate_skill"


def test_generic_plan_exposes_internal_debug_stage_only_in_payload():
    with patch("agent.auxiliary_client.call_llm", side_effect=[
        _llm_response(_clarify_payload("meeting_scope", "先确认纪要重点", "会议纪要里最想保留什么？", ["决定", "行动项", "风险"])),
        _llm_response(_confirm_payload()),
    ]):
        first = json.loads(generic_plan(goal="每周整理会议纪要"))

    assert first["debug_stage"] == "plan"
    assert first["session"]["debug_stage"] == "plan"

    result = first
    with patch("agent.auxiliary_client.call_llm", return_value=_llm_response(_confirm_payload())):
        result = json.loads(generic_plan(session=result["session"], answer="1"))

    approved = json.loads(generic_plan(session=result["session"], approval={"approved": True}))
    assert approved["debug_stage"] == "plan"
    assert approved["debug_next_stage"] == "generate_skill"
    assert approved["next_tool"]["name"] == "generic_generate_skill"


def test_generic_plan_keeps_vague_goal_in_capture_phase():
    first = json.loads(generic_plan())
    assert first["status"] == "needs_goal"
    assert first["session"]["phase"] == "capture_goal"

    vague = json.loads(generic_plan(session=first["session"], answer="不知道"))

    assert vague["status"] == "needs_goal"
    assert vague["session"]["phase"] == "capture_goal"
    assert vague["question"] == "你想把哪件常做的事保存成以后能直接用的做法？"


def test_generic_plan_offers_reuse_choice_for_similar_skill(tmp_path):
    skill_dir = tmp_path / "skills" / "productivity" / "weekly-notes"
    skill_dir.mkdir(parents=True)
    skill_dir.joinpath("SKILL.md").write_text(
        "\n".join([
            "---",
            "name: weekly-notes",
            "description: 每周整理会议纪要并列出行动项",
            "---",
            "",
            "# Weekly Notes",
        ]),
        encoding="utf-8",
    )

    with patch("tools.skills_tool.SKILLS_DIR", tmp_path / "skills"):
        result = json.loads(generic_plan(goal="每周整理会议纪要"))

    assert result["status"] == "reuse_choice"
    assert result["session"]["phase"] == "reuse_check"
    assert result["choices"] == ["直接用", "改一下", "新建"]
    assert result["session"]["matched_skills"][0]["name"] == "weekly-notes"


def test_generic_plan_does_not_require_all_coverage_before_confirmation():
    with patch("agent.auxiliary_client.call_llm", return_value=_llm_response(_confirm_payload())):
        first = json.loads(generic_plan(goal="每周整理会议纪要"))
    current = first

    assert first["status"] == "awaiting_confirmation"
    assert current["status"] == "awaiting_confirmation"
    assert current["session"]["coverage"]["complete"] is True
    assert "next_tool" not in current
    assert "用户交互流程描述" in current["summary"]


def test_generic_plan_uses_dynamic_analyzer_without_keyword_question_flow():
    payload = _clarify_payload("doc_focus", "确认资料目标", "这次资料整理，最想先得到什么？", ["摘要", "清单", "行动项"])
    with patch("agent.auxiliary_client.call_llm", return_value=_llm_response(payload)):
        first = json.loads(generic_plan(goal="整理资料"))

    assert first["status"] == "needs_clarification"
    assert first["question_id"] == "doc_focus"
    assert first["pending_interaction"]["choices"][1]["label"] == "2. 清单"


def test_generic_plan_blocks_unsupported_capability_from_spec():
    result = json.loads(generic_plan(goal="从日历自动读取账单", session_id="mobile-session", task_id="task-1"))

    assert result["status"] == "blocked"
    assert result["diagnostics"][0]["code"] == "unsupported_capability"
    assert result["diagnostics"][0]["capability"] == "日历读取"
    assert "在聊天里提供材料" in result["user_display"]


def test_generic_plan_blocks_automatic_health_data_read_with_manual_fallback():
    result = json.loads(generic_plan(goal="自动读取健康数据生成健康周报", session_id="mobile-session", task_id="task-1"))

    assert result["status"] == "blocked"
    assert result["diagnostics"][0]["code"] == "unsupported_capability"
    assert result["diagnostics"][0]["capability"] == "健康数据读取"
    assert "手动输入" in result["user_display"]
    assert "截图" in result["user_display"]


def test_generic_plan_blocks_payment_request_instead_of_asking_permission_question():
    result = json.loads(generic_plan(goal="帮我识别账单并自动付款", session_id="mobile-session", task_id="task-1"))

    assert result["status"] == "blocked"
    assert result["diagnostics"][0]["code"] == "unsupported_capability"
    assert result["diagnostics"][0]["capability"] == "付款或转账"
    assert "如果涉及发送、删除、付款、发布或改账号" not in result["user_display"]


def test_generic_plan_builds_artifacts_from_user_confirmed_parts_not_domain_keywords():
    first = json.loads(generic_plan(
        goal="整理资料",
        session={
            "id": "artifact-session",
            "phase": "confirm",
            "status": "awaiting_confirmation",
            "user_goal": "整理资料",
            "answers": [],
            "workflow_parts": ["收集资料", "整理重点", "提醒我查看"],
            "proposed_design": _confirm_payload()["proposed_design"],
        },
        approval={"approved": True},
    ))
    approved = first
    artifacts = approved["plan"].get("artifacts", [])

    assert approved["status"] == "approved"
    assert [artifact["type"] for artifact in artifacts if artifact["type"] == "skill"] == ["skill", "skill", "skill", "skill"]
    assert {artifact["user_goal"] for artifact in artifacts if artifact["type"] == "skill"} >= {
        "收集资料",
        "整理重点",
        "提醒我查看",
    }
    skill_ids = [artifact["id"] for artifact in artifacts if artifact["type"] == "skill"]
    assert all(skill_id.startswith("workflow_part_") or skill_id == "orchestrator" for skill_id in skill_ids)


def test_generic_plan_rejection_returns_to_clarification():
    with patch("agent.auxiliary_client.call_llm", return_value=_llm_response(_confirm_payload())):
        first = json.loads(generic_plan(goal="每周整理会议纪要"))
    result = first
    session = result["session"]
    assert result["status"] == "awaiting_confirmation"

    rejected = json.loads(generic_plan(session=session, approval={"approved": False, "feedback": "输出要先保存成草稿"}))

    assert rejected["status"] == "needs_clarification"
    assert rejected["session"]["phase"] == "clarify"
    assert rejected["session"]["answers"][-1]["question_id"] == "approval_feedback"
    assert "next_tool" not in rejected


def test_generic_plan_hardcoded_question_texts_are_not_in_planner_or_capability_markdown():
    banned = [
        "你通常会给我什么材料",
        "拿到材料后",
        "这个任务需要长期记住什么",
        "完成后，你想看到什么",
    ]
    production_files = [
        Path("tools/generic_planning_tool.py"),
        *Path("capabilities/genskills").glob("*.md"),
    ]
    for path in production_files:
        content = path.read_text(encoding="utf-8")
        for text in banned:
            assert text not in content, f"{text!r} remains in {path}"
        if path.suffix == ".md":
            assert "clarification:" not in content


def test_generic_generate_skill_persists_loadable_skill(tmp_path):
    plan = {
        "approved": True,
        "user_goal": "weekly meeting notes",
        "inputs_needed": ["meeting transcript"],
        "steps": ["Summarize decisions.", "List next actions."],
        "tools_required": [],
        "schedule_or_trigger": "weekly",
        "output_or_delivery": "draft summary",
        "user_confirmation_required": True,
        "constraints": ["Do not send without review."],
        "acceptance_criteria": ["Summary includes decisions and actions."],
    }
    skills_dir = tmp_path / "skills"
    with patch("tools.skills_tool.SKILLS_DIR", skills_dir):
        result = json.loads(generic_generate_skill(plan=plan, persist=True))
        viewed = json.loads(skill_view("weekly-meeting-notes"))

    assert result["status"] == "generated"
    assert result["reload"]["total"] >= 1
    output_path = result["output_path"]
    assert output_path.endswith("SKILL.md")
    content = (skills_dir / "productivity" / "weekly-meeting-notes" / "SKILL.md").read_text()
    assert "name: \"weekly-meeting-notes\"" in content
    assert "## Workflow" in content
    assert viewed["success"] is True


def test_generic_generate_skill_exposes_internal_debug_stage(tmp_path):
    plan = {
        "approved": True,
        "user_goal": "weekly meeting notes",
        "inputs_needed": ["meeting transcript"],
        "steps": ["Summarize decisions."],
        "tools_required": [],
        "user_confirmation_required": True,
    }
    skills_dir = tmp_path / "skills"
    with patch("tools.skills_tool.SKILLS_DIR", skills_dir):
        result = json.loads(generic_generate_skill(plan=plan, persist=True))

    assert result["status"] == "generated"
    assert result["debug_stage"] == "generate_skill"
    assert "generic_generate_skill" not in result["user_display"]


def test_generic_generate_skill_persists_bundle_with_orchestrator(tmp_path):
    plan = {
        "approved": True,
        "user_goal": "collect weekly metrics and write weekly report",
        "inputs_needed": ["metrics"],
        "tools_required": [],
        "user_confirmation_required": True,
        "constraints": ["Review before sending."],
        "acceptance_criteria": ["Each part can be reused."],
        "skills_to_generate": [
            {
                "user_goal": "collect weekly metrics",
                "steps": ["Collect metrics.", "Check missing fields."],
                "tools_required": [],
            },
            {
                "user_goal": "write weekly report",
                "steps": ["Draft the report.", "List next actions."],
                "tools_required": [],
            },
        ],
    }
    skills_dir = tmp_path / "skills"
    with patch("tools.skills_tool.SKILLS_DIR", skills_dir):
        result = json.loads(generic_generate_skill(plan=plan, persist=True))

    assert result["status"] == "generated"
    assert len(result["skills"]) == 3
    assert result["skill"]["name"].endswith("-workflow")
    assert len(result["output_paths"]) == 3
    assert (skills_dir / "productivity" / "collect-weekly-metrics" / "SKILL.md").exists()
    assert (skills_dir / "productivity" / "write-weekly-report" / "SKILL.md").exists()
    orchestrator_content = (skills_dir / "productivity" / result["skill"]["name"] / "SKILL.md").read_text()
    assert "## Child Skills" in orchestrator_content
    assert "collect-weekly-metrics" in orchestrator_content
    assert "write-weekly-report" in orchestrator_content


def test_generic_generate_skill_persists_artifact_bundle_and_creates_cron_after_writes(tmp_path):
    plan = {
        "approved": True,
        "user_goal": "weekly source packet workflow",
        "inputs_needed": ["source packet"],
        "tools_required": [],
        "user_confirmation_required": True,
        "constraints": ["Confirm source details before preparing the summary."],
        "acceptance_criteria": ["Each saved part can be reused."],
        "artifacts": [
            {
                "type": "skill",
                "id": "workflow_part_1",
                "user_facing_label": "收集资料包",
                "user_goal": "collect source packet",
                "requires_user_confirmation": True,
            },
            {
                "type": "skill",
                "id": "workflow_part_2",
                "user_facing_label": "整理重点",
                "user_goal": "summarize source packet",
                "requires_user_confirmation": True,
            },
            {
                "type": "skill",
                "id": "workflow_part_3",
                "user_facing_label": "提醒查看",
                "user_goal": "notify user to review summary",
                "requires_user_confirmation": True,
            },
            {
                "type": "cronjob",
                "id": "scheduled_reminder",
                "user_facing_label": "每周日早上9点提醒提供资料",
                "name": "每周资料提醒",
                "schedule": "0 9 * * 0",
                "prompt": "Remind the user to provide the source packet.",
                "depends_on": ["workflow_part_1"],
                "requires_user_confirmation": True,
            },
            {
                "type": "skill",
                "id": "orchestrator",
                "user_facing_label": "协调完整流程",
                "user_goal": "coordinate weekly source packet workflow",
                "requires_user_confirmation": True,
            },
        ],
    }
    skills_dir = tmp_path / "skills"
    with patch("tools.skills_tool.SKILLS_DIR", skills_dir), patch(
        "tools.generic_planning_tool._call_cronjob_tool",
        return_value={"success": True, "job_id": "job-weekly-source"},
        create=True,
    ) as cron:
        result = json.loads(generic_generate_skill(plan=plan, persist=True))

    assert result["status"] == "generated"
    assert len(result["skills"]) == 4
    assert len(result["output_paths"]) == 4
    assert (skills_dir / "productivity" / "collect-source-packet" / "SKILL.md").exists()
    assert (skills_dir / "productivity" / "summarize-source-packet" / "SKILL.md").exists()
    assert (skills_dir / "productivity" / "notify-user-to-review-summary" / "SKILL.md").exists()
    create_calls = [call for call in cron.call_args_list if call.kwargs.get("action") == "create"]
    assert len(create_calls) == 1
    assert create_calls[0].kwargs["schedule"] == "0 9 * * 0"
    assert result["cronjobs"][0]["job_id"] == "job-weekly-source"


def test_generic_generate_skill_blocks_cron_name_conflict_before_writes(tmp_path):
    plan = {
        "approved": True,
        "user_goal": "weekly source packet workflow",
        "inputs_needed": ["source packet"],
        "tools_required": [],
        "user_confirmation_required": True,
        "artifacts": [
            {"type": "skill", "id": "workflow_part_1", "user_goal": "summarize source packet"},
            {"type": "cronjob", "id": "scheduled_reminder", "name": "每周资料提醒", "schedule": "0 9 * * 0", "prompt": "提醒用户提供资料。"},
        ],
    }
    skills_dir = tmp_path / "skills"

    def fake_cronjob(**kwargs):
        if kwargs["action"] == "list":
            return {"success": True, "jobs": [{"id": "existing-job", "name": "每周资料提醒", "skills": ["other-workflow"]}]}
        raise AssertionError(f"unexpected cron call: {kwargs}")

    with patch("tools.skills_tool.SKILLS_DIR", skills_dir), patch("tools.generic_planning_tool._call_cronjob_tool", side_effect=fake_cronjob):
        result = json.loads(generic_generate_skill(plan=plan, persist=True))

    assert result["status"] == "blocked"
    assert result["diagnostics"][0]["code"] == "cron_name_conflict"
    assert not skills_dir.exists()


def test_generic_generate_skill_updates_matching_generated_cron(tmp_path):
    plan = {
        "approved": True,
        "user_goal": "weekly source packet workflow",
        "inputs_needed": ["source packet"],
        "tools_required": [],
        "user_confirmation_required": True,
        "artifacts": [
            {"type": "skill", "id": "workflow_part_1", "user_goal": "summarize source packet"},
            {
                "type": "cronjob",
                "id": "scheduled_reminder",
                "name": "每周资料提醒",
                "schedule": "0 10 * * 0",
                "prompt": "提醒用户提供资料。",
                "update_existing": True,
                "existing_job_id": "existing-job",
            },
        ],
    }
    skills_dir = tmp_path / "skills"
    calls = []

    def fake_cronjob(**kwargs):
        calls.append(kwargs)
        if kwargs["action"] == "list":
            return {"success": True, "jobs": [{"id": "existing-job", "name": "每周资料提醒", "skills": ["weekly-source-packet-workflow-workflow"]}]}
        if kwargs["action"] == "update":
            return {"success": True, "job_id": "existing-job", "job": {"id": "existing-job"}}
        raise AssertionError(f"unexpected cron call: {kwargs}")

    with patch("tools.skills_tool.SKILLS_DIR", skills_dir), patch("tools.generic_planning_tool._call_cronjob_tool", side_effect=fake_cronjob):
        result = json.loads(generic_generate_skill(plan=plan, persist=True))

    assert result["status"] == "generated"
    assert any(call["action"] == "update" and call["job_id"] == "existing-job" for call in calls)


def test_generic_generate_skill_blocks_artifact_bundle_conflict_before_cron_or_writes(tmp_path):
    existing = tmp_path / "skills" / "productivity" / "summarize-source-packet" / "SKILL.md"
    existing.parent.mkdir(parents=True)
    existing.write_text("original", encoding="utf-8")
    plan = {
        "approved": True,
        "user_goal": "weekly source packet workflow",
        "tools_required": [],
        "user_confirmation_required": True,
        "artifacts": [
            {"type": "skill", "id": "workflow_part_1", "user_goal": "collect source packet"},
            {"type": "skill", "id": "workflow_part_2", "user_goal": "summarize source packet"},
            {"type": "cronjob", "id": "scheduled_reminder", "name": "每周资料提醒", "schedule": "0 9 * * 0", "prompt": "提醒用户提供资料。"},
        ],
    }
    skills_dir = tmp_path / "skills"
    with patch("tools.skills_tool.SKILLS_DIR", skills_dir), patch(
        "tools.generic_planning_tool._call_cronjob_tool",
        return_value={"success": True, "job_id": "job-weekly-source"},
        create=True,
    ) as cron:
        result = json.loads(generic_generate_skill(plan=plan, persist=True))

    assert result["status"] == "blocked"
    assert result["diagnostics"][0]["code"] == "name_conflict"
    assert existing.read_text(encoding="utf-8") == "original"
    assert not (skills_dir / "productivity" / "collect-source-packet").exists()
    assert not any(call.kwargs.get("action") in {"create", "update"} for call in cron.call_args_list)


def test_generic_generate_skill_rolls_back_artifact_bundle_when_cron_fails(tmp_path):
    plan = {
        "approved": True,
        "user_goal": "weekly source packet workflow",
        "inputs_needed": ["source packet"],
        "tools_required": [],
        "user_confirmation_required": True,
        "constraints": ["Confirm source details before preparing the summary."],
        "acceptance_criteria": ["Each saved part can be reused."],
        "artifacts": [
            {"type": "skill", "id": "workflow_part_1", "user_goal": "collect source packet"},
            {"type": "skill", "id": "workflow_part_2", "user_goal": "summarize source packet"},
            {"type": "cronjob", "id": "scheduled_reminder", "name": "每周资料提醒", "schedule": "0 9 * * 0", "prompt": "提醒用户提供资料。"},
        ],
    }
    skills_dir = tmp_path / "skills"
    with patch("tools.skills_tool.SKILLS_DIR", skills_dir), patch(
        "tools.generic_planning_tool._call_cronjob_tool",
        return_value={"success": False, "error": "cron unavailable"},
        create=True,
    ):
        result = json.loads(generic_generate_skill(plan=plan, persist=True))

    assert result["status"] == "blocked"
    assert result["diagnostics"][0]["code"] == "cron_create_failed"
    assert not (skills_dir / "productivity" / "collect-source-packet").exists()
    assert not (skills_dir / "productivity" / "summarize-source-packet").exists()


def test_generic_generate_skill_rolls_back_artifact_bundle_when_skill_write_fails(tmp_path):
    plan = {
        "approved": True,
        "user_goal": "weekly source packet workflow",
        "inputs_needed": ["source packet"],
        "tools_required": [],
        "user_confirmation_required": True,
        "artifacts": [
            {"type": "skill", "id": "workflow_part_1", "user_goal": "collect source packet"},
            {"type": "skill", "id": "workflow_part_2", "user_goal": "summarize source packet"},
        ],
    }
    skills_dir = tmp_path / "skills"
    original_write_text = type(skills_dir).write_text
    calls = {"count": 0}

    def flaky_write_text(self, content, encoding=None):
        calls["count"] += 1
        if calls["count"] == 2:
            raise OSError("disk full")
        return original_write_text(self, content, encoding=encoding)

    with patch("tools.skills_tool.SKILLS_DIR", skills_dir), patch("pathlib.Path.write_text", flaky_write_text):
        result = json.loads(generic_generate_skill(plan=plan, persist=True))

    assert result["status"] == "blocked"
    assert result["diagnostics"][0]["code"] == "skill_write_failed"
    assert not (skills_dir / "productivity" / "collect-source-packet").exists()
    assert not (skills_dir / "productivity" / "summarize-source-packet").exists()


def test_generic_generate_skill_blocks_bundle_missing_child_tool_without_saving(tmp_path):
    plan = {
        "approved": True,
        "user_goal": "collect weekly metrics and draft weekly report",
        "tools_required": [],
        "user_confirmation_required": True,
        "skills_to_generate": [
            {
                "user_goal": "collect weekly metrics",
                "steps": ["Collect metrics."],
                "tools_required": [],
                },
                {
                    "user_goal": "draft weekly report",
                    "steps": ["Draft the report."],
                    "tools_required": ["DefinitelyMissingTool"],
                },
        ],
    }
    skills_dir = tmp_path / "skills"
    with patch("tools.skills_tool.SKILLS_DIR", skills_dir):
        result = json.loads(generic_generate_skill(plan=plan, persist=True))

    assert result["status"] == "blocked"
    assert result["diagnostics"][0]["code"] == "missing_tools"
    assert not skills_dir.exists()


def test_generic_generate_skill_blocks_missing_tool():
    result = json.loads(generic_generate_skill(plan={
        "approved": True,
        "user_goal": "weekly meeting notes",
        "tools_required": ["DefinitelyMissingTool"],
        "user_confirmation_required": True,
    }))
    assert result["status"] == "blocked"
    assert result["diagnostics"][0]["code"] == "missing_tools"


def test_generic_generate_skill_blocks_unsupported_external_action_from_markdown_capability():
    result = json.loads(generic_generate_skill(plan={
        "approved": True,
        "user_goal": "send weekly email",
        "steps": ["Send the email to customers."],
        "tools_required": [],
        "user_confirmation_required": False,
    }))
    assert result["status"] == "blocked"
    assert result["diagnostics"][0]["code"] == "unsupported_capability"
    assert result["diagnostics"][0]["message"] == "计划引用了当前不可用的能力：主动发送给别人。"


def test_generic_generate_skill_blocks_unapproved_plan_without_saving(tmp_path):
    skills_dir = tmp_path / "skills"
    result = json.loads(generic_generate_skill(plan={
        "user_goal": "weekly meeting notes",
        "tools_required": [],
        "user_confirmation_required": True,
    }, persist=True, output_path=str(skills_dir / "productivity" / "weekly-meeting-notes" / "SKILL.md")))

    assert result["status"] == "blocked"
    assert result["diagnostics"][0]["code"] == "plan_not_approved"
    assert not skills_dir.exists()


def test_generic_generate_skill_blocks_name_conflict_without_overwriting(tmp_path):
    existing = tmp_path / "skills" / "productivity" / "weekly-meeting-notes" / "SKILL.md"
    existing.parent.mkdir(parents=True)
    existing.write_text("original", encoding="utf-8")

    with patch("tools.skills_tool.SKILLS_DIR", tmp_path / "skills"):
        result = json.loads(generic_generate_skill(plan={
            "approved": True,
            "user_goal": "weekly meeting notes",
            "tools_required": [],
            "user_confirmation_required": True,
        }, persist=True))

    assert result["status"] == "blocked"
    assert result["diagnostics"][0]["code"] == "name_conflict"
    assert existing.read_text(encoding="utf-8") == "original"
