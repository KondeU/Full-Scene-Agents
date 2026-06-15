#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: syncSkill2Openclaw.sh [options]

Sync genSkill-main into a flat skills directory layout.

Options:
  --target openclaw|claude|all  Target runtime to sync. Defaults to openclaw.
  --source PATH                 genSkill-main source directory. Defaults to this script's directory.
  --openclaw-home PATH          openclaw home. Defaults to ${OPENCLAW_HOME:-$HOME/.openclaw}.
  --claude-home PATH            Claude Code home. Defaults to ${CLAUDE_HOME:-$HOME/.claude}.
  --dry-run                     Print actions without writing files.
  -h, --help                    Show this help.
USAGE
}

die() {
  echo "syncSkill2Openclaw: $*" >&2
  exit 1
}

script_dir() {
  local source="${BASH_SOURCE[0]}"
  while [[ -L "$source" ]]; do
    local dir
    dir="$(cd -P "$(dirname "$source")" && pwd)"
    source="$(readlink "$source")"
    [[ "$source" != /* ]] && source="$dir/$source"
  done
  cd -P "$(dirname "$source")" && pwd
}

TARGET="openclaw"
SOURCE_DIR="$(script_dir)"
OPENCLAW_HOME_DIR="${OPENCLAW_HOME:-$HOME/.openclaw}"
CLAUDE_HOME_DIR="${CLAUDE_HOME:-$HOME/.claude}"
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      [[ $# -ge 2 ]] || die "--target requires a value"
      TARGET="$2"
      shift 2
      ;;
    --source)
      [[ $# -ge 2 ]] || die "--source requires a path"
      SOURCE_DIR="$2"
      shift 2
      ;;
    --openclaw-home)
      [[ $# -ge 2 ]] || die "--openclaw-home requires a path"
      OPENCLAW_HOME_DIR="$2"
      shift 2
      ;;
    --claude-home)
      [[ $# -ge 2 ]] || die "--claude-home requires a path"
      CLAUDE_HOME_DIR="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
done

case "$TARGET" in
  openclaw|claude|all) ;;
  *) die "--target must be one of: openclaw, claude, all" ;;
esac

SOURCE_DIR="$(cd "$SOURCE_DIR" && pwd)"

required_paths=(
  "SKILL.md"
  "skills/brainstorming/SKILL.md"
  "skills/writing-plans/SKILL.md"
  "skills/writing-skills/SKILL.md"
  "skills/execute/SKILL.md"
  "scripts/generate-skill.cjs"
  "references/capabilities"
)

for required_path in "${required_paths[@]}"; do
  [[ -e "$SOURCE_DIR/$required_path" ]] || die "missing required source path: $SOURCE_DIR/$required_path"
done

run() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '+'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

copy_file() {
  local src="$1"
  local dest="$2"
  run mkdir -p "$(dirname "$dest")"
  run cp "$src" "$dest"
}

copy_dir_clean() {
  local src="$1"
  local dest="$2"
  run rm -rf "$dest"
  run mkdir -p "$(dirname "$dest")"
  run cp -R "$src" "$dest"
  if [[ "$DRY_RUN" -eq 0 ]]; then
    find "$dest" -name .DS_Store -type f -delete
  fi
}

sync_home() {
  local label="$1"
  local home_dir="$2"
  local skills_dir="$home_dir/skills"

  echo "Syncing genSkill to $label: $skills_dir"
  run mkdir -p "$skills_dir"

  run rm -rf "$skills_dir/genSkill"
  run mkdir -p "$skills_dir/genSkill"
  copy_file "$SOURCE_DIR/SKILL.md" "$skills_dir/genSkill/SKILL.md"
  copy_dir_clean "$SOURCE_DIR/scripts" "$skills_dir/genSkill/scripts"
  copy_dir_clean "$SOURCE_DIR/references" "$skills_dir/genSkill/references"

  copy_dir_clean "$SOURCE_DIR/skills/brainstorming" "$skills_dir/genSkill-brainstorming"

  copy_dir_clean "$SOURCE_DIR/skills/writing-plans" "$skills_dir/genSkill-writing-plans"

  copy_dir_clean "$SOURCE_DIR/skills/writing-skills" "$skills_dir/genSkill-writing-skills"
  copy_dir_clean "$SOURCE_DIR/skills/execute" "$skills_dir/genSkill-execute"
}

if [[ "$TARGET" == "openclaw" || "$TARGET" == "all" ]]; then
  sync_home "openclaw" "$OPENCLAW_HOME_DIR"
fi

if [[ "$TARGET" == "claude" || "$TARGET" == "all" ]]; then
  sync_home "Claude Code" "$CLAUDE_HOME_DIR"
fi
