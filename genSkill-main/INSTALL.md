# 安装 genSkill 到 openclaw 与 Claude Code

genSkill 是一套把"一件常做的事"变成可复用 Skill 的四阶段工作流:
`brainstorming → writing-plans → writing-skills → execute`。它本身就是几份
Skill（加一个校验/编排脚本和能力清单），安装它 = 让你的运行时在
`/genSkill` 时能发现并加载这些 Skill。

本文覆盖两个运行时：

- **openclaw** — 脚本原生支持的目标（`--target openclaw`）。
- **Claude Code** — 脚本没有专门的 `claudecode` 目标，但它的 Skill 目录布局
  与 openclaw/codex 完全一致，可以直接复用，下文说明怎么接。

> 前提：装好 Node.js（脚本是纯 Node，无第三方依赖）和对应运行时。
> 验证：`node --version` 能打印版本号即可。

## 这套东西由什么组成

```
genSkill-main/
  SKILL.md                    # 入口：/genSkill 路由到各阶段
  skills/
    brainstorming/SKILL.md    # 澄清意图
    writing-plans/SKILL.md    # 拆解 + 确认计划
    writing-skills/SKILL.md   # 由 LLM 撰写每个子技能正文
    execute/SKILL.md          # 可选首次试跑
  scripts/
    generate-skill.cjs        # 校验 + 能力门控 + DAG 排序 + 写 orchestration.json
  references/
    capabilities/*.md         # 能力清单（支持/不支持）
    authoring-good-skills.md  # 写好 workflow skill 的手艺层
    authoring-good-skills-example.md  # 一个完整范例
    approved-plan.schema.json # 计划 JSON 的 schema
  agents/*.yaml               # 各平台的挂载配置
```

安装要做两件事：

1. 把 genSkill 这套 **Skill 目录**放到运行时能发现的位置。
2. 确保 `/genSkill` 触发后，`writing-skills` 阶段能跑到 `generate-skill.cjs`。

> genSkill 生成的**用户 Skill**（如健康周报的 4 个子技能）和 genSkill **自身**
> 装在同一个 `skills/` 根下，互不冲突——前者是产物，后者是工具。

## 安装到 openclaw

openclaw 在 `~/.openclaw/skills/<slug>/SKILL.md` 这种扁平目录里发现 Skill；
环境变量 `OPENCLAW_HOME` 可覆盖根路径。

### 1. 放置 genSkill 这套 Skill

把 genSkill 的每个 Skill 目录复制到 openclaw 的 skills 根下。保持目录名即 Skill 名：

```bash
# 假定你在 genSkill-main 仓库根目录
OPENCLAW_SKILLS="${OPENCLAW_HOME:-$HOME/.openclaw}/skills"
mkdir -p "$OPENCLAW_SKILLS"

# 入口 Skill（genSkill 自身）
mkdir -p "$OPENCLAW_SKILLS/genSkill"
cp SKILL.md "$OPENCLAW_SKILLS/genSkill/SKILL.md"

# 四个阶段 Skill
for phase in brainstorming writing-plans writing-skills execute; do
  cp -R "skills/$phase" "$OPENCLAW_SKILLS/genSkill-$phase"
done
```

> 目录名用 `genSkill-<phase>` 只是为了在扁平命名空间里不撞名；每个 SKILL.md
> 内部的 `name:`（如 `genSkill:writing-plans`）才是路由真正认的标识，保持不动。

### 2. 让 writing-skills 能找到脚本和能力清单

`writing-skills` 阶段会运行 `scripts/generate-skill.cjs`，它还会读
`references/capabilities/`。把脚本和 references 一起带过去，并让命令指向 `.cjs`：

```bash
cp -R scripts "$OPENCLAW_SKILLS/genSkill-writing-skills/scripts"
cp -R references "$OPENCLAW_SKILLS/genSkill-writing-skills/references"
```

> 脚本用 `path.resolve(__dirname, "..", "references", "capabilities")` 定位能力清单，
> 即它要求 `scripts/` 和 `references/` 是**同级目录**。上面把两者都放进
> `genSkill-writing-skills/` 下，正好满足这个相对关系。

### 3. 验证

新开一个 openclaw 会话，发：

```
/genSkill 把每周健康数据整理成周报
```

预期：先进入 brainstorming 澄清意图，而**不是**直接开始写文件。这说明入口
Skill 被发现、路由生效。

生成阶段产物会落在 `~/.openclaw/skills/<slug>/`，与 genSkill 自身的目录平级。

## 安装到 Claude Code

Claude Code 从 `~/.claude/skills/<slug>/SKILL.md`（个人级）或项目内
`.claude/skills/<slug>/SKILL.md`（项目级）发现 Skill。布局与 openclaw 一致：
都是 `skills/<slug>/SKILL.md` 扁平目录。

