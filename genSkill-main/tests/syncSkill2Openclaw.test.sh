#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT_DIR/syncSkill2Openclaw.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

assert_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo "Expected file to exist: $path" >&2
    exit 1
  fi
}

assert_same() {
  local left="$1"
  local right="$2"
  if ! cmp -s "$left" "$right"; then
    echo "Expected files to match:" >&2
    echo "  $left" >&2
    echo "  $right" >&2
    exit 1
  fi
}

assert_not_exists() {
  local path="$1"
  if [[ -e "$path" ]]; then
    echo "Expected path not to exist: $path" >&2
    exit 1
  fi
}

assert_contains() {
  local path="$1"
  local text="$2"
  if ! grep -Fq "$text" "$path"; then
    echo "Expected file to contain '$text': $path" >&2
    exit 1
  fi
}

bash "$SCRIPT" --source "$ROOT_DIR" --openclaw-home "$TMP_DIR/openclaw"

OPENCLAW_SKILLS="$TMP_DIR/openclaw/skills"
assert_same "$ROOT_DIR/SKILL.md" "$OPENCLAW_SKILLS/genSkill/SKILL.md"
assert_same "$ROOT_DIR/scripts/generate-skill.cjs" "$OPENCLAW_SKILLS/genSkill/scripts/generate-skill.cjs"
assert_file "$OPENCLAW_SKILLS/genSkill/references/capabilities-summary.md"
assert_file "$OPENCLAW_SKILLS/genSkill/references/a2ui-emit-guide.md"
assert_same "$ROOT_DIR/skills/brainstorming/SKILL.md" "$OPENCLAW_SKILLS/genSkill-brainstorming/SKILL.md"
assert_not_exists "$OPENCLAW_SKILLS/genSkill-brainstorming/scripts"
assert_not_exists "$OPENCLAW_SKILLS/genSkill-brainstorming/references"
assert_contains "$OPENCLAW_SKILLS/genSkill-brainstorming/SKILL.md" "../genSkill/references/capabilities-summary.md"
assert_contains "$OPENCLAW_SKILLS/genSkill-brainstorming/SKILL.md" "../genSkill/scripts/generate-skill.cjs"
assert_same "$ROOT_DIR/skills/writing-plans/SKILL.md" "$OPENCLAW_SKILLS/genSkill-writing-plans/SKILL.md"
assert_file "$OPENCLAW_SKILLS/genSkill-writing-plans/plan-reviewer-prompt.md"
assert_not_exists "$OPENCLAW_SKILLS/genSkill-writing-plans/references"
assert_contains "$OPENCLAW_SKILLS/genSkill-writing-plans/SKILL.md" "../genSkill/references/capabilities-summary.md"
assert_contains "$OPENCLAW_SKILLS/genSkill-writing-plans/plan-reviewer-prompt.md" "../genSkill/references/capabilities-summary.md"
assert_same "$ROOT_DIR/skills/writing-skills/SKILL.md" "$OPENCLAW_SKILLS/genSkill-writing-skills/SKILL.md"
assert_same "$ROOT_DIR/skills/execute/SKILL.md" "$OPENCLAW_SKILLS/genSkill-execute/SKILL.md"
assert_not_exists "$OPENCLAW_SKILLS/genSkill-writing-skills/scripts"
assert_not_exists "$OPENCLAW_SKILLS/genSkill-writing-skills/references"
assert_not_exists "$OPENCLAW_SKILLS/genSkill-execute/references"
assert_contains "$OPENCLAW_SKILLS/genSkill-execute/SKILL.md" "../genSkill/references/"
assert_contains "$OPENCLAW_SKILLS/genSkill-writing-skills/SKILL.md" "../genSkill/scripts/generate-skill.cjs"
assert_contains "$OPENCLAW_SKILLS/genSkill-writing-skills/SKILL.md" "../genSkill/references/capabilities-summary.md"

PLAN_JSON="$TMP_DIR/plan.json"
cat >"$PLAN_JSON" <<'JSON'
{
  "approved": true,
  "user_goal": "保存一个文字输入测试流程",
  "inputs_needed": ["一段文字"],
  "schedule_or_trigger": "手动触发",
  "memory_scope": "只保存流程",
  "output_or_delivery": "聊天里返回结果",
  "confirmation_boundary": "输出前无需额外确认",
  "failure_handling": "缺少文字时追问一次",
  "acceptance_criteria": ["能生成待写清单"],
  "capabilities_used": ["input.typed_text"]
}
JSON

(
  cd "$OPENCLAW_SKILLS/genSkill-writing-skills"
  node ../genSkill/scripts/generate-skill.cjs \
    --plan "$PLAN_JSON" \
    --target openclaw \
    --home "$TMP_DIR/openclaw" \
    --dry-run \
    | grep -Fq '"status": "ready_to_write"'
)

bash "$SCRIPT" \
  --source "$ROOT_DIR" \
  --target all \
  --openclaw-home "$TMP_DIR/openclaw-all" \
  --claude-home "$TMP_DIR/claude"

assert_same "$ROOT_DIR/SKILL.md" "$TMP_DIR/openclaw-all/skills/genSkill/SKILL.md"
assert_same "$ROOT_DIR/SKILL.md" "$TMP_DIR/claude/skills/genSkill/SKILL.md"
assert_file "$TMP_DIR/claude/skills/genSkill/references/capabilities-summary.md"
assert_file "$TMP_DIR/claude/skills/genSkill/scripts/generate-skill.cjs"
assert_not_exists "$TMP_DIR/claude/skills/genSkill-writing-skills/scripts"
assert_not_exists "$TMP_DIR/claude/skills/genSkill-writing-skills/references"

echo "syncSkill2Openclaw tests passed"
