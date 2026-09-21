#!/bin/bash
# Shared helpers for claude-teacher hooks.
#
# The plugin registers hooks for SessionStart, UserPromptSubmit, Stop,
# PostToolUse and PostToolUseFailure. Those events fire in every project where
# the plugin is enabled, and the default install scope is `user`, so each hook
# checks teach_is_learning_project before emitting anything.

# These files define helpers only. Each event hook explicitly checks its runtime.
. "$SCRIPT_DIR/lib/json.sh"

# Project root for this invocation. CLAUDE_PROJECT_DIR is exported into every
# hook process; the payload's cwd and $PWD are fallbacks.
teach_project_dir() {
  local input="$1" project_dir="${CLAUDE_PROJECT_DIR:-}"

  if [ -z "$project_dir" ] && [ -n "$input" ]; then
    project_dir=$(printf '%s' "$input" | teach_json cwd 2>/dev/null)
  fi

  printf '%s' "${project_dir:-$PWD}"
}

# True when /init-edu has set this project up for learning. The marker file is
# authoritative; memory/knowledge_gaps.md keeps projects initialized by earlier
# versions working.
teach_is_learning_project() {
  local project_dir marker
  # Ignore malformed input and subagent activity. Teaching prompts belong in
  # the main conversation, not in a background research or utility task.
  printf '%s' "$1" | teach_json main-payload >/dev/null 2>&1 || return 1
  project_dir=$(teach_project_dir "$1")
  marker="$project_dir/.claude/claude-teacher.json"
  if [ -e "$marker" ]; then
    # An explicit opt-out wins over the legacy marker. Invalid markers do not
    # activate teaching and are never repaired by a read-only hook.
    teach_json marker "$marker" >/dev/null 2>&1
  else
    [ -f "$project_dir/memory/knowledge_gaps.md" ]
  fi
}

# Path to the global education DB.
teach_db_dir() {
  local database_dir="${CLAUDE_TEACHER_DB:-$HOME/.local/share/claude-education}"
  # Relative overrides would refer to different databases after a cd.
  # Also reject filesystem-root paths made entirely of slashes.
  [ -n "${database_dir//\//}" ] || return 1
  case "$database_dir" in
    /*)
      printf '%s' "${database_dir%/}"
      ;;
    *)
      return 1
      ;;
  esac
}

# Read exactly one JSON object. Broken files are left intact for recovery.
teach_read_object() {
  teach_json object "$1" 2>/dev/null
}

# Emit context for Claude. Plain stdout is only surfaced for UserPromptSubmit
# and SessionStart, so every hook uses this structured form instead.
teach_emit_context() {
  teach_json emit "$1" "$2"
}