> 注意：`generate-skill.cjs` **没有** `claudecode` 目标，只支持
> `codex / openclaw / hermes`。因为 Claude Code 的目录布局和 openclaw/codex
> 相同，我们用 `--target openclaw`（或 `codex`）加 `--home` 指向 `.claude`
> 来复用，而不是新增目标。这是有意的复用，不是脚本原生支持。

### 1. 放置 genSkill 这套 Skill（个人级）

```bash
CLAUDE_SKILLS="$HOME/.claude/skills"
mkdir -p "$CLAUDE_SKILLS"

mkdir -p "$CLAUDE_SKILLS/genSkill"
cp SKILL.md "$CLAUDE_SKILLS/genSkill/SKILL.md"

for phase in brainstorming writing-plans writing-skills execute; do
  cp -R "skills/$phase" "$CLAUDE_SKILLS/genSkill-$phase"
done

# 脚本与能力清单跟 writing-skills 同级
cp -R scripts "$CLAUDE_SKILLS/genSkill-writing-skills/scripts"
cp -R references "$CLAUDE_SKILLS/genSkill-writing-skills/references"
```

装到某个项目而不是个人级，把 `$HOME/.claude` 换成
`<项目根>/.claude` 即可。

### 2. writing-skills 阶段的生成命令

让脚本把产物写进 Claude Code 的 skills 根：

```bash
node scripts/generate-skill.cjs \
  --plan <plan.json> \
  --target openclaw \
  --home ~/.claude \
  --write
```

`--home ~/.claude` 让输出落到 `~/.claude/skills/<slug>/SKILL.md`，正是
Claude Code 发现 Skill 的位置。项目级则传 `--home <项目根>/.claude`。

> `--target openclaw` 与 `--target codex` 在输出布局上等价（都是
> `<home>/skills/<slug>/`）；二者任选其一。不要用 `hermes`，它会多套一层
> `productivity/` 子目录。

### 3. 验证

```
/genSkill 把每周健康数据整理成周报
```

预期同样是先进 brainstorming。生成阶段会在 `~/.claude/skills/<slug>/` 下
看到新写的 SKILL.md 与 `orchestration.json`。

## 已知不一致（安装前请留意）

`agents/` 下的 `codex.yaml`、`openclaw.yaml`、`hermes.yaml` 里
`generator_command` 写的是 `scripts/generate-skill.js`，但仓库里实际文件名是
`generate-skill.cjs`（只有 `openai.yaml` 写对了）。照 yaml 原样跑会报
"Cannot find module ... generate-skill.js"。

**以本文给出的 `.cjs` 命令为准。** 若要让 yaml 自洽，可统一改名引用：

```bash
# 在 genSkill-main 根目录，把三处错误引用从 .js 修正为 .cjs
# （仅修正命令字符串，不改实际脚本）
sed -i '' 's#generate-skill\.js#generate-skill.cjs#' \
  agents/codex.yaml agents/openclaw.yaml agents/hermes.yaml
```

## 故障排查

| 现象 | 原因 | 处理 |
|------|------|------|
| `Cannot find module .../generate-skill.js` | yaml 引用了不存在的 `.js` | 用 `.cjs`，见上节 |
| 脚本报 `ENOENT references/capabilities` | `references/` 没和 `scripts/` 同级 | 两者一起复制到同一父目录 |
| 子技能被 `skipped` | 用到 `status: unsupported` 的能力 | 查 `references/capabilities/<id>.md`，改用受支持能力 |
| `status: blocked` + `unsupported_capability` | 触到始终禁止的能力（付款/发消息给他人/删除发布/改账号） | 换成手动确认的替代做法 |
| `status: blocked` + `dependency_cycle` | 子技能 `produces/consumes` 成环 | 回 writing-plans 修依赖关系 |
| `skill_already_exists` | 目标 slug 已有 SKILL.md | 换 goal 或先删旧的 |
| `/genSkill` 不进 brainstorming，直接写文件 | 入口 Skill 没被发现 | 确认 `genSkill/SKILL.md` 在 skills 根下，重开会话 |

## 平台路径速查

| 平台 | Skill 根 | 覆盖变量 | 生成命令的 `--target` |
|------|----------|----------|------------------------|
| openclaw | `~/.openclaw/skills/<slug>/` | `OPENCLAW_HOME` | `openclaw` |
| codex | `~/.codex/skills/<slug>/` | `CODEX_HOME` | `codex` |
| Claude Code | `~/.claude/skills/<slug>/` | 用 `--home ~/.claude` | `openclaw`（复用） |
| hermes | `~/.hermes/skills/productivity/<slug>/` | `HERMES_HOME` | `hermes` |
