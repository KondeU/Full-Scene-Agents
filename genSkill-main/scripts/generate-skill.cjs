#!/usr/bin/env node
/**
 * generate-skill.cjs
 *
 * Validation + planning helper for the genSkill writing-skills phase.
 *
 * This does NOT write SKILL.md bodies — authoring a good skill (workflow
 * detail, description, naming) is a judgment task left to the LLM. The script
 * validates the approved plan, gates on capability support (hard-blocking the
 * always-forbidden capabilities, skipping the merely-unsupported ones and
 * cascading the skip down the produces/consumes DAG), orders the surviving
 * skills topologically, and returns a work-list telling the LLM exactly which
 * skills to write and where. It also writes the one pure-data artifact,
 * orchestration.json.
 *
 * Output status:
 *   ready_to_write — plan ok; `skills[]` is the work-list, `skipped[]` explains
 *                    any dropped sub-skills, `orchestration` is the manifest.
 *   blocked        — `diagnostics[]` explains why (forbidden capability,
 *                    dependency cycle, malformed plan, name conflict).
 *
 * Usage:
 *   node generate-skill.cjs --plan <path.json> --target codex [--write] [--dry-run] [--home <dir>]
 */

const fs = require("fs");
const path = require("path");
const crypto = require("crypto");

const SUPPORTED_TARGETS = ["codex", "openclaw", "hermes"];

// Fields required on every plan, regardless of single- or multi-skill shape.
const REQUIRED_PLAN_FIELDS = [
  "approved",
  "user_goal",
  "schedule_or_trigger",
  "memory_scope",
  "output_or_delivery",
  "confirmation_boundary",
  "failure_handling",
  "acceptance_criteria",
  "capabilities_used",
];

// Fields required on each sub-skill inside plan.skills[]. Note: detailed
// `steps` are NOT required here — authoring the workflow is the LLM's job in
// writing-skills. The plan only needs to say what each sub-skill is for and
// which capabilities/products it touches.
const REQUIRED_SKILL_FIELDS = ["id", "role", "user_goal", "capabilities_used"];

// Fields required only on legacy flat (single-skill) plans.
const REQUIRED_LEGACY_FIELDS = ["inputs_needed"];

// --- Capability loading ---

function splitFrontmatter(text, filePath) {
  if (!text.startsWith("---\n")) {
    throw new Error(`${filePath} missing frontmatter`);
  }
  const end = text.indexOf("\n---\n", 4);
  if (end < 0) {
    throw new Error(`${filePath} has unterminated frontmatter`);
  }
  const yamlBlock = text.slice(4, end);
  const body = text.slice(end + 5).trim();
  return { meta: parseSimpleYaml(yamlBlock), body };
}

function parseSimpleYaml(text) {
  const data = {};
  for (const rawLine of text.split("\n")) {
    const line = rawLine.trim();
    if (!line || line.startsWith("#") || !line.includes(":")) continue;
    const colonIdx = line.indexOf(":");
    const key = line.slice(0, colonIdx).trim();
    let value = line.slice(colonIdx + 1).trim();
    if (value.startsWith("[") && value.endsWith("]")) {
      const inner = value.slice(1, -1).trim();
      data[key] = inner
        ? inner.split(",").map((s) => s.trim().replace(/^["']|["']$/g, ""))
        : [];
    } else {
      data[key] = value.replace(/^["']|["']$/g, "");
    }
  }
  return data;
}

function loadCapabilities() {
  const capDir = path.resolve(__dirname, "..", "references", "capabilities");
  const files = fs.readdirSync(capDir).filter((f) => f.endsWith(".md")).sort();
  return files.map((file) => {
    const filePath = path.join(capDir, file);
    const content = fs.readFileSync(filePath, "utf-8");
    const { meta, body } = splitFrontmatter(content, filePath);
    const userWords = Array.isArray(meta.user_words) ? meta.user_words : [];
    return {
      id: (meta.id || "").trim(),
      domain: (meta.domain || "").trim(),
      label: (meta.label || "").trim(),
      status: (meta.status || "unsupported").trim(),
      userWords,
      body,
    };
  });
}

// --- Plan shape normalization ---

// A plan is "multi-skill" when it carries an explicit skills[] array.
// Legacy plans expose a flat steps[]/inputs_needed[] and render as one skill.
function isMultiSkill(plan) {
  return Array.isArray(plan.skills) && plan.skills.length > 0;
}

// Collapse a legacy flat plan into the same skills[] shape the multi-skill
// path uses, so downstream code only handles one representation.
function normalizeSkills(plan) {
  if (isMultiSkill(plan)) {
    return plan.skills.map((s) => ({
      id: s.id,
      role: s.role || s.id,
      user_goal: s.user_goal || plan.user_goal,
      inputs_needed: s.inputs_needed || [],
      steps: s.steps || [],
      capabilities_used: s.capabilities_used || [],
      produces: s.produces || null,
      produces_shape: s.produces_shape || null,
      consumes: Array.isArray(s.consumes) ? s.consumes : [],
    }));
  }
  return [
    {
      id: null, // legacy single skill uses the plan-level slug directly
      role: plan.user_goal,
      user_goal: plan.user_goal,
      inputs_needed: plan.inputs_needed || [],
      steps: plan.steps || [],
      capabilities_used: plan.capabilities_used || [],
      produces: null,
      consumes: [],
    },
  ];
}

// --- Validation ---

// Capabilities that hard-block the WHOLE plan even in multi-skill mode.
// These mirror the root SKILL.md "always-blocked" list: they are not merely
// "unsupported on this platform" but disallowed outright, so they must never
// be silently downgraded to a per-skill skip.
const ALWAYS_BLOCKED_IDS = new Set([
  "external.payment",
  "external.send_message",
  "external.delete_or_publish",
  "external.account_change",
]);

// Find unsupported-capability hits. In multi-skill mode, only ALWAYS_BLOCKED
// capabilities are returned (the rest are handled by per-skill gating/skip).
// In legacy single-skill mode, any unsupported capability blocks, preserving
// the original behavior.
function findUnsupportedMatches(plan, capabilities, hardBlockOnly) {
  const usedIds = new Set(
    (plan.capabilities_used || []).map((s) => s.toLowerCase())
  );
  const riskText = [
    plan.user_goal || "",
    plan.schedule_or_trigger || "",
    plan.memory_scope || "",
    plan.output_or_delivery || "",
    plan.confirmation_boundary || "",
    plan.failure_handling || "",
    ...(plan.inputs_needed || []),
    ...(plan.steps || []),
    ...(plan.acceptance_criteria || []),
    ...(plan.capabilities_used || []),
  ]
    .join("\n")
    .toLowerCase();

  const matches = [];
  for (const cap of capabilities) {
    if (cap.status === "supported") continue;
    if (hardBlockOnly && !ALWAYS_BLOCKED_IDS.has(cap.id)) continue;
    const words = [cap.id, cap.label, ...cap.userWords];
    const hit =
      usedIds.has(cap.id.toLowerCase()) ||
      words.some((w) => w && riskText.includes(w.toLowerCase()));
    if (hit) {
      matches.push({
        code: "unsupported_capability",
        capability_id: cap.id,
        capability: cap.label,
        message: `当前不能保存包含"${cap.label}"的流程。请改成手动确认后的替代做法。`,
      });
    }
  }
  return matches;
}

function validatePlan(plan, capabilities) {
  const diagnostics = [];
  const missing = REQUIRED_PLAN_FIELDS.filter(
    (f) =>
      !(f in plan) ||
      plan[f] === "" ||
      plan[f] === null ||
      (Array.isArray(plan[f]) && plan[f].length === 0)
  );
  if (missing.length > 0) {
    diagnostics.push({
      code: "missing_required_fields",
      fields: missing,
      message: "Plan is missing required fields.",
    });
  }

  if (isMultiSkill(plan)) {
    // Each sub-skill must carry its own id/steps/capabilities.
    plan.skills.forEach((skill, idx) => {
      const miss = REQUIRED_SKILL_FIELDS.filter(
        (f) =>
          !(f in skill) ||
          skill[f] === "" ||
          skill[f] === null ||
          (Array.isArray(skill[f]) && skill[f].length === 0)
      );
      if (miss.length > 0) {
        diagnostics.push({
          code: "missing_skill_fields",
          skill_index: idx,
          skill_id: skill.id || `#${idx}`,
          fields: miss,
          message: `Sub-skill ${skill.id || `#${idx}`} is missing required fields.`,
        });
      }
    });
    // Sub-skill ids must be unique — they become directory slugs.
    const ids = plan.skills.map((s) => s.id).filter(Boolean);
    const dupes = ids.filter((id, i) => ids.indexOf(id) !== i);
    if (dupes.length > 0) {
      diagnostics.push({
        code: "duplicate_skill_id",
        ids: [...new Set(dupes)],
        message: `Duplicate sub-skill ids: ${[...new Set(dupes)].join(", ")}`,
      });
    }
  } else {
    // Legacy flat plan: require the old flat fields.
    const legacyMissing = REQUIRED_LEGACY_FIELDS.filter(
      (f) =>
        !(f in plan) ||
        (Array.isArray(plan[f]) && plan[f].length === 0)
    );
    if (legacyMissing.length > 0) {
      diagnostics.push({
        code: "missing_required_fields",
        fields: legacyMissing,
        message: "Legacy plan is missing required fields.",
      });
    }
  }

  if (plan.approved !== true) {
    diagnostics.push({
      code: "plan_not_approved",
      message: "The plan must be explicitly approved before generating a skill.",
    });
  }
  // Multi-skill plans only hard-block on always-blocked capabilities; other
  // unsupported caps are handled per-skill (skip + cascade) in generate().
  diagnostics.push(...findUnsupportedMatches(plan, capabilities, isMultiSkill(plan)));
  return diagnostics;
}

// --- Slug generation ---

const SPECIAL_SLUGS = {
  "health.weekly_report": "health-weekly-report",
};

function slugify(plan) {
  for (const capId of plan.capabilities_used || []) {
    if (SPECIAL_SLUGS[capId]) return SPECIAL_SLUGS[capId];
  }
  const goal = (plan.user_goal || "workflow").trim().toLowerCase();
  let slug = goal.replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");
  if (!slug) {
    const hash = crypto
      .createHash("sha1")
      .update(goal)
      .digest("hex")
      .slice(0, 8);
    slug = `workflow-${hash}`;
  }
  return slug.slice(0, 60).replace(/-$/, "");
}

// Sub-skills live in sibling directories: <plan-slug>-<skill-id>.
function subSkillSlug(planSlug, skillId) {
  const safeId = String(skillId)
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "");
  return `${planSlug}-${safeId}`.slice(0, 80).replace(/-$/, "");
}

// Map capability id -> status for fast gating.
function capabilityStatusMap(capabilities) {
  const map = new Map();
  for (const cap of capabilities) {
    if (cap.id) map.set(cap.id.toLowerCase(), cap.status);
  }
  return map;
}

// Capabilities used by a skill that are not marked supported.
function unsupportedCapsForSkill(skill, statusMap) {
  return (skill.capabilities_used || []).filter((id) => {
    const st = statusMap.get(String(id).toLowerCase());
    return st !== "supported";
  });
}

// --- Output path resolution ---

function targetHome(target, homeOverride) {
  if (homeOverride) return path.resolve(homeOverride);
  const envMap = {
    codex: "CODEX_HOME",
    openclaw: "OPENCLAW_HOME",
    hermes: "HERMES_HOME",
  };
  const defaults = {
    codex: "~/.codex",
    openclaw: "~/.openclaw",
    hermes: "~/.hermes",
  };
  const envVal = process.env[envMap[target]];
  const raw = envVal || defaults[target];
  return raw.startsWith("~")
    ? path.join(process.env.HOME || "/tmp", raw.slice(2))
    : path.resolve(raw);
}

function outputPath(target, home, slug) {
  if (target === "hermes") {
    return path.join(home, "skills", "productivity", slug, "SKILL.md");
  }
  return path.join(home, "skills", slug, "SKILL.md");
}

// --- Build-item assembly ---
//
// The script no longer renders SKILL.md bodies. Writing a good skill (workflow
// detail, description, naming) is a judgment task that belongs to the LLM in
// the writing-skills phase. This script's job is to validate, gate on
// capabilities, order the DAG, and hand the LLM a precise work-list: which
// skills to write, where, and the shared context every skill needs.

function listLines(items) {
  if (!items || items.length === 0) return ["- 未指定"];
  return items.map((item) => `- ${item}`);
}

// Build one work-item describing a skill the LLM must author. Includes the
// resolved slug/output path and the sub-skill's own fields, plus nothing the
// LLM should be deciding for itself (no body, no description).
function buildItem(plan, skill, slug, outPath) {
  return {
    id: skill.id,
    role: skill.role || skill.user_goal || slug,
    user_goal: skill.user_goal || plan.user_goal,
    slug,
    output_path: outPath,
    inputs_needed: skill.inputs_needed || [],
    capabilities_used: skill.capabilities_used || [],
    produces: skill.produces || null,
    produces_shape: skill.produces_shape || null,
    consumes: skill.consumes || [],
  };
}

// Plan-level context shared by every skill the LLM writes.
function planContext(plan) {
  return {
    user_goal: plan.user_goal,
    schedule_or_trigger: plan.schedule_or_trigger || "手动触发",
    memory_scope: plan.memory_scope || "只保存流程，不保存具体数据",
    output_or_delivery: plan.output_or_delivery || "在聊天里给一份结果",
    confirmation_boundary: plan.confirmation_boundary || "输出前让用户检查",
    failure_handling: plan.failure_handling || "缺少必要内容时先问一个最小问题。",
    acceptance_criteria: plan.acceptance_criteria || [],
  };
}

// --- DAG ordering & gating ---

// Topologically order skills by produces/consumes. Returns {order, cycle}.
// order is a list of skill ids; cycle is non-null if a dependency loop exists.
function topoOrder(skills) {
  const byProduct = new Map(); // product id -> producing skill id
  for (const s of skills) {
    if (s.produces) byProduct.set(s.produces, s.id);
  }
  const deps = new Map(); // skill id -> set of skill ids it depends on
  for (const s of skills) {
    const set = new Set();
    for (const c of s.consumes || []) {
      const producer = byProduct.get(c);
      if (producer && producer !== s.id) set.add(producer);
    }
    deps.set(s.id, set);
  }

  const order = [];
  const visited = new Set();
  const onStack = new Set();
  let cycle = null;

  function visit(id, trail) {
    if (cycle) return;
    if (visited.has(id)) return;
    if (onStack.has(id)) {
      cycle = [...trail, id];
      return;
    }
    onStack.add(id);
    for (const dep of deps.get(id) || []) {
      visit(dep, [...trail, id]);
      if (cycle) return;
    }
    onStack.delete(id);
    visited.add(id);
    order.push(id);
  }

  for (const s of skills) {
    visit(s.id, []);
    if (cycle) break;
  }
  return { order, cycle, deps, byProduct };
}

// Given skills that are skipped (unsupported caps), cascade the skip to any
// downstream skill whose consumed product can no longer be produced.
function cascadeSkips(skills, initialSkipIds, byProduct) {
  const skipped = new Set(initialSkipIds);
  let changed = true;
  while (changed) {
    changed = false;
    for (const s of skills) {
      if (skipped.has(s.id)) continue;
      for (const c of s.consumes || []) {
        const producer = byProduct.get(c);
        if (producer && skipped.has(producer)) {
          skipped.add(s.id);
          changed = true;
          break;
        }
      }
    }
  }
  return skipped;
}

// --- Main logic ---

function generate(plan, target, homeOverride, write) {
  const capabilities = loadCapabilities();
  const planSlug = slugify(plan);
  const home = targetHome(target, homeOverride);

  const diagnostics = validatePlan(plan, capabilities);
  if (diagnostics.length > 0) {
    return { status: "blocked", skills: [], skipped: [], diagnostics };
  }

  const multi = isMultiSkill(plan);
  const normalized = normalizeSkills(plan);
  const statusMap = capabilityStatusMap(capabilities);
  const context = planContext(plan);

  // Legacy single-skill path: one work-item, plan-level slug.
  if (!multi) {
    const outPath = outputPath(target, home, planSlug);
    if (write && fs.existsSync(outPath)) {
      return blockedExists(outPath);
    }
    return {
      status: "ready_to_write",
      context,
      skills: [buildItem(plan, normalized[0], planSlug, outPath)],
      orchestration: {},
      orchestration_path: "",
      skipped: [],
      diagnostics: [],
    };
  }

  // --- Multi-skill path ---
  const { order, cycle, byProduct } = topoOrder(normalized);
  if (cycle) {
    return {
      status: "blocked", skills: [], skipped: [],
      diagnostics: [{ code: "dependency_cycle", cycle, message: `Sub-skill dependency cycle: ${cycle.join(" → ")}` }],
    };
  }

  // Gate on capability support, then cascade skips down the DAG.
  const gatedSkips = [];
  const initialSkip = [];
  for (const skill of normalized) {
    const bad = unsupportedCapsForSkill(skill, statusMap);
    if (bad.length > 0) {
      initialSkip.push(skill.id);
      gatedSkips.push({
        id: skill.id, reason: "unsupported_capability", capabilities: bad,
        message: `子流程「${skill.role || skill.id}」用到当前不支持的能力（${bad.join(", ")}），已跳过。`,
      });
    }
  }
  const skipSet = cascadeSkips(normalized, initialSkip, byProduct);
  for (const skill of normalized) {
    if (skipSet.has(skill.id) && !initialSkip.includes(skill.id)) {
      gatedSkips.push({
        id: skill.id, reason: "broken_dependency",
        message: `子流程「${skill.role || skill.id}」依赖的上游被跳过，已一并跳过。`,
      });
    }
  }

  const byId = new Map(normalized.map((s) => [s.id, s]));
  const items = [];
  // List in topological order so the LLM writes producers before consumers.
  for (const id of order) {
    if (skipSet.has(id)) continue;
    const skill = byId.get(id);
    const subSlug = subSkillSlug(planSlug, id);
    const outPath = outputPath(target, home, subSlug);
    if (write && fs.existsSync(outPath)) {
      return blockedExists(outPath);
    }
    items.push(buildItem(plan, skill, subSlug, outPath));
  }

  // Emit orchestration.json (pure data, filtered to surviving skills). This is
  // the one file the script writes — the LLM authors the SKILL.md bodies.
  const orchestration = filterOrchestration(plan.orchestration || {}, skipSet);
  const orchDir = path.dirname(outputPath(target, home, planSlug));
  const orchPath = path.join(orchDir, "orchestration.json");
  if (write) {
    fs.mkdirSync(orchDir, { recursive: true });
    fs.writeFileSync(orchPath, JSON.stringify(orchestration, null, 2) + "\n", "utf-8");
    // Pre-create each surviving skill's directory so the LLM only writes files.
    for (const it of items) {
      fs.mkdirSync(path.dirname(it.output_path), { recursive: true });
    }
  }

  return {
    status: "ready_to_write",
    context,
    skills: items,
    orchestration,
    orchestration_path: write ? orchPath : "",
    skipped: gatedSkips,
    diagnostics: [],
  };
}

function blockedExists(outPath) {
  return {
    status: "blocked", skills: [], skipped: [],
    diagnostics: [{ code: "skill_already_exists", message: `A skill already exists at ${outPath}. Choose a different goal or remove the existing skill first.` }],
  };
}

// Drop orchestration entries that reference skipped skills.
function filterOrchestration(orch, skipSet) {
  const out = {};
  if (Array.isArray(orch.scheduled)) {
    out.scheduled = orch.scheduled.filter((e) => !skipSet.has(e.skill));
  }
  if (Array.isArray(orch.immediate)) {
    out.immediate = orch.immediate
      .filter((e) => !skipSet.has(e.skill))
      .map((e) => {
        if (!Array.isArray(e.bindings)) return e;
        return { ...e, bindings: e.bindings.filter((b) => !b.target_skill || !skipSet.has(b.target_skill)) };
      });
  }
  return out;
}

// --- CLI ---

function parseArgs(argv) {
  const args = { plan: null, target: null, home: null, write: false, dryRun: false };
  for (let i = 0; i < argv.length; i++) {
    switch (argv[i]) {
      case "--plan":
        args.plan = argv[++i];
        break;
      case "--target":
        args.target = argv[++i];
        break;
      case "--home":
        args.home = argv[++i];
        break;
      case "--write":
        args.write = true;
        break;
      case "--dry-run":
        args.dryRun = true;
        break;
    }
  }
  return args;
}

function main() {
  const args = parseArgs(process.argv.slice(2));

  if (!args.plan) {
    console.error("Error: --plan is required");
    process.exit(1);
  }
  if (!args.target || !SUPPORTED_TARGETS.includes(args.target)) {
    console.error(`Error: --target must be one of: ${SUPPORTED_TARGETS.join(", ")}`);
    process.exit(1);
  }

  let plan;
  try {
    const raw = fs.readFileSync(path.resolve(args.plan), "utf-8");
    plan = JSON.parse(raw);
    if (typeof plan !== "object" || plan === null || Array.isArray(plan)) {
      throw new Error("Plan JSON must be an object");
    }
  } catch (err) {
    const payload = {
      status: "blocked",
      skill: null,
      output_path: "",
      diagnostics: [{ code: "generator_error", message: err.message }],
    };
    console.log(JSON.stringify(payload, null, 2));
    process.exit(0);
  }

  const result = generate(plan, args.target, args.home, args.write && !args.dryRun);
  console.log(JSON.stringify(result, null, 2));
}

main();
